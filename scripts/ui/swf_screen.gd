extends Node2D
## One original screen built from its generated layout (scenes/swf/<screen>.json, from
## tools/convert/layout.py). Every layout node becomes a Node2D whose global transform is
## the node's stage matrix, so the screen sits in original stage units and reaches the
## window through one scale factor (`fit`).
##
## Timeline: the layout carries what the reference player recorded frame by frame from the
## moment the screen opened (record_screen.py timeline). The screen plays it on the
## original's 35 fps clock: node tracks (stage matrix, visibility, clip frame) up to the
## capture frame, then the recorded period in a loop. Sequence pieces switch their art at
## the recorded frames. `open_delay` frames pass before the screen shows, as in the original.
##
## Art comes from the local original pack: original/screens/<screen>/manifest.json, written
## on the machine with the SWF (route A: each piece rendered by the reference player at 3×
## with its masks, filters and blends). Without the pack a piece draws its render bounds as
## an outline, so layout, timing and input still work. Art is resampled once, with
## Lanczos, from 3× to the exact screen scale.
##
## Interactive instances get a hit area over their stage bounds. Buttons show the recorded
## hover and press frames; switches show the frame their owner sets (`set_frame`). The
## comparison loop's node dump reads the `swf_*` metas.

signal action(name: StringName)
signal opened

const STAGE := Vector2(700, 510)
const PACK := "res://original/screens/%s/manifest.json"
const FPS := 35.0
const BLEND_SHADER := preload("res://scripts/ui/swf_blend.gdshader")
## flash.display.BlendMode names (as the reference player dumps them) -> shader modes.
const BLEND_MODES := {"Multiply": 1, "Screen": 2, "Lighten": 3, "Darken": 4, "Difference": 5,
	"Add": 6, "Subtract": 7, "Overlay": 8, "HardLight": 9}

## Set by the comparison loop (tools/compare/godot_capture.gd): advance one SWF frame per
## Godot frame instead of by elapsed time, as the reference player is stepped.
static var frame_locked := false

## Decoded art, shared by every build of every screen: returning to a screen reuses it.
## `warm` fills it from a background thread, so opening a screen does not wait on disk.
static var _images := {}
static var _resized := {}
static var _cache_lock := Mutex.new()
static var _warm_tasks: Array[int] = []

var screen_name: StringName
var layout: Dictionary
var by_path: Dictionary = {}
var art_loaded := 0
var open_delay := 0
var frames_since_created := 0
var index := 0
var is_open := false

var _records: Array[Dictionary] = []
var _by_name: Dictionary = {}
var _art: Array[Dictionary] = []
var _px := -1.0
var _clock := 0.0
var _timeline: Dictionary = {}
var _hits: Node2D


static func create(screen: StringName, delay := 0) -> Node2D:
	var node: Node2D = load("res://scripts/ui/swf_screen.gd").new()
	node.open_delay = delay
	node.build(screen)
	return node


static func layout_of(screen: StringName) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://scenes/swf/%s.json" % screen))


func build(screen: StringName) -> void:
	screen_name = screen
	name = "Swf_" + String(screen)
	layout = layout_of(screen)
	_timeline = layout.get("timeline") if layout.get("timeline") is Dictionary else {}
	var manifest := _manifest()
	var background := Node2D.new()
	background.name = "StageBackground"
	background.set_meta("swf_art", true)
	background.draw.connect(func(): background.draw_rect(Rect2(Vector2.ZERO, STAGE), _background_colour()))
	add_child(background)
	_hits = Node2D.new()
	_hits.name = "Hits"
	_hits.set_meta("swf_art", true)
	for entry: Dictionary in layout.nodes:
		var path: String = entry.path
		if by_path.has(path):
			push_error("duplicate layout path %s: re-record the golden with the current reference player" % path)
			continue
		var node := Node2D.new()
		node.name = _node_name(path)
		var parent: Node2D = by_path.get(entry.parent, self)
		parent.add_child(node)
		by_path[path] = node
		var moved: Array = entry.get("moved_by", [0.0, 0.0])
		var rec := {"entry": entry, "node": node, "parent": entry.parent, "path": path,
			"static": _matrix(entry.stage_matrix), "visible": bool(entry.effective_visible),
			"frame": entry.get("frame", 0), "offset": Vector2(moved[0], moved[1]),
			"track_index": PackedInt32Array(), "track": [], "art": [], "override": -1}
		if entry.has("track"):
			for change: Array in entry.track:
				rec.track_index.append(int(change[0]))
				rec.track.append(change[1])
		node.set_meta("swf_path", path)
		node.set_meta("swf_kind", entry.get("kind", ""))
		node.set_meta("swf_alpha", entry.get("alpha", 1.0))
		node.set_meta("swf_baked", entry.role in ["piece", "sequence"])
		for key in ["frame", "button_state", "text", "clip_depth", "clip_mask", "mask"]:
			if entry.has(key): node.set_meta("swf_" + key, entry[key])
		_records.append(rec)
		_add_piece_art(rec, manifest)
		if entry.has("action") and entry.has("stage_bounds"):
			_hits.add_child(_hit(rec))
			_by_name[String(entry.get("name", "")).split("@")[0]] = rec
	add_child(_hits)
	_apply(0)
	visible = open_delay <= 0
	is_open = open_delay <= 0
	_hits.visible = is_open


## Scale the stage to fit `size` and centre it: the one scale factor of rule 5.
func fit(size: Vector2) -> void:
	var factor := minf(size.x / STAGE.x, size.y / STAGE.y)
	scale = Vector2(factor, factor)
	position = (size - STAGE * factor) * 0.5
	_px = -1.0
	_refresh_art.call_deferred()


## Screen pixels per stage unit, through the window's own stretch.
func pixels_per_unit() -> float:
	if not is_inside_tree(): return scale.x
	return (get_viewport().get_final_transform() * get_global_transform_with_canvas()).get_scale().x


func node_for(path: String) -> Node2D:
	return by_path.get(path)


## Show a switch's frame (1-based clip frame), as its owner's setting dictates.
func set_frame(instance: String, frame: int) -> void:
	var rec: Dictionary = _by_name.get(instance, {})
	if rec.is_empty(): return
	rec.override = frame
	_apply(index)


func _process(delta: float) -> void:
	# The comparison loop steps frames, not time: one SWF frame per Godot frame.
	_clock += 1.0 / FPS if frame_locked else delta
	while _clock >= 1.0 / FPS - 1e-6:
		_clock -= 1.0 / FPS
		frames_since_created += 1
		var t := frames_since_created - open_delay
		if t < 0: continue
		if not is_open:
			is_open = true
			visible = true
			_hits.visible = true
			opened.emit()
		_apply(_timeline_index(t))


func _timeline_index(t: int) -> int:
	if _timeline.is_empty(): return 0
	var capture: int = int(_timeline.capture_index)
	var period: int = maxi(1, int(_timeline.period))
	return t if t <= capture else capture + (t - capture) % period


# ------------------------------------------------------------------ playback

func _state(rec: Dictionary, i: int):
	if rec.track_index.is_empty(): return null
	var k: int = (rec.track_index as PackedInt32Array).bsearch(i, false) - 1
	if k < 0: return []  # not yet present
	return rec.track[k] if rec.track[k] != null else []


func _global_at(rec: Dictionary, i: int) -> Transform2D:
	var s = _state(rec, i)
	if s is Array and s.size() >= 6:
		return Transform2D(Vector2(s[0], s[1]), Vector2(s[2], s[3]), Vector2(s[4], s[5]) + rec.offset)
	return rec.static


func _apply(i: int) -> void:
	index = i
	var globals := {}
	var shown := {}
	for rec: Dictionary in _records:
		var s = _state(rec, i)
		var present: bool = s == null or (s is Array and s.size() > 0)
		var g: Transform2D = _global_at(rec, i) if present else rec.static
		var vis: bool = present and (rec.visible if s == null else bool(s[6]))
		var frame: int = int(rec.frame) if s == null or not present else int(s[7])
		var parent_g: Transform2D = globals.get(rec.parent, Transform2D.IDENTITY)
		var parent_shown: bool = shown.get(rec.parent, true)
		var node: Node2D = rec.node
		node.transform = parent_g.affine_inverse() * g
		node.visible = vis or (present and not parent_shown)
		globals[rec.path] = g
		shown[rec.path] = vis and parent_shown
		if rec.override > 0: frame = rec.override
		if frame > 0: node.set_meta("swf_frame", frame)
		_show_art(rec, i, frame)


func _show_art(rec: Dictionary, i: int, _frame: int) -> void:
	if rec.art.is_empty(): return
	var pick := -1
	var wanted: int = rec.override if rec.override > 0 else int(rec.get("state_frame", -1))
	if wanted > 0:
		for k in rec.art.size():
			if int(rec.art[k].get("state", -1)) == wanted: pick = k
	if pick < 0:
		for k in rec.art.size():
			var art: Dictionary = rec.art[k]
			if art.has("state"): continue
			# A sequence shows its latest art at or before this frame; a static piece its one image.
			if pick < 0 or int(art.index) <= i: pick = k
	for k in rec.art.size():
		var art: Dictionary = rec.art[k]
		art.sprite.visible = k == pick
		if k == pick: _ensure(art)


# ------------------------------------------------------------------ art

func _manifest() -> Dictionary:
	var file := PACK % screen_name
	if not FileAccess.file_exists(file): return {}
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(file))
	if manifest.get("golden_sha256", "") != layout.source.golden_sha256:
		push_warning("original pack for %s was rendered from another golden; re-run the converter" % screen_name)
	return manifest


func _add_piece_art(rec: Dictionary, manifest: Dictionary) -> void:
	var entry: Dictionary = rec.entry
	var path: String = rec.path
	var capture: int = int(_timeline.get("capture_index", 0))
	if entry.role == "piece" and (entry.effective_visible or entry.has("first_visible")):
		var piece = manifest.get("pieces", {}).get(path)
		if piece is Dictionary:
			_add_art(rec, piece, int(piece.get("index", capture)), -1)
		elif entry.effective_visible:
			_add_outline(rec, entry.get("render_bounds", entry.get("stage_bounds", [])))
	elif entry.role == "sequence":
		var frames = manifest.get("sequences", {}).get(path)
		if frames is Dictionary:
			var keys: Array = frames.keys()
			keys.sort_custom(func(a, b): return int(a) < int(b))
			for key in keys: _add_art(rec, frames[key], int(key), -1)
		else:
			_add_outline(rec, entry.get("render_bounds", entry.get("stage_bounds", [])))
	var states = manifest.get("states", {}).get(path)
	if states is Dictionary:
		for frame in states: _add_art(rec, states[frame], capture, int(frame))


## One rendered image of a piece. It was rendered in stage space at timeline `at`: its sprite
## undoes the node's transform at that frame, so later motion of the node carries the art.
## The image itself is decoded only when the art is first shown (or by `warm`).
func _add_art(rec: Dictionary, piece: Dictionary, at: int, state: int) -> void:
	var file := ProjectSettings.globalize_path((PACK % screen_name).get_base_dir().path_join(piece.file))
	if not FileAccess.file_exists(file): return
	var sprite := Sprite2D.new()
	sprite.name = "Art"
	sprite.set_meta("swf_art", true)
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var blend: int = BLEND_MODES.get(String(rec.entry.get("blend_mode", "Normal")), 0)
	if blend > 0:
		# A piece that blends with what lies below it (Flash blend mode), via the screen.
		var shader := ShaderMaterial.new()
		shader.shader = BLEND_SHADER
		shader.set_shader_parameter("mode", blend)
		sprite.material = shader
	else:
		var material := CanvasItemMaterial.new()
		material.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
		sprite.material = material
	sprite.visible = false
	rec.node.add_child(sprite)
	var size: Array = piece.get("pixel_size", [])
	var art := {"sprite": sprite, "file": file, "scale": float(piece.scale), "index": at,
		"size": Vector2(size[0], size[1]) if size.size() == 2 else Vector2.ZERO,
		"at": _global_at(rec, at),
		"origin": Vector2(piece.pixel_origin[0], piece.pixel_origin[1]) / float(piece.scale) + rec.offset,
		"px": -1.0}
	if state > 0: art["state"] = state
	rec.art.append(art)
	art_loaded += 1


func _refresh_art() -> void:
	_px = pixels_per_unit()
	for rec: Dictionary in _records:
		for art: Dictionary in rec.art:
			if art.sprite.visible: _ensure(art)


## Resample once, from the 3× source to the current screen scale.
func _ensure(art: Dictionary) -> void:
	var px := _px if _px > 0.0 else pixels_per_unit()
	if is_equal_approx(px, art.px): return
	art.px = px
	var source := _image(art.file)
	if source == null: return
	var w := maxi(1, roundi(source.get_width() * px / art.scale))
	var h := maxi(1, roundi(source.get_height() * px / art.scale))
	var sprite: Sprite2D = art.sprite
	sprite.texture = ImageTexture.create_from_image(_resized_image(art.file, source, w, h))
	# Stage units per texture pixel, per axis (the rounded size keeps the exact extent).
	var unit := Vector2(source.get_width() / art.scale / w, source.get_height() / art.scale / h)
	sprite.transform = (art.at as Transform2D).affine_inverse() * Transform2D(0.0, unit, 0.0, art.origin)


## The premultiplied 3× image of a piece file, decoded once.
static func _image(file: String) -> Image:
	_cache_lock.lock()
	var image: Image = _images.get(file)
	_cache_lock.unlock()
	if image != null: return image
	image = Image.load_from_file(file)
	if image == null: return null
	# Premultiplied alpha, so resampling does not bleed the black of transparent pixels
	# into edges (dark fringes on thin lines).
	image.premultiply_alpha()
	_cache_lock.lock()
	_images[file] = image
	_cache_lock.unlock()
	return image


static func _resized_image(file: String, source: Image, w: int, h: int) -> Image:
	var key := "%s|%d|%d" % [file, w, h]
	_cache_lock.lock()
	var image: Image = _resized.get(key)
	_cache_lock.unlock()
	if image != null: return image
	image = source.duplicate()
	if w != source.get_width() or h != source.get_height():
		image.resize(w, h, Image.INTERPOLATE_LANCZOS)
	_cache_lock.lock()
	_resized[key] = image
	_cache_lock.unlock()
	return image


## Decode (and, for screen scale `px`, resample) a screen's art in a background thread,
## while another screen is showing.
static func warm(screen: StringName, px: float) -> void:
	var file := PACK % screen
	if not FileAccess.file_exists(file): return
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(file))
	var base := ProjectSettings.globalize_path(file.get_base_dir())
	var jobs := []
	for piece in manifest.get("pieces", {}).values(): jobs.append(piece)
	for states in manifest.get("states", {}).values():
		for piece in states.values(): jobs.append(piece)
	for frames in manifest.get("sequences", {}).values():
		for piece in frames.values(): jobs.append(piece)
	_warm_tasks.append(WorkerThreadPool.add_task(func():
		for piece in jobs:
			var path: String = base.path_join(piece.file)
			var image := _image(path)
			if image != null and px > 0.0:
				var s := float(piece.scale)
				_resized_image(path, image, maxi(1, roundi(image.get_width() * px / s)), maxi(1, roundi(image.get_height() * px / s)))))


## Wait for background decoding before the program exits.
static func finish_warming() -> void:
	for task in _warm_tasks: WorkerThreadPool.wait_for_task_completion(task)
	_warm_tasks.clear()


func _add_outline(rec: Dictionary, bounds: Array) -> void:
	if bounds.size() != 4: return
	var outline := Node2D.new()
	outline.name = "Placeholder"
	outline.set_meta("swf_art", true)
	outline.transform = (rec.static as Transform2D).affine_inverse()
	var rect := Rect2(bounds[0], bounds[1], bounds[2] - bounds[0], bounds[3] - bounds[1])
	outline.draw.connect(func(): outline.draw_rect(rect, Color(1, 1, 1, 0.35), false, 1.0))
	rec.node.add_child(outline)


# ------------------------------------------------------------------ input

## A hit area tested against the art itself, as Flash tests a clip's shapes rather than
## its bounding box: a point counts where the shown art is at least half opaque.
class HitArea extends Button:
	var screen: Node2D
	var rec: Dictionary

	func _has_point(point: Vector2) -> bool:
		if not Rect2(Vector2.ZERO, size).has_point(point): return false
		var art: Dictionary = {}
		for candidate: Dictionary in rec.art:
			if candidate.sprite.visible: art = candidate
		if art.is_empty(): return true  # no art (outline placeholder): the bounds decide
		var image: Image = screen._image(art.file)
		if image == null: return true
		var stage := position + point
		# The art was rendered in stage space at its render frame; buttons do not move.
		var pixel: Vector2 = ((stage - (art.origin as Vector2)) * float(art.scale)).floor()
		if pixel.x < 0 or pixel.y < 0 or pixel.x >= image.get_width() or pixel.y >= image.get_height():
			return false
		return image.get_pixelv(Vector2i(pixel)).a >= 0.5


func _hit(rec: Dictionary) -> Button:
	var entry: Dictionary = rec.entry
	var bounds: Array = entry.stage_bounds
	var hit := HitArea.new()
	hit.screen = self
	hit.rec = rec
	hit.name = String(entry.name).split("@")[0] if entry.has("name") else _node_name(entry.path)
	hit.flat = true
	hit.focus_mode = Control.FOCUS_NONE
	for style in ["normal", "hover", "pressed", "disabled", "focus"]:
		hit.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	# The area covers every state's art (a hovered button may draw larger than at rest).
	var area := Rect2(Vector2(bounds[0], bounds[1]) + rec.offset, Vector2(bounds[2] - bounds[0], bounds[3] - bounds[1]))
	for art: Dictionary in rec.art:
		if art.size != Vector2.ZERO: area = area.merge(Rect2(art.origin, art.size / art.scale))
	hit.position = area.position
	hit.size = area.size
	hit.set_meta("swf_art", true)
	hit.set_meta("swf_hit", entry.path)
	var act := StringName(entry.action)
	var states: Dictionary = entry.get("states", {})
	if states.get("kind", "") == "button":
		# The frames the original shows (recorded by record_screen.py states).
		hit.mouse_entered.connect(func(): _state_frame(rec, states.get("hover")))
		hit.mouse_exited.connect(func(): _state_frame(rec, null))
		hit.button_down.connect(func(): _state_frame(rec, states.get("press")))
		hit.button_up.connect(func(): _state_frame(rec, states.get("hover") if hit.is_hovered() else null))
	if states.get("acts_on", "release") == "press":
		hit.button_down.connect(func(): action.emit(act))
	else:
		hit.pressed.connect(func(): action.emit(act))
	return hit


func _state_frame(rec: Dictionary, frame) -> void:
	if frame == null or int(frame) == int(rec.entry.get("states", {}).get("rest", -1)):
		rec.erase("state_frame")
	else:
		rec["state_frame"] = int(frame)
	_apply(index)


# ------------------------------------------------------------------ helpers

func _background_colour() -> Color:
	var bg = layout.stage.get("background")
	if bg is Array and bg.size() >= 3: return Color8(int(bg[0]), int(bg[1]), int(bg[2]))
	return Color.WHITE


static func _matrix(m: Array) -> Transform2D:
	return Transform2D(Vector2(m[0], m[1]), Vector2(m[2], m[3]), Vector2(m[4], m[5]))


## Layout nodes are named `swf_<segment>` so hit areas can carry the plain instance names.
static func _node_name(path: String) -> String:
	return ("swf_" + path.rsplit("/", true, 1)[-1].replace("@", "d")).validate_node_name()

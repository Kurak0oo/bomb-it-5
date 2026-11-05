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
## For screens driven by a ported controller: over / out / down / up / click on an instance.
signal mouse_event(instance: String, kind: StringName)
## Any mouse press on the stage, after the instances' own handlers (AS3 bubbling to the
## root). `press` counts presses, so a handler can ignore the press that added it.
signal stage_down(press: int)
## A key press, as the AS3 stage's KeyboardEvent sees it: the Flash keyCode.
signal key_down(keycode: int)

const STAGE := Vector2(700, 510)
const PACK := "res://original/screens/%s/manifest.json"
const FPS := 35.0
const BLEND_SHADER := preload("res://scripts/ui/swf_blend.gdshader")
const GLOW_SHADER := preload("res://scripts/ui/swf_glow.gdshader")
const OFFSET_SHADER := preload("res://scripts/ui/swf_color_add.gdshader")
const FlashKeys = preload("res://scripts/ui/flash_keys.gd")
const FONTS := "res://original/fonts/fonts.json"
## Flash's TextField draws its text 2 units inside its bounds.
const GUTTER := 2.0
## flash.display.BlendMode names (as the reference player dumps them) -> shader modes.
const BLEND_MODES := {"Multiply": 1, "Screen": 2, "Lighten": 3, "Darken": 4, "Difference": 5,
	"Add": 6, "Subtract": 7, "Overlay": 8, "HardLight": 9}

## Set by the comparison loop (tools/compare/godot_capture.gd): advance one SWF frame per
## Godot frame instead of by elapsed time, as the reference player is stepped.
static var frame_locked := false

## Art resampled to the screen scale, shared by every build of every screen (returning to a
## screen reuses it), filled from background threads (`warm`, `_request`) so the main thread
## never waits on decoding or resampling. Bounded: least recently shown dropped first.
const ART_BUDGET := 256 * 1024 * 1024
static var _resized := {}
static var _resized_order: Array[String] = []
static var _resized_bytes := 0
static var _queued := {}
## 3× sources kept for hit tests only (`_image`).
static var _sources := {}
static var _cache_lock := Mutex.new()
static var _fonts := {}
static var _warm_tasks: Array[int] = []
static var _cancel_warm := false

var screen_name: StringName
var layout: Dictionary
var by_path: Dictionary = {}
var art_loaded := 0
var open_delay := 0
var frames_since_created := 0
var index := 0
var is_open := false

var _records: Array[Dictionary] = []
var _by_path_rec: Dictionary = {}
var _extra_shown_at: Dictionary = {}
var _t := 0
var _by_name: Dictionary = {}
var _art: Array[Dictionary] = []
var _px := -1.0
var _clock := 0.0
var _timeline: Dictionary = {}
var _hits: Node2D
var press_count := 0
var _created_frame := -1
## Nodes whose wanted art is still being resampled (path -> record).
var _waiting := {}
var _warm_started := false
var _apply_queued := false


static func create(screen: StringName, delay := 0) -> Node2D:
	var node: Node2D = load("res://scripts/ui/swf_screen.gd").new()
	node.open_delay = delay
	node.build(screen)
	return node


static func layout_of(screen: StringName) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://scenes/swf/%s.json" % screen))


func build(screen: StringName) -> void:
	_created_frame = Engine.get_process_frames()
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
			"track_index": PackedInt32Array(), "track": [], "art": [], "override": -1,
			"shown": not entry.get("initially_hidden", false), "hit": null,
			"alpha_at_capture": float(entry.get("alpha", 1.0))}
		if entry.has("track"):
			for change: Array in entry.track:
				rec.track_index.append(int(change[0]))
				rec.track.append(change[1])
		node.set_meta("swf_path", entry.get("golden_path", path))
		node.set_meta("swf_kind", entry.get("kind", ""))
		node.set_meta("swf_alpha", entry.get("alpha", 1.0))
		node.set_meta("swf_baked", entry.role in ["piece", "sequence"])
		if entry.has("covers"): node.set_meta("swf_covers", entry.covers)
		for key in ["frame", "button_state", "text", "clip_depth", "clip_mask", "mask"]:
			if entry.has(key): node.set_meta("swf_" + key, entry[key])
		_records.append(rec)
		_by_path_rec[path] = rec
		_add_piece_art(rec, manifest)
		if entry.has("action") and entry.has("stage_bounds"):
			rec.hit = _hit(rec)
			_hits.add_child(rec.hit)
		# Instances are addressed by name, or by their path relative to the screen root
		# (`robotStage1/robotMc/robot3/bodyMc`, `Art_clothPanel3/icon1`), as the AS3 does
		# with `_mc["robotStage1"]["robotMc"]`.
		if entry.has("name"):
			_by_name.get_or_add(String(entry.name).split("@")[0], rec)
		var relative := _relative(path)
		if not relative.is_empty(): _by_name[relative] = rec
	add_child(_hits)
	_apply(0)
	visible = open_delay <= 0
	is_open = open_delay <= 0
	_hits.visible = is_open


## Scale the stage to fit `size` and centre it: the one scale factor of rule 5.
func fit(size: Vector2) -> void:
	var factor := minf(size.x / STAGE.x, size.y / STAGE.y)
	scale = Vector2(factor, factor)
	# Whole pixels, so pieces aligned to the stage origin's pixel grid stay sharp (_pads).
	position = ((size - STAGE * factor) * 0.5).round()
	_px = -1.0
	_refresh_art.call_deferred()


## Screen pixels per stage unit, through the window's own stretch.
func pixels_per_unit() -> float:
	if not is_inside_tree(): return scale.x
	return (get_viewport().get_final_transform() * get_global_transform_with_canvas()).get_scale().x


func node_for(path: String) -> Node2D:
	return by_path.get(path)


## `gotoAndStop(frame)` on an instance (1-based clip frame).
func set_frame(instance: String, frame: int) -> void:
	var rec: Dictionary = _by_name.get(instance, {})
	if rec.is_empty(): return
	rec.override = frame
	_queue_apply()


## `play()` on an instance stopped by `set_frame`: the clip runs on as the recording shows
## it (the original played it then too), so its recorded track takes over again.
func play(instance: String) -> void:
	var rec: Dictionary = _by_name.get(instance, {})
	if rec.is_empty(): return
	rec.override = -1
	_queue_apply()


## `addFrameScript(frame - 1, script)`: `script` runs (deferred, after the frame is drawn
## up) each time the instance, on the display list, comes to `frame` (1-based).
func add_frame_script(instance: String, frame: int, script: Callable) -> void:
	var rec: Dictionary = _by_name.get(instance, {})
	if rec.is_empty(): return
	rec.get_or_add("scripts", {})[frame] = script


## `totalFrames` of an instance.
func get_total_frames(instance: String) -> int:
	return int(_by_name.get(instance, {}).get("entry", {}).get("total_frames", 1))


## `currentFrame` of an instance.
func get_frame(instance: String) -> int:
	var rec: Dictionary = _by_name.get(instance, {})
	if rec.is_empty(): return 0
	if rec.override > 0: return rec.override
	var s = _state(rec, index)
	return int(s[7]) if s is Array and s.size() > 7 else int(rec.frame)


## `addChild` / `removeChild` of an instance on its parent, or its `visible`: shown, an
## instance the capture recorded hidden shows too (RESTART after a loss).
func set_shown(instance: String, shown: bool) -> void:
	var rec: Dictionary = _by_name.get(instance, {})
	if rec.is_empty(): return
	rec.shown = shown
	rec.made_visible = shown
	_queue_apply()


func is_shown(instance: String) -> bool:
	return bool(_by_name.get(instance, {}).get("shown", false))


## `mouseEnabled` of an instance.
func set_enabled(instance: String, enabled: bool) -> void:
	var rec: Dictionary = _by_name.get(instance, {})
	if rec.is_empty() or rec.hit == null: return
	rec.hit.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE


## Move an instance and everything inside it by `delta` stage units (`x`/`y` set by its
## controller: GameInterFace puts each robot's panel at its seat's slot). Its art and live
## text go with it.
func move_instance(instance: String, delta: Vector2) -> void:
	var rec: Dictionary = _by_name.get(instance, {})
	if rec.is_empty() or delta == Vector2.ZERO: return
	var root: String = rec.path
	for r: Dictionary in _records:
		if r.path == root or String(r.path).begins_with(root + "/"):
			r.static = Transform2D(r.static.x, r.static.y, r.static.origin + delta)
	_queue_apply()


## The stage position of an instance (its matrix's translation).
func instance_position(instance: String) -> Vector2:
	var rec: Dictionary = _by_name.get(instance, {})
	return Vector2.ZERO if rec.is_empty() else (rec.static as Transform2D).origin


## A node its controller lays out at run time under a layout group (the board's boxes and
## portals, scripts/ui/game_board.gd). `entry` is shaped like a layout node (`path`,
## `parent`, `stage_matrix`, `role`, ...); `art`, if any, is an image of the local pack
## (manifest `tiles` / `features`) rendered on another node at stage matrix `art.at`: the
## sprite undoes that matrix, so the image lands on this node wherever it is.
func add_node(entry: Dictionary, art: Dictionary = {}) -> Dictionary:
	var path: String = entry.path
	var parent: Node2D = by_path.get(entry.parent, self)
	var node := Node2D.new()
	node.name = _node_name(path)
	parent.add_child(node)
	by_path[path] = node
	var rec := {"entry": entry, "node": node, "parent": entry.parent, "path": path,
		"static": _matrix(entry.stage_matrix), "visible": bool(entry.get("effective_visible", true)),
		"frame": entry.get("frame", 0), "offset": Vector2.ZERO, "track_index": PackedInt32Array(),
		"track": [], "art": [], "override": -1, "shown": true, "hit": null, "alpha_at_capture": 1.0}
	node.set_meta("swf_path", path)
	node.set_meta("swf_kind", entry.get("kind", "movie_clip"))
	node.set_meta("swf_alpha", 1.0)
	node.set_meta("swf_baked", entry.get("role", "piece") == "piece")
	node.set_meta("swf_frame", int(entry.get("frame", 0)))
	_records.append(rec)
	_by_path_rec[path] = rec
	if not art.is_empty():
		var added := _add_art(rec, art, 0, -1)
		if not added.is_empty(): added["at"] = _matrix(art.at)
	elif entry.get("render_bounds") is Array:
		_add_outline(rec, entry.render_bounds)
	_queue_apply()
	return rec


## Take a run-time node (and its art, and the run-time nodes inside it) off the screen:
## `removeChild` of a box that broke, a robot leaving its row.
func remove_node(path: String) -> void:
	var rec: Dictionary = _by_path_rec.get(path, {})
	if rec.is_empty(): return
	for r: Dictionary in _records.duplicate():
		if r.path == path or String(r.path).begins_with(path + "/"):
			_records.erase(r)
			_by_path_rec.erase(r.path)
			by_path.erase(r.path)
			_waiting.erase(r.path)
	rec.node.queue_free()


## A run-time node's display-list path changes (`@0#k` of the boxes after a removed one);
## the run-time nodes inside it follow.
func rename_node(path: String, new_path: String) -> void:
	var rec: Dictionary = _by_path_rec.get(path, {})
	if rec.is_empty() or path == new_path: return
	for r: Dictionary in _records:
		var old: String = r.path
		if old != path and not old.begins_with(path + "/"): continue
		var renamed := new_path + old.substr(path.length())
		_by_path_rec.erase(old)
		by_path.erase(old)
		_waiting.erase(old)
		r.path = renamed
		r.entry.path = renamed
		if old != path:
			r.parent = new_path + String(r.parent).substr(path.length())
			r.entry.parent = r.parent
		_by_path_rec[renamed] = r
		by_path[renamed] = r.node
		r.node.set_meta("swf_path", renamed)


## A run-time node moves (a robot walking): its stage matrix.
func move_node(path: String, stage_matrix: Array) -> void:
	var rec: Dictionary = _by_path_rec.get(path, {})
	if rec.is_empty(): return
	rec.static = _matrix(stage_matrix)
	_queue_apply()


## A run-time node shows another image (a robot's clip at another frame): `art` as for
## `add_node` (an image of the local pack and the stage matrix it was rendered at), or none.
## `frame` is the clip frame it reports.
func set_node_art(path: String, art: Dictionary, frame := 0) -> void:
	var rec: Dictionary = _by_path_rec.get(path, {})
	if rec.is_empty(): return
	if frame > 0:
		rec.frame = frame
		rec.node.set_meta("swf_frame", frame)
	var key := "%s|%s" % [art.get("file", ""), art.get("at", "")]
	if rec.get("art_key", "") == key: return
	rec.art_key = key
	rec.art.clear()
	rec.erase("art_table")
	rec.erase("placed")
	rec.shown_art = -1
	if rec.has("sprite"): rec.sprite.visible = false
	if not art.is_empty():
		var added := _add_art(rec, art, 0, -1)
		if not added.is_empty(): added["at"] = _matrix(art.at)
	_queue_apply()


## Flash colour offsets on a run-time node's art (`InvincibilityCommand`'s +50 blink),
## added to every pixel it draws.
func set_node_offset(path: String, offset: Color) -> void:
	var rec: Dictionary = _by_path_rec.get(path, {})
	if rec.is_empty(): return
	rec.color_offset = offset
	if rec.has("sprite"): _offset_material(rec)


func _offset_material(rec: Dictionary) -> void:
	var offset: Color = rec.get("color_offset", Color(0, 0, 0, 0))
	var sprite: Sprite2D = rec.sprite
	if offset == Color(0, 0, 0, 0):
		if sprite.material is ShaderMaterial and (sprite.material as ShaderMaterial).shader == OFFSET_SHADER:
			var material := CanvasItemMaterial.new()
			material.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
			sprite.material = material
		return
	if not (sprite.material is ShaderMaterial and (sprite.material as ShaderMaterial).shader == OFFSET_SHADER):
		var shader := ShaderMaterial.new()
		shader.shader = OFFSET_SHADER
		sprite.material = shader
	(sprite.material as ShaderMaterial).set_shader_parameter("offset", Vector3(offset.r, offset.g, offset.b))


## The local pack's manifest of this screen (art the controllers lay out themselves).
func pack() -> Dictionary:
	if not has_meta("pack"): set_meta("pack", _manifest())
	return get_meta("pack")


## `TextField.text = text`: the field's recorded art gives way to live text, drawn in the
## SWF's own font (original/fonts/, exported by record_screen.py fonts) with its format.
func set_text(instance: String, text: String) -> void:
	var rec: Dictionary = _by_name.get(instance, {})
	if rec.is_empty(): return
	if text == String(rec.entry.get("text", "")):
		# The recorded text again: its art (with the field's filters) shows, not live text.
		if rec.has("label"):
			# (with the CanvasGroup that draws its filters, when it has one)
			(rec.label.get_parent() if rec.label.get_parent() is CanvasGroup else rec.label).queue_free()
			rec.erase("label")
			rec.erase("live_text")
			rec.node.set_meta("swf_text", text)
			_queue_apply()
		return
	rec["live_text"] = text
	if not rec.has("label"): rec["label"] = _make_label(rec)
	rec.label.text = text
	rec.node.set_meta("swf_text", text)
	_fit_label(rec)
	_queue_apply()


func get_text(instance: String) -> String:
	var rec: Dictionary = _by_name.get(instance, {})
	return String(rec.get("live_text", rec.get("entry", {}).get("text", "")))


func _make_label(rec: Dictionary) -> Label:
	var f: Dictionary = rec.entry.get("text_format", {})
	var label := Label.new()
	label.name = "LiveText"
	label.set_meta("swf_art", true)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font := _font(String(f.get("font", "")), bool(f.get("bold", false)))
	if font != null: label.add_theme_font_override("font", font)
	var colour: Array = f.get("color", [0, 0, 0])
	label.add_theme_color_override("font_color", Color8(int(colour[0]), int(colour[1]), int(colour[2])))
	label.horizontal_alignment = {"Left": HORIZONTAL_ALIGNMENT_LEFT, "Center": HORIZONTAL_ALIGNMENT_CENTER,
		"Right": HORIZONTAL_ALIGNMENT_RIGHT, "Justify": HORIZONTAL_ALIGNMENT_FILL}.get(String(f.get("align", "Left")), HORIZONTAL_ALIGNMENT_LEFT)
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if f.get("word_wrap", false) else TextServer.AUTOWRAP_OFF
	label.clip_text = false
	var glow := _glow_filter(rec.entry)
	if glow.is_empty():
		rec.node.add_child(label)
		return label
	# The field's GlowFilter: the text draws into a group whose shader adds the glow.
	var group := CanvasGroup.new()
	group.name = "LiveTextFilters"
	group.set_meta("swf_art", true)
	var material := ShaderMaterial.new()
	material.shader = GLOW_SHADER
	var colour_g: Array = glow.get("color", [255, 255, 255])
	material.set_shader_parameter("glow_color", Color8(int(colour_g[0]), int(colour_g[1]), int(colour_g[2]),
		roundi(float(glow.get("alpha", 1.0)) * 255.0)))
	material.set_shader_parameter("strength", float(glow.get("strength", 2.0)))
	material.set_shader_parameter("inner", bool(glow.get("inner", false)))
	material.set_shader_parameter("knockout", bool(glow.get("knockout", false)))
	material.set_shader_parameter("composite_source", bool(glow.get("composite_source", true)))
	group.material = material
	group.add_child(label)
	rec.node.add_child(group)
	return label


## The field's filters as the display dump records them (`filter_list`). Only a single
## GlowFilter is drawn for live text; any other list keeps its art and warns once.
static func _glow_filter(entry: Dictionary) -> Dictionary:
	var filters: Array = entry.get("filter_list", [])
	if filters.is_empty(): return {}
	if filters.size() > 1 or String(filters[0].get("type", "")) != "GlowFilter":
		push_warning("%s: live text draws only a single GlowFilter, not %s" % [entry.get("path", ""), filters])
		return {}
	return filters[0]


## One axis of a Flash blur in screen pixels: `quality` passes of Ruffle's box, which spans
## `size` pixels with whole taps inside and fractional end taps (render/wgpu/src/filters/
## blur.rs, BlurFilter::apply: radius = (size - 1) / 2, m = ceil(radius) - 1, end weight
## alpha = floor((radius - m) * 255) / 255, sum = size). Odd length, centred.
static func _glow_kernel(size: float, passes: int) -> PackedFloat32Array:
	var kernel := PackedFloat32Array([1.0])
	var full := minf(size, 255.0)
	if full <= 1.0: return kernel
	var radius := (full - 1.0) / 2.0
	var m := ceilf(radius) - 1.0
	var alpha := floorf((radius - m) * 255.0) / 255.0
	var box := PackedFloat32Array()
	box.append(alpha / full)
	for k in int(2.0 * m + 1.0): box.append(1.0 / full)
	box.append(alpha / full)
	for p in maxi(1, passes):
		var out := PackedFloat32Array()
		out.resize(kernel.size() + box.size() - 1)
		for i in kernel.size():
			for j in box.size(): out[i + j] += kernel[i] * box[j]
		kernel = out
	return kernel


## Font size for the real screen scale, so text stays sharp; the label is scaled back.
func _fit_label(rec: Dictionary) -> void:
	var label: Label = rec.label
	var f: Dictionary = rec.entry.get("text_format", {})
	var px := maxf(0.01, _px if _px > 0.0 else pixels_per_unit())
	var b: Array = f.get("local_bounds", [0, 0, 100, 20])
	var font_px := maxi(1, roundi(float(f.get("size", 12)) * px))
	label.add_theme_font_size_override("font_size", font_px)
	# Flash (Ruffle's edit_text.rs / html/layout.rs) puts the first baseline at the field's
	# top + GUTTER + the SWF font's ascent at the format's size (`ascent`, recorded from the
	# player's layout metrics), and each next line ascent + descent + leading lower. Godot's
	# Label puts it at its top + the shaped line's ascent from the exported TTF, whose
	# metrics are not the SWF font's: move the label by the difference.
	var line := TextLine.new()
	line.add_string(label.text if not label.text.is_empty() else " ", label.get_theme_font("font"), font_px)
	var top := 0.0
	var spacing := float(f.get("leading", 0)) * px
	if f.has("ascent"):
		top = float(f.ascent) - line.get_line_ascent() / px
		spacing = (float(f.ascent) + float(f.get("descent", 0)) + float(f.get("leading", 0))) * px \
			- line.get_line_ascent() - line.get_line_descent()
	label.add_theme_constant_override("line_spacing", roundi(spacing))
	var left := GUTTER + float(f.get("left_margin", 0))
	var right := GUTTER + float(f.get("right_margin", 0))
	label.position = Vector2(float(b[0]) + left, float(b[1]) + GUTTER + top)
	label.size = Vector2(float(b[2]) - float(b[0]) - left - right, float(b[3]) - float(b[1]) - 2 * GUTTER) * px
	label.scale = Vector2(1.0 / px, 1.0 / px)
	var group := label.get_parent() as CanvasGroup
	if group != null: _fit_glow(group, _glow_filter(rec.entry), px)


## The glow's kernels for the current screen scale. Ruffle scales a filter's blur with the
## stage matrix as (blur - 1) * scale + 1 (swf BlurFilter::scale_blur).
func _fit_glow(group: CanvasGroup, glow: Dictionary, px: float) -> void:
	var passes := int(glow.get("quality", 1))
	var kx := _glow_kernel((float(glow.get("blur_x", 0)) - 1.0) * px + 1.0, passes)
	var ky := _glow_kernel((float(glow.get("blur_y", 0)) - 1.0) * px + 1.0, passes)
	var material: ShaderMaterial = group.material
	material.set_shader_parameter("nx", mini(kx.size(), 64))
	material.set_shader_parameter("ny", mini(ky.size(), 64))
	material.set_shader_parameter("wx", kx)
	material.set_shader_parameter("wy", ky)
	# The group draws the glow around the text: its rect and cleared backbuffer reach past
	# the kernel (margins in local units or screen pixels, whichever is larger).
	var reach := float(maxi(kx.size(), ky.size()) / 2 + 2) * maxf(1.0, 1.0 / px)
	group.fit_margin = reach
	group.clear_margin = reach * 2.0


## The family's embedded subsets: the largest first, the others as fallbacks.
static func _font(family: String, bold: bool) -> Font:
	var key := family + ("|b" if bold else "")
	if _fonts.has(key): return _fonts[key]
	var font: Font = null
	if FileAccess.file_exists(FONTS):
		var families: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FONTS))
		var files: Array = families.get(family, [])
		var loaded: Array[Font] = []
		for file in files:
			var ff := FontFile.new()
			if ff.load_dynamic_font(ProjectSettings.globalize_path(FONTS.get_base_dir().path_join(file))) == OK: loaded.append(ff)
		if not loaded.is_empty():
			var primary: FontFile = loaded[0]
			primary.fallbacks = loaded.slice(1)
			font = primary
			if bold:
				var variation := FontVariation.new()
				variation.base_font = primary
				variation.variation_embolden = 0.6
				font = variation
	_fonts[key] = font
	return font


func _unhandled_key_input(event: InputEvent) -> void:
	if not is_open or not is_visible_in_tree(): return
	if event is InputEventKey and event.pressed and not event.echo:
		var code := FlashKeys.from_godot(event.physical_keycode if event.keycode == KEY_NONE else event.keycode)
		if code != 0: key_down.emit(code)


func _input(event: InputEvent) -> void:
	if not is_open or not is_visible_in_tree(): return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		press_count += 1
		_emit_stage_down.call_deferred(press_count)


func _emit_stage_down(press: int) -> void:
	stage_down.emit(press)


func _process(delta: float) -> void:
	_reap_tasks()
	_show_ready()
	# A screen made by input (a click) during this frame has not run a frame yet: in the
	# original, input lands between frames and the next frame is the screen's first.
	if _created_frame > 0 and Engine.get_process_frames() == _created_frame: return
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
		_t = t
		_apply(_timeline_index(t))


## Timeline index of one node: the screen's, or for a part from another capture its own
## loop, counted from when it was shown so that the recorded capture comes as many frames
## after showing as it did in the original.
func _local_index(rec: Dictionary, i_screen: int) -> int:
	return _capture_index(rec.entry.get("timeline_of", ""), i_screen)


## Timeline index on capture `cap`'s own loop ("" is the screen's), at screen index `i_screen`.
func _capture_index(cap: String, i_screen: int) -> int:
	if cap.is_empty(): return i_screen
	var own: Dictionary = layout.get("extra_timelines", {}).get(cap, {})
	var period: int = maxi(1, int(own.get("period", 1)))
	var since: int = _t - int(_extra_shown_at.get(cap, _t))
	if own.get("from_shown", false):
		# Recorded from the frame the part shows, through its capture, then a loop. A
		# wall-time screen's part may run some frames ahead (`shown_offset`, layout.py).
		since = maxi(0, since + int(own.get("shown_offset", 0)))
		var capture: int = int(own.capture_index)
		return since if since <= capture else capture + (since - capture) % period
	return posmod(since - int(own.get("shown_before_capture", 0)), period)


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


## The clip frame a node shows at timeline index `i` (an override from `set_frame` wins).
func _shown_frame(rec: Dictionary, i: int) -> int:
	if int(rec.override) > 0: return int(rec.override)
	var s = _state(rec, i)
	return int(s[7]) if s is Array and s.size() > 7 else int(rec.frame)


func _global_at(rec: Dictionary, i: int) -> Transform2D:
	var s = _state(rec, i)
	if s is Array and s.size() >= 6:
		return Transform2D(Vector2(s[0], s[1]), Vector2(s[2], s[3]), Vector2(s[4], s[5]) + rec.offset)
	return rec.static


## Changes made by a controller (often dozens in one handler: a clothes panel sets every
## icon) are applied once, at the end of the frame, instead of once each.
func _queue_apply() -> void:
	if _apply_queued: return
	_apply_queued = true
	_flush_apply.call_deferred()


func _flush_apply() -> void:
	if _apply_queued: _apply(index)


func _apply(i_screen: int) -> void:
	_apply_queued = false
	index = i_screen
	var globals := {}
	var shown := {}
	for rec: Dictionary in _records:
		var i := _local_index(rec, i_screen)
		var s = _state(rec, i)
		var present: bool = s == null or (s is Array and s.size() > 0)
		var g: Transform2D = _global_at(rec, i) if present else rec.static
		var vis: bool = present and rec.shown and ((rec.visible if s == null else bool(s[6])) or rec.get("made_visible", false))
		# A clip's timeline shows different children per frame (robotMc shows robot<N> on
		# frame N+1): once the parent is sent to a frame, only that frame's children show.
		var parent_rec: Dictionary = _by_path_rec.get(rec.parent, {})
		if vis and rec.entry.has("parent_frame") and not parent_rec.is_empty():
			vis = _shown_frame(parent_rec, i) == int(rec.entry.parent_frame)
		var frame: int = int(rec.frame) if s == null or not present else int(s[7])
		var parent_g: Transform2D = globals.get(rec.parent, Transform2D.IDENTITY)
		var parent_shown: bool = shown.get(rec.parent, true)
		var node: Node2D = rec.node
		node.transform = parent_g.affine_inverse() * g
		node.visible = vis or (present and rec.shown and not parent_shown)
		globals[rec.path] = g
		shown[rec.path] = vis and parent_shown
		# The first part of another capture to show starts that capture's own clock.
		var cap: String = rec.entry.get("timeline_of", "")
		if not cap.is_empty() and _by_path_rec.get(rec.parent, {}).get("entry", {}).get("timeline_of", "") != cap:
			if vis and parent_shown:
				# Shown later by input (a robot after its icon's click): as a screen made by
				# input (see _created_frame), its first frame is the next one. A part shown as
				# the screen opens (the unlock tip) starts with the screen, which already
				# skipped its creation frame.
				if not _extra_shown_at.has(cap): _extra_shown_at[cap] = _t + (1 if _t > 0 else 0)
			else:
				_extra_shown_at.erase(cap)
		if rec.hit != null: rec.hit.visible = vis and parent_shown
		if rec.override > 0: frame = rec.override
		if frame > 0: node.set_meta("swf_frame", frame)
		if rec.has("scripts"):
			var on_list: bool = vis and parent_shown
			if on_list and frame != int(rec.get("script_frame", -1)) and rec.scripts.has(frame):
				(rec.scripts[frame] as Callable).call_deferred()
			rec.script_frame = frame if on_list else -1
		# Recorded alpha (older timelines have none): the art carries the alpha it was
		# rendered with at the capture, so the node scales by the ratio.
		if s is Array and s.size() > 9:
			var alpha := float(s[9])
			node.set_meta("swf_alpha", alpha)
			var base := float(rec.alpha_at_capture)
			var ratio := alpha / base if base > 0.0 else alpha
			# A sequence's frames were rendered with its alpha at each frame.
			if rec.entry.get("role", "") == "sequence": ratio = 1.0
			# The art is premultiplied: colour scales with alpha, or a fade-in stays dark.
			node.modulate = Color(ratio, ratio, ratio, ratio)
		# Art is picked (and resampled) only for what shows: hidden robots and panels wait.
		if vis and parent_shown: _show_art(rec, i, frame)


func _show_art(rec: Dictionary, i: int, _frame: int) -> void:
	# (`_frame` is the clip frame the node shows at timeline index `i`)
	if rec.art.is_empty(): return
	if rec.has("live_text"):
		_switch_art(rec, -1)
		return
	if not rec.has("art_table"): rec.art_table = _art_table(rec.art)
	var table: Dictionary = rec.art_table
	var by_state: Dictionary = table.by_state
	var pick := -1
	var wanted: int = rec.override if rec.override > 0 else int(rec.get("state_frame", -1))
	# At its recorded frame a widget plays its recorded art (a sequence when it animates).
	if wanted == int(rec.frame) and rec.entry.role == "sequence": wanted = -1
	if wanted > 0:
		pick = by_state.get(wanted, -1)
		# A frame that animates at another capture (the selected robot's icon) plays that
		# capture's sequence on its clock while that capture's part shows (layout.py
		# `frame_sequences`): its latest art at or before that clock's index.
		var seq: Dictionary = table.of.get(wanted, {})
		if not seq.is_empty() and _extra_shown_at.has(seq.of):
			pick = _latest(seq, _capture_index(seq.of, index))
	if pick < 0 and rec.entry.role == "group":
		# A group widget's art is its frame art, for the frame it shows now.
		pick = by_state.get(_frame, -1)
	if pick < 0 and not table.plain.k.is_empty():
		# A sequence shows its latest art at or before this frame; a static piece its one image.
		pick = _latest(table.plain, i)
	if pick < 0:
		# A widget with no art at rest (hidden at its capture) shows its frame's art.
		pick = by_state.get(_frame, -1)
	_switch_art(rec, pick)


## Lookup tables over a node's art, so a frame picks its image without scanning them all:
## `plain` (sequence frames and still pieces, by timeline index), `by_state` (clip frame ->
## its art) and `of` (clip frame -> a sequence on another capture's clock).
static func _art_table(arts: Array) -> Dictionary:
	var plain := {"i": PackedInt32Array(), "k": PackedInt32Array()}
	var by_state := {}
	var of := {}
	var order := range(arts.size())
	order.sort_custom(func(a, b): return int(arts[a].index) < int(arts[b].index) or (int(arts[a].index) == int(arts[b].index) and a < b))
	for k in order:
		var art: Dictionary = arts[k]
		if not art.has("state"):
			plain.i.append(int(art.index))
			plain.k.append(k)
		elif art.has("of"):
			var seq: Dictionary = of.get_or_add(int(art.state), {"of": art.of, "i": PackedInt32Array(), "k": PackedInt32Array()})
			seq.i.append(int(art.index))
			seq.k.append(k)
	for k in arts.size():
		if arts[k].has("state") and not arts[k].has("of"): by_state[int(arts[k].state)] = k
	return {"plain": plain, "by_state": by_state, "of": of}


## The latest art of a sorted table at or before index `i` (its first when none is).
static func _latest(table: Dictionary, i: int) -> int:
	var j: int = (table.i as PackedInt32Array).bsearch(i, false) - 1
	return table.k[maxi(j, 0)]


## Show art `pick` of a node (-1: none). Its image is resampled off the main thread: until
## it is ready the node keeps the art it shows (a sequence lags a frame), then `_process`
## swaps it in. The comparison loop (frame-locked) resamples it at once instead.
func _switch_art(rec: Dictionary, pick: int) -> void:
	rec.want_art = pick
	if pick < 0:
		if rec.get("shown_art", -1) >= 0:
			rec.sprite.visible = false
			rec.sprite.texture = null
			rec.erase("placed")
		rec.shown_art = -1
		return
	# (before the screen is fitted its scale is unknown: `_refresh_art` places the art)
	if _px <= 0.0 and not frame_locked: return
	if not _ensure(rec.art[pick]):
		_waiting[rec.path] = rec
		return
	if _place(rec, pick): rec.shown_art = pick
	else: _waiting[rec.path] = rec  # (dropped from the cache meanwhile: made again)


## The node's one art sprite, made when it first shows art. It draws beneath the node's
## children (as the art was laid out before them), after the screen copy of a blend.
func _sprite(rec: Dictionary) -> Sprite2D:
	if rec.has("sprite"): return rec.sprite
	var sprite := Sprite2D.new()
	sprite.name = "Art"
	sprite.set_meta("swf_art", true)
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.visible = false
	var blend: int = BLEND_MODES.get(String(rec.entry.get("blend_mode", "Normal")), 0)
	if blend > 0:
		# A piece that blends with what lies below it (Flash blend mode), via the screen.
		# The screen is copied right before it, so it sees everything already drawn.
		var copy := BackBufferCopy.new()
		copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
		copy.set_meta("swf_art", true)
		rec.node.add_child(copy)
		rec.node.move_child(copy, 0)
		var shader := ShaderMaterial.new()
		shader.shader = BLEND_SHADER
		shader.set_shader_parameter("mode", blend)
		sprite.material = shader
	else:
		var material := CanvasItemMaterial.new()
		material.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
		sprite.material = material
	rec.node.add_child(sprite)
	rec.node.move_child(sprite, 1 if blend > 0 else 0)
	rec.sprite = sprite
	if rec.has("color_offset"): _offset_material(rec)
	return sprite


## Put art `k` (its image ready) on the node's sprite, at the screen scale.
func _place(rec: Dictionary, k: int) -> bool:
	var sprite := _sprite(rec)
	var px := _px if _px > 0.0 else pixels_per_unit()
	if sprite.texture != null and int(rec.get("placed", -1)) == k and is_equal_approx(float(rec.get("placed_px", -1.0)), px):
		sprite.visible = true
		return true
	var art: Dictionary = rec.art[k]
	var fit := _fit_of(art, px)
	var image := _cached(fit.key)
	if image == null:
		if not frame_locked: _request(art.file, fit, true)
		return false
	sprite.texture = ImageTexture.create_from_image(image)
	sprite.transform = fit.transform
	sprite.self_modulate = art.get("modulate", Color.WHITE)
	sprite.visible = true
	rec.placed = k
	rec.placed_px = px
	return true


## Nodes waiting for an image: each shows its wanted art as soon as it is ready.
func _show_ready() -> void:
	if _waiting.is_empty(): return
	for path in _waiting.keys():
		var rec: Dictionary = _waiting[path]
		var pick: int = rec.get("want_art", -1)
		if pick < 0 or rec.get("shown_art", -1) == pick or _ensure(rec.art[pick]):
			_waiting.erase(path)
			if pick >= 0 and rec.get("shown_art", -1) != pick: _switch_art(rec, pick)


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
	# Art per clip frame: recorded hover/press states, and every frame of a widget.
	for source in ["states", "frames"]:
		var by_frame = manifest.get(source, {}).get(path)
		if by_frame is Dictionary:
			for frame in by_frame: _add_art(rec, by_frame[frame], int(by_frame[frame].get("index", capture)), int(frame))
	# A widget frame that plays as a sequence on another capture's clock (`frame_sequences`):
	# each image is indexed on that capture's timeline. The widget itself is on this
	# screen's timeline, so the art undoes its transform at the capture.
	var frame_seqs = manifest.get("frame_sequences", {}).get(path)
	if frame_seqs is Dictionary:
		for frame in frame_seqs:
			var seq: Dictionary = frame_seqs[frame]
			for key in seq.frames:
				var art := _add_art(rec, seq.frames[key], int(key), int(frame))
				if art.is_empty(): continue
				art["of"] = String(seq.capture)
				art["at"] = _global_at(rec, capture)


## One rendered image of a piece. It was rendered in stage space at timeline `at`: its sprite
## undoes the node's transform at that frame, so later motion of the node carries the art.
## The image is decoded and resampled only when the art is first shown (or by `warm`).
func _add_art(rec: Dictionary, piece: Dictionary, at: int, state: int) -> Dictionary:
	var file := ProjectSettings.globalize_path((PACK % screen_name).get_base_dir().path_join(piece.file))
	if not FileAccess.file_exists(file): return {}
	var size: Array = piece.get("pixel_size", [])
	var art := {"file": file, "scale": float(piece.scale), "index": at,
		"size": Vector2(size[0], size[1]) if size.size() == 2 else Vector2.ZERO,
		"at": _global_at(rec, at),
		"origin": Vector2(piece.pixel_origin[0], piece.pixel_origin[1]) / float(piece.scale) + rec.offset,
		"pixel_origin": Vector2(piece.pixel_origin[0], piece.pixel_origin[1])}
	if state > 0: art["state"] = state
	if state <= 0 and rec.entry.has("art_index"): art["modulate"] = _undo_art_alpha(rec, at)
	rec.art.append(art)
	art_loaded += 1
	return art


## A still piece rendered away from the capture (layout.py `art_index`: its group was faded
## out there) carries its chain's alpha at that frame, while `_apply` scales each node of the
## chain by its alpha relative to the capture: the sprite undoes the difference.
func _undo_art_alpha(rec: Dictionary, at: int) -> Color:
	var fix := 1.0
	var r := rec
	var cap: String = rec.entry.get("timeline_of", "")
	while not r.is_empty() and String(r.entry.get("timeline_of", "")) == cap:
		var s = _state(r, at)
		if s is Array and s.size() > 9 and float(s[9]) > 0.0:
			var base := float(r.alpha_at_capture)
			fix *= (base if base > 0.0 else 1.0) / float(s[9])
		r = _by_path_rec.get(r.parent, {})
	return Color(fix, fix, fix, fix)


func _refresh_art() -> void:
	_px = pixels_per_unit()
	for rec: Dictionary in _records:
		if rec.has("label"): _fit_label(rec)
	for rec: Dictionary in _records:
		if int(rec.get("want_art", -1)) >= 0: _switch_art(rec, rec.want_art)
	# Resample the rest of this screen's art in the background, entrances first, so later
	# frames and other robots show without waiting.
	if not frame_locked and not _warm_started:
		_warm_started = true
		warm(screen_name, _px)


## Whether the art's image is ready at the screen scale; if not, it is resampled in the
## background (at once when frame-locked: the comparison loop needs every frame drawn).
func _ensure(art: Dictionary) -> bool:
	var px := _px if _px > 0.0 else pixels_per_unit()
	if art.size == Vector2.ZERO:
		# (no recorded pixel size: read it from the image)
		var source := _decode(art.file)
		if source == null: return false
		art.size = Vector2(source.get_width(), source.get_height())
	var fit := _fit_of(art, px)
	if _has_cached(fit.key): return true
	if frame_locked:
		_make(art.file, fit.w, fit.h, fit.pads, fit.key)
		return _has_cached(fit.key)
	_request(art.file, fit, true)
	return false


## How art shows at screen scale `px`: the resampled size, its cache key, and the sprite
## transform (stage units per texture pixel; the rounded size keeps the exact extent).
static func _fit_of(art: Dictionary, px: float) -> Dictionary:
	if art.has("fit") and is_equal_approx(float(art.fit_px), px): return art.fit
	var fit := _fit(art.file, art.pixel_origin, art.size, art.scale, px)
	var origin: Vector2 = art.origin - (fit.pads[0] as Vector2) / art.scale
	fit.transform = (art.at as Transform2D).affine_inverse() * Transform2D(0.0, fit.unit, 0.0, origin)
	art.fit = fit
	art.fit_px = px
	return fit


static func _fit(file: String, pixel_origin: Vector2, size: Vector2, scale: float, px: float) -> Dictionary:
	var pads := _pads(pixel_origin, size, scale, px)
	var padded: Vector2 = size + pads[0] + pads[1]
	var w := maxi(1, roundi(padded.x * px / scale))
	var h := maxi(1, roundi(padded.y * px / scale))
	return {"key": "%s|%d|%d|%s|%s" % [file, w, h, pads[0], pads[1]], "w": w, "h": h, "pads": pads,
		"unit": Vector2(padded.x / scale / w, padded.y / scale / h)}


## Transparent source pixels to add before ([0]) and after ([1]) a piece, per axis, so its
## resampled texels fall on the screen's pixel grid: a piece rendered at 3× starts on a
## third of a stage unit, which at 1× would sit between screen pixels and be blurred by
## the texture filter. Exact where 3×/px is whole (1×, 3×); nearest otherwise.
static func _pads(pixel_origin: Vector2, size: Vector2, scale: float, px: float) -> Array:
	var before := Vector2.ZERO
	var after := Vector2.ZERO
	var count := int(ceil(scale / maxf(px, 0.001) - 0.0001))
	for axis in 2:
		var best := INF
		for p in count:
			var at := (pixel_origin[axis] - p) * px / scale
			var off := absf(at - roundf(at))
			if off < best - 0.0001:
				best = off
				before[axis] = p
		best = INF
		for q in count:
			var extent := (size[axis] + before[axis] + q) * px / scale
			var off := absf(extent - roundf(extent))
			if off < best - 0.0001:
				best = off
				after[axis] = q
	return [before, after]


## The premultiplied 3× image of a piece file (not kept: see `_image`).
static func _decode(file: String) -> Image:
	var image := Image.load_from_file(file)
	if image == null: return null
	# Premultiplied alpha, so resampling does not bleed the black of transparent pixels
	# into edges (dark fringes on thin lines).
	image.premultiply_alpha()
	return image


## The 3× image of a piece a hit area tests, decoded once and kept (hit areas only: every
## piece at 3× would take over a gigabyte).
static func _image(file: String) -> Image:
	_cache_lock.lock()
	var image: Image = _sources.get(file)
	_cache_lock.unlock()
	if image != null: return image
	image = _decode(file)
	if image == null: return null
	_cache_lock.lock()
	_sources[file] = image
	_cache_lock.unlock()
	return image


## Resample a piece file to w×h with its pads, into the cache (any thread).
static func _make(file: String, w: int, h: int, pads: Array, key: String) -> void:
	var source := _decode(file) if not _cancel_warm else null
	if source != null:
		var image: Image
		if pads[0] != Vector2.ZERO or pads[1] != Vector2.ZERO:
			var before: Vector2 = pads[0]
			var size := Vector2i(Vector2(source.get_width(), source.get_height()) + before + (pads[1] as Vector2))
			image = Image.create_empty(size.x, size.y, false, source.get_format())
			image.blit_rect(source, Rect2i(0, 0, source.get_width(), source.get_height()), Vector2i(before))
		else:
			image = source
		if w != image.get_width() or h != image.get_height():
			image.resize(w, h, Image.INTERPOLATE_LANCZOS)
		_cache_put(key, image)
	_cache_lock.lock()
	_queued.erase(key)
	_cache_lock.unlock()


## Resampled art, shared by every build of every screen (returning to a screen reuses it),
## least recently shown dropped first beyond ART_BUDGET bytes.
static func _cache_put(key: String, image: Image) -> void:
	_cache_lock.lock()
	if not _resized.has(key):
		_resized[key] = image
		_resized_order.append(key)
		_resized_bytes += image.get_data_size()
		while _resized_bytes > ART_BUDGET and _resized_order.size() > 1:
			var old: String = _resized_order.pop_front()
			_resized_bytes -= (_resized[old] as Image).get_data_size()
			_resized.erase(old)
	_cache_lock.unlock()


static func _has_cached(key: String) -> bool:
	_cache_lock.lock()
	var has := _resized.has(key)
	_cache_lock.unlock()
	return has


static func _cached(key: String) -> Image:
	_cache_lock.lock()
	var image: Image = _resized.get(key)
	if image != null:
		_resized_order.erase(key)
		_resized_order.append(key)
	_cache_lock.unlock()
	return image


## Resample one piece in the background (once, however often it is asked for).
static func _request(file: String, fit: Dictionary, urgent: bool) -> void:
	_cache_lock.lock()
	var known: bool = _queued.has(fit.key) or _resized.has(fit.key)
	if not known: _queued[fit.key] = true
	_cache_lock.unlock()
	if known: return
	var w: int = fit.w
	var h: int = fit.h
	var pads: Array = fit.pads
	var key: String = fit.key
	_warm_tasks.append(WorkerThreadPool.add_task(func(): _make(file, w, h, pads, key), urgent))


## Resample a screen's art for screen scale `px` in a background thread, in timeline order
## (what shows first, first), up to part of the cache budget so warming never pushes out
## art in use. Called for the next screen while another shows, and by each screen for
## its own remaining art.
static func warm(screen: StringName, px: float) -> void:
	var file := PACK % screen
	if not FileAccess.file_exists(file) or px <= 0.0: return
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(file))
	var base := ProjectSettings.globalize_path(file.get_base_dir())
	var jobs := []
	for piece in manifest.get("pieces", {}).values(): jobs.append([int(piece.get("index", 0)), piece])
	for source in ["states", "frames"]:
		for by_frame in manifest.get(source, {}).values():
			for piece in by_frame.values(): jobs.append([int(piece.get("index", 0)), piece])
	for frames in manifest.get("sequences", {}).values():
		for at in frames: jobs.append([int(at), frames[at]])
	for by_frame in manifest.get("frame_sequences", {}).values():
		for seq in by_frame.values():
			for at in seq.frames: jobs.append([int(at), seq.frames[at]])
	jobs.sort_custom(func(a, b): return a[0] < b[0])
	_warm_tasks.append(WorkerThreadPool.add_task(func():
		for job in jobs:
			if _cancel_warm: return
			_cache_lock.lock()
			var full := _resized_bytes > ART_BUDGET * 3 / 4
			_cache_lock.unlock()
			if full: return
			var piece: Dictionary = job[1]
			var size: Array = piece.get("pixel_size", [])
			if size.size() != 2: continue
			var path: String = base.path_join(piece.file)
			var fit := _fit(path, Vector2(piece.pixel_origin[0], piece.pixel_origin[1]), Vector2(size[0], size[1]),
				float(piece.scale), px)
			_cache_lock.lock()
			var known: bool = _queued.has(fit.key) or _resized.has(fit.key)
			if not known: _queued[fit.key] = true
			_cache_lock.unlock()
			if not known: _make(path, fit.w, fit.h, fit.pads, fit.key), false))


## Collect finished background tasks (each must be waited for once).
static func _reap_tasks() -> void:
	var running: Array[int] = []
	for task in _warm_tasks:
		if WorkerThreadPool.is_task_completed(task): WorkerThreadPool.wait_for_task_completion(task)
		else: running.append(task)
	_warm_tasks = running


## Stop background work and wait for it before the program exits.
static func finish_warming() -> void:
	_cancel_warm = true
	for task in _warm_tasks: WorkerThreadPool.wait_for_task_completion(task)
	_warm_tasks.clear()
	_cancel_warm = false


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
		# A TextField is hit anywhere in its box (Flash tests its bounds, not its glyphs).
		if rec.entry.get("kind", "") == "text": return true
		var shown: int = rec.get("shown_art", -1)
		var art: Dictionary = rec.art[shown] if shown >= 0 else {}
		# A controller's widget is hit on its recorded frame's shape: other frames may show
		# parts that take no mouse (ClothesPanel's info panel, `mouseEnabled = false`), which
		# would cover the neighbouring icons.
		if rec.entry.has("widget_frames"):
			for candidate: Dictionary in rec.art:
				if int(candidate.get("state", -1)) == int(rec.entry.get("frame", 1)): art = candidate
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
	# (A moved node's stage_bounds are already shifted by layout.py's owner edit.)
	var area := Rect2(Vector2(bounds[0], bounds[1]), Vector2(bounds[2] - bounds[0], bounds[3] - bounds[1]))
	# Not a sequence's frames: they follow the clip's recorded motion (the unlock tip flying in).
	for art: Dictionary in rec.art:
		if entry.role == "sequence" and not art.has("state"): continue
		# A controller's widget is hit on its recorded frame's shape (see HitArea).
		if entry.has("widget_frames") and int(art.get("state", -1)) != int(entry.get("frame", 1)): continue
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
	if layout.get("controller") != null:
		# The address relative to the screen root: several panels each have an `icon1`.
		var instance := _relative(entry.path)
		hit.mouse_entered.connect(func(): mouse_event.emit(instance, &"over"))
		hit.mouse_exited.connect(func(): mouse_event.emit(instance, &"out"))
		hit.button_down.connect(func(): mouse_event.emit(instance, &"down"))
		hit.button_up.connect(func(): mouse_event.emit(instance, &"up"))
		hit.pressed.connect(func(): mouse_event.emit(instance, &"click"))
	elif states.get("acts_on", "release") == "press":
		hit.button_down.connect(func(): action.emit(act))
	else:
		hit.pressed.connect(func(): action.emit(act))
	return hit


func _state_frame(rec: Dictionary, frame) -> void:
	if frame == null or int(frame) == int(rec.entry.get("states", {}).get("rest", -1)):
		rec.erase("state_frame")
	else:
		rec["state_frame"] = int(frame)
	_queue_apply()


# ------------------------------------------------------------------ helpers

func _background_colour() -> Color:
	var bg = layout.stage.get("background")
	if bg is Array and bg.size() >= 3: return Color8(int(bg[0]), int(bg[1]), int(bg[2]))
	return Color.WHITE


static func _matrix(m: Array) -> Transform2D:
	return Transform2D(Vector2(m[0], m[1]), Vector2(m[2], m[3]), Vector2(m[4], m[5]))


func has_instance(instance: String) -> bool:
	return _by_name.has(instance)


## A path relative to the screen root, in instance names (`@depth` segments kept as is).
func _relative(path: String) -> String:
	var root: String = layout.get("screen_root", "")
	if not path.begins_with(root + "/"): return ""
	var parts := path.substr(root.length() + 1).split("/")
	for k in parts.size(): parts[k] = parts[k].split("@")[0] if not parts[k].begins_with("@") else parts[k]
	return "/".join(parts)


## Layout nodes are named `swf_<segment>` so hit areas can carry the plain instance names.
static func _node_name(path: String) -> String:
	return ("swf_" + path.rsplit("/", true, 1)[-1].replace("@", "d")).validate_node_name()

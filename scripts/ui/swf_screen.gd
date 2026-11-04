extends Node2D
## One original screen built from its generated layout (scenes/swf/<screen>.json, from
## tools/convert/layout.py). Every layout node becomes a Node2D whose global transform is
## the node's stage matrix, so the screen sits in original stage units and reaches the
## window through one scale factor set by the owner (`fit`).
##
## Art comes from the local original pack: original/screens/<screen>/manifest.json, written
## by tools/convert/render_pieces.py on the machine with the SWF (route A: each piece
## rendered by the reference player at 3× with its masks, filters and blends). Without the
## pack a piece draws its render bounds as an outline, so layout and input still work.
##
## Interactive instances get a hit area over their stage bounds and emit `action` with the
## layout's action name. The comparison loop's node dump reads the `swf_*` metas.

signal action(name: StringName)

const STAGE := Vector2(700, 510)
const PACK := "res://original/screens/%s/manifest.json"

var screen_name: StringName
var layout: Dictionary
var by_path: Dictionary = {}
var art_loaded := 0
var _art: Array[Dictionary] = []
var _art_px := -1.0


static func create(screen: StringName) -> Node2D:
	var node: Node2D = load("res://scripts/ui/swf_screen.gd").new()
	node.build(screen)
	return node


func build(screen: StringName) -> void:
	screen_name = screen
	name = "Swf_" + String(screen)
	layout = JSON.parse_string(FileAccess.get_file_as_string("res://scenes/swf/%s.json" % screen))
	var manifest := _manifest()
	var background := Node2D.new()
	background.name = "StageBackground"
	background.set_meta("swf_art", true)
	background.draw.connect(func(): background.draw_rect(Rect2(Vector2.ZERO, STAGE), _background_colour()))
	add_child(background)
	var hits := Node2D.new()
	hits.name = "Hits"
	hits.set_meta("swf_art", true)
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
		var stage := _matrix(entry.stage_matrix)
		node.transform = _global(parent).affine_inverse() * stage
		node.visible = bool(entry.effective_visible) or not _visible(parent)
		node.set_meta("swf_path", path)
		node.set_meta("swf_kind", entry.get("kind", ""))
		node.set_meta("swf_alpha", entry.get("alpha", 1.0))
		node.set_meta("swf_baked", entry.role == "piece")
		for key in ["frame", "button_state", "text", "clip_depth", "clip_mask", "mask"]:
			if entry.has(key): node.set_meta("swf_" + key, entry[key])
		if entry.role == "piece" and entry.effective_visible:
			if manifest.has(path):
				_add_art(node, stage, manifest[path])
			else:
				_add_outline(node, stage, entry.get("render_bounds", entry.get("stage_bounds", [])))
		if entry.has("action") and entry.has("stage_bounds"):
			hits.add_child(_hit(entry))
	add_child(hits)


## Scale the stage to fit `size` and centre it: the one scale factor of rule 5. Piece art
## is then resampled once, from its 3× source to the exact screen scale.
func fit(size: Vector2) -> void:
	var factor := minf(size.x / STAGE.x, size.y / STAGE.y)
	scale = Vector2(factor, factor)
	position = (size - STAGE * factor) * 0.5
	_refresh_art.call_deferred()


## Screen pixels per stage unit, through the window's own stretch.
func pixels_per_unit() -> float:
	if not is_inside_tree(): return scale.x
	return (get_viewport().get_final_transform() * get_global_transform_with_canvas()).get_scale().x


func _refresh_art() -> void:
	var px := pixels_per_unit()
	if px <= 0.0 or is_equal_approx(px, _art_px): return
	_art_px = px
	for art: Dictionary in _art:
		var source: Image = art.image
		var w := maxi(1, roundi(source.get_width() * px / art.scale))
		var h := maxi(1, roundi(source.get_height() * px / art.scale))
		var image: Image = source.duplicate()
		if w != source.get_width() or h != source.get_height():
			image.resize(w, h, Image.INTERPOLATE_LANCZOS)
		var sprite: Sprite2D = art.sprite
		sprite.texture = ImageTexture.create_from_image(image)
		# Stage units per texture pixel, per axis (the rounded size keeps the exact extent).
		var unit := Vector2(source.get_width() / art.scale / w, source.get_height() / art.scale / h)
		sprite.transform = art.stage.affine_inverse() * Transform2D(0.0, unit, 0.0, art.origin)


func node_for(path: String) -> Node2D:
	return by_path.get(path)


func _manifest() -> Dictionary:
	var file := PACK % screen_name
	if not FileAccess.file_exists(file): return {}
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(file))
	if manifest.get("golden_sha256", "") != layout.source.golden_sha256:
		push_warning("original pack for %s was rendered from another golden; re-run render_pieces" % screen_name)
	return manifest.get("pieces", {})


func _add_art(node: Node2D, stage: Transform2D, piece: Dictionary) -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path((PACK % screen_name).get_base_dir().path_join(piece.file)))
	if image == null: return
	# Premultiplied alpha, so resampling does not bleed the black of transparent pixels
	# into edges (dark fringes on thin lines).
	image.premultiply_alpha()
	var sprite := Sprite2D.new()
	sprite.name = "Art"
	sprite.set_meta("swf_art", true)
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	sprite.material = material
	node.add_child(sprite)
	# The piece was rendered in stage space: its sprite undoes the node's own transform.
	_art.append({"sprite": sprite, "image": image, "scale": float(piece.scale), "stage": stage,
		"origin": Vector2(piece.pixel_origin[0], piece.pixel_origin[1]) / float(piece.scale)})
	art_loaded += 1


func _add_outline(node: Node2D, stage: Transform2D, bounds: Array) -> void:
	if bounds.size() != 4: return
	var outline := Node2D.new()
	outline.name = "Placeholder"
	outline.set_meta("swf_art", true)
	outline.transform = stage.affine_inverse()
	var rect := Rect2(bounds[0], bounds[1], bounds[2] - bounds[0], bounds[3] - bounds[1])
	outline.draw.connect(func(): outline.draw_rect(rect, Color(1, 1, 1, 0.35), false, 1.0))
	node.add_child(outline)


func _hit(entry: Dictionary) -> Button:
	var bounds: Array = entry.stage_bounds
	var hit := Button.new()
	hit.name = String(entry.name).split("@")[0] if entry.has("name") else _node_name(entry.path)
	hit.flat = true
	hit.focus_mode = Control.FOCUS_NONE
	for style in ["normal", "hover", "pressed", "disabled", "focus"]:
		hit.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	hit.position = Vector2(bounds[0], bounds[1])
	hit.size = Vector2(bounds[2] - bounds[0], bounds[3] - bounds[1])
	hit.set_meta("swf_art", true)
	hit.set_meta("swf_hit", entry.path)
	var act := StringName(entry.action)
	hit.pressed.connect(func(): action.emit(act))
	return hit


func _background_colour() -> Color:
	var bg = layout.stage.get("background")
	if bg is Array and bg.size() >= 3: return Color8(int(bg[0]), int(bg[1]), int(bg[2]))
	return Color.WHITE


static func _matrix(m: Array) -> Transform2D:
	return Transform2D(Vector2(m[0], m[1]), Vector2(m[2], m[3]), Vector2(m[4], m[5]))


func _global(node: Node2D) -> Transform2D:
	# Stage-space transform of a layout node (the screen root itself is the stage).
	var t := Transform2D.IDENTITY
	var walk: Node = node
	while walk != self and walk is Node2D:
		t = (walk as Node2D).transform * t
		walk = walk.get_parent()
	return t


func _visible(node: Node2D) -> bool:
	var walk: Node = node
	while walk != self and walk is Node2D:
		if not (walk as Node2D).visible: return false
		walk = walk.get_parent()
	return true


## Layout nodes are named `swf_<segment>` so hit areas can carry the plain instance names.
static func _node_name(path: String) -> String:
	return ("swf_" + path.rsplit("/", true, 1)[-1].replace("@", "d")).validate_node_name()

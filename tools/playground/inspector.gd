extends Node
## Playground inspector: a checkbox and a read-only panel that show the stage node under a
## click and, while a round runs, the cell there with its board kind, pickup, bombs, fire and
## actors. The playground's overlay is 700×510 in stage units, so an overlay-local point is a
## stage point.
##
## `pick` returns the topmost visible node carrying `swf_path` whose drawn rect contains the
## point (the later-drawn node wins). Art nodes (`swf_art`) are skipped; a plain Node2D is
## measured by the art it owns, since a layout node's pixels live in its child sprite.

const BoardGeometry := preload("res://tools/playground/board_geometry.gd")
const PANEL_LINES := 12
const LINE_HEIGHT := 18

var playground: Node
var check: CheckBox
var output: TextEdit
var marker: Node2D

var _picked: Dictionary = {}
var _rect := Rect2()


func setup(playground_node: Node) -> void:
	name = "Inspector"
	playground = playground_node
	var box: VBoxContainer = playground.plugin_box
	check = CheckBox.new()
	check.text = "Inspect (click the stage)"
	check.toggled.connect(_on_toggled)
	box.add_child(check)
	output = TextEdit.new()
	output.editable = false
	output.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	output.custom_minimum_size = Vector2(0, PANEL_LINES * LINE_HEIGHT)
	output.text = ""
	box.add_child(output)
	marker = Node2D.new()
	marker.name = "InspectorMarker"
	marker.draw.connect(_draw_marker)
	playground.overlay.add_child(marker)
	playground.overlay.gui_input.connect(_on_overlay_input)
	playground.case_loaded.connect(_on_case_loaded)
	_set_enabled(false)


## The topmost visible node under `stage_point` that carries `swf_path`, or {}.
func pick(stage_point: Vector2) -> Dictionary:
	var candidates: Array[CanvasItem] = []
	_collect(playground.viewport, candidates)
	var picked := {}
	for index in range(candidates.size() - 1, -1, -1):
		var item := candidates[index]
		var rect := _rect_of(item)
		if rect.has_area() and rect.has_point(stage_point):
			picked = {"path": String(item.get_meta("swf_path")), "node": item,
				"metas": _metas_of(item), "matrix": _matrix_of(item)}
			_rect = rect
			break
	if picked.is_empty():
		_rect = Rect2()
	_picked = picked
	output.text = _describe(picked, stage_point)
	marker.queue_redraw()
	return picked


func _set_enabled(on: bool) -> void:
	playground.overlay.mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
	marker.visible = on
	marker.queue_redraw()


func _on_toggled(on: bool) -> void:
	_set_enabled(on)
	if not on:
		_rect = Rect2()
		marker.queue_redraw()


func _on_case_loaded(_case: String, _capture: String) -> void:
	_picked = {}
	_rect = Rect2()
	output.text = ""
	marker.queue_redraw()


func _on_overlay_input(event: InputEvent) -> void:
	if not check.button_pressed:
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
			pick(mouse.position)


func _collect(parent: Node, out: Array[CanvasItem]) -> void:
	for child in parent.get_children():
		if child is CanvasItem:
			var item := child as CanvasItem
			if item.has_meta("swf_path") and not item.has_meta("swf_art") and item.is_visible_in_tree():
				out.append(item)
		_collect(child, out)


func _rect_of(item: CanvasItem) -> Rect2:
	if item is Sprite2D:
		var sprite := item as Sprite2D
		if sprite.texture == null:
			return Rect2()
		return sprite.get_global_transform() * sprite.get_rect()
	if item is AnimatedSprite2D:
		var animated := item as AnimatedSprite2D
		if animated.sprite_frames == null or animated.sprite_frames.get_frame_count(animated.animation) <= 0:
			return Rect2()
		var texture := animated.sprite_frames.get_frame_texture(animated.animation, animated.frame)
		if texture == null:
			return Rect2()
		var local := Rect2(Vector2.ZERO, texture.get_size())
		if animated.centered:
			local.position -= texture.get_size() * 0.5
		local.position += animated.offset
		return animated.get_global_transform() * local
	if item is Control:
		return (item as Control).get_global_rect()
	return _owned_art_rect(item)


## The union of the art drawn by `item` itself (its descendants until a node that belongs to
## a child layout node, which is measured on its own).
func _owned_art_rect(item: CanvasItem) -> Rect2:
	var rect := Rect2()
	var found := false
	for child in item.get_children():
		if not child is CanvasItem:
			continue
		var art := child as CanvasItem
		if art.has_meta("swf_path"):
			continue
		var child_rect := _subtree_art_rect(art)
		if not child_rect.has_area():
			continue
		rect = child_rect if not found else rect.merge(child_rect)
		found = true
	return rect


func _subtree_art_rect(item: CanvasItem) -> Rect2:
	if item.has_meta("swf_art"):
		if item is Sprite2D or item is AnimatedSprite2D or item is Control:
			return _rect_of(item)
	var rect := Rect2()
	var found := false
	for child in item.get_children():
		if not child is CanvasItem:
			continue
		var art := child as CanvasItem
		if art.has_meta("swf_path"):
			continue
		var child_rect := _subtree_art_rect(art)
		if not child_rect.has_area():
			continue
		rect = child_rect if not found else rect.merge(child_rect)
		found = true
	return rect


func _metas_of(item: CanvasItem) -> Dictionary:
	var metas := {}
	for key in item.get_meta_list():
		var meta := String(key)
		if meta.begins_with("swf_") and meta != "swf_art":
			metas[meta] = _jsonable(item.get_meta(key))
	return metas


func _matrix_of(item: CanvasItem) -> Array:
	var transform := item.get_global_transform()
	return [transform.x.x, transform.x.y, transform.y.x, transform.y.y, transform.origin.x, transform.origin.y]


func _describe(picked: Dictionary, point: Vector2) -> String:
	if picked.is_empty():
		return "Nothing under (%.1f, %.1f)." % [point.x, point.y]
	var lines: Array[String] = []
	lines.append("path: " + String(picked.path))
	lines.append("matrix: " + JSON.stringify(picked.matrix))
	lines.append("metas: " + JSON.stringify(picked.metas))
	var running = playground.game()
	if running != null:
		var board := BoardGeometry.board_layout()
		var snapshot: Dictionary = running.get_snapshot()
		var cell := BoardGeometry.stage_to_cell(board, point)
		var board_cell: Dictionary = snapshot.get("board", {})
		var pickups: Dictionary = snapshot.get("pickups", {})
		lines.append("cell: (%d, %d) board: %s" % [cell.x, cell.y,
			str(board_cell.get(cell, &"floor"))])
		lines.append("pickup: " + (str(pickups[cell]) if pickups.has(cell) else "none"))
		var bombs := []
		for bomb in snapshot.get("bombs", []):
			if bomb is Dictionary and _cell_of(bomb.get("cell", Vector2i(-1, -1))) == cell:
				bombs.append(_jsonable(bomb))
		lines.append("bombs: " + JSON.stringify(bombs))
		var on_fire := Array(snapshot.get("fire", [])).any(func(value): return _cell_of(value) == cell)
		lines.append("fire: " + ("yes" if on_fire else "no"))
		var actors := {}
		for id in snapshot.get("actors", {}):
			var actor = snapshot.actors[id]
			if actor is Dictionary and _cell_of(actor.get("cell", Vector2i(-1, -1))) == cell:
				actors[str(id)] = _jsonable(actor)
		lines.append("actors: " + JSON.stringify(actors))
	return "\n".join(lines)


func _cell_of(value) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Vector2:
		return Vector2i(value)
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i(-1, -1)


func _jsonable(value):
	if value is Dictionary:
		var result := {}
		for key in value:
			result[str(key)] = _jsonable(value[key])
		return result
	if value is Array:
		var result := []
		for item in value:
			result.append(_jsonable(item))
		return result
	if value is Vector2i or value is Vector2:
		return [value.x, value.y]
	if value is StringName:
		return String(value)
	if value is Color:
		return value.to_html()
	if value is Object:
		return str(value)
	return value


func _draw_marker() -> void:
	if _rect.has_area():
		marker.draw_rect(_rect, Color(0.15, 0.9, 1.0, 0.95), false, 2.0)

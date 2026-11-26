extends Node
## Playground overlays: board grid, hit areas, fire, bombs and actors drawn over the stage.
## The playground's overlay is 700×510 in stage units, so the draw node (a child of it) can
## use the board geometry directly.

const BoardGeometry := preload("res://tools/playground/board_geometry.gd")
const GRID_COLOUR := Color(1.0, 1.0, 1.0, 0.22)
const HIT_COLOUR := Color(0.2, 1.0, 0.9, 0.9)
const FIRE_COLOUR := Color(1.0, 0.0, 0.0, 0.35)
const BOMB_COLOUR := Color(1.0, 0.6, 0.05, 0.95)
const ACTOR_COLOUR := Color(0.25, 0.85, 1.0, 0.9)
const TEXT_SIZE := 12

var playground: Node
var grid_box: CheckBox
var hit_box: CheckBox
var fire_box: CheckBox
var bombs_box: CheckBox
var actors_box: CheckBox
var draw_node: Node2D

var _font: Font
## The gameplay layout's board (read once: it does not change while the playground runs).
var _board: Dictionary = {}


func setup(playground_node: Node) -> void:
	name = "Overlays"
	playground = playground_node
	_font = ThemeDB.fallback_font
	var box: VBoxContainer = playground.plugin_box
	grid_box = _add_check(box, "Grid")
	hit_box = _add_check(box, "Hit areas")
	fire_box = _add_check(box, "Fire")
	bombs_box = _add_check(box, "Bombs")
	actors_box = _add_check(box, "Actors")
	draw_node = Node2D.new()
	draw_node.name = "StageOverlay"
	draw_node.draw.connect(_draw)
	playground.overlay.add_child(draw_node)
	playground.case_loaded.connect(_on_case_loaded)
	playground.stepped.connect(_on_stepped)
	set_process(true)


func _add_check(box: VBoxContainer, label: String) -> CheckBox:
	var check := CheckBox.new()
	check.text = label
	check.button_pressed = false
	check.toggled.connect(_on_toggled)
	box.add_child(check)
	return check


func _on_toggled(_pressed: bool) -> void:
	draw_node.queue_redraw()


func _on_case_loaded(_case: String, _capture: String) -> void:
	draw_node.queue_redraw()


func _on_stepped(_frame: int) -> void:
	draw_node.queue_redraw()


func _process(_delta: float) -> void:
	if _any_checked():
		draw_node.queue_redraw()


func _any_checked() -> bool:
	return (grid_box != null and grid_box.button_pressed) \
		or (hit_box != null and hit_box.button_pressed) \
		or (fire_box != null and fire_box.button_pressed) \
		or (bombs_box != null and bombs_box.button_pressed) \
		or (actors_box != null and actors_box.button_pressed)


func _draw() -> void:
	if _board.is_empty():
		_board = BoardGeometry.board_layout()
	var board := _board
	if board.is_empty():
		return
	if grid_box.button_pressed:
		_draw_grid(board)
	if hit_box.button_pressed:
		_draw_hit_areas()
	var running = playground.game()
	if running == null:
		return
	var snapshot: Dictionary = running.get_snapshot()
	if snapshot.is_empty():
		return
	if fire_box.button_pressed:
		_draw_fire(board, snapshot)
	if bombs_box.button_pressed:
		_draw_bombs(board, snapshot)
	if actors_box.button_pressed:
		_draw_actors(board, snapshot)


func _draw_grid(board: Dictionary) -> void:
	var size = board.get("size", [17, 15])
	var width := int(size[0])
	var height := int(size[1])
	for x in width + 1:
		draw_node.draw_line(BoardGeometry.cell_to_stage(board, Vector2i(x, 0)),
			BoardGeometry.cell_to_stage(board, Vector2i(x, height)), GRID_COLOUR, 1.0)
	for y in height + 1:
		draw_node.draw_line(BoardGeometry.cell_to_stage(board, Vector2i(0, y)),
			BoardGeometry.cell_to_stage(board, Vector2i(width, y)), GRID_COLOUR, 1.0)


func _draw_hit_areas() -> void:
	var hits: Array[Control] = []
	_collect_hits(playground.viewport, hits)
	for hit in hits:
		draw_node.draw_rect(hit.get_global_rect(), HIT_COLOUR, false, 1.5)


func _collect_hits(parent: Node, out: Array[Control]) -> void:
	for child in parent.get_children():
		if child is Control:
			var control := child as Control
			if control.has_meta("swf_hit") and control.is_visible_in_tree():
				out.append(control)
		_collect_hits(child, out)


func _draw_fire(board: Dictionary, snapshot: Dictionary) -> void:
	for value in snapshot.get("fire", []):
		var cell := _cell_of(value)
		draw_node.draw_rect(_cell_rect(board, cell), FIRE_COLOUR, true)


func _draw_bombs(board: Dictionary, snapshot: Dictionary) -> void:
	for bomb in snapshot.get("bombs", []):
		if not bomb is Dictionary:
			continue
		var cell := _cell_of(bomb.get("cell", Vector2i.ZERO))
		var rect := _cell_rect(board, cell)
		draw_node.draw_rect(rect, BOMB_COLOUR, false, 2.0)
		draw_node.draw_string(_font, rect.position + Vector2(4.0, 14.0),
			str(int(bomb.get("power", 0))), HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE, BOMB_COLOUR)


func _draw_actors(board: Dictionary, snapshot: Dictionary) -> void:
	var half := _half_cell(board)
	for id in snapshot.get("actors", {}):
		var actor = snapshot.actors[id]
		if not actor is Dictionary:
			continue
		var position := Vector2(actor.get("position", Vector2(actor.get("cell", Vector2.ZERO))))
		var centre := BoardGeometry.position_to_stage(board, position) + half
		var radius := minf(half.x, half.y)
		draw_node.draw_circle(centre, radius, Color(ACTOR_COLOUR, 0.2), true)
		draw_node.draw_arc(centre, radius, 0.0, TAU, 32, ACTOR_COLOUR, 2.0, true)
		draw_node.draw_string(_font, centre + Vector2(-radius, TEXT_SIZE * 0.35), String(id),
			HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, TEXT_SIZE, ACTOR_COLOUR)


func _cell_rect(board: Dictionary, cell: Vector2i) -> Rect2:
	var start := BoardGeometry.cell_to_stage(board, cell)
	var end := BoardGeometry.cell_to_stage(board, cell + Vector2i(1, 1))
	return Rect2(start, end - start)


func _half_cell(board: Dictionary) -> Vector2:
	var start := BoardGeometry.cell_to_stage(board, Vector2i(0, 0))
	var end := BoardGeometry.cell_to_stage(board, Vector2i(1, 1))
	return (end - start) * 0.5


func _cell_of(value) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Vector2:
		return Vector2i(value)
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i.ZERO

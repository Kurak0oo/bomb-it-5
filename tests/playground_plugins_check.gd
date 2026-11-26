extends SceneTree
## The playground's inspector and overlays plugins (tools/playground/inspector.gd,
## tools/playground/overlays.gd) over the shared board geometry: the recorded board's cell
## transform, a live round's bomb and fire cells, the draw pass with every overlay on, and a
## pick on the human's own cell.
##
## Loads the same compare case as tests/playground_check.gd through the playground's
## CaseRunner.

const PLAYGROUND := preload("res://tools/playground/playground.tscn")
const BoardGeometry := preload("res://tools/playground/board_geometry.gd")
const CASE := "gameplay-cinema-bomb"
const CHECKBOXES := ["Grid", "Hit areas", "Fire", "Bombs", "Actors"]

var failures := 0
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var playground = PLAYGROUND.instantiate()
	root.add_child(playground)
	await process_frame
	await process_frame

	playground.case_name = CASE
	playground.capture_name = "bomb"
	await playground.load_case()

	var board := BoardGeometry.board_layout()
	_expect(not board.is_empty() and board.has("container_matrix") and board.has("excursion")
		and board.has("grid") and board.has("size"), "the gameplay layout has the board fields")
	if board.is_empty():
		_finish()
		return

	var corner := BoardGeometry.cell_to_stage(board, Vector2i.ZERO)
	_expect(corner.distance_to(Vector2(163.21, 12.67)) <= 0.5,
		"cell (0, 0) is at the recorded stage corner (got %s)" % corner)
	var centre := BoardGeometry.cell_centre(board, Vector2i(5, 7))
	_expect(BoardGeometry.stage_to_cell(board, centre) == Vector2i(5, 7),
		"stage_to_cell round-trips cell_centre((5, 7)) (got %s)" % BoardGeometry.stage_to_cell(board, centre))

	var running = playground.game()
	_expect(running != null, "the bomb capture reaches a real round")
	if running == null:
		_finish()
		return
	var snapshot: Dictionary = running.get_snapshot()
	_expect(snapshot.get("bombs", []).size() >= 1, "the bomb capture's snapshot has a bomb")

	var overlays = playground.get_node_or_null("Overlays")
	_expect(overlays != null, "the overlays plugin is instanced")
	if overlays != null:
		for label in CHECKBOXES:
			var check := _checkbox(playground.plugin_box, label)
			_expect(check != null, "the overlays plugin has the %s checkbox" % label)
			if check != null:
				check.button_pressed = true
		await process_frame
		await playground.step(3)
		_expect(playground.runner != null and playground.runner.frame > 0,
			"the overlays draw for three steps with every box on")

	var inspector = playground.get_node_or_null("Inspector")
	_expect(inspector != null, "the inspector plugin is instanced")
	if inspector != null:
		var roster: Dictionary = snapshot.get("actors", {})
		_expect(not roster.is_empty(), "the snapshot has an actor for the pick")
		if not roster.is_empty():
			var human: Dictionary = roster[roster.keys()[0]]
			var cell := _cell_of(human.get("cell", Vector2i.ZERO))
			var picked: Dictionary = inspector.pick(BoardGeometry.cell_centre(board, cell))
			_expect(not picked.is_empty() and String(picked.get("path", "")) != "",
				"inspector.pick at the human's cell finds a node (got %s)" % picked.get("path", ""))

	await playground.load_case(CASE, "blast")
	var blast_running = playground.game()
	_expect(blast_running != null, "the blast capture reaches a real round")
	if blast_running != null:
		_expect(not blast_running.get_snapshot().get("fire", []).is_empty(),
			"the blast capture's snapshot has fire")

	_finish()


func _checkbox(root_node: Node, label: String) -> CheckBox:
	if root_node is CheckBox and (root_node as CheckBox).text == label:
		return root_node as CheckBox
	for child in root_node.get_children():
		var found := _checkbox(child, label)
		if found != null:
			return found
	return null


func _cell_of(value) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Vector2:
		return Vector2i(value)
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i(-1, -1)


func _expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + label)


func _finish() -> void:
	print("%s: %d playground plugin checks" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)

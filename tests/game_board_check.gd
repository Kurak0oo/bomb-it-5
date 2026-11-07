extends SceneTree
## The gameplay screen's board (checkpoint 4, slice a): the port of `MapMaster.createRow` /
## `Box.setItem` in scripts/ui/game_board.gd, fed the round the original recorded
## (scenes/swf/game.json `board`, read back by `Layouts.recorded`), must lay out the same
## boxes, frames, kinds, display order and features as the original's display list, and
## place each cell where the original placed its Sprite. (A hold cell's Sprite has no clip,
## so no frame to compare.) Likewise for every other stage set recorded on the screen
## (`board.sets`: Zoo, its crocodiles as features; Candy Factory, its machine and belt; Magic
## Library, its spellbook).

const GameBoard = preload("res://scripts/ui/game_board.gd")
const Layouts = preload("res://scripts/simulation/layouts.gd")
const SwfScreen = preload("res://scripts/ui/swf_screen.gd")
var failures := 0
var checks := 0


func _initialize() -> void:
	var layout := SwfScreen.layout_of(&"game")
	# The screen's own stage set and every other set recorded on it (`board.sets`).
	_check_set(layout, StringName(layout.board.set))
	for set_id in layout.board.get("sets", {}):
		_check_set(layout, StringName(set_id))
	_expect(GameBoard._child_path("/a", 0, 1) == "/a/@0" and GameBoard._child_path("/a", 2, 5) == "/a/@0#2",
		"an only child is `@0`, siblings `@0#k`")
	print("%s: %d game board checks" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(1 if failures else 0)


func _check_set(layout: Dictionary, set_id: StringName) -> void:
	var view := GameBoard.new(null, layout.board, set_id)
	var recorded: Dictionary = view.set_data
	var golden_path: String = recorded.get("golden", layout.source.golden)
	var board := Layouts.recorded(recorded.template, recorded.boxes)
	_expect(board.skin == set_id and board.layout == recorded.template, "the recorded %s round is a %s layout" % [set_id, recorded.template])
	var soft := 0
	for cell in board.cells:
		if board.cells[cell] == &"soft": soft += 1
	_expect(soft == recorded.boxes.filter(func(b): return b.exist).size(), "every recorded breakable box is a soft block (%d)" % soft)
	# The belt's track as the round's feature state gives it (`belt_<n>` cells sorted by n,
	# CandyFactoryMapData.setData; scripts/simulation/features/belt.gd `track`).
	var belts: Array = board.features.keys().filter(func(c): return board.features[c].kind == &"belt")
	belts.sort_custom(func(a, b): return int(board.features[a].detail) < int(board.features[b].detail))
	var snapshot := {"board": board.cells, "board_meta": {"skin": board.skin, "variants": board.variants,
		"center": board.center, "portal_ids": board.portal_ids},
		"features": [{"kind": &"belt", "track": belts}] if not belts.is_empty() else []}
	var items: Dictionary = view._items_of(snapshot)
	var want: Array = recorded.boxes.map(func(b): return [_cell(b.cell), int(b.frame) if b.shown else 0, b.shown, b.exist])
	var got: Array = items.boxes.map(func(b): return [_cell(b.cell), int(b.frame) if b.shown else 0, b.shown, b.exist])
	_expect(got == want, "createRow lays out the original's %d %s boxes in its order, frames, visibility and kinds" % [want.size(), set_id])
	var features: Array = recorded.features.map(func(f): return [_cell(f.cell), f["class"], int(f.get("row", f.cell[1]))])
	var got_features: Array = items.features.map(func(f): return [_cell(f.cell), f["class"], int(f.get("row", f.cell[1]))])
	features.sort()
	got_features.sort()
	_expect(got_features == features, "%s features (portals Art_Portal_<pair>, crocodiles Art_Crocodile, the candy machine and belt) are on their cells and layers" % set_id)
	var golden: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://" + golden_path))
	var matrices := {}
	for node: Dictionary in golden.nodes: matrices[node.path] = node.stage_matrix
	var worst := 0.0
	for box: Dictionary in recorded.boxes:
		var m: Array = view.cell_matrix(Vector2(box.cell[0], box.cell[1]))
		var g: Array = matrices[box.path]
		worst = maxf(worst, Vector2(m[4] - g[4], m[5] - g[5]).length())
	# (Flash positions in twips, and the golden keeps 4 decimals of the 32/30 scale.)
	_expect(worst < 0.05, "each %s cell's Sprite sits where the original's does (worst %.4f units)" % [set_id, worst])


func _cell(cell: Array) -> Vector2i:
	return Vector2i(int(cell[0]), int(cell[1]))


func _expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)

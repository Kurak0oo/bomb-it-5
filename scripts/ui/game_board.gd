extends RefCounted
## The map's display on the generated gameplay screen (scenes/swf/game.json, `board`):
## every box and board feature of the round, laid out as the original does, on the row
## layers the layout keeps as groups (`Game.displayReInit`).
##
## Ports, display side only (the round's own state stays in scripts/simulation/):
## - `MapMaster.createRow`: one row at a time, columns left to right, a box per wall, fixed
##   prop, centre or hold cell and per soft block, with its `_brick5` frame (`beginNum + 23`
##   for the centre and its hold cells, `beginNum - 1 + fixed choice`, `soft choice +
##   beginNum + fixedPropNum - 1`; StageSets begin_num / fixed_prop_num);
## - `Box.init` / `Box.setItem`: the box is a Sprite on its row's box layer (layer 1) at
##   `xN * GRID_WIDTH + EXCURSION_X` (`AbstractObject`), its clip shrunk and centred when it
##   breaks (`isExist`); `MapMaster.setBoxVisible(false)` leaves a hold cell's Sprite empty;
## - `Portal.setMc` / `AbstractPlatForm`: `Art_Portal_<colorId>` on the platform layer (0);
## - `Box.countBrickExp`: `_mainContainer.removeChild(_container)` once a box has broken
##   (here when the round clears the cell; the explosion clip is slice b).
## The grid (`excursion`, `grid`) and the container's matrix come from the recorded board.
## Each box's art is the pack's tile for its frame and kind (record_screen.py tiles),
## rendered on a recorded box and placed on this cell.

const StageSets = preload("res://scripts/simulation/stage_sets.gd")

var _screen: Node2D
var _board: Dictionary
## Per row: the box records in display order, each {cell, frame, shown, exist, path}.
var _rows: Array = []
var _features: Array = []


func _init(screen: Node2D, board: Dictionary) -> void:
	_screen = screen
	_board = board


## Lay out the round's map. `recorded`: the boxes and features as the layout recorded
## them (the comparison loop's round, `App.round_as_recorded`); otherwise from the round's
## own board (`snapshot.board`, `board_meta`).
func build(snapshot: Dictionary, recorded: bool) -> void:
	_rows.clear()
	for y in int(_board.size[1]): _rows.append([])
	var items := _recorded_items() if recorded else _items_of(snapshot)
	for box: Dictionary in items.boxes:
		_rows[int(box.cell[1])].append(box)
	_features = items.features
	var tiles: Dictionary = _screen.pack().get("tiles", {})
	var looks: Dictionary = _screen.pack().get("features", {})
	for y in _rows.size():
		var row: Array = _rows[y]
		for k in row.size():
			var box: Dictionary = row[k]
			box.path = _child_path(_board.layers.box[y], k, row.size())
			var art: Dictionary = tiles.get("%d|%d" % [int(box.frame), int(box.exist)], {}) if box.shown else {}
			_screen.add_node(_entry(box, _board.layers.box[y], art.is_empty() and box.shown), art)
	var by_row := {}
	for feature: Dictionary in _features:
		by_row.get_or_add(int(feature.cell[1]), []).append(feature)
	for y in by_row:
		var row: Array = by_row[y]
		for k in row.size():
			var feature: Dictionary = row[k]
			feature.path = _child_path(_board.layers.platform[y], k, row.size())
			var art: Dictionary = looks.get(String(feature["class"]), {})
			_screen.add_node(_entry(feature, _board.layers.platform[y], art.is_empty()), art)


## The round moved on: boxes whose cell no longer holds a block leave their row
## (`Box.countBrickExp`), and the boxes after them on that row move up one place.
func update(snapshot: Dictionary) -> void:
	var cells: Dictionary = snapshot.get("board", {})
	for y in _rows.size():
		var row: Array = _rows[y]
		var gone := false
		for k in range(row.size() - 1, -1, -1):
			var box: Dictionary = row[k]
			if box.exist and cells.get(Vector2i(int(box.cell[0]), int(box.cell[1])), &"floor") != &"soft":
				_screen.remove_node(box.path)
				row.remove_at(k)
				gone = true
		if not gone: continue
		for k in row.size():
			var path := _child_path(_board.layers.box[y], k, row.size())
			_screen.rename_node(row[k].path, path)
			row[k].path = path


## Where a cell lies on the stage: the board container's matrix after `x = xN * 30 +
## EXCURSION_X`, `y = yN * 30 + EXCURSION_Y` (in the container's units).
func cell_matrix(cell: Vector2) -> Array:
	var m: Array = _board.container_matrix
	var local := Vector2(float(_board.excursion[0]), float(_board.excursion[1])) + cell * float(_board.grid)
	return [m[0], m[1], m[2], m[3], m[4] + m[0] * local.x + m[2] * local.y, m[5] + m[1] * local.x + m[3] * local.y]


## The transform, in the board container, of a view that draws cell (x, y) at
## `origin + (x, y) * pitch` (the placeholder actors of scripts/game_view.gd).
func view_transform(origin: Vector2, pitch: float) -> Transform2D:
	var unit := float(_board.grid) / pitch
	var excursion := Vector2(float(_board.excursion[0]), float(_board.excursion[1]))
	return Transform2D(0.0, Vector2(unit, unit), 0.0, excursion - origin * unit)


func box_count() -> int:
	var count := 0
	for row: Array in _rows: count += row.size()
	return count


func _entry(item: Dictionary, parent: String, outline: bool) -> Dictionary:
	var entry := {"path": item.path, "parent": parent, "stage_matrix": cell_matrix(Vector2(item.cell[0], item.cell[1])),
		"role": "piece", "kind": "movie_clip", "effective_visible": true, "frame": 0}
	if outline:
		var m: Array = entry.stage_matrix
		var size := float(_board.grid) * float(m[0])
		entry.render_bounds = [m[4], m[5], m[4] + size, m[5] + size]
	return entry


## A Sprite's segment among its row layer's children: unnamed, all at depth 0, so `@0#k`
## by display order, or `@0` when it is the only one (the reference player's path rule).
static func _child_path(layer: String, k: int, count: int) -> String:
	return "%s/@0#%d" % [layer, k] if count > 1 else layer + "/@0"


func _recorded_items() -> Dictionary:
	var boxes := []
	for box: Dictionary in _board.boxes:
		boxes.append({"cell": box.cell, "frame": box.frame if box.frame != null else 0, "shown": box.shown, "exist": box.exist})
	var features := []
	for feature: Dictionary in _board.features:
		features.append({"cell": feature.cell, "class": feature["class"]})
	return {"boxes": boxes, "features": features}


## `MapMaster.createRow` over the round's board: which cells get a box and which frame.
func _items_of(snapshot: Dictionary) -> Dictionary:
	var meta: Dictionary = snapshot.get("board_meta", {})
	var entry: Dictionary = StageSets.SETS.get(StringName(meta.get("skin", &"cinema")), StageSets.SETS[&"cinema"])
	var begin: int = entry.begin_num
	var variants: Dictionary = meta.get("variants", {})
	var center = meta.get("center")
	var cells: Dictionary = snapshot.get("board", {})
	var size: Array = _board.size
	var boxes := []
	var features := []
	for y in int(size[1]):
		for x in int(size[0]):
			var cell := Vector2i(x, y)
			var kind: StringName = cells.get(cell, &"floor")
			var hold: bool = center is Vector2i and x >= center.x and x < center.x + 3 and y >= center.y and y < center.y + 3
			if hold:
				# `getMidBox == 3` (the centre) shows `beginNum + 23`; `== 2` is a hidden box.
				boxes.append({"cell": [x, y], "frame": begin + 23, "shown": cell == center, "exist": false})
			elif kind == &"solid" and variants.has(cell):
				boxes.append({"cell": [x, y], "frame": begin - 1 + int(variants[cell]), "shown": true, "exist": false})
			elif kind == &"soft":
				boxes.append({"cell": [x, y], "frame": int(variants.get(cell, 1)) + begin + int(entry.fixed_prop_num) - 1,
					"shown": true, "exist": true})
			elif kind == &"portal":
				features.append({"cell": [x, y], "class": "Art_Portal_%d" % int(meta.get("portal_ids", {}).get(cell, 1))})
	return {"boxes": boxes, "features": features}

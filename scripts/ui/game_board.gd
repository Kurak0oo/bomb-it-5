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
## - `Portal.setMc` / `AbstractPlatForm`: `Art_Portal_<colorId>` on the platform layer (0),
##   its glow a nested loop that plays from map load;
## - `Box.brickExp` / `Box.countBrickExp`: a box that breaks swaps its clip for `brickExp`
##   (`Tool.CreateBoxExpMovie`), which plays; once it reaches `totalFrames - 1` the box's
##   Sprite leaves its row (`_mainContainer.removeChild(_container)`).
## The grid (`excursion`, `grid`) and the container's matrix come from the recorded board.
## Each box's art is the pack's tile for its frame and kind (record_screen.py tiles),
## rendered on a recorded box and placed on this cell.
##
## Every row layer's children are unnamed Sprites at depth 0, so their display-list paths
## are `@0#k` by display order (`@0` for an only child, the reference player's rule): the
## board keeps each layer's children in order (`attach` / `detach`) for the moving actors
## too (scripts/ui/game_actors.gd).

const StageSets = preload("res://scripts/simulation/stage_sets.gd")

var _screen: Node2D
var _board: Dictionary
## Per row: the box records in display order, each {cell, frame, shown, exist, path}.
var _rows: Array = []
var _features: Array = []
## Layer path -> its children (dictionaries with `path`) in display order.
var _children: Dictionary = {}
## Boxes breaking: each {box, age}.
var _breaking: Array = []
var _tick := -1
## The moving actors' art (original/screens/game/actors/actors.json), shared with GameActors.
var actor_art: Dictionary = {}
var _portal_loop: Dictionary = {}


func _init(screen: Node2D, board: Dictionary) -> void:
	_screen = screen
	_board = board
	var file := ProjectSettings.globalize_path("res://original/screens/game/actors/actors.json")
	if FileAccess.file_exists(file):
		actor_art = JSON.parse_string(FileAccess.get_file_as_string(file))
		for cls in actor_art.get("played", {}):
			if not String(cls).begins_with("Art_Portal"): continue
			var by_frame := {}
			for age in actor_art.played[cls]:
				var art: Dictionary = actor_art.played[cls][age]
				var nested = art.get("frames", {}).values()
				var key: int = int(nested[0]) if nested.size() > 0 and nested[0] != null else 1
				if not by_frame.has(key): by_frame[key] = art
			_portal_loop[cls] = by_frame


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
	_tick = int(snapshot.get("tick", 0))
	var tiles: Dictionary = _screen.pack().get("tiles", {})
	var looks: Dictionary = _screen.pack().get("features", {})
	for y in _rows.size():
		for box: Dictionary in _rows[y]:
			var art: Dictionary = tiles.get("%d|%d" % [int(box.frame), int(box.exist)], {}) if box.shown else {}
			attach(_board.layers.box[y], box, cell_matrix(Vector2(box.cell[0], box.cell[1])), art, "piece", art.is_empty() and box.shown)
	for feature: Dictionary in _features:
		var art: Dictionary = looks.get(String(feature["class"]), {})
		attach(_board.layers.platform[int(feature.cell[1])], feature, cell_matrix(Vector2(feature.cell[0], feature.cell[1])), art, "piece", art.is_empty())
	_portals()


## The round moved on (one call per snapshot; animations advance once per tick): boxes
## whose cell no longer holds a block break (`Box.brickExp`) and leave their row when the
## break has played (`Box.countBrickExp`); the portals' glow plays.
func update(snapshot: Dictionary) -> void:
	var tick := int(snapshot.get("tick", _tick))
	var steps := tick - _tick
	if steps <= 0: return
	_tick = tick
	var cells: Dictionary = snapshot.get("board", {})
	for step in steps:
		# countBrickExp runs on the brick explosion handlers, each frame after the break.
		for k in range(_breaking.size() - 1, -1, -1):
			var breaking: Dictionary = _breaking[k]
			breaking.age += 1
			if not _show_brick(breaking):
				_breaking.remove_at(k)
	for y in _rows.size():
		var row: Array = _rows[y]
		for k in range(row.size() - 1, -1, -1):
			var box: Dictionary = row[k]
			if box.exist and not box.get("breaking", false) and cells.get(Vector2i(int(box.cell[0]), int(box.cell[1])), &"floor") != &"soft":
				box.breaking = true
				var breaking := {"box": box, "age": 0, "row": y}
				_screen.set_node_art(box.path, {})
				_screen.add_node(_entry(box.path + "/@0", box.path, cell_matrix(Vector2(box.cell[0], box.cell[1])), "piece"))
				if not _show_brick(breaking): continue
				_breaking.append(breaking)
	_portals()


## `brickExp` at age `age` (frames since `Box.brickExp`): made with `new`, it shows its first
## frame twice, then one frame per frame; `countBrickExp` removes the box once the clip
## reaches `totalFrames - 1` (recorded: frames 1, 1, 2 … 9, gone on the 11th frame).
func _show_brick(breaking: Dictionary) -> bool:
	var box: Dictionary = breaking.box
	var frames: Dictionary = actor_art.get("still", {}).get("brickExp", {})
	var total := frames.size() if not frames.is_empty() else 11
	var frame := maxi(1, int(breaking.age))
	if frame >= total - 1:
		detach(_board.layers.box[int(breaking.row)], box)
		_rows[int(breaking.row)].erase(box)
		return false
	_screen.set_node_art(box.path + "/@0", frames.get(str(frame), {}), frame)
	return true


## The portals' glow: `Art_Portal_<n>`'s nested loop, recorded at the capture frame
## (`loop_frame`) and one frame further per tick.
func _portals() -> void:
	for feature: Dictionary in _features:
		var loop: Dictionary = _portal_loop.get(String(feature["class"]), {})
		if loop.is_empty() or feature.get("loop_frame") == null: continue
		var frame := posmod(int(feature.loop_frame) - 1 + _tick, loop.size()) + 1
		var art: Dictionary = loop.get(frame, {})
		if not art.is_empty(): _screen.set_node_art(feature.path, art)


## Add `item` as the last child of `layer` (`addChild`): its path is `@0#k` among the layer's
## children (renaming an only child `@0` to `@0#0`). `item.path` is set.
func attach(layer: String, item: Dictionary, stage_matrix: Array, art: Dictionary = {}, role := "group", outline := false) -> void:
	var list: Array = _children.get_or_add(layer, [])
	list.append(item)
	if list.size() == 2: _repath(layer)
	item.path = _child_path(layer, list.size() - 1, list.size())
	var entry := _entry(item.path, layer, stage_matrix, role)
	if outline:
		var size := float(_board.grid) * float(stage_matrix[0])
		entry.render_bounds = [stage_matrix[4], stage_matrix[5], stage_matrix[4] + size, stage_matrix[5] + size]
	_screen.add_node(entry, art)


## `removeChild`: the children after it move up one place.
func detach(layer: String, item: Dictionary) -> void:
	var list: Array = _children.get(layer, [])
	var k := list.find(item)
	if k < 0: return
	_screen.remove_node(item.path)
	list.remove_at(k)
	_repath(layer)


func _repath(layer: String) -> void:
	var list: Array = _children.get(layer, [])
	for k in list.size():
		var path := _child_path(layer, k, list.size())
		if list[k].path != path:
			_screen.rename_node(list[k].path, path)
			list[k].path = path


## Where a point given in cells lies on the stage: the board container's matrix after
## `x = xPos + EXCURSION_X`, `y = yPos + EXCURSION_Y`, xPos = cell * 30 (in the container's units).
func cell_matrix(cell: Vector2) -> Array:
	var m: Array = _board.container_matrix
	var local := Vector2(float(_board.excursion[0]), float(_board.excursion[1])) + cell * float(_board.grid)
	return [m[0], m[1], m[2], m[3], m[4] + m[0] * local.x + m[2] * local.y, m[5] + m[1] * local.x + m[3] * local.y]


## The row layer `layer` (`Game.getDisArr(y).getChildAt(layer)`: 0 platforms, 1 boxes,
## 2 bombs, 3 AI robots, 4 the player's robot) of row y.
func layer_of(y: int, layer: int) -> String:
	var row: String = _board.rows[clampi(y, 0, _board.rows.size() - 1)]
	return "%s/@0#%d" % [row, layer]


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


func _entry(path: String, parent: String, stage_matrix: Array, role: String) -> Dictionary:
	return {"path": path, "parent": parent, "stage_matrix": stage_matrix,
		"role": role, "kind": "movie_clip", "effective_visible": true, "frame": 0}


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
		features.append({"cell": feature.cell, "class": feature["class"], "loop_frame": feature.get("loop_frame")})
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
	# (A rolled round's portals start their glow where the recorded one's was at its first frame.)
	var loop_frame = _board.features[0].get("loop_frame") if not _board.features.is_empty() else null
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
				features.append({"cell": [x, y], "class": "Art_Portal_%d" % int(meta.get("portal_ids", {}).get(cell, 1)),
					"loop_frame": loop_frame})
	return {"boxes": boxes, "features": features}

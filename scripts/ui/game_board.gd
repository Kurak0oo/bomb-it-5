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
## - `ConveyorBelt.initDis` / `initBeltView` (Candy Factory): `Art_CandyMachine` at 30/32 in a
##   container left at the board's origin, on the centre row's platform layer, and
##   `Art_ConveyorBelt_1` at 30/32 on row 0's platform layer at the track's first cell; each
##   plays its own nested loops from map load (the machine's sweets, the belt's segments);
## - `Spellbook.initDis` / `runEngine` / `signItemPosition` (Magic Library): `Art_Spellbook` at
##   30/32 in a container left at the board's origin, on the centre row's platform layer, and
##   its flip and warning signs from the round's spellbook state (`_spellbooks`);
## - `ToyHand.setMc` / `runEngine` (Birthday Party): `Art_ToyHand_<Direction>` at 30/32 in its
##   container on its cell's platform layer, stopped at 1; from its first opening on at the
##   label `g<pushStep>` (frames 2-5) with its `hand` clip one frame per tick (`_toy_hands`);
## - `Box.brickExp` / `Box.countBrickExp`: a box that breaks swaps its clip for `brickExp`
##   (`Tool.CreateBoxExpMovie`), which plays; once it reaches `totalFrames - 1` the box's
##   Sprite leaves its row (`_mainContainer.removeChild(_container)`).
## The grid (`excursion`, `grid`) and the container's matrix come from the recorded board.
## Each box's art is the pack's tile for its frame and kind (record_screen.py tiles),
## rendered on a recorded box and placed on this cell.
##
## Stage sets: the layout's `board` is the screen's own set (`board.set`, Cinema) and
## `board.sets.<set>` another set's round on the same board geometry (its boxes, features,
## robots, floor). A set's art is the screen's pack for its own set, and
## `original/screens/game/sets/<set>/manifest.json` (record_screen.py sets) for another: the
## floor (`AbstractMapSet.init`'s BackGround_<Set> bitmap, on the container's first child),
## its tiles and features, and its features' own frames (`Crocodile`). A set whose art is
## not in the pack has none here (`has_art`): the placeholder layer draws it.
##
## Every row layer's children are unnamed Sprites at depth 0, so their display-list paths
## are `@0#k` by display order (`@0` for an only child, the reference player's rule): the
## board keeps each layer's children in order (`attach` / `detach`) for the moving actors
## too (scripts/ui/game_actors.gd).

const StageSets = preload("res://scripts/simulation/stage_sets.gd")
const SET_PACK := "res://original/screens/game/sets/%s/manifest.json"
## Sets whose `<Set>MapData.setData` calls `mapMaster.setMidBox(x, y)` on `centerProp` without
## `true`, so the centre is a hidden box (`getMidBox == 2`, `MapMaster.createRow`):
## CandyFactoryMapData.as:109 (the candy machine stands there), MagicLibraryMapData.as:106.
const HIDDEN_CENTRE: Array[StringName] = [&"candy_factory", &"magic_library"]
## Features a set's pack plays by their nested loops' frame (record_screen.py sets `played`).
const PLAYED_FEATURES := ["Art_Portal", "Art_Crocodile", "Art_ConveyorBelt_", "Art_CandyMachine", "Art_Spellbook"]
## `Spellbook`: FLIP_DELAY (closed ticks before a flip); `signItemPosition`'s sign classes and
## their scale (`_loc6_.scaleX = _loc6_.scaleY = 30 / 32`).
const FLIP_DELAY := 450
const SIGN_BOMB := "Art_Sign_Red"
const SIGN_OTHER := "Art_Sign_Blue"
const SIGN_SCALE := 30.0 / 32.0

var _screen: Node2D
var _board: Dictionary
## The stage set shown (StageSets id), its board fields (`board` with `board.sets.<set>` over
## it) and its art (tiles, features, floor `pieces`, features' `played` and `frames`).
var set_id: StringName
var set_data: Dictionary
var _art: Dictionary
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
## A box whose tile is not in the pack shows an outline (off where the placeholder layer draws
## the board: a stage set other than Cinema).
var outline_missing := true
## Rows made so far (`show_row`).
var _built: Array = []
## The spellbook's warning signs on the board: each {cell, class, linear, path}.
var _signs: Array = []
## The toy hands' open frames were sent to be resampled (`_toy_hands`).
var _hands_prefetched := false


func _init(screen: Node2D, board: Dictionary, stage_set: StringName = &"") -> void:
	_screen = screen
	_board = board
	set_id = stage_set if stage_set != &"" else StringName(board.get("set", "cinema"))
	set_data = board.duplicate()
	set_data.erase("sets")
	set_data.merge(board.get("sets", {}).get(String(set_id), {}), true)
	_art = art_of(screen, board, set_id)
	var file := ProjectSettings.globalize_path("res://original/screens/game/actors/actors.json")
	if FileAccess.file_exists(file):
		actor_art = JSON.parse_string(FileAccess.get_file_as_string(file))
	# Each feature's own loop by its nested clip's frame: the portals' glow (actors pass),
	# another set's features (its pack's `played`: the crocodile's water).
	for played: Dictionary in [actor_art.get("played", {}), _art.get("played", {})]:
		for cls in played:
			if not PLAYED_FEATURES.any(func(prefix): return String(cls).begins_with(prefix)): continue
			var by_frame := {}
			for age in played[cls]:
				var art: Dictionary = played[cls][age]
				var nested := []
				for k in art.get("frames", {}):
					if k != "/" and art.frames[k] != null: nested.append(art.frames[k])
				var key: int = int(nested[0]) if nested.size() > 0 else 1
				if not by_frame.has(key): by_frame[key] = art
			_portal_loop[cls] = by_frame


## The art of stage set `stage_set` on the gameplay screen: the screen's own pack for its own
## set, else that set's pack (record_screen.py sets); empty when the pack has none.
static func art_of(screen: Node2D, board: Dictionary, stage_set: StringName) -> Dictionary:
	if String(stage_set) == String(board.get("set", "cinema")):
		var own: Dictionary = screen.pack() if screen != null else {}
		return own if own.has("tiles") else {}
	if not board.get("sets", {}).has(String(stage_set)): return {}
	var file := SET_PACK % stage_set
	if not FileAccess.file_exists(file): return {}
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(file))
	if manifest.get("golden_sha256", "") != board.sets[String(stage_set)].golden_sha256:
		push_warning("original pack for the %s board was rendered from another golden; run record_screen.py sets" % stage_set)
	return manifest


## Whether this set's board art is in the pack (otherwise the placeholder layer draws it).
func has_art() -> bool:
	return not _art.is_empty()


## A clip a feature makes stopped at run time and steps itself (record_screen.py sets
## `stopped`: `Art_Prop_Disappear`): `total` frames and the art of each (`frames`); empty when
## the set's pack has none.
func stopped_art(cls: String) -> Dictionary:
	return _art.get("stopped", {}).get(cls, {})


## Lay out the round's map. `recorded`: the boxes and features as the layout recorded
## them (the comparison loop's round, `App.round_as_recorded`); otherwise from the round's
## own board (`snapshot.board`, `board_meta`).
func build(snapshot: Dictionary, recorded: bool, all_rows := true) -> void:
	_rows.clear()
	for y in int(_board.size[1]): _rows.append([])
	var items := _recorded_items() if recorded else _items_of(snapshot)
	for box: Dictionary in items.boxes:
		_rows[int(box.cell[1])].append(box)
	_features = items.features
	_hands_prefetched = false
	_tick = int(snapshot.get("tick", 0))
	_built.clear()
	# `AbstractMapSet.init`: the set's BackGround_<Set> bitmap beneath the grid (the screen's
	# floor pieces show another set's art).
	if String(set_id) != String(_board.get("set", "cinema")):
		var floor: Dictionary = _art.get("pieces", {})
		for path in floor: _screen.set_node_art(path, floor[path])
	# The platforms (portals, crocodiles, the candy machine and belt) are made with the map
	# (`AbstractMapSet.create`, `CandyFactoryMapData.setData`), before any row.
	var looks: Dictionary = _art.get("features", {})
	for feature: Dictionary in _features:
		var art: Dictionary = looks.get(String(feature["class"]), {})
		# Its layer: its own row's, or another's (the belt: `game.getDisArr(0)`).
		var layer: String = _board.layers.platform[int(feature.get("row", feature.cell[1]))]
		var at := feature_matrix(feature)
		if feature.has("node"):
			# The clip inside a container that stays at `origin` (`ConveyorBelt.initDis`: the
			# container at xPos 0, the machine at `_xN * GRID_WIDTH`).
			var origin: Array = feature.origin
			attach(layer, feature, cell_matrix(Vector2(origin[0], origin[1])))
			var entry := _entry(art_path(feature), feature.path, at, "piece")
			entry.frame = int(feature.get("frame", 0))
			_screen.add_node(entry, art)
		else:
			attach(layer, feature, at, art, "piece", art.is_empty(), int(feature.get("frame", 0)))
	if all_rows:
		for y in _rows.size(): show_row(y)
	_portals()


func has_row(y: int) -> bool:
	return y in _built


## `MapMaster.createRow(y)`: row y's boxes, left to right, go on the row's box layer. The
## map-loading screen calls it on the recorded Timer ticks (scripts/ui/loading_map_ui.gd);
## `build` makes every row at once otherwise.
func show_row(y: int) -> void:
	if y in _built or y < 0 or y >= _rows.size(): return
	_built.append(y)
	var tiles: Dictionary = _art.get("tiles", {})
	for box: Dictionary in _rows[y]:
		var art: Dictionary = tiles.get("%d|%d" % [int(box.frame), int(box.exist)], {}) if box.shown else {}
		attach(_board.layers.box[y], box, cell_matrix(Vector2(box.cell[0], box.cell[1])), art, "piece", art.is_empty() and box.shown and outline_missing)
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
			if box.has("path") and box.exist and not box.get("breaking", false) and cells.get(Vector2i(int(box.cell[0]), int(box.cell[1])), &"floor") != &"soft":
				box.breaking = true
				var breaking := {"box": box, "age": 0, "row": y}
				_screen.set_node_art(box.path, {})
				_screen.add_node(_entry(box.path + "/@0", box.path, cell_matrix(Vector2(box.cell[0], box.cell[1])), "piece"))
				if not _show_brick(breaking): continue
				_breaking.append(breaking)
	_portals()
	_crocodiles(snapshot)
	_spellbooks(snapshot)
	_toy_hands(snapshot)


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
## (`loop_frame`) and one frame further per tick. Likewise a box whose `_brick5` frame runs
## loops of its own (the centre's marquee lights and screen, `loop_frames`).
func _portals() -> void:
	for row: Array in _rows:
		for box: Dictionary in row:
			if not box.has("path") or box.get("loop_frames", []).is_empty() or box.get("breaking", false): continue
			var loop: Dictionary = actor_art.get("loops", {}).get(str(int(box.frame)), {})
			if loop.is_empty(): continue
			var key := PackedStringArray()
			for k in box.loop_frames.size():
				key.append(str(posmod(int(box.loop_frames[k]) - 1 + _tick, int(loop.periods[k])) + 1))
			var art: Dictionary = loop.frames.get("|".join(key), {})
			if not art.is_empty(): _screen.set_node_art(box.path, art)
	for feature: Dictionary in _features:
		var loop: Dictionary = _portal_loop.get(String(feature["class"]), {})
		if not feature.has("path") or loop.is_empty() or feature.get("loop_frame") == null: continue
		if feature.get("own_clock", false): continue  # a crocodile past its first opening (_crocodiles)
		var frame := posmod(int(feature.loop_frame) - 1 + _tick, loop.size()) + 1
		var art: Dictionary = loop.get(frame, {})
		if not art.is_empty(): _screen.set_node_art(art_path(feature), art)


## `Crocodile.runEngine`, display side. Closed, the clip stays on frame 1 (`_mc.gotoAndStop(1)`),
## whose water loop plays on its own (`_portals`, from `loop_frame` at the round's first frame);
## at the 240th closed tick `gotoAndStop(2)` with `mouthOpen_mc.gotoAndStop(1)`, then one mouth
## frame per tick (`ACTION_OPEN`) until the label `openComplete` (frame 25), held while it eats
## (`OPEN_CLOSE`, 60 ticks), one frame per tick again (`ACTION_CLOSE`) to its last (46), then
## frame 1. The simulation's crocodile `frame` (scripts/simulation/features/crocodile.gd) counts
## those ticks: 240 -> mouth 1, 264 -> 25, 265-324 -> 25, 325 -> 26, 345 -> 46. Frame 2's own
## clips (its water `@3`, made when the clip enters frame 2, and `mouthOpen_mc`) are drawn as
## nodes of their own over its body (record_screen.py sets `frames`); frame 1 made again on
## the way back starts its water loop over (`own_clock`).
func _crocodiles(snapshot: Dictionary) -> void:
	var frames: Dictionary = _art.get("frames", {}).get("Art_Crocodile", {}).get("2", {})
	var closed: Dictionary = _portal_loop.get("Art_Crocodile", {})
	var by_cell := {}
	for state: Dictionary in snapshot.get("features", []):
		if state.get("kind") == &"crocodile": by_cell[Vector2i(state.cell)] = int(state.frame)
	for feature: Dictionary in _features:
		if feature["class"] != "Art_Crocodile" or not feature.has("path"): continue
		var cell := Vector2i(int(feature.cell[0]), int(feature.cell[1]))
		if not by_cell.has(cell): continue
		var f: int = by_cell[cell]
		var mouth := 0
		if f >= 240 and f <= 264: mouth = f - 239
		elif f > 264 and f <= 324: mouth = 25
		elif f > 324: mouth = f - 299
		if mouth > 0 and not frames.is_empty():
			feature.own_clock = true
			# (The clip's frame is reported on the clip, which the container's art bakes in.)
			_screen.set_node_art(feature.path, frames.body)
			var water := posmod(f - 240, int(frames.parts["/@3"].size())) + 1
			var shown := {"/@3": water, "/mouthOpen_mc": mini(mouth, int(frames.parts["/mouthOpen_mc"].size()))}
			for part: String in frames.order:
				var path: String = feature.path + "/@0" + part
				if not feature.get("parts", {}).has(part):
					feature.get_or_add("parts", {})[part] = path
					_screen.add_node(_entry(path, feature.path, cell_matrix(Vector2(cell)), "piece"))
				_screen.set_node_art(path, frames.parts[part].get(str(shown.get(part, 1)), {}), int(shown.get(part, 1)))
		elif feature.get("own_clock", false):
			for part in feature.get("parts", {}):
				_screen.remove_node(feature.parts[part])
			feature.erase("parts")
			var art: Dictionary = closed.get(posmod(f - 1, closed.size()) + 1, {}) if not closed.is_empty() else {}
			if not art.is_empty(): _screen.set_node_art(feature.path, art)


## `Spellbook.runEngine`, display side. Closed, the clip stays on frame 1 (`_mc.gotoAndStop(1)`),
## whose nested loop (`/@42`, 50 frames) plays on its own from map load (`_portals`); after
## FLIP_DELAY closed ticks it steps one frame per tick (`gotoAndStop(_mc.currentFrame + 1)`)
## to its last (69), then back to 1. Observed in the reference player: the loop carries on
## through frames 2-9 (rendered apart, record_screen.py sets `frames`) and is gone from 10;
## frame 1 made again starts it over (`own_clock`). The simulation's spellbook gives the
## clip's frame while flipping and the ticks since it closed (scripts/simulation/features/spellbook.gd).
## `signItemPosition` (frame 2) puts a sign per target on the target row's platform layer
## (`game.getDisArr(y).getChildAt(0).addChild`), at 30/32 on the cell: `Art_Sign_Red` for a bomb,
## `Art_Sign_Blue` otherwise. Each plays from its frame 1 (shown twice, as made during the
## frame) and stops on its last; `deleSign` takes them off on frame 69.
func _spellbooks(snapshot: Dictionary) -> void:
	var frames: Dictionary = _art.get("frames", {}).get("Art_Spellbook", {})
	var closed_loop: Dictionary = _portal_loop.get("Art_Spellbook", {})
	for state: Dictionary in snapshot.get("features", []):
		if state.get("kind") != &"spellbook": continue
		var flipping: bool = state.get("flipping", false)
		var flip: int = int(state.get("frame", 0))
		var closed: int = int(state.get("closed", 0))
		var last := frames.size() + 1
		# On the flip's last tick the clip is still on its last frame (`deleSign`, then CLOSE).
		var frame := flip if flipping else (last if closed == 0 and flip == last else 1)
		if has_art(): _spellbook_signs(state.get("signs", []) if flipping else [], flip)
		for feature: Dictionary in _features:
			if feature["class"] != "Art_Spellbook" or not feature.has("path") or frames.is_empty(): continue
			if Vector2i(int(feature.cell[0]), int(feature.cell[1])) != Vector2i(state.cell): continue
			var path := art_path(feature)
			# The nested loop's frame: from map load (`_portals`) until the first flip ends, then
			# from the clip's return to frame 1, carried on through the flip.
			var count := closed if not flipping else FLIP_DELAY + flip - 1
			var size := maxi(1, closed_loop.size())
			var phase := posmod(count - 1, size) + 1 if feature.get("own_clock", false) \
				else posmod(int(feature.get("loop_frame", 1)) - 1 + _tick, size) + 1
			var shown: Dictionary = frames.get(str(frame), {})
			for part: String in feature.get("parts", []):
				if not shown.get("parts", {}).has(part): _screen.remove_node(path + part)
			feature.parts = (shown.get("order", []) as Array).duplicate()
			if frame == 1:
				if feature.get("own_clock", false) and closed_loop.has(phase):
					_screen.set_node_art(path, closed_loop[phase], 1)
				continue
			if frame == last and not flipping: feature.own_clock = true
			_screen.set_node_art(path, shown.get("body", {}), frame)
			for part: String in feature.parts:
				if not _screen.by_path.has(path + part):
					_screen.add_node(_entry(path + part, path, feature_matrix(feature), "piece"))
				_screen.set_node_art(path + part, shown.parts[part].get(str(phase), {}), phase)


## The spellbook's signs (`signItemPosition` / `deleSign`) at flip frame `flip`.
func _spellbook_signs(wanted: Array, flip: int) -> void:
	for k in range(_signs.size() - 1, -1, -1):
		var sign: Dictionary = _signs[k]
		if wanted.any(func(w): return Vector2i(w.cell) == Vector2i(int(sign.cell[0]), int(sign.cell[1]))): continue
		detach(_board.layers.platform[int(sign.cell[1])], sign)
		_signs.remove_at(k)
	for target: Dictionary in wanted:
		var cell := Vector2i(target.cell)
		var sign: Dictionary = {}
		for s: Dictionary in _signs:
			if Vector2i(int(s.cell[0]), int(s.cell[1])) == cell: sign = s
		if sign.is_empty():
			sign = {"cell": [cell.x, cell.y], "class": SIGN_BOMB if target.get("kind") == &"bomb" else SIGN_OTHER,
				"linear": [SIGN_SCALE, 0.0, 0.0, SIGN_SCALE]}
			attach(_board.layers.platform[cell.y], sign, feature_matrix(sign), {}, "piece")
			_signs.append(sign)
		# Made on the book's frame 2, it plays from there: the pack's images by age since
		# its making (record_screen.py sets, RUNTIME_CLASSES), held on the last.
		var ages: Dictionary = _art.get("played", {}).get(sign["class"], {})
		if ages.is_empty(): continue
		var age := clampi(flip - 2, 0, ages.size() - 1)
		var art: Dictionary = ages.get(str(age), {})
		_screen.set_node_art(sign.path, art, int(art.get("frame", 1)))


## `ToyHand.runEngine`, display side. Closed until its first opening, the clip stays on frame 1
## (`setMc`: `_mc.gotoAndStop(1)`). On opening, `_mc.gotoAndStop("g" + this._pushStep)` (labels
## g0-g3 on frames 2-5) and `_handMc.gotoAndStop(1)`, then one hand frame per tick to its last
## (14), where `_handMc.stop()` leaves it: the clip is never sent back to frame 1. The
## simulation's toy hand (scripts/simulation/features/toy_hand.gd) gives the hand clip's frame
## (`frame`, 0 before the first opening) and the label's step (`push_step`). The label's body
## and its `hand` clip are drawn apart (record_screen.py sets `frames`), the hand as the clip's
## child node over the body.
func _toy_hands(snapshot: Dictionary) -> void:
	# Each label's body and hand frames are resampled ahead (one image a tick once open).
	if not _hands_prefetched:
		_hands_prefetched = true
		for feature: Dictionary in _features:
			if not String(feature["class"]).begins_with("Art_ToyHand_"): continue
			var labels: Dictionary = _art.get("frames", {}).get(String(feature["class"]), {})
			for label in labels:
				_screen.prefetch(labels[label].body)
				for art in labels[label].get("parts", {}).get("/hand", {}).values(): _screen.prefetch(art)
	var by_cell := {}
	for state: Dictionary in snapshot.get("features", []):
		if state.get("kind") == &"toy_hand": by_cell[Vector2i(state.cell)] = state
	for feature: Dictionary in _features:
		if not String(feature["class"]).begins_with("Art_ToyHand_") or not feature.has("path"): continue
		var state: Dictionary = by_cell.get(Vector2i(int(feature.cell[0]), int(feature.cell[1])), {})
		var hand := int(state.get("frame", 0))
		if hand <= 0: continue
		var label := int(state.get("push_step", 0)) + 2
		var frames: Dictionary = _art.get("frames", {}).get(String(feature["class"]), {}).get(str(label), {})
		if frames.is_empty(): continue
		var shown := [label, hand]
		if feature.get("shown", []) == shown: continue
		feature.shown = shown
		var clip := art_path(feature)
		_screen.set_node_art(clip, frames.body, label)
		var path := clip + "/hand"
		if not feature.get("hand_added", false):
			feature.hand_added = true
			_screen.add_node(_entry(path, clip, feature_matrix(feature), "piece"))
		var parts: Dictionary = frames.get("parts", {}).get("/hand", {})
		_screen.set_node_art(path, parts.get(str(mini(hand, parts.size())), {}), hand)


## Add `item` as the last child of `layer` (`addChild`): its path is `@0#k` among the layer's
## children (renaming an only child `@0` to `@0#0`). `item.path` is set.
func attach(layer: String, item: Dictionary, stage_matrix: Array, art: Dictionary = {}, role := "group", outline := false, frame := 0) -> void:
	var list: Array = _children.get_or_add(layer, [])
	list.append(item)
	item.path = _child_path(layer, list.size() - 1, list.size())
	if list.size() == 2: _repath(layer)
	var entry := _entry(item.path, layer, stage_matrix, role)
	entry.frame = frame
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


## The node that draws a feature's clip: its layer child, or the clip under it (`node`) when
## the child is a container left elsewhere. (Read from `path` each time: a sibling added to
## the layer renames the child, `_repath`.)
static func art_path(feature: Dictionary) -> String:
	return String(feature.path) + String(feature.get("node", ""))


## Where a feature's clip lies on the stage: its cell's matrix, scaled as the AS3 scales the
## clip (`linear`, in the container's units: the belt and machine at 30/32).
func feature_matrix(feature: Dictionary) -> Array:
	var m := cell_matrix(Vector2(feature.cell[0], feature.cell[1]))
	var l: Array = feature.get("linear", [1.0, 0.0, 0.0, 1.0])
	return [m[0] * l[0] + m[2] * l[1], m[1] * l[0] + m[3] * l[1], m[0] * l[2] + m[2] * l[3], m[1] * l[2] + m[3] * l[3], m[4], m[5]]


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


## The row Sprite of row y (`Game.getDisArr(y)`): its five layers are its first children,
## so a pickup added to the row itself (`AbstractItem.init`) is its child 5 on.
func row_of(y: int) -> String:
	var row: String = _board.rows[clampi(y, 0, _board.rows.size() - 1)]
	if not _children.has(row):
		var layers := []
		for k in _board.layers.size(): layers.append({"path": "%s/@0#%d" % [row, k]})
		_children[row] = layers
	return row


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
	for box: Dictionary in set_data.boxes:
		boxes.append({"cell": box.cell, "frame": box.frame if box.frame != null else 0, "shown": box.shown, "exist": box.exist,
			"loop_frames": box.get("loop_frames", [])})
	var features := []
	for feature: Dictionary in set_data.features:
		var item := {"cell": feature.cell, "class": feature["class"], "loop_frame": feature.get("loop_frame")}
		for key in ["row", "origin", "node", "linear", "frame"]:
			if feature.has(key): item[key] = feature[key]
		features.append(item)
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
	# (A rolled round's features start their loops where the recorded ones' were at its first
	# frame, by class; likewise the centre's.)
	var loop_frames := {}
	for feature: Dictionary in set_data.features:
		loop_frames[String(feature["class"]).rstrip("0123456789")] = feature.get("loop_frame")
	var centre_loops: Array = []
	for box: Dictionary in set_data.boxes:
		if box.has("loop_frames"): centre_loops = box.loop_frames
	var skin := StringName(meta.get("skin", &"cinema"))
	# The recorded features' placement fields by class (the machine's container origin and
	# node, the belt's and machine's scale).
	var placed := {}
	for feature: Dictionary in set_data.features:
		placed[String(feature["class"])] = feature
	# The toy hands of the round's feature state, by cell: their class by direction
	# (`ToyHand.setMc`); a direction the recorded round lacks takes another hand's placement.
	var hands := {}
	var hand_placed := {}
	for feature: Dictionary in set_data.features:
		if String(feature["class"]).begins_with("Art_ToyHand_"): hand_placed = feature
	for state: Dictionary in snapshot.get("features", []):
		if state.get("kind") != &"toy_hand": continue
		var d := Vector2i(state.direction)
		hands[Vector2i(state.cell)] = "Art_ToyHand_" + ("Up" if d == Vector2i.UP else "Down" if d == Vector2i.DOWN else "Left" if d == Vector2i.LEFT else "Right")
	for y in int(size[1]):
		for x in int(size[0]):
			var cell := Vector2i(x, y)
			var kind: StringName = cells.get(cell, &"floor")
			var hold: bool = center is Vector2i and x >= center.x and x < center.x + 3 and y >= center.y and y < center.y + 3
			if hold:
				# `getMidBox == 3` (the centre) shows `beginNum + 23`; `== 2` is a hidden box.
				boxes.append({"cell": [x, y], "frame": begin + 23, "shown": cell == center and skin not in HIDDEN_CENTRE, "exist": false,
					"loop_frames": centre_loops if cell == center else []})
			elif hands.has(cell):
				# `BirthdayPartyMapData.setData`: `toyHand_<direction>` sets a hidden box
				# (`setMidBox` without `true`) and makes a ToyHand (`Art_ToyHand_<Direction>`).
				boxes.append({"cell": [x, y], "frame": begin + 23, "shown": false, "exist": false})
				var hand: Dictionary = placed.get(hands[cell], hand_placed)
				var item_hand := {"cell": [x, y], "class": hands[cell], "loop_frame": null, "origin": [x, y]}
				for key in ["node", "linear", "frame"]:
					if hand.has(key): item_hand[key] = hand[key]
				features.append(item_hand)
			elif kind == &"solid" and variants.has(cell):
				boxes.append({"cell": [x, y], "frame": begin - 1 + int(variants[cell]), "shown": true, "exist": false})
			elif kind == &"soft":
				boxes.append({"cell": [x, y], "frame": int(variants.get(cell, 1)) + begin + int(entry.fixed_prop_num) - 1,
					"shown": true, "exist": true})
			elif kind == &"portal":
				features.append({"cell": [x, y], "class": "Art_Portal_%d" % int(meta.get("portal_ids", {}).get(cell, 1)),
					"loop_frame": loop_frames.get("Art_Portal_")})
			elif kind == &"crocodile":
				# `ZooMapData`: a `crocodile` cell makes a Crocodile (`Crocodile.setMc`: Art_Crocodile).
				features.append({"cell": [x, y], "class": "Art_Crocodile", "loop_frame": loop_frames.get("Art_Crocodile")})
	# `CandyFactoryMapData.setData`: `centerProp` makes a ConveyorBelt (`initDis`: the machine
	# on the centre row) and, after every cell, `setBeltTrack` the belt (`initBeltView`, only
	# with a track: Pac-Man layouts have none) on row 0 at the track's first cell (`belt_<n>`
	# sorted by n: scripts/simulation/features/belt.gd `track`).
	if skin == &"candy_factory" and center is Vector2i:
		var machine: Dictionary = placed.get("Art_CandyMachine", {})
		var item := {"cell": [center.x, center.y], "class": "Art_CandyMachine", "loop_frame": loop_frames.get("Art_CandyMachine")}
		for key in ["origin", "node", "linear", "frame"]:
			if machine.has(key): item[key] = machine[key]
		features.append(item)
		var track: Array = []
		for state: Dictionary in snapshot.get("features", []):
			if state.get("kind") == &"belt": track = state.get("track", [])
		if not track.is_empty():
			var belt: Dictionary = placed.get("Art_ConveyorBelt_1", {})
			var first: Vector2i = track[0]
			var item_belt := {"cell": [first.x, first.y], "class": "Art_ConveyorBelt_1", "loop_frame": loop_frames.get("Art_ConveyorBelt_")}
			if first.y != 0: item_belt.row = 0
			for key in ["linear", "frame"]:
				if belt.has(key): item_belt[key] = belt[key]
			features.append(item_belt)
	# `MagicLibraryMapData.setData` / `setDataByPacMan`: `centerProp` makes a Spellbook
	# (`initDis`: `Art_Spellbook` at 30/32 at `_xN * GRID_WIDTH` in its container, on the centre
	# row's platform layer), stopped on frame 1.
	if skin == &"magic_library" and center is Vector2i:
		var book: Dictionary = placed.get("Art_Spellbook", {})
		var item_book := {"cell": [center.x, center.y], "class": "Art_Spellbook", "loop_frame": loop_frames.get("Art_Spellbook")}
		for key in ["origin", "node", "linear", "frame"]:
			if book.has(key): item_book[key] = book[key]
		features.append(item_book)
	return {"boxes": boxes, "features": features}

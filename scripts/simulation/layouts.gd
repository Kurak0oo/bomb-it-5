extends RefCounted
## Recorded layout templates rolled into board data as edition 5 does
## (`AbstractMapData.data`, `<Set>MapData.setData`, `MapMaster.createRow`).

const BoardData = preload("res://scripts/simulation/board_data.gd")
const StageSets = preload("res://scripts/simulation/stage_sets.gd")
const SOURCE := "res://assets/maps/layouts.json"
const CENTER := Vector2i(7, 6)
static var _layouts: Dictionary = {}


static func all() -> Dictionary:
	if _layouts.is_empty():
		_layouts = JSON.parse_string(FileAccess.get_file_as_string(SOURCE)).layouts
	return _layouts


static func names(set_id: StringName, pac_man: bool) -> Array[String]:
	var result: Array[String] = []
	for name in all():
		var layout: Dictionary = all()[name]
		if StringName(layout.set) == set_id and layout.pac_man == pac_man:
			result.append(name)
	result.sort()
	return result


## Picks one of the set's three layouts, then rolls it into board data, in the original's draw
## order (`AbstractMapSet.create`): `MapMaster.init`, `<Set>MapData.init`, `AbstractMapData.data`
## (a Pac-Man round draws in `pacManData` instead), then `setData` and `MapMaster.createRow`.
## `random` is the round's `Math.random` (scripts/simulation/avm_random.gd) or, without the
## original's, a Godot RandomNumberGenerator drawn the same way.
static func roll_set(set_id: StringName, pac_man: bool, soft_chance: float, random: Object) -> Dictionary:
	var choices := names(set_id, pac_man)
	var picks := _init_draws(set_id, random)
	var name: String
	if pac_man:
		# `pacManData`: "<Set>Stage_PacMan_" + Math.ceil(Math.random() * 3).
		name = choices[maxi(0, ceili(_draw(random) * 3) - 1)]
	else:
		# `get data`: `_dataArr[Math.floor(Math.random() * (_dataArr.length - 1))]`, the Pac-Man
		# entry being the last.
		name = choices[floori(_draw(random) * choices.size())]
	return _roll(name, soft_chance, random, picks)


## One layout rolled into board data (`<Set>MapData.init`, then `setData` and `createRow`).
static func roll(name: String, soft_chance: float, random: Object) -> Dictionary:
	return _roll(name, soft_chance, random, _init_draws(StringName(all()[name].set), random))


## `MapMaster.init` (`_diffeNum = Math.random() * (5 - 3 + 1)`, never read) and
## `<Set>MapData.init`: two of the set's soft-block frames (`_unfixedArr`), then two fixed-prop
## frames (`_fixedArr`), each `list.splice(int(Math.random() * list.length), 1)`.
static func _init_draws(set_id: StringName, random: Object) -> Dictionary:
	var entry: Dictionary = StageSets.SETS[set_id]
	_draw(random)
	var soft_choices := _pick_two(entry.soft_choices, random)
	var fixed_choices := _pick_two(entry.fixed_choices, random)
	return {"fixed": fixed_choices, "soft": soft_choices}


static func _roll(name: String, soft_chance: float, random: Object, picks: Dictionary) -> Dictionary:
	var layout: Dictionary = all()[name]
	var rows: Array = layout.rows
	var fixed_choices: Array = picks.fixed
	var soft_choices: Array = picks.soft
	# `setData` (Pac-Man: `setDataByPacMan`), column by column: a `fixedProp_r` draws its frame
	# from `_fixedArr`, a numbered one takes `_fixedArr[0]`; `unfixedProp_r` gets the soft
	# chance (`unfixNum`; Pac-Man sets the cell null); centre, hold and toy-hand cells get a mid
	# box (`setMidBox`). The features' constructors draw nothing here.
	var fixed_mc := {}
	var unfixed := {}
	var mid_box := {}
	for x in rows[0].size():
		for y in rows.size():
			var instance: String = rows[y][x]
			var cell := Vector2i(x, y)
			if instance.begins_with("fixedProp"):
				fixed_mc[cell] = fixed_choices[int(_draw(random) * fixed_choices.size())] if instance == "fixedProp_r" else fixed_choices[0]
			elif instance.begins_with("unfixedProp"):
				if instance == "unfixedProp_r" and not layout.pac_man: unfixed[cell] = soft_chance
			elif instance in ["centerProp", "holdProp"] or instance.begins_with("toyHand"):
				mid_box[cell] = true
	# `MapMaster.createRow`, row by row on its Timer: every cell without a mid box draws once
	# (`random > null && random < fixed + null` ...); a fixed cell (fixed 1) takes its frame, a
	# soft candidate under `unfixNum` becomes a box whose frame is
	# `_unfixedFrameArr[int(Math.random() * length)]`.
	var cells: Dictionary = {}
	var features: Dictionary = {}
	var variants: Dictionary = {}
	var pairs: Dictionary = {}
	for y in rows.size():
		var row: Array = rows[y]
		for x in row.size():
			var cell := Vector2i(x, y)
			var instance: String = row[x]
			var drawn := -1.0
			if not mid_box.has(cell): drawn = _draw(random)
			var tile: StringName = &"floor"
			if fixed_mc.has(cell):
				tile = &"solid"
				variants[cell] = fixed_mc[cell]
			elif unfixed.has(cell):
				if drawn > 0.0 and drawn < unfixed[cell]:
					tile = &"soft"
					variants[cell] = soft_choices[int(_draw(random) * soft_choices.size())]
			elif instance.begins_with("unfixedProp"):
				pass
			elif instance in ["centerProp", "holdProp"]:
				tile = &"solid"
			elif instance.begins_with("portal_"):
				tile = &"portal"
				pairs.get_or_add(instance.get_slice("_", 1), []).append(cell)
			elif instance != "":
				var kind := _feature_kind(instance)
				# A toy hand stands on an invisible indestructible box (`setMidBox`).
				tile = &"solid" if kind == &"toy_hand" else kind
				features[cell] = {"kind": kind, "detail": instance.get_slice("_", 1)}
			cells[cell] = tile
	var board := BoardData.make(cells, BoardData._link(pairs), StringName(layout.set), features, name)
	board.variants = variants
	board.fixed_choices = fixed_choices
	board.soft_choices = soft_choices
	board.portal_ids = BoardData.pair_ids(pairs)
	board.center = CENTER if layout.rows[CENTER.y][CENTER.x] == "centerProp" else null
	return board


## `Math.random()` of the round's source.
static func _draw(random: Object) -> float:
	return random.randf() if random is RandomNumberGenerator else random.random()


## Two distinct entries in draw order, as the source splices them from its list.
static func _pick_two(choices: Array, random: Object) -> Array:
	var pool := choices.duplicate()
	var result := []
	while result.size() < 2:
		result.append(pool.pop_at(int(_draw(random) * pool.size())))
	return result


static func _feature_kind(instance: String) -> StringName:
	match instance.get_slice("_", 0):
		"crocodile": return &"crocodile"
		"belt": return &"belt"
		"slidePlat": return &"slide_platform"
		"toyHand": return &"toy_hand"
	return StringName(instance)


## The board of a recorded round (the gameplay screen's layout, `board` in
## scenes/swf/game.json, from tools/convert/layout.py): the template it was rolled from with
## the soft blocks the original rolled and every box's art choice, read back from its
## `_brick5` frame through `MapMaster.createRow`'s frame rules (`StageSets` begin_num and
## fixed_prop_num). The comparison loop can start its round on it (`App.round_as_recorded`),
## for a recording whose draws Godot does not replay.
static func recorded(name: String, boxes: Array) -> Dictionary:
	var layout: Dictionary = all()[name]
	var entry: Dictionary = StageSets.SETS[StringName(layout.set)]
	var begin: int = entry.begin_num
	var frame_at := {}
	for box: Dictionary in boxes:
		if box.shown: frame_at[Vector2i(int(box.cell[0]), int(box.cell[1]))] = int(box.frame)
	var cells: Dictionary = {}
	var features: Dictionary = {}
	var variants: Dictionary = {}
	var pairs: Dictionary = {}
	var fixed_choices := []
	var soft_choices := []
	for y in layout.rows.size():
		var row: Array = layout.rows[y]
		for x in row.size():
			var cell := Vector2i(x, y)
			var instance: String = row[x]
			var tile: StringName = &"floor"
			if instance == "unfixedProp_r" and frame_at.has(cell):
				tile = &"soft"
				variants[cell] = frame_at[cell] - begin - int(entry.fixed_prop_num) + 1
				if not soft_choices.has(variants[cell]): soft_choices.append(variants[cell])
			elif instance.begins_with("fixedProp"):
				tile = &"solid"
				variants[cell] = frame_at.get(cell, begin) - begin + 1
				# The ring's numbered props show the round's first choice (`_fixedArr[0]`).
				if not fixed_choices.has(variants[cell]):
					if instance != "fixedProp_r": fixed_choices.push_front(variants[cell])
					else: fixed_choices.append(variants[cell])
			elif instance in ["centerProp", "holdProp"]:
				tile = &"solid"
			elif instance.begins_with("portal_"):
				tile = &"portal"
				pairs.get_or_add(instance.get_slice("_", 1), []).append(cell)
			elif instance != "" and not instance.begins_with("unfixedProp"):
				var kind := _feature_kind(instance)
				tile = &"solid" if kind == &"toy_hand" else kind
				features[cell] = {"kind": kind, "detail": instance.get_slice("_", 1)}
			cells[cell] = tile
	var board := BoardData.make(cells, BoardData._link(pairs), StringName(layout.set), features, name)
	board.variants = variants
	board.fixed_choices = fixed_choices
	board.soft_choices = soft_choices
	board.portal_ids = BoardData.pair_ids(pairs)
	board.center = CENTER if layout.rows[CENTER.y][CENTER.x] == "centerProp" else null
	return board

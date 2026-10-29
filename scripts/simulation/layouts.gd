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


## Picks one of the set's three layouts, then rolls it into board data.
static func roll_set(set_id: StringName, pac_man: bool, soft_chance: float, rng: RandomNumberGenerator) -> Dictionary:
	var choices := names(set_id, pac_man)
	return roll(choices[rng.randi_range(0, choices.size() - 1)], soft_chance, rng)


static func roll(name: String, soft_chance: float, rng: RandomNumberGenerator) -> Dictionary:
	var layout: Dictionary = all()[name]
	var cells: Dictionary = {}
	var features: Dictionary = {}
	var variants: Dictionary = {}
	var pairs: Dictionary = {}
	# Art only: the round's two fixed and two soft choices (`<Set>MapData.init`).
	var entry: Dictionary = StageSets.SETS[StringName(layout.set)]
	var fixed_choices := _pick_two(entry.fixed_choices, rng)
	var soft_choices := _pick_two(entry.soft_choices, rng)
	for y in layout.rows.size():
		var row: Array = layout.rows[y]
		for x in row.size():
			var cell := Vector2i(x, y)
			var instance: String = row[x]
			var tile: StringName = &"floor"
			if instance.begins_with("unfixedProp"):
				# Pac-Man layouts (`setDataByPacMan`) and plain unfixedProp leave the cell empty.
				if instance == "unfixedProp_r" and not layout.pac_man and rng.randf() < soft_chance:
					tile = &"soft"
					variants[cell] = soft_choices[rng.randi_range(0, 1)]
			elif instance.begins_with("fixedProp"):
				tile = &"solid"
				# Visual variant only. The source ignores a numbered prop's own number and draws
				# the round's first fixed choice; `_r` cells draw either choice.
				variants[cell] = fixed_choices[rng.randi_range(0, 1)] if instance == "fixedProp_r" else fixed_choices[0]
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


## Two distinct entries in draw order, as the source splices them from its list.
static func _pick_two(choices: Array, rng: RandomNumberGenerator) -> Array:
	var pool := choices.duplicate()
	var result := []
	while result.size() < 2:
		result.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	return result


static func _feature_kind(instance: String) -> StringName:
	match instance.get_slice("_", 0):
		"crocodile": return &"crocodile"
		"belt": return &"belt"
		"slidePlat": return &"slide_platform"
		"toyHand": return &"toy_hand"
	return StringName(instance)

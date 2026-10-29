extends SceneTree
## The workbench catalogue covers every slot the game can draw (#70) and matches the art
## pipeline's mirror `tools/art_pipeline/catalog.json`. `WRITE_CATALOG=1` regenerates it.

const Catalog = preload("res://scripts/art/catalog.gd")
const GameView = preload("res://scripts/game_view.gd")
const Looks = preload("res://scripts/looks.gd")
const Pickups = preload("res://scripts/simulation/pickups.gd")
const StageSets = preload("res://scripts/simulation/stage_sets.gd")
const MIRROR := "res://tools/art_pipeline/catalog.json"
var failures := 0
var checks := 0


func _initialize() -> void:
	var ids := {}
	var listed: Array = []
	for entry in Catalog.entries():
		ids[entry.id] = entry
		listed.append({"id": entry.id, "category": entry.category, "size": [int(entry.size.x), int(entry.size.y)]})
	_expect(ids.size() == Catalog.entries().size(), "slot ids are unique")
	_expect(Catalog.ROBOTS == Array(GameView.ROBOT_SLOTS).map(func(slot): return String(slot)), "catalogue robots follow the roster slots")
	var missing: Array[String] = []
	for robot in GameView.ROBOT_SLOTS.size():
		for pose in ["idle", "walk", "action", "portrait", "death"]: _need(ids, missing, "actor.%s.%s" % [GameView.ROBOT_SLOTS[robot], pose])
		for kind in [&"hat", &"body"]:
			for number in range(1, Looks.count(robot, kind) + 1): _need(ids, missing, "look.%s.%s%d" % [GameView.ROBOT_SLOTS[robot], kind, number])
	for kind in Pickups.WEIGHTS:
		if not String(kind).begins_with("reserved") and kind != &"vehicle": _need(ids, missing, "item." + kind)
	for ride in Pickups.VEHICLES:
		_need(ids, missing, "item." + ride)
		_need(ids, missing, "effect." + ride)
		_need(ids, missing, "effect.%s_recovery" % ride)
	_need(ids, missing, "item.coin")
	for set_id in StageSets.ORDER:
		_expect(StageSets.SETS[set_id].fixed_choices.all(func(n): return n <= 7), "%s fixed choices fit the seven solid slots" % set_id)
		if set_id == &"cinema": continue
		for part in ["floor_even", "floor_odd", "wall", "center"]: _need(ids, missing, "board.%s.%s" % [set_id, part])
		for variant in range(1, 8): _need(ids, missing, "board.%s.solid_%d" % [set_id, variant])
		for variant in StageSets.SETS[set_id].soft_choices: _need(ids, missing, "board.%s.soft_%d" % [set_id, variant])
	for id in GameView.CINEMA_SOFT: _need(ids, missing, id)
	for part in ["zoo.crocodile", "zoo.crocodile_open", "birthday_party.toy_hand", "candy_factory.belt",
		"magic_library.spellbook", "magic_library.sign_bomb", "magic_library.sign_pickup"]:
		_need(ids, missing, "board." + part)
	for part in ["mode.flag", "mode.progress"]: _need(ids, missing, part)
	for page in ["menu", "settings", "character", "how_to_play", "score", "dress_up", "game_over", "game_win"]:
		_need(ids, missing, "screen." + page)
	_expect(missing.is_empty(), "every slot the game draws is in the catalogue: missing %s" % [missing])
	if OS.get_environment("WRITE_CATALOG") == "1":
		var file := FileAccess.open(MIRROR, FileAccess.WRITE)
		file.store_string(JSON.stringify(listed, "  ") + "\n")
		file.close()
	var mirror: Variant = JSON.parse_string(FileAccess.get_file_as_string(MIRROR))
	_expect(mirror == JSON.parse_string(JSON.stringify(listed)), "tools/art_pipeline/catalog.json mirrors the catalogue (WRITE_CATALOG=1 to refresh)")
	print("%s: %d art catalogue checks (%d slots)" % ["PASS" if failures == 0 else "FAIL", checks, listed.size()])
	quit(0 if failures == 0 else 1)


func _need(ids: Dictionary, missing: Array[String], id: String) -> void:
	if not ids.has(id): missing.append(id)


func _expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr(label)

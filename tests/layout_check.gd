extends SceneTree
## Recorded layouts and edition 5 board rolls (#58); observed openings are in
## docs/evidence/edition-5-stage-openings.md.

const Layouts = preload("res://scripts/simulation/layouts.gd")
const StageSets = preload("res://scripts/simulation/stage_sets.gd")
const Simulation = preload("res://scripts/simulation/bomb_simulation.gd")
const ArcadeMode = preload("res://scripts/simulation/modes/arcade_mode.gd")
var failures := 0
var checks := 0


func _initialize() -> void:
	_expect(Layouts.all().size() == 36, "36 used layouts are recorded")
	for set_id in StageSets.ORDER:
		_expect(Layouts.names(set_id, false).size() == 3 and Layouts.names(set_id, true).size() == 3,
			"%s has three normal and three Pac-Man layouts" % set_id)

	var first := _rng(7)
	var second := _rng(7)
	_expect(Layouts.roll("CinemaStage2", 0.6, first).cells == Layouts.roll("CinemaStage2", 0.6, second).cells,
		"the same seed rolls the same board")

	var structural_ok := true
	var spawn_clear := true
	for name in Layouts.all():
		var rows: Array = Layouts.all()[name].rows
		var board: Dictionary = Layouts.roll(name, 0.6, _rng(name.hash()))
		for cell in board.cells:
			var instance: String = rows[cell.y][cell.x]
			var tile: StringName = board.cells[cell]
			if tile == &"soft" and instance != "unfixedProp_r": structural_ok = false
			if (instance.begins_with("fixedProp") or instance in ["centerProp", "holdProp"]) and tile != &"solid": structural_ok = false
		for cell in [Vector2i(1, 1), Vector2i(15, 1), Vector2i(1, 13), Vector2i(15, 13), Vector2i(2, 1), Vector2i(1, 2),
				Vector2i(14, 1), Vector2i(15, 2), Vector2i(1, 12), Vector2i(2, 13), Vector2i(15, 12), Vector2i(14, 13)]:
			spawn_clear = spawn_clear and board.cells[cell] == &"floor"
	_expect(structural_ok, "solids follow the template and soft blocks appear only on candidates")
	_expect(spawn_clear, "spawn corners and their neighbours start empty in every layout")

	_expect(absf(_soft_ratio("CinemaStage2", 0.6) - 0.6) < 0.01, "Arcade rolls fill about 60% of candidates")
	_expect(absf(_soft_ratio("ZooStage3", 0.55) - 0.55) < 0.01, "Kill rolls fill about 55% of candidates")
	_expect(Layouts.roll("CinemaStage_PacMan_1", 1.0, _rng(3)).cells.values().count(&"soft") == 0,
		"Pac-Man layouts never hold soft blocks")
	_expect(Layouts.roll("CinemaStage1", 0.0, _rng(3)).cells.values().count(&"soft") == 0,
		"Green Zone and Pac-Man's zero chance leaves no soft blocks")

	var seen := {}
	for seed_value in 60:
		seen[Layouts.roll_set(&"cinema", false, 0.6, _rng(seed_value)).layout] = true
	_expect(seen.size() == 3, "a set picks among all three of its layouts")

	var cinema: Dictionary = Layouts.roll("CinemaStage3", 0.6, _rng(4))
	_expect(cinema.portals.size() == 4 and cinema.portals.keys().all(func(cell): return cinema.portals[cinema.portals[cell]] == cell),
		"Cinema layouts link two portal pairs")
	_expect(Layouts.roll("LuxuryStoresStage1", 0.6, _rng(4)).portals.is_empty(), "Luxury Shop has no portals")
	var empty_arena: Dictionary = Layouts.roll("BirthdayPartyStage3", 0.6, _rng(4))
	_expect(empty_arena.cells.values().count(&"solid") == 60 and empty_arena.center == null,
		"Birthday Party layout 3 is the recorded empty arena")
	var zoo: Dictionary = Layouts.roll("ZooStage1", 0.6, _rng(4))
	_expect(zoo.features.values().any(func(f): return f.kind == &"crocodile"), "unported tiles are kept as marked features")

	_expect(StageSets.available_sets() == [&"cinema", &"luxury_stores"], "only fully ported sets are offered")

	var luxury: Dictionary = Layouts.roll("LuxuryStoresStage2", 0.6, _rng(9))
	var game := Simulation.new([&"human"], {&"human": {"cell": Vector2i(1, 1)}}, luxury.cells,
		{"movement": true, "damage": true, "drops": true, "seed": 3, "vehicles": [&"car"], "mode": ArcadeMode.new(&"normal", &"luxury_stores")})
	var state: Dictionary = {}
	for tick in 140:
		state = game.advance([{"actor_id": &"human", "direction": Vector2.RIGHT if tick < 20 else Vector2.ZERO,
			"bomb_events": [&"down", &"up"] if tick == 30 else []}])
	_expect(state.board.size() == 255 and state.mode == &"arcade", "Arcade plays on a rolled Luxury Shop board")
	_finish()


func _soft_ratio(name: String, chance: float) -> float:
	# 300 rolls of one layout; the observed original rate is 0.607 over 1,300 candidates.
	var soft := 0
	var candidates := 0
	for seed_value in 300:
		var board: Dictionary = Layouts.roll(name, chance, _rng(seed_value))
		soft += board.cells.values().count(&"soft")
	for row in Layouts.all()[name].rows:
		candidates += row.count("unfixedProp_r")
	return float(soft) / (candidates * 300)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr(label)


func _finish() -> void:
	print("%s: %d layout checks" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)

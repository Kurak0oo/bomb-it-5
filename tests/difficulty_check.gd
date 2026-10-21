extends SceneTree
## Easy and Hard against the observed original (#60): see edition-5-difficulty.md.

const Simulation = preload("res://scripts/simulation/bomb_simulation.gd")
const ArcadeMode = preload("res://scripts/simulation/modes/arcade_mode.gd")
const AIProfiles = preload("res://scripts/simulation/ai_profiles.gd")
const Layouts = preload("res://scripts/simulation/layouts.gd")
const Session = preload("res://scripts/session.gd")
var failures := 0
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var rows := {&"easy": [0.6, 1000, 5, 30], &"normal": [0.5, 2000, 6, 20], &"hard": [0.4, 3000, 7, 20]}
	for difficulty in rows:
		var mode := ArcadeMode.new(difficulty)
		var row: Array = rows[difficulty]
		_expect(is_equal_approx(mode.drop_chance(), row[0]), "%s drop chance is %s" % [difficulty, row[0]])
		var profile: Dictionary = AIProfiles.for_mode(&"arcade", difficulty)
		_expect(profile.find_range == row[2] and profile.answer_ms == row[3], "%s AI range and answer time follow the observed profile" % difficulty)
		_expect(_won_bonus(difficulty) == row[1], "%s level bonus is %d" % [difficulty, row[1]])
	_expect(AIProfiles.for_mode(&"arcade", &"hard").states.any(func(entry): return entry.state == &"Idle"), "Hard Arcade AI carries the Idle state")

	var board: Dictionary = Layouts.roll("CinemaStage2", 0.6, _rng(3))
	var easy := Simulation.new([&"human"], {&"human": {"cell": Vector2i(1, 1)}}, board.cells,
		{"drops": true, "mode": ArcadeMode.new(&"easy")})
	_expect(easy.snapshot().pickups.get(Vector2i(1, 1)) == &"shield", "Easy places a shield on the player's spawn")
	var state: Dictionary = easy.advance([{"actor_id": &"human", "direction": Vector2.ZERO, "bomb_events": []}])
	_expect(state.actors[&"human"].shield == 1 and state.actors[&"human"].score == 100, "the player collects it at once for 100 points, as observed")
	var normal := Simulation.new([&"human"], {&"human": {"cell": Vector2i(1, 1)}}, board.cells,
		{"drops": true, "mode": ArcadeMode.new(&"normal")})
	_expect(normal.snapshot().pickups.is_empty(), "Normal and Hard start without a spawn shield")

	var drops := {}
	for difficulty in rows:
		drops[difficulty] = _drop_rate(difficulty)
	_expect(drops[&"easy"] > drops[&"normal"] and drops[&"normal"] > drops[&"hard"], "harder settings drop fewer pickups")

	var game = load("res://scripts/game.gd").new()
	var session := Session.new(2)
	session.difficulty = &"hard"
	session.stage = &"cinema"
	session.begin()
	game.session = session
	game.auto_start = false
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.play_level()
	_expect(game.ai.profile.find_range == 7 and game.get_snapshot().difficulty == &"hard", "a Hard session drives the Hard AI profile")
	game.queue_free()
	await process_frame
	_finish()


func _won_bonus(difficulty: StringName) -> int:
	var cells := {}
	for y in 3:
		for x in 4:
			cells[Vector2i(x, y)] = &"floor" if x in [1, 2] and y == 1 else &"solid"
	var game := Simulation.new([&"human", &"ai"], {&"human": {"cell": Vector2i(1, 1)}, &"ai": {"cell": Vector2i(2, 1), "alive": false, "removed": true}},
		cells, {"round": true, "mode": ArcadeMode.new(difficulty)})
	var state: Dictionary = {}
	for tick in 200:
		state = game.advance([{"actor_id": &"human", "direction": Vector2.ZERO, "bomb_events": []},
			{"actor_id": &"ai", "direction": Vector2.ZERO, "bomb_events": []}])
		if state.outcome != &"running": break
	return state.get("result_breakdown", {}).get("difficulty", -1)


## Fraction of broken soft blocks that dropped a pickup, through the real round.
func _drop_rate(difficulty: StringName) -> float:
	var dropped := 0
	var broken := 0
	for seed_value in 300:
		var cells := {}
		for x in 7:
			for y in 3:
				cells[Vector2i(x, y)] = &"soft" if y == 1 and x in [2, 4] else &"floor" if y == 1 else &"solid"
		cells[Vector2i(0, 1)] = &"solid"
		cells[Vector2i(6, 1)] = &"solid"
		var game := Simulation.new([&"human"], {&"human": {"cell": Vector2i(3, 1)}}, cells,
			{"drops": true, "damage": false, "seed": seed_value, "mode": ArcadeMode.new(difficulty)})
		var state: Dictionary = game.advance([{"actor_id": &"human", "direction": Vector2.ZERO, "bomb_events": [&"down"]}])
		for tick in 100:
			state = game.advance([{"actor_id": &"human", "direction": Vector2.ZERO, "bomb_events": []}])
		broken += 2
		dropped += state.pickups.size()
	return float(dropped) / broken


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
	print("%s: %d difficulty checks" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)

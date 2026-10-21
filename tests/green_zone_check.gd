extends SceneTree
## Green Zone through the real round (#68); observed original in edition-5-green-zone.md.

const Simulation = preload("res://scripts/simulation/bomb_simulation.gd")
const GreenZoneMode = preload("res://scripts/simulation/modes/green_zone_mode.gd")
const AIProfiles = preload("res://scripts/simulation/ai_profiles.gd")
const AI = preload("res://scripts/simulation/ai_controller.gd")
const Layouts = preload("res://scripts/simulation/layouts.gd")
const Session = preload("res://scripts/session.gd")
var failures := 0
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var inside := true
	for seed_value in 30:
		var mode := GreenZoneMode.new()
		var board: Dictionary = Layouts.roll("CinemaStage2", mode.soft_chance(), _rng(seed_value))
		var game := Simulation.new([&"human"], {&"human": {"cell": Vector2i(1, 1)}}, board.cells,
			{"drops": true, "seed": seed_value, "mode": mode})
		var flag: Vector2i = game.snapshot().mode_state.flag
		inside = inside and flag.x >= 3 and flag.x <= 14 and flag.y >= 3 and flag.y <= 12 and board.cells[flag] == &"floor"
		if seed_value == 0:
			_expect(game.snapshot().pickups.size() == 2, "map load adds two random pickups")
			_expect(board.cells.values().count(&"soft") == 0, "Green Zone boards have no soft blocks")
	_expect(inside, "the flag starts on a free cell at least two cells from the edges (observed x 3-14, y 3-12)")

	var mode := GreenZoneMode.new()
	var game := _open_round(mode, {&"human": {"cell": Vector2i(1, 1)}, &"ai": {"cell": Vector2i(7, 3)}})
	mode.flag = Vector2i(4, 2)
	_park(game, &"human", Vector2i(4, 2))
	var state: Dictionary = {}
	for tick in 104: state = _step(game)
	_expect(state.mode_state.progress.get(&"human") == 104 and state.actors[&"human"].flags == 0, "standing on the flag fills progress by one per tick")
	state = _step(game)
	_expect(state.actors[&"human"].flags == 1 and state.actors[&"human"].points == 1 and state.mode_state.flag == null,
		"a full bar (105 ticks) captures the flag")
	for tick in 104: state = _step(game)
	_expect(state.mode_state.flag == null, "the flag stays away during its 105-tick move delay")
	state = _step(game)
	_expect(state.mode_state.flag != null, "then it reappears elsewhere")

	mode = GreenZoneMode.new()
	game = _open_round(mode, {&"human": {"cell": Vector2i(1, 1)}, &"ai": {"cell": Vector2i(7, 3)}})
	mode.flag = Vector2i(4, 2)
	_park(game, &"human", Vector2i(4, 2))
	for tick in 40: state = _step(game)
	_park(game, &"human", Vector2i(1, 1))
	for tick in 20: state = _step(game)
	_expect(state.mode_state.progress.get(&"human") == 20, "leaving the flag drains progress by one per tick")
	for tick in 21: state = _step(game)
	_expect(not state.mode_state.progress.has(&"human"), "an emptied bar disappears")

	mode = GreenZoneMode.new()
	game = _open_round(mode, {&"human": {"cell": Vector2i(1, 1), "flags": 9}, &"ai": {"cell": Vector2i(7, 3)}})
	mode.flag = Vector2i(4, 2)
	_park(game, &"human", Vector2i(4, 2))
	for tick in 105 + 106: state = _step(game)
	_expect(state.round_stage == &"ending" and state.pending_outcome == &"won", "the 10th capture wins when the flag moves")
	for tick in 106: state = _step(game)
	_expect(state.outcome == &"won" and state.result_breakdown.kills == 1000, "Green Zone scores 100 per flag")

	var rows := [[3, [3], &"won"], [2, [3], &"lost"], [4, [1, 4], &"won"]]
	for row in rows:
		var fake := FakeRound.new({"flags": row[0]}, row[1].map(func(f): return {"flags": f}))
		_expect(GreenZoneMode.new().judge(fake, false, 6300) == row[2], "timeout compares flags, ties to the human (%s)" % row[2])
	_expect(GreenZoneMode.new().player_speed() == 1.8 and GreenZoneMode.new().respawn_ticks(true) == 35, "player speed 1.8 and 1 s respawn")
	_expect(GreenZoneMode.new().timed_pickup_count(15 * 35) == 2 and GreenZoneMode.new().timed_pickup_count(0) == 0, "timed pickups start after 10 s")

	mode = GreenZoneMode.new()
	game = _open_round(mode, {&"human": {"cell": Vector2i(1, 3)}, &"ai": {"cell": Vector2i(7, 3)}}, true)
	mode.flag = Vector2i(4, 2)
	var ai := AI.new(4, [], AIProfiles.for_mode(&"green_zone", &"hard"))
	var captured := false
	for tick in 900:
		var view: Dictionary = game.snapshot()
		var command: Dictionary = ai.command(view, &"ai")
		var commands: Array[Dictionary] = [{"actor_id": &"human", "direction": Vector2.ZERO, "bomb_events": []},
			{"actor_id": &"ai", "direction": command.direction, "bomb_events": command.bomb_events}]
		state = game.advance(commands)
		if state.actors[&"ai"].flags > 0:
			captured = true
			break
	_expect(captured, "Green Zone AI walks to the flag and captures it")

	var app_game = load("res://scripts/game.gd").new()
	var session := Session.new(3)
	session.mode = &"green_zone"
	session.stage = &"cinema"
	session.begin()
	app_game.session = session
	app_game.auto_start = false
	root.add_child(app_game)
	await process_frame
	app_game.set_process(false)
	app_game.play_level()
	_expect(app_game.get_snapshot().actors[&"human"].speed == 1.8 and app_game.get_snapshot().actors[&"human"].weapon == &"hammer",
		"a Green Zone level gives the player speed 1.8 and the hammer")
	app_game.queue_free()
	await process_frame
	_finish()


func _open_round(mode: RefCounted, actors: Dictionary, movement := false) -> RefCounted:
	var cells := {}
	for x in 9:
		for y in 6:
			cells[Vector2i(x, y)] = &"solid" if x == 0 or y == 0 or x == 8 or y == 5 else &"floor"
	var ids: Array[StringName] = []
	ids.assign(actors.keys())
	return Simulation.new(ids, actors, cells, {"movement": movement, "damage": true, "drops": true, "round": true,
		"seed": 3, "mode": mode})


func _park(game: RefCounted, id: StringName, cell: Vector2i) -> void:
	game.actors()[id].cell = cell
	game.actors()[id].position = Vector2(cell)


func _step(game: RefCounted) -> Dictionary:
	var commands: Array[Dictionary] = []
	for id in game.snapshot().actors:
		commands.append({"actor_id": id, "direction": Vector2.ZERO, "bomb_events": []})
	return game.advance(commands)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


class FakeRound extends RefCounted:
	var _human: Dictionary
	var _enemies: Array[Dictionary] = []

	func _init(human_actor: Dictionary, others: Array) -> void:
		_human = human_actor
		_enemies.assign(others)

	func human() -> Dictionary:
		return _human

	func enemies() -> Array[Dictionary]:
		return _enemies


func _expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr(label)


func _finish() -> void:
	print("%s: %d green zone checks" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)

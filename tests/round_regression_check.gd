extends SceneTree

const Simulation = preload("res://scripts/simulation/bomb_simulation.gd")
const Scheduler = preload("res://scripts/simulation/tick_scheduler.gd")
const AI = preload("res://scripts/simulation/ai_controller.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	_movement()
	_lifecycle()
	_hazards()
	_drops()
	_outcomes()
	_weapons()
	_controller_rejection()
	_surviving_controller()
	_escape_following()
	print("%s: %d round regression checks" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)


func _board() -> Dictionary:
	var board: Dictionary = {}
	for y in 7:
		for x in 9:
			board[Vector2i(x, y)] = &"solid" if x == 0 or x == 8 or y == 0 or y == 6 else &"floor"
	return board


func _command(id: StringName = &"human", direction: Vector2 = Vector2.ZERO, events: Array = []) -> Dictionary:
	return {"actor_id": id, "direction": direction, "bomb_events": events}


func _game(options: Dictionary = {}, actors: Dictionary = {}, board: Dictionary = {}) -> Simulation:
	if actors.is_empty(): actors = {&"human": {"cell": Vector2i(2, 3)}}
	if board.is_empty(): board = _board()
	var ids: Array[StringName] = []
	ids.assign(actors.keys())
	return Simulation.new(ids, actors, board, options)


func _ticks(game: Simulation, count: int, direction: Vector2 = Vector2.ZERO, ids: Array = [&"human"]) -> Dictionary:
	var state: Dictionary = game.snapshot()
	for index in count:
		var commands: Array[Dictionary] = []
		for id in ids:
			commands.append(_command(id, direction if id == &"human" else Vector2.ZERO))
		state = game.advance(commands)
	return state


func _expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr(label)


func _movement() -> void:
	var straight := _game({"movement": true}, {&"human": {"cell": Vector2i(3, 3)}})
	var diagonal := _game({"movement": true}, {&"human": {"cell": Vector2i(3, 3)}})
	var a := _ticks(straight, 20, Vector2.RIGHT)
	var b := _ticks(diagonal, 20, Vector2(1, 1))
	_expect(absf(a.actors[&"human"].position.distance_to(Vector2(3, 3)) - b.actors[&"human"].position.distance_to(Vector2(3, 3))) < 0.0001,
		"normalized diagonal and cardinal travel have equal speed")
	var at: Vector2 = a.actors[&"human"].position
	_expect(_ticks(straight, 1).actors[&"human"].position == at, "release stops displacement immediately")
	var blockers := _board()
	blockers[Vector2i(2, 1)] = &"solid"
	blockers[Vector2i(1, 2)] = &"soft"
	var corner := _game({"movement": true}, {&"human": {"cell": Vector2i(1, 1)}}, blockers)
	_expect(_ticks(corner, 30, Vector2(1, 1)).actors[&"human"].position == Vector2(1, 1), "touching blocked corners cannot be cut diagonally")
	blockers[Vector2i(1, 2)] = &"floor"
	var sliding := _game({"movement": true}, {&"human": {"cell": Vector2i(1, 1)}}, blockers)
	var slide := _ticks(sliding, 4, Vector2(1, 1)).actors[&"human"].position as Vector2
	_expect(is_equal_approx(slide.x, 1) and slide.y > 1, "a blocked axis slides along the free axis")
	var depart := _game({"movement": true})
	depart.advance([_command(&"human", Vector2.RIGHT, [&"down"])])
	_ticks(depart, 20, Vector2.RIGHT)
	var returned := _ticks(depart, 35, Vector2.LEFT)
	_expect(returned.actors[&"human"].position.x >= 2.9999, "a fully departed bomb blocks re-entry")
	var copy: Dictionary = depart.snapshot()
	copy.actors[&"human"].position = Vector2(99, 99)
	copy.board.clear()
	_expect(depart.snapshot().actors[&"human"].position.x < 8 and depart.snapshot().board.size() == 63, "public state is owned and cannot mutate the round")
	var invalid := _game()
	_expect(not invalid.advance([_command(&"human", Vector2(NAN, 0))]).accepted, "non-finite movement cannot enter a tick")


func _lifecycle() -> void:
	var board := _board()
	board[Vector2i(2, 3)] = &"portal"
	board[Vector2i(6, 3)] = &"portal"
	var game := _game({"movement": true, "damage": true, "portals": {Vector2i(2, 3): Vector2i(6, 3), Vector2i(6, 3): Vector2i(2, 3)}}, {}, board)
	var scheduler := Scheduler.new([&"human"], game)
	scheduler.advance_time(1.0 / 35)
	scheduler.pause()
	scheduler.advance_time(60)
	_expect(game.snapshot().tick == 1 and game.snapshot().actors[&"human"].cell == Vector2i(2, 3), "paused portal transfer does not age")
	_expect(scheduler.resume(), "focused paused round can explicitly resume")
	for index in 29: scheduler.advance_time(1.0 / 35)
	_expect(game.snapshot().actors[&"human"].cell == Vector2i(2, 3), "portal does not arrive before its thirty callbacks")
	scheduler.advance_time(1.0 / 35)
	var arrival: Dictionary = game.snapshot()
	_expect(arrival.actors[&"human"].cell == Vector2i(6, 3), "portal arrives at the paired cell")
	_expect(arrival.actors[&"human"].protected_until <= arrival.tick and arrival.actors[&"human"].blink_until > arrival.tick,
		"arrival restores damage eligibility before the remaining source blink ends")
	for index in 50: scheduler.advance_time(1.0 / 35)
	_expect(game.snapshot().actors[&"human"].cell == Vector2i(6, 3), "destination latch prevents a stationary portal return")
	scheduler.free()
	game = _game({}, {}, board)
	_expect(game.advance([_command(&"human", Vector2.ZERO, [&"down"])]).bombs.is_empty(), "ordinary bomb placement is rejected on a portal platform")


func _hazards() -> void:
	var game := _game({"damage": true}, {&"human": {"cell": Vector2i(2, 3), "protected_until": 1000}})
	game.advance([_command(&"human", Vector2.ZERO, [&"down"])])
	var state := _ticks(game, 72)
	_expect(state.flames.size() == 1 and state.actors[&"human"].alive, "detonation creates a persistent flame and respects protection")
	var rejected: Dictionary = game.advance([])
	_expect(not rejected.accepted and rejected.tick == 73 and rejected.flames == state.flames, "atomic rejection freezes active hazards")
	_expect(_ticks(game, 15).flames.size() == 1, "flames remain before the seventeenth cleanup callback")
	_expect(_ticks(game, 1).flames.is_empty(), "expired flames are removed")
	game = _game({"damage": true, "drops": true}, {}, _board())
	game.advance([_command(&"human", Vector2.ZERO, [&"down"])])
	state = _ticks(game, 72)
	_expect(not state.actors[&"human"].alive and state.actors[&"human"].lives == 3, "unprotected self-hit detaches the actor without spending a retry heart")
	var dead_at: Vector2 = state.actors[&"human"].position
	state = game.advance([_command(&"human", Vector2.RIGHT, [&"down"])])
	_expect(state.actors[&"human"].position == dead_at and state.bombs.is_empty(), "dead actors neither move nor place bombs")


func _drops() -> void:
	var appeared := 0
	for seed_value in 40:
		var board := _board()
		board[Vector2i(3, 3)] = &"soft"
		var game := _game({"damage": true, "drops": true, "seed": seed_value},
			{&"human": {"cell": Vector2i(2, 3), "protected_until": 1000}}, board)
		game.advance([_command(&"human", Vector2.ZERO, [&"down"])])
		var early := _ticks(game, 81)
		_expect(early.pickups.is_empty(), "drops wait for the recovered brick animation boundary")
		var ready := _ticks(game, 1)
		appeared += ready.pickups.size()
	_expect(appeared > 0 and appeared < 40, "eligible soft blocks have conditional rather than guaranteed drops")
	var board := _board()
	board[Vector2i(3, 3)] = &"soft"
	var game := _game({"movement": true, "damage": true, "drops": true, "seed": 42},
		{&"human": {"cell": Vector2i(2, 3), "protected_until": 1000}}, board)
	game.advance([_command(&"human", Vector2.ZERO, [&"down"])])
	_ticks(game, 72)
	var occupied := _ticks(game, 11, Vector2.RIGHT)
	_expect(occupied.actors[&"human"].cell == Vector2i(3, 3) and occupied.pickups.is_empty(), "occupying a broken cell suppresses its delayed drop")
	for kind in [&"capacity", &"power", &"speed", &"life", &"shield", &"invincible"]:
		game = _game({"drops": true, "pickups": {Vector2i(2, 3): kind}})
		var state := _ticks(game, 1)
		_expect(state.pickups.is_empty() and state.actors[&"human"].score == (0 if kind == &"invincible" else 100), "a collected pickup is removed and awards its source HUD points")


func _outcomes() -> void:
	var actors := {&"human": {"cell": Vector2i(2, 3), "shield": 1},
		&"a": {"cell": Vector2i(3, 3)}, &"b": {"cell": Vector2i(2, 4)}, &"c": {"cell": Vector2i(2, 2)}}
	var game := _game({"round": true, "damage": true}, actors)
	game.advance([_command(&"human", Vector2.ZERO, [&"down"]), _command(&"a"), _command(&"b"), _command(&"c")])
	var state := _ticks(game, 236, Vector2.ZERO, actors.keys())
	_expect(state.outcome == &"won" and state.actors[&"human"].kills == 3, "eliminating all three enemies wins a round")
	_expect(state.result_score == 4670, "Normal victory awards kills, difficulty and time captured at delayed mode judgment")
	var after := _ticks(game, 40, Vector2.ZERO, actors.keys())
	_expect(after.tick == 237 and after.result_score == 4670, "a completed round cannot advance or recount its result")
	actors[&"human"].shield = 0
	game = _game({"round": true, "damage": true}, actors)
	game.advance([_command(&"human", Vector2.ZERO, [&"down"]), _command(&"a"), _command(&"b"), _command(&"c")])
	_expect(_ticks(game, 236, Vector2.ZERO, actors.keys()).outcome == &"lost", "human defeat takes priority in a simultaneous elimination batch")


func _weapons() -> void:
	var board := _board()
	board[Vector2i(4, 3)] = &"soft"
	var actors := {&"human": {"cell": Vector2i(2, 3)}, &"a": {"cell": Vector2i(6, 3)}}
	var game := _game({"movement": true, "damage": true, "drops": true, "pickups": {Vector2i(2, 3): &"laser"}}, actors, board)
	game.advance([_command(&"human", Vector2.RIGHT), _command(&"a")])
	game.advance([_command(&"human", Vector2.ZERO, [&"down", &"down"]), _command(&"a")])
	var state := _ticks(game, 12, Vector2.ZERO, actors.keys())
	_expect(state.actors[&"a"].alive and state.board[Vector2i(4, 3)] == &"floor", "laser destroys its first soft blocker without hitting an actor beyond it")
	_expect(state.actors[&"human"].ammo == 1, "repeated input cannot spend a weapon again while its action is locked")
	board = _board()
	board[Vector2i(4, 3)] = &"solid"
	game = _game({"movement": true, "damage": true, "drops": true, "pickups": {Vector2i(2, 3): &"flamer"}}, actors, board)
	game.advance([_command(&"human", Vector2.RIGHT), _command(&"a")])
	game.advance([_command(&"human", Vector2.ZERO, [&"down"]), _command(&"a")])
	state = _ticks(game, 20, Vector2.ZERO, actors.keys())
	_expect(state.attacks[0].get("cells", []) == [Vector2i(3, 3)] and state.actors[&"a"].alive,
		"the flamer publishes its resolved visible footprint and cannot burn through a solid")
	game = _game({"movement": true, "damage": true, "drops": true, "pickups": {Vector2i(2, 3): &"car"}})
	game.advance([_command()])
	game.advance([_command(&"human", Vector2.ZERO, [&"down"])])
	state = _ticks(game, 72)
	_expect(state.actors[&"human"].alive and state.actors[&"human"].vehicle == &"car" and state.actors[&"human"].vehicle_recovery_until > state.tick, "a blast starts retained vehicle recovery before any rider death")
	_expect(state.actors[&"human"].protected_until > state.tick, "vehicle loss grants its recovery protection")
	game = _game({"movement": true, "drops": true,
		"pickups": {Vector2i(2, 3): &"laser", Vector2i(3, 3): &"car"}})
	state = _ticks(game, 12, Vector2.RIGHT)
	_expect(state.actors[&"human"].vehicle == &"car" and state.actors[&"human"].weapon == &"laser", "vehicle acquisition retains the equipped source weapon")
	game = _game({"movement": true, "damage": true, "drops": true, "pickups": {Vector2i(2, 3): &"landmine"}})
	game.advance([_command()])
	game.advance([_command(&"human", Vector2.ZERO, [&"down"])])
	_ticks(game, 20, Vector2.RIGHT)
	state = _ticks(game, 25, Vector2.LEFT)
	_expect(state.bombs.is_empty() and not state.actors[&"human"].alive, "an armed mine detonates when its owner returns")


func _controller_rejection() -> void:
	var actors := {&"human": {"cell": Vector2i(2, 3)}, &"ai": {"cell": Vector2i(6, 3)}}
	var game := _game({"movement": true}, actors)
	var scheduler := Scheduler.new([&"human", &"ai"], game)
	var produced := {"direction": Vector2.RIGHT, "bomb_events": [&"down"]}
	scheduler.set_controller(&"ai", func(): return produced)
	scheduler.set_direction(&"human", Vector2(NAN, 0))
	scheduler.advance_time(1.0 / 35)
	_expect(game.snapshot().tick == 0, "a rejected batch does not advance controller gameplay")
	produced.direction = Vector2.LEFT
	scheduler.set_direction(&"human", Vector2.ZERO)
	var update: Dictionary = scheduler.advance_time(1.0 / 35)
	_expect(update.ticks[0].commands[1].direction == Vector2.RIGHT, "a captured controller proposal is owned across rejection")
	_expect(update.ticks[0].commands[1].bomb_events == [&"down"], "controller events survive rejection exactly once")
	scheduler.free()


func _surviving_controller() -> void:
	var actors := {&"human": {"cell": Vector2i(1, 1)}, &"a": {"cell": Vector2i(2, 1), "alive": false},
		&"b": {"cell": Vector2i(3, 1), "alive": false}, &"c": {"cell": Vector2i(6, 4)}}
	var game := _game({"movement": true}, actors)
	var scheduler := Scheduler.new([&"human", &"a", &"b", &"c"], game)
	var controller := AI.new(5)
	scheduler.set_controller(&"c", func(): return controller.command(game.snapshot(), &"c"))
	for index in 5: scheduler.advance_time(1.0 / 35)
	_expect(game.snapshot().actors[&"c"].position != Vector2(6, 4),
		"the surviving AI receives a decision turn without waiting for eliminated controllers")
	scheduler.free()


func _escape_following() -> void:
	var board := _board()
	for cell in board:
		if cell.y != 3: board[cell] = &"solid"
	var actors := {&"human": {"cell": Vector2i(2, 3), "power": 3}, &"a": {"cell": Vector2i(4, 3)},
		&"b": {"cell": Vector2i(1, 3)}, &"c": {"cell": Vector2i(7, 3)}}
	var game := _game({"movement": true}, actors, board)
	game.advance([_command(&"human", Vector2.ZERO, [&"down"]), _command(&"a"), _command(&"b"), _command(&"c")])
	_ticks(game, 33, Vector2.ZERO, actors.keys())
	var scheduler := Scheduler.new([&"human", &"a", &"b", &"c"], game)
	var controller := AI.new(5)
	scheduler.set_controller(&"a", func(): return controller.command(game.snapshot(), &"a"))
	for index in 12: scheduler.advance_time(1.0 / 35)
	var first: Vector2 = game.snapshot().actors[&"a"].position
	scheduler.advance_time(1.0 / 35)
	_expect(first.x > 4 and game.snapshot().actors[&"a"].position.x > first.x,
		"AI follows a multi-cell escape on non-thinking ticks through threatened intermediate cells")
	scheduler.free()

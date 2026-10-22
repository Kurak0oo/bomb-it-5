extends SceneTree
## Zoo, Birthday Party, Candy Factory and Magic Library features through the real round
## (#63-#66); observed originals in edition-5-zoo.md, -birthday-party.md, -candy-factory.md
## and -magic-library.md.

const Simulation = preload("res://scripts/simulation/bomb_simulation.gd")
const Modes = preload("res://scripts/simulation/modes/modes.gd")
const Layouts = preload("res://scripts/simulation/layouts.gd")
const StageSets = preload("res://scripts/simulation/stage_sets.gd")
const Perception = preload("res://scripts/simulation/ai_perception.gd")
const Pickups = preload("res://scripts/simulation/pickups.gd")
const Session = preload("res://scripts/session.gd")
var failures := 0
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_crocodiles()
	_toy_hands()
	_belt()
	_spellbook()
	_rides()
	_sets()
	await _level()
	_finish()


func _crocodiles() -> void:
	var game := _round("ZooStage1", {&"human": {"cell": Vector2i(1, 1)}})
	var phases := {}
	for tick in 345:
		var state := _step(game)
		var croc: Dictionary = state.features.filter(func(f): return f.kind == &"crocodile")[0]
		phases[state.tick] = [croc.phase, croc.danger]
	_expect(phases[239] == [&"closed", false] and phases[240][1] and phases[264][0] == &"opening" and phases[265][0] == &"open"
		and phases[324][0] == &"open" and phases[325][0] == &"closing" and phases[345][1],
		"crocodiles: 240 closed, 24 opening, 60 open, 21 closing; danger from the 240th tick (observed)")
	var states: Array = game.snapshot().features.map(func(f): return f.frame)
	_expect(states.size() == 4 and states.all(func(f): return f == states[0]), "all four crocodiles run in lockstep")

	game = _round("ZooStage1", {&"human": {"cell": Vector2i(4, 5)}, &"ai": {"cell": Vector2i(1, 1)}})
	game.pickups()[Vector2i(12, 5)] = &"speed"
	var placed := _step(game, {&"human": [&"down"]})
	_expect(placed.bombs.is_empty(), "no bomb can be placed on a crocodile")
	var died_at := -1
	for tick in 300:
		var state := _step(game)
		if died_at < 0 and not state.actors[&"human"].alive: died_at = state.tick
	_expect(died_at == 265, "an open crocodile eats a robot on its cell on the first open tick")
	_expect(not game.pickups().has(Vector2i(12, 5)), "it also eats pickups")

	game = _round("ZooStage1", {&"human": {"cell": Vector2i(4, 5), "shield": 1}, &"ai": {"cell": Vector2i(1, 1)}})
	for tick in 266: _step(game)
	_expect(game.actors()[&"human"].alive and game.actors()[&"human"].shield == 0, "a shield absorbs the bite")

	game = _round("ZooStage1", {&"human": {"cell": Vector2i(3, 5), "power": 3}, &"ai": {"cell": Vector2i(1, 1)}})
	var state := _step(game, {&"human": [&"down"]})
	var blast := {}
	for tick in 80:
		state = _step(game)
		for flame in state.flames: for cell in flame.cells: blast[cell] = true
	_expect(blast.has(Vector2i(4, 5)) and blast.has(Vector2i(5, 5)), "blasts pass through a crocodile")
	var view: Dictionary = game.snapshot()
	for tick in 200: view = _step(game)
	var seen := Perception.observe(view, &"ai", {}, 12)
	_expect(seen.danger.get(Vector2i(4, 5)) == 0 and Vector2i(4, 5) not in seen.free, "AI reads an open crocodile as danger and never roams onto one")


func _toy_hands() -> void:
	var game := _round("BirthdayPartyStage1", {&"human": {"cell": Vector2i(8, 4)}, &"ai": {"cell": Vector2i(1, 1)}})
	var hand_state := func(): return game.snapshot().features.filter(func(f): return f.kind == &"toy_hand" and f.cell == Vector2i(8, 2))[0]
	_expect(game.board().get(Vector2i(8, 2)) == &"solid", "the hand cell holds an invisible solid box")
	for tick in 104: _step(game)
	_expect(not hand_state.call().open, "hands stay shut for 104 ticks")
	_step(game)
	var hand: Dictionary = hand_state.call()
	_expect(hand.open and hand.reach == 1, "at tick 105 the hand opens and reaches up to the robot in front (observed)")
	var start: Vector2 = game.actors()[&"human"].position
	var pushed_at := -1
	for tick in 13:
		var state := _step(game)
		if pushed_at < 0 and not game.actors()[&"human"].get("pushed", {}).is_empty(): pushed_at = state.tick
	_expect(pushed_at == 105 + 9, "the push lands on the clip's pushComplete frame (down, reach 1: frame 10)")
	_expect(not hand_state.call().open, "the hand closes 13 ticks after opening (observed)")
	for tick in 40: _step(game)
	var landed: Vector2 = game.actors()[&"human"].position
	_expect(landed.x == start.x and landed.y > start.y and game.actors()[&"human"].get("pushed", {}).is_empty() and game.board().get(Vector2i(landed + Vector2(0, 1))) != &"floor",
		"a pushed robot slides until the next cell blocks, then stops")
	_expect(game.actors()[&"human"].alive, "pushing does not hurt")

	game = _round("BirthdayPartyStage1", {&"human": {"cell": Vector2i(1, 1)}, &"ai": {"cell": Vector2i(15, 13)}})
	game.add_bomb({"actor_id": &"", "cell": Vector2i(8, 4), "power": 1, "fuse": 400})
	game.pickups()[Vector2i(8, 3)] = &"power"
	for tick in 117: _step(game)
	var bomb: Dictionary = game.bombs()[0]
	_expect(bomb.get("flying", false) or bomb.cell != Vector2i(8, 4), "a bomb in reach is thrown")
	_expect(not game.pickups().has(Vector2i(8, 3)), "pickups in the arm's reach are destroyed")
	var age: int = bomb.age
	for tick in 4: _step(game)
	_expect(bomb.age == age or not bomb.get("flying", false), "a thrown bomb's fuse pauses in flight")
	for tick in 40: _step(game)
	_expect(not bomb.get("flying", false) and game.board().get(bomb.cell + Vector2i.DOWN) != &"floor", "it lands in front of the next obstacle")

	var delays := {}
	var hand_model = load("res://scripts/simulation/features/toy_hand.gd").new(Vector2i(8, 2), "down")
	var fake := FakeRound.new()
	for open in 40:
		hand_model.current_frame = hand_model.total_frame - 1
		hand_model.is_open = false
		hand_model.advance(fake, {})
		delays[hand_model.total_frame] = true
	_expect(delays.keys().all(func(d): return d % 35 == 0 and d >= 70 and d <= 735), "later closed periods are 2-21 s in whole seconds")


func _belt() -> void:
	var game := _round("CandyFactoryStage1", {&"human": {"cell": Vector2i(1, 1)}, &"ai": {"cell": Vector2i(15, 13)}}, &"arcade", 7)
	var belt: Dictionary = game.snapshot().features.filter(func(f): return f.kind == &"belt")[0]
	_expect(belt.track.size() == 33 and belt.track[0] == Vector2i(8, 9) and belt.track[-1] == Vector2i(6, 11), "the 33-cell track runs from the machine exit (8,9) to (6,11)")
	var spawned_at := -1
	for tick in 215:
		var state := _step(game)
		if spawned_at < 0 and (state.pickups.has(Vector2i(8, 9)) or state.bombs.any(func(b): return b.cell == Vector2i(8, 9))): spawned_at = state.tick
	_expect(spawned_at == 210, "the machine makes an item every 210 ticks (observed)")
	game.pickups().clear()
	for bomb in game.bombs().duplicate(): game.vanish_bomb(bomb)
	game.pickups()[Vector2i(8, 9)] = &"speed"
	var placed_at: int = game.current_tick()
	var reached := {}
	for tick in 120:
		var state := _step(game)
		for cell in state.pickups:
			if state.pickups[cell] == &"speed" and not reached.has(cell): reached[cell] = state.tick
	# Float steps of 1/30 cell drift by a tick against the original's twip positions.
	_expect(reached.get(Vector2i(8, 10), 0) - placed_at == 15 and absi(reached.get(Vector2i(8, 11), 0) - reached.get(Vector2i(8, 10), 0) - 30) <= 1
		and absi(reached.get(Vector2i(9, 11), 0) - reached.get(Vector2i(8, 11), 0) - 21) <= 1,
		"items ride 30 ticks per straight cell and about 21 per corner (observed)")

	game = _round("CandyFactoryStage1", {&"human": {"cell": Vector2i(12, 8)}, &"ai": {"cell": Vector2i(1, 1)}})
	var before: Vector2 = game.actors()[&"human"].position
	for tick in 15: _step(game)
	_expect(game.actors()[&"human"].position.y < before.y, "an idle robot rides the belt")
	game = _round("CandyFactoryStage1", {&"human": {"cell": Vector2i(12, 8)}, &"ai": {"cell": Vector2i(1, 1)}})
	before = game.actors()[&"human"].position
	for tick in 15: _step(game, {}, {&"human": Vector2.RIGHT})
	_expect(game.actors()[&"human"].position.y == before.y, "holding across the belt cancels its push")

	game = _round("CandyFactoryStage1", {&"human": {"cell": Vector2i(1, 1)}, &"ai": {"cell": Vector2i(15, 13)}})
	game.add_bomb({"actor_id": &"", "cell": Vector2i(5, 11), "power": 1, "fuse": 900, "belt_position": Vector2(5, 11)})
	for tick in 60: _step(game)
	_expect(game.bombs().is_empty(), "a bomb reaching the track's end disappears without exploding")
	var fuses := []
	for seed_value in 12:
		game = _round("CandyFactoryStage1", {&"human": {"cell": Vector2i(1, 1)}, &"ai": {"cell": Vector2i(15, 13)}}, &"arcade", seed_value)
		for tick in 211: _step(game)
		for bomb in game.bombs(): fuses.append([bomb.actor_id, bomb.fuse])
	_expect(not fuses.is_empty() and fuses.all(func(f): return f[0] == &"" and f[1] >= 0 and f[1] < 990), "belt bombs are ownerless with a 0-989 tick fuse")
	var kill_items := true
	for seed_value in 8:
		game = _round("CandyFactoryStage1", {&"human": {"cell": Vector2i(1, 1)}, &"ai": {"cell": Vector2i(15, 13)}}, &"kill", seed_value)
		for tick in 211: _step(game)
		kill_items = kill_items and game.bombs().is_empty() and game.pickups().has(Vector2i(8, 9))
	_expect(kill_items, "in Kill the machine only makes pickups")


func _spellbook() -> void:
	var game := _round("MagicLibraryStage1", {&"human": {"cell": Vector2i(1, 1)}, &"ai": {"cell": Vector2i(15, 13)}}, &"arcade", 3)
	var signs_at := -1
	var dropped: Array = []
	for tick in 482:
		var before: int = game.bombs().size() + game.pickups().size()
		var state := _step(game)
		var book: Dictionary = state.features.filter(func(f): return f.kind == &"spellbook")[0]
		if signs_at < 0 and not book.signs.is_empty():
			signs_at = state.tick
			dropped = book.signs
		if state.tick == 481:
			_expect(game.bombs().size() + game.pickups().size() > before or dropped.is_empty(), "items drop at tick 481")
	_expect(signs_at == 451 and dropped.size() == 2, "the book opens at 450 and marks two cells at 451 (observed drop at 481)")
	if dropped.size() == 2:
		var a: Vector2i = dropped[0].cell
		var b: Vector2i = dropped[1].cell
		var quadrant := func(c: Vector2i): return (0 if c.y < 7 else 3) if c.x < 8 else (1 if c.y < 7 else 2)
		_expect(quadrant.call(a) != quadrant.call(b) and (absi(a.x - b.x) > 1 or absi(a.y - b.y) > 1), "the two cells sit in different quadrants and do not touch")
	var book_bombs: Array = game.bombs().filter(func(bomb): return bomb.actor_id == &"")
	_expect(book_bombs.all(func(bomb): return bomb.get("fuse", 72) == 72), "spellbook bombs are ownerless with the normal fuse (observed)")
	var kill_items := true
	for seed_value in 6:
		game = _round("MagicLibraryStage1", {&"human": {"cell": Vector2i(1, 1)}, &"ai": {"cell": Vector2i(15, 13)}}, &"kill", seed_value)
		for tick in 482: _step(game)
		kill_items = kill_items and game.bombs().filter(func(bomb): return bomb.actor_id == &"").is_empty()
	_expect(kill_items, "in Kill the spellbook only drops pickups")


func _rides() -> void:
	var board := _box_board()
	board[Vector2i(4, 2)] = &"soft"
	var game := Simulation.new([&"human"], {&"human": {"cell": Vector2i(3, 2), "vehicle": &"horse", "drive_speed": 1.6}}, board,
		{"movement": true, "damage": true})
	var jumped_at := -1
	for tick in 60:
		var state := game.advance([{"actor_id": &"human", "direction": Vector2.RIGHT, "bomb_events": []}])
		if jumped_at < 0 and state.actors[&"human"].cell == Vector2i(5, 2): jumped_at = state.tick
	_expect(jumped_at > 0 and game.board()[Vector2i(4, 2)] == &"soft", "a horse jumps over a box it runs into")
	board = _box_board()
	board[Vector2i(4, 2)] = &"soft"
	board[Vector2i(5, 2)] = &"solid"
	game = Simulation.new([&"human"], {&"human": {"cell": Vector2i(3, 2), "vehicle": &"horse", "drive_speed": 1.6}}, board, {"movement": true})
	for tick in 40: game.advance([{"actor_id": &"human", "direction": Vector2.RIGHT, "bomb_events": []}])
	_expect(game.actors()[&"human"].cell == Vector2i(3, 2), "it cannot land on a box")
	board = _box_board()
	board[Vector2i(4, 2)] = &"soft"
	game = Simulation.new([&"human"], {&"human": {"cell": Vector2i(3, 2), "vehicle": &"dragon", "drive_speed": 1.28}}, board,
		{"movement": true, "damage": true})
	for tick in 20: game.advance([{"actor_id": &"human", "direction": Vector2.RIGHT, "bomb_events": []}])
	_expect(game.board()[Vector2i(4, 2)] == &"floor" and game.actors()[&"human"].score == 10, "a dragon breaks soft boxes it runs into and scores them")
	var actor := {"speed": 1.6, "score": 0}
	Pickups.apply(actor, &"horse", 0)
	var horse: float = actor.drive_speed
	Pickups.apply(actor, &"dragon", 0)
	_expect(is_equal_approx(horse, 1.6) and is_equal_approx(actor.drive_speed, 1.28), "rides XML: horse x1, dragon x0.8")
	_expect(Simulation.CAPPED_VEHICLES.has(&"horse") and not Simulation.CAPPED_VEHICLES.has(&"dragon"), "box drops cap horses with cars and motos, never dragons")


func _sets() -> void:
	_expect(StageSets.available_sets() == StageSets.ORDER, "all six stage sets are offered")
	var arcade_magic: RefCounted = Modes.create(&"arcade", &"normal", &"magic_library")
	var arcade_candy: RefCounted = Modes.create(&"arcade", &"normal", &"candy_factory")
	_expect(arcade_magic.timed_pickup_count(60 * 35) == 0 and arcade_candy.timed_pickup_count(60 * 35) == 1,
		"Arcade timed pickups: one in Candy Factory, none in Magic Library")
	_expect(Layouts.roll("CandyFactoryStage_PacMan_1", 0.0, _rng(1)).features.is_empty(), "Pac-Man Candy Factory layouts have no belt")


func _level() -> void:
	var app_game = load("res://scripts/game.gd").new()
	var session := Session.new(3)
	session.stage = &"zoo"
	session.begin()
	app_game.session = session
	app_game.auto_start = false
	root.add_child(app_game)
	await process_frame
	app_game.set_process(false)
	app_game.play_level()
	var snapshot: Dictionary = app_game.get_snapshot()
	_expect(snapshot.features.size() == 4 and snapshot.features.all(func(f): return f.kind == &"crocodile"), "a Zoo level runs its crocodiles")
	app_game.queue_free()
	await process_frame


func _round(layout: String, actors: Dictionary, mode_name: StringName = &"arcade", seed_value := 4) -> RefCounted:
	var board: Dictionary = Layouts.roll(layout, 0.0, _rng(seed_value))
	var ids: Array[StringName] = []
	ids.assign(actors.keys())
	var mode: RefCounted = Modes.create(mode_name, &"normal", board.skin)
	return Simulation.new(ids, actors, board.cells, {"movement": true, "damage": true, "drops": true, "seed": seed_value,
		"mode": mode, "features": board.features, "center": board.center, "skin": board.skin, "portals": board.portals,
		"vehicles": StageSets.vehicles(board.skin)})


func _box_board() -> Dictionary:
	var cells := {}
	for x in 9:
		for y in 5:
			cells[Vector2i(x, y)] = &"solid" if x == 0 or y == 0 or x == 8 or y == 4 else &"floor"
	return cells


func _step(game: RefCounted, events: Dictionary = {}, directions: Dictionary = {}) -> Dictionary:
	var commands: Array[Dictionary] = []
	for id in game.snapshot().actors:
		commands.append({"actor_id": id, "direction": directions.get(id, Vector2.ZERO), "bomb_events": events.get(id, [])})
	return game.advance(commands)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


class FakeRound extends RefCounted:
	var _rng := RandomNumberGenerator.new()

	func draw_random() -> float:
		return _rng.randf()

	func board() -> Dictionary:
		return {}

	func bombs() -> Array[Dictionary]:
		return []

	func actors() -> Dictionary:
		return {}


func _expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr(label)


func _finish() -> void:
	print("%s: %d stage feature checks" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)

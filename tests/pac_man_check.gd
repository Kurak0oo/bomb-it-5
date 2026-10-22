extends SceneTree
## Pac-Man through the real round (#69); observed original in edition-5-pac-man.md.

const Simulation = preload("res://scripts/simulation/bomb_simulation.gd")
const PacManMode = preload("res://scripts/simulation/modes/pac_man_mode.gd")
const AIProfiles = preload("res://scripts/simulation/ai_profiles.gd")
const AI = preload("res://scripts/simulation/ai_controller.gd")
const Layouts = preload("res://scripts/simulation/layouts.gd")
const BoardData = preload("res://scripts/simulation/board_data.gd")
const Session = preload("res://scripts/session.gd")
const ITEM_KINDS: Array[StringName] = [&"speed", &"life", &"shield", &"invincible"]
var failures := 0
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var opening_ok := true
	for seed_value in 12:
		var mode := PacManMode.new()
		var board: Dictionary = Layouts.roll("CinemaStage_PacMan_1", mode.soft_chance(), _rng(seed_value))
		var game := _board_round(mode, board, seed_value)
		var state: Dictionary = game.snapshot()
		var items: Array = state.pickups.keys().filter(func(cell): return state.pickups[cell] != &"coin")
		var quadrants := {}
		for cell in items: quadrants[(0 if cell.y < 7 else 3) if cell.x < 8 else (1 if cell.y < 7 else 2)] = true
		var spread := items.all(func(a): return items.all(func(b): return a == b or absi(a.x - b.x) > 1 or absi(a.y - b.y) > 1))
		opening_ok = opening_ok and items.size() == 4 and quadrants.size() == 4 and spread \
			and items.all(func(cell): return state.pickups[cell] in ITEM_KINDS) \
			and mode.coins_total == 121 and not state.pickups.has(Vector2i(1, 1)) and state.points_goal == 121
	_expect(opening_ok, "the opening places four pickups, one per quadrant and none adjacent, then 121 coins (observed)")

	var mode := PacManMode.new()
	var game := _open_round(mode, {&"human": {"cell": Vector2i(1, 1), "facing": Vector2.RIGHT}, &"ghost": {"cell": Vector2i(6, 3)}})
	var state: Dictionary = game.snapshot()
	_expect(state.actors[&"human"].weapon == &"none" and state.actors[&"ghost"].weapon == &"flamer" and state.actors[&"ghost"].ammo < 0,
		"the player has no action; ghosts carry an unlimited flamer")
	state = _step(game, {&"human": [&"down"]})
	_expect(state.bombs.is_empty() and state.attacks.is_empty(), "the action button does nothing in Pac-Man")
	var score: int = state.actors[&"human"].score
	game.pickups()[Vector2i(2, 1)] = &"coin"
	game.pickups()[Vector2i(5, 3)] = &"coin"
	_park(game, &"human", Vector2i(2, 1))
	state = _step(game, {})
	_expect(state.actors[&"human"].points == 1 and state.mode_state.eaten == 1 and not state.pickups.has(Vector2i(2, 1)), "walking over a coin eats it")
	_expect(state.actors[&"human"].score == score, "coins count toward the level score, not the item score")
	_park(game, &"ghost", Vector2i(5, 3))
	state = _step(game, {})
	_expect(state.pickups.get(Vector2i(5, 3)) == &"coin", "ghosts never eat")

	mode = PacManMode.new()
	game = _open_round(mode, {&"human": {"cell": Vector2i(3, 1)}, &"ghost": {"cell": Vector2i(1, 1), "facing": Vector2.RIGHT}})
	game.pickups()[Vector2i(2, 1)] = &"coin"
	_step(game, {&"ghost": [&"down"]})
	state = _run_ticks(game, 40)
	_expect(state.pickups.get(Vector2i(2, 1)) == &"coin", "ghost flames leave coins alone (PacModeWeapon destroyProp false)")
	_expect(not state.actors[&"human"].alive, "a ghost's flame kills the player")
	state = _run_ticks(game, 120)
	_expect(state.pending_outcome == &"lost" or state.outcome == &"lost", "the player's death loses the level")
	_expect(state.actors[&"human"].get("respawn_at", 0) <= 0, "the player does not respawn")

	mode = PacManMode.new()
	game = _open_round(mode, {&"human": {"cell": Vector2i(1, 1)}, &"ghost": {"cell": Vector2i(6, 3)}})
	game.pickups().clear()
	game.pickups()[Vector2i(2, 1)] = &"coin"
	mode.coins_total = mode.eaten + 1
	_park(game, &"human", Vector2i(2, 1))
	state = _step(game, {})
	_expect(state.round_stage == &"ending" and state.pending_outcome == &"won", "eating the last coin wins")
	state = _run_ticks(game, 120)
	_expect(state.outcome == &"won" and state.result_breakdown.kills == 10 and state.result_breakdown.difficulty == 2000,
		"a won level scores 10 per coin plus time and difficulty bonuses")

	mode = PacManMode.new()
	game = _open_round(mode, {&"human": {"cell": Vector2i(1, 1)}, &"ghost": {"cell": Vector2i(6, 3)}})
	game.pickups()[Vector2i(2, 1)] = &"invincible"
	_park(game, &"human", Vector2i(2, 1))
	state = _step(game, {})
	_expect(state.actors[&"human"].invincible_until == state.tick + 29 + 175, "invincibility lasts 5 s in Pac-Man")
	_park(game, &"human", Vector2i(6, 3))
	var removed_at := -1
	var back_at := -1
	for tick in 300:
		state = _step(game, {})
		if removed_at < 0 and state.actors[&"ghost"].get("removed", false): removed_at = state.tick
		if removed_at > 0 and back_at < 0 and state.actors[&"ghost"].alive: back_at = state.tick
	_expect(removed_at > 0 and back_at - removed_at == 35, "an invincible player knocks out ghosts, which return after 1 s")
	_expect(state.actors[&"ghost"].cell == Vector2i(6, 3), "ghosts return at their spawn")

	var easy := PacManMode.new(&"easy")
	_expect(easy.opening_pickups(Vector2i(1, 1)) == {Vector2i(1, 1): &"shield"} and PacManMode.new().opening_pickups(Vector2i(1, 1)).is_empty(),
		"Easy puts a shield on the player's spawn")
	_expect(not PacManMode.new().bomb_hits(false) and PacManMode.new().bomb_hits(true), "bombs and flames skip ghosts")
	_expect(PacManMode.new().timed_pickup_count(15 * 35) == 2 and PacManMode.new().timed_pickup_count(10 * 35) == 0
		and PacManMode.new(&"normal", &"magic_library").timed_pickup_count(15 * 35) == 0, "two timed pickups every 15 s after 10 s, none in Magic Library")
	_expect(PacManMode.new().judge(FakeRound.new({"alive": true}), false, 6300) == &"lost", "time running out loses")
	var weights: Dictionary = PacManMode.new().drop_weights()
	_expect(weights.values().reduce(func(a, b): return a + b) == 100 and weights[&"speed"] == 40 and weights[&"invincible"] == 30,
		"Pac-Man pickups follow the PacManMode prop table")

	_expect(AI.regions(Vector2i(1, 1)) == [&"A"] and AI.regions(Vector2i(15, 1)) == [&"C"] and AI.regions(Vector2i(8, 7)).size() == 4,
		"RegionDivide splits the board into four overlapping areas")
	var follow_view := _view({&"human": Vector2i(1, 1), &"ghost": Vector2i(15, 1)})
	var ghost := AI.new(3, [], AIProfiles.for_mode(&"pac_man", &"hard"))
	ghost.command(follow_view, &"ghost")
	_expect(ghost._followed(follow_view, &"ghost") == &"", "a ghost ignores a player outside its manager area")
	follow_view.actors[&"human"].cell = Vector2i(12, 3)
	_expect(ghost._followed(follow_view, &"ghost") == &"human", "a ghost follows a player inside its manager area")
	follow_view.actors[&"human"].invincible_until = 50
	_expect(ghost._followed(follow_view, &"ghost") == &"", "no ghost follows while a robot in its area is invincible")

	mode = PacManMode.new(&"hard")
	var board: Dictionary = Layouts.roll("CinemaStage_PacMan_1", 0.0, _rng(4))
	var ids: Array[StringName] = [&"human", &"g1", &"g2", &"g3"]
	var actors := {&"human": {"cell": Vector2i(12, 3)}}
	var profile: Dictionary = AIProfiles.for_mode(&"pac_man", &"hard")
	for index in 3:
		actors[ids[index + 1]] = {"cell": board.spawns[index + 1], "speed": profile.speed, "power": profile.power, "capacity": profile.capacity}
	game = Simulation.new(ids, actors, board.cells, {"movement": true, "damage": true, "drops": true, "round": true,
		"seed": 4, "mode": mode, "portals": board.portals})
	var ai := AI.new(4, [], profile)
	var caught := false
	for tick in 2100:
		var view: Dictionary = game.snapshot()
		var commands: Array[Dictionary] = [{"actor_id": &"human", "direction": Vector2.ZERO, "bomb_events": []}]
		for id in ids.slice(1):
			var command: Dictionary = ai.command(view, id)
			commands.append({"actor_id": id, "direction": command.direction, "bomb_events": command.bomb_events})
		state = game.advance(commands)
		if not state.actors[&"human"].alive:
			caught = true
			break
	_expect(caught, "Hard ghosts hunt down an idle player standing in their area")
	_expect(state.pickups.values().count(&"coin") == mode.coins_total - mode.eaten, "ghost flames destroyed no coins on the way")

	var app_game = load("res://scripts/game.gd").new()
	var session := Session.new(3)
	session.mode = &"pac_man"
	session.stage = &"cinema"
	session.begin()
	app_game.session = session
	app_game.auto_start = false
	root.add_child(app_game)
	await process_frame
	app_game.set_process(false)
	app_game.play_level()
	var snapshot: Dictionary = app_game.get_snapshot()
	_expect(String(snapshot.board_meta.layout).contains("_PacMan_") and snapshot.actors[&"human"].weapon == &"none"
		and snapshot.pickups.values().count(&"coin") == snapshot.points_goal and snapshot.points_goal > 100,
		"a Pac-Man level loads a Pac-Man layout full of coins")
	app_game.queue_free()
	await process_frame
	_finish()


func _open_round(mode: RefCounted, actors: Dictionary) -> RefCounted:
	var cells := {}
	for x in 9:
		for y in 6:
			cells[Vector2i(x, y)] = &"solid" if x == 0 or y == 0 or x == 8 or y == 5 else &"floor"
	var ids: Array[StringName] = []
	ids.assign(actors.keys())
	return Simulation.new(ids, actors, cells, {"movement": true, "damage": true, "drops": true, "round": true,
		"seed": 3, "mode": mode})


func _board_round(mode: RefCounted, board: Dictionary, seed_value: int) -> RefCounted:
	var ids: Array[StringName] = [&"human", &"g1", &"g2", &"g3"]
	var actors := {}
	for index in ids.size(): actors[ids[index]] = {"cell": board.spawns[index]}
	return Simulation.new(ids, actors, board.cells, {"movement": true, "damage": true, "drops": true, "round": true,
		"seed": seed_value, "mode": mode, "portals": board.portals})


func _view(cells: Dictionary) -> Dictionary:
	var view := {"tick": 1, "board": {}, "fire": [], "bombs": [], "bomb_occupancy": [], "pickups": {}, "actors": {},
		"outcome": &"running", "round_stage": &"playing"}
	for x in 17:
		for y in 15:
			view.board[Vector2i(x, y)] = &"solid" if x == 0 or y == 0 or x == 16 or y == 14 else &"floor"
	for id in cells:
		view.actors[id] = {"cell": cells[id], "position": Vector2(cells[id]), "alive": true, "protected_until": 0,
			"invincible_until": 0, "is_human": id == &"human", "transit_until": 0, "busy_until": 0,
			"capacity": 1, "power": 2, "weapon": &"flamer", "bomb_count": 0}
	return view


func _park(game: RefCounted, id: StringName, cell: Vector2i) -> void:
	game.actors()[id].cell = cell
	game.actors()[id].position = Vector2(cell)


func _step(game: RefCounted, events: Dictionary) -> Dictionary:
	var commands: Array[Dictionary] = []
	for id in game.snapshot().actors:
		commands.append({"actor_id": id, "direction": Vector2.ZERO, "bomb_events": events.get(id, [])})
	return game.advance(commands)


func _run_ticks(game: RefCounted, ticks: int) -> Dictionary:
	var state: Dictionary = {}
	for tick in ticks: state = _step(game, {})
	return state


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


class FakeRound extends RefCounted:
	var _human: Dictionary

	func _init(human_actor: Dictionary) -> void:
		_human = human_actor

	func human() -> Dictionary:
		return _human


func _expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr(label)


func _finish() -> void:
	print("%s: %d pac-man checks" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)

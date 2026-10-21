extends SceneTree
## Kill mode through the real round (#67); observed original in edition-5-kill-mode.md.

const Simulation = preload("res://scripts/simulation/bomb_simulation.gd")
const KillMode = preload("res://scripts/simulation/modes/kill_mode.gd")
const Perception = preload("res://scripts/simulation/ai_perception.gd")
const Layouts = preload("res://scripts/simulation/layouts.gd")
var failures := 0
var checks := 0


func _initialize() -> void:
	var game := _round({&"human": {"cell": Vector2i(1, 1), "facing": Vector2.RIGHT}, &"ai": {"cell": Vector2i(2, 1)}})
	var state: Dictionary = game.snapshot()
	_expect(state.actors[&"human"].weapon == &"hammer" and state.actors[&"ai"].weapon == &"hammer", "everyone's action is the hammer")
	state = _step(game, {&"human": [&"down"]})
	_expect(state.bombs.is_empty() and state.attacks.size() == 1, "the action button swings the hammer instead of placing a bomb")
	state = _run(game, 30)
	_expect(not state.actors[&"ai"].alive and state.actors[&"human"].kills == 1 and state.actors[&"human"].points == 1,
		"a hammer kill scores a point")
	_expect(state.actors[&"human"].weapon == &"hammer" and state.actors[&"human"].ammo < 0, "the base hammer never runs out")
	var removed_at := -1
	var back_at := -1
	for tick in 140:
		state = _step(game, {})
		if removed_at < 0 and state.actors[&"ai"].removed: removed_at = state.tick
		if back_at < 0 and state.actors[&"ai"].alive: back_at = state.tick
	_expect(removed_at > 0 and back_at - removed_at == 35, "the dead respawn 35 ticks (1 s) after their death animation")
	var ai: Dictionary = state.actors[&"ai"]
	_expect(ai.cell == Vector2i(2, 1) and ai.weapon == &"hammer", "respawn returns to the spawn with the base hammer")
	_expect(ai.protected_until == back_at + 81 and ai.blink_until == back_at + 81,
		"a respawned robot is protected for InvincibilityCommand's 81 ticks")

	game = _round({&"human": {"cell": Vector2i(1, 1), "facing": Vector2.RIGHT, "weapon": &"flamer", "ammo": 2},
		&"ai": {"cell": Vector2i(6, 3)}})
	for use in 2:
		_step(game, {&"human": [&"down"]})
		state = _run(game, 30)
	_expect(state.actors[&"human"].weapon == &"hammer", "a spent pickup weapon falls back to the hammer")

	game = _round({&"human": {"cell": Vector2i(1, 1), "facing": Vector2.RIGHT, "kills": 9}, &"ai": {"cell": Vector2i(2, 1)}})
	_step(game, {&"human": [&"down"]})
	state = _run(game, 100)
	_expect(state.round_stage == &"ending" and state.pending_outcome == &"won", "the human's 10th kill wins after the death animation")
	state = _run(game, 110)
	_expect(state.outcome == &"won" and state.result_breakdown.kills == 1000, "a Kill level scores 100 per kill plus bonuses")

	game = _round({&"human": {"cell": Vector2i(2, 1)}, &"ai": {"cell": Vector2i(1, 1), "facing": Vector2.RIGHT, "kills": 9}})
	_step(game, {&"ai": [&"down"]})
	state = _run(game, 100)
	_expect(state.pending_outcome == &"lost", "an AI's 10th kill loses the level")
	_expect(not state.actors[&"human"].alive or state.actors[&"human"].removed, "the human died to it")

	var mode := KillMode.new()
	var rows := [[{"kills": 3}, [{"kills": 3}], &"won"], [{"kills": 2}, [{"kills": 3}], &"lost"], [{"kills": 4}, [{"kills": 1}, {"kills": 4}], &"won"]]
	for row in rows:
		_expect(mode.judge(FakeRound.new(row[0], row[1]), false, 6300) == row[2], "timeout: the human wins unless an AI has more kills (%s)" % row[2])
	var actor := {"kills": 2}
	mode.on_self_kill(actor)
	_expect(actor.kills == 1, "dying to one's own attack costs a kill")
	actor = {"kills": 0}
	mode.on_self_kill(actor)
	_expect(actor.kills == 0, "a self-kill never goes below zero")

	game = _round({&"human": {"cell": Vector2i(1, 1), "facing": Vector2.RIGHT}, &"ai": {"cell": Vector2i(2, 1)}})
	_step(game, {})
	game._actors[&"ai"].collected = [&"speed", &"power"]
	game._actors[&"ai"].kept_weapons = [&"flamer", &"laser", &"triple"]
	_step(game, {&"human": [&"down"]})
	state = _run(game, 100)
	var kinds: Array = state.pickups.values()
	_expect(kinds.count(&"speed") == 1 and kinds.count(&"power") == 1 and state.pickups.size() == 4,
		"a death scatters collected power-ups and two kept weapons")

	_expect(KillMode.new().drop_weights()[&"capacity"] == 0 and KillMode.new().drop_weights()[&"flamer"] == 15, "Kill drops follow the KillMode prop table")
	_expect(is_equal_approx(KillMode.new().soft_chance(), 0.55), "Kill boards roll soft blocks at 0.55 (observed)")
	_expect(KillMode.new(&"normal", &"magic_library").timed_pickup_count(60 * 35) == 0 and KillMode.new().timed_pickup_count(60 * 35) == 2,
		"Kill timed pickups: two, none in Magic Library")

	var view := {"tick": 1, "board": {}, "fire": [], "bombs": [], "bomb_occupancy": [], "pickups": {},
		"actors": {&"human": {"cell": Vector2i(1, 1), "alive": true, "protected_until": 0},
			&"ai": {"cell": Vector2i(2, 1), "alive": true, "protected_until": 0},
			&"rival": {"cell": Vector2i(3, 1), "alive": true, "protected_until": 0}}}
	for x in 6:
		for y in 3:
			view.board[Vector2i(x, y)] = &"floor"
	_expect(Perception.observe(view, &"ai", {}, 6, true).enemies.size() == 2 and Perception.observe(view, &"ai", {}, 6, false).enemies.size() == 1,
		"Kill AI targets every robot; Arcade AI only the human")
	_finish()


func _round(actors: Dictionary) -> RefCounted:
	var cells := {}
	for x in 8:
		for y in 5:
			cells[Vector2i(x, y)] = &"solid" if x == 0 or y == 0 or x == 7 or y == 4 else &"floor"
	var ids: Array[StringName] = []
	ids.assign(actors.keys())
	return Simulation.new(ids, actors, cells, {"movement": true, "damage": true, "drops": true, "round": true,
		"seed": 3, "mode": KillMode.new()})


func _step(game: RefCounted, events: Dictionary) -> Dictionary:
	var commands: Array[Dictionary] = []
	for id in game.snapshot().actors:
		commands.append({"actor_id": id, "direction": Vector2.ZERO, "bomb_events": events.get(id, [])})
	return game.advance(commands)


func _run(game: RefCounted, ticks: int) -> Dictionary:
	var state: Dictionary = {}
	for tick in ticks:
		state = _step(game, {})
	return state


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
	print("%s: %d kill checks" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)

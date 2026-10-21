extends SceneTree
## Mode, board-data and AI-profile seams (ADR 0007) through the real round.

const Simulation = preload("res://scripts/simulation/bomb_simulation.gd")
const BoardData = preload("res://scripts/simulation/board_data.gd")
const ArcadeMode = preload("res://scripts/simulation/modes/arcade_mode.gd")
const AIProfiles = preload("res://scripts/simulation/ai_profiles.gd")
const AI = preload("res://scripts/simulation/ai_controller.gd")
var failures := 0
var checks := 0


class ScriptedMode extends "res://scripts/simulation/modes/game_mode.gd":
	var end_tick := 3
	var weights := {&"power": 1}
	var timed := {}

	func drop_weights() -> Dictionary:
		return weights

	func timed_pickup_count(tick: int) -> int:
		return timed.get(tick, 0)

	func judge(_round: RefCounted, _ready: bool, tick: int) -> StringName:
		return &"won" if tick >= end_tick else &""

	func settle(_round: RefCounted, _outcome: StringName, _end: int) -> int:
		return 777


func _initialize() -> void:
	var board: Dictionary = BoardData.load_instance("res://assets/maps/cinema-stage1.csv")
	var counts := {}
	for cell in board.cells:
		counts[board.cells[cell]] = counts.get(board.cells[cell], 0) + 1
	_expect(board.size == Vector2i(17, 15), "recorded instance is 17x15")
	_expect(counts == {&"solid": 125, &"soft": 68, &"floor": 58, &"portal": 4}, "recorded instance keeps its audited counts")
	_expect(board.portals.get(Vector2i(8, 1)) == Vector2i(8, 13) and board.portals.get(Vector2i(12, 7)) == Vector2i(4, 7), "portal pairs come from the board data")
	_expect(board.spawns == [Vector2i(1, 1), Vector2i(15, 1), Vector2i(1, 13), Vector2i(15, 13)], "spawns are the four corners")

	var game := Simulation.new([&"human", &"ai"], {&"human": {"cell": Vector2i(1, 1)}, &"ai": {"cell": Vector2i(15, 13)}},
		board.cells, {"round": true, "portals": board.portals})
	_expect(game.snapshot().mode == &"arcade", "the round defaults to the Arcade mode module")

	var scripted := ScriptedMode.new()
	game = Simulation.new([&"human", &"ai"], {&"human": {"cell": Vector2i(1, 1)}, &"ai": {"cell": Vector2i(15, 13)}},
		board.cells, {"round": true, "mode": scripted})
	var state: Dictionary = {}
	for tick in 3:
		state = game.advance(_commands())
	_expect(state.round_stage == &"ending" and state.pending_outcome == &"won", "an injected mode decides the ending")
	for tick in 105:
		state = game.advance(_commands())
	_expect(state.outcome == &"won" and state.result_score == 777, "an injected mode settles the level score")

	scripted = ScriptedMode.new()
	scripted.end_tick = 99999
	scripted.timed = {2: 3}
	game = Simulation.new([&"human"], {&"human": {"cell": Vector2i(1, 1)}}, board.cells,
		{"drops": true, "mode": scripted, "seed": 9})
	for tick in 2:
		state = game.advance([{"actor_id": &"human", "direction": Vector2.ZERO, "bomb_events": []}])
	_expect(state.pickups.size() == 3, "timed pickups use the mode's count")
	_expect(state.pickups.values().all(func(kind): return kind == &"power"), "drops draw from the mode's weights")

	var arcade := ArcadeMode.new()
	_expect(arcade.timed_pickup_count(45 * 35) == 0 and arcade.timed_pickup_count(60 * 35) == 2, "Arcade timed pickups start after 45 s")
	_expect(ArcadeMode.new(&"normal", &"candy_factory").timed_pickup_count(60 * 35) == 1, "Arcade gives Candy Factory one timed pickup")
	_expect(is_equal_approx(arcade.soft_chance(), 0.6), "Arcade soft-block chance is 0.6")

	_expect(AIProfiles.PROFILES.size() == 12, "twelve GameAI profiles")
	var hard_kill: Dictionary = AIProfiles.for_mode(&"kill", &"hard")
	_expect(hard_kill.answer_ms == 10 and hard_kill.find_range == 7 and hard_kill.power == 2, "Kill Hard profile follows XML 020301")
	var normal: Dictionary = AIProfiles.for_mode(&"arcade", &"normal")
	var chances: Array = normal.states.map(func(entry): return float(entry.chance))
	_expect(chances == [0.6, 0.8, 0.8, 0.7, 0.8, 1.0], "Normal Arcade state chances match the earlier constants")
	_expect(AI.new(1, [], AIProfiles.for_mode(&"pac_man", &"easy")).profile.find_range == 8, "the controller keeps its supplied profile")
	_finish()


func _commands() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id in [&"human", &"ai"]:
		result.append({"actor_id": id, "direction": Vector2.ZERO, "bomb_events": []})
	return result


func _expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr(label)


func _finish() -> void:
	print("%s: %d mode seam checks" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)

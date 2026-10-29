extends SceneTree
## #84: the AI against the traced original in every mode and difficulty
## (docs/evidence/edition-5-ai-modes.md; profiles in tests/fixtures/ai-profiles-traced.json).

const Simulation = preload("res://scripts/simulation/bomb_simulation.gd")
const AIProfiles = preload("res://scripts/simulation/ai_profiles.gd")
const AI = preload("res://scripts/simulation/ai_controller.gd")
const Modes = preload("res://scripts/simulation/modes/modes.gd")
const GreenZoneMode = preload("res://scripts/simulation/modes/green_zone_mode.gd")
const TRACED := "res://tests/fixtures/ai-profiles-traced.json"
const STATES := {"StateAttack": &"Attack", "StateEvade": &"Evade", "StateGetItem": &"GetItem", "StateBox": &"Box",
	"StateFree": &"Free", "StateIdel": &"Idle", "StateEscape": &"Escape", "StateFlag": &"Flag",
	"StateDefence": &"Defence", "StateFollow": &"Follow"}
var failures := 0
var checks := 0


func _initialize() -> void:
	_profiles()
	_answer_gate()
	_flag_and_defence()
	_follow()
	print("%s: %d ai trace checks" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)


## Every live profile the traces read (answer time, find range, state order, percentages,
## weapon delay, advance chances) equals the replica's table.
func _profiles() -> void:
	var traced: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TRACED))
	for key in traced:
		var live: Dictionary = traced[key]
		var parts: PackedStringArray = key.split("/")
		var ours: Dictionary = AIProfiles.for_mode(StringName(parts[0]), StringName(parts[1]))
		var problems: Array[String] = []
		if ours.answer_ms != live.answer_time: problems.append("answer %s vs %s" % [ours.answer_ms, live.answer_time])
		if ours.find_range != live.find_range: problems.append("range %s vs %s" % [ours.find_range, live.find_range])
		if ours.default_state != STATES[live.default]: problems.append("default")
		var order: Array = ours.states.map(func(entry): return entry.state)
		var live_order: Array = live.states.map(func(entry): return STATES[entry["class"]])
		if order != live_order: problems.append("order %s vs %s" % [order, live_order])
		else:
			for index in order.size():
				var entry: Dictionary = ours.states[index]
				var seen: Dictionary = live.states[index]
				if not is_equal_approx(float(entry.chance), float(seen.precentage)): problems.append("%s chance" % entry.state)
				if not is_equal_approx(float(entry.weapon_delay_ms), float(seen.weaponAttackDelay)): problems.append("%s delay" % entry.state)
				if entry.has("advance_attack") and not is_equal_approx(float(entry.advance_attack), float(seen.advanceAttack)):
					problems.append("%s advance attack" % entry.state)
				if entry.has("advance_dodge") and not is_equal_approx(float(entry.advance_dodge), float(seen.advanceDodge)):
					problems.append("%s advance dodge" % entry.state)
		_expect(problems.is_empty(), "%s profile matches the traced original %s" % [key, problems])


func _round(mode: RefCounted, actors: Dictionary) -> RefCounted:
	var cells := {}
	for x in 11:
		for y in 9:
			cells[Vector2i(x, y)] = &"solid" if x == 0 or y == 0 or x == 10 or y == 8 else &"floor"
	var ids: Array[StringName] = []
	ids.assign(actors.keys())
	return Simulation.new(ids, actors, cells, {"movement": false, "damage": true, "drops": true, "seed": 3, "mode": mode})


## `AIControl.update`: the first selected opportunity only caches `getTimer()`; every later
## one thinks, whatever the answer time (traced: no perception on each AI's first update).
func _answer_gate() -> void:
	for difficulty in [&"easy", &"hard"]:
		var round = _round(Modes.create(&"arcade", difficulty, &"cinema"), {&"human": {"cell": Vector2i(1, 1)}, &"ai": {"cell": Vector2i(9, 7)}})
		var ai = AI.new(1, [], AIProfiles.for_mode(&"arcade", difficulty))
		var first: bool = not ai.command(round.snapshot(), &"ai").observation.perception.is_empty()
		round.advance([{"actor_id": &"human", "direction": Vector2.ZERO, "bomb_events": []},
			{"actor_id": &"ai", "direction": Vector2.ZERO, "bomb_events": []}] as Array[Dictionary])
		var second: bool = not ai.command(round.snapshot(), &"ai").observation.perception.is_empty()
		_expect(not first and second, "%s: the first opportunity waits, the second thinks" % difficulty)


## StateFlag and StateDefence decide without a random draw; Defence bombs a rival on its cell.
func _flag_and_defence() -> void:
	var mode := GreenZoneMode.new()
	var round = _round(mode, {&"human": {"cell": Vector2i(1, 1)}, &"ai": {"cell": Vector2i(5, 4)}})
	mode.flag = Vector2i(5, 4)
	var ai = AI.new(1, [0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5], AIProfiles.for_mode(&"green_zone", &"easy"))
	ai.command(round.snapshot(), &"ai")
	var state: Dictionary = round.snapshot()
	state.tick += 1
	var observed: Dictionary = ai.command(state, &"ai").observation
	_expect(observed.state == &"Defence" and ai._draw_index == 0, "on the flag, Defence is chosen with no draw (%s, %d draws)" % [observed.state, ai._draw_index])
	round.actors()[&"human"].cell = Vector2i(5, 4)
	state = round.snapshot()
	state.tick += 2
	_expect(ai.command(state, &"ai").bomb_events == [&"down", &"up"], "Defence bombs a rival sharing the flag cell")


## StateFollow: chosen whenever a human shares the manager areas, even with every bomb out;
## spawn protection is not RobotState.INVINCIBLE, so it does not stop the chase.
func _follow() -> void:
	var round = _round(Modes.create(&"pac_man", &"normal", &"cinema"), {&"human": {"cell": Vector2i(3, 4)}, &"ai": {"cell": Vector2i(7, 4)}})
	round.actors()[&"human"].protected_until = 100000
	round.actors()[&"ai"].bomb_count = 1
	var ai = AI.new(1, [0.1, 0.0], AIProfiles.for_mode(&"pac_man", &"normal"))
	ai.command(round.snapshot(), &"ai")
	var state: Dictionary = round.snapshot()
	state.tick += 1
	var observed: Dictionary = ai.command(state, &"ai").observation
	_expect(observed.state == &"Follow" and observed.route.is_empty(), "Follow is chosen with every bomb out and walks nowhere (%s)" % observed.state)


func _expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr(label)

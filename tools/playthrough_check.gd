extends SceneTree
## Production round/scheduler/controllers on the full recorded board, without private-state writes.
## Arcade first (its three records unchanged), then one seeded full race for each of Kill,
## Green Zone and Pac-Man, plus the mode HUD counters. The Pac-Man scripted run has no AI and
## eats every coin; the idle run is caught by the real ghosts.

const Simulation = preload("res://scripts/simulation/bomb_simulation.gd")
const Scheduler = preload("res://scripts/simulation/tick_scheduler.gd")
const AI = preload("res://scripts/simulation/ai_controller.gd")
const AIProfiles = preload("res://scripts/simulation/ai_profiles.gd")
const Layouts = preload("res://scripts/simulation/layouts.gd")
const Modes = preload("res://scripts/simulation/modes/modes.gd")
const StageSets = preload("res://scripts/simulation/stage_sets.gd")
const DesktopPlayer = preload("res://tools/desktop_player.gd")
const SwfScreen = preload("res://scripts/ui/swf_screen.gd")
const GameInterFace = preload("res://scripts/ui/game_inter_face.gd")
const Session = preload("res://scripts/session.gd")
## `GameInterFace.setScore`/`mapLoadOver` suffixes, keyed by mode.
const DIFF_POINT := {&"easy": 1000, &"normal": 2000, &"hard": 3000}
const IDS: Array[StringName] = [&"human", &"ruby", &"mint", &"gold"]
const KILL_SEED := 1
const GREEN_ZONE_SEED := 45
const PAC_MAN_SEED := 1
## Pac-Man's Ghost RegionDivide areas cover the middle of the board; the corner spawn is
## outside every follow route, so the idle player stands on this central floor cell.
const PAC_MAN_IDLE_CELL := Vector2i(12, 3)
const MAX_TICKS := 6405
var failures: Array[String] = []


func _initialize() -> void:
	var started := Time.get_ticks_msec()
	var records := _arcade_records()
	records.append(_kill_record())
	records.append(_green_zone_record())
	var pac_man := _pac_man_records()
	records.append_array(pac_man)
	var path := ProjectSettings.globalize_path("res://.scratch/game-captures")
	DirAccess.make_dir_recursive_absolute(path)
	var log := FileAccess.open(path.path_join("playthroughs.json"), FileAccess.WRITE)
	log.store_string(JSON.stringify(records, "  "))
	if not failures.is_empty():
		printerr("Full-board playthroughs failed: ", failures)
		quit(1)
		return
	print("PASS: %d full-board playthrough checks %d ms %s" % [records.size(), Time.get_ticks_msec() - started,
		JSON.stringify(records)])
	quit(0)


func _arcade_records() -> Array[Dictionary]:
	var board: Dictionary = {}
	var csv := FileAccess.open("res://assets/maps/cinema-stage1.csv", FileAccess.READ)
	csv.get_csv_line()
	while not csv.eof_reached():
		var row := csv.get_csv_line()
		if row.size() >= 3: board[Vector2i(int(row[0]), int(row[1]))] = StringName(row[2])
	var records: Array[Dictionary] = []
	for seed_value in [2, 5, 42]:
		var actors := {&"human": {"cell": Vector2i(1, 1)}, &"ruby": {"cell": Vector2i(15, 1)},
			&"mint": {"cell": Vector2i(1, 13)}, &"gold": {"cell": Vector2i(15, 13)}}
		var game := Simulation.new(IDS, actors, board,
			{"movement": true, "damage": true, "portals": true, "drops": true, "round": true, "seed": seed_value})
		var scheduler := Scheduler.new(IDS, game)
		var brain := AI.new(seed_value)
		var human_driver := DesktopPlayer.new(seed_value)
		for id in IDS:
			scheduler.set_controller(id, _produce.bind(game, human_driver if id == &"human" else brain, id))
		if seed_value == 42:
			scheduler.set_controller(&"human", func(): return {"direction": Vector2.ZERO,
				"bomb_events": [&"down", &"up"] if game.snapshot().tick == 0 else []})
		var state: Dictionary = game.snapshot()
		var bomb_seen := false
		var started := Time.get_ticks_msec()
		for index in MAX_TICKS:
			scheduler.advance_time(1.0 / 35)
			state = game.snapshot()
			bomb_seen = bomb_seen or not state.bombs.is_empty()
			if state.outcome != &"running": break
		if state.outcome == &"running" or not bomb_seen:
			_fail("Full-board Arcade playthrough did not complete correctly: %d" % seed_value)
		records.append({"seed": seed_value, "tick": state.tick, "outcome": state.outcome,
			"human_input": "ordinary self-bomb then idle" if seed_value == 42 else "desktop command driver",
			"kills": state.actors[&"human"].kills, "score": state.result_score,
			"elapsed_ms": Time.get_ticks_msec() - started,
			"remaining_soft": state.board.values().count(&"soft")})
		scheduler.free()
	if not records.any(func(record): return record.outcome == &"won") or not records.any(func(record): return record.outcome == &"lost"):
		_fail("Full-board Arcade playthroughs must exercise both legitimate victory and defeat: " + JSON.stringify(records))
	return records


func _kill_record() -> Dictionary:
	var started := Time.get_ticks_msec()
	var run := _run_ai_mode(&"kill", &"hard", KILL_SEED, Vector2i(-1, -1))
	var state: Dictionary = run.state
	_expect(state.outcome != &"running", "Kill seed %d leaves the running stage" % KILL_SEED)
	_expect(state.actors[&"human"].points == 0, "Kill idle human stays on 0 kills")
	var winner := _leader(state)
	_expect(winner.points >= 10, "Kill seed %d: an AI reaches 10 kills (%d)" % [KILL_SEED, winner.points])
	_expect(state.outcome == (&"won" if winner.id == &"human" else &"lost"),
		"Kill seed %d: the outcome matches who reached 10 kills" % KILL_SEED)
	_expect(state.outcome == &"lost", "Kill seed %d: an AI's 10 kills lose the level" % KILL_SEED)
	_check_settle(state, &"hard", 100)
	_check_hud(&"kill", state)
	return _record(state, &"kill", KILL_SEED, started,
		{"human_input": "idle", "kills": state.actors[&"human"].points,
			"winner": String(winner.id), "winner_kills": winner.points})


func _green_zone_record() -> Dictionary:
	var started := Time.get_ticks_msec()
	var run := _run_ai_mode(&"green_zone", &"hard", GREEN_ZONE_SEED, Vector2i(-1, -1))
	var state: Dictionary = run.state
	_expect(state.outcome != &"running", "Green Zone seed %d leaves the running stage" % GREEN_ZONE_SEED)
	_expect(state.actors[&"human"].points == 0, "Green Zone idle human keeps the flag at 0 captures")
	var holder := _leader(state)
	_expect(holder.points >= 10, "Green Zone seed %d: a holder reaches 10 flags (%d)" % [GREEN_ZONE_SEED, holder.points])
	_expect(state.outcome == (&"won" if holder.id == &"human" else &"lost"),
		"Green Zone seed %d: the outcome matches who reached 10 flags" % GREEN_ZONE_SEED)
	_expect(state.outcome == &"lost", "Green Zone seed %d: an AI's 10 flags lose the level" % GREEN_ZONE_SEED)
	_check_settle(state, &"hard", 100)
	_check_hud(&"green_zone", state)
	return _record(state, &"green_zone", GREEN_ZONE_SEED, started,
		{"human_input": "idle", "flags": state.actors[&"human"].points,
			"holder": String(holder.id), "holder_flags": holder.points})


func _pac_man_records() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	var started := Time.get_ticks_msec()
	var idle := _run_ai_mode(&"pac_man", &"hard", PAC_MAN_SEED, PAC_MAN_IDLE_CELL)
	var state: Dictionary = idle.state
	_expect(state.outcome == &"lost", "Pac-Man seed %d: the idle human is caught and loses" % PAC_MAN_SEED)
	_expect(not state.actors[&"human"].alive, "Pac-Man seed %d: the idle human is dead" % PAC_MAN_SEED)
	_expect(int(state.mode_state.coins_total) == 121 and int(state.mode_state.eaten) < 121,
		"Pac-Man seed %d: 121 coins, the idle run eats only a part" % PAC_MAN_SEED)
	_check_settle(state, &"hard", 10)
	_check_hud(&"pac_man", state)
	records.append(_record(state, &"pac_man", PAC_MAN_SEED, started,
		{"run": "idle caught", "human_input": "idle", "eaten": state.mode_state.eaten,
			"coins": state.mode_state.coins_total}))

	started = Time.get_ticks_msec()
	state = _run_scripted_pac_man(PAC_MAN_SEED)
	_expect(state.outcome == &"won", "Pac-Man seed %d: the scripted run eats every coin and wins" % PAC_MAN_SEED)
	_expect(int(state.mode_state.eaten) == int(state.mode_state.coins_total),
		"Pac-Man seed %d: every coin is eaten" % PAC_MAN_SEED)
	_expect(int(state.mode_state.coins_total) == 121 and int(state.actors[&"human"].points) == 121,
		"Pac-Man seed %d: the won round scores 121 coins" % PAC_MAN_SEED)
	_check_settle(state, &"hard", 10)
	_check_hud(&"pac_man", state)
	records.append(_record(state, &"pac_man", PAC_MAN_SEED, started,
		{"run": "scripted eat every coin", "human_input": "scripted path to every coin",
			"eaten": state.mode_state.eaten, "coins": state.mode_state.coins_total}))
	return records


## A production-shaped mode round: rolled Cinema set, profile stats, spawn cells, the mode's
## own map-load draws (`Layouts.roll_set` then the mode's `begin`).
func _round_for(mode_name: StringName, difficulty: StringName, seed_value: int,
		ids: Array[StringName], human_cell: Vector2i) -> Dictionary:
	var mode: RefCounted = Modes.create(mode_name, difficulty, &"cinema")
	var profile: Dictionary = AIProfiles.for_mode(mode_name, difficulty)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var board: Dictionary = Layouts.roll_set(&"cinema", mode_name == &"pac_man", mode.soft_chance(), rng)
	var actors := {}
	for index in ids.size():
		var id: StringName = ids[index]
		var cell: Vector2i = human_cell if index == 0 and human_cell != Vector2i(-1, -1) else board.spawns[index]
		actors[id] = {"cell": cell, "lives": 3 if index == 0 else 1, "robot": index}
		if index > 0:
			actors[id].merge({"speed": profile.speed, "power": profile.power, "capacity": profile.capacity})
		else:
			actors[id].speed = mode.player_speed()
	var game := Simulation.new(ids, actors, board.cells,
		{"movement": true, "damage": true, "portals": board.portals, "round": true, "drops": true,
		"seed": seed_value, "mode": mode, "vehicles": StageSets.vehicles(board.skin),
		"features": board.get("features", {}), "center": board.get("center"), "skin": board.skin,
		"board_meta": {"skin": board.skin, "layout": board.layout, "size": board.size,
			"variants": board.get("variants", {}), "center": board.get("center", Vector2i(7, 6)),
			"portal_ids": board.get("portal_ids", {})}})
	return {"game": game, "board": board, "mode": mode, "profile": profile}


func _run_ai_mode(mode_name: StringName, difficulty: StringName, seed_value: int,
		human_cell: Vector2i) -> Dictionary:
	var round := _round_for(mode_name, difficulty, seed_value, IDS, human_cell)
	var game: RefCounted = round.game
	var scheduler := Scheduler.new(IDS, game)
	var brain := AI.new(seed_value, [], round.profile)
	var human := func(): return {"direction": Vector2.ZERO, "bomb_events": []}
	for id in IDS:
		scheduler.set_controller(id, human if id == &"human" else _produce.bind(game, brain, id))
	var state: Dictionary = game.snapshot()
	for index in MAX_TICKS:
		scheduler.advance_time(1.0 / 35)
		state = game.snapshot()
		if state.outcome != &"running": break
	scheduler.free()
	return {"state": state, "board": round.board}


## Pac-Man without AI: only the human actor, eating every coin by shortest-path BFS. A target
## is reconsidered whenever the player's registered cell reaches it.
func _run_scripted_pac_man(seed_value: int) -> Dictionary:
	var ids: Array[StringName] = [&"human"]
	var round := _round_for(&"pac_man", &"hard", seed_value, ids, Vector2i(-1, -1))
	var game: RefCounted = round.game
	var state: Dictionary = game.snapshot()
	var direction := Vector2.ZERO
	var target := Vector2i(-1, -1)
	var commands: Array[Dictionary] = [{"actor_id": &"human", "direction": direction, "bomb_events": []}]
	for index in MAX_TICKS:
		if target == Vector2i(-1, -1) or state.actors[&"human"].cell == target:
			target = _next_coin_step(state, state.actors[&"human"].cell)
			direction = Vector2(target - state.actors[&"human"].cell) if target != Vector2i(-1, -1) else Vector2.ZERO
		commands[0].direction = direction
		state = game.advance(commands)
		if state.outcome != &"running": break
	return state


## First cell of a shortest path to the nearest coin (four-way, over floor and portals).
func _next_coin_step(state: Dictionary, from: Vector2i) -> Vector2i:
	var queue: Array[Vector2i] = [from]
	var came := {from: from}
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		if cell != from and state.pickups.get(cell) == &"coin":
			var step: Vector2i = cell
			while came[step] != from: step = came[step]
			return step
		for delta in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var next: Vector2i = cell + delta
			if came.has(next) or state.board.get(next) not in [&"floor", &"portal"]: continue
			came[next] = cell
			queue.append(next)
	return Vector2i(-1, -1)


func _leader(state: Dictionary) -> Dictionary:
	var best := {"id": &"", "points": -1}
	for id in state.actors:
		var points := int(state.actors[id].points)
		if points > best.points:
			best = {"id": id, "points": points}
	return best


## `settle()` formula: points at 100 each (Kill/Green Zone) or 10 (Pac-Man), then the win
## bonuses of the time left and the difficulty; a loss spends a retry heart and pays neither.
func _check_settle(state: Dictionary, difficulty: StringName, per_point: int) -> void:
	var breakdown: Dictionary = state.result_breakdown
	var points := int(state.actors[&"human"].points)
	_expect(int(breakdown.get("kills", 0)) == points * per_point,
		"settle: %d points score %d each" % [points, per_point])
	var expected_time := 0
	var expected_difficulty := 0
	if state.outcome == &"won":
		expected_time = ceili(float(state.remaining) / 35.0) * 10
		expected_difficulty = int(DIFF_POINT.get(difficulty, 2000))
	_expect(int(breakdown.get("time", -1)) == expected_time, "settle: win time bonus %d" % expected_time)
	_expect(int(breakdown.get("difficulty", -1)) == expected_difficulty,
		"settle: difficulty bonus %d" % expected_difficulty)
	_expect(int(state.result_score) == int(breakdown.kills) + int(breakdown.time) + int(breakdown.difficulty),
		"settle: result score is the breakdown sum")
	_expect(int(state.actors[&"human"].score) == int(state.result_score), "settle: the human carries the level score")


## `GameInterFace.present`/`setFaceMc`/`mapLoadOver` on the real generated game screen: every
## seat shows its mode score with the mode's suffix (`/10`, `/<coins>`); Pac-Man seats with -1
## are empty, and `mapLoadOver` sets the coin suffix and `textColNum`.
func _check_hud(mode_name: StringName, state: Dictionary) -> void:
	var host := HudHost.new()
	host.session = Session.new(3)
	host.session.mode = mode_name
	host.session.enemies = 3
	host.session.robot = 0
	host.session.ai_robots.assign([1, 6, 3])
	host.session.level = 1
	root.add_child(host)
	var screen: Node2D = SwfScreen.create(&"game")
	root.add_child(screen)
	var hud: RefCounted = GameInterFace.new(screen, host, null)
	hud.present(state)
	var suffix := "/10"
	if mode_name == &"pac_man": suffix = "/" + str(int(state.mode_state.coins_total))
	var ui := 0
	for id in state.actors:
		var points := int(state.actors[id].points)
		var expected := str(points) + suffix if points >= 0 else ""
		_expect(screen.get_text(hud._scoreTextArr[ui]) == expected,
			"%s HUD seat %d shows %s" % [mode_name, ui, expected])
		ui += 1
	_expect(hud.scoreStr == suffix, "%s HUD score suffix is %s" % [mode_name, suffix])
	if mode_name == &"pac_man":
		_expect(hud.textColNum == int(state.mode_state.coins_total) - 15,
			"Pac-Man HUD textColNum is coins_total - 15")
	hud.destroy()
	screen.free()
	host.free()


func _record(state: Dictionary, mode_name: StringName, seed_value: int, started: int,
		details: Dictionary) -> Dictionary:
	var record := {"mode": String(mode_name), "seed": seed_value, "tick": state.tick,
		"outcome": state.outcome, "score": state.result_score,
		"breakdown": state.result_breakdown.duplicate(),
		"elapsed_ms": Time.get_ticks_msec() - started,
		"remaining_soft": state.board.values().count(&"soft")}
	record.merge(details)
	return record


func _produce(game: RefCounted, brain: RefCounted, id: StringName) -> Dictionary:
	return brain.command(game.snapshot(), id)


func _expect(condition: bool, label: String) -> void:
	if not condition: _fail(label)


func _fail(label: String) -> void:
	failures.append(label)


class HudHost extends Node:
	var session: RefCounted

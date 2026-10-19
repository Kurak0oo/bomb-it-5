extends SceneTree
## Production round/scheduler/controllers on the full recorded board, without private-state writes.

const Simulation = preload("res://scripts/simulation/bomb_simulation.gd")
const Scheduler = preload("res://scripts/simulation/tick_scheduler.gd")
const AI = preload("res://scripts/simulation/ai_controller.gd")
const IDS: Array[StringName] = [&"human", &"ruby", &"mint", &"gold"]


func _initialize() -> void:
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
		for id in IDS:
			scheduler.set_controller(id, _produce.bind(game, brain, id))
		var state: Dictionary = game.snapshot()
		var bomb_seen := false
		var started := Time.get_ticks_msec()
		for index in 6300:
			scheduler.advance_time(1.0 / 35)
			state = game.snapshot()
			bomb_seen = bomb_seen or not state.bombs.is_empty()
			if state.outcome != &"running": break
		if state.outcome == &"running" or not bomb_seen:
			printerr("Full-board playthrough did not complete correctly: ", seed_value)
			scheduler.free()
			quit(1)
			return
		records.append({"seed": seed_value, "tick": state.tick, "outcome": state.outcome,
			"kills": state.actors[&"human"].kills, "score": state.result_score,
			"elapsed_ms": Time.get_ticks_msec() - started,
			"remaining_soft": state.board.values().count(&"soft")})
		scheduler.free()
	if not records.any(func(record): return record.outcome == &"won") or not records.any(func(record): return record.outcome == &"lost"):
		printerr("Full-board playthroughs must exercise both legitimate victory and defeat")
		quit(1)
		return
	var path := ProjectSettings.globalize_path("res://.scratch/game-captures")
	DirAccess.make_dir_recursive_absolute(path)
	var log := FileAccess.open(path.path_join("playthroughs.json"), FileAccess.WRITE)
	log.store_string(JSON.stringify(records, "  "))
	print("PASS: 3 full-board playthrough checks ", JSON.stringify(records))
	quit(0)


func _produce(game: RefCounted, brain: RefCounted, id: StringName) -> Dictionary:
	return brain.command(game.snapshot(), id)

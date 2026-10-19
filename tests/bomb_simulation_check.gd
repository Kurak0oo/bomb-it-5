extends SceneTree

const Simulation = preload("res://scripts/simulation/bomb_simulation.gd")
const Scheduler = preload("res://scripts/simulation/tick_scheduler.gd")

var _failures: int = 0
var _checks: int = 0
var _schedulers: Array[Node] = []


func _initialize() -> void:
	_down_places_a_bomb_at_the_actor_cell()
	_repeated_downs_cannot_stack_bombs_in_one_cell()
	_roster_order_wins_a_shared_cell_independently_of_batch_order()
	_placement_requires_known_floor()
	_newborn_bomb_detonates_on_the_72nd_following_tick()
	_blast_breaks_the_first_soft_block_and_stops_at_solids()
	_power_two_still_stops_at_the_first_soft_block()
	_rejected_batches_cannot_place_or_advance_a_fuse()
	_caller_mutation_cannot_rewrite_the_simulation()
	_expiry_tick_input_is_consumed_before_capacity_is_freed()
	_scheduler_drives_the_real_simulation_from_buffered_input()
	_focus_pause_freezes_the_fuse_and_discards_queued_input()
	_stall_catch_up_ages_only_the_five_processed_ticks()
	_a_blast_chains_a_newer_bomb_in_the_same_tick()
	for scheduler in _schedulers:
		scheduler.free()
	if _failures == 0:
		print("PASS: %d bomb simulation checks" % _checks)
	else:
		printerr("FAIL: %d of %d bomb simulation checks" % [_failures, _checks])
	quit(0 if _failures == 0 else 1)


func _down_places_a_bomb_at_the_actor_cell() -> void:
	var simulation := _new_simulation()
	var result: Dictionary = simulation.advance([_command(&"human", [&"down"], Vector2.RIGHT)])
	_expect([result.accepted, result.tick, result.bombs], [true, 1, [
		{"actor_id": &"human", "cell": Vector2i(2, 1), "power": 1}]],
		"accepted down places a bomb before movement at the configured actor cell")


func _repeated_downs_cannot_stack_bombs_in_one_cell() -> void:
	var simulation := Simulation.new([&"human"],
		{&"human": {"cell": Vector2i(2, 1), "capacity": 3}}, _board())
	var first: Dictionary = simulation.advance([_command(&"human", [&"up"])])
	_expect(first.bombs, [], "ordinary bomb-up alone does not place a bomb")
	var result: Dictionary = simulation.advance([_command(&"human", [&"down", &"up", &"down", &"down"])])
	_expect(result.bombs, [{"actor_id": &"human", "cell": Vector2i(2, 1), "power": 1}],
		"ordered repeated downs cannot stack bombs even when capacity exceeds one")
	_expect(simulation.advance([_command(&"human", [&"down"])]).bombs.size(), 1,
		"an occupied cell rejects placement on later accepted ticks too")


func _roster_order_wins_a_shared_cell_independently_of_batch_order() -> void:
	for commands in [[_command(&"human", [&"down"]), _command(&"ai", [&"down"])],
			[_command(&"ai", [&"down"]), _command(&"human", [&"down"])]]:
		var simulation := Simulation.new([&"human", &"ai"], {
			&"human": {"cell": Vector2i(2, 1)}, &"ai": {"cell": Vector2i(2, 1)}}, _board())
		var batch: Array[Dictionary] = []
		batch.assign(commands)
		_expect(simulation.advance(batch).bombs, [
			{"actor_id": &"human", "cell": Vector2i(2, 1), "power": 1}],
			"fixed roster priority resolves shared-cell placement regardless of command-array order")


func _placement_requires_known_floor() -> void:
	for cell in [Vector2i(2, 0), Vector2i(3, 1), Vector2i(6, 1)]:
		var simulation := Simulation.new([&"human"], {&"human": {"cell": cell}}, _board())
		var result: Dictionary = simulation.advance([_command(&"human", [&"down"])])
		_expect([result.accepted, result.tick, result.bombs], [true, 1, []],
			"solid, soft and outside-excerpt cells prevent placement without rejecting valid input")


func _newborn_bomb_detonates_on_the_72nd_following_tick() -> void:
	var simulation := _new_simulation()
	simulation.advance([_command(&"human", [&"down"])])
	var premature_blasts := 0
	var result: Dictionary = {}
	for tick in 71:
		result = simulation.advance([_command(&"human")])
		premature_blasts += result.blasts.size()
	_expect([result.tick, premature_blasts, result.bombs.size()], [72, 0, 1],
		"creation tick is excluded and the bomb survives all 71 following countdowns")
	result = simulation.advance([_command(&"human")])
	_expect([result.tick, result.bombs, result.blasts.size()], [73, [], 1],
		"a bomb placed on tick 1 detonates exactly on accepted tick 73")
	_expect(simulation.advance([_command(&"human")]).blasts, [],
		"one detonation is reported once rather than replayed on later ticks")


func _blast_breaks_the_first_soft_block_and_stops_at_solids() -> void:
	var simulation := _new_simulation()
	simulation.advance([_command(&"human", [&"down"])])
	var result: Dictionary = {}
	for tick in 72:
		result = simulation.advance([_command(&"human")])
	var cells: Array = []
	for blast in result.blasts:
		cells.append_array(blast.cells)
	cells.sort()
	_expect([cells, result.broken_soft_blocks, result.board[Vector2i(3, 1)],
		result.board[Vector2i(4, 1)], result.board[Vector2i(2, 0)], result.board[Vector2i(2, 2)]],
		[[Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)], [Vector2i(3, 1)],
		 &"floor", &"soft", &"solid", &"solid"],
		"the source-derived blast footprint breaks the first soft cell and never flames solid cells")
	_expect(simulation.advance([_command(&"human")]).broken_soft_blocks, [],
		"the broken block is reported only on the detonation tick")


func _power_two_still_stops_at_the_first_soft_block() -> void:
	var simulation := Simulation.new([&"human"],
		{&"human": {"cell": Vector2i(2, 1), "power": 2}}, _board())
	simulation.advance([_command(&"human", [&"down"])])
	var result: Dictionary = {}
	for tick in 72:
		result = simulation.advance([_command(&"human")])
	var cells: Array = result.blasts[0].cells.duplicate()
	cells.sort()
	_expect([cells, result.board[Vector2i(4, 1)]],
		[[Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)], &"soft"],
		"power two cannot pass a soft block removed by this same ray")


func _rejected_batches_cannot_place_or_advance_a_fuse() -> void:
	var simulation := _new_simulation()
	_expect(simulation.advance([_command(&"unknown", [&"down"])]).bombs, [],
		"an unknown actor cannot mutate gameplay before admission")
	simulation.advance([_command(&"human", [&"down"])])
	for tick in 71:
		simulation.advance([_command(&"human")])
	for batch in [[], [_command(&"human", [&"invalid"])],
			[_command(&"human"), _command(&"human", [&"down"])]]:
		var commands: Array[Dictionary] = []
		commands.assign(batch)
		var rejected: Dictionary = simulation.advance(commands)
		_expect([rejected.accepted, rejected.tick, rejected.bombs.size(), rejected.blasts,
			rejected.broken_soft_blocks, rejected.board[Vector2i(3, 1)]],
			[false, 72, 1, [], [], &"soft"], "a rejected tick cannot age a bomb or mutate the board")
	_expect(simulation.advance([_command(&"human")]).broken_soft_blocks, [Vector2i(3, 1)],
		"the next accepted tick detonates without a gap from rejected calls")


func _caller_mutation_cannot_rewrite_the_simulation() -> void:
	var roster: Array[StringName] = [&"human"]
	var actors := {&"human": {"cell": Vector2i(2, 1), "power": 2}}
	var board := _board()
	var simulation := Simulation.new(roster, actors, board)
	roster.append(&"unknown")
	actors[&"human"].cell = Vector2i(3, 1)
	actors[&"human"].power = 5
	board[Vector2i(3, 1)] = &"floor"
	var result: Dictionary = simulation.advance([_command(&"human", [&"down"])])
	_expect([result.bombs, result.board[Vector2i(3, 1)]],
		[[{"actor_id": &"human", "cell": Vector2i(2, 1), "power": 2}], &"soft"],
		"construction owns its roster, actor settings and board cells")
	result.bombs[0].cell = Vector2i(5, 5)
	result.board[Vector2i(3, 1)] = &"solid"
	var next: Dictionary = simulation.advance([_command(&"human")])
	_expect([next.bombs, next.board[Vector2i(3, 1)]],
		[[{"actor_id": &"human", "cell": Vector2i(2, 1), "power": 2}], &"soft"],
		"returned state cannot mutate the simulation")
	for tick in 71:
		next = simulation.advance([_command(&"human")])
	_expect([result.board[Vector2i(3, 1)], next.board[Vector2i(3, 1)]], [&"solid", &"floor"],
		"later explosions do not rewrite previously returned snapshots")


func _expiry_tick_input_is_consumed_before_capacity_is_freed() -> void:
	var simulation := _new_simulation()
	simulation.advance([_command(&"human", [&"down"])])
	for tick in 71:
		simulation.advance([_command(&"human")])
	var expiry: Dictionary = simulation.advance([_command(&"human", [&"down"])])
	_expect([expiry.tick, expiry.bombs, expiry.blasts.size()], [73, [], 1],
		"input on the expiry tick fails before the old bomb releases its slot")
	_expect(simulation.advance([_command(&"human")]).bombs, [],
		"a failed accepted input is never retried automatically after expiry")
	_expect(simulation.advance([_command(&"human", [&"down"])]).bombs,
		[{"actor_id": &"human", "cell": Vector2i(2, 1), "power": 1}],
		"a fresh delivered down can place after capacity and the cell become available")


func _scheduler_drives_the_real_simulation_from_buffered_input() -> void:
	var scheduler := Scheduler.new([&"human"], _new_simulation())
	_schedulers.append(scheduler)
	scheduler.enqueue_bomb_event(&"human", &"down")
	_expect(scheduler.advance_time(0.01).ticks, [], "queued input waits for a complete logical interval")
	var result: Dictionary = scheduler.advance_time(0.02)
	_expect(result.ticks[0].get("bombs", []), [
		{"actor_id": &"human", "cell": Vector2i(2, 1), "power": 1}],
		"the scheduler advances its supplied real bomb simulation rather than a separate command-only target")
	_expect(scheduler.advance_time(1.0 / 35.0).ticks[0].commands[0].bomb_events, [],
		"accepted gameplay input is acknowledged and not replayed next tick")


func _focus_pause_freezes_the_fuse_and_discards_queued_input() -> void:
	var scheduler := Scheduler.new([&"human"], _new_simulation())
	_schedulers.append(scheduler)
	scheduler.enqueue_bomb_event(&"human", &"down")
	scheduler.advance_time(1.0 / 35.0)
	for frame in 14:
		scheduler.advance_time(5.0 / 35.0)
	scheduler.advance_time(1.0 / 35.0)
	scheduler.enqueue_bomb_event(&"human", &"down")
	scheduler.advance_time(0.5 / 35.0)
	scheduler.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_expect(scheduler.advance_time(60.0), {"paused": true, "ticks": []},
		"focus pause processes no simulation time while a bomb is about to expire")
	scheduler.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	_expect(scheduler.advance_time(1.0 / 35.0), {"paused": true, "ticks": []},
		"focus return alone cannot advance a live fuse")
	scheduler.resume()
	_expect(scheduler.advance_time(0.5 / 35.0).ticks, [],
		"resuming a live fuse discards pre-pause partial time")
	var result: Dictionary = scheduler.advance_time(0.5 / 35.0).ticks[0]
	_expect([result.tick, result.commands[0].bomb_events, result.bombs, result.blasts.size()],
		[73, [], [], 1], "only the next accepted interval expires the bomb, with stale input cleared")
	_expect(scheduler.advance_time(1.0 / 35.0).ticks[0].bombs, [],
		"cleared pause input cannot place a replacement after detonation")
	scheduler.enqueue_bomb_event(&"human", &"down")
	_expect(scheduler.advance_time(1.0 / 35.0).ticks[0].bombs.size(), 1,
		"fresh input after resume can place a new bomb")


func _stall_catch_up_ages_only_the_five_processed_ticks() -> void:
	var scheduler := Scheduler.new([&"human"], _new_simulation())
	_schedulers.append(scheduler)
	scheduler.enqueue_bomb_event(&"human", &"down")
	var frame: Dictionary = scheduler.advance_time(2.01)
	_expect(frame.ticks.map(func(tick: Dictionary): return tick.tick), [1, 2, 3, 4, 5],
		"a stall advances the real simulation through five accepted ticks")
	_expect(frame.ticks.map(func(tick: Dictionary): return tick.commands[0].bomb_events),
		[[&"down"], [], [], [], []], "catch-up consumes the gameplay capture exactly once")
	_expect(scheduler.advance_time(0.0).ticks, [], "discarded stall time cannot age the live bomb later")
	var premature_blasts := 0
	for rendered_frame in 13:
		frame = scheduler.advance_time(5.0 / 35.0)
		for tick in frame.ticks:
			premature_blasts += tick.blasts.size()
	frame = scheduler.advance_time(2.0 / 35.0)
	_expect([frame.ticks[-1].tick, frame.ticks[-1].bombs.size(), premature_blasts,
		frame.ticks[0].blasts.size(), frame.ticks[1].blasts.size()], [72, 1, 0, 0, 0],
		"elapsed time discarded during a stall never contributes to the 72-tick fuse")
	_expect(scheduler.advance_time(1.0 / 35.0).ticks[0].broken_soft_blocks, [Vector2i(3, 1)],
		"the real scheduler detonates only on the next processed simulation tick")


func _a_blast_chains_a_newer_bomb_in_the_same_tick() -> void:
	# Same-frame chain detonation is source-supported; see the gameplay-phase evidence record.
	var simulation := Simulation.new([&"human", &"ai"], {
		&"human": {"cell": Vector2i(1, 1), "power": 3},
		&"ai": {"cell": Vector2i(2, 1)}}, _board())
	simulation.advance([_command(&"human", [&"down"]), _command(&"ai")])
	for tick in 70:
		simulation.advance([_command(&"human"), _command(&"ai")])
	simulation.advance([_command(&"human"), _command(&"ai", [&"down"])])
	var result: Dictionary = simulation.advance([_command(&"human"), _command(&"ai")])
	var owners: Array = result.blasts.map(func(blast: Dictionary): return blast.actor_id)
	owners.sort()
	_expect([result.tick, result.bombs, owners, result.broken_soft_blocks],
		[73, [], [&"ai", &"human"], [Vector2i(3, 1)]],
		"a hit newer bomb detonates synchronously instead of waiting for its own fuse")
	var parent_cells: Array = []
	for blast in result.blasts:
		if blast.actor_id == &"human":
			parent_cells = blast.cells
	_expect(parent_cells.has(Vector2i(3, 1)), false,
		"the parent ray stops at the chained bomb even when the chain removes it immediately")
	_expect(simulation.advance([_command(&"human"), _command(&"ai")]).blasts, [],
		"a chain-removed bomb is not processed a second time by the outer countdown pass")


func _new_simulation() -> Simulation:
	return Simulation.new([&"human"], {&"human": {"cell": Vector2i(2, 1)}}, _board())


func _board() -> Dictionary:
	# Exact CinemaStage1 excerpt x=0..5, y=0..2; see docs/evidence/first-bomb-test-excerpt.md.
	var cells: Dictionary = {}
	var rows := ["######", "#..sss", "#.##s#"]
	for y in rows.size():
		for x in rows[y].length():
			cells[Vector2i(x, y)] = {"#": &"solid", ".": &"floor", "s": &"soft"}[rows[y][x]]
	return cells


func _command(actor_id: StringName, events: Array = [], direction: Vector2 = Vector2.ZERO) -> Dictionary:
	return {"actor_id": actor_id, "direction": direction, "bomb_events": events}


func _expect(actual: Variant, expected: Variant, description: String) -> void:
	_checks += 1
	if actual != expected:
		_failures += 1
		printerr("FAIL: %s\n  expected: %s\n  actual: %s" % [description, expected, actual])

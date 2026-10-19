extends SceneTree

const Scheduler = preload("res://scripts/simulation/tick_scheduler.gd")

var _failures: int = 0
var _checks: int = 0
var _schedulers: Array[Node] = []


func _initialize() -> void:
	_one_tick_supplies_every_registered_actor()
	_fractional_elapsed_time_is_accumulated()
	_stalls_run_five_ticks_and_discard_excess_time()
	_logical_rate_is_independent_of_render_rate()
	_direction_is_held_per_actor_until_replaced()
	_bomb_events_keep_order_and_are_consumed_once()
	_pause_stops_ticks_and_resume_starts_with_fresh_input()
	_input_is_rejected_while_paused_or_for_unknown_actors()
	_focus_loss_pauses_and_focus_return_requires_explicit_resume()
	_invalid_elapsed_time_cannot_poison_the_clock()
	await _attached_scheduler_is_driven_by_godot_frames()
	for scheduler in _schedulers:
		scheduler.free()
	if _failures == 0:
		print("PASS: %d scheduler checks" % _checks)
	else:
		printerr("FAIL: %d of %d scheduler checks" % [_failures, _checks])
	quit(0 if _failures == 0 else 1)


func _one_tick_supplies_every_registered_actor() -> void:
	var scheduler := _new_scheduler([&"human", &"ai"])
	_expect(scheduler.advance_time(1.0 / 35.0), {"paused": false, "ticks": [
		{"accepted": true, "tick": 1, "commands": [
			{"actor_id": &"human", "direction": Vector2.ZERO, "bomb_events": []},
			{"actor_id": &"ai", "direction": Vector2.ZERO, "bomb_events": []}]}]},
		"one logical interval advances once with explicit idle commands for the full roster")


func _fractional_elapsed_time_is_accumulated() -> void:
	var scheduler := _new_scheduler([&"human"])
	var counts: Array[int] = []
	for elapsed in [0.0, 0.01, 0.01, 0.01, 0.01]:
		counts.append(scheduler.advance_time(elapsed).ticks.size())
	_expect(counts, [0, 0, 0, 1, 0],
		"sub-tick intervals accumulate without advancing early or dropping the remainder")


func _stalls_run_five_ticks_and_discard_excess_time() -> void:
	var scheduler := _new_scheduler([&"human"])
	_expect(scheduler.advance_time(2.01).ticks.size(), 5,
		"a long frame processes at most five logical ticks")
	_expect(scheduler.advance_time(0.0).ticks, [],
		"discarded stall time cannot generate later catch-up ticks")
	_expect(scheduler.advance_time(0.02).ticks, [],
		"the discarded stall remainder cannot contribute to a future tick")
	_expect(scheduler.advance_time(0.01).ticks.map(func(tick: Dictionary): return tick.tick), [6],
		"only processed ticks advance the simulation after a stall")


func _logical_rate_is_independent_of_render_rate() -> void:
	for frames in [30, 60, 90, 120, 144]:
		var scheduler := _new_scheduler([&"human"])
		var count := 0
		for frame in frames:
			count += scheduler.advance_time(1.0 / frames).ticks.size()
		_expect(count, 35, "one second at %d rendered frames produces 35 logical ticks" % frames)


func _direction_is_held_per_actor_until_replaced() -> void:
	var scheduler := _new_scheduler([&"human", &"ai"])
	_expect(scheduler.set_direction(&"human", Vector2.LEFT), true, "registered actors accept direction")
	_expect(scheduler.set_direction(&"ai", Vector2.DOWN), true, "each actor has its own direction")
	var ticks: Array = scheduler.advance_time(2.0 / 35.0).ticks
	_expect(ticks.map(func(tick: Dictionary): return tick.commands), [
		[{"actor_id": &"human", "direction": Vector2.LEFT, "bomb_events": []},
		 {"actor_id": &"ai", "direction": Vector2.DOWN, "bomb_events": []}],
		[{"actor_id": &"human", "direction": Vector2.LEFT, "bomb_events": []},
		 {"actor_id": &"ai", "direction": Vector2.DOWN, "bomb_events": []}]],
		"directions persist independently across catch-up ticks")
	scheduler.set_direction(&"human", Vector2.ZERO)
	_expect(scheduler.advance_time(1.0 / 35.0).ticks[0].commands[0].direction, Vector2.ZERO,
		"releasing direction replaces the held value")


func _bomb_events_keep_order_and_are_consumed_once() -> void:
	var scheduler := _new_scheduler([&"human", &"ai"])
	var accepted: Array[bool] = []
	for event in [&"down", &"up", &"down", &"down"]:
		accepted.append(scheduler.enqueue_bomb_event(&"human", event))
	accepted.append(scheduler.enqueue_bomb_event(&"ai", &"up"))
	_expect(accepted, [true, true, true, true, true], "each actor buffers ordered bomb input")
	var ticks: Array = scheduler.advance_time(3.0 / 35.0).ticks
	_expect(ticks.map(func(tick: Dictionary): return tick.commands), [
		[{"actor_id": &"human", "direction": Vector2.ZERO, "bomb_events": [&"down", &"up", &"down", &"down"]},
		 {"actor_id": &"ai", "direction": Vector2.ZERO, "bomb_events": [&"up"]}],
		[{"actor_id": &"human", "direction": Vector2.ZERO, "bomb_events": []},
		 {"actor_id": &"ai", "direction": Vector2.ZERO, "bomb_events": []}],
		[{"actor_id": &"human", "direction": Vector2.ZERO, "bomb_events": []},
		 {"actor_id": &"ai", "direction": Vector2.ZERO, "bomb_events": []}]],
		"catch-up ticks consume the captured event list once, preserving repeated events")
	scheduler.enqueue_bomb_event(&"human", &"up")
	_expect(scheduler.advance_time(1.0 / 35.0).ticks[0].commands[0].bomb_events, [&"up"],
		"new input belongs to a later tick after the previous capture is accepted")


func _pause_stops_ticks_and_resume_starts_with_fresh_input() -> void:
	var scheduler := _new_scheduler([&"human"])
	scheduler.advance_time(0.5 / 35.0)
	scheduler.set_direction(&"human", Vector2.RIGHT)
	scheduler.enqueue_bomb_event(&"human", &"down")
	scheduler.pause()
	_expect(scheduler.advance_time(60.0), {"paused": true, "ticks": []},
		"paused time produces no ticks or catch-up debt")
	_expect(scheduler.resume(), true, "explicit resume leaves the paused state")
	_expect(scheduler.advance_time(0.5 / 35.0), {"paused": false, "ticks": []},
		"resume discards the partial interval from before pause")
	_expect(scheduler.advance_time(0.5 / 35.0), {"paused": false, "ticks": [
		{"accepted": true, "tick": 1, "commands": [
			{"actor_id": &"human", "direction": Vector2.ZERO, "bomb_events": []}]}]},
		"the first resumed tick contains no held controls or queued events from before pause")
	scheduler.set_direction(&"human", Vector2.LEFT)
	scheduler.enqueue_bomb_event(&"human", &"down")
	_expect(scheduler.advance_time(1.0 / 35.0).ticks[0].commands, [
		{"actor_id": &"human", "direction": Vector2.LEFT, "bomb_events": [&"down"]}],
		"fresh input is accepted after explicit resume")


func _input_is_rejected_while_paused_or_for_unknown_actors() -> void:
	var scheduler := _new_scheduler([&"human"])
	_expect([scheduler.set_direction(&"unknown", Vector2.UP),
		scheduler.enqueue_bomb_event(&"unknown", &"down"),
		scheduler.enqueue_bomb_event(&"human", &"invalid")], [false, false, false],
		"unknown actors and invalid bomb events are rejected")
	scheduler.pause()
	_expect([scheduler.set_direction(&"human", Vector2.UP),
		scheduler.enqueue_bomb_event(&"human", &"down")], [false, false],
		"gameplay input is not accepted while paused")
	scheduler.resume()
	_expect(scheduler.advance_time(1.0 / 35.0).ticks[0].commands, [
		{"actor_id": &"human", "direction": Vector2.ZERO, "bomb_events": []}],
		"rejected input does not leak into the resumed round")


func _focus_loss_pauses_and_focus_return_requires_explicit_resume() -> void:
	var scheduler := _new_scheduler([&"human"])
	scheduler.set_direction(&"human", Vector2.UP)
	scheduler.enqueue_bomb_event(&"human", &"down")
	scheduler.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_expect(scheduler.advance_time(1.0), {"paused": true, "ticks": []},
		"Godot application focus loss automatically pauses gameplay")
	_expect(scheduler.resume(), false, "gameplay cannot resume while the application lacks focus")
	scheduler.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	_expect(scheduler.advance_time(1.0), {"paused": true, "ticks": []},
		"focus return alone does not resume gameplay")
	_expect(scheduler.resume(), true, "explicit resume works once application focus returns")
	_expect(scheduler.advance_time(1.0 / 35.0), {"paused": false, "ticks": [
		{"accepted": true, "tick": 1, "commands": [
			{"actor_id": &"human", "direction": Vector2.ZERO, "bomb_events": []}]}]},
		"focus pause clears input and does not build catch-up debt")


func _invalid_elapsed_time_cannot_poison_the_clock() -> void:
	for elapsed in [-1.0, NAN, INF, -INF]:
		var scheduler := _new_scheduler([&"human"])
		scheduler.advance_time(0.5 / 35.0)
		_expect(scheduler.advance_time(elapsed), {"paused": false, "ticks": []},
			"invalid elapsed time is ignored: %s" % elapsed)
		_expect(scheduler.advance_time(0.5 / 35.0).ticks.map(func(tick: Dictionary): return tick.tick), [1],
			"invalid elapsed time preserves accumulated valid time: %s" % elapsed)


func _attached_scheduler_is_driven_by_godot_frames() -> void:
	var scheduler := _new_scheduler([&"human"])
	root.add_child.call_deferred(scheduler)
	await create_timer(0.1).timeout
	scheduler.set_process(false)
	var result: Dictionary = scheduler.advance_time(1.0 / 35.0)
	_expect(result.ticks.size(), 1, "manual advancement remains available with automatic processing disabled")
	_expect(result.ticks[0].tick > 1, true,
		"attaching the scheduler to Godot drives logical ticks without manual advancement")


func _new_scheduler(actor_ids: Array[StringName]) -> Scheduler:
	var scheduler := Scheduler.new(actor_ids)
	_schedulers.append(scheduler)
	return scheduler


func _expect(actual: Variant, expected: Variant, description: String) -> void:
	_checks += 1
	if actual != expected:
		_failures += 1
		printerr("FAIL: %s\n  expected: %s\n  actual: %s" % [description, expected, actual])

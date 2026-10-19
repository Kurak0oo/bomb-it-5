extends SceneTree

const Boundary = preload("res://scripts/simulation/command_boundary.gd")
const BombEvents = preload("res://scripts/simulation/bomb_event_queue.gd")

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_ordered_bomb_events_preserve_repeats()
	_invalid_bomb_events_reject_the_whole_tick()
	_valid_batches_advance_one_tick()
	_missing_actor_rejects_without_advancing()
	_duplicate_actor_rejects_without_advancing()
	_unknown_actor_rejects_without_advancing()
	_roster_stays_fixed_after_creation()
	_consumed_commands_are_owned_by_the_boundary()
	_incomplete_command_rejects_without_advancing()
	_wrong_payload_types_reject_without_advancing()
	_queue_captures_delivered_event_order()
	_accepted_tick_consumes_its_capture()
	_rejected_tick_retains_its_capture()
	_late_events_wait_behind_a_retried_capture()
	_old_acknowledgements_cannot_consume_new_input()
	_queue_rejects_unknown_bomb_events()
	if _failures == 0:
		print("PASS: %d command boundary checks" % _checks)
	else:
		printerr("FAIL: %d of %d command boundary checks" % [_failures, _checks])
	quit(0 if _failures == 0 else 1)


func _ordered_bomb_events_preserve_repeats() -> void:
	var boundary = Boundary.new([&"human"])
	var command := _command(&"human", Vector2.RIGHT, [&"down", &"down", &"up", &"down"])
	var result: Dictionary = boundary.advance([command])
	_expect(result, {"accepted": true, "tick": 1, "commands": [
		{"actor_id": &"human", "direction": Vector2.RIGHT,
			"bomb_events": [&"down", &"down", &"up", &"down"]}]},
		"one actor command preserves bomb event order and repeated downs")


func _invalid_bomb_events_reject_the_whole_tick() -> void:
	for invalid in [[&"down", &"fire"], ["down"], [true], [&"up", 0]]:
		var boundary = Boundary.new([&"human", &"ai"])
		var previous: Array[Dictionary] = [_command(&"human"), _command(&"ai")]
		boundary.advance(previous)
		_expect(boundary.advance([
			_command(&"human", Vector2.RIGHT, [&"down"]),
			_command(&"ai", Vector2.ZERO, invalid)]),
			{"accepted": false, "tick": 1, "commands": previous},
			"a malformed bomb event rejects every actor's command without advancing")


func _valid_batches_advance_one_tick() -> void:
	var boundary = Boundary.new([&"human", &"ai"])
	var first: Array[Dictionary] = [
		_command(&"human", Vector2.RIGHT, [&"down"]),
		_command(&"ai"),
	]
	_expect(boundary.advance(first), {"accepted": true, "tick": 1, "commands": first},
		"a complete two-actor batch is consumed at tick 1")
	var second: Array[Dictionary] = [
		_command(&"ai", Vector2.UP),
		_command(&"human", Vector2.ZERO, [&"up"]),
	]
	_expect(boundary.advance(second), {"accepted": true, "tick": 2, "commands": second},
		"the next explicit call consumes fresh commands at tick 2")


func _missing_actor_rejects_without_advancing() -> void:
	var boundary = Boundary.new([&"human", &"ai"])
	var previous: Array[Dictionary] = [_command(&"human"), _command(&"ai")]
	boundary.advance(previous)
	_expect(boundary.advance([_command(&"human", Vector2.RIGHT, [&"down"])]),
		{"accepted": false, "tick": 1, "commands": previous},
		"a missing actor rejects the batch and preserves the last consumed commands")
	_expect(boundary.advance(previous), {"accepted": true, "tick": 2, "commands": previous},
		"a rejected call does not create a gap in logical ticks")


func _duplicate_actor_rejects_without_advancing() -> void:
	var boundary = Boundary.new([&"human", &"ai"])
	_expect(boundary.advance([_command(&"human"), _command(&"human", Vector2.LEFT)]),
		{"accepted": false, "tick": 0, "commands": []},
		"duplicate commands cannot stand in for another actor, even with the right count")


func _unknown_actor_rejects_without_advancing() -> void:
	var boundary = Boundary.new([&"human", &"ai"])
	var previous: Array[Dictionary] = [_command(&"human"), _command(&"ai")]
	boundary.advance(previous)
	_expect(boundary.advance([_command(&"human", Vector2.RIGHT), _command(&"outsider")]),
		{"accepted": false, "tick": 1, "commands": previous},
		"an unknown actor rejects the entire batch before the known actor's command is consumed")


func _roster_stays_fixed_after_creation() -> void:
	var roster: Array[StringName] = [&"human", &"ai_1", &"ai_2", &"ai_3"]
	var boundary = Boundary.new(roster)
	roster[3] = &"replacement"
	var original: Array[Dictionary] = [
		_command(&"human"), _command(&"ai_1"), _command(&"ai_2"), _command(&"ai_3"),
	]
	_expect(boundary.advance(original), {"accepted": true, "tick": 1, "commands": original},
		"the four-actor roster remains fixed when the caller changes its source array")


func _consumed_commands_are_owned_by_the_boundary() -> void:
	var boundary = Boundary.new([&"human"])
	var supplied: Array[Dictionary] = [_command(&"human", Vector2.RIGHT, [&"down"])]
	var result: Dictionary = boundary.advance(supplied)
	supplied[0].direction = Vector2.LEFT
	result.commands[0].bomb_events[0] = &"up"
	_expect(boundary.advance([]), {"accepted": false, "tick": 1,
		"commands": [_command(&"human", Vector2.RIGHT, [&"down"])]},
		"mutating caller inputs or public results cannot rewrite a consumed tick")


func _incomplete_command_rejects_without_advancing() -> void:
	var boundary = Boundary.new([&"human"])
	_expect(boundary.advance([{"actor_id": &"human"}]),
		{"accepted": false, "tick": 0, "commands": []},
		"an actor id alone is not a direction and ordered bomb-event command")


func _wrong_payload_types_reject_without_advancing() -> void:
	for field in ["actor_id", "direction", "bomb_events"]:
		var boundary = Boundary.new([&"human"])
		var malformed := _command(&"human")
		malformed[field] = 42
		_expect(boundary.advance([malformed]),
			{"accepted": false, "tick": 0, "commands": []},
			"wrong type for %s cannot advance a tick" % field)


func _queue_captures_delivered_event_order() -> void:
	var queue = BombEvents.new()
	queue.enqueue(&"down")
	queue.enqueue(&"down")
	queue.enqueue(&"up")
	queue.enqueue(&"down")
	_expect(queue.capture().events, [&"down", &"down", &"up", &"down"],
		"a tick-start capture preserves delivered event order and repeats")


func _accepted_tick_consumes_its_capture() -> void:
	var queue = BombEvents.new()
	var boundary = Boundary.new([&"human"])
	queue.enqueue(&"down")
	queue.enqueue(&"up")
	var captured: Dictionary = queue.capture()
	var result: Dictionary = boundary.advance([_command(&"human", Vector2.ZERO, captured.events)])
	var acknowledged: bool = queue.acknowledge(captured.token, result.accepted)
	_expect({"acknowledged": acknowledged, "next_events": queue.capture().events},
		{"acknowledged": true, "next_events": []},
		"an accepted command batch consumes that actor's capture")


func _rejected_tick_retains_its_capture() -> void:
	var queue = BombEvents.new()
	var boundary = Boundary.new([&"human", &"ai"])
	queue.enqueue(&"down")
	queue.enqueue(&"up")
	var captured: Dictionary = queue.capture()
	var result: Dictionary = boundary.advance([_command(&"human", Vector2.ZERO, captured.events)])
	var acknowledged: bool = queue.acknowledge(captured.token, result.accepted)
	_expect({"acknowledged": acknowledged, "retry": queue.capture()},
		{"acknowledged": false, "retry": captured},
		"an incomplete actor batch leaves the same bomb capture available for retry")


func _late_events_wait_behind_a_retried_capture() -> void:
	var queue = BombEvents.new()
	var boundary = Boundary.new([&"human", &"ai"])
	queue.enqueue(&"down")
	var captured: Dictionary = queue.capture()
	queue.enqueue(&"up")
	var rejected: Dictionary = boundary.advance([_command(&"human", Vector2.ZERO, captured.events)])
	queue.acknowledge(captured.token, rejected.accepted)
	var retry: Dictionary = queue.capture()
	_expect(retry, captured, "retry keeps the original cutoff despite input arriving later")
	var accepted: Dictionary = boundary.advance([
		_command(&"human", Vector2.ZERO, retry.events), _command(&"ai")])
	queue.acknowledge(retry.token, accepted.accepted)
	_expect(queue.capture().events, [&"up"],
		"acceptance consumes only the captured prefix and leaves later input for the next tick")


func _old_acknowledgements_cannot_consume_new_input() -> void:
	var queue = BombEvents.new()
	var boundary = Boundary.new([&"human"])
	queue.enqueue(&"down")
	var first: Dictionary = queue.capture()
	var result: Dictionary = boundary.advance([_command(&"human", Vector2.ZERO, first.events)])
	queue.acknowledge(first.token, result.accepted)
	queue.enqueue(&"down")
	var second: Dictionary = queue.capture()
	_expect(queue.acknowledge(first.token, result.accepted), false,
		"a duplicate acknowledgement cannot consume an identical event in a later capture")
	_expect(queue.capture(), second, "the current capture survives an old acknowledgement")
	var next_result: Dictionary = boundary.advance([_command(&"human", Vector2.ZERO, second.events)])
	_expect(queue.acknowledge(second.token, next_result.accepted), true,
		"the current token can still commit its accepted tick")
	_expect(queue.acknowledge(second.token, next_result.accepted), false,
		"a committed token cannot be acknowledged twice")


func _queue_rejects_unknown_bomb_events() -> void:
	var queue = BombEvents.new()
	queue.enqueue(&"down")
	_expect(queue.enqueue(&"fire"), false, "the queue rejects unknown event names at intake")
	queue.enqueue(&"up")
	_expect(queue.capture().events, [&"down", &"up"],
		"rejecting an event does not poison the next command capture")


func _command(actor_id: StringName, direction := Vector2.ZERO, bomb_events: Array = []) -> Dictionary:
	return {"actor_id": actor_id, "direction": direction, "bomb_events": bomb_events}


func _expect(actual: Variant, expected: Variant, description: String) -> void:
	_checks += 1
	if actual != expected:
		_failures += 1
		printerr("FAIL: %s\n  expected: %s\n  actual: %s" % [description, expected, actual])

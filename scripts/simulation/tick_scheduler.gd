extends Node
## Drives command admission from rendered frames, or supplied elapsed time when detached.

const CommandModule = preload("res://scripts/simulation/command_boundary.gd")
const BombEventQueue = preload("res://scripts/simulation/bomb_event_queue.gd")
const TICKS_PER_SECOND: float = 35.0
const MAX_TICKS_PER_FRAME: float = 5.0
# Roundoff tolerance in logical-tick units, far below a meaningful time interval.
const TICK_EPSILON: float = 1e-9

var _actor_ids: Array[StringName]
var _commands: RefCounted
var _tick_credit: float = 0.0
var _directions: Dictionary = {}
var _bomb_queues: Dictionary = {}
var _paused: bool = false
var _focused: bool = true
var _controllers: Dictionary = {}
var _pending_controllers: Dictionary = {}


func _init(actor_ids: Array[StringName], tick_target: RefCounted = null) -> void:
	_actor_ids = actor_ids.duplicate()
	_commands = tick_target if tick_target != null else CommandModule.new(_actor_ids)
	for actor_id in _actor_ids:
		_directions[actor_id] = Vector2.ZERO
		_bomb_queues[actor_id] = BombEventQueue.new()


func set_direction(actor_id: StringName, direction: Vector2) -> bool:
	if _paused or not _directions.has(actor_id):
		return false
	_directions[actor_id] = direction
	return true


func enqueue_bomb_event(actor_id: StringName, event: StringName) -> bool:
	if _paused or not _bomb_queues.has(actor_id):
		return false
	return _bomb_queues[actor_id].enqueue(event)


func set_controller(actor_id: StringName, producer: Callable) -> bool:
	if not _directions.has(actor_id) or not producer.is_valid():
		return false
	_controllers[actor_id] = producer
	return true


func pause() -> void:
	_paused = true
	_clear_input_and_time()


func resume() -> bool:
	if not _paused or not _focused:
		return false
	_clear_input_and_time()
	_paused = false
	return true


func advance_time(elapsed_seconds: float) -> Dictionary:
	if _paused:
		return {"paused": true, "ticks": []}
	if not is_finite(elapsed_seconds) or elapsed_seconds < 0.0:
		return {"paused": false, "ticks": []}
	_tick_credit = minf(_tick_credit + elapsed_seconds * TICKS_PER_SECOND, MAX_TICKS_PER_FRAME)
	var ticks: Array[Dictionary] = []
	while _tick_credit + TICK_EPSILON >= 1.0:
		var batch: Array[Dictionary] = []
		var captures: Dictionary = {}
		for actor_id in _actor_ids:
			if _controllers.has(actor_id):
				if not _pending_controllers.has(actor_id):
					var produced: Dictionary = _controllers[actor_id].call()
					_pending_controllers[actor_id] = produced.duplicate(true)
					for event in produced.bomb_events:
						_bomb_queues[actor_id].enqueue(event)
				_directions[actor_id] = _pending_controllers[actor_id].direction
			var capture: Dictionary = _bomb_queues[actor_id].capture()
			captures[actor_id] = capture
			batch.append({"actor_id": actor_id, "direction": _directions[actor_id], "bomb_events": capture.events})
		var result: Dictionary = _commands.call(&"advance", batch)
		for actor_id in _actor_ids:
			_bomb_queues[actor_id].acknowledge(captures[actor_id].token, result.accepted)
		if result.accepted:
			_pending_controllers.clear()
		ticks.append(result)
		_tick_credit = maxf(0.0, _tick_credit - 1.0)
	return {"paused": false, "ticks": ticks}


func _process(delta: float) -> void:
	advance_time(delta)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_focused = false
		pause()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_focused = true


func _clear_input_and_time() -> void:
	_tick_credit = 0.0
	_pending_controllers.clear()
	for actor_id in _actor_ids:
		_directions[actor_id] = Vector2.ZERO
		_bomb_queues[actor_id] = BombEventQueue.new()

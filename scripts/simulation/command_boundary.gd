extends RefCounted
## Explicit command intake; gameplay interpretation and scheduling live elsewhere.

var _tick: int = 0
var _actor_ids: Array[StringName]
var _commands: Array[Dictionary] = []


func _init(actor_ids: Array[StringName]) -> void:
	_actor_ids = actor_ids.duplicate()


func advance(commands: Array[Dictionary]) -> Dictionary:
	if commands.size() != _actor_ids.size():
		return {"accepted": false, "tick": _tick, "commands": _commands.duplicate(true)}
	var seen: Dictionary = {}
	for command in commands:
		if not command.has_all(["actor_id", "direction", "bomb_events"]):
			return {"accepted": false, "tick": _tick, "commands": _commands.duplicate(true)}
		if not (command.actor_id is StringName and command.direction is Vector2
				and command.bomb_events is Array):
			return {"accepted": false, "tick": _tick, "commands": _commands.duplicate(true)}
		if not command.direction.is_finite() or not _actor_ids.has(command.actor_id) or seen.has(command.actor_id):
			return {"accepted": false, "tick": _tick, "commands": _commands.duplicate(true)}
		for event in command.bomb_events:
			if not (event is StringName) or event not in [&"down", &"up"]:
				return {"accepted": false, "tick": _tick, "commands": _commands.duplicate(true)}
		seen[command.actor_id] = true
	_tick += 1
	_commands = commands.duplicate(true)
	return {"accepted": true, "tick": _tick, "commands": _commands.duplicate(true)}

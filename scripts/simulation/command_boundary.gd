extends RefCounted
## Explicit command intake; gameplay interpretation and scheduling live elsewhere.

var _tick: int = 0
var _actor_ids: Array[StringName]
var _commands: Array[Dictionary] = []
## One pending key release per actor (`InteractiveController.moveStop`'s remaining direction);
## it rides on the next zero-direction command as the optional `release_direction` field.
var _releases: Dictionary = {}


func _init(actor_ids: Array[StringName]) -> void:
	_actor_ids = actor_ids.duplicate()


## Stage the direction `InteractiveController.moveStop` dispatches for the key still held
## before the last one is removed (`model.movArr.slice(-1)`): a release between frames keeps
## that facing even though the tick's move stops. Cleared on a press (`direction != ZERO`),
## by a caller after an advance (`clear_release`) or at a pause.
func stage_release(actor_id: StringName, direction: Vector2) -> bool:
	if not _actor_ids.has(actor_id) or not direction.is_finite(): return false
	_releases[actor_id] = direction
	return true


func clear_release(actor_id: StringName) -> void:
	_releases.erase(actor_id)


func clear_releases() -> void:
	_releases.clear()


## The admitted commands, each zero-direction one carrying this actor's staged release.
func _with_releases(commands: Array[Dictionary]) -> Array[Dictionary]:
	if _releases.is_empty(): return commands
	var prepared: Array[Dictionary] = []
	for command in commands:
		var copy: Dictionary = command.duplicate()
		var raw = copy.get("actor_id")
		if not (raw is StringName):
			prepared.append(copy)
			continue
		var actor_id: StringName = raw
		if copy.get("direction", Vector2.ZERO) != Vector2.ZERO:
			# A press resumed movement: the release no longer owns the facing.
			_releases.erase(actor_id)
		else:
			var release: Vector2 = _releases.get(actor_id, Vector2.ZERO)
			if release != Vector2.ZERO: copy.release_direction = release
		prepared.append(copy)
	return prepared


func advance(commands: Array[Dictionary]) -> Dictionary:
	var prepared: Array[Dictionary] = _with_releases(commands)
	if prepared.size() != _actor_ids.size():
		return {"accepted": false, "tick": _tick, "commands": _commands.duplicate(true)}
	var seen: Dictionary = {}
	for command in prepared:
		if not command.has_all(["actor_id", "direction", "bomb_events"]):
			return {"accepted": false, "tick": _tick, "commands": _commands.duplicate(true)}
		if not (command.actor_id is StringName and command.direction is Vector2
				and command.bomb_events is Array):
			return {"accepted": false, "tick": _tick, "commands": _commands.duplicate(true)}
		if not command.direction.is_finite() or not _actor_ids.has(command.actor_id) or seen.has(command.actor_id):
			return {"accepted": false, "tick": _tick, "commands": _commands.duplicate(true)}
		if command.has("release_direction") and not (command.release_direction is Vector2
				and command.release_direction.is_finite()):
			return {"accepted": false, "tick": _tick, "commands": _commands.duplicate(true)}
		for event in command.bomb_events:
			if not (event is StringName) or event not in [&"down", &"up"]:
				return {"accepted": false, "tick": _tick, "commands": _commands.duplicate(true)}
		seen[command.actor_id] = true
	_tick += 1
	_commands = prepared.duplicate(true)
	return {"accepted": true, "tick": _tick, "commands": _commands.duplicate(true)}

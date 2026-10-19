extends RefCounted
## One actor's ordered bomb events, captured for explicit command admission.

var _pending: Array[StringName] = []
var _captured: Array[StringName] = []
var _has_capture: bool = false
var _token: int = 0


func enqueue(event: StringName) -> bool:
	if event not in [&"down", &"up"]:
		return false
	_pending.append(event)
	return true


func capture() -> Dictionary:
	if not _has_capture:
		_captured = _pending.duplicate()
		_has_capture = true
		_token += 1
	return {"token": _token, "events": _captured.duplicate()}


func acknowledge(token: int, accepted: bool) -> bool:
	if not accepted or not _has_capture or token != _token:
		return false
	_pending = _pending.slice(_captured.size())
	_captured.clear()
	_has_capture = false
	return true

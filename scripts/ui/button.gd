extends RefCounted
## Port of `zlong.bombit5.utils.Button`: a clip used as a push button. Frame 1 up, 2 over,
## 3 down, 4 disabled. Unlike `ToggletButton`, the AS3 never touches `mouseEnabled` (only
## `mouseChildren = false` and `buttonMode`), so this port does not call `set_enabled`.

var _btn: String
var _screen: Node2D
var _events: RefCounted
var _enable := true


## `Button(param1)`: `_btn.mouseChildren = false` has no counterpart (a generated screen
## sends events to the instance itself).
func _init(screen: Node2D, events: RefCounted, btn: String) -> void:
	_screen = screen
	_events = events
	_btn = btn
	init()


## `init` (`_btn.stop()` keeps the current frame and `buttonMode` only sets the hand
## cursor: nothing to do on a generated screen)
func init() -> void:
	_events.add(_btn, &"down", downHandle)
	_events.add(_btn, &"over", overHandle)
	_events.add(_btn, &"out", outHandle)


## `downHandle`
func downHandle(_target: String) -> void:
	if _enable:
		_screen.set_frame(_btn, 3)


## `overHandle`
func overHandle(_target: String) -> void:
	if _enable:
		_screen.set_frame(_btn, 2)


## `outHandle`
func outHandle(_target: String) -> void:
	if _enable:
		_screen.set_frame(_btn, 1)


## `get enable` / `set enable`
var enable: bool:
	get: return _enable
	set(value):
		_enable = value
		if not _enable:
			_screen.set_frame(_btn, 4)
			_events.remove(_btn, &"down", downHandle)
			_events.remove(_btn, &"over", overHandle)
			_events.remove(_btn, &"out", outHandle)
		else:
			_screen.set_frame(_btn, 1)
			_events.add(_btn, &"down", downHandle)
			_events.add(_btn, &"over", overHandle)
			_events.add(_btn, &"out", outHandle)


## `destroy`
func destroy() -> void:
	_events.remove(_btn, &"down", downHandle)
	_events.remove(_btn, &"over", overHandle)
	_events.remove(_btn, &"out", outHandle)
	_btn = ""


## `get btn`
var btn: String:
	get: return _btn

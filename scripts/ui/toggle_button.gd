extends RefCounted
## Port of `zlong.bombit5.utils.ToggletButton`: a clip used as a toggle. Frame 1 up,
## 2 over, 3 selected, 4 disabled.

var _btn: String
var _screen: Node2D
var _events: RefCounted
var _isSelect := false
var _enable := true


func _init(screen: Node2D, events: RefCounted, btn: String) -> void:
	_screen = screen
	_events = events
	_btn = btn
	init()


## `init` (`_btn.stop()` keeps the current frame: nothing to do on a generated screen)
func init() -> void:
	_events.add(_btn, &"down", downHandle)
	_events.add(_btn, &"over", overHandle)
	_events.add(_btn, &"out", outHandle)


func downHandle(_target: String) -> void:
	if _enable:
		_screen.set_frame(_btn, 3)
		_isSelect = true


func overHandle(_target: String) -> void:
	if not _isSelect and _enable:
		_screen.set_frame(_btn, 2)


func outHandle(_target: String) -> void:
	if not _isSelect and _enable:
		_screen.set_frame(_btn, 1)


var enable: bool:
	get: return _enable
	set(value):
		_enable = value
		_screen.set_enabled(_btn, _enable)
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


var isSelect: bool:
	get: return _isSelect
	set(value):
		if _enable:
			_isSelect = value
			if _isSelect:
				_screen.set_frame(_btn, 3)
				_events.remove(_btn, &"down", downHandle)
				_events.remove(_btn, &"over", overHandle)
				_events.remove(_btn, &"out", outHandle)
			else:
				_screen.set_frame(_btn, 1)
				_events.add(_btn, &"down", downHandle)
				_events.add(_btn, &"over", overHandle)
				_events.add(_btn, &"out", outHandle)


var btn: String:
	get: return _btn

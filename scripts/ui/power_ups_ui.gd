extends RefCounted
## Port of `zlong.bombit5.ui.PowerUpsUI` (class UI_POWER_UPS) onto a generated screen:
## the static power-ups sheet with BACK and CONTROLS. As in the AS3, neither button has a
## roll-over sound.

const UtilsButton = preload("res://scripts/ui/button.gd")
const SwfEvents = preload("res://scripts/ui/swf_events.gd")

var _mc: Node2D
var _events: RefCounted
var _app: Node
var simpleButtons: Array = []
var _back := ""
var _controls := ""


## `PowerUpsUI(param1, param2)` -> `AbstractUI`: init, initView, initListener, initData.
func _init(screen: Node2D, app: Node) -> void:
	_mc = screen
	_app = app
	_events = SwfEvents.new(screen)
	init()
	initView()
	initListener()


## `init`: `setMC("UI_POWER_UPS")`; the app has already built the screen.
func init() -> void:
	pass


func _sound(name: String) -> void:
	if name == "menuPress": _app.audio.menu_press()
	else: _app.audio.menu_touch()


## `initView`
func initView() -> void:
	_back = "back"  # _mc.getChildByName("back")
	_controls = "controls"  # _mc.getChildByName("controls")
	simpleButtons.append(UtilsButton.new(_mc, _events, _back))
	simpleButtons.append(UtilsButton.new(_mc, _events, _controls))


## `initListener`
func initListener() -> void:
	_events.add(_back, &"down", backHandle)
	_events.add(_controls, &"down", controlsHandle)


## `delListener`
func delListener() -> void:
	_events.remove(_back, &"down", backHandle)
	_events.remove(_controls, &"down", controlsHandle)


## `backHandle`
func backHandle(_t: String) -> void:
	_app.show_main_menu()  # UIEvent.CHANGE_BACK -> UIManager.changeBack
	_sound("menuPress")
	destroy()


## `controlsHandle`
func controlsHandle(_t: String) -> void:
	_app.show_how_to_play()  # UIEvent.CONTROLS -> UIManager.controlsSetting
	_sound("menuPress")
	destroy()


## `AbstractUI.destroy`: delListener, delData, delView (the app removes the screen;
## `Button.destroy` drops each button's listeners).
func destroy() -> void:
	delListener()
	for button in simpleButtons: button.destroy()
	simpleButtons = []

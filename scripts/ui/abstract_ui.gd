extends RefCounted
## Port of `zlong.bombit5.ui.AbstractUI`, the base of the results screens. The generated
## screen stands in for `_mc` and the app for `_root` (the UI container, which also
## carries `_root.stage` and the `UIEvent`s the screens dispatch).
##
## The constructor runs `init`, `initView`, `initListener`, `initData` as the AS3 does.
## `setMC(className)` creates the clip in the AS3; here the app has already built the
## screen from the class's generated layout, so `setMC` records the class name only.
## `onCheckCallback` / `onCopyRightMouseClick` (portal copyright alert) and the `display`
## setter (`UIManager` adding and removing the clip) are not ported.

const SwfEvents = preload("res://scripts/ui/swf_events.gd")

var _mc: Node2D
var _root: Node
var _events: RefCounted
var simpleButtons: Array = []
## The class `setMC` named (the screen's root clip).
var mc_class := ""


## `AbstractUI(root)`
func _init(screen: Node2D, app: Node) -> void:
	_mc = screen
	_root = app
	_events = SwfEvents.new(screen)
	init()
	initView()
	initListener()
	initData()


## `init`
func init() -> void:
	pass


## `setMC`: `getDefinitionByName(className)`, `new`, `_root.addChild(_mc)`.
func setMC(className: String) -> void:
	mc_class = className


## `initView`
func initView() -> void:
	pass


## `delView`: `removeChild(_mc)` is the app's (it frees the screen); the buttons are destroyed.
func delView() -> void:
	for button in simpleButtons:
		button.destroy()
	simpleButtons = []


## `initListener`
func initListener() -> void:
	pass


## `delListener`
func delListener() -> void:
	pass


## `initData`
func initData() -> void:
	pass


## `delData`
func delData() -> void:
	pass


## `destroy`
func destroy() -> void:
	delListener()
	delData()
	delView()


## `SoundManger.createSound(name)`: menuPress / menuTouch through the app's audio, any
## other class name through `play_sound` (silent when the SWF has no such class).
func _sound(name: String) -> void:
	if name == "menuPress": _root.audio.menu_press()
	elif name == "menuTouch": _root.audio.menu_touch()
	else: _root.audio.play_sound(StringName(name))

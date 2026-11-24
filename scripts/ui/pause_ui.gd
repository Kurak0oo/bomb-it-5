extends "res://scripts/ui/abstract_ui.gd"
## Port of `zlong.bombit5.ui.PauseUI` (class UI_pause) onto its generated screen
## (scenes/swf/pause.json): `Game.doGamePause` adds it over the gameplay screen, whose board
## container it hides, and `gameResume` / `mainMenu` follow its events.
##
## `_root` is the app (sound switches, quality); `game` stands in for the AS3 `Game` that
## listens for UIEvent.RESUME and MAIN_MENU. The robot's body and hat take random frames
## (`int(Math.random() * totalFrames) + 1`) from the round's Math.random (`math_random`).

const UtilsButton = preload("res://scripts/ui/button.gd")
const Quality = preload("res://scripts/quality.gd")

var _mainMenu := ""
var _resume := ""
var _soundCtl := ""
var _qualityCtl := ""
var _musicCtl := ""
var _bodyMc := ""
var _headMc := ""
var game: Node
var _random: RefCounted


## `PauseUI(root, soundManager)`: after `AbstractUI`, the switches show the settings and
## the robot takes its random frames.
func _init(screen: Node2D, app: Node, round_host: Node, random: RefCounted) -> void:
	game = round_host
	_random = random
	super(screen, app)
	_mc.set_frame(_qualityCtl, Quality.index() + 1)
	if not _root.audio.sound_on: _mc.set_frame(_soundCtl, 2)
	if not _root.audio.music_on: _mc.set_frame(_musicCtl, 2)
	_bodyMc = "bodyMc"  # _mc["bodyMc"]
	_headMc = "head/hatMc"  # _mc["head"]["hatMc"]
	_mc.set_frame(_bodyMc, int(_draw() * _mc.get_total_frames(_bodyMc)) + 1)
	_mc.set_frame(_headMc, int(_draw() * _mc.get_total_frames(_headMc)) + 1)


func _draw() -> float:
	return _random.random() if _random != null else randf()


## `init`
func init() -> void:
	super.init()
	setMC("UI_pause")


## `initView`: RESUME and MAIN MENU are zlong Buttons; the switches stop on their frame.
func initView() -> void:
	_mainMenu = "mainMenu"
	_resume = "resume"
	simpleButtons.push_back(UtilsButton.new(_mc, _events, _mainMenu))
	simpleButtons.push_back(UtilsButton.new(_mc, _events, _resume))
	_soundCtl = "sound"
	_qualityCtl = "quality"
	_musicCtl = "music"


## `initListener` (SPACE on the stage resumes, `keydownHandler`).
func initListener() -> void:
	_events.add(_mainMenu, &"down", onMainClickHandler)
	_events.add(_resume, &"down", onResumeClickHandler)
	_events.add(_soundCtl, &"down", soundCtlHandle)
	_events.add(_qualityCtl, &"down", qualityCtlHandle)
	_events.add(_musicCtl, &"down", musicCtlHandle)
	_mc.key_down.connect(keydownHandler)


func delListener() -> void:
	_events.remove(_mainMenu, &"down", onMainClickHandler)
	_events.remove(_resume, &"down", onResumeClickHandler)
	_events.remove(_soundCtl, &"down", soundCtlHandle)
	_events.remove(_qualityCtl, &"down", qualityCtlHandle)
	_events.remove(_musicCtl, &"down", musicCtlHandle)
	if _mc.key_down.is_connected(keydownHandler): _mc.key_down.disconnect(keydownHandler)


## `keydownHandler`: SPACE resumes.
func keydownHandler(keycode: int) -> void:
	if keycode == KEY_SPACE: onResumeClickHandler("")


## `onMainClickHandler`: UIEvent.MAIN_MENU (`Game.mainMenu`), then `destroy`.
func onMainClickHandler(_t: String) -> void:
	var host := game
	destroy()
	if is_instance_valid(host): host.main_menu_requested.emit()


## `onResumeClickHandler`: UIEvent.RESUME (`Game.gameResume`), then `destroy`.
func onResumeClickHandler(_t: String) -> void:
	var host := game
	destroy()
	if is_instance_valid(host): host.toggle_pause()


## `soundCtlHandle`
func soundCtlHandle(_t: String) -> void:
	if _mc.get_frame(_soundCtl) == 1:
		_mc.set_frame(_soundCtl, 2)
		_root.audio.set_sound(false)
	else:
		_mc.set_frame(_soundCtl, 1)
		_root.audio.set_sound(true)


## `qualityCtlHandle`: HIGH, MEDIUM, LOW in turn.
func qualityCtlHandle(_t: String) -> void:
	var frame: int = _mc.get_frame(_qualityCtl)
	_mc.set_frame(_qualityCtl, 1 if frame == 3 else frame + 1)
	Quality.cycle()
	Quality.apply(_mc.get_viewport())


## `musicCtlHandle`: the flag only (the round's music stays paused).
func musicCtlHandle(_t: String) -> void:
	if _mc.get_frame(_musicCtl) == 1:
		_mc.set_frame(_musicCtl, 2)
		_root.audio.set_music(false, false)
	else:
		_mc.set_frame(_musicCtl, 1)
		_root.audio.set_music(true, false)


## `destroy`: also drops the round it reads.
func destroy() -> void:
	super.destroy()
	game = null

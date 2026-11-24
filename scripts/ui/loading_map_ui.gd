extends "res://scripts/ui/abstract_ui.gd"
## Port of `zlong.bombit5.ui.LoadingMapUI` (class UI_reading) onto its generated screen
## (scenes/swf/loading_map.json): the map-loading screen `UIManager.gamePlay` opens over the
## gameplay screen at START (`loadingMap`) and `Game.gameStartHandler` destroys when the
## round starts.
##
## `progress(rows / MAP_HEIGHT)` (`MapMaster.createRow` -> `Game.mapProgress`, before each
## row) tweens processBarMc's frame to `int(p * 100)` in 0.1 s (TweenMax, linear), here on
## the frame clock at 35 fps. The reference player runs TweenMax on the host's clock, so
## the bar's frame is not compared frame for frame (the case's `wall_clock_frame`).
## `setStageQuality` (the default quality set HIGH on processBarMc's last frame) is the
## quality switch's business and not ported here. The loading sound plays as the bar
## passes its frames (`addFrameScript`).
##
## The gameplay screen under it (`schedule`, recorded with this screen's timeline,
## record_screen.py timeline `game_schedule`) follows the original's map building:
## `MapMaster.timerHandle` makes one board row per Timer(100) tick (`rows`: the frame each
## row gets its boxes) and `Game.firstMapLoadOver` the robots and their HUD counters
## (`robots`); `closed_index` is the round's first frame.

const ARCADE_MODE := &"arcade"
const KILL_MODE := &"kill"
const PAC_MAN_MODE := &"pac_man"
const GREEN_ZONE := &"green_zone"

var txt_mode := ""
var txt_mode_dec := ""
var _processBarMc := ""
var _modePaint := ""
var _sound_frames: Array = []
## TweenMax on processBarMc's frame: from, to, seconds elapsed.
var _tween := {}
var _bar := 0.0
const FPS := 35.0


## `init`
func init() -> void:
	super.init()
	setMC("UI_reading")


## `initData`: the mode's frame on the mode title, its description and its picture; the
## loading sound on processBarMc's frames 23, 37, 51, 65, 80 and 88 less 10.
func initData() -> void:
	txt_mode = "modeMc"  # _mc.getChildByName("modeMc")
	txt_mode_dec = "mode_dec"
	_processBarMc = "processBarMc"
	for frame in [23, 37, 51, 65, 80, 88]:
		# `addFrameScript(frame - 10, playSound)`: 0-based, so frame - 9 counted from 1.
		_sound_frames.append(frame - 9)
	_modePaint = "modePaint"  # _mc["modePaint"]
	var mode := 0
	match _root.session.mode:
		ARCADE_MODE: mode = 1
		KILL_MODE: mode = 2
		PAC_MAN_MODE: mode = 3
		GREEN_ZONE: mode = 4
	_mc.set_frame(txt_mode_dec, mode)
	_mc.set_frame(txt_mode, mode)
	_mc.set_frame(_modePaint, mode)


## `playSound`: `createSound("loadingBomb")`.
func playSound() -> void:
	if _root.audio != null: _root.audio.play_sound(&"loadingBomb")


## The recorded schedule of the gameplay screen under this one (see the header).
func schedule() -> Dictionary:
	var timeline = _mc.layout.get("timeline")
	if not timeline is Dictionary: return {}
	var recorded: Dictionary = timeline.get("game_schedule", {})
	return {"rows": recorded.get("rows", {}), "robots": int(recorded.get("robots", 0)),
		"closed": int(timeline.get("closed_index", 0))}


## `progress(param1)`: `TweenMax.to(_processBarMc, 0.1, {frame: int(param1 * 100), ease: Linear})`.
func progress(param1: float) -> void:
	if _tween.is_empty(): _bar = float(_mc.get_frame(_processBarMc))
	_tween = {"from": _bar, "to": float(int(param1 * 100.0)), "t": 0.0}


## One frame of the tween (the screen's frame clock).
func tick() -> void:
	if _tween.is_empty(): return
	_tween.t += 1.0 / FPS
	var was := int(_bar + 0.5)
	_bar = lerpf(_tween.from, _tween.to, minf(1.0, _tween.t / 0.1))
	if _tween.t >= 0.1: _tween = {}
	var frame := clampi(int(_bar + 0.5), 1, _mc.get_total_frames(_processBarMc))
	_mc.set_frame(_processBarMc, frame)
	for f in _sound_frames:
		if was < f and frame >= f: playSound()

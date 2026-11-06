extends RefCounted
## The round's end cartoon on the generated gameplay screen: a port of
## `zlong.bombit5.ui.GameEndCartoon`, driven by the simulation's ending (display side only).
##
## - `AbstractGameMode.win` / `lose` make it with "winCartoon" / "loseCartoon"; each
##   edition-5 mode's `timeOut` (ArcadeMode, KillMode, GreenZoneMode, PacManMode) with
##   "timeUpCartoon", whatever `judgeHandler` then decides (snapshot `ending_timed_out`).
## - `setCartoon`: the library clip (100 frames) is added to `game.uiManager.uiContainer`,
##   after the HUD (its path's `@0` becomes `@0#0`, the cartoon `@0#1`), at the stage origin,
##   and `TweenMax.to(mc, 3, {frame: mc.totalFrames, onComplete: animationComplete})`.
##   TweenMax's default ease is `TweenLite.easeOut` (1 - (1 - t)²); FramePlugin rounds
##   (`TweenPlugin.updateTweens`, `round`: int(v + 0.5)) and calls `gotoAndStop`. The clip is
##   made at frame 1; the tween moves it from the next frame.
## - `animationComplete`: the clip is taken off and the result handler runs.
## The simulation holds the ending for 105 ticks (`BombSimulation._finish_round`), the
## tween's three seconds at 35 frames a second: the frame shown after k ticks is the tween's
## at k / 105 of its duration. A pause freezes the ending (accepted conversion); the cartoon
## stays under PauseUI, which `doGamePause` adds to the same container after it.
## The frames are the reference player's (original/screens/game/cartoons/,
## record_screen.py cartoons).

const CARTOONS := "res://original/screens/game/cartoons/cartoons.json"
const ENDING_TICKS := 105.0

var _screen: Node2D
var _host: String
var _hud_path: String
var _art: Dictionary = {}
var _mc_path := ""
var _cartoon_name := ""
var _total_frames := 100


func _init(screen: Node2D, hud_path: String) -> void:
	_screen = screen
	_hud_path = hud_path
	_host = hud_path.get_base_dir()
	var file := ProjectSettings.globalize_path(CARTOONS)
	if FileAccess.file_exists(file):
		_art = JSON.parse_string(FileAccess.get_file_as_string(file)).get("cartoons", {})


## Every snapshot: the cartoon while the round is ending, none otherwise.
func update(snapshot: Dictionary) -> void:
	var ending: bool = snapshot.get("round_stage", &"") == &"ending"
	if ending and _mc_path == "":
		setCartoon(_cartoon_for(snapshot))
	elif not ending and _mc_path != "":
		animationComplete()
	if _mc_path == "": return
	var elapsed := roundi(float(snapshot.get("ending_progress", 0.0)) * ENDING_TICKS)
	_show(frame_at(elapsed, _total_frames))


## The cartoon's node path while it shows, else "".
func path() -> String:
	return _mc_path


## The cartoon's library class while it shows.
func cartoon_name() -> String:
	return _cartoon_name


## `TweenMax.to(mc, 3, {frame: totalFrames})` after `elapsed` of the ending's 105 ticks.
static func frame_at(elapsed: int, total_frames: int) -> int:
	var t := clampf(float(elapsed) / ENDING_TICKS, 0.0, 1.0)
	var ratio := 1.0 - (1.0 - t) * (1.0 - t)  # TweenLite.easeOut
	var value := 1.0 + float(total_frames - 1) * ratio
	return int(value + 0.5)  # TweenPlugin.updateTweens, round


static func _cartoon_for(snapshot: Dictionary) -> String:
	if snapshot.get("ending_timed_out", false): return "timeUpCartoon"
	return "winCartoon" if snapshot.get("pending_outcome", &"") == &"won" else "loseCartoon"


## `GameEndCartoon.setCartoon`: the clip, last in the UI container.
func setCartoon(cartoon_name: String) -> void:
	_cartoon_name = cartoon_name
	var clip: Dictionary = _art.get(cartoon_name, {})
	_total_frames = int(clip.get("total_frames", 100))
	# Another unnamed child of the container: the HUD's segment gains its index.
	_mc_path = _host.path_join("@0#%d" % _screen.add_ui_child(_hud_path))
	# The tween skips frames: only those it shows are resampled, ahead of time.
	var frames: Dictionary = clip.get("frames", {})
	var shown := {}
	for elapsed in int(ENDING_TICKS):
		var frame := frame_at(elapsed, _total_frames)
		if not shown.has(frame) and frames.has(str(frame)):
			shown[frame] = true
			_screen.prefetch(frames[str(frame)])
	_screen.add_node({"path": _mc_path, "parent": _host, "stage_matrix": [1.0, 0.0, 0.0, 1.0, 0.0, 0.0],
		"role": "piece", "kind": "movie_clip", "class": cartoon_name, "frame": 1})
	_show(1)


## `GameEndCartoon.animationComplete`: the clip comes off the container.
func animationComplete() -> void:
	if _mc_path == "" or not is_instance_valid(_screen): return
	_screen.remove_node(_mc_path)
	_screen.remove_ui_child(_hud_path)
	_mc_path = ""
	_cartoon_name = ""


func _show(frame: int) -> void:
	var art: Dictionary = _art.get(_cartoon_name, {}).get("frames", {}).get(str(frame), {})
	_screen.set_node_art(_mc_path, art, frame)

extends SceneTree
## Godot half of the comparison loop (tools/compare/compare.py): boots the main scene in a
## 700×510 SubViewport (the original stage, one unit per pixel) and hands the case to a
## CaseRunner (tools/compare/case_runner.gd), which replays its input commands frame by frame.
## This script writes what the runner reaches: a PNG and node dump at each `capture`, a node
## dump after each `trace` tick, and godot-log.json.
## Run with `--fixed-fps <swf rate>` so every frame advances by exactly one SWF frame; the
## frame rules live in case_runner.gd.

const STAGE := Vector2i(700, 510)

var _viewport: SubViewport
var _out := ""
## Preloaded, not looked up by class_name: a checkout whose .godot cache predates the class still runs.
const CaseRunnerScript := preload("res://tools/compare/case_runner.gd")
var _runner: CaseRunnerScript


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var case_path := _arg(args, "--case")
	_out = _arg(args, "--out")
	if case_path.is_empty() or _out.is_empty():
		push_error("usage: -- --case CASE.json --out DIR")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	var case: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(case_path))
	_viewport = SubViewport.new()
	_viewport.size = STAGE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.handle_input_locally = true
	root.add_child(_viewport)
	# The comparison window is driven by frames, not the user: keep it from being pushed to
	# the background (an occluded window may stop drawing, which stalled a parallel capture).
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	# Generated screens follow the stepped frames, not the clock (see swf_screen.gd).
	load("res://scripts/ui/swf_screen.gd").frame_locked = true
	# The round host is stepped here too: one host frame per captured frame, so a delayed or
	# occluded window draw cannot give the round extra ticks (Game.capture_clock).
	load("res://scripts/game.gd").capture_clock = true
	_runner = CaseRunnerScript.new(self, _viewport)
	# `--frame-clock` (a case's `godot_args`): the round's Date seconds follow the stepped
	# frames (35 a second), not the host clock, so a long case's timed events (ArcadeMode.timePassed)
	# do not depend on how fast this machine renders. The reference player's Date follows its
	# own host clock, which runs far behind its stepped frames; such a case ends before 45 s.
	if args.has("--frame-clock"):
		load("res://scripts/game.gd").seconds_source = func() -> int: return int(_runner.frame / 35) % 60
	var app: Node = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	if "save_path" in app:
		app.save_path = _out.path_join("save.json")
		DirAccess.remove_absolute(app.save_path)
	_viewport.add_child(app)
	_runner.on_capture = _capture
	_runner.on_trace_tick = _trace_tick
	_run.call_deferred(case)


func _run(case: Dictionary) -> void:
	await _runner.run(case)
	FileAccess.open(_out.path_join("godot-log.json"), FileAccess.WRITE).store_string(JSON.stringify({"frame": _runner.frame, "notes": _runner.log}, " "))
	# (A static Callable bound to this tree must not outlive it.)
	load("res://scripts/game.gd").seconds_source = Callable()
	load("res://scripts/game.gd").capture_clock = false
	quit(0)


func _capture(name: String) -> void:
	_viewport.get_texture().get_image().save_png(_out.path_join(name + ".png"))
	_runner.write_nodes(_out.path_join(name + ".nodes.json"))


func _trace_tick(trace_name: String, tick: int) -> void:
	_runner.write_nodes(_out.path_join("%s.t%04d.nodes.json" % [trace_name, tick]))


func _arg(args: PackedStringArray, flag: String) -> String:
	var i := args.find(flag)
	return args[i + 1] if i >= 0 and i + 1 < args.size() else ""

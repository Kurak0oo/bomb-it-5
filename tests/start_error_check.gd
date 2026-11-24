extends SceneTree
## The START flow through the real input pipeline: PLAY on the title, START on the menu,
## Game Settings. Opening the next screen from a button press must not take the pressed
## control out of the tree while the viewport still dispatches the event; the engine then
## prints `Condition "!is_inside_tree()" is true. Returning: false` at `Node::can_process`
## (scene/main/node.cpp) when the first click opens the next screen.
##
## The flow runs in a child Godot process so this check reads the engine's own stderr
## instead of trusting a script-side flag: an engine error line fails the check.

const CHILD_ARG := "--start-error-child"
const SAVE_PATH := "user://start-error-check-save.json"

var failures := 0
var checks := 0
var app: Control


## Counts the app's Math.random draws, and the ones made after the screen under test has
## been replaced: the dropped screen's per-frame effects must not run (or draw) one more
## frame before queue_free.
class CountingRandom extends "res://scripts/simulation/avm_random.gd":
	var source
	var app
	var screen_id: StringName
	var draws := 0
	var post_change_draws := 0


	func _init(generator) -> void:
		source = generator
		super(1)


	func next_raw() -> int:
		draws += 1
		if app.current != screen_id: post_change_draws += 1
		return source.next_raw()


func _initialize() -> void:
	if CHILD_ARG in OS.get_cmdline_user_args():
		_run_flow.call_deferred()
	else:
		_run_check.call_deferred()


func _run_check() -> void:
	var output := []
	var code := OS.execute(OS.get_executable_path(), [
		"--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://tests/start_error_check.gd", "--", CHILD_ARG], output, true)
	var text := "\n".join(output)
	var lines: Array = Array(text.split("\n"))
	var errors: Array = lines.filter(func(line): return line.begins_with("ERROR:") or line.begins_with("SCRIPT ERROR:") or line.contains("is_inside_tree"))
	_expect(code == 0, "the START flow finishes (exit %d)" % code)
	_expect(text.contains("AFTER START settings"), "PLAY then START reaches Game Settings")
	_expect(errors.is_empty(), "the START flow prints no engine error (%s)" % [errors])
	_expect(text.contains("DROP PASS"), "the dropped screen stops processing at once")
	print("%s: %d start error checks" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)


func _run_flow() -> void:
	root.size = Vector2i(1280, 720)
	app = load("res://scenes/main.tscn").instantiate()
	app.save_path = SAVE_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	root.add_child(app)
	await process_frame
	await app.screen_opened()
	# The title's PLAY replaces it on the same press: count its frames and Math.random
	# draws (through the game-over confetti effect, a per-frame controller like the real
	# GAME_WIN screen's FallSnow) and assert none land after the replacement.
	var title_screen: Control = app.screen
	var title_swf = title_screen.get_child(0)
	var counting := CountingRandom.new(app.math_random)
	counting.app = app
	counting.screen_id = &"title"
	app.math_random = counting
	var confetti = load("res://scripts/ui/fall_snow.gd").new(title_swf, counting)
	confetti.creatSnow()
	var post_change_advances := [0]
	title_swf.advanced.connect(func(_t: int):
		if app.current != &"title": post_change_advances[0] += 1)
	var state_at_exit := [-1, true]
	title_screen.tree_exiting.connect(func():
		state_at_exit[0] = title_screen.process_mode
		state_at_exit[1] = title_screen.visible)
	var draws_at_add := counting.draws
	for wait in 10:
		if counting.draws > draws_at_add: break
		await process_frame
	var live: bool = counting.draws > draws_at_add
	await _click(app.find_child("btn_play", true, false))
	await app.screen_opened()
	var stopped: bool = post_change_advances[0] == 0 and counting.post_change_draws == 0 \
		and state_at_exit[0] == Node.PROCESS_MODE_DISABLED and not state_at_exit[1] and live
	print("DROP %s: advanced=%d draws_after=%d mode_at_exit=%d hidden_at_exit=%s live=%s current=%s" % [
		"PASS" if stopped else "FAIL", post_change_advances[0],
		counting.post_change_draws, state_at_exit[0], not state_at_exit[1], live, app.current])
	await _click(app.find_child("startGame", true, false))
	await app.screen_opened()
	await process_frame
	print("AFTER START %s" % app.current)
	app.queue_free()
	await process_frame
	await process_frame
	quit(0)


## A real click: the Input singleton dispatches it (with the project's touch emulation) as
## the OS does. Pushing the event straight at the root does not expose the detached control.
func _click(control: Control) -> void:
	if control == null: return
	for wait in 900:
		if control.is_visible_in_tree(): break
		await process_frame
	var at := control.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		Input.parse_input_event(event)
	await process_frame
	await process_frame


func _expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr(label)

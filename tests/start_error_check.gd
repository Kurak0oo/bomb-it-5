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
	await _click(app.find_child("btn_play", true, false))
	await app.screen_opened()
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

extends Control
## Dev-only compare playground: loads a tools/compare/cases case through the same CaseRunner the
## comparison uses, then lets a person pause, step and play the real game frame by frame. The
## stage is the comparison's 700×510 SubViewport shown 1:1; a compare capture is the pause point.
## (The viewport lives under a plain host node and its texture is painted by the container: a
## SubViewport parented directly by a SubViewportContainer does not register GUI roots for the
## runner's `push_input`.)
## Development only: it is not part of any export and the export presets do not include it.
##
## Run it with `tools/playground.sh [--case NAME] [--capture NAME]`, or directly:
## `godot --path . res://tools/playground/playground.tscn -- --case NAME --capture NAME`.
## `--capture` stops at that capture's drawn frame; without it the whole case replays. The side
## panel lists every case, its captures, frame/tick, stepping, play/pause and speed. Keyboard
## events go to the stage viewport, so the player can move the robot between steps (the shared
## runner supplies the case's own mouse clicks).
##
## Plugins (tools/playground/<name>.gd, `extends Node`) are optional. Each is instanced when
## present and gets `setup(playground)`; it can read and drive the playground through:
##   app, game() (the running Game or null), viewport, overlay (700×510 stage units, above the
##   stage), stage_view, side_panel, plugin_box (empty VBox at the bottom of the panel), runner,
##   case_name, capture_name;
##   signals case_loaded(case_name, capture_name) and stepped(frame);
##   func step(n), func set_playing(on: bool).
## Plugins are loaded by path (see PLUGINS), so a checkout without their .godot cache still parses.

const CaseRunnerScript := preload("res://tools/compare/case_runner.gd")
const GameScript := preload("res://scripts/game.gd")
const SwfScreen := preload("res://scripts/ui/swf_screen.gd")
const MAIN_SCENE := preload("res://scenes/main.tscn")

const CASES_DIR := "res://tools/compare/cases"
const SAVE_PATH := "user://playground-save.json"
const PLUGINS := ["res://tools/playground/inspector.gd", "res://tools/playground/overlays.gd",
	"res://tools/playground/spawn_panel.gd", "res://tools/playground/reference_peek.gd"]
const SPEEDS := [["0.25x", 0.25], ["0.5x", 0.5], ["1x", 1.0], ["2x", 2.0], ["4x", 4.0]]

signal case_loaded(case_name: String, capture_name: String)
signal stepped(frame: int)

@onready var side_panel: VBoxContainer = $Layout/SideBar/SideScroll/side_panel
@onready var stage_view: SubViewportContainer = $Layout/Stage/stage_view
@onready var viewport: SubViewport = $Layout/Stage/stage_view/ViewportHost/viewport
@onready var stage_texture: TextureRect = $Layout/Stage/stage_view/stage_texture
@onready var overlay: Control = $Layout/Stage/overlay
@onready var plugin_box: VBoxContainer = $Layout/SideBar/SideScroll/side_panel/plugin_box
@onready var case_option: OptionButton = $Layout/SideBar/SideScroll/side_panel/case_option
@onready var capture_option: OptionButton = $Layout/SideBar/SideScroll/side_panel/capture_option
@onready var load_button: Button = $Layout/SideBar/SideScroll/side_panel/load_button
@onready var frame_label: Label = $Layout/SideBar/SideScroll/side_panel/frame_label
@onready var step_one_button: Button = $Layout/SideBar/SideScroll/side_panel/actions/step_one
@onready var step_ten_button: Button = $Layout/SideBar/SideScroll/side_panel/actions/step_ten
@onready var play_button: Button = $Layout/SideBar/SideScroll/side_panel/actions/play
@onready var speed_option: OptionButton = $Layout/SideBar/SideScroll/side_panel/speed_option

## The app instanced from the main scene in the stage viewport (the comparison does the same).
var app: Node = null
## Replays the loaded case; null until a case is loaded.
var runner = null
var case_name := ""
var capture_name := ""
var speed := 1.0

var _cases: Array[Dictionary] = []
var _loading := false
var _playing := false
var _stepping := false
var _stage_clicked := false
var _accum := 0.0
var _label_clock := 0.0
var _previous_frame_locked := false
var _previous_capture_clock := false


func _ready() -> void:
	# The comparison's static hooks (tools/compare/godot_capture.gd): screens follow the stepped
	# frames and the round host is stepped by the capture, not by the window's clock.
	_previous_frame_locked = SwfScreen.frame_locked
	_previous_capture_clock = GameScript.capture_clock
	SwfScreen.frame_locked = true
	GameScript.capture_clock = true
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The shared CaseRunner pushes mouse/key events straight into the stage. A SubViewport
	# parented directly by a SubViewportContainer does not register its GUI roots for
	# `push_input` (Godot handles its input from the container instead), so the stage keeps the
	# viewport under a plain Node and paints its texture 1:1 in this container.
	viewport.handle_input_locally = true
	stage_texture.texture = viewport.get_texture()

	_scan_cases()
	_build_speed()
	case_option.item_selected.connect(_on_case_selected)
	capture_option.item_selected.connect(_on_capture_selected)
	load_button.pressed.connect(_on_load_pressed)
	step_one_button.pressed.connect(_on_step_one)
	step_ten_button.pressed.connect(_on_step_ten)
	play_button.pressed.connect(_on_play_pressed)
	speed_option.item_selected.connect(_on_speed_selected)
	if not _cases.is_empty():
		case_option.select(0)
		case_name = String(_cases[0].name)
		_fill_captures(_cases[0].data)
		capture_name = ""
	await _replace_app()
	_setup_plugins()
	_refresh_label()
	_apply_args.call_deferred()


func _process(delta: float) -> void:
	_label_clock -= delta
	if _label_clock <= 0.0:
		_label_clock = 0.1
		_refresh_label()
	if not _playing or _loading or runner == null:
		return
	_accum += delta * 35.0 * speed
	if _stepping:
		_accum = minf(_accum, 4.0)
		return
	# At most four frames per window frame: a slow draw must not make play sprint to catch up.
	var frames := mini(int(_accum), 4)
	if frames <= 0:
		return
	_accum -= frames
	_advance(frames)


## The round host of the loaded app, or null while the title screen (or no app) runs.
func game():
	if app == null or not is_instance_valid(app):
		return null
	var running = app.get("game")
	if running == null or not is_instance_valid(running):
		return null
	return running


## Step N frames through the shared runner; manual stepping pauses playback.
func step(n: int) -> void:
	if runner == null or _loading:
		return
	set_playing(false)
	await _advance(n)


func set_playing(on: bool) -> void:
	_playing = on and runner != null and not _loading
	if not _playing:
		_accum = 0.0
	play_button.text = "Pause" if _playing else "Play"


## Load a compare case and stop at `p_capture`'s drawn frame (an empty capture runs the whole
## case). With neither argument, the current `case_name`/`capture_name` are used.
func load_case(p_case = null, p_capture = null) -> void:
	if _loading:
		return
	var target := case_name if p_case == null else String(p_case)
	var cap := capture_name if p_capture == null else String(p_capture)
	var entry := _find_case(target)
	if entry.is_empty():
		push_error("playground: no compare case named %s" % target)
		return
	_loading = true
	set_playing(false)
	runner = null
	while _stepping:
		await get_tree().process_frame
	await _replace_app()
	case_name = String(entry.name)
	capture_name = cap if _has_capture(entry.data, cap) else ""
	_sync_options()
	runner = CaseRunnerScript.new(get_tree(), viewport)
	runner.stop_at_capture = capture_name
	_refresh_label()
	await runner.run(entry.data)
	_loading = false
	_refresh_label()
	case_loaded.emit(case_name, capture_name)


func _advance(frames: int) -> void:
	if runner == null or _stepping:
		return
	_stepping = true
	var active = runner
	await active.step(frames)
	_stepping = false
	# A load may have replaced the runner while the step awaited the next frame.
	if runner == active:
		stepped.emit(active.frame)
	_refresh_label()


func _replace_app() -> void:
	if is_instance_valid(app):
		viewport.remove_child(app)
		app.queue_free()
		app = null
		await get_tree().process_frame
	# The comparison starts with no SharedObject; the playground likewise starts with no save.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	app = MAIN_SCENE.instantiate()
	if "save_path" in app:
		app.save_path = SAVE_PATH
	viewport.add_child(app)
	await get_tree().process_frame


func _scan_cases() -> void:
	var dir := DirAccess.open(CASES_DIR)
	if dir == null:
		push_error("playground: cannot open %s" % CASES_DIR)
		return
	var files: Array[String] = []
	for file in dir.get_files():
		if file.ends_with(".json"):
			files.append(file)
	files.sort()
	for file in files:
		var data = JSON.parse_string(FileAccess.get_file_as_string(CASES_DIR.path_join(file)))
		if data is Dictionary:
			_cases.append({"name": String(data.get("name", file.get_basename())), "file": file, "data": data})
	_cases.sort_custom(func(a, b): return String(a.name) < String(b.name))
	for entry in _cases:
		case_option.add_item(String(entry.name))


func _find_case(target: String) -> Dictionary:
	var file := target.get_file()
	for entry in _cases:
		if String(entry.name) == target or String(entry.file) == file \
				or String(entry.file).get_basename() == file.get_basename():
			return entry
	return {}


func _has_capture(case: Dictionary, capture: String) -> bool:
	if capture.is_empty():
		return true
	for action in case.get("actions", []):
		if action is Dictionary and String(action.get("capture", "")) == capture:
			return true
	return false


func _fill_captures(case: Dictionary) -> void:
	capture_option.clear()
	capture_option.add_item("(whole case)")
	for action in case.get("actions", []):
		if action is Dictionary and action.has("capture"):
			capture_option.add_item(String(action.capture))
	capture_option.select(0)


func _sync_options() -> void:
	for index in _cases.size():
		if String(_cases[index].name) == case_name:
			case_option.select(index)
			_fill_captures(_cases[index].data)
			break
	var selected := 0
	for index in capture_option.item_count:
		if index > 0 and capture_option.get_item_text(index) == capture_name:
			selected = index
			break
	if selected == 0:
		capture_name = ""
	capture_option.select(selected)


func _build_speed() -> void:
	for entry in SPEEDS:
		speed_option.add_item(String(entry[0]))
		speed_option.set_item_metadata(speed_option.item_count - 1, float(entry[1]))
	speed_option.select(2)
	speed = 1.0


func _setup_plugins() -> void:
	for path in PLUGINS:
		if not ResourceLoader.exists(path):
			continue
		var script = load(path)
		if script == null:
			continue
		var plugin = script.new()
		if not plugin is Node:
			push_warning("playground: %s does not extend Node" % path)
			continue
		add_child(plugin)
		if plugin.has_method("setup"):
			plugin.setup(self)


func _apply_args() -> void:
	var args := OS.get_cmdline_user_args()
	var wanted := _arg(args, "--case")
	if wanted.is_empty():
		return
	case_name = wanted
	capture_name = _arg(args, "--capture")
	load_case()


func _refresh_label() -> void:
	var frame: int = int(runner.frame) if runner != null else 0
	var tick := "-"
	var running = game()
	if running != null:
		var state = running.get("state")
		if state is Dictionary and not state.is_empty():
			tick = str(int(running.get_snapshot().get("tick", 0)))
	frame_label.text = "frame %d  tick %s" % [int(frame), tick]


func _on_case_selected(index: int) -> void:
	if index < 0 or index >= _cases.size():
		return
	case_name = String(_cases[index].name)
	capture_name = ""
	_fill_captures(_cases[index].data)


func _on_capture_selected(index: int) -> void:
	capture_name = "" if index <= 0 else capture_option.get_item_text(index)


func _on_load_pressed() -> void:
	load_case()


func _on_step_one() -> void:
	step(1)


func _on_step_ten() -> void:
	step(10)


func _on_play_pressed() -> void:
	set_playing(not _playing)


func _on_speed_selected(index: int) -> void:
	speed = float(speed_option.get_item_metadata(index))


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
			_stage_clicked = stage_view.get_global_rect().has_point(mouse.position)
	if event is InputEventKey and viewport != null:
		if _stage_clicked or stage_view.get_global_rect().has_point(get_global_mouse_position()):
			viewport.push_input(event)
			get_viewport().set_input_as_handled()


func _arg(args: PackedStringArray, flag: String) -> String:
	var index := args.find(flag)
	return args[index + 1] if index >= 0 and index + 1 < args.size() else ""


func _exit_tree() -> void:
	_playing = false
	runner = null
	# Restore the static hooks the comparison owns (`godot_capture.gd` does the same on exit).
	SwfScreen.frame_locked = _previous_frame_locked
	GameScript.capture_clock = _previous_capture_clock

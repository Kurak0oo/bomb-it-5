extends Node2D
## Scene host: one scheduler, committed state, original painted presentation.

const Simulation = preload("res://scripts/simulation/bomb_simulation.gd")
const Scheduler = preload("res://scripts/simulation/tick_scheduler.gd")
const TouchControls = preload("res://scripts/touch_controls.gd")
const GameView = preload("res://scripts/game_view.gd")
const AIController = preload("res://scripts/simulation/ai_controller.gd")
const ACTORS: Array[StringName] = [&"human", &"ruby", &"mint", &"gold"]

var simulation: RefCounted
var scheduler: Node
var state: Dictionary
var practice := true
var paused := false
var held: Array[int] = []
var buttons: Dictionary = {}
var touch_controls: Node2D
var ai: RefCounted
var session_lives := 3
var total_score := 0
var result_credited := false
var view: Node2D


func _ready() -> void:
	view = GameView.new()
	add_child(view)
	touch_controls = TouchControls.new()
	add_child(touch_controls)
	touch_controls.direction_changed.connect(func(direction: Vector2):
		if is_instance_valid(scheduler): scheduler.set_direction(&"human", direction))
	touch_controls.bomb_event.connect(func(event: StringName):
		if is_instance_valid(scheduler): scheduler.enqueue_bomb_event(&"human", event))
	_make_button("match", "START MATCH", Vector2(1010, 100), func(): start_session(false))
	_make_button("practice", "PRACTICE", Vector2(1010, 148), func(): start_session(true))
	_make_button("pause", "PAUSE", Vector2(1010, 220), toggle_pause)
	_make_button("reset", "RESET", Vector2(1010, 268), retry_round)
	start_session(true)


func start_session(is_practice: bool = false, seed_value: int = -1) -> void:
	session_lives = 3
	total_score = 0
	_start_round(is_practice, seed_value)


func retry_round() -> void:
	if practice:
		start_session(true)
	elif state.outcome != &"running":
		if session_lives <= 0:
			start_session(false)
		else:
			_start_round(false)


func _start_round(is_practice: bool, seed_value: int = -1) -> void:
	if is_instance_valid(scheduler):
		scheduler.free()
	practice = is_practice
	paused = false
	result_credited = false
	held.clear()
	var board: Dictionary = {}
	var csv := FileAccess.open("res://assets/maps/cinema-stage1.csv", FileAccess.READ)
	csv.get_csv_line()
	while not csv.eof_reached():
		var row := csv.get_csv_line()
		if row.size() >= 3:
			board[Vector2i(int(row[0]), int(row[1]))] = StringName(row[2])
	var roster: Array[StringName] = []
	roster.assign([&"human"] if practice else ACTORS)
	var actors: Dictionary = {}
	var session_seed := Time.get_ticks_msec() if seed_value < 0 else seed_value
	var spawns := [Vector2i(1, 1), Vector2i(15, 1), Vector2i(1, 13), Vector2i(15, 13)]
	for index in roster.size():
		actors[roster[index]] = {"cell": spawns[index], "lives": session_lives if index == 0 else 1}
	simulation = Simulation.new(roster, actors, board,
		{"movement": true, "damage": true, "portals": true, "round": not practice,
		"drops": true, "seed": session_seed})
	scheduler = Scheduler.new(roster, simulation)
	add_child(scheduler)
	scheduler.set_process(false)
	ai = AIController.new(session_seed)
	if not practice:
		for id in roster.slice(1):
			scheduler.set_controller(id, _ai_command.bind(id))
	state = simulation.snapshot()
	touch_controls.enabled = true
	touch_controls.reset()
	buttons.pause.text = "PAUSE"
	buttons.pause.disabled = false
	buttons.reset.text = "RESET" if practice else "TRY AGAIN"
	buttons.reset.disabled = not practice
	_refresh()


func get_snapshot() -> Dictionary:
	var result := state.duplicate(true)
	result.paused = paused
	result.session = {"lives": session_lives if result_credited else state.actors[&"human"].lives,
		"total_score": total_score, "game_over": not practice and session_lives <= 0}
	return result


func _ai_command(id: StringName) -> Dictionary:
	return ai.command(simulation.snapshot(), id)


func advance_time(seconds: float) -> void:
	var update: Dictionary = scheduler.advance_time(seconds)
	for tick in update.ticks:
		state = tick
		if state.get("round_stage") == &"ending":
			touch_controls.enabled = false
			touch_controls.reset()
			held.clear()
		if not practice and state.outcome != &"running" and not result_credited:
			result_credited = true
			session_lives = state.actors[&"human"].lives
			total_score += state.result_score
			touch_controls.enabled = false
			touch_controls.reset()
			held.clear()
			buttons.pause.disabled = true
			buttons.reset.disabled = false
			buttons.reset.text = "NEW SESSION" if session_lives == 0 else "PLAY AGAIN" if state.outcome == &"won" else "TRY AGAIN"
	_refresh()


func toggle_pause() -> void:
	if not state.is_empty() and state.outcome != &"running":
		return
	if paused:
		if scheduler.resume():
			paused = false
	else:
		scheduler.pause()
		paused = true
	held.clear()
	touch_controls.enabled = not paused
	touch_controls.reset()
	buttons.pause.text = "RESUME" if paused else "PAUSE"
	_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(scheduler) and state.get("outcome", &"running") == &"running":
		scheduler.pause()
		paused = true
		held.clear()
		touch_controls.enabled = false
		touch_controls.reset()
		buttons.pause.text = "RESUME"
		_refresh()


func _process(delta: float) -> void:
	position = (get_viewport_rect().size - Vector2(1280, 720)) * 0.5
	if is_instance_valid(scheduler):
		advance_time(delta)


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.keycode == KEY_P and event.pressed and not event.echo:
			toggle_pause()
		elif event.keycode == KEY_SPACE and _can_control():
			scheduler.enqueue_bomb_event(&"human", &"down" if event.pressed else &"up")
		elif event.keycode in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT] and _can_control():
			if event.pressed and not event.echo:
				held.erase(event.keycode)
				held.append(event.keycode)
			elif not event.pressed:
				held.erase(event.keycode)
			var directions := {KEY_UP: Vector2.UP, KEY_DOWN: Vector2.DOWN,
				KEY_LEFT: Vector2.LEFT, KEY_RIGHT: Vector2.RIGHT}
			scheduler.set_direction(&"human", Vector2.ZERO if held.is_empty() else directions[held.back()])


func _make_button(key: String, caption: String, position_at: Vector2, action: Callable) -> void:
	var button := Button.new()
	button.name = key.capitalize()
	button.text = caption
	button.position = position_at
	button.size = Vector2(210, 40)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color("f7f1dc"))
	button.add_theme_color_override("font_hover_color", Color("fff0bc"))
	button.add_theme_color_override("font_pressed_color", Color("fff0bc"))
	button.add_theme_color_override("font_disabled_color", Color("77949e"))
	for state_name in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("315a6a") if state_name == "normal" else Color("427687") if state_name == "hover" else Color("1a374a")
		style.border_color = Color("87b6b6") if state_name != "disabled" else Color("355364")
		if key == "match" and state_name != "disabled":
			style.bg_color = Color("b97643") if state_name == "normal" else Color("cd9656") if state_name == "hover" else Color("86532e")
			style.border_color = Color("ffe1a0")
		style.set_border_width_all(1)
		style.border_width_top = 2
		style.shadow_color = Color("0c182b", 0.55)
		style.shadow_size = 2
		style.shadow_offset = Vector2(0, 3 if state_name != "pressed" else 1)
		style.set_corner_radius_all(10)
		button.add_theme_stylebox_override(state_name, style)
	button.pressed.connect(action)
	add_child(button)
	buttons[key] = button



func _refresh() -> void:
	if is_instance_valid(view) and not state.is_empty():
		touch_controls.enabled = _can_control()
		touch_controls.action_kind = state.actors[&"human"].weapon if state.actors[&"human"].weapon != &"" else &"bomb"
		view.present(get_snapshot(), practice, paused)


func _can_control() -> bool:
	return not paused and not state.is_empty() and state.outcome == &"running" and state.get("round_stage") != &"ending" and state.actors[&"human"].alive

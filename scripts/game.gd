extends Node2D
## Scene host: one scheduler, committed state, original procedural presentation.

const Simulation = preload("res://scripts/simulation/bomb_simulation.gd")
const Scheduler = preload("res://scripts/simulation/tick_scheduler.gd")
const TouchControls = preload("res://scripts/touch_controls.gd")
const GameView = preload("res://scripts/game_view.gd")
const AIController = preload("res://scripts/simulation/ai_controller.gd")
const VisualSkin = preload("res://scripts/art/skin.gd")
const BoardData = preload("res://scripts/simulation/board_data.gd")
const ArcadeMode = preload("res://scripts/simulation/modes/arcade_mode.gd")
const AIProfiles = preload("res://scripts/simulation/ai_profiles.gd")
const Layouts = preload("res://scripts/simulation/layouts.gd")
const StageSets = preload("res://scripts/simulation/stage_sets.gd")
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
var visual_skin: RefCounted
var stage_set: StringName = &""


func _ready() -> void:
	if visual_skin == null: visual_skin = VisualSkin.new()
	view = GameView.new()
	view.skin = visual_skin
	add_child(view)
	touch_controls = TouchControls.new()
	touch_controls.skin = visual_skin
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
	stage_set = &""
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
	var profile: Dictionary = AIProfiles.for_mode(&"arcade", &"normal")
	var roster: Array[StringName] = []
	roster.assign([&"human"] if practice else ACTORS)
	var actors: Dictionary = {}
	var session_seed := Time.get_ticks_msec() if seed_value < 0 else seed_value
	var mode := ArcadeMode.new()
	var board: Dictionary
	if practice:
		board = BoardData.load_instance("res://assets/maps/cinema-stage1.csv")
	else:
		var rng := RandomNumberGenerator.new()
		rng.seed = session_seed
		var choices := StageSets.available_sets()
		if stage_set == &"": stage_set = choices[rng.randi_range(0, choices.size() - 1)]
		mode.stage_set = stage_set
		board = Layouts.roll_set(stage_set, false, mode.soft_chance(), rng)
	for index in roster.size():
		actors[roster[index]] = {"cell": board.spawns[index], "lives": session_lives if index == 0 else 1}
		if index > 0:
			actors[roster[index]].merge({"speed": profile.speed, "power": profile.power, "capacity": profile.capacity})
	simulation = Simulation.new(roster, actors, board.cells,
		{"movement": true, "damage": true, "portals": board.portals, "round": not practice,
		"drops": true, "seed": session_seed, "mode": mode,
		"vehicles": StageSets.vehicles(board.skin),
		"board_meta": {"skin": board.skin, "layout": board.layout, "size": board.size,
			"variants": board.get("variants", {}), "center": board.get("center", Vector2i(7, 6))}})
	scheduler = Scheduler.new(roster, simulation)
	add_child(scheduler)
	scheduler.set_process(false)
	ai = AIController.new(session_seed, [], profile)
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
	for state_name in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("285768") if state_name == "normal" else Color("39788a") if state_name == "hover" else Color("1b4052")
		style.border_color = Color("7fb6b7") if state_name != "disabled" else Color("3b616a")
		style.set_border_width_all(1)
		style.set_corner_radius_all(9)
		button.add_theme_stylebox_override(state_name, style)
		var replacement: Texture2D = visual_skin.button_texture("ui.button_" + state_name)
		if replacement != null:
			var texture_style := StyleBoxTexture.new()
			texture_style.texture = replacement
			texture_style.modulate_color = Color(visual_skin.entry("ui.button_" + state_name).get("tint", "ffffffff"))
			button.add_theme_stylebox_override(state_name, texture_style)
	button.pressed.connect(action)
	add_child(button)
	buttons[key] = button



func _refresh() -> void:
	if is_instance_valid(view) and not state.is_empty():
		touch_controls.enabled = _can_control()
		view.present(get_snapshot(), practice, paused)


func _can_control() -> bool:
	return not paused and not state.is_empty() and state.outcome == &"running" and state.get("round_stage") != &"ending" and state.actors[&"human"].alive

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
const Modes = preload("res://scripts/simulation/modes/modes.gd")
const SaveStore = preload("res://scripts/save_store.gd")
const Fidelity = preload("res://scripts/fidelity.gd")
const ReplicaLayout = preload("res://scripts/replica_layout.gd")
const ReplicaScenery = preload("res://scripts/replica_scenery.gd")
const ReplicaHud = preload("res://scripts/replica_hud.gd")
const ACTORS: Array[StringName] = [&"human", &"ruby", &"mint", &"gold"]
## Seat robots for the standalone match (Blue, Ruby, Mint, Gold); a session chooses its own.
const DEFAULT_ROBOTS: Array[int] = [0, 1, 6, 3]

## A session-driven level finished its ending; the host shows the score screen.
signal level_settled(snapshot: Dictionary)
signal main_menu_requested

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
## Set before entering the tree: a session drives levels and hides development controls.
var session: RefCounted = null
var auto_start := true
## Desktop key per action (up/left/down/right/bomb); the app supplies saved bindings.
var bindings: Dictionary = SaveStore.DEFAULT_KEYS.duplicate()
## The replica page (ReplicaLayout) under the `original` profile, fixed when the node is ready.
var replica := false
var scenery: Node2D
var hud: Node2D
## Tests pin the safe area; otherwise it is read from the display every frame.
var safe_area_override := Rect2()
## The step before `state`, for drawing between steps (#79); never fed back to the round.
var previous_state: Dictionary = {}
## The replica round clock's second source (#80): the wall clock unless checks inject one.
static var seconds_source: Callable
## Original pause (#81, `Game.gamePause`): the request takes effect `PAUSE_DELAY_STEPS` steps
## later (`setTimeout(doGamePause, 100)`); -1 when none is pending.
const PAUSE_DELAY_STEPS := 4
var pause_after := -1
## Wall clock in milliseconds for paused time; checks inject one.
static var msec_source: Callable
var _paused_at_msec := 0


func _ready() -> void:
	if visual_skin == null: visual_skin = VisualSkin.new()
	view = GameView.new()
	view.skin = visual_skin
	add_child(view)
	replica = Fidelity.original
	if replica:
		view.compact = true
		view.scale = Vector2.ONE * ReplicaLayout.view_scale()
		view.position = ReplicaLayout.view_position()
		scenery = ReplicaScenery.new()
		scenery.name = "Scenery"
		scenery.skin = visual_skin
		add_child(scenery)
	touch_controls = TouchControls.new()
	touch_controls.skin = visual_skin
	touch_controls.replica = Fidelity.original
	add_child(touch_controls)
	touch_controls.direction_changed.connect(func(direction: Vector2):
		if is_instance_valid(scheduler): scheduler.set_direction(&"human", direction))
	touch_controls.bomb_event.connect(func(event: StringName):
		if is_instance_valid(scheduler): scheduler.enqueue_bomb_event(&"human", event))
	if replica:
		hud = ReplicaHud.new()
		hud.name = "Hud"
		hud.skin = visual_skin
		hud.pause_pressed.connect(toggle_pause)
		add_child(hud)
	_make_button("match", "START MATCH", Vector2(1010, 100), func(): start_session(false))
	_make_button("practice", "PRACTICE", Vector2(1010, 148), func(): start_session(true))
	_make_button("pause", "PAUSE", Vector2(1010, 220), toggle_pause)
	_make_button("reset", "RESET", Vector2(1010, 268), retry_round)
	_make_button("menu", "MAIN MENU", Vector2(1010, 268), func(): main_menu_requested.emit())
	buttons.menu.visible = false
	if session != null or replica:
		for key in ["match", "practice", "reset"]: buttons[key].visible = false
	if replica:
		# Development and caption-free page: pause comes from the pause icon (#91) and P;
		# RESUME and MAIN MENU appear only on the pause overlay over the map centre.
		buttons.pause.visible = false
		_place_pause_button(buttons.pause, hud.pause_to_page(hud.PAUSE_RESUME))
		_place_pause_button(buttons.menu, hud.pause_to_page(hud.PAUSE_MENU))
	if auto_start: start_session(true)


## Starts the session's current level on a freshly rolled board.
func play_level() -> void:
	session_lives = session.lives
	total_score = session.total_score
	stage_set = session.current_set
	_start_round(false, session.next_seed())


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
	pause_after = -1
	result_credited = false
	held.clear()
	var mode_name: StringName = session.mode if session != null else &"arcade"
	var difficulty: StringName = session.difficulty if session != null else &"normal"
	var profile: Dictionary = AIProfiles.for_mode(mode_name, difficulty)
	var roster: Array[StringName] = []
	roster.assign([&"human"] if practice else ACTORS.slice(0, 1 + (session.enemies if session != null else 3)))
	var robots: Array[int] = DEFAULT_ROBOTS.duplicate()
	if session != null: robots.assign([session.robot] + session.ai_robots)
	var actors: Dictionary = {}
	var session_seed := Time.get_ticks_msec() if seed_value < 0 else seed_value
	var mode: RefCounted = Modes.create(mode_name, difficulty, &"cinema")
	var board: Dictionary
	if practice:
		board = BoardData.load_instance("res://assets/maps/cinema-stage1.csv")
	else:
		var rng := RandomNumberGenerator.new()
		rng.seed = session_seed
		var choices := StageSets.available_sets()
		if stage_set == &"": stage_set = choices[rng.randi_range(0, choices.size() - 1)]
		mode.stage_set = stage_set
		board = Layouts.roll_set(stage_set, mode_name == &"pac_man", mode.soft_chance(), rng)
	for index in roster.size():
		actors[roster[index]] = {"cell": board.spawns[index], "lives": session_lives if index == 0 else 1, "robot": robots[index]}
		if session != null:
			var look: Array = [session.hat, session.body] if index == 0 else session.ai_looks[index - 1]
			actors[roster[index]].merge({"hat": look[0], "body": look[1]})
		if index > 0:
			actors[roster[index]].merge({"speed": profile.speed, "power": profile.power, "capacity": profile.capacity})
		else:
			actors[roster[index]].speed = mode.player_speed()
	simulation = Simulation.new(roster, actors, board.cells,
		{"movement": true, "damage": true, "portals": board.portals, "round": not practice,
		"drops": true, "seed": session_seed, "mode": mode, "seconds": _seconds_source() if replica else null, "hit_move": replica,
		"vehicles": StageSets.vehicles(board.skin),
		"features": board.get("features", {}), "center": board.get("center"), "skin": board.skin,
		"board_meta": {"skin": board.skin, "layout": board.layout, "size": board.size,
			"variants": board.get("variants", {}), "center": board.get("center", Vector2i(7, 6)),
			"portal_ids": board.get("portal_ids", {})}})
	scheduler = Scheduler.new(roster, simulation)
	scheduler.frame_driven = replica
	add_child(scheduler)
	scheduler.set_process(false)
	ai = AIController.new(session_seed, [], profile)
	if not practice:
		for id in roster.slice(1):
			scheduler.set_controller(id, _ai_command.bind(id))
	state = simulation.snapshot()
	previous_state = {}
	if replica: scenery.set_stage(board.skin)
	touch_controls.enabled = true
	touch_controls.reset()
	buttons.pause.text = "PAUSE"
	buttons.pause.disabled = false
	if replica: buttons.pause.visible = false
	buttons.menu.visible = false
	buttons.reset.text = "RESET" if practice else "TRY AGAIN"
	buttons.reset.disabled = not practice
	_refresh()


## `Game.countTime` polls `new Date().getSeconds()`; checks inject a deterministic source.
func _seconds_source() -> Callable:
	if seconds_source.is_valid(): return seconds_source
	return func() -> int: return Time.get_datetime_dict_from_system().second


func get_snapshot() -> Dictionary:
	var result := state.duplicate(true)
	result.paused = paused
	result.session = {"lives": session_lives if result_credited else state.actors[&"human"].lives,
		"total_score": total_score, "game_over": not practice and session_lives <= 0,
		"level": session.level_text() if session != null else ""}
	result.bindings = bindings
	return result


func _ai_command(id: StringName) -> Dictionary:
	return ai.command(simulation.snapshot(), id)


func advance_time(seconds: float) -> void:
	var update: Dictionary = scheduler.advance_time(seconds)
	for tick in update.ticks:
		previous_state = state
		state = tick
		if pause_after > 0:
			pause_after -= 1
			if pause_after == 0 and state.outcome == &"running":
				_begin_original_pause()
				return
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
			if session != null:
				level_settled.emit(get_snapshot())
				return
	_refresh()


func toggle_pause() -> void:
	if not state.is_empty() and state.outcome != &"running":
		return
	if replica and not paused:
		# `gamePause` waits 100 ms; a second press inside that window cancels it (`gameResume`
		# with `gamePaused` still false clears the timeout).
		pause_after = PAUSE_DELAY_STEPS if pause_after < 0 else -1
		return
	if paused:
		if scheduler.resume():
			paused = false
			if replica: _credit_paused_time()
	else:
		scheduler.pause()
		paused = true
	held.clear()
	touch_controls.enabled = not paused
	touch_controls.reset()
	buttons.pause.text = "RESUME" if paused else "PAUSE"
	buttons.menu.visible = paused and session != null
	if replica: buttons.pause.visible = paused
	_refresh()


## The pause takes effect: the engine stops and every robot's movement stage is cleared.
func _begin_original_pause() -> void:
	pause_after = -1
	scheduler.pause()
	paused = true
	simulation.hold_movement()
	_paused_at_msec = _now_msec()
	held.clear()
	touch_controls.enabled = false
	touch_controls.reset()
	buttons.pause.text = "RESUME"
	buttons.pause.visible = true
	buttons.menu.visible = session != null
	_refresh()


## TweenMax timers kept running while the engine was stopped.
func _credit_paused_time() -> void:
	var steps := roundi((_now_msec() - _paused_at_msec) * Scheduler.TICKS_PER_SECOND / 1000.0)
	simulation.pass_host_time(steps)
	if ai != null: ai.pass_host_time(steps, state.get("tick", 0))


func _now_msec() -> int:
	return msec_source.call() if msec_source.is_valid() else Time.get_ticks_msec()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(scheduler) and state.get("outcome", &"running") == &"running":
		# Leaving the app pauses at once (Q15); no frames run in the background to wait 100 ms.
		if replica and not paused:
			_begin_original_pause()
			return
		scheduler.pause()
		paused = true
		held.clear()
		touch_controls.enabled = false
		touch_controls.reset()
		buttons.pause.text = "RESUME"
		buttons.menu.visible = session != null
		if replica: buttons.pause.visible = true
		_refresh()


func _process(delta: float) -> void:
	fit_page()
	if is_instance_valid(scheduler):
		advance_time(delta)


## Centres the 1280×720 page on the screen; the replica also keeps it inside the safe area,
## re-read every frame so rotation re-lays it out.
func fit_page(viewport: Vector2 = get_viewport_rect().size) -> void:
	if not replica:
		position = (viewport - ReplicaLayout.PAGE) * 0.5
		return
	var safe := safe_area_override if safe_area_override.has_area() else ReplicaLayout.safe_area(viewport)
	var placement := ReplicaLayout.fit(viewport, safe)
	position = placement.offset
	scale = Vector2.ONE * placement.scale


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.keycode == KEY_P and event.pressed and not event.echo:
			toggle_pause()
		elif event.keycode == bindings.bomb and _can_control():
			scheduler.enqueue_bomb_event(&"human", &"down" if event.pressed else &"up")
		elif event.keycode in [bindings.up, bindings.down, bindings.left, bindings.right] and _can_control():
			if event.pressed and not event.echo:
				held.erase(event.keycode)
				held.append(event.keycode)
			elif not event.pressed:
				held.erase(event.keycode)
			var directions := {bindings.up: Vector2.UP, bindings.down: Vector2.DOWN,
				bindings.left: Vector2.LEFT, bindings.right: Vector2.RIGHT}
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



## RESUME and MAIN MENU on the replica's pause screen: ghosts over the painted buttons when
## the original art is shown (ADR 0009), native buttons otherwise.
func _place_pause_button(button: Button, rect: Rect2) -> void:
	button.position = rect.position
	button.size = rect.size
	if hud.pause_art():
		var clear := StyleBoxEmpty.new()
		for name in ["normal", "hover", "pressed", "disabled", "focus"]: button.add_theme_stylebox_override(name, clear)
		button.add_theme_color_override("font_color", Color.TRANSPARENT)
		button.add_theme_color_override("font_hover_color", Color.TRANSPARENT)
		button.add_theme_color_override("font_pressed_color", Color.TRANSPARENT)


func _refresh() -> void:
	if is_instance_valid(view) and not state.is_empty():
		touch_controls.enabled = _can_control()
		var snapshot := get_snapshot()
		var between: float = scheduler.interpolation() if replica and not paused and is_instance_valid(scheduler) else 1.0
		view.present(snapshot, practice, paused, previous_state, between)
		if replica:
			hud.present(snapshot, paused)
			var weapon: StringName = snapshot.actors[&"human"].get("weapon", &"")
			touch_controls.item = &"" if weapon in [&"", &"none"] else weapon


func _can_control() -> bool:
	return not paused and not state.is_empty() and state.outcome == &"running" and state.get("round_stage") != &"ending" and state.actors[&"human"].alive

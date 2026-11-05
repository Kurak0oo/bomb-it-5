extends Node2D
## Scene host: one scheduler, committed state, keyboard input and the round's flow. It draws
## nothing itself: the app shows the round on the generated gameplay screen (App._game_screen),
## with `swf_view` (scripts/game_view.gd) for what has no original art yet.

const Simulation = preload("res://scripts/simulation/bomb_simulation.gd")
const Scheduler = preload("res://scripts/simulation/tick_scheduler.gd")
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
const Looks = preload("res://scripts/looks.gd")
const Audio = preload("res://scripts/original_audio.gd")
const ACTORS: Array[StringName] = [&"human", &"ruby", &"mint", &"gold"]
## Seat robots for the standalone match (Blue, Ruby, Mint, Gold); a session chooses its own.
const DEFAULT_ROBOTS: Array[int] = [0, 1, 6, 3]

## A session-driven level finished its ending; the host shows the score screen.
signal level_settled(snapshot: Dictionary)
signal main_menu_requested
## The round paused or resumed (`doGamePause` / `gameResume`): the generated gameplay
## screen shows the original pause screen (App, scripts/ui/pause_ui.gd).
signal pause_changed(is_paused: bool)

var simulation: RefCounted
var scheduler: Node
var state: Dictionary
var practice := true
var paused := false
var held: Array[int] = []
var ai: RefCounted
var session_lives := 3
var total_score := 0
var result_credited := false
var visual_skin: RefCounted
var stage_set: StringName = &""
## Set before entering the tree: a session drives levels and hides development controls.
var session: RefCounted = null
var auto_start := true
## Desktop key per action (up/left/down/right/bomb); the app supplies saved bindings.
var bindings: Dictionary = SaveStore.DEFAULT_KEYS.duplicate()
## The `original` fidelity profile (frame-driven steps, HitMove, the Date clock), fixed when
## the node is ready.
var replica := false
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
## The generated gameplay screen (App._game_screen): its placeholder actors view, drawn in
## the screen's board container, and what the screen reads from each snapshot (the
## board's boxes, GameInterFace's fields).
var swf_view: Node2D
var _swf_present: Callable
## Frames before the round's first step: the original builds the map one row per
## Timer(100) tick under its loading screen and starts the round 100 ms after
## (`MapMaster.timerHandle`, `Game.firstMapLoadOver`); the recorded number of frames
## (layout `board.round_start_after_input`).
var start_delay := 0:
	set(frames):
		start_delay = frames
		_delay_from = Engine.get_process_frames()
var _delay_from := -1
## A recorded board for the next round (the comparison loop's `round` action).
var recorded_board: Dictionary = {}
## The original's `Math.random` (scripts/simulation/avm_random.gd) the round draws from; the
## app shares its own (`App.math_random`). Unset, the round uses Godot's generator.
var math_random: RefCounted
## The generated gameplay screen shows the original pause screen: the page's own pause
## art and buttons stay hidden.
var swf_pause := false
const AvmRandom = preload("res://scripts/simulation/avm_random.gd")


func _ready() -> void:
	if visual_skin == null: visual_skin = VisualSkin.new()
	replica = Fidelity.original
	if auto_start: start_session(true)


## Starts the session's current level on a freshly rolled board.
func play_level() -> void:
	session_lives = session.lives
	total_score = session.total_score
	stage_set = session.current_set
	_start_round(false, session.next_seed())
	# `gameStartHandler` starts the round's music once the board is up.
	if Audio.current != null: Audio.current.create_game_music()


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
	var draws: Array = []
	var round_random: RefCounted = math_random
	var rolled := false
	if practice:
		board = BoardData.load_instance("res://assets/maps/cinema-stage1.csv")
	elif not recorded_board.is_empty():
		board = Layouts.recorded(recorded_board.template, recorded_board.boxes)
		if recorded_board.has("math_random"):
			var place := _recorded_draws(recorded_board.math_random)
			draws = place.pool
			round_random = place.random
		stage_set = board.skin
		mode.stage_set = stage_set
		recorded_board = {}
	else:
		rolled = true
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
		"drops": true, "seed": session_seed, "random_draws": draws, "math_random": round_random, "mode": mode, "seconds": _seconds_source() if replica else null, "hit_move": replica, "glove_items": replica,
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
	# The AI draws from the round's `Math.random` when the round has the original's.
	if round_random != null and not practice: ai.math_random = round_random
	if rolled and round_random != null and session != null and session.math_random != null:
		_create_ai_players(round_random, roster)
	if not practice:
		for id in roster.slice(1):
			scheduler.set_controller(id, _ai_command.bind(id))
	state = simulation.snapshot()
	previous_state = {}
	_refresh()


## A rolled round's draws after the map, in the original's order: the player's `updateUI`
## (`AbstractPlayer.set scoreData`, two draws, traced: tools/compare/round_draws.py), then
## `AbstractGameMode.createAIPlayer` per AI: clothID `int(random * 7)`, hatID `int(random * 7)`,
## and its AI from the difficulty's list (`_xml.ai[difficulty].split("|")`; one profile in
## every mode, so the draw picks nothing). The map's own draws (`MapMaster`, `<Set>MapData`)
## are still Godot's (Layouts.roll_set), so these do not land on the original's ordinals.
func _create_ai_players(random: RefCounted, roster: Array[StringName]) -> void:
	random.random()
	random.random()
	for id in roster.slice(1):
		var cloth := int(random.random() * 7)
		var hat := int(random.random() * 7)
		random.random()
		var actor: Dictionary = simulation.actors()[id]
		# `setRobotMc` sends the look clips to id + 1; past a clip's last frame Flash stays on
		# its last frame, so a robot with fewer looks wears its last one.
		actor.body = mini(cloth, Looks.count(int(actor.get("robot", 0)), &"body"))
		actor.hat = mini(hat, Looks.count(int(actor.get("robot", 0)), &"hat"))


## Where the original's `Math.random` stands at a recorded round (tests/goldens/<case>/
## math_random.json, tools/compare/round_draws.py): the drop pool's Vehicle entries were drawn
## at `pool_draws` (`AbstractGameMode.initMap`), and the round's own draws continue after
## `draws_before_round` (the menus', the map's and the AI players' draws, which Godot takes
## from the recording instead). The same seed's generator replays them (checked against the
## recorded raw draws).
static func _recorded_draws(record: Dictionary) -> Dictionary:
	var random: RefCounted = AvmRandom.new(int(record.seed))
	var pool := []
	var pool_draws: Array = record.pool_draws.map(func(n): return int(n))
	var raw: Array = record.get("raw", [])
	for ordinal in range(1, int(record.draws_before_round) + 1):
		var value: int = random.next_raw()
		if ordinal <= raw.size() and int(raw[ordinal - 1]) != value:
			push_error("the original's draw %d does not match the Math.random port" % ordinal)
		if ordinal in pool_draws: pool.append(float(value) / 2147483648.0)
	return {"pool": pool, "random": random}


## The `Math.random` the round draws from (the original's, for a recorded round from where
## it stood), shared by the screens made during the round (PauseUI).
func round_random() -> RefCounted:
	var source: RefCounted = simulation.random_source() if simulation != null else null
	return source if source != null else math_random


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


## The comparison loop only (`ai-stop N`, where the case stops the original's AI with the
## `ai-control stop` fixture, `AIControl.stop`): the AI robot of seat N gets no more commands.
func stop_ai(seat: int) -> void:
	var roster: Array = state.get("actors", {}).keys()
	if seat <= 0 or seat >= roster.size(): return
	scheduler.set_controller(roster[seat], func() -> Dictionary: return {"direction": Vector2.ZERO, "bomb_events": []})


## The comparison loop only (`pickup KIND`, where the case uses the reference player's `pickup`
## fixture: the original's pickup class made on the player's cell, `AbstractItem.init`): the
## pickup lies on the player's cell, and the round's next step collects it.
func give_pickup(kind: StringName) -> void:
	var human: Dictionary = simulation.actors()[&"human"]
	simulation.pickups()[human.cell] = kind


func _ai_command(id: StringName) -> Dictionary:
	return ai.command(simulation.snapshot(), id)


func advance_time(seconds: float) -> void:
	var update: Dictionary = scheduler.advance_time(seconds)
	for tick in update.ticks:
		var was_ending: bool = state.get("round_stage") == &"ending"
		previous_state = state
		state = tick
		_play_audio(was_ending)
		if pause_after > 0:
			pause_after -= 1
			if pause_after == 0 and state.outcome == &"running":
				_begin_original_pause()
				return
		if state.get("round_stage") == &"ending":
			held.clear()
		if not practice and state.outcome != &"running" and not result_credited:
			result_credited = true
			session_lives = state.actors[&"human"].lives
			total_score += state.result_score
			held.clear()
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
		if pause_after < 0:
			pause_after = PAUSE_DELAY_STEPS
		else:
			pause_after = -1
			# The cancelling `gameResume` calls `createGameMusic`: the round's track starts
			# again and the next round's choice moves on.
			if Audio.current != null: Audio.current.create_game_music()
		return
	if paused:
		if scheduler.resume():
			paused = false
			if replica: _credit_paused_time()
			# `doGameResume` restarts the music 100 ms later, from the start of the track.
			if Audio.current != null: Audio.current.restart_game_music()
	else:
		scheduler.pause()
		paused = true
	held.clear()
	_refresh()
	pause_changed.emit(paused)


## The step's sounds, and the win or lose jingle when the ending begins (`win`/`lose`:
## `stopPause` stops the round music, then `playWinMusic`/`playLoseMusic`).
func _play_audio(was_ending: bool) -> void:
	var audio := Audio.current
	if audio == null: return
	audio.play_sounds(state.get("sounds", []))
	if was_ending or state.get("round_stage") != &"ending": return
	audio.pause_game_music()
	audio.null_game_music()
	var outcome: StringName = state.get("pending_outcome", &"")
	var won: bool = outcome == &"won" or (outcome == &"timeout" and state.get("mode") == &"arcade" and Fidelity.timeout_wins())
	if won: audio.create_level_complete_music()
	else: audio.create_level_failed_music()


## The pause takes effect: the engine stops and every robot's movement stage is cleared.
func _begin_original_pause() -> void:
	pause_after = -1
	scheduler.pause()
	paused = true
	if Audio.current != null: Audio.current.pause_game_music()
	simulation.hold_movement()
	_paused_at_msec = _now_msec()
	held.clear()
	_refresh()
	pause_changed.emit(true)


## TweenMax timers kept running while the engine was stopped.
func _credit_paused_time() -> void:
	var steps := roundi((_now_msec() - _paused_at_msec) * Scheduler.TICKS_PER_SECOND / 1000.0)
	simulation.pass_host_time(steps)
	if ai != null: ai.pass_host_time(steps, state.get("tick", 0))


func _now_msec() -> int:
	return msec_source.call() if msec_source.is_valid() else Time.get_ticks_msec()


func _notification(what: int) -> void:
	# iOS sends PAUSED when the app goes to the background as well as FOCUS_OUT on resign.
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED] and is_instance_valid(scheduler) and state.get("outcome", &"running") == &"running":
		# Leaving the app pauses at once (Q15); no frames run in the background to wait 100 ms.
		if replica and not paused:
			_begin_original_pause()
			return
		scheduler.pause()
		paused = true
		held.clear()
		_refresh()
		pause_changed.emit(true)


func _process(delta: float) -> void:
	if start_delay > 0:
		# The frame the round was made in (by START's press) is not one of them: input lands
		# between the original's frames, so its next frame is the first (as SwfScreen).
		if Engine.get_process_frames() != _delay_from: start_delay -= 1
		return
	if is_instance_valid(scheduler):
		advance_time(delta)


## Before a new round's screen: the previous one's placeholder layer goes.
func detach_swf() -> void:
	if is_instance_valid(swf_view): swf_view.queue_free()
	swf_view = null
	_swf_present = Callable()
	start_delay = 0
	swf_pause = false


## Draw the round on the generated gameplay screen: `present` is called with every snapshot,
## and the placeholder layer (scripts/game_view.gd: what has no original art yet; the board
## itself for a stage set whose art is not in the pack) sits in `parent`, the screen's board
## container, through `transform`.
func attach_swf(parent: Node2D, transform_in_parent: Transform2D, present: Callable, draw_board := false) -> void:
	swf_view = GameView.new()
	swf_view.name = "PlaceholderLayer"
	swf_view.skin = visual_skin
	swf_view.draw_board = draw_board
	swf_view.transform = transform_in_parent
	parent.add_child(swf_view)
	# A board drawn here goes under the row layers (its boxes, robots and bombs).
	if draw_board: parent.move_child(swf_view, 0)
	_swf_present = present
	_refresh()


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


func _refresh() -> void:
	if is_instance_valid(swf_view) and not state.is_empty():
		var snapshot := get_snapshot()
		var between: float = scheduler.interpolation() if replica and not paused and is_instance_valid(scheduler) else 1.0
		swf_view.present(snapshot, practice, paused, previous_state, between)
		_swf_present.call(snapshot)


func _can_control() -> bool:
	return not paused and not state.is_empty() and state.outcome == &"running" and state.get("round_stage") != &"ending" and state.actors[&"human"].alive

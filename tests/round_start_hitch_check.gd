extends SceneTree
## The owner's report (2026-11-24): "when entering games after the game menu, there is an
## instant stuck for a few seconds". The round used to prepare all of its art on the frame
## the map finished loading: it scanned ~2,200 files, pinned them in one loop and started
## ~2,200 WorkerThreadPool tasks there, which stalled the main thread for seconds at full
## window scale.
##
## This check starts a game the way the player does, from the main menu, and times every
## frame until the round's first tick. The art is now prepared behind the loading screen and
## resampled in batches. Budget: 100 ms. Measured on this Mac (2026-11-24), the old path's
## worst frame was 2,176 ms and it held ~600 ms frames for ten more; the fixed path's worst
## frame is ~71 ms. A frame of 100 ms is the largest hitch a player does not read as a stop,
## and it leaves headroom over the 1/35 s original frame for this machine and a windowed
## (full-scale) run.
##
## It also asserts the round's first displayed tick draws every robot with its own clip art:
## the fix must not bring back the hidden/blank robot or the stale direction. Three
## scenarios:
## - a normal menu -> game run, the baseline for the tick the loading screen closes on;
## - the same run with the 78 MB parse held for HOLD_FRAMES (a cold/slow machine): the
##   loading screen and the round's clock must both wait, so the closing and first displayed
##   ticks match the baseline, and no frame may stall;
## - a round with no loading screen: its first tick is held until the actor display can
##   build the robots, so no tick is ever drawn without them.

const GameActors = preload("res://scripts/ui/game_actors.gd")
const GameBoard = preload("res://scripts/ui/game_board.gd")
const Game = preload("res://scripts/game.gd")
const SwfScreen = preload("res://scripts/ui/swf_screen.gd")
const BUDGET_USEC := 100_000
const MAX_FRAMES := 600
## Frames the parse is held for before the test releases it: a cold machine's 78 MB parse,
## long past the point where the old path would have waited for it on the main thread.
const HOLD_FRAMES := 120
var failures := 0
var checks := 0
var frames := 0
var worst_usec := 0
var worst_frame := 0
var _parse_gate: Semaphore


func _initialize() -> void:
	# Real time and real resamples: the freeze is a main-thread stall at window scale.
	SwfScreen.frame_locked = false
	_run.call_deferred()


func _run() -> void:
	if not FileAccess.file_exists("res://original/screens/game/actors/actors.json"):
		print("SKIP: round start hitch checks need the local actors pack")
		quit(0)
		return
	root.size = Vector2i(1280, 720)
	var baseline := await _app_round(false)
	var held := await _app_round(true)
	_expect(baseline.reached and held.reached, "the parsed and held runs reach the first displayed tick")
	if baseline.reached and held.reached:
		_expect(held.closed_tick == baseline.closed_tick,
			"the tick when the loading screen closes is the same with the parse held (%d vs %d)"
				% [held.closed_tick, baseline.closed_tick])
		_expect(held.first_tick == baseline.first_tick,
			"the first displayed tick is the same with the parse held (%d vs %d)"
				% [held.first_tick, baseline.first_tick])
	_expect(worst_usec <= BUDGET_USEC, "no frame in the menu -> round transition exceeds %d ms (worst %.1f ms at frame %d)"
		% [BUDGET_USEC / 1000, worst_usec / 1000.0, worst_frame])
	await _no_loading_round()
	_finish()


## A menu -> game start in the real scene. `hold`: keep the actors parse blocked for
## HOLD_FRAMES before letting it finish.
func _app_round(hold: bool) -> Dictionary:
	_reset_actor_art()
	# The baseline is the unheld case: the pack is already parsed, so neither the loading
	# screen nor the round waits. The held run blocks the same parse for HOLD_FRAMES.
	if not hold: SwfScreen.actor_art(true)
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.save_path = "user://round-start-hitch-check-save.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(app.save_path))
	root.add_child(app)
	await process_frame
	await app.screen_opened()
	# The main menu, as PLAY opens it, then the player's START: `_start_level` builds the
	# gameplay screen, the map-loading screen, and the round starts under it.
	app.show_main_menu()
	await app.screen_opened()
	for idle in 10: await process_frame
	if hold:
		var gate := Semaphore.new()
		_parse_gate = gate
		SwfScreen.actors_parse_gate = func(): gate.wait()
	var before := Time.get_ticks_usec()
	app.start_session()
	# Drive the loading screen and the host with a fixed 1/35 s step, so the two runs' tick
	# at the loading close is comparable (real time would make it depend on the background
	# resample load's frame rate). The screens stay out of the engine's `_process`.
	app.game.set_process(false)
	var loading = _loading_node(app)
	if loading != null: loading.set_process(false)
	if hold:
		for held in HOLD_FRAMES: before = await _locked_step(before, app, loading)
		var actors = _actors(app)
		_expect(_loading_up(app), "the map-loading screen stays up while the actors pack parses")
		_expect(actors != null and actors._robots.is_empty(),
			"the round does not create its robots before the actors pack is ready")
		_release_parse()
	var reached := false
	var closed_tick := -1
	var first_tick := -1
	var count := 0
	while count < MAX_FRAMES:
		before = await _locked_step(before, app, loading)
		count += 1
		if app.game == null: break
		var tick: int = app.game.get_snapshot().tick
		if closed_tick < 0 and not _loading_up(app): closed_tick = tick
		# The first tick the player sees: the map-loading screen has gone (`gameStartHandler`
		# destroys it), so the round is on screen with its robots (made at loading frame 56).
		if tick >= 1 and not _loading_up(app):
			first_tick = tick
			reached = true
			break
	_expect(app.current == &"playing", "the game is playing the level")
	_expect(closed_tick >= 0, "the loading screen closes before the round is displayed")
	if reached:
		_check_robots(app)
	_release_parse()
	app.queue_free()
	await process_frame
	return {"reached": reached, "closed_tick": closed_tick, "first_tick": first_tick}


## A round whose gameplay screen has no map-loading screen over it: the round's first tick
## is held until the actor display can build the robots.
func _no_loading_round() -> void:
	_reset_actor_art()
	var gate := Semaphore.new()
	_parse_gate = gate
	SwfScreen.actors_parse_gate = func(): gate.wait()
	var game = Game.new()
	game.auto_start = false
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.start_session(true, 42)
	var screen = SwfScreen.create(&"game", 0)
	root.add_child(screen)
	screen.fit(root.size)
	await process_frame
	var board := GameBoard.new(screen, screen.layout.board, &"cinema", &"")
	board.build(game.get_snapshot(), false, true)
	var actors := GameActors.new(screen, board)
	game.attach_swf(screen, Transform2D.IDENTITY, func(snapshot: Dictionary):
		board.update(snapshot)
		actors.update(snapshot))
	game.start_delay = 61
	# The parse is held: no frame may tick the round without its robots.
	var step_worst := 0
	for held in HOLD_FRAMES:
		var at := Time.get_ticks_usec()
		game._host_step(1.0 / 35.0)
		await process_frame
		step_worst = maxi(step_worst, Time.get_ticks_usec() - at)
	_expect(game.get_snapshot().tick == 0, "no tick runs while the actors pack is still parsing")
	_expect(actors._robots.is_empty(), "no robots are built while the actors pack is still parsing")
	_release_parse()
	var ticked_without_robots := false
	var ticks := 0
	while game.get_snapshot().tick < 1 and ticks < 400:
		var at := Time.get_ticks_usec()
		game._host_step(1.0 / 35.0)
		await process_frame
		step_worst = maxi(step_worst, Time.get_ticks_usec() - at)
		ticks += 1
		if game.get_snapshot().tick > 0 and actors._robots.is_empty(): ticked_without_robots = true
	_expect(not actors._robots.is_empty(), "the robots are built before the first tick")
	_expect(not ticked_without_robots, "no tick is drawn without robots")
	_expect(step_worst <= BUDGET_USEC, "no no-loading-screen host step exceeds %d ms (worst %.1f ms)"
		% [BUDGET_USEC / 1000, step_worst / 1000.0])
	_release_parse()
	screen.queue_free()
	game.queue_free()
	await process_frame


## The robots' first displayed tick: every one is visible with the image of the clip the
## round is on (a robot may already have turned while the loading screen covered the round),
## never hidden or left on a stale clip while a replacement resamples.
func _check_robots(app: Control) -> void:
	var swf: Node2D = app.screen.get_child(0)
	_expect(swf != null and swf.screen_name == &"game", "the round shows on the generated gameplay screen")
	var actors = swf.get_meta("actors") if swf != null and swf.has_meta("actors") else null
	_expect(actors != null, "the gameplay screen keeps its actor display")
	var snapshot: Dictionary = app.game.get_snapshot()
	_expect(not snapshot.actors.is_empty(), "the round has its robots")
	if actors == null: return
	for id in snapshot.actors:
		var view: Dictionary = actors._robots.get(id, {})
		_expect(not view.is_empty() and not view.item.is_empty(), "robot %s is on the board" % id)
		if view.is_empty() or view.item.is_empty(): continue
		var path := String(view.item.path) + "/@0"
		var rec: Dictionary = swf._by_path_rec.get(path, {})
		_expect(rec.get("sprite") != null and rec.sprite.visible and rec.sprite.texture != null,
			"robot %s is visible with art on the round's first tick" % id)
		_expect(not String(view.class).is_empty() and int(view.frame) >= 1,
			"robot %s shows a live clip on the first displayed tick" % id)
		var want: Dictionary = actors._robot_art(view)
		_expect(not want.is_empty(), "the pack has robot %s's first-tick art" % id)
		var shown := int(rec.get("shown_art", -1))
		if not want.is_empty() and rec.has("sprite") and rec.sprite.texture != null and shown >= 0 and shown < rec.art.size():
			_expect(String(rec.art[shown].get("file", "")).get_file() == String(want.get("file", "")).get_file(),
				"robot %s draws its own clip's image on the first tick" % id)


## One fixed-delta loading frame and host step, then one measured engine frame.
func _locked_step(before: int, app: Control, loading) -> int:
	if is_instance_valid(loading): loading._process(1.0 / 35.0)
	if is_instance_valid(app.game): app.game._host_step(1.0 / 35.0)
	return await _step(before)


## One measured engine frame, with the transition's worst frame tracked for the report.
func _step(before: int) -> int:
	await process_frame
	var now := Time.get_ticks_usec()
	var gap := now - before
	frames += 1
	if gap > worst_usec:
		worst_usec = gap
		worst_frame = frames
	return now


## The actor display of the gameplay screen (`App._game_swf`).
func _actors(app: Control):
	var swf = app.get("_game_swf")
	if not is_instance_valid(swf) or not swf.has_meta("actors"): return null
	return swf.get_meta("actors")


## The map-loading screen over the round (`App._loading_map`).
func _loading_node(app: Control) -> Node:
	for child in app.screen.get_children():
		if is_instance_valid(child) and not child.is_queued_for_deletion() and child.get("screen_name") == &"loading_map":
			return child
	return null


## Whether the map-loading screen over the round is still up.
func _loading_up(app: Control) -> bool:
	return _loading_node(app) != null


## Parse fresh in each scenario, as on a cold machine.
func _reset_actor_art() -> void:
	SwfScreen._actors_lock.lock()
	SwfScreen._actors_art = {}
	SwfScreen._actors_failed = false
	SwfScreen._actors_task = -1
	SwfScreen._actors_lock.unlock()


## Release and clear the parse hook on every exit path, so a failing check never leaves the
## parse task blocked (and `finish_warming` never waits on it forever).
func _release_parse() -> void:
	SwfScreen.actors_parse_gate = Callable()
	if _parse_gate != null:
		_parse_gate.post()
		_parse_gate = null


func _finish() -> void:
	_release_parse()
	# The standalone no-loading scenario has no App to wait for its background tasks.
	SwfScreen.finish_warming()
	if failures == 0:
		print("PASS: %d round start hitch checks (worst frame %.1f ms)" % [checks, worst_usec / 1000.0])
	else:
		print("FAIL: %d round start hitch checks (worst frame %.1f ms at frame %d)" % [checks, worst_usec / 1000.0, worst_frame])
	quit(0 if failures == 0 else 1)


func _expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr(label)

extends SceneTree
## The replica's mobile-first page (#89-#92; DESIGN.md › Gameplay layout): page fit and safe
## area at phone and tablet sizes, the 48 px full board, and nothing but the map on it.

const ReplicaLayout = preload("res://scripts/replica_layout.gd")
const Fidelity = preload("res://scripts/fidelity.gd")
const TouchControls = preload("res://scripts/touch_controls.gd")
const ScreenLayout = preload("res://scripts/art/screen_layout.gd")
## Logical viewports under `canvas_items` + `expand` at 720 px height, with safe areas.
## 2532×1170 (iPhone 13/14) has a 47 pt sensor housing on one side and a 21 pt home indicator.
const PHONE := Vector2(2532.0 * 720 / 1170, 720)
const NOTCH := 47.0 * 3 * 720 / 1170
const INDICATOR := 21.0 * 3 * 720 / 1170
var failures := 0
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_page_fit()
	await _scene()
	await _hud()
	await _scenery()
	await _pause()
	_screen_tables()
	print("%s: %d replica page checks" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)


func _page_fit() -> void:
	for side in [-1, 1]:
		var safe := Rect2(NOTCH if side < 0 else 0, 0, PHONE.x - NOTCH, PHONE.y - INDICATOR)
		var placed := ReplicaLayout.fit(PHONE, safe)
		var page := Rect2(placed.offset, ReplicaLayout.PAGE * placed.scale)
		_expect(placed.scale == 1.0, "2532×1170 notch %s: the page keeps 1:1" % ("left" if side < 0 else "right"))
		_expect(page.position.x >= safe.position.x and page.end.x <= safe.end.x,
			"2532×1170 notch %s: the page stays clear of the sensor housing" % ("left" if side < 0 else "right"))
		_expect(_inside(_important(page), safe), "2532×1170 notch %s: HUD, controls and map stay in the safe area" % ("left" if side < 0 else "right"))
		_expect(absf(page.get_center().y - 360) < 1, "2532×1170: the page is centred vertically")
	var full := ReplicaLayout.fit(Vector2(1280, 720), Rect2(0, 0, 1280, 720))
	_expect(full.scale == 1.0 and full.offset == Vector2.ZERO, "1920×1080 (16:9): the page fills the screen")
	var tablet := ReplicaLayout.fit(Vector2(1280, 960), Rect2(0, 0, 1280, 960))
	_expect(tablet.scale == 1.0 and tablet.offset == Vector2(0, 120), "2048×1536 (4:3): the page centres with scenery above and below")
	var cramped := ReplicaLayout.fit(Vector2(1280, 720), Rect2(100, 0, 1080, 720))
	_expect(cramped.scale < 1.0 and cramped.offset.x >= 100 and cramped.offset.x + 1280 * cramped.scale <= 1180.5,
		"a safe area narrower than the page scales it down inside the safe area")
	_expect(ReplicaLayout.BOARD.size == Vector2(ReplicaLayout.BOARD_CELLS) * ReplicaLayout.CELL and ReplicaLayout.BOARD.size.y == 720,
		"the whole 17×15 board fills the page height at 48 px cells")
	_expect(ReplicaLayout.MAP.position.x == ReplicaLayout.BOARD.position.x + ReplicaLayout.CELL / 2
		and ReplicaLayout.MAP.end.x == ReplicaLayout.BOARD.end.x - ReplicaLayout.CELL / 2,
		"the outer ring columns are cropped to half a cell")


func _scene() -> void:
	Fidelity.original = true
	var game = load("res://scripts/game.gd").new()
	game.safe_area_override = Rect2(NOTCH, 0, PHONE.x - NOTCH, PHONE.y - INDICATOR)
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.start_session(false, 42)
	game.fit_page(PHONE)
	_expect(game.position.x >= NOTCH and game.scale == Vector2.ONE, "the scene places the page inside the phone's safe area")
	var view: Node2D = game.view
	var cell_origin: Vector2 = view.position + view.scale * (ReplicaLayout.VIEW_ORIGIN + Vector2(3, 4) * ReplicaLayout.VIEW_PITCH)
	_expect(cell_origin.is_equal_approx(ReplicaLayout.cell_rect(Vector2i(3, 4)).position) and is_equal_approx(view.scale.x * ReplicaLayout.VIEW_PITCH, 48.0),
		"board cells draw at 48 px on the page")
	_expect(view.compact, "the view draws only the board: no titles, captions or hints")
	var visible_buttons: Array = game.buttons.keys().filter(func(key): return game.buttons[key].visible)
	_expect(visible_buttons.is_empty(), "no development buttons appear during play (visible: %s)" % [visible_buttons])
	var covered := true
	for area in game.scenery.areas():
		covered = covered and not area.intersects(ReplicaLayout.MAP)
	_expect(covered and game.scenery.get_index() > view.get_index(), "the scenery covers everything but the map, above the board")
	_expect(game.scenery.stage_set == game.get_snapshot().board_meta.skin, "the scenery follows the round's stage set")
	# #79: the replica scheduler is frame-driven and the view blends positions between steps.
	_expect(game.scheduler.frame_driven, "the replica round steps from drawn frames")
	game.scheduler.set_direction(&"human", Vector2.RIGHT)
	for frame in 12: game.advance_time(1.0 / 60.0)
	var before: Dictionary = game.get_snapshot()
	var was: Vector2 = game.previous_state.actors[&"human"].position
	var now: Vector2 = before.actors[&"human"].position
	game.view.between = 0.5
	_expect(now != was and game.view._blend(was, now).is_equal_approx(was.lerp(now, 0.5)), "actors draw halfway between steps at a half-step fraction")
	game.view.queue_redraw()
	await process_frame
	_expect(game.get_snapshot() == before, "interpolation never changes the round state")
	game.toggle_pause()
	for step in game.PAUSE_DELAY_STEPS: game.advance_time(1.0 / 35)
	_expect(game.buttons.pause.visible and ReplicaLayout.MAP.encloses(Rect2(game.buttons.pause.position, game.buttons.pause.size)),
		"pause shows RESUME over the map centre")
	game.toggle_pause()
	_expect(not game.buttons.pause.visible, "resuming hides the pause controls")
	await _controls(game)
	game.queue_free()
	await process_frame


## #90: the stick and bomb button sit on the side areas, inside the safe area, sized for
## thumbs; touch works in screen coordinates; keyboard and AI stay single-cardinal.
func _controls(game) -> void:
	var stick := Rect2(TouchControls.STICK - Vector2.ONE * TouchControls.STICK_REACH, Vector2.ONE * TouchControls.STICK_REACH * 2)
	var bomb := Rect2(TouchControls.BOMB - Vector2.ONE * TouchControls.BOMB_REACH, Vector2.ONE * TouchControls.BOMB_REACH * 2)
	_expect(ReplicaLayout.LEFT.encloses(stick) and ReplicaLayout.RIGHT.encloses(bomb) and not stick.intersects(ReplicaLayout.MAP)
		and not bomb.intersects(ReplicaLayout.MAP), "stick bottom-left and bomb bottom-right never overlap playable cells")
	_expect(_important(Rect2(0, 0, 1280, 720)).encloses(stick) and _important(Rect2(0, 0, 1280, 720)).encloses(bomb),
		"both controls stay inside the safe band of every checked screen")
	# 44 pt minimum touch target on the 2532×1170 phone (1 logical px = 1170 / 720 / 3 pt).
	var points_per_px := 1170.0 / 720 / 3
	_expect(TouchControls.BOMB_REACH * 2 * points_per_px >= 44 and TouchControls.STICK_REACH * 2 * points_per_px >= 88,
		"the stick and button are sized for thumbs")
	for placement in [{"scale": 1.0, "offset": Vector2(NOTCH + 50, 0)}, {"scale": 0.8, "offset": Vector2(40, 30)}]:
		game.position = placement.offset
		game.scale = Vector2.ONE * placement.scale
		var page_to_screen := func(at: Vector2) -> Vector2: return placement.offset + at * placement.scale
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.position = page_to_screen.call(TouchControls.STICK)
		touch.pressed = true
		root.push_input(touch, true)
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = page_to_screen.call(TouchControls.STICK + Vector2(-50, 50))
		root.push_input(drag, true)
		game.advance_time(1.0 / 35.0)
		_expect(game.get_snapshot().commands[0].direction.is_equal_approx(Vector2(-1, 1).normalized()),
			"touch in screen coordinates drives the eight-way stick at page scale %.1f" % placement.scale)
		touch.pressed = false
		root.push_input(touch, true)
		var press := InputEventScreenTouch.new()
		press.index = 1
		press.position = page_to_screen.call(TouchControls.BOMB)
		press.pressed = true
		root.push_input(press, true)
		game.advance_time(1.0 / 35.0)
		_expect(game.get_snapshot().commands[0].bomb_events == [&"down"], "the bomb button presses in screen coordinates at page scale %.1f" % placement.scale)
		press.pressed = false
		root.push_input(press, true)
		game.advance_time(1.0 / 35.0)
	var keys := [KEY_RIGHT, KEY_DOWN]
	for key in keys:
		var event := InputEventKey.new()
		event.keycode = key
		event.pressed = true
		root.push_input(event, true)
	game.advance_time(1.0 / 35.0)
	_expect(game.get_snapshot().commands[0].direction == Vector2.DOWN, "keyboard keeps one cardinal direction: the last key held")
	for key in keys:
		var event := InputEventKey.new()
		event.keycode = key
		root.push_input(event, true)
	var cardinal := true
	for tick in 300:
		game.advance_time(1.0 / 35.0)
		for command in game.get_snapshot().commands:
			if command.actor_id != &"human": cardinal = cardinal and (command.direction.x == 0 or command.direction.y == 0)
	_expect(cardinal, "original AI commands stay single-cardinal")


## #91: the compact HUD reads the live round and the session, and never covers playable cells.
func _hud() -> void:
	var Hud = load("res://scripts/replica_hud.gd")
	var playable := Rect2(ReplicaLayout.MAP.position + Vector2(0, ReplicaLayout.CELL), ReplicaLayout.MAP.size - Vector2(0, ReplicaLayout.CELL * 2))
	var zones: Array = [Hud.STATUS, Hud.TIMER, Hud.LEVEL, Rect2(Hud.PAUSE_CENTER - Vector2.ONE * Hud.PAUSE_RADIUS, Vector2.ONE * Hud.PAUSE_RADIUS * 2)]
	for x in Hud.RIVAL_X: zones.append(Rect2(Vector2(x, Hud.RIVAL_Y) - Vector2(26, 26), Vector2(52, 60)))
	_expect(zones.all(func(zone): return not zone.intersects(playable) and Rect2(0, 0, 1280, 720).encloses(zone)),
		"HUD zones cover only the scenery and the board's cropped top row")
	for mode in [&"arcade", &"kill", &"green_zone"]:
		var session = load("res://scripts/session.gd").new(11)
		session.mode = mode
		session.begin()
		var game = load("res://scripts/game.gd").new()
		game.session = session
		game.auto_start = false
		root.add_child(game)
		await process_frame
		game.set_process(false)
		game.play_level()
		for tick in 40: game.advance_time(1.0 / 35.0)
		var hud = game.hud
		var rivals: Array = hud.rivals()
		_expect(rivals.map(func(id): return hud.robot_of(id)) == Array(session.ai_robots).slice(0, rivals.size()),
			"%s: rival badges show the session's drawn AI robots" % mode)
		var expected: String = "0/10" if mode != &"arcade" else str(game.get_snapshot().actors[&"human"].score)
		_expect(hud.score_text(&"human") == expected, "%s: the score slot shows %s" % [mode, expected])
		var remaining: int = game.get_snapshot().remaining
		_expect(hud.time_text() == "%d:%02d" % [ceili(remaining / 35.0) / 60, ceili(remaining / 35.0) % 60]
			and hud.state.session.level == session.level_text(), "%s: the timer reads the round clock and the level badge the session" % mode)
		if mode == &"kill":
			_expect(game.touch_controls.replica and game.touch_controls.item == &"hammer",
				"kill: the bomb button shows the equipped hammer in the mockup style (#78)")
		elif mode == &"arcade":
			_expect(game.touch_controls.item == &"", "arcade: the bomb button shows the bomb")
		hud.pause_button.pressed.emit()
		for step in game.PAUSE_DELAY_STEPS: game.advance_time(1.0 / 35)
		_expect(game.paused and hud.paused, "%s: the pause icon opens the pause screen" % mode)
		hud.pause_button.pressed.emit()
		_expect(not game.paused, "%s: the pause icon resumes" % mode)
		game.queue_free()
		await process_frame


## #92: each stage set's original background fills the scenery and changes between levels;
## without the pack the plain extension remains.
func _scenery() -> void:
	var Catalog = load("res://scripts/art/catalog.gd")
	var StageSets = load("res://scripts/simulation/stage_sets.gd")
	var ids: Array = Catalog.entries().map(func(entry): return entry.id)
	_expect(StageSets.ORDER.all(func(set_id): return "scenery." + set_id in ids), "every stage set has a side-scenery slot")
	var session = load("res://scripts/session.gd").new(5)
	session.levels = 2
	session.begin()
	var game = load("res://scripts/game.gd").new()
	game.session = session
	game.auto_start = false
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.play_level()
	var first: StringName = game.scenery.stage_set
	session.last_result = session.Result.LEVEL_WIN
	session.current_set = &"zoo" if first != &"zoo" else &"cinema"
	game.play_level()
	_expect(game.scenery.stage_set == session.current_set, "the scenery changes with the stage set between levels")
	var bare = load("res://scripts/replica_scenery.gd").new()
	_expect(bare.background() == null, "without the original pack the plain extension remains")
	bare.free()
	game.queue_free()
	await process_frame


## #81 (docs/evidence/edition-5-pause-and-focus.md): the pause request runs four more steps,
## a second press inside them cancels it, held movement waits for a new press with its speed
## kept, and paused wall time reaches the TweenMax timers.
func _pause() -> void:
	var game = load("res://scripts/game.gd").new()
	var clock := {"ms": 1000}
	game.msec_source = func() -> int: return clock.ms
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.start_session(false, 42)
	var right := InputEventKey.new()
	right.keycode = KEY_RIGHT
	right.pressed = true
	root.push_input(right, true)
	for step in 3: game.advance_time(1.0 / 35.0)
	var asked: int = game.get_snapshot().tick
	game.toggle_pause()
	for step in game.PAUSE_DELAY_STEPS - 1: game.advance_time(1.0 / 35.0)
	_expect(not game.paused, "the original pause has not taken effect three steps after the request")
	game.advance_time(1.0 / 35.0)
	_expect(game.paused and game.get_snapshot().tick == asked + 4, "the pause takes effect four steps (100 ms) after the request")
	var held_speed: Vector2 = game.get_snapshot().actors[&"human"].velocity
	var held_at: Vector2 = game.get_snapshot().actors[&"human"].position
	clock.ms += 5000
	game.toggle_pause()
	for step in 6: game.advance_time(1.0 / 35.0)
	var after: Dictionary = game.get_snapshot().actors[&"human"]
	_expect(after.position == held_at and after.velocity == held_speed and held_speed.x > 0,
		"a key held through the pause moves nothing after resume, and the speed is kept")
	right.pressed = false
	root.push_input(right, true)
	right.pressed = true
	root.push_input(right, true)
	game.advance_time(1.0 / 35.0)
	_expect(game.get_snapshot().actors[&"human"].position.x > held_at.x, "a new press moves again")
	game.toggle_pause()
	game.advance_time(1.0 / 35.0)
	game.toggle_pause()
	for step in 6: game.advance_time(1.0 / 35.0)
	_expect(not game.paused, "a second press within the 100 ms window cancels the pause")
	game.simulation._weapons.attacks.append({"actor_id": &"human", "kind": &"triple", "recover_at": game.get_snapshot().tick + 11})
	game.simulation.pass_host_time(35)
	_expect(game.simulation._weapons.attacks.back().recover_at == game.get_snapshot().tick,
		"paused wall time counts down the TweenMax recovery timers")
	game.simulation._weapons.attacks.pop_back()
	game.msec_source = Callable()
	game.queue_free()
	await process_frame


## Everything a player must see or touch: HUD strip, map and both control areas, without the
## one ring row each at the top and bottom edge.
## #76: every art page is the 700x510 stage at 720/510, and its table is self-consistent.
func _screen_tables() -> void:
	var stage := ScreenLayout.STAGE_FRAME
	_expect(is_equal_approx(stage.size.y / 510.0, 720.0 / 510.0) and absf(stage.size.x - 700.0 * 720.0 / 510.0) < 0.1
		and absf(stage.get_center().x - 640.0) < 0.1, "the screen frame is the original stage at 720/510, centred")
	var problems: Array[String] = []
	for page in ScreenLayout.pages():
		var table := ScreenLayout.table(page)
		if table.frame.size.x == 0: continue
		for name in table.baked + table.live:
			if not table.slots.has(name) and name != &"guide": problems.append("%s.%s has no slot" % [page, name])
		for name in table.slots:
			if not _inside(table.slots[name], stage.grow(2)): problems.append("%s.%s leaves the stage" % [page, name])
		for name in table.plates:
			if not table.live.has(name): problems.append("%s.%s plate hides art no live widget replaces" % [page, name])
			if not table.colors.has(name): problems.append("%s.%s plate has no sampled colour" % [page, name])
	_expect(problems.is_empty(), "screen tables are consistent: %s" % [problems])


func _important(page: Rect2) -> Rect2:
	return Rect2(page.position + Vector2(0, ReplicaLayout.CELL), Vector2(page.size.x, page.size.y - ReplicaLayout.CELL * 2))


func _inside(inner: Rect2, outer: Rect2) -> bool:
	return outer.grow(0.5).encloses(inner)


func _expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr(label)

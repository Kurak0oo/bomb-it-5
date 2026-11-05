extends SceneTree
## Smoke playthrough of a normal launch (no review flags): the main scene from the title,
## through the menus by clicks, Arcade on Cinema, rounds played with keyboard events (arrows
## and Space, as the original's `PersonInteractiveController`; P pauses) on the generated
## gameplay screen, the pause screen, score screens, NEXT / RESTART, and the session's end.
##
##     Godot --headless --path . --fixed-fps 35 --script res://tools/smoke_playthrough.gd
##
## The keys come from the desktop input driver (tools/desktop_player.gd), turned into key
## presses and releases on the window, so the round sees only what a player's keyboard sends.
## Prints `PASS: smoke playthrough …` with what it reached.

const DesktopPlayer = preload("res://tools/desktop_player.gd")
const Session = preload("res://scripts/session.gd")
const MAX_FRAMES := 60000
var app: Control
var driver := DesktopPlayer.new(5)
var held_key := KEY_NONE
var log := []
var failures := 0


func _initialize() -> void:
	# Headless there is no window to fit the screens to or to wait for art on: the screens step
	# one SWF frame per Godot frame, which --fixed-fps 35 makes the original's rate anyway.
	load("res://scripts/ui/swf_screen.gd").frame_locked = true
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	app = load("res://scenes/main.tscn").instantiate()
	app.save_path = "user://smoke-save.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(app.save_path))
	root.add_child(app)
	await _until(func(): return app.current == &"title", "the title opens")
	await _click("btn_play")
	await _until(func(): return app.current == &"menu", "PLAY opens the main menu")
	await _click("startGame")
	await _until(func(): return app.current == &"settings", "START opens Game Settings")
	await _click("levelsTen")
	await _click("mapMenu")
	await _click("cinemaStages")
	await _click("confirm")
	await _until(func(): return app.current == &"character", "CONFIRM opens character select")
	await _click("startBtn")
	await _until(func(): return app.current == &"playing", "START begins level 1")
	_note("session: Arcade, %s, %d levels, stage %s" % [app.session.difficulty, app.session.levels, app.session.stage])

	# Session A: play two levels with the keyboard (a pause on the way), whatever the result.
	var paused_once := false
	var levels_done := 0
	var frames := 0
	while levels_done < 2 and frames < MAX_FRAMES and failures == 0:
		if app.current == &"playing" and is_instance_valid(app.game):
			if not paused_once and app.game.get_snapshot().tick > 120:
				paused_once = true
				await _pause_and_resume()
				continue
			_drive(app.game.get_snapshot())
		elif app.current == &"score":
			_release()
			levels_done += 1
			var won: bool = app.session.last_result in [Session.Result.LEVEL_WIN, Session.Result.GAME_WIN]
			_note("level %d %s; total %d, hearts %d" % [app.session.level, "won" if won else "lost", app.session.total_score, app.session.lives])
			await _wait(80)
			# The unlock tip, if the total crossed a look's score, closes with OK first.
			var ok := app.find_child("okBt", true, false)
			if ok != null and ok.is_visible_in_tree():
				await _wait(120)
				await _click("okBt")
			await _click("nextLevel" if won else "restartBtn")
			await _until(func(): return app.current in [&"playing", &"game_over", &"game_win"], "NEXT/RESTART goes on")
			if app.current != &"playing": break
			_note("level %d (%s) starts on stage %s" % [app.session.level, "next" if won else "retry", app.session.current_set])
		elif app.current in [&"game_over", &"game_win"]:
			break
		await process_frame
		frames += 1
	_expect(levels_done >= 1, "at least one level was played to its end with the keyboard")

	# Session B: back to the menu from the pause screen, a new session lost on purpose.
	if app.current == &"playing":
		_key(KEY_P, true)
		_key(KEY_P, false)
		await _until(func(): return app.find_child("mainMenu", true, false) != null, "P opens the pause screen")
		await _wait(5)
		await _click("mainMenu")
		await _until(func(): return app.current == &"menu", "MAIN MENU leaves the level")
		await _click("startGame")
		await _until(func(): return app.current == &"settings", "START opens Game Settings again")
		await _click("confirm")
		await _until(func(): return app.current == &"character", "character select again")
		await _click("startBtn")
		await _until(func(): return app.current == &"playing", "a new session starts")
	frames = 0
	while app.current not in [&"game_over", &"game_win"] and frames < MAX_FRAMES and failures == 0:
		if app.current == &"playing" and is_instance_valid(app.game):
			var human: Dictionary = app.game.get_snapshot().actors[&"human"]
			# Stand still and drop a bomb: the robot's own blast ends the level.
			if human.alive and app.game.get_snapshot().bombs.is_empty() and app.game.get_snapshot().tick > 40:
				_key(KEY_SPACE, true)
				_key(KEY_SPACE, false)
		elif app.current == &"score":
			await _wait(80)
			var ok := app.find_child("okBt", true, false)
			if ok != null and ok.is_visible_in_tree():
				await _wait(120)
				await _click("okBt")
			await _click("restartBtn")
			await _until(func(): return app.current in [&"playing", &"game_over"], "RESTART after a lost level")
			_note("lost on purpose; hearts %d" % app.session.lives)
		await process_frame
		frames += 1
	_expect(app.current in [&"game_over", &"game_win"], "the session ends on its end screen")
	_note("end screen: %s, total %d" % [app.current, app.session.total_score])
	if app.current in [&"game_over", &"game_win"]:
		await _wait(60)
		await _click("back")
		await _until(func(): return app.current == &"settings", "TRY AGAIN returns to Game Settings")
	# Session C: a stage set without board art in the pack (Zoo) on the same generated
	# screen, its board from the placeholder layer; a few hundred frames of keyboard play.
	await _click("mapMenu")
	await _click("weddingStages")
	await _click("confirm")
	await _until(func(): return app.current == &"character", "character select for Zoo")
	await _click("startBtn")
	await _until(func(): return app.current == &"playing", "a Zoo level starts")
	_expect(app.screen.get_child(0).screen_name == &"game" and app.game.swf_view.draw_board,
		"Zoo plays on the generated gameplay screen with its board on the placeholder layer")
	for frame in 400:
		if app.current != &"playing": break
		_drive(app.game.get_snapshot())
		await process_frame
	_release()
	_note("Zoo level played to tick %d on the generated screen" % app.game.get_snapshot().tick if is_instance_valid(app.game) else "Zoo level ended")
	print(("PASS" if failures == 0 else "FAIL") + ": smoke playthrough " + JSON.stringify(log))
	quit(0 if failures == 0 else 1)


## `gamePause` after P (100 ms later), the original pause screen, Space resumes (PauseUI).
func _pause_and_resume() -> void:
	_release()
	_key(KEY_P, true)
	_key(KEY_P, false)
	await _until(func(): return app.game.paused and app.find_child("resume", true, false) != null, "P pauses the round on PauseUI")
	var tick: int = app.game.get_snapshot().tick
	await _wait(30)
	_expect(app.game.get_snapshot().tick == tick, "the paused round does not advance")
	_key(KEY_SPACE, true)
	_key(KEY_SPACE, false)
	await _until(func(): return not app.game.paused, "Space on the pause screen resumes")
	_note("paused at tick %d and resumed" % tick)


## The driver's command as keys: one arrow held at a time, Space pressed and released.
func _drive(state: Dictionary) -> void:
	if state.outcome != &"running" or not state.actors[&"human"].alive:
		_release()
		return
	var command: Dictionary = driver.command(state, &"human")
	var d: Vector2 = command.direction
	var want := KEY_NONE
	if d != Vector2.ZERO:
		if absf(d.x) >= absf(d.y): want = KEY_RIGHT if d.x > 0 else KEY_LEFT
		else: want = KEY_DOWN if d.y > 0 else KEY_UP
	if want != held_key:
		_release()
		if want != KEY_NONE:
			_key(want, true)
			held_key = want
	if &"down" in command.bomb_events:
		_key(KEY_SPACE, true)
		_key(KEY_SPACE, false)


func _release() -> void:
	if held_key != KEY_NONE: _key(held_key, false)
	held_key = KEY_NONE


func _key(keycode: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	root.push_input(event)


func _click(node_name: String) -> void:
	# A generated screen takes input once it has opened (as many frames late as the original).
	await app.screen_opened()
	var control: Control = null
	for wait in 900:
		control = app.find_child(node_name, true, false) as Control
		if control != null and control.is_visible_in_tree(): break
		await process_frame
	if control == null:
		_expect(false, "%s exists to click" % node_name)
		return
	var at := control.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		root.push_input(event)
	await process_frame
	await process_frame


func _until(condition: Callable, label: String, frames := 2400) -> void:
	for wait in frames:
		if condition.call(): return
		await process_frame
	_expect(false, label)


func _wait(frames: int) -> void:
	for wait in frames: await process_frame


func _note(text: String) -> void:
	log.append(text)
	print("  ", text)


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + label)

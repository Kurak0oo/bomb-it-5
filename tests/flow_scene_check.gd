extends SceneTree
## Main-scene flow through real clicks and keys: menu, settings, character select,
## levels, score screens, game over, pause to main menu (#59).

const Session = preload("res://scripts/session.gd")
var failures := 0
var checks := 0
var app: Control


func _initialize() -> void:
	# Generated screens follow frames, not the clock, so waiting for them is quick.
	load("res://scripts/ui/swf_screen.gd").frame_locked = true
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	app = load("res://scenes/main.tscn").instantiate()
	app.save_path = "user://flow-check-save.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(app.save_path))
	root.add_child(app)
	await process_frame
	await app.screen_opened()
	_expect(app.current == &"title", "the game opens on the title screen (UILoading)")
	await _click(_find("btn_play"))
	await app.screen_opened()
	_expect(app.current == &"menu", "PLAY opens the main menu")
	_expect(_find("startGame") != null and _find("howToPlay") != null, "the menu offers START and HOW TO PLAY")
	_expect(_find("moregames") == null, "MORE GAMES (the portal link) is removed (owner edit)")

	await _click(_find("startGame"))
	await app.screen_opened()
	_expect(app.current == &"settings", "START opens Game Settings")
	_expect(_find("arcadeMode") != null and _find("collectMode") != null, "the four mode cards are offered")
	await _click(_find("levelsFive"))
	_expect(app.session.levels == 1, "original: the levels button named five sets one level (levelsHandle)")
	await _click(_find("levelsTen"))
	_expect(app.session.levels == 10, "a levels button sets its count")
	await _click(_find("normal"))
	_expect(app.session.difficulty == &"normal", "a difficulty can be chosen")
	await _click(_find("enemiesOne"))
	_expect(app.session.enemies == 1, "one to three enemies can be chosen")
	_expect(_find("enemiesZero").mouse_filter == Control.MOUSE_FILTER_IGNORE, "zero enemies is disabled for one player")
	var swf = app.screen.get_child(0)
	_expect(not swf.is_shown("showMenu"), "the stage list starts closed")
	await _click(_find("mapMenu"))
	_expect(swf.is_shown("showMenu"), "the arena button opens the stage list")
	await _click(_find("cinemaStages"))
	_expect(app.session.stage == &"cinema" and swf.get_frame("choose") == 2, "picking Cinema sets it (choose frame 2, stagesHandle)")
	_expect(not swf.is_shown("showMenu"), "picking a stage closes the list")
	var chosen_set: StringName = app.session.stage
	await _click(_find("confirm"))
	await app.screen_opened()
	_expect(app.current == &"character", "CONFIRM opens character select")
	await app.screen_opened()
	_expect(_find("robotIcon7") != null, "all eight robots are offered")
	await _click(_find("robotIcon5"))
	await _click(_find("startBtn"))
	_expect(app.session.robot == 5, "clicking a robot selects it (startFunc: P1Robot)")
	_expect(app.current == &"playing" and is_instance_valid(app.game), "START begins the first level")
	var game: Node2D = app.game
	game.set_process(false)
	var snapshot: Dictionary = game.get_snapshot()
	_expect(snapshot.actors.size() == 2, "the roster follows the enemy count")
	_expect(snapshot.actors[&"human"].robot == 5, "the player plays the chosen robot")
	_expect(snapshot.board_meta.skin == chosen_set, "the level uses the chosen arena")
	_expect(not game.buttons.match.visible and not game.buttons.practice.visible, "development buttons are hidden in a session")

	for attempt in 3:
		await _lose_level(game)
		if attempt < 2:
			_expect(app.current == &"score", "a lost level shows its score screen")
			_expect(_find_text("LEVEL 1 / 10 FAILED…") != null, "the score screen names the failed level")
			_expect(app.session.lives == 2 - attempt, "each lost level spends one heart")
			var key := InputEventKey.new()
			key.keycode = KEY_SPACE
			key.pressed = true
			root.push_input(key)
			await process_frame
			_expect(app.current == &"playing" and game.get_snapshot().board_meta.skin == chosen_set,
				"Space retries the level in the same arena")
	_expect(app.current == &"game_over" and _find_text("GAME OVER") != null, "the last heart ends in GAME OVER")
	await _click(_find("TryAgain"))
	_expect(app.current == &"settings", "TRY AGAIN after game over returns to Game Settings")

	app.session.levels = 5
	await _click(_find("confirm"))
	await app.screen_opened()
	await _click(_find("startBtn"))
	game = app.game
	game.set_process(false)
	app.session.level = 5
	app._on_level_settled({"outcome": &"won", "result_score": 2500, "actors": {&"human": {"lives": 3}},
		"result_breakdown": {"kills": 300, "time": 200, "difficulty": 2000}})
	await process_frame
	_expect(app.current == &"score" and _find_text("LEVEL 5 / 5 COMPLETE!") != null, "winning the last level shows its score")
	var score = app.screen.get_child(0)
	_expect(score.get_frame("bonus_txt") == 2 and score.get_text("difficulity") == "2000",
		"the score screen shows the difficulty bonus (bonus_txt frame 2: NORMAL BONUS)")
	_expect(score.is_shown("nextLevel") and not score.is_shown("restartBtn"), "a won level offers NEXT, not RESTART")
	# 2,500 points also unlock the first look; its tip covers the score screen until OK.
	_expect(score.is_shown("UI_UNLOCK_TIP"), "crossing an unlock score opens the unlock tip")
	await _click(_find("okBt"))
	_expect(not score.is_shown("UI_UNLOCK_TIP"), "OK closes the unlock tip")
	await _click(_find("nextLevel"))
	_expect(app.current == &"game_win" and _find_text("GAME COMPLETE!") != null, "NEXT after the last level completes the game")

	await _click(_find("TryAgain"))
	await app.screen_opened()
	await _click(_find("confirm"))
	await app.screen_opened()
	await _click(_find("startBtn"))
	game = app.game
	game.set_process(false)
	game.toggle_pause()
	for step in game.PAUSE_DELAY_STEPS: game.advance_time(1.0 / 35)
	_expect(game.buttons.menu.visible, "pause offers MAIN MENU")
	await _click(game.buttons.menu)
	await process_frame
	_expect(app.current == &"menu" and not is_instance_valid(app.game), "MAIN MENU leaves the level")

	await _click(_find("startGame"))
	await app.screen_opened()
	await _click(_find("killMode"))
	_expect(app.session.mode == &"kill", "Battle Royale can be chosen")
	await _click(_find("confirm"))
	await app.screen_opened()
	await _click(_find("startBtn"))
	app.game.set_process(false)
	_expect(app.game.get_snapshot().mode == &"kill" and app.game.get_snapshot().actors[&"human"].weapon == &"hammer",
		"a Battle Royale level starts with the hammer")
	app.game.toggle_pause()
	for step in app.game.PAUSE_DELAY_STEPS: app.game.advance_time(1.0 / 35)
	await _click(app.game.buttons.menu)

	app._open_practice()
	await process_frame
	_expect(app.game.practice and app.game.get_snapshot().board.size() == 255, "the development launch opens the practice board")
	app.queue_free()
	await process_frame
	print("%s: %d flow scene checks" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)


func _lose_level(game: Node2D) -> void:
	var bomb := InputEventKey.new()
	bomb.keycode = KEY_SPACE
	bomb.pressed = true
	root.push_input(bomb, true)
	for tick in 240:
		if app.current != &"playing": break
		game.advance_time(1.0 / 35.0)
	bomb.pressed = false
	root.push_input(bomb, true)
	await process_frame


func _click(control: Control) -> void:
	if control == null:
		_expect(false, "control to click exists")
		return
	# A generated screen shows some instances only after a while (PLAY after loading).
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
		root.push_input(event)
	await process_frame
	await process_frame


func _find(node_name: String) -> Node:
	return app.find_child(node_name, true, false)


func _find_text(text: String) -> Node:
	for node in app.find_children("*", "", true, false):
		if (node is Label or node is Button) and node.text == text and node.is_visible_in_tree(): return node
	return null


func _expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr(label)

extends SceneTree
## Main-scene flow through real clicks and keys: menu, settings, character select,
## levels, score screens, game over, pause to main menu (#59).

const Session = preload("res://scripts/session.gd")
var failures := 0
var checks := 0
var app: Control


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	app = load("res://scenes/main.tscn").instantiate()
	app.save_path = "user://flow-check-save.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(app.save_path))
	root.add_child(app)
	await process_frame
	_expect(app.current == &"menu", "the game opens on the main menu")
	_expect(_find("Start") != null and _find("HowToPlay") != null, "the menu offers START and HOW TO PLAY")
	_expect(_find_text("MORE GAMES") == null, "the publisher's MORE GAMES link is not offered")

	await _click(_find("Start"))
	_expect(app.current == &"settings", "START opens Game Settings")
	_expect(not _find("Mode_arcade").disabled, "Arcade is selectable")
	await _click(_find_text("10"))
	_expect(app.session.levels == 10, "a levels button sets its labelled count")
	await _click(_find_text("1"))
	_expect(app.session.enemies == 1, "one to three enemies can be chosen")
	_expect(_find_text("0") == null, "zero enemies is not offered to one player")
	var arena: OptionButton = _find("Arena")
	_expect(arena.get_item_text(0) == "RANDOM" and arena.item_count == 1 + app.StageSets.available_sets().size(),
		"the arena list offers Random and every available stage set")
	arena.select(arena.item_count - 1)
	arena.item_selected.emit(arena.item_count - 1)
	var chosen_set: StringName = app.session.stage
	_expect(chosen_set != &"random", "an arena can be chosen")
	await _click(_find("Next"))
	_expect(app.current == &"character", "NEXT opens character select")
	_expect(_find("Robot7") != null, "all eight robots are offered")
	await _click(_find("Robot5"))
	_expect(app.session.robot == 5, "clicking a robot selects it")
	await _click(_find("StartGame"))
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
	await _click(_find("Next"))
	await _click(_find("StartGame"))
	game = app.game
	game.set_process(false)
	app.session.level = 5
	app._on_level_settled({"outcome": &"won", "result_score": 2500, "actors": {&"human": {"lives": 3}},
		"result_breakdown": {"kills": 300, "time": 200, "difficulty": 2000}})
	await process_frame
	_expect(app.current == &"score" and _find_text("LEVEL 5 / 5 COMPLETE!") != null, "winning the last level shows its score")
	_expect(_find_text("NORMAL BONUS") != null and _find_text("2000") != null, "the score screen shows the difficulty bonus")
	# 2,500 points also unlock the first look; its tip covers the score screen until OK.
	if _find("TipOk") != null: await _click(_find("TipOk"))
	await _click(_find("Continue"))
	_expect(app.current == &"game_win" and _find_text("GAME COMPLETE!") != null, "NEXT after the last level completes the game")

	await _click(_find("TryAgain"))
	await _click(_find("Next"))
	await _click(_find("StartGame"))
	game = app.game
	game.set_process(false)
	game.toggle_pause()
	_expect(game.buttons.menu.visible, "pause offers MAIN MENU")
	await _click(game.buttons.menu)
	await process_frame
	_expect(app.current == &"menu" and not is_instance_valid(app.game), "MAIN MENU leaves the level")

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

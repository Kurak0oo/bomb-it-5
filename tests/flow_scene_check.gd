extends SceneTree
## Main-scene flow through real clicks and keys: menu, settings, character select,
## levels, score screens, game over, pause to main menu (#59).

const Session = preload("res://scripts/session.gd")
const GameBoard = preload("res://scripts/ui/game_board.gd")
const StageSets = preload("res://scripts/simulation/stage_sets.gd")
const SwfScreen = preload("res://scripts/ui/swf_screen.gd")
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
	_expect(app.screen != null and app.screen.get_child(0).screen_name == &"game", "the level shows on the generated gameplay screen")
	_expect(not is_instance_valid(game.swf_board_view), "Cinema's board is its own art: no placeholder board")

	for attempt in 3:
		if attempt == 0: await _lose_level_with_cartoon(game)
		else: await _lose_level(game)
		if attempt < 2:
			_expect(app.current == &"score", "a lost level shows its score screen")
			if attempt == 0:
				# DRESS UP with nothing newly unlocked: no unlock burst (`Art_unlockAnimas` is
				# only added by UnlockAnimaPanel).
				var score_swf = app.screen.get_child(0)
				score_swf.get_meta("controller").dressUpHandle("")
				_expect(score_swf.is_shown("UI_UNLOCK_TIP") and not score_swf.is_shown("UI_UNLOCK_TIP/containerMc/Art_unlockAnimas"),
					"DRESS UP opens the tip without an unlock burst")
				for tip in score_swf.get_meta("controller")._tips: if tip.__mc != "": tip.onClickOkBt("")
			_expect(_find_text("LEVEL 1 / 10 FAILED…") != null, "the score screen names the failed level")
			_expect(app.session.lives == 2 - attempt, "each lost level spends one heart")
			var key := InputEventKey.new()
			key.keycode = KEY_SPACE
			key.pressed = true
			root.push_input(key)
			await process_frame
			_expect(app.current == &"playing" and game.get_snapshot().board_meta.skin == chosen_set,
				"Space retries the level in the same arena")
	_expect(app.current == &"game_over" and app.screen.get_child(0).screen_name == &"game_over",
		"the last heart ends on the generated Game Over screen (UI_GAMEOVERONEP)")
	await app.screen_opened()
	var over = app.screen.get_child(0)
	_expect(over.get_text("score") == str(app.session.total_score), "Game Over shows the final total (OnePGameOverUI.initData)")
	_expect(_find("moregames") == null, "MORE GAMES (the portal link) is removed from Game Over (owner edit)")
	_expect(not over.has_node("FallSnow"), "Game Over drops no confetti (FallSnow only for GAME_WIN)")
	await _click(_find("back"))
	await app.screen_opened()
	_expect(app.current == &"settings", "TRY AGAIN after game over returns to Game Settings")
	_expect(app.session.levels == 5 and app.session.difficulty == &"easy" and app.session.stage == &"random",
		"TRY AGAIN resets the settings (GameModel.init: five levels, Easy, random stage)")

	await _click(_find("normal"))
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
	await _tip_landed(score)
	await _click(_find("okBt"))
	_expect(not score.is_shown("UI_UNLOCK_TIP"), "OK closes the unlock tip")
	await _click(_find("nextLevel"))
	_expect(app.current == &"game_win" and app.screen.get_child(0).screen_name == &"game_win",
		"NEXT after the last level opens the generated congratulations screen (UI_CONGRATULATIONSONEP)")
	await app.screen_opened()
	_expect(app.screen.get_child(0).get_text("score") == "2500", "the congratulations screen shows the final total")
	var win: Node2D = app.screen.get_child(0)
	_expect(win.has_node("FallSnow"), "the congratulations screen starts FallSnow (PlayerGameOver.initView, GAME_WIN)")
	for wait in 900:
		if not _snow(win).is_empty(): break
		await process_frame
	_expect(not _snow(win).is_empty(), "FallSnow drops confetti on its 300 ms timer (creatSnow)")

	await _click(_find("back"))
	await app.screen_opened()
	await _click(_find("confirm"))
	await app.screen_opened()
	await _click(_find("startBtn"))
	game = app.game
	game.set_process(false)
	game.toggle_pause()
	for step in game.PAUSE_DELAY_STEPS: game.advance_time(1.0 / 35)
	await process_frame
	_expect(_find("mainMenu") != null and _find("mainMenu").is_visible_in_tree(), "pause opens the original pause screen with MAIN MENU (PauseUI)")
	await _click(_find("mainMenu"))
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
	# `robotRelive`: a robot that died comes back on the board (it vanished for good before).
	var sim = app.game.simulation
	var hurt: Dictionary = sim._actors[&"human"]
	hurt.protected_until = 0
	hurt.shield = 0
	hurt.vehicle = &""
	sim._hurt(&"human", &"")
	var actor_views = app.screen.get_child(0).get_meta("actors")
	for wait in 600:
		if actor_views._robots.has(&"human"): break
		await process_frame
	var gone := false
	for step in 400:
		app.game.advance_time(1.0 / 35)
		var view: Dictionary = actor_views._robots[&"human"]
		if view.removed: gone = true
		if gone and sim._actors[&"human"].alive and not view.removed: break
	var back: Dictionary = actor_views._robots[&"human"]
	var back_node: Node = app.screen.get_child(0).node_for(back.item.get("path", "")) if not back.item.is_empty() else null
	_expect(gone and sim._actors[&"human"].alive and not back.dead and back_node != null and back_node.is_visible_in_tree(),
		"a robot that respawns is shown again (AbstractPlayer.robotRelive)")
	app.game.toggle_pause()
	for step in app.game.PAUSE_DELAY_STEPS: app.game.advance_time(1.0 / 35)
	await process_frame
	await _click(_find("mainMenu"))
	_expect(app.current == &"menu", "MAIN MENU on the pause screen leaves a Battle Royale level too")

	# A stage set whose board art is not in the pack: the placeholder board goes over the
	# floor art and under the row layers; the effects layer stays over every row. (The first
	# set without a `board.sets` entry, so no art: none of the screen's recorded sets.)
	var bare: StringName = &""
	for id: StringName in StageSets.ORDER:
		if id != &"cinema" and not SwfScreen.layout_of(&"game").board.get("sets", {}).has(String(id)) and bare == &"": bare = id
	app.session.mode = &"arcade"
	app.session.stage = bare
	app.start_session()
	await process_frame
	app.game.set_process(false)
	var game_swf = app.screen.get_child(0)
	var first_row: Node = game_swf.node_for(game_swf.layout.board.rows[0])
	var board_view: Node = app.game.swf_board_view
	_expect(is_instance_valid(board_view) and board_view.get_parent() == first_row.get_parent()
		and board_view.get_index() == first_row.get_index() - 1 and board_view.get_index() > 0,
		"a %s board without art is drawn just under the first row, over the floor art" % bare)
	_expect(app.game.swf_view.get_index() == app.game.swf_view.get_parent().get_child_count() - 1,
		"weapon and protection effects are drawn over every row")
	# A stage set whose board art is in the pack (record_screen.py sets) draws its own floor,
	# boxes and features (Zoo's crocodiles, Candy Factory's machine and belt): no placeholder board.
	for set_id: StringName in [&"zoo", &"candy_factory", &"magic_library"]:
		if not FileAccess.file_exists(GameBoard.SET_PACK % set_id): continue
		app.show_main_menu()
		await process_frame
		app.session.mode = &"arcade"
		app.session.stage = set_id
		app.start_session()
		await process_frame
		app.game.set_process(false)
		var set_board: RefCounted = app.screen.get_child(0).get_meta("board")
		_expect(set_board.has_art() and set_board.set_id == set_id and not is_instance_valid(app.game.swf_board_view),
			"a %s board with its art in the pack is drawn from it, without the placeholder board" % set_id)
		if set_id == &"candy_factory":
			var classes: Array = set_board._features.map(func(f): return f["class"])
			_expect(classes.has("Art_CandyMachine") and classes.has("Art_ConveyorBelt_1"),
				"a rolled Candy Factory board has the candy machine and the belt (%s)" % [classes])
		if set_id == &"magic_library":
			_check_spellbook(app, set_board)
	app.queue_free()
	await process_frame
	print("%s: %d flow scene checks" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)


## A rolled Magic Library board shows the spellbook (`Spellbook.initDis`) and follows its flip
## (`Spellbook.runEngine`) from the round's spellbook state, with the signs on the targets'
## rows as the reference player showed them (a second child of a row's platform layer renames
## the spellbook's container `@0` to `@0#0`; the signs leave on frame 69).
func _check_spellbook(app: Node, board: RefCounted) -> void:
	var book: Array = board._features.filter(func(f): return f["class"] == "Art_Spellbook")
	_expect(book.size() == 1, "a rolled Magic Library board has the spellbook")
	if book.size() != 1: return
	var screen: Node2D = app.screen.get_child(0)
	var snapshot: Dictionary = app.game.get_snapshot()
	var state: Dictionary = {}
	for f: Dictionary in snapshot.get("features", []):
		if f.kind == &"spellbook": state = f
	_expect(not state.is_empty() and Vector2i(state.cell) == Vector2i(book[0].cell[0], book[0].cell[1]),
		"the spellbook stands on the round's spellbook cell")
	if state.is_empty(): return
	var at: Vector2i = state.cell
	var clock := {"tick": int(snapshot.tick)}  # (a lambda captures locals by value)
	var layer: String = board._board.layers.platform[at.y]
	var up := Vector2i(1, at.y - 2)
	var step := func(flipping: bool, frame: int, closed: int, signs: Array) -> void:
		clock.tick += 1
		var s := snapshot.duplicate()
		s.tick = clock.tick
		s.features = [{"kind": &"spellbook", "cell": at, "flipping": flipping, "frame": frame, "closed": closed, "signs": signs}]
		board.update(s)
	var signs := [{"cell": up, "kind": &"bomb"}, {"cell": Vector2i(at.x + 4, at.y), "kind": &"pickup"}]
	step.call(true, 2, 0, signs)
	_expect(board.art_path(book[0]) == layer + "/@0#0/@0" and screen.by_path.has(layer + "/@0#1"),
		"on frame 2 a sign joins the spellbook's row (%s)" % board.art_path(book[0]))
	_expect(screen.by_path.has(String(board._board.layers.platform[up.y]) + "/@0"), "the bomb's sign is on its own row")
	_expect(screen.by_path.has(board.art_path(book[0]) + "/@42") and int(screen.by_path[board.art_path(book[0])].get_meta("swf_frame", 0)) == 2,
		"frame 2 shows its body and the loop carried on over it")
	step.call(true, 69 - 1, 0, signs)
	_expect(not screen.by_path.has(board.art_path(book[0]) + "/@42"), "the loop is gone by frame 68")
	step.call(false, 69, 0, [])
	_expect(board.art_path(book[0]) == layer + "/@0/@0" and not screen.by_path.has(layer + "/@0#1"),
		"deleSign takes the signs off on frame 69")


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


## As `_lose_level`, checking the end cartoon (`GameEndCartoon`): `loseCartoon` is the UI
## container's last child, over the HUD, while the round ends, at the tween's frame, and is
## taken off when the result handler runs.
func _lose_level_with_cartoon(game: Node2D) -> void:
	var game_swf = app.screen.get_child(0)
	var cartoon = game_swf.get_meta("end_cartoon")
	# The map-loading screen closes first (`firstMapLoadOver`): the actors and HUD are drawn.
	for wait in 300:
		if app.screen.get_child_count() == 1: break
		await process_frame
	var hud_parent: String = game_swf.layout.screen_root + "/@0#1"
	# P, then P again: the HUD is the container's only child again, `@0`.
	game.toggle_pause()
	for step in game.PAUSE_DELAY_STEPS: game.advance_time(1.0 / 35.0)
	await process_frame
	game.toggle_pause()
	for wait in 60:
		if not game_swf.has_meta("pause"): break
		await process_frame
	_expect(game_swf.node_for(hud_parent + "/@0") != null and game_swf.node_for(hud_parent + "/@0#0") == null,
		"after a pause the HUD is the UI container's only child again (@0)")
	var seen := {}
	var removed := {}
	var bomb := InputEventKey.new()
	bomb.keycode = KEY_SPACE
	bomb.pressed = true
	root.push_input(bomb, true)
	for tick in 240:
		if app.current != &"playing": break
		game.advance_time(1.0 / 35.0)
		var snapshot: Dictionary = game.get_snapshot()
		if app.current != &"playing" and removed.is_empty():
			removed = {"cartoon": game_swf.by_path.has(hud_parent + "/@0#1"), "hud": game_swf.by_path.has(hud_parent + "/@0")}
		if snapshot.get("round_stage") != &"ending" or app.current != &"playing": continue
		var node: Node = game_swf.node_for(cartoon.path()) if cartoon.path() != "" else null
		var host: Node = game_swf.node_for(hud_parent)
		if seen.is_empty():
			_expect(node != null and cartoon.cartoon_name() == "loseCartoon" and node.get_parent() == host
				and node.get_index() == host.get_child_count() - 1 and game_swf.node_for(hud_parent + "/@0#0") != null,
				"a lost round shows loseCartoon, the UI container's last child over the HUD")
		var elapsed := roundi(float(snapshot.ending_progress) * 105.0)
		if elapsed == 30 and not seen.has(30):
			# P during the ending: the pause screen and the cartoon are both beside the HUD;
			# after the pause the HUD stays `@0#0` under the cartoon (it went back to `@0`).
			game.toggle_pause()
			for step in game.PAUSE_DELAY_STEPS: game.advance_time(1.0 / 35.0)
			await process_frame
			var paused_ok: bool = game.paused and game_swf.node_for(hud_parent + "/@0#0") != null
			game.toggle_pause()
			for wait in 60:
				if not game_swf.has_meta("pause"): break
				await process_frame
			_expect(paused_ok and not game_swf.has_meta("pause") and not game.paused and game_swf.node_for(hud_parent + "/@0#0") != null
				and game_swf.node_for(hud_parent + "/@0") == null and game_swf.node_for(cartoon.path()) != null,
				"a pause during the end cartoon leaves the HUD beside the cartoon")
			continue  # (the snapshot above is from before the pause's steps)
		seen[elapsed] = node != null and int(node.get_meta("swf_frame")) == cartoon.frame_at(elapsed, 100)
	bomb.pressed = false
	root.push_input(bomb, true)
	await process_frame
	_expect(seen.size() > 90 and not seen.values().has(false), "the cartoon plays its tween's frames through the ending")
	_expect(cartoon.path() == "" and not removed.is_empty() and not removed.cartoon and removed.hud,
		"the cartoon is taken off when the round settles")


## The unlock tip flies in on its own timeline; OK is where it lands once the clip is on
## its last frame (as in the original, it cannot be hit on the way in).
func _tip_landed(score: Node2D) -> void:
	for wait in 120:
		if score.get_frame("UI_UNLOCK_TIP") >= score.get_total_frames("UI_UNLOCK_TIP"): return
		await process_frame


func _snow(screen: Node2D) -> Array:
	return screen.get_children().filter(func(n): return n.has_meta("swf_effect"))


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

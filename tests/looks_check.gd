extends SceneTree
## Unlockable hats and outfits with local saving (#62), through the main scene.

const Looks = preload("res://scripts/looks.gd")
const SaveStore = preload("res://scripts/save_store.gd")
const SAVE := "user://looks-check-save.json"
var failures := 0
var checks := 0
var app: Control


func _initialize() -> void:
	# Generated screens follow frames, not the clock, so waiting for them is quick.
	load("res://scripts/ui/swf_screen.gd").frame_locked = true
	_run.call_deferred()


func _run() -> void:
	_expect(Looks.look(0, 1) == [&"hat", 1] and Looks.look(0, 4) == [&"body", 1], "robot 0: looks 1-3 are hats, 4-8 outfits")
	_expect(Looks.count(3, &"hat") == 4 and Looks.count(4, &"body") == 6, "per-robot hat/outfit split follows the unlock XML")
	_expect(Looks.newly_unlocked(2, 7200, []) == [1, 2] and Looks.newly_unlocked(2, 7200, [1]) == [2], "thresholds unlock each look once")
	_expect(Looks.newly_unlocked(2, 2499, []).is_empty() and Looks.newly_unlocked(2, 48000, []).size() == 8, "2,500 to 48,000 points cover all eight looks")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	root.size = Vector2i(1280, 720)
	app = load("res://scenes/main.tscn").instantiate()
	app.save_path = SAVE
	root.add_child(app)
	await process_frame
	await app.screen_opened()
	await _click(_find("btn_play"))
	await app.screen_opened()
	await _click(_find("startGame"))
	await app.screen_opened()
	await _click(_find("confirm"))
	await app.screen_opened()
	var swf = app.screen.get_child(0)
	# ClothesPanel: frame 1 is an unlocked look, 5 a locked one.
	_expect(swf.get_frame("Art_clothPanel0/hat1") == 5 and swf.get_frame("Art_clothPanel0/icon1") == 5,
		"a fresh save shows every look locked")
	await _click(_find("startBtn"))
	app.game.set_process(false)
	app._on_level_settled({"outcome": &"won", "result_score": 7300, "actors": {&"human": {"lives": 3}},
		"result_breakdown": {"kills": 0, "time": 5300, "difficulty": 2000}})
	await process_frame
	var score = app.screen.get_child(0)
	# OnePScoreUI.unlockCloth: the tip (UnlockTipScreen) opens with its "New outfit
	# unlocked!" line and a burst over each new look (UnlockAnimaPanel).
	_expect(score.is_shown("UI_UNLOCK_TIP") and score.is_shown("UI_UNLOCK_TIP/containerMc/unlock_tip"),
		"crossing unlock scores opens the unlock tip")
	_expect(score.get_text("UI_UNLOCK_TIP/containerMc/scoreText") == "7300", "the tip shows the total score")
	_expect(SaveStore.new(SAVE).unlocks.get("0", []) == [1, 2], "unlocks are saved at once")
	await _click(_find("okBt"))
	_expect(not score.is_shown("UI_UNLOCK_TIP"), "OK closes the tip")
	await _click(_find("dressUpBtn"))
	_expect(app.current == &"score" and score.is_shown("UI_UNLOCK_TIP"), "DRESS UP opens the tip to change looks")
	var panel := "UI_UNLOCK_TIP/containerMc/Art_clothPanel0/"
	_expect(score.get_frame(panel + "hat2") == 1 and score.get_frame(panel + "hat3") == 5, "DRESS UP offers the unlocked looks only")
	await _click(_find("hat2"))
	_expect(app.session.hat == 2, "choosing an unlocked hat wears it")
	await _click(_find("hat2"))
	_expect(app.session.hat == 0, "choosing the worn hat again removes it")
	await _click(_find("hat1"))
	await _click(_find("okBt"))
	_expect(app.current == &"score" and not score.is_shown("UI_UNLOCK_TIP"), "OK returns to the score screen")
	await _click(_find("nextLevel"))
	var actor: Dictionary = app.game.get_snapshot().actors[&"human"]
	_expect(actor.hat == 1 and actor.body == 0, "the next level shows the chosen look")
	var ai_ok := true
	for id in app.game.get_snapshot().actors:
		if id == &"human": continue
		var ai: Dictionary = app.game.get_snapshot().actors[id]
		ai_ok = ai_ok and ai.hat <= Looks.count(ai.robot, &"hat") and ai.body <= Looks.count(ai.robot, &"body")
	_expect(ai_ok, "AI robots wear random looks within their robot's set")
	app.queue_free()
	await process_frame

	app = load("res://scenes/main.tscn").instantiate()
	app.save_path = SAVE
	root.add_child(app)
	await process_frame
	await app.screen_opened()
	await _click(_find("btn_play"))
	await app.screen_opened()
	await _click(_find("startGame"))
	await app.screen_opened()
	await _click(_find("confirm"))
	await app.screen_opened()
	swf = app.screen.get_child(0)
	_expect(swf.get_frame("Art_clothPanel0/hat1") == 1 and swf.get_frame("Art_clothPanel0/hat2") == 1
		and swf.get_frame("Art_clothPanel0/hat3") == 5, "unlocks persist across launches")
	await _click(_find("robotIcon1"))
	_expect(swf.is_shown("Art_clothPanel1") and swf.get_frame("Art_clothPanel1/hat1") == 5, "looks are unlocked per robot")
	app.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("%s: %d looks checks" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)


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

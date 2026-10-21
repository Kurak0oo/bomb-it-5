extends SceneTree
## Unlockable hats and outfits with local saving (#62), through the main scene.

const Looks = preload("res://scripts/looks.gd")
const SaveStore = preload("res://scripts/save_store.gd")
const SAVE := "user://looks-check-save.json"
var failures := 0
var checks := 0
var app: Control


func _initialize() -> void:
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
	await _click(_find("Start"))
	await _click(_find("Next"))
	_expect(_find("Look1") != null and _find("Look1").disabled, "a fresh save shows every look locked")
	_expect(_find_text("2500 PTS") != null, "locked looks show their unlock score")
	await _click(_find("StartGame"))
	app.game.set_process(false)
	app._on_level_settled({"outcome": &"won", "result_score": 7300, "actors": {&"human": {"lives": 3}},
		"result_breakdown": {"kills": 0, "time": 5300, "difficulty": 2000}})
	await process_frame
	_expect(_find("UnlockTip") != null and _find_text("New outfit unlocked!") != null, "crossing unlock scores announces new looks")
	_expect(_find_text("HAT 1, HAT 2") != null, "the tip names each newly unlocked look")
	_expect(SaveStore.new(SAVE).unlocks.get("0", []) == [1, 2], "unlocks are saved at once")
	await _click(_find("TipOk"))
	_expect(_find("UnlockTip") == null or not _find("UnlockTip").is_visible_in_tree(), "OK closes the tip")
	await _click(_find("DressUp"))
	_expect(app.current == &"dress_up" and not _find("Look2").disabled and _find("Look3").disabled, "DRESS UP offers the unlocked looks only")
	await _click(_find("Look2"))
	_expect(app.session.hat == 2, "choosing an unlocked hat wears it")
	await _click(_find("Look2"))
	_expect(app.session.hat == 0, "choosing the worn hat again removes it")
	await _click(_find("Look1"))
	await _click(_find("DressDone"))
	_expect(app.current == &"score", "OK returns to the score screen")
	await _click(_find("Continue"))
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
	await _click(_find("Start"))
	await _click(_find("Next"))
	_expect(not _find("Look1").disabled and not _find("Look2").disabled and _find("Look3").disabled, "unlocks persist across launches")
	await _click(_find("Robot1"))
	_expect(_find("Look1").disabled, "looks are unlocked per robot")
	app.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("%s: %d looks checks" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)


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

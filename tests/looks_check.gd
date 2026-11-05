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

	_check_robot_parts()

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
	await _tip_landed(score)
	await _click(_find("okBt"))
	_expect(not score.is_shown("UI_UNLOCK_TIP"), "OK closes the tip")
	await _click(_find("dressUpBtn"))
	_expect(app.current == &"score" and score.is_shown("UI_UNLOCK_TIP"), "DRESS UP opens the tip to change looks")
	await _tip_landed(score)
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
	# AbstractGameMode.loseHandler: the last heart still makes the score screen (onePScore,
	# which unlocks) before UIManager.gameOver replaces it with Game Over.
	await _click(_find("startBtn"))
	app.game.set_process(false)
	app._on_level_settled({"outcome": &"lost", "result_score": 2600, "actors": {&"human": {"lives": 0}},
		"result_breakdown": {}})
	await process_frame
	_expect(app.current == &"game_over" and app.screen.get_child(0).get_text("score") == "2600",
		"the last heart opens Game Over with the session total")
	_expect(SaveStore.new(SAVE).unlocks.get("1", []) == [1], "a game over still unlocks the looks its total reached")
	app.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("%s: %d looks checks" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)


## Character select draws every robot from its recorded parts (scenes/swf/character.json):
## - every part the robot's timeline shows (tests/goldens/character-select/char<N>.timeline.json,
##   its entrance included) is a node of the screen or inside one drawn whole (robot 7's
##   first arms are off the display list at its capture);
## - with the local art pack: its hat and body clips have art for every look frame, and
##   none of its still parts is an empty image (robot 5's head was rendered while faded out).
func _check_robot_parts() -> void:
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://scenes/swf/character.json"))
	var pack_file := "res://original/screens/character/manifest.json"
	var pack: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(pack_file)) if FileAccess.file_exists(pack_file) else {}
	var nodes := {}
	for node: Dictionary in layout.nodes: nodes[String(node.get("golden_path", node.path))] = node
	for robot in 8:
		var top := String(layout.screen_root) + "/robotStage1/robotMc/robot%d" % robot
		var capture := "char%d" % robot
		var timeline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
			"res://tests/goldens/character-select/%s.timeline.json" % capture))
		var missing := []
		for path: String in timeline.tracks:
			if not path.begins_with(top + "/") or nodes.has(path): continue
			var shown := false
			for change: Array in timeline.tracks[path]:
				if change[1] != null and bool(change[1][6]): shown = true
			if not shown: continue
			# Drawn whole by an ancestor (a piece or a sequence renders its subtree, a widget
			# group its frames).
			var baked := false
			var up := path.get_base_dir()
			while up.begins_with(top) and not baked:
				baked = nodes.has(up) and (String(nodes[up].role) in ["piece", "sequence"] or nodes[up].has("frames_hide"))
				up = up.get_base_dir()
			if not baked: missing.append(path.substr(top.length()))
		_expect(missing.is_empty(), "robot %d: every part of its timeline is drawn (missing %s)" % [robot, missing])
		if pack.is_empty(): continue
		for clip: String in ["bodyMc", "hatMc"]:
			var kind := &"body" if clip == "bodyMc" else &"hat"
			var path := ""
			for p: String in nodes:
				if p.begins_with(top + "/") and p.get_file() == clip: path = String(nodes[p].path)
			var frames: Dictionary = pack.get("frames", {}).get(path, {})
			var missing_frames := []
			for frame in range(1, Looks.count(robot, kind) + 2):
				if not frames.has(str(frame)): missing_frames.append(frame)
			_expect(not path.is_empty() and missing_frames.is_empty(),
				"robot %d: %s has art for every look (missing frames %s)" % [robot, clip, missing_frames])
		var empty := []
		for p: String in nodes:
			var node: Dictionary = nodes[p]
			if not p.begins_with(top + "/") or node.role != "piece" or node.has("widget_frames"): continue
			var piece = pack.pieces.get(node.path)
			if not piece is Dictionary: continue
			var file := ProjectSettings.globalize_path(pack_file.get_base_dir().path_join(piece.file))
			var image := Image.load_from_file(file) if FileAccess.file_exists(file) else null
			if image != null and image.detect_alpha() != Image.ALPHA_NONE and image.get_used_rect().size == Vector2i.ZERO:
				empty.append(p.substr(top.length()))
		_expect(empty.is_empty(), "robot %d: no still part is an empty image (%s)" % [robot, empty])


## The unlock tip flies in on its own timeline; OK is where it lands once the clip is on
## its last frame (as in the original, it cannot be hit on the way in).
func _tip_landed(score: Node2D) -> void:
	for wait in 120:
		if score.get_frame("UI_UNLOCK_TIP") >= score.get_total_frames("UI_UNLOCK_TIP"): return
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

extends SceneTree
## The dress-up panel after a game shows the robot the player picked, not robot 0, for every
## pick and on every result path (level win, loss, game win, game over). `UnlockTipScreen`
## and `ClothesPanel` read `GameModel.P1Robot` (`session.robot`); the tip's recorded screen
## held robot 0's `robotMc` frame and `Art_clothPanel0` only, so `UnlockTipScreen.selectRobotBtn`
## now brings the picked robot's library clip and panel in from the character-select capture
## (`CharacterSelectUI.setRobotClothPanel` records the same classes for every robot).
##
## Also checks that wearing a look in the tip is the picked robot's look in the next round,
## and that the AI seats' looks are untouched.

const Looks = preload("res://scripts/looks.gd")
const SAVE := "user://dress-up-after-game-check-save.json"
## The all-looks total (`Looks.THRESHOLDS` last): every look of the picked robot is unlocked,
## so the tip offers its whole panel and the test can click one.
const ALL_LOOKS := 48000
## robot, outcome, hearts left, level to settle, what follows the score screen.
const ROUNDS := [
	{"robot": 0, "outcome": &"won", "lives": 3, "level": 1, "then": &"next"},
	{"robot": 1, "outcome": &"lost", "lives": 1, "level": 1, "then": &"restart"},
	{"robot": 2, "outcome": &"won", "lives": 3, "level": 5, "then": &"game_win"},
	{"robot": 3, "outcome": &"lost", "lives": 0, "level": 1, "then": &"game_over"},
]
var failures := 0
var checks := 0
var app: Control


func _initialize() -> void:
	# Generated screens follow frames, not the clock, so waiting for them is quick.
	load("res://scripts/ui/swf_screen.gd").frame_locked = true
	_run.call_deferred()


func _run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	root.size = Vector2i(1280, 720)
	app = load("res://scenes/main.tscn").instantiate()
	app.save_path = SAVE
	root.add_child(app)
	await process_frame
	await app.screen_opened()
	for plan: Dictionary in ROUNDS:
		await _check_round(plan)
	app.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("%s: %d dress-up after game checks" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)


## One picked robot: character select through START, the round's result, and the post-game
## tip (the automatic unlock tip and the DRESS UP button, the same UnlockTipScreen).
func _check_round(plan: Dictionary) -> void:
	var robot: int = plan.robot
	app.show_character_select()
	await process_frame
	await app.screen_opened()
	await _click(_find("robotIcon%d" % robot))
	await _click(_find("startBtn"))
	await process_frame
	_expect(app.current == &"playing" and app.session.robot == robot,
		"START on character select begins a round as robot %d" % robot)
	if app.current != &"playing": return
	app.game.set_process(false)
	var human: Dictionary = app.game.get_snapshot().actors[&"human"]
	_expect(human.robot == robot, "the round's human actor is robot %d" % robot)
	var ai_before := _ai_looks()
	for id: StringName in ai_before:
		_expect(int(ai_before[id][0]) != robot, "AI seat %s is not the picked robot %d" % [id, robot])

	app.session.level = int(plan.level)
	app._on_level_settled({"outcome": plan.outcome, "result_score": ALL_LOOKS,
		"actors": {&"human": {"lives": int(plan.lives)}}, "result_breakdown": {}})
	await process_frame
	if plan.then == &"game_over":
		# `AbstractGameMode.loseHandler`: the last heart replaces the score screen at once.
		await _check_end_screen(robot, &"game_over")
		return
	# `OnePScoreUI.initData`: the total unlocks every look, so the tip opens by itself.
	_expect(app.current == &"score", "robot %d's settled round shows the score screen" % robot)
	var score = app.screen.get_child(0) if app.current == &"score" else null
	if score == null: return
	var controller = score.get_meta("controller")
	if robot > 0:
		_expect(_has_art(score, "p1head"),
			"the score screen draws robot %d's SWF-rendered P1 head" % robot)
	_expect(score.is_shown("UI_UNLOCK_TIP"), "robot %d's unlocks open the post-game tip" % robot)
	await _check_tip(score, robot, "the unlock tip")
	await _click(_find("okBt"))
	_expect(not score.is_shown("UI_UNLOCK_TIP"), "OK closes robot %d's unlock tip" % robot)
	await _click(_find("dressUpBtn"))
	_expect(score.is_shown("UI_UNLOCK_TIP"), "DRESS UP opens the tip for robot %d" % robot)
	await _check_tip(score, robot, "DRESS UP")
	await _wear_look(score, robot)
	_expect(_ai_unchanged(ai_before), "wearing robot %d's look leaves the AI seats' looks alone" % robot)
	await _click(_find("okBt"))
	_expect(not score.is_shown("UI_UNLOCK_TIP"), "OK closes robot %d's DRESS UP tip" % robot)
	await _follow_score(score, plan)


## The tip's panel, preview and icons are the picked robot's; the recorded robot 0 panel is
## hidden while another robot's shows.
func _check_tip(score: Node2D, robot: int, where: String) -> void:
	var panel := "UI_UNLOCK_TIP/containerMc/Art_clothPanel%d" % robot
	var robot_mc := "UI_UNLOCK_TIP/containerMc/robotStage/robotMc"
	var robot_path := robot_mc + "/robot%d" % robot
	_expect(score.has_instance(panel) and score.is_shown(panel),
		"%s shows robot %d's clothes panel (%s)" % [where, robot, panel])
	for other in 8:
		if other == robot: continue
		var hidden := "UI_UNLOCK_TIP/containerMc/Art_clothPanel%d" % other
		if score.has_instance(hidden):
			_expect(not score.is_shown(hidden), "%s hides robot %d's panel" % [where, other])
	_expect(score.get_frame(robot_mc) == robot + 1,
		"%s sets the robots clip to frame %d (robotId + 1), got %d"
		% [where, robot + 1, score.get_frame(robot_mc)])
	# The reference capture's recorded stage matrices (compare tolerance): the picked
	# robot and its panel sit where the original puts them, panel N inside panel 0's box.
	_expect_matrix(score, robot, panel, where + " panel")
	_expect_matrix(score, robot, robot_path, where + " robot")
	_expect(score.get_frame("UI_UNLOCK_TIP/containerMc/robotBtn1/robotHeadMc") == robot + 1,
		"%s's P1 head shows robot %d (frame %d)" % [where, robot, robot + 1])
	if robot > 0:
		_expect(not score.is_shown(robot_mc + "/robot0"), "%s hides the recorded robot 0 preview" % where)
		# The recorded preview is baked robot 0; the SWF art pass supplies the picked robot's
		# clip, whose reference face layer (eyes and mouth) draws under the imported look.
		var preview := robot_path + "/swfPreview"
		_expect(score.has_instance(preview) and score.is_shown(preview),
			"%s draws the SWF-rendered preview of robot %d" % [where, robot])
		# The face layer differs per robot in the SWF (`head` on 1 and 3, the eye `hatMc` on 2):
		# whichever one the reference capture has must be the imported clip's own layer, at
		# the recorded frame.
		var face := ""
		var want_head := -1
		for child: String in ["head", "hatMc"]:
			var layer: String = robot_path + "/" + child
			if not score.has_instance(layer): continue
			var want: int = _golden_frame(robot, "unlock-tip", score.golden_path_of(layer))
			if want > 0:
				face = layer
				want_head = want
				break
		_expect(not face.is_empty() and score.get_frame(face) == want_head,
			"%s's robot %d preview face layer is at the reference frame (got %d, want %d)"
			% [where, robot, score.get_frame(face) if not face.is_empty() else 0, want_head])
	_expect(score.has_instance(robot_path), "%s has robot %d's robot clip" % [where, robot])
	var body := robot_path + "/bodyMc"
	_expect(score.get_frame(body) == 1, "%s's robot %d preview starts bare (bodyMc frame 1)" % [where, robot])
	var hat := robot_path + ("/head/hatMc" if score.has_instance(robot_path + "/head") else "/hatMc")
	_expect(score.has_instance(hat) and score.get_frame(hat) == 1,
		"%s's robot %d preview starts bare (hatMc frame 1)" % [where, robot])
	var first_frame := _first_track_frame(score, robot_path)
	for step in 3: await process_frame
	_expect(score.get_frame(robot_path) != first_frame,
		"%s's robot %d preview animates (frame %d -> %d)"
		% [where, robot, first_frame, score.get_frame(robot_path)])
	# 48,000 points unlocked every look of this robot (OnePScoreUI.unlockCloth).
	var bad := []
	for i in range(1, Looks.count(robot, &"hat") + 1):
		var icon := panel + "/hat%d" % i
		if not score.has_instance(icon) or score.get_frame(icon) != 1: bad.append(icon)
	for i in range(1, Looks.count(robot, &"body") + 1):
		var icon := panel + "/icon%d" % i
		if not score.has_instance(icon) or score.get_frame(icon) != 1: bad.append(icon)
	_expect(bad.is_empty(), "%s's robot %d panel has its unlocked outfit/hat icons (bad %s)"
		% [where, robot, bad])
	var tip = _tip(score)
	_expect(tip != null and tip._clothesPanel.robotId == robot,
		"%s's ClothesPanel is built for robot %d" % [where, robot])
	if tip != null:
		_expect(tip._clothesPanel._iconsHat.size() == Looks.count(robot, &"hat")
			and tip._clothesPanel._iconsBody.size() == Looks.count(robot, &"body"),
			"%s's robot %d panel has that robot's hat/outfit counts (%d/%d)"
			% [where, robot, tip._clothesPanel._iconsHat.size(), tip._clothesPanel._iconsBody.size()])


## Click an unlocked hat and outfit on that robot's panel: the worn look and the preview
## follow, through the same icon clicks the owner uses.
func _wear_look(score: Node2D, robot: int) -> void:
	var panel := "UI_UNLOCK_TIP/containerMc/Art_clothPanel%d" % robot
	var robot_path := "UI_UNLOCK_TIP/containerMc/robotStage/robotMc/robot%d" % robot
	var hat := robot_path + ("/head/hatMc" if score.has_instance(robot_path + "/head") else "/hatMc")
	var first_frame := _first_track_frame(score, robot_path)
	await _click_look(score, panel + "/hat1")
	await _click_look(score, panel + "/icon1")
	_expect(app.session.hat == 1 and app.session.body == 1,
		"wearing robot %d's hat1/icon1 writes P1HatId/P1ClothId (got %d/%d)"
		% [robot, app.session.hat, app.session.body])
	_expect(score.get_frame(hat) == 2 and score.get_frame(robot_path + "/bodyMc") == 2,
		"robot %d's preview wears the chosen look (hatMc %d, bodyMc %d)"
		% [robot, score.get_frame(hat), score.get_frame(robot_path + "/bodyMc")])
	# `ClothesPanel.onClickIcon` -> `_singleRobotMc.gotoAndPlay(1)`: the look click restarts
	# the robot's clip at its first recorded frame, then it plays on.
	_expect(score.get_frame(robot_path) == first_frame,
		"a look click restarts robot %d's preview at its first frame (%d), got %d"
		% [robot, first_frame, score.get_frame(robot_path)])
	for step in 3: await process_frame
	_expect(score.get_frame(robot_path) != first_frame,
		"robot %d's restarted preview plays on (frame %d)" % [robot, score.get_frame(robot_path)])
	var tip = _tip(score)
	_expect(tip != null and tip._clothesPanel.hatId == 1 and tip._clothesPanel.clothId == 1,
		"robot %d's ClothesPanel keeps the worn look" % robot)


## NEXT / RESTART / the last level's NEXT / game over, and the picked robot's look next.
func _follow_score(score: Node2D, plan: Dictionary) -> void:
	var robot: int = plan.robot
	match plan.then:
		&"next", &"restart":
			var button := "nextLevel" if plan.then == &"next" else "restartBtn"
			await _click(_find(button))
			_expect(app.current == &"playing", "%s after robot %d's win starts the next round" % [button, robot])
			if app.current == &"playing":
				app.game.set_process(false)
				_expect_actor(robot, 1, 1, "the next round")
		&"game_win":
			await _click(_find("nextLevel"))
			await app.screen_opened()
			await _check_end_screen(robot, &"game_win")


## The end screen shows the picked robot's head (`OnePGameOverUI.initData`), or Game Over
## leads back to Game Settings and character select: `CharacterSelectUI.initData` reopens on
## robot 0 bare (the AS3 quirk), so it must not leak the previous tip's panel.
func _check_end_screen(robot: int, id: StringName) -> void:
	_expect(app.current == id, "robot %d's game ends on the %s screen" % [robot, id])
	var swf = app.screen.get_child(0) if app.current == id else null
	if swf == null: return
	_expect(swf.get_frame("p1head") == robot + 1,
		"%s shows robot %d's head (p1head frame %d)" % [id, robot, robot + 1])
	if robot > 0:
		_expect(_has_art(swf, "p1head"),
			"%s draws robot %d's SWF-rendered head" % [id, robot])
	await _click(_find("back"))
	await app.screen_opened()
	_expect(app.current == &"settings", "TRY AGAIN after %s opens Game Settings" % id)
	await _click(_find("confirm"))
	await app.screen_opened()
	_expect(app.current == &"character", "CONFIRM opens character select")
	var character = app.screen.get_child(0) if app.current == &"character" else null
	if character == null: return
	var controller = character.get_meta("controller")
	# `CharacterSelectUI.initData`: `selectRobotIcon(0, true)` whatever the session held; the
	# owner-reported robot 0 was the post-game tip (UnlockTipScreen.selectRobotBtn).
	_expect(controller._p1RobotId == 0, "character select reopens on robot 0, as the AS3 does")
	_expect(character.is_shown("Art_clothPanel0") and not character.is_shown("Art_clothPanel%d" % robot),
		"character select shows robot 0's panel, not the finished round's robot %d" % robot)


## The SWF art pass adds the picked robot's head images to the screen's `p1head`.
func _has_art(screen: Node2D, instance: String) -> bool:
	var rec: Dictionary = screen._by_name.get(instance, {})
	return not rec.get("art", []).is_empty()


## The recorded clip frame of a golden node, or -1 when the golden has no such node.
func _golden_frame(robot: int, capture: String, path: String) -> int:
	var golden_path := "res://tests/goldens/results-robot%d/%s.json" % [robot, capture]
	if not GoldenFile.exists(golden_path): return -1
	var golden: Dictionary = GoldenFile.load_json(golden_path)
	for node: Dictionary in golden.get("nodes", []):
		if String(node.get("path", "")) == path: return int(node.get("frame", -1))
	return -1


func _tip(score: Node2D):
	var controller = score.get_meta("controller")
	if controller == null or controller._tips.is_empty(): return null
	return controller._tips[-1]


func _expect_actor(robot: int, body: int, hat: int, where: String) -> void:
	var actor: Dictionary = app.game.get_snapshot().actors[&"human"]
	_expect(actor.robot == robot and actor.body == body and actor.hat == hat,
		"%s draws robot %d in look %d|%d (got %d in %d|%d)"
		% [where, robot, body, hat, int(actor.robot), int(actor.body), int(actor.hat)])


func _ai_looks() -> Dictionary:
	var looks := {}
	for id: StringName in app.game.get_snapshot().actors:
		if id == &"human": continue
		var actor: Dictionary = app.game.get_snapshot().actors[id]
		looks[id] = [int(actor.robot), int(actor.body), int(actor.hat)]
	return looks


func _ai_unchanged(before: Dictionary) -> bool:
	for id: StringName in before:
		var actor: Dictionary = app.game.get_snapshot().actors.get(id, {})
		if actor.is_empty(): return false
		if [int(actor.robot), int(actor.body), int(actor.hat)] != before[id]: return false
	return true


## A tip icon's hit area, by the layout path it reports (`swf_hit`); several panels carry an
## `icon1`, so the name alone is ambiguous.
func _click_hit(score: Node2D, instance: String) -> void:
	var full: String = String(score.layout.get("screen_root", "")) + "/" + instance
	for child in score.find_children("*", "Button", true, false):
		if String(child.get_meta("swf_hit", "")) == full:
			await _click(child)
			return
	_expect(false, "the tip has a hit area for %s" % instance)


## A generated node's stage matrix against the recorded reference capture's (0.5 position,
## 0.001 scale, like compare.py's tolerance).
func _expect_matrix(score: Node2D, robot: int, instance: String, label: String) -> void:
	if robot == 0: return  # robot 0 is the screen's own recording, not an imported node
	var golden_path := "res://tests/goldens/results-robot%d/unlock-tip.json" % robot
	if not GoldenFile.exists(golden_path): return
	var golden: Dictionary = GoldenFile.load_json(golden_path)
	var path: String = score.golden_path_of(instance)
	var want: Array = []
	for node: Dictionary in golden.get("nodes", []):
		if String(node.path) == path:
			want = node.get("stage_matrix", [])
			break
	var got: Transform2D = score.stage_matrix_of(instance)
	var ok: bool = want.size() == 6 \
		and absf(got.x.x - float(want[0])) <= 0.001 and absf(got.y.y - float(want[3])) <= 0.001 \
		and got.origin.distance_to(Vector2(want[4], want[5])) <= 0.5
	_expect(ok, "%s has the reference stage matrix (got %s, want %s)"
		% [label, [got.x.x, got.y.y, got.origin.x, got.origin.y], want])


## The first recorded `currentFrame` of a node's track (the frame `gotoAndPlay(1)` starts
## at; the character capture's robot clips start on frame 2, robot 0 on 1).
func _first_track_frame(score: Node2D, instance: String) -> int:
	var full: String = String(score.layout.get("screen_root", "")) + "/" + instance
	var rec: Dictionary = score._by_path_rec.get(full, {})
	var track: Array = rec.get("track", [])
	if not track.is_empty() and track[0] is Array and track[0].size() > 7:
		return int(track[0][7])
	return int(rec.get("frame", 1))


## A look click, then the one frame its restart is applied on.
func _click_look(score: Node2D, instance: String) -> void:
	var full: String = String(score.layout.get("screen_root", "")) + "/" + instance
	for child in score.find_children("*", "Button", true, false):
		if String(child.get_meta("swf_hit", "")) == full:
			await _click_one(child)
			return
	_expect(false, "the tip has a hit area for %s" % instance)


func _click_one(control: Control) -> void:
	if control == null:
		_expect(false, "control to click exists")
		return
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


func _expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr(label)

extends SceneTree
## The player's dress-up choice follows the session into every level and a new game, and the
## actors pack keeps art for every look, so a later `record_screen.py actors` pass that only
## records a round's looks cannot make GameActors draw the default look (#74).

const Looks = preload("res://scripts/looks.gd")
const SAVE := "user://dress-up-check-save.json"
## robot, GameModel.P1ClothId (outfit), GameModel.P1HatId: non-default looks the two
## robots' Looks.count allows.
const LOOKS := [[0, 1, 1], [2, 2, 1]]
var failures := 0
var checks := 0
var app: Control


func _initialize() -> void:
	# Generated screens follow frames, not the clock, so waiting for them is quick.
	load("res://scripts/ui/swf_screen.gd").frame_locked = true
	_run.call_deferred()


func _run() -> void:
	_check_actor_art()

	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	root.size = Vector2i(1280, 720)
	app = load("res://scenes/main.tscn").instantiate()
	app.save_path = SAVE
	root.add_child(app)
	await process_frame
	await app.screen_opened()
	for look: Array in LOOKS:
		await _start_level(look[0], look[1], look[2])
		_expect_actor(look[0], look[1], look[2], "starting a level")
		# `AbstractGameMode.winHandler`: the score screen, then its NEXT.
		app.game.set_process(false)
		app._on_level_settled({"outcome": &"won", "result_score": 100,
			"actors": {&"human": {"lives": 3}}, "result_breakdown": {}})
		await process_frame
		app._continue()
		await process_frame
		_expect_actor(look[0], look[1], look[2], "the next level")
	# CharacterSelectUI.startFunc: `GameModel.P1Robot/P1ClothId/P1HatId` into the session, then
	# GAME_START; the new game starts on the look chosen under the robot on that screen.
	var look: Array = LOOKS[1]
	app.show_character_select()
	await process_frame
	await app.screen_opened()
	var controller = app.screen.get_child(0).get_meta("controller")
	controller.selectRobotIcon(look[0], true)
	controller._clothesPanel.changeCloth(look[1], look[2])
	await _click(_find("startBtn"))
	await process_frame
	_expect(app.current == &"playing", "START on character select begins a new game")
	_expect(app.session.robot == look[0] and app.session.body == look[1] and app.session.hat == look[2],
		"startFunc writes GameModel.P1Robot/P1ClothId/P1HatId into the session")
	app.game.set_process(false)
	_expect_actor(look[0], look[1], look[2], "a new game")

	app.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("%s: %d dress-up checks" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)


## RobotView.setRobotMc sends the innermost bodyMc/hatMc to clothID + 1 / hatID + 1; a clip
## with no hatMc is set to the hat's frame itself (`_r0_Down`), and GameActors keys its art by
## the clips it has. Every robot clip of the robot needs that look's full frame range; the
## missing art is drawn as the default look (`_robot_art`'s fallback).
func _check_actor_art() -> void:
	var pack_file := "res://original/screens/game/actors/actors.json"
	if not FileAccess.file_exists(pack_file):
		_expect(false, "the local actors pack %s is missing: run record_screen.py actors" % pack_file)
		return
	var pack: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(pack_file))
	var robots: Dictionary = pack.get("robots", {})
	for look: Array in LOOKS:
		var robot: int = look[0]
		_expect(look[1] <= Looks.count(robot, &"body") and look[2] <= Looks.count(robot, &"hat"),
			"robot %d: look %d|%d is within Looks.count" % [robot, look[1], look[2]])
		var missing := []
		for cls: String in robots:
			if not cls.begins_with("_r%d_" % robot): continue
			var clip: Dictionary = robots[cls]
			var key := "%d|%d" % [look[1] if clip.body else -1, look[2] if clip.hat else -1]
			var frames: Dictionary = clip.get("looks", {}).get(key, {})
			var gaps := []
			for frame in range(1, int(clip.get("frames", 0)) + 1):
				if not frames.has(str(frame)): gaps.append(frame)
			if gaps.size() > 0: missing.append("%s %s (frames %s)" % [cls, key, gaps])
		_expect(missing.is_empty(), "robot %d look %d|%d: the actors pack has every clip's frames (missing %s)"
			% [robot, look[1], look[2], missing])


func _start_level(robot: int, body: int, hat: int) -> void:
	app.session.robot = robot
	app.session.body = body
	app.session.hat = hat
	app.session.begin()
	app._start_level()
	await process_frame


func _expect_actor(robot: int, body: int, hat: int, where: String) -> void:
	var actor: Dictionary = app.game.get_snapshot().actors[&"human"]
	_expect(actor.robot == robot and actor.body == body and actor.hat == hat,
		"%s draws the player's robot %d in look %d|%d (got %d in %d|%d)"
		% [where, robot, body, hat, int(actor.get("robot", -1)), int(actor.get("body", -1)), int(actor.get("hat", -1))])


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

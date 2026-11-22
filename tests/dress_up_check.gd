extends SceneTree
## The player's dress-up choice follows the session into every level and a new game, and the
## actors pack keeps art for every look, so a later `record_screen.py actors` pass that only
## records a round's looks cannot make GameActors draw the default look (#74).

const Looks = preload("res://scripts/looks.gd")
const GameActors = preload("res://scripts/ui/game_actors.gd")
const SAVE := "user://dress-up-check-save.json"
## `AbstractGameMode.createAIPlayer` draws `int(random * 7)` for both looks, so an AI look
## reaches 6 whatever its robot's unlock set holds.
const MAX_AI_LOOK := 6
## robot, GameModel.P1ClothId (outfit), GameModel.P1HatId: non-default looks the two
## robots' Looks.count allows.
const LOOKS := [[0, 1, 1], [2, 2, 1]]
var failures := 0
var checks := 0
var app: Control


## A board for GameActors without a scene: `_robot_art` only reads `actor_art`.
class PackBoard extends RefCounted:
	var actor_art: Dictionary


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


## The actors pack is optional (tests/looks_check.gd); without the local pack only these
## assertions are skipped, and the level flow below still runs.
func _check_actor_art() -> void:
	var pack_file := "res://original/screens/game/actors/actors.json"
	if not FileAccess.file_exists(pack_file):
		print("NOTE: the local actors pack %s is missing; skipping the pack checks" % pack_file)
		return
	var pack: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(pack_file))
	var robots: Dictionary = pack.get("robots", {})
	if _check_frame_counts(robots):
		_check_look_grids(robots)
		_check_every_look(robots)
	_check_robot_art(pack)


## Each clip's true innermost `bodyMc`/`hatMc` frame counts: `_record_robots` stores them
## whatever looks it rendered, so the grid and clamp below no longer infer a clip's extent
## from whichever looks the pack happens to hold.
func _check_frame_counts(robots: Dictionary) -> bool:
	var missing := []
	for cls: String in robots:
		if _robot_of(cls) < 0: continue
		var clip: Dictionary = robots[cls]
		if not clip.has("body_frames") or not clip.has("hat_frames"): missing.append(cls)
	_expect(missing.is_empty(),
		"%d robot clips lack body_frames/hat_frames (%s): re-run record_screen.py actors (pack predates frame counts)"
		% [missing.size(), missing.slice(0, 5)])
	return missing.is_empty()


## `record_screen.py actors --looks all` renders a clip's looks as the full grid of its
## innermost `bodyMc`/`hatMc` frames (tools/convert/record_screen.py `_record_robots`). A pack
## recorded for one round's looks (`--looks round`) does not, and GameActors would fall back
## to the default look for the rest. The grid comes from the clip's frame counts, not from
## whichever keys the pack holds.
func _check_look_grids(robots: Dictionary) -> void:
	for cls: String in robots:
		if _robot_of(cls) < 0: continue
		var clip: Dictionary = robots[cls]
		var looks: Dictionary = clip.get("looks", {})
		var expected := {}
		# -1 for a part the clip lacks (`body_frames`/`hat_frames` 0).
		var clothes: Array = range(int(clip["body_frames"])) if clip.get("body", false) else [-1]
		var hats: Array = range(int(clip["hat_frames"])) if clip.get("hat", false) else [-1]
		for cloth: int in clothes:
			for hat: int in hats: expected["%d|%d" % [cloth, hat]] = true
		var missing := []
		var extra := []
		for key: String in expected:
			if not looks.has(key): missing.append(key)
		for key: String in looks:
			if not expected.has(key): extra.append(key)
		_expect(missing.is_empty() and extra.is_empty(),
			"%s: its looks are the clip's full grid (missing %s, extra %s)" % [cls, missing, extra])


## Every look the game can give a robot (its unlock set, and the AI's raw `int(random * 7)`
## draw up to 6): every clip resolves to the look clamped to its own frame counts, and that
## key has the clip's full frame range. Flash keeps a look past a clip's last frame on that
## last frame (`_create_ai_players`), so the default fallback only shows when the clamped look
## is the default.
func _check_every_look(robots: Dictionary) -> void:
	for robot in 8:
		var clips := _clips_of(robots, robot)
		_expect(not clips.is_empty(), "robot %d: the actors pack has its clips" % robot)
		var max_cloth: int = maxi(Looks.count(robot, &"body"), MAX_AI_LOOK)
		var max_hat: int = maxi(Looks.count(robot, &"hat"), MAX_AI_LOOK)
		for cloth in range(max_cloth + 1):
			for hat in range(max_hat + 1):
				var bad := []
				for cls: String in clips:
					var clip: Dictionary = robots[cls]
					var key: String = GameActors.resolve_look_key(clip,
						cloth if clip.get("body", false) else -1, hat if clip.get("hat", false) else -1)
					var expected := "%d|%d" % [
						mini(cloth, int(clip["body_frames"]) - 1) if clip.get("body", false) else -1,
						mini(hat, int(clip["hat_frames"]) - 1) if clip.get("hat", false) else -1]
					if key != expected:
						bad.append("%s resolves %s, not its clamped look %s" % [cls, key, expected])
						continue
					var frames: Dictionary = clip.get("looks", {}).get(key, {})
					var gaps := []
					for frame in range(1, int(clip.get("frames", 0)) + 1):
						if not frames.has(str(frame)): gaps.append(frame)
					if not gaps.is_empty():
						bad.append("%s %s misses frames %s" % [cls, key, gaps])
				_expect(bad.is_empty(),
					"robot %d look %d|%d: every clip draws its clamped look for its full range (bad %s)"
					% [robot, cloth, hat, bad])


## `_robot_art` is the draw path `resolve_look_key` serves; without a scene it still needs
## only the pack's robots (`_init` reads `board.actor_art`).
func _check_robot_art(pack: Dictionary) -> void:
	var board := PackBoard.new()
	board.actor_art = pack
	var actors := GameActors.new(null, board)
	var frames: Dictionary = actors._robot_art({"class": "_r2_Up", "cloth": 1, "hat": 0, "frame": 1})
	_expect(not frames.is_empty(), "_robot_art draws a non-default look on _r2_Up")
	# `_r2_Up` has a one-frame hatMc (its looks are "x|0"), so cloth 2, hat 1 must draw the
	# clip's last hat frame, key "2|0" (resolve_look_key), not fall back to the default 0|0.
	var robots: Dictionary = pack.get("robots", {})
	_expect_look_frame(actors, robots, "_r2_Up", 2, 1, "2|0",
		"a hat past _r2_Up's one-frame hatMc draws its clamped look")
	# Owner edit 2026-11-22: robot 0's Down clip has no hatMc in the original; its front
	# hat (character 1323) is composed for every body/hat look (tools/convert/record_screen.py).
	var down: Dictionary = robots.get("_r0_Down", {})
	_expect(int(down.get("hat_frames", 0)) == 4, "_r0_Down has hat_frames 4")
	var down_looks: Dictionary = down.get("looks", {})
	var missing_looks := []
	for cloth in 7:
		for hat in 4:
			var key := "%d|%d" % [cloth, hat]
			if not down_looks.has(key): missing_looks.append(key)
	_expect(down_looks.size() == 28 and missing_looks.is_empty(),
		"_r0_Down's looks are the 7x4 grid (missing %s)" % [missing_looks])
	_expect_look_frame(actors, robots, "_r0_Down", 0, 2, "0|2",
		"hat 2 on body 0 resolves to its front-hat look")
	# A clip without a hatMc takes the cloth only ("1|-1").
	_expect_look_frame(actors, robots, "_r2_Car_Up", 1, 0, "1|-1",
		"a clip without a hatMc draws its cloth look")
	# The dead clips have a single look of their own ("-1|-1").
	var dead: Dictionary = robots.get("_r2_Dead", {}).get("looks", {})
	if dead.is_empty():
		print("NOTE: _r2_Dead has no looks; skipping its frame check")
	else:
		_expect_look_frame(actors, robots, "_r2_Dead", 0, 0, "-1|-1",
			"a dead clip draws its own look")


## The frame `_robot_art` returns for `cls` at look `cloth`|`hat` is the pack's own entry for
## the key the game resolves, compared by image (the frame dictionaries' `file`).
func _expect_look_frame(actors: RefCounted, robots: Dictionary, cls: String, cloth: int, hat: int,
		key: String, label: String) -> void:
	var expected: Dictionary = robots.get(cls, {}).get("looks", {}).get(key, {}).get("1", {})
	var frame: Dictionary = actors._robot_art({"class": cls, "cloth": cloth, "hat": hat, "frame": 1})
	_expect(not expected.is_empty() and frame.get("file", "") == expected.get("file", ""),
		"%s (got %s, want %s %s)" % [label, frame.get("file", ""), key, expected.get("file", "")])


## The clips `_r<n>_...` of one robot; -1 for a class that is not a robot clip.
func _robot_of(cls: String) -> int:
	if not cls.begins_with("_r"): return -1
	var rest := cls.substr(2)
	var at := rest.find("_")
	if at <= 0: return -1
	var digits := rest.substr(0, at)
	return int(digits) if digits.is_valid_int() else -1


func _clips_of(robots: Dictionary, robot: int) -> Array:
	var clips := []
	for cls: String in robots:
		if _robot_of(cls) == robot: clips.append(cls)
	return clips


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

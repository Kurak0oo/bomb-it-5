extends SceneTree
## The walk clip when a direction key is released mid-step, against the reference recording
## (`gameplay-cinema-walk-stop.release.trace`): the original's `RobotController.moveStop`
## (`RobotModel.moveStop` then `RobotView.normalStop`) stops the clip on the frame it reached
## and leaves the robot where the last held tick left it; it does not finish the cycle or go
## to a stand frame. The trace's human clip is at frame 5 on the release tick and stays there.
##
## The test runs the real round simulation and the display's `GameActors` over an open Cinema
## board: three Down ticks (the clip plays 2, 3, 4), a release (one more advance to 5, then
## stopped), eleven idle ticks (5 throughout, matching every golden tick), and a fresh press
## (continues from 5, as `robot_turnHandler`'s `mc.play()` does). It also covers the
## two-key release (the last released key's clip at frame 1), a tap shorter than a step, and
## the input's model facing, against `gameplay-cinema-walk-two-key`.

const GameActors = preload("res://scripts/ui/game_actors.gd")
const Game = preload("res://scripts/game.gd")
const Simulation = preload("res://scripts/simulation/bomb_simulation.gd")
const GoldenFile = preload("res://scripts/golden_file.gd")
const PACK := "res://original/screens/game/actors/actors.json"
const TRACE := "res://tests/goldens/gameplay-cinema-walk-stop/release.trace.json"
const WALK_TICKS := 3
const IDLE_TICKS := 12
var failures := 0
var checks := 0


## The display-list calls `GameActors` makes (the same small stand-in as
## `actor_display_check.gd`): a real Node2D per attached item, recording art, frame and
## colour offset by path.
class FakeScreen extends Node2D:
	var by_path: Dictionary = {}
	var recs: Dictionary = {}

	func add_node(entry: Dictionary, art: Dictionary = {}) -> Dictionary:
		var path: String = entry.path
		var node := Node2D.new()
		var parent: Node2D = by_path.get(entry.parent, self)
		parent.add_child(node)
		node.set_meta("swf_path", path)
		by_path[path] = node
		var rec := {"node": node, "art": art, "frame": int(entry.get("frame", 0)), "color_offset": Color(0, 0, 0, 0)}
		recs[path] = rec
		return rec

	func remove_node(path: String) -> void:
		for p: String in recs.keys():
			if p != path and not p.begins_with(path + "/"): continue
			var node: Node2D = recs[p].node
			if is_instance_valid(node): node.queue_free()
			by_path.erase(p)
			recs.erase(p)

	func rename_node(path: String, new_path: String) -> void:
		for p: String in recs.keys():
			if p != path and not p.begins_with(path + "/"): continue
			var renamed: String = new_path + p.substr(path.length())
			var rec: Dictionary = recs[p]
			recs.erase(p)
			recs[renamed] = rec
			by_path.erase(p)
			by_path[renamed] = rec.node
			rec.node.set_meta("swf_path", renamed)

	func set_node_art(path: String, art: Dictionary, frame := 0) -> void:
		if not recs.has(path): return
		recs[path].art = art
		recs[path].frame = frame

	func move_node(_path: String, _stage_matrix: Array) -> void:
		pass

	func set_node_offset(path: String, offset: Color) -> void:
		if recs.has(path): recs[path].color_offset = offset

	func set_node_filter(_path: String, _filter: Dictionary) -> void:
		pass

	func set_node_alpha(_path: String, _alpha: float) -> void:
		pass

	func set_node_under(_path: String, _under: bool) -> void:
		pass

	func set_path_shown(_path: String, _shown: bool) -> void:
		pass

	func prefetch(_art: Dictionary) -> void:
		pass


## `GameBoard`'s display-list bookkeeping for the calls `GameActors` makes (attach/detach on
## row layers and cell matrices); the board is an open floor, so only the robot is drawn.
class FakeBoard extends RefCounted:
	var actor_art: Dictionary
	var screen
	var grid := 30.0
	var set_id: StringName = &"cinema"
	var _children: Dictionary = {}

	func layer_of(y: int, layer: int) -> String:
		return "row%d/L%d" % [y, layer]

	func row_of(y: int) -> String:
		return "row%d" % y

	func cell_matrix(cell: Vector2) -> Array:
		return [1.0, 0.0, 0.0, 1.0, float(cell.x) * grid, float(cell.y) * grid]

	func stopped_art(_cls: String) -> Dictionary:
		return {}

	func attach(layer: String, item: Dictionary, matrix: Array, art: Dictionary = {}, role := "group", _outline := false, frame := 0) -> void:
		var list: Array = _children.get_or_add(layer, [])
		list.append(item)
		item.path = "%s/c%d" % [layer, list.size() - 1]
		if list.size() == 2: _repath(layer)
		screen.add_node({"path": item.path, "parent": layer, "stage_matrix": matrix, "role": role,
			"kind": "movie_clip", "effective_visible": true, "frame": frame}, art)

	func detach(layer: String, item: Dictionary) -> void:
		var list: Array = _children.get(layer, [])
		var k := list.find(item)
		if k < 0: return
		screen.remove_node(item.path)
		list.remove_at(k)
		_repath(layer)

	func _repath(layer: String) -> void:
		var list: Array = _children.get(layer, [])
		for k in list.size():
			var path := "%s/c%d" % [layer, k] if list.size() > 1 else "%s/c0" % layer
			if list[k].path == path: continue
			screen.rename_node(list[k].path, path)
			list[k].path = path


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if not FileAccess.file_exists(PACK):
		print("SKIP: walk stop check needs the local actors pack")
		quit(0)
		return
	var pack: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PACK))
	var golden := _golden_frames()
	_expect(golden.size() == IDLE_TICKS, "the recorded release trace has %d ticks" % IDLE_TICKS)
	var scene := _make(pack)
	var actors: RefCounted = scene.actors
	var sim: RefCounted = scene.sim
	actors.update(sim.snapshot())
	var view: Dictionary = actors._robots[&"human"]
	_expect(int(view.frame) == 1 and not view.playing, "the robot starts stopped on the clip's first frame")
	var commands: Array[Dictionary] = [_command(Vector2.DOWN)]
	for tick in WALK_TICKS:
		actors.update(sim.advance(commands))
	_expect(int(view.frame) == 4 and view.playing,
		"three held Down ticks advance the walk clip to frame 4 (recorded: one frame per tick)")
	commands = [_command(Vector2.ZERO)]
	var released: Dictionary = sim.advance(commands)
	actors.update(released)
	var released_frame := int(view.frame)
	_expect(released_frame == int(golden[0]),
		"the release tick shows the recorded stop frame %d (display %d)" % [int(golden[0]), released_frame])
	_expect(not view.playing, "RobotView.normalStop stops the clip on the release tick")
	var idle: Array[int] = [released_frame]
	for tick in IDLE_TICKS - 1:
		actors.update(sim.advance(commands))
		idle.append(int(view.frame))
	# Every tick over the release must match the reference trace, not just the first.
	_expect(idle == golden, "the clip stays on the recorded frame every tick after the release (%s vs %s)" % [idle, golden])
	_expect(not view.playing, "a stopped clip does not resume while no direction is held")
	# A fresh press resumes `mc.play()` from the stopped frame; it does not make a new clip.
	commands = [_command(Vector2.DOWN)]
	actors.update(sim.advance(commands))
	_expect(int(view.frame) == released_frame % 24 + 1 and view.playing,
		"a fresh Down press plays on from the stopped frame, as robot_turnHandler's mc.play() does")
	# Two held directions released in one tick: `InteractiveController.moveStop` for the
	# first release still has the other key, dispatches its direction (a new clip at frame 1)
	# and the second release empties `movArr`; the same tick's moveStop stops that new clip.
	# The release goes through the real command boundary, as the input layer stages it.
	var stopped: Array[Dictionary] = [_command(Vector2.ZERO)]
	sim.stage_release(&"human", Vector2.RIGHT)
	actors.update(sim.advance(stopped))
	_expect(view.class == "_r0_Right" and int(view.frame) == 1 and not view.playing,
		"a two-key release keeps the last released (Right) clip at frame 1, stopped")
	# A quick tap shorter than a step: the key-down and key-up both land between frames, but
	# the original's robotTurn still makes the new direction's clip at frame 1 before moveStop.
	sim.stage_release(&"human", Vector2.LEFT)
	actors.update(sim.advance(stopped))
	_expect(view.class == "_r0_Left" and int(view.frame) == 1 and not view.playing,
		"a tap between frames shows the tapped (Left) clip at frame 1, stopped")
	# The listener is off in a portal (`RobotView.robotMoveStop`): a release that lands while
	# the robot is sent must not turn the new clip, even though the command carries it.
	var human: Dictionary = sim.actors()[&"human"]
	human.transit_until = int(sim.snapshot().tick) + 5
	sim.stage_release(&"human", Vector2.RIGHT)
	actors.update(sim.advance(stopped))
	_expect(view.class == "_r0_Left" and int(view.frame) == 1 and not view.playing,
		"a release during portal transit does not turn the clip")
	human.transit_until = 0
	view.transit = false
	# A toy hand owns the movement callback: `PushRobotCommand` re-selects it every tick.
	human.pushed = {"direction": Vector2i.LEFT, "speed": 4.0}
	sim.stage_release(&"human", Vector2.RIGHT)
	actors.update(sim.advance(stopped))
	_expect(view.class == "_r0_Left" and int(view.frame) == 1 and not view.playing,
		"a release during a toy-hand push does not turn the clip")
	human.pushed = {}
	sim.clear_release(&"human")
	scene.screen.queue_free()
	await process_frame
	# The input side: the snapshot carries the last released key's direction and the model
	# keeps that facing (`InteractiveController.moveStop` / `RobotController.robot_turnHandler` -> `RobotView.robotTurn`).
	var game: Node = Game.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.start_session(true, 42)
	for tick in 120:
		if game._can_control(): break
		game.advance_time(1.0 / 35.0)
	_expect(game._can_control(), "the practice round accepts direction input")
	_key(KEY_RIGHT, true)
	game.advance_time(1.0 / 35.0)
	_key(KEY_DOWN, true)
	game.advance_time(1.0 / 35.0)
	_key(KEY_DOWN, false)
	_key(KEY_RIGHT, false)
	game.advance_time(1.0 / 35.0)
	var snap: Dictionary = game.get_snapshot()
	_expect(snap.commands[0].direction == Vector2.ZERO, "the two-key release tick requests no movement")
	_expect(snap.commands[0].get("release_direction", Vector2.ZERO) == Vector2.RIGHT,
		"the input command carries the last released (Right) direction")
	_expect(snap.actors[&"human"].facing == Vector2.RIGHT,
		"the model keeps the last released (Right) facing after both keys are up")
	# One key released while the other stays held: the remaining key turns and walks.
	_key(KEY_RIGHT, true)
	_key(KEY_DOWN, true)
	game.advance_time(1.0 / 35.0)
	_key(KEY_DOWN, false)
	game.advance_time(1.0 / 35.0)
	_expect(game.get_snapshot().actors[&"human"].facing == Vector2.RIGHT,
		"releasing Down while Right stays held leaves the robot facing and walking Right")
	_key(KEY_RIGHT, false)
	game.advance_time(1.0 / 35.0)
	# A release whose listener is off (push, portal) is not staged, so it cannot turn the clip.
	var live: Dictionary = game.simulation.actors()[&"human"]
	live.pushed = {"direction": Vector2i.LEFT, "speed": 4.0}
	_key(KEY_LEFT, true)
	_key(KEY_LEFT, false)
	game.advance_time(1.0 / 35.0)
	_expect(game.get_snapshot().actors[&"human"].facing == Vector2.RIGHT,
		"a release during a push leaves the facing unchanged")
	live.pushed = {}
	live.transit_until = int(game.get_snapshot().tick) + 5
	_key(KEY_UP, true)
	_key(KEY_UP, false)
	game.advance_time(1.0 / 35.0)
	_expect(game.get_snapshot().actors[&"human"].facing == Vector2.RIGHT,
		"a release during portal transit leaves the facing unchanged")
	live.transit_until = 0
	game.queue_free()
	await process_frame
	print("%s: %d walk stop checks" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)


func _command(direction: Vector2) -> Dictionary:
	return {"actor_id": &"human", "direction": direction, "bomb_events": []}


func _key(keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = pressed
	root.push_input(event, true)


func _make(pack: Dictionary) -> Dictionary:
	var screen := FakeScreen.new()
	root.add_child(screen)
	var board := FakeBoard.new()
	board.actor_art = pack
	board.screen = screen
	var cells := {}
	for y in 15:
		for x in 17:
			cells[Vector2i(x, y)] = &"floor"
	var sim: RefCounted = Simulation.new([&"human"], {&"human": {"cell": Vector2i(1, 1), "robot": 0}},
		cells, {"movement": true, "damage": false, "portals": {}, "round": false, "drops": false})
	var actors: RefCounted = GameActors.new(screen, board)
	return {"screen": screen, "board": board, "actors": actors, "sim": sim}


## The human robot's clip frame in every tick of the committed release trace
## (`tools/compare/tick_trace.py`'s delta encoding), from `_r0_` clips on the player's layer 4.
func _golden_frames() -> Array[int]:
	var trace: Dictionary = GoldenFile.load_json(TRACE)
	if trace.is_empty():
		_fail("the recorded release trace is missing")
		return []
	var by_path := {}
	for node: Dictionary in trace.get("first", []):
		by_path[String(node.get("path", ""))] = node
	var result: Array[int] = []
	for tick in int(trace.get("frames", []).size()):
		if tick > 0:
			var change: Dictionary = trace.changes[tick - 1]
			for path: String in change.get("gone", []): by_path.erase(path)
			for node: Dictionary in change.get("set", []): by_path[String(node.get("path", ""))] = node
		for path: String in by_path:
			var node: Dictionary = by_path[path]
			if not String(node.get("class", "")).begins_with("_r0_"): continue
			if not path.contains("/@0#4/"): continue
			result.append(int(node.get("frame", 0)))
			break
	return result


func _fail(label: String) -> void:
	checks += 1
	failures += 1
	printerr(label)


func _expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr(label)

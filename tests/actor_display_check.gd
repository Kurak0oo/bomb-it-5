extends SceneTree
## Display-only checks for `scripts/ui/game_actors.gd`: the invincibility blink follows the
## command's end tick (`InvincibilityCommand.execute`), leaves no colour offset behind, and a
## horse jump keeps its clip playing until `HorseProp.xJump`/`yJump` land it on frame 1.
##
## The board and screen here are the smallest stand-ins for `GameBoard`/`SwfScreen` that
## `GameActors` needs: a cell matrix and a display-list path per attached item, and records for
## the runtime art/offset calls. The real pack is read for the clips.

const GameActors = preload("res://scripts/ui/game_actors.gd")
const Simulation = preload("res://scripts/simulation/bomb_simulation.gd")
const Layouts = preload("res://scripts/simulation/layouts.gd")
const Modes = preload("res://scripts/simulation/modes/modes.gd")
const StageSets = preload("res://scripts/simulation/stage_sets.gd")
const PACK := "res://original/screens/game/actors/actors.json"
const ZERO := Color(0, 0, 0, 0)
## `HorseProp.frog`'s `gotoAndPlay(19)`; `_r<n>_forg_<dir>.as` restarts at 1 on frame 34
## (its `addFrameScript(33, ...)` is 0-based).
const JUMP_START := 19
const JUMP_END := 34
var failures := 0
var checks := 0


## A display list with the handful of calls `GameActors` makes. Nodes are real Node2Ds so
## `_arrange` can order them; `recs` keeps the art and colour offset per path.
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


## A `FakeScreen` with real sprite visibility: `SwfScreen.set_node_art` hides the old image
## while the new one is resampled, and `_show_ready` shows it on the next process frame.
## Used only by the trace check, so the other checks keep the plain recorder.
class TraceScreen extends FakeScreen:
	func add_node(entry: Dictionary, art: Dictionary = {}) -> Dictionary:
		var rec := super.add_node(entry, art)
		var sprite := Sprite2D.new()
		sprite.name = "Art"
		sprite.set_meta("swf_art", true)
		rec.node.add_child(sprite)
		rec.sprite = sprite
		return rec

	func set_node_art(path: String, art: Dictionary, frame := 0) -> void:
		if not recs.has(path): return
		var rec: Dictionary = recs[path]
		if rec.art != art and rec.get("sprite", null) != null: rec.sprite.visible = false
		super.set_node_art(path, art, frame)

	func show_ready() -> void:
		for rec: Dictionary in recs.values():
			if not rec.art.is_empty() and rec.get("sprite", null) != null: rec.sprite.visible = true


## `GameBoard`'s display-list bookkeeping for the calls `GameActors` makes (attach/detach on
## row layers, cell matrices, pickups' row).
class FakeBoard extends RefCounted:
	var actor_art: Dictionary
	var screen
	var grid := 30.0
	var _children: Dictionary = {}
	var _serial := 0

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
	if FileAccess.file_exists(PACK):
		var pack: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PACK))
		_check_spawn_blink(pack)
		_check_round_window_no_blink(pack)
		_check_same_end_blink_restart(pack)
		_check_golden_spawn_captures(pack)
		_check_short_command_blink(pack)
		_check_replacement_blink(pack)
		_check_loops_follow_the_clip(pack)
		_check_horse_jump(pack)
		_check_horse_jump_turn(pack)
		_check_horse_stop_frame(pack)
	else:
		print("SKIP: actor display checks need the local actors pack")
	# The input gate reads the snapshot only: it runs with or without the art pack.
	_check_jump_input_gate()
	print("%s: %d actor display checks" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)


## `AbstractRobot.init` adds `new InvincibilityCommand(this)` (80): the +50 offset toggles
## every 4th callback and is cleared when the counter passes 80, on the 81st tick.
func _check_spawn_blink(pack: Dictionary) -> void:
	var scene := _make(pack)
	var actors: RefCounted = scene.actors
	var screen: FakeScreen = scene.screen
	actors.update(_snapshot(0))
	var view: Dictionary = actors._robots[&"human"]
	_expect(view.blinking and view.blink == 0, "spawn invincibility owns the robot's first tick")
	for tick in range(1, 82):
		actors.update(_snapshot(tick))
	_expect(not view.blinking and not view.bright and view.blink == 0,
		"the spawn blink clears on the 81st tick after robot init")
	_expect(_no_offsets(screen, view), "the spawn blink leaves no colour offset on the robot's nodes")
	scene.screen.queue_free()


## A real rolled Arcade round: the display is made on the round's tick 38 (as
## `App._game_screen` does under the map-loading screen) and runs to tick 260. The original
## never hides a robot's model while its clip changes frames (`RobotView.setRobotMc` stops
## the root clip; the nested loops just play), so after the round-start `InvincibilityCommand`
## ends no robot node may toggle visibility or a colour offset. The test's fake screen hides
## a sprite on every image change, like `SwfScreen.set_node_art` before the new image is
## resampled; the display must keep the previous image up (the model must not blink).
func _check_round_window_no_blink(pack: Dictionary) -> void:
	var states := _arcade_states(260)
	var scene := _make_trace(pack)
	var actors: RefCounted = scene.actors
	var screen: TraceScreen = scene.screen
	actors.update(states[38])
	var end := 0
	for id: StringName in actors._robots:
		end = maxi(end, int(actors._robots[id].blink_until))
	_expect(end == 38 + 81, "the round-start command runs 81 ticks from the display's first snapshot")
	for tick in range(39, end + 2):
		actors.update(states[tick])
	for id: StringName in actors._robots:
		var view: Dictionary = actors._robots[id]
		_expect(not view.blinking and not view.bright and int(view.blink) == 0,
			"%s's round-start blink is over after its command" % id)
	var toggles := _trace_toggles(actors, screen, states, 38, 260, end)
	for path: String in toggles:
		var counts: Dictionary = toggles[path]
		_expect(int(counts.visible) == 0, "%s never blinks out after protection (%d visibility toggles)" % [path, counts.visible])
		_expect(int(counts.offset) == 0, "%s keeps no +50 blink after protection (%d colour toggles)" % [path, counts.offset])
	_expect(toggles.is_empty(), "every robot node is steady after the round-start protection")
	scene.screen.queue_free()


## `CommandChain.addCommand` removes the previous `InvincibilityCommand` before adding the
## new one, so a second command starts its own 4-tick phase even when it ends on the tick the
## running command would have ended (same `blink_until`). The snapshot's `blink_serial`
## identifies the replacement; the display restarts the phase on it.
func _check_same_end_blink_restart(pack: Dictionary) -> void:
	var scene := _make(pack)
	var actors: RefCounted = scene.actors
	var screen: FakeScreen = scene.screen
	actors.update(_snapshot(0, {"blink_until": 61, "blink_started": 0, "blink_serial": 0}))
	var view: Dictionary = actors._robots[&"human"]
	for tick in range(1, 20):
		actors.update(_snapshot(tick, {"blink_until": 61, "blink_started": 0, "blink_serial": 0}))
	actors.update(_snapshot(20, {"blink_until": 66, "blink_started": 20, "blink_serial": 1}))
	for tick in range(21, 40):
		actors.update(_snapshot(tick, {"blink_until": 66, "blink_started": 20, "blink_serial": 1}))
	_expect(view.blink_until == 66 and view.blinking, "the first new command owns the blink")
	actors.update(_snapshot(40, {"blink_until": 66, "blink_started": 40, "blink_serial": 2}))
	_expect(view.blink_until == 66 and view.blinking and int(view.blink) <= 1 and not view.bright,
		"a same-end replacement command restarts the blink phase")
	_expect(_no_offsets(screen, view), "the restarted blink starts from no colour offset")
	scene.screen.queue_free()


## A real rolled Cinema Arcade round, one snapshot per tick. The display is created on
## snapshot 38, as `App._game_screen` does under the map-loading screen.
func _arcade_states(until: int) -> Array:
	var mode: RefCounted = Modes.create(&"arcade", &"normal", &"cinema")
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var board: Dictionary = Layouts.roll_set(&"cinema", false, mode.soft_chance(), rng)
	var ids: Array[StringName] = [&"human", &"ruby", &"mint", &"gold"]
	var actors := {}
	for index in ids.size():
		actors[ids[index]] = {"cell": board.spawns[index], "lives": 3 if index == 0 else 1, "robot": index}
	var game: RefCounted = Simulation.new(ids, actors, board.cells,
		{"movement": true, "damage": false, "portals": board.portals, "round": false, "drops": false,
		"seed": 42, "mode": mode, "vehicles": StageSets.vehicles(board.skin),
		"features": board.get("features", {}), "center": board.get("center"), "skin": board.skin,
		"board_meta": {"skin": board.skin, "layout": board.layout, "size": board.size,
			"variants": board.get("variants", {}), "center": board.get("center", Vector2i(7, 6)),
			"portal_ids": board.get("portal_ids", {})}})
	var states: Array = [game.snapshot()]
	var commands: Array[Dictionary] = []
	for id: StringName in ids:
		commands.append({"actor_id": id, "direction": Vector2.ZERO, "bomb_events": []})
	for tick in until:
		# A scripted walk (and idle stretches) changes the robot clip's frames as it plays.
		commands[0].direction = Vector2.RIGHT if (tick / 30) % 2 == 0 else Vector2.ZERO
		states.append(game.advance(commands))
	return states


## Every robot node's visibility and colour-offset changes after `after` (the trace logic):
## each path under each robot container is sampled once per tick, before the fake screen's
## next process frame shows a freshly resampled image.
func _trace_toggles(actors: RefCounted, screen: TraceScreen, states: Array, from_tick: int, to_tick: int, after: int) -> Dictionary:
	var previous_visible := {}
	var previous_offset := {}
	var changes := {}
	for tick in range(from_tick, to_tick + 1):
		if tick > from_tick: actors.update(states[tick])
		for id: StringName in actors._robots:
			var view: Dictionary = actors._robots[id]
			if view.get("item", {}).is_empty(): continue
			var base: String = String(view.item.path)
			for path: String in screen.recs:
				if path != base and not path.begins_with(base + "/"): continue
				var visible: bool = screen.recs[path].sprite.visible
				var offset: Color = screen.recs[path].color_offset
				if tick > after:
					if previous_visible.has(path) and previous_visible[path] != visible:
						changes.get_or_add(path, {"visible": 0, "offset": 0}).visible += 1
					if previous_offset.has(path) and previous_offset[path] != offset:
						changes.get_or_add(path, {"visible": 0, "offset": 0}).offset += 1
				previous_visible[path] = visible
				previous_offset[path] = offset
		screen.show_ready()
	return changes


## The committed captures record the original's human robot container's colour transform.
## The round's first gameplay capture is 701 (`gameplay-cinema-start`), so a capture at
## frame f is the display's tick f - 701; every included capture's +50 state must match the
## spawn command's 4-tick phase there. Captures owned by a later command (`shield/used`) are
## left out. The portal's `arrive` is owned by `Portal.runEngine`'s own
## `new InvincibilityCommand(45)`, which restarts the 4-tick phase on that tick.
func _check_golden_spawn_captures(pack: Dictionary) -> void:
	var cases := {
		"gameplay-cinema-start": ["cinema-start"],
		"gameplay-cinema-bomb": ["walk", "bomb", "blast", "box-break"],
		"gameplay-cinema-boxing": ["turned", "punch", "punch-late", "after"],
		"gameplay-cinema-portal": ["fade", "fade-late", "arrive"],
		"gameplay-cinema-invincible": ["intro", "intro-late", "glow", "glow-turned"],
		# `used` is the shield's own new InvincibilityCommand after the bomb consumes it.
		"gameplay-cinema-shield": ["held", "turned", "walk", "blast"],
	}
	var base := int(_golden_meta("gameplay-cinema-start").frames["cinema-start"])
	for case: String in cases:
		var meta := _golden_meta(case)
		var observations := []
		var restarts := {}
		var max_tick := 0
		for capture: String in cases[case]:
			var tick := int(meta.frames[capture]) - base
			# `Portal.runEngine`'s `new InvincibilityCommand(robot, 45)` on the arrival tick:
			# it ends 46 ticks later (`_check_short_command_blink`).
			var restart := 46 if case == "gameplay-cinema-portal" and capture == "arrive" else 0
			observations.append({"capture": capture, "tick": tick,
				"on": _golden_blink_on(case, capture), "restart": restart})
			if restart > 0: restarts[tick] = restart
			max_tick = maxi(max_tick, tick + 4)
		var scene := _make(pack)
		var actors: RefCounted = scene.actors
		actors.update(_snapshot(0))
		var view: Dictionary = actors._robots[&"human"]
		var lit := {0: false}
		for tick in range(1, max_tick + 1):
			var overrides := {}
			if restarts.has(tick): overrides["blink_until"] = tick + int(restarts[tick])
			actors.update(_snapshot(tick, overrides))
			lit[tick] = bool(view.bright)
		for obs: Dictionary in observations:
			_expect(bool(lit[int(obs.tick)]) == bool(obs.on),
				"%s/%s: the human robot's blink is %s at its capture tick" % [case, obs.capture,
					"on" if obs.on else "off"])
		scene.screen.queue_free()


func _golden_meta(case: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://tests/goldens/%s/meta.json" % case))


## The original's +50 on the human's own robot container at a capture
## (`color_transform.add`): the container of the human's clip `_r0_<direction>`
## (`RobotView.setRobotMc`; the player's robot is DEFAULT_ROBOTS[0]) on the player's layer 4
## (`Game.getDisArr(y).getChildAt(4)`, `robotRow`). The AI robots on layer 3 are not the
## human's.
func _golden_blink_on(case: String, capture: String) -> bool:
	var scene: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://tests/goldens/%s/%s.json" % [case, capture]))
	var by_path := {}
	for node: Dictionary in scene.nodes: by_path[String(node.get("path", ""))] = node
	for node: Dictionary in scene.nodes:
		if not String(node.get("class", "")).begins_with("_r0_"): continue
		var container: Dictionary = by_path.get(String(node.get("path", "")).get_base_dir(), {})
		if container.is_empty(): continue
		# The clip sits in the layer's container; the layer is the clip's grandparent, and the
		# player's is layer 4 (a nested container can also end `@0#4`).
		if not String(container.get("path", "")).get_base_dir().ends_with("/@0#4"): continue
		var ct = container.get("color_transform")
		var add: Array = ct.get("add", [0, 0, 0, 0]) if ct is Dictionary else [0, 0, 0, 0]
		return not add.is_empty() and int(add[0]) != 0
	return false


## Portal's `new InvincibilityCommand(robot, 45)` sets `blink_until` 46 ticks later; the
## display must stop on that tick, not after its own fixed 80-tick count.
func _check_short_command_blink(pack: Dictionary) -> void:
	var scene := _make(pack)
	var actors: RefCounted = scene.actors
	var screen: FakeScreen = scene.screen
	actors.update(_snapshot(0))
	var view: Dictionary = actors._robots[&"human"]
	var end := 128
	for tick in range(1, 82):
		actors.update(_snapshot(tick))
	for tick in range(82, end + 1):
		actors.update(_snapshot(tick, {"blink_until": end}))
	_expect(view.blink_until == end and not view.blinking and not view.bright,
		"a 45-tick InvincibilityCommand ends on its blink_until tick")
	_expect(_no_offsets(screen, view), "a finished InvincibilityCommand clears the robot's offset")
	scene.screen.queue_free()


## Portal's 45-tick command replaces a running spawn command (`CommandChain.addCommand`
## removes the old one), so its shorter end wins even though it is earlier than the spawn end.
func _check_replacement_blink(pack: Dictionary) -> void:
	var scene := _make(pack)
	var actors: RefCounted = scene.actors
	var screen: FakeScreen = scene.screen
	actors.update(_snapshot(0))
	var view: Dictionary = actors._robots[&"human"]
	for tick in range(1, 21):
		actors.update(_snapshot(tick))
	var end := 20 + 46
	actors.update(_snapshot(20, {"blink_until": end}))
	for tick in range(21, end + 1):
		actors.update(_snapshot(tick, {"blink_until": end}))
	_expect(view.blink_until == end and not view.blinking and not view.bright,
		"a shorter Portal command replaces the running spawn blink")
	_expect(_no_offsets(screen, view), "the replaced spawn blink leaves no colour offset")
	scene.screen.queue_free()


## A clip with fewer loops (`_r0_Right`) than the one before (`_r0_Down`) takes the extra loop
## node off instead of leaving it with the previous clip's offset (a blink left on the board).
func _check_loops_follow_the_clip(pack: Dictionary) -> void:
	var scene := _make(pack)
	var actors: RefCounted = scene.actors
	var screen: FakeScreen = scene.screen
	actors.update(_snapshot(0))
	var view: Dictionary = actors._robots[&"human"]
	for tick in range(1, 78):
		actors.update(_snapshot(tick))
	_expect(view.bright, "the spawn blink is lit before the direction change")
	actors.update(_snapshot(78, {}, [{"actor_id": &"human", "direction": Vector2.RIGHT}]))
	var loop_path: String = String(view.item.path) + "/@0/~loop1"
	_expect(not screen.by_path.has(loop_path),
		"_r0_Right's single loop removes _r0_Down's second loop node")
	for tick in range(79, 83):
		actors.update(_snapshot(tick, {}, [{"actor_id": &"human", "direction": Vector2.RIGHT}]))
	_expect(not view.bright and _no_offsets(screen, view),
		"no loop node keeps a +50 offset after the clip's blink turns off")
	scene.screen.queue_free()


## `HorseProp.frog`: `robotMoveStop`, then `view.mc.gotoAndPlay(19)`; while the jump runs the
## clip keeps playing even with no key held. `xJump`/`yJump` land with `gotoAndStop(1)`.
func _check_horse_jump(pack: Dictionary) -> void:
	var clip: Dictionary = pack.get("robots", {}).get("_r0_forg_Down", {})
	_expect(int(clip.get("frames", 0)) >= JUMP_END and not clip.get("looks", {}).get("0|0", {}).get(str(JUMP_END), {}).is_empty(),
		"the frog clip has frame 34, where its restart script sits (addFrameScript(33))")
	var scene := _make(pack)
	var actors: RefCounted = scene.actors
	var screen: FakeScreen = scene.screen
	var jump := {"aim": [2, 1], "speed": [4, 0], "axis": 0}
	actors.update(_snapshot(0, {"vehicle": &"horse"}))
	var view: Dictionary = actors._robots[&"human"]
	_expect(view.class == "_r0_forg_Down", "the horse ride draws the frog clip")
	actors.update(_snapshot(1, {"vehicle": &"horse", "jump": jump}))
	_expect(bool(view.get("jumping", false)) and view.playing and view.frame == JUMP_START,
		"the jump starts its clip at HorseProp.frog's gotoAndPlay(19)")
	actors.update(_snapshot(2, {"vehicle": &"horse", "jump": jump}))
	actors.update(_snapshot(3, {"vehicle": &"horse", "jump": jump}))
	_expect(view.playing and view.frame == JUMP_START + 2,
		"a held jump keeps advancing with no direction held")
	for tick in range(4, 17):
		actors.update(_snapshot(tick, {"vehicle": &"horse", "jump": jump}))
	_expect(view.playing and view.frame == JUMP_END,
		"the jump reaches frame 34, where the ride clip's restart script sits")
	actors.update(_snapshot(17, {"vehicle": &"horse", "jump": jump}))
	_expect(view.playing and view.frame == 1,
		"the ride's frame 34 script restarts its clip at 1 while the jump continues")
	actors.update(_snapshot(18, {"vehicle": &"horse"}))
	_expect(not bool(view.get("jumping", true)) and not view.playing and view.frame == 1,
		"landing stops the ride clip on gotoAndStop(1)")
	scene.screen.queue_free()


## A direction key mid-jump goes through `_turn` in the display only if the input gate is
## bypassed; the new clip keeps the jump (`HorseProp.frog` stopped the listeners, so a real
## key cannot reach this).
func _check_horse_jump_turn(pack: Dictionary) -> void:
	var scene := _make(pack)
	var actors: RefCounted = scene.actors
	var screen: FakeScreen = scene.screen
	var jump := {"aim": [2, 1], "speed": [4, 0], "axis": 0}
	actors.update(_snapshot(0, {"vehicle": &"horse"}))
	var view: Dictionary = actors._robots[&"human"]
	actors.update(_snapshot(1, {"vehicle": &"horse", "jump": jump}))
	actors.update(_snapshot(2, {"vehicle": &"horse", "jump": jump}, [{"actor_id": &"human", "direction": Vector2.RIGHT}]))
	_expect(view.class == "_r0_forg_Right" and view.jumping and view.playing and view.frame == JUMP_START + 1,
		"a turn during the jump keeps the jump playing instead of restarting it")
	actors.update(_snapshot(3, {"vehicle": &"horse", "jump": jump}))
	_expect(view.playing and view.frame == JUMP_START + 2,
		"the jump keeps advancing after a turn instead of restarting")
	scene.screen.queue_free()


## `HorseProp.frogMcStop`: the normal ride's `stopMcSurrogate` sends frame 15 to frame 1.
func _check_horse_stop_frame(pack: Dictionary) -> void:
	var scene := _make(pack)
	var actors: RefCounted = scene.actors
	var screen: FakeScreen = scene.screen
	actors.update(_snapshot(0, {"vehicle": &"horse"}))
	var view: Dictionary = actors._robots[&"human"]
	var right := [{"actor_id": &"human", "direction": Vector2.RIGHT}]
	for tick in range(1, 15):
		actors.update(_snapshot(tick, {"vehicle": &"horse"}, right))
	_expect(view.frame == 14 and view.playing, "the horse ride is on frame 14 before the stop")
	actors.update(_snapshot(15, {"vehicle": &"horse"}))
	_expect(view.frame == 1 and not view.playing,
		"a normal horse stop on frame 15 goes to frame 1 (frogMcStop)")
	scene.screen.queue_free()


## `Game._can_control`: `HorseProp.frog`'s `robotMoveStop` / `robotBombStop` remove the human's
## listeners while `jump` is set; direction and bomb keys must be ignored, then work on landing.
func _check_jump_input_gate() -> void:
	var game: Node = load("res://scripts/game.gd").new()
	game.state = {"outcome": &"running", "round_stage": &"playing", "actors": {
		&"human": {"alive": true, "jump": {"aim": [2, 1], "speed": [4, 0], "axis": 0}}}}
	game.paused = false
	var sched := FakeScheduler.new()
	game.scheduler = sched
	game.bindings = {"up": KEY_UP, "down": KEY_DOWN, "left": KEY_LEFT, "right": KEY_RIGHT, "bomb": KEY_SPACE}
	var right := InputEventKey.new()
	right.keycode = KEY_RIGHT
	right.pressed = true
	var bomb := InputEventKey.new()
	bomb.keycode = KEY_SPACE
	bomb.pressed = true
	_expect(not game._can_control(), "the human's controls are off while the frog jump runs")
	game._input(right)
	game._input(bomb)
	_expect(game.held.is_empty() and sched.direction == Vector2.ZERO and sched.bombs.is_empty(),
		"a direction and bomb key mid-jump neither turn nor queue a bomb")
	game.state.actors[&"human"].jump = {}
	_expect(game._can_control(), "landing gives the human's controls back")
	game._input(right)
	game._input(bomb)
	_expect(sched.direction == Vector2.RIGHT and sched.bombs.size() == 1,
		"after landing the same keys turn and queue the bomb again")
	sched.free()
	game.free()


## `Game._can_control`'s scheduler surface.
class FakeScheduler extends Node:
	var direction := Vector2.ZERO
	var bombs: Array = []

	func set_direction(_id: StringName, value: Vector2) -> void:
		direction = value

	func enqueue_bomb_event(_id: StringName, event: StringName) -> void:
		bombs.append(event)


## A display with a fake board/screen and the real actors pack.
func _make(pack: Dictionary) -> Dictionary:
	var screen := FakeScreen.new()
	root.add_child(screen)
	var board := FakeBoard.new()
	board.actor_art = pack
	board.screen = screen
	var actors := GameActors.new(screen, board)
	return {"screen": screen, "board": board, "actors": actors}


## The trace display: the real actors pack, a `TraceScreen` (sprite hiding on resample).
func _make_trace(pack: Dictionary) -> Dictionary:
	var screen := TraceScreen.new()
	root.add_child(screen)
	var board := FakeBoard.new()
	board.actor_art = pack
	board.screen = screen
	var actors := GameActors.new(screen, board)
	return {"screen": screen, "board": board, "actors": actors}


## One actor's snapshot; `overrides` merges into its fields and `commands` is optional.
func _snapshot(tick: int, overrides: Dictionary = {}, commands: Array = []) -> Dictionary:
	var actor := {"position": Vector2(1, 1), "alive": true, "robot": 0, "body": 0, "hat": 0,
		"cell": Vector2i(1, 1), "base_weapon": &"", "vehicle": &"", "jump": {}, "blink_until": 0}
	actor.merge(overrides, true)
	return {"tick": tick, "actors": {&"human": actor}, "commands": commands, "attacks": [], "bombs": [],
		"projectiles": [], "pickups": {}, "features": [], "flames": [], "board": {}, "board_meta": {}}


## Whether every node inside the robot's container still has a zero (`ColorTransform`) offset.
func _no_offsets(screen: FakeScreen, view: Dictionary) -> bool:
	var base: String = String(view.item.path)
	for path: String in screen.recs:
		if path != base and not path.begins_with(base + "/"): continue
		if screen.recs[path].color_offset != ZERO: return false
	return true


func _expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr(label)

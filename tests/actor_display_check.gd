extends SceneTree
## Display-only checks for `scripts/ui/game_actors.gd`: the invincibility blink follows the
## command's end tick (`InvincibilityCommand.execute`), leaves no colour offset behind, and a
## horse jump keeps its clip playing until `HorseProp.xJump`/`yJump` land it on frame 1.
##
## The board and screen here are the smallest stand-ins for `GameBoard`/`SwfScreen` that
## `GameActors` needs: a cell matrix and a display-list path per attached item, and records for
## the runtime art/offset calls. The real pack is read for the clips.

const GameActors = preload("res://scripts/ui/game_actors.gd")
const SwfScreen = preload("res://scripts/ui/swf_screen.gd")
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


## A `FakeScreen` with real sprite visibility: `SwfScreen.set_node_art` keeps the image
## already shown while the new one is resampled (hiding only for an empty replacement), and
## `_show_ready` shows the new image once ready. Used only by the trace check, so the other
## checks keep the plain recorder.
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
		if art.is_empty() and rec.get("sprite", null) != null: rec.sprite.visible = false
		super.set_node_art(path, art, frame)

	func show_ready() -> void:
		for rec: Dictionary in recs.values():
			if not rec.art.is_empty() and rec.get("sprite", null) != null: rec.sprite.visible = true


## A `FakeScreen` that records which image is actually up: `prefetch` marks a file ready (the
## background resample finished), and `set_node_art` only swaps the shown image for a ready
## one, keeping the previous image otherwise, as the real `SwfScreen.set_node_art` does.
class ArtScreen extends FakeScreen:
	var loaded: Dictionary = {}

	func prefetch(art: Dictionary) -> void:
		if String(art.get("file", "")) != "": loaded[String(art.file)] = true

	func add_node(entry: Dictionary, art: Dictionary = {}) -> Dictionary:
		var rec := super.add_node(entry, art)
		var sprite := Sprite2D.new()
		sprite.name = "Art"
		sprite.set_meta("swf_art", true)
		rec.node.add_child(sprite)
		rec.sprite = sprite
		rec.shown_art = {}
		return rec

	func set_node_art(path: String, art: Dictionary, frame := 0) -> void:
		super.set_node_art(path, art, frame)
		if not recs.has(path): return
		var rec: Dictionary = recs[path]
		if art.is_empty():
			rec.sprite.visible = false
			rec.shown_art = {}
		elif loaded.has(String(art.get("file", ""))):
			rec.sprite.visible = true
			rec.shown_art = art
		# (not ready: the previous image stays up)


## `GameBoard`'s display-list bookkeeping for the calls `GameActors` makes (attach/detach on
## row layers, cell matrices, pickups' row).
class FakeBoard extends RefCounted:
	var actor_art: Dictionary
	var screen
	var grid := 30.0
	var set_id: StringName = &"cinema"
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
	# The input gate reads the snapshot only: it runs with or without the art pack.
	_check_jump_input_gate()
	if not FileAccess.file_exists(PACK):
		# A clean checkout has no local pack: announce the skip only, so `run_checks` reports
		# it instead of counting a PASS line that ran no display checks.
		if failures > 0:
			print("FAIL: %d actor display checks" % checks)
			quit(1)
			return
		print("SKIP: actor display checks need the local actors pack")
		quit(0)
		return
	var pack: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PACK))
	_check_spawn_blink(pack)
	_check_round_window_no_blink(pack)
	_check_same_end_blink_restart(pack)
	_check_golden_spawn_captures(pack)
	_check_short_command_blink(pack)
	_check_replacement_blink(pack)
	_check_loops_follow_the_clip(pack)
	_check_turn_and_ride_art(pack)
	_check_spawn_blink_at_81(pack)
	_check_horse_jump(pack)
	_check_horse_jump_turn(pack)
	_check_horse_stop_frame(pack)
	await _check_art_never_hidden(pack)
	await _check_round_frames_pinned(pack)
	await _check_failed_cache(pack)
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
	_expect(end == 81, "the round-start command ends on the round's tick 81, not the display's first tick + 81")
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


## A turn and a ride change draw the new direction's clip on their own tick: the round load
## prefetched every direction and ride clip for the seat's look, so `set_node_art` has the
## image at once instead of showing the previous clip while it resamples.
func _check_turn_and_ride_art(pack: Dictionary) -> void:
	var scene := _make_art(pack)
	var actors: RefCounted = scene.actors
	var screen: ArtScreen = scene.screen
	actors.update(_snapshot(0))
	var view: Dictionary = actors._robots[&"human"]
	var mc_path := String(view.item.path) + "/@0"
	var look := [int(view.cloth), int(view.hat)]
	var right_art: Dictionary = _frame_art(pack, "_r0_Right", look, 1)
	var car_art: Dictionary = _frame_art(pack, "_r0_Car_Right", look, 1)
	_expect(screen.loaded.has(String(_frame_art(pack, "_r0_Left", look, 1).get("file", ""))),
		"the round load prefetches the other direction's frames")
	_expect(screen.loaded.has(String(car_art.get("file", ""))), "the round load prefetches the ride's frames")
	# (the first frame of a turn is the new clip's frame 1)
	actors.update(_snapshot(1, {}, [{"actor_id": &"human", "direction": Vector2.RIGHT}]))
	mc_path = String(view.item.path) + "/@0"
	var shown: Dictionary = screen.recs[mc_path].shown_art
	_expect(String(shown.get("file", "")) == String(right_art.get("file", "")),
		"the turn tick draws the new direction's clip (%s)" % right_art.get("file", ""))
	_expect(screen.recs[mc_path].sprite.visible, "the turned robot never goes blank")
	actors.update(_snapshot(2, {"vehicle": &"car"}, [{"actor_id": &"human", "direction": Vector2.RIGHT}]))
	mc_path = String(view.item.path) + "/@0"
	shown = screen.recs[mc_path].shown_art
	_expect(String(shown.get("file", "")) == String(car_art.get("file", "")),
		"the ride change draws the ride clip on its own tick (%s)" % car_art.get("file", ""))
	_expect(screen.recs[mc_path].sprite.visible, "the riding robot never goes blank")
	scene.screen.queue_free()


## The seat's look frame `frame` of a robot clip (`_robot_art`'s lookup).
func _frame_art(pack: Dictionary, cls: String, look: Array, frame: int) -> Dictionary:
	var clip: Dictionary = pack.get("robots", {}).get(cls, {})
	var key := GameActors.resolve_look_key(clip, int(look[0]), int(look[1]))
	return clip.get("looks", {}).get(key, {}).get(str(frame), {})


## The spawn `InvincibilityCommand` ends at the round's tick 81, whatever tick the display
## first updates: created at tick 0 or at tick 38 (under the map-loading screen), the phase
## comes from `blink_started`, not from the display's own first snapshot.
func _check_spawn_blink_at_81(pack: Dictionary) -> void:
	for first in [0, 38]:
		var scene := _make(pack)
		var actors: RefCounted = scene.actors
		var blink := {"blink_until": 81, "blink_started": 0, "blink_serial": 1}
		actors.update(_snapshot(first, blink))
		var view: Dictionary = actors._robots[&"human"]
		_expect(int(view.blink_until) == 81, "the spawn blink ends at 81 when the display starts at %d" % first)
		_expect(view.blinking and int(view.blink) == first,
			"the display seeds its 4-tick phase from blink_started (start %d)" % first)
		_expect(bool(view.bright) == ((first / 4) % 2 == 1),
			"the seeded phase is the command's own (start %d)" % first)
		for tick in range(first + 1, 83):
			actors.update(_snapshot(tick, blink))
		_expect(not view.blinking and not view.bright and int(view.blink) == 0,
			"the spawn blink is over after tick 81 (start %d)" % first)
		scene.screen.queue_free()


## No art change hides a node that has an image: a board-like node, a bomb and an explosion
## keep their previous frame up while the replacement is resampled. An empty replacement (a
## clip frame the original leaves empty) hides it, as before.
func _check_art_never_hidden(pack: Dictionary) -> void:
	var screen: Node2D = SwfScreen.new()
	screen.screen_name = &"game"
	screen.is_open = true
	screen._px = 1.0
	root.add_child(screen)
	var bombs: Array = pack.get("played", {}).get("bomb0", {}).values()
	var exp: Dictionary = pack.get("nested", {}).get("exp0", {}).get("1", {}).get("1", {})
	if bombs.size() >= 2 and not exp.is_empty():
		# A board box's tile changes frame (game_board.gd `set_node_art`).
		await _show_art(screen, "board/box", bombs[0])
		_expect_change_visible(screen, "board/box", bombs[1], "a board tile")
		# Bomb0's frames (game_actors.gd `_show_bomb`) and exp0's nested blast (the arms).
		await _show_art(screen, "bomb", bombs[0])
		_expect_change_visible(screen, "bomb", bombs[1], "a bomb")
		await _show_art(screen, "explosion", bombs[0])
		_expect_change_visible(screen, "explosion", exp, "an explosion")
		# A failed resample keeps the previous image up instead of hiding the node.
		var bad := {"file": "../../../project.godot", "scale": 3.0, "pixel_size": [10, 10],
			"pixel_origin": [0, 0], "at": [1.0, 0.0, 0.0, 1.0, 0.0, 0.0]}
		screen.set_node_art("explosion", bad, 3)
		for frame in 20: await process_frame
		var rec: Dictionary = screen._by_path_rec["explosion"]
		_expect(rec.get("sprite") != null and rec.sprite.visible and rec.sprite.texture != null,
			"a failed resample shows the previous image, not nothing")
		# A replacement with no image at all hides the node, as the original's empty clip.
		screen.set_node_art("board/box", {})
		_expect(not screen._by_path_rec["board/box"].sprite.visible, "an empty replacement hides the node")
	else:
		_expect(false, "the actors pack has the bomb and explosion frames")
	screen.queue_free()


## The round's prefetched frames are pinned: filling the shared cache past its budget with
## other art must not evict them, so a turn or ride change draws its own clip's frame on its
## tick instead of leaving the old clip up while the new frame resamples.
func _check_round_frames_pinned(pack: Dictionary) -> void:
	var screen: Node2D = SwfScreen.new()
	screen.screen_name = &"game"
	screen.is_open = true
	screen._px = 1.0
	root.add_child(screen)
	var board := FakeBoard.new()
	board.actor_art = pack
	board.screen = screen
	var actors := GameActors.new(screen, board)
	actors.update(_snapshot(0))
	var view: Dictionary = actors._robots[&"human"]
	var look := [int(view.cloth), int(view.hat)]
	var right_art: Dictionary = _frame_art(pack, "_r0_Right", look, 1)
	var car_art: Dictionary = _frame_art(pack, "_r0_Car_Right", look, 1)
	var right_key := _art_key(right_art, 1.0)
	var car_key := _art_key(car_art, 1.0)
	_expect(not right_key.is_empty() and not car_key.is_empty(),
		"the pack has the turn and ride frames")
	var frames := 0
	while frames < 3000:
		await process_frame
		frames += 1
		if screen._prefetch_queue.is_empty() and SwfScreen._queued.is_empty(): break
	_expect(frames < 3000, "the round prefetch finishes")
	_expect(SwfScreen._pinned.has(right_key), "the round load pins the turn frame")
	_expect(SwfScreen._pinned.has(car_key), "the round load pins the ride frame")
	_expect(SwfScreen._has_cached(right_key), "the turn frame is ready after the prefetch")
	# Fill the shared cache past its budget with other images: the pinned round art stays.
	var filler := Image.create_empty(1024, 1024, false, Image.FORMAT_RGBA8)
	var count: int = SwfScreen.ART_BUDGET / filler.get_data_size() + 2
	for i in count: SwfScreen._cache_put("pin-test-filler-%d" % i, filler)
	_expect(not SwfScreen._has_cached("pin-test-filler-0"),
		"budget eviction drops the oldest unpinned filler")
	_expect(SwfScreen._resized_bytes <= SwfScreen.ART_BUDGET, "the shared cache stays within budget")
	_expect(SwfScreen._has_cached(right_key), "budget eviction keeps the round's turn frame")
	_expect(SwfScreen._has_cached(car_key), "budget eviction keeps the round's ride frame")
	# A turn draws the new direction's own frame (the cache's newest entries are fillers).
	actors.update(_snapshot(1, {}, [{"actor_id": &"human", "direction": Vector2.RIGHT}]))
	await process_frame
	var mc_path := String(view.item.path) + "/@0"
	_expect(_shown_name(screen, mc_path) == String(right_art.get("file", "")).get_file(),
		"the turn draws the new direction's own frame with the cache full")
	_expect(_sprite_up(screen, mc_path), "the turned robot never goes blank")
	# A ride change draws the ride clip's own frame too.
	actors.update(_snapshot(2, {"vehicle": &"car"}, [{"actor_id": &"human", "direction": Vector2.RIGHT}]))
	await process_frame
	mc_path = String(view.item.path) + "/@0"
	_expect(_shown_name(screen, mc_path) == String(car_art.get("file", "")).get_file(),
		"the ride change draws the ride clip's own frame with the cache full")
	_expect(_sprite_up(screen, mc_path), "the riding robot never goes blank")
	screen.queue_free()
	await process_frame
	_expect(SwfScreen._pinned.is_empty(), "the round's pins are dropped when its screen is torn down")
	# Release the filler images for the rest of the check.
	SwfScreen._resized.clear()
	SwfScreen._resized_order.clear()
	SwfScreen._resized_bytes = 0


## `_failed` is bounded like the resized cache and cleared on teardown; a failed source warns
## once, and the raw fallback pads the 3× source like `_fit` (same stage origin and grid).
func _check_failed_cache(pack: Dictionary) -> void:
	var bad := ProjectSettings.globalize_path("res://project.godot")
	for i in SwfScreen.FAILED_LIMIT + 44:
		SwfScreen._make(bad, 8, 8, [Vector2.ZERO, Vector2.ZERO], "failed-test-%d" % i)
	_expect(SwfScreen._failed.size() == SwfScreen.FAILED_LIMIT, "the failed cache is bounded")
	SwfScreen._is_failed(String(SwfScreen._failed.keys().back()))
	_expect(SwfScreen._warned.size() == 1, "a failed file warns once")
	for key: String in SwfScreen._failed: SwfScreen._is_failed(key)
	_expect(SwfScreen._warned.size() == 1, "checking the failed cache again does not warn again")
	var screen: Node2D = SwfScreen.new()
	screen.screen_name = &"game"
	screen._px = 1.0
	root.add_child(screen)
	screen.add_node({"path": "raw", "parent": "", "stage_matrix": [1.0, 0.0, 0.0, 1.0, 0.0, 0.0],
		"role": "piece", "kind": "movie_clip", "effective_visible": true, "frame": 1})
	var art := _frame_art(pack, "_r0_Down", [0, 0], 1)
	var rendered: Dictionary = art.duplicate()
	rendered["file"] = ProjectSettings.globalize_path("res://original/screens/game".path_join(art.file))
	rendered["size"] = Vector2(art.pixel_size[0], art.pixel_size[1])
	rendered["pixel_origin"] = Vector2(art.pixel_origin[0], art.pixel_origin[1])
	rendered["origin"] = rendered.pixel_origin / float(art.scale)
	rendered["at"] = SwfScreen._matrix(art.at)
	var rec: Dictionary = screen._by_path_rec["raw"]
	_expect(screen._place_raw(rec, rendered), "the raw fallback decodes the 3x source")
	var fit := SwfScreen._fit(ProjectSettings.globalize_path("res://original/screens/game".path_join(art.file)),
		Vector2(art.pixel_origin[0], art.pixel_origin[1]), Vector2(art.pixel_size[0], art.pixel_size[1]),
		float(art.scale), 1.0)
	var texture: Texture2D = rec.sprite.texture
	_expect(texture.get_width() == int(art.pixel_size[0] + fit.pads[0].x + fit.pads[1].x)
		and texture.get_height() == int(art.pixel_size[1] + fit.pads[0].y + fit.pads[1].y),
		"the raw fallback pads the source like _fit")
	var expected: Vector2 = (rendered.at as Transform2D).affine_inverse() * (rendered.origin - fit.pads[0] / float(art.scale))
	_expect(rec.sprite.transform.origin.is_equal_approx(expected),
		"the raw fallback keeps _fit's stage origin")
	screen.queue_free()
	await process_frame
	_expect(SwfScreen._failed.is_empty(), "teardown clears the failed cache")


## The `_fit` cache key of a pack art at screen scale `px`.
func _art_key(art: Dictionary, px: float) -> String:
	if art.is_empty(): return ""
	var file := ProjectSettings.globalize_path("res://original/screens/game".path_join(art.file))
	var size: Array = art.get("pixel_size", [])
	if size.size() != 2: return ""
	return SwfScreen._fit(file, Vector2(art.pixel_origin[0], art.pixel_origin[1]),
		Vector2(size[0], size[1]), float(art.scale), px).key


## The file name of the image a node currently shows ("" when none).
func _shown_name(screen: Node2D, path: String) -> String:
	var rec: Dictionary = screen._by_path_rec.get(path, {})
	var shown := int(rec.get("shown_art", -1))
	if shown < 0 or shown >= rec.art.size(): return ""
	return String(rec.art[shown].get("file", "")).get_file()


## Whether a node currently has a visible sprite image.
func _sprite_up(screen: Node2D, path: String) -> bool:
	var rec: Dictionary = screen._by_path_rec.get(path, {})
	return rec.get("sprite") != null and rec.sprite.visible and rec.sprite.texture != null


## Add a run-time node with `art` and wait until its image is up.
func _show_art(screen: Node2D, path: String, art: Dictionary) -> void:
	if not screen.by_path.has(path):
		screen.add_node({"path": path, "parent": "", "stage_matrix": [1.0, 0.0, 0.0, 1.0, 0.0, 0.0],
			"role": "piece", "kind": "movie_clip", "effective_visible": true, "frame": 1})
	screen.set_node_art(path, art, 1)
	for frame in 600:
		await process_frame
		var rec: Dictionary = screen._by_path_rec.get(path, {})
		if rec.get("sprite") != null and rec.sprite.visible and rec.sprite.texture != null: return
	_expect(false, "the art for %s was resampled" % path)


## Change `path`'s art and check the previous image is still up (never hidden).
func _expect_change_visible(screen: Node2D, path: String, art: Dictionary, label: String) -> void:
	screen.set_node_art(path, art, 2)
	var rec: Dictionary = screen._by_path_rec[path]
	_expect(rec.get("sprite") != null and rec.sprite.visible and rec.sprite.texture != null,
		"%s never becomes invisible across an art change" % label)


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


## The prefetch display: an `ArtScreen` that records which image a prefetched file puts up.
func _make_art(pack: Dictionary) -> Dictionary:
	var screen := ArtScreen.new()
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

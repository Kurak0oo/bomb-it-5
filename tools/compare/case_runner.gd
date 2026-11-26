class_name CaseRunner
extends RefCounted
## Replays a compare case in Godot (tools/compare/compare.py and the interactive playground):
## runs the main scene in a 700×510 SubViewport (the original stage, one unit per pixel),
## replays a case's input commands frame by frame and, at each `capture`, asks the caller to
## write the node dump and a PNG.
## Run with `--fixed-fps <swf rate>` so every frame advances by exactly one SWF frame. The
## round host is stepped by the case's frames too (`Game.capture_clock`), not by the window's
## own `_process`: a delayed or occluded draw must not give the round extra ticks.
##
## Nodes are dumped only where a generated scene marks them with the `swf_path` meta (the
## reference player's display-list path). Optional metas: `swf_baked` (the node draws its
## whole SWF subtree, so reference descendants are not expected), `swf_kind`,
## `swf_frame`, `swf_button_state`, `swf_text`, and the mask relationships
## `swf_clip_depth`, `swf_clip_mask`, `swf_mask` (paths, as in the golden).
##
## The app starts from a fresh save file, as the reference player starts with no
## SharedObject (unlocks, keys and switches all at their defaults).
##
## An action with only `godot_*` fields runs in Godot alone (the reference player and the
## golden hash skip it). Its `godot_command` may be `settle CAPTURE`: Godot cannot replay
## the original's round, so the app ends the current round with the points the original
## showed at CAPTURE (its golden) and opens the score screen so that, when CAPTURE is
## taken, the screen is as far into its timeline as the original's was
## (`App.settle_as_recorded`). `round CAPTURE` starts the next round on the board and robots
## the gameplay capture CAPTURE recorded (`App.round_as_recorded`), for the same reason;
## `ai-stop N` stops the round's AI robot of seat N (`Game.stop_ai`), where the case stops the
## original's with the `ai-control` fixture; `pickup KIND` puts a pickup on the player's cell, where
## the case gives the original's player one with the `pickup` fixture; `reposition X Y` puts the
## player on that cell, where the case uses the `reposition` fixture.

const KEYS := {"left": KEY_LEFT, "right": KEY_RIGHT, "up": KEY_UP, "down": KEY_DOWN,
	"space": KEY_SPACE, "enter": KEY_ENTER, "esc": KEY_ESCAPE, "p": KEY_P}

var tree: SceneTree
var viewport: SubViewport
var frame := 0
## The current frame has run (a key was pushed after its draw); cleared by `step`.
var _between_frames := false
## The current frame's host step was already taken (by `step` or `wait_frame_drawn`).
var _capture_frame_ticked := false
var _wait_drawing := false
var _wait_serial := 0
var log: Array = []
## Called with the capture's name after its frame is drawn; the caller writes the PNG/dump.
var on_capture: Callable
## Called with (trace name, tick) after each trace tick's frame is drawn.
var on_trace_tick: Callable
## When non-empty, `run` stops at that capture's frame-drawn point (the playground pauses).
var stop_at_capture := ""


func _init(p_tree: SceneTree, p_viewport: SubViewport) -> void:
	tree = p_tree
	viewport = p_viewport


func run(case: Dictionary) -> void:
	var actions: Array = case.actions
	for step_index in actions.size():
		var action: Dictionary = actions[step_index]
		if action.has("command") or action.has("godot_command"):
			# `godot_command` replaces the input where an owner edit moved its target
			# (the case says why); the reference player always runs `command`.
			var words: PackedStringArray = String(action.get("godot_command", action.get("command"))).split(" ", false)
			match words[0]:
				"step":
					await step(int(words[1]))
				"click":
					var at := Vector2(float(words[1]), float(words[2]))
					mouse_move(at)
					mouse_button(at, true)
					mouse_button(at, false)
				"move":
					mouse_move(Vector2(float(words[1]), float(words[2])))
				"kd", "ku":
					# After the current frame has run (`await tree.process_frame` resumes before the
					# frame's nodes process): the key lands between frames and the round sees it
					# on the next one, as in the original.
					# (Once between two frames: a second wait would run another frame.)
					if not _between_frames:
						await wait_frame_drawn()
						_between_frames = true
					key(words[1], words[0] == "kd")
				"settle":
					var golden_path := "res://tests/goldens/%s/%s.json" % [case.name, words[1]]
					var golden: Dictionary = GoldenFile.load_json(golden_path)
					viewport.get_child(0).settle_as_recorded(golden, words[1], frames_until(actions, step_index, words[1]),
						case.get("godot_phases", {}))
				"round":
					# The next round starts on the board and robots the gameplay screen's
					# capture recorded (App.round_as_recorded).
					viewport.get_child(0).round_as_recorded(words[1])
				"ai-stop":
					# The original's AI robot at Game.players index N stopped (the case's
					# `ai-control stop` fixture): Godot's gives no more commands.
					viewport.get_child(0).game.stop_ai(int(words[1]))
				"pickup":
					# The case's `pickup` fixture (the original's pickup class made on the
					# player's cell): the same pickup on the player's cell (Game.give_pickup).
					viewport.get_child(0).game.give_pickup(StringName(words[1]))
				"reposition":
					# The case's `reposition` fixture (the original's setters put the player on
					# an empty floor cell): the player on that cell (Game.reposition_human).
					viewport.get_child(0).game.reposition_human(Vector2i(int(words[1]), int(words[2])))
				"seed":
					# The app's Flash `Math.random` (scripts/simulation/avm_random.gd) takes
					# the case's seed, as the reference player's does. The screens' draws
					# (FallSnow) and a rolled round's use it; a recorded round continues from
					# where the original's stood (tests/goldens/<case>/math_random.json).
					var app_node := viewport.get_child(0)
					if app_node.has_method("seed_math_random"):
						app_node.seed_math_random(int(words[1]))
					log.append({"frame": frame, "note": "seed %s applied to the app's Math.random" % words[1]})
				_:
					log.append({"frame": frame, "note": "ignored command " + " ".join(words)})
		if action.has("capture"):
			if not _between_frames: await wait_frame_drawn()
			_between_frames = true
			var name: String = action.capture
			if stop_at_capture != "" and name == stop_at_capture:
				return
			if on_capture.is_valid():
				await on_capture.call(name)
			if tree.paused: tree.paused = false
		if action.has("trace"):
			# A trace (tools/compare/tick_trace.py): one frame at a time, the scene after each, as
			# `step 1` and a capture would, without the PNG (traces compare state only).
			for tick in int(action.ticks):
				_between_frames = false
				await tree.process_frame
				frame += 1
				tick_capture_frame()
				await wait_frame_drawn()
				_between_frames = true
				if on_trace_tick.is_valid():
					on_trace_tick.call(action.trace, tick)
				if tree.paused: tree.paused = false


## The `step N` loop: advance N frames, one host round step each.
func step(frames: int) -> void:
	_between_frames = false
	for i in frames:
		await tree.process_frame
		frame += 1
		tick_capture_frame()


## Finish the current captured frame at its host pre-draw point. The capture window is kept
## in front and unfocused so parallel captures keep drawing; the scene is frozen between
## pre-draw and post-draw so no clock advances if the draw is slow. A five-second watchdog
## forces the draw if the host never starts it, so an occluded window cannot stall the run.
func wait_frame_drawn() -> void:
	if not _capture_frame_ticked: tick_capture_frame()
	# The window flags above keep the capture window drawing in parallel, but a stuck host
	# draw must not block the run forever: after five seconds, force the frame out.
	_wait_drawing = true
	_wait_serial += 1
	var serial := _wait_serial
	var timer := tree.create_timer(5.0, true)
	timer.timeout.connect(func(): if _wait_drawing and serial == _wait_serial: RenderingServer.force_draw())
	await RenderingServer.frame_pre_draw
	tree.paused = true
	await RenderingServer.frame_post_draw
	tree.paused = false
	_wait_drawing = false
	_capture_frame_ticked = false


## One host frame for the round (`Game.capture_step`), the capture's clock: called at the
## start of each frame it steps, never by the window's own `_process`.
func tick_capture_frame() -> void:
	_capture_frame_ticked = true
	var app = viewport.get_child(0)
	if app == null: return
	var game = app.get("game")
	if game != null and is_instance_valid(game) and not game.state.is_empty():
		game.capture_step(1.0 / 35.0)


func write_nodes(path: String) -> void:
	var out := {"schema": "bombit5-godot-nodes-v1", "frame": frame,
		"stage": {"width": viewport.size.x, "height": viewport.size.y},
		"nodes": [], "unmapped_visible": 0}
	dump(viewport, out)
	FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify(out, " "))


func dump(node: Node, dump: Dictionary) -> void:
	for child in node.get_children():
		if child is CanvasItem:
			var item: CanvasItem = child
			if item.has_meta("swf_path"):
				var t := item.get_global_transform()
				var entry := {"path": String(item.get_meta("swf_path")),
					"kind": String(item.get_meta("swf_kind", "")),
					"baked": bool(item.get_meta("swf_baked", false)),
					"effective_visible": item.is_visible_in_tree(),
					# A generated screen draws alpha inside its piece art, so it reports it as a meta.
					"alpha": float(item.get_meta("swf_alpha", item.modulate.a * item.self_modulate.a)),
					"stage_matrix": [t.x.x, t.x.y, t.y.x, t.y.y, t.origin.x, t.origin.y]}
				if item.has_meta("swf_covers"): entry.covers = item.get_meta("swf_covers")
				# Made at random by a ported effect (FallSnow): compare.py checks it by rules.
				if item.has_meta("swf_effect"):
					entry.effect = String(item.get_meta("swf_effect"))
					entry.color_transform = item.get_meta("swf_color_transform", {})
					if item is Sprite2D and (item as Sprite2D).texture != null:
						var r := t * Rect2(Vector2.ZERO, (item as Sprite2D).texture.get_size())
						entry.render_bounds = [r.position.x, r.position.y, r.end.x, r.end.y]
				for key in ["frame", "button_state", "text", "clip_depth", "clip_mask", "mask"]:
					if item.has_meta("swf_" + key): entry[key] = item.get_meta("swf_" + key)
				if not entry.has("frame") and item is AnimatedSprite2D:
					entry.frame = (item as AnimatedSprite2D).frame + 1
				dump.nodes.append(entry)
			elif item.has_meta("swf_art"):
				continue  # art, outlines and hit areas of a generated screen
			elif item.is_visible_in_tree() and (item is Control or item is Sprite2D or item is Polygon2D):
				dump.unmapped_visible += 1
		self.dump(child, dump)


func mouse_move(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	viewport.push_input(event)


func mouse_button(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = at
	event.global_position = at
	event.pressed = pressed
	viewport.push_input(event)


func key(name: String, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEYS.get(name, KEY_NONE)
	event.physical_keycode = event.keycode
	event.pressed = pressed
	viewport.push_input(event)


## Frames the case steps from after action `at` until its capture `capture`.
static func frames_until(actions: Array, at: int, capture: String) -> int:
	var frames := 0
	for k in range(at + 1, actions.size()):
		var action: Dictionary = actions[k]
		if action.get("capture", "") == capture: return frames
		var words := String(action.get("godot_command", action.get("command", ""))).split(" ", false)
		if words.size() == 2 and words[0] == "step": frames += int(words[1])
		if action.has("trace"): frames += int(action.ticks)
	push_error("no capture %s after action %d" % [capture, at])
	return frames

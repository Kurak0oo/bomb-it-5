extends SceneTree
## Godot half of the comparison loop (tools/compare/compare.py). Runs the main scene in a
## 700×510 SubViewport (the original stage, one unit per pixel), replays a case's input
## commands frame by frame and, at each `capture`, writes the node dump and a PNG.
## Run with `--fixed-fps <swf rate>` so every frame advances by exactly one SWF frame.
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

const STAGE := Vector2i(700, 510)

var _viewport: SubViewport
var _out := ""
var _frame := 0
## The current frame has run (a key was pushed after its draw); cleared by `step`.
var _between_frames := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var case_path := _arg(args, "--case")
	_out = _arg(args, "--out")
	if case_path.is_empty() or _out.is_empty():
		push_error("usage: -- --case CASE.json --out DIR")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	var case: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(case_path))
	_viewport = SubViewport.new()
	_viewport.size = STAGE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.handle_input_locally = true
	root.add_child(_viewport)
	# Generated screens follow the stepped frames, not the clock (see swf_screen.gd).
	load("res://scripts/ui/swf_screen.gd").frame_locked = true
	# `--frame-clock` (a case's `godot_args`): the round's Date seconds follow the stepped
	# frames (35 a second), not the host clock, so a long case's timed events (ArcadeMode.timePassed)
	# do not depend on how fast this machine renders. The reference player's Date follows its
	# own host clock, which runs far behind its stepped frames; such a case ends before 45 s.
	if args.has("--frame-clock"):
		load("res://scripts/game.gd").seconds_source = func() -> int: return int(_frame / 35) % 60
	var app: Node = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	if "save_path" in app:
		app.save_path = _out.path_join("save.json")
		DirAccess.remove_absolute(app.save_path)
	_viewport.add_child(app)
	_run.call_deferred(case)


func _run(case: Dictionary) -> void:
	var log := []
	var actions: Array = case.actions
	for step_index in actions.size():
		var action: Dictionary = actions[step_index]
		if action.has("command") or action.has("godot_command"):
			# `godot_command` replaces the input where an owner edit moved its target
			# (the case says why); the reference player always runs `command`.
			var words: PackedStringArray = String(action.get("godot_command", action.get("command"))).split(" ", false)
			match words[0]:
				"step":
					_between_frames = false
					for i in int(words[1]):
						await process_frame
						_frame += 1
				"click":
					var at := Vector2(float(words[1]), float(words[2]))
					_mouse_move(at)
					_mouse_button(at, true)
					_mouse_button(at, false)
				"move":
					_mouse_move(Vector2(float(words[1]), float(words[2])))
				"kd", "ku":
					# After the current frame has run (`await process_frame` resumes before the
					# frame's nodes process): the key lands between frames and the round sees it
					# on the next one, as in the original.
					# (Once between two frames: a second wait would run another frame.)
					if not _between_frames:
						await RenderingServer.frame_post_draw
						_between_frames = true
					_key(words[1], words[0] == "kd")
				"settle":
					var golden_path := "res://tests/goldens/%s/%s.json" % [case.name, words[1]]
					var golden: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(golden_path))
					_viewport.get_child(0).settle_as_recorded(golden, words[1], _frames_until(actions, step_index, words[1]))
				"round":
					# The next round starts on the board and robots the gameplay screen's
					# capture recorded (App.round_as_recorded).
					_viewport.get_child(0).round_as_recorded(words[1])
				"ai-stop":
					# The original's AI robot at Game.players index N stopped (the case's
					# `ai-control stop` fixture): Godot's gives no more commands.
					_viewport.get_child(0).game.stop_ai(int(words[1]))
				"pickup":
					# The case's `pickup` fixture (the original's pickup class made on the
					# player's cell): the same pickup on the player's cell (Game.give_pickup).
					_viewport.get_child(0).game.give_pickup(StringName(words[1]))
				"reposition":
					# The case's `reposition` fixture (the original's setters put the player on
					# an empty floor cell): the player on that cell (Game.reposition_human).
					_viewport.get_child(0).game.reposition_human(Vector2i(int(words[1]), int(words[2])))
				"seed":
					# The app's Flash `Math.random` (scripts/simulation/avm_random.gd) takes
					# the case's seed, as the reference player's does. The screens' draws
					# (FallSnow) and a rolled round's use it; a recorded round continues from
					# where the original's stood (tests/goldens/<case>/math_random.json).
					var app_node := _viewport.get_child(0)
					if app_node.has_method("seed_math_random"):
						app_node.seed_math_random(int(words[1]))
					log.append({"frame": _frame, "note": "seed %s applied to the app's Math.random" % words[1]})
				_:
					log.append({"frame": _frame, "note": "ignored command " + " ".join(words)})
		if action.has("capture"):
			if not _between_frames: await RenderingServer.frame_post_draw
			_between_frames = true
			var name: String = action.capture
			_viewport.get_texture().get_image().save_png(_out.path_join(name + ".png"))
			var dump := {"schema": "bombit5-godot-nodes-v1", "frame": _frame,
				"stage": {"width": STAGE.x, "height": STAGE.y},
				"nodes": [], "unmapped_visible": 0}
			_dump(_viewport, dump)
			FileAccess.open(_out.path_join(name + ".nodes.json"), FileAccess.WRITE).store_string(JSON.stringify(dump, " "))
	FileAccess.open(_out.path_join("godot-log.json"), FileAccess.WRITE).store_string(JSON.stringify({"frame": _frame, "notes": log}, " "))
	# (A static Callable bound to this tree must not outlive it.)
	load("res://scripts/game.gd").seconds_source = Callable()
	quit(0)


func _dump(node: Node, dump: Dictionary) -> void:
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
		_dump(child, dump)


func _mouse_move(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	_viewport.push_input(event)


func _mouse_button(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = at
	event.global_position = at
	event.pressed = pressed
	_viewport.push_input(event)


const KEYS := {"left": KEY_LEFT, "right": KEY_RIGHT, "up": KEY_UP, "down": KEY_DOWN,
	"space": KEY_SPACE, "enter": KEY_ENTER, "esc": KEY_ESCAPE, "p": KEY_P}


func _key(name: String, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEYS.get(name, KEY_NONE)
	event.physical_keycode = event.keycode
	event.pressed = pressed
	_viewport.push_input(event)


## Frames the case steps from after action `at` until its capture `capture`.
static func _frames_until(actions: Array, at: int, capture: String) -> int:
	var frames := 0
	for k in range(at + 1, actions.size()):
		var action: Dictionary = actions[k]
		if action.get("capture", "") == capture: return frames
		var words := String(action.get("godot_command", action.get("command", ""))).split(" ", false)
		if words.size() == 2 and words[0] == "step": frames += int(words[1])
	push_error("no capture %s after action %d" % [capture, at])
	return frames


static func _arg(args: PackedStringArray, flag: String) -> String:
	var i := args.find(flag)
	return args[i + 1] if i >= 0 and i + 1 < args.size() else ""

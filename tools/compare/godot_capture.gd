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

const STAGE := Vector2i(700, 510)

var _viewport: SubViewport
var _out := ""
var _frame := 0


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
	_viewport.add_child(load(ProjectSettings.get_setting("application/run/main_scene")).instantiate())
	_run.call_deferred(case)


func _run(case: Dictionary) -> void:
	var log := []
	for action in case.actions:
		if action.has("command"):
			var words: PackedStringArray = String(action.command).split(" ", false)
			match words[0]:
				"step":
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
					_key(words[1], words[0] == "kd")
				"seed":
					# The replica's RNG (scripts/simulation/avm_random.gd) is not wired into
					# the screens yet; record it so the report shows the case expected one.
					log.append({"frame": _frame, "note": "seed %s not applied (no seeded RNG hook yet)" % words[1]})
				_:
					log.append({"frame": _frame, "note": "ignored command " + action.command})
		if action.has("capture"):
			await RenderingServer.frame_post_draw
			var name: String = action.capture
			_viewport.get_texture().get_image().save_png(_out.path_join(name + ".png"))
			var dump := {"schema": "bombit5-godot-nodes-v1", "frame": _frame,
				"stage": {"width": STAGE.x, "height": STAGE.y},
				"nodes": [], "unmapped_visible": 0}
			_dump(_viewport, dump)
			FileAccess.open(_out.path_join(name + ".nodes.json"), FileAccess.WRITE).store_string(JSON.stringify(dump, " "))
	FileAccess.open(_out.path_join("godot-log.json"), FileAccess.WRITE).store_string(JSON.stringify({"frame": _frame, "notes": log}, " "))
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


static func _arg(args: PackedStringArray, flag: String) -> String:
	var i := args.find(flag)
	return args[i + 1] if i >= 0 and i + 1 < args.size() else ""

extends SceneTree
## The playground's dev plugins (tools/playground/spawn_panel.gd and reference_peek.gd):
## the spawn panel changes the running round the way the compare fixtures do, and the
## reference peek loads a local 700x510 capture and paints it in Ghost mode.
##
## Run:
##   godot --path . --fixed-fps 35 --script res://tests/playground_tools_check.gd

const PLAYGROUND := preload("res://tools/playground/playground.tscn")

var failures := 0
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var playground = PLAYGROUND.instantiate()
	root.add_child(playground)
	await process_frame
	await process_frame

	# What `--case NAME --capture NAME` sets before it loads.
	playground.case_name = "gameplay-cinema-bomb"
	playground.capture_name = "walk"
	await playground.load_case()

	var spawn = playground.find_child("SpawnPanel", false, false)
	var peek = playground.find_child("ReferencePeek", false, false)
	_expect(spawn != null, "the spawn panel plugin is installed")
	_expect(peek != null, "the reference peek plugin is installed")
	var running = playground.game()
	_expect(running != null, "the loaded case reaches a round")
	if running == null or spawn == null or peek == null:
		_finish()
		return

	# The case's `kd down` is still held at the walk capture; release it and let the step that
	# carries its last momentum settle, so the pickup is not left behind and the reposition
	# check is not carried off by a held direction.
	playground.runner.key("down", false)
	await playground.step(1)

	# The `pickup KIND` fixture through the panel's own action.
	spawn.give(&"shield")
	await playground.step(3)
	var snapshot: Dictionary = running.get_snapshot()
	var human: Dictionary = snapshot.actors[&"human"]
	_expect(bool(human.get("shield", false)) or String(human.get("protection_stage", &"none")) != "none",
		"the spawn panel's shield is collected by the round")

	# The `ai-stop N` fixture through the panel's own action.
	spawn.stop_ai(1)
	_expect(true, "Stop AI 1 runs without an error")

	# The `reposition X Y` fixture: a floor cell from the live snapshot next to the human.
	var target := _next_floor(snapshot, human.cell)
	_expect(target.x >= 0, "the snapshot has a floor cell next to the human")
	if target.x >= 0:
		spawn.move_player(target)
		await playground.step(2)
		_expect(running.get_snapshot().actors[&"human"].cell == target,
			"the player stands on the cell the spawn panel moved it to")

	# The reference peek's loader and Ghost mode.
	var image := Image.create(700, 510, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.2, 0.4, 0.6, 1.0))
	var reference_path := "user://ref_test.png"
	_expect(image.save_png(reference_path) == OK, "a 700x510 test reference PNG is written")
	_expect(peek.load_reference(ProjectSettings.globalize_path(reference_path)),
		"load_reference accepts a 700x510 PNG")
	var small := Image.create(10, 10, false, Image.FORMAT_RGBA8)
	small.fill(Color(0.6, 0.2, 0.2, 1.0))
	var small_path := "user://ref_test_small.png"
	_expect(small.save_png(small_path) == OK, "a 10x10 test PNG is written")
	_expect(not peek.load_reference(ProjectSettings.globalize_path(small_path)),
		"load_reference rejects a 10x10 PNG")
	peek.set_mode(1)
	var ghost: TextureRect = null
	for child in playground.overlay.get_children():
		if child is TextureRect and (child as TextureRect).texture != null:
			ghost = child
			break
	_expect(ghost != null, "Ghost mode paints the reference TextureRect over the overlay")
	if ghost != null:
		_expect(ghost.position == Vector2.ZERO and ghost.size == Vector2(700, 510),
			"the ghost sits at the stage origin at 700x510")
		_expect(is_equal_approx(ghost.modulate.a, 0.5), "the ghost uses the opacity slider")
	_finish()


## The first floor cell from the live board next to `cell`, avoiding bombs, or (-1,-1).
func _next_floor(snapshot: Dictionary, cell: Vector2i) -> Vector2i:
	var board: Dictionary = snapshot.get("board", {})
	var occupied := {}
	for bomb in snapshot.get("bombs", []):
		if bomb is Dictionary and bomb.has("cell"):
			occupied[bomb.cell] = true
	for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
			Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		var next: Vector2i = cell + offset
		if next.x < 0 or next.y < 0 or next.x > 16 or next.y > 14:
			continue
		if board.get(next) != &"floor" or occupied.has(next):
			continue
		return next
	return Vector2i(-1, -1)


func _expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + label)


func _finish() -> void:
	print("%s: %d playground tool checks" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)

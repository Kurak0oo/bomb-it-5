extends SceneTree
## The dev playground (tools/playground/playground.gd): loading the cinema bomb case through the
## shared CaseRunner stops on the same `walk` frame godot_capture reports, and stepping advances
## both the runner frame and the live round's tick.
##
## The reference number comes from the case's godot_capture run:
## `godot --path . --fixed-fps 35 --resolution 700x510 --script res://tools/compare/godot_capture.gd
##  -- --case tools/compare/cases/gameplay-cinema-bomb.json --out .scratch/p2`
## `.scratch/p2/walk.nodes.json` has "frame": 707 (2026-11-26).
const PLAYGROUND := preload("res://tools/playground/playground.tscn")
const WALK_FRAME := 707

var failures := 0
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var playground = PLAYGROUND.instantiate()
	root.add_child(playground)
	await process_frame
	await process_frame
	_expect(playground.viewport.size == Vector2i(700, 510), "the stage viewport is the comparison's 700x510")
	_expect(playground.overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE and playground.overlay.size == Vector2(700, 510),
		"the plugin overlay covers the stage and ignores the mouse")
	_expect(playground.side_panel.size.x == 280, "the case side panel is 280 px wide")

	# What `--case NAME --capture NAME` sets before it loads.
	playground.case_name = "gameplay-cinema-bomb"
	playground.capture_name = "walk"
	await playground.load_case()
	if playground.runner == null:
		_expect(false, "the case loads through the shared CaseRunner")
		_finish()
		return
	_expect(playground.runner.frame == WALK_FRAME,
		"the loaded runner pauses on walk's frame %d (got %d)" % [WALK_FRAME, playground.runner.frame])
	var running = playground.game()
	_expect(running != null, "the loaded case reaches a real round")
	if running != null:
		var tick_before: int = int(running.get_snapshot().tick)
		await playground.step(3)
		_expect(playground.runner.frame == WALK_FRAME + 3,
			"stepping 3 advances the runner by 3 frames")
		_expect(int(running.get_snapshot().tick) > tick_before, "stepping 3 advances the round's snapshot tick")
	_finish()


func _expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + label)


func _finish() -> void:
	print("%s: %d playground checks" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)

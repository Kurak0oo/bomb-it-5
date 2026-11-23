extends SceneTree
## The comparison loop steps frames with `SwfScreen.frame_locked` (tools/compare/godot_capture.gd)
## and has no window the user drives. An application focus change there is host noise: it must
## not pause the captured round, or a capture taken during the full `compare.sh all` run shows
## the pause screen over a hidden board while the same case passes alone. Reproduced in
## .scratch/logs/close19-compare-all.log (gameplay-birthday-push, -library-kill-start,
## -zoo-crocodile, -zoo-start: 173 extra pause-screen nodes, board `@0#0` hidden, ~303 off).
##
## Outside the capture (normal play) leaving the app still pauses the round; game_scene_check
## keeps that behavior. Here: frame-locked, focus out/in advances the round exactly as if the
## window had stayed focused.

const SwfScreen = preload("res://scripts/ui/swf_screen.gd")
const Game = preload("res://scripts/game.gd")
const TICKS := 5
var failures := 0
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	SwfScreen.frame_locked = true
	var scene = Game.new()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	scene.start_session(false, 42)
	for index in TICKS: scene.advance_time(1.0 / 35.0)
	var before: int = scene.get_snapshot().tick
	# What the window server sends when another window (a terminal, another capture) takes
	# focus during the run: the scene and its scheduler see FOCUS_OUT, then FOCUS_IN.
	scene.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_expect(not scene.paused, "a frame-locked capture does not pause when the window loses focus")
	scene.advance_time(1.0 / 35.0)
	_expect(scene.get_snapshot().tick == before + 1, "the captured round keeps ticking after focus loss")
	scene.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	scene.advance_time(1.0 / 35.0)
	_expect(scene.get_snapshot().tick == before + 2, "the captured round keeps ticking after focus returns")
	_expect(not scene.paused, "the captured round stays unpaused after focus returns")
	# A whole `step` block around the focus change must advance by the same number of ticks
	# as one without it: the compare driver counts Godot frames, not window events.
	var ticks_before: int = scene.get_snapshot().tick
	scene.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	for index in 10: scene.advance_time(1.0 / 35.0)
	scene.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	for index in 10: scene.advance_time(1.0 / 35.0)
	_expect(scene.get_snapshot().tick == ticks_before + 20,
		"twenty stepped frames advance twenty ticks across a focus change")
	scene.queue_free()
	await process_frame
	SwfScreen.frame_locked = false
	print("%s: %d capture focus checks" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)


func _expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr(label)

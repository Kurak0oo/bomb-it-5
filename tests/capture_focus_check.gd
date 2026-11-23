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
## window had stayed focused, and the board's clip clock is the same whether the capture keeps
## the scheduler out of the tree or in it.

const SwfScreen = preload("res://scripts/ui/swf_screen.gd")
const Game = preload("res://scripts/game.gd")
const GameBoard = preload("res://scripts/ui/game_board.gd")
const TICKS := 5


## Records the art a `GameBoard` shows for each node, without a real screen: the board's
## film/loop clips are chosen from `_tick`, so identical recordings prove the board clock
## advances the same whether the scheduler is in the tree or detached for the capture.
class BoardScreen extends Node2D:
	var by_path := {}
	var art := {}

	func pack() -> Dictionary:
		return {}

	func add_node(entry: Dictionary, _art: Dictionary = {}) -> Dictionary:
		by_path[entry.path] = self
		return {"path": entry.path}

	func set_node_art(path: String, piece: Dictionary, frame := 0) -> void:
		if piece.is_empty(): return
		art.get_or_add(path, []).append([String(piece.get("file", "")), frame])

	func remove_node(path: String) -> void:
		for p: String in by_path.keys():
			if p == path or p.begins_with(path + "/"): by_path.erase(p)

	func rename_node(_path: String, _new_path: String) -> void:
		pass

	func move_node(_path: String, _stage_matrix: Array) -> void:
		pass

	func set_path_shown(_path: String, _shown: bool) -> void:
		pass

	func prefetch(_art: Dictionary) -> void:
		pass
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
	# Keeping the scheduler out of the tree must not shift the clock that drives the board's
	# animated clips (`GameBoard._portals`: the Cinema centre's film). Run the same round with
	# and without the detached scheduler and compare every art frame the board shows over 20
	# ticks.
	var detached := await _board_art(true)
	var attached := await _board_art(false)
	_expect(detached == attached,
		"board clips advance identically with the scheduler detached or in the tree")
	var recorded: Dictionary = JSON.parse_string(detached)
	var centre := ""
	for path: String in recorded:
		if path.contains("/@0#8/@0#1/@0#5"): centre = path
	var frames: Array = recorded.get(centre, [])
	_expect(frames.size() >= 2 and frames[0] != frames[-1],
		"the board's animated centre clip advanced over the stepped ticks")
	SwfScreen.frame_locked = false
	print("%s: %d capture focus checks" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)


## The board's art sequence for one round, with the scheduler detached (`frame_locked`) or
## in the tree. Both runs use the same practice round and step the host's `advance_time`, so
## the only difference is where the scheduler lives.
func _board_art(detached: bool) -> String:
	SwfScreen.frame_locked = detached
	var game := Game.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.start_session(true, 42)
	# The board itself runs frame-locked in both runs; only the scheduler attachment differs.
	SwfScreen.frame_locked = true
	var screen := BoardScreen.new()
	var layout: Dictionary = SwfScreen.layout_of(&"game")
	var board := GameBoard.new(screen, layout.board, &"cinema", &"")
	board.build(game.get_snapshot(), true, true)
	for index in 20:
		game.advance_time(1.0 / 35.0)
		board.update(game.get_snapshot())
	var out := JSON.stringify(screen.art, "", true)
	screen.queue_free()
	game.queue_free()
	await process_frame
	return out


func _expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr(label)

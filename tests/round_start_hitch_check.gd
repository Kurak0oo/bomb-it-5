extends SceneTree
## The owner's report (2026-11-24): "when entering games after the game menu, there is an
## instant stuck for a few seconds". The round used to prepare all of its art on the frame
## the map finished loading: it scanned ~2,200 files, pinned them in one loop and started
## ~2,200 WorkerThreadPool tasks there, which stalled the main thread for seconds at full
## window scale.
##
## This check starts a game the way the player does, from the main menu, and times every
## frame until the round's first tick. The art is now prepared behind the loading screen and
## resampled in batches. Budget: 100 ms. Measured on this Mac (2026-11-24), the old path's
## worst frame was 2,176 ms and it held ~600 ms frames for ten more; the fixed path's worst
## frame is 67 ms. A frame of 100 ms is the largest hitch a player does not read as a stop,
## and it leaves headroom over the 1/35 s original frame for this machine and a windowed
## (full-scale) run.
##
## It also asserts the round's first displayed tick draws every robot with its own clip art:
## the fix must not bring back the hidden/blank robot or the stale direction.

const GameActors = preload("res://scripts/ui/game_actors.gd")
const BUDGET_USEC := 100_000
const MAX_FRAMES := 600
var failures := 0
var checks := 0


func _initialize() -> void:
	# Real time and real resamples: the freeze is a main-thread stall at window scale.
	load("res://scripts/ui/swf_screen.gd").frame_locked = false
	_run.call_deferred()


func _run() -> void:
	if not FileAccess.file_exists("res://original/screens/game/actors/actors.json"):
		print("SKIP: round start hitch checks need the local actors pack")
		quit(0)
		return
	root.size = Vector2i(1280, 720)
	var app: Control = load("res://scenes/main.tscn").instantiate()
	app.save_path = "user://round-start-hitch-check-save.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(app.save_path))
	root.add_child(app)
	await process_frame
	await app.screen_opened()
	# The main menu, as PLAY opens it, then the player's START: `_start_level` builds the
	# gameplay screen, the map-loading screen, and the round starts under it.
	app.show_main_menu()
	await app.screen_opened()
	for idle in 10: await process_frame
	var before := Time.get_ticks_usec()
	app.start_session()
	var worst := 0
	var worst_at := 0
	var frames := 0
	var reached := false
	while frames < MAX_FRAMES:
		await process_frame
		var now := Time.get_ticks_usec()
		var gap := now - before
		before = now
		frames += 1
		if gap > worst:
			worst = gap
			worst_at = frames
		# The first tick the player sees: the map-loading screen has gone (`gameStartHandler`
		# destroys it), so the round is on screen with its robots (made at loading frame 56).
		if app.game != null and app.game.get_snapshot().tick >= 1 and not _loading_up(app):
			reached = true
			break
	_expect(reached, "the round reaches its first tick (menu -> game)")
	_expect(worst <= BUDGET_USEC, "no frame in the menu -> round transition exceeds %d ms (worst %.1f ms at frame %d)" % [BUDGET_USEC / 1000, worst / 1000.0, worst_at])
	_expect(app.current == &"playing", "the game is playing the level")
	if not reached or not is_instance_valid(app.game):
		_finish(app)
		return
	var swf: Node2D = app.screen.get_child(0)
	_expect(swf != null and swf.screen_name == &"game", "the round shows on the generated gameplay screen")
	var actors = swf.get_meta("actors") if swf != null and swf.has_meta("actors") else null
	_expect(actors != null, "the gameplay screen keeps its actor display")
	var snapshot: Dictionary = app.game.get_snapshot()
	_expect(not snapshot.actors.is_empty(), "the round has its robots")
	if actors != null:
		for id in snapshot.actors:
			var view: Dictionary = actors._robots.get(id, {})
			_expect(not view.is_empty() and not view.item.is_empty(), "robot %s is on the board" % id)
			if view.is_empty() or view.item.is_empty(): continue
			var path := String(view.item.path) + "/@0"
			var rec: Dictionary = swf._by_path_rec.get(path, {})
			_expect(rec.get("sprite") != null and rec.sprite.visible and rec.sprite.texture != null,
				"robot %s is visible with art on the round's first tick" % id)
			# The clip the round is on (a robot may already have turned while the loading
			# screen covered the round) and its own image: not a stale clip, and not blank
			# while a replacement resamples.
			_expect(not String(view.class).is_empty() and int(view.frame) >= 1,
				"robot %s shows a live clip on the first displayed tick" % id)
			var want: Dictionary = actors._robot_art(view)
			_expect(not want.is_empty(), "the pack has robot %s's first-tick art" % id)
			var shown := int(rec.get("shown_art", -1))
			if not want.is_empty() and rec.has("sprite") and rec.sprite.texture != null and shown >= 0 and shown < rec.art.size():
				_expect(String(rec.art[shown].get("file", "")).get_file() == String(want.get("file", "")).get_file(),
					"robot %s draws its own clip's image on the first tick" % id)
	_finish(app)


## The map-loading screen over the round (`App._loading_map`), while it is still up.
func _loading_up(app: Control) -> bool:
	for child in app.screen.get_children():
		if is_instance_valid(child) and not child.is_queued_for_deletion() and child.get("screen_name") == &"loading_map":
			return true
	return false


func _finish(app: Control) -> void:
	# Waits for in-flight resample batches (`App._exit_tree` -> `SwfScreen.finish_warming`).
	app.queue_free()
	await process_frame
	print("%s: %d round start hitch checks" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)


func _expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr(label)

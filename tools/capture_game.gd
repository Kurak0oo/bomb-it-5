extends SceneTree
## Desktop rendering fixture, invoked explicitly; not part of the gameplay flow.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.start_session(false, 42)
	game.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	if game.get_snapshot().get("paused", false):
		game.toggle_pause()
	for index in 120:
		game.advance_time(1.0 / 35.0)
	await _capture("match")
	game.toggle_pause()
	await _capture("pause")
	game.start_session(false, 42)
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	root.push_input(key, true)
	for index in 73: game.advance_time(1.0 / 35.0)
	await _capture("death")
	for index in 59: game.advance_time(1.0 / 35.0)
	await _capture("ending")
	for index in 105: game.advance_time(1.0 / 35.0)
	await _capture("results")
	for index in 2:
		game.retry_round()
		root.push_input(key, true)
		for tick in 237: game.advance_time(1.0 / 35.0)
	await _capture("game-over")
	game.start_session(false, 2)
	# Drive legal human commands through the existing producer seam, without changing round state.
	var driver = load("res://tools/desktop_player.gd").new(2)
	game.scheduler.set_controller(&"human", func(): return driver.command(game.get_snapshot(), &"human"))
	for index in 6405:
		game.advance_time(1.0 / 35.0)
		if game.get_snapshot().outcome != &"running": break
	assert(game.get_snapshot().outcome == &"won", "production match must reach legitimate elimination victory")
	await _capture("victory")
	quit(0)


func _capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://.scratch/game-captures")
	DirAccess.make_dir_recursive_absolute(path)
	var error := root.get_texture().get_image().save_png(path.path_join(name + ".png"))
	assert(error == OK)
	print("CAPTURE: ", name, " status=", error)

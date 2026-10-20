extends SceneTree
## Desktop window checks only. No physical-device cutout claim.
var checks := 0
var records: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_session(false, 42)
	game.set_process(false)
	for n in 120: game.advance_time(1.0 / 35.0)
	var folder := ProjectSettings.globalize_path("res://.scratch/presentation-layout")
	DirAccess.make_dir_recursive_absolute(folder)
	for size in [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1280, 800), Vector2i(1800, 720)]:
		root.size = size
		game.set_process(true)
		await process_frame
		await process_frame
		game.set_process(false)
		await RenderingServer.frame_post_draw
		var visible: Rect2 = game.get_viewport_rect()
		var content := Rect2(Vector2.ONE * 24, visible.size - Vector2.ONE * 48)
		var origin: Vector2 = game.global_position
		var stick := Rect2(origin + Vector2(53, 443), Vector2.ONE * 184)
		var action := Rect2(origin + Vector2(1047, 467), Vector2.ONE * 136)
		var board := Rect2(origin + Vector2(324, 76), Vector2(632, 560))
		assert(content.encloses(stick) and content.encloses(action), "controls need desktop edge clearance")
		assert(not board.intersects(stick) and not board.intersects(action), "controls cannot cover the arena")
		for button in game.buttons.values():
			assert(content.encloses(button.get_global_rect()), "buttons must stay in the desktop content region")
		assert(not game.touch_controls.enabled or game.get_snapshot().outcome == &"running")
		checks += 4
		var image := root.get_texture().get_image()
		var label := "%dx%d" % [size.x, size.y]
		assert(image.save_png(folder.path_join(label + ".png")) == OK)
		records.append({"window": label, "image_size": str(image.get_size()),
			"logical_viewport": str(visible), "game_origin": str(origin)})
		print("CAPTURE: desktop layout ", label)
	var file := FileAccess.open(folder.path_join("checks.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "desktop_only": true, "layouts": records}, "  "))
	print("PASS: %d desktop layout checks" % checks)
	quit(0)

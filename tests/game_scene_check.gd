extends SceneTree

var failures := 0
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# The round host; the main scene wraps it in the menu flow (see flow_scene_check.gd).
	var scene = load("res://scripts/game.gd").new()
	root.add_child(scene)
	await process_frame
	_expect(scene.has_method("get_snapshot"), "the round host exposes the live game")
	if scene.has_method("get_snapshot"):
		_expect(scene.get_snapshot().board.size() == 255, "practice loads the recorded full board")
		scene.set_process(false)
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.position = Vector2(145, 535)
		touch.pressed = true
		root.push_input(touch, true)
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = Vector2(200, 590)
		root.push_input(drag, true)
		scene.advance_time(1.0 / 35.0)
		var direction: Vector2 = scene.get_snapshot().commands[0].direction
		_expect(direction.x > 0.6 and direction.y > 0.6, "stick produces a normalized diagonal through the real command path")
		touch.pressed = false
		root.push_input(touch, true)
		for sector in [Vector2.RIGHT, Vector2(1, 1), Vector2.DOWN, Vector2(-1, 1),
			Vector2.LEFT, Vector2(-1, -1), Vector2.UP, Vector2(1, -1)]:
			touch.pressed = true
			root.push_input(touch, true)
			drag.position = touch.position + sector.normalized() * 100
			root.push_input(drag, true)
			scene.advance_time(1.0 / 35.0)
			_expect(scene.get_snapshot().commands[0].direction.is_equal_approx(sector.normalized()),
				"each stick sector requests its normal-speed direction")
			touch.pressed = false
			root.push_input(touch, true)
		touch.pressed = true
		root.push_input(touch, true)
		drag.position = touch.position + Vector2(9, 0)
		root.push_input(drag, true)
		scene.advance_time(1.0 / 35.0)
		_expect(scene.get_snapshot().commands[0].direction == Vector2.ZERO, "the stick central deadzone requests idle")
		touch.pressed = false
		root.push_input(touch, true)
		touch.position = Vector2(500, 300)
		touch.pressed = true
		root.push_input(touch, true)
		scene.advance_time(1.0 / 35.0)
		_expect(scene.get_snapshot().commands[0].direction == Vector2.ZERO and scene.get_snapshot().commands[0].bomb_events.is_empty(),
			"unrelated board touches do not create gameplay commands")
		touch.pressed = false
		root.push_input(touch, true)
		drag.position = Vector2(200, 590)
		scene.start_session(false, 42)
		for index in 20:
			scene.advance_time(1.0 / 35.0)
		_expect(scene.get_snapshot().actors[&"ruby"].position != Vector2(15, 1), "a match has active AI movement through the scheduler")
		var ai_bomb := false
		for index in 350:
			scene.advance_time(1.0 / 35.0)
			for bomb in scene.get_snapshot().bombs:
				ai_bomb = ai_bomb or bomb.actor_id != &"human"
		_expect(ai_bomb, "AI place ordinary bombs in a real match")
		scene.start_session(false, 42)
		var bomb_key := InputEventKey.new()
		bomb_key.keycode = KEY_SPACE
		bomb_key.pressed = true
		root.push_input(bomb_key, true)
		for index in 237:
			scene.advance_time(1.0 / 35.0)
		_expect(scene.get_snapshot().get("session", {}).get("lives", -1) == 2,
			"losing a match consumes one retry heart")
		var score_after: int = scene.get_snapshot().session.total_score
		for index in 20:
			scene.advance_time(1.0 / 35.0)
		_expect(scene.get_snapshot().session.lives == 2 and scene.get_snapshot().session.total_score == score_after,
			"completed results are settled once")
		for remaining in [1, 0]:
			scene.retry_round()
			root.push_input(bomb_key, true)
			for index in 237: scene.advance_time(1.0 / 35.0)
			_expect(scene.get_snapshot().session.lives == remaining, "retry carries remaining hearts across rounds")
		_expect(scene.get_snapshot().session.game_over, "losing the last heart enters game over")
		scene.retry_round()
		_expect(scene.get_snapshot().session.lives == 3 and scene.get_snapshot().session.total_score == 0, "new session clears exhausted lives and totals")
		scene.start_session(true, 42)
		var arrow := InputEventKey.new()
		arrow.keycode = KEY_RIGHT
		arrow.pressed = true
		root.push_input(arrow, true)
		scene.advance_time(1.0 / 35)
		arrow.keycode = KEY_UP
		root.push_input(arrow, true)
		scene.advance_time(1.0 / 35)
		_expect(scene.get_snapshot().commands[0].direction == Vector2.UP, "latest pressed held cardinal key wins")
		arrow.pressed = false
		root.push_input(arrow, true)
		scene.advance_time(1.0 / 35)
		_expect(scene.get_snapshot().commands[0].direction == Vector2.RIGHT, "releasing the latest key restores the older held direction")
		scene.toggle_pause()
		var paused_at: int = scene.get_snapshot().tick
		root.push_input(bomb_key, true)
		scene.advance_time(60)
		_expect(scene.get_snapshot().tick == paused_at, "scene pause prevents gameplay and catch-up debt")
		scene.toggle_pause()
		scene.advance_time(1.0 / 35)
		_expect(scene.get_snapshot().commands[0].direction == Vector2.ZERO and scene.get_snapshot().bombs.is_empty(), "resume requires fresh input and discards queued bombs")
		scene.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		scene.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
		_expect(scene.get_snapshot().paused, "focus return does not automatically resume the scene")
		scene.toggle_pause()
		scene.start_session(true, 42)
		touch.position = Vector2(145, 535)
		touch.pressed = true
		root.push_input(touch, true)
		root.push_input(drag, true)
		var action_touch := InputEventScreenTouch.new()
		action_touch.index = 1
		action_touch.position = Vector2(1115, 535)
		action_touch.pressed = true
		root.push_input(action_touch, true)
		scene.advance_time(1.0 / 35)
		_expect(scene.get_snapshot().commands[0].bomb_events == [&"down"] and scene.get_snapshot().commands[0].direction.length() > 0.99, "independent touches move and press bomb concurrently")
		scene.advance_time(1.0 / 35)
		_expect(scene.get_snapshot().commands[0].bomb_events.is_empty(), "held touch does not synthesize another bomb press")
		action_touch.pressed = false
		root.push_input(action_touch, true)
		scene.advance_time(1.0 / 35)
		_expect(scene.get_snapshot().commands[0].bomb_events == [&"up"], "touch release supplies one up event")
	scene.queue_free()
	await process_frame
	print("%s: %d game scene checks" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)


func _expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr(label)

extends SceneTree
## Input after a respawn (#respawn-input): the death window removes the movement listener
## (`AbstractRobot.kill` → `RobotController.robotStop` → `PersonInteractiveController.stopMoveListener`,
## `RobotController.clearMovStage`); relive adds it back with a moveStop `moveFunc`
## (`AbstractRobot.relive` → `RobotController.initStage`, `robotStart`). A key released while dead
## must not stay latched in the scene's held stage, or the respawn rearm never sees a stop and the
## player cannot move after returning.

const Session = preload("res://scripts/session.gd")
const Game = preload("res://scripts/game.gd")
const CARDINAL: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]

var failures := 0
var checks := 0
var game: Node2D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _respawn_moves_after_a_key_released_while_dead(&"kill", "Kill")
	await _respawn_moves_after_a_key_released_while_dead(&"green_zone", "Green Zone")
	await _arcade_life_starts_with_a_fresh_movement_stage()
	await _jump_starts_with_a_fresh_movement_stage()
	if failures == 0:
		print("PASS: %d respawn input checks" % checks)
	else:
		printerr("FAIL: %d of %d respawn input checks" % [failures, checks])
	quit(0 if failures == 0 else 1)


## Kill/Green Zone: die holding a direction, release it during the death window (the original
## has no key listener then), respawn 35 ticks later with 81 ticks of protection, then press a
## direction as a player would. The first press after respawn must move.
func _respawn_moves_after_a_key_released_while_dead(mode: StringName, label: String) -> void:
	await _start(mode)
	var spawn: Vector2i = game.get_snapshot().actors[&"human"].spawn
	var direction: Vector2 = _open_direction(spawn)
	var key := _key_for(direction)
	_key(key, true)
	for tick in 3:
		game.advance_time(1.0 / 35.0)
	_expect(game.get_snapshot().actors[&"human"].position != Vector2(spawn),
		"%s: the held direction moves the player before the death" % label)

	# `_hurt` is the shared damage path (`_deliver_blast_contact`): a plain death.
	var actor: Dictionary = game.simulation._actors[&"human"]
	actor.protected_until = 0
	actor.shield = 0
	game.simulation._hurt(&"human", &"")
	game.advance_time(1.0 / 35.0)
	_expect(not game.get_snapshot().actors[&"human"].alive, "%s: the human is dead" % label)

	# The player lets go while dead: the original listener is removed, and `clearMoveStage`
	# cleared the stage flags when it was, so nothing may stay latched here.
	_key(key, false)
	var deadline: int = game.get_snapshot().tick + 200
	while not game.get_snapshot().actors[&"human"].alive and game.get_snapshot().tick < deadline:
		game.advance_time(1.0 / 35.0)
	var back: Dictionary = game.get_snapshot()
	_expect(back.actors[&"human"].alive and back.actors[&"human"].cell == spawn,
		"%s: the player respawns at the spawn" % label)
	_expect(back.actors[&"human"].protected_until == back.tick + 81,
		"%s: InvincibilityCommand's 81 ticks of protection start at the respawn" % label)
	_expect(not back.actors[&"human"].movement_rearm,
		"%s: the respawn rearm clears instead of staying latched to the dead key" % label)

	_key(key, true)
	for tick in 8:
		game.advance_time(1.0 / 35.0)
	var after: Dictionary = game.get_snapshot()
	_expect(not after.actors[&"human"].movement_rearm,
		"%s: a fresh press after the respawn clears the rearm" % label)
	_expect(after.actors[&"human"].position != Vector2(spawn),
		"%s: the player moves after respawning" % label)
	game.queue_free()
	await process_frame


## Arcade has no in-round respawn: a death spends a retry heart and the next round starts at
## the spawn (`ArcadeMode.end`, `_start_round`). The new round must take the first press.
func _arcade_life_starts_with_a_fresh_movement_stage() -> void:
	await _start(&"arcade", 1)
	var spawn: Vector2i = game.get_snapshot().actors[&"human"].spawn
	var direction: Vector2 = _open_direction(spawn)
	var key := _key_for(direction)
	_key(key, true)
	for tick in 3:
		game.advance_time(1.0 / 35.0)
	_key(key, false)

	var actor: Dictionary = game.simulation._actors[&"human"]
	actor.protected_until = 0
	actor.shield = 0
	game.simulation._hurt(&"human", &"")
	var deadline: int = game.get_snapshot().tick + 300
	while game.get_snapshot().get("outcome", &"running") == &"running" and game.get_snapshot().tick < deadline:
		game.advance_time(1.0 / 35.0)
	_expect(game.get_snapshot().outcome != &"running", "Arcade: the death ends the round")
	game.retry_round()
	_expect(game.get_snapshot().actors[&"human"].alive, "Arcade: the retry starts a fresh round")
	var retry_spawn: Vector2i = game.get_snapshot().actors[&"human"].spawn
	var retry_direction: Vector2 = _open_direction(retry_spawn)
	var retry_key := _key_for(retry_direction)
	_key(retry_key, true)
	for tick in 8:
		game.advance_time(1.0 / 35.0)
	_expect(game.get_snapshot().actors[&"human"].position != Vector2(retry_spawn),
		"Arcade: the retry round moves on its first press")
	game.queue_free()
	await process_frame


## `HorseProp.frog`: when the frog jump starts, `robotMoveStop`/`robotBombStop` remove the
## movement and bomb listeners and `clearMoveStage` clears the held flags, so a key released
## during the jump must not stay latched: the landing must not walk on in the direction held
## when the jump started, and a fresh press after it must move.
func _jump_starts_with_a_fresh_movement_stage() -> void:
	game = Game.new()
	game.auto_start = false
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.start_session(true)
	var actor: Dictionary = game.simulation._actors[&"human"]
	actor.vehicle = &"horse"
	actor.drive_speed = 1.6
	actor.cell = Vector2i(2, 1)
	actor.position = Vector2(actor.cell)
	actor.velocity = Vector2.ZERO
	actor.movement_rearm = false
	# The practice map's row 1: a soft box ahead at (3, 1) and open floor to land on at (4, 1).
	var board: Dictionary = game.simulation._board
	board[Vector2i(3, 1)] = &"soft"
	for x in range(4, 8): board[Vector2i(x, 1)] = &"floor"
	game.state = game.simulation.snapshot()
	game.previous_state = {}
	var right := _key_for(Vector2.RIGHT)
	_key(right, true)
	var deadline: int = game.get_snapshot().tick + 60
	while game.get_snapshot().actors[&"human"].get("jump", {}).is_empty() and game.get_snapshot().tick < deadline:
		game.advance_time(1.0 / 35.0)
	_expect(not (game.get_snapshot().actors[&"human"].get("jump", {}) as Dictionary).is_empty(),
		"Jump: the horse's frog jump starts on the soft box")
	_expect(game.held.is_empty(), "Jump: starting the jump clears the held key")
	_expect(game.scheduler._directions[&"human"] == Vector2.ZERO,
		"Jump: starting the jump clears the scheduler's held direction")

	# The player lets go while the jump runs: `robotMoveStop` removed the listener then.
	_key(right, false)
	var landing_deadline: int = game.get_snapshot().tick + 60
	while not (game.get_snapshot().actors[&"human"].get("jump", {}) as Dictionary).is_empty() \
			and game.get_snapshot().tick < landing_deadline:
		game.advance_time(1.0 / 35.0)
	var landed: Vector2 = game.get_snapshot().actors[&"human"].position
	for tick in 8:
		game.advance_time(1.0 / 35.0)
	_expect(game.get_snapshot().actors[&"human"].position == landed,
		"Jump: no stale direction walks the robot on after landing")
	_key(right, true)
	for tick in 8:
		game.advance_time(1.0 / 35.0)
	_expect(game.get_snapshot().actors[&"human"].position != landed,
		"Jump: a fresh press after landing moves")
	game.queue_free()
	await process_frame


func _start(mode: StringName, enemies := 0) -> void:
	var session := Session.new(7)
	session.mode = mode
	session.enemies = enemies
	session.stage = &"cinema"
	session.begin()
	game = Game.new()
	game.auto_start = false
	game.session = session
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.play_level()


func _open_direction(cell: Vector2i) -> Vector2:
	var board: Dictionary = game.get_snapshot().board
	for step in CARDINAL:
		if board.get(cell + step) in [&"floor", &"belt", &"portal", &"crocodile"]:
			return Vector2(step)
	return Vector2.RIGHT


func _key_for(direction: Vector2) -> int:
	if direction.x > 0: return game.bindings[&"right"]
	if direction.x < 0: return game.bindings[&"left"]
	if direction.y > 0: return game.bindings[&"down"]
	return game.bindings[&"up"]


func _key(keycode: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	root.push_input(event, true)


func _expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr(label)

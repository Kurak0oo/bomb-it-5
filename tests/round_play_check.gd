extends SceneTree

const Simulation = preload("res://scripts/simulation/bomb_simulation.gd")
const Scheduler = preload("res://scripts/simulation/tick_scheduler.gd")
const AI = preload("res://scripts/simulation/ai_controller.gd")
var failures := 0
var checks := 0


func _initialize() -> void:
	var game := Simulation.new([&"human"], {&"human": {"cell": Vector2i(1, 1)}}, _board(), {"movement": true})
	var state: Dictionary = game.advance([_command(Vector2.RIGHT)])
	_expect(state.actors[&"human"].position.x > 1.0 and state.actors[&"human"].position.x < 1.1,
		"movement starts continuously within the cell")
	var corridor := _board()
	corridor[Vector2i(2, 2)] = &"solid"
	game = Simulation.new([&"human"], {&"human": {"cell": Vector2i(1, 1)}}, corridor, {"movement": true})
	for index in 4:
		state = game.advance([_command(Vector2.RIGHT)])
	var before: Vector2 = state.actors[&"human"].position
	state = game.advance([_command(Vector2.DOWN)])
	_expect(state.actors[&"human"].position.x < before.x, "turning into an open corridor spends movement aligning")
	game = Simulation.new([&"human"], {&"human": {"cell": Vector2i(1, 1)}}, _board(), {"damage": true})
	game.advance([_command(Vector2.ZERO, [&"down"])])
	for index in 72:
		state = game.advance([_command()])
	_expect(not state.actors[&"human"].get("alive", true), "an unprotected actor dies in its own explosion")
	var portals := _board()
	portals[Vector2i(2, 1)] = &"portal"
	portals[Vector2i(6, 5)] = &"portal"
	game = Simulation.new([&"human"], {&"human": {"cell": Vector2i(2, 1)}}, portals,
		{"movement": true, "portals": {Vector2i(2, 1): Vector2i(6, 5), Vector2i(6, 5): Vector2i(2, 1)}})
	for index in 31:
		state = game.advance([_command()])
	_expect(state.actors[&"human"].cell == Vector2i(6, 5), "portal transfer arrives after thirty following callbacks")
	game = Simulation.new([&"human", &"ai"], {&"human": {"cell": Vector2i(1, 1)}, &"ai": {"cell": Vector2i(7, 5)}}, _board(), {"round": true})
	for index in 6405:
		state = game.advance([_command(), {"actor_id": &"ai", "direction": Vector2.ZERO, "bomb_events": []}])
	_expect(state.get("outcome", &"running") == &"timeout", "6300 accepted ticks end a round with enemies in timeout defeat")
	game = Simulation.new([&"human"], {&"human": {"cell": Vector2i(1, 1)}}, _board(),
		{"drops": true, "pickups": {Vector2i(1, 1): &"capacity"}})
	state = game.advance([_command()])
	_expect(state.actors[&"human"].get("capacity", 1) == 2, "collecting a capacity pickup increases future bomb allowance")
	game = Simulation.new([&"human"], {&"human": {"cell": Vector2i(1, 1)}}, _board(),
		{"drops": true, "damage": true, "pickups": {Vector2i(1, 1): &"shield"}})
	game.advance([_command()])
	game.advance([_command(Vector2.ZERO, [&"down"])])
	for index in 72:
		state = game.advance([_command()])
	_expect(state.actors[&"human"].alive and state.actors[&"human"].shield == 0,
		"a collected one-use shield absorbs an explosion without in-round death")
	game = Simulation.new([&"human"], {&"human": {"cell": Vector2i(1, 1)}}, _board(),
		{"drops": true, "damage": true, "pickups": {Vector2i(1, 1): &"car"}})
	state = game.advance([_command()])
	_expect(state.actors[&"human"].get("vehicle", &"") == &"car", "a Cinema car pickup enters the riding state")
	game = Simulation.new([&"human"], {&"human": {"cell": Vector2i(1, 1)}}, _board(),
		{"drops": true, "pickups": {Vector2i(1, 1): &"landmine"}})
	game.advance([_command()])
	game.advance([_command(Vector2.ZERO, [&"down"])])
	for index in 100:
		state = game.advance([_command()])
	_expect(state.bombs.size() == 1, "an unarmed landmine waits for departure instead of using an ordinary fuse")
	var hammer_board := _board()
	hammer_board[Vector2i(2, 1)] = &"soft"
	game = Simulation.new([&"human"], {&"human": {"cell": Vector2i(1, 1)}}, hammer_board,
		{"drops": true, "movement": true, "pickups": {Vector2i(1, 1): &"hammer"}})
	game.advance([_command(Vector2.RIGHT)])
	game.advance([_command(Vector2.ZERO, [&"down"])])
	for index in 25:
		state = game.advance([_command()])
	_expect(state.board[Vector2i(2, 1)] == &"floor" and state.bombs.is_empty(), "a hammer breaks its adjacent soft block after the wind-up")
	hammer_board = _board()
	hammer_board[Vector2i(2, 1)] = &"soft"
	hammer_board[Vector2i(3, 1)] = &"soft"
	game = Simulation.new([&"human"], {&"human": {"cell": Vector2i(1, 1)}}, hammer_board,
		{"drops": true, "movement": true, "pickups": {Vector2i(1, 1): &"flamer"}})
	game.advance([_command(Vector2.RIGHT)])
	game.advance([_command(Vector2.ZERO, [&"down"])])
	for index in 25:
		state = game.advance([_command()])
	_expect(state.board[Vector2i(2, 1)] == &"floor" and state.board[Vector2i(3, 1)] == &"floor", "flamer animation burns successive soft blocks within its three-cell reach")
	game = Simulation.new([&"human", &"ai"], {&"human": {"cell": Vector2i(1, 1)}, &"ai": {"cell": Vector2i(5, 1)}}, _board(),
		{"drops": true, "movement": true, "damage": true, "pickups": {Vector2i(1, 1): &"laser"}})
	var idle_ai := {"actor_id": &"ai", "direction": Vector2.ZERO, "bomb_events": []}
	game.advance([_command(Vector2.RIGHT), idle_ai])
	game.advance([_command(Vector2.ZERO, [&"down"]), idle_ai])
	for index in 12:
		state = game.advance([_command(), idle_ai])
	_expect(not state.actors[&"ai"].alive and state.bombs.is_empty(), "the charged laser hits a distant actor without creating an ordinary bomb")
	game = Simulation.new([&"human"], {&"human": {"cell": Vector2i(1, 1)}}, _board(),
		{"drops": true, "movement": true, "pickups": {Vector2i(1, 1): &"triple"}})
	game.advance([_command(Vector2.RIGHT)])
	game.advance([_command(Vector2.ZERO, [&"down"])])
	for index in 16:
		state = game.advance([_command()])
	_expect(state.projectiles.size() == 2 and state.bombs.is_empty(), "triple-shot emits successive projectiles fifteen ticks apart")
	game = Simulation.new([&"human"], {&"human": {"cell": Vector2i(1, 1)}}, _board(),
		{"drops": true, "movement": true, "pickups": {Vector2i(1, 1): &"shotgun"}})
	game.advance([_command(Vector2.RIGHT)])
	game.advance([_command(Vector2.ZERO, [&"down"])])
	for index in 14:
		state = game.advance([_command()])
	_expect(state.projectiles.size() == 1 and state.bombs.is_empty(), "the fireball weapon launches one projectile after its fourteen-frame animation")
	var portal_block := _board()
	portal_block[Vector2i(2, 2)] = &"portal"
	game = Simulation.new([&"human"], {&"human": {"cell": Vector2i(2, 3), "power": 3}}, portal_block)
	game.advance([_command(Vector2.ZERO, [&"down"])])
	for index in 72:
		state = game.advance([_command()])
	_expect(Vector2i(2, 1) not in state.blasts[0].cells and Vector2i(2, 2) not in state.blasts[0].cells,
		"ordinary blast rays stop before a non-existing portal platform")
	game = Simulation.new([&"human", &"ai"], {&"human": {"cell": Vector2i(5, 1)}, &"ai": {"cell": Vector2i(1, 1)}}, _board(),
		{"drops": true, "movement": true, "damage": true, "pickups": {Vector2i(1, 1): &"laser"}})
	var scheduler := Scheduler.new([&"human", &"ai"], game)
	var brain := AI.new(42)
	scheduler.set_controller(&"ai", func(): return brain.command(game.snapshot(), &"ai"))
	for index in 20:
		scheduler.advance_time(1.0 / 35.0)
	state = game.snapshot()
	_expect(state.actors[&"ai"].ammo == 1, "AI uses the acquired laser against a visible distant actor")
	scheduler.free()
	_finish()


func _board() -> Dictionary:
	var board: Dictionary = {}
	for y in 7:
		for x in 9:
			board[Vector2i(x, y)] = &"solid" if x == 0 or y == 0 or x == 8 or y == 6 else &"floor"
	return board


func _command(direction: Vector2 = Vector2.ZERO, events: Array = []) -> Dictionary:
	return {"actor_id": &"human", "direction": direction, "bomb_events": events}


func _expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr(label)


func _finish() -> void:
	print("%s: %d round play checks" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)

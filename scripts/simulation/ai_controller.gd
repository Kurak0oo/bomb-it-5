extends RefCounted
## Source-grounded evade/get-item/free states; eight-direction routing is an adaptation.

const DIRECTIONS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN,
	Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]
var _rng := RandomNumberGenerator.new()
var _routes: Dictionary = {}
var _last_attack: Dictionary = {}


func _init(seed_value: int = 5) -> void:
	_rng.seed = seed_value


func command(state: Dictionary, id: StringName) -> Dictionary:
	var actor: Dictionary = state.actors[id]
	var output := {"direction": Vector2.ZERO, "bomb_events": []}
	if not actor.alive or actor.transit_until > 0 or actor.busy_until > state.tick or state.outcome != &"running":
		return output
	var roster: Array = state.actors.keys()
	var active: Array = roster.slice(1).filter(func(other):
		return state.actors[other].alive and state.actors[other].transit_until == 0 and state.actors[other].busy_until <= state.tick)
	# Stopped AI handlers leave the source rotation; path following still runs every tick.
	var thinking: bool = id == roster[0] or state.tick % maxi(1, active.size()) == active.find(id)
	var danger := _danger(state)
	if thinking and not danger.has(actor.cell) and actor.position.distance_to(Vector2(actor.cell)) < 0.16:
		var owned: int = state.bombs.filter(func(b): return b.actor_id == id and b.get("kind", &"bomb") != &"mine").size()
		var aim := _target_direction(state, actor, id)
		if (actor.weapon != &"" or owned < actor.capacity) and state.tick - _last_attack.get(id, -100) >= 6 and aim != Vector2.ZERO:
			if actor.weapon != &"":
				if actor.facing.dot(aim) < 0.99:
					output.direction = aim
					_routes.erase(id)
					return output
				output.bomb_events = [&"down", &"up"]
				_last_attack[id] = state.tick
				_routes.erase(id)
				return output
			var predicted: Dictionary = state.duplicate(true)
			predicted.bombs.append({"actor_id": id, "cell": actor.cell, "power": actor.power})
			var escape := _find_route(predicted, actor, _danger(predicted))
			if not escape.is_empty():
				_routes[id] = escape
				_last_attack[id] = state.tick
				output.bomb_events = [&"down", &"up"]
				danger = _danger(predicted)
	var route: Array = _routes.get(id, [])
	while not route.is_empty() and actor.position.distance_to(Vector2(route[0])) < 0.11:
		route.pop_front()
	if not route.is_empty():
		var next_burning: bool = route[0] in state.get("fire", []) and actor.protected_until <= state.tick
		# Escaping a blast lane can require threatened intermediate cells; keep following between brain turns.
		if actor.position.distance_to(Vector2(route[0])) > 2.0 or next_burning or (danger.has(route[0]) and not danger.has(actor.cell)):
			route.clear()
	if route.is_empty() and thinking:
		route = _find_route(state, actor, danger)
	_routes[id] = route
	if not route.is_empty():
		var delta: Vector2 = Vector2(route[0]) - actor.position
		output.direction = Vector2(signf(delta.x) if absf(delta.x) > 0.055 else 0.0,
			signf(delta.y) if absf(delta.y) > 0.055 else 0.0).normalized()
	return output


func _danger(state: Dictionary) -> Dictionary:
	var danger: Dictionary = {}
	for cell in state.get("fire", []):
		danger[cell] = true
	for bomb in state.bombs:
		if bomb.get("kind", &"bomb") == &"mine":
			continue
		danger[bomb.cell] = true
		for direction in DIRECTIONS.slice(0, 4):
			for distance in range(1, bomb.power + 1):
				var cell: Vector2i = bomb.cell + direction * distance
				if state.board.get(cell) != &"floor":
					break
				danger[cell] = true
	return danger


func _find_route(state: Dictionary, actor: Dictionary, danger: Dictionary) -> Array:
	var start: Vector2i = actor.cell
	var queue: Array[Vector2i] = [start]
	var previous: Dictionary = {start: start}
	var free: Array[Vector2i] = []
	var items: Array[Vector2i] = []
	var escaping: bool = danger.has(start)
	var goal := start
	var found := false
	var index := 0
	while index < queue.size():
		var cell: Vector2i = queue[index]
		index += 1
		if cell != start and not danger.has(cell):
			free.append(cell)
			if state.pickups.has(cell):
				items.append(cell)
			if escaping:
				goal = cell
				found = true
				break
		for direction in DIRECTIONS:
			var next: Vector2i = cell + direction
			if previous.has(next) or absi(next.x - start.x) > 6 or absi(next.y - start.y) > 6:
				continue
			if not _open(state, next) or (not escaping and danger.has(next)):
				continue
			if next in state.get("fire", []) and actor.protected_until <= state.tick:
				continue
			if direction.x != 0 and direction.y != 0:
				if not _open(state, cell + Vector2i(direction.x, 0)) or not _open(state, cell + Vector2i(0, direction.y)):
					continue
			previous[next] = cell
			queue.append(next)
	if not found:
		if not items.is_empty():
			goal = items[0]
		elif not free.is_empty():
			goal = free[_rng.randi_range(0, free.size() - 1)]
	var route: Array = []
	while goal != start:
		route.push_front(goal)
		goal = previous[goal]
	return route


func _open(state: Dictionary, cell: Vector2i) -> bool:
	return state.board.get(cell) in [&"floor", &"portal"] and not state.bombs.any(func(b): return b.cell == cell and b.get("kind", &"bomb") != &"mine")


func _target_direction(state: Dictionary, actor: Dictionary, id: StringName) -> Vector2:
	var box := Vector2.ZERO
	var enemy := Vector2.ZERO
	var reach: int = actor.power
	if actor.weapon != &"":
		reach = 1 if actor.weapon in [&"hammer", &"landmine"] else 3 if actor.weapon == &"flamer" else 17
	reach = mini(6, reach)
	for direction in DIRECTIONS.slice(0, 4):
		for distance in range(1, reach + 1):
			var cell: Vector2i = actor.cell + direction * distance
			if state.board.get(cell) == &"soft":
				box = Vector2(direction)
				break
			if state.board.get(cell) not in [&"floor", &"portal"]:
				break
			for other in state.actors:
				if other != id and state.actors[other].alive and state.actors[other].cell == cell:
					enemy = Vector2(direction)
	# Normal Arcade XML: StateAttack .6, StateBox .7, StateGetItem .8.
	if enemy != Vector2.ZERO and _rng.randf() < 0.6:
		return enemy
	if box != Vector2.ZERO and _rng.randf() < 0.7:
		return box
	return Vector2.ZERO

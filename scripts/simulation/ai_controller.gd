extends RefCounted
## Normal 010201 state/action responsibilities on the admitted simulation clock.
const Perception = preload("res://scripts/simulation/ai_perception.gd")
const Search = preload("res://scripts/simulation/ai_search.gd")
const CARDINAL := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const ORDER := [&"Attack", &"Evade", &"GetItem", &"Box", &"Free", &"Escape"]
const CHANCE := [0.6, 0.8, 0.8, 0.7, 0.8, 1.0]
var _rng := RandomNumberGenerator.new()
var _memory := {}
var _last_tick := -1
var _selected: StringName = &""
var _rotation := 0
var _draws: Array = []
var _draw_index := 0
var _node_costs := {}
var _previous_fire: Array = []


func _init(seed_value: int = 5, random_draws: Array = []) -> void:
	_rng.seed = seed_value
	_draws = random_draws.duplicate()


func command(state: Dictionary, id: StringName) -> Dictionary:
	var output := {"direction": Vector2.ZERO, "bomb_events": []}
	var actor: Dictionary = state.actors[id]
	if not actor.alive or state.outcome != &"running" or state.get("round_stage") in [&"ending", &"settled"]:
		_memory.erase(id)
		return output
	if not _memory.has(id):
		_memory[id] = {"state": &"Free", "default": true, "repeat": 0, "complete": true,
			"route": [], "target": actor.cell, "aim": actor.cell, "timer": 0,
			"pending": &"", "due": 0, "orientations": 0, "ready": false, "answer_elapsed": 0.0,
			"perception": {}, "path_cost": -1, "step_callbacks": 0, "escaping_bomb": false}
	var memory: Dictionary = _memory[id]
	if state.tick != _last_tick:
		_last_tick = state.tick
		for cell in _previous_fire:
			if cell not in state.fire: _node_costs[cell] = 30 if state.board.get(cell) == &"portal" else 1
		_previous_fire = state.fire.duplicate()
		var active: Array = state.actors.keys().slice(1).filter(func(other):
			var a: Dictionary = state.actors[other]
			return a.alive and a.transit_until == 0 and a.busy_until <= state.tick)
		_selected = active[_rotation % active.size()] if not active.is_empty() else &""
		_rotation = (_rotation + 1) % maxi(1, active.size())
	memory.perception = Perception.observe(state, id, _node_costs)
	_run_pending(state, id, memory, output)
	if not output.bomb_events.is_empty():
		output.observation = _observation(memory, false)
		return output
	if actor.transit_until > 0 or actor.busy_until > state.tick:
		memory.route = []
		memory.orientations = 0
		memory.complete = true
		output.observation = _observation(memory, false)
		return output
	if not memory.complete and state.tick >= memory.timer: _cancel(memory)
	if id == _selected:
		if memory.ready:
			if memory.complete: _choose(state, id, memory)
		else:
			# Source never resets this cached accumulator after its initial threshold.
			if memory.answer_elapsed > 20.0: memory.ready = true
			else: memory.answer_elapsed = state.tick * 1000.0 / 35.0
	_follow(state, id, memory, output)
	output.observation = _observation(memory, id == _selected)
	return output


func _observation(memory: Dictionary, thinking: bool) -> Dictionary:
	return {"state": memory.state, "default_instance": memory.default, "thinking": thinking,
		"complete": memory.complete, "route": memory.route.duplicate(), "target": memory.target,
		"path_cost": memory.path_cost, "pending": memory.pending,
		"perception": memory.perception.duplicate(true)}


func _choose(state: Dictionary, id: StringName, memory: Dictionary) -> void:
	var actor: Dictionary = state.actors[id]
	var perception: Dictionary = memory.perception
	var choice: StringName = &"Free"
	var target: Variant = null
	var aim: Variant = null
	var default_instance := true
	for index in ORDER.size():
		if _random() > CHANCE[index]: continue
		target = null
		aim = null
		var kind: StringName = ORDER[index]
		match kind:
			&"Attack", &"Box":
				if actor.get("bomb_count", 0) >= actor.capacity: continue
				var selected := _attack_position(state, actor, perception, perception.enemies if kind == &"Attack" else perception.boxes)
				if selected.is_empty(): continue
				target = selected.cell
				aim = selected.aim
				if actor.weapon == &"" and _escape_positions(state, target, actor.power, perception).is_empty(): continue
			&"Evade":
				if not _danger(perception, actor.cell, 40): continue
				target = _best(state, actor.cell, perception.free.duplicate(), perception.costs, 1500)
			&"GetItem": target = _item(state, actor.cell, perception)
			&"Free": target = _best(state, actor.cell, perception.free.duplicate(), perception.costs, 100)
			&"Escape":
				var invincible := _invincible_enemies(state, id)
				if not _danger(perception, actor.cell, 40) and invincible.is_empty(): continue
				var safe: Array = perception.free.filter(func(cell):
					return not invincible.any(func(other): return _manhattan(cell, other) <= 4))
				target = _best(state, actor.cell, safe, perception.costs, 1500)
		if target != null:
			choice = kind
			default_instance = false
			break
	if memory.state == choice and memory.default == default_instance:
		memory.repeat += 1
		if memory.repeat >= 2:
			memory.repeat = 0
			memory.default = true
			memory.state = &"Free"
			memory.complete = true
			return
	else:
		memory.state = choice
		memory.default = default_instance
	if target == null: return
	memory.target = target
	memory.aim = aim if aim != null else target
	memory.escaping_bomb = false
	_set_route(state, id, memory, target)


func _item(state: Dictionary, start: Vector2i, perception: Dictionary) -> Variant:
	var candidates: Array = perception.items
	for index in candidates.size():
		var cell: Vector2i = candidates[int(_random() * candidates.size())]
		var route: Dictionary = Search.find(state, start, cell, perception.costs)
		if route.cost != -1 and route.cost < 100: return cell
	return null


func _best(state: Dictionary, start: Vector2i, candidates: Array, costs: Dictionary, limit: int) -> Variant:
	var best: Variant = null
	var fallback: Variant = null
	var fallback_cost := -1
	while not candidates.is_empty():
		var index := int(_random() * candidates.size())
		var cell: Vector2i = candidates.pop_at(index)
		var found: Dictionary = Search.find(state, start, cell, costs)
		if found.cost == -1: continue
		if found.cost < limit:
			best = cell
			limit = found.cost
			if limit < 100: break
		elif fallback_cost == -1 or found.cost < fallback_cost:
			fallback_cost = found.cost
			fallback = cell
		else:
			fallback_cost = found.cost
			fallback = cell
	return best if best != null else fallback


func _attack_position(state: Dictionary, actor: Dictionary, perception: Dictionary, targets: Array) -> Dictionary:
	var best := {}
	var price := 1000
	var reach: int = actor.power if actor.weapon == &"" else 1 if actor.weapon in [&"landmine", &"hammer"] else 3 if actor.weapon == &"flamer" else 17
	for aim in targets:
		if CARDINAL.any(func(direction): return state.get("bomb_occupancy", state.bombs).any(func(b): return b.cell == aim + direction)):
			continue
		for direction in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
			for distance in range(1, reach + 1):
				var cell: Vector2i = aim + direction * distance
				if not Perception.is_empty(state, cell): break
				var path: Dictionary = Search.find(state, actor.cell, cell, perception.costs)
				if path.cost != -1 and path.cost < 500 and path.cost < price:
					best = {"cell": cell, "aim": aim}
					price = path.cost
					if price == -2: return best
	return best


func _escape_positions(state: Dictionary, start: Vector2i, power: int, perception: Dictionary) -> Array:
	var blast := {}
	for direction in CARDINAL:
		for distance in range(1, power + 1):
			var cell: Vector2i = start + direction * distance
			if state.board.get(cell) not in [&"floor", &"portal"]: break
			blast[cell] = true
	var visited := {start: true}
	var frontier: Array = [start]
	var safe: Array = []
	while safe.is_empty() and not frontier.is_empty():
		var next_layer: Array = []
		for cell in frontier:
			for direction in CARDINAL:
				var next: Vector2i = cell + direction
				if visited.has(next): continue
				visited[next] = true
				if not Perception.is_empty(state, next) or perception.danger.has(next): continue
				if not blast.has(next): safe.append(next)
				else: next_layer.append(next)
		frontier = next_layer
	return safe


func _set_route(state: Dictionary, id: StringName, memory: Dictionary, target: Vector2i) -> void:
	var found: Dictionary = Search.find(state, state.actors[id].cell, target, memory.perception.costs)
	memory.path_cost = found.cost
	if found.cost == -1:
		_cancel(memory)
		return
	memory.complete = false
	memory.timer = state.tick + 70
	if found.cost == -2:
		# Source same-cell setAction keeps stored route fields and schedules arrival separately.
		memory.pending = &"arrival"
		memory.due = state.tick + 4
	else:
		memory.route = found.path.slice(1)
		memory.orientations = 0
		memory.step_callbacks = 2


func _follow(state: Dictionary, id: StringName, memory: Dictionary, output: Dictionary) -> void:
	var actor: Dictionary = state.actors[id]
	var route: Array = memory.route
	if route.is_empty(): return
	while memory.step_callbacks > 0:
		memory.step_callbacks -= 1
		_on_step(state, id, memory, output)
		if memory.route.is_empty(): return
	var next: Vector2i = route[0]
	if actor.position.distance_to(Vector2(next)) < 0.16:
		route.pop_front()
		memory.orientations = 0
		if route.is_empty():
			_arrive(state, id, memory, output)
			return
		next = route[0]
		_on_step(state, id, memory, output)
		if memory.route.is_empty(): return
	else:
		memory.orientations += 1
		if memory.orientations > 10:
			_cancel(memory)
			return
	if not Perception.is_open(state, next):
		_cancel(memory)
		return
	var delta: Vector2 = Vector2(next) - actor.position
	output.direction = Vector2(signf(delta.x), 0) if absf(delta.x) > 0.16 else Vector2(0, signf(delta.y))


func _arrive(state: Dictionary, id: StringName, memory: Dictionary, output: Dictionary) -> void:
	if memory.state not in [&"Attack", &"Box"]:
		memory.complete = true
		return
	if state.actors[id].weapon == &"":
		output.bomb_events = [&"down", &"up"]
		memory.pending = &"escape"
		memory.due = state.tick + 11
	else:
		var aim: Vector2i = memory.aim
		if Perception.is_empty(state, aim) and not state.actors.values().any(func(a): return a.alive and a.cell == aim):
			_cancel(memory)
			return
		if state.get("bomb_occupancy", state.bombs).any(func(b): return b.cell == aim):
			_cancel(memory)
			return
		memory.pending = &"attack"
		memory.due = state.tick + 6


func _run_pending(state: Dictionary, id: StringName, memory: Dictionary, output: Dictionary) -> void:
	if memory.pending == &"" or state.tick < memory.due: return
	var pending: StringName = memory.pending
	memory.pending = &""
	match pending:
		&"arrival": _arrive(state, id, memory, output)
		&"attack":
			var delta: Vector2 = Vector2(memory.aim - state.actors[id].cell)
			output.direction = Vector2(signf(delta.x), 0) if delta.x != 0 else Vector2(0, signf(delta.y))
			output.bomb_events = [&"down", &"up"]
			memory.complete = true
		&"escape":
			var target: Variant = _best(state, state.actors[id].cell, memory.perception.free.duplicate(), memory.perception.costs, 1500)
			if target == null:
				memory.pending = &"escape"
				memory.due = state.tick + 11
			else:
				_set_route(state, id, memory, target)
				memory.escaping_bomb = true


func _on_step(state: Dictionary, id: StringName, memory: Dictionary, output: Dictionary) -> void:
	if memory.state == &"Evade": return
	var route: Array = memory.route
	if route.is_empty(): return
	var actor: Dictionary = state.actors[id]
	var next: Vector2i = route[0]
	var after: Vector2i = route[1] if route.size() > 1 else next
	if memory.escaping_bomb:
		if _danger(memory.perception, next, 30) or _danger(memory.perception, after, 30):
			memory.pending = &"escape"
			memory.due = state.tick + 11
		return
	var draw := _random()
	if draw < 0.8 and (_danger(memory.perception, actor.cell, 30) or _danger(memory.perception, next, 30) or _danger(memory.perception, after, 30)):
		_cancel(memory)
		return
	if draw < 0.6 and memory.state in [&"Attack", &"Box"]:
		var human: Dictionary = state.actors[state.actors.keys()[0]]
		var reach: int = actor.power if actor.weapon == &"" else 1 if actor.weapon in [&"landmine", &"hammer"] else 3 if actor.weapon == &"flamer" else 17
		var delta: Vector2i = human.cell - actor.cell
		if human.alive and human.protected_until <= state.tick and (delta.x == 0 or delta.y == 0) and _manhattan(human.cell, actor.cell) <= reach:
			var direction := Vector2i(signi(delta.x), signi(delta.y))
			for distance in range(_manhattan(human.cell, actor.cell)):
				if not Perception.is_open(state, actor.cell + direction * distance): return
			memory.aim = human.cell
			memory.route = []
			_arrive(state, id, memory, output)
	if memory.state == &"Escape":
		var invincible := _invincible_enemies(state, id)
		if invincible.is_empty() or route.any(func(cell): return cell in invincible): memory.complete = true


func _cancel(memory: Dictionary) -> void:
	memory.route = []
	memory.pending = &""
	memory.complete = true
	memory.orientations = 0


func _danger(perception: Dictionary, cell: Vector2i, threshold: int) -> bool:
	return perception.danger.has(cell) and perception.danger[cell] <= threshold


func _invincible_enemies(state: Dictionary, id: StringName) -> Array:
	var cells: Array = []
	for other in state.actors:
		if other != id and state.actors[other].alive and state.actors[other].invincible_until > state.tick:
			cells.append(state.actors[other].cell)
	return cells


func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _random() -> float:
	var value: float = _draws[_draw_index] if _draw_index < _draws.size() else _rng.randf()
	_draw_index += 1
	return clampf(value, 0.0, 0.9999999999999999)

extends RefCounted
## AIControl.updatePerceptions: ring order, shared ray flags and parser quirks.
const RAYS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.UP]


## `attack_all`: Kill and Green Zone target every robot (`allAttactRobot = AbstractRobot`);
## Arcade and Pac-Man target humans only.
static func observe(state: Dictionary, id: StringName, shared_costs: Dictionary = {}, find_range: int = 6, attack_all := false) -> Dictionary:
	var result := {"bombs": [], "items": [], "boxes": [], "enemies": [], "free": [], "danger": {}, "costs": shared_costs}
	var origin: Vector2i = state.actors[id].cell
	var visited := {}
	var rays := [true, true, true, true]
	for cell in state.board:
		if not result.costs.has(cell): result.costs[cell] = 30 if state.board[cell] == &"portal" else 1
		if cell in state.fire: result.costs[cell] = 1000
	for radius in range(1, find_range + 1):
		for dx in range(radius, -radius - 1, -1):
			for dy in range(radius, -radius - 1, -1):
				var cell := origin + Vector2i(dx, dy)
				if not state.board.has(cell) or visited.has(cell): continue
				visited[cell] = true
				if cell in state.fire:
					result.danger[cell] = 0
					continue
				for bomb in state.get("bomb_occupancy", state.bombs):
					if bomb.cell != cell: continue
					var age: int = mini(71, bomb.get("age", 0))
					var remaining: int = 0 if bomb.get("kind") == &"mine" else 70 - age
					result.bombs.append({"cell": cell, "remaining": remaining})
					result.danger[cell] = remaining
					result.costs[cell] = age * 10
					if bomb.get("kind") == &"mine": continue
					for distance in range(1, bomb.power + 1):
						for ray in 4:
							var target: Vector2i = cell + RAYS[ray] * distance
							if not rays[ray] or not state.board.has(target): continue
							if state.board[target] in [&"solid", &"soft"]:
								rays[ray] = false
							else:
								if ray != 3 or remaining < 30: result.danger[target] = remaining
								result.costs[target] = age * 10
								visited[target] = true
				if state.pickups.has(cell):
					if state.pickups[cell] not in [&"speed", &"landmine"]: result.items.append(cell)
				elif state.board[cell] == &"soft":
					result.boxes.append(cell)
				else:
					for target_id in (state.actors.keys() if attack_all else [state.actors.keys()[0]]):
						var target: Dictionary = state.actors[target_id]
						if target_id != id and target.alive and target.cell == cell and target.protected_until <= state.tick:
							result.enemies.append(cell)
							break
					if is_open(state, cell): result.free.append(cell)
	result.free = result.free.filter(func(cell): return not result.danger.has(cell))
	return result


static func is_open(state: Dictionary, cell: Vector2i) -> bool:
	return state.board.get(cell) in [&"floor", &"portal"] and not state.get("bomb_occupancy", state.bombs).any(func(b): return b.cell == cell)


static func is_empty(state: Dictionary, cell: Vector2i) -> bool:
	return state.board.get(cell) == &"floor" and is_open(state, cell)

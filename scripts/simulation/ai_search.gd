extends RefCounted
## RoadSearch: accumulated estimate prices, cardinal insertion order, strict ties.
const Perception = preload("res://scripts/simulation/ai_perception.gd")
const DIRECTIONS := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]


static func find(state: Dictionary, start: Vector2i, goal: Vector2i, costs: Dictionary) -> Dictionary:
	if start == goal: return {"cost": -2, "path": [start]}
	var waiting: Array[Vector2i] = [start]
	var nodes := {start: {"parent": start, "estimate": 0, "length": 0}}
	var checked := {}
	while not waiting.is_empty():
		var current: Vector2i = waiting[0]
		for cell in waiting:
			if nodes[cell].estimate < nodes[current].estimate: current = cell
		waiting.erase(current)
		checked[current] = true
		for direction in DIRECTIONS:
			var next: Vector2i = current + direction
			if checked.has(next) or not Perception.is_open(state, next): continue
			if next == goal:
				nodes[next] = {"parent": current, "estimate": 0, "length": 0}
				var path: Array[Vector2i] = [next]
				var cost := 0
				while next != start:
					cost += nodes[next].estimate
					next = nodes[next].parent
					path.push_front(next)
				return {"cost": cost, "path": path}
			var estimate: int = (nodes[current].length + absi(next.x - goal.x) + absi(next.y - goal.y)) * costs.get(next, 1)
			if not nodes.has(next) or estimate < nodes[next].estimate:
				nodes[next] = {"parent": current, "estimate": estimate, "length": nodes[current].length + 1}
				if not next in waiting: waiting.append(next)
	return {"cost": -1, "path": []}

extends RefCounted
## Magic Library spellbook on the 3x3 center block (`Spellbook.as`); see edition-5-magic-library.md.
## Closed for 450 ticks, then a 69-frame flip: targets are marked on frame 2 and items
## drop on frame 32.

const FLIP_DELAY := 450
const FLIP_FRAMES := 69
const SIGN_FRAME := 2
const DROP_FRAME := 32
const EMPTY_NUM := 10
const ITEM_COUNT := 2
## `[pickup, bomb, nothing]` by difficulty; other modes always drop a pickup.
const PROBS := {&"easy": [0.5, 0.5, 0.0], &"normal": [0.4, 0.6, 0.0], &"hard": [0.3, 0.7, 0.0]}
const POWER := {&"easy": 1, &"normal": 2, &"hard": 3}

var cell: Vector2i
var flipping := false
var current_frame := 0
var flip_frame := 0
var targets: Array[Dictionary] = []
var probs: Array = []
var power := 2


func _init(at: Vector2i, mode: RefCounted) -> void:
	cell = at
	probs = PROBS.get(mode.difficulty, PROBS[&"normal"]) if mode.name == &"arcade" else [1.0, 0.0, 0.0]
	power = POWER.get(mode.difficulty, 2)


func advance(round_state: RefCounted, _inputs: Dictionary) -> void:
	if not flipping:
		current_frame += 1
		if current_frame >= FLIP_DELAY:
			current_frame = 0
			flipping = true
			flip_frame = 1
			round_state.play_sound(&"spellOpen")
		return
	flip_frame += 1
	if flip_frame == SIGN_FRAME: _choose(round_state)
	elif flip_frame == DROP_FRAME: _drop(round_state)
	elif flip_frame >= FLIP_FRAMES:
		flipping = false
		targets.clear()


## Two cells from different quadrants (split at x 8, y 7), not touching each other.
func _choose(round_state: RefCounted) -> void:
	targets.clear()
	var empty: Array[Vector2i] = round_state.empty_cells()
	if empty.size() < EMPTY_NUM: return
	var quadrants: Array = [[], [], [], []]
	for at in empty:
		quadrants[(0 if at.y < 7 else 3) if at.x < 8 else (1 if at.y < 7 else 2)].append(at)
	quadrants = quadrants.filter(func(q): return not q.is_empty())
	while targets.size() < ITEM_COUNT and not quadrants.is_empty():
		var quadrant: Array = quadrants.pop_at(int(round_state.draw_random() * quadrants.size()))
		while not quadrant.is_empty():
			var at: Vector2i = quadrant.pop_at(int(round_state.draw_random() * quadrant.size()))
			if targets.any(func(t): return absi(t.cell.x - at.x) <= 1 and absi(t.cell.y - at.y) <= 1): continue
			var draw: float = round_state.draw_random()
			var kind: StringName = &"pickup" if draw < probs[0] else &"bomb" if draw < probs[0] + probs[1] else &""
			if kind != &"": targets.append({"cell": at, "kind": kind})
			break


## A robot on a target cell cancels that item; a pickup replaces any prop there.
func _drop(round_state: RefCounted) -> void:
	for target in targets:
		var at: Vector2i = target.cell
		if round_state.actors().values().any(func(a): return a.alive and a.cell == at): continue
		if target.kind == &"pickup":
			round_state.pickups()[at] = round_state.random_pool_kind()
		else:
			round_state.add_bomb({"actor_id": &"", "cell": at, "power": power})


func blocked_cells() -> Array[Vector2i]:
	return []


func public_state() -> Dictionary:
	return {"kind": &"spellbook", "cell": cell, "flipping": flipping, "frame": flip_frame,
		"signs": targets.duplicate(true) if flipping and flip_frame < DROP_FRAME else []}

extends RefCounted
## Explosion lab: presentation-only ordering of one tick's blasts.
##
## The simulation resolves a whole chain inside one tick (`BombSimulation._detonate`,
## the port of `Bomb.blast`: rays grow ring by ring and a ray that reaches a bomb stops
## and detonates it inline). Gameplay hit cells are never delayed; this file only works
## out *when the player sees* each cell, so a chain reads as a travelling wave.

const KIND_CENTER := 0.0
const KIND_ARM := 0.5
const KIND_TIP := 1.0


## Chain depth per blast: 0 for a bomb whose own fuse ran out, n + 1 for a bomb set off
## by a depth-n blast. `is_root[i]` says whether blast i expired on its own fuse.
static func depths(blasts: Array, is_root: Array) -> Array[int]:
	var result: Array[int] = []
	result.resize(blasts.size())
	result.fill(-1)
	var queue: Array[int] = []
	for index in blasts.size():
		if is_root[index]:
			result[index] = 0
			queue.append(index)
	var head := 0
	while head < queue.size():
		var parent: int = queue[head]
		head += 1
		for child in blasts.size():
			if result[child] == -1 and touches(blasts[parent], blasts[child]):
				result[child] = result[parent] + 1
				queue.append(child)
	for index in result.size():
		if result[index] == -1:
			result[index] = 0
	return result


## Seconds after the gameplay hit at which each blast shows. A bomb goes off one
## `chain_step` after the blast whose ray stopped on it, as with `depths`. The
## simulation also lets a later ray run through a cell whose bomb an earlier branch of
## the chain already set off; on screen that bomb must go off no later than the moment
## that flame reaches it (`ring_step` per cell), or the flame would cross a bomb that
## still looks unexploded.
static func starts(blasts: Array, is_root: Array, chain_step: float, ring_step: float) -> Array[float]:
	var result: Array[float] = []
	result.resize(blasts.size())
	result.fill(INF)
	for index in blasts.size():
		if is_root[index]:
			result[index] = 0.0
	var changed := true
	while changed:
		changed = false
		for parent in blasts.size():
			if result[parent] == INF:
				continue
			for child in blasts.size():
				var step := INF
				if touches(blasts[parent], blasts[child]):
					step = chain_step
				elif child != parent and blasts[parent].cells.has(blasts[child].cell):
					var offset: Vector2i = blasts[child].cell - blasts[parent].cell
					step = (absi(offset.x) + absi(offset.y)) * ring_step
				if result[parent] + step < result[child] - 0.00001:
					result[child] = result[parent] + step
					changed = true
	for index in result.size():
		if result[index] == INF:
			result[index] = 0.0
	return result


## True when blast `a`'s ray stopped on the cell where blast `b`'s bomb sat: the cell
## just past `a`'s last flame cell in that direction (`_detonate` leaves the bomb cell
## out of the parent's cells). A ray that ended on power alone can look the same; the
## lab accepts that, since it only changes a visual delay.
static func touches(a: Dictionary, b: Dictionary) -> bool:
	var origin: Vector2i = a.cell
	var offset: Vector2i = b.cell - origin
	if offset == Vector2i.ZERO or (offset.x != 0 and offset.y != 0):
		return false
	var direction := Vector2i(signi(offset.x), signi(offset.y))
	var extent := 0
	while a.cells.has(origin + direction * (extent + 1)):
		extent += 1
	return b.cell == origin + direction * (extent + 1)


## Each flame cell of a blast with its sprite kind, outward direction and ring distance.
static func segments(blast: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var origin: Vector2i = blast.cell
	for cell: Vector2i in blast.cells:
		var offset: Vector2i = cell - origin
		if offset == Vector2i.ZERO:
			result.append({"cell": cell, "kind": KIND_CENTER, "direction": Vector2i.ZERO, "distance": 0})
			continue
		var direction := Vector2i(signi(offset.x), signi(offset.y))
		var tip: bool = not blast.cells.has(cell + direction)
		result.append({"cell": cell, "kind": KIND_TIP if tip else KIND_ARM,
			"direction": direction, "distance": absi(offset.x) + absi(offset.y)})
	return result


## Longest ray of a blast in cells (at least 1), used to size glow, light and shockwave.
static func reach(blast: Dictionary) -> int:
	var longest := 1
	for cell: Vector2i in blast.cells:
		var offset: Vector2i = cell - blast.cell
		longest = maxi(longest, absi(offset.x) + absi(offset.y))
	return longest


## Seconds after the gameplay hit at which a flame cell appears on screen.
static func delay(depth: int, distance: int, chain_step: float, ring_step: float) -> float:
	return depth * chain_step + distance * ring_step

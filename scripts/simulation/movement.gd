extends RefCounted
## Continuous full-cell footprint in cell units; source uses 30 units per cell.



static func step(actor: Dictionary, direction: Vector2, board: Dictionary, bombs: Array) -> void:
	# Single-cardinal producers (keyboard, original AI) send cardinal requests; the stick may
	# send diagonals, which use the accepted eight-direction rules (decision E).
	direction = direction.normalized()
	if direction == Vector2.ZERO:
		actor.velocity *= 0.6
		return
	actor.facing = direction
	if direction.x == 0:
		actor.velocity.x = 0.0
	if direction.y == 0:
		actor.velocity.y = 0.0
	var acceleration: float = actor.drive_speed if actor.get("vehicle", &"") != &"" else actor.get("speed", 1.6)
	actor.velocity = actor.velocity * 0.6 + direction * acceleration / 30.0
	var distance: Vector2 = actor.velocity
	if (direction.x == 0 or direction.y == 0) and not can_stand(actor.position + distance, actor, board, bombs):
		var center: Vector2 = actor.position
		if direction.x == 0:
			center.x = roundf(center.x)
		else:
			center.y = roundf(center.y)
		var correction := (center - Vector2(actor.position)).limit_length(distance.length())
		if can_stand(center + direction * 0.02, actor, board, bombs) and can_stand(actor.position + correction, actor, board, bombs):
			actor.position += correction
			distance = distance.normalized() * maxf(0.0, distance.length() - correction.length())
	var count := maxi(1, ceili(distance.length() / 0.02))
	for index in count:
		var part := distance / count
		for axis in [Vector2(part.x, 0), Vector2(0, part.y)]:
			if can_stand(actor.position + axis, actor, board, bombs):
				actor.position += axis
	for cell in actor.departures.duplicate():
		if not overlaps(actor.position, cell):
			actor.departures.erase(cell)


static func overlaps(position_at: Vector2, cell: Vector2i) -> bool:
	return absf(position_at.x - cell.x) < 0.99999 and absf(position_at.y - cell.y) < 0.99999


static func can_stand(position_at: Vector2, actor: Dictionary, board: Dictionary, bombs: Array) -> bool:
	for y in range(floori(position_at.y + 0.00001), floori(position_at.y + 0.99999) + 1):
		for x in range(floori(position_at.x + 0.00001), floori(position_at.x + 0.99999) + 1):
			if board.get(Vector2i(x, y)) not in [&"floor", &"portal", &"belt", &"crocodile"]:
				return false
	for bomb in bombs:
		if bomb.get("kind", &"bomb") != &"mine" and bomb.cell not in actor.departures and overlaps(position_at, bomb.cell):
			return false
	return true


## Edition 5 `HitMove` (#82) for one cardinal step under the `original` profile, ported from
## `RobotModel.moveLeft/…/moveStop`, `RobotController.moveLeft/…` and `HitMove.*Afoul`. Units
## are the original 30-pixel cells; every position write is truncated to twips because
## `AbstractObject.xPos` lives on the display container (`_container.x`, board offset 183,40).
## `actor.cell` is the registration from before the step (`view.xN`), as the source reads it.
## Not ported: `game.hitArr` (moving Tractor objects; none in a selectable stage) and the
## `transSpeed` platform term, which is zero for robots off moving platforms.
const GRID := 30.0
const STAGE_OFFSET := Vector2(183, 40)
const RESISTANCE := 0.6


static func step_hit_move(actor: Dictionary, direction: Vector2, board: Dictionary, bombs: Array) -> void:
	var push: float = actor.drive_speed if actor.get("vehicle", &"") != &"" else actor.get("speed", 1.6)
	var speed: Vector2 = actor.velocity * GRID
	if direction == Vector2.ZERO:
		# `moveStop`: the speed decays, nothing moves.
		actor.velocity = speed * RESISTANCE / GRID
		return
	actor.facing = direction
	var at: Vector2 = actor.position * GRID
	var cell: Vector2i = actor.cell
	if direction.x != 0:
		speed = Vector2(RESISTANCE * speed.x + signf(direction.x) * push, 0)
		if (direction.x < 0 and cell.x > 0) or (direction.x > 0 and cell.x < 16):
			at = _afoul(at, 0, direction.x > 0, speed.x, board, bombs)
	else:
		speed = Vector2(0, RESISTANCE * speed.y + signf(direction.y) * push)
		if (direction.y < 0 and cell.y > 0) or (direction.y > 0 and cell.y < 14):
			at = _afoul(at, 1, direction.y > 0, speed.y, board, bombs)
	actor.position = at / GRID
	actor.velocity = speed / GRID
	for departed in actor.departures.duplicate():
		if not overlaps(actor.position, departed): actor.departures.erase(departed)


## `leftAfoul` / `rightAfoul` (axis 0) and `upAfoul` / `downAfoul` (axis 1). `forward` is right
## or down, chosen by the pressed key; `speed` keeps its sign, so a reversal can still move back.
static func _afoul(at: Vector2, axis: int, forward: bool, speed: float, board: Dictionary, bombs: Array) -> Vector2:
	var across := 1 - axis
	var lead := floori((at[axis] + (GRID if forward else 0.0) + speed) / GRID)
	var middle := floori((at[axis] + GRID / 2) / GRID)
	var low := floori(at[across] / GRID)
	var high := floori((at[across] + GRID - 1) / GRID)
	var centre := floori((at[across] + GRID / 2) / GRID)
	var target := func(along: int, side: int) -> Vector2i: return Vector2i(along, side) if axis == 0 else Vector2i(side, along)
	if lead == middle:
		return _twips(at, axis, at[axis] + speed)
	if _passable(target.call(lead, centre), board, bombs):
		if low == centre:
			if high == centre or _passable(target.call(lead, high), board, bombs) or fposmod(at[across] + GRID, GRID) == 0:
				return _twips(at, axis, at[axis] + speed)
			# Lane assistance: slide back towards the centre row.
			var distance := at[across] + GRID - high * GRID
			return _twips(at, across, at[across] - (absf(speed) if distance > absf(speed) else distance))
		if _passable(target.call(lead, low), board, bombs) or fposmod(at[across], GRID) == 0:
			return _twips(at, axis, at[axis] + speed)
		var distance := centre * GRID - at[across]
		return _twips(at, across, at[across] + (absf(speed) if distance > absf(speed) else distance))
	var blocker: Vector2i = target.call(lead, centre)
	if blocker.x < 0 or blocker.y < 0 or blocker.x > 16 or blocker.y > 14 or not _occupied(blocker, board, bombs):
		return at
	# A box or bomb ahead: move up to its edge, or not at all once touching (`hasHit`).
	var edge := lead * GRID
	if not forward:
		if edge + GRID < at[axis]:
			return _twips(at, axis, at[axis] + (speed if edge + GRID - at[axis] <= speed else edge + GRID - at[axis]))
	elif at[axis] + GRID < edge:
		return _twips(at, axis, at[axis] + (speed if edge - (at[axis] + GRID) >= speed else edge - (at[axis] + GRID)))
	return at


## `fixedHitTest`: false for boxes (visible or hidden), ordinary bombs and the blocking
## platform classes; true for landmines, open floor and every other platform.
static func _passable(cell: Vector2i, board: Dictionary, bombs: Array) -> bool:
	if board.get(cell) in [&"solid", &"soft"]: return false
	for bomb in bombs:
		if bomb.cell == cell and not bomb.has("fly_position"): return bomb.get("kind", &"bomb") == &"mine"
	return true


## `Map.isEmpty` is false where a box, bomb, platform or tramcar is registered.
static func _occupied(cell: Vector2i, board: Dictionary, bombs: Array) -> bool:
	return board.get(cell, &"floor") != &"floor" or bombs.any(func(bomb): return bomb.cell == cell and not bomb.has("fly_position"))


## Flash stores display positions in whole twips (1/20 px), truncating the assigned value.
static func _twips(at: Vector2, axis: int, value: float) -> Vector2:
	var offset := STAGE_OFFSET[axis]
	# Vector2 is single precision: snap its noise (well under a hundredth of a twip) away first.
	at[axis] = floorf(snappedf((value + offset) * 20.0, 0.01)) / 20.0 - offset
	return at

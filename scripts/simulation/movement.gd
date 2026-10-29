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

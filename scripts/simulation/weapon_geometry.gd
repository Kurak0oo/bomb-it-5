extends RefCounted
## Numeric gameplay metadata, not copied art. See the weapon interaction evidence.
## Native Script bounds for the 22 independently observed inner flamer frames.
const FLAME_LENGTH := [7.4, 17.65, 26.75, 29.9, 33.35, 42.8, 46.6, 50.15,
	52.85, 54.75, 56.45, 58.35, 60.2, 67.2, 67.55, 73.45, 79.35, 85.2,
	86.5, 87.8, 89.5, 91.85]
const FLAMER_MUZZLE := {Vector2i.UP: Vector2(14.8, 10.1), Vector2i.DOWN: Vector2(6.75, 11.5),
	Vector2i.LEFT: Vector2(9.65, 13.2), Vector2i.RIGHT: Vector2(24.65, 10.2)}
const HAMMER_OFFSET := {Vector2i.LEFT: Vector2(10, -15), Vector2i.RIGHT: Vector2(-10, -15),
	Vector2i.UP: Vector2(15, -15), Vector2i.DOWN: Vector2.ZERO}


static func flamer_endpoint(attack: Dictionary, actor: Dictionary, board: Dictionary) -> Vector2i:
	var direction: Vector2i = attack.direction
	# Terminal callback retains the last measured cell extent; terminal outline is unverified.
	var length: float = FLAME_LENGTH[clampi(attack.frame - 1, 0, FLAME_LENGTH.size() - 1)]
	var origin: Vector2 = Vector2(actor.cell)
	var tip: Vector2 = origin + Vector2(direction) * length * attack.get("scale", 1.0) / 30.0
	var endpoint := Vector2i(int(tip.x), int(tip.y))
	if board.get(endpoint) == &"solid":
		var muzzle: Vector2 = actor.position + FLAMER_MUZZLE[direction] / 30.0
		var edge := Vector2(endpoint)
		if direction.x < 0: edge.x += 1
		if direction.y < 0: edge.y += 1
		attack.scale = absf((edge.x - muzzle.x) if direction.x != 0 else (edge.y - muzzle.y)) / 3.0
		tip = origin + Vector2(direction) * length * attack.scale / 30.0
		endpoint = Vector2i(int(tip.x), int(tip.y))
	return endpoint

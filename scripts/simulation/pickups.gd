extends RefCounted
## Arcade XML integer weights (round(value*100)); reserved glove candidates stay empty.

const WEIGHTS := {&"capacity": 28, &"power": 24, &"speed": 22, &"life": 1, &"shield": 1,
	&"reserved_kick": 10, &"invincible": 1, &"reserved_boxing": 1, &"landmine": 1,
	&"flamer": 1, &"laser": 1, &"hammer": 1, &"triple": 1, &"shotgun": 1, &"vehicle": 3}


static func build_pool(draw: Callable, weights: Dictionary = WEIGHTS) -> Array[StringName]:
	var pool: Array[StringName] = []
	for kind in weights:
		for index in weights[kind]:
			pool.append((&"moto" if draw.call() < 0.5 else &"car") if kind == &"vehicle" else kind)
	return pool


static func apply(actor: Dictionary, kind: StringName, tick: int) -> void:
	match kind:
		&"capacity": actor.capacity = mini(9, actor.capacity + 1)
		&"power": actor.power = mini(5, actor.power + 1)
		&"speed": actor.speed = minf(2.3, actor.speed + 0.1)
		&"life":
			if actor.get("is_human", false): actor.lives += 1
		&"shield": actor.shield = 1
		&"invincible":
			actor.invincible_active_from = tick + 29
			actor.invincible_until = tick + 29 + 351
			actor.protected_until = actor.invincible_until
			actor.protection_stage = &"introduction"
		&"car", &"moto":
			actor.vehicle = kind
			actor.drive_speed = 1.6 * (1.6 if kind == &"car" else 1.3)
		&"landmine":
			actor.weapon = kind
			actor.ammo = 1
		&"hammer", &"flamer", &"laser", &"triple", &"shotgun":
			actor.weapon = kind
			actor.ammo = 2
	if kind != &"invincible": actor.score += 100

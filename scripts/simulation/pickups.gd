extends RefCounted
## Arcade XML integer weights (round(value*100)); reserved glove candidates stay empty.

const WEIGHTS := {&"capacity": 28, &"power": 24, &"speed": 22, &"life": 1, &"shield": 1,
	&"reserved_kick": 10, &"invincible": 1, &"reserved_boxing": 1, &"landmine": 1,
	&"flamer": 1, &"laser": 1, &"hammer": 1, &"triple": 1, &"shotgun": 1, &"vehicle": 3}


static func choose(rng: RandomNumberGenerator, vehicles: int) -> StringName:
	var total := 0
	for kind in WEIGHTS:
		if kind != &"vehicle" or vehicles > 0:
			total += WEIGHTS[kind]
	var draw := rng.randi_range(0, total - 1)
	for kind in WEIGHTS:
		if kind == &"vehicle" and vehicles <= 0:
			continue
		draw -= WEIGHTS[kind]
		if draw < 0:
			if kind in [&"reserved_kick", &"reserved_boxing"]:
				return &""
			return kind
	return &""


static func apply(actor: Dictionary, kind: StringName, tick: int) -> void:
	match kind:
		&"capacity": actor.capacity = mini(9, actor.capacity + 1)
		&"power": actor.power = mini(5, actor.power + 1)
		&"speed": actor.speed = minf(2.3, actor.speed + 0.1)
		&"life": actor.lives += 1
		&"shield": actor.shield = 1
		&"invincible":
			actor.invincible_active_from = tick + 29
			actor.invincible_until = tick + 29 + 352
			actor.protected_until = actor.invincible_until
		&"car", &"moto":
			actor.vehicle = kind
			actor.drive_speed = 1.6 * (1.6 if kind == &"car" else 1.3)
		&"landmine":
			actor.weapon = kind
			actor.ammo = 1
		&"hammer", &"flamer", &"laser", &"triple", &"shotgun":
			actor.weapon = kind
			actor.ammo = 2
	actor.score += 100

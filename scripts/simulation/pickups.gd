extends RefCounted
## Arcade XML integer weights (round(value*100)); reserved glove candidates stay empty.

const WEIGHTS := {&"capacity": 28, &"power": 24, &"speed": 22, &"life": 1, &"shield": 1,
	&"reserved_kick": 10, &"invincible": 1, &"reserved_boxing": 1, &"landmine": 1,
	&"flamer": 1, &"laser": 1, &"hammer": 1, &"triple": 1, &"shotgun": 1, &"vehicle": 3}


const VEHICLES: Array[StringName] = [&"car", &"moto", &"horse", &"dragon"]


## Each vehicle entry draws its class from the stage set's list, even a one-item list
## (`AbstractGameMode.initMap`).
static func build_pool(draw: Callable, weights: Dictionary = WEIGHTS, vehicles: Array = [&"moto", &"car"]) -> Array[StringName]:
	var pool: Array[StringName] = []
	for kind in weights:
		for index in weights[kind]:
			pool.append(vehicles[int(draw.call() * vehicles.size())] if kind == &"vehicle" else kind)
	return pool


static func apply(actor: Dictionary, kind: StringName, tick: int, invincible_ticks := 351) -> void:
	match kind:
		&"capacity": actor.capacity = mini(9, actor.capacity + 1)
		&"power": actor.power = mini(5, actor.power + 1)
		&"speed": actor.speed = minf(2.3, actor.speed + 0.1)
		&"life":
			if actor.get("is_human", false): actor.lives += 1
		&"shield": actor.shield = 1
		&"invincible":
			actor.invincible_active_from = tick + 29
			actor.invincible_until = tick + 29 + invincible_ticks
			actor.protected_until = actor.invincible_until
			actor.protection_stage = &"introduction"
		&"car", &"moto", &"horse", &"dragon":
			# Rules XML `rides`: base move speed times car 1.6, moto 1.3, horse 1, dragon 0.8.
			actor.vehicle = kind
			actor.drive_speed = 1.6 * {&"car": 1.6, &"moto": 1.3, &"horse": 1.0, &"dragon": 0.8}[kind]
		&"landmine":
			actor.weapon = kind
			actor.ammo = 1
		&"hammer", &"flamer", &"laser", &"triple", &"shotgun":
			actor.weapon = kind
			actor.ammo = 2
	if kind not in [&"invincible", &"coin"]: actor.score += 100

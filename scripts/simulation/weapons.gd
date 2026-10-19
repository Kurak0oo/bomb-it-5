extends RefCounted
## Weapon callbacks translated to simulation ticks; see recovered animation frame counts.

var attacks: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []


func record_cells(effect: Dictionary, cells: Array[Vector2i]) -> void:
	for attack in attacks:
		if attack.actor_id == effect.actor_id and attack.started == effect.started:
			attack.cells = cells.duplicate()


static func cardinal(facing: Vector2) -> Vector2i:
	if absf(facing.x) > absf(facing.y):
		return Vector2i(int(signf(facing.x)), 0)
	return Vector2i(0, int(signf(facing.y)))


func start(id: StringName, actor: Dictionary, tick: int) -> void:
	var kind: StringName = actor.weapon
	if kind not in [&"hammer", &"flamer", &"laser", &"triple", &"shotgun"]:
		return
	actor.ammo -= 1
	var windup := 23 if kind == &"hammer" else 10 if kind == &"laser" else 0
	var duration := 24 if kind == &"hammer" else 22 if kind == &"laser" else 23
	if kind == &"triple":
		duration = 41
	elif kind == &"shotgun":
		windup = 13
		duration = 24
	actor.busy_until = tick + duration
	attacks.append({"kind": kind, "actor_id": id, "direction": cardinal(actor.facing),
		"ready": tick + windup, "expires": tick + duration, "cell": actor.cell,
		"started": tick, "fired": false})
	if actor.ammo == 0:
		actor.weapon = &""


func advance(tick: int, actors: Dictionary, board: Dictionary, bombs: Array) -> Array[Dictionary]:
	var effects: Array[Dictionary] = []
	for attack in attacks.duplicate():
		if not actors[attack.actor_id].alive:
			attacks.erase(attack)
			continue
		if tick >= attack.expires:
			attacks.erase(attack)
			continue
		if attack.kind in [&"triple", &"shotgun"]:
			var age: int = tick - attack.started
			if (attack.kind == &"triple" and age in [0, 15, 30]) or (attack.kind == &"shotgun" and tick == attack.ready):
				projectiles.append({"actor_id": attack.actor_id, "kind": attack.kind,
					"position": Vector2(actors[attack.actor_id].cell), "direction": attack.direction,
					"speed": (5.0 if attack.kind == &"triple" else 10.0) / 30.0, "born": tick})
			continue
		if tick >= attack.ready and (not attack.fired or attack.kind == &"flamer"):
			var effect: Dictionary = attack.duplicate()
			effect.cell = actors[attack.actor_id].cell
			effect.reach = mini(3, 1 + floori((tick - attack.started) * 3.0 / 22.0))
			effects.append(effect)
			attack.fired = true
	for projectile in projectiles.duplicate():
		if projectile.born == tick:
			continue
		var next: Vector2 = projectile.position + Vector2(projectile.direction) * projectile.speed
		var edge: Vector2 = next + Vector2(projectile.direction) * 0.49999
		var leading := Vector2i(floori(edge.x + 0.5), floori(edge.y + 0.5))
		var blocked: bool = board.get(leading) not in [&"floor", &"portal"] or bombs.any(func(b): return b.cell == leading)
		projectile.position = next
		var target := leading if blocked else Vector2i(floori(next.x + 0.5), floori(next.y + 0.5))
		effects.append({"kind": &"projectile", "actor_id": projectile.actor_id, "cell": target,
			"direction": Vector2i.ZERO})
		if blocked:
			projectiles.erase(projectile)
	return effects

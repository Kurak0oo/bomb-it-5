extends RefCounted
## Weapon callbacks translated to simulation ticks; see recovered animation frame counts.

var attacks: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
## Sound class names raised since the round last drained them (`SoundManger.createSound`).
var sounds: Array[StringName] = []
## `_weaponSound` per action; `useBowling` (fireball) names no class in the SWF, so it is silent.
const USE_SOUNDS := {&"hammer": &"useSinker", &"landmine": &"useSinker", &"flamer": &"useThrower",
	&"laser": &"useLaserReady", &"triple": &"useShotgun", &"shotgun": &"useBowling", &"boxing": &"useBoxing"}
const Geometry = preload("res://scripts/simulation/weapon_geometry.gd")


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
	if kind not in [&"landmine", &"hammer", &"flamer", &"laser", &"triple", &"shotgun", &"boxing"]:
		return
	if actor.ammo > 0: actor.ammo -= 1
	actor.action_started_tick = tick
	sounds.append(USE_SOUNDS[kind])
	var windup := 24 if kind == &"hammer" else 11 if kind == &"laser" else 0
	var duration := 24 if kind == &"hammer" else 22 if kind == &"laser" else 23
	if kind == &"triple":
		duration = 43
	elif kind == &"shotgun":
		windup = 14
		duration = 26
	elif kind == &"flamer":
		duration = 24
	actor.busy_until = tick + duration
	attacks.append({"kind": kind, "actor_id": id, "direction": cardinal(actor.facing),
		"ready": tick + windup, "expires": tick + duration, "cell": actor.cell,
		"started": tick, "fired": false, "frame": 0, "phase": &"windup", "layer": &"front", "recover_at": -1})
	if kind == &"hammer":
		attacks[-1].expires = tick + 25
		actor.busy_until = tick + 24
	elif kind == &"boxing":
		# `BoxingPlayCommand` resolves at `totalFrames-1` of the 14-frame `boxing*_Play` clips.
		attacks[-1].ready = tick + 13
		attacks[-1].expires = tick + 14
		actor.busy_until = tick + 13


func advance(tick: int, actors: Dictionary, board: Dictionary, bombs: Array) -> Array[Dictionary]:
	var effects: Array[Dictionary] = []
	for attack in attacks.duplicate():
		if not actors[attack.actor_id].alive:
			attacks.erase(attack)
			continue
		if tick >= attack.expires:
			complete(attack, actors[attack.actor_id], tick)
			continue
		if attack.recover_at >= 0 and tick >= attack.recover_at:
			complete(attack, actors[attack.actor_id], tick)
			continue
		attack.frame = tick - attack.started
		if attack.kind == &"flamer":
			if attack.frame <= 0: continue
			attack.direction = cardinal(actors[attack.actor_id].facing)
			attack.endpoint = Geometry.flamer_endpoint(attack, actors[attack.actor_id], board)
			attack.phase = &"active"
			attack.fired = true
			effects.append(attack.duplicate())
			if attack.frame >= 23: complete(attack, actors[attack.actor_id], tick)
			continue
		if attack.kind == &"landmine":
			if attack.frame > 0:
				effects.append(attack.duplicate())
				complete(attack, actors[attack.actor_id], tick)
			continue
		if attack.kind == &"laser" and attack.frame >= 11:
			attack.frame = 11
			attack.phase = &"beam"
		if attack.kind in [&"hammer", &"boxing"]:
			attack.direction = cardinal(actors[attack.actor_id].facing)
			if attack.kind == &"hammer": attack.attachment = Geometry.HAMMER_OFFSET[attack.direction]
			# Both re-insert the Up clip behind the robot on `floor(totalFrames / 2)`.
			if attack.frame >= (12 if attack.kind == &"hammer" else 7) and attack.direction == Vector2i.UP:
				attack.layer = &"behind"
		if attack.kind in [&"triple", &"shotgun"]:
			var age: int = tick - attack.started
			if (attack.kind == &"triple" and age in [1, 16, 31]) or (attack.kind == &"shotgun" and tick == attack.ready):
				attack.direction = cardinal(actors[attack.actor_id].facing)
				# Each projectile is a `Bomb` subclass, so its constructor plays `addBomb`.
				sounds.append(&"addBomb")
				projectiles.append({"actor_id": attack.actor_id, "kind": attack.kind,
					"position": Vector2(actors[attack.actor_id].cell), "direction": attack.direction,
					"previous_cell": actors[attack.actor_id].cell, "phase": &"travel", "cleanup_count": 0,
					"speed": (5.0 if attack.kind == &"triple" else 10.0) / 30.0, "born": tick})
				attack.fired = true
				attack.phase = &"emission"
				if age == 31 or attack.kind == &"shotgun":
					# Deliberate simulation-clock conversion; not an observed SWF frame count.
					attack.recover_at = tick + ceili(0.3 * 35.0)
					attack.phase = &"recovery"
			continue
		if tick >= attack.ready and (not attack.fired or attack.kind == &"flamer"):
			var effect: Dictionary = attack.duplicate()
			effect.cell = actors[attack.actor_id].cell
			effect.reach = mini(3, 1 + floori((tick - attack.started) * 3.0 / 22.0))
			effects.append(effect)
			attack.fired = true
			attack.phase = &"beam" if attack.kind == &"laser" else &"impact"
			if attack.kind == &"laser": sounds.append(&"useLaserShoot")
			if attack.kind in [&"hammer", &"boxing"]: complete(attack, actors[attack.actor_id], tick)
	for projectile in projectiles.duplicate():
		if projectile.born == tick:
			continue
		if projectile.phase == &"cleanup":
			if projectile.cleanup_count > 10: projectiles.erase(projectile)
			projectile.cleanup_count += 1
			continue
		var next: Vector2 = projectile.position + Vector2(projectile.direction) * projectile.speed
		var edge: Vector2 = next + Vector2(projectile.direction) * 0.49999
		var leading := Vector2i(floori(edge.x + 0.5), floori(edge.y + 0.5))
		var blocked: bool = board.get(leading) not in [&"floor", &"portal"] or bombs.any(func(b): return b.cell == leading)
		projectile.position = Vector2(leading - projectile.direction) if blocked else next
		var target := Vector2i(floori(projectile.position.x + 0.5), floori(projectile.position.y + 0.5))
		effects.append({"kind": &"projectile", "actor_id": projectile.actor_id, "cell": target,
			"direction": Vector2i.ZERO, "hit_items": target != projectile.previous_cell})
		projectile.previous_cell = target
		if blocked:
			effects.append({"kind": &"projectile", "actor_id": projectile.actor_id,
				"cell": target + projectile.direction, "direction": Vector2i.ZERO, "damage": false})
			projectile.phase = &"cleanup"
			sounds.append(&"bomb")
	return effects


func complete(attack: Dictionary, actor: Dictionary, tick: int) -> void:
	attacks.erase(attack)
	actor.busy_until = tick
	if actor.ammo == 0:
		# A spent pickup falls back to the mode's unlimited base action, if any.
		actor.weapon = actor.get("base_weapon", &"")
		if actor.weapon != &"": actor.ammo = -1


func cancel(actor: Dictionary, id: StringName) -> void:
	for attack in attacks.duplicate():
		if attack.actor_id == id: attacks.erase(attack)
	actor.busy_until = 0


func is_active(id: StringName) -> bool:
	return attacks.any(func(attack: Dictionary): return attack.actor_id == id)

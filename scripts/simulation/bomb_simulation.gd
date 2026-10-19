extends RefCounted
## Headless round and compatible ordinary-bomb slice; see DESIGN.md and runtime evidence.

const CommandModule = preload("res://scripts/simulation/command_boundary.gd")
const Movement = preload("res://scripts/simulation/movement.gd")
const Pickups = preload("res://scripts/simulation/pickups.gd")
const Weapons = preload("res://scripts/simulation/weapons.gd")
const FUSE_TICKS: int = 72

var _commands: CommandModule
var _actor_ids: Array[StringName]
var _actors: Dictionary
var _board: Dictionary
var _bombs: Array[Dictionary] = []
var _tick: int = 0
var _rules: Dictionary
var _flames: Array[Dictionary] = []
var _fire: Dictionary = {}
var _portals: Dictionary = {}
var _outcome: StringName = &"running"
var _result_score: int = 0
var _pickups: Dictionary = {}
var _pending_drops: Array[Dictionary] = []
var _spawned_drops := 0
var _vehicles_left := 4
var _rng := RandomNumberGenerator.new()
var _weapons := Weapons.new()


func _init(actor_ids: Array[StringName], actors: Dictionary, board: Dictionary, rules: Dictionary = {}) -> void:
	_actor_ids = actor_ids.duplicate()
	_actors = actors.duplicate(true)
	_board = board.duplicate(true)
	_commands = CommandModule.new(_actor_ids)
	_rules = rules.duplicate(true)
	_rng.seed = _rules.get("seed", 5)
	_pickups = _rules.get("pickups", {}).duplicate(true)
	if _rules.get("portals", false) is Dictionary:
		_portals = _rules.portals.duplicate()
	elif _rules.get("portals", false):
		_portals = {Vector2i(8, 1): Vector2i(8, 13), Vector2i(8, 13): Vector2i(8, 1),
			Vector2i(4, 7): Vector2i(12, 7), Vector2i(12, 7): Vector2i(4, 7)}
	for id in _actor_ids:
		var actor: Dictionary = _actors[id]
		actor.position = Vector2(actor.cell)
		actor.velocity = Vector2.ZERO
		actor.facing = Vector2.DOWN
		actor.departures = []
		actor.alive = actor.get("alive", true)
		actor.protected_until = actor.get("protected_until", 0)
		actor.shield = actor.get("shield", 0)
		actor.kills = actor.get("kills", 0)
		actor.score = actor.get("score", 0)
		actor.transit_until = 0
		actor.portal_latch = Vector2i(-99, -99)
		actor.portal_target = actor.cell
		actor.blink_until = 0
		actor.capacity = actor.get("capacity", 1)
		actor.power = actor.get("power", 1)
		actor.speed = actor.get("speed", 1.6)
		actor.lives = actor.get("lives", 3 if id == _actor_ids[0] else 1)
		actor.invincible_until = 0
		actor.invincible_active_from = 0
		actor.vehicle = &""
		actor.drive_speed = actor.speed
		actor.busy_until = 0
		actor.weapon = &""
		actor.ammo = 0


func advance(commands: Array[Dictionary]) -> Dictionary:
	if _outcome != &"running":
		var stopped := snapshot()
		stopped.accepted = false
		stopped.commands = []
		return stopped
	var result: Dictionary = _commands.advance(commands)
	_tick = result.tick
	var blasts: Array[Dictionary] = []
	var broken_soft_blocks: Array[Vector2i] = []
	if result.accepted:
		for flame in _flames.duplicate():
			if _tick >= flame.expires:
				for cell in flame.cells:
					_fire.erase(cell)
				_flames.erase(flame)
		var by_actor: Dictionary = {}
		for command in commands:
			by_actor[command.actor_id] = command
		for actor_id in _actor_ids:
			var command: Dictionary = by_actor[actor_id]
			if not _actors[actor_id].alive or _actors[actor_id].transit_until > 0 or _actors[actor_id].busy_until > _tick:
				continue
			for event in command.bomb_events:
				if event == &"down":
					var actor: Dictionary = _actors[command.actor_id]
					if actor.busy_until > _tick:
						continue
					if actor.weapon == &"landmine":
						_bombs.append({"actor_id": actor_id, "cell": actor.cell, "power": 2,
							"kind": &"mine", "armed": false, "detonation_tick": 2147483647})
						actor.weapon = &""
						actor.ammo = 0
						actor.busy_until = _tick + 1
						continue
					if actor.weapon != &"":
						_weapons.start(actor_id, actor, _tick)
						continue
					if _board.get(actor.cell) != &"floor":
						continue
					var owned_bombs: int = _bombs.filter(
						func(bomb: Dictionary): return bomb.actor_id == command.actor_id and bomb.get("kind", &"bomb") != &"mine").size()
					if owned_bombs >= actor.get("capacity", 1):
						continue
					if _bombs.any(func(bomb: Dictionary): return bomb.cell == actor.cell):
						continue
					_bombs.append({"actor_id": command.actor_id, "cell": actor.cell,
						"power": actor.get("power", 1), "detonation_tick": result.tick + FUSE_TICKS})
					for other in _actors.values():
						if Movement.overlaps(other.position, actor.cell) and actor.cell not in other.departures:
							other.departures.append(actor.cell)
		for bomb in _bombs.duplicate():
			if bomb.get("kind", &"bomb") == &"mine" and _bombs.has(bomb):
				if _actors[bomb.actor_id].cell != bomb.cell:
					bomb.armed = true
				if bomb.armed and _actors.values().any(func(a): return a.alive and a.cell == bomb.cell):
					_detonate(bomb, blasts, broken_soft_blocks)
				continue
			if _bombs.has(bomb) and result.tick >= bomb.detonation_tick:
				_detonate(bomb, blasts, broken_soft_blocks)
		for effect in _weapons.advance(_tick, _actors, _board, _bombs):
			_resolve_attack(effect, blasts, broken_soft_blocks)
		_advance_portals()
		if _rules.get("movement", false):
			for command in commands:
				if _actors[command.actor_id].alive and _actors[command.actor_id].transit_until == 0 and _actors[command.actor_id].busy_until <= _tick:
					Movement.step(_actors[command.actor_id], command.direction, _board, _bombs)
		if _rules.get("damage", false):
			for actor_id in _actor_ids:
				if _fire.has(_actors[actor_id].cell):
					_hurt(actor_id, &"")
		if _rules.get("drops", false):
			_advance_pickups()
		if _rules.get("round", false):
			_finish_round()
	result.merge(snapshot(), true)
	result.blasts = blasts
	result.broken_soft_blocks = broken_soft_blocks
	return result


func snapshot() -> Dictionary:
	return {"tick": _tick, "board": _board.duplicate(true), "actors": _actors.duplicate(true),
		"bombs": _public_bombs(),
		"blasts": [], "broken_soft_blocks": [], "flames": _flames.duplicate(true),
		"outcome": _outcome, "remaining": maxi(0, 6300 - _tick), "result_score": _result_score,
		"pickups": _pickups.duplicate(true), "attacks": _weapons.attacks.duplicate(true),
		"projectiles": _weapons.projectiles.duplicate(true), "fire": _fire.keys()}


func _public_bombs() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for bomb in _bombs:
		var item := {"actor_id": bomb.actor_id, "cell": bomb.cell, "power": bomb.power}
		if bomb.get("kind", &"bomb") == &"mine":
			item.kind = &"mine"
		result.append(item)
	return result


func _detonate(bomb: Dictionary, blasts: Array[Dictionary], broken: Array[Vector2i]) -> void:
	# Removal before tracing also prevents a chain from detonating its parent again.
	_bombs.erase(bomb)
	var cells: Array[Vector2i] = [bomb.cell]
	_pickups.erase(bomb.cell)
	for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		for distance in range(1, bomb.power + 1):
			var cell: Vector2i = bomb.cell + direction * distance
			var tile: Variant = _board.get(cell)
			if tile not in [&"floor", &"soft"]:
				break
			cells.append(cell)
			_pickups.erase(cell)
			var hit_bombs: Array[Dictionary] = _bombs.filter(
				func(other: Dictionary): return other.cell == cell)
			if not hit_bombs.is_empty():
				_detonate(hit_bombs[0], blasts, broken)
				break
			if tile == &"soft":
				_board[cell] = &"floor"
				broken.append(cell)
				_actors[bomb.actor_id].score += 10
				_pending_drops.append({"cell": cell, "ready": _tick + 11})
				break
	blasts.append({"actor_id": bomb.actor_id, "cell": bomb.cell, "cells": cells})
	if _rules.get("damage", false):
		_flames.append({"cells": cells.duplicate(), "expires": _tick + 17, "actor_id": bomb.actor_id})
		for cell in cells:
			_fire[cell] = true
			for actor_id in _actor_ids:
				if _actors[actor_id].cell == cell:
					_hurt(actor_id, bomb.actor_id)


func _hurt(actor_id: StringName, owner: StringName) -> void:
	var actor: Dictionary = _actors[actor_id]
	if not _rules.get("damage", false) or not actor.alive or actor.protected_until > _tick:
		return
	if actor.vehicle != &"":
		actor.vehicle = &""
		actor.busy_until = _tick + 35
		actor.protected_until = _tick + 35 + 82
		actor.velocity = Vector2.ZERO
	elif actor.shield > 0:
		actor.shield -= 1
		actor.protected_until = _tick + 82
	else:
		actor.alive = false
		actor.lives = maxi(0, actor.lives - 1)
		actor.velocity = Vector2.ZERO
		if owner != &"" and owner != actor_id and _actors.has(owner):
			_actors[owner].kills += 1
			_actors[owner].score += 100


func _advance_portals() -> void:
	for actor in _actors.values():
		if not actor.alive:
			continue
		if actor.transit_until > 0:
			if _tick >= actor.transit_until:
				actor.cell = actor.portal_target
				actor.position = Vector2(actor.cell)
				actor.velocity = Vector2.ZERO
				actor.transit_until = 0
				# SendRobotCommand restores isExist at arrival, before the blink command ends.
				actor.protected_until = _tick
			continue
		if not _portals.has(actor.cell):
			actor.portal_latch = Vector2i(-99, -99)
		elif actor.portal_latch != actor.cell and _portals.get(actor.cell) != actor.portal_latch:
			actor.portal_target = _portals[actor.cell]
			actor.portal_latch = actor.portal_target
			actor.transit_until = _tick + 30
			actor.protected_until = _tick + 30
			actor.blink_until = _tick + 47


func _finish_round() -> void:
	var human: Dictionary = _actors[_actor_ids[0]]
	var enemy_alive := false
	for id in _actor_ids.slice(1):
		enemy_alive = enemy_alive or _actors[id].alive
	# ArcadeMode.end checks surviving humans before checking surviving AI.
	if not human.alive:
		_outcome = &"lost"
	elif not enemy_alive:
		_outcome = &"won"
	elif _tick >= 6300:
		_outcome = &"timeout"
		human.lives = maxi(0, human.lives - 1)
	if _outcome != &"running":
		_result_score = human.kills * 300
		if _outcome == &"won":
			_result_score += 2000 + ceili(maxi(0, 6300 - _tick) / 35.0) * 10


func _advance_pickups() -> void:
	for drop in _pending_drops.duplicate():
		if _tick >= drop.ready:
			_pending_drops.erase(drop)
			var occupied := false
			for actor in _actors.values():
				occupied = occupied or (actor.alive and actor.cell == drop.cell)
			if not occupied and _spawned_drops < 32 and _rng.randf() < 0.5:
				_spawn_pickup(drop.cell, true)
	# ArcadeMode.timePassed uses >45, so the first timed spawn is at 60 seconds.
	if _tick > 45 * 35 and _tick % (15 * 35) == 0:
		var free: Array[Vector2i] = []
		for cell in _board:
			if _board[cell] in [&"floor", &"portal"] and not _pickups.has(cell) and not _bombs.any(func(b): return b.cell == cell) and not _actors.values().any(func(a): return a.alive and a.cell == cell):
				free.append(cell)
		for index in mini(2, free.size()):
			var selected := _rng.randi_range(0, free.size() - 1)
			_spawn_pickup(free[selected], false)
			free.remove_at(selected)
	for actor in _actors.values():
		if actor.alive and actor.transit_until == 0 and _pickups.has(actor.cell):
			Pickups.apply(actor, _pickups[actor.cell], _tick)
			_pickups.erase(actor.cell)
	for id in _actor_ids:
		if _actors[id].alive and _actors[id].invincible_until > _tick and _actors[id].invincible_active_from <= _tick:
			for other in _actor_ids:
				if other != id and _actors[other].cell == _actors[id].cell:
					_hurt(other, id)


func _spawn_pickup(cell: Vector2i, quota: bool) -> void:
	var kind := Pickups.choose(_rng, _vehicles_left if quota else 4)
	if kind == &"":
		return
	if kind == &"vehicle":
		kind = &"car" if _rng.randi_range(0, 1) else &"moto"
		if quota:
			_vehicles_left -= 1
	_pickups[cell] = kind
	if quota:
		_spawned_drops += 1


func _resolve_attack(effect: Dictionary, blasts: Array[Dictionary], broken: Array[Vector2i]) -> void:
	if effect.kind == &"laser":
		var beam: Array[Vector2i] = []
		for distance in 17:
			var cell: Vector2i = effect.cell + effect.direction * distance
			if _board.get(cell) not in [&"floor", &"portal", &"soft"]:
				break
			var occupied := _actors.values().any(func(a): return a.alive and a.cell == cell)
			var blocked: bool = _board[cell] == &"soft" or (not occupied and _bombs.any(func(b): return b.cell == cell))
			beam.append(cell)
			_hit_cell(cell, effect.actor_id, blasts, broken)
			if blocked:
				break
		_weapons.record_cells(effect, beam)
		return
	var target: Vector2i = effect.cell + effect.direction
	if effect.kind == &"flamer":
		var visible_cells: Array[Vector2i] = []
		for distance in range(1, effect.reach + 1):
			target = effect.cell + effect.direction * distance
			if _board.get(target) not in [&"floor", &"portal", &"soft"]:
				break
			visible_cells.append(target)
		_weapons.record_cells(effect, visible_cells)
	_hit_cell(target, effect.actor_id, blasts, broken)
	if effect.kind == &"hammer":
		for id in _actor_ids:
			if id != effect.actor_id and _actors[id].cell == effect.cell:
				_hurt(id, effect.actor_id)


func _hit_cell(target: Vector2i, owner: StringName, blasts: Array[Dictionary], broken: Array[Vector2i]) -> void:
	if _board.get(target) == &"soft":
		_board[target] = &"floor"
		broken.append(target)
		_actors[owner].score += 10
		_pending_drops.append({"cell": target, "ready": _tick + 11})
	else:
		for bomb in _bombs.duplicate():
			if bomb.cell == target and _bombs.has(bomb):
				_detonate(bomb, blasts, broken)
		_pickups.erase(target)
	for id in _actor_ids:
		if id != owner and _actors[id].cell == target:
			_hurt(id, owner)

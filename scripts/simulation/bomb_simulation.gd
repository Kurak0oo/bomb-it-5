extends RefCounted
## Headless round and compatible ordinary-bomb slice; see DESIGN.md and runtime evidence.

const CommandModule = preload("res://scripts/simulation/command_boundary.gd")
const Movement = preload("res://scripts/simulation/movement.gd")
const Pickups = preload("res://scripts/simulation/pickups.gd")
const Weapons = preload("res://scripts/simulation/weapons.gd")
const ArcadeMode = preload("res://scripts/simulation/modes/arcade_mode.gd")
const FUSE_TICKS: int = 72

var _commands: CommandModule
var _actor_ids: Array[StringName]
var _actors: Dictionary
var _board: Dictionary
var _bombs: Array[Dictionary] = []
var _countdowns: Array[Dictionary] = []
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
var _drop_pool: Array[StringName] = []
var _random_draws: Array = []
var _random_index := 0
var _late_blast := false
var _round_stage: StringName = &"playing"
var _pending_outcome: StringName = &""
var _ending_started := 0
var _gameplay_end_tick := 0
var _judgment_ready := false
var _mode: RefCounted
var _board_max := Vector2i(16, 14)


func _init(actor_ids: Array[StringName], actors: Dictionary, board: Dictionary, rules: Dictionary = {}) -> void:
	_actor_ids = actor_ids.duplicate()
	_actors = actors.duplicate(true)
	_board = board.duplicate(true)
	_commands = CommandModule.new(_actor_ids)
	_rules = rules.duplicate(true)
	_mode = _rules.get("mode") if _rules.get("mode") is RefCounted else ArcadeMode.new()
	# Timed pickups scan the recorded 17x15 interior; larger boards extend it.
	for cell in _board:
		_board_max = Vector2i(maxi(_board_max.x, cell.x), maxi(_board_max.y, cell.y))
	_rng.seed = _rules.get("seed", 5)
	_random_draws = _rules.get("random_draws", []).duplicate()
	_drop_pool = Pickups.build_pool(_draw_random, _mode.drop_weights(), _rules.get("vehicles", [&"moto", &"car"]))
	_vehicles_left = _rules.get("vehicle_budget", 4)
	_spawned_drops = _rules.get("drop_count", 0)
	_pickups = _rules.get("pickups", {}).duplicate(true)
	_pickups.merge(_mode.opening_pickups(_actors[_actor_ids[0]].cell), true)
	if _rules.get("portals", false) is Dictionary:
		_portals = _rules.portals.duplicate()
	elif _rules.get("portals", false):
		_portals = {Vector2i(8, 1): Vector2i(8, 13), Vector2i(8, 13): Vector2i(8, 1),
			Vector2i(4, 7): Vector2i(12, 7), Vector2i(12, 7): Vector2i(4, 7)}
	for id in _actor_ids:
		var actor: Dictionary = _actors[id]
		actor.position = actor.get("position", Vector2(actor.cell))
		actor.velocity = actor.get("velocity", Vector2.ZERO)
		actor.facing = actor.get("facing", Vector2.DOWN)
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
		actor.vehicle = actor.get("vehicle", &"")
		actor.drive_speed = actor.get("drive_speed", actor.speed)
		actor.busy_until = 0
		actor.weapon = actor.get("weapon", &"")
		actor.ammo = actor.get("ammo", 0)
		actor.bomb_count = 0
		actor.is_human = id == _actor_ids[0]
		actor.protection_stage = &"none"
		actor.vehicle_recovery_until = 0
		actor.movement_rearm = false
		actor.death_frame = 0
		actor.removed = false
		actor.model_state = &"normal"
		actor.registered_state = &"normal"
		actor.registered_vehicle = actor.vehicle
		actor.action_started_tick = -1


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
		if _round_stage == &"ending":
			_finish_round()
			result.merge(snapshot(), true)
			return result
		_late_blast = false
		_advance_actor_states()
		# Live registry removal deliberately skips the following cleanup callback.
		var cleanup_index := 0
		while cleanup_index < _flames.size():
			var flame: Dictionary = _flames[cleanup_index]
			if flame.count > 15:
				for cell in flame.cells:
					_fire.erase(cell)
				_bombs.erase(flame.bomb)
				_flames.erase(flame)
			flame.count += 1
			cleanup_index += 1
		var by_actor: Dictionary = {}
		for command in commands:
			by_actor[command.actor_id] = command
		for actor_id in _actor_ids:
			var command: Dictionary = by_actor[actor_id]
			if not _actors[actor_id].alive or _actors[actor_id].transit_until > 0 or _actors[actor_id].busy_until > _tick or _weapons.is_active(actor_id):
				continue
			if command.direction != Vector2.ZERO:
				_actors[actor_id].facing = command.direction.normalized()
			for event in command.bomb_events:
				if event == &"down":
					var actor: Dictionary = _actors[command.actor_id]
					if actor.busy_until > _tick:
						continue
					if actor.weapon == &"landmine":
						_weapons.start(actor_id, actor, _tick)
						continue
					if actor.weapon != &"":
						_weapons.start(actor_id, actor, _tick)
						continue
					if _board.get(actor.cell) != &"floor":
						continue
					if actor.bomb_count >= actor.get("capacity", 1):
						continue
					if _bombs.any(func(bomb: Dictionary): return bomb.cell == actor.cell):
						continue
					var placed := {"actor_id": command.actor_id, "cell": actor.cell,
						"power": actor.get("power", 1), "born": _tick, "age": 0, "blasted": false, "previous_cell": Vector2i.ZERO}
					_bombs.append(placed)
					_countdowns.append(placed)
					actor.bomb_count += 1
					for other in _actors.values():
						if Movement.overlaps(other.position, actor.cell) and actor.cell not in other.departures:
							other.departures.append(actor.cell)
		var countdown_index := 0
		while countdown_index < _countdowns.size():
			var bomb: Dictionary = _countdowns[countdown_index]
			if bomb.get("kind") == &"mine":
				if bomb.armed:
					if _actors.values().any(func(a): return a.alive and a.cell == bomb.cell):
						_detonate(bomb, blasts, broken_soft_blocks, true)
				elif _actors[bomb.actor_id].cell != bomb.cell:
					bomb.armed = true
			elif bomb.born < _tick:
				bomb.age += 1
				if bomb.age >= FUSE_TICKS:
					_detonate(bomb, blasts, broken_soft_blocks)
				bomb.previous_cell = bomb.cell
			countdown_index += 1
		_late_blast = true
		for effect in _weapons.advance(_tick, _actors, _board, _bombs):
			_resolve_attack(effect, blasts, broken_soft_blocks)
		var previous_cells := {}
		var registered_cells := {}
		for id in _actor_ids:
			previous_cells[id] = _actors[id].cell
			var position_at: Vector2 = _actors[id].position
			registered_cells[id] = Vector2i(floori(position_at.x + 0.5), floori(position_at.y + 0.5))
		_advance_portals()
		if _rules.get("movement", false):
			for command in commands:
				var actor: Dictionary = _actors[command.actor_id]
				if actor.movement_rearm and command.direction == Vector2.ZERO:
					actor.movement_rearm = false
				if actor.alive and actor.transit_until == 0 and actor.busy_until <= _tick and not actor.movement_rearm:
					Movement.step(actor, command.direction, _board, _bombs)
		for actor_id in _actor_ids:
			var actor: Dictionary = _actors[actor_id]
			var changed: bool = previous_cells[actor_id] != registered_cells[actor_id] or actor.model_state != actor.registered_state or actor.vehicle != actor.registered_vehicle
			actor.cell = registered_cells[actor_id]
			actor.registered_state = actor.model_state
			actor.registered_vehicle = actor.vehicle
			if _rules.get("damage", false):
				if changed and _fire.has(registered_cells[actor_id]):
					_hurt(actor_id, &"")
		if _rules.get("drops", false):
			_advance_pickups()
		_advance_death_movies()
		if _rules.get("round", false):
			_finish_round()
	result.merge(snapshot(), true)
	result.blasts = blasts
	result.broken_soft_blocks = broken_soft_blocks
	return result


func snapshot() -> Dictionary:
	return {"tick": _tick, "board": _board.duplicate(true), "actors": _actors.duplicate(true),
		"bombs": _public_bombs(), "bomb_occupancy": _bombs.duplicate(true),
		"blasts": [], "broken_soft_blocks": [], "flames": _flames.duplicate(true),
		"outcome": _outcome, "round_stage": _round_stage, "pending_outcome": _pending_outcome,
		"ending_progress": clampf(float(_tick - _ending_started) / 105.0, 0.0, 1.0) if _round_stage == &"ending" else 0.0,
		"remaining": maxi(0, _mode.round_ticks() - (_gameplay_end_tick if _gameplay_end_tick > 0 else _tick)), "result_score": _result_score,
		"mode": _mode.name, "difficulty": _mode.difficulty, "board_meta": _rules.get("board_meta", {}), "result_breakdown": _mode.breakdown.duplicate(),
		"pickups": _pickups.duplicate(true), "attacks": _weapons.attacks.duplicate(true),
		"projectiles": _weapons.projectiles.duplicate(true), "fire": _fire.keys()}


func _public_bombs() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for bomb in _bombs:
		if bomb.get("detonated", false): continue
		var item := {"actor_id": bomb.actor_id, "cell": bomb.cell, "power": bomb.power}
		if bomb.get("kind", &"bomb") == &"mine":
			item.kind = &"mine"
		result.append(item)
	return result


func _detonate(bomb: Dictionary, blasts: Array[Dictionary], broken: Array[Vector2i], mine_contact: bool = false) -> void:
	if bomb.get("detonated", false): return
	bomb.detonated = true
	bomb.blasted = not mine_contact
	_countdowns.erase(bomb)
	if not mine_contact: _actors[bomb.actor_id].bomb_count -= 1
	if mine_contact and _rules.get("damage", false):
		# Landmine.hitReset awards and tries contact damage before calling inherited blast.
		for id in _actor_ids:
			var actor: Dictionary = _actors[id]
			if not actor.alive or actor.cell != bomb.cell: continue
			if id != bomb.actor_id and actor.vehicle == &"" and actor.shield == 0:
				_actors[bomb.actor_id].score += 100
				_actors[bomb.actor_id].kills += 1
			_hurt(id, &"")
	var cells: Array[Vector2i] = []
	_add_blast_cell(cells, bomb.cell)
	if bomb.get("previous_cell", Vector2i.ZERO) != bomb.cell:
		_hit_cell(bomb.cell, bomb.actor_id, blasts, broken, false)
	_deliver_blast_contact(bomb.cell, bomb.actor_id)
	var directions := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	var continuing := [true, true, true, true]
	# Source Bomb.blast visits each distance ring before the next, delivering damage inline.
	for distance in range(1, bomb.power + 1):
		for ray in 4:
			if not continuing[ray]: continue
			var cell: Vector2i = bomb.cell + directions[ray] * distance
			var tile: Variant = _board.get(cell)
			if tile not in [&"floor", &"soft"]:
				continuing[ray] = false
				if tile != null: _hit_cell(cell, bomb.actor_id, blasts, broken, false)
				continue
			if _bombs.any(func(other: Dictionary): return other.cell == cell):
				continuing[ray] = false
				# hitItem dispatches to every map bomb entry, not just the first one.
				_hit_cell(cell, bomb.actor_id, blasts, broken, false)
				continue
			_add_blast_cell(cells, cell)
			_hit_cell(cell, bomb.actor_id, blasts, broken, false)
			if tile == &"soft":
				continuing[ray] = false
			else:
				_deliver_blast_contact(cell, bomb.actor_id)
	blasts.append({"actor_id": bomb.actor_id, "cell": bomb.cell, "cells": cells})
	if _rules.get("damage", false):
		_flames.append({"cells": cells.duplicate(), "count": 0 if _late_blast else 1, "bomb": bomb,
			"expires": _tick + 16, "actor_id": bomb.actor_id})
	else:
		_bombs.erase(bomb)


func _add_blast_cell(cells: Array[Vector2i], cell: Vector2i) -> void:
	cells.append(cell)
	if _rules.get("damage", false): _fire[cell] = true


func _deliver_blast_contact(cell: Vector2i, owner: StringName) -> void:
	for id in _actor_ids:
		if _actors[id].cell == cell: _hurt(id, owner)


func _hurt(actor_id: StringName, owner: StringName) -> void:
	var actor: Dictionary = _actors[actor_id]
	if not _rules.get("damage", false) or not actor.alive or actor.protected_until > _tick:
		return
	if actor.vehicle != &"":
		actor.busy_until = _tick + 35
		actor.vehicle_recovery_until = _tick + 35
		actor.protected_until = _tick + 35
		actor.drive_speed = actor.speed
		actor.velocity = Vector2.ZERO
	elif actor.shield > 0:
		actor.shield -= 1
		actor.protected_until = _tick + 81
	else:
		actor.alive = false
		actor.model_state = &"dead"
		actor.death_frame = 1
		actor.velocity = Vector2.ZERO
		_weapons.cancel(actor, actor_id)
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
				actor.movement_rearm = true
				# SendRobotCommand restores isExist at arrival, before the blink command ends.
				actor.protected_until = _tick
			continue
		if not _portals.has(actor.cell):
			actor.portal_latch = Vector2i(-99, -99)
		elif actor.portal_latch != actor.cell and _portals.get(actor.cell) != actor.portal_latch:
			actor.portal_target = _portals[actor.cell]
			actor.portal_latch = actor.portal_target
			actor.transit_until = _tick + 29
			actor.protected_until = _tick + 29
			actor.blink_until = _tick + 46


func _advance_actor_states() -> void:
	for actor in _actors.values():
		if actor.vehicle_recovery_until > 0 and _tick >= actor.vehicle_recovery_until:
			actor.vehicle_recovery_until = 0
			actor.vehicle = &""
			actor.protected_until = _tick + 81
			actor.movement_rearm = true
		actor.protection_stage = &"none"
		if actor.alive:
			actor.model_state = &"Invincible" if actor.invincible_until > _tick else &"normal"
		if actor.invincible_until > _tick:
			actor.protection_stage = &"introduction" if _tick < actor.invincible_active_from else &"active"
		elif actor.protected_until > _tick:
			actor.protection_stage = &"recovery" if actor.vehicle_recovery_until > 0 else &"blink"


func human() -> Dictionary:
	return _actors[_actor_ids[0]]


func enemies() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id in _actor_ids.slice(1):
		result.append(_actors[id])
	return result


func _finish_round() -> void:
	if _round_stage == &"ending":
		# Source GameEndCartoon uses a three-second host Tween; accepted conversion freezes on pause.
		if _tick - _ending_started >= 105:
			_outcome = _pending_outcome
			_round_stage = &"settled"
			_result_score = _mode.settle(self, _outcome, _gameplay_end_tick)
			human().score = _result_score
		return
	_pending_outcome = _mode.judge(self, _judgment_ready, _tick)
	if _pending_outcome != &"":
		_round_stage = &"ending"
		_ending_started = _tick
		_gameplay_end_tick = _tick
		for id in _actor_ids:
			_weapons.cancel(_actors[id], id)
			_actors[id].velocity = Vector2.ZERO
		_weapons.projectiles.clear()


func _advance_death_movies() -> void:
	_judgment_ready = false
	for actor in _actors.values():
		if not actor.alive and not actor.removed:
			_round_stage = &"death"
			if actor.death_frame >= 60:
				actor.removed = true
				_judgment_ready = true
			else:
				actor.death_frame += 1


func _advance_pickups() -> void:
	var drop_index := 0
	while drop_index < _pending_drops.size():
		var drop: Dictionary = _pending_drops[drop_index]
		if drop.born < _tick: drop.frame += 1
		if drop.frame >= 10:
			_pending_drops.erase(drop)
			var occupied := false
			for actor in _actors.values():
				occupied = occupied or (actor.alive and actor.cell == drop.cell)
			if not occupied and _spawned_drops < 32 and _draw_random() < _rules.get("drop_chance", _mode.drop_chance()):
				_spawn_pickup(drop.cell, true)
		drop_index += 1
	var timed_count: int = _mode.timed_pickup_count(_tick)
	if timed_count > 0:
		var free: Array[Vector2i] = []
		# Source enumerates x first, then y, chooses all positions before any class draw.
		for x in range(1, _board_max.x + 1):
			for y in range(1, _board_max.y + 1):
				var cell := Vector2i(x, y)
				if _board.get(cell) in [&"floor", &"portal"] and not _pickups.has(cell) and not _bombs.any(func(b): return b.cell == cell) and not _actors.values().any(func(a): return a.alive and a.cell == cell):
					free.append(cell)
		var selected_cells: Array[Vector2i] = []
		for index in mini(timed_count, free.size()):
			var selected := int(_draw_random() * free.size())
			selected_cells.append(free[selected])
			free.remove_at(selected)
		for cell in selected_cells: _spawn_pickup(cell, false)
	for actor in _actors.values():
		if actor.alive and actor.transit_until == 0 and actor.action_started_tick != _tick and _pickups.has(actor.cell):
			var kind: StringName = _pickups[actor.cell]
			if kind in [&"landmine", &"hammer", &"flamer", &"laser", &"triple", &"shotgun"]:
				_weapons.cancel(actor, _actors.find_key(actor))
			Pickups.apply(actor, kind, _tick)
			_pickups.erase(actor.cell)
	for id in _actor_ids:
		if _actors[id].alive and _actors[id].invincible_until > _tick and _actors[id].invincible_active_from <= _tick:
			for other in _actor_ids:
				if other != id and _actors[other].cell == _actors[id].cell:
					_hurt(other, id)


func _spawn_pickup(cell: Vector2i, quota: bool) -> void:
	var kind: StringName = _drop_pool[int(_draw_random() * _drop_pool.size())]
	if quota and kind in Pickups.VEHICLES:
		if _vehicles_left <= 0:
			var index := 0
			while index < _drop_pool.size():
				if _drop_pool[index] in Pickups.VEHICLES:
					_drop_pool.remove_at(index)
				index += 1
			return
		_vehicles_left -= 1
	if kind not in [&"reserved_kick", &"reserved_boxing"]:
		_pickups[cell] = kind
	if quota:
		_spawned_drops += 1


func _draw_random() -> float:
	var value: float = _random_draws[_random_index] if _random_index < _random_draws.size() else _rng.randf()
	_random_index += 1
	return clampf(value, 0.0, 0.9999999999999999)


func _resolve_attack(effect: Dictionary, blasts: Array[Dictionary], broken: Array[Vector2i]) -> void:
	if effect.kind == &"landmine":
		var mine := {"actor_id": effect.actor_id, "cell": _actors[effect.actor_id].cell,
			"power": 2, "kind": &"mine", "armed": false, "blasted": false, "detonated": false}
		_bombs.append(mine)
		_countdowns.append(mine)
		return
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
		target = effect.endpoint
		var visible_cells: Array[Vector2i] = [target]
		_weapons.record_cells(effect, visible_cells)
	_hit_cell(target, effect.actor_id, blasts, broken, effect.get("damage", true), effect.get("hit_items", true))
	if effect.kind == &"hammer":
		for id in _actor_ids:
			if id != effect.actor_id and _actors[id].cell == effect.cell:
				_hurt(id, effect.actor_id)


func _hit_cell(target: Vector2i, owner: StringName, blasts: Array[Dictionary], broken: Array[Vector2i], damage: bool = true, hit_items: bool = true) -> void:
	if hit_items and _board.get(target) == &"soft":
		_board[target] = &"floor"
		broken.append(target)
		_actors[owner].score += 10
		_pending_drops.append({"cell": target, "born": _tick, "frame": 0})
	elif hit_items:
		for bomb in _bombs.duplicate():
			if bomb.cell == target and _bombs.has(bomb):
				_detonate(bomb, blasts, broken)
		_pickups.erase(target)
	for id in _actor_ids:
		if damage and id != owner and _actors[id].cell == target:
			_hurt(id, owner)

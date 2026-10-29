extends RefCounted
## Headless round and compatible ordinary-bomb slice; see DESIGN.md and runtime evidence.

const CommandModule = preload("res://scripts/simulation/command_boundary.gd")
const Movement = preload("res://scripts/simulation/movement.gd")
const Pickups = preload("res://scripts/simulation/pickups.gd")
const Weapons = preload("res://scripts/simulation/weapons.gd")
const ArcadeMode = preload("res://scripts/simulation/modes/arcade_mode.gd")
const Features = preload("res://scripts/simulation/features/features.gd")
## Rides that boxes may drop at most four of (`Box.as`); the dragon is uncapped.
const CAPPED_VEHICLES: Array[StringName] = [&"car", &"moto", &"horse"]
const HORSE_JUMP_SPEED := 4.0 / 30.0
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
## Original round clock (#80, `Game.countTime`): `seconds` polls the wall-clock second once per
## step and `_past_time` gains one whenever it changes, so stalls miss seconds and the first
## step already counts one (`pastSecond` starts as NaN). Absent, the round runs on steps.
var _seconds: Callable
var _past_time := 0
var _past_second := -1
var _clock_advanced := false
var _mode: RefCounted
var _board_max := Vector2i(16, 14)
var _features: Array = []
var _current_blasts: Array[Dictionary] = []
var _current_broken: Array[Vector2i] = []


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
	if _rules.get("seconds") is Callable: _seconds = _rules.seconds
	_random_draws = _rules.get("random_draws", []).duplicate()
	_drop_pool = Pickups.build_pool(_draw_random, _mode.drop_weights(), _rules.get("vehicles", [&"moto", &"car"]))
	_vehicles_left = _rules.get("vehicle_budget", 4)
	_spawned_drops = _rules.get("drop_count", 0)
	_pickups = _rules.get("pickups", {}).duplicate(true)
	_pickups.merge(_mode.opening_pickups(_actors[_actor_ids[0]].cell), true)
	_features = Features.create(_rules.get("features", {}), _mode, _rules.get("center"), _rules.get("skin", &""))
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
		actor.pushed = {}
		actor.jump = {}
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
		actor.spawn = actor.get("spawn", actor.cell)
		actor.base_stats = {"capacity": actor.capacity, "power": actor.power, "speed": actor.speed}
		# KillModeWeapon/PacModeWeapon: an unlimited action that replaces bomb placement.
		actor.base_weapon = _mode.base_weapon(actor.is_human)
		if actor.weapon == &"" and actor.base_weapon != &"":
			actor.weapon = actor.base_weapon
			actor.ammo = -1
		# model.propArr / weaponPropArr: what a non-Arcade death scatters (RobotDeadCommand.spitProp).
		actor.collected = []
		actor.kept_weapons = []
		actor.respawn_at = 0
		actor.protection_stage = &"none"
		actor.vehicle_recovery_until = 0
		actor.movement_rearm = false
		actor.death_frame = 0
		actor.removed = false
		actor.model_state = &"normal"
		actor.registered_state = &"normal"
		actor.registered_vehicle = actor.vehicle
		actor.action_started_tick = -1
	_mode.begin(self)


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
	_current_blasts = blasts
	_current_broken = broken_soft_blocks
	if result.accepted:
		if _round_stage == &"ending":
			_finish_round()
			result.merge(snapshot(), true)
			return result
		_late_blast = false
		_advance_respawns()
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
			# Toy-hand pushes and horse jumps take the controls away.
			if not _actors[actor_id].get("pushed", {}).is_empty() or not _actors[actor_id].get("jump", {}).is_empty():
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
					if _board.get(actor.cell) not in [&"floor", &"belt"]:
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
				elif not _actors.has(bomb.actor_id) or _actors[bomb.actor_id].cell != bomb.cell:
					bomb.armed = true
			elif bomb.born < _tick and not bomb.get("flying", false):
				# Belt bombs carry their own fuse; toy-hand throws pause it in flight.
				bomb.age += 1
				if bomb.age >= bomb.get("fuse", FUSE_TICKS):
					_detonate(bomb, blasts, broken_soft_blocks)
				bomb.previous_cell = bomb.cell
			countdown_index += 1
		_advance_flying()
		_late_blast = true
		for effect in _weapons.advance(_tick, _actors, _board, _bombs):
			_resolve_attack(effect, blasts, broken_soft_blocks)
		var held := {}
		for command in commands:
			held[command.actor_id] = command.direction if _actors[command.actor_id].alive else Vector2.ZERO
		for feature in _features:
			feature.advance(self, held)
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
				if actor.alive and not actor.get("pushed", {}).is_empty():
					_advance_push(actor)
				elif actor.alive and actor.get("jump", {}).size() > 0:
					_advance_jump(actor)
				elif actor.alive and actor.transit_until == 0 and actor.busy_until <= _tick and not actor.movement_rearm:
					Movement.step(actor, command.direction, _board, _bombs)
					if actor.vehicle in [&"horse", &"dragon"]: _ride_contact(actor, command.direction)
		for actor_id in _actor_ids:
			var actor: Dictionary = _actors[actor_id]
			var changed: bool = previous_cells[actor_id] != registered_cells[actor_id] or actor.model_state != actor.registered_state or actor.vehicle != actor.registered_vehicle
			actor.cell = registered_cells[actor_id]
			actor.registered_state = actor.model_state
			actor.registered_vehicle = actor.vehicle
			if _rules.get("damage", false):
				if changed and _fire.has(registered_cells[actor_id]):
					_hurt(actor_id, &"")
		if _rules.get("round", false) and _round_stage != &"ending": _count_time()
		if _rules.get("drops", false):
			_advance_pickups()
		_advance_death_movies()
		if _round_stage != &"ending": _mode.tick(self, _tick)
		if _rules.get("round", false):
			_finish_round()
	result.merge(snapshot(), true)
	result.blasts = blasts
	result.broken_soft_blocks = broken_soft_blocks
	return result


func snapshot() -> Dictionary:
	for id in _actor_ids: _actors[id].points = _mode.points(_actors[id])
	return {"tick": _tick, "board": _board.duplicate(true), "actors": _actors.duplicate(true),
		"bombs": _public_bombs(), "bomb_occupancy": _bombs.duplicate(true),
		"blasts": [], "broken_soft_blocks": [], "flames": _flames.duplicate(true),
		"outcome": _outcome, "round_stage": _round_stage, "pending_outcome": _pending_outcome,
		"ending_progress": clampf(float(_tick - _ending_started) / 105.0, 0.0, 1.0) if _round_stage == &"ending" else 0.0,
		"remaining": maxi(0, _mode.round_ticks() - (_gameplay_end_tick if _gameplay_end_tick > 0 else clock_tick())), "result_score": _result_score,
		"mode": _mode.name, "difficulty": _mode.difficulty, "mode_state": _mode.public_state(), "points_goal": _mode.points_goal(), "board_meta": _rules.get("board_meta", {}), "result_breakdown": _mode.breakdown.duplicate(),
		"features": _features.map(func(feature): return feature.public_state()),
		"pickups": _pickups.duplicate(true), "attacks": _weapons.attacks.duplicate(true),
		"projectiles": _weapons.projectiles.duplicate(true), "fire": _fire.keys()}


func _public_bombs() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for bomb in _bombs:
		if bomb.get("detonated", false): continue
		var item := {"actor_id": bomb.actor_id, "cell": bomb.cell, "power": bomb.power}
		# Thrown and belt-carried bombs sit between cells.
		if bomb.has("fly_position") or bomb.has("belt_position"):
			item.position = bomb.get("fly_position", bomb.get("belt_position"))
		if bomb.get("kind", &"bomb") == &"mine":
			item.kind = &"mine"
		result.append(item)
	return result


func _detonate(bomb: Dictionary, blasts: Array[Dictionary], broken: Array[Vector2i], mine_contact: bool = false) -> void:
	if bomb.get("detonated", false): return
	bomb.detonated = true
	bomb.blasted = not mine_contact
	_countdowns.erase(bomb)
	if not mine_contact and _actors.has(bomb.actor_id): _actors[bomb.actor_id].bomb_count -= 1
	if mine_contact and _rules.get("damage", false):
		# Landmine.hitReset awards and tries contact damage before calling inherited blast.
		for id in _actor_ids:
			var actor: Dictionary = _actors[id]
			if not actor.alive or actor.cell != bomb.cell: continue
			if id != bomb.actor_id and actor.vehicle == &"" and actor.shield == 0 and _actors.has(bomb.actor_id):
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
			if tile != null and tile in Features.WALKABLE: tile = &"floor"
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
		if _actors[id].cell == cell and _mode.bomb_hits(_actors[id].is_human): _hurt(id, owner)


func _hurt(actor_id: StringName, owner: StringName) -> void:
	var actor: Dictionary = _actors[actor_id]
	if not _rules.get("damage", false) or not actor.alive or actor.protected_until > _tick:
		return
	if actor.vehicle != &"":
		# A horse hit mid-jump stays where it was.
		actor.jump = {}
		actor.busy_until = _tick + 35
		actor.vehicle_recovery_until = _tick + 35
		actor.protected_until = _tick + 35
		actor.drive_speed = actor.speed
		actor.velocity = Vector2.ZERO
	elif actor.shield > 0:
		actor.shield -= 1
		actor.protected_until = _tick + 81
	else:
		if owner == actor_id: _mode.on_self_kill(actor)
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


## The round clock in steps: elapsed steps, or under the original clock its counted seconds
## (`pastTime`) at 35 steps each, so modes keep one time unit.
func clock_tick() -> int:
	return _past_time * 35 if _seconds.is_valid() else _tick


func _count_time() -> void:
	_clock_advanced = false
	if not _seconds.is_valid(): return
	var second: int = _seconds.call()
	if second != _past_second:
		_past_time += 1
		_past_second = second
		_clock_advanced = true


func _finish_round() -> void:
	if _round_stage == &"ending":
		# Source GameEndCartoon uses a three-second host Tween; accepted conversion freezes on pause.
		if _tick - _ending_started >= 105:
			_outcome = _pending_outcome
			_round_stage = &"settled"
			_result_score = _mode.settle(self, _outcome, _gameplay_end_tick)
			human().score = _result_score
		return
	_pending_outcome = _mode.judge(self, _judgment_ready, clock_tick())
	if _pending_outcome != &"":
		_round_stage = &"ending"
		_ending_started = _tick
		_gameplay_end_tick = clock_tick()
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
				if _mode.name != &"arcade": _scatter(actor)
				var delay: int = _mode.respawn_ticks(actor.is_human)
				if delay >= 0: actor.respawn_at = _tick + delay
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
	var timed_count: int = _mode.timed_pickup_count(clock_tick()) if _clock_advanced or not _seconds.is_valid() else 0
	if timed_count > 0: spawn_random_pickups(timed_count)
	for actor in _actors.values():
		if actor.alive and actor.transit_until == 0 and actor.action_started_tick != _tick and _pickups.has(actor.cell):
			var kind: StringName = _pickups[actor.cell]
			if not _mode.can_collect(actor.is_human, kind):
				continue
			var weapon: bool = kind in [&"landmine", &"hammer", &"flamer", &"laser", &"triple", &"shotgun"]
			if weapon:
				_weapons.cancel(actor, _actors.find_key(actor))
			var before := [actor.capacity, actor.power, actor.speed]
			Pickups.apply(actor, kind, _tick, _mode.invincibility_ticks())
			if kind in [&"capacity", &"power", &"speed"] and [actor.capacity, actor.power, actor.speed] != before:
				actor.collected.append(kind)
			if weapon and _mode.keeps_weapon_pickups():
				actor.kept_weapons.append(kind)
			_pickups.erase(actor.cell)
			_mode.pickup_removed(self, kind, _actors.find_key(actor))
	for id in _actor_ids:
		if _actors[id].alive and _actors[id].invincible_until > _tick and _actors[id].invincible_active_from <= _tick:
			for other in _actor_ids:
				if other != id and _actors[other].cell == _actors[id].cell:
					_hurt(other, id)


## Map.createRamdonProp: choose every cell first, then draw each pickup's class.
func spawn_random_pickups(count: int) -> void:
	var free := _free_cells()
	var selected_cells: Array[Vector2i] = []
	for index in mini(count, free.size()):
		var selected := int(_draw_random() * free.size())
		selected_cells.append(free[selected])
		free.remove_at(selected)
	for cell in selected_cells: _spawn_pickup(cell, false)


## Mode hooks reach the live actors, the board, controlled draws and free cells here.
func actors() -> Dictionary:
	return _actors


func board() -> Dictionary:
	return _board


func draw_random() -> float:
	return _draw_random()


func free_cells(margin: int = 0) -> Array[Vector2i]:
	return _free_cells().filter(func(cell: Vector2i):
		# containerMove(map, m, m, m, m): x in 1+m .. width-1-m, y likewise.
		return cell.x > margin and cell.y > margin and cell.x <= _board_max.x - margin and cell.y <= _board_max.y - margin)


func pickups() -> Dictionary:
	return _pickups


## A pickup drawn from the mode's pool onto a cell (Pac-Man's quadrant items).
func place_drawn_pickup(cell: Vector2i) -> void:
	_spawn_pickup(cell, false)


func bombs() -> Array[Dictionary]:
	return _bombs


func mode() -> RefCounted:
	return _mode


## An ownerless or feature-made bomb enters the map with its fuse running.
func add_bomb(bomb: Dictionary) -> void:
	bomb.merge({"born": _tick, "age": 0, "blasted": false, "previous_cell": Vector2i.ZERO}, false)
	_bombs.append(bomb)
	_countdowns.append(bomb)


## `Bomb.disappear`: removed without exploding; a robot owner gets its bomb back.
func vanish_bomb(bomb: Dictionary) -> void:
	_bombs.erase(bomb)
	_countdowns.erase(bomb)
	if _actors.has(bomb.actor_id): _actors[bomb.actor_id].bomb_count -= 1


## `Bomb.startFly`: off the map with its fuse paused until it lands.
func throw_bomb(bomb: Dictionary, direction: Vector2i, speed: float) -> void:
	bomb.flying = true
	bomb.fly_direction = direction
	bomb.fly_speed = speed
	bomb.fly_position = Vector2(bomb.cell)
	bomb.erase("belt_position")


## A random class from the mode's pickup pool (`game.mapPropArr`), vehicles uncapped.
func random_pool_kind() -> StringName:
	var kind: StringName = &"reserved_boxing"
	while kind in [&"reserved_kick", &"reserved_boxing"]:
		kind = _drop_pool[int(_draw_random() * _drop_pool.size())]
	return kind


func can_stand(position_at: Vector2, actor: Dictionary) -> bool:
	return Movement.can_stand(position_at, actor, _board, _bombs)


## Crocodile `eat`: bombs on the cell detonate, its pickup goes, robots on it are hurt.
func eat_cell(cell: Vector2i) -> void:
	for bomb in _bombs.duplicate():
		if bomb.cell == cell and not bomb.get("detonated", false): _detonate(bomb, _current_blasts, _current_broken)
	if _pickups.has(cell):
		var kind: StringName = _pickups[cell]
		_pickups.erase(cell)
		_mode.pickup_removed(self, kind, &"")
	for id in _actor_ids:
		if _actors[id].alive and _actors[id].cell == cell: _hurt(id, &"")


## `Map.getAllEmptyPosition`: no box, bomb, belt, arm, pickup or robot.
func empty_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for x in range(1, _board_max.x + 1):
		for y in range(1, _board_max.y + 1):
			var cell := Vector2i(x, y)
			if _board.get(cell) not in [&"floor", &"portal", &"crocodile"] or _feature_blocked(cell) or _pickups.has(cell): continue
			if _bombs.any(func(b): return b.cell == cell): continue
			if _actors.values().any(func(a): return a.alive and a.cell == cell): continue
			result.append(cell)
	return result


func _feature_blocked(cell: Vector2i) -> bool:
	return _board.get(cell) == &"belt" or _features.any(func(feature): return cell in feature.blocked_cells())


func _advance_flying() -> void:
	for bomb in _bombs:
		if not bomb.get("flying", false): continue
		var at: Vector2 = bomb.fly_position
		var aligned := at.is_equal_approx(at.round())
		var ahead: Vector2i = Vector2i(at.round()) + bomb.fly_direction
		if aligned and (not _board.has(ahead) or _board[ahead] not in [&"floor", &"portal", &"belt", &"crocodile"] \
				or _bombs.any(func(other): return other != bomb and other.cell == ahead and other.get("kind") != &"mine" and not other.get("flying", false))):
			bomb.flying = false
			bomb.cell = Vector2i(at.round())
			bomb.erase("fly_position")
			continue
		bomb.fly_position = at + Vector2(bomb.fly_direction) * bomb.fly_speed
		bomb.cell = Vector2i(-100, -100)


## PushRobotCommand: no control; on entering a cell holding a box or bomb, stop and snap
## back to the previous cell along the push axis.
func _advance_push(actor: Dictionary) -> void:
	var direction: Vector2i = actor.pushed.direction
	var before := Vector2i(floori(actor.position.x + 0.5), floori(actor.position.y + 0.5))
	var moved: Vector2 = (actor.position + Vector2(direction) * actor.pushed.speed).clamp(Vector2.ZERO, Vector2(_board_max))
	var cell := Vector2i(floori(moved.x + 0.5), floori(moved.y + 0.5))
	actor.velocity = Vector2.ZERO
	if cell != before and (_board.get(cell) in [&"solid", &"soft"] or _bombs.any(func(b): return b.cell == cell and b.get("kind") != &"mine")):
		if direction.x != 0: moved.x = before.x
		else: moved.y = before.y
		actor.pushed = {}
	actor.position = moved


## HorseProp/DragonProp `hitHandleArr`: fires while pushing flush into a blocked cell ahead.
func _ride_contact(actor: Dictionary, direction: Vector2) -> void:
	if direction == Vector2.ZERO or (direction.x != 0 and direction.y != 0): return
	var step := Vector2i(int(signf(direction.x)), int(signf(direction.y)))
	var here := Vector2i(floori(actor.position.x + 0.5), floori(actor.position.y + 0.5))
	var ahead := here + step
	var flush := absf(actor.position.x - here.x) < 0.01 if step.x != 0 else absf(actor.position.y - here.y) < 0.01
	if not flush or Movement.can_stand(Vector2(ahead), actor, _board, _bombs): return
	var bomb_ahead := _bombs.any(func(b): return b.cell == ahead and b.get("kind") != &"mine")
	if not bomb_ahead and _board.get(ahead) in [&"floor", &"portal", &"belt", &"crocodile"]: return
	if actor.vehicle == &"horse":
		var landing := ahead + step
		if not _board.has(landing) or _board[landing] in [&"solid", &"soft"] or landing.x < 0 or landing.y < 0 \
				or landing.x > 16 or landing.y > 14 or _bombs.any(func(b): return b.cell == landing):
			return
		actor.jump = {"target": Vector2(landing), "step": step}
		actor.velocity = Vector2.ZERO
	elif not bomb_ahead and _board.get(ahead) == &"soft":
		# Dragon crash: break the box, score it, stop 17 ticks.
		_board[ahead] = &"floor"
		_current_broken.append(ahead)
		actor.score += 10
		_pending_drops.append({"cell": ahead, "born": _tick, "frame": 0})
		actor.busy_until = _tick + 18
		actor.velocity = Vector2.ZERO


## The horse jump: 60 px at 4 px per tick along the push axis, 1 px per tick across.
func _advance_jump(actor: Dictionary) -> void:
	var target: Vector2 = actor.jump.target
	var step: Vector2i = actor.jump.step
	var at: Vector2 = actor.position
	if step.x != 0:
		at.x = move_toward(at.x, target.x, HORSE_JUMP_SPEED)
		if absf(at.y - target.y) > 1.0 / 30.0: at.y += signf(target.y - at.y) / 30.0
	else:
		at.y = move_toward(at.y, target.y, HORSE_JUMP_SPEED)
		if absf(at.x - target.x) > 1.0 / 30.0: at.x += signf(target.x - at.x) / 30.0
	actor.position = at
	if (step.x != 0 and at.x == target.x) or (step.y != 0 and at.y == target.y): actor.jump = {}


func current_tick() -> int:
	return _tick


## Empty cells for placed pickups, x first then y as the source enumerates them.
func _free_cells() -> Array[Vector2i]:
	var free: Array[Vector2i] = []
	for x in range(1, _board_max.x + 1):
		for y in range(1, _board_max.y + 1):
			var cell := Vector2i(x, y)
			if _board.get(cell) in [&"floor", &"portal", &"crocodile"] and not _feature_blocked(cell) and not _pickups.has(cell) and not _bombs.any(func(b): return b.cell == cell) and not _actors.values().any(func(a): return a.alive and a.cell == cell):
				free.append(cell)
	return free


## RobotDeadCommand.spitProp: every collected power-up, then up to two kept weapons,
## each onto a random free cell.
func _scatter(actor: Dictionary) -> void:
	for kind in actor.collected:
		var free := _free_cells()
		if not free.is_empty(): _pickups[free[int(_draw_random() * free.size())]] = kind
	for attempt in 2:
		if actor.kept_weapons.is_empty(): break
		var index := int(_draw_random() * actor.kept_weapons.size())
		var free := _free_cells()
		if free.is_empty(): continue
		_pickups[free[int(_draw_random() * free.size())]] = actor.kept_weapons[index]
		actor.kept_weapons.remove_at(index)
	actor.collected = []


## ReliveThread → robotRelive: back at the spawn with fresh stats, the base action and
## InvincibilityCommand's 81 ticks of protection.
func _advance_respawns() -> void:
	for id in _actor_ids:
		var actor: Dictionary = _actors[id]
		if not actor.removed or actor.respawn_at <= 0 or _tick < actor.respawn_at: continue
		actor.merge(actor.base_stats, true)
		actor.merge({"alive": true, "removed": false, "death_frame": 0, "model_state": &"normal",
			"registered_state": &"normal", "cell": actor.spawn, "position": Vector2(actor.spawn),
			"velocity": Vector2.ZERO, "facing": Vector2.DOWN, "departures": [], "vehicle": &"", "pushed": {}, "jump": {},
			"registered_vehicle": &"", "shield": 0, "invincible_until": 0, "busy_until": 0,
			"transit_until": 0, "vehicle_recovery_until": 0, "protected_until": _tick + 81,
			"blink_until": _tick + 81, "weapon": actor.base_weapon, "ammo": -1 if actor.base_weapon != &"" else 0,
			"kept_weapons": [], "respawn_at": 0, "portal_latch": Vector2i(-99, -99), "movement_rearm": true}, true)
		actor.drive_speed = actor.speed


func _spawn_pickup(cell: Vector2i, quota: bool) -> void:
	var kind: StringName = _drop_pool[int(_draw_random() * _drop_pool.size())]
	if quota and kind in CAPPED_VEHICLES:
		if _vehicles_left <= 0:
			var index := 0
			while index < _drop_pool.size():
				if _drop_pool[index] in CAPPED_VEHICLES:
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
		if _actors.has(owner): _actors[owner].score += 10
		_pending_drops.append({"cell": target, "born": _tick, "frame": 0})
	elif hit_items:
		for bomb in _bombs.duplicate():
			if bomb.cell == target and _bombs.has(bomb):
				_detonate(bomb, blasts, broken)
		if _pickups.has(target) and _mode.destroys_pickups():
			var removed: StringName = _pickups[target]
			_pickups.erase(target)
			_mode.pickup_removed(self, removed, &"")
	for id in _actor_ids:
		if damage and id != owner and _actors[id].cell == target and _mode.bomb_hits(_actors[id].is_human):
			_hurt(id, owner)

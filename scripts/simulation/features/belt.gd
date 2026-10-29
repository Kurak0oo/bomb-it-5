extends RefCounted
const Movement = preload("res://scripts/simulation/movement.gd")
## Candy Factory candy machine and conveyor belt (`ConveyorBelt.as`); see edition-5-candy-factory.md.
## Positions are in cells (30 px); the belt moves 1 px per tick.

const SPEED := 1.0 / 30.0
const BUILD_DELAY := 210
## `[pickup, bomb, box]` by difficulty; Kill and Green Zone only make pickups.
const PROBS := {&"easy": [0.55, 0.45, 0.0], &"normal": [0.45, 0.55, 0.0], &"hard": [0.4, 0.6, 0.0]}
const POWER := {&"easy": 1, &"normal": 2, &"hard": 3}

var track: Array[Vector2i] = []
var flow: Array[Vector2i] = []
var exit_cell := Vector2i.ZERO
var move_time := 0
var total_frame := 0
var spawn_pending := false
var probs: Array = []
var power := 2
## Fractional positions of carried pickups, keyed by their current cell.
var prop_positions := {}


func _init(cells: Dictionary, center: Vector2i, mode: RefCounted) -> void:
	var ordered := cells.keys()
	ordered.sort_custom(func(a, b): return int(cells[a]) < int(cells[b]))
	track.assign(ordered)
	for index in track.size():
		flow.append(Vector2i.DOWN if index == 0 else track[index] - track[index - 1])
	exit_cell = center + Vector2i(1, 3)
	move_time = track.size() * 30
	probs = [1.0, 0.0, 0.0] if mode.name in [&"kill", &"green_zone"] else PROBS.get(mode.difficulty, PROBS[&"normal"])
	power = POWER.get(mode.difficulty, 2)


func advance(round_state: RefCounted, inputs: Dictionary) -> void:
	if track.is_empty(): return
	if spawn_pending and not _exit_occupied(round_state):
		_spawn(round_state)
		spawn_pending = false
		total_frame = 0
	total_frame += 1
	if total_frame % BUILD_DELAY == 0:
		total_frame -= BUILD_DELAY
		if _exit_occupied(round_state): spawn_pending = true
		else: _spawn(round_state)
	var last := track.size() - 1
	for index in track.size():
		var cell := track[index]
		var along := flow[index]
		# flowArr[0] is (cos(pi/2), sin(pi/2)): never exactly equal to its successor, so the
		# exit cell counts as a corner, yet its near-zero x means no corner alignment.
		var corner := index == 0 or (index < last and flow[index + 1] != along)
		var velocity := Vector2(along) * SPEED
		if corner and index > 0:
			velocity = Vector2(along + flow[index + 1]).normalized() * SPEED
		var align: Vector2i = along if index > 0 else Vector2i.ZERO
		for bomb in round_state.bombs().duplicate():
			if bomb.cell != cell or bomb.get("flying", false): continue
			if index == last:
				round_state.vanish_bomb(bomb)
				continue
			var at: Vector2 = bomb.get("belt_position", Vector2(cell))
			at += _clamped(velocity, at, cell, align) if corner else velocity
			bomb.belt_position = _display(round_state, at)
			at = bomb.belt_position
			bomb.cell = Vector2i(floori(at.x + 0.5), floori(at.y + 0.5))
		if round_state.pickups().has(cell):
			var kind: StringName = round_state.pickups()[cell]
			var at: Vector2 = prop_positions.get(cell, Vector2(cell))
			prop_positions.erase(cell)
			round_state.pickups().erase(cell)
			if index == last:
				round_state.mode().pickup_removed(round_state, kind, &"")
			else:
				at = _display(round_state, at + (_clamped(velocity, at, cell, align) if corner else velocity))
				var landed := Vector2i(floori(at.x + 0.5), floori(at.y + 0.5))
				round_state.pickups()[landed] = kind
				prop_positions[landed] = at
		for id in round_state.actors():
			var actor: Dictionary = round_state.actors()[id]
			if not actor.alive or actor.cell != cell or actor.get("pushed", {}).size() > 0: continue
			var held: Vector2 = inputs.get(id, Vector2.ZERO)
			var offset := velocity
			if held == Vector2.ZERO:
				if corner: offset = _clamped(velocity, actor.position, cell, align)
			elif corner:
				offset = Vector2.ZERO
			else:
				var axis := Vector2i(int(signf(held.x)), 0) if absf(held.x) > absf(held.y) else Vector2i(0, int(signf(held.y)))
				if axis.x * along.x + axis.y * along.y == 0: offset = Vector2.ZERO
			_push_robot(round_state, actor, offset)


## modifyOffest: the incoming-axis step never passes the corner cell's aligned coordinate.
func _clamped(velocity: Vector2, at: Vector2, cell: Vector2i, along: Vector2i) -> Vector2:
	var result := velocity
	if along.x == 0 and along.y != 0:
		var limit := float(cell.y)
		if (along.y > 0 and at.y >= limit) or (along.y < 0 and at.y <= limit): result.y = 0.0
		elif (along.y > 0 and at.y + result.y > limit) or (along.y < 0 and at.y + result.y < limit): result.y = limit - at.y
	elif along.y == 0 and along.x != 0:
		var limit := float(cell.x)
		if (along.x > 0 and at.x >= limit) or (along.x < 0 and at.x <= limit): result.x = 0.0
		elif (along.x > 0 and at.x + result.x > limit) or (along.x < 0 and at.x + result.x < limit): result.x = limit - at.x
	return result


## robotMove: horizontal pushes use the normal look-ahead; vertical ones test the cell
## being left (`upAfoul`/`downAfoul` swapped), so nothing ahead stops them.
func _push_robot(round_state: RefCounted, actor: Dictionary, offset: Vector2) -> void:
	if round_state.original_movement():
		# The original calls the robot's own `HitMove`, with the vertical pair swapped.
		var at := Movement.pixels(actor)
		var px := offset * Movement.GRID
		if px.x != 0.0: at = Movement._afoul(at, 0, px.x > 0, px.x, round_state.board(), round_state.bombs())
		if px.y != 0.0: at = Movement._afoul(at, 1, px.y < 0, px.y, round_state.board(), round_state.bombs())
		Movement.set_pixels(actor, at)
		return
	if offset.x != 0.0:
		var moved: Vector2 = actor.position + Vector2(offset.x, 0)
		if round_state.can_stand(moved, actor): actor.position = moved
	if offset.y != 0.0:
		actor.position += Vector2(0, offset.y)


## Carried bombs and pickups move their display position (`xPos += offset`), which Flash
## keeps in whole twips under the original movement.
func _display(round_state: RefCounted, at: Vector2) -> Vector2:
	if not round_state.original_movement(): return at
	var px := at * Movement.GRID
	px = Movement._twips(Movement._twips(px, 0, px.x, 1e-3), 1, px.y, 1e-3)
	return px / Movement.GRID


func _exit_occupied(round_state: RefCounted) -> bool:
	return round_state.actors().values().any(func(a): return a.alive and a.cell == exit_cell) \
		or round_state.bombs().any(func(b): return b.cell == exit_cell)


## createRandomItem: a pickup from the mode's pool or a long-fused ownerless bomb.
func _spawn(round_state: RefCounted) -> void:
	var draw: float = round_state.draw_random()
	if draw < probs[0]:
		round_state.pickups()[exit_cell] = round_state.random_pool_kind()
		prop_positions[exit_cell] = Vector2(exit_cell)
	elif draw < probs[0] + probs[1]:
		var fuse := int(round_state.draw_random() * move_time)
		round_state.add_bomb({"actor_id": &"", "cell": exit_cell, "power": power, "fuse": fuse,
			"belt_position": Vector2(exit_cell)})


## The belt's cells are `belt` board cells, which the round already treats as blocked.
func blocked_cells() -> Array[Vector2i]:
	return []


func public_state() -> Dictionary:
	return {"kind": &"belt", "track": track, "flow": flow, "exit": exit_cell, "next_spawn": BUILD_DELAY - total_frame}

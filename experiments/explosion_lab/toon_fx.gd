extends Node2D
## Explosion lab: cartoon puffs and each robot's signature burst, drawn by hand so they
## keep clean shapes and outlines (particle sprites read as realistic smoke and embers,
## which is not the original's look). A blast throws four pieces of its robot's
## signature, each moving in that robot's own way (README, "Bomb profiles"). Totals are
## capped, so a long chain never fills the screen.

const BombStyles = preload("res://experiments/explosion_lab/bomb_styles.gd")
const ToonDraw = preload("res://experiments/explosion_lab/toon_draw.gd")
const MAX_ITEMS := 20
const MAX_PUFFS := 30
## Fake-height gravity, in cells per second squared (same feel as debris.gd).
const GRAVITY_CELLS := 23.0

var _puffs: Array[Dictionary] = []
var _items: Array[Dictionary] = []
var _cell := 48.0


func puffs(origin: Vector2, count: int, cell: float, fill: Color, line: Color) -> void:
	for index in mini(count, MAX_PUFFS - _puffs.size()):
		var direction := Vector2.from_angle(randf() * TAU)
		_puffs.append({
			"pos": origin + direction * randf_range(0.05, 0.3) * cell,
			"vel": direction * randf_range(10.0, 45.0) + Vector2(0, -randf_range(15.0, 40.0)),
			"radius": randf_range(0.16, 0.28) * cell, "life": randf_range(0.4, 0.6), "age": -index * 0.02,
			"fill": fill, "line": line,
		})


## Four pieces of `robot`'s signature (Violet adds its spell ring). Skipped whole when
## the screen already has enough, so a burst is never cut in half.
func signature(origin: Vector2, robot: int, reach: int, cell: float) -> void:
	_cell = cell
	var style := BombStyles.style(robot)
	var fx: StringName = style.fx
	var count := 5 if fx == &"twinkle" else 4
	if _items.size() + count > MAX_ITEMS:
		return
	var fill: Color = style.mid.lerp(style.hot, 0.35)
	var line: Color = style.rim
	if fx == &"twinkle":
		var ring := _item(origin, Vector2.ZERO, &"rune", 0.4, fill, line)
		ring.size = 0.4 * cell
		_items.append(ring)
	var phase := randf() * TAU
	for index in 4:
		var direction := Vector2.from_angle(phase + index * TAU / 4.0)
		var item := _item(origin + direction * 0.4 * cell, direction * 4.6 * cell, fx, 0.42, fill, line)
		match fx:
			&"bolt":
				# Short sharp crackles on the diagonals, gone in a blink.
				direction = Vector2.from_angle(PI / 4.0 + index * PI / 2.0)
				item.pos = origin + direction * 0.45 * cell
				item.vel = direction * 7.5 * cell
				item.rot = direction.angle()
				item.life = 0.24
				item.drag = 9.0
			&"note":
				# Notes float up off the beat and sway, one after another.
				item.pos = origin + Vector2((index - 1.5) * 0.36, -0.25) * cell
				item.vel = Vector2(0, -1.5 * cell)
				item.sway = 0.16 * cell
				item.life = 0.8
				item.age = -index * 0.07
				item.drag = 0.0
				item.flip = index % 2 == 1
			&"drop":
				# Goo arcs up, lands and splats flat.
				item.vel = direction * 1.6 * cell
				item.z = 0.2 * cell
				item.vz = 5.5 * cell
				item.gravity = true
				item.life = 0.8
				item.drag = 0.0
			&"twinkle":
				# Twinkles spiral out of the spell ring.
				item.vel = direction * 2.6 * cell
				item.curl = 4.0
				item.life = 0.45
				item.drag = 3.0
			&"nut":
				# Nuts and bolts are thrown up, clatter twice and lie still.
				item.vel = direction * 1.8 * cell
				item.z = 0.3 * cell
				item.vz = 4.6 * cell
				item.gravity = true
				item.bounce = 0.45
				item.spin = randf_range(-14.0, 14.0)
				item.life = 0.9
				item.drag = 0.0
			&"leaf":
				# Leaves start high and drift down slowly, rocking as they fall.
				item.pos = origin + direction * 0.3 * cell
				item.vel = direction * 0.7 * cell
				item.z = 0.9 * cell
				item.fall = 0.9 * cell
				item.sway = 0.22 * cell
				item.life = 1.1
				item.drag = 1.5
				item.age = -index * 0.05
			&"streak":
				# Speed lines shoot on along the four rays, past the tips.
				direction = Vector2.from_angle(index * PI / 2.0)
				item.pos = origin + direction * (reach + 0.4) * cell
				item.vel = direction * 9.0 * cell
				item.rot = direction.angle()
				item.life = 0.22
				item.drag = 4.0
		_items.append(item)


func clear() -> void:
	_puffs.clear()
	_items.clear()


func _item(pos: Vector2, vel: Vector2, mode: StringName, life: float, fill: Color, line: Color) -> Dictionary:
	return {"pos": pos, "vel": vel, "mode": mode, "life": life, "age": -0.05, "fill": fill, "line": line,
		"size": 0.17 * _cell, "rot": randf_range(-0.4, 0.4), "spin": randf_range(-2.5, 2.5), "drag": 7.0,
		"z": 0.0, "vz": 0.0, "gravity": false, "bounce": 0.0, "landed": -1.0, "curl": 0.0,
		"sway": 0.0, "fall": 0.0, "flip": false}


func _process(delta: float) -> void:
	var index := 0
	while index < _puffs.size():
		var puff: Dictionary = _puffs[index]
		puff.age += delta
		if puff.age >= puff.life:
			_puffs.remove_at(index)
			continue
		if puff.age > 0.0:
			puff.pos += puff.vel * delta
			puff.vel *= maxf(0.0, 1.0 - delta * 4.0)
		index += 1
	index = 0
	while index < _items.size():
		var item: Dictionary = _items[index]
		item.age += delta
		if item.age >= item.life:
			_items.remove_at(index)
			continue
		if item.age > 0.0:
			_move(item, delta)
		index += 1
	queue_redraw()


func _move(item: Dictionary, delta: float) -> void:
	if item.curl != 0.0:
		item.vel = item.vel.rotated(item.curl * delta)
	item.vel *= maxf(0.0, 1.0 - delta * item.drag)
	item.pos += item.vel * delta
	item.rot += item.spin * delta
	if item.gravity:
		item.vz -= GRAVITY_CELLS * _cell * delta
		item.z += item.vz * delta
		if item.z <= 0.0:
			item.z = 0.0
			if item.bounce > 0.0 and absf(item.vz) > 1.2 * _cell:
				item.vz = -item.vz * item.bounce
				item.vel *= 0.6
				item.spin *= 0.6
			else:
				item.vz = 0.0
				item.gravity = false
				item.vel = Vector2.ZERO
				item.spin = 0.0
				if item.landed < 0.0:
					item.landed = item.age
	if item.fall > 0.0:
		item.z = maxf(item.z - item.fall * delta, 0.0)
		item.rot = 0.6 * sin(item.age * 7.0)


func _draw() -> void:
	# Outlines first, fills second: overlapping puffs merge into one cloud.
	for pass_index in 2:
		for puff in _puffs:
			var radius := _puff_radius(puff)
			if radius <= 0.5:
				continue
			if pass_index == 0:
				draw_circle(puff.pos, radius + 2.0, puff.line, true, -1.0, true)
			else:
				draw_circle(puff.pos, radius, puff.fill, true, -1.0, true)
				draw_circle(puff.pos + Vector2(-0.3, -0.3) * radius, radius * 0.35, Color.WHITE, true, -1.0, true)
	for item in _items:
		if item.age > 0.0:
			_draw_item(item)
	draw_set_transform(Vector2.ZERO)


func _draw_item(item: Dictionary) -> void:
	var life: float = item.age / item.life
	var size: float = item.size * minf(life / 0.12, 1.0) * (1.0 - smoothstep(0.6, 1.0, life))
	if size <= 1.0:
		return
	var ground: Vector2 = item.pos
	if item.sway > 0.0:
		ground.x += sin(item.age * 9.0) * item.sway
	var lifted: Vector2 = ground - Vector2(0.0, item.z)
	if item.z > 0.0 or item.fall > 0.0:
		draw_set_transform(ground, 0.0, Vector2(1.0, 0.4))
		draw_circle(Vector2.ZERO, size * 0.6, Color(0.16, 0.0, 0.2, 0.25), true, -1.0, true)
	match item.mode:
		&"drop":
			if item.landed >= 0.0:
				# Splat: a flat puddle that spreads, then shrinks away.
				var spread := minf((item.age - item.landed) / 0.08, 1.0)
				draw_set_transform(ground, 0.0, Vector2(1.0 + 0.5 * spread, 0.38))
				draw_circle(Vector2.ZERO, size + 2.0, item.line, true, -1.0, true)
				draw_circle(Vector2.ZERO, size, item.fill, true, -1.0, true)
				return
			draw_set_transform(lifted, 0.0, Vector2.ONE)
			BombStyles.draw_shape(self, &"drop", Vector2.ZERO, size, item.fill, item.line)
		&"bolt":
			draw_set_transform(lifted, item.rot, Vector2.ONE)
			var zag := PackedVector2Array([Vector2(-size, 0), Vector2(-0.25 * size, -0.4 * size),
				Vector2(0.25 * size, 0.4 * size), Vector2(size, 0)])
			draw_polyline(zag, item.line, 6.0, true)
			draw_polyline(zag, item.fill, 2.5, true)
		&"note":
			draw_set_transform(lifted, 0.0, Vector2(-1.0 if item.flip else 1.0, 1.0))
			_draw_note(size, item.fill, item.line)
		&"streak":
			draw_set_transform(lifted, item.rot, Vector2.ONE)
			var length := _cell * 0.9 * (1.0 - smoothstep(0.5, 1.0, life))
			draw_line(Vector2(-length, 0), Vector2.ZERO, item.line, 5.0, true)
			draw_line(Vector2(-length * 0.8, 0), Vector2.ZERO, item.fill, 2.0, true)
		&"rune":
			# The spell ring: a thin circle with four marks, turning as it widens.
			draw_set_transform(lifted, life * 3.0, Vector2(1.0, 0.85))
			var radius: float = item.size * (1.0 + 2.2 * life)
			var fade := Color(item.line, 1.0 - life)
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, fade, 3.0, true)
			draw_arc(Vector2.ZERO, radius * 0.82, 0.0, TAU, 48, Color(item.fill, 1.0 - life), 1.5, true)
			for mark in 4:
				ToonDraw.polygon(self, ToonDraw.star(Vector2.from_angle(mark * PI / 2.0) * radius, 0.09 * _cell, 4, 0.4, 0.0), fade)
		_:
			draw_set_transform(lifted, item.rot, Vector2.ONE)
			BombStyles.draw_shape(self, item.mode, Vector2.ZERO, size, item.fill, item.line)


## A quaver: round head, stem and flag, outlined.
func _draw_note(size: float, fill: Color, line: Color) -> void:
	var head := Vector2(-0.15 * size, 0.45 * size)
	var flag := PackedVector2Array([Vector2(0.2 * size, -0.95 * size), Vector2(0.75 * size, -0.55 * size),
		Vector2(0.7 * size, -0.2 * size), Vector2(0.2 * size, -0.5 * size)])
	for pass_index in 2:
		var grow := 2.0 if pass_index == 0 else 0.0
		var colour := line if pass_index == 0 else fill
		draw_line(Vector2(0.2 * size, 0.45 * size), Vector2(0.2 * size, -0.95 * size), colour, 0.2 * size + grow * 2.0, true)
		draw_circle(head, 0.38 * size + grow, colour, true, -1.0, true)
		if pass_index == 0:
			var outline := PackedVector2Array()
			var middle := Vector2(0.45 * size, -0.55 * size)
			for point in flag:
				outline.append(point + (point - middle).normalized() * grow)
			ToonDraw.polygon(self, outline, colour)
		else:
			ToonDraw.polygon(self, flag, colour)


func _puff_radius(puff: Dictionary) -> float:
	if puff.age <= 0.0:
		return 0.0
	var life: float = puff.age / puff.life
	# Pop out past full size, settle, then shrink away to nothing.
	var grow := minf(life / 0.25, 1.0)
	var overshoot := 1.0 + 0.25 * sin(grow * PI)
	return puff.radius * grow * overshoot * (1.0 - smoothstep(0.55, 1.0, life))

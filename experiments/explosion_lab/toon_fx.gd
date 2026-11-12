extends Node2D
## Explosion lab: cartoon puffs and sparkles, drawn by hand so they keep clean shapes
## and outlines (particle sprites read as realistic smoke and embers, which is not the
## original's look).

const ToonDraw = preload("res://experiments/explosion_lab/toon_draw.gd")
const PUFF_FILL := Color("fff7df")
const PUFF_LINE := Color("e2b27a")
const STAR_FILL := Color("fff066")
const STAR_LINE := Color("ff9a1a")
const GRAVITY := 520.0

var _puffs: Array[Dictionary] = []
var _stars: Array[Dictionary] = []


func puffs(origin: Vector2, count: int, cell: float) -> void:
	for index in count:
		var direction := Vector2.from_angle(randf() * TAU)
		_puffs.append({
			"pos": origin + direction * randf_range(0.05, 0.3) * cell,
			"vel": direction * randf_range(10.0, 45.0) + Vector2(0, -randf_range(15.0, 40.0)),
			"radius": randf_range(0.16, 0.3) * cell, "life": randf_range(0.4, 0.65), "age": -index * 0.02,
		})


func sparkles(origin: Vector2, count: int, cell: float) -> void:
	for index in count:
		var direction := Vector2.from_angle(randf_range(-PI, 0.0))
		_stars.append({
			"pos": origin + Vector2(randf_range(-0.25, 0.25), randf_range(-0.25, 0.25)) * cell,
			"vel": direction * randf_range(120.0, 330.0) + Vector2(randf_range(-60.0, 60.0), 0),
			"size": randf_range(0.14, 0.24) * cell, "rot": randf() * TAU, "spin": randf_range(-9.0, 9.0),
			"life": randf_range(0.45, 0.75), "age": -randf_range(0.03, 0.09),
		})


func clear() -> void:
	_puffs.clear()
	_stars.clear()


func _process(delta: float) -> void:
	for list in [_puffs, _stars]:
		var index := 0
		while index < list.size():
			var item: Dictionary = list[index]
			item.age += delta
			if item.age >= item.life:
				list.remove_at(index)
				continue
			if item.age > 0.0:
				item.pos += item.vel * delta
			index += 1
	for puff in _puffs:
		puff.vel *= maxf(0.0, 1.0 - delta * 4.0)
	for star in _stars:
		if star.age <= 0.0:
			continue
		# Launched upward against gravity: stars arc and fall back (fake height).
		star.vel.y += GRAVITY * delta
		star.rot += star.spin * delta
	queue_redraw()


func _draw() -> void:
	# Outlines first, fills second: overlapping puffs merge into one cloud.
	for pass_index in 2:
		for puff in _puffs:
			var radius := _puff_radius(puff)
			if radius <= 0.5:
				continue
			if pass_index == 0:
				draw_circle(puff.pos, radius + 2.0, PUFF_LINE, true, -1.0, true)
			else:
				draw_circle(puff.pos, radius, PUFF_FILL, true, -1.0, true)
				draw_circle(puff.pos + Vector2(-0.3, -0.3) * radius, radius * 0.35, Color.WHITE, true, -1.0, true)
	for star in _stars:
		if star.age <= 0.0:
			continue
		var life: float = star.age / star.life
		var size: float = star.size * (1.0 - smoothstep(0.5, 1.0, life)) * minf(life / 0.1, 1.0)
		if size <= 0.5:
			continue
		draw_set_transform(star.pos, star.rot, Vector2.ONE)
		ToonDraw.polygon(self, ToonDraw.star(Vector2.ZERO, size + 2.5, 4, 0.42, 0.0), STAR_LINE)
		ToonDraw.polygon(self, ToonDraw.star(Vector2.ZERO, size, 4, 0.38, 0.0), STAR_FILL)
		draw_circle(Vector2.ZERO, size * 0.28, Color.WHITE, true, -1.0, true)
	draw_set_transform(Vector2.ZERO)


func _puff_radius(puff: Dictionary) -> float:
	if puff.age <= 0.0:
		return 0.0
	var life: float = puff.age / puff.life
	# Pop out past full size, settle, then shrink away to nothing.
	var grow := minf(life / 0.25, 1.0)
	var overshoot := 1.0 + 0.25 * sin(grow * PI)
	return puff.radius * grow * overshoot * (1.0 - smoothstep(0.55, 1.0, life))


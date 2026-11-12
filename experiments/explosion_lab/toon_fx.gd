extends Node2D
## Explosion lab: cartoon puffs and sparkles, drawn by hand so they keep clean shapes
## and outlines (particle sprites read as realistic smoke and embers, which is not the
## original's look). Each blast throws one small ring of its robot's shape; the totals
## are capped, so a long chain never fills the screen with them.

const BombStyles = preload("res://experiments/explosion_lab/bomb_styles.gd")
const MAX_SPARKLES := 20
const MAX_PUFFS := 30

var _puffs: Array[Dictionary] = []
var _sparkles: Array[Dictionary] = []


func puffs(origin: Vector2, count: int, cell: float, fill: Color, line: Color) -> void:
	for index in mini(count, MAX_PUFFS - _puffs.size()):
		var direction := Vector2.from_angle(randf() * TAU)
		_puffs.append({
			"pos": origin + direction * randf_range(0.05, 0.3) * cell,
			"vel": direction * randf_range(10.0, 45.0) + Vector2(0, -randf_range(15.0, 40.0)),
			"radius": randf_range(0.16, 0.28) * cell, "life": randf_range(0.4, 0.6), "age": -index * 0.02,
			"fill": fill, "line": line,
		})


## One ring of `count` shapes, evenly spaced, that fly out about a cell and a half,
## slow down and shrink away. Skipped whole when the screen already has enough.
func sparkles(origin: Vector2, count: int, cell: float, shape: StringName, fill: Color, line: Color) -> void:
	if _sparkles.size() + count > MAX_SPARKLES:
		return
	var phase := randf() * TAU
	for index in count:
		var direction := Vector2.from_angle(phase + index * TAU / count)
		_sparkles.append({
			"pos": origin + direction * 0.4 * cell, "vel": direction * 4.6 * cell,
			"size": 0.17 * cell, "rot": randf_range(-0.4, 0.4), "spin": randf_range(-2.5, 2.5),
			"life": 0.42, "age": -0.05, "shape": shape, "fill": fill, "line": line,
		})


func clear() -> void:
	_puffs.clear()
	_sparkles.clear()


func _process(delta: float) -> void:
	for list in [_puffs, _sparkles]:
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
	for sparkle in _sparkles:
		if sparkle.age > 0.0:
			sparkle.vel *= maxf(0.0, 1.0 - delta * 7.0)
			sparkle.rot += sparkle.spin * delta
	queue_redraw()


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
	for sparkle in _sparkles:
		if sparkle.age <= 0.0:
			continue
		var life: float = sparkle.age / sparkle.life
		var size: float = sparkle.size * (1.0 - smoothstep(0.55, 1.0, life)) * minf(life / 0.12, 1.0)
		if size <= 1.0:
			continue
		draw_set_transform(sparkle.pos, sparkle.rot, Vector2.ONE)
		BombStyles.draw_shape(self, sparkle.shape, Vector2.ZERO, size, sparkle.fill, sparkle.line)
	draw_set_transform(Vector2.ZERO)


func _puff_radius(puff: Dictionary) -> float:
	if puff.age <= 0.0:
		return 0.0
	var life: float = puff.age / puff.life
	# Pop out past full size, settle, then shrink away to nothing.
	var grow := minf(life / 0.25, 1.0)
	var overshoot := 1.0 + 0.25 * sin(grow * PI)
	return puff.radius * grow * overshoot * (1.0 - smoothstep(0.55, 1.0, life))

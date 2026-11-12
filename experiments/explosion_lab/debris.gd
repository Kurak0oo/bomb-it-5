extends Node2D
## Explosion lab: 2.5D debris. Each chunk has a ground position plus a height `z`; it is
## drawn lifted by `z` over a ground shadow that shrinks and fades with height. That
## split between ground and height is what makes flat chunks read as flying. Chunks are
## chunky, outlined and in the broken block's own colours, to match the cartoon board.

const GRAVITY := 1150.0
const BOUNCE := 0.45
const LINE_DARKEN := 0.55

var _chunks: Array[Dictionary] = []


func burst(origin: Vector2, away: Vector2, palette: Array, cell: float) -> void:
	for index in randi_range(5, 8):
		var spread := Vector2.from_angle(randf() * TAU) * 0.9
		var direction := (away + spread).normalized() if (away + spread) != Vector2.ZERO else Vector2.RIGHT
		_chunks.append({
			"pos": origin + Vector2(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3)) * cell,
			"vel": direction * randf_range(60.0, 210.0),
			"z": randf_range(4.0, 18.0), "vz": randf_range(240.0, 420.0),
			"rot": randf() * TAU, "spin": randf_range(-10.0, 10.0),
			"size": randf_range(0.16, 0.28) * cell, "color": palette[randi() % palette.size()],
			"life": randf_range(0.8, 1.2), "age": 0.0,
		})


func clear() -> void:
	_chunks.clear()


func _process(delta: float) -> void:
	var index := 0
	while index < _chunks.size():
		var chunk: Dictionary = _chunks[index]
		chunk.age += delta
		if chunk.age >= chunk.life:
			_chunks.remove_at(index)
			continue
		chunk.vz -= GRAVITY * delta
		chunk.z += chunk.vz * delta
		if chunk.z < 0.0:
			chunk.z = 0.0
			chunk.vz = -chunk.vz * BOUNCE
			chunk.vel *= 0.55
			chunk.spin *= 0.5
		if chunk.z == 0.0 and absf(chunk.vz) < 30.0:
			chunk.vz = 0.0
			chunk.vel *= maxf(0.0, 1.0 - delta * 6.0)
		chunk.pos += chunk.vel * delta
		chunk.rot += chunk.spin * delta
		index += 1
	queue_redraw()


func _draw() -> void:
	for chunk in _chunks:
		# Chunks shrink away at the end instead of fading: a cartoon "pop", no ghosts.
		var shrink := 1.0 - smoothstep(0.7, 1.0, chunk.age / chunk.life)
		var lift := clampf(1.0 - chunk.z / 160.0, 0.3, 1.0)
		draw_set_transform(chunk.pos, 0.0, Vector2(1.0, 0.45))
		draw_circle(Vector2.ZERO, chunk.size * 0.6 * lift * shrink, Color(0.16, 0.0, 0.2, 0.28 * lift), true, -1.0, true)
		draw_set_transform(chunk.pos - Vector2(0.0, chunk.z), chunk.rot, Vector2.ONE * shrink)
		var half: float = chunk.size * 0.5
		var colour: Color = chunk.color
		draw_rect(Rect2(-half - 2.0, -half * 0.8 - 2.0, half * 2.0 + 4.0, half * 1.6 + 4.0), colour.darkened(LINE_DARKEN))
		draw_rect(Rect2(-half, -half * 0.8, half * 2.0, half * 1.6), colour)
		draw_rect(Rect2(-half + 1.0, -half * 0.8 + 1.0, half * 2.0 - 2.0, half * 0.5), colour.lightened(0.45))
	draw_set_transform(Vector2.ZERO)

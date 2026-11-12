extends Node2D
## Explosion lab: one bomb with anticipation, drawn in the original's look (big glossy
## dark ball, small cap, short fuse with a cartoon spark). It reads the simulation's own
## bomb record (`age`, `fuse`) and never changes it. The pulse speeds up as the fuse
## burns; the last ticks squash it and blink it red just before it pops.

const FxTextures = preload("res://experiments/explosion_lab/fx_textures.gd")
## BombSimulation.FUSE_TICKS
const DEFAULT_FUSE := 72.0
const WARN_TICKS := 8.0
const LINE := Color("15151c")

var bomb: Dictionary
var cell_size := 48.0
var anticipation := true
var pop := 0.0
var _phase := 0.0
var _time := 0.0
var _circle := PackedVector2Array()
var _circle_uvs := PackedVector2Array()


func _ready() -> void:
	for index in 40:
		var direction := Vector2.from_angle(index * TAU / 40.0)
		_circle.append(direction)
		_circle_uvs.append(direction * 0.5 + Vector2(0.5, 0.5))
	pop = 0.0
	create_tween().tween_property(self, "pop", 1.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_time += delta
	if anticipation:
		var fuse: float = bomb.get("fuse", DEFAULT_FUSE)
		_phase += delta * lerpf(5.0, 18.0, clampf(bomb.get("age", 0) / fuse, 0.0, 1.0))
	queue_redraw()


func _draw() -> void:
	var c := cell_size
	var fuse: float = bomb.get("fuse", DEFAULT_FUSE)
	var age: float = bomb.get("age", 0)
	var squash := Vector2.ONE * pop
	var blink := false
	if anticipation:
		var pulse := 1.0 + 0.06 * sin(_phase)
		var warn := clampf(1.0 - (fuse - age) / WARN_TICKS, 0.0, 1.0)
		squash *= Vector2(2.0 - pulse + 0.2 * warn, pulse - 0.16 * warn)
		blink = warn > 0.0 and int(age) % 4 < 2
	var ground := Vector2(0, 0.38 * c)
	draw_set_transform(ground, 0.0, Vector2(squash.x, 0.34))
	draw_circle(Vector2.ZERO, 0.4 * c, Color(0.16, 0.0, 0.2, 0.3), true, -1.0, true)
	# Everything else squashes about the point where the bomb touches the floor.
	draw_set_transform(ground, 0.0, squash)
	var radius := 0.4 * c
	var middle := Vector2(0, -radius - 0.02 * c)
	var top := middle + Vector2.from_angle(-1.0) * radius
	# Cap and fuse sit behind the ball's upper right.
	draw_set_transform_matrix(Transform2D(0.0, ground) * Transform2D(0.0, squash, 0.0, Vector2.ZERO) * Transform2D(0.57, top))
	draw_rect(Rect2(-0.17 * c, -0.13 * c, 0.34 * c, 0.2 * c), LINE)
	draw_rect(Rect2(-0.17 * c + 2.0, -0.13 * c + 2.0, 0.34 * c - 4.0, 0.2 * c - 4.0), Color("7b7b8c"))
	draw_set_transform(ground, 0.0, squash)
	var fuse_line := PackedVector2Array([top + Vector2(0.03, -0.08) * c, top + Vector2(0.07, -0.17) * c, top + Vector2(0.15, -0.22) * c])
	draw_polyline(fuse_line, LINE, 6.0, true)
	draw_polyline(fuse_line, Color("e9c98a"), 3.0, true)
	draw_circle(middle, radius + 2.0, LINE, true, -1.0, true)
	var points := PackedVector2Array()
	for direction in _circle:
		points.append(middle + direction * radius)
	draw_colored_polygon(points, Color.WHITE, _circle_uvs, FxTextures.bomb_shade())
	if blink:
		draw_circle(middle, radius, Color(1.0, 0.25, 0.2, 0.6), true, -1.0, true)
	draw_set_transform_matrix(Transform2D(0.0, ground) * Transform2D(0.0, squash, 0.0, Vector2.ZERO)
		* Transform2D(-0.7, Vector2(1.0, 0.55), 0.0, middle + Vector2(-0.4, -0.48) * radius))
	draw_circle(Vector2.ZERO, radius * 0.3, Color(1, 1, 1, 0.8), true, -1.0, true)
	draw_set_transform(ground, 0.0, squash)
	draw_circle(middle + Vector2(-0.62, -0.1) * radius, radius * 0.08, Color(1, 1, 1, 0.7), true, -1.0, true)
	if anticipation:
		# Cartoon spark: a spinning star that flickers between two sizes.
		var spark := fuse_line[2]
		var size := 0.13 * c * (1.0 + 0.3 * signf(sin(_time * 30.0)))
		draw_colored_polygon(_star(spark, size + 2.0, _time * 6.0), Color("e6321e"))
		draw_colored_polygon(_star(spark, size, _time * 6.0), Color("ff9a1a"))
		draw_circle(spark, size * 0.45, Color("fff27a"), true, -1.0, true)
	draw_set_transform(Vector2.ZERO)


func _star(center: Vector2, size: float, angle: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in 10:
		points.append(center + Vector2.from_angle(angle + index * PI / 5.0) * (size if index % 2 == 0 else size * 0.5))
	return points

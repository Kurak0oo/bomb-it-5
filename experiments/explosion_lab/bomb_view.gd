extends Node2D
## Explosion lab: one bomb with anticipation, drawn in the original's look (big glossy
## dark ball, small cap, short fuse with a cartoon spark). It reads the simulation's own
## bomb record (`age`, `fuse`) and never changes it. While the fuse burns, each robot's
## bomb waits in character (README, "Bomb profiles"); the last 8 ticks are the same for
## every robot (squash and red blink), so the warning always reads the same.

const FxTextures = preload("res://experiments/explosion_lab/fx_textures.gd")
const BombStyles = preload("res://experiments/explosion_lab/bomb_styles.gd")
const ToonDraw = preload("res://experiments/explosion_lab/toon_draw.gd")
## BombSimulation.FUSE_TICKS
const DEFAULT_FUSE := 72.0
const WARN_TICKS := 8.0
const LINE := Color("15151c")

var bomb: Dictionary
var cell_size := 48.0
## The owner robot (index into BombStyles.STYLES): emblem, colours and idle motion.
var robot: int = BombStyles.DEFAULT:
	set(value):
		robot = value
		style = BombStyles.style(value)
var style: Dictionary = BombStyles.style(BombStyles.DEFAULT)
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
	var burnt := clampf(age / fuse, 0.0, 1.0)
	var squash := Vector2.ONE * pop
	var lift := 0.0
	var jitter := Vector2.ZERO
	var tilt := 0.0
	var blink := false
	if anticipation:
		match robot:
			1: # Ruby: hops to the beat, squashing on each landing.
				var beat := absf(sin(_phase * 0.5))
				lift = 0.12 * c * beat
				squash *= Vector2(1.0 + 0.1 * (1.0 - beat), 1.0 - 0.1 * (1.0 - beat))
			2: # Lime: wobbles like jelly.
				var wobble := sin(_phase * 1.4)
				squash *= Vector2(1.0 + 0.09 * wobble, 1.0 - 0.09 * wobble)
			4: # Violet: floats above its shadow.
				lift = 0.1 * c + 0.035 * c * sin(_time * 3.0)
			5: # Slate: rattles harder as the fuse burns down.
				jitter.x = 0.035 * c * burnt * burnt * signf(sin(_time * 55.0))
				tilt = 0.05 * burnt * signf(sin(_time * 41.0))
			6: # Mint: rocks gently from side to side.
				tilt = 0.12 * sin(_time * 2.6)
			7: # Snow: revs, a fine fast shiver that grows.
				jitter = Vector2(sin(_time * 90.0), cos(_time * 77.0)) * 0.012 * c * (1.0 + 2.0 * burnt)
			_: # Blue and Gold: the plain pulse, faster as the fuse burns.
				var pulse := 1.0 + (0.08 if robot == 3 else 0.05) * sin(_phase)
				squash *= Vector2(2.0 - pulse, pulse)
		var warn := clampf(1.0 - (fuse - age) / WARN_TICKS, 0.0, 1.0)
		squash *= Vector2(1.0 + 0.2 * warn, 1.0 - 0.16 * warn)
		blink = warn > 0.0 and int(age) % 4 < 2
	var ground := Vector2(0, 0.38 * c) + jitter
	var shadow := 1.0 - 0.35 * clampf(lift / (0.15 * c), 0.0, 1.0)
	draw_set_transform(ground, 0.0, Vector2(squash.x * shadow, 0.34 * shadow))
	draw_circle(Vector2.ZERO, 0.4 * c, Color(0.16, 0.0, 0.2, 0.3), true, -1.0, true)
	# Everything else squashes (and tilts) about the point where the bomb meets the floor.
	var base := Transform2D(tilt, ground - Vector2(0, lift)) * Transform2D(0.0, squash, 0.0, Vector2.ZERO)
	var radius := 0.4 * c
	var middle := Vector2(0, -radius - 0.02 * c)
	var top := middle + Vector2.from_angle(-1.0) * radius
	var spark := top + Vector2(0.15, -0.22) * c
	if robot == 0:
		# Blue: an antenna with an LED instead of a fuse, blinking faster as it burns.
		var antenna := middle + Vector2(0, -radius)
		spark = antenna + Vector2(0, -0.26 * c)
		draw_set_transform_matrix(base)
		draw_line(antenna, spark, LINE, 5.0, true)
		draw_line(antenna, spark, Color("c9d6e6"), 2.0, true)
	else:
		# Cap and fuse sit behind the ball's upper right.
		draw_set_transform_matrix(base * Transform2D(0.57, top))
		ToonDraw.box(self, Rect2(-0.17 * c, -0.13 * c, 0.34 * c, 0.2 * c), style.rim.lerp(Color("7b7b8c"), 0.35), 3, LINE, 2)
		draw_set_transform_matrix(base)
		var fuse_line := PackedVector2Array([top + Vector2(0.03, -0.08) * c, top + Vector2(0.07, -0.17) * c, spark])
		draw_polyline(fuse_line, LINE, 6.0, true)
		draw_polyline(fuse_line, Color("e9c98a"), 3.0, true)
	draw_circle(middle, radius + 2.0, LINE, true, -1.0, true)
	var points := PackedVector2Array()
	for direction in _circle:
		points.append(middle + direction * radius)
	draw_colored_polygon(points, Color.WHITE, _circle_uvs, FxTextures.bomb_shade())
	if robot == 7:
		# Snow: twin racing stripes, like its helmet.
		for x in [-0.34, 0.06]:
			ToonDraw.polygon(self, _stripe(middle, radius, x * radius, (x + 0.2) * radius), Color(style.rim, 0.9))
	# The robot's mark on the ball, in its blast colours.
	BombStyles.draw_shape(self, style.shape, middle + Vector2(0.16, 0.2) * radius, radius * 0.4, style.mid, style.rim, 2.0)
	if blink:
		draw_circle(middle, radius, Color(1.0, 0.25, 0.2, 0.6), true, -1.0, true)
	draw_set_transform_matrix(base * Transform2D(-0.7, Vector2(1.0, 0.55), 0.0, middle + Vector2(-0.4, -0.48) * radius))
	draw_circle(Vector2.ZERO, radius * 0.3, Color(1, 1, 1, 0.8), true, -1.0, true)
	draw_set_transform_matrix(base)
	draw_circle(middle + Vector2(-0.62, -0.1) * radius, radius * 0.08, Color(1, 1, 1, 0.7), true, -1.0, true)
	if anticipation:
		if robot == 0:
			var on := sin(_phase * 2.0) > 0.0
			draw_circle(spark, 0.09 * c + 2.0, LINE, true, -1.0, true)
			draw_circle(spark, 0.09 * c, style.mid if on else style.rim.darkened(0.4), true, -1.0, true)
			if on:
				draw_circle(spark, 0.16 * c, Color(style.mid, 0.35), true, -1.0, true)
		else:
			# Cartoon spark: a spinning star in the robot's colours, flickering between two sizes.
			var size := 0.13 * c * (1.0 + 0.3 * signf(sin(_time * 30.0)))
			ToonDraw.polygon(self, ToonDraw.star(spark, size + 2.0, 5, 0.5, _time * 6.0), style.rim)
			ToonDraw.polygon(self, ToonDraw.star(spark, size, 5, 0.5, _time * 6.0), style.mid)
			draw_circle(spark, size * 0.45, style.hot, true, -1.0, true)
		if robot == 4:
			# Violet: a twinkle orbits the floating bomb.
			var orbit := middle + Vector2(cos(_time * 4.0), sin(_time * 4.0) * 0.45) * radius * 1.25
			ToonDraw.polygon(self, ToonDraw.star(orbit, 0.1 * c + 2.0, 4, 0.4, 0.0), style.rim)
			ToonDraw.polygon(self, ToonDraw.star(orbit, 0.1 * c, 4, 0.4, 0.0), style.hot)
	draw_set_transform(Vector2.ZERO)


## A vertical band of the ball between x0 and x1, following the ball's outline.
func _stripe(middle: Vector2, radius: float, x0: float, x1: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for step in 7:
		var x := lerpf(x0, x1, step / 6.0)
		points.append(middle + Vector2(x, -sqrt(maxf(radius * radius - x * x, 0.0))))
	for step in 7:
		var x := lerpf(x1, x0, step / 6.0)
		points.append(middle + Vector2(x, sqrt(maxf(radius * radius - x * x, 0.0))))
	return points

extends Node2D
## Explosion lab: one bomb with anticipation. It reads the simulation's own bomb record
## (`age`, `fuse`) and never changes it. Pulse speeds up as the fuse burns; the last
## ticks squash and whiten it just before it pops.

const FxTextures = preload("res://experiments/explosion_lab/fx_textures.gd")
## BombSimulation.FUSE_TICKS
const DEFAULT_FUSE := 72.0
const WARN_TICKS := 8.0

var bomb: Dictionary
var cell_size := 48.0
var anticipation := true
var pop := 0.0

var _phase := 0.0
var _body: Sprite2D
var _spark: CPUParticles2D


func _ready() -> void:
	_body = Sprite2D.new()
	var size := int(cell_size * 0.72)
	_body.texture = FxTextures.bomb(size)
	_body.light_mask = 2
	add_child(_body)
	var fuse := Line2D.new()
	var top := -size * 0.5
	fuse.points = PackedVector2Array([Vector2(0, top + 2), Vector2(3, top - 5), Vector2(8, top - 9)])
	fuse.width = 3.0
	fuse.default_color = Color(0.85, 0.72, 0.5)
	_body.add_child(fuse)
	_spark = CPUParticles2D.new()
	_spark.position = Vector2(8, top - 9)
	_spark.amount = 10
	_spark.lifetime = 0.35
	_spark.texture = FxTextures.soft_circle()
	_spark.scale_amount_min = 0.03
	_spark.scale_amount_max = 0.07
	_spark.direction = Vector2(0.3, -1)
	_spark.spread = 70.0
	_spark.initial_velocity_min = 30.0
	_spark.initial_velocity_max = 80.0
	_spark.gravity = Vector2(0, 160)
	_spark.color = Color(1.0, 0.8, 0.35)
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	additive.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_spark.material = additive
	_body.add_child(_spark)
	pop = 0.0
	create_tween().tween_property(self, "pop", 1.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	var fuse: float = bomb.get("fuse", DEFAULT_FUSE)
	var age: float = bomb.get("age", 0)
	var scale_xy := Vector2.ONE * pop
	var tint := Color.WHITE
	if anticipation:
		var burnt := clampf(age / fuse, 0.0, 1.0)
		_phase += delta * lerpf(5.0, 18.0, burnt)
		var pulse := 1.0 + 0.07 * sin(_phase)
		var warn := clampf(1.0 - (fuse - age) / WARN_TICKS, 0.0, 1.0)
		scale_xy *= Vector2(pulse + 0.18 * warn, pulse - 0.14 * warn)
		tint = Color.WHITE.lerp(Color(2.6, 2.1, 1.8), warn)
	_body.scale = scale_xy
	_body.modulate = tint
	_spark.emitting = anticipation
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2(0, cell_size * 0.26), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, cell_size * 0.3 * pop, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO)

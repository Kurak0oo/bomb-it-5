extends Node2D
## Explosion lab (experiment, not shipped, not part of any checkpoint).
##
## Drives the real `BombSimulation` and layers presentation-only explosion effects on
## its blast results, each one toggleable, so they can be judged one at a time. Gameplay
## stays in the simulation: nothing here changes which cell is hit or when.
##
## Run:      godot --path . res://experiments/explosion_lab/lab.tscn
## Capture:  godot --path . res://experiments/explosion_lab/lab.tscn -- --capture=DIR [--preset=chain]

const Simulation = preload("res://scripts/simulation/bomb_simulation.gd")
const ChainOrder = preload("res://experiments/explosion_lab/chain_order.gd")
const FxTextures = preload("res://experiments/explosion_lab/fx_textures.gd")
const Debris = preload("res://experiments/explosion_lab/debris.gd")
const BombView = preload("res://experiments/explosion_lab/bomb_view.gd")
const FireBody = preload("res://experiments/explosion_lab/fire_body.gdshader")
const FireCore = preload("res://experiments/explosion_lab/fire_core.gdshader")
const ShockwaveRing = preload("res://experiments/explosion_lab/shockwave_ring.gdshader")
const ShockwaveRefract = preload("res://experiments/explosion_lab/shockwave_refract.gdshader")

const CELL := 48.0
const BOARD_SIZE := Vector2i(15, 13)
## TickScheduler.TICKS_PER_SECOND: the simulation clock.
const TICKS_PER_SECOND := 35.0
## `_detonate` keeps a damaging flame alive for 16 ticks (`expires: _tick + 16`).
const FLAME_TICKS := 16
const FLAME_SECONDS := FLAME_TICKS / TICKS_PER_SECOND
const LAB_ACTOR := &"lab"
const NEVER := 1_000_000
const LIGHT_POOL := 6
const CRATE_PALETTE := [Color(0.66, 0.44, 0.24), Color(0.52, 0.33, 0.17), Color(0.78, 0.56, 0.32)]
const TOGGLE_KEYS := {
	KEY_1: &"anticipation", KEY_2: &"stagger", KEY_3: &"core", KEY_4: &"glow", KEY_5: &"lights",
	KEY_6: &"shockwave", KEY_7: &"smoke", KEY_8: &"embers", KEY_9: &"debris", KEY_0: &"scorch",
	KEY_S: &"shake", KEY_H: &"hitstop", KEY_B: &"hitbox",
}

var toggles := {
	&"anticipation": true, &"stagger": true, &"core": true, &"glow": true, &"lights": true,
	&"shockwave": true, &"smoke": true, &"embers": true, &"debris": true, &"scorch": true,
	&"shake": true, &"hitstop": true, &"hitbox": false,
}
var ring_step := 0.022
var chain_step := 0.07
var power := 2
var lab_speed := 1.0
## Key F: screen-texture refraction instead of the light ring (see shockwave_refract).
var refract_shockwave := false

var _sim: Simulation
var _sim_tick := 0
var _tick_credit := 0.0
var _last_usec := 0
var _fx_time := 0.0
var _hitstop_left := 0.0
var _trauma := 0.0
var _shake_time := 0.0
var _next_id := 0
var _board_seed := 7
var _bombs: Array[Dictionary] = []
var _bomb_views: Dictionary = {}
var _block_views: Dictionary = {}
var _flames: Array[Dictionary] = []
var _hitboxes: Array[Dictionary] = []
var _lights: Array[Dictionary] = []
var _light_index := 0
var _shake_noise := FastNoiseLite.new()
var _capture_dir := ""
var _capture_frames: Array[float] = []

var _camera: Camera2D
var _world: Node2D
var _floor: Node2D
var _scorch_layer: Node2D
var _block_layer: Node2D
var _bomb_layer: Node2D
var _debris: Node2D
var _canvas_modulate: CanvasModulate
var _fx_root: Node2D
var _smoke_layer: Node2D
var _flame_layer: Node2D
var _glow_layer: Node2D
var _spark_layer: Node2D
var _shock_layer: Node2D
var _hitbox_layer: Node2D
var _hud: Label
var _body_material := ShaderMaterial.new()
var _core_material := ShaderMaterial.new()
var _add_material := CanvasItemMaterial.new()
var _occluder := OccluderPolygon2D.new()
var _smoke_ramp := Gradient.new()
var _smoke_curve := Curve.new()
var _ember_ramp := Gradient.new()


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.07, 0.07, 0.09))
	_build_resources()
	_build_nodes()
	_reset_board(true)
	get_viewport().size_changed.connect(_fit_camera)
	_fit_camera()
	_last_usec = Time.get_ticks_usec()
	_parse_args()


# --- Scene -----------------------------------------------------------------------------

func _build_resources() -> void:
	for material in [_body_material, _core_material]:
		material.set_shader_parameter("noise_tex", FxTextures.noise())
		material.set_shader_parameter("ramp_tex", FxTextures.fire_ramp())
	_body_material.shader = FireBody
	_core_material.shader = FireCore
	_add_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_add_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	var half := CELL * 0.5 - 1.0
	_occluder.polygon = PackedVector2Array([Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)])
	_smoke_ramp.offsets = PackedFloat32Array([0.0, 0.12, 0.6, 1.0])
	_smoke_ramp.colors = PackedColorArray([Color(0.35, 0.32, 0.3, 0.0), Color(0.3, 0.28, 0.27, 0.55),
		Color(0.22, 0.21, 0.21, 0.3), Color(0.2, 0.2, 0.2, 0.0)])
	_smoke_curve.add_point(Vector2(0.0, 0.45))
	_smoke_curve.add_point(Vector2(1.0, 1.4))
	_ember_ramp.offsets = PackedFloat32Array([0.0, 0.25, 0.6, 1.0])
	_ember_ramp.colors = PackedColorArray([Color(1, 1, 0.85, 1), Color(1, 0.8, 0.3, 1), Color(1, 0.35, 0.05, 0.8), Color(0.6, 0.1, 0, 0)])
	_shake_noise.frequency = 0.9


func _build_nodes() -> void:
	_camera = Camera2D.new()
	_camera.position = Vector2(BOARD_SIZE) * CELL * 0.5 + Vector2(0, -CELL * 0.4)
	add_child(_camera)
	_canvas_modulate = CanvasModulate.new()
	add_child(_canvas_modulate)
	_world = Node2D.new()
	_world.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_world)
	_floor = Node2D.new()
	_floor.draw.connect(_draw_floor)
	_scorch_layer = Node2D.new()
	_block_layer = Node2D.new()
	_bomb_layer = Node2D.new()
	_debris = Debris.new()
	for child in [_floor, _scorch_layer, _block_layer, _bomb_layer, _debris]:
		_world.add_child(child)
	for index in LIGHT_POOL:
		_lights.append(_make_light_pair())
	# FX sit on their own layer: CanvasModulate dims the board only, never the fire.
	var fx_layer := CanvasLayer.new()
	fx_layer.layer = 1
	fx_layer.follow_viewport_enabled = true
	add_child(fx_layer)
	_fx_root = Node2D.new()
	_fx_root.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	fx_layer.add_child(_fx_root)
	_smoke_layer = Node2D.new()
	_flame_layer = Node2D.new()
	_glow_layer = Node2D.new()
	_spark_layer = Node2D.new()
	_shock_layer = Node2D.new()
	_hitbox_layer = Node2D.new()
	_hitbox_layer.draw.connect(_draw_hitboxes)
	for child in [_smoke_layer, _flame_layer, _glow_layer, _spark_layer, _shock_layer, _hitbox_layer]:
		_fx_root.add_child(child)
	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 2
	add_child(hud_layer)
	_hud = Label.new()
	_hud.position = Vector2(10, 6)
	_hud.add_theme_font_size_override("font_size", 13)
	_hud.add_theme_color_override("font_outline_color", Color.BLACK)
	_hud.add_theme_constant_override("outline_size", 4)
	hud_layer.add_child(_hud)
	_apply_toggles()


## Two lights per explosion: one shadowed light for the floor (blocks cast shadows) and
## one unshadowed light for block and bomb faces (lights their normal maps).
func _make_light_pair() -> Dictionary:
	var ground := PointLight2D.new()
	ground.texture = FxTextures.light_falloff()
	ground.color = Color(1.0, 0.62, 0.28)
	ground.shadow_enabled = true
	ground.shadow_filter = Light2D.SHADOW_FILTER_PCF5
	ground.shadow_filter_smooth = 2.0
	ground.range_item_cull_mask = 1
	ground.enabled = false
	var face := PointLight2D.new()
	face.texture = FxTextures.light_falloff()
	face.color = Color(1.0, 0.5, 0.2)
	face.range_item_cull_mask = 2
	face.height = 36.0
	face.enabled = false
	_world.add_child(ground)
	_world.add_child(face)
	return {"ground": ground, "face": face, "tween": null}


func _fit_camera() -> void:
	var view := get_viewport_rect().size
	var board := Vector2(BOARD_SIZE) * CELL + Vector2(0, CELL * 1.6)
	var zoom := minf(view.x / board.x, view.y / board.y)
	_camera.zoom = Vector2.ONE * zoom


func _draw_floor() -> void:
	for y in BOARD_SIZE.y:
		for x in BOARD_SIZE.x:
			var shade := 0.3 if (x + y) % 2 == 0 else 0.27
			_floor.draw_rect(Rect2(Vector2(x, y) * CELL, Vector2.ONE * CELL), Color(shade * 0.8, shade, shade * 0.75))


func _draw_hitboxes() -> void:
	for hitbox in _hitboxes:
		for cell: Vector2i in hitbox.cells:
			_hitbox_layer.draw_rect(Rect2(Vector2(cell) * CELL + Vector2(3, 3), Vector2.ONE * (CELL - 6)), Color(0.2, 1.0, 1.0, 0.9), false, 2.0)


# --- Board and bombs -------------------------------------------------------------------

func _reset_board(fill_soft: bool) -> void:
	for layer in [_scorch_layer, _block_layer, _bomb_layer, _smoke_layer, _flame_layer, _glow_layer, _spark_layer, _shock_layer]:
		for child in layer.get_children():
			child.queue_free()
	_block_views.clear()
	_bomb_views.clear()
	_bombs.clear()
	_flames.clear()
	_hitboxes.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = _board_seed
	var board := {}
	for y in BOARD_SIZE.y:
		for x in BOARD_SIZE.x:
			var cell := Vector2i(x, y)
			var border := x == 0 or y == 0 or x == BOARD_SIZE.x - 1 or y == BOARD_SIZE.y - 1
			if border or (x % 2 == 0 and y % 2 == 0):
				board[cell] = &"solid"
			elif fill_soft and x + y > 3 and rng.randf() < 0.55:
				board[cell] = &"soft"
			else:
				board[cell] = &"floor"
	var ids: Array[StringName] = [&"human"]
	# Lab rules: no damage, so blasts never hurt the parked actor and bombs clear at once.
	_sim = Simulation.new(ids, {&"human": {"cell": Vector2i(1, 1)}}, board, {"seed": 5})
	_sim_tick = 0
	for cell: Vector2i in _sim.board():
		var kind: StringName = _sim.board()[cell]
		if kind in [&"solid", &"soft"]:
			_add_block_view(cell, kind)


func _add_block_view(cell: Vector2i, kind: StringName) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = FxTextures.block(kind, int(CELL))
	sprite.position = _cell_center(cell)
	sprite.light_mask = 2
	var occluder := LightOccluder2D.new()
	occluder.occluder = _occluder
	sprite.add_child(occluder)
	_block_layer.add_child(sprite)
	_block_views[cell] = sprite


## Lab-only board edit: `BombSimulation.board()` hands out its live board.
func _set_cell(cell: Vector2i, kind: StringName) -> void:
	_sim.board()[cell] = kind
	if _block_views.has(cell):
		_block_views[cell].queue_free()
		_block_views.erase(cell)
	if kind != &"floor":
		_add_block_view(cell, kind)


func _place_bomb(cell: Vector2i, bomb_power: int, fuse := 0) -> void:
	if _sim.board().get(cell) != &"floor" or not _bomb_at(cell).is_empty():
		return
	var bomb := {"actor_id": LAB_ACTOR, "cell": cell, "power": bomb_power, "lab_id": _next_id}
	if fuse > 0:
		bomb.fuse = fuse
	_next_id += 1
	# `add_bomb` keeps this very dictionary, so the view can read its live `age`.
	_sim.add_bomb(bomb)
	_bombs.append(bomb)
	var view := BombView.new()
	view.bomb = bomb
	view.cell_size = CELL
	view.anticipation = toggles.anticipation
	view.position = _cell_center(cell)
	_bomb_layer.add_child(view)
	_bomb_views[bomb.lab_id] = view


func _bomb_at(cell: Vector2i) -> Dictionary:
	for bomb in _bombs:
		if bomb.cell == cell:
			return bomb
	return {}


func _cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * CELL


# --- Clock -----------------------------------------------------------------------------

func _process(delta: float) -> void:
	var now := Time.get_ticks_usec()
	var real_dt := minf((now - _last_usec) / 1_000_000.0, 0.25)
	_last_usec = now
	if _capture_dir != "":
		real_dt = 1.0 / 60.0
	# The simulation runs on real time: hit-stop freezes the picture, never the rules.
	_tick_credit = minf(_tick_credit + real_dt * TICKS_PER_SECOND * lab_speed, 5.0)
	while _tick_credit >= 1.0:
		_tick_credit -= 1.0
		_step()
	_hitstop_left = maxf(_hitstop_left - real_dt, 0.0)
	Engine.time_scale = lab_speed * (0.03 if _hitstop_left > 0.0 else 1.0)
	_fx_time += delta
	_update_flames()
	_update_shake(delta)
	_hitboxes = _hitboxes.filter(func(hitbox: Dictionary) -> bool: return hitbox.until > _sim_tick)
	_hitbox_layer.queue_redraw()
	_update_hud()
	_update_capture()


func _step() -> void:
	var commands: Array[Dictionary] = [{"actor_id": &"human", "direction": Vector2.ZERO, "bomb_events": []}]
	var result: Dictionary = _sim.advance(commands)
	_sim_tick = result.tick
	if not result.blasts.is_empty():
		_on_blasts(result.blasts, result.broken_soft_blocks)


func _on_blasts(blasts: Array, broken: Array) -> void:
	var roots: Array = []
	for blast in blasts:
		var bomb := _bomb_at(blast.cell)
		roots.append(bomb.is_empty() or bomb.age >= bomb.get("fuse", Simulation.FUSE_TICKS))
	var depths := ChainOrder.depths(blasts, roots)
	var broken_cells := {}
	for cell in broken:
		broken_cells[cell] = true
	if toggles.hitstop:
		# Freeze just after the first flash peaks, longer for bigger batches.
		_later(0.04, _start_hitstop.bind(blasts.size()))
	for index in blasts.size():
		_spawn_blast(blasts[index], depths[index] if toggles.stagger else 0, broken_cells)
	if toggles.hitbox:
		var cells: Array[Vector2i] = []
		for blast in blasts:
			cells.append_array(blast.cells)
		_hitboxes.append({"cells": cells, "until": _sim_tick + FLAME_TICKS})


func _later(delay: float, callable: Callable) -> void:
	if delay <= 0.0:
		callable.call()
	else:
		get_tree().create_timer(delay).timeout.connect(callable)


# --- Effects ---------------------------------------------------------------------------

func _spawn_blast(blast: Dictionary, depth: int, broken_cells: Dictionary) -> void:
	var base_delay := ChainOrder.delay(depth, 0, chain_step, ring_step)
	var bomb := _bomb_at(blast.cell)
	if not bomb.is_empty():
		_bombs.erase(bomb)
		# The bomb stays drawn until its own flame shows, so chained bombs never vanish early.
		_later(base_delay, _remove_bomb_view.bind(bomb.lab_id))
	for segment in ChainOrder.segments(blast):
		var distance: int = segment.distance if toggles.stagger else 0
		var delay := ChainOrder.delay(depth, distance, chain_step, ring_step)
		_add_flame(segment, delay)
		if toggles.scorch:
			_later(delay, _add_scorch.bind(segment.cell))
		if broken_cells.has(segment.cell):
			broken_cells.erase(segment.cell)
			_later(delay, _break_block.bind(segment.cell, blast.cell))
	_later(base_delay, _burst.bind(blast, ChainOrder.reach(blast)))


func _remove_bomb_view(lab_id: int) -> void:
	if _bomb_views.has(lab_id):
		_bomb_views[lab_id].queue_free()
		_bomb_views.erase(lab_id)


func _add_flame(segment: Dictionary, delay: float) -> void:
	var record := {"start": _fx_time + delay, "kind": segment.kind, "seed": randf(), "nodes": []}
	var materials: Array = [_body_material, _core_material] if toggles.core else [_body_material]
	for material in materials:
		var sprite := Sprite2D.new()
		sprite.texture = FxTextures.white()
		sprite.material = material
		sprite.position = _cell_center(segment.cell)
		sprite.rotation = Vector2(segment.direction).angle()
		# Arms span exactly one cell along the ray (plus 2 % overlap) and leave headroom
		# across it; the centre quad is larger still so the fireball stays round.
		var size := Vector2(1.45, 1.45) if segment.kind == ChainOrder.KIND_CENTER else Vector2(1.02, 1.45)
		sprite.scale = size * CELL / FxTextures.WHITE_SIZE
		sprite.visible = false
		_flame_layer.add_child(sprite)
		record.nodes.append(sprite)
	_flames.append(record)


func _update_flames() -> void:
	var index := 0
	while index < _flames.size():
		var record: Dictionary = _flames[index]
		var age: float = (_fx_time - record.start) / FLAME_SECONDS
		if age >= 1.0:
			for sprite in record.nodes:
				sprite.queue_free()
			_flames.remove_at(index)
			continue
		for sprite: Sprite2D in record.nodes:
			sprite.visible = age >= 0.0
			# Shader parameters packed into modulate: age, kind, seed (see fire_shape).
			sprite.modulate = Color(clampf(age, 0.0, 1.0), record.kind, record.seed, 1.0)
		index += 1


func _burst(blast: Dictionary, reach: int) -> void:
	var center := _cell_center(blast.cell)
	var points := PackedVector2Array()
	for cell: Vector2i in blast.cells:
		points.append(_cell_center(cell) - center)
	if toggles.glow:
		_flash(center, reach)
	if toggles.lights:
		_light(center, reach)
	if toggles.shockwave:
		_shockwave(center, reach)
	if toggles.smoke:
		_smoke(center, points, reach)
	if toggles.embers:
		_embers(center, points, reach)
	if toggles.shake:
		_trauma = minf(_trauma + 0.2 + 0.04 * reach, 1.0)


func _flash(center: Vector2, reach: int) -> void:
	var flash := Sprite2D.new()
	flash.texture = FxTextures.soft_circle()
	flash.material = _add_material
	flash.position = center
	flash.scale = Vector2.ONE * CELL * 2.2 / 128.0
	_glow_layer.add_child(flash)
	var fade := flash.create_tween()
	fade.tween_property(flash, "modulate:a", 0.0, 0.1).from(1.0)
	fade.tween_callback(flash.queue_free)
	var glow := Sprite2D.new()
	glow.texture = FxTextures.fire_glow()
	glow.material = _add_material
	glow.position = center
	var size := CELL * (2.0 + reach) / 128.0
	_glow_layer.add_child(glow)
	var swell := glow.create_tween().set_parallel()
	swell.tween_property(glow, "scale", Vector2.ONE * size * 1.1, 0.35).from(Vector2.ONE * size * 0.5) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	swell.tween_property(glow, "modulate:a", 0.0, 0.45).from(0.9)
	swell.chain().tween_callback(glow.queue_free)


func _light(center: Vector2, reach: int) -> void:
	var pair: Dictionary = _lights[_light_index]
	_light_index = (_light_index + 1) % _lights.size()
	if pair.tween is Tween and pair.tween.is_valid():
		pair.tween.kill()
	var tween := create_tween().set_parallel()
	for key in [&"ground", &"face"]:
		var light: PointLight2D = pair[key]
		light.position = center
		light.texture_scale = CELL * (2.0 * reach + 3.0) / 256.0
		light.enabled = true
		tween.tween_property(light, "energy", 0.0, 0.55).from(2.2 if key == &"ground" else 0.75) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(func() -> void:
		pair.ground.enabled = false
		pair.face.enabled = false)
	pair.tween = tween


func _shockwave(center: Vector2, reach: int) -> void:
	var ring := Sprite2D.new()
	ring.texture = FxTextures.white()
	var material := ShaderMaterial.new()
	material.shader = ShockwaveRefract if refract_shockwave else ShockwaveRing
	material.set_shader_parameter("strength", 0.008 + 0.003 * reach)
	ring.material = material
	ring.position = center
	ring.scale = Vector2.ONE * CELL * (2.0 * reach + 1.5) / FxTextures.WHITE_SIZE
	_shock_layer.add_child(ring)
	var tween := ring.create_tween()
	tween.tween_method(func(value: float) -> void: material.set_shader_parameter("progress", value), 0.0, 1.0, 0.38) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(ring.queue_free)


func _particles(center: Vector2, points: PackedVector2Array, lifetime: float) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.position = center
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.lifetime = lifetime
	particles.texture = FxTextures.soft_circle()
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
	particles.emission_points = points
	particles.spread = 180.0
	get_tree().create_timer(lifetime + 0.3).timeout.connect(particles.queue_free)
	return particles


func _smoke(center: Vector2, points: PackedVector2Array, reach: int) -> void:
	var smoke := _particles(center, points, 1.3)
	smoke.amount = 6 + reach * 3
	smoke.direction = Vector2.UP
	smoke.initial_velocity_min = 10.0
	smoke.initial_velocity_max = 30.0 + 10.0 * reach
	smoke.gravity = Vector2(0, -28)
	smoke.damping_min = 10.0
	smoke.damping_max = 25.0
	smoke.angle_min = 0.0
	smoke.angle_max = 360.0
	smoke.scale_amount_min = 0.35
	smoke.scale_amount_max = 0.6
	smoke.scale_amount_curve = _smoke_curve
	smoke.color_ramp = _smoke_ramp
	_smoke_layer.add_child(smoke)
	smoke.emitting = true


func _embers(center: Vector2, points: PackedVector2Array, reach: int) -> void:
	var embers := _particles(center, points, 0.7)
	embers.amount = 14 + reach * 4
	embers.material = _add_material
	embers.direction = Vector2.UP
	embers.initial_velocity_min = 140.0
	embers.initial_velocity_max = 360.0
	# Strong downward gravity on an upward launch: sparks arc up and fall back (fake z).
	embers.gravity = Vector2(0, 520)
	embers.damping_min = 40.0
	embers.damping_max = 80.0
	embers.scale_amount_min = 0.04
	embers.scale_amount_max = 0.09
	embers.color_ramp = _ember_ramp
	_spark_layer.add_child(embers)
	embers.emitting = true


func _add_scorch(cell: Vector2i) -> void:
	if _scorch_layer.get_child_count() > 300:
		return
	var mark := Sprite2D.new()
	mark.texture = FxTextures.scorch()
	mark.position = _cell_center(cell) + Vector2(randf_range(-4, 4), randf_range(-4, 4))
	mark.rotation = randf() * TAU
	mark.scale = Vector2.ONE * CELL * randf_range(1.0, 1.3) / 128.0
	_scorch_layer.add_child(mark)
	var tween := mark.create_tween()
	tween.tween_property(mark, "modulate:a", 0.55, 0.15).from(0.0)
	tween.tween_interval(3.0)
	tween.tween_property(mark, "modulate:a", 0.0, 2.0)
	tween.tween_callback(mark.queue_free)


func _break_block(cell: Vector2i, origin: Vector2i) -> void:
	if _block_views.has(cell):
		_block_views[cell].queue_free()
		_block_views.erase(cell)
	if toggles.debris:
		_debris.burst(_cell_center(cell), Vector2(cell - origin), CRATE_PALETTE, CELL)


func _start_hitstop(count: int) -> void:
	_hitstop_left = maxf(_hitstop_left, clampf(0.035 + 0.015 * (count - 1), 0.035, 0.12))


func _update_shake(delta: float) -> void:
	_trauma = maxf(_trauma - delta * 1.5, 0.0)
	_shake_time += delta * 40.0
	var amount := _trauma * _trauma
	_camera.offset = Vector2(_shake_noise.get_noise_2d(_shake_time, 0.0), _shake_noise.get_noise_2d(0.0, _shake_time)) * 16.0 * amount


func _apply_toggles() -> void:
	_canvas_modulate.color = Color(0.58, 0.58, 0.68) if toggles.lights else Color.WHITE
	for view in _bomb_views.values():
		view.anticipation = toggles.anticipation


# --- Presets ---------------------------------------------------------------------------

## A snake of power-2 bombs two cells apart: only the first has a fuse, the rest wait
## to be chained, so the wave travels the whole board. Crates line the corridor.
func _preset_chain() -> void:
	_reset_board(false)
	for x in range(1, BOARD_SIZE.x - 2, 2):
		_set_cell(Vector2i(x, 2), &"soft")
		_set_cell(Vector2i(x, BOARD_SIZE.y - 3), &"soft")
	var path: Array[Vector2i] = []
	for x in range(1, BOARD_SIZE.x - 1, 2):
		path.append(Vector2i(x, 1))
	for y in range(3, BOARD_SIZE.y - 1, 2):
		path.append(Vector2i(BOARD_SIZE.x - 2, y))
	for x in range(BOARD_SIZE.x - 4, 0, -2):
		path.append(Vector2i(x, BOARD_SIZE.y - 2))
	for index in path.size():
		_place_bomb(path[index], 2, 40 if index == 0 else NEVER)


## A dense cluster that goes off almost at once: stresses hit-stop, the light pool and
## additive overdraw.
func _preset_cluster() -> void:
	_reset_board(false)
	var middle := BOARD_SIZE / 2
	for y in range(middle.y - 3, middle.y + 4):
		for x in range(middle.x - 4, middle.x + 5):
			var cell := Vector2i(x, y)
			if absi(x - middle.x) + absi(y - middle.y) >= 5 and _sim.board().get(cell) == &"floor":
				_set_cell(cell, &"soft")
	for y in range(middle.y - 2, middle.y + 3):
		for x in range(middle.x - 2, middle.x + 3):
			var cell := Vector2i(x, y)
			_place_bomb(cell, 3, 30 if cell == middle else NEVER)


## Ordinary play: crates everywhere, bombs with staggered fuses and mixed power.
func _preset_random() -> void:
	_reset_board(true)
	var rng := RandomNumberGenerator.new()
	rng.seed = _board_seed + 1
	var floors: Array[Vector2i] = []
	for cell: Vector2i in _sim.board():
		if _sim.board()[cell] == &"floor":
			floors.append(cell)
	floors.sort()
	for index in 18:
		var cell := floors[rng.randi_range(0, floors.size() - 1)]
		_place_bomb(cell, rng.randi_range(1, 4), rng.randi_range(30, 140))


func _detonate_all() -> void:
	for bomb in _bombs:
		bomb.fuse = bomb.age + 1


# --- Input and HUD ---------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mouse := get_global_mouse_position()
		var cell := Vector2i(floori(mouse.x / CELL), floori(mouse.y / CELL))
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_place_bomb(cell, power)
			MOUSE_BUTTON_RIGHT:
				var kind: Variant = _sim.board().get(cell)
				if kind in [&"floor", &"soft"] and _bomb_at(cell).is_empty():
					_set_cell(cell, &"soft" if kind == &"floor" else &"floor")
			MOUSE_BUTTON_WHEEL_UP:
				power = mini(power + 1, 10)
			MOUSE_BUTTON_WHEEL_DOWN:
				power = maxi(power - 1, 1)
	elif event is InputEventKey and event.pressed and not event.echo:
		if TOGGLE_KEYS.has(event.keycode):
			var key: StringName = TOGGLE_KEYS[event.keycode]
			toggles[key] = not toggles[key]
			_apply_toggles()
			return
		match event.keycode:
			KEY_R: _reset_board(true)
			KEY_C: _preset_chain()
			KEY_V: _preset_cluster()
			KEY_G: _preset_random()
			KEY_SPACE: _detonate_all()
			KEY_BRACKETLEFT: power = maxi(power - 1, 1)
			KEY_BRACKETRIGHT: power = mini(power + 1, 10)
			KEY_MINUS: chain_step = maxf(chain_step - 0.01, 0.0)
			KEY_EQUAL: chain_step = minf(chain_step + 0.01, 0.3)
			KEY_COMMA: ring_step = maxf(ring_step - 0.004, 0.0)
			KEY_PERIOD: ring_step = minf(ring_step + 0.004, 0.1)
			KEY_P: lab_speed = 0.25 if lab_speed == 1.0 else 1.0
			KEY_F: refract_shockwave = not refract_shockwave


func _update_hud() -> void:
	var names := {KEY_1: "1", KEY_2: "2", KEY_3: "3", KEY_4: "4", KEY_5: "5", KEY_6: "6", KEY_7: "7",
		KEY_8: "8", KEY_9: "9", KEY_0: "0", KEY_S: "S", KEY_H: "H", KEY_B: "B"}
	var parts: PackedStringArray = []
	for keycode in TOGGLE_KEYS:
		var key: StringName = TOGGLE_KEYS[keycode]
		parts.append("%s %s%s" % [names[keycode], "+" if toggles[key] else "-", key])
	_hud.text = "Explosion lab  |  click bomb  right-click crate  wheel/[ ] power %d  space detonate all  F shockwave: %s\n" % [
		power, "refract" if refract_shockwave else "ring"] \
		+ "C chain  V cluster  G random  R reset  P slow-mo %s  -/= chain step %.0f ms  ,/. ring step %.0f ms\n" % [
			"on" if lab_speed < 1.0 else "off", chain_step * 1000.0, ring_step * 1000.0] \
		+ "  ".join(parts)


# --- Capture (for reviewing effects without a display) -------------------------------

func _parse_args() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			_capture_dir = argument.trim_prefix("--capture=")
	if _capture_dir == "":
		return
	DirAccess.make_dir_recursive_absolute(_capture_dir)
	var preset := "chain"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--preset="):
			preset = argument.trim_prefix("--preset=")
		if argument.begins_with("--off="):
			for key in argument.trim_prefix("--off=").split(","):
				toggles[StringName(key)] = false
	_apply_toggles()
	toggles.hitstop = false
	match preset:
		"cluster": _preset_cluster()
		"random": _preset_random()
		_: _preset_chain()
	_capture_frames.assign([1.0, 1.17, 1.2, 1.25, 1.32, 1.45, 1.6, 1.8, 2.1, 2.6, 3.4])


func _update_capture() -> void:
	if _capture_dir == "" or _capture_frames.is_empty():
		return
	if _fx_time >= _capture_frames[0]:
		var image := get_viewport().get_texture().get_image()
		image.save_png("%s/frame_%04d.png" % [_capture_dir, int(_capture_frames[0] * 1000.0)])
		_capture_frames.remove_at(0)
		if _capture_frames.is_empty():
			get_tree().quit()

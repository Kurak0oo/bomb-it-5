extends RefCounted
## Explosion lab: procedural placeholder textures (no original art). Built once, cached.
## Normal maps use Godot's convention (X+ right, Y+ up, Z+ toward the viewer).

const WHITE_SIZE := 4.0

static var _cache: Dictionary = {}


static func white() -> Texture2D:
	if not _cache.has(&"white"):
		var image := Image.create_empty(int(WHITE_SIZE), int(WHITE_SIZE), false, Image.FORMAT_RGBA8)
		image.fill(Color.WHITE)
		_cache[&"white"] = ImageTexture.create_from_image(image)
	return _cache[&"white"]


static func radial(key: StringName, colors: PackedColorArray, offsets: PackedFloat32Array, size := 128) -> Texture2D:
	if not _cache.has(key):
		var gradient := Gradient.new()
		gradient.offsets = offsets
		gradient.colors = colors
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(1.0, 0.5)
		texture.width = size
		texture.height = size
		_cache[key] = texture
	return _cache[key]


static func soft_circle() -> Texture2D:
	return radial(&"soft", PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.6), Color(1, 1, 1, 0)]),
		PackedFloat32Array([0.0, 0.45, 1.0]))


static func fire_glow() -> Texture2D:
	return radial(&"glow", PackedColorArray([Color(1, 0.8, 0.45, 0.9), Color(1, 0.4, 0.08, 0.4), Color(0.6, 0.1, 0, 0)]),
		PackedFloat32Array([0.0, 0.4, 1.0]))


static func light_falloff() -> Texture2D:
	return radial(&"light", PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)]),
		PackedFloat32Array([0.0, 0.35, 1.0]), 256)


static func scorch() -> Texture2D:
	return radial(&"scorch", PackedColorArray([Color(0.04, 0.03, 0.02, 0.9), Color(0.07, 0.05, 0.03, 0.45), Color(0, 0, 0, 0)]),
		PackedFloat32Array([0.0, 0.5, 1.0]))


static func noise() -> Texture2D:
	if not _cache.has(&"noise"):
		var source := FastNoiseLite.new()
		source.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		source.frequency = 0.035
		source.fractal_octaves = 3
		var texture := NoiseTexture2D.new()
		texture.noise = source
		texture.seamless = true
		texture.width = 128
		texture.height = 128
		_cache[&"noise"] = texture
	return _cache[&"noise"]


## Heat ramp for the flame body: cool edge (deep red) to hot spine (pale yellow).
static func fire_ramp() -> Texture2D:
	if not _cache.has(&"ramp"):
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.3, 0.6, 0.85, 1.0])
		gradient.colors = PackedColorArray([Color(0.45, 0.04, 0.02), Color(0.9, 0.22, 0.04),
			Color(1.0, 0.55, 0.1), Color(1.0, 0.85, 0.35), Color(1.0, 0.97, 0.8)])
		var texture := GradientTexture1D.new()
		texture.gradient = gradient
		_cache[&"ramp"] = texture
	return _cache[&"ramp"]


## Bevelled block with a matching normal map, so 2D lights shade its edges.
static func block(kind: StringName, size: int) -> Texture2D:
	var key := StringName("block_%s_%d" % [kind, size])
	if _cache.has(key):
		return _cache[key]
	var solid := kind == &"solid"
	var albedo := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var normals := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var base := Color(0.46, 0.48, 0.56) if solid else Color(0.66, 0.44, 0.24)
	var bevel := 6 if solid else 4
	var plank := maxi(size / 3, 1)
	for y in size:
		for x in size:
			var left := x
			var right := size - 1 - x
			var top := y
			var bottom := size - 1 - y
			var edge := mini(mini(left, right), mini(top, bottom))
			var normal := Vector3(0, 0, 1)
			var shade := 1.0
			if edge < bevel:
				if edge == top:
					normal = Vector3(0, 1, 1)
					shade = 1.2
				elif edge == left:
					normal = Vector3(-1, 0, 1)
					shade = 1.08
				elif edge == right:
					normal = Vector3(1, 0, 1)
					shade = 0.82
				else:
					normal = Vector3(0, -1, 1)
					shade = 0.68
			elif not solid and y % plank < 2 and y > bevel:
				# Plank groove: upper lip faces down, lower lip faces up.
				normal = Vector3(0, -1 if y % plank == 0 else 1, 1)
				shade = 0.72
			var grain := 0.95 + 0.05 * sin(x * 0.7 + y * 0.21) if not solid else 0.93 + 0.07 * fposmod(sin(x * 12.9898 + y * 78.233) * 43758.5453, 1.0)
			albedo.set_pixel(x, y, Color(base.r * shade * grain, base.g * shade * grain, base.b * shade * grain, 1.0))
			normal = normal.normalized()
			normals.set_pixel(x, y, Color(normal.x * 0.5 + 0.5, normal.y * 0.5 + 0.5, normal.z * 0.5 + 0.5))
	var texture := CanvasTexture.new()
	texture.diffuse_texture = ImageTexture.create_from_image(albedo)
	texture.normal_texture = ImageTexture.create_from_image(normals)
	_cache[key] = texture
	return texture


## Dark bomb sphere with a spherical normal map: nearby explosions rim-light it.
static func bomb(size: int) -> Texture2D:
	var key := StringName("bomb_%d" % size)
	if _cache.has(key):
		return _cache[key]
	var albedo := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var normals := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var radius := size * 0.5 - 1.0
	var center := Vector2(size, size) * 0.5
	for y in size:
		for x in size:
			var offset := (Vector2(x, y) + Vector2(0.5, 0.5) - center) / radius
			var r2 := offset.length_squared()
			if r2 > 1.0:
				albedo.set_pixel(x, y, Color(0, 0, 0, 0))
				normals.set_pixel(x, y, Color(0.5, 0.5, 1.0, 0.0))
				continue
			var normal := Vector3(offset.x, -offset.y, sqrt(1.0 - r2))
			# Baked key light from the upper left so the bomb reads round without 2D lights.
			var lambert := clampf(normal.dot(Vector3(-0.45, 0.55, 0.7).normalized()), 0.0, 1.0)
			var specular := pow(clampf(normal.dot(Vector3(-0.35, 0.45, 0.82).normalized()), 0.0, 1.0), 40.0)
			var tone := 0.12 + 0.3 * lambert
			var colour := Color(tone * 0.9 + specular, tone * 0.95 + specular, tone * 1.25 + specular, 1.0)
			albedo.set_pixel(x, y, colour)
			normals.set_pixel(x, y, Color(normal.x * 0.5 + 0.5, normal.y * 0.5 + 0.5, normal.z * 0.5 + 0.5))
	var texture := CanvasTexture.new()
	texture.diffuse_texture = ImageTexture.create_from_image(albedo)
	texture.normal_texture = ImageTexture.create_from_image(normals)
	_cache[key] = texture
	return texture

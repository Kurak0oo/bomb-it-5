extends RefCounted
## Explosion lab: procedural placeholder textures (no original art). Built once, cached.

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


## Soft swell behind a blast, tinted by the blast's own colour through `modulate` and
## alpha-blended, so it stays candy-bright on a saturated floor instead of burning out.
static func fire_glow() -> Texture2D:
	return radial(&"glow", PackedColorArray([Color(1, 1, 1, 0.7), Color(1, 1, 1, 0.3), Color(1, 1, 1, 0)]),
		PackedFloat32Array([0.0, 0.45, 1.0]))


## Soft light spot under every floor cell, as on the original's stage floors.
static func floor_spot() -> Texture2D:
	return radial(&"floor", PackedColorArray([Color(1, 1, 1, 0.16), Color(1, 1, 1, 0.05), Color(1, 1, 1, 0)]),
		PackedFloat32Array([0.0, 0.6, 1.0]))


## Bomb ball shading: an off-centre radial gradient (key light from the upper left).
static func bomb_shade() -> Texture2D:
	if not _cache.has(&"bomb"):
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.35, 0.8, 1.0])
		gradient.colors = PackedColorArray([Color("8c8c9c"), Color("54545f"), Color("2c2c36"), Color("1d1d26")])
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.36, 0.32)
		texture.fill_to = Vector2(1.0, 0.85)
		texture.width = 96
		texture.height = 96
		_cache[&"bomb"] = texture
	return _cache[&"bomb"]

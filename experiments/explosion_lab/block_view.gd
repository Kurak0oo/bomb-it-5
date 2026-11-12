extends Node2D
## Explosion lab: one placeholder block in the original's look: a chunky, glossy,
## saturated object with a darker outline of its own hue, taller than its cell so it
## overlaps the row above. Procedural; no original art.

const ToonDraw = preload("res://experiments/explosion_lab/toon_draw.gd")
const SOLID := {"top": Color("9fb4ee"), "front": Color("6074c4"), "line": Color("2c3780"), "accent": Color("ffd23c")}
const SOFT := [
	{"top": Color("ff5a52"), "front": Color("cf2434"), "line": Color("7c0f22"), "accent": Color("ffe14a")},
	{"top": Color("ffe066"), "front": Color("f7a325"), "line": Color("96560c"), "accent": Color("ff4d4d")},
	{"top": Color("5cc8ff"), "front": Color("2385e0"), "line": Color("0f4390"), "accent": Color("ffffff")},
]

var kind: StringName = &"solid"
var variant := 0
var cell_size := 48.0


func palette() -> Dictionary:
	return SOLID if kind == &"solid" else SOFT[variant % SOFT.size()]


func debris_colours() -> Array:
	var colours := palette()
	return [colours.top, colours.front, colours.accent]


func _draw() -> void:
	var c := cell_size
	var colours := palette()
	var half := 0.46 * c
	var top := -0.62 * c
	var face_bottom := 0.16 * c
	var bottom := 0.46 * c
	draw_set_transform(Vector2(0, bottom - 0.02 * c), 0.0, Vector2(1.0, 0.32))
	draw_circle(Vector2.ZERO, 0.56 * c, Color(0.16, 0.0, 0.2, 0.28), true, -1.0, true)
	draw_set_transform(Vector2.ZERO)
	var radius := int(0.19 * c)
	_box(Rect2(-half, top, half * 2.0, bottom - top), colours.front, radius, colours.line, 2)
	_box(Rect2(-half + 2.0, top + 2.0, half * 2.0 - 4.0, face_bottom - top), colours.top, radius - 2)
	if kind == &"solid":
		var middle := Vector2(0, (top + face_bottom) * 0.5 + 1.0)
		draw_circle(middle, 0.2 * c, colours.line, true, -1.0, true)
		draw_circle(middle, 0.2 * c - 2.0, colours.accent, true, -1.0, true)
		draw_circle(middle + Vector2(-0.06, -0.07) * c, 0.06 * c, Color(1, 1, 1, 0.85), true, -1.0, true)
	else:
		match variant % SOFT.size():
			0: # gift ribbon
				draw_rect(Rect2(-0.09 * c, top + 2.0, 0.18 * c, bottom - top - 4.0), colours.accent)
				draw_rect(Rect2(-half + 2.0, top + 0.36 * c, half * 2.0 - 4.0, 0.14 * c), colours.accent)
			1: # striped tub
				for index in 3:
					var x := (-0.3 + 0.24 * index) * c
					draw_rect(Rect2(x, face_bottom + 2.0, 0.12 * c, bottom - face_bottom - 5.0), colours.accent)
			2: # star crate
				ToonDraw.polygon(self, ToonDraw.star(Vector2(0, (top + face_bottom) * 0.5 + 1.0), 0.24 * c, 5, 0.45), colours.accent)
	_box(Rect2(-half + 6.0, top + 5.0, half * 2.0 - 12.0, 0.13 * c), Color(1, 1, 1, 0.42), 4)


func _box(rect: Rect2, colour: Color, radius: int, line := Color.TRANSPARENT, line_width := 0) -> void:
	ToonDraw.box(self, rect, colour, radius, line, line_width)

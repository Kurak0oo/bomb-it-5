extends RefCounted
## Explosion lab: one bomb effect per robot (Session.ROBOTS order; names and base
## colours from GameView.ROBOT_TITLES / ROBOT_COLORS). The original gives every robot
## the same bomb and blast, so these are new-art ideas, not replica behaviour. Every
## style keeps the original's form (glossy dark ball, flat three-band cross blast) and
## changes only its colours, the shape that bursts out of it, and the bomb's emblem.

const ToonDraw = preload("res://experiments/explosion_lab/toon_draw.gd")

## hot / mid / rim: the blast's three colour bands. puff / puff_line: the cloud.
const STYLES := [
	{"robot": "BLUE", "theme": "spark", "shape": &"bolt", "hot": Color("ffffdd"), "mid": Color("6fe0ff"), "rim": Color("1e6bff"), "puff": Color("eaf8ff"), "puff_line": Color("8cc8f0")},
	{"robot": "RUBY", "theme": "sweetheart", "shape": &"heart", "hot": Color("fff6fa"), "mid": Color("ffa3cf"), "rim": Color("ff3d8b"), "puff": Color("ffeaf3"), "puff_line": Color("f29ac0")},
	{"robot": "LIME", "theme": "slime", "shape": &"drop", "hot": Color("fbffe0"), "mid": Color("c8f24a"), "rim": Color("4fb81e"), "puff": Color("efffd0"), "puff_line": Color("9bd45a")},
	{"robot": "GOLD", "theme": "sunburst", "shape": &"star", "hot": Color("fffff5"), "mid": Color("ffeb38"), "rim": Color("ff850a"), "puff": Color("fff7df"), "puff_line": Color("e2b27a")},
	{"robot": "VIOLET", "theme": "magic", "shape": &"twinkle", "hot": Color("fdf5ff"), "mid": Color("e7b0ff"), "rim": Color("b44cff"), "puff": Color("f4e6ff"), "puff_line": Color("b98ae6")},
	{"robot": "SLATE", "theme": "steel", "shape": &"nut", "hot": Color("e8edf5"), "mid": Color("a9b6c9"), "rim": Color("3d4a66"), "puff": Color("eef1f5"), "puff_line": Color("9aa6b4")},
	{"robot": "MINT", "theme": "leaf", "shape": &"leaf", "hot": Color("e6fff0"), "mid": Color("6fe8ac"), "rim": Color("0f9a70"), "puff": Color("e4fff2"), "puff_line": Color("7fd0aa")},
	{"robot": "SNOW", "theme": "peppermint", "shape": &"candy", "hot": Color("ffffff"), "mid": Color("fff1f1"), "rim": Color("e8283c"), "puff": Color("ffffff"), "puff_line": Color("f2a0a8")},
]
## Gold is the original's own yellow and orange blast.
const DEFAULT := 3

static var _shapes: Dictionary = {}


static func style(index: int) -> Dictionary:
	return STYLES[posmod(index, STYLES.size())]


## The style's burst shape as a polygon in unit size (fits a circle of radius 1).
static func shape(kind: StringName) -> PackedVector2Array:
	if _shapes.has(kind):
		return _shapes[kind]
	var points := PackedVector2Array()
	match kind:
		&"bolt":
			points = PackedVector2Array([Vector2(0.25, -1.0), Vector2(-0.6, 0.12), Vector2(-0.08, 0.12),
				Vector2(-0.3, 1.0), Vector2(0.6, -0.22), Vector2(0.08, -0.22), Vector2(0.5, -1.0)])
		&"heart":
			for index in 28:
				var t := index * TAU / 28.0
				points.append(Vector2(16.0 * pow(sin(t), 3.0),
					-(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)) - 2.5) / 16.5)
		&"drop":
			points.append(Vector2(0, -1.0))
			for index in 17:
				points.append(Vector2(0, 0.3) + Vector2.from_angle(-0.5 + index * (PI + 1.0) / 16.0) * 0.68)
		&"star":
			points = ToonDraw.star(Vector2.ZERO, 1.0, 5, 0.5)
		&"twinkle":
			points = ToonDraw.star(Vector2.ZERO, 1.0, 4, 0.36)
		&"nut":
			for index in 6:
				points.append(Vector2.from_angle(index * TAU / 6.0) * 0.92)
		&"leaf":
			for index in 9:
				points.append(Vector2(-1.0 + index * 0.25, -0.5 * sin(index * PI / 8.0)))
			for index in range(7, 0, -1):
				points.append(Vector2(-1.0 + index * 0.25, 0.5 * sin(index * PI / 8.0)))
		&"candy":
			for index in 20:
				points.append(Vector2.from_angle(index * TAU / 20.0) * 0.9)
	_shapes[kind] = points
	return points


## Draws the shape with an outline, in the canvas's current transform.
static func draw_shape(canvas: CanvasItem, kind: StringName, center: Vector2, size: float, fill: Color, line: Color, line_width := 2.5) -> void:
	var unit := shape(kind)
	for pass_index in 2:
		var radius := size + line_width if pass_index == 0 else size
		var points := PackedVector2Array()
		for point in unit:
			points.append(center + point * radius)
		ToonDraw.polygon(canvas, points, line if pass_index == 0 else fill)
	if kind == &"candy":
		# Peppermint swirl: three wedges in the outline colour on the white disc.
		for wedge in 3:
			var points := PackedVector2Array([center])
			for step in 5:
				points.append(center + Vector2.from_angle(wedge * TAU / 3.0 + step * TAU / 24.0) * size * 0.9)
			ToonDraw.polygon(canvas, points, line)
	if kind == &"nut":
		canvas.draw_circle(center, size * 0.36, line, true, -1.0, true)

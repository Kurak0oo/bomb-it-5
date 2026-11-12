extends RefCounted
## Explosion lab: smooth-edged drawing helpers. The Compatibility renderer has no 2D
## MSAA, so shapes bring their own antialiasing: polygons get a one-pixel feathered
## edge line, boxes use StyleBoxFlat's built-in edge smoothing.


static func polygon(canvas: CanvasItem, points: PackedVector2Array, colour: Color) -> void:
	canvas.draw_colored_polygon(points, colour)
	var edge := points.duplicate()
	edge.append(points[0])
	edge.append(points[1])
	canvas.draw_polyline(edge, colour, 1.0, true)


## A star with `spikes` points; `inner` is the inner radius as a share of `radius`.
static func star(center: Vector2, radius: float, spikes: int, inner: float, angle := -PI / 2.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in spikes * 2:
		var length := radius if index % 2 == 0 else radius * inner
		points.append(center + Vector2.from_angle(angle + index * PI / spikes) * length)
	return points


static func box(canvas: CanvasItem, rect: Rect2, colour: Color, radius: int, line := Color.TRANSPARENT, line_width := 0) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = colour
	style.set_corner_radius_all(radius)
	style.border_color = line
	style.set_border_width_all(line_width)
	style.anti_aliasing_size = 1.0
	canvas.draw_style_box(style, rect)

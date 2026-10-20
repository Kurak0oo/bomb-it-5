extends RefCounted
## Project-owned painted atlases. Region drawing never edits source images.

const PROPS = preload("res://assets/art/cinema-atlas-v1.png")
const ROBOT = preload("res://assets/art/robot-atlas-v1.png")
const COLORS := [Color("83dcff"), Color("ffa4c9"), Color("9cf0bf"), Color("ffda80")]
const SLOTS := {&"popcorn": 0, &"drink": 1, &"seat": 2, &"spotlight": 3,
	&"projector": 4, &"carpet": 5, &"bomb": 6, &"landmine": 7,
	&"hammer": 8, &"flamer": 9, &"laser": 10, &"triple": 11,
	&"shotgun": 12, &"car": 13, &"moto": 14, &"shield": 15,
	&"life": 16, &"invincible": 17, &"capacity": 18, &"power": 19,
	&"speed": 20, &"portal": 21, &"ghost": 22, &"trophy": 23}


static func prop(canvas: CanvasItem, kind: StringName, at: Vector2, size: Vector2,
		tint: Color = Color.WHITE, angle: float = 0.0) -> void:
	if not SLOTS.has(kind): return
	var slot: int = SLOTS[kind]
	canvas.draw_set_transform(at, angle)
	canvas.draw_texture_rect_region(PROPS, Rect2(-size * 0.5, size),
		Rect2(Vector2(slot % 6, slot / 6) * 256, Vector2.ONE * 256), tint)
	canvas.draw_set_transform(Vector2.ZERO)


static func robot(canvas: CanvasItem, at: Vector2, size: Vector2, facing: Vector2,
		frame: int, tint: Color = Color.WHITE) -> void:
	var row := 0 if facing.y > 0 else 2 if facing.y < 0 else 1 if facing.x > 0 else 3
	var pitch := Vector2(ROBOT.get_size()) / 4.0
	canvas.draw_texture_rect_region(ROBOT, Rect2(at - size * 0.5, size),
		Rect2(Vector2(frame, row) * pitch, pitch), tint)

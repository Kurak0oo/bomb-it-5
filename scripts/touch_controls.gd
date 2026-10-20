extends Node2D
## Independent touch contacts; presentation never synthesizes held bomb repeats.

const Art = preload("res://scripts/game_art.gd")

signal direction_changed(direction: Vector2)
signal bomb_event(event: StringName)

const STICK := Vector2(145, 535)
const BOMB := Vector2(1115, 535)
const DIRECTIONS := [Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Vector2(-1, 1),
	Vector2(-1, 0), Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1)]

var enabled := true
var stick_contact := -1
var bomb_contact := -1
var thumb := Vector2.ZERO
var target := Vector2.ZERO
var action_kind: StringName = &"bomb"


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func reset() -> void:
	stick_contact = -1
	bomb_contact = -1
	target = Vector2.ZERO
	direction_changed.emit(Vector2.ZERO)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if stick_contact == -1 and to_local(event.position).distance_to(STICK) <= 92:
				stick_contact = event.index
				_drag(to_local(event.position))
			elif bomb_contact == -1 and to_local(event.position).distance_to(BOMB) <= 68:
				bomb_contact = event.index
				bomb_event.emit(&"down")
		else:
			if event.index == stick_contact:
				stick_contact = -1
				target = Vector2.ZERO
				direction_changed.emit(Vector2.ZERO)
			if event.index == bomb_contact:
				bomb_contact = -1
				bomb_event.emit(&"up")
		queue_redraw()
	elif event is InputEventScreenDrag and event.index == stick_contact:
		_drag(to_local(event.position))


func _drag(at: Vector2) -> void:
	target = (at - STICK).limit_length(64)
	var sector := posmod(roundi(target.angle() / (PI / 4.0)), 8)
	direction_changed.emit(Vector2.ZERO if target.length() < 14 else DIRECTIONS[sector].normalized())
	queue_redraw()


func _process(delta: float) -> void:
	thumb = thumb.move_toward(target, delta * 900)
	queue_redraw()


func _draw() -> void:
	var alpha := 1.0 if enabled else 0.45
	draw_circle(STICK + Vector2(0, 4), 84, Color("101c30", 0.45 * alpha))
	draw_circle(STICK, 82, Color("8bd8ed", 0.09 * alpha))
	draw_arc(STICK, 80, 0, TAU, 64, Color("83b8ca", 0.5 * alpha), 2, true)
	draw_arc(STICK, 74, 0, TAU, 64, Color("a1d3df", 0.14 * alpha), 1, true)
	for n in 8:
		var direction := Vector2.from_angle(n * TAU / 8)
		draw_line(STICK + direction * 64, STICK + direction * 69, Color("a9d5da", 0.35 * alpha), 2, true)
	draw_circle(STICK + thumb + Vector2(0, 3), 28, Color("101c30", 0.3 * alpha))
	draw_circle(STICK + thumb, 28, Color("83d7e9", (0.6 if stick_contact != -1 else 0.23) * alpha))
	draw_arc(STICK + thumb, 27, 0, TAU, 32, Color("b1e7ec", 0.65 * alpha), 2, true)
	draw_arc(STICK + thumb - Vector2(0, 1), 22, PI, TAU, 24, Color("d9fff8", 0.25 * alpha), 2, true)
	var pressed := bomb_contact != -1
	draw_circle(BOMB + Vector2(0, 5), 64, Color("101c30", 0.55 * alpha))
	draw_circle(BOMB, 61 if not pressed else 57, Color("dda366", (0.14 if not pressed else 0.4) * alpha))
	draw_arc(BOMB, 64, 0, TAU, 64, Color("e4bb7e", 0.65 * alpha), 2, true)
	draw_arc(BOMB, 58, PI * 1.12, PI * 1.88, 32, Color("ffdf9c", 0.35 * alpha), 2, true)
	Art.prop(self, action_kind, BOMB + Vector2(0, -8 if not pressed else -3),
		Vector2.ONE * (53 if not pressed else 47), Color(1, 1, 1, alpha))
	draw_string(ThemeDB.fallback_font, BOMB + Vector2(-24, 34), "USE", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("ffe2a0", alpha))

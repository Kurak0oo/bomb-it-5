extends Node2D
## Independent touch contacts; presentation never synthesizes held bomb repeats.

signal direction_changed(direction: Vector2)
signal bomb_event(event: StringName)

const STICK := Vector2(145, 535)
const BOMB := Vector2(1115, 535)
const VisualSkin = preload("res://scripts/art/skin.gd")
const ArtCatalog = preload("res://scripts/art/catalog.gd")
const Fidelity = preload("res://scripts/fidelity.gd")
const DIRECTIONS := [Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Vector2(-1, 1),
	Vector2(-1, 0), Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1)]

var enabled := true
var stick_contact := -1
var bomb_contact := -1
var thumb := Vector2.ZERO
var target := Vector2.ZERO
var skin: RefCounted = VisualSkin.new()


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
	# Original profile: four quarter sectors around the dominant axis (no diagonals).
	var sector := posmod(roundi(target.angle() / (PI / 2.0)), 4) * 2 if Fidelity.original else posmod(roundi(target.angle() / (PI / 4.0)), 8)
	direction_changed.emit(Vector2.ZERO if target.length() < 14 else DIRECTIONS[sector].normalized())
	queue_redraw()


func _process(delta: float) -> void:
	thumb = thumb.move_toward(target, delta * 900)
	queue_redraw()


func _draw() -> void:
	if not skin.draw(self, "control.stick_base", ArtCatalog.rect("control.stick_base", STICK)):
		draw_circle(STICK, 84, Color(0.6, 0.8, 1.0, 0.09))
		draw_arc(STICK, 80, 0, TAU, 64, Color(0.6, 0.8, 1.0, 0.35), 2, true)
		draw_arc(STICK, 14, 0, TAU, 32, Color(0.6, 0.8, 1.0, 0.12), 1, true)
	if not skin.draw(self, "control.stick_thumb", ArtCatalog.rect("control.stick_thumb", STICK + thumb)):
		draw_circle(STICK + thumb, 27, Color(0.55, 0.83, 1.0, 0.6 if stick_contact != -1 else 0.25))
		draw_arc(STICK + thumb, 27, 0, TAU, 32, Color("8cceea"), 2, true)
	var mode := "disabled" if not enabled else "pressed" if bomb_contact != -1 else "normal"
	var replaced: bool = skin.draw(self, "control.action_" + mode, ArtCatalog.rect("control.action_" + mode, BOMB))
	if not replaced and mode != "normal": replaced = skin.draw(self, "control.action_normal", ArtCatalog.rect("control.action_normal", BOMB))
	if not replaced:
		draw_circle(BOMB, 61 if bomb_contact == -1 else 56, Color(1.0, 0.72, 0.4, 0.23 if bomb_contact == -1 else 0.55))
		draw_arc(BOMB, 64, 0, TAU, 64, Color("c29f70"), 2, true)
		draw_string(ThemeDB.fallback_font, BOMB + Vector2(-28, 7), "BOMB", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("ffdda0"))

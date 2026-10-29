extends Node2D
## Independent touch contacts; presentation never synthesizes held bomb repeats.

signal direction_changed(direction: Vector2)
signal bomb_event(event: StringName)

## Bottom-left and bottom-right on the side areas, clear of every playable cell on the
## replica page (zones 5 and 6) and inside the adapted layout's side columns.
const STICK := Vector2(150, 560)
const BOMB := Vector2(1130, 560)
const STICK_REACH := 92.0
const BOMB_REACH := 80.0
const Quality = preload("res://scripts/quality.gd")
const VisualSkin = preload("res://scripts/art/skin.gd")
const ArtCatalog = preload("res://scripts/art/catalog.gd")
const DIRECTIONS := [Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Vector2(-1, 1),
	Vector2(-1, 0), Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1)]

var enabled := true
var stick_contact := -1
var bomb_contact := -1
var thumb := Vector2.ZERO
var target := Vector2.ZERO
var skin: RefCounted = VisualSkin.new()
## Replica style (#78): the mockup's translucent ring with direction marks and gold thumb, and
## a round bomb button that shows the equipped item. Set by the round host.
var replica := false
## The weapon or item that replaces bomb placement, or `&""` for ordinary bombs.
var item: StringName = &""
const GOLD := Color("f2c35b")


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
			if stick_contact == -1 and to_local(event.position).distance_to(STICK) <= STICK_REACH:
				stick_contact = event.index
				_drag(to_local(event.position))
			elif bomb_contact == -1 and to_local(event.position).distance_to(BOMB) <= BOMB_REACH:
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
	# Eight sectors in both profiles: decision E keeps the stick eight-way on the replica.
	var sector := posmod(roundi(target.angle() / (PI / 4.0)), 8)
	direction_changed.emit(Vector2.ZERO if target.length() < 14 else DIRECTIONS[sector].normalized())
	queue_redraw()


func _process(delta: float) -> void:
	thumb = thumb.move_toward(target, delta * 900)
	queue_redraw()


func _draw() -> void:
	if replica:
		_draw_replica()
		return
	if not skin.draw(self, "control.stick_base", ArtCatalog.rect("control.stick_base", STICK)):
		draw_circle(STICK, 84, Color(0.6, 0.8, 1.0, 0.09))
		draw_arc(STICK, 80, 0, TAU, 64, Color(0.6, 0.8, 1.0, 0.35), 2, Quality.edges)
		draw_arc(STICK, 14, 0, TAU, 32, Color(0.6, 0.8, 1.0, 0.12), 1, Quality.edges)
	if not skin.draw(self, "control.stick_thumb", ArtCatalog.rect("control.stick_thumb", STICK + thumb)):
		draw_circle(STICK + thumb, 27, Color(0.55, 0.83, 1.0, 0.6 if stick_contact != -1 else 0.25))
		draw_arc(STICK + thumb, 27, 0, TAU, 32, Color("8cceea"), 2, Quality.edges)
	var mode := "disabled" if not enabled else "pressed" if bomb_contact != -1 else "normal"
	var replaced: bool = skin.draw(self, "control.action_" + mode, ArtCatalog.rect("control.action_" + mode, BOMB))
	if not replaced and mode != "normal": replaced = skin.draw(self, "control.action_normal", ArtCatalog.rect("control.action_normal", BOMB))
	if not replaced:
		draw_circle(BOMB, 61 if bomb_contact == -1 else 56, Color(1.0, 0.72, 0.4, 0.23 if bomb_contact == -1 else 0.55))
		draw_arc(BOMB, 64, 0, TAU, 64, Color("c29f70"), 2, Quality.edges)
		draw_string(ThemeDB.fallback_font, BOMB + Vector2(-28, 7), "BOMB", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("ffdda0"))


## The accepted mockup's controls; workbench slots still replace each part.
func _draw_replica() -> void:
	var held := stick_contact != -1
	if not skin.draw(self, "control.stick_base", ArtCatalog.rect("control.stick_base", STICK)):
		draw_circle(STICK, 84, Color(0.1, 0.05, 0.12, 0.30))
		draw_arc(STICK, 84, 0, TAU, 72, Color(1, 0.93, 0.78, 0.55), 3, Quality.edges)
		for index in 4:
			var axis := Vector2.RIGHT.rotated(index * PI / 2)
			var tip := STICK + axis * 70
			draw_colored_polygon(PackedVector2Array([tip, tip - axis * 12 + axis.orthogonal() * 9, tip - axis * 12 - axis.orthogonal() * 9]),
				Color(1, 0.95, 0.85, 0.75 if held and target.normalized().dot(axis) > 0.38 else 0.45))
	if not skin.draw(self, "control.stick_thumb", ArtCatalog.rect("control.stick_thumb", STICK + thumb)):
		var at := STICK + thumb
		draw_circle(at + Vector2(0, 3), 30, Color(0, 0, 0, 0.25))
		draw_circle(at, 30, GOLD.darkened(0.25))
		draw_circle(at + Vector2(-2, -3), 26, GOLD.lightened(0.15 if held else 0.0))
		draw_arc(at, 30, 0, TAU, 48, Color("8a5a1c"), 2, Quality.edges)
	var mode := "disabled" if not enabled else "pressed" if bomb_contact != -1 else "normal"
	var replaced: bool = skin.draw(self, "control.action_" + mode, ArtCatalog.rect("control.action_" + mode, BOMB))
	if not replaced and mode != "normal": replaced = skin.draw(self, "control.action_normal", ArtCatalog.rect("control.action_normal", BOMB))
	if not replaced:
		var radius := 66.0 if bomb_contact == -1 else 62.0
		var alpha := 0.45 if mode == "disabled" else 1.0
		draw_circle(BOMB + Vector2(0, 4), radius, Color(0, 0, 0, 0.3 * alpha))
		draw_circle(BOMB, radius, Color(GOLD, alpha))
		draw_circle(BOMB, radius - 5, Color(Color("e0582f").darkened(0.15 if mode == "pressed" else 0.0), alpha))
		draw_arc(BOMB + Vector2(-8, -10), radius - 18, PI * 1.05, PI * 1.55, 24, Color(1, 1, 1, 0.35 * alpha), 6, Quality.edges)
	# The equipped item replaces the bomb icon, as the bomb button now uses it.
	var icon := Rect2(BOMB - Vector2.ONE * 32, Vector2.ONE * 64)
	if item != &"" and skin.draw(self, "item." + item, icon): return
	if item != &"":
		draw_string(ThemeDB.fallback_font, BOMB + Vector2(-60, 9), str(item).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 120, 22, Color(1, 0.97, 0.9))
		return
	if skin.draw(self, "effect.bomb", icon): return
	draw_circle(BOMB + Vector2(2, 4), 24, Color("1d1a2a"))
	draw_circle(BOMB + Vector2(-6, -4), 7, Color(1, 1, 1, 0.5))
	draw_line(BOMB + Vector2(14, -14), BOMB + Vector2(22, -24), GOLD, 4)
	draw_circle(BOMB + Vector2(24, -26), 5, Color("ffe08a"))

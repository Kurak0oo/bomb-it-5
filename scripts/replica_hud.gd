extends Node2D
## The replica's compact play HUD (DESIGN.md › Gameplay layout M2–M5; zones 1–3 of
## docs/design/replica-layout-zones.png): own status top-left, time and level top-centre,
## rivals and the pause icon top-right, all within the board's cropped top ring row or the
## side scenery. Outcomes play the original end cartoons over the map. Reads snapshots only.

signal pause_pressed

const ReplicaLayout = preload("res://scripts/replica_layout.gd")
const ArtCatalog = preload("res://scripts/art/catalog.gd")
## Same slots and colours as the view (GameView.ROBOT_SLOTS / ROBOT_COLORS).
const ROBOT_SLOTS := [&"human", &"ruby", &"lime", &"gold", &"violet", &"slate", &"mint", &"snow"]
const ROBOT_COLORS := [Color("66d8ff"), Color("ed86c6"), Color("b6e36a"), Color("ffd470"),
	Color("b394f0"), Color("9aa6b4"), Color("8ce2b5"), Color("f2f4f7")]
## Gold-and-purple chrome from the accepted mockup.
const PILL := Color(0.16, 0.09, 0.22, 0.86)
const GOLD := Color("f2c35b")
const INK := Color("fff3d6")
## Zone rectangles on the page.
const STATUS := Rect2(14, 8, 232, 72)
const TIMER := Rect2(565, 3, 150, 31)
const LEVEL := Rect2(610, 32, 60, 14)
const PAUSE_CENTER := Vector2(1244, 42)
const PAUSE_RADIUS := 27.0
## The original pause screen (`UI_pause`, a 700×510 page) fitted to the page height, and its
## painted MAIN MENU and RESUME buttons in stage coordinates.
const PAUSE_PAGE := Rect2(145.9, 0, 988.2, 720)
const PAUSE_MENU := Rect2(158, 395, 152, 40)
const PAUSE_RESUME := Rect2(360, 395, 153, 40)
## Rival badges right of the map, leftmost first.
const RIVAL_X := [1062.0, 1118.0, 1174.0]
const RIVAL_Y := 34.0
## The original stage (700×510, board at `GameConfig.EXCURSION_X/Y`, 30 px cells) on the page:
## end cartoons are authored in stage coordinates.
const STAGE_BOARD := Vector2(183, 40)
const STAGE_SIZE := Vector2(700, 510)
## Share of the 100-frame end cartoon its sheet covers.
const CARTOON_SHEET_SPAN := 0.2

var skin: RefCounted
var state: Dictionary = {}
var paused := false
## The pause control; a Button so desktop clicks and touch both reach it.
var pause_button: Button


func _ready() -> void:
	pause_button = Button.new()
	pause_button.name = "PauseIcon"
	pause_button.flat = true
	pause_button.focus_mode = Control.FOCUS_NONE
	pause_button.position = PAUSE_CENTER - Vector2.ONE * PAUSE_RADIUS
	pause_button.size = Vector2.ONE * PAUSE_RADIUS * 2
	var clear := StyleBoxEmpty.new()
	for name in ["normal", "hover", "pressed", "disabled", "focus"]: pause_button.add_theme_stylebox_override(name, clear)
	pause_button.pressed.connect(func(): pause_pressed.emit())
	add_child(pause_button)


func present(snapshot: Dictionary, is_paused: bool) -> void:
	state = snapshot
	paused = is_paused
	pause_button.disabled = state.is_empty() or state.outcome != &"running" or state.get("round_stage") == &"ending"
	queue_redraw()


## Page rectangle of a stage-space rectangle, at the board's scale.
static func stage_to_page(rect: Rect2) -> Rect2:
	var scale := ReplicaLayout.CELL / 30.0
	return Rect2(ReplicaLayout.BOARD.position + (rect.position - STAGE_BOARD) * scale, rect.size * scale)


## Rivals in roster order, as the badges show them.
func rivals() -> Array[StringName]:
	var result: Array[StringName] = []
	for id in state.get("actors", {}):
		if id != &"human": result.append(id)
	return result


func robot_of(id: StringName) -> int:
	return state.actors[id].get("robot", 0)


## Points shown in an actor's score slot: kills or flags out of 10 in Kill and Green Zone.
func score_text(id: StringName) -> String:
	var actor: Dictionary = state.actors[id]
	var points: int = actor.get("points", -1)
	if points >= 0 and state.get("mode") in [&"kill", &"green_zone"]: return "%d/%d" % [points, state.get("points_goal", 10)]
	return str(points if points >= 0 else actor.score)


func time_text() -> String:
	var seconds := ceili(state.get("remaining", 0) / 35.0)
	return "%d:%02d" % [seconds / 60, seconds % 60]


## Page rectangle of a rectangle on the pause screen's stage.
static func pause_to_page(rect: Rect2) -> Rect2:
	var scale := PAUSE_PAGE.size.y / STAGE_SIZE.y
	return Rect2(PAUSE_PAGE.position + rect.position * scale, rect.size * scale)


## Whether the pause screen shows the original art (its buttons are then ghosts).
func pause_art() -> bool:
	return skin != null and skin.texture("screen.pause") != null


func _draw() -> void:
	if state.is_empty() or not state.actors.has(&"human"): return
	_cartoon()
	_status(state.actors[&"human"])
	_timer()
	var rows := rivals()
	for index in rows.size():
		_rival(rows[index], Vector2(RIVAL_X[index + 3 - rows.size()], RIVAL_Y))
	_pause_icon()
	if paused: _pause_screen()


## Opened from the pause icon or P: the original pause page over the whole screen.
func _pause_screen() -> void:
	draw_rect(Rect2(-ReplicaLayout.PAGE, ReplicaLayout.PAGE * 3), Color(0, 0, 0, 0.55))
	if pause_art() and skin.draw(self, "screen.pause", PAUSE_PAGE): return
	var panel := Rect2(440, 200, 400, 320)
	_pill(panel, 24)
	draw_string(ThemeDB.fallback_font, panel.position + Vector2(0, 80), "PAUSE", HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 44, GOLD)


func _status(actor: Dictionary) -> void:
	_pill(STATUS, STATUS.size.y / 2)
	var face := STATUS.position + Vector2(36, 36)
	_portrait(robot_of(&"human"), face, 28)
	_text(STATUS.position + Vector2(76, 32), score_text(&"human"), 22, INK)
	_heart(STATUS.position + Vector2(160, 24), 9)
	_text(STATUS.position + Vector2(174, 32), "×%d" % actor.lives, 20, INK)
	var speed := roundi((actor.speed - 1.6) / 0.1) + 1
	var counts := [["bomb", actor.capacity], ["flame", actor.power], ["bolt", speed]]
	for index in counts.size():
		var at := STATUS.position + Vector2(80 + index * 52, 56)
		_glyph(counts[index][0], at)
		_text(at + Vector2(11, 6), str(counts[index][1]), 16, INK)


func _timer() -> void:
	_pill(TIMER, TIMER.size.y / 2)
	_glyph("hourglass", TIMER.position + Vector2(22, 15))
	_text(TIMER.position + Vector2(44, 24), time_text(), 22, INK)
	var level: String = state.get("session", {}).get("level", "")
	if level == "": return
	var badge := StyleBoxFlat.new()
	badge.bg_color = Color("5b3486")
	badge.border_color = GOLD
	badge.set_border_width_all(1)
	badge.set_corner_radius_all(7)
	draw_style_box(badge, LEVEL)
	draw_string(ThemeDB.fallback_font, LEVEL.position + Vector2(0, 11), level, HORIZONTAL_ALIGNMENT_CENTER, LEVEL.size.x, 11, INK)


func _rival(id: StringName, at: Vector2) -> void:
	var actor: Dictionary = state.actors[id]
	var faded := 1.0 if actor.alive or actor.get("respawn_at", 0) > 0 else 0.45
	_portrait(robot_of(id), at, 24, faded)
	var tag := Rect2(at + Vector2(-22, 17), Vector2(44, 16))
	_pill(tag, 8)
	draw_string(ThemeDB.fallback_font, tag.position + Vector2(0, 13), score_text(id), HORIZONTAL_ALIGNMENT_CENTER, tag.size.x, 12, INK)
	if state.get("mode") == &"arcade" or actor.lives > 1:
		_heart(at + Vector2(17, -18), 5)
		_text(at + Vector2(23, -14), str(actor.lives), 11, INK)


func _pause_icon() -> void:
	draw_circle(PAUSE_CENTER, PAUSE_RADIUS, GOLD)
	draw_circle(PAUSE_CENTER, PAUSE_RADIUS - 4, Color("5b3486") if not paused else Color("7a4bb0"))
	for x in [-7.0, 4.0]:
		draw_rect(Rect2(PAUSE_CENTER + Vector2(x, -10), Vector2(5, 20)), INK)


## The original `GameEndCartoon`: the round's end clip over the stage, tweened to its last
## frame over the 3-second ending (`ending_progress`).
func _cartoon() -> void:
	var ending: bool = state.get("round_stage") == &"ending"
	if not ending and state.outcome == &"running": return
	var outcome: StringName = state.pending_outcome if ending else state.outcome
	# The sheet holds clip frames 1-20 of 100; the tween reaches frame 20 at 20 % (see the slot note).
	var progress: float = minf(1.0, state.get("ending_progress", 0.0) / CARTOON_SHEET_SPAN) if ending else 1.0
	var slot := "cartoon." + str(outcome)
	if skin != null and skin.draw(self, slot, stage_to_page(Rect2(Vector2.ZERO, STAGE_SIZE)), 0, Vector2.DOWN, progress): return
	# Native fallback: a dimmed map and the outcome word, no banner chrome.
	draw_rect(ReplicaLayout.MAP, Color(0, 0, 0, 0.35 * minf(1.0, progress * 3)))
	var word: String = {&"won": "YOU WIN!", &"lost": "YOU LOSE!", &"timeout": "TIME'S UP!"}.get(outcome, "")
	draw_string_outline(ThemeDB.fallback_font, Vector2(ReplicaLayout.MAP.position.x, 375), word, HORIZONTAL_ALIGNMENT_CENTER, ReplicaLayout.MAP.size.x, 54, 8, Color("5b1e3e"))
	draw_string(ThemeDB.fallback_font, Vector2(ReplicaLayout.MAP.position.x, 375), word, HORIZONTAL_ALIGNMENT_CENTER, ReplicaLayout.MAP.size.x, 54, Color("ff6fae"))


func _portrait(robot: int, at: Vector2, radius: float, alpha := 1.0) -> void:
	draw_circle(at, radius + 2, Color(GOLD, alpha))
	draw_circle(at, radius, Color(ROBOT_COLORS[robot].darkened(0.55), alpha))
	var slot := "actor.%s.portrait" % ROBOT_SLOTS[robot]
	if skin != null and skin.draw(self, slot, Rect2(at - Vector2.ONE * radius, Vector2.ONE * radius * 2), 0, Vector2.DOWN, -1, Color(1, 1, 1, alpha)): return
	draw_circle(at, radius - 4, Color(ROBOT_COLORS[robot], alpha))


func _pill(rect: Rect2, radius: float) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = PILL
	style.border_color = GOLD
	style.set_border_width_all(2)
	style.set_corner_radius_all(int(radius))
	draw_style_box(style, rect)


func _heart(at: Vector2, size: float) -> void:
	draw_circle(at + Vector2(-size * 0.45, 0), size * 0.55, Color("ff4d6d"))
	draw_circle(at + Vector2(size * 0.45, 0), size * 0.55, Color("ff4d6d"))
	draw_colored_polygon(PackedVector2Array([at + Vector2(-size, size * 0.15), at + Vector2(size, size * 0.15), at + Vector2(0, size * 1.1)]), Color("ff4d6d"))


func _glyph(kind: String, at: Vector2) -> void:
	match kind:
		"bomb":
			draw_circle(at, 7, Color("1d1a2a"))
			draw_arc(at, 7, 0, TAU, 16, INK, 1.5, true)
			draw_line(at + Vector2(4, -5), at + Vector2(7, -9), GOLD, 2)
		"flame":
			draw_colored_polygon(PackedVector2Array([at + Vector2(0, -9), at + Vector2(6, 2), at + Vector2(0, 8), at + Vector2(-6, 2)]), Color("ff8a3d"))
			draw_circle(at + Vector2(0, 3), 3, Color("ffe08a"))
		"bolt":
			draw_colored_polygon(PackedVector2Array([at + Vector2(2, -9), at + Vector2(-5, 1), at + Vector2(0, 1),
				at + Vector2(-2, 9), at + Vector2(5, -1), at + Vector2(0, -1)]), Color("7cc7ff"))
		"hourglass":
			draw_colored_polygon(PackedVector2Array([at + Vector2(-7, -10), at + Vector2(7, -10), at + Vector2(0, 0)]), GOLD)
			draw_colored_polygon(PackedVector2Array([at + Vector2(-7, 10), at + Vector2(7, 10), at + Vector2(0, 0)]), GOLD)


func _text(at: Vector2, text: String, size_px: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)

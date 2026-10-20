extends Node2D
## Read-only painted presentation. Every gameplay animation samples admitted state.

const Art = preload("res://scripts/game_art.gd")
const PITCH := 36.0
const ORIGIN := Vector2(334, 86)
const IDS := [&"human", &"ruby", &"mint", &"gold"]
const COLORS := Art.COLORS
const INK := Color("171c36")
const GOLD := Color("ffe5a0")
const CREAM := Color("f7f1dc")

var state: Dictionary = {}
var practice := true
var paused := false
var motion: Dictionary = {}


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func present(snapshot: Dictionary, is_practice: bool, is_paused: bool) -> void:
	if state.is_empty() or snapshot.tick == 0 or snapshot.tick < state.tick:
		motion.clear()
	elif snapshot.tick > state.tick:
		for id in snapshot.actors:
			motion[id] = state.actors.has(id) and not snapshot.actors[id].position.is_equal_approx(state.actors[id].position)
	state = snapshot
	practice = is_practice
	paused = is_paused
	queue_redraw()


func _draw() -> void:
	_shell()
	if state.is_empty(): return
	_panel(Rect2(790, 25, 157, 43), INK, Color("6c9da6"), 12)
	_label(Vector2(805, 53), "TIME  %03d" % ceili(state.remaining / 35.0), 23,
		Color("ff9788") if state.remaining <= 1050 else GOLD)
	_board_frame()
	for cell in state.board: _tile(cell, state.board[cell])
	_marquee()
	for cell in state.pickups: _pickup(cell, state.pickups[cell])
	for bomb in state.bombs:
		var mine: bool = bomb.get("kind", &"bomb") == &"mine"
		var at := _center(bomb.cell)
		_shadow(at + Vector2(0, 11), 12)
		var pulse := 1.0 + sin(state.tick * 0.7) * 0.035
		Art.prop(self, &"landmine" if mine else &"bomb", at + Vector2(0, -3), Vector2(36, 36) * pulse)
	_flames()
	for attack in state.attacks:
		if attack.get("layer") == &"behind": _attack(attack)
	for projectile in state.projectiles:
		if projectile.get("phase") == &"cleanup": continue
		var at: Vector2 = ORIGIN + (projectile.position + Vector2.ONE * 0.5) * PITCH
		Art.prop(self, &"shotgun", at, Vector2(31, 26) if projectile.kind == &"triple" else Vector2(41, 35),
			Color.WHITE, Vector2(projectile.direction).angle())
	var visible: Array = IDS.filter(func(id): return state.actors.has(id))
	visible.sort_custom(func(a, b): return state.actors[a].position.y < state.actors[b].position.y)
	for id in visible: _actor(state.actors[id], IDS.find(id))
	for attack in state.attacks:
		if attack.get("layer") != &"behind": _attack(attack)
	for index in IDS.size():
		if state.actors.has(IDS[index]): _hud(state.actors[IDS[index]], index)
	_instructions()
	if paused or state.outcome != &"running" or state.get("round_stage") == &"ending": _overlay()


func _shell() -> void:
	draw_rect(Rect2(-position - get_parent().position, get_viewport_rect().size + Vector2(100, 100)), Color("101c30"))
	_panel(Rect2(12, 12, 1256, 696), Color("183e51"), Color("67a9b3"), 22)
	_panel(Rect2(21, 21, 1238, 678), Color("163446"), Color("264e63"), 16)
	for x in [37, 1243]:
		for y in [37, 683]:
			draw_circle(Vector2(x, y), 6, Color("527884"))
			draw_line(Vector2(x - 3, y + 2), Vector2(x + 3, y - 2), INK, 2, true)
	_label(Vector2(48, 51), "LOCAL ARCADE", 25, GOLD)
	_label(Vector2(48, 72), "PRACTICE. THEN PLAY." if practice else "ONE ARENA. THREE RIVALS.", 11, Color("9bc4cc"))
	_label(Vector2(334, 49), "CINEMA", 30, GOLD)
	_label(Vector2(477, 47), "PRACTICE" if practice else "ARCADE / NORMAL", 14, Color("abd3d6"))
	for x in [334, 984]: draw_line(Vector2(x, 30), Vector2(x, 68), Color("3d6573"), 1)


func _board_frame() -> void:
	_panel(Rect2(ORIGIN - Vector2(10, 10), Vector2(632, 560)), Color("ae5864"), Color("efb08b"), 9)
	_panel(Rect2(ORIGIN - Vector2(5, 5), Vector2(622, 550)), INK, Color("542a49"), 5)
	for x in range(343, 948, 30):
		for y in [80, 632]: draw_circle(Vector2(x, y), 2, Color("ffdb8c"))


func _tile(cell: Vector2i, kind: StringName) -> void:
	var at := ORIGIN + Vector2(cell) * PITCH
	draw_rect(Rect2(at, Vector2.ONE * PITCH), Color("432644") if (cell.x + cell.y) % 2 else Color("48294b"))
	# Fine carpet weave is decorative and deterministic, with no visual clock.
	for n in 3:
		var inset := Vector2(5 + n * 11, 8 + (cell.x * 7 + cell.y * 3 + n * 9) % 22)
		draw_line(at + inset, at + inset + Vector2(4, 1), Color("55304f"), 1, true)
	if kind == &"solid":
		if cell.x == 0 or cell.y == 0 or cell.x == 16 or cell.y == 14:
			_panel(Rect2(at + Vector2.ONE, Vector2.ONE * 34), Color("22586b"), Color("508b9b"), 5)
			draw_line(at + Vector2(5, 5), at + Vector2(31, 5), Color("6bafbd"), 2, true)
			draw_line(at + Vector2(5, 31), at + Vector2(31, 31), Color("15354a"), 3, true)
		else:
			_shadow(at + Vector2(19, 30), 13)
			Art.prop(self, &"spotlight" if (cell.x + cell.y) % 3 == 0 else &"seat",
				at + Vector2(18, 16), Vector2(37, 39))
	elif kind == &"soft":
		_shadow(at + Vector2(18, 30), 12)
		Art.prop(self, &"drink" if (cell.x + cell.y) % 2 else &"popcorn",
			at + Vector2(18, 16), Vector2(37, 39))
	elif kind == &"portal":
		var tint := Color("a6ffd8") if cell.x == 8 else Color("e1bcff")
		draw_circle(at + Vector2.ONE * 18, 17, Color(tint, 0.12))
		Art.prop(self, &"portal", at + Vector2.ONE * 18, Vector2(37, 33), tint)
		for n in 3:
			var angle: float = state.tick * 0.06 + n * TAU / 3
			draw_circle(at + Vector2.ONE * 18 + Vector2.from_angle(angle) * 12, 1.3, Color(tint, 0.85))


func _marquee() -> void:
	var at := ORIGIN + Vector2(7, 6) * PITCH
	_panel(Rect2(at + Vector2(1, 1), Vector2(106, 106)), Color("7f294a"), Color("f2be77"), 11)
	_panel(Rect2(at + Vector2(7, 28), Vector2(94, 71)), Color("1b4150"), Color("c7836c"), 5)
	Art.prop(self, &"projector", at + Vector2(54, 63), Vector2(67, 65))
	_label(at + Vector2(13, 23), "★ CINEMA ★", 14, GOLD)
	for n in 6: draw_circle(at + Vector2(10 + n * 17, 101), 2.1, GOLD)


func _pickup(cell: Vector2i, kind: StringName) -> void:
	var at := _center(cell)
	_shadow(at + Vector2(0, 12), 11)
	var offset := sin((state.tick + cell.x * 3 + cell.y) * 0.12) * 1.1
	draw_circle(at, 14, Color("97ebe1", 0.12))
	draw_arc(at, 14, 0, TAU, 28, Color("b9f5de", 0.65), 1, true)
	Art.prop(self, kind, at + Vector2(0, -2 + offset), Vector2.ONE * 30)


func _flames() -> void:
	for flame in state.flames:
		var count: int = flame.get("count", 0)
		var fading := clampf((17.0 - count) / 5.0, 0.12, 1.0)
		for cell in flame.cells:
			var at := _center(cell)
			var lethal: bool = state.get("fire", []).has(cell)
			var alpha := maxf(0.75, fading) if lethal else fading * 0.22
			for direction in [Vector2i.RIGHT, Vector2i.DOWN]:
				if flame.cells.has(cell + direction):
					draw_line(at, _center(cell + direction), Color("ff7d39", alpha * 0.65), 20 * fading, true)
			Art.prop(self, &"power", at + Vector2(0, -3), Vector2(36, 43) * (0.85 + fading * 0.15),
				Color(1, 1, 1, alpha))


func _actor(actor: Dictionary, index: int) -> void:
	var at: Vector2 = ORIGIN + (actor.position + Vector2.ONE * 0.5) * PITCH
	var tint: Color = COLORS[index]
	if not actor.alive:
		if actor.get("removed", false): return
		var progress := clampf(actor.get("death_frame", 1) / 60.0, 0, 1)
		Art.prop(self, &"ghost", at + Vector2(sin(progress * TAU) * 6, -8 - progress * 30),
			Vector2.ONE * (38 + progress * 8), Color(tint, 1.0 - progress * 0.8))
		return
	var transferring: bool = actor.transit_until > 0
	if transferring:
		tint.a = clampf(float(actor.transit_until - state.tick + 5) / 35.0, 0.14, 1.0)
		draw_arc(at, 19, state.tick * 0.3, state.tick * 0.3 + PI * 1.5, 24, COLORS[index], 2, true)
	_shadow(at + Vector2(0, 12), 13)
	var recovering: bool = actor.get("vehicle_recovery_until", 0) > state.tick
	var riding: bool = actor.vehicle != &""
	if riding:
		var shake := sin(state.tick * 2.0) * 2.5 if recovering else 0.0
		Art.prop(self, actor.vehicle, at + Vector2(shake, 6), Vector2(45, 35),
			Color("ffb098") if recovering else Color.WHITE)
	if actor.shield > 0 or actor.protected_until > state.tick:
		draw_circle(at, 21, Color("98f6ff", 0.11))
		draw_arc(at, 21, 0, TAU, 40, Color("a3f2ff", 0.8), 1.5, true)
	if actor.invincible_until > state.tick:
		var radius := 24.0 + (sin(state.tick * 0.2) * 3 if actor.get("protection_stage") == &"introduction" else 0.0)
		for n in 3:
			Art.prop(self, &"invincible", at + Vector2.from_angle(state.tick * 0.12 + n * TAU / 3) * radius, Vector2.ONE * 11)
	if actor.blink_until > state.tick or actor.get("protection_stage") == &"blink":
		tint = tint.lightened(0.45 if state.tick % 6 < 3 else 0)
	var moving: bool = motion.get(IDS[index], false)
	var frame: int = 1 + (state.tick / 5) % 2 if moving and not riding else 0
	if state.attacks.any(func(attack): return attack.actor_id == IDS[index]): frame = 3
	Art.robot(self, at + Vector2(0, -9 if riding else -7), Vector2(40, 40), actor.facing, frame, tint)
	if actor.weapon != &"":
		Art.prop(self, actor.weapon, at + Vector2(actor.facing) * 12 + Vector2(1, 1), Vector2(23, 22), Color.WHITE,
			PI if actor.facing.x < 0 else -PI / 2 if actor.facing.y < 0 else PI / 2 if actor.facing.y > 0 else 0)
	if index == 0:
		draw_colored_polygon(PackedVector2Array([at + Vector2(-3, -34), at + Vector2(3, -34), at + Vector2(0, -29)]), GOLD)
	if not moving and not transferring and not recovering and actor.busy_until <= state.tick and frame != 3:
		for command in state.get("commands", []):
			if command.actor_id == IDS[index] and command.direction != Vector2.ZERO:
				var impact: Vector2 = at + command.direction * 15
				draw_line(impact + Vector2(-3, -3), impact + Vector2(3, 3), Color("ffd696"), 2, true)
				draw_line(impact + Vector2(-3, 3), impact + Vector2(3, -3), Color("ffd696"), 2, true)


func _hud(actor: Dictionary, index: int) -> void:
	var at := Vector2(40, 94 + index * 85)
	_panel(Rect2(at + Vector2(0, 3), Vector2(246, 76)), INK, INK, 12)
	_panel(Rect2(at, Vector2(246, 75)), Color("244c5e"), COLORS[index].darkened(0.45), 12)
	draw_line(at + Vector2(63, 12), at + Vector2(63, 62), Color("447180"), 1)
	Art.robot(self, at + Vector2(32, 32), Vector2(54, 54), Vector2.DOWN, 0,
		Color(COLORS[index], 0.4 if not actor.alive else 1.0))
	_label(at + Vector2(10, 67), "P1" if index == 0 else "AI", 11, COLORS[index])
	_label(at + Vector2(74, 21), "YOU" if index == 0 else str(IDS[index]).to_upper(), 15, COLORS[index])
	Art.prop(self, &"life", at + Vector2(198, 15), Vector2.ONE * 19)
	_label(at + Vector2(209, 21), str(actor.lives), 15, GOLD)
	if not actor.alive: _label(at + Vector2(136, 21), "OUT", 12, Color("c2c2cf"))
	for entry in [[&"capacity", actor.capacity], [&"power", actor.power], [&"speed", roundi((actor.speed - 1.6) / 0.1) + 1]]:
		var offset: int = [&"capacity", &"power", &"speed"].find(entry[0]) * 48
		Art.prop(self, entry[0], at + Vector2(82 + offset, 37), Vector2.ONE * 19)
		_label(at + Vector2(94 + offset, 42), str(entry[1]), 13, CREAM)
	_label(at + Vector2(75, 63), "%06d" % actor.score, 15, Color("c8e0dc"))
	if actor.weapon != &"":
		Art.prop(self, actor.weapon, at + Vector2(196, 58), Vector2.ONE * 24)
		_label(at + Vector2(211, 64), "×%d" % actor.ammo, 12, GOLD)


func _attack(attack: Dictionary) -> void:
	var at := _center(attack.cell)
	var direction := Vector2(attack.direction)
	var age: int = attack.get("frame", 0)
	if attack.kind == &"hammer":
		var hand: Vector2 = at + attack.get("attachment", Vector2.ZERO) * PITCH / 75.0
		var angle := direction.angle() + lerpf(-1.4, 0.25, minf(1, age / 24.0))
		Art.prop(self, &"hammer", hand + Vector2.from_angle(angle) * 19, Vector2.ONE * 35, Color.WHITE, angle + 0.7)
	elif attack.kind == &"laser" and attack.fired:
		for cell in attack.get("cells", []):
			var center := _center(cell)
			draw_line(center - direction * 18, center + direction * 18, Color("56e9ef", 0.2), 18, true)
			draw_line(center - direction * 18, center + direction * 18, Color("74fff6"), 7, true)
			draw_line(center - direction * 18, center + direction * 18, Color("f4fff0"), 3, true)
	elif attack.kind == &"flamer":
		for cell in attack.get("cells", []):
			draw_line(at, _center(cell), Color("f37235", 0.7), 15, true)
			draw_line(at, _center(cell), Color("ffe388"), 5, true)
			Art.prop(self, &"shotgun", _center(cell), Vector2(34, 27), Color.WHITE, direction.angle())
	elif not attack.fired and attack.kind in [&"laser", &"shotgun"]:
		var progress := minf(age / (14.0 if attack.kind == &"shotgun" else 11.0), 1)
		var muzzle := at + direction * 18
		draw_circle(muzzle, 5 + progress * 7, Color("ffe2a0", 0.2))
		Art.prop(self, &"invincible" if attack.kind == &"laser" else &"power", muzzle,
			Vector2.ONE * (8 + progress * 14))
	elif attack.kind == &"triple" and age % 15 < 3:
		Art.prop(self, &"invincible", at + direction * 23, Vector2.ONE * 17)


func _instructions() -> void:
	_label(Vector2(1010, 349), "HOW TO PLAY", 15, GOLD)
	_label(Vector2(1010, 377), "Arrows  Move", 16, CREAM)
	_label(Vector2(1010, 403), "Space    Bomb / item", 16, CREAM)
	_label(Vector2(1010, 429), "P             Pause", 16, Color("aacdd1"))
	_label(Vector2(88, 649), "MOVE", 13, Color("a7d4dd"))
	_label(Vector2(57, 672), "Eight directions", 12, Color("789fae"))
	_label(Vector2(1045, 657), "TAP TO USE", 13, Color("d5be94"))
	var fixture: bool = state.get("comparison_fixture", false)
	_label(Vector2(340, 663), "CONTROLLED ACTION PREVIEW" if fixture else "CINEMA  /  PAIRED PORTALS", 13, Color("b6cecd"))
	var hint := "Move · place · escape. Start a match when you're ready." if practice else "Eliminate every rival before time runs out."
	if practice and not state.actors[&"human"].alive: hint = "Choose RESET to return to practice."
	_label(Vector2(340, 684), hint, 13, GOLD)


func _overlay() -> void:
	draw_rect(Rect2(ORIGIN, Vector2(612, 540)), Color("101b30", 0.78))
	_panel(Rect2(426, 211, 428, 306), Color("0e253b"), Color("a77d61"), 20)
	_panel(Rect2(433, 218, 414, 292), Color("204959"), Color("467887"), 15)
	var outcome: StringName = state.pending_outcome if state.get("round_stage") == &"ending" else state.outcome
	var title := "PAUSED" if paused else "YOU WIN!" if outcome == &"won" else "TIME'S UP" if outcome == &"timeout" else "YOU LOSE"
	if not paused and state.session.game_over: title = "GAME OVER"
	Art.prop(self, &"projector" if paused else &"trophy" if outcome == &"won" else &"ghost",
		Vector2(640, 266), Vector2(77, 77))
	_center_label(Vector2(640, 331), title, 31, GOLD)
	if paused:
		_center_label(Vector2(640, 383), "Choose RESUME to continue.", 20, CREAM)
		_center_label(Vector2(640, 419), "Fresh input after resuming.", 16, Color("aed1d3"))
	elif state.get("round_stage") == &"ending":
		var progress: float = state.get("ending_progress", 0)
		_panel(Rect2(502, 373, 276, 9), INK, Color("395868"), 4)
		if progress > 0: draw_rect(Rect2(504, 375, 272 * progress, 5), GOLD)
		_center_label(Vector2(640, 424), "ROUND COMPLETE", 17, CREAM)
		_center_label(Vector2(640, 469), "Finishing the round…", 15, Color("aed1d3"))
	else:
		for entry in [["ENEMIES KILLED", state.actors[&"human"].kills], ["ROUND SCORE", state.result_score], ["TOTAL SCORE", state.session.total_score]]:
			var row: int = ["ENEMIES KILLED", "ROUND SCORE", "TOTAL SCORE"].find(entry[0])
			_label(Vector2(473, 376 + row * 33), entry[0], 15, Color("b9d4d4"))
			_label(Vector2(721, 376 + row * 33), str(entry[1]), 19, GOLD)
		_center_label(Vector2(640, 484), "Choose the next action on the right.", 15, CREAM)


func _center(cell: Vector2i) -> Vector2:
	return ORIGIN + (Vector2(cell) + Vector2.ONE * 0.5) * PITCH


func _shadow(at: Vector2, width: float) -> void:
	draw_set_transform(at, 0, Vector2(1, 0.35))
	draw_circle(Vector2.ZERO, width, Color("14172d", 0.55))
	draw_set_transform(Vector2.ZERO)


func _label(at: Vector2, text: String, size_px: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, at + Vector2(0, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color("101c30", color.a * 0.8))
	draw_string(ThemeDB.fallback_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)


func _center_label(at: Vector2, text: String, size_px: int, color: Color) -> void:
	_label(at - Vector2(ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x / 2, 0), text, size_px, color)


func _panel(rect: Rect2, fill: Color, border: Color, radius: int) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	draw_style_box(style, rect)

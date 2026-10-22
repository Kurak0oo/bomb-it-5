extends Node2D
## Original vector artwork. Receives snapshots; never owns or advances gameplay.

const PITCH := 36.0
const ORIGIN := Vector2(334, 86)
## Art slots and native colours per robot r0-r7 (Session.ROBOTS order).
const ROBOT_SLOTS := [&"human", &"ruby", &"lime", &"gold", &"violet", &"slate", &"mint", &"snow"]
const ROBOT_TITLES := ["BLUE", "RUBY", "LIME", "GOLD", "VIOLET", "SLATE", "MINT", "SNOW"]
const ROBOT_COLORS := [Color("66d8ff"), Color("ed86c6"), Color("b6e36a"), Color("ffd470"),
	Color("b394f0"), Color("9aa6b4"), Color("8ce2b5"), Color("f2f4f7")]
const LOOK_COLORS := [Color("e35d6a"), Color("4f8fe0"), Color("f2b84b"), Color("5cc48d"), Color("a66ce0"), Color("ef8a3c"), Color("3fb7c9")]
## Standalone seat robots when an actor carries no explicit robot.
const SEAT_ROBOTS := {&"human": 0, &"ruby": 1, &"mint": 6, &"gold": 3}
const ITEM_NAMES := {&"capacity": "B+", &"power": "P+", &"speed": "S+", &"life": "♥",
	&"shield": "O", &"invincible": "★", &"car": "CAR", &"moto": "RIDE", &"landmine": "M",
	&"hammer": "H", &"flamer": "F", &"laser": "L", &"triple": "3", &"shotgun": "●",
	&"horse": "HRS", &"dragon": "DRG"}
const VisualSkin = preload("res://scripts/art/skin.gd")
const StageSets = preload("res://scripts/simulation/stage_sets.gd")
## Native board palettes per stage set: floor pair, wall, solid fill/edge, soft fill/edge.
const THEMES := {
	&"luxury_stores": [Color("f4e4a4"), Color("eedb93"), Color("9fd6e8"), Color("e48bb4"), Color("fbd2e4"), Color("8f5fc0"), Color("e5c3f4")],
	&"zoo": [Color("8cc76a"), Color("80bb60"), Color("6c8e4a"), Color("a7845a"), Color("d8bb8a"), Color("e6c66b"), Color("fff0b0")],
	&"candy_factory": [Color("f6d2e2"), Color("efc4d8"), Color("b6e1f2"), Color("8bc6e7"), Color("e3f5fc"), Color("f39ab9"), Color("ffe1ec")],
	&"birthday_party": [Color("cfe9f7"), Color("c0e0f3"), Color("f3b8d0"), Color("78bfe6"), Color("d8f0fb"), Color("f6c66b"), Color("fff0c4")],
	&"magic_library": [Color("5b4a7d"), Color("524371"), Color("2f2747"), Color("8c6a46"), Color("c9a679"), Color("4fa3b8"), Color("b9eef8")],
}
const ArtCatalog = preload("res://scripts/art/catalog.gd")

var state: Dictionary = {}
var practice := true
var paused := false
var skin: RefCounted = VisualSkin.new()


func present(snapshot: Dictionary, is_practice: bool, is_paused: bool) -> void:
	state = snapshot
	practice = is_practice
	paused = is_paused
	queue_redraw()


func _draw() -> void:
	if not skin.draw(self, "ui.background", Rect2(Vector2.ZERO, Vector2(1280, 720))):
		draw_rect(Rect2(-position - get_parent().position, get_viewport_rect().size + Vector2(100, 100)), Color("102c3b"))
	if not skin.draw(self, "ui.frame", Rect2(10, 10, 1260, 700)):
		_box(Rect2(10, 10, 1260, 700), Color("163e51"), Color("39798a"), 18)
	_label(Vector2(30, 49), "LOCAL ARCADE", 29, Color("ffd989"))
	_label(Vector2(335, 43), _board_title(), 27, Color("ffe6ad"))
	_label(Vector2(336, 67), "PRACTICE" if practice else _mode_caption(), 13, Color("9acbd3"))
	if state.is_empty():
		return
	if not skin.draw(self, "ui.timer", Rect2(805, 25, 141, 42)):
		_box(Rect2(805, 25, 141, 42), Color("102c3b"), Color("568d98"), 10)
	_label(Vector2(818, 52), "TIME  %03d" % ceili(state.remaining / 35.0), 21, Color("ffd989"))
	if not skin.draw(self, "ui.board_frame", Rect2(ORIGIN - Vector2.ONE * 7, Vector2(626, 554))):
		_box(Rect2(ORIGIN - Vector2.ONE * 7, Vector2(626, 554)), Color("164957"), Color("a7d5c5"), 9)
	for cell in state.board:
		_tile(cell, state.board[cell])
	_marquee()
	_features()
	for cell in state.pickups:
		var at := _center(cell)
		if skin.draw(self, "item." + state.pickups[cell], ArtCatalog.rect("item." + state.pickups[cell], at), state.tick): continue
		if state.pickups[cell] == &"coin":
			draw_circle(at, 6, Color("f6c94a"))
			draw_arc(at, 6, 0, TAU, 16, Color("a8741c"), 1.5, true)
			continue
		draw_circle(at + Vector2(1, 2), 14, Color(0, 0, 0, 0.3))
		draw_circle(at, 13, Color("d1fff0"))
		draw_arc(at, 13, 0, TAU, 28, Color("60b4a4"), 2, true)
		var text: String = ITEM_NAMES.get(state.pickups[cell], "?")
		_label(at + Vector2(-text.length() * 4.0, 5), text, 13, Color("173c40"))
	_mode_objects()
	for bomb in state.bombs:
		var bomb_at: Vector2 = ORIGIN + (bomb.position + Vector2.ONE * 0.5) * PITCH if bomb.has("position") else _center(bomb.cell)
		_bomb(bomb_at, bomb.get("kind", &"bomb") == &"mine")
	for flame in state.flames:
		for cell in flame.cells:
			var at := _center(cell)
			if skin.draw(self, "effect.flame", ArtCatalog.rect("effect.flame", at), state.tick,
				Vector2.DOWN, minf(1, flame.get("count", 0) / 17.0)): continue
			var size_factor := clampf((17.0 - flame.get("count", 0)) / 5.0, 0.15, 1.0)
			draw_circle(at, 17 * size_factor, Color("ed7040"))
			draw_circle(at + Vector2(0, -2), 12 * size_factor, Color("ffd473"))
			draw_circle(at + Vector2(-2, -4), 6 * size_factor, Color("fff1b6"))
	for attack in state.attacks:
		if attack.get("layer") == &"behind": _attack(attack)
	for projectile in state.projectiles:
		if projectile.get("phase") == &"cleanup": continue
		var at: Vector2 = ORIGIN + (projectile.position + Vector2.ONE * 0.5) * PITCH
		if skin.draw(self, "projectile." + projectile.kind, ArtCatalog.rect("projectile." + projectile.kind, at), state.tick, projectile.direction): continue
		draw_line(at - Vector2(projectile.direction) * 15, at, Color("ee9958"), 6, true)
		draw_circle(at, 6 if projectile.kind == &"triple" else 9, Color("ffdf8d"))
	var seat := 0
	for id in state.actors:
		var actor: Dictionary = state.actors[id]
		var robot: int = actor.get("robot", SEAT_ROBOTS.get(id, seat))
		_actor(actor, robot, id)
		_hud(actor, seat, robot)
		seat += 1
	for attack in state.attacks:
		if attack.get("layer") != &"behind": _attack(attack)
	_mode_overlays()
	_label(Vector2(1010, 339), "HOW TO PLAY", 17, Color("ffd989"))
	var keys: Dictionary = state.get("bindings", {})
	var arrows: bool = keys.is_empty() or (keys.up == KEY_UP and keys.left == KEY_LEFT and keys.down == KEY_DOWN and keys.right == KEY_RIGHT)
	_label(Vector2(1010, 367), "Arrows to move" if arrows else "%s %s %s %s to move" % [_key(keys.up), _key(keys.left), _key(keys.down), _key(keys.right)], 17)
	_label(Vector2(1010, 393), "%s: bomb / item" % ("Space" if keys.is_empty() else _key(keys.bomb)), 17)
	_label(Vector2(1010, 419), "P: pause", 17)
	_label(Vector2(30, 658), "MOVE", 15, Color("a9d4de"))
	_label(Vector2(30, 681), "Eight directions · equal speed", 13, Color("8cb1bb"))
	_label(Vector2(1020, 653), "Tap to place / use", 15, Color("b9cdd2"))
	_label(Vector2(340, 658), "CONTROLLED ACTION PREVIEW" if state.get("comparison_fixture", false) else _board_caption(), 14, Color("a9d4de"))
	var hint: String = "Reset restores the board. Start Match adds three rivals." if practice else {
		&"kill": "Be the first to kill 10 enemies!",
		&"green_zone": "Stay on the green zone to occupy it. First to 10 wins!",
		&"pac_man": "Avoid the enemies and collect all of the coins!"}.get(state.get("mode", &"arcade"), "Eliminate every rival before time runs out.")
	if practice and not state.actors[&"human"].alive:
		hint = "Actor eliminated. Choose RESET to try again."
	_label(Vector2(340, 684), hint, 15, Color("ffd989"))
	if paused or state.outcome != &"running" or state.get("round_stage") == &"ending":
		_overlay()


## Pair 1 draws green and pair 2 purple; the recorded instance falls back to its columns.
func _portal_pair(cell: Vector2i) -> int:
	var ids: Dictionary = state.get("board_meta", {}).get("portal_ids", {})
	return ids.get(cell, 1 if cell.x == 8 else 2)


func _board_skin() -> StringName:
	return state.get("board_meta", {}).get("skin", &"cinema") if not state.is_empty() else &"cinema"


func _points_label() -> String:
	return {&"kill": "KILLS", &"green_zone": "FLAGS", &"pac_man": "COINS"}.get(state.get("mode", &""), "SCORE")


func _points_goal() -> int:
	return state.get("points_goal", 10)


## Green Zone flag with each holder's progress (`Flag`, `r<robot>_progress`).
func _mode_objects() -> void:
	var mode_state: Dictionary = state.get("mode_state", {})
	var flag: Variant = mode_state.get("flag")
	if flag != null:
		var at := _center(flag)
		if not skin.draw(self, "mode.flag", Rect2(at - Vector2(18, 26), Vector2(36, 44)), state.tick):
			draw_circle(at + Vector2(0, 10), 14, Color(0.35, 0.85, 0.45, 0.35))
			draw_line(at + Vector2(-6, 14), at + Vector2(-6, -20), Color("e8e2cf"), 3)
			draw_colored_polygon(PackedVector2Array([at + Vector2(-5, -20), at + Vector2(14, -13), at + Vector2(-5, -6)]), Color("58c46a"))


## Holders' progress bars over the flag, drawn above the robots.
func _mode_overlays() -> void:
	var mode_state: Dictionary = state.get("mode_state", {})
	var flag: Variant = mode_state.get("flag")
	if flag != null:
		var at := _center(flag)
		var row := 0
		for id in mode_state.get("progress", {}):
			if not state.actors.has(id): continue
			var robot: int = state.actors[id].get("robot", SEAT_ROBOTS.get(id, 0))
			var bar := Rect2(at + Vector2(-18, -34 - row * 7), Vector2(36, 5))
			var filled := Rect2(bar.position, Vector2(36.0 * mode_state.progress[id] / mode_state.get("capture_ticks", 105), 5))
			draw_rect(bar, Color(0, 0, 0, 0.5))
			if not skin.draw(self, "mode.progress", filled, state.tick): draw_rect(filled, ROBOT_COLORS[robot])
			row += 1


func _key(keycode: int) -> String:
	return {KEY_UP: "↑", KEY_DOWN: "↓", KEY_LEFT: "←", KEY_RIGHT: "→"}.get(keycode, OS.get_keycode_string(keycode))


func _mode_caption() -> String:
	if state.is_empty(): return ""
	var mode_title: String = {&"kill": "BATTLE ROYALE", &"pac_man": "PAC-MAN"}.get(state.get("mode", &"arcade"), str(state.get("mode", &"arcade")).to_upper().replace("_", " "))
	var caption := "%s  /  %s" % [mode_title, str(state.get("difficulty", &"normal")).to_upper()]
	var level: String = state.get("session", {}).get("level", "")
	return caption + ("  /  LEVEL " + level if level != "" else "")


func _board_caption() -> String:
	var layout: String = state.get("board_meta", {}).get("layout", "")
	if layout == "": return "RECORDED CINEMA BOARD  /  PAIRED PORTALS"
	return "%s  /  LAYOUT %s" % [StageSets.title(_board_skin()), layout.right(1)]


func _board_title() -> String:
	var set_id := _board_skin()
	return "CINEMA CLUB" if set_id == &"cinema" else StageSets.title(set_id)


func _tile(cell: Vector2i, kind: StringName) -> void:
	if _board_skin() != &"cinema":
		_themed_tile(cell, kind, _board_skin())
		return
	var at := ORIGIN + Vector2(cell) * PITCH
	if not skin.draw(self, "board.floor_odd" if (cell.x + cell.y) % 2 else "board.floor_even", Rect2(at, Vector2.ONE * PITCH)):
		draw_rect(Rect2(at, Vector2.ONE * PITCH), Color("53304d") if (cell.x + cell.y) % 2 else Color("5c3555"))
		draw_line(at + Vector2(0, 35), at + Vector2(35, 35), Color("472942"), 1)
	if kind == &"solid":
		if cell.x == 0 or cell.y == 0 or cell.x == 16 or cell.y == 14:
			if skin.draw(self, "board.wall", Rect2(at, Vector2.ONE * 36)): return
			_box(Rect2(at + Vector2.ONE, Vector2.ONE * 34), Color("344c64"), Color("66899a"), 5)
			draw_circle(at + Vector2(6, 6), 2, Color("a2bac3"))
		elif (cell.x + cell.y) % 3 == 0:
			if skin.draw(self, "board.spotlight", Rect2(at, Vector2.ONE * 36)): return
			draw_circle(at + Vector2(18, 25), 10, Color("293d59"))
			_box(Rect2(at + Vector2(12, 6), Vector2(13, 20)), Color("768eaa"), Color("b8d7d9"), 5)
			draw_circle(at + Vector2(18, 12), 6, Color("ffe7a3"))
		else:
			if skin.draw(self, "board.seat", Rect2(at, Vector2.ONE * 36)): return
			_box(Rect2(at + Vector2(5, 4), Vector2(26, 27)), Color("8a344a"), Color("c36d70"), 7)
			_box(Rect2(at + Vector2(9, 5), Vector2(18, 19)), Color("c85060"), Color("ee9c8a"), 5)
			draw_rect(Rect2(at + Vector2(7, 26), Vector2(23, 5)), Color("d46a6b"))
	elif kind == &"soft":
		if (cell.x + cell.y) % 2:
			if skin.draw(self, "board.clapper", Rect2(at, Vector2.ONE * 36)): return
			_box(Rect2(at + Vector2(5, 13), Vector2(27, 19)), Color("559ba8"), Color("acd6cf"), 3)
			draw_rect(Rect2(at + Vector2(3, 7), Vector2(29, 7)), Color("253d4c"))
			for n in 3:
				draw_line(at + Vector2(6 + n * 9, 8), at + Vector2(10 + n * 9, 13), Color("dce9d7"), 3)
		else:
			if skin.draw(self, "board.popcorn", Rect2(at, Vector2.ONE * 36)): return
			draw_colored_polygon(PackedVector2Array([at + Vector2(8, 13), at + Vector2(29, 13), at + Vector2(25, 32), at + Vector2(11, 32)]), Color("dfb676"))
			for n in 4:
				draw_line(at + Vector2(11 + n * 4, 15), at + Vector2(13 + n * 3, 30), Color("b75457"), 2)
			for n in 5:
				draw_circle(at + Vector2(10 + n * 4, 10 + (n % 2) * 3), 5, Color("ffe9b7"))
	elif kind == &"portal":
		var green := _portal_pair(cell) == 1
		if skin.draw(self, "board.portal_green" if green else "board.portal_purple", Rect2(at, Vector2.ONE * 36), state.tick): return
		var color := Color("a8e0b9") if green else Color("bab2f4")
		draw_circle(at + Vector2.ONE * 18, 16, Color(color, 0.18))
		draw_arc(at + Vector2.ONE * 18, 13, 0, TAU, 32, color, 3, true)
		draw_arc(at + Vector2.ONE * 18, 7, 0, TAU, 24, Color(color, 0.7), 2, true)


## Native drawing for stage sets other than Cinema; `board.<set>.<piece>` slots replace it.
func _themed_tile(cell: Vector2i, kind: StringName, set_id: StringName) -> void:
	var at := ORIGIN + Vector2(cell) * PITCH
	var theme: Array = THEMES.get(set_id, THEMES[&"luxury_stores"])
	var prefix := "board.%s." % set_id
	var rect := Rect2(at, Vector2.ONE * PITCH)
	if not skin.draw(self, prefix + ("floor_odd" if (cell.x + cell.y) % 2 else "floor_even"), rect):
		draw_rect(rect, theme[1] if (cell.x + cell.y) % 2 else theme[0])
	var size: Vector2i = state.get("board_meta", {}).get("size", Vector2i(17, 15))
	if kind == &"solid":
		if cell.x == 0 or cell.y == 0 or cell.x == size.x - 1 or cell.y == size.y - 1:
			if skin.draw(self, prefix + "wall", rect): return
			_box(Rect2(at + Vector2.ONE, Vector2.ONE * 34), theme[2], theme[2].lightened(0.4), 5)
			return
		var center = state.get("board_meta", {}).get("center")
		if center != null and Rect2i(center, Vector2i(3, 3)).has_point(cell): return
		var variant: int = state.get("board_meta", {}).get("variants", {}).get(cell, 1)
		if skin.draw(self, prefix + "solid_%d" % variant, rect): return
		var fill: Color = theme[3].lerp(theme[2], 0.25 * (variant % 3))
		_box(Rect2(at + Vector2(5, 4), Vector2(26, 28)), fill, theme[4], 7)
		draw_circle(at + Vector2(18, 13), 6, theme[4])
	elif kind == &"soft":
		if skin.draw(self, prefix + ("soft_a" if (cell.x + cell.y) % 2 else "soft_b"), rect): return
		_box(Rect2(at + Vector2(7, 9), Vector2(22, 22)), theme[5], theme[6], 4)
		draw_line(at + Vector2(9, 14), at + Vector2(27, 14), theme[6], 2)
	elif kind in [&"belt", &"crocodile"]:
		return
	elif kind != &"floor":
		_box(Rect2(at + Vector2(6, 6), Vector2(24, 24)), Color("e9e2d0"), Color("6d6a60"), 4)
		_label(at + Vector2(8, 23), str(kind).substr(0, 3).to_upper(), 11, Color("3a3a3a"))


## Stage-set map features: belt track, crocodiles, toy hands and the spellbook.
func _features() -> void:
	var prefix := "board.%s." % _board_skin()
	for feature in state.get("features", []):
		match feature.kind:
			&"belt":
				for index in feature.track.size():
					var cell: Vector2i = feature.track[index]
					var at := ORIGIN + Vector2(cell) * PITCH
					if skin.draw(self, prefix + "belt", Rect2(at, Vector2.ONE * PITCH), state.tick, Vector2(feature.flow[index])): continue
					draw_rect(Rect2(at + Vector2(3, 3), Vector2.ONE * (PITCH - 6)), Color("f3d98c"))
					var mid := at + Vector2.ONE * PITCH * 0.5
					var along := Vector2(feature.flow[index])
					var shift := fmod(state.tick / 30.0, 1.0) * 8.0 - 4.0
					draw_line(mid - along * 9 + along * shift, mid + along * 5 + along * shift, Color("d49a3a"), 3)
					draw_colored_polygon(PackedVector2Array([mid + along * (11 + shift), mid + along * (3 + shift) + along.orthogonal() * 6,
						mid + along * (3 + shift) - along.orthogonal() * 6]), Color("d49a3a"))
				var last: Vector2i = feature.track[-1]
				draw_circle(_center(last), 11, Color("2c2233"))
			&"crocodile":
				var at := ORIGIN + Vector2(feature.cell) * PITCH
				var slot: String = prefix + ("crocodile_open" if feature.phase in [&"opening", &"open"] else "crocodile")
				if skin.draw(self, slot, Rect2(at, Vector2.ONE * PITCH), state.tick): continue
				var body := Color("4f9a4a") if not feature.danger else Color("6aa640")
				_box(Rect2(at + Vector2(4, 8), Vector2(28, 22)), body, Color("2f5e2c"), 9)
				draw_circle(at + Vector2(12, 12), 3, Color("fff6c8"))
				draw_circle(at + Vector2(24, 12), 3, Color("fff6c8"))
				if feature.phase in [&"opening", &"open"]:
					_box(Rect2(at + Vector2(8, 17), Vector2(20, 10)), Color("a3263b"), Color("fff6c8"), 3)
			&"toy_hand":
				var at := ORIGIN + Vector2(feature.cell) * PITCH
				var direction := Vector2(feature.direction)
				if not skin.draw(self, prefix + "toy_hand", Rect2(at, Vector2.ONE * PITCH), state.tick, direction):
					_box(Rect2(at + Vector2(4, 4), Vector2(28, 28)), Color("f2b8c6"), Color("b0566e"), 9)
					draw_circle(_center(feature.cell) + direction * 8, 6, Color("fbe3a4"))
				if feature.open and feature.reach > 0:
					var start := _center(feature.cell) + direction * PITCH * 0.5
					var tip: Vector2 = _center(feature.cell) + direction * PITCH * (feature.reach + 0.2)
					draw_line(start, tip, Color("e88aa5"), 10)
					draw_circle(tip, 12, Color("fbe3a4"))
			&"spellbook":
				var at := ORIGIN + Vector2(feature.cell) * PITCH
				if not skin.draw(self, prefix + "spellbook", Rect2(at + Vector2(18, 18), Vector2(72, 72)), state.tick):
					# Below the centrepiece title, opening wider while it flips.
					var open_by := 14.0 if feature.flipping else 2.0
					_box(Rect2(at + Vector2(54 - 20 - open_by, 70), Vector2(20 + open_by, 28)), Color("6b3f8f"), Color("e8c86b"), 4)
					_box(Rect2(at + Vector2(54, 70), Vector2(20 + open_by, 28)), Color("7d4ca6"), Color("e8c86b"), 4)
				for sign in feature.signs:
					var mark := _center(sign.cell)
					if skin.draw(self, prefix + ("sign_bomb" if sign.kind == &"bomb" else "sign_pickup"), Rect2(mark - Vector2.ONE * 18, Vector2.ONE * 36), state.tick): continue
					draw_arc(mark, 14, 0, TAU, 24, Color("e0473c") if sign.kind == &"bomb" else Color("3f8ce0"), 3, true)


func _marquee() -> void:
	var at := ORIGIN + Vector2(7, 6) * PITCH
	if _board_skin() != &"cinema":
		if state.get("board_meta", {}).get("center") == null: return
		var theme: Array = THEMES.get(_board_skin(), THEMES[&"luxury_stores"])
		if skin.draw(self, "board.%s.center" % _board_skin(), Rect2(at, Vector2.ONE * 108), state.tick): return
		_box(Rect2(at + Vector2(2, 2), Vector2(104, 104)), theme[3].darkened(0.2), theme[4], 12)
		var words := StageSets.title(_board_skin()).split(" ")
		for line in words.size():
			_label(at + Vector2(12, 30 + line * 20), words[line], 17, theme[4].lightened(0.5))
		return
	if skin.draw(self, "board.marquee", Rect2(at, Vector2.ONE * 108), state.tick): return
	_box(Rect2(at + Vector2(2, 2), Vector2(104, 104)), Color("74334c"), Color("e3b36f"), 12)
	_box(Rect2(at + Vector2(9, 30), Vector2(90, 60)), Color("285d73"), Color("acc8ad"), 5)
	_label(at + Vector2(13, 57), "CINEMA", 19, Color("ffe8b2"))
	_label(at + Vector2(15, 77), "★  ★  ★", 18, Color("ffe8b2"))
	for n in 8:
		draw_circle(at + Vector2(12 + n * 12, 18), 3, Color("ffe4a3"))


func _bomb(at: Vector2, mine: bool) -> void:
	var slot := "effect.mine" if mine else "effect.bomb"
	if skin.draw(self, slot, ArtCatalog.rect(slot, at), state.tick): return
	if mine:
		_box(Rect2(at - Vector2(12, 7), Vector2(24, 14)), Color("bd9e74"), Color("e5d3a3"), 5)
		draw_circle(at, 3, Color("ec7869"))
	else:
		draw_circle(at + Vector2(1, 3), 13, Color("262b3d"))
		draw_circle(at, 11, Color("465b71"))
		draw_circle(at + Vector2(-4, -4), 3, Color("92a7b3"))
		draw_line(at + Vector2(3, -9), at + Vector2(8, -16), Color("e8bd78"), 3, true)
		draw_circle(at + Vector2(8, -16), 3 + sin(state.tick * 0.8), Color("ffe49e"))


func _actor(actor: Dictionary, robot: int, id: StringName) -> void:
	var at: Vector2 = ORIGIN + (actor.position + Vector2.ONE * 0.5) * PITCH
	var color: Color = ROBOT_COLORS[robot]
	if not actor.alive:
		if actor.get("removed", false): return
		var progress := clampf(actor.get("death_frame", 1) / 60.0, 0.0, 1.0)
		at.y -= sin(progress * PI) * 25
		if skin.draw(self, "actor.%s.death" % ROBOT_SLOTS[robot], ArtCatalog.rect("actor.%s.death" % ROBOT_SLOTS[robot], at), state.tick, actor.facing, progress,
			Color(1, 1, 1, 1.0 - progress * 0.7)): return
		var skull := Color("e4f4e8")
		skull.a = 1.0 - progress * 0.7
		draw_circle(at, 13 * (1.0 - progress * 0.35), skull)
		draw_circle(at + Vector2(-4, -1), 3, color.darkened(0.8))
		draw_circle(at + Vector2(4, -1), 3, color.darkened(0.8))
		draw_line(at + Vector2(-5, 8), at + Vector2(5, 8), skull, 4, true)
		return
	if actor.transit_until > 0:
		if not skin.draw(self, "effect.transit", ArtCatalog.rect("effect.transit", at), state.tick):
			draw_arc(at, 16, state.tick * 0.3, state.tick * 0.3 + PI * 1.5, 24, color, 3, true)
		color.a = clampf(float(actor.transit_until - state.tick + 5) / 35.0, 0.14, 1.0)
	if actor.vehicle != &"":
		var recovering: bool = actor.get("vehicle_recovery_until", 0) > state.tick
		var ride_color := Color("d77f68") if recovering else Color("3c8890")
		var shake := sin(state.tick * 2.0) * 3.0 if recovering else 0.0
		var ride_slot: String = "effect." + actor.vehicle
		if recovering and skin.texture(ride_slot + "_recovery") != null: ride_slot += "_recovery"
		if not skin.draw(self, ride_slot, ArtCatalog.rect(ride_slot, at, state.tick), state.tick, actor.facing):
			_box(Rect2(at + Vector2(-16 + shake, 1), Vector2(32, 17)), ride_color, Color("b9dfca"), 6)
			draw_circle(at + Vector2(-10, 15), 5, Color("203347"))
			draw_circle(at + Vector2(10, 15), 5, Color("203347"))
	if actor.shield > 0 or actor.protected_until > state.tick:
		if not skin.draw(self, "effect.shield", ArtCatalog.rect("effect.shield", at), state.tick):
			draw_arc(at, 19, 0, TAU, 32, Color("d2eeb1"), 2, true)
	if actor.invincible_until > state.tick:
		var introducing: bool = actor.get("protection_stage") == &"introduction"
		var aura := "effect.invincible_intro" if introducing and skin.texture("effect.invincible_intro") != null else "effect.invincible"
		if not skin.draw(self, aura, ArtCatalog.rect(aura, at), state.tick):
			draw_arc(at, 21 + sin(state.tick * 0.3) * (6 if introducing else 2), 0, TAU, 32, Color("ffd778"), 3, true)
	if actor.blink_until > state.tick or actor.get("protection_stage") == &"blink":
		skin.draw(self, "effect.blink", ArtCatalog.rect("effect.blink", at), state.tick)
		color = color.lightened(0.35 if state.tick % 6 < 3 else 0.0)
	var bob := sin(state.tick * 0.8) * 1.5 if actor.velocity.length() > 0.02 and not paused else 0.0
	at.y += bob
	var requested: bool = state.get("commands", []).any(func(command): return command.actor_id == id and command.direction != Vector2.ZERO)
	var action_progress := -1.0
	for attack in state.attacks:
		if attack.actor_id == id:
			action_progress = _attack_progress(attack)
			break
	var pose := "action" if action_progress >= 0 else "walk" if requested and actor.velocity.length() > 0.02 else "idle"
	var modulation := Color(1, 1, 1, color.a)
	if actor.blink_until > state.tick and state.tick % 6 < 3: modulation = Color(1.35, 1.35, 1.35, color.a)
	var slot := "actor.%s.%s" % [ROBOT_SLOTS[robot], pose]
	var replaced: bool = skin.draw(self, slot, ArtCatalog.rect(slot, at), state.tick, actor.facing, action_progress, modulation)
	if not replaced and pose != "idle":
		replaced = skin.draw(self, "actor.%s.idle" % ROBOT_SLOTS[robot], ArtCatalog.rect("actor.%s.idle" % ROBOT_SLOTS[robot], at), state.tick, actor.facing, -1, modulation)
	if replaced:
		_looks(actor, at, robot)
		if actor.weapon not in [&"", &"none"]:
			if not skin.draw(self, "held." + actor.weapon, ArtCatalog.rect("held." + actor.weapon, at), state.tick, actor.facing):
				_label(at + Vector2(11, 8), ITEM_NAMES.get(actor.weapon, "?"), 12, Color("fff1b6"))
		return
	draw_circle(at + Vector2(0, 7), 13, Color(0.05, 0.1, 0.17, 0.5))
	_box(Rect2(at + Vector2(-10, 1), Vector2(20, 13)), color.darkened(0.25), color.lightened(0.15), 6)
	_box(Rect2(at + Vector2(-14, -16), Vector2(28, 25)), color, color.lightened(0.35), 10)
	_box(Rect2(at + Vector2(-10, -10), Vector2(20, 11)), Color("244357"), Color("498090"), 4)
	var facing: Vector2 = actor.facing
	draw_circle(at + Vector2(-5, -5) + facing * 1.5, 2.5, Color("e1fff3"))
	draw_circle(at + Vector2(5, -5) + facing * 1.5, 2.5, Color("e1fff3"))
	draw_line(at + Vector2(0, -16), at + Vector2(0, -20), color, 2)
	draw_circle(at + Vector2(0, -21), 2, Color("fff1b6"))
	_looks(actor, at, robot)
	if actor.weapon not in [&"", &"none"]:
		if not skin.draw(self, "held." + actor.weapon, ArtCatalog.rect("held." + actor.weapon, at), state.tick, actor.facing):
			_label(at + Vector2(11, 8), ITEM_NAMES.get(actor.weapon, "?"), 12, Color("fff1b6"))


## Unlocked hat and outfit over a robot: `look.<robot>.hat<k>`/`body<k>` slots or native shapes.
func _looks(actor: Dictionary, at: Vector2, robot: int) -> void:
	var body: int = actor.get("body", 0)
	var hat: int = actor.get("hat", 0)
	if body > 0 and not skin.draw(self, "look.%s.body%d" % [ROBOT_SLOTS[robot], body], Rect2(at + Vector2(-12, -1), Vector2(24, 17)), state.get("tick", 0), actor.facing):
		var cloth: Color = LOOK_COLORS[(body + robot) % LOOK_COLORS.size()]
		_box(Rect2(at + Vector2(-10, 2), Vector2(20, 11)), cloth, cloth.lightened(0.35), 4)
		draw_line(at + Vector2(0, 3), at + Vector2(0, 12), cloth.darkened(0.3), 2)
	if hat > 0 and not skin.draw(self, "look.%s.hat%d" % [ROBOT_SLOTS[robot], hat], Rect2(at + Vector2(-15, -33), Vector2(30, 20)), state.get("tick", 0), actor.facing):
		var felt: Color = LOOK_COLORS[(hat * 2 + robot) % LOOK_COLORS.size()]
		match (hat - 1) % 4:
			0: # cap
				_box(Rect2(at + Vector2(-13, -23), Vector2(26, 8)), felt, felt.lightened(0.3), 4)
				draw_rect(Rect2(at + Vector2(-2, -18), Vector2(17, 3)), felt.darkened(0.25))
			1: # top hat
				draw_rect(Rect2(at + Vector2(-15, -19), Vector2(30, 3)), felt.darkened(0.3))
				_box(Rect2(at + Vector2(-8, -33), Vector2(16, 15)), felt, felt.lightened(0.3), 3)
			2: # tricorn
				draw_colored_polygon(PackedVector2Array([at + Vector2(-16, -17), at + Vector2(16, -17), at + Vector2(0, -31)]), felt)
				draw_circle(at + Vector2(0, -23), 3, Color("fff1b6"))
			_: # crown
				draw_colored_polygon(PackedVector2Array([at + Vector2(-12, -17), at + Vector2(12, -17), at + Vector2(12, -29),
					at + Vector2(6, -23), at + Vector2(0, -31), at + Vector2(-6, -23), at + Vector2(-12, -29)]), Color("ffd470"))


func _hud(actor: Dictionary, index: int, robot: int) -> void:
	var at := Vector2(28, 90 + index * 85)
	if not skin.draw(self, "ui.roster", Rect2(at, Vector2(251, 76))):
		_box(Rect2(at, Vector2(251, 76)), Color("234e62"), ROBOT_COLORS[robot].darkened(0.25), 12)
	if not skin.draw(self, "actor.%s.portrait" % ROBOT_SLOTS[robot], Rect2(at + Vector2(11, 11), Vector2.ONE * 38)):
		draw_circle(at + Vector2(30, 30), 19, ROBOT_COLORS[robot].darkened(0.1))
		_label(at + Vector2(17, 36), "P1" if index == 0 else "AI", 17, Color("173649"))
	_label(at + Vector2(61, 23), "YOU" if index == 0 else ROBOT_TITLES[robot], 17, ROBOT_COLORS[robot])
	var status := "" if actor.alive else " …" if actor.get("respawn_at", 0) > 0 or (actor.get("base_weapon", &"") != &"" and not actor.get("removed", false)) else " OUT"
	_label(at + Vector2(177, 23), "♥%d%s" % [actor.lives, status], 15, Color("ffe4ad"))
	_label(at + Vector2(61, 44), "B %d   P %d   S %d" % [actor.capacity, actor.power, roundi((actor.speed - 1.6) / 0.1) + 1], 14)
	var points: int = actor.get("points", -1)
	if points < 0: _label(at + Vector2(61, 64), "SCORE %d" % actor.score, 14, Color("b4d2d7"))
	else: _label(at + Vector2(61, 64), "%s %d/%d" % [_points_label(), points, _points_goal()], 14, Color("ffe4ad"))
	if actor.weapon not in [&"", &"none"]:
		var uses: String = " ×%d" % actor.ammo if actor.ammo >= 0 else ""
		_label(at + Vector2(174, 64), ITEM_NAMES.get(actor.weapon, "?") + uses, 13, Color("ffd989"))


func _attack_animation_end(kind: StringName) -> float:
	# Laser stops on animation frame 11 while its separate recovery lock continues.
	# See docs/evidence/edition-5-weapon-action-recovery.md and Weapons.advance.
	return {&"hammer": 24.0, &"laser": 11.0, &"flamer": 23.0, &"triple": 32.0, &"shotgun": 14.0}.get(kind, 24.0)


func _attack_progress(attack: Dictionary) -> float:
	return clampf(attack.get("frame", 0) / _attack_animation_end(attack.kind), 0, 1)


func _attack(attack: Dictionary) -> void:
	var at := _center(attack.cell)
	var direction: Vector2 = Vector2(attack.direction)
	var age: int = attack.get("frame", 0)
	var progress := _attack_progress(attack)
	if attack.kind == &"laser" and attack.get("fired", false) or attack.kind == &"flamer" and not attack.get("cells", []).is_empty():
		if skin.texture("attack." + attack.kind) != null:
			for cell in attack.get("cells", []):
				skin.draw(self, "attack." + attack.kind, ArtCatalog.rect("attack." + attack.kind, _center(cell), state.tick, true), state.tick, direction, progress)
			return
	elif skin.draw(self, "attack." + attack.kind, ArtCatalog.rect("attack." + attack.kind, at), state.tick, direction, progress): return
	if attack.kind == &"hammer":
		var attachment: Vector2 = attack.get("attachment", Vector2.ZERO) * PITCH / 30.0
		var swing := direction.rotated(lerpf(-1.5, 0.2, minf(1.0, age / 24.0)))
		var hand := at + attachment * 0.4
		var head := hand + swing * 29
		draw_line(hand, head, Color("e5be80"), 5, true)
		_box(Rect2(head - Vector2(10, 7), Vector2(20, 14)), Color("d5edf0"), Color("7cacba"), 3)
	elif attack.kind == &"laser" and attack.fired:
		for cell in attack.get("cells", []):
			draw_line(_center(cell) - Vector2(attack.direction) * 18, _center(cell) + Vector2(attack.direction) * 18, Color("fff1b6"), 7, true)
	elif attack.kind == &"flamer":
		for cell in attack.get("cells", []):
			draw_line(at, _center(cell), Color("ffae62"), 11 + sin(age) * 2, true)
			draw_line(at, _center(cell), Color("ffe69e"), 5, true)
			draw_circle(_center(cell), 8, Color("fff0b0"))
	elif attack.kind == &"shotgun" and not attack.fired:
		draw_circle(at + direction * 18, 3 + minf(age, 14) * 0.7, Color("ffba6e"))
	elif attack.kind == &"triple":
		var kick := 5.0 if age % 15 < 3 else 0.0
		draw_line(at, at + direction * (23 - kick), Color("b7d7d4"), 8, true)
	elif not attack.fired:
		draw_arc(at, 22, -PI / 2, -PI / 2 + TAU * minf(1.0, float(state.tick - attack.started + 1) / maxf(1, attack.ready - attack.started)), 24, Color("ffd989"), 3, true)


func _overlay() -> void:
	draw_rect(Rect2(ORIGIN, Vector2(612, 540)), Color(0.04, 0.10, 0.17, 0.82))
	if not skin.draw(self, "ui.results", Rect2(418, 242, 444, 228)):
		_box(Rect2(418, 242, 444, 228), Color("214c60"), Color("c9c7a0"), 18)
	var outcome: StringName = state.pending_outcome if state.get("round_stage") == &"ending" else state.outcome
	var title := "PAUSED" if paused else "YOU WIN!" if outcome == &"won" else "TIME'S UP" if outcome == &"timeout" else "YOU LOSE"
	if not paused and state.session.game_over:
		title = "GAME OVER"
	var illustration := "paused" if paused else "game_over" if state.session.game_over else str(outcome)
	skin.draw(self, "outcome." + illustration, Rect2(782, 251, 64, 64), state.tick)
	_label(Vector2(455, 296), title, 34, Color("ffe2a0"))
	if paused:
		_label(Vector2(455, 347), "Choose RESUME to continue.", 21)
		_label(Vector2(455, 387), "Fresh input is required after resuming.", 17, Color("abcbd2"))
	elif state.get("round_stage") == &"ending":
		var progress: float = state.get("ending_progress", 0.0)
		draw_arc(Vector2(640, 367), 34, -PI / 2, -PI / 2 + TAU * maxf(0.01, progress), 48, Color("ffd989"), 5, true)
		_label(Vector2(455, 442), "ROUND COMPLETE", 20, Color("ffe2a0"))
	else:
		_label(Vector2(455, 340), "ENEMIES KILLED   %d" % state.actors[&"human"].kills, 19)
		_label(Vector2(455, 371), "ROUND SCORE      %d" % state.result_score, 19)
		_label(Vector2(455, 402), "TOTAL SCORE       %d" % state.session.total_score, 19, Color("ffe2a0"))
		_label(Vector2(455, 442), "Choose the next action on the right.", 17, Color("abcbd2"))


func _center(cell: Vector2i) -> Vector2:
	return ORIGIN + (Vector2(cell) + Vector2.ONE * 0.5) * PITCH


func _label(at: Vector2, text: String, size_px: int = 18, color: Color = Color("dfede7")) -> void:
	draw_string(ThemeDB.fallback_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)


func _box(rect: Rect2, fill: Color, border: Color, radius: int) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	draw_style_box(style, rect)

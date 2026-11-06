extends Node2D
## The gameplay screen's placeholder layer (App._game_screen, in the board container): what the
## round shows that has no original art in the pack yet. Weapon actions other than the hammer's
## and their shots, mode objects (Green Zone's flag) and, for a stage set other than Cinema, the
## board itself (its `_brick5` tiles, background and features are not rendered yet). Robots,
## bombs, blasts and pickups are the original's (scripts/ui/game_actors.gd). Receives
## snapshots; never owns or advances gameplay.

const PITCH := 36.0
## Portal transit length in steps (`BombSimulation`, `SendRobotCommand` totalFrame).
const TRANSIT_TICKS := 29
const ORIGIN := Vector2(334, 86)
## Art slots and native colours per robot r0-r7 (Session.ROBOTS order).
const ROBOT_SLOTS := [&"human", &"ruby", &"lime", &"gold", &"violet", &"slate", &"mint", &"snow"]
const ROBOT_COLORS := [Color("66d8ff"), Color("ed86c6"), Color("b6e36a"), Color("ffd470"),
	Color("b394f0"), Color("9aa6b4"), Color("8ce2b5"), Color("f2f4f7")]
## Cinema soft choices 1-4 (`_brick5` frames 53-56); the first and third keep their older slot ids.
const CINEMA_SOFT := ["board.clapper", "board.popcorn_box", "board.popcorn", "board.clapperboard"]
## Standalone seat robots when an actor carries no explicit robot.
const SEAT_ROBOTS := {&"human": 0, &"ruby": 1, &"mint": 6, &"gold": 3}
const Quality = preload("res://scripts/quality.gd")
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
## The board's boxes and features too (a stage set whose board art is not in the pack).
var draw_board := false
## Only the board (the layer under the row layers); the effects go on a layer over them.
var board_only := false
## Weapon actions GameActors draws from their own clips (HammerProp's `sinker*_Play`).
const ORIGINAL_ATTACKS: Array[StringName] = [&"hammer"]


## Drawing between steps (#79): `previous` is the step before `snapshot` and `between` how far
## drawing is from it towards the next step. Only positions are blended; state is untouched.
var previous: Dictionary = {}
var between := 1.0


func present(snapshot: Dictionary, is_practice: bool, is_paused: bool, previous_step: Dictionary = {}, fraction := 1.0) -> void:
	previous = previous_step
	between = fraction
	state = snapshot
	practice = is_practice
	paused = is_paused
	queue_redraw()


func _draw() -> void:
	if state.is_empty(): return
	if draw_board:
		for cell in state.board:
			_tile(cell, &"floor")
		# Boxes after every floor, row by row, so overhanging props cover the row above.
		for cell in state.board:
			if state.board[cell] != &"floor": _tile(cell, state.board[cell], false)
		_marquee()
		_features()
	if board_only: return
	_mode_objects()
	for attack in state.attacks:
		if attack.get("layer") == &"behind" and attack.kind not in ORIGINAL_ATTACKS: _attack(attack)
	for projectile in state.projectiles:
		if projectile.get("phase") == &"cleanup": continue
		var at: Vector2 = ORIGIN + (_blend(_was_projectile(projectile), projectile.position) + Vector2.ONE * 0.5) * PITCH
		if skin.draw(self, "projectile." + projectile.kind, ArtCatalog.rect("projectile." + projectile.kind, at), state.tick, projectile.direction): continue
		draw_line(at - Vector2(projectile.direction) * 15, at, Color("ee9958"), 6, Quality.edges)
		draw_circle(at, 6 if projectile.kind == &"triple" else 9, Color("ffdf8d"))
	for attack in state.attacks:
		if attack.get("layer") != &"behind" and attack.kind not in ORIGINAL_ATTACKS: _attack(attack)
	for id in state.actors: _protection(state.actors[id], id)
	_mode_overlays()


func _was_actor(id: StringName) -> Variant:
	var old: Dictionary = previous.get("actors", {}).get(id, {})
	return old.get("position") if old.get("alive", false) else null


## Placeholders for what the robots' original clips do not show yet: the shield
## (`ShieldProp`: `nombril_<direction>` in the robot's clip), the invincibility effect
## (`InvincibilityProp`: `invincibityPlay` and the colour filter) and the portal transit
## (`SendRobotCommand`). Drawn over the robot until those clips are rendered.
func _protection(actor: Dictionary, id: StringName) -> void:
	if not actor.get("alive", false): return
	var at: Vector2 = ORIGIN + (_blend(_was_actor(id), actor.position) + Vector2.ONE * 0.5) * PITCH
	if int(actor.get("transit_until", 0)) > state.tick:
		if not skin.draw(self, "effect.transit", ArtCatalog.rect("effect.transit", at), state.tick):
			draw_arc(at, 16, state.tick * 0.3, state.tick * 0.3 + PI * 1.5, 24, Color("bab2f4"), 3, Quality.edges)
	if int(actor.get("shield", 0)) > 0:
		if not skin.draw(self, "effect.shield", ArtCatalog.rect("effect.shield", at), state.tick):
			draw_circle(at, 21, Color(0.82, 0.93, 0.69, 0.18))
			draw_arc(at, 21, 0, TAU, 32, Color("d2eeb1"), 2.5, Quality.edges)
	if int(actor.get("invincible_until", 0)) > state.tick:
		var introducing: bool = actor.get("protection_stage") == &"introduction"
		var aura := "effect.invincible_intro" if introducing and skin.texture("effect.invincible_intro") != null else "effect.invincible"
		if not skin.draw(self, aura, ArtCatalog.rect(aura, at), state.tick):
			# `InvincibilityProp._filerColor`: the filter cycles through the rainbow.
			var hue := fposmod(state.tick / 26.0, 1.0)
			draw_arc(at, 23 + sin(state.tick * 0.3) * (6 if introducing else 2), 0, TAU, 32, Color.from_hsv(hue, 0.8, 1.0), 3, Quality.edges)


## Where a moving thing is drawn: its previous-step position blended towards `now`, unless it
## jumped (portal, respawn) or has no previous step.
func _blend(was: Variant, now: Vector2) -> Vector2:
	if between >= 1.0 or was == null or (was as Vector2).distance_to(now) > 1.5: return now
	return (was as Vector2).lerp(now, between)


func _was_projectile(projectile: Dictionary) -> Variant:
	for old in previous.get("projectiles", []):
		if old.actor_id == projectile.actor_id and old.get("born") == projectile.get("born"): return old.position
	return null


## Pair 1 draws green and pair 2 purple; the recorded instance falls back to its columns.
func _portal_pair(cell: Vector2i) -> int:
	var ids: Dictionary = state.get("board_meta", {}).get("portal_ids", {})
	return ids.get(cell, 1 if cell.x == 8 else 2)


func _board_skin() -> StringName:
	return state.get("board_meta", {}).get("skin", &"cinema") if not state.is_empty() else &"cinema"


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


func _tile(cell: Vector2i, kind: StringName, floor := true) -> void:
	if _board_skin() != &"cinema":
		_themed_tile(cell, kind, _board_skin(), floor)
		return
	var at := ORIGIN + Vector2(cell) * PITCH
	if floor and not skin.draw(self, "board.floor_odd" if (cell.x + cell.y) % 2 else "board.floor_even", Rect2(at, Vector2.ONE * PITCH)):
		draw_rect(Rect2(at, Vector2.ONE * PITCH), Color("53304d") if (cell.x + cell.y) % 2 else Color("5c3555"))
		draw_line(at + Vector2(0, 35), at + Vector2(35, 35), Color("472942"), 1)
	# A rolled board names each box's art choice (`StageSets.SETS`); the recorded practice
	# board has none and keeps the parity rule.
	var variant = state.get("board_meta", {}).get("variants", {}).get(cell)
	if kind == &"solid" and variant != null:
		if _brick("board.spotlight" if variant == 1 else "board.seat", cell): return
	elif kind == &"soft" and variant != null:
		if skin.draw(self, CINEMA_SOFT[variant - 1], Rect2(at, Vector2.ONE * 36)): return
	if kind == &"solid":
		if cell.x == 0 or cell.y == 0 or cell.x == 16 or cell.y == 14:
			if _brick("board.wall", cell): return
			_box(Rect2(at + Vector2.ONE, Vector2.ONE * 34), Color("344c64"), Color("66899a"), 5)
			draw_circle(at + Vector2(6, 6), 2, Color("a2bac3"))
		elif (cell.x + cell.y) % 3 == 0:
			if _brick("board.spotlight", cell): return
			draw_circle(at + Vector2(18, 25), 10, Color("293d59"))
			_box(Rect2(at + Vector2(12, 6), Vector2(13, 20)), Color("768eaa"), Color("b8d7d9"), 5)
			draw_circle(at + Vector2(18, 12), 6, Color("ffe7a3"))
		else:
			if _brick("board.seat", cell): return
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
		draw_arc(at + Vector2.ONE * 18, 13, 0, TAU, 32, color, 3, Quality.edges)
		draw_arc(at + Vector2.ONE * 18, 7, 0, TAU, 24, Color(color, 0.7), 2, Quality.edges)


## Native drawing for stage sets other than Cinema; `board.<set>.<piece>` slots replace it.
func _themed_tile(cell: Vector2i, kind: StringName, set_id: StringName, floor := true) -> void:
	var at := ORIGIN + Vector2(cell) * PITCH
	var theme: Array = THEMES.get(set_id, THEMES[&"luxury_stores"])
	var prefix := "board.%s." % set_id
	var rect := Rect2(at, Vector2.ONE * PITCH)
	if floor and not skin.draw(self, prefix + ("floor_odd" if (cell.x + cell.y) % 2 else "floor_even"), rect):
		draw_rect(rect, theme[1] if (cell.x + cell.y) % 2 else theme[0])
	var size: Vector2i = state.get("board_meta", {}).get("size", Vector2i(17, 15))
	var variants: Dictionary = state.get("board_meta", {}).get("variants", {})
	if kind == &"solid":
		# The outer ring is ordinary fixed props in the source; it draws their art when rolled.
		if variants.has(cell) and _brick(prefix + "solid_%d" % variants[cell], cell): return
		if cell.x == 0 or cell.y == 0 or cell.x == size.x - 1 or cell.y == size.y - 1:
			if _brick(prefix + "wall", cell): return
			_box(Rect2(at + Vector2.ONE, Vector2.ONE * 34), theme[2], theme[2].lightened(0.4), 5)
			return
		var center = state.get("board_meta", {}).get("center")
		if center != null and Rect2i(center, Vector2i(3, 3)).has_point(cell): return
		var variant: int = variants.get(cell, 1)
		var fill: Color = theme[3].lerp(theme[2], 0.25 * (variant % 3))
		_box(Rect2(at + Vector2(5, 4), Vector2(26, 28)), fill, theme[4], 7)
		draw_circle(at + Vector2(18, 13), 6, theme[4])
	elif kind == &"soft":
		if skin.draw(self, prefix + "soft_%d" % variants.get(cell, 1 + (cell.x + cell.y) % 2), rect): return
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
				var book: Rect2 = skin.registration(prefix + "spellbook")
				var book_rect := Rect2(at + book.position / 32.0 * PITCH, book.size / 32.0 * PITCH) if book.has_area() else Rect2(at + Vector2(18, 18), Vector2(72, 72))
				# Closed on frame 1; while flipping the clip steps one frame per tick (`Spellbook`).
				var page: float = clampf((feature.get("frame", 1) - 1) / 69.0, 0, 1) if feature.flipping else 0.0
				if not skin.draw(self, prefix + "spellbook", book_rect, state.tick, Vector2.DOWN, page):
					# Below the centrepiece title, opening wider while it flips.
					var open_by := 14.0 if feature.flipping else 2.0
					_box(Rect2(at + Vector2(54 - 20 - open_by, 70), Vector2(20 + open_by, 28)), Color("6b3f8f"), Color("e8c86b"), 4)
					_box(Rect2(at + Vector2(54, 70), Vector2(20 + open_by, 28)), Color("7d4ca6"), Color("e8c86b"), 4)
				for sign in feature.signs:
					var mark := _center(sign.cell)
					if skin.draw(self, prefix + ("sign_bomb" if sign.kind == &"bomb" else "sign_pickup"), Rect2(mark - Vector2.ONE * 18, Vector2.ONE * 36), state.tick): continue
					draw_arc(mark, 14, 0, TAU, 24, Color("e0473c") if sign.kind == &"bomb" else Color("3f8ce0"), 3, Quality.edges)


## A `_brick5` box at `cell`: pack art keeps the clip's registration, so tall props overhang
## the row above as in the original; anything else fits the `cells`-wide square.
func _brick(slot: String, cell: Vector2i, cells: int = 1) -> bool:
	var box: Rect2 = skin.registration(slot)
	if not box.has_area(): return skin.draw(self, slot, Rect2(ORIGIN + Vector2(cell) * PITCH, Vector2.ONE * PITCH * cells), state.get("tick", 0))
	return skin.draw(self, slot, Rect2(ORIGIN + (Vector2(cell) + box.position / 32.0) * PITCH, box.size / 32.0 * PITCH), state.get("tick", 0))


func _marquee() -> void:
	var at := ORIGIN + Vector2(7, 6) * PITCH
	if _board_skin() != &"cinema":
		if state.get("board_meta", {}).get("center") == null: return
		# MagicLibraryMapData hides the centre box (`setMidBox(x, y, false)`); its spellbook stands there.
		if _board_skin() == &"magic_library" and skin.texture("board.magic_library.spellbook") != null: return
		var theme: Array = THEMES.get(_board_skin(), THEMES[&"luxury_stores"])
		if _brick("board.%s.center" % _board_skin(), Vector2i(7, 6), 3): return
		_box(Rect2(at + Vector2(2, 2), Vector2(104, 104)), theme[3].darkened(0.2), theme[4], 12)
		var words := StageSets.title(_board_skin()).split(" ")
		for line in words.size():
			_label(at + Vector2(12, 30 + line * 20), words[line], 17, theme[4].lightened(0.5))
		return
	if _brick("board.marquee", Vector2i(7, 6), 3): return
	_box(Rect2(at + Vector2(2, 2), Vector2(104, 104)), Color("74334c"), Color("e3b36f"), 12)
	_box(Rect2(at + Vector2(9, 30), Vector2(90, 60)), Color("285d73"), Color("acc8ad"), 5)
	_label(at + Vector2(13, 57), "CINEMA", 19, Color("ffe8b2"))
	_label(at + Vector2(15, 77), "★  ★  ★", 18, Color("ffe8b2"))
	for n in 8:
		draw_circle(at + Vector2(12 + n * 12, 18), 3, Color("ffe4a3"))


func _attack_animation_end(kind: StringName) -> float:
	# Laser stops on animation frame 11 while its separate recovery lock continues.
	# See docs/evidence/edition-5-weapon-action-recovery.md and Weapons.advance.
	return {&"hammer": 24.0, &"laser": 11.0, &"flamer": 23.0, &"triple": 32.0, &"shotgun": 14.0, &"boxing": 13.0}.get(kind, 24.0)


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
		draw_line(hand, head, Color("e5be80"), 5, Quality.edges)
		_box(Rect2(head - Vector2(10, 7), Vector2(20, 14)), Color("d5edf0"), Color("7cacba"), 3)
	elif attack.kind == &"boxing":
		var reach: float = sin(progress * PI) * PITCH * 1.2
		draw_line(at, at + direction * reach, Color("e5be80"), 5, Quality.edges)
		draw_circle(at + direction * reach, 9, Color("e8584f"))
	elif attack.kind == &"laser" and attack.fired:
		for cell in attack.get("cells", []):
			draw_line(_center(cell) - Vector2(attack.direction) * 18, _center(cell) + Vector2(attack.direction) * 18, Color("fff1b6"), 7, Quality.edges)
	elif attack.kind == &"flamer":
		for cell in attack.get("cells", []):
			draw_line(at, _center(cell), Color("ffae62"), 11 + sin(age) * 2, Quality.edges)
			draw_line(at, _center(cell), Color("ffe69e"), 5, Quality.edges)
			draw_circle(_center(cell), 8, Color("fff0b0"))
	elif attack.kind == &"shotgun" and not attack.fired:
		draw_circle(at + direction * 18, 3 + minf(age, 14) * 0.7, Color("ffba6e"))
	elif attack.kind == &"triple":
		var kick := 5.0 if age % 15 < 3 else 0.0
		draw_line(at, at + direction * (23 - kick), Color("b7d7d4"), 8, Quality.edges)
	elif not attack.fired:
		draw_arc(at, 22, -PI / 2, -PI / 2 + TAU * minf(1.0, float(state.tick - attack.started + 1) / maxf(1, attack.ready - attack.started)), 24, Color("ffd989"), 3, Quality.edges)


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

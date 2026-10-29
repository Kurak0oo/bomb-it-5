extends "res://scripts/game_view.gd"
## Isolated visual samples only; the Play Preview button uses the real game.

const Catalog = preload("res://scripts/art/catalog.gd")
var component_id := "effect.bomb"
var facing := Vector2.DOWN
var sample_tick := 12.0
var playing := false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	state = {"tick": 12, "attacks": [], "actors": {}, "session": {"game_over": false}, "features": [], "mode_state": {}}
	for id in ROBOT_SLOTS:
		state.actors[id] = {"position": Vector2.ZERO, "cell": Vector2i.ZERO, "alive": true,
			"facing": Vector2.DOWN, "velocity": Vector2.ZERO, "vehicle": &"", "shield": 0,
			"protected_until": 0, "invincible_until": 0, "blink_until": 0, "transit_until": 0,
			"weapon": &"", "ammo": 2, "capacity": 1, "power": 1, "speed": 1.6,
			"score": 0, "lives": 3, "death_frame": 12}
	if not skin.changed.is_connected(queue_redraw): skin.changed.connect(queue_redraw)


func _process(delta: float) -> void:
	if playing: sample_tick += delta * 35
	var bounds := focus_rect()
	var available := get_viewport_rect().size - Vector2.ONE * 24
	var zoom := minf(available.x / bounds.size.x, available.y / bounds.size.y)
	scale = Vector2.ONE * clampf(zoom, 0.02, 6)
	position = get_viewport_rect().size / 2 - bounds.get_center() * scale
	state.tick = floori(sample_tick)
	queue_redraw()


func focus_rect() -> Rect2:
	if component_id == "board.marquee": return Rect2(ORIGIN + Vector2(7, 6) * PITCH, Vector2.ONE * 108)
	if component_id.begins_with("screen."): return Rect2(Vector2.ZERO, Vector2(1280, 720))
	if component_id == "mode.flag": return Rect2(ORIGIN + Vector2.ONE * 18 - Vector2(18, 26), Vector2(36, 44))
	if component_id == "mode.progress": return Rect2(ORIGIN + Vector2.ONE * 18 + Vector2(-18, -34), Vector2(36, 5))
	if component_id.begins_with("look."): return Rect2(ORIGIN + Vector2(-5, -18), Vector2(46, 58))
	if component_id.begins_with("board.") and component_id.count(".") == 2:
		var part := component_id.get_slice(".", 2)
		if part == "center": return Rect2(ORIGIN + Vector2(7, 6) * PITCH, Vector2.ONE * 108)
		if part == "spellbook": return Rect2(ORIGIN + Vector2(7, 6) * PITCH + Vector2.ONE * 18, Vector2.ONE * 72)
		return Rect2(ORIGIN + Vector2(_set_cell(part)) * PITCH, Vector2.ONE * PITCH)
	var tiles := {"board.seat": Vector2(2, 2), "board.spotlight": Vector2(2, 4),
		"board.clapper": Vector2(2, 3), "board.popcorn": Vector2(2, 2),
		"board.popcorn_box": Vector2(2, 2), "board.clapperboard": Vector2(2, 2),
		"board.portal_green": Vector2(8, 1), "board.portal_purple": Vector2(4, 7)}
	if tiles.has(component_id): return Rect2(ORIGIN + tiles[component_id] * PITCH, Vector2.ONE * PITCH)
	if component_id.ends_with(".death"): return Rect2(ORIGIN + Vector2(-10, -36), Vector2(56, 80))
	if component_id.begins_with("actor.") and not component_id.ends_with("portrait"):
		return Rect2(ORIGIN + Vector2(-5, -12), Vector2(46, 52))
	return Catalog.rect(component_id, ORIGIN + Vector2.ONE * 18, sample_tick)


func _draw() -> void:
	if state.is_empty(): return
	state.tick = floori(sample_tick)
	var bounds := focus_rect()
	var group := component_id.get_slice(".", 0)
	var kind := component_id.get_slice(".", 1)
	if group == "actor" and not component_id.ends_with("portrait"):
		_sample_actor(kind, component_id.get_slice(".", 2))
		return
	if group == "attack":
		_attack(_sample_attack(StringName(kind)))
		return
	if group == "look":
		_sample_look(kind, component_id.get_slice(".", 2))
		return
	if group == "board" and component_id.count(".") == 2:
		_sample_set(kind, component_id.get_slice(".", 2))
		return
	if group == "mode":
		if kind == "flag": state.mode_state = {"flag": Vector2i.ZERO}
		else: state.mode_state = {"flag": Vector2i.ZERO, "progress": {&"human": 105}, "capture_ticks": 105}
		state.actors[&"human"].robot = 0
		if kind == "flag": _mode_objects()
		else: _mode_overlays()
		return
	var at := ORIGIN + Vector2.ONE * 18
	var target := Catalog.rect(component_id, at, sample_tick)
	if component_id.begins_with("board.") or component_id.begins_with("screen."): target = bounds
	var progress := posmod(floori(sample_tick), 18) / 17.0 if component_id == "effect.flame" else 0.0 if component_id.begins_with("ui.button_") else -1.0
	if skin.draw(self, component_id, target, sample_tick, facing, progress): return
	match group:
		"board":
			match kind:
				"marquee":
					_marquee()
				"floor_even", "floor_odd":
					draw_rect(bounds, Color("5c3555") if kind == "floor_even" else Color("53304d"))
				"wall": _tile(Vector2i.ZERO, &"solid")
				"seat": _sample_tile(Vector2i(2, 2), &"solid")
				"spotlight": _sample_tile(Vector2i(2, 4), &"solid")
				"clapper": _sample_tile(Vector2i(2, 3), &"soft")
				"popcorn": _sample_tile(Vector2i(2, 2), &"soft")
				"popcorn_box", "clapperboard": _sample_soft(Vector2i(2, 2), 2 if kind == "popcorn_box" else 4)
				"portal_green": _sample_tile(Vector2i(8, 1), &"portal")
				"portal_purple": _sample_tile(Vector2i(4, 7), &"portal")
		"actor":
			var index: int = ROBOT_SLOTS.find(StringName(kind))
			draw_circle(at, 19, ROBOT_COLORS[index].darkened(0.1))
			_label(at + Vector2(-13, 6), "P1" if index == 0 else "AI", 17, Color("173649"))
		"item", "held":
			if kind == "coin":
				draw_circle(at, 6, Color("f6c94a"))
				draw_arc(at, 6, 0, TAU, 16, Color("a8741c"), 1.5, true)
				return
			draw_circle(at, 13, Color("d1fff0"))
			draw_arc(at, 13, 0, TAU, 28, Color("60b4a4"), 2, true)
			var caption: String = ITEM_NAMES.get(StringName(kind), "?")
			_label(at + Vector2(-caption.length() * 4.0, 5), caption, 13, Color("173c40"))
		"projectile":
			draw_line(at - facing * 15, at, Color("ee9958"), 6, true)
			draw_circle(at, 6 if kind == "triple" else 9, Color("ffdf8d"))
		"effect":
			match kind:
				"bomb", "mine": _bomb(at, kind == "mine")
				"flame":
					draw_circle(at, 17, Color("ed7040"))
					draw_circle(at + Vector2(0, -2), 12, Color("ffd473"))
					draw_circle(at + Vector2(-2, -4), 6, Color("fff1b6"))
				"car", "moto", "horse", "dragon", "car_recovery", "moto_recovery", "horse_recovery", "dragon_recovery":
					_box(Rect2(at + Vector2(-16, 1), Vector2(32, 17)), Color("d77f68") if kind.ends_with("recovery") else Color("3c8890"), Color("b9dfca"), 6)
					draw_circle(at + Vector2(-10, 15), 5, Color("203347"))
					draw_circle(at + Vector2(10, 15), 5, Color("203347"))
				_: draw_arc(at, 19, sample_tick * 0.1 if kind == "transit" else 0, TAU, 32,
					Color("ffd778") if kind.begins_with("invincible") else Color("d2eeb1"), 2, true)
		"control":
			var radius := bounds.size.x / 2 - 3
			draw_circle(at, radius, Color(0.6, 0.8, 1, 0.18))
			draw_arc(at, radius, 0, TAU, 64, Color("8cceea"), 2, true)
			if kind.begins_with("action"):
				_label(at + Vector2(-28, 7), "BOMB", 20, Color("ffdda0"))
		"ui":
			_box(bounds, Color("234e62") if kind == "roster" else Color("214c60"), Color("7fb6b7"), 9)
			if kind.begins_with("button"): _label(at + Vector2(-34, 6), "BUTTON", 18)
		"outcome":
			_label(at + Vector2(-28, 7), "WIN" if kind == "won" else "END", 18, Color("ffd989"))
		"screen":
			draw_rect(bounds, Color("102c3b"))
			_label(Vector2(520, 360), kind.replace("_", " ").to_upper(), 40, Color("ffd989"))


## Sample cell per stage-set slot: parity picks the light/dark floor.
func _set_cell(part: String) -> Vector2i:
	if part == "wall": return Vector2i(0, 2)
	if part == "floor_odd": return Vector2i(2, 3)
	return Vector2i(2, 2)


func _sample_set(set_id: String, part: String) -> void:
	var cell := _set_cell(part)
	state.board_meta = {"skin": StringName(set_id), "center": Vector2i(7, 6), "size": Vector2i(17, 15),
		"variants": {cell: part.get_slice("_", 1).to_int()} if part.begins_with("solid_") or part.begins_with("soft_") else {}}
	state.features = []
	match part:
		"floor_even", "floor_odd": _themed_tile(cell, &"floor", StringName(set_id))
		"wall": _themed_tile(cell, &"solid", StringName(set_id))
		"center": _marquee()
		"crocodile", "crocodile_open":
			_themed_tile(cell, &"floor", StringName(set_id))
			state.features = [{"kind": &"crocodile", "cell": cell, "phase": &"open" if part == "crocodile_open" else &"closed",
				"danger": part == "crocodile_open"}]
		"toy_hand":
			state.features = [{"kind": &"toy_hand", "cell": cell, "direction": Vector2i(facing), "open": false, "reach": 0}]
		"belt":
			state.features = [{"kind": &"belt", "track": [cell, cell + Vector2i(0, 9)], "flow": [Vector2i(facing), Vector2i(facing)]}]
		"spellbook", "sign_bomb", "sign_pickup":
			var signs := [] if part == "spellbook" else [{"cell": cell, "kind": &"bomb" if part == "sign_bomb" else &"pickup"}]
			state.features = [{"kind": &"spellbook", "cell": Vector2i(7, 6), "flipping": part != "spellbook", "signs": signs}]
		_:
			if part.begins_with("solid_"): _themed_tile(cell, &"solid", StringName(set_id))
			elif part.begins_with("soft_"): _themed_tile(cell, &"soft", StringName(set_id))
	if not state.features.is_empty(): _features()


func _sample_look(robot_slot: String, part: String) -> void:
	var index: int = ROBOT_SLOTS.find(StringName(robot_slot))
	var actor: Dictionary = state.actors[ROBOT_SLOTS[index]].duplicate(true)
	actor.facing = facing
	actor.hat = part.trim_prefix("hat").to_int() if part.begins_with("hat") else 0
	actor.body = part.trim_prefix("body").to_int() if part.begins_with("body") else 0
	state.commands = []
	state.attacks = []
	_actor(actor, index, ROBOT_SLOTS[index])


func _sample_tile(cell: Vector2i, tile: StringName) -> void:
	_tile(cell, tile)


## A rolled Cinema soft block showing one art choice (`GameView.CINEMA_SOFT`).
func _sample_soft(cell: Vector2i, choice: int) -> void:
	var meta: Dictionary = state.get("board_meta", {}).duplicate()
	meta.variants = {cell: choice}
	state.board_meta = meta
	_tile(cell, &"soft")


func _sample_actor(kind: String, pose: String) -> void:
	var index: int = ROBOT_SLOTS.find(StringName(kind))
	var actor: Dictionary = state.actors[ROBOT_SLOTS[index]].duplicate(true)
	actor.facing = facing
	actor.alive = pose != "death"
	actor.velocity = facing if pose == "walk" else Vector2.ZERO
	actor.death_frame = posmod(floori(sample_tick), 61)
	state.commands = [{"actor_id": ROBOT_SLOTS[index], "direction": facing if pose == "walk" else Vector2.ZERO}]
	state.attacks = [_sample_attack(&"hammer")] if pose == "action" else []
	if not state.attacks.is_empty(): state.attacks[0].actor_id = ROBOT_SLOTS[index]
	_actor(actor, index, ROBOT_SLOTS[index])


func _sample_attack(kind: StringName) -> Dictionary:
	# Sample the existing weapon phase contract, not a second damage simulation.
	var cycle: int = {&"hammer": 25, &"laser": 22, &"flamer": 24, &"triple": 43, &"shotgun": 26}.get(kind, 25)
	var age := posmod(floori(sample_tick), cycle)
	var ready: int = {&"hammer": 24, &"laser": 11, &"shotgun": 14}.get(kind, 1)
	var fired := age >= ready
	return {"kind": kind, "actor_id": &"human", "cell": Vector2i.ZERO, "direction": Vector2i(facing),
		"frame": mini(age, 11) if kind == &"laser" else age, "fired": fired,
		"cells": [Vector2i.ZERO] if fired else [], "started": 0, "ready": ready}

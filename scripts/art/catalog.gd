extends RefCounted
## Stable visual slots shared by the workbench and the real renderer.

const Looks = preload("res://scripts/looks.gd")
const REFERENCE := "res://docs/evidence/reference-2026-10-19/"
const OPENING := REFERENCE + "cinema-observed-01/opening-board.png"
const FEATURES := "res://docs/evidence/reference-2026-10-21/features/"
## Robot slot names in roster order (`_r0`..`_r7`); keep in step with GameView.ROBOT_SLOTS.
const ROBOTS: Array[String] = ["human", "ruby", "lime", "gold", "violet", "slate", "mint", "snow"]
## Native board skins beyond Cinema, and the map features each set draws.
const SETS: Array[String] = ["birthday_party", "candy_factory", "zoo", "luxury_stores", "magic_library"]
const SET_FEATURES := {"zoo": [["crocodile", "Crocodile · closed"], ["crocodile_open", "Crocodile · open"]],
	"birthday_party": [["toy_hand", "Toy hand"]], "candy_factory": [["belt", "Conveyor belt cell"]],
	"magic_library": [["spellbook", "Spellbook"], ["sign_bomb", "Spellbook sign · bomb"], ["sign_pickup", "Spellbook sign · pickup"]]}
const SCREENS := [["menu", "Main menu"], ["settings", "Game settings"], ["character", "Character select"],
	["how_to_play", "How to play"], ["score", "Level score"], ["dress_up", "Dress up"], ["game_over", "Game over"],
	["game_win", "Game complete"]]
const RIDES: Array[String] = ["car", "moto", "horse", "dragon"]
static var _cache: Array[Dictionary] = []


static func entries() -> Array[Dictionary]:
	if not _cache.is_empty(): return _cache
	var result: Array[Dictionary] = []
	for item in [["floor_even", "Floor · light"], ["floor_odd", "Floor · dark"],
		["wall", "Outer wall"], ["seat", "Cinema seat"], ["spotlight", "Spotlight"],
		["clapper", "Soft block · clapper"], ["popcorn", "Soft block · popcorn"],
		["portal_green", "Portal · green"], ["portal_purple", "Portal · purple"],
		["marquee", "Cinema centrepiece"]]:
		result.append(_entry("board." + item[0], item[1], "Board", Vector2(108, 108) if item[0] == "marquee" else Vector2(36, 36)))
	for set_id in SETS:
		var set_title := set_id.replace("_", " ").capitalize()
		for item in [["floor_even", "Floor · light"], ["floor_odd", "Floor · dark"], ["wall", "Outer wall"],
			["soft_a", "Soft block · A"], ["soft_b", "Soft block · B"]]:
			result.append(_entry("board.%s.%s" % [set_id, item[0]], "%s · %s" % [set_title, item[1]], "Stage sets", Vector2(36, 36)))
		for variant in range(1, 8):
			result.append(_entry("board.%s.solid_%d" % [set_id, variant], "%s · Solid block %d" % [set_title, variant], "Stage sets", Vector2(36, 36)))
		result.append(_entry("board.%s.center" % set_id, set_title + " · Centrepiece", "Stage sets", Vector2(108, 108)))
		for item in SET_FEATURES.get(set_id, []):
			var size := Vector2(72, 72) if item[0] == "spellbook" else Vector2(36, 36)
			result.append(_entry("board.%s.%s" % [set_id, item[0]], "%s · %s" % [set_title, item[1]], "Stage sets", size))
	for actor in ROBOTS:
		for pose in ["idle", "walk", "action", "portrait", "death"]:
			result.append(_entry("actor.%s.%s" % [actor, pose], "%s · %s" % [actor.capitalize(), pose.capitalize()],
				"Characters", Vector2(38, 38) if pose == "portrait" else Vector2(40, 40) if pose == "death" else Vector2(40, 44)))
	for robot in ROBOTS.size():
		for kind in ["hat", "body"]:
			for number in range(1, Looks.count(robot, StringName(kind)) + 1):
				result.append(_entry("look.%s.%s%d" % [ROBOTS[robot], kind, number], "%s · %s %d" % [ROBOTS[robot].capitalize(), "Hat" if kind == "hat" else "Outfit", number],
					"Looks", Vector2(30, 20) if kind == "hat" else Vector2(24, 17)))
	for item in ["capacity", "power", "speed", "life", "shield", "invincible", "car", "moto", "horse", "dragon", "coin",
		"landmine", "hammer", "flamer", "laser", "triple", "shotgun"]:
		result.append(_entry("item." + item, _title(item) + " pickup", "Pickups", Vector2(28, 28)))
	for kind in ["landmine", "hammer", "flamer", "laser", "triple", "shotgun"]:
		result.append(_entry("held." + kind, _title(kind) + " · held", "Weapons", Vector2(24, 24)))
	for kind in ["hammer", "flamer", "laser", "triple", "shotgun"]:
		result.append(_entry("attack." + kind, _title(kind) + " · action", "Weapons", Vector2(48, 48)))
	for kind in ["triple", "shotgun"]:
		result.append(_entry("projectile." + kind, _title(kind) + " · projectile", "Weapons", Vector2(28, 24)))
	for item in [["bomb", "Ordinary bomb"], ["mine", "Placed mine"], ["flame", "Bomb flame"],
		["shield", "Shield bubble"], ["invincible", "Invincibility · active aura"], ["invincible_intro", "Invincibility · introduction"], ["blink", "Protection blink overlay"],
		["transit", "Portal transit overlay"], ["car", "Car ride"], ["moto", "Moto ride"], ["horse", "Horse ride"], ["dragon", "Dragon ride"],
		["car_recovery", "Car · damage recovery"], ["moto_recovery", "Moto · damage recovery"],
		["horse_recovery", "Horse · damage recovery"], ["dragon_recovery", "Dragon · damage recovery"]]:
		var size := Vector2(36, 36) if item[0] in ["bomb", "mine", "flame"] else Vector2(48, 48) if item[0].begins_with("invincible") else Vector2(44, 35) if item[0].get_slice("_", 0) in RIDES else Vector2(44, 44)
		result.append(_entry("effect." + item[0], item[1], "Effects", size))
	for item in [["stick_base", "Joystick base", 168], ["stick_thumb", "Joystick thumb", 54],
		["action_normal", "Action button · idle", 128], ["action_pressed", "Action button · pressed", 128],
		["action_disabled", "Action button · disabled", 128]]:
		result.append(_entry("control." + item[0], item[1], "Controls", Vector2.ONE * item[2]))
	for item in [["background", "Screen background", Vector2(1280, 720)], ["frame", "Screen frame", Vector2(1260, 700)],
		["board_frame", "Board frame", Vector2(626, 554)],
		["roster", "Player HUD panel", Vector2(251, 76)], ["timer", "Timer panel", Vector2(141, 42)],
		["results", "Result panel", Vector2(444, 228)], ["button_normal", "Menu button · idle", Vector2(210, 40)],
		["button_hover", "Menu button · hover", Vector2(210, 40)], ["button_pressed", "Menu button · pressed", Vector2(210, 40)],
		["button_disabled", "Menu button · disabled", Vector2(210, 40)]]:
		result.append(_entry("ui." + item[0], item[1], "Interface", item[2]))
	result.append(_entry("mode.flag", "Green Zone flag", "Modes", Vector2(36, 44)))
	result.append(_entry("mode.progress", "Capture progress bar", "Modes", Vector2(36, 5)))
	for item in SCREENS:
		result.append(_entry("screen." + item[0], "Screen · " + item[1], "Screens", Vector2(1280, 720)))
	for outcome in ["won", "lost", "timeout", "game_over", "paused"]:
		result.append(_entry("outcome." + outcome, "Outcome · " + outcome.replace("_", " "), "Outcomes", Vector2(64, 64)))
	_cache = result
	return _cache


static func find(id: String) -> Dictionary:
	for entry in entries():
		if entry.id == id: return entry
	return {}


static func rect(id: String, at: Vector2, tick: float = 0, beam: bool = false) -> Rect2:
	# The same placement feeds the live renderer and the component inspector.
	var size: Vector2 = find(id).get("size", Vector2(44, 44))
	var offset := Vector2.ZERO
	if beam: size = Vector2.ONE * 36
	if id.begins_with("actor.") and id.get_slice(".", 2) in ["idle", "walk", "action"]: offset.y = -2
	if id.begins_with("held."): offset = Vector2(15, 7)
	if id.begins_with("effect.") and id.get_slice(".", 1).get_slice("_", 0) in RIDES:
		offset.y = 8.5
		if id.ends_with("_recovery"): offset.x = sin(tick * 2.0) * 3.0
	return Rect2(at + offset - size / 2, size)


static func _entry(id: String, title: String, category: String, size: Vector2) -> Dictionary:
	var reference := OPENING
	var kind := id.get_slice(".", 1)
	if id.begins_with("attack.") or id.begins_with("held.") or id.begins_with("projectile."):
		var family := "fireball" if kind == "shotgun" else kind
		reference = REFERENCE + "weapon-survey/weapon-survey-%s-right-01/first-frame.png" % family
		if kind == "flamer": reference = REFERENCE + "weapon-survey/flamer-geometry-right-01/input.png"
	elif id.begins_with("outcome.") or id == "ui.results":
		reference = REFERENCE + "results/zero-kill-win/win-results.png"
	elif id.begins_with("board.zoo."): reference = FEATURES + "zoo-crocodiles-open.png"
	elif id.begins_with("board.birthday_party."): reference = FEATURES + "birthday-toy-hands-open.png"
	elif id.begins_with("board.candy_factory."): reference = FEATURES + "candy-belt.png"
	elif id.begins_with("board.magic_library."): reference = FEATURES + "magic-spellbook-signs.png"
	elif id in ["item.coin"]: reference = "res://docs/evidence/reference-2026-10-21/pac-man/pac-man-opening.png"
	elif id.begins_with("mode."): reference = "res://docs/evidence/reference-2026-10-21/green-zone/green-zone-capture.png"
	elif id.begins_with("board.") and id.count(".") == 2: reference = ""
	return {"id": id, "title": title, "category": category, "size": size,
		"reference": reference, "description": "Visual replacement only. Game rules and collision stay unchanged."}


static func _title(kind: String) -> String:
	return {"shotgun": "Fireball", "triple": "Triple-shot", "invincible": "Invincibility", "landmine": "Mine",
		"coin": "Pac-Man coin"}.get(kind, kind.capitalize())

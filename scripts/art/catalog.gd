extends RefCounted
## Stable visual slots shared by the workbench and the real renderer.

const REFERENCE := "res://docs/evidence/reference-2026-10-19/"
const OPENING := REFERENCE + "cinema-observed-01/opening-board.png"
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
	for actor in ["human", "ruby", "mint", "gold"]:
		for pose in ["idle", "walk", "action", "portrait", "death"]:
			result.append(_entry("actor.%s.%s" % [actor, pose], "%s · %s" % [actor.capitalize(), pose.capitalize()],
				"Characters", Vector2(38, 38) if pose == "portrait" else Vector2(40, 40) if pose == "death" else Vector2(40, 44)))
	for item in ["capacity", "power", "speed", "life", "shield", "invincible", "car", "moto",
		"landmine", "hammer", "flamer", "laser", "triple", "shotgun"]:
		result.append(_entry("item." + item, _title(item) + " pickup", "Pickups", Vector2(28, 28)))
	for kind in ["landmine", "hammer", "flamer", "laser", "triple", "shotgun"]:
		result.append(_entry("held." + kind, _title(kind) + " · held", "Weapons", Vector2(24, 24)))
	for kind in ["hammer", "flamer", "laser", "triple", "shotgun"]:
		result.append(_entry("attack." + kind, _title(kind) + " · action", "Weapons", Vector2(36, 36)))
	for kind in ["triple", "shotgun"]:
		result.append(_entry("projectile." + kind, _title(kind) + " · projectile", "Weapons", Vector2(28, 24)))
	for item in [["bomb", "Ordinary bomb"], ["mine", "Placed mine"], ["flame", "Bomb flame"],
		["shield", "Shield bubble"], ["invincible", "Invincibility · active aura"], ["invincible_intro", "Invincibility · introduction"], ["blink", "Protection blink overlay"],
		["transit", "Portal transit overlay"], ["car", "Car ride"], ["moto", "Moto ride"],
		["car_recovery", "Car · damage recovery"], ["moto_recovery", "Moto · damage recovery"]]:
		result.append(_entry("effect." + item[0], item[1], "Effects", Vector2(44, 44)))
	for item in [["stick_base", "Joystick base", 168], ["stick_thumb", "Joystick thumb", 54],
		["action_normal", "Action button · idle", 128], ["action_pressed", "Action button · pressed", 120],
		["action_disabled", "Action button · disabled", 128]]:
		result.append(_entry("control." + item[0], item[1], "Controls", Vector2.ONE * item[2]))
	for item in [["background", "Screen background", Vector2(1280, 720)], ["frame", "Screen frame", Vector2(1260, 700)],
		["board_frame", "Board frame", Vector2(626, 554)],
		["roster", "Player HUD panel", Vector2(251, 76)], ["timer", "Timer panel", Vector2(141, 42)],
		["results", "Result panel", Vector2(444, 228)], ["button_normal", "Menu button · idle", Vector2(210, 40)],
		["button_hover", "Menu button · hover", Vector2(210, 40)], ["button_pressed", "Menu button · pressed", Vector2(210, 40)],
		["button_disabled", "Menu button · disabled", Vector2(210, 40)]]:
		result.append(_entry("ui." + item[0], item[1], "Interface", item[2]))
	for outcome in ["won", "lost", "timeout", "game_over", "paused"]:
		result.append(_entry("outcome." + outcome, "Outcome · " + outcome.replace("_", " "), "Outcomes", Vector2(64, 64)))
	_cache = result
	return _cache


static func find(id: String) -> Dictionary:
	for entry in entries():
		if entry.id == id: return entry
	return {}


static func _entry(id: String, title: String, category: String, size: Vector2) -> Dictionary:
	var reference := OPENING
	var kind := id.get_slice(".", 1)
	if id.begins_with("attack.") or id.begins_with("held.") or id.begins_with("projectile."):
		var family := "fireball" if kind == "shotgun" else kind
		reference = REFERENCE + "weapon-survey/weapon-survey-%s-right-01/first-frame.png" % family
		if kind == "flamer": reference = REFERENCE + "weapon-survey/flamer-geometry-right-01/input.png"
	elif id.begins_with("outcome.") or id == "ui.results":
		reference = REFERENCE + "results/zero-kill-win/win-results.png"
	return {"id": id, "title": title, "category": category, "size": size,
		"reference": reference, "description": "Visual replacement only. Game rules and collision stay unchanged."}


static func _title(kind: String) -> String:
	return {"shotgun": "Fireball", "triple": "Triple-shot", "invincible": "Invincibility", "landmine": "Mine"}.get(kind, kind.capitalize())

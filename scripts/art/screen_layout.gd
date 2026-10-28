extends RefCounted
## Where the original pack's screen art puts each widget (#76).
##
## Every rectangle is in page coordinates (1280 x 720) and comes from measuring the ignored
## local pack sheets with `tools/inspect_screen_art.gd`. Nothing here is art: it is the
## registration table the replica needs so that a machine without `original/` still checks
## the native fallback (`NATIVE`) and the art layout (`PAGES`) separately.
##
## Two kinds of native widget sit on this table (see ADR 0009):
## - a *ghost* is real text, rect and hit test with transparent pixels, because the sheet
##   already paints that control (`baked`);
## - a *live painter* occludes its painted region with an opaque `plate` and draws itself,
##   because the sheet cannot supply the value (key names, scores, look state — `live`).
##
## `frame` is the page rectangle the whole plate draws into: the sheet's visible pixels
## fitted to the page height and centred (`Skin.screen_frame`). `crop` cuts a plate out of
## its sheet when the capture cannot be used whole; both are measured, not chosen.
##
## Registration evidence: `original/art/slots/screen.<page>/candidate.png` (ignored local
## pack built by `tools/art_pipeline/original_pack.py`), measured 2026-10-29.

const PAGE := Rect2(0, 0, 1280, 720)

## Page tables. `slots` are the painted hotspots; `plates` occlude art a live widget
## replaces; `baked` names are ghosted; `live` names paint over a plate.
const PAGES := {
	&"menu": {"crop": Rect2(), "frame": Rect2(), "slots": {}, "plates": {}, "baked": [], "live": []},
	&"settings": {"crop": Rect2(), "frame": Rect2(), "slots": {}, "plates": {}, "baked": [], "live": []},
	&"character": {"crop": Rect2(), "frame": Rect2(), "slots": {}, "plates": {}, "baked": [], "live": []},
	&"how_to_play": {"crop": Rect2(), "frame": Rect2(), "slots": {}, "plates": {}, "baked": [], "live": []},
	&"score": {"crop": Rect2(), "frame": Rect2(), "slots": {}, "plates": {}, "baked": [], "live": []},
	&"dress_up": {"crop": Rect2(), "frame": Rect2(), "slots": {}, "plates": {}, "baked": [], "live": []},
	&"game_over": {"crop": Rect2(), "frame": Rect2(), "slots": {}, "plates": {}, "baked": [], "live": []},
	&"game_win": {"crop": Rect2(), "frame": Rect2(), "slots": {}, "plates": {}, "baked": [], "live": []},
}

## The pinned native fallback: today's coordinates, unchanged when no screen sheet is used.
## A height of 0 means the widget sizes itself (labels); the checks compare x/width only.
const NATIVE := {
	&"menu": {
		&"title": Rect2(0, 120, 1280, 0), &"local_arcade": Rect2(0, 215, 1280, 0),
		&"start": Rect2(490, 330, 300, 62), &"how_to_play": Rect2(490, 410, 300, 62),
	},
	&"settings": {
		&"title": Rect2(0, 40, 1280, 0), &"goals": Rect2(0, 245, 1280, 0),
		&"mode_arcade": Rect2(130, 110, 240, 120), &"mode_kill": Rect2(390, 110, 240, 120),
		&"mode_pac_man": Rect2(650, 110, 240, 120), &"mode_green_zone": Rect2(910, 110, 240, 120),
		&"label_enemies": Rect2(180, 308, 0, 0), &"label_levels": Rect2(180, 378, 0, 0),
		&"label_arena": Rect2(180, 448, 0, 0), &"label_difficulty": Rect2(180, 518, 0, 0),
		&"enemies_3": Rect2(400, 300, 116, 44), &"enemies_2": Rect2(526, 300, 116, 44),
		&"enemies_1": Rect2(652, 300, 116, 44),
		&"levels_5": Rect2(400, 370, 116, 44), &"levels_10": Rect2(526, 370, 116, 44),
		&"levels_15": Rect2(642, 370, 116, 44), &"levels_20": Rect2(758, 370, 116, 44),
		&"arena": Rect2(400, 440, 500, 44),
		&"difficulty_easy": Rect2(400, 510, 160, 44), &"difficulty_normal": Rect2(570, 510, 160, 44),
		&"difficulty_hard": Rect2(740, 510, 160, 44),
		&"back": Rect2(130, 610, 220, 60), &"next": Rect2(930, 610, 220, 60),
	},
	&"character": {
		&"title": Rect2(0, 40, 1280, 0), &"preview": Rect2(260, 290, 220, 220),
		&"robot_0": Rect2(150, 120, 110, 110), &"robot_1": Rect2(275, 120, 110, 110),
		&"robot_2": Rect2(400, 120, 110, 110), &"robot_3": Rect2(525, 120, 110, 110),
		&"robot_4": Rect2(650, 120, 110, 110), &"robot_5": Rect2(775, 120, 110, 110),
		&"robot_6": Rect2(900, 120, 110, 110), &"robot_7": Rect2(1025, 120, 110, 110),
		&"name_0": Rect2(150, 236, 110, 0), &"name_1": Rect2(275, 236, 110, 0),
		&"name_2": Rect2(400, 236, 110, 0), &"name_3": Rect2(525, 236, 110, 0),
		&"name_4": Rect2(650, 236, 110, 0), &"name_5": Rect2(775, 236, 110, 0),
		&"name_6": Rect2(900, 236, 110, 0), &"name_7": Rect2(1025, 236, 110, 0),
		&"looks_panel": Rect2(540, 290, 560, 250), &"looks_title": Rect2(564, 304, 0, 0),
		&"look_1": Rect2(564, 346, 120, 50), &"look_2": Rect2(696, 346, 120, 50),
		&"look_3": Rect2(828, 346, 120, 50), &"look_4": Rect2(960, 346, 120, 50),
		&"look_5": Rect2(564, 440, 120, 50), &"look_6": Rect2(696, 440, 120, 50),
		&"look_7": Rect2(828, 440, 120, 50), &"look_8": Rect2(960, 440, 120, 50),
		&"looks_hint": Rect2(710, 308, 360, 0),
		&"set_avatar": Rect2(520, 606, 200, 60),
		&"back": Rect2(130, 610, 220, 60), &"start_game": Rect2(930, 610, 220, 60),
	},
	&"how_to_play": {
		&"title": Rect2(0, 30, 1280, 0), &"controls_tab": Rect2(410, 95, 220, 44),
		&"power_ups_tab": Rect2(640, 95, 220, 44),
		&"keyboard_label": Rect2(160, 180, 0, 0), &"action_up": Rect2(160, 233, 0, 0),
		&"action_left": Rect2(160, 289, 0, 0), &"action_down": Rect2(160, 345, 0, 0),
		&"action_right": Rect2(160, 401, 0, 0), &"action_bomb": Rect2(160, 457, 0, 0),
		&"key_up": Rect2(400, 225, 200, 46), &"key_left": Rect2(400, 281, 200, 46),
		&"key_down": Rect2(400, 337, 200, 46), &"key_right": Rect2(400, 393, 200, 46),
		&"key_bomb": Rect2(400, 449, 200, 46),
		&"pause_label": Rect2(160, 513, 0, 0), &"pause_value": Rect2(400, 513, 200, 0),
		&"message": Rect2(160, 560, 440, 0),
		&"reset_keys": Rect2(660, 470, 220, 56), &"save_keys": Rect2(910, 470, 220, 56),
		&"touch_label": Rect2(690, 180, 0, 0), &"touch_text": Rect2(690, 225, 410, 0),
		&"goals_label": Rect2(690, 345, 410, 0),
		&"back": Rect2(130, 630, 220, 60),
	},
	&"score": {
		&"title": Rect2(290, 130, 700, 0),
		&"row_label_0": Rect2(360, 210, 0, 0), &"row_label_1": Rect2(360, 266, 0, 0),
		&"row_label_2": Rect2(360, 322, 0, 0), &"row_label_3": Rect2(360, 378, 0, 0),
		&"row_label_4": Rect2(360, 434, 0, 0),
		&"row_value_0": Rect2(720, 210, 200, 0), &"row_value_1": Rect2(720, 266, 200, 0),
		&"row_value_2": Rect2(720, 322, 200, 0), &"row_value_3": Rect2(720, 378, 200, 0),
		&"row_value_4": Rect2(720, 434, 200, 0),
		&"continue": Rect2(660, 520, 260, 64), &"dress_up": Rect2(360, 520, 260, 64),
		&"tip_ok": Rect2(540, 410, 200, 60),
	},
	&"dress_up": {
		&"title": Rect2(0, 90, 1280, 0), &"preview": Rect2(240, 230, 220, 220),
		&"looks_panel": Rect2(500, 215, 560, 250), &"looks_title": Rect2(524, 229, 0, 0),
		&"look_1": Rect2(524, 271, 120, 50), &"look_2": Rect2(656, 271, 120, 50),
		&"look_3": Rect2(788, 271, 120, 50), &"look_4": Rect2(920, 271, 120, 50),
		&"look_5": Rect2(524, 365, 120, 50), &"look_6": Rect2(656, 365, 120, 50),
		&"look_7": Rect2(788, 365, 120, 50), &"look_8": Rect2(920, 365, 120, 50),
		&"looks_hint": Rect2(670, 233, 360, 0),
		&"dress_done": Rect2(540, 560, 200, 60),
	},
	&"game_over": {
		&"title": Rect2(290, 170, 700, 0), &"retry_hint": Rect2(290, 260, 700, 0),
		&"end_unlock": Rect2(290, 400, 700, 0), &"total_label": Rect2(400, 340, 0, 0),
		&"total_value": Rect2(680, 340, 200, 0), &"try_again": Rect2(510, 460, 260, 64),
	},
	&"game_win": {
		&"title": Rect2(290, 170, 700, 0), &"end_unlock": Rect2(290, 400, 700, 0),
		&"total_label": Rect2(400, 340, 0, 0), &"total_value": Rect2(680, 340, 200, 0),
		&"try_again": Rect2(510, 460, 260, 64),
	},
}


static func pages() -> Array[StringName]:
	var result: Array[StringName] = []
	for page in PAGES: result.append(page)
	return result


## The page's table; an unmeasured page (no sheet yet) has none.
static func table(page: StringName) -> Dictionary:
	return PAGES.get(page, {})


## The plate crop for a `screen.<page>` id.
static func crop_from_id(id: String) -> Rect2:
	return table(StringName(id.trim_prefix("screen."))).get("crop", Rect2())


## The page rectangle the plate draws into, as measured from the sheet.
static func frame(page: StringName) -> Rect2:
	return table(page).get("frame", Rect2())


## The native rectangle for a widget, pinned at the pre-art coordinates.
static func native(page: StringName, name: StringName) -> Rect2:
	return NATIVE.get(page, {}).get(name, Rect2())


## Where a widget goes: its painted hotspot in art mode, else the native fallback.
static func slot(page: StringName, name: StringName, native_rect: Rect2, art: bool) -> Rect2:
	if art and table(page).get("slots", {}).has(name): return table(page).slots[name]
	return native_rect


## The opaque rectangle that hides art a live widget replaces.
static func plate(page: StringName, name: StringName) -> Rect2:
	return table(page).get("plates", {}).get(name, Rect2())


## Whether the sheet already paints this widget's text and frame.
static func is_baked(page: StringName, name: StringName) -> bool:
	return name in table(page).get("baked", [])


## Whether this widget replaces painted art and must sit on a plate.
static func is_live(page: StringName, name: StringName) -> bool:
	return name in table(page).get("live", [])

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

## Every UI page is the 700x510 stage `UIManager` clips to (`scrollRect`), drawn at 720/510
## and centred: the sheets are cropped to it (`source.crop`), so a page's `frame` is this.
const STAGE_FRAME := Rect2(145.9, 0, 988.2, 720)

## Page tables, in page coordinates. `slots` are the painted hotspots (named instances
## measured by `tools/measure_screen_art.py`, which maps stage x to 145.9 + x * 720 / 510);
## `plates` occlude art a live widget replaces, with `colors` sampled from the sheet beside
## it; `baked` names are ghosted; `live` names paint over a plate. Painted labels with no
## instance name (row captions, titles) are placed on their painted text; ghosts there only
## carry the text for tests and accessibility.
const PAGES := {
	&"menu": {"crop": Rect2(), "frame": STAGE_FRAME,
		"slots": {&"title": Rect2(232, 20, 750, 190), &"local_arcade": Rect2(232, 20, 750, 190),
			&"Start": Rect2(778.5, 242.2, 317.1, 87.9), &"HowToPlay": Rect2(776.8, 345, 319.5, 86.3),
			&"quality": Rect2(1060.4, 38.8, 55.3, 55.3), &"sound": Rect2(1060.4, 104.9, 55.3, 55.3),
			&"music": Rect2(1060.4, 171, 55.3, 55.3), &"version": Rect2(1063.6, 7, 70, 20)},
		"plates": {}, "colors": {},
		"baked": [&"title", &"local_arcade", &"Start", &"HowToPlay", &"quality", &"sound", &"music"],
		"live": [&"version"]},
	&"settings": {"crop": Rect2(), "frame": STAGE_FRAME,
		"slots": {&"Title": Rect2(448, 50, 392, 72), &"Goals": Rect2(448, 50, 392, 72),
			&"Mode_arcade": Rect2(228.3, 137.7, 212, 216.9), &"Mode_kill": Rect2(431.4, 140.4, 209.1, 216.5),
			&"Mode_pac_man": Rect2(621.7, 136.5, 229.9, 220.5), &"Mode_green_zone": Rect2(831, 137.4, 213, 219.5),
			&"LabelEnemies": Rect2(252, 420, 190, 45), &"LabelLevels": Rect2(252, 472, 190, 45),
			&"LabelArena": Rect2(252, 526, 190, 45), &"LabelDifficulty": Rect2(252, 580, 190, 45),
			&"Enemies3": Rect2(462.6, 417.3, 94.8, 47.2), &"Enemies2": Rect2(554.9, 417.4, 94.8, 47.2),
			&"Enemies1": Rect2(646, 417.3, 94.8, 47.2),
			&"Levels5": Rect2(462.6, 469.2, 94.8, 47.2), &"Levels10": Rect2(555, 469.2, 94.8, 47.2),
			&"Levels15": Rect2(646.1, 469.2, 94.8, 47.2), &"Levels20": Rect2(738.6, 469.2, 94.8, 47.2),
			&"Arena": Rect2(463, 520.5, 375.7, 55.1),
			&"Difficulty_easy": Rect2(463, 580.2, 180.9, 47.7), &"Difficulty_normal": Rect2(643.7, 580.2, 180.9, 47.7),
			&"Difficulty_hard": Rect2(825.4, 580.2, 180.9, 47.7),
			&"Back": Rect2(266.4, 643.5, 237.5, 58), &"Next": Rect2(778.4, 643.5, 237.5, 58)},
		"plates": {&"Arena": Rect2(468, 529, 308, 39)}, "colors": {&"Arena": Color("fefefe")},
		"baked": [&"Title", &"Goals", &"Mode_arcade", &"Mode_kill", &"Mode_pac_man", &"Mode_green_zone",
			&"LabelEnemies", &"LabelLevels", &"LabelArena", &"LabelDifficulty", &"Enemies3", &"Enemies2", &"Enemies1",
			&"Levels5", &"Levels10", &"Levels15", &"Levels20", &"Difficulty_easy", &"Difficulty_normal",
			&"Difficulty_hard", &"Back", &"Next"],
		"live": [&"Arena"]},
	&"character": {"crop": Rect2(), "frame": STAGE_FRAME,
		"slots": {&"Title": Rect2(470, 30, 350, 120),
			&"Robot0": Rect2(236, 153.1, 116.5, 113.6), &"Robot1": Rect2(334.4, 154.6, 116.5, 113.6),
			&"Robot2": Rect2(433.8, 157.2, 116.5, 113.6), &"Robot3": Rect2(533.8, 156, 116.5, 113.6),
			&"Robot4": Rect2(633.2, 155.2, 116.5, 113.6), &"Robot5": Rect2(731.9, 156.3, 116.5, 113.6),
			&"Robot6": Rect2(830, 156.7, 116.5, 117), &"Robot7": Rect2(930.1, 156.4, 116.5, 113.6),
			&"preview": Rect2(240, 335, 175, 235), &"looks_panel": Rect2(436, 318, 412, 252),
			&"Back": Rect2(266.4, 640.5, 237.5, 58), &"SetAvatar": Rect2(521.5, 640.5, 237.5, 58),
			&"StartGame": Rect2(774.8, 640.5, 237.6, 58)},
		"plates": {&"preview": Rect2(240, 335, 175, 235)}, "colors": {&"preview": Color("e7fff8")},
		"baked": [&"Title", &"Robot0", &"Robot1", &"Robot2", &"Robot3", &"Robot4", &"Robot5", &"Robot6",
			&"Robot7", &"Back", &"SetAvatar", &"StartGame"],
		"live": [&"preview", &"looks_panel"]},
	&"how_to_play": {"crop": Rect2(), "frame": STAGE_FRAME,
		"slots": {&"title": Rect2(414, 60.9, 451.8, 74.5), &"ControlsTab": Rect2(414, 60.9, 451.8, 74.5),
			&"PowerUpsTab": Rect2(788.8, 585.5, 237.6, 58), &"Back": Rect2(251.2, 585.5, 237.6, 58),
			&"SaveKeys": Rect2(451.5, 504.8, 165, 40.8), &"reset_keys": Rect2(679, 504.8, 165, 40.8),
			&"Message": Rect2(287.2, 174.8, 705.9, 40.1),
			&"Key_up": Rect2(472.1, 331.1, 35.8, 35.8), &"Key_left": Rect2(433, 364.4, 35.9, 35.9),
			&"Key_down": Rect2(472.1, 368.3, 35.9, 35.9), &"Key_right": Rect2(511.6, 364.4, 35.9, 35.9),
			&"Key_bomb": Rect2(418, 439.9, 153, 35.1),
			&"keyboard_label": Rect2(252, 320, 135, 170), &"action_up": Rect2(252, 340, 135, 60),
			&"action_left": Rect2(252, 340, 135, 60), &"action_down": Rect2(252, 340, 135, 60),
			&"action_right": Rect2(252, 340, 135, 60), &"action_bomb": Rect2(252, 420, 135, 60),
			&"pause_label": Rect2(252, 420, 135, 60), &"pause_value": Rect2(252, 420, 135, 60),
			&"touch_label": Rect2(612, 310, 395, 185), &"touch_text": Rect2(612, 310, 395, 185),
			&"goals_label": Rect2(612, 310, 395, 185)},
		"plates": {&"Message": Rect2(292, 176, 696, 40), &"Key_up": Rect2(477.2, 334.6, 25.7, 30),
			&"Key_left": Rect2(436.7, 371, 25.7, 30), &"Key_down": Rect2(478.3, 371, 25.7, 30),
			&"Key_right": Rect2(515.9, 371, 25.7, 30), &"Key_bomb": Rect2(425, 444, 138, 27)},
		"colors": {&"Message": Color("12ecff"), &"Key_up": Color("f4f4f4"), &"Key_left": Color("f4f4f4"),
			&"Key_down": Color("f4f4f4"), &"Key_right": Color("f4f4f4"), &"Key_bomb": Color("e6e6e6")},
		"baked": [&"title", &"ControlsTab", &"PowerUpsTab", &"Back", &"SaveKeys", &"reset_keys", &"keyboard_label",
			&"action_up", &"action_left", &"action_down", &"action_right", &"action_bomb", &"pause_label",
			&"pause_value", &"touch_label", &"touch_text", &"goals_label"],
		"live": [&"Message", &"Key_up", &"Key_left", &"Key_down", &"Key_right", &"Key_bomb"]},
	&"power_ups": {"crop": Rect2(), "frame": STAGE_FRAME,
		"slots": {&"title": Rect2(440, 40, 400, 90), &"PowerUpsTab": Rect2(440, 40, 400, 90),
			&"ControlsTab": Rect2(773.4, 641.9, 237.6, 58), &"Back": Rect2(266.4, 641.9, 237.6, 58)},
		"plates": {}, "colors": {},
		"baked": [&"title", &"PowerUpsTab", &"ControlsTab", &"Back", &"guide"], "live": []},
	&"score": {"crop": Rect2(), "frame": STAGE_FRAME,
		"slots": {&"title": Rect2(396.8, 41.9, 494.1, 80.2),
			&"row_label_0": Rect2(414.1, 200.3, 254.1, 40.1), &"row_label_1": Rect2(414.1, 272, 254.1, 40.1),
			&"row_label_2": Rect2(414.1, 343.7, 254.1, 40.1), &"row_label_3": Rect2(414.1, 407, 254.1, 40.1),
			&"row_label_4": Rect2(414.1, 471, 254.1, 40.1),
			&"row_value_0": Rect2(796.9, 204.8, 146.8, 42.4), &"row_value_1": Rect2(796.9, 275.2, 146.8, 42.4),
			&"row_value_2": Rect2(796.9, 345.5, 146.8, 42.4), &"row_value_3": Rect2(796.9, 408.7, 146.8, 42.4),
			&"row_value_4": Rect2(796.9, 472, 146.8, 42.4),
			&"Continue": Rect2(793, 566.5, 237.5, 58), &"DressUp": Rect2(523, 566.5, 237.6, 58)},
		"plates": {&"title": Rect2(366, 46, 556, 74), &"row_label_0": Rect2(412, 202, 258, 37),
			&"row_label_2": Rect2(412, 345, 258, 37),
			&"row_value_0": Rect2(798, 207, 146, 36), &"row_value_1": Rect2(798, 277, 146, 36),
			&"row_value_2": Rect2(798, 347, 146, 36), &"row_value_3": Rect2(798, 411, 146, 36),
			&"row_value_4": Rect2(798, 474, 146, 36)},
		"colors": {&"title": Color("2edfff"), &"row_label_0": Color("e7fff8"), &"row_label_2": Color("e7fff8"),
			&"row_value_0": Color("ffffcd"), &"row_value_1": Color("ffffcd"), &"row_value_2": Color("ffffcd"),
			&"row_value_3": Color("ffffcd"), &"row_value_4": Color("ffffcd")},
		"baked": [&"row_label_1", &"row_label_3", &"row_label_4", &"Continue", &"DressUp"],
		"live": [&"title", &"row_label_0", &"row_label_2", &"row_value_0", &"row_value_1", &"row_value_2",
			&"row_value_3", &"row_value_4"]},
	&"dress_up": {"crop": Rect2(), "frame": Rect2(), "slots": {}, "plates": {}, "colors": {}, "baked": [], "live": []},
	&"game_over": {"crop": Rect2(), "frame": STAGE_FRAME,
		"slots": {&"title": Rect2(440, 50, 400, 100), &"retry_hint": Rect2(380, 362, 520, 40),
			&"total_label": Rect2(420, 495, 190, 90), &"total_value": Rect2(678.8, 527.6, 146.8, 38.1),
			&"end_unlock": Rect2(380, 410, 520, 30), &"TryAgain": Rect2(779.2, 601.8, 237.6, 58)},
		"plates": {&"total_value": Rect2(680, 530, 145, 32)}, "colors": {&"total_value": Color("f3ffe6")},
		"baked": [&"title", &"retry_hint", &"total_label", &"TryAgain"], "live": [&"total_value", &"end_unlock"]},
	&"game_win": {"crop": Rect2(), "frame": STAGE_FRAME,
		"slots": {&"title": Rect2(420, 50, 440, 100), &"total_label": Rect2(360, 490, 200, 95),
			&"total_value": Rect2(792.8, 528.4, 146.8, 38.1), &"end_unlock": Rect2(300, 455, 680, 30),
			&"TryAgain": Rect2(772.8, 594.1, 237.6, 58)},
		"plates": {&"total_value": Rect2(794, 531, 145, 32)}, "colors": {&"total_value": Color("ffffcd")},
		"baked": [&"title", &"total_label", &"TryAgain"], "live": [&"total_value", &"end_unlock"]},
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


## The plate's colour, sampled from the sheet beside the art it hides.
static func plate_color(page: StringName, name: StringName, fallback: Color) -> Color:
	return table(page).get("colors", {}).get(name, fallback)


## Whether the sheet already paints this widget's text and frame.
static func is_baked(page: StringName, name: StringName) -> bool:
	return name in table(page).get("baked", [])


## Whether this widget replaces painted art and must sit on a plate.
static func is_live(page: StringName, name: StringName) -> bool:
	return name in table(page).get("live", [])

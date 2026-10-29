extends Control
## Main scene: the edition 5 screen flow (`UIManager`) around the round host.
## Main menu → Game Settings → character select → levels → score screen → game win/over.
## `--practice` after `--` opens the development practice board directly.

const Game = preload("res://scripts/game.gd")
const Session = preload("res://scripts/session.gd")
const StageSets = preload("res://scripts/simulation/stage_sets.gd")
const Modes = preload("res://scripts/simulation/modes/modes.gd")
const UiKit = preload("res://scripts/ui_kit.gd")
const VisualSkin = preload("res://scripts/art/skin.gd")
const GameView = preload("res://scripts/game_view.gd")
const SaveStore = preload("res://scripts/save_store.gd")
const ArtCatalog = preload("res://scripts/art/catalog.gd")
const ScreenLayout = preload("res://scripts/art/screen_layout.gd")
const Looks = preload("res://scripts/looks.gd")
const Fidelity = preload("res://scripts/fidelity.gd")
const Audio = preload("res://scripts/original_audio.gd")
## Power-up guide (`PowerUpsUI`): original names; only pickups this build implements.
## The glove slots (BOXING GLOVE, PUSH THE BOMB) appear only where rounds drop them (#85).
const GUIDE := [
	["POWER-UPS", [[&"capacity", "BOMB +1", "Place one more bomb at a time."],
		[&"power", "POWER BLAST +1", "Your blasts reach one cell farther."],
		[&"speed", "SPEED +10%", "Move faster."],
		[&"life", "LIFE +1", "One more heart for this run."],
		[&"shield", "SHIELD", "Absorbs one hit."],
		[&"invincible", "INVINCIBILITY", "Brief immunity; touching rivals defeats them."]]],
	["WEAPONS", [[&"hammer", "HAMMER", "Smash the cell in front. Two uses."],
		[&"flamer", "FLAMETHROWER", "A short burst of fire ahead. Two uses."],
		[&"laser", "LIGHTNING GUN", "A beam along the whole lane. Two uses."],
		[&"triple", "MACHINE GUN", "Three quick shots ahead. Two uses."],
		[&"shotgun", "FIREBALL LAUNCHER", "A fireball that flies ahead. Two uses."],
		[&"landmine", "LANDMINE", "A hidden mine; arms when you step off. One use."]]],
	["VEHICLES", [[&"car", "SPORT CAR", "Drive fast; a hit costs the car, not you."],
		[&"moto", "SKATEBOARD", "Ride faster; a hit costs the board, not you."]]],
]
const GLOVES := {"POWER-UPS": [&"kick", "PUSH THE BOMB", "Walk into a bomb to kick it along the lane."],
	"WEAPONS": [&"boxing", "BOXING GLOVE", "Punch up to two cells ahead. Two uses."]}


static func guide() -> Array:
	if not Fidelity.original: return GUIDE
	var columns: Array = GUIDE.duplicate(true)
	for column in columns:
		if GLOVES.has(column[0]): column[1].append(GLOVES[column[0]])
	return columns


## Edition 5 Game Settings modes in source order; unported modes show disabled.
const MODE_ORDER: Array[StringName] = [&"arcade", &"kill", &"pac_man", &"green_zone"]
const MODE_TITLES := {&"arcade": "ARCADE", &"kill": "BATTLE ROYALE", &"pac_man": "PAC-MAN", &"green_zone": "GREEN ZONE"}
const DIFFICULTIES: Array[StringName] = [&"easy", &"normal", &"hard"]
static var playable_difficulties: Array[StringName] = [&"easy", &"normal", &"hard"]

var session: RefCounted = Session.new()
var screen: Control
var game: Node2D
var skin: RefCounted
var current := &""
var save_path := SaveStore.DEFAULT_PATH
var store: RefCounted
var audio: Node
var _rebinding: StringName = &""
var _last_snapshot: Dictionary = {}
var _new_looks: Array[int] = []
var _message: Label
## Art layout control (#76): -1 native, 0 follow the pack, 1 art hotspots (checks).
var screen_layout_override := 0
var _layout: StringName = &""
var _art := false
var _page_fill := Color("214c60")


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	skin = VisualSkin.new()
	store = SaveStore.new(save_path)
	audio = Audio.new()
	audio.name = "Audio"
	audio.sound_on = store.sound_on
	audio.music_on = store.music_on
	audio.persist = func(sound: bool, music: bool):
		# Only the switches change; keys and unlocks are saved as they stand on disk.
		var saved := SaveStore.new(save_path)
		saved.sound_on = sound
		saved.music_on = music
		saved.save_file()
		store.sound_on = sound
		store.music_on = music
	add_child(audio)
	if "--practice" in OS.get_cmdline_user_args():
		_open_practice()
	else:
		show_main_menu()


func _draw() -> void:
	if is_instance_valid(game): return
	draw_rect(Rect2(Vector2.ZERO, size), Color("102c3b"))
	for index in 9:
		var at := Vector2(80 + index * 150, 650 - (index % 3) * 18)
		draw_circle(at, 20, Color("1b4052"))
		draw_line(at + Vector2(8, -16), at + Vector2(14, -28), Color("3b6f7d"), 3)


func show_main_menu() -> void:
	_end_game()
	var page := _page(&"menu")
	_plate(&"dropdown", Color("2b7fbf"))
	_label(page, &"title", "BOMB IT 5", Rect2(0, 120, 1280, 0), 76, UiKit.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	_label(page, &"local_arcade", "LOCAL ARCADE", Rect2(0, 215, 1280, 0), 22, Color("9acbd3"), HORIZONTAL_ALIGNMENT_CENTER)
	_plate(&"more_games")
	var start := _button(page, &"Start", "START", Rect2(490, 330, 300, 62), show_settings, 26)
	_button(page, &"HowToPlay", "HOW TO PLAY", Rect2(490, 410, 300, 62), show_how_to_play, 26)
	# `UI_MainMenu`'s sound and music switches; the music switch also stops or starts the menu music.
	var sound := UiKit.switch(page, &"SoundSwitch", "SOUND", _rect(&"sound", Rect2(1110, 24, 150, 40)), audio.sound_on,
		func(on: bool): audio.set_sound(on))
	var music := UiKit.switch(page, &"MusicSwitch", "MUSIC", _rect(&"music", Rect2(1110, 72, 150, 40)), audio.music_on,
		func(on: bool): audio.set_music(on))
	_gate(sound, &"sound")
	_gate(music, &"music")
	# `UIManager` starts the menu music on the first menu, and again on returning to it
	# (`mainMenu` drops the round's music first).
	audio.null_game_music()
	audio.create_ui_music()
	start.grab_focus.call_deferred()


func show_how_to_play(page_name: StringName = &"controls") -> void:
	if page_name == &"controls": store.load_file()
	_show_guide(page_name)


func _show_guide(page_name: StringName) -> void:
	_rebinding = &""
	# The power-ups sheet has no source yet; without it the page keeps the native layout.
	var page := _page(&"power_ups" if page_name == &"power_ups" else &"how_to_play")
	_label(page, &"title", "HOW TO PLAY", Rect2(0, 30, 1280, 0), 42, UiKit.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	var tabs := UiKit.choices(page, Vector2(410, 95), [["CONTROLS", &"controls", true], ["POWER-UPS", &"power_ups", true]],
		page_name, func(value): _show_guide(value), 220, [&"ControlsTab", &"PowerUpsTab"], _placer)
	for widget in tabs: _gate(widget, widget.name)
	if page_name == &"controls": _controls_page(page)
	else: _power_ups_page(page)
	_button(page, &"Back", "BACK", Rect2(130, 630, 220, 60), _leave_guide, 24).grab_focus.call_deferred()


func _controls_page(page: Control) -> void:
	if not _art:
		UiKit.panel(page, Rect2(130, 165, 500, 445), Color("1d4557"), Color("5d96a3"))
		UiKit.panel(page, Rect2(660, 165, 470, 285), Color("1d4557"), Color("5d96a3"))
	_label(page, &"keyboard_label", "KEYBOARD", Rect2(160, 180, 0, 0), 24, Color("ffc79a"))
	var titles := {&"up": "UP", &"left": "LEFT", &"down": "DOWN", &"right": "RIGHT", &"bomb": "BOMB / ITEM"}
	for index in SaveStore.ACTIONS.size():
		var action: StringName = SaveStore.ACTIONS[index]
		_plate(&"keys_%d" % index)
		_label(page, &"action_" + action, titles[action], Rect2(160, 233 + index * 56, 0, 0), 21)
		_button(page, StringName("Key_" + str(action)), SaveStore.key_name(store.keys[action]), Rect2(400, 225 + index * 56, 200, 46),
			func(): _begin_rebind(action), 20)
	_plate(&"keys_extra_a")
	_plate(&"keys_extra_b")
	_plate(&"pause_label")
	_plate(&"pause_value")
	_label(page, &"pause_label", "PAUSE", Rect2(160, 513, 0, 0), 21, UiKit.FONT_COLOR, HORIZONTAL_ALIGNMENT_LEFT, true)
	_label(page, &"pause_value", "P", Rect2(400, 513, 200, 0), 21, UiKit.ACCENT, HORIZONTAL_ALIGNMENT_CENTER, true)
	_plate(&"message")
	_message = _label(page, &"Message", "Click a control button to change it.", Rect2(160, 560, 440, 0), 18,
		Color("b4d2d7"), HORIZONTAL_ALIGNMENT_LEFT, true)
	_button(page, &"reset_keys", "RESET", Rect2(660, 470, 220, 56), _reset_keys, 22)
	_button(page, &"SaveKeys", "SAVE", Rect2(910, 470, 220, 56), _save_keys, 22)
	_label(page, &"touch_label", "TOUCH", Rect2(690, 180, 0, 0), 24, Color("ffc79a"))
	_label(page, &"touch_text", "Drag the stick on the left to move in eight directions. Tap the button on the right to place a bomb or use your item.",
		Rect2(690, 225, 410, 0), 19)
	var goals := ""
	for mode in Modes.available(): goals += "%s: %s\n" % [MODE_TITLES[mode], Modes.GOALS[mode]]
	_label(page, &"goals_label", goals.strip_edges(), Rect2(690, 345, 410, 0), 18, Color("b4d2d7"))


func _power_ups_page(page: Control) -> void:
	var columns := guide()
	for column in columns.size():
		var x := 130 + column * 345
		UiKit.panel(page, Rect2(x, 165, 330, 455), Color("1d4557"), Color("5d96a3"))
		UiKit.label(page, columns[column][0], Vector2(x + 20, 180), 24, Color("ffc79a"))
		var entries: Array = columns[column][1]
		for row in entries.size():
			var entry: Array = entries[row]
			var y := 222 + row * (65 if entries.size() < 7 else 56)
			var icon := ItemIcon.new()
			icon.kind = entry[0]
			icon.skin = skin
			icon.position = Vector2(x + 16, y)
			icon.size = Vector2(44, 44)
			page.add_child(icon)
			UiKit.label(page, entry[1], Vector2(x + 70, y - 4), 17, UiKit.ACCENT)
			var detail := UiKit.label(page, entry[2], Vector2(x + 70, y + 18), 13, UiKit.FONT_COLOR, 250)
			detail.add_theme_constant_override("line_spacing", -3)


func _begin_rebind(action: StringName) -> void:
	_rebinding = action
	_message.text = "Select a key with your keyboard"


func _input(event: InputEvent) -> void:
	if _rebinding == &"" or not (event is InputEventKey) or not event.pressed or event.echo: return
	get_viewport().set_input_as_handled()
	var keycode: int = event.keycode
	if store.can_bind(_rebinding, keycode):
		store.keys[_rebinding] = keycode
		var button: Button = screen.find_child("Key_" + _rebinding, true, false)
		button.text = SaveStore.key_name(keycode)
		_message.text = "Click a control button to change it."
	else:
		_message.text = "This key is not possible. Please choose a different key."
	_rebinding = &""


func _reset_keys() -> void:
	store.keys = SaveStore.DEFAULT_KEYS.duplicate()
	_show_guide(&"controls")


func _save_keys() -> void:
	_message.text = "Custom controls saved." if store.save_file() else "Controls could not be saved."


## Leaving without SAVE discards key changes, as `HowToPlayUI.backHandle` does.
func _leave_guide() -> void:
	store.load_file()
	show_main_menu()


func show_settings() -> void:
	var page := _page(&"settings")
	_label(page, &"Title", "GAME SETTINGS", Rect2(0, 40, 1280, 0), 42, UiKit.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	_plate(&"players_row")
	var modes := Modes.available()
	for index in MODE_ORDER.size():
		var mode: StringName = MODE_ORDER[index]
		var card := _button(page, StringName("Mode_" + mode), MODE_TITLES[mode], Rect2(130 + index * 260, 110, 240, 120),
			func(): _set_mode(mode), 22)
		card.toggle_mode = true
		card.button_pressed = session.mode == mode
		card.disabled = mode not in modes
		if not (_art and ScreenLayout.is_baked(_layout, card.name)):
			var chosen := StyleBoxFlat.new()
			chosen.bg_color = Color("c8743f")
			chosen.border_color = UiKit.ACCENT
			chosen.set_border_width_all(3)
			chosen.set_corner_radius_all(12)
			card.add_theme_stylebox_override("pressed", chosen)
		card.tooltip_text = Modes.GOALS.get(mode, "Not available yet")
	_plate(&"goals")
	_label(page, &"Goals", Modes.GOALS.get(session.mode, ""), Rect2(0, 245, 1280, 0), 19, Color("b4d2d7"),
		HORIZONTAL_ALIGNMENT_CENTER, true)
	var rows := [["ENEMIES", 300, &"LabelEnemies"], ["LEVELS", 370, &"LabelLevels"], ["ARENA", 440, &"LabelArena"],
		["DIFFICULTY", 510, &"LabelDifficulty"]]
	for row in rows:
		_label(page, row[2], row[0], Rect2(180, row[1] + 8, 0, 0), 22, Color("ffc79a"))
	var enemies := UiKit.choices(page, Vector2(400, 300), [["3", 3, true], ["2", 2, true], ["1", 1, true]], session.enemies,
		func(value): session.enemies = value, 116, [&"Enemies3", &"Enemies2", &"Enemies1"], _placer)
	for widget in enemies: _gate(widget, widget.name)
	var level_options: Array = []
	var level_names: Array = []
	for count in Session.LEVEL_CHOICES:
		level_options.append([str(count), Fidelity.levels_for_button(count), true])
		level_names.append(&"Levels%d" % count)
	var levels := UiKit.choices(page, Vector2(400, 370), level_options, session.levels, func(value): session.levels = value,
		116, level_names, _placer)
	for widget in levels: _gate(widget, widget.name)
	var arena := OptionButton.new()
	arena.name = "Arena"
	var arena_rect := _rect(&"Arena", Rect2(400, 440, 500, 44))
	arena.position = arena_rect.position
	arena.size = arena_rect.size
	arena.add_theme_font_size_override("font_size", 19)
	arena.add_item("RANDOM")
	arena.set_item_metadata(0, &"random")
	for set_id in StageSets.available_sets():
		arena.add_item(StageSets.title(set_id))
		arena.set_item_metadata(arena.item_count - 1, set_id)
	for index in arena.item_count:
		if arena.get_item_metadata(index) == session.stage: arena.select(index)
	arena.item_selected.connect(func(index: int): session.stage = arena.get_item_metadata(index))
	page.add_child(arena)
	_gate(arena, &"Arena")
	var difficulty_options: Array = []
	for difficulty in DIFFICULTIES:
		difficulty_options.append([str(difficulty).to_upper(), difficulty, difficulty in playable_difficulties])
	if session.difficulty not in playable_difficulties: session.difficulty = &"normal"
	var difficulties := UiKit.choices(page, Vector2(400, 510), difficulty_options, session.difficulty,
		func(value): session.difficulty = value, 160, [&"Difficulty_easy", &"Difficulty_normal", &"Difficulty_hard"], _placer)
	for widget in difficulties: _gate(widget, widget.name)
	_button(page, &"Back", "BACK", Rect2(130, 610, 220, 60), show_main_menu, 24)
	_button(page, &"Next", "NEXT", Rect2(930, 610, 220, 60), show_character_select, 24).grab_focus.call_deferred()


func _set_mode(mode: StringName) -> void:
	session.mode = mode
	show_settings()


func show_character_select() -> void:
	var page := _page(&"character")
	UiKit.label(page, "CHOOSE YOUR ROBOT", Vector2(0, 40), 42, UiKit.ACCENT, 1280, HORIZONTAL_ALIGNMENT_CENTER)
	for index in Session.ROBOTS.size():
		var badge := RobotBadge.new()
		badge.robot = index
		badge.skin = skin
		badge.position = Vector2(150 + index * 125, 120)
		badge.size = Vector2(110, 110)
		badge.selected = index == session.robot
		badge.name = "Robot%d" % index
		badge.chosen.connect(func(robot: int):
			if robot != session.robot:
				session.robot = robot
				session.hat = 0
				session.body = 0
			show_character_select())
		page.add_child(badge)
		UiKit.label(page, Session.ROBOT_TITLES[index].to_upper(), badge.position + Vector2(0, 116), 17,
			GameView.ROBOT_COLORS[index], 110, HORIZONTAL_ALIGNMENT_CENTER)
	var preview := RobotBadge.new()
	preview.robot = session.robot
	preview.skin = skin
	preview.position = Vector2(260, 290)
	preview.size = Vector2(220, 220)
	preview.selected = true
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(preview)
	preview.hat = session.hat
	preview.body = session.body
	_looks_panel(page, Vector2(540, 290), show_character_select)
	UiKit.button(page, "BACK", Rect2(130, 610, 220, 60), show_settings, skin, 24)
	var start := UiKit.button(page, "START", Rect2(930, 610, 220, 60), start_session, skin, 24)
	start.name = "StartGame"
	start.grab_focus.call_deferred()


## Eight look slots of the chosen robot (`ClothesPanel`): one hat and one outfit at a time,
## clicking the worn one removes it; locked looks show their unlock score.
func _looks_panel(page: Control, at: Vector2, refresh: Callable) -> void:
	UiKit.panel(page, Rect2(at, Vector2(560, 250)), Color("1d4557"), Color("5d96a3"))
	UiKit.label(page, "LOOKS", at + Vector2(24, 14), 22, Color("ffc79a"))
	var unlocked: Array = store.unlocks.get(str(session.robot), [])
	for number in range(1, 9):
		var entry: Array = Looks.look(session.robot, number)
		var worn: bool = (session.hat if entry[0] == &"hat" else session.body) == entry[1]
		var cell := at + Vector2(24 + ((number - 1) % 4) * 132, 56 + ((number - 1) / 4) * 94)
		var widget := UiKit.button(page, Looks.title(session.robot, number), Rect2(cell, Vector2(120, 50)),
			func(): _wear(entry, refresh), null, 15)
		widget.name = "Look%d" % number
		widget.disabled = number not in unlocked
		if worn:
			var chosen := StyleBoxFlat.new()
			chosen.bg_color = Color("c8743f")
			chosen.border_color = UiKit.ACCENT
			chosen.set_border_width_all(2)
			chosen.set_corner_radius_all(10)
			for state_name in ["normal", "hover"]: widget.add_theme_stylebox_override(state_name, chosen)
		if widget.disabled:
			UiKit.label(page, "%d PTS" % Looks.THRESHOLDS[number - 1], cell + Vector2(0, 52), 13, Color("8fb1ba"), 120, HORIZONTAL_ALIGNMENT_CENTER)
	if unlocked.is_empty():
		UiKit.label(page, "Score points to unlock outfits.", at + Vector2(170, 18), 16, Color("b4d2d7"), 360)


func _wear(entry: Array, refresh: Callable) -> void:
	if entry[0] == &"hat": session.hat = 0 if session.hat == entry[1] else entry[1]
	else: session.body = 0 if session.body == entry[1] else entry[1]
	refresh.call()


func start_session() -> void:
	session.begin()
	_start_level()


func _start_level() -> void:
	_clear_screen()
	# `gameStart` stops the menu music before the board loads.
	audio.null_ui_music()
	if not is_instance_valid(game):
		game = Game.new()
		game.session = session
		game.auto_start = false
		game.visual_skin = skin
		game.bindings = store.keys.duplicate()
		game.level_settled.connect(_on_level_settled)
		game.main_menu_requested.connect(show_main_menu)
		add_child(game)
	game.play_level()
	current = &"playing"
	queue_redraw()


func _on_level_settled(snapshot: Dictionary) -> void:
	var outcome: StringName = snapshot.outcome
	var won: bool = outcome == &"won" or (outcome == &"timeout" and session.mode == &"arcade" and Fidelity.timeout_wins())
	var result: int = session.settle(&"won" if won else &"lost", snapshot.result_score,
		snapshot.actors[&"human"].lives)
	# Every score screen checks the session total against the unlock scores (`OnePScoreUI`).
	var key := str(session.robot)
	_new_looks = Looks.newly_unlocked(session.robot, session.total_score, store.unlocks.get(key, []))
	if not _new_looks.is_empty():
		var unlocked: Array = store.unlocks.get(key, []).duplicate()
		unlocked.append_array(_new_looks)
		unlocked.sort()
		store.unlocks[key] = unlocked
		store.save_file()
	_last_snapshot = snapshot
	if result == Session.Result.GAME_OVER:
		show_end(false)
	else:
		show_score(snapshot)


func show_score(snapshot: Dictionary) -> void:
	var page := _page(&"score", false)
	var won: bool = session.last_result in [Session.Result.LEVEL_WIN, Session.Result.GAME_WIN]
	page.add_child(_shade())
	UiKit.panel(page, Rect2(290, 100, 700, 520))
	var title := "LEVEL %s COMPLETE!" % session.level_text() if won else "LEVEL %s FAILED…" % session.level_text()
	UiKit.label(page, title, Vector2(290, 130), 38, UiKit.ACCENT, 700, HORIZONTAL_ALIGNMENT_CENTER)
	var parts: Dictionary = snapshot.get("result_breakdown", {})
	var rows := [["ENEMIES KILLED", parts.get("kills", 0)], ["TIME BONUS", parts.get("time", 0)],
		["%s BONUS" % str(session.difficulty).to_upper(), parts.get("difficulty", 0)],
		["LEVEL SCORE", snapshot.result_score], ["TOTAL SCORE", session.total_score]]
	for index in rows.size():
		var y := 210 + index * 56
		UiKit.label(page, rows[index][0], Vector2(360, y), 24, Color("ffc79a") if index >= 3 else UiKit.FONT_COLOR)
		UiKit.label(page, str(rows[index][1]), Vector2(720, y), 24, UiKit.ACCENT, 200, HORIZONTAL_ALIGNMENT_RIGHT)
	var proceed := UiKit.button(page, "NEXT" if won else "TRY AGAIN", Rect2(660, 520, 260, 64), _continue, skin, 24)
	proceed.name = "Continue"
	var dress := UiKit.button(page, "DRESS UP", Rect2(360, 520, 260, 64), show_dress_up, skin, 24)
	dress.name = "DressUp"
	proceed.grab_focus.call_deferred()
	if not _new_looks.is_empty(): _unlock_tip(page)


func _unlock_tip(page: Control) -> void:
	var tip := Control.new()
	tip.name = "UnlockTip"
	tip.size = Vector2(1280, 720)
	page.add_child(tip)
	tip.add_child(_shade())
	UiKit.panel(tip, Rect2(390, 200, 500, 300))
	UiKit.label(tip, "New outfit unlocked!", Vector2(390, 230), 32, UiKit.ACCENT, 500, HORIZONTAL_ALIGNMENT_CENTER)
	var names := PackedStringArray()
	for number in _new_looks: names.append(Looks.title(session.robot, number))
	UiKit.label(tip, ", ".join(names), Vector2(420, 300), 22, UiKit.FONT_COLOR, 440, HORIZONTAL_ALIGNMENT_CENTER)
	var ok := UiKit.button(tip, "OK", Rect2(540, 410, 200, 60), func():
		_new_looks.clear()
		tip.queue_free(), skin, 24)
	ok.name = "TipOk"
	ok.grab_focus.call_deferred()


## DRESS UP from the score screen: change looks between levels.
func show_dress_up() -> void:
	var page := _page(&"dress_up", false)
	page.add_child(_shade())
	UiKit.label(page, "DRESS UP", Vector2(0, 90), 42, UiKit.ACCENT, 1280, HORIZONTAL_ALIGNMENT_CENTER)
	var preview := RobotBadge.new()
	preview.robot = session.robot
	preview.hat = session.hat
	preview.body = session.body
	preview.skin = skin
	preview.position = Vector2(240, 230)
	preview.size = Vector2(220, 220)
	preview.selected = true
	page.add_child(preview)
	_looks_panel(page, Vector2(500, 215), show_dress_up)
	var done := UiKit.button(page, "OK", Rect2(540, 560, 200, 60), func(): show_score(_last_snapshot), skin, 24)
	done.name = "DressDone"
	done.grab_focus.call_deferred()


func _continue() -> void:
	if session.last_result == Session.Result.GAME_WIN:
		show_end(true)
		return
	session.advance()
	_start_level()


func show_end(won: bool) -> void:
	_end_game()
	# `OnePGameOverUI`: menu music, after the win or lose jingle if it is still playing.
	audio.create_over_ui_music()
	var page := _page(&"game_win" if won else &"game_over")
	UiKit.panel(page, Rect2(290, 130, 700, 440))
	UiKit.label(page, "GAME COMPLETE!" if won else "GAME OVER", Vector2(290, 170), 52, UiKit.ACCENT, 700, HORIZONTAL_ALIGNMENT_CENTER)
	if not won:
		UiKit.label(page, "Don't give up! Give it another bomb…", Vector2(290, 260), 22, Color("b4d2d7"), 700, HORIZONTAL_ALIGNMENT_CENTER)
	if not _new_looks.is_empty():
		var names := PackedStringArray()
		for number in _new_looks: names.append(Looks.title(session.robot, number))
		UiKit.label(page, "New outfit unlocked! " + ", ".join(names), Vector2(290, 400), 20, UiKit.ACCENT, 700,
			HORIZONTAL_ALIGNMENT_CENTER).name = "EndUnlock"
		_new_looks.clear()
	UiKit.label(page, "TOTAL SCORE", Vector2(400, 340), 28, Color("ffc79a"))
	UiKit.label(page, str(session.total_score), Vector2(680, 340), 28, UiKit.ACCENT, 200, HORIZONTAL_ALIGNMENT_RIGHT)
	var again := UiKit.button(page, "TRY AGAIN", Rect2(510, 460, 260, 64), show_settings, skin, 24)
	again.name = "TryAgain"
	again.grab_focus.call_deferred()


func _unhandled_key_input(event: InputEvent) -> void:
	# Original score screens also continue on Space.
	if current == &"score" and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		get_viewport().set_input_as_handled()
		_continue()


func _open_practice() -> void:
	_clear_screen()
	game = Game.new()
	game.visual_skin = skin
	add_child(game)
	current = &"practice"


func _end_game() -> void:
	if is_instance_valid(game):
		game.queue_free()
		remove_child(game)
	game = null
	queue_redraw()


func _page(id: StringName, solid := true) -> Control:
	_clear_screen()
	if solid: _end_game()
	current = id
	_layout = id
	# Art layout control: -1 forces the native fallback, 0 uses the pack when it has a sheet.
	var sheet: bool = skin != null and skin.has_screen("screen." + id)
	_art = sheet and screen_layout_override >= 0
	screen = Control.new()
	screen.name = "Screen_" + id
	screen.size = Vector2(1280, 720)
	screen.position = (get_viewport_rect().size - Vector2(1280, 720)) * 0.5
	add_child(screen)
	if _art:
		var crop := ScreenLayout.crop_from_id(String(id))
		var fill := ColorRect.new()
		fill.name = "ScreenFill"
		fill.color = skin.screen_fill("screen." + id, crop)
		fill.size = screen.size
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		screen.add_child(fill)
		var plate := TextureRect.new()
		plate.name = "ScreenArt"
		plate.texture = skin.screen_plate("screen." + id, crop)
		var frame: Rect2 = ScreenLayout.frame(id)
		if frame.size.x > 0 and frame.size.y > 0:
			plate.position = frame.position
			plate.size = frame.size
		else:
			plate.position = skin.screen_frame("screen." + id, crop).position
			plate.size = skin.screen_frame("screen." + id, crop).size
		plate.stretch_mode = TextureRect.STRETCH_SCALE
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		screen.add_child(plate)
	else:
		# Optional workbench art behind the page (`screen.<page>`); native drawing otherwise.
		var texture: Texture2D = skin.texture("screen." + id) if skin != null else null
		if texture != null:
			var backdrop := TextureRect.new()
			backdrop.name = "ScreenArt"
			backdrop.texture = texture
			backdrop.size = screen.size
			backdrop.stretch_mode = TextureRect.STRETCH_SCALE
			backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
			screen.add_child(backdrop)
	return screen


## Where a widget goes: its painted hotspot on an art page, else the native rectangle.
func _rect(name: StringName, native_rect: Rect2) -> Rect2:
	return ScreenLayout.slot(_layout, name, native_rect, _art)


## Callable for `UiKit.choices`, so each option can sit on its painted hotspot.
func _placer(name: StringName, native_rect: Rect2) -> Rect2:
	return _rect(name, native_rect)


## Hide art a live widget replaces, so the widget's own pixels stay readable.
func _plate(name: StringName, colour := Color("214c60")) -> ColorRect:
	if not _art: return null
	var rect: Rect2 = ScreenLayout.plate(_layout, name)
	if rect.size.x <= 0 or rect.size.y <= 0: return null
	return UiKit.plate(screen, rect, colour)


## A text label on its hotspot; ghosted when the sheet already paints that text.
func _label(page: Control, name: StringName, text: String, native_rect: Rect2, font_px := 20,
		colour := UiKit.FONT_COLOR, align := HORIZONTAL_ALIGNMENT_LEFT, carrier := false) -> Label:
	var rect := _rect(name, native_rect)
	var width := rect.size.x if rect.size.x > 0 else -1.0
	var widget := UiKit.label(page, text, rect.position, font_px, colour, width, align, carrier)
	widget.name = name
	if _art and not carrier and ScreenLayout.is_baked(_layout, name): UiKit.ghost_label(widget)
	return widget


## A button on its hotspot; ghosted when the sheet already paints that button.
func _button(page: Control, name: StringName, text: String, native_rect: Rect2, action: Callable,
		font_px := 22) -> Button:
	var widget := UiKit.button(page, text, _rect(name, native_rect), action, skin, font_px)
	widget.name = name
	_gate(widget, name)
	return widget


## Transparent art-backed control: real text and hit test over painted pixels.
func _gate(widget: Control, name: StringName) -> void:
	if not _art or not ScreenLayout.is_baked(_layout, name): return
	if widget is OptionButton: UiKit.ghost_option(widget)
	else: UiKit.ghost(widget)


func _clear_screen() -> void:
	if is_instance_valid(screen):
		screen.queue_free()
		remove_child(screen)
	screen = null


func _shade() -> ColorRect:
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.10, 0.17, 0.72)
	shade.size = Vector2(1280, 720)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	return shade


## A selectable robot portrait: workbench portrait slot or the native robot drawing.
class RobotBadge extends Control:
	signal chosen(robot: int)
	var robot := 0
	var hat := 0
	var body := 0
	var skin: RefCounted
	var selected := false

	func _ready() -> void:
		focus_mode = Control.FOCUS_ALL
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func _gui_input(event: InputEvent) -> void:
		var pressed: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
		pressed = pressed or event.is_action_pressed("ui_accept")
		if pressed:
			chosen.emit(robot)
			accept_event()

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		var color: Color = GameView.ROBOT_COLORS[robot]
		var style := StyleBoxFlat.new()
		style.bg_color = Color("234e62")
		style.border_color = Color("ffd989") if selected or has_focus() else color.darkened(0.3)
		style.set_border_width_all(4 if selected else 2)
		style.set_corner_radius_all(16)
		draw_style_box(style, rect)
		if skin != null and skin.draw(self, "actor.%s.portrait" % GameView.ROBOT_SLOTS[robot], rect.grow(-size.x * 0.12)):
			return
		var center := size * 0.5
		var unit := size.x / 110.0
		draw_circle(center + Vector2(0, 8) * unit, 30 * unit, color.darkened(0.25))
		draw_circle(center - Vector2(0, 6) * unit, 32 * unit, color)
		draw_rect(Rect2(center + Vector2(-22, -18) * unit, Vector2(44, 20) * unit), Color("244357"))
		draw_circle(center + Vector2(-10, -8) * unit, 5 * unit, Color("e1fff3"))
		draw_circle(center + Vector2(10, -8) * unit, 5 * unit, Color("e1fff3"))
		draw_line(center - Vector2(0, 38) * unit, center - Vector2(0, 48) * unit, color, 3 * unit)
		if body > 0:
			var cloth: Color = GameView.LOOK_COLORS[(body + robot) % GameView.LOOK_COLORS.size()]
			draw_rect(Rect2(center + Vector2(-24, 14) * unit, Vector2(48, 14) * unit), cloth)
		if hat > 0:
			var felt: Color = GameView.LOOK_COLORS[(hat * 2 + robot) % GameView.LOOK_COLORS.size()]
			draw_colored_polygon(PackedVector2Array([center + Vector2(-28, -34) * unit, center + Vector2(28, -34) * unit,
				center + Vector2(0, -58) * unit]), felt)

	func _notification(what: int) -> void:
		if what in [NOTIFICATION_FOCUS_ENTER, NOTIFICATION_FOCUS_EXIT]: queue_redraw()


## A pickup icon: the workbench `item.<kind>` slot or the native badge.
class ItemIcon extends Control:
	var kind: StringName
	var skin: RefCounted

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		if skin != null and skin.draw(self, "item." + kind, rect): return
		draw_circle(size / 2, size.x / 2 - 2, Color("d1fff0"))
		draw_arc(size / 2, size.x / 2 - 2, 0, TAU, 28, Color("60b4a4"), 2, true)
		var text: String = GameView.ITEM_NAMES.get(kind, "?")
		draw_string(ThemeDB.fallback_font, size / 2 + Vector2(-text.length() * 4.5, 6), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("173c40"))

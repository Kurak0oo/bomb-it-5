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
## Power-up guide (`PowerUpsUI`): original names; only pickups this build implements.
## The unresolved glove slots (BOXING GLOVE, PUSH THE BOMB) are left out.
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
var _rebinding: StringName = &""
var _message: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	skin = VisualSkin.new()
	store = SaveStore.new(save_path)
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
	UiKit.label(page, "BOMB IT 5", Vector2(0, 120), 76, UiKit.ACCENT, 1280, HORIZONTAL_ALIGNMENT_CENTER)
	UiKit.label(page, "LOCAL ARCADE", Vector2(0, 215), 22, Color("9acbd3"), 1280, HORIZONTAL_ALIGNMENT_CENTER)
	var start := UiKit.button(page, "START", Rect2(490, 330, 300, 62), show_settings, skin, 26)
	var help := UiKit.button(page, "HOW TO PLAY", Rect2(490, 410, 300, 62), show_how_to_play, skin, 26)
	help.name = "HowToPlay"
	start.name = "Start"
	start.grab_focus.call_deferred()


func show_how_to_play(page_name: StringName = &"controls") -> void:
	if page_name == &"controls": store.load_file()
	_show_guide(page_name)


func _show_guide(page_name: StringName) -> void:
	_rebinding = &""
	var page := _page(&"how_to_play")
	UiKit.label(page, "HOW TO PLAY", Vector2(0, 30), 42, UiKit.ACCENT, 1280, HORIZONTAL_ALIGNMENT_CENTER)
	var tabs := UiKit.choices(page, Vector2(410, 95), [["CONTROLS", &"controls", true], ["POWER-UPS", &"power_ups", true]],
		page_name, func(value): _show_guide(value), 220)
	tabs[0].name = "ControlsTab"
	tabs[1].name = "PowerUpsTab"
	if page_name == &"controls": _controls_page(page)
	else: _power_ups_page(page)
	var back := UiKit.button(page, "BACK", Rect2(130, 630, 220, 60), _leave_guide, skin, 24)
	back.name = "Back"
	back.grab_focus.call_deferred()


func _controls_page(page: Control) -> void:
	UiKit.panel(page, Rect2(130, 165, 500, 445), Color("1d4557"), Color("5d96a3"))
	UiKit.label(page, "KEYBOARD", Vector2(160, 180), 24, Color("ffc79a"))
	var titles := {&"up": "UP", &"left": "LEFT", &"down": "DOWN", &"right": "RIGHT", &"bomb": "BOMB / ITEM"}
	for index in SaveStore.ACTIONS.size():
		var action: StringName = SaveStore.ACTIONS[index]
		UiKit.label(page, titles[action], Vector2(160, 233 + index * 56), 21)
		var key := UiKit.button(page, SaveStore.key_name(store.keys[action]), Rect2(400, 225 + index * 56, 200, 46),
			func(): _begin_rebind(action), null, 20)
		key.name = "Key_" + action
	UiKit.label(page, "PAUSE", Vector2(160, 513), 21)
	UiKit.label(page, "P", Vector2(400, 513), 21, UiKit.ACCENT, 200, HORIZONTAL_ALIGNMENT_CENTER)
	_message = UiKit.label(page, "Click a control button to change it.", Vector2(160, 560), 18, Color("b4d2d7"), 440)
	_message.name = "Message"
	UiKit.button(page, "RESET", Rect2(660, 470, 220, 56), _reset_keys, skin, 22).name = "ResetKeys"
	UiKit.button(page, "SAVE", Rect2(910, 470, 220, 56), _save_keys, skin, 22).name = "SaveKeys"
	UiKit.panel(page, Rect2(660, 165, 470, 285), Color("1d4557"), Color("5d96a3"))
	UiKit.label(page, "TOUCH", Vector2(690, 180), 24, Color("ffc79a"))
	UiKit.label(page, "Drag the stick on the left to move in eight directions. Tap the button on the right to place a bomb or use your item.",
		Vector2(690, 225), 19, UiKit.FONT_COLOR, 410)
	var goals := ""
	for mode in Modes.available(): goals += "%s: %s\n" % [MODE_TITLES[mode], Modes.GOALS[mode]]
	UiKit.label(page, goals.strip_edges(), Vector2(690, 345), 18, Color("b4d2d7"), 410)


func _power_ups_page(page: Control) -> void:
	for column in GUIDE.size():
		var x := 130 + column * 345
		UiKit.panel(page, Rect2(x, 165, 330, 455), Color("1d4557"), Color("5d96a3"))
		UiKit.label(page, GUIDE[column][0], Vector2(x + 20, 180), 24, Color("ffc79a"))
		var entries: Array = GUIDE[column][1]
		for row in entries.size():
			var entry: Array = entries[row]
			var y := 222 + row * 65
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
	UiKit.label(page, "GAME SETTINGS", Vector2(0, 40), 42, UiKit.ACCENT, 1280, HORIZONTAL_ALIGNMENT_CENTER)
	var modes := Modes.available()
	for index in MODE_ORDER.size():
		var mode: StringName = MODE_ORDER[index]
		var card := UiKit.button(page, MODE_TITLES[mode], Rect2(130 + index * 260, 110, 240, 120),
			func(): _set_mode(mode), skin, 22)
		card.name = "Mode_" + mode
		card.toggle_mode = true
		card.button_pressed = session.mode == mode
		card.disabled = mode not in modes
		var chosen := StyleBoxFlat.new()
		chosen.bg_color = Color("c8743f")
		chosen.border_color = UiKit.ACCENT
		chosen.set_border_width_all(3)
		chosen.set_corner_radius_all(12)
		card.add_theme_stylebox_override("pressed", chosen)
		card.tooltip_text = Modes.GOALS.get(mode, "Not available yet")
	UiKit.label(page, Modes.GOALS.get(session.mode, ""), Vector2(0, 245), 19, Color("b4d2d7"), 1280, HORIZONTAL_ALIGNMENT_CENTER)
	var rows := [["ENEMIES", 300], ["LEVELS", 370], ["ARENA", 440], ["DIFFICULTY", 510]]
	for row in rows:
		UiKit.label(page, row[0], Vector2(180, row[1] + 8), 22, Color("ffc79a"))
	UiKit.choices(page, Vector2(400, 300), [["3", 3, true], ["2", 2, true], ["1", 1, true]], session.enemies,
		func(value): session.enemies = value)
	var level_options: Array = []
	for count in Session.LEVEL_CHOICES: level_options.append([str(count), count, true])
	UiKit.choices(page, Vector2(400, 370), level_options, session.levels, func(value): session.levels = value)
	var arena := OptionButton.new()
	arena.name = "Arena"
	arena.position = Vector2(400, 440)
	arena.size = Vector2(500, 44)
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
	var difficulty_options: Array = []
	for difficulty in DIFFICULTIES:
		difficulty_options.append([str(difficulty).to_upper(), difficulty, difficulty in playable_difficulties])
	if session.difficulty not in playable_difficulties: session.difficulty = &"normal"
	UiKit.choices(page, Vector2(400, 510), difficulty_options, session.difficulty,
		func(value): session.difficulty = value, 160)
	UiKit.button(page, "BACK", Rect2(130, 610, 220, 60), show_main_menu, skin, 24)
	var next := UiKit.button(page, "NEXT", Rect2(930, 610, 220, 60), show_character_select, skin, 24)
	next.name = "Next"
	next.grab_focus.call_deferred()


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
			session.robot = robot
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
	UiKit.panel(page, Rect2(540, 290, 480, 220), Color("1d4557"), Color("5d96a3"))
	UiKit.label(page, "LOOKS", Vector2(570, 310), 22, Color("ffc79a"))
	UiKit.label(page, "Hats and outfits unlock with your total score.", Vector2(570, 350), 19, Color("b4d2d7"), 420)
	UiKit.button(page, "BACK", Rect2(130, 610, 220, 60), show_settings, skin, 24)
	var start := UiKit.button(page, "START", Rect2(930, 610, 220, 60), start_session, skin, 24)
	start.name = "StartGame"
	start.grab_focus.call_deferred()


func start_session() -> void:
	session.begin()
	_start_level()


func _start_level() -> void:
	_clear_screen()
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
	var result: int = session.settle(&"won" if outcome == &"won" else &"lost", snapshot.result_score,
		snapshot.actors[&"human"].lives)
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
	var dress := UiKit.button(page, "DRESS UP", Rect2(360, 520, 260, 64), func(): pass, skin, 24)
	dress.name = "DressUp"
	dress.disabled = true
	proceed.grab_focus.call_deferred()


func _continue() -> void:
	if session.last_result == Session.Result.GAME_WIN:
		show_end(true)
		return
	session.advance()
	_start_level()


func show_end(won: bool) -> void:
	_end_game()
	var page := _page(&"game_win" if won else &"game_over")
	UiKit.panel(page, Rect2(290, 130, 700, 440))
	UiKit.label(page, "GAME COMPLETE!" if won else "GAME OVER", Vector2(290, 170), 52, UiKit.ACCENT, 700, HORIZONTAL_ALIGNMENT_CENTER)
	if not won:
		UiKit.label(page, "Don't give up! Give it another bomb…", Vector2(290, 260), 22, Color("b4d2d7"), 700, HORIZONTAL_ALIGNMENT_CENTER)
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
	screen = Control.new()
	screen.name = "Screen_" + id
	screen.size = Vector2(1280, 720)
	screen.position = (get_viewport_rect().size - Vector2(1280, 720)) * 0.5
	add_child(screen)
	return screen


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

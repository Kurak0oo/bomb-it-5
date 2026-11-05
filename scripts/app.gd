extends Control
## Main scene: the edition 5 screen flow (`UIManager`) around the round host.
## Title (`UILoading`) → main menu → Game Settings → character select → levels → score
## screen → game win/over. Every screen is a generated original screen
## (scripts/ui/swf_screen.gd). `--practice` after `--` opens the development practice board
## directly; `--screen NAME` one generated screen (`--screen score --capture loss-score`: the
## score screen with a recorded capture's points; `--screen game_over` / `game_win`: the end
## screens with their recorded final score).

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
const Fidelity = preload("res://scripts/fidelity.gd")
const Audio = preload("res://scripts/original_audio.gd")
const Quality = preload("res://scripts/quality.gd")
const SwfScreen = preload("res://scripts/ui/swf_screen.gd")
const GameSettingsUI = preload("res://scripts/ui/game_settings_ui.gd")
const CharacterSelectUI = preload("res://scripts/ui/character_select_ui.gd")
const HowToPlayUI = preload("res://scripts/ui/how_to_play_ui.gd")
const PowerUpsUI = preload("res://scripts/ui/power_ups_ui.gd")
const OnePScoreUI = preload("res://scripts/ui/one_p_score_ui.gd")
const OnePGameOverUI = preload("res://scripts/ui/one_p_game_over_ui.gd")
const AvmRandom = preload("res://scripts/simulation/avm_random.gd")
const GameInterFace = preload("res://scripts/ui/game_inter_face.gd")
const GameBoard = preload("res://scripts/ui/game_board.gd")
const GameActors = preload("res://scripts/ui/game_actors.gd")
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
## The Flash `Math.random` the ported screens draw from (FallSnow). Flash seeds it from the
## clock; the comparison loop gives it the case's seed (`seed_math_random`).
var math_random: RefCounted = AvmRandom.new(maxi(1, int(Time.get_unix_time_from_system() * 1000.0) & 0xFFFFFFFF))
var screen: Control
var game: Node2D
var skin: RefCounted
var current := &""
var save_path := SaveStore.DEFAULT_PATH
var store: RefCounted
var audio: Node
var _rebinding: StringName = &""
var _last_snapshot: Dictionary = {}
var _message: Label
## Art layout control (#76): -1 native, 0 follow the pack, 1 art hotspots (checks).
var screen_layout_override := 0
var _layout: StringName = &""
var _art := false
var _page_fill := Color("214c60")
## The comparison loop's recorded round (`round_as_recorded`): the next level starts on it.
var recorded_round: Dictionary = {}


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
	Quality.apply(get_viewport())
	var args := OS.get_cmdline_user_args()
	if "--practice" in args:
		_open_practice()
	elif "--screen" in args and args.find("--screen") + 1 < args.size():
		# Development launch: one generated original screen on its own, for review.
		var id := StringName(args[args.find("--screen") + 1])
		if id == &"score":
			# With the points, title and settings of a recorded capture (`--capture`).
			var at := args.find("--capture")
			_review_score(args[at + 1] if at >= 0 and at + 1 < args.size() else "win-score")
			return
		if id in [&"game_over", &"game_win"]:
			_review_end(id)
			return
		var timeline = SwfScreen.layout_of(id).get("timeline")
		_swf_page(id, int(timeline.opened_frame) if timeline is Dictionary else 0)
	else:
		show_title()


## The reference player's `seed N` for the screens' `Math.random` (tools/compare/godot_capture.gd).
func seed_math_random(seed: int) -> void:
	math_random = AvmRandom.new(seed)


func _exit_tree() -> void:
	SwfScreen.finish_warming()


func _draw() -> void:
	if is_instance_valid(game) and game.visible: return
	if current in [&"title", &"menu", &"settings", &"character", &"controls", &"powerups", &"score", &"game_over", &"game_win"]:
		# Outside the original stage there is nothing: letterbox black.
		draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color("102c3b"))
	for index in 9:
		var at := Vector2(80 + index * 150, 650 - (index % 3) * 18)
		draw_circle(at, 20, Color("1b4052"))
		draw_line(at + Vector2(8, -16), at + Vector2(14, -28), Color("3b6f7d"), 3)


## `UILoading` after loading: PLAY opens the main menu. Both screens open as many frames
## late as the original (recorded with their timelines).
func show_title() -> void:
	_end_game()
	var timeline = SwfScreen.layout_of(&"title").get("timeline")
	var swf := _swf_page(&"title", int(timeline.opened_frame) if timeline is Dictionary else 0)
	swf.action.connect(func(name: StringName): if name == &"play": show_main_menu(true))
	# Decode the menu's art in the background now, so PLAY (and every later return to the
	# menu) does not wait on disk.
	(func(): SwfScreen.warm(&"menu", swf.pixels_per_unit())).call_deferred()


## `MainMenuUI`: START → Game Settings, HOW TO PLAY → controls, and the quality, sound and
## music switches. The portal's MORE GAMES, promo strip, "Add to your site" and language
## bar are removed by owner edits (tools/convert/owner_edits.json).
func show_main_menu(from_title := false) -> void:
	_end_game()
	var timeline = SwfScreen.layout_of(&"menu").get("timeline")
	var delay: int = int(timeline.opened_after_input) if from_title and timeline is Dictionary else 0
	# Owner edit: skip the original's publisher-intro pause in play; the comparison loop
	# (frame-locked) keeps the original timing its goldens were recorded with.
	var skip = SwfScreen.layout_of(&"menu").get("owner_edits", {}).get("open_delay")
	if from_title and skip is Dictionary and not SwfScreen.frame_locked: delay = int(skip.frames)
	var swf := _swf_page(&"menu", delay)
	swf.action.connect(_menu_action)
	_sync_switches()
	# `UIManager` starts the menu music on the first menu, and again on returning to it
	# (`mainMenu` drops the round's music first).
	audio.null_game_music()
	audio.create_ui_music()


## Frames between the input and a screen's opening, as the original (recorded timeline),
## unless an owner edit sets another delay for play.
func _open_delay(id: StringName) -> int:
	var screen_layout := SwfScreen.layout_of(id)
	var timeline = screen_layout.get("timeline")
	var delay: int = int(timeline.opened_after_input) if timeline is Dictionary else 0
	var edit = screen_layout.get("owner_edits", {}).get("open_delay")
	if edit is Dictionary and not SwfScreen.frame_locked: delay = int(edit.frames)
	return delay


## Wait until the current generated screen has opened (it may open some frames late).
func screen_opened() -> void:
	var swf = screen.get_child(0) if is_instance_valid(screen) and screen.get_child_count() > 0 else null
	if swf is SwfScreen and not swf.is_open: await swf.opened


## The switches show the session's settings: quality frames HIGH/MEDIUM/LOW, sound and
## music frame 1 on, 2 off (docs/evidence/edition-5-quality.md).
func _sync_switches() -> void:
	var swf = screen.get_child(0) if is_instance_valid(screen) and screen.get_child_count() > 0 else null
	if not swf is SwfScreen: return
	swf.set_frame("quality", Quality.index() + 1)
	swf.set_frame("sound", 1 if audio.sound_on else 2)
	swf.set_frame("music", 1 if audio.music_on else 2)


func _menu_action(name: StringName) -> void:
	if name == &"start": show_settings()
	elif name == &"how_to_play": show_how_to_play()
	elif name == &"quality": _set_quality()
	elif name == &"sound": audio.set_sound(not audio.sound_on)
	elif name == &"music": audio.set_music(not audio.music_on)
	_sync_switches()


## A generated original screen, fitted to the window by one scale factor. With a delay the
## previous screen stays until the new one opens, as the original keeps showing it.
func _swf_page(id: StringName, delay := 0) -> SwfScreen:
	var previous := screen
	if delay <= 0 or not is_instance_valid(previous):
		_clear_screen()
	current = id
	_layout = id
	_art = false
	screen = Control.new()
	screen.name = "Screen_" + id
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var swf := SwfScreen.create(id, delay)
	screen.add_child(swf)
	swf.fit(screen.size)
	screen.resized.connect(func(): swf.fit(screen.size))
	if delay > 0 and is_instance_valid(previous):
		swf.opened.connect(func(): if is_instance_valid(previous): previous.queue_free())
	queue_redraw()
	return swf


## `HowToPlayUI` (controls, key rebinding) and `PowerUpsUI`, ported.
func show_how_to_play(page_name: StringName = &"controls") -> void:
	if page_name == &"power_ups":
		show_power_ups()
		return
	_end_game()
	store.load_file()
	var swf := _swf_page(&"controls", _open_delay(&"controls"))
	swf.set_meta("controller", HowToPlayUI.new(swf, self))


func show_power_ups() -> void:
	_end_game()
	var swf := _swf_page(&"powerups", _open_delay(&"powerups"))
	swf.set_meta("controller", PowerUpsUI.new(swf, self))

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
		_label(page, &"action_" + action, titles[action], Rect2(160, 233 + index * 56, 0, 0), 21)
		# On the sheet each key is the first column's cap (`onePOne<Action>Mc`); its name is live.
		var key := _button(page, StringName("Key_" + str(action)), SaveStore.key_name(store.keys[action]), Rect2(400, 225 + index * 56, 200, 46),
			func(): _begin_rebind(action), 20)
		if _art: key.add_theme_font_size_override("font_size", 16 if action == &"bomb" else 14)
		_live(key, key.name, Color.BLACK)
	_label(page, &"pause_label", "PAUSE", Rect2(160, 513, 0, 0), 21, UiKit.FONT_COLOR)
	_label(page, &"pause_value", "P", Rect2(400, 513, 200, 0), 21, UiKit.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	_message = _label(page, &"Message", "Click a control button to change it.", Rect2(160, 560, 440, 0), 18,
		Color("b4d2d7"), HORIZONTAL_ALIGNMENT_LEFT, true)
	if _art:
		_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_message.add_theme_font_size_override("font_size", 24)
		_live(_message, &"Message", Color("0f2f6b"))
		_message.add_theme_color_override("font_color", Color("0f2f6b"))
	_button(page, &"reset_keys", "RESET", Rect2(660, 470, 220, 56), _reset_keys, 22)
	_button(page, &"SaveKeys", "SAVE", Rect2(910, 470, 220, 56), _save_keys, 22)
	_label(page, &"touch_label", "TOUCH", Rect2(690, 180, 0, 0), 24, Color("ffc79a"))
	_label(page, &"touch_text", "Drag the stick on the left to move in eight directions. Tap the button on the right to place a bomb or use your item.",
		Rect2(690, 225, 410, 0), 19)
	var goals := ""
	for mode in Modes.available(): goals += "%s: %s\n" % [MODE_TITLES[mode], Modes.GOALS[mode]]
	_label(page, &"goals_label", goals.strip_edges(), Rect2(690, 345, 410, 0), 18, Color("b4d2d7"))


func _power_ups_page(screen_page: Control) -> void:
	# The `UI_POWER_UPS` sheet paints the whole guide; the native entries stay as transparent
	# text for tests and accessibility.
	var page := Control.new()
	page.name = "Guide"
	page.size = Vector2(1280, 720)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _art and ScreenLayout.is_baked(_layout, &"guide"): page.modulate = Color.TRANSPARENT
	screen_page.add_child(page)
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
	_end_game()
	var swf := _swf_page(&"settings", _open_delay(&"settings"))
	# `GameSettingsUI`, ported: it drives the screen's clips and writes the session.
	swf.set_meta("controller", GameSettingsUI.new(swf, self))
	audio.null_game_music()

func _set_mode(mode: StringName) -> void:
	session.mode = mode
	show_settings()


## `CharacterSelectUI` + `ClothesPanel`, ported: robots, outfits and hats on the original
## screen; START begins the session, BACK returns to Game Settings.
func show_character_select() -> void:
	_end_game()
	var swf := _swf_page(&"character", _open_delay(&"character"))
	swf.set_meta("controller", CharacterSelectUI.new(swf, self))


func start_session() -> void:
	session.begin()
	if not recorded_round.is_empty():
		# The recorded round's robots (seat order) and stage set.
		session.ai_robots.assign(recorded_round.robots.slice(1).map(func(r): return int(r)))
		session.current_set = &"cinema"
	_start_level()


## The comparison loop only (tools/compare/godot_capture.gd `round CAPTURE`): Godot does
## not reproduce the original's `Math.random` draws before the map, so the next level starts
## on the round the gameplay screen's capture CAPTURE recorded (its board, its robots),
## from that screen's layout (scenes/swf/game.json `board`, tools/convert/layout.py).
func round_as_recorded(capture: String) -> void:
	var screen_layout := SwfScreen.layout_of(&"game")
	if not String(screen_layout.source.golden).ends_with("/%s.json" % capture):
		push_error("the gameplay screen was not converted from capture %s" % capture)
		return
	recorded_round = screen_layout.board


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
	game.visible = true
	game.detach_swf()
	var recorded := not recorded_round.is_empty()
	game.recorded_board = recorded_round
	recorded_round = {}
	game.play_level()
	if _has_game_screen(session.current_set): _game_screen(recorded)
	current = &"playing"
	queue_redraw()


## Rounds on a stage set whose gameplay screen is converted (checkpoint 4: Cinema) show the
## generated original screen; the others keep the placeholder page until theirs is.
func _has_game_screen(set_id: StringName) -> bool:
	return set_id == &"cinema" and FileAccess.file_exists("res://scenes/swf/game.json")


## The gameplay screen (scenes/swf/game.json): `GameInterFace` on its HUD, the round's map
## laid out on its board (scripts/ui/game_board.gd), the round's actors as placeholders in
## its board container (robots, bombs and blasts from their original clips, GameActors;
## pickups and weapon effects still placeholders), and the round held for as many frames as the original takes to
## load the map (`round_start_after_input`).
func _game_screen(recorded: bool) -> void:
	var swf := _swf_page(&"game")
	var board_layout: Dictionary = swf.layout.board
	var board := GameBoard.new(swf, board_layout)
	board.build(game.get_snapshot(), recorded)
	# The recorded round's robots wear the recorded looks; a rolled round's the session's.
	var actors := GameActors.new(swf, board, board_layout.get("looks", []) if recorded else [])
	actors.update(game.get_snapshot())
	var hud := GameInterFace.new(swf, self, game)
	swf.set_meta("controller", hud)
	swf.set_meta("board", board)
	swf.set_meta("actors", actors)
	game.attach_swf(swf.node_for(board_layout.container), board.view_transform(GameView.ORIGIN, GameView.PITCH),
		func(snapshot: Dictionary):
			board.update(snapshot)
			actors.update(snapshot)
			hud.present(snapshot))
	game.start_delay = int(board_layout.round_start_after_input)
	# The round's pause screen (still the placeholder page's) draws over the screen.
	move_child(game, -1)


func _on_level_settled(snapshot: Dictionary, delay := 0) -> void:
	var outcome: StringName = snapshot.outcome
	var won: bool = outcome == &"won" or (outcome == &"timeout" and session.mode == &"arcade" and Fidelity.timeout_wins())
	var result: int = session.settle(&"won" if won else &"lost", snapshot.result_score,
		snapshot.actors[&"human"].lives)
	_last_snapshot = snapshot
	# `AbstractGameMode.loseHandler` / `winHandler`: the score screen for every result
	# (`onePScore`, which also unlocks the looks the total reached); after the last heart
	# `gameOver(GAME_OVER)` replaces it at once, so the Game Over screen takes the delay.
	if result == Session.Result.GAME_OVER:
		show_score(snapshot)
		show_end(false, delay)
	else:
		show_score(snapshot, delay)


## `OnePScoreUI` (UI_LEVEL_COMPLETED_ONEP), ported: the level's points, NEXT or RESTART
## (and Space), DRESS UP, and the unlock tip when the total unlocks looks, on the
## generated original screen. The round stays loaded, hidden, for RESTART and NEXT.
func show_score(snapshot: Dictionary, delay := 0) -> void:
	if is_instance_valid(game): game.visible = false
	var swf := _swf_page(&"score", delay)
	var round_state := {"personalPlayers": [OnePScoreUI.personal_player(snapshot, session)]}
	swf.set_meta("controller", OnePScoreUI.new(swf, self, OnePScoreUI.game_result(session.last_result), round_state))


## The comparison loop (tools/compare/godot_capture.gd `settle`) and `--screen score` only.
## Godot cannot replay the original's round, so the round ends with the points the
## original's score screen showed at a recorded capture (its golden: the TextFields `kill`,
## `time`, `difficulity` and `levelScore`, and levelTitle's frame, 1 complete or 2 failed),
## through the app's own round-end path. Hearts are not on the screen: a failed level with
## RESTART showing keeps the session's. With `frames_to_capture`, the screen opens so that
## when the capture is taken it is as far into its timeline as the original's was
## (`capture_index_of`, matched by tools/convert/layout.py).
func settle_as_recorded(golden: Dictionary, capture: String, frames_to_capture := -1) -> void:
	var end := _end_screen_of(golden)
	if end != &"":
		_settle_end_as_recorded(golden, capture, end, frames_to_capture)
		return
	var screen_layout := SwfScreen.layout_of(&"score")
	var root: String = screen_layout.screen_root
	var shown := {}
	for node: Dictionary in golden.nodes:
		if String(node.path).begins_with(root + "/"): shown[String(node.path).substr(root.length() + 1)] = node
	var points := func(field: String) -> int: return String(shown.get(field, {}).get("text", "0")).to_int()
	var won: bool = int(shown.get("title", {}).get("frame", 1)) == 1
	var lives: int = session.lives if won or bool(shown.get("restartBtn", {}).get("effective_visible", false)) else 0
	var delay := 0
	if frames_to_capture >= 0:
		var phases: Dictionary = screen_layout.get("timeline", {}).get("capture_index_of", {})
		delay = frames_to_capture - int(phases.get(capture, 0))
	_end_game()
	_on_level_settled({"outcome": &"won" if won else &"lost", "result_score": points.call("levelScore"),
		"actors": {&"human": {"lives": lives}},
		"result_breakdown": {"kills": points.call("kill"), "time": points.call("time"),
			"difficulty": points.call("difficulity")}}, delay)


## `--screen score [--capture NAME]`: the score screen as the original showed it at a
## capture of the results case, with that capture's settings: "LEVEL n / m" from the title,
## the difficulty from `bonus_txt`'s frame, the robot from `p1head`'s (the inverse of
## `PlayerScoreUI.initData` and `OnePScoreUI.initData`) and the earlier levels' points
## (`total` less `levelScore`). Unlocks come from the player's own save.
func _review_score(capture: String) -> void:
	var golden: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/goldens/results/%s.json" % capture))
	var root: String = SwfScreen.layout_of(&"score").screen_root
	var title := RegEx.create_from_string("(\\d+) / (\\d+)")
	var level := 1
	var earlier := 0
	for node: Dictionary in golden.nodes:
		var relative := String(node.path).trim_prefix(root + "/")
		var found: RegExMatch = title.search(String(node.get("text", ""))) if relative.begins_with("title/") else null
		if found != null:
			level = found.get_string(1).to_int()
			session.levels = found.get_string(2).to_int()
		elif relative == "bonus_txt": session.difficulty = [&"easy", &"normal", &"hard"][int(node.frame) - 1]
		elif relative == "p1head": session.robot = int(node.frame) - 1
		elif relative == "total": earlier += String(node.text).to_int()
		elif relative == "levelScore": earlier -= String(node.text).to_int()
	session.begin()
	session.level = level
	session.total_score = earlier  # the levels before this one
	settle_as_recorded(golden, capture)


## The end screen (`game_over`, `game_win`) whose root clip a golden shows, or none.
func _end_screen_of(golden: Dictionary) -> StringName:
	var classes := {"UI_GAMEOVERONEP": &"game_over", "UI_CONGRATULATIONSONEP": &"game_win"}
	for node: Dictionary in golden.nodes:
		if classes.has(String(node.get("class", ""))): return classes[String(node.class)]
	return &""


## `settle_as_recorded` for a capture of an end screen. The original's screen shows only
## the final score (`score`, the score screen's `total`): the round ends as the last level
## won (`game_win`, as the session's last level) or with the last heart spent
## (`game_over`), with the points that make the session total that score. Game Over opens
## from the round's end, so it takes the capture's timeline index as the score screen
## does; the congratulations screen opens later, from NEXT on the score screen.
func _settle_end_as_recorded(golden: Dictionary, capture: String, end: StringName, frames_to_capture := -1) -> void:
	var screen_layout := SwfScreen.layout_of(end)
	var root: String = screen_layout.screen_root
	var final := 0
	for node: Dictionary in golden.nodes:
		if String(node.path) == root + "/score": final = String(node.get("text", "0")).to_int()
	var won := end == &"game_win"
	if won: session.level = session.levels
	var delay := 0
	if frames_to_capture >= 0 and not won:
		var phases: Dictionary = screen_layout.get("timeline", {}).get("capture_index_of", {})
		delay = frames_to_capture - int(phases.get(capture, 0))
	_end_game()
	_on_level_settled({"outcome": &"won" if won else &"lost", "result_score": final - session.total_score,
		"actors": {&"human": {"lives": session.lives if won else 0}}, "result_breakdown": {}}, delay)


## `--screen game_over` / `--screen game_win`: the end screen with its recorded capture's
## final score and robot (`p1head`'s frame, the inverse of `OnePGameOverUI.initData`).
func _review_end(id: StringName) -> void:
	var source: String = SwfScreen.layout_of(id).source.golden
	var golden: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://" + source))
	var root: String = SwfScreen.layout_of(id).screen_root
	for node: Dictionary in golden.nodes:
		if String(node.path) == root + "/p1head": session.robot = int(node.frame) - 1
	session.begin()
	settle_as_recorded(golden, source.get_file().get_basename())
	if id == &"game_win": show_end(true)


func _continue() -> void:
	if session.last_result == Session.Result.GAME_WIN:
		show_end(true)
		return
	session.advance()
	_start_level()


## `UIManager.gameOver(gameResult)`, one player: the round is disposed, the score screen
## hidden, `OnePGameOverUI` opened with the score screen's `total` (UI_GAMEOVERONEP after
## the last heart, UI_CONGRATULATIONSONEP after the last level), then the score screen's
## controller destroyed. TRY AGAIN (`backHandle`) returns to Game Settings. Without a score
## screen (a development launch) the session total stands in for `total`.
func show_end(won: bool, delay := -1) -> void:
	_end_game()  # this.game.dispose()
	var swf_score = screen.get_child(0) if is_instance_valid(screen) and screen.get_child_count() > 0 else null
	var score_ui = swf_score.get_meta("controller") if swf_score is SwfScreen and current == &"score" and swf_score.has_meta("controller") else null
	var total: int = score_ui.total if score_ui != null else session.total_score
	_clear_screen()  # this._uiOnePScore.display = false
	var id := &"game_win" if won else &"game_over"
	var swf := _swf_page(id, _open_delay(id) if delay < 0 else delay)
	var gameResult: int = OnePGameOverUI.GameResult.GAME_WIN if won else OnePGameOverUI.GameResult.GAME_OVER
	swf.set_meta("controller", OnePGameOverUI.new(swf, self, total, gameResult))
	if score_ui != null: score_ui.destroy()


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
	return UiKit.plate(screen, rect, ScreenLayout.plate_color(_layout, name, colour))


## A text label on its hotspot; ghosted when the sheet already paints that text.
func _label(page: Control, name: StringName, text: String, native_rect: Rect2, font_px := 20,
		colour := UiKit.FONT_COLOR, align := HORIZONTAL_ALIGNMENT_LEFT, carrier := false) -> Label:
	var rect := _rect(name, native_rect)
	var width := rect.size.x if rect.size.x > 0 else -1.0
	var widget := UiKit.label(page, text, rect.position, font_px, colour, width, align, carrier)
	widget.name = name
	if _art and rect.size.y > 0:
		widget.size.y = rect.size.y
		widget.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if _art and not carrier and ScreenLayout.is_baked(_layout, name): UiKit.ghost_label(widget)
	return widget


## A button on its hotspot; ghosted when the sheet already paints that button.
func _button(page: Control, name: StringName, text: String, native_rect: Rect2, action: Callable,
		font_px := 22) -> Button:
	var widget := UiKit.button(page, text, _rect(name, native_rect), action, skin, font_px)
	widget.name = name
	_gate(widget, name)
	return widget


## `qualityCtlHandle`: the next stage quality, for this session only.
func _set_quality() -> void:
	Quality.cycle()
	Quality.apply(get_viewport())


## A live widget on an art page: a plate hides the painted value, the widget draws its own
## text in the sheet's colour over it.
func _live(widget: Control, name: StringName, colour: Color) -> void:
	if not _art or not ScreenLayout.is_live(_layout, name): return
	var cover := _plate(name)
	if cover != null: screen.move_child(cover, widget.get_index() if widget.get_parent() == screen else screen.get_child_count() - 1)
	UiKit.ghost_text(widget, colour)


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


## A pickup icon: the workbench `item.<kind>` slot or the native badge.
class ItemIcon extends Control:
	var kind: StringName
	var skin: RefCounted

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		if skin != null and skin.draw(self, "item." + kind, rect): return
		draw_circle(size / 2, size.x / 2 - 2, Color("d1fff0"))
		draw_arc(size / 2, size.x / 2 - 2, 0, TAU, 28, Color("60b4a4"), 2, Quality.edges)
		var text: String = GameView.ITEM_NAMES.get(kind, "?")
		draw_string(ThemeDB.fallback_font, size / 2 + Vector2(-text.length() * 4.5, 6), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("173c40"))

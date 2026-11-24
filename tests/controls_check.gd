extends SceneTree
## How to Play, power-up guide and saved key rebinding (#61) through the main scene.

const Fidelity = preload("res://scripts/fidelity.gd")

const SaveStore = preload("res://scripts/save_store.gd")
const SAVE := "user://controls-check-save.json"
var failures := 0
var checks := 0
var app: Control


func _initialize() -> void:
	# Generated screens follow frames, not the clock, so waiting for them is quick.
	load("res://scripts/ui/swf_screen.gd").frame_locked = true
	_run.call_deferred()


func _run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	var store := SaveStore.new(SAVE)
	_expect(store.keys == SaveStore.DEFAULT_KEYS, "a missing save starts with arrows and Space")
	_expect(not store.can_bind(&"up", KEY_P), "P stays reserved for pause")
	_expect(not store.can_bind(&"up", KEY_DOWN), "a key bound to another control is rejected")
	_expect(not store.can_bind(&"up", KEY_SPACE) and store.can_bind(&"bomb", KEY_ENTER) == false, "movement cannot take Space; Enter is not in the original tables")
	_expect(store.can_bind(&"bomb", KEY_KP_0) and store.can_bind(&"bomb", KEY_F2) and not store.can_bind(&"left", KEY_KP_0),
		"numpad and F-keys are bomb-only")
	store.keys[&"bomb"] = KEY_Q
	_expect(store.save_file(), "bindings save")
	_expect(SaveStore.new(SAVE).keys[&"bomb"] == KEY_Q, "saved bindings load back")
	var file := FileAccess.open(SAVE, FileAccess.WRITE)
	file.store_string("{not json")
	file.close()
	_expect(SaveStore.new(SAVE).keys == SaveStore.DEFAULT_KEYS, "a corrupt save falls back to defaults")
	file = FileAccess.open(SAVE, FileAccess.WRITE)
	file.store_string(JSON.stringify({"keys": {"up": KEY_P, "left": KEY_LEFT, "down": KEY_DOWN, "right": KEY_RIGHT, "bomb": KEY_SPACE}}))
	file.close()
	_expect(SaveStore.new(SAVE).keys == SaveStore.DEFAULT_KEYS, "an invalid saved binding set is ignored")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	root.size = Vector2i(1280, 720)
	app = load("res://scenes/main.tscn").instantiate()
	app.save_path = SAVE
	root.add_child(app)
	await process_frame
	await app.screen_opened()
	await _click(_find("btn_play"))
	await app.screen_opened()
	await _click(_find("howToPlay"))
	await app.screen_opened()
	var caps := "ctrlField/"
	_expect(app.current == &"controls" and _swf().get_text(caps + "onePOneBomb") == "Space", "HOW TO PLAY shows the current controls")
	await _click(_find("onePOneBomb"))
	_expect(_swf().get_frame("messenge") == 2, "clicking a control waits for a key (message frame 2)")
	await _press(KEY_Q)
	_expect(_swf().get_text(caps + "onePOneBomb") == "Q", "pressing a key rebinds the control")
	await _click(_find("onePOneUp"))
	await _press(KEY_P)
	# MyTextField.onePOneUpKeyHandle: KEY_ERROR leaves the cap as the click cleared it;
	# onePOneUpFocusHandle puts the default back when focus leaves.
	_expect(_swf().get_frame("messenge") == 3 and _swf().get_text(caps + "onePOneUp") == "",
		"a reserved key is refused with the original message (frame 3)")
	await _click(_find("back"))
	await app.screen_opened()
	await _click(_find("howToPlay"))
	await app.screen_opened()
	_expect(_swf().get_text(caps + "onePOneBomb") == "Space", "leaving without SAVE discards changes")
	await _click(_find("onePOneBomb"))
	await _press(KEY_Q)
	await _click(_find("save"))
	_expect(_swf().get_frame("messenge") == 4, "SAVE confirms with the original message (frame 4)")
	await _click(_find("back"))
	await app.screen_opened()
	await _click(_find("howToPlay"))
	await app.screen_opened()
	_expect(_swf().get_text(caps + "onePOneBomb") == "Q", "saved controls persist")
	await _click(_find("powerUps"))
	await app.screen_opened()
	_expect(app.current == &"powerups" and _find("controls") != null, "POWER-UPS opens the power-up guide")
	await _click(_find("back"))
	await app.screen_opened()

	await _click(_find("startGame"))
	await app.screen_opened()
	await _click(_find("confirm"))
	await app.screen_opened()
	await _click(_find("startBtn"))
	var game: Node2D = app.game
	game.set_process(false)
	_expect(game.bindings[&"bomb"] == KEY_Q, "the level uses the saved bindings")
	await _press(KEY_Q)
	game.advance_time(1.0 / 35.0)
	_expect(game.get_snapshot().bombs.any(func(bomb): return bomb.actor_id == &"human"), "the rebound key places a bomb")
	app.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("%s: %d controls checks" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)


func _swf() -> Node:
	return app.screen.get_child(0)


func _press(keycode: int) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	root.push_input(event)
	await process_frame


func _click(control: Control) -> void:
	if control == null:
		_expect(false, "control to click exists")
		return
	# A generated screen shows some instances only after a while (PLAY after loading).
	for wait in 900:
		if control.is_visible_in_tree(): break
		await process_frame
	var at := control.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		root.push_input(event)
	await process_frame
	await process_frame


func _find(node_name: String) -> Node:
	return app.find_child(node_name, true, false)


func _find_text(text: String) -> Node:
	for node in app.find_children("*", "", true, false):
		if (node is Label or node is Button) and node.text == text and node.is_visible_in_tree(): return node
	return null


func _expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr(label)

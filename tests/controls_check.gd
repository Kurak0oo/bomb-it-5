extends SceneTree
## How to Play, power-up guide and saved key rebinding (#61) through the main scene.

const Fidelity = preload("res://scripts/fidelity.gd")

const SaveStore = preload("res://scripts/save_store.gd")
const SAVE := "user://controls-check-save.json"
var failures := 0
var checks := 0
var app: Control


func _initialize() -> void:
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
	await _click(_find("HowToPlay"))
	_expect(app.current == &"how_to_play" and _find("Key_bomb").text == "Space", "HOW TO PLAY shows the current controls")
	await _click(_find("Key_bomb"))
	_expect(_find("Message").text == "Select a key with your keyboard", "clicking a control waits for a key")
	await _press(KEY_Q)
	_expect(_find("Key_bomb").text == "Q", "pressing a key rebinds the control")
	await _click(_find("Key_up"))
	await _press(KEY_P)
	_expect(_find("Message").text.begins_with("This key is not possible") and _find("Key_up").text == "↑",
		"a reserved key is refused with the original message")
	await _click(_find("Back"))
	await _click(_find("HowToPlay"))
	_expect(_find("Key_bomb").text == "Space", "leaving without SAVE discards changes")
	await _click(_find("Key_bomb"))
	await _press(KEY_Q)
	await _click(_find("SaveKeys"))
	_expect(_find("Message").text == "Custom controls saved.", "SAVE confirms with the original message")
	await _click(_find("Back"))
	await _click(_find("HowToPlay"))
	_expect(_find("Key_bomb").text == "Q", "saved controls persist")
	await _click(_find("PowerUpsTab"))
	_expect(_find_text("SPORT CAR") != null and _find_text("LIGHTNING GUN") != null and _find_text("INVINCIBILITY") != null,
		"the power-up guide lists pickups, weapons and vehicles")
	var gloves: bool = _find_text("BOXING GLOVE") != null and _find_text("PUSH THE BOMB") != null
	_expect(gloves == Fidelity.original, "the glove items are described exactly where rounds drop them (#85)")
	await _click(_find("Back"))

	await _click(_find("Start"))
	await _click(_find("Next"))
	await _click(_find("StartGame"))
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

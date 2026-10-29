extends RefCounted
## Local save file: key bindings, unlocks and the sound and music switches (`Cookie`,
## `HowToPlayUI.saveKeys`). No accounts.
## A missing or unreadable file starts from defaults.

const DEFAULT_PATH := "user://bomb_it_5_save.json"
const ACTIONS: Array[StringName] = [&"up", &"left", &"down", &"right", &"bomb"]
const DEFAULT_KEYS := {&"up": KEY_UP, &"left": KEY_LEFT, &"down": KEY_DOWN, &"right": KEY_RIGHT, &"bomb": KEY_SPACE}
## P pauses, so no control may take it (`HowToPlayUI` adds keyCode 80 to every list).
const RESERVED: Array[int] = [KEY_P]

var path := DEFAULT_PATH
var keys: Dictionary = DEFAULT_KEYS.duplicate()
## robot index (String) → array of unlocked look numbers 1-8.
var unlocks: Dictionary = {}
## `Cookie.soundEnable` / `musicEnable`, true until switched off.
var sound_on := true
var music_on := true


func _init(file_path: String = DEFAULT_PATH) -> void:
	path = file_path
	load_file()


func load_file() -> void:
	keys = DEFAULT_KEYS.duplicate()
	unlocks = {}
	sound_on = true
	music_on = true
	if not FileAccess.file_exists(path): return
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary: return
	var data: Dictionary = json.data
	var saved_keys: Variant = data.get("keys", {})
	if saved_keys is Dictionary:
		var candidate := DEFAULT_KEYS.duplicate()
		for action in ACTIONS:
			if saved_keys.get(action) is float: candidate[action] = int(saved_keys[action])
		if valid_bindings(candidate): keys = candidate
	if data.get("sound") is bool: sound_on = data.sound
	if data.get("music") is bool: music_on = data.music
	var saved_unlocks: Variant = data.get("unlocks", {})
	if saved_unlocks is Dictionary:
		for robot in saved_unlocks:
			if saved_unlocks[robot] is Array:
				unlocks[str(robot)] = saved_unlocks[robot].filter(func(look): return look is float and look >= 1 and look <= 8).map(func(look): return int(look))


func save_file() -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify({"keys": keys, "unlocks": unlocks, "sound": sound_on, "music": music_on}, "\t"))
	return true


## Original key tables: movement takes letters, digits, arrows and punctuation; the bomb
## key also takes Space, the numpad, F1-F8, Tab and Esc.
static func allowed(action: StringName, keycode: int) -> bool:
	if keycode in RESERVED: return false
	if (keycode >= KEY_A and keycode <= KEY_Z) or (keycode >= KEY_0 and keycode <= KEY_9): return true
	if keycode in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_QUOTELEFT, KEY_COMMA, KEY_PERIOD, KEY_SEMICOLON,
			KEY_APOSTROPHE, KEY_BRACKETLEFT, KEY_BRACKETRIGHT, KEY_MINUS, KEY_EQUAL, KEY_BACKSLASH, KEY_SLASH]:
		return true
	if action != &"bomb": return false
	return keycode in [KEY_SPACE, KEY_TAB, KEY_ESCAPE, KEY_KP_DIVIDE, KEY_KP_MULTIPLY, KEY_KP_SUBTRACT,
		KEY_KP_ADD, KEY_KP_PERIOD] or (keycode >= KEY_KP_0 and keycode <= KEY_KP_9) or (keycode >= KEY_F1 and keycode <= KEY_F8)


static func valid_bindings(bindings: Dictionary) -> bool:
	var seen := {}
	for action in ACTIONS:
		var keycode: int = bindings.get(action, KEY_NONE)
		if not allowed(action, keycode) or seen.has(keycode): return false
		seen[keycode] = true
	return true


## Rejects a key that is not allowed or already bound to another control.
func can_bind(action: StringName, keycode: int) -> bool:
	if not allowed(action, keycode): return false
	for other in ACTIONS:
		if other != action and keys[other] == keycode: return false
	return true


func action_for(keycode: int) -> StringName:
	for action in ACTIONS:
		if keys[action] == keycode: return action
	return &""


static func key_name(keycode: int) -> String:
	match keycode:
		KEY_UP: return "↑"
		KEY_DOWN: return "↓"
		KEY_LEFT: return "←"
		KEY_RIGHT: return "→"
	return OS.get_keycode_string(keycode)

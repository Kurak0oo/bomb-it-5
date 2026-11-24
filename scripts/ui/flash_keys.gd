extends RefCounted
## Flash `KeyboardEvent.keyCode` values <-> Godot keys, for ported UI code that reads the
## original's key codes (flash.ui.Keyboard).

const FLASH_TO_GODOT := {
	8: KEY_BACKSPACE, 9: KEY_TAB, 13: KEY_ENTER, 16: KEY_SHIFT, 17: KEY_CTRL, 18: KEY_ALT, 20: KEY_CAPSLOCK,
	27: KEY_ESCAPE, 32: KEY_SPACE, 33: KEY_PAGEUP, 34: KEY_PAGEDOWN, 35: KEY_END, 36: KEY_HOME,
	37: KEY_LEFT, 38: KEY_UP, 39: KEY_RIGHT, 40: KEY_DOWN, 45: KEY_INSERT, 46: KEY_DELETE,
	96: KEY_KP_0, 97: KEY_KP_1, 98: KEY_KP_2, 99: KEY_KP_3, 100: KEY_KP_4, 101: KEY_KP_5, 102: KEY_KP_6,
	103: KEY_KP_7, 104: KEY_KP_8, 105: KEY_KP_9, 106: KEY_KP_MULTIPLY, 107: KEY_KP_ADD, 109: KEY_KP_SUBTRACT,
	110: KEY_KP_PERIOD, 111: KEY_KP_DIVIDE, 186: KEY_SEMICOLON, 187: KEY_EQUAL, 188: KEY_COMMA, 189: KEY_MINUS,
	190: KEY_PERIOD, 191: KEY_SLASH, 192: KEY_QUOTELEFT, 219: KEY_BRACKETLEFT, 220: KEY_BACKSLASH,
	221: KEY_BRACKETRIGHT, 222: KEY_APOSTROPHE,
}


## Flash keyCode of a Godot key (letters and digits share their ASCII codes), or 0.
static func from_godot(key: Key) -> int:
	if key >= KEY_A and key <= KEY_Z: return int(key)
	if key >= KEY_0 and key <= KEY_9: return int(key)
	if key >= KEY_F1 and key <= KEY_F12: return 112 + int(key - KEY_F1)
	var code = FLASH_TO_GODOT.find_key(key)
	return int(code) if code != null else 0


static func to_godot(code: int) -> Key:
	if code >= 65 and code <= 90: return code as Key
	if code >= 48 and code <= 57: return code as Key
	if code >= 112 and code <= 123: return (KEY_F1 + code - 112) as Key
	return FLASH_TO_GODOT.get(code, KEY_NONE)

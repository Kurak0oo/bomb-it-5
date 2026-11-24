extends RefCounted
## Port of `zlong.bombit5.ui.HowToPlayUI` (class UI_CONTROLS) and the
## `zlong.bombit5.utils.MyTextField` key caps it builds, onto a generated screen.
##
## One player only (the owner removed 2-player play): the 1P column is live. The 2P key
## lists (`_twoP*Date`) are kept with their original defaults so `_dataArrTwo`,
## `reInitData` and `saveKeys` keep their shape, but no `MyTextField` is made for the
## `twoP*` caps, so those columns stay inert (no text set, no listeners).
##
## Keys are Flash key codes throughout, as in the AS3 (`KeyboardEvent.keyCode`, delivered
## by the screen's `key_down`). They become Godot keys only where they leave the screen:
## `GameModel.onePOne*Date` is `app.store.keys` and the SharedObject `key` array is
## `app.store.save_file()`; `FlashKeys` (scripts/ui/flash_keys.gd, the table the screen
## itself uses for `key_down`) converts both ways.
##
## Quirks kept: a key with no name in the cap's table is stored anyway and then reported
## as an error (the TypeError in `onePOneUpKeyHandle`); an emptied cap falls back to the
## name it showed when the screen opened, not to its current key; DEFAULT changes the keys
## but only SAVE or POWER-UPS writes them, and BACK without SAVE puts back the keys the
## screen opened with (`saveDefaultData`). The `messenge` clip's frames hold the
## original message texts (1 "Click a control button to change it.", 2 "Select a key with
## your keyboard", 3 "This key is not possible.Please choose a different key.",
## 4 "Custom controls saved."), so the port only picks frames.

const UtilsButton = preload("res://scripts/ui/button.gd")
const SwfEvents = preload("res://scripts/ui/swf_events.gd")
const FlashKeys = preload("res://scripts/ui/flash_keys.gd")

## `new Array(38,37,40,39,32,87,65,83,68,32,38,37,40,39,13)` in `initData`: 1P arrows and
## Space; 2P player one W A S D and Space, player two arrows and Enter.
const DEFAULT_KEYS: Array[int] = [38, 37, 40, 39, 32, 87, 65, 83, 68, 32, 38, 37, 40, 39, 13]
## The store's actions in the AS3 order of the 1P lists (up, left, down, right, bomb).
const ONE_P_ACTIONS: Array[StringName] = [&"up", &"left", &"down", &"right", &"bomb"]
## `new GlowFilter(16750848, 1, 10, 10, 2)` on a cap while it waits for a key.
const GLOW := {"color": 16750848, "alpha": 1.0, "blurX": 10.0, "blurY": 10.0, "strength": 2.0}

## The AS3's static key lists: one-element arrays shared by the caps, kept for the session
## (a later visit reads them, not the save file).
static var _onePOneUpDate: Array = []
static var _onePOneLeftDate: Array = []
static var _onePOneDownDate: Array = []
static var _onePOneRightDate: Array = []
static var _onePOneBombDate: Array = []
static var _twoPOneUpDate: Array = []
static var _twoPOneLeftDate: Array = []
static var _twoPOneDownDate: Array = []
static var _twoPOneRightDate: Array = []
static var _twoPOneBombDate: Array = []
static var _twoPTwoUpDate: Array = []
static var _twoPTwoLeftDate: Array = []
static var _twoPTwoDownDate: Array = []
static var _twoPTwoRightDate: Array = []
static var _twoPTwoBombDate: Array = []

var _mc: Node2D
var _events: RefCounted
var _app: Node
var simpleButtons: Array = []

var _back := ""
var _defaule := ""
var _powerUps := ""
var _save := ""
var _messenge := ""
var _ctrlField := ""

var _onePOneUp: MyTextField
var _onePOneLeft: MyTextField
var _onePOneDown: MyTextField
var _onePOneRight: MyTextField
var _onePOneBomb: MyTextField

var _asciiBomb: Dictionary = {}
var _asciiMove: Dictionary = {}
var _dataArrOne: Array = []
var _dataArrTwo: Array = []
var _dataArrTotal: Array = []
var _haveSave := false

## Flash focus (`stage.focus`) as far as the caps need it: the cap holding focus, and the
## press number of the last mouse-down an instance heard.
var _focus: MyTextField = null
var _down_press := -1
var _text_fields: Array[MyTextField] = []


## `HowToPlayUI(param1, param2)` -> `AbstractUI`: init, initView, initListener, initData.
func _init(screen: Node2D, app: Node) -> void:
	_mc = screen
	_app = app
	# Before SwfEvents, so focus moves before the press's MOUSE_DOWN handlers run, as in
	# the player (Ruffle `update_focus_on_mouse_press` precedes the AVM2 dispatch).
	_mc.mouse_event.connect(_mouseFocusChange)
	_mc.stage_down.connect(_stageFocusHandle)
	_mc.key_down.connect(_stageKeyHandle)
	_events = SwfEvents.new(screen)
	init()
	initView()
	initListener()
	initData()


## `init`: `setMC("UI_CONTROLS")`; the app has already built the screen.
func init() -> void:
	pass


func _sound(name: String) -> void:
	if name == "menuPress": _app.audio.menu_press()
	else: _app.audio.menu_touch()


## `initView`
func initView() -> void:
	_back = "back"
	_powerUps = "powerUps"
	simpleButtons.append(UtilsButton.new(_mc, _events, _back))
	simpleButtons.append(UtilsButton.new(_mc, _events, _powerUps))
	_ctrlField = "ctrlField"
	_messenge = "messenge"
	_mc.set_frame(_messenge, 1)
	_defaule = "defaule"
	_save = "save"
	simpleButtons.append(UtilsButton.new(_mc, _events, _defaule))
	simpleButtons.append(UtilsButton.new(_mc, _events, _save))


## `initListener`. The `ctrlField` UIEvent listeners (KEY_DOWN / KEY_ERROR / KEY_NORMAL)
## are direct calls from the caps to `keyDown` / `keyErroe` / `keyNormal`.
func initListener() -> void:
	_events.add(_save, &"down", saveHandle)
	_events.add(_save, &"over", backOverHandle)
	_events.add(_defaule, &"down", defauleHandle)
	_events.add(_defaule, &"over", backOverHandle)
	_events.add(_powerUps, &"down", powerUpsHandle)
	_events.add(_powerUps, &"over", powerUpsOverHandle)
	_events.add(_back, &"down", backHandle)
	_events.add(_back, &"over", backOverHandle)


## `delListener` (as in the AS3, the save / defaule over handlers stay).
func delListener() -> void:
	_events.remove(_save, &"down", saveHandle)
	_events.remove(_defaule, &"down", defauleHandle)
	_events.remove(_powerUps, &"down", powerUpsHandle)
	_events.remove(_powerUps, &"over", powerUpsOverHandle)
	_events.remove(_back, &"down", backHandle)
	_events.remove(_back, &"over", backOverHandle)


## `initData`
func initData() -> void:
	var _loc2_: Array
	_dataArrOne = []
	_dataArrTwo = []
	_dataArrTotal = []
	_asciiBomb = {}
	_asciiMove = {}
	_haveSave = false
	for code in range(65, 91):  # A-Z
		_asciiBomb[code] = String.chr(code)
		_asciiMove[code] = String.chr(code)
	for code in range(48, 58):  # 0-9
		_asciiBomb[code] = String.chr(code)
		_asciiMove[code] = String.chr(code)
	_asciiBomb[32] = "Space"
	_asciiBomb[192] = "~"; _asciiMove[192] = "~"
	_asciiBomb[38] = "↑"; _asciiMove[38] = "↑"
	_asciiBomb[40] = "↓"; _asciiMove[40] = "↓"
	_asciiBomb[37] = "←"; _asciiMove[37] = "←"
	_asciiBomb[39] = "→"; _asciiMove[39] = "→"
	for code in range(96, 106):  # Numpad 0-9
		_asciiBomb[code] = "Numpad " + str(code - 96)
	_asciiBomb[111] = "Numpad /"
	_asciiBomb[106] = "Numpad *"
	_asciiBomb[109] = "Numpad -"
	_asciiBomb[107] = "Numpad +"
	_asciiBomb[110] = "Numpad ."
	for code in range(112, 120):  # F1-F8
		_asciiBomb[code] = "F" + str(code - 111)
	for pair in [[188, ","], [190, "."], [186, ";"], [222, "'"], [219, "["], [221, "]"], [189, "-"],
			[187, "+"], [220, "\\"], [191, "/"]]:
		_asciiBomb[pair[0]] = pair[1]
		_asciiMove[pair[0]] = pair[1]
	_asciiBomb[9] = "Tab"
	_asciiBomb[27] = "Esc"
	_asciiBomb[13] = "Enter"
	# `if(_onePOneUpDate == null) _onePOneUpDate = new Array()` ...: the static vars start
	# as empty arrays.
	# `SharedObject.getLocal(GameConfig.GAME_NAME).data["key"]`: the store's keys (it falls
	# back to the same defaults when nothing is saved); the store keeps 1P only, so the 2P
	# entries are the AS3 defaults.
	if _app.store != null and _app.store.keys is Dictionary:
		_loc2_ = DEFAULT_KEYS.duplicate()
		for i in ONE_P_ACTIONS.size():
			_loc2_[i] = FlashKeys.from_godot(_app.store.keys.get(ONE_P_ACTIONS[i], KEY_NONE))
	else:
		_loc2_ = DEFAULT_KEYS.duplicate()
	var _loc3_: Array = [_onePOneUpDate, _onePOneLeftDate, _onePOneDownDate, _onePOneRightDate, _onePOneBombDate,
		_twoPOneUpDate, _twoPOneLeftDate, _twoPOneDownDate, _twoPOneRightDate, _twoPOneBombDate,
		_twoPTwoUpDate, _twoPTwoLeftDate, _twoPTwoDownDate, _twoPTwoRightDate, _twoPTwoBombDate]
	for _loc4_ in _loc3_.size():
		if (_loc3_[_loc4_] as Array).is_empty():
			_loc3_[_loc4_].append(_loc2_[_loc4_])
	_dataArrOne.append_array([_onePOneUpDate, _onePOneLeftDate, _onePOneDownDate, _onePOneRightDate, _onePOneBombDate, 80])
	_dataArrTwo.append_array([_twoPOneUpDate, _twoPOneLeftDate, _twoPOneDownDate, _twoPOneRightDate, _twoPOneBombDate,
		_twoPTwoUpDate, _twoPTwoLeftDate, _twoPTwoDownDate, _twoPTwoRightDate, _twoPTwoBombDate, 80])
	_dataArrTotal.append_array(_loc3_ + [80])
	_onePOneUp = _make_field("onePOneUp", _onePOneUpDate, _asciiMove, _dataArrOne)
	_onePOneLeft = _make_field("onePOneLeft", _onePOneLeftDate, _asciiMove, _dataArrOne)
	_onePOneDown = _make_field("onePOneDown", _onePOneDownDate, _asciiMove, _dataArrOne)
	_onePOneRight = _make_field("onePOneRight", _onePOneRightDate, _asciiMove, _dataArrOne)
	_onePOneBomb = _make_field("onePOneBomb", _onePOneBombDate, _asciiBomb, _dataArrOne)
	# twoPOneUp ... twoPTwoBomb: not made (2-player play removed), see the class comment.


## `new MyTextField(this._ctrlField[name], this._ctrlField[name + "Mc"], data, ascii,
## dataArr, this._soundManger, this._ctrlField)`.
func _make_field(name: String, data: Array, ascii: Dictionary, data_arr: Array) -> MyTextField:
	var field := MyTextField.new(self, _ctrlField + "/" + name, _ctrlField + "/" + name + "Mc", data, ascii, data_arr)
	_text_fields.append(field)
	return field


## `backHandle`
func backHandle(_t: String) -> void:
	if not _haveSave:
		saveDefaultData()
	else:
		saveKeys()
	_app.show_main_menu()  # UIEvent.CHANGE_BACK -> UIManager.changeBack
	_sound("menuPress")
	destroy()


## `saveDefaultData`: GameModel gets the keys the screen opened with (`Keydefault` also
## writes them back into the lists). GameModel's 2P keys have no counterpart.
func saveDefaultData() -> void:
	_set_game_model([_onePOneUp.Keydefault, _onePOneLeft.Keydefault, _onePOneDown.Keydefault,
		_onePOneRight.Keydefault, _onePOneBomb.Keydefault])


## `backOverHandle`
func backOverHandle(_t: String) -> void:
	_sound("menuTouch")


## `saveHandle`
func saveHandle(_t: String) -> void:
	_haveSave = true
	saveKeys()
	_mc.set_frame(_messenge, 4)
	_sound("menuPress")


## `defauleHandle`
func defauleHandle(_t: String) -> void:
	defauleData()
	_mc.set_frame(_messenge, 1)
	_sound("menuPress")


## `keyDown` (UIEvent.KEY_DOWN on ctrlField)
func keyDown() -> void:
	_mc.set_frame(_messenge, 2)


## `keyErroe` (UIEvent.KEY_ERROR on ctrlField)
func keyErroe() -> void:
	_mc.set_frame(_messenge, 3)


## `keyNormal` (UIEvent.KEY_NORMAL on ctrlField)
func keyNormal() -> void:
	_mc.set_frame(_messenge, 1)


## `defauleData`
func defauleData() -> void:
	reInitData()
	_onePOneUp.setDefault()
	_onePOneDown.setDefault()
	_onePOneLeft.setDefault()
	_onePOneRight.setDefault()
	_onePOneBomb.setDefault()


## `reInitData`: the lists keep their identity (`splice(0)` then `push`), so the caps see
## the new keys.
func reInitData() -> void:
	var lists: Array = [_onePOneUpDate, _onePOneLeftDate, _onePOneDownDate, _onePOneRightDate, _onePOneBombDate,
		_twoPOneUpDate, _twoPOneLeftDate, _twoPOneDownDate, _twoPOneRightDate, _twoPOneBombDate,
		_twoPTwoUpDate, _twoPTwoLeftDate, _twoPTwoDownDate, _twoPTwoRightDate, _twoPTwoBombDate]
	for list: Array in lists: list.clear()
	_dataArrOne.clear()
	_dataArrTwo.clear()
	_dataArrTotal.clear()
	for i in lists.size(): lists[i].append(DEFAULT_KEYS[i])
	_dataArrOne.append_array([_onePOneUpDate, _onePOneLeftDate, _onePOneDownDate, _onePOneRightDate, _onePOneBombDate, 80])
	_dataArrTwo.append_array([_twoPOneUpDate, _twoPOneLeftDate, _twoPOneDownDate, _twoPOneRightDate, _twoPOneBombDate,
		_twoPTwoUpDate, _twoPTwoLeftDate, _twoPTwoDownDate, _twoPTwoRightDate, _twoPTwoBombDate, 80])
	_dataArrTotal.append_array(lists + [80])


## `powerUpsHandle`
func powerUpsHandle(_t: String) -> void:
	saveKeys()
	_app.show_power_ups()  # UIEvent.POWER_UPS -> UIManager.powerUps
	_sound("menuPress")
	destroy()


## `powerUpsOverHandle`
func powerUpsOverHandle(_t: String) -> void:
	_sound("menuTouch")


## `saveKeys`: GameModel, then the SharedObject `key` array (flush). Only the 1P keys have
## somewhere to go: the store holds no 2P keys.
func saveKeys() -> void:
	_set_game_model([onePOneUpDate, onePOneLeftDate, onePOneDownDate, onePOneRightDate, onePOneBombDate])
	_app.store.save_file()  # _loc1_.data["key"] = _loc2_; flush(); close()


## `GameModel.onePOne<Action>Date = ...`: the bindings the game reads (`app.store.keys`),
## as Godot keys. A Flash code with no Godot key becomes KEY_NONE.
func _set_game_model(codes: Array) -> void:
	for i in ONE_P_ACTIONS.size():
		_app.store.keys[ONE_P_ACTIONS[i]] = FlashKeys.to_godot(int(codes[i]))


## `get onePOneUpDate` ... `get onePOneBombDate`
var onePOneUpDate: int:
	get: return _onePOneUpDate[0]
var onePOneLeftDate: int:
	get: return _onePOneLeftDate[0]
var onePOneRightDate: int:
	get: return _onePOneRightDate[0]
var onePOneDownDate: int:
	get: return _onePOneDownDate[0]
var onePOneBombDate: int:
	get: return _onePOneBombDate[0]


## `get messenge`
var messenge: String:
	get: return _messenge


## `AbstractUI.destroy`: delListener, delData, delView (the app removes the screen;
## `Button.destroy` drops each button's listeners).
func destroy() -> void:
	delListener()
	for button in simpleButtons: button.destroy()
	simpleButtons = []
	for field in _text_fields: field.destroy()
	# delView nulls the fields; each holds this UI, so keeping them would be a cycle.
	_text_fields.clear()
	_onePOneUp = null
	_onePOneLeft = null
	_onePOneDown = null
	_onePOneRight = null
	_onePOneBomb = null
	if _mc.mouse_event.is_connected(_mouseFocusChange): _mc.mouse_event.disconnect(_mouseFocusChange)
	if _mc.stage_down.is_connected(_stageFocusHandle): _mc.stage_down.disconnect(_stageFocusHandle)
	if _mc.key_down.is_connected(_stageKeyHandle): _mc.key_down.disconnect(_stageKeyHandle)
	_focus = null


## Flash focus on a press: the pressed instance takes focus (AVM2 moves focus to any
## pressed InteractiveObject); a cap that loses it gets FOCUS_OUT. Runs before the press's
## MOUSE_DOWN handlers.
func _mouseFocusChange(instance: String, kind: StringName) -> void:
	if kind != &"down": return
	_down_press = _mc.press_count
	var pressed: MyTextField = null
	for field in _text_fields:
		if field.matches(instance): pressed = field
	_setFocus(pressed)


## A press no instance heard (the stage or plain art) also takes focus off a cap.
func _stageFocusHandle(press: int) -> void:
	if press != _down_press: _setFocus(null)


func _setFocus(field: MyTextField) -> void:
	if field == _focus: return
	var old := _focus
	_focus = field
	if old != null: old.onePOneUpFocusHandle()


## KeyboardEvent.KEY_DOWN goes to the focused object: only the focused cap, and only once
## its own MOUSE_DOWN has added its key listener.
func _stageKeyHandle(keycode: int) -> void:
	if _focus != null and _focus.listening: _focus.onePOneUpKeyHandle(keycode)


## Port of `zlong.bombit5.utils.MyTextField`: a key cap made of a TextField (`_text`) and
## its background clip (`_mc`), editing a one-element key list (`_data`).
class MyTextField extends RefCounted:
	var _ui
	var _text: String
	var _mc: String
	var _data: Array
	var _default: String
	var _ascii: Dictionary
	var _dataArr: Array
	var _initKey: int
	var listening := false  # KeyboardEvent.KEY_DOWN listener on _text

	## `MyTextField(param1..param7)`; the sound manager and `_listenArea` (ctrlField) are
	## reached through the owning HowToPlayUI.
	func _init(ui, text: String, mc: String, data: Array, ascii: Dictionary, data_arr: Array) -> void:
		_ui = ui
		_text = text
		_mc = mc
		_data = data
		_ascii = ascii
		_default = _ascii.get(_data[0], "")  # an unnamed key throws a TypeError in the AS3
		_initKey = _data[0]
		_ui._mc.set_text(_text, _default)
		_dataArr = data_arr
		init()

	## `init`: MOUSE_DOWN on the TextField; FOCUS_OUT comes from HowToPlayUI's focus.
	func init() -> void:
		_ui._events.add(_text, &"down", onePOneUpMouseHandle)

	func matches(instance: String) -> bool:
		return instance == _text

	## `onePOneUpMouseHandle`
	func onePOneUpMouseHandle(_t: String) -> void:
		_ui._mc.set_text(_text, "")
		_glow(true)  # this._mc.filters = [new GlowFilter(16750848,1,10,10,2)]
		listening = true  # this._text.addEventListener(KeyboardEvent.KEY_DOWN, ...)
		_ui.keyDown()  # _listenArea.dispatchEvent(new Event(UIEvent.KEY_DOWN))
		_ui._sound("menuPress")

	## `onePOneUpFocusHandle` (FocusEvent.FOCUS_OUT). The key listener stays, as in the
	## AS3, but keys only reach the focused cap.
	func onePOneUpFocusHandle() -> void:
		_glow(false)  # this._mc.filters = []
		if _ui._mc.get_text(_text) == "":
			_ui._mc.set_text(_text, _default)
		_ui.keyNormal()  # UIEvent.KEY_NORMAL

	## `onePOneUpKeyHandle`. `e.keyCode == this._dataArr[i]` compares with each one-element
	## list's key (Array to Number) and with 80, P.
	func onePOneUpKeyHandle(keyCode: int) -> void:
		for entry in _dataArr:
			var code: int = entry[0] if entry is Array else entry
			if keyCode == code:
				if keyCode != _data[0]:
					_ui.keyErroe()  # UIEvent.KEY_ERROR
					return
		# try { _data[0] = keyCode; _text.text = _ascii[keyCode]; KEY_DOWN }
		# catch (TypeError) { KEY_ERROR }: the key is stored before the name lookup fails.
		_data[0] = keyCode
		if not _ascii.has(keyCode):
			_ui.keyErroe()
			return
		_ui._mc.set_text(_text, _ascii[keyCode])
		_ui.keyDown()

	## `setDefault`
	func setDefault() -> void:
		_ui._mc.set_text(_text, _ascii.get(_data[0], ""))

	## `get Keydefault`: puts the opening key back and returns it.
	var Keydefault: int:
		get:
			_data[0] = _initKey
			return _initKey

	func destroy() -> void:
		_ui._events.remove(_text, &"down", onePOneUpMouseHandle)
		listening = false

	## GlowFilter on the cap's background clip. The screen has no filter API yet: this
	## calls `set_glow(instance, glow)` when it exists ({} clears).
	func _glow(on: bool) -> void:
		if _ui._mc.has_method("set_glow"):
			_ui._mc.set_glow(_mc, GLOW if on else {})

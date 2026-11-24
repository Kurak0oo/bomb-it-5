extends RefCounted
## Port of `zlong.bombit5.ui.GameSettingsUI` (class UI_SETTING) onto a generated screen.
## Method names follow the AS3; `GameModel` reads and writes the app's session. Quirks of
## the original are kept: `initData` shows the Cinema stage set on `choose` frame 5 while
## `stagesHandle` uses frame 2, and the levels button named five sets one level.

const ToggletButton = preload("res://scripts/ui/toggle_button.gd")
const SwfEvents = preload("res://scripts/ui/swf_events.gd")

## GameMode / GameStage values (zlong.bombit5.data) <-> the session's ids.
const MODE_TO_SESSION := {"arcade": &"arcade", "kill": &"kill", "pacMan": &"pac_man", "greenZone": &"green_zone"}
const STAGE_TO_SESSION := {"random": &"random", "BirthdayParty": &"birthday_party", "CandyFactory": &"candy_factory",
	"Cinema": &"cinema", "Zoo": &"zoo", "LuxuryStores": &"luxury_stores", "MagicLibrary": &"magic_library"}

var _mc: Node2D
var _events: RefCounted
var _app: Node
var GameModel: Dictionary
var _playArr: Array = []
var _enemiesArr: Array = []
var _levelArr: Array = []
var _mapArr: Array = []
var _difficulty: Array = []
var simpleButtons: Array = []
var _focus_press := -1


func _init(screen: Node2D, app: Node) -> void:
	_mc = screen
	_app = app
	_events = SwfEvents.new(screen)
	GameModel = _read_model()
	initView()
	initListener()
	initData()


func _read_model() -> Dictionary:
	var s = _app.session
	return {"gameMode": MODE_TO_SESSION.find_key(s.mode), "playerCount": s.get_meta("player_count", 1),
		"enemiesNum": s.enemies, "levels": s.levels, "stages": STAGE_TO_SESSION.find_key(s.stage),
		"difficulty": String(s.difficulty)}


func _write_model() -> void:
	var s = _app.session
	s.mode = MODE_TO_SESSION[GameModel.gameMode]
	s.set_meta("player_count", GameModel.playerCount)
	s.enemies = GameModel.enemiesNum
	s.levels = GameModel.levels
	s.stage = STAGE_TO_SESSION[GameModel.stages]
	s.difficulty = StringName(GameModel.difficulty)


func _sound(name: String) -> void:
	if name == "menuPress": _app.audio.menu_press()
	else: _app.audio.menu_touch()


func initView() -> void:
	for t in ["playersOne", "playersTwo"]: _playArr.append(ToggletButton.new(_mc, _events, t))
	for t in ["enemiesOne", "enemiesTwo", "enemiesThree", "enemiesZero"]: _enemiesArr.append(ToggletButton.new(_mc, _events, t))
	for t in ["levelsFive", "levelsTen", "levelsFifteen", "levelsTwenty"]: _levelArr.append(ToggletButton.new(_mc, _events, t))
	simpleButtons.append(ToggletButton.new(_mc, _events, "mapMenu"))
	_mc.set_shown("showMenu", false)  # _mc.removeChild(this._showMenu)
	_mc.set_frame("choose", 1)
	for t in ["randomStages", "restaurantStages", "basketballStages", "cinemaStages", "weddingStages",
			"mysteriousStages", "caveStages"]:
		_mapArr.append(ToggletButton.new(_mc, _events, t))
	for t in ["easy", "normal", "hard"]: _difficulty.append(ToggletButton.new(_mc, _events, t))
	simpleButtons.append(ToggletButton.new(_mc, _events, "confirm"))
	simpleButtons.append(ToggletButton.new(_mc, _events, "back"))


func initListener() -> void:
	_events.add("arcadeMode", &"down", arcadeHandle)
	_events.add("arcadeMode", &"over", arcadeOverHandle)
	_events.add("killMode", &"down", killHandle)
	_events.add("killMode", &"over", killOverHandle)
	_events.add("collectMode", &"down", collectHandle)
	_events.add("collectMode", &"over", collectOverHandle)
	_events.add("paintingMode", &"down", paintingHandle)
	_events.add("paintingMode", &"over", paintingOverHandle)
	for t in ["playersOne", "playersTwo"]: _events.add(t, &"down", playersHandle)
	for t in ["enemiesOne", "enemiesTwo", "enemiesThree", "enemiesZero"]: _events.add(t, &"down", enemiesHandle)
	for t in ["levelsFive", "levelsTen", "levelsFifteen", "levelsTwenty"]: _events.add(t, &"down", levelsHandle)
	_events.add("mapMenu", &"down", mapMenuHandle)
	_events.add("choose", &"down", mapMenuHandle)
	for t in ["randomStages", "restaurantStages", "basketballStages", "cinemaStages", "weddingStages",
			"mysteriousStages", "caveStages"]:
		_events.add(t, &"down", stagesHandle)
	for t in ["easy", "normal", "hard"]: _events.add(t, &"down", difficultyHandle)
	_events.add("confirm", &"down", confirmHandle)
	_events.add("confirm", &"over", confirmOverHandle)
	_events.add("back", &"down", backHandle)
	_events.add("back", &"over", backOverHandle)


## Selects one mode card: frame 3 for it, its over/out handlers off; the others back to
## frame 1 with their roll-over handler on (the shared head of the four mode handlers).
func _select_mode(chosen: String) -> void:
	var cards := {"arcadeMode": [arcadeOverHandle, arcadeOutHandle], "killMode": [killOverHandle, killOutHandle],
		"collectMode": [collectOverHandle, collectOutHandle], "paintingMode": [paintingOverHandle, paintingOutHandle]}
	for card in cards:
		if card == chosen:
			_mc.set_frame(card, 3)
			_events.remove(card, &"over", cards[card][0])
			_events.remove(card, &"out", cards[card][1])
		else:
			_mc.set_frame(card, 1)
			_events.add(card, &"over", cards[card][0])


func initData() -> void:
	match GameModel.gameMode:
		"arcade": _select_mode("arcadeMode")
		"kill": _select_mode("killMode")
		"pacMan": _select_mode("collectMode")  # GameMode.COLLECT_MODE in the AS3 switch
		"greenZone": _select_mode("paintingMode")  # GameMode.PAINTING_MODE in the AS3 switch
	match GameModel.playerCount:
		1:
			_playArr[0].isSelect = true
			_enemiesArr[3].enable = false
		2:
			_playArr[1].isSelect = true
			_enemiesArr[2].enable = false
			if GameModel.gameMode == "arcade": _enemiesArr[3].enable = false
	match GameModel.enemiesNum:
		0: _enemiesArr[3].isSelect = true
		1: _enemiesArr[0].isSelect = true
		2: _enemiesArr[1].isSelect = true
		3: _enemiesArr[2].isSelect = true
	match GameModel.levels:
		5: _levelArr[0].isSelect = true
		10: _levelArr[1].isSelect = true
		15: _levelArr[3].isSelect = true
		20: _levelArr[2].isSelect = true
	match GameModel.stages:
		"random": _mc.set_frame("choose", 1)
		"BirthdayParty": _mc.set_frame("choose", 7)
		"CandyFactory": _mc.set_frame("choose", 6)
		"Cinema": _mc.set_frame("choose", 5)
		"Zoo": _mc.set_frame("choose", 4)
		"LuxuryStores": _mc.set_frame("choose", 3)
		"MagicLibrary": _mc.set_frame("choose", 2)
	_events.add("mapMenu", &"down", mapMenuHandle)
	match GameModel.difficulty:
		"easy": _difficulty[0].isSelect = true
		"normal": _difficulty[1].isSelect = true
		"hard": _difficulty[2].isSelect = true


func arcadeHandle(_t: String) -> void:
	_select_mode("arcadeMode")
	if GameModel.playerCount == 2:
		if _mc.get_frame("enemiesZero") != 4: _enemiesArr[3].enable = false
		if GameModel.enemiesNum == 0:
			GameModel.enemiesNum = 1
			_enemiesArr[0].isSelect = true
	_playArr[1].enable = true
	GameModel.gameMode = "arcade"
	_sound("menuPress")
	_write_model()


func arcadeOverHandle(_t: String) -> void:
	_mc.set_frame("arcadeMode", 2)
	_events.add("arcadeMode", &"out", arcadeOutHandle)
	_sound("menuTouch")


func arcadeOutHandle(_t: String) -> void:
	_mc.set_frame("arcadeMode", 1)


func killHandle(_t: String) -> void:
	_select_mode("killMode")
	if GameModel.playerCount == 2 and _mc.get_frame("enemiesZero") == 4: _enemiesArr[3].enable = true
	_playArr[1].enable = true
	GameModel.gameMode = "kill"
	_sound("menuPress")
	_write_model()


func killOverHandle(_t: String) -> void:
	_mc.set_frame("killMode", 2)
	_events.add("killMode", &"out", killOutHandle)
	_sound("menuTouch")


func killOutHandle(_t: String) -> void:
	_mc.set_frame("killMode", 1)


func collectHandle(_t: String) -> void:
	_select_mode("collectMode")
	if GameModel.playerCount == 2:
		_enemiesArr[3].enable = false
		_enemiesArr[2].enable = true
		if _enemiesArr[3].isSelect:
			_enemiesArr[3].isSelect = false
			_enemiesArr[2].isSelect = true
		_playArr[0].isSelect = true
		_playArr[1].isSelect = false
		GameModel.playerCount = 1
	_playArr[1].enable = false
	GameModel.gameMode = "pacMan"
	_sound("menuPress")
	_write_model()


func collectOverHandle(_t: String) -> void:
	_mc.set_frame("collectMode", 2)
	_events.add("collectMode", &"out", collectOutHandle)
	_sound("menuTouch")


func collectOutHandle(_t: String) -> void:
	_mc.set_frame("collectMode", 1)


func paintingHandle(_t: String) -> void:
	_select_mode("paintingMode")
	if GameModel.playerCount == 2 and _mc.get_frame("enemiesZero") == 4: _enemiesArr[3].enable = true
	_playArr[1].enable = true
	GameModel.gameMode = "greenZone"
	_sound("menuPress")
	_write_model()


func paintingOverHandle(_t: String) -> void:
	_mc.set_frame("paintingMode", 2)
	_events.add("paintingMode", &"out", paintingOutHandle)
	_sound("menuTouch")


func paintingOutHandle(_t: String) -> void:
	_mc.set_frame("paintingMode", 1)


func playersHandle(target: String) -> void:
	for button in _playArr: button.isSelect = button.btn == target
	if target == "playersOne":
		if _mc.get_frame("enemiesZero") == 3:
			_enemiesArr[3].enable = false
			_enemiesArr[0].isSelect = true
			GameModel.enemiesNum = 1
		elif _mc.get_frame("enemiesZero") != 4:
			_enemiesArr[3].enable = false
		if _mc.get_frame("enemiesThree") == 4: _enemiesArr[2].enable = true
		GameModel.playerCount = 1
	else:
		if _mc.get_frame("enemiesThree") == 3:
			_enemiesArr[2].enable = false
			_enemiesArr[1].isSelect = true
			GameModel.enemiesNum = 2
		elif _mc.get_frame("enemiesThree") != 4:
			_enemiesArr[2].enable = false
		if GameModel.gameMode != "arcade" and _mc.get_frame("enemiesZero") == 4: _enemiesArr[3].enable = true
		GameModel.playerCount = 2
	_sound("menuPress")
	_write_model()


func enemiesHandle(target: String) -> void:
	var enabled := true
	for button in _enemiesArr:
		if button.btn == target: enabled = button.enable
	if enabled:
		for button in _enemiesArr:
			if button.btn == target and button.enable:
				button.isSelect = true
				match target:
					"enemiesThree": GameModel.enemiesNum = 3
					"enemiesTwo": GameModel.enemiesNum = 2
					"enemiesOne": GameModel.enemiesNum = 1
					"enemiesZero": GameModel.enemiesNum = 0
				_sound("menuPress")
			elif button.enable:
				button.isSelect = false
	_write_model()


func levelsHandle(target: String) -> void:
	for button in _levelArr:
		if button.btn == target:
			button.isSelect = true
			match target:
				"levelsFive": GameModel.levels = 1
				"levelsTen": GameModel.levels = 10
				"levelsFifteen": GameModel.levels = 15
				"levelsTwenty": GameModel.levels = 20
			_sound("menuPress")
		else:
			button.isSelect = false
	_write_model()


func mapMenuHandle(_t: String) -> void:
	_mc.set_shown("showMenu", true)  # _mc.addChild(this._showMenu); stage.focus = showMenu
	_events.remove("mapMenu", &"down", mapMenuHandle)
	# FOCUS_OUT on the next press anywhere, then the root's MOUSE_DOWN closes the menu
	# (showMenuFocusHandle -> focusOutHandle): after that press's own handlers.
	_focus_press = _mc.press_count
	if not _mc.stage_down.is_connected(showMenuFocusHandle): _mc.stage_down.connect(showMenuFocusHandle)
	_sound("menuPress")


func showMenuFocusHandle(press: int) -> void:
	if press <= _focus_press: return  # the press that opened the menu
	_mc.stage_down.disconnect(showMenuFocusHandle)
	focusOutHandle()


func focusOutHandle() -> void:
	_mc.set_shown("showMenu", false)
	_events.add("mapMenu", &"down", mapMenuHandle)


func stagesHandle(target: String) -> void:
	for button in _mapArr:
		if button.btn == target:
			button.isSelect = true
			match target:
				"randomStages":
					_mc.set_frame("choose", 1)
					GameModel.stages = "random"
				"restaurantStages":
					_mc.set_frame("choose", 7)
					GameModel.stages = "BirthdayParty"
				"basketballStages":
					_mc.set_frame("choose", 6)
					GameModel.stages = "CandyFactory"
				"cinemaStages":
					_mc.set_frame("choose", 2)
					GameModel.stages = "Cinema"
				"weddingStages":
					_mc.set_frame("choose", 5)
					GameModel.stages = "Zoo"
				"mysteriousStages":
					_mc.set_frame("choose", 4)
					GameModel.stages = "LuxuryStores"
				"caveStages":
					_mc.set_frame("choose", 3)
					GameModel.stages = "MagicLibrary"
			_sound("menuPress")
		else:
			button.isSelect = false
	_events.add("mapMenu", &"down", mapMenuHandle)
	_write_model()


func difficultyHandle(target: String) -> void:
	for button in _difficulty:
		if button.btn == target:
			button.isSelect = true
			GameModel.difficulty = {"easy": "easy", "normal": "normal", "hard": "hard"}[target]
			_sound("menuPress")
		else:
			button.isSelect = false
	_write_model()


func confirmHandle(_t: String) -> void:
	_close_menu()
	_sound("menuPress")
	_app.show_character_select()  # UIEvent.SELECT_CHARACTER


func confirmOverHandle(_t: String) -> void:
	_sound("menuTouch")


func backHandle(_t: String) -> void:
	_close_menu()
	_sound("menuPress")
	_app.show_main_menu()  # UIEvent.CHANGE_BACK


func backOverHandle(_t: String) -> void:
	_sound("menuTouch")


func _close_menu() -> void:
	if _mc.is_shown("showMenu"):
		_mc.set_shown("showMenu", false)
		if _mc.stage_down.is_connected(showMenuFocusHandle): _mc.stage_down.disconnect(showMenuFocusHandle)

extends RefCounted
## Port of `zlong.bombit5.ui.unlockCloth.ClothesPanel`: the hats and outfits of one robot on
## character select. Its art (`Attach.getSprite("Art_clothPanel" + robotId)`) is the hidden
## `Art_clothPanel<N>` instance of the generated screen; `addChild` / `removeChild` /
## `visible` become `set_shown`. Icon frames: 1 up, 2 over, 3 worn, 4 worn and over,
## 5 locked, 6 locked and over.
##
## Unlocks (`Cookie.instance.isClothEnable(robot, i)` / `isHatEnable(robot, i)`): the Cookie
## keeps `avatar.robot<r>.icon<i>` / `hat<i>` flags, set by `Cookie.unlockAvatar(r, n)` through
## the unlock XML (`sets id = r + 1`, `set index = n` -> id `icon<i>` or `hat<i>`). The app
## keeps the look numbers n instead: `store.unlocks[str(r)]`, and `Looks.LOOKS[r][n - 1]` is
## the XML's set as [&"body" (icon) | &"hat", i]. So `isClothEnable(r, i)` is
## `Looks.number(r, &"body", i) in store.unlocks[str(r)]`, and the XML lookup
## `_xmlNode.set.(@id == dressName).@index` is `Looks.number(r, kind, i)`.

## `ChangeClothEvent.CHANGE_CLOTH` / `CHANGE_HAT` (`avatarId`). Nothing listens to them on
## character select; kept for the port.
signal CHANGE_CLOTH(avatarId: int)
signal CHANGE_HAT(avatarId: int)

const Looks = preload("res://scripts/looks.gd")

## `GameConfig.CHEAT_UNLOCK_ALL_CLOTHES` (false) and `Root.PORTAL_TYPE`
## (`PortalType.PORTAL_TYPE_TWEEN`, "tween") in this build: neither unlocks everything.
const CHEAT_UNLOCK_ALL_CLOTHES := false
const PORTAL_TYPE := "tween"

var _pmc: Node2D
var _events: RefCounted
var _app: Node
var _mc: String
var _robotsMc: String
var _singleRobotMc: String
var _clothMc: String
var _robotId: int
var _iconsBody: Array = []
var _iconsHat: Array = []
var _selectedBodyIcon := ""
var _selectedHatIcon := ""
var _curSelectClothId := 0
var _curSelectHatId := 0
var _visible := false
var _hatMc: String
## The address of the clip `pmc` stands for, when it is not the screen's own clip (the
## unlock tip's `containerMc`); empty on character select.
var _pmcPath := ""


## `ClothesPanel(pmc, robotId, robotsMc, soundManager)`. `robotsMc` is the address of the
## stage's `robotMc` clip; `app` stands in for the `SoundManger` (and the Cookie).
## `XmlManager.unlockDress` is read through `Looks` (see the header). `pmcPath` addresses
## `pmc` inside the screen when it is a child clip (UnlockTipScreen's `containerMc`).
func _init(pmc: Node2D, events: RefCounted, robotId: int, robotsMc: String, app: Node, pmcPath := "") -> void:
	_pmc = pmc
	_pmcPath = pmcPath
	_events = events
	_app = app
	_robotId = robotId
	_robotsMc = robotsMc
	# `_robotsMc.addFrameScript(_robotId, onGetRobotHandler)` then `gotoAndStop(robotId + 1)`:
	# the frame script runs as part of the goto (the AS3 relies on it: `toDressView` sets
	# `visible` on the panel right after construction), so it is called directly here.
	_pmc.set_frame(_robotsMc, robotId + 1)
	onGetRobotHandler()


func _sound(name: String) -> void:
	if name == "menuPress": _app.audio.menu_press()
	else: _app.audio.menu_touch()


## `onGetRobotHandler`: the robot clip on its frame, and its outfit and hat clips.
func onGetRobotHandler() -> void:
	_singleRobotMc = _robotsMc + "/robot" + str(_robotId)
	_clothMc = _singleRobotMc + "/bodyMc"
	_hatMc = _singleRobotMc + "/hatMc"
	if not _pmc.has_instance(_hatMc):
		_hatMc = _singleRobotMc + "/head/hatMc"
	init()


## `destroy`
func destroy() -> void:
	delEvents()
	delDis()
	_singleRobotMc = ""
	_robotsMc = ""


## `init`
func init() -> void:
	initDis()
	initEvents()
	initSetting()


## `initDis`: shows the robot's panel and sets each hat and outfit icon to up (1) or locked (5).
func initDis() -> void:
	_mc = ("" if _pmcPath.is_empty() else _pmcPath + "/") + "Art_clothPanel" + str(_robotId)
	# `Root.__lockContent__` is false in this build and there is no portal login, so the
	# `login_to_unlock` overlay is never added.
	_pmc.set_shown(_mc, true)  # this._pmc.addChild(this._mc)
	_iconsBody = []
	_iconsHat = []
	_init_icons("icon", &"body", _iconsBody)
	_init_icons("hat", &"hat", _iconsHat)


## The two identical loops of `initDis` (`icon1`-`icon6`, then `hat1`-`hat6`).
func _init_icons(prefix: String, kind: StringName, icons: Array) -> void:
	var i := 1
	while i < 7:
		var dressName := prefix + str(i)
		var tempIcon := _mc + "/" + dressName
		if not _pmc.has_instance(tempIcon):
			break
		# `new icon_dress()` named "dress_icon", added to the icon, hidden; `buttonMode`.
		_pmc.set_shown(tempIcon + "/dress_icon", false)
		icons.append(tempIcon)
		# `infoPanel.infoText.getChildAt(0)` (multiline, word wrap); the info panel takes no mouse.
		var infoPanel := tempIcon + "/infoPanel"
		_pmc.set_enabled(infoPanel, false)
		var textField := infoPanel + "/infoText"
		var unlock_text: String = _pmc.get_text(textField) if _pmc.has_method("get_text") else ""
		var scoreIndex := Looks.number(_robotId, kind, i)
		# Quirk kept: `indexOf` is truthy for -1 and false only at index 0, so "[x]" is
		# replaced unless the text starts with it. `String.replace` replaces the first match.
		if unlock_text.find("[x]") != 0:
			unlock_text = _replace_first(unlock_text, "[x]", _unlock_score(scoreIndex))
		elif unlock_text.find("[X]") != 0:
			unlock_text = _replace_first(unlock_text, "[X]", _unlock_score(scoreIndex))
		# TODO(live text): textField.text = unlock_text (the screen cannot set text yet).
		var enable := isClothEnable(_robotId, i) if kind == &"body" else isHatEnable(_robotId, i)
		if enable or CHEAT_UNLOCK_ALL_CLOTHES or PORTAL_TYPE == "china":
			_pmc.set_frame(tempIcon, 1)
		else:
			_pmc.set_frame(tempIcon, 5)
		i += 1


## `GameConfig["UNLOCK_SCORE_" + scoreIndex]` as text ("undefined" for a missing constant).
static func _unlock_score(scoreIndex: int) -> String:
	if scoreIndex >= 1 and scoreIndex <= Looks.THRESHOLDS.size():
		return str(Looks.THRESHOLDS[scoreIndex - 1])
	return "undefined"


static func _replace_first(text: String, what: String, forwhat: String) -> String:
	var at := text.find(what)
	if at < 0: return text
	return text.substr(0, at) + forwhat + text.substr(at + what.length())


## `Cookie.instance.isClothEnable(robot, i)`: outfit `icon<i>` unlocked (see the header).
func isClothEnable(robot: int, i: int) -> bool:
	return Looks.number(robot, &"body", i) in _app.store.unlocks.get(str(robot), [])


## `Cookie.instance.isHatEnable(robot, i)`: hat `hat<i>` unlocked (see the header).
func isHatEnable(robot: int, i: int) -> bool:
	return Looks.number(robot, &"hat", i) in _app.store.unlocks.get(str(robot), [])


## `delDis`
func delDis() -> void:
	_iconsBody = []
	_iconsHat = []
	_pmc.set_shown(_mc, false)  # this._pmc.removeChild(this._mc)
	_mc = ""


## `initEvents` (ROLL_OVER, ROLL_OUT, CLICK on every icon)
func initEvents() -> void:
	for icon: String in _iconsBody + _iconsHat:
		_events.add(icon, &"over", onOverIcon)
		_events.add(icon, &"out", onOutIcon)
		_events.add(icon, &"click", onClickIcon)


## `delEvents`
func delEvents() -> void:
	for icon: String in _iconsBody + _iconsHat:
		_events.remove(icon, &"over", onOverIcon)
		_events.remove(icon, &"out", onOutIcon)
		_events.remove(icon, &"click", onClickIcon)


## `initSetting`: a new panel always starts bare (outfit 0, hat 0).
func initSetting() -> void:
	_curSelectClothId = 0
	_curSelectHatId = 0
	selectCloth(_curSelectClothId)
	selectHat(_curSelectHatId)


## `selectCloth`
func selectCloth(id: int) -> void:
	_pmc.set_frame(_clothMc, id + 1)


## `selectHat`
func selectHat(id: int) -> void:
	_pmc.set_frame(_hatMc, id + 1)


## `changeCloth`
func changeCloth(clothId: int, hatId: int) -> void:
	CHANGE_CLOTH.emit(clothId)
	CHANGE_HAT.emit(hatId)
	_curSelectClothId = clothId
	_curSelectHatId = hatId
	selectCloth(_curSelectClothId)
	selectHat(_curSelectHatId)
	if _selectedBodyIcon != "":
		_pmc.set_frame(_selectedBodyIcon, 1)
		_pmc.set_shown(_selectedBodyIcon + "/dress_icon", false)
	if _selectedHatIcon != "":
		_pmc.set_frame(_selectedHatIcon, 1)
		_pmc.set_shown(_selectedHatIcon + "/dress_icon", false)
	if _curSelectClothId != 0:
		_pmc.set_frame(_iconsBody[_curSelectClothId - 1], 3)
		_selectedBodyIcon = _iconsBody[_curSelectClothId - 1]
		_pmc.set_shown(_selectedBodyIcon + "/dress_icon", true)
	if _curSelectHatId != 0:
		_pmc.set_frame(_iconsHat[_curSelectHatId - 1], 3)
		_selectedHatIcon = _iconsHat[_curSelectHatId - 1]
		_pmc.set_shown(_selectedHatIcon + "/dress_icon", true)


## `onOverIcon` (the touch sound plays on every roll-over, locked icons too)
func onOverIcon(target: String) -> void:
	var frame: int = _pmc.get_frame(target)
	if frame == 1:
		_pmc.set_frame(target, 2)
	elif frame == 3:
		_pmc.set_frame(target, 4)
		_pmc.set_shown(target + "/dress_icon", false)
	elif frame == 5:
		_pmc.set_frame(target, 6)
	_sound("menuTouch")


## `onOutIcon`
func onOutIcon(target: String) -> void:
	var frame: int = _pmc.get_frame(target)
	if frame == 2:
		_pmc.set_frame(target, 1)
	elif frame == 4:
		_pmc.set_frame(target, 3)
		_pmc.set_shown(target + "/dress_icon", true)
	elif frame == 6:
		_pmc.set_frame(target, 5)


## `onClickIcon`: wears the clicked look, or takes it off when it is worn.
func onClickIcon(target: String) -> void:
	var frame: int = _pmc.get_frame(target)
	if frame == 5 or frame == 6:
		return
	var name := target.get_file()  # the instance name: `icon<i>` or `hat<i>`
	if name.find("icon") != -1:
		if _selectedBodyIcon != "" and _selectedBodyIcon != target:
			_pmc.set_frame(_selectedBodyIcon, 1)
			_pmc.set_shown(_selectedBodyIcon + "/dress_icon", false)
		if frame == 3 or frame == 4:
			_curSelectClothId = 0
			_pmc.set_frame(target, 2)
			_pmc.set_shown(target + "/dress_icon", false)
			CHANGE_CLOTH.emit(_curSelectClothId)
		else:
			_curSelectClothId = name.substr(4).to_int()  # parseInt(name.substr(4))
			_pmc.set_frame(target, 4)
			_pmc.set_shown(target + "/dress_icon", true)
			CHANGE_CLOTH.emit(_curSelectClothId)
		_selectedBodyIcon = target
		selectCloth(_curSelectClothId)
	else:
		if _selectedHatIcon != "" and _selectedHatIcon != target:
			_pmc.set_frame(_selectedHatIcon, 1)
			_pmc.set_shown(_selectedHatIcon + "/dress_icon", false)
		if frame == 3 or frame == 4:
			_curSelectHatId = 0
			_pmc.set_frame(target, 2)
			CHANGE_HAT.emit(_curSelectHatId)
			_pmc.set_shown(target + "/dress_icon", false)
		else:
			_curSelectHatId = name.right(1).to_int()  # parseInt(name.substr(-1, 1))
			_pmc.set_frame(target, 4)
			_pmc.set_shown(target + "/dress_icon", true)
			CHANGE_HAT.emit(_curSelectHatId)
		_selectedHatIcon = target
		selectHat(_curSelectHatId)
	# TODO(play): `_singleRobotMc.gotoAndPlay(1)` restarts the robot's animation; the screen
	# has `set_frame` (gotoAndStop) only, which would freeze the clip, so it is left out.
	_sound("menuPress")


## `get robotId`
var robotId: int:
	get: return _robotId


## `get clothId`
var clothId: int:
	get: return _curSelectClothId


## `get hatId`
var hatId: int:
	get: return _curSelectHatId


## `set x` / `set y`: CharacterSelectUI places the panel at (212, 240). The generated
## layout already places `Art_clothPanel<N>` where the capture shows it, so these are not
## ported (no typed-in coordinates).


## `set visible`
var visible: bool:
	get: return _visible
	set(value):
		_visible = value
		_pmc.set_shown(_mc, value)

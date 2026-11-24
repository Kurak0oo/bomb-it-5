extends RefCounted
## Port of `zlong.bombit5.ui.CharacterSelectUI` (class UI_SELECTCHARACTER) onto a generated
## screen. Method names follow the AS3; `GameModel.P1Robot / P1ClothId / P1HatId` are the
## app session's `robot / body / hat`.
##
## One player only: the owner removed 2-player play, so `GameModel.playerCount` is always 1.
## The 1P branches are kept; the 2P-only branches of `initData` and `startFunc` are dropped
## (marked where they were). `robotStage2` and `tagP2` stay hidden, so the stage-2 parts of
## `onClickRobotStage` cannot run; they are kept as written.
## Quirk kept: the screen always opens on robot 0 bare (`initData` selects icon 0 and every
## new `ClothesPanel` starts at outfit 0, hat 0), whatever the session held before.

const UtilsButton = preload("res://scripts/ui/button.gd")  # zlong.bombit5.utils.Button
const ClothesPanel = preload("res://scripts/ui/clothes_panel.gd")
const SwfEvents = preload("res://scripts/ui/swf_events.gd")

var _mc: Node2D
var _events: RefCounted
var _app: Node
var GameModel := {"playerCount": 1}
var simpleButtons: Array = []
var _startBt := ""
var _backBt := ""
var _setAvatarBt := ""
var _tagP2 := ""
var _robotStage1 := ""
var _robotStage2 := ""
var _robotMc1 := ""
var _robotMc2 := ""
var _clothesPanel: ClothesPanel
var _p1RobotId := -1
var _p2RobotId := -1
var _isCur1P := true
var _robotIconsArr: Array = []


## `CharacterSelectUI(root, soundManager)`: `AbstractUI` runs init, initView, initListener,
## initData; then `toDressView`.
func _init(screen: Node2D, app: Node) -> void:
	_mc = screen  # init: setMC("UI_SELECTCHARACTER")
	_app = app
	_events = SwfEvents.new(screen)
	initView()
	initListener()
	initData()
	toDressView()


func _sound(name: String) -> void:
	if name == "menuPress": _app.audio.menu_press()
	else: _app.audio.menu_touch()


## `initView`
func initView() -> void:
	_startBt = "startBtn"
	simpleButtons.append(UtilsButton.new(_mc, _events, _startBt))
	_backBt = "backBtn"
	simpleButtons.append(UtilsButton.new(_mc, _events, _backBt))
	_setAvatarBt = "setAvatarBt"
	simpleButtons.append(UtilsButton.new(_mc, _events, _setAvatarBt))
	# `_setAvatarBt.visible = GamatarSender.showAvatarButton`: false in this build (no portal
	# avatars), so SET AS AVATAR stays hidden and inert.
	_mc.set_shown(_setAvatarBt, false)
	_robotStage1 = "robotStage1"
	_robotStage2 = "robotStage2"
	_robotMc1 = _robotStage1 + "/robotMc"
	_robotMc2 = _robotStage2 + "/robotMc"
	# `buttonMode = true` on both stages: the hand cursor only.
	_tagP2 = "tagP2"
	# `_dressBtn`, `_infoBtn`, `_infoPanel` are fresh `new MovieClip()`s never added to the
	# display list: they cannot be seen or clicked, so they are not ported.
	initRobotIcons()


## `initListener`
func initListener() -> void:
	_events.add(_startBt, &"down", startHandle)
	_events.add(_startBt, &"over", startOverHandle)
	_events.add(_backBt, &"down", backHandle)
	_events.add(_backBt, &"over", backOverHandle)
	_events.add(_setAvatarBt, &"down", setAvatarHandle)
	_events.add(_setAvatarBt, &"over", setAvatarOverHandle)
	# `_infoBtn` / `_dressBtn` MOUSE_DOWN: off-stage clips (see initView), never fire.
	for icon: String in _robotIconsArr:
		_events.add(icon, &"over", onRollOverIcon)
		_events.add(icon, &"out", onRollOutIcon)
		_events.add(icon, &"click", onClickIcon)
	for stage: String in [_robotStage1, _robotStage2]:
		_events.add(stage, &"over", onOverRobotStage)
		_events.add(stage, &"out", onOutRobotStage)
		_events.add(stage, &"click", onClickRobotStage)


## `onDressBtnDownHandler` (empty in the AS3)
func onDressBtnDownHandler(_t: String) -> void:
	pass


## `onInfoBtnDownHandler`
func onInfoBtnDownHandler(_t: String) -> void:
	toDressView()


## `toDressView` (only the panel is a real clip; see initView)
func toDressView() -> void:
	_clothesPanel.visible = true


## `toInfoView` (never called in the AS3)
func toInfoView() -> void:
	_clothesPanel.visible = false


## `delListener`
func delListener() -> void:
	delCLothPanel()
	for stage: String in [_robotStage1, _robotStage2]:
		_events.remove(stage, &"over", onOverRobotStage)
		_events.remove(stage, &"out", onOutRobotStage)
		_events.remove(stage, &"click", onClickRobotStage)
	for icon: String in _robotIconsArr:
		_events.remove(icon, &"over", onRollOverIcon)
		_events.remove(icon, &"out", onRollOutIcon)
		_events.remove(icon, &"click", onClickIcon)
	_events.remove(_startBt, &"down", startHandle)
	_events.remove(_startBt, &"over", startOverHandle)
	_events.remove(_backBt, &"down", backHandle)
	_events.remove(_backBt, &"over", backOverHandle)
	_events.remove(_setAvatarBt, &"down", setAvatarHandle)
	_events.remove(_setAvatarBt, &"over", setAvatarOverHandle)


## `initData`
func initData() -> void:
	if GameModel.playerCount == 1:
		selectRobotIcon(0, true)
		_mc.set_shown(_robotStage2, false)  # _robotStage2.visible = false
		_mc.set_shown(_tagP2, false)  # _tagP2.visible = false
	# else (2 players: icon 1 for P2, both stages and tagP2 shown): dropped, 1P only.
	setCurStage(true)


## `initRobotIcons`
func initRobotIcons() -> void:
	_robotIconsArr = []
	for i in 8:
		var icon := "robotIcon" + str(i)  # _mc.getChildByName("robotIcon" + i); buttonMode
		_mc.set_frame(icon, 1)
		_robotIconsArr.append(icon)
	_p1RobotId = -1
	_p2RobotId = -1


## `selectRobotIcon(robotId, isP1)`: frame 3 marks P1's robot, frame 4 P2's.
func selectRobotIcon(robotId: int, isP1: bool) -> bool:
	var result := true
	if robotId == _p1RobotId or robotId == _p2RobotId:
		result = false
	else:
		if isP1:
			if _p1RobotId != -1:
				_mc.set_frame(_robotIconsArr[_p1RobotId], 1)
			_mc.set_frame(_robotIconsArr[robotId], 3)
			_p1RobotId = robotId
			setRobotClothPanel(robotId, true)
		else:
			if _p2RobotId != -1:
				_mc.set_frame(_robotIconsArr[_p2RobotId], 1)
			_mc.set_frame(_robotIconsArr[robotId], 4)
			_p2RobotId = robotId
			setRobotClothPanel(robotId, false)
		result = true
	return result


## `setRobotClothPanel`
func setRobotClothPanel(robotId: int, isP1: bool) -> void:
	var robotsMc := _robotMc1 if isP1 else _robotMc2
	changeRobotCloth(robotId, robotsMc)


## `changeRobotCloth`
func changeRobotCloth(robotId: int, robotsMc: String) -> void:
	delCLothPanel()
	initClothPanel(robotId, robotsMc)


## `initClothPanel`. `_clothesPanel.x = 212; y = 240` is not ported: the generated layout
## places `Art_clothPanel<N>` (see ClothesPanel `set x` / `set y`).
func initClothPanel(robotId: int, robotsMc: String) -> void:
	_clothesPanel = ClothesPanel.new(_mc, _events, robotId, robotsMc, _app)


## `delCLothPanel`
func delCLothPanel() -> void:
	if _clothesPanel:
		_clothesPanel.destroy()
		_clothesPanel = null


## `setCurStage`: frame 3 marks the stage being dressed.
func setCurStage(isP1: bool) -> void:
	_isCur1P = isP1
	if _isCur1P:
		_mc.set_frame(_robotStage1, 3)
		_mc.set_frame(_robotStage2, 1)
	else:
		_mc.set_frame(_robotStage1, 1)
		_mc.set_frame(_robotStage2, 3)


## `startFunc`: P1's robot and look into the session, then GAME_START.
## The AS3 then draws P2 (for one player), P3 and P4 from the other seven robots with
## `Math.random`; the session draws the AI robots (and their looks) in `begin()`, called by
## `app.start_session()`, so that draw replaces this one. (The session's RNG is not the
## Flash `Math.random` port, `avm_random.gd`; the session would need to take its draws from
## an AvmRandom to match the original's sequence.)
## The 2P branch (P2Robot, P2ClothId, P2HatId from stage 2) is dropped: 1P only.
func startFunc() -> void:
	var s = _app.session
	s.robot = _p1RobotId  # GameModel.P1Robot
	s.body = robot1ClothId  # GameModel.P1ClothId
	s.hat = robot1HatId  # GameModel.P1HatId
	_app.start_session()  # _root.dispatchEvent(new Event(UIEvent.GAME_START))
	destroy()  # the screen is only queued for freeing, so destroy can still reach it


## `initSetAvatarScreen` / `delSetAvatarScreen` / `onCloseSetAvatarHandler`: the `SetAvatar`
## screen uploads a portal avatar (`GamatarSender`); it does not exist in this build and its
## button is hidden, so they are not ported.


## `onRollOverIcon`
func onRollOverIcon(target: String) -> void:
	var frame: int = _mc.get_frame(target)
	if frame != 3 and frame != 4:
		_mc.set_frame(target, 2)
		_sound("menuTouch")


## `onRollOutIcon`
func onRollOutIcon(target: String) -> void:
	var frame: int = _mc.get_frame(target)
	if frame != 3 and frame != 4:
		_mc.set_frame(target, 1)


## `onClickIcon`
func onClickIcon(target: String) -> void:
	var frame: int = _mc.get_frame(target)
	if frame != 3 and frame != 4:
		var robotId := target.substr(9).to_int()  # parseInt(name.substr(9)) of "robotIcon<N>"
		selectRobotIcon(robotId, _isCur1P)
		_sound("menuPress")


## `startHandle`. The AS3 plays the sound after `startFunc` has dispatched GAME_START; the
## order is kept.
func startHandle(_t: String) -> void:
	var app := _app
	startFunc()
	app.audio.menu_press()  # createSound("menuPress")


## `startOverHandle`
func startOverHandle(_t: String) -> void:
	_sound("menuTouch")


## `backHandle`: GAME_SETTING, the sound, then `destroy` (kept in this order).
func backHandle(_t: String) -> void:
	var app := _app
	app.show_settings()  # _root.dispatchEvent(new Event(UIEvent.GAME_SETTING))
	app.audio.menu_press()  # createSound("menuPress")
	destroy()


## `backOverHandle`
func backOverHandle(_t: String) -> void:
	_sound("menuTouch")


## `setAvatarHandle`: would open `SetAvatar` (`initSetAvatarScreen`); inert, the button is
## hidden in this build.
func setAvatarHandle(_t: String) -> void:
	pass


## `setAvatarOverHandle`: inert with its hidden button.
func setAvatarOverHandle(_t: String) -> void:
	pass


## `onOverRobotStage`
func onOverRobotStage(target: String) -> void:
	if _mc.get_frame(target) != 3:
		_sound("menuTouch")
		_mc.set_frame(target, 2)


## `onOutRobotStage`
func onOutRobotStage(target: String) -> void:
	if _mc.get_frame(target) != 3:
		_mc.set_frame(target, 1)


## `onClickRobotStage`. With one player `robotStage1` always sits on frame 3 and
## `robotStage2` is hidden, so this never acts; kept as written.
func onClickRobotStage(target: String) -> void:
	if _mc.get_frame(target) != 3:
		_sound("menuPress")
		_mc.set_frame(target, 3)
		if target == _robotStage1:
			var clothId := robot1ClothId
			var hatId := robot1HatId
			setCurStage(true)
			setRobotClothPanel(_p1RobotId, _isCur1P)
			_clothesPanel.changeCloth(clothId, hatId)
		elif target == _robotStage2:
			var clothId := robot2ClothId
			var hatId := robot2HatId
			setCurStage(false)
			setRobotClothPanel(_p2RobotId, _isCur1P)
			_clothesPanel.changeCloth(clothId, hatId)


## `AbstractUI.destroy`: delListener, delData (empty), delView (`simpleButtons` destroyed;
## the screen itself is removed by the app when it opens the next one).
func destroy() -> void:
	delListener()
	for button in simpleButtons: button.destroy()
	simpleButtons = []


## `get robot1ClothId`: the outfit is the frame of the robot's `bodyMc`, less one.
var robot1ClothId: int:
	get: return _mc.get_frame(_robotMc1 + "/robot" + str(_p1RobotId) + "/bodyMc") - 1


## `get robot1HatId`: `head/hatMc` when the robot has a head clip, else `hatMc`.
var robot1HatId: int:
	get: return _hat_id(_robotMc1, _p1RobotId)


## `get robot2ClothId`
var robot2ClothId: int:
	get: return _mc.get_frame(_robotMc2 + "/robot" + str(_p2RobotId) + "/bodyMc") - 1


## `get robot2HatId`
var robot2HatId: int:
	get: return _hat_id(_robotMc2, _p2RobotId)


func _hat_id(robotsMc: String, robotId: int) -> int:
	var robot := robotsMc + "/robot" + str(robotId)
	if _mc.has_instance(robot + "/head"):
		return _mc.get_frame(robot + "/head/hatMc") - 1
	return _mc.get_frame(robot + "/hatMc") - 1

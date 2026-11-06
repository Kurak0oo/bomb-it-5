extends RefCounted
## Port of `zlong.bombit5.ui.unlockCloth.UnlockTipScreen` (class UI_UNLOCK_TIP): the panel
## a score screen opens over itself when looks unlock, and on DRESS UP. Its clip
## (`Attach.getMovieClip("UI_UNLOCK_TIP")`, added to the score screen's `_mc`) is the hidden
## `UI_UNLOCK_TIP` instance of the generated score screen; `addChild` / `removeChild` /
## `visible` become `set_shown`. `GameModel.P1Robot / P1ClothId / P1HatId` are the app
## session's `robot / body / hat`.
##
## One player only (the owner removed 2-player play): `isOnePlayer` is always true, so
## `robotBtn2` stays hidden and its handlers, kept as written, cannot run.
##
## The clip plays its recorded timeline (from the unlock-tip capture); its last-frame
## script (`onLastFrameHandler`) starts the unlock bursts.
##
## Not ported: `_robotBtn1.x += 84` in `initSetting` (the screen cannot move an instance;
## the 1P head button stays where the layout puts it), `__mc.stop()` (the recording already
## stops there), and `AwardSender.sendAward5` (portal achievement) when
## `Cookie.checkAllUnlocked()`.

const UtilsButton = preload("res://scripts/ui/button.gd")  # zlong.bombit5.utils.Button
const ClothesPanel = preload("res://scripts/ui/clothes_panel.gd")
const UnlockAnimaPanel = preload("res://scripts/ui/unlock_anima_panel.gd")
const UnlockClothData = preload("res://scripts/ui/unlock_cloth_data.gd")

## The tip's instance on the generated score screen (`UI_UNLOCK_TIP`).
const UI_UNLOCK_TIP := "UI_UNLOCK_TIP"

var _screen: Node2D
var _events: RefCounted
var _app: Node
var __mc := ""
var __containerMc := ""
var _scoreText := ""
var _unlockData: UnlockClothData
var _robotBtn1 := ""
var _robotBtn2 := ""
var _robotMc := ""
var _clothesPanel: ClothesPanel
var _unlockAnimaPanel: UnlockAnimaPanel
var _okBt := ""
## `new Button(this._okBt)`: kept here so the RefCounted button stays alive.
var _okButton: UtilsButton
var _isOnePlayer := true
var _is1P := true
## `this._player`: `game.personalPlayers`, each a Dictionary with `totalPoint`.
var _player: Array = []
var _unlockTip := ""


## `UnlockTipScreen(pmc, players, unlockData, isOnePlayer, is1P = true, soundManager = null)`.
## `pmc` is the score screen itself (`_mc`); `events` its listeners; `app` stands in for
## the `SoundManger` and `GameModel`.
func _init(screen: Node2D, events: RefCounted, player: Array, unlockData: UnlockClothData,
		isOnePlayer: bool, is1P := true, app: Node = null) -> void:
	_screen = screen
	_events = events
	_unlockData = unlockData
	_is1P = is1P
	_isOnePlayer = isOnePlayer
	_app = app
	_player = player
	init()


func _sound(name: String) -> void:
	if name == "menuPress": _app.audio.menu_press()
	else: _app.audio.menu_touch()


## `init` (`Cookie.instance.checkAllUnlocked()` -> `AwardSender.sendAward5()`: portal only)
func init() -> void:
	initDis()
	initEvents()
	initSetting()


## `destory` (sic)
func destory() -> void:
	delCLothPanel()
	delEvents()
	delDis()
	_unlockData = null


## `initDis`
func initDis() -> void:
	__mc = UI_UNLOCK_TIP
	_screen.set_shown(__mc, true)  # this.__pmc.addChild(this.__mc)
	__containerMc = __mc + "/containerMc"
	_robotBtn1 = __containerMc + "/robotBtn1"
	_robotBtn2 = __containerMc + "/robotBtn2"
	# `_robotBtn1.buttonMode = _robotBtn1.buttonMode = true`: the hand cursor only.
	_robotMc = __containerMc + "/robotStage/robotMc"
	_unlockTip = __containerMc + "/unlock_tip"
	_screen.set_shown(_unlockTip, false)  # visible = false
	# `Art_unlockAnimas` is not in the tip's clip: only UnlockAnimaPanel adds it (`initDis`),
	# when looks were unlocked. The tip was recorded with a burst playing, so its generated
	# instance starts hidden here (DRESS UP showed a burst over the first outfit).
	_screen.set_shown(__containerMc + "/Art_unlockAnimas", false)
	# robotStage: mouseEnabled = mouseChildren = false, gotoAndStop(1)
	_screen.set_enabled(__containerMc + "/robotStage", false)
	_screen.set_frame(__containerMc + "/robotStage", 1)
	_okBt = __containerMc + "/okBt"
	_okButton = UtilsButton.new(_screen, _events, _okBt)
	_scoreText = __containerMc + "/scoreText"
	_screen.set_enabled(_scoreText, false)  # mouseEnabled = false
	_screen.set_text(_scoreText, str(_player[0].totalPoint))


## `delDis`
func delDis() -> void:
	_okBt = ""
	_robotMc = ""
	_robotBtn1 = ""
	_robotBtn2 = ""
	_screen.set_shown(__mc, false)  # this.__pmc.removeChild(this.__mc)
	__containerMc = ""
	__mc = ""


## `initEvents`
func initEvents() -> void:
	_screen.add_frame_script(__mc, _screen.get_total_frames(__mc), onLastFrameHandler)
	_events.add(_okBt, &"click", onClickOkBt)
	_events.add(_okBt, &"over", onRollOverHandler)
	_events.add(_robotBtn1, &"over", onOverRobotBtn1)
	_events.add(_robotBtn1, &"out", onOutRobotBtn1)
	_events.add(_robotBtn1, &"click", onClickRobotBtn1)
	_events.add(_robotBtn2, &"over", onOverRobotBtn2)
	_events.add(_robotBtn2, &"out", onOutRobotBtn2)
	_events.add(_robotBtn2, &"click", onClickRobotBtn2)


## `delEvents`. Quirk kept: the OK button's ROLL_OVER listener is not removed.
func delEvents() -> void:
	_events.remove(_okBt, &"click", onClickOkBt)
	_events.remove(_robotBtn1, &"over", onOverRobotBtn1)
	_events.remove(_robotBtn1, &"out", onOutRobotBtn1)
	_events.remove(_robotBtn1, &"click", onClickRobotBtn1)
	_events.remove(_robotBtn2, &"over", onOverRobotBtn2)
	_events.remove(_robotBtn2, &"out", onOutRobotBtn2)
	_events.remove(_robotBtn2, &"click", onClickRobotBtn2)


## `initSetting`
func initSetting() -> void:
	selectRobotBtn(_is1P)
	if _isOnePlayer:
		_screen.set_frame(_robotBtn1 + "/robotHeadMc", _unlockData.robot1Id + 1)
		_screen.set_shown(_robotBtn2, false)  # visible = false
		# TODO(move): `this._robotBtn1.x += 84` (see the header).
	else:
		_screen.set_frame(_robotBtn1 + "/robotHeadMc", _unlockData.robot1Id + 1)
		_screen.set_frame(_robotBtn2 + "/robotHeadMc", _unlockData.robot2Id + 1)


## `changeRobot`
func changeRobot(robotId: int, robotsMc: String) -> void:
	delCLothPanel()
	initClothPanel(robotId, robotsMc)


## `selectRobotBtn`: frame 3 marks the selected player's head button.
func selectRobotBtn(is1P: bool) -> void:
	_is1P = is1P
	if _is1P:
		_screen.set_frame(_robotBtn1, 3)
		_screen.set_frame(_robotBtn2, 1)
	else:
		_screen.set_frame(_robotBtn1, 1)
		_screen.set_frame(_robotBtn2, 3)
	_screen.set_shown(_unlockTip, false)  # visible = false
	var s = _app.session
	# GameModel.P2Robot / P2ClothId / P2HatId: no second player, 0.
	changeRobot(s.robot if is1P else 0, _robotMc)
	_clothesPanel.changeCloth(s.body if is1P else 0, s.hat if is1P else 0)
	delUnlockAnimaPanel()
	if _is1P and not _unlockData.isUsed1:
		_unlockData.isUsed1 = true
		initUnlockAnimaPanel(_unlockData.unlockedP1Index)
	elif not _is1P and not _unlockData.isUsed2:
		_unlockData.isUsed2 = true
		initUnlockAnimaPanel(_unlockData.unlockedP2Index)


## `initClothPanel`: the panel is added to `__containerMc`. `_clothesPanel.x = 142; y = 214`
## is not ported: the generated layout places `Art_clothPanel<N>` (see ClothesPanel
## `set x` / `set y`).
func initClothPanel(robotId: int, robotsMc: String) -> void:
	_clothesPanel = ClothesPanel.new(_screen, _events, robotId, robotsMc, _app, __containerMc)
	_clothesPanel.CHANGE_CLOTH.connect(onChangeCloth)
	_clothesPanel.CHANGE_HAT.connect(onChangeHat)


## `delCLothPanel`
func delCLothPanel() -> void:
	if _clothesPanel:
		_clothesPanel.CHANGE_CLOTH.disconnect(onChangeCloth)
		_clothesPanel.CHANGE_HAT.disconnect(onChangeHat)
		_clothesPanel.destroy()
		_clothesPanel = null


## `onChangeCloth`: GameModel.P1ClothId (P2ClothId has no second player to go to).
func onChangeCloth(avatarId: int) -> void:
	if _is1P:
		_app.session.body = avatarId


## `onChangeHat`: GameModel.P1HatId (P2HatId has no second player to go to).
func onChangeHat(avatarId: int) -> void:
	if _is1P:
		_app.session.hat = avatarId


## `initUnlockAnimaPanel`. `x = 142; y = 214` not ported (see UnlockAnimaPanel).
func initUnlockAnimaPanel(unlockIds: Array) -> void:
	if unlockIds.size() > 0:
		_screen.set_shown(_unlockTip, true)  # visible = true
		_unlockAnimaPanel = UnlockAnimaPanel.new(_screen, __containerMc, unlockIds, _app)


## `delUnlockAnimaPanel`
func delUnlockAnimaPanel() -> void:
	if _unlockAnimaPanel:
		_unlockAnimaPanel.destroy()
		_unlockAnimaPanel = null


## `onLastFrameHandler` (the tip clip's last-frame script)
func onLastFrameHandler() -> void:
	# `this.__mc.stop()`: the recorded timeline stops there already.
	if _unlockAnimaPanel:
		_unlockAnimaPanel.startPlay()


## `onClickOkBt`
func onClickOkBt(_t: String) -> void:
	destory()
	_sound("menuPress")  # SoundManger.getInstance().menuPress()


## `onRollOverHandler`
func onRollOverHandler(_t: String) -> void:
	_sound("menuTouch")


## `onOverRobotBtn1`
func onOverRobotBtn1(_t: String) -> void:
	if _screen.get_frame(_robotBtn1) == 1:
		_screen.set_frame(_robotBtn1, 2)
	_sound("menuTouch")


## `onOutRobotBtn1`
func onOutRobotBtn1(_t: String) -> void:
	if _screen.get_frame(_robotBtn1) == 2:
		_screen.set_frame(_robotBtn1, 1)


## `onClickRobotBtn1`
func onClickRobotBtn1(_t: String) -> void:
	_screen.set_text(_scoreText, str(_player[0].totalPoint))
	if _screen.get_frame(_robotBtn1) != 3:
		selectRobotBtn(true)
		if _unlockAnimaPanel:
			_unlockAnimaPanel.startPlay()
	_sound("menuPress")


## `onOverRobotBtn2`
func onOverRobotBtn2(_t: String) -> void:
	if _screen.get_frame(_robotBtn2) == 1:
		_screen.set_frame(_robotBtn2, 2)
	_sound("menuTouch")


## `onOutRobotBtn2`
func onOutRobotBtn2(_t: String) -> void:
	if _screen.get_frame(_robotBtn2) == 2:
		_screen.set_frame(_robotBtn2, 1)


## `onClickRobotBtn2` (hidden with one player; `_player[1]` exists only with two)
func onClickRobotBtn2(_t: String) -> void:
	_screen.set_text(_scoreText, str(_player[1].totalPoint))
	if _screen.get_frame(_robotBtn2) != 3:
		selectRobotBtn(false)
		if _unlockAnimaPanel:
			_unlockAnimaPanel.startPlay()
	_sound("menuPress")

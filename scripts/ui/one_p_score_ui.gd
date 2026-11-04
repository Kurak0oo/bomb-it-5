extends "res://scripts/ui/player_score_ui.gd"
## Port of `zlong.bombit5.ui.OnePScoreUI` (class UI_LEVEL_COMPLETED_ONEP): the one-player
## score screen. On top of `PlayerScoreUI` it fills the five point fields and the robot's
## head, unlocks the looks the session total has reached (`unlockCloth`) and opens the
## unlock tip when any are new.
##
## Unlocks (`Cookie.instance.isAvatarEnable(robot, n)` / `unlockAvatar(robot, n)` /
## `flush`): the app keeps look numbers n per robot in `store.unlocks[str(robot)]` (see
## ClothesPanel); `flush` is `store.save_file()`. `Cookie.unlockAvatar` unlocks for everyone
## in this build (`Root.__lockContent__` is false).
##
## Not ported: `AwardSender.sendAward4` (Green Zone kill count), `sendAwardOnComplete`
## and `sendScore` (portal achievements and score board). `_box` / `_item` and their setters
## have no TextField on UI_LEVEL_COMPLETED_ONEP (never assigned in the AS3); kept as setters
## that would fail as the AS3's would.

## `Root.PORTAL_TYPE` in this build (`PortalType.PORTAL_TYPE_TWEEN`, see ClothesPanel).
const PORTAL_TYPE := "tween"
## `GameConfig.TOTAL_ROBOT_CONSUME`
const TOTAL_ROBOT_CONSUME := 8
const Looks = preload("res://scripts/looks.gd")

var _box := ""
var _item := ""
var _kill := ""
var _time := ""
var _difficulity := ""
var _level := ""
var _total := ""
var _head := ""


## `OnePScoreUI(root, gameResult, game, soundManager)`
func _init(screen: Node2D, app: Node, gameResult: int, round_state: Dictionary) -> void:
	isOnePlayer = true
	super(screen, app, gameResult, round_state)


## `init`
func init() -> void:
	super.init()
	setMC("UI_LEVEL_COMPLETED_ONEP")


## `initView`: the TextFields, then `PlayerScoreUI.initView`.
func initView() -> void:
	_kill = "kill"
	_time = "time"
	_difficulity = "difficulity"
	_level = "levelScore"
	_total = "total"
	_head = "p1head"
	super.initView()


## `delView`
func delView() -> void:
	_box = ""
	_item = ""
	_kill = ""
	_time = ""
	_difficulity = ""
	_level = ""
	_total = ""
	_head = ""
	super.delView()


## `initData`
func initData() -> void:
	super.initData()
	var player: Dictionary = game.personalPlayers[0]
	_mc.set_text(_kill, str(player.modePoint))
	_mc.set_text(_time, str(player.timePoint))
	_mc.set_text(_difficulity, str(player.diffiPoint))
	_mc.set_text(_level, str(player.levelPoint))
	_mc.set_text(_total, str(player.totalPoint))
	_mc.set_frame(_head, _root.session.robot + 1)  # GameModel.P1Robot + 1
	# GREEN_ZONE: killNum >= AwardSender.sendAward4Count -> sendAward4(); LEVEL_WIN ->
	# sendAwardOnComplete(): portal only.
	var data := unlockCloth(_root.session.robot, player.totalPoint, true)
	if data.unlockedP1Index.size() > 0 and PORTAL_TYPE != "china":
		_tips.append(UnlockTipScreen.new(_mc, _events, game.personalPlayers, data, true, true, _root))
	# AwardSender.sendScore(totalPoint): portal only.


## `unlockCloth(robotId, totalPoint, isP1)`: every look whose `UNLOCK_SCORE_n` the total
## reaches and that is still locked is unlocked and listed.
func unlockCloth(robotId: int, totalPoint: int, isP1: bool) -> UnlockClothData:
	var data := UnlockClothData.new()
	if isP1:
		data.robot1Id = robotId
	else:
		data.robot2Id = robotId
	var i := 1
	while i <= TOTAL_ROBOT_CONSUME:
		if totalPoint >= Looks.THRESHOLDS[i - 1]:  # GameConfig["UNLOCK_SCORE_" + i]
			if not isAvatarEnable(robotId, i):
				if isP1:
					data.unlockedP1Index.append(i)
				else:
					data.unlockedP2Index.append(i)
				unlockAvatar(robotId, i)
		i += 1
	_root.store.save_file()  # Cookie.instance.flush()
	return data


## `Cookie.instance.isAvatarEnable(robot, n)`
func isAvatarEnable(robot: int, n: int) -> bool:
	return n in _root.store.unlocks.get(str(robot), [])


## `Cookie.instance.unlockAvatar(robot, n)`
func unlockAvatar(robot: int, n: int) -> void:
	var unlocked: Array = _root.store.unlocks.get(str(robot), []).duplicate()
	if n not in unlocked: unlocked.append(n)
	unlocked.sort()
	_root.store.unlocks[str(robot)] = unlocked


## `set box`
func set_box(value: int) -> void:
	_mc.set_text(_box, str(value))


## `set item`
func set_item(value: int) -> void:
	_mc.set_text(_item, str(value))


## `set kill`
func set_kill(value: int) -> void:
	_mc.set_text(_kill, str(value))


## `set time`
func set_time(value: int) -> void:
	_mc.set_text(_time, str(value))


## `set difficulity`
func set_difficulity(value: int) -> void:
	_mc.set_text(_difficulity, str(value))


## `set level`
func set_level(value: int) -> void:
	_mc.set_text(_level, str(value))


## `set total` / `get total`: `int(this._total.text)`, read back from the field. UIManager
## passes it to `OnePGameOverUI` as the final score.
var total: int:
	get: return String(_mc.get_text(_total)).to_int()
	set(value): _mc.set_text(_total, str(value))

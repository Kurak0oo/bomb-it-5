extends "res://scripts/ui/abstract_ui.gd"
## Port of `zlong.bombit5.ui.PlayerScoreUI`, the score screen after each level (the base of
## `OnePScoreUI`). Method names follow the AS3. `GameModel` reads the app session:
## `currentLevel` is `session.level` (the level just played: the AS3 sets it when the next
## map loads), `levels`, `gameMode`, `difficulty` and `P1Robot` (`session.robot`).
##
## `game` stands in for the round: `{"personalPlayers": [player]}`, `player` a Dictionary of
## the points the AS3 reads (`modePoint`, `timePoint`, `diffiPoint`, `levelPoint`,
## `totalPoint`, `killNum`); see `personal_player`.
##
## Navigation (`nextLevelFunc`) replaces `UIManager.gameReStart` / `gameOver` with the app's
## `_continue` / `show_end`. Not ported: `GASender.sendModePlay` (analytics) and MORE GAMES'
## publisher link (its handler only plays the press sound in the AS3 too).

const UtilsButton = preload("res://scripts/ui/button.gd")  # zlong.bombit5.utils.Button
const UnlockTipScreen = preload("res://scripts/ui/unlock_tip_screen.gd")
const UnlockClothData = preload("res://scripts/ui/unlock_cloth_data.gd")
const Session = preload("res://scripts/session.gd")

## `zlong.bombit5.data.GameResult`
const GameResult := {"LEVEL_WIN": 1, "GAME_WIN": 2, "LEVEL_RESTART": 3, "GAME_OVER": 4}
## Flash key code of Space (`keyDownHandle`).
const KEY_SPACE_CODE := 32
## `NewTransText.updateText`: the en-US value of each title TextField's localization key
## (`LocalizationPack`, item id = the TextField's name). The failed title ends in an
## ellipsis, as the results goldens show it ("LEVEL 2 / 5 FAILED…", loss-score).
const LOCALIZED := {"LevelOver_1": "LEVEL [X]/[X] COMPLETE!", "LevelOver_2": "LEVEL [X]/[X] FAILED…"}
## `levelTitle`'s children that `setdata` looks for, and the name of each one's first child
## (`getChildAt(0)`, the `NewTransText` TextField). `levelTitle` declares only `title`
## (`translation_72`) and `title4` (`translation_73`); title2, 3, 5 and 6 never exist.
const TITLE_FIELDS := {"title": "LevelOver_1", "title2": "", "title3": "", "title4": "LevelOver_2",
	"title5": "", "title6": ""}

var _title := ""
var _gameResult: int
var game: Dictionary
var _bonus := ""
var _nextLevelBtn := ""
var _restartBtn := ""
var _dressUpBtn := ""
var _moreGamesBtn := ""
var isOnePlayer := false
## Unlock tips opened on this screen, kept alive (the AS3 keeps them through their listeners).
var _tips: Array = []


## `PlayerScoreUI(root, gameResult, game, soundManager)`; `gameResult` is a `GameResult` value.
func _init(screen: Node2D, app: Node, gameResult: int, round_state: Dictionary) -> void:
	_gameResult = gameResult
	game = round_state
	super(screen, app)


## `GameResult` for the session's `Result` of the settled level.
static func game_result(result: int) -> int:
	match result:
		Session.Result.LEVEL_WIN: return GameResult.LEVEL_WIN
		Session.Result.GAME_WIN: return GameResult.GAME_WIN
		Session.Result.LEVEL_RESTART: return GameResult.LEVEL_RESTART
	return GameResult.GAME_OVER


## `game.personalPlayers[0]` after `countScore`, from the settled snapshot and the session:
## modePoint (kills, coins or zones), timePoint, diffiPoint, levelPoint, totalPoint.
static func personal_player(snapshot: Dictionary, session: RefCounted) -> Dictionary:
	var parts: Dictionary = snapshot.get("result_breakdown", {})
	return {"modePoint": int(parts.get("kills", 0)), "timePoint": int(parts.get("time", 0)),
		"diffiPoint": int(parts.get("difficulty", 0)), "levelPoint": int(snapshot.get("result_score", 0)),
		"totalPoint": int(session.total_score),
		"killNum": int(snapshot.get("actors", {}).get(&"human", {}).get("kills", 0))}


## `initView`
func initView() -> void:
	super.initView()
	_moreGamesBtn = "moregames"
	simpleButtons.append(UtilsButton.new(_mc, _events, _moreGamesBtn))
	_nextLevelBtn = "nextLevel"
	_restartBtn = "restartBtn"
	_dressUpBtn = "dressUpBtn"
	_title = "title"
	# `_title.addFrameScript(0, setdata)` and `(1, setdata)`: called after each
	# `_title.gotoAndStop` instead (see initData).
	_bonus = "bonus_txt"
	simpleButtons.append(UtilsButton.new(_mc, _events, _nextLevelBtn))
	simpleButtons.append(UtilsButton.new(_mc, _events, _restartBtn))
	simpleButtons.append(UtilsButton.new(_mc, _events, _dressUpBtn))
	setMode()


## `delView`
func delView() -> void:
	_nextLevelBtn = ""
	_restartBtn = ""
	_dressUpBtn = ""
	_moreGamesBtn = ""
	_title = ""
	_bonus = ""
	super.delView()


## `setdata`: the title's frame script (frames 1 and 2). Each `levelTitle` child present
## gets its TextField's `[X]/[X]` replaced by "current / levels" (first match only, as
## `String.replace` with a string). The TextField first gets its localized text
## (`NewTransText.updateText`, run as the child enters the stage).
func setdata() -> void:
	var current := str(_root.session.level)  # GameModel.currentLevel.toString()
	var levels := str(_root.session.levels)  # GameModel.levels.toString()
	var text := current + " / " + levels
	for child: String in TITLE_FIELDS:
		var clip := _title + "/" + child
		if _mc.has_instance(clip) and TITLE_FIELDS[child] != "":
			var field := clip + "/" + String(TITLE_FIELDS[child])
			_mc.set_text(field, LOCALIZED[TITLE_FIELDS[child]])  # NewTransText.updateText
			_mc.set_text(field, _replace_first(_mc.get_text(field), "[X]/[X]", text))


static func _replace_first(text: String, what: String, forwhat: String) -> String:
	var at := text.find(what)
	if at < 0: return text
	return text.substr(0, at) + forwhat + text.substr(at + what.length())


## `initData`: title frame 1 (complete) with NEXT, or frame 2 (failed) with RESTART;
## `bonus_txt` frame per difficulty.
func initData() -> void:
	if _gameResult == GameResult.LEVEL_WIN or _gameResult == GameResult.GAME_WIN:
		_mc.set_frame(_title, 1)
		setdata()  # frame script 0
		_mc.set_shown(_nextLevelBtn, true)  # visible = true
		_mc.set_shown(_restartBtn, false)  # visible = false
	else:
		_mc.set_shown(_nextLevelBtn, false)
		_mc.set_shown(_restartBtn, true)
		_mc.set_frame(_title, 2)
		setdata()  # frame script 1
	match _root.session.difficulty:
		&"easy": _mc.set_frame(_bonus, 1)
		&"normal": _mc.set_frame(_bonus, 2)
		&"hard": _mc.set_frame(_bonus, 3)


## `delData`
func delData() -> void:
	game = {}


## `setMode`: the mode picture and caption. Quirk kept: Kill mode shows frame 1, as Arcade.
func setMode() -> void:
	var modePic := "modePic"
	var text_mode := "text_mode"
	match _root.session.mode:
		&"arcade":
			_mc.set_frame(modePic, 1)
			_mc.set_frame(text_mode, 1)
		&"kill":
			_mc.set_frame(modePic, 1)
			_mc.set_frame(text_mode, 1)
		&"pac_man":
			_mc.set_frame(modePic, 3)
			_mc.set_frame(text_mode, 3)
		&"green_zone":
			_mc.set_frame(modePic, 4)
			_mc.set_frame(text_mode, 4)


## `initListener` (`_root.stage` KEY_DOWN: the screen's `key_down`, Flash key codes)
func initListener() -> void:
	super.initListener()
	_events.add(_nextLevelBtn, &"down", nextLevelHandle)
	_events.add(_nextLevelBtn, &"over", nextLevelOverHandle)
	_events.add(_restartBtn, &"down", nextLevelHandle)
	_events.add(_restartBtn, &"over", nextLevelOverHandle)
	_events.add(_dressUpBtn, &"down", dressUpHandle)
	_events.add(_dressUpBtn, &"over", dressUpOverHandle)
	_mc.connect("key_down", keyDownHandle)
	_events.add(_moreGamesBtn, &"down", moreHandle)
	_events.add(_moreGamesBtn, &"over", moreOverHandle)


## `nextLevelFunc`: RESTART retries the level (`gameReStart(true)`), NEXT plays the next one
## (`gameReStart(false)`); the last level's NEXT and a final loss open the end screen
## (`gameOver`). The app's `_continue` retries or advances by the session's result.
func nextLevelFunc() -> void:
	if _gameResult == GameResult.LEVEL_RESTART:
		_root._continue()  # game.uiManager.gameReStart(true)
	elif _gameResult == GameResult.GAME_OVER:
		_root.show_end(false)  # game.uiManager.gameOver(GameResult.GAME_OVER)
	elif _gameResult == GameResult.LEVEL_WIN:
		_root._continue()  # game.uiManager.gameReStart(false)
	elif _gameResult == GameResult.GAME_WIN:
		_root.show_end(true)  # game.uiManager.gameOver(GameResult.GAME_WIN)
	_disconnect_keys()


## `keyDownHandle`: Space continues, as NEXT / RESTART (no press sound).
func keyDownHandle(keyCode: int) -> void:
	match keyCode:
		KEY_SPACE_CODE: nextLevelFunc()


## `delListener`
func delListener() -> void:
	_events.remove(_nextLevelBtn, &"down", nextLevelHandle)
	_events.remove(_nextLevelBtn, &"over", nextLevelOverHandle)
	_events.remove(_restartBtn, &"down", nextLevelHandle)
	_events.remove(_restartBtn, &"over", nextLevelOverHandle)
	_events.remove(_dressUpBtn, &"down", dressUpHandle)
	_events.remove(_dressUpBtn, &"over", dressUpOverHandle)
	_disconnect_keys()
	_events.remove(_moreGamesBtn, &"down", moreHandle)
	_events.remove(_moreGamesBtn, &"over", moreOverHandle)
	super.delListener()


## `_root.stage.removeEventListener(KeyboardEvent.KEY_DOWN, keyDownHandle)`
func _disconnect_keys() -> void:
	if is_instance_valid(_mc) and _mc.is_connected("key_down", keyDownHandle):
		_mc.disconnect("key_down", keyDownHandle)


## `nextLevelHandle` (NEXT and RESTART)
func nextLevelHandle(_t: String) -> void:
	_sound("menuPress")
	nextLevelFunc()


## `moreHandle`
func moreHandle(_t: String) -> void:
	_sound("menuPress")


## `dressUpHandle`: the unlock tip with no new looks, to change the robot's looks. Quirk
## kept: each press opens another tip over the last.
func dressUpHandle(_t: String) -> void:
	var data := UnlockClothData.new()
	data.robot1Id = _root.session.robot  # GameModel.P1Robot
	data.robot2Id = 0  # GameModel.P2Robot: no second player
	_tips.append(UnlockTipScreen.new(_mc, _events, game.personalPlayers, data, isOnePlayer, true, _root))
	_sound("menuPress")


## `moreOverHandle`
func moreOverHandle(_t: String) -> void:
	_sound("menuTouch")


## `nextLevelOverHandle`
func nextLevelOverHandle(_t: String) -> void:
	_sound("menuTouch")


## `dressUpOverHandle`
func dressUpOverHandle(_t: String) -> void:
	_sound("menuTouch")

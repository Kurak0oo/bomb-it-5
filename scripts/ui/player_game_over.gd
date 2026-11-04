extends "res://scripts/ui/abstract_ui.gd"
## Port of `zlong.bombit5.ui.PlayerGameOver`, the end screen after the last level or the
## last heart (the base of `OnePGameOverUI`). Method names follow the AS3.
##
## `backHandle` (TRY AGAIN) resets `GameModel` (`GameModel.init`) on the app session and
## opens Game Settings (`UIEvent.GAME_SETTING` -> `UIManager.gameStart_start`), as observed
## in docs/evidence/edition-5-results-runtime-probes.md ("Hearts, Game Over and fresh session").
##
## Not ported: `FallSnow` (the confetti a GAME_WIN drops over the stage: bitmaps drawn from
## the `fallSnow` clip on a 300 ms timer; it needs its own art slot) and `deleFallSnowCartoon`
## beyond a stub, the `display` setter (UIManager), and MORE GAMES' publisher link (its
## handler only plays the press sound in the AS3 too).

const UtilsButton = preload("res://scripts/ui/button.gd")  # zlong.bombit5.utils.Button
## `zlong.bombit5.data.GameResult`
const GameResult := {"LEVEL_WIN": 1, "GAME_WIN": 2, "LEVEL_RESTART": 3, "GAME_OVER": 4}

var _gameResult: int
var _title := ""
var _fallSnowCartoon = null
var _back := ""
var _moreGamesBtn := ""


## `PlayerGameOver(root, gameResult, soundManager)`; `gameResult` is a `GameResult` value.
func _init(screen: Node2D, app: Node, gameResult: int) -> void:
	_gameResult = gameResult
	super(screen, app)


## `initView`
func initView() -> void:
	_back = "back"
	simpleButtons.append(UtilsButton.new(_mc, _events, _back))
	_moreGamesBtn = "moregames"
	simpleButtons.append(UtilsButton.new(_mc, _events, _moreGamesBtn))
	if _gameResult == GameResult.GAME_WIN:
		pass  # TODO(art): this._fallSnowCartoon = new FallSnow(_root.stage) (see the header)


## `initListener` (ROLL_OVER on `back`, MOUSE_OVER on `moregames`: both the screen's &"over")
func initListener() -> void:
	super.initListener()
	_events.add(_back, &"down", backHandle)
	_events.add(_back, &"over", backOverHandle)
	_events.add(_moreGamesBtn, &"down", moreHandle)
	_events.add(_moreGamesBtn, &"over", moreOverHandle)


## `delListener`
func delListener() -> void:
	_events.remove(_back, &"down", backHandle)
	_events.remove(_back, &"over", backOverHandle)
	_events.remove(_moreGamesBtn, &"down", moreHandle)
	_events.remove(_moreGamesBtn, &"over", moreOverHandle)


## `backHandle`: GameModel.init, destroy, then Game Settings; the press sound last.
func backHandle(_t: String) -> void:
	GameModel_init()
	destroy()
	_root.show_settings()  # _root.dispatchEvent(new Event(UIEvent.GAME_SETTING))
	_sound("menuPress")


## `GameModel.init`: one player, Arcade, 3 enemies, 5 levels, level 1, random stage, Easy.
## (`playerChosStage = ""` has no session counterpart.)
func GameModel_init() -> void:
	var s = _root.session
	s.set_meta("player_count", 1)
	s.mode = &"arcade"
	s.enemies = 3
	s.levels = 5
	s.level = 1
	s.stage = &"random"
	s.difficulty = &"easy"


## `backOverHandle`
func backOverHandle(_t: String) -> void:
	_sound("menuTouch")


## `moreHandle`
func moreHandle(_t: String) -> void:
	_sound("menuPress")


## `moreOverHandle`
func moreOverHandle(_t: String) -> void:
	_sound("menuTouch")


## `deleFallSnowCartoon` (`FallSnow.deleSnow`; FallSnow is not ported)
func deleFallSnowCartoon() -> void:
	if _fallSnowCartoon != null:
		_fallSnowCartoon = null


## `destroy`
func destroy() -> void:
	if _fallSnowCartoon:
		deleFallSnowCartoon()
	super.destroy()
	_moreGamesBtn = ""

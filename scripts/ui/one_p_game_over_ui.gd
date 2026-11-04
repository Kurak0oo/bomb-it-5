extends "res://scripts/ui/player_game_over.gd"
## Port of `zlong.bombit5.ui.OnePGameOverUI` (class UI_CONGRATULATIONSONEP after the last
## level, UI_GAMEOVERONEP after the last heart): the one-player end screen with the final
## score and the robot's head. `playerScore` is what UIManager passes: the score screen's
## `total` (`OnePScoreUI.total`, the session total).
##
## Not ported: `AwardSender.sendScore` (portal score board). `_playName` has no TextField on
## either class (`getChildByName("playName")` is null and never used).

var _score := ""
var _playName := ""
var _playerScore: int
var _head := ""


## The class `init` builds (`setMC`) for a `GameResult`: the app opens that screen.
static func mc_class_for(gameResult: int) -> String:
	return "UI_CONGRATULATIONSONEP" if gameResult == GameResult.GAME_WIN else "UI_GAMEOVERONEP"


## `OnePGameOverUI(root, playerScore, gameResult, soundManager)`
func _init(screen: Node2D, app: Node, playerScore: int, gameResult: int) -> void:
	_playerScore = playerScore
	super(screen, app, gameResult)


## `init`: the clip for the result, then `createOverUiMusic` (the menu music, after the
## win or lose jingle if it is still playing).
func init() -> void:
	super.init()
	setMC(mc_class_for(_gameResult))
	_root.audio.create_over_ui_music()


## `initData` (does not call `super`)
func initData() -> void:
	_mc.set_text(_score, str(_playerScore))
	_mc.set_frame(_head, _root.session.robot + 1)  # GameModel.P1Robot + 1
	# AwardSender.sendScore(this._playerScore): portal only.


## `initView`: `_score.selectable = false` (no selection on a generated screen), then
## `PlayerGameOver.initView`.
func initView() -> void:
	_score = "score"
	_playName = "playName"
	_head = "p1head"
	super.initView()

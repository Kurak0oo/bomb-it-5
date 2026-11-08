extends "res://scripts/ui/abstract_ui.gd"
## Port of `zlong.bombit5.ui.GameInterFace` (class UI_interface): the gameplay screen's HUD
## on the generated screen (scenes/swf/game.json). One panel `robotUI<robot>` per robot of
## the round, moved to its seat's slot, with its life, bomb, power, speed and score fields;
## the level, total levels and time; PAUSE.
##
## `game` stands in for the AS3 `Game`: its round (scripts/game.gd) and session. The
## counters are written by the players' setters in the AS3 (`AbstractPlayer.lifeData` ...,
## `Game.countTime`); `present` ports those setters over each snapshot of the round.
##
## `changeTimeCol`: once TIME reads under 10 (`Game.countTime` dispatches TIME_COUNT_DOWN,
## `timeCountDownHandle` adds it to the engine's tween handlers), TIME turns red, white, red …
## on every tween tick (`GameEngine.enterFrameHandle` runs them every 4th engine tick).
## `changeCol` / `defaultCol` are ported for the modes that flash a score; Arcade does not.
##
## Not ported yet: `stopMC` (generated screens show recorded frames only) and the `gameFrame`
## bitmap copy in `initData` (the layout already holds it as the screen's first piece).

const UtilsButton = preload("res://scripts/ui/button.gd")

## `GameMode` names, as the session stores modes.
const ARCADE_MODE := &"arcade"
const KILL_MODE := &"kill"
const PAC_MAN_MODE := &"pac_man"
const GREEN_ZONE := &"green_zone"

var _currentLevel := ""
var _totalLevel := ""
var _time := ""
var _pauseBtn := ""
var _robotIdArr: Array = []
var _robotInterFaceArr: Array = []
var _lifeTextArr: Array = []
var _bombTextArr: Array = []
var _powerTextArr: Array = []
var _speedTextArr: Array = []
var _scoreTextArr: Array = []
var _faceMcArr: Array = []
var _uiArr: Array = []
var _scoreStr := ""
var game: Node
## The HUD panel slots (GameConfig.ROBOT_UI_X_k / ROBOT_UI_Y_k), read by the converter from
## the recorded panels (layout `board.robot_ui_slots`).
var _slots: Array = []
## What the fields show, so a field is written only when its text changes.
var _shown := {}
## `changeTimeCol` is on the engine's tween handlers (after TIME_COUNT_DOWN).
var _time_flashing := false
var _tween_tick := -1
## The score fields that flash (`colorChangeArray`): uiId -> on.
var colorChangeArray := {}
## `Game.textColNum` (set by PacManMode's `mapLoadOver`).
var textColNum := 0
## The mode's `mapLoadOver` has run on the HUD (first snapshot of the round).
var _map_loaded := false
const RED := Color8(255, 0, 0)  # 16711680
const WHITE := Color8(255, 255, 255)  # 16777215


## `GameInterFace(root, game, soundManager)`
func _init(screen: Node2D, app: Node, round_host: Node) -> void:
	game = round_host
	_slots = screen.layout.get("board", {}).get("robot_ui_slots", [])
	super(screen, app)


## `init`
func init() -> void:
	super.init()
	setMC("UI_interface")


## `initView`: the fields; every panel hidden, then one per robot of the round (seat order
## `[P1Robot, P2Robot, P3Robot, P4Robot]`) shown at its seat's slot.
func initView() -> void:
	super.initView()
	_currentLevel = "currentLevel"
	_totalLevel = "totalLevel"
	_time = "time"
	_pauseBtn = "pause"
	simpleButtons.push_back(UtilsButton.new(_mc, _events, _pauseBtn))
	for i in 8:
		_mc.set_shown("robotUI%d" % i, false)
	_robotInterFaceArr = []
	_lifeTextArr = []
	_bombTextArr = []
	_powerTextArr = []
	_speedTextArr = []
	_scoreTextArr = []
	_faceMcArr = []
	_uiArr = []
	var session = _root.session
	# `_mc["robotUI" + id]`: addressed from the screen root, through UI_interface's own path.
	var ui := _ui_path()
	_robotIdArr = [session.robot] + Array(session.ai_robots)
	var totalRobotsCount: int = 1 + int(session.enemies)
	for i in totalRobotsCount:
		var robot: int = int(_robotIdArr[i])
		var panel := ui + "robotUI%d" % robot
		var face := "%s/interfaceMc%d" % [panel, robot]
		_mc.set_shown(face, true)
		_robotInterFaceArr.push_back(face)
		_lifeTextArr.push_back(face + "/lifeTf")
		_bombTextArr.push_back(face + "/bombTf")
		_powerTextArr.push_back(face + "/powerTf")
		_speedTextArr.push_back(face + "/speedTf")
		_scoreTextArr.push_back(face + "/scoreTf")
		_faceMcArr.push_back(face + "/faceMc")
		_mc.set_shown(panel, true)
		# A panel the capture had hidden recorded its parts hidden with it: they show with it.
		for part in ["/lifeTf", "/bombTf", "/powerTf", "/speedTf", "/scoreTf", "/faceMc"]:
			_mc.set_shown(face + part, true)
		_uiArr.push_back(panel)
		if i < _slots.size():
			# `_loc11_.x = GameConfig["ROBOT_UI_X_" + i]`, and y.
			var slot := Vector2(float(_slots[i][0]), float(_slots[i][1]))
			_mc.move_instance(panel, slot - _mc.instance_position(panel))
	setFaceMc()


## Where UI_interface (the AS3 `_mc`) lies under the screen root, as instance addresses go
## (`@0#1/@0/`): every panel has its own `lifeTf`, so they are addressed by path.
func _ui_path() -> String:
	for entry: Dictionary in _mc.layout.nodes:
		if entry.get("class", "") == "UI_interface":
			var relative: String = _mc._relative(entry.path)
			return relative + "/" if not relative.is_empty() else ""
	return ""


## `setFaceMc`: the score icon per mode.
func setFaceMc() -> void:
	var frame := 4
	_scoreStr = ""
	match _root.session.mode:
		KILL_MODE:
			frame = 1
			_scoreStr = "/10"
		PAC_MAN_MODE:
			frame = 3
		GREEN_ZONE:
			frame = 2
			_scoreStr = "/10"
	for face in _faceMcArr:
		_mc.set_frame(face, frame)


## `initListener`: PAUSE on MOUSE_DOWN (every mode but speed).
func initListener() -> void:
	super.initListener()
	_events.add(_pauseBtn, &"down", pauseHandle)


## `delListener`
func delListener() -> void:
	_events.remove(_pauseBtn, &"down", pauseHandle)


## `initData`: level 1 of the session's levels, every counter `--`, the panels' frames
## (P1's panel frame 2, an enemy's stays on 1, a seat beyond the enemies frame 4).
func initData() -> void:
	_put(_currentLevel, "1")
	_put(_totalLevel, str(_root.session.levels))
	for i in _lifeTextArr.size():
		for field in [_lifeTextArr[i], _bombTextArr[i], _powerTextArr[i], _speedTextArr[i], _scoreTextArr[i]]:
			_put(field, "--")
	var enemies := 0
	for i in _uiArr.size():
		if i == 0:  # `_robotIdArr[i] == GameModel.P1Robot`
			_mc.set_frame(_uiArr[i], 2)
		elif enemies < int(_root.session.enemies):
			enemies += 1
		else:
			_mc.set_frame(_uiArr[i], 4)


## `pauseHandle`: `UIEvent.PAUSE` (`Game.gamePause`), and the menu press sound.
func pauseHandle(_target: String) -> void:
	if is_instance_valid(game): game.toggle_pause()
	_sound("menuPress")


## `set time`
func set_time(value: String) -> void:
	_put(_time, value)


## `set currentLevel`
func set_current_level(value: int) -> void:
	_put(_currentLevel, str(value))


## `setLife(uiId, life)`
func setLife(uiId: int, value: int) -> void:
	_put(_lifeTextArr[uiId], str(value))


## `setBomb(uiId, bombs)`
func setBomb(uiId: int, value: int) -> void:
	_put(_bombTextArr[uiId], str(value))


## `setPower(uiId, power)`
func setPower(uiId: int, value: int) -> void:
	_put(_powerTextArr[uiId], str(value))


## `setSpeed(uiId, level)`
func setSpeed(uiId: int, value: int) -> void:
	_put(_speedTextArr[uiId], str(value))


## `setScore(uiId, points)`: -1 empties the field and shows the face's frame 4.
func setScore(uiId: int, value: int) -> void:
	if value != -1:
		_put(_scoreTextArr[uiId], str(value) + _scoreStr)
	else:
		_put(_scoreTextArr[uiId], "")
		_mc.set_frame(_faceMcArr[uiId], 4)


## The players' setters over one snapshot of the round (`AbstractPlayer.lifeData`,
## `bombData`, `powerData`, `speedData` = round((velocity - 1.6) / 0.1) + 1, `scoreData`;
## `Game.countTime`: `time = gameTime - pastTime`, which the round counts as `remaining`
## steps of 35 per second; `currentLevel` from `firstMapLoadOver`).
func present(snapshot: Dictionary) -> void:
	if snapshot.is_empty(): return
	if not _map_loaded:
		_map_loaded = true
		mapLoadOver(snapshot)
	set_current_level(int(_root.session.level))
	var time := int(snapshot.get("remaining", 0)) / 35
	set_time(str(time))
	# `countTime`: `if (gameTime - pastTime < 10)` dispatch TIME_COUNT_DOWN.
	if time < 10 and not _time_flashing: timeCountDownHandle()
	_tween_handlers(int(snapshot.get("tick", 0)))
	var uiId := 0
	for id in snapshot.actors:
		if uiId >= _lifeTextArr.size(): break
		var actor: Dictionary = snapshot.actors[id]
		setLife(uiId, int(actor.get("lives", 0)))
		setBomb(uiId, int(actor.get("capacity", 1)))
		setPower(uiId, int(actor.get("power", 1)))
		setSpeed(uiId, roundi((float(actor.get("speed", 1.6)) - 1.6) / 0.1) + 1)
		# Arcade starts at 0 (`AbstractPlayer.updateUI`) and adds BOX_POINT, PROP_POINT and
		# ROBOT_POINT as they come (`boxPoint`, `itemPoint`, `modePoint` setters: the round's
		# `score`); the other modes show the level's points.
		setScore(uiId, int(actor.get("score", 0)) if _root.session.mode == ARCADE_MODE else int(actor.get("points", 0)))
		uiId += 1


## What the mode's `mapLoadOver` does to the HUD. PacManMode: `setScore(i, -1)` for the
## players (field emptied, face on frame 4), `scoreStr = "/" + _coinTotal`, `textColNum =
## _coinTotal - 15`, then `eatNum = 0` writes the player's score through `coinsNum`
## (`scoreData`, here by `present`), and `setScore(i, -1)` for every AI seat.
func mapLoadOver(snapshot: Dictionary) -> void:
	if _root.session.mode != PAC_MAN_MODE: return
	var coins := int(snapshot.get("mode_state", {}).get("coins_total", 0))
	for uiId in _scoreTextArr.size(): setScore(uiId, -1)
	scoreStr = "/" + str(coins)
	textColNum = coins - 15


## `set scoreStr`
var scoreStr: String:
	set(value): _scoreStr = value
	get: return _scoreStr


## `timeCountDownHandle`: `changeTimeCol` joins the engine's tween handlers.
func timeCountDownHandle() -> void:
	_time_flashing = true


## The engine's tween handlers, every 4th engine tick (`GameEngine.enterFrameHandle`: `count`
## reaches 4 on the 5th tick, then every 4th).
func _tween_handlers(tick: int) -> void:
	if _tween_tick < 0: _tween_tick = tick
	while _tween_tick < tick:
		_tween_tick += 1
		if _tween_tick % 4 != 0: continue
		if _time_flashing: changeTimeCol()
		for uiId in colorChangeArray: _flip(_scoreTextArr[uiId])


## `changeTimeCol`: red unless red, then white.
func changeTimeCol() -> void:
	_flip(_time)


## `changeCol(index)`: that score field flashes on the tween handlers.
func changeCol(index: int) -> void:
	colorChangeArray[index] = true


## `defaultCol(index)`: the score field back to 6634002, no longer flashing.
func defaultCol(index: int) -> void:
	colorChangeArray.erase(index)
	_mc.set_text_color(_scoreTextArr[index], Color8(101, 58, 18))


func _flip(field: String) -> void:
	var red: bool = _shown.get(field + "|colour") == RED
	_shown[field + "|colour"] = WHITE if red else RED
	_mc.set_text_color(field, WHITE if red else RED)


func _put(field: String, text: String) -> void:
	if _shown.get(field) == text: return
	_shown[field] = text
	_mc.set_text(field, text)


## `destroy`: also drops the round it reads.
func destroy() -> void:
	super.destroy()
	game = null

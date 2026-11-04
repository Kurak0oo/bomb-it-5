extends RefCounted
## Port of `zlong.bombit5.ui.unlockCloth.UnlockAnimaPanel`: the "unlocked" bursts over the
## looks a score screen just unlocked. Its art (`Attach.getSprite("Art_unlockAnimas")`,
## added to the tip's `containerMc`) is the hidden `Art_unlockAnimas` instance of the
## generated screen, under `pmc`; `addChild` / `removeChild` become `set_shown`.
## `set x` / `set y` (the tip places it at (142, 214)) are not ported: the generated layout
## places the instance where the capture shows it (no typed-in coordinates).

## `GameConfig.TOTAL_ROBOT_CONSUME`
const TOTAL_ROBOT_CONSUME := 8

var _screen: Node2D
var _pmc: String
var _mc: String
var _unlockIds: Array
var _app: Node


## `UnlockAnimaPanel(pmc, unlockIds, soundManager)`. `pmc` is the address of the parent
## clip (the tip's `containerMc`); `app` stands in for the `SoundManger`.
func _init(screen: Node2D, pmc: String, unlockIds: Array, app: Node) -> void:
	_screen = screen
	_pmc = pmc
	_unlockIds = unlockIds
	_app = app
	init()


## `destroy`
func destroy() -> void:
	delDis()
	_unlockIds = []


## `startPlay`: every burst plays, then the `unlockclothes` sound (no such class in the
## SWF: `createSound` drops it, docs/evidence/edition-5-audio.md).
func startPlay() -> void:
	var i := 1
	while i <= TOTAL_ROBOT_CONSUME:
		_screen.play(_mc + "/unlockAnima" + str(i))  # this._mc["unlockAnima" + i].play()
		i += 1
	_app.audio.play_sound(&"unlockclothes")  # this._soundManager.createSound("unlockclothes")


## `init`
func init() -> void:
	initDis()
	initSetting()


## `initDis`: `mouseChildren = mouseEnabled = false`, added to the parent.
func initDis() -> void:
	_mc = _pmc + "/Art_unlockAnimas"
	_screen.set_enabled(_mc, false)
	_screen.set_shown(_mc, true)  # this._pmc.addChild(this._mc)


## `delDis`
func delDis() -> void:
	_screen.set_shown(_mc, false)  # this._pmc.removeChild(this._mc)
	_pmc = ""


## `initSetting`: every burst on frame 1 and hidden, then the unlocked ones shown.
func initSetting() -> void:
	var i := 1
	while i <= TOTAL_ROBOT_CONSUME:
		var anima := _mc + "/unlockAnima" + str(i)
		_screen.set_frame(anima, 1)
		_screen.set_shown(anima, false)  # visible = false
		i += 1
	var k := 0
	while k < _unlockIds.size():
		_screen.set_shown(_mc + "/unlockAnima" + str(_unlockIds[k]), true)  # visible = true
		k += 1

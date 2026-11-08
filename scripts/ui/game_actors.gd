extends RefCounted
## The round's moving actors on the generated gameplay screen (checkpoint 4, slice b): each
## robot, bomb and blast drawn with the original's library clips (original/screens/game/
## actors/, record_screen.py actors) at their registration points, on the row layers of the
## board (scripts/ui/game_board.gd), driven by the simulation's snapshots. Display side only:
## the round's state stays in scripts/simulation/.
##
## Ports (zlong.bombit5):
## - `RobotView`: a robot is a Sprite (`_container`) at `xPos + EXCURSION_X`, `yPos +
##   EXCURSION_Y` holding its clip `_r<robot><vehicle><direction>` (`setRobotMc`, the look
##   set on its innermost `bodyMc`/`hatMc`, the vehicle `_Car` or `_Skateboard` on a ride);
##   a loop the clip plays on its own (eyes blinking) is a node of its own over it, at the
##   place the art pass recorded for each root frame; it starts on row 0's layer 3 (the constructor,
##   yN 0) and `resetMainContainer` moves it to its row's layer `robotRow` (3 for AI, 4 for
##   the player) on the engine tick, from where it stood before that tick's move;
##   `robotTurn` makes a new clip and plays it, `RobotController.robot_turnHandler` plays it,
##   `normalStop` (the engine's `moveStop` once no direction is held) stops it;
## - `InvincibilityCommand`: +50 on every colour channel of the robot every 4 ticks, for 80;
## - `AbstractRobot.kill` / `RobotDeadCommand.countDead`: the `_Dead` clip, one frame per
##   tick, the robot removed once it reaches `totalFrames - 1`;
## - `Bomb`: `bomb0` in a Sprite on its row's layer 2 (`init`, `createMC`), playing;
##   `blast` swaps it for `exp0` stopped at frame 1 and puts an `exp0` per flame cell on the
##   flame row's layer 0 (frames 2/3 up, 8/9 down, 6/7 left, 4/5 right, the odd one at the
##   bomb's full power), which stay on the display list; `ended` removes the bomb after 16
##   blast ticks (`_continueTime > 15`).
##
## - `AbstractWeapon` (slice c): a weapon pickup adds `showTimes` (its count left) and the held
##   clip `<name><direction>` at the robot's hand, in front of or behind the robot clip in its
##   container; HammerProp's `bombDown` swaps the held clip for `sinker<direction>_Play`, which
##   `HammerPlayCommand` takes off at the blow, when `robotMoveStart` makes the robot's clip
##   again. The other weapons' action clips and shots are still the placeholder view's.
##
## Frame timing recorded in the reference player (gameplay-cinema-bomb): a clip made between
## frames (a key press turning the robot, a bomb dropped by key) shows its first frame on the
## next frame and advances from the one after; `play()` on a key press advances the clip on
## the next frame; a key release stops it on the next engine tick, after that frame's advance.
## Nested clips: bomb0's spark loops (14 frames) with its root (27); exp0's nested blast
## shows frames 1, 1, 2, … at the centre and 1, 2, 3, … on an arm. The centre's art is the
## recording's next nested key (the art pass's exp0, made by `new`, shows its first nested
## frame twice): checked against the original through frame 817 (gameplay-cinema-item).
## The arms stay on the display list after the bomb is gone and play to their last, empty
## frame.
##
## Pickups (slice b2), ports of `AbstractItem` and `PixelClip`: `init` adds the item's Sprite
## to its row itself (`getDisArr(yN)`, after the five layers) at the cell; `getMc` hands the
## `prop` clip's frames to a PixelClip, a Sprite at (int(15 - tx / 2) + xOffset, int(15 - ty / 2)
## + yOffset) holding a Bitmap at (-15, -15), with tx 10, ty 20, xOffset 2, yOffset 0;
## `playArr` shows bitmap i every 4th frame and wraps before the last bitmap
## (`i >= totalFrame`, totalFrame = bitmaps - 1). Recorded (gameplay-cinema-item): made on
## the engine frame (age 0) the Bitmap is empty; `playArr` first runs on the next frame,
## so bitmap k shows from age 4k + 1. `eatProp` takes the Sprite off its row; `deleProp` (a blast)
## swaps the PixelClip for `brickExp`, removed when it reaches its last frame
## (`countBrickExp`: `currentFrame == totalFrames`). The bitmaps are the reference player's
## (original/screens/game/items/, record_screen.py items).
##
## Effects (checkpoint 5, robot effects; art: record_screen.py actors --parts effects):
## - `ShieldProp.changeStage` / `initMc` (`resetRobotMc`: a new robot clip) and
##   `RobotView.setRobotMc`: with a shield, every new clip that has a `hand2` gets a new
##   `nombril<direction>` at hand2's x and y, at the bottom of the clip facing right
##   (`addChildAt(_, 0)`) and on top otherwise, sent to the clip's frame and playing and
##   stopping with it (`robotTurn`, `normalStop`); `addUseNum` takes it off. A ride's clip has
##   no `hand2` on most rides (`removeShieldDisplay`), and a `_Dead` clip none;
## - `InvincibilityProp.changeStage`: `invincibityPlay` in the robot's `itemMc` Sprite, which
##   `setItemMc` puts on top of the robot's container; `CountMcPlayCommand` takes the clip off
##   on its frame totalFrames - 1 (recorded: frames 1, 1, 2 … 28 over the 29 ticks of the
##   introduction; the empty Sprite stays), then `CountInvincibilityCommand` sets a
##   GradientGlowFilter on the robot's clip and weapon every tick (`_filerColor` turned every
##   2nd tick, `_filerStr` + `_colortime`) until `_time > _totalTime`;
## - `SendRobotCommand.execute`: the robot's clip at alpha 1 - count / 35 (count 1 on the
##   tick the portal sends it), until callback 30's `robotMoveStart` makes a new clip.

const DIRECTIONS := {Vector2i(0, 1): "_Down", Vector2i(-1, 0): "_Left", Vector2i(1, 0): "_Right", Vector2i(0, -1): "_Up"}
## `RobotModel.vehicle` per ride (CarProp `_Car`, MotoCycleProp `_Skateboard`, HorseProp
## `_forg`, DragonProp `_Elephant`): the robot's clip is `_r<robot><vehicle><direction>`.
const VEHICLE_CLIPS := {&"car": "_Car", &"moto": "_Skateboard", &"horse": "_forg", &"dragon": "_Elephant"}
## `AbstractWeapon._weaponName` per weapon (HammerProp sinker, FlamerProp thrower, LaserGunProp
## lasergun, TripleShootGunProp shotgun, ShotGunProp fireball, LandmineProp mine, BoxingProp boxing).
const WEAPON_NAMES := {&"hammer": "sinker", &"flamer": "thrower", &"laser": "lasergun", &"triple": "shotgun",
	&"shotgun": "fireball", &"landmine": "mine", &"boxing": "boxing"}
## `updateWeaponDisplay`: these go behind the robot facing left only; the others facing up or left.
const BEHIND_LEFT_ONLY := ["shotgun", "lasergun", "thrower", "boxing"]
## `HammerProp.initPlayPos`: where `bombDown` puts the `_Play` clip in the robot's container.
const HAMMER_PLAY_POS := {"_Left": Vector2(10, -15), "_Right": Vector2(-10, -15), "_Up": Vector2(15, -15), "_Down": Vector2(0, 0)}
## `bombDown` adds the `_Play` clip at the container's bottom facing up or left.
const PLAY_BEHIND := ["_Up", "_Left"]
## `setWeaponTimesMc`: showTimes at (mc.x, mc.y - 40) in the robot's container.
const TIMES_AT := Vector2(0, -40)
## `TryToKillCommandChain`: a ride's clip goes to `dead` and tweens to its last frame in 1 s.
const VEHICLE_HIT_TICKS := 35
## `Bomb.blast`'s exp0 frames per ray (middle, end).
const ARM_FRAMES := {Vector2i(0, -1): [2, 3], Vector2i(0, 1): [8, 9], Vector2i(-1, 0): [6, 7], Vector2i(1, 0): [4, 5]}
const INVINCIBILITY_FRAMES := 80
## `CountInvincibilityCommand()`: the filter's colours, ratios and alpha; `execute` builds
## `new GradientGlowFilter(-20, 60, _filerColor, alphas, ratios, 18, 18, 1, HIGH, INNER, false)`.
const FILER_COLOR := [16711680, 16744192, 16776960, 8388352, 65280, 65407, 65535, 32767, 255, 8323327,
	16711935, 16711807, 16711680]
const FILER_STR := [0, 20, 40, 60, 80, 100, 120, 140, 160, 180, 200, 220, 240]
const FILER_ALPHA := 0.8
const FILER_STEP := -20
## `SendRobotCommand`: `Root.GAME_FRAMERATE`, the fade's divisor.
const GAME_FRAMERATE := 35.0
## `SendRobotCommand`'s `_totalFrame` (default 30): its last callback makes the robot's clip again.
const SEND_TOTAL_FRAME := 30
const ROUND_START_LOOP_AGE := 4
const BLAST_TICKS := 16

var _screen: Node2D
var _board: RefCounted
var _art: Dictionary
## Seat looks of a recorded round ([clothID, hatID] per seat), else from the snapshot.
var _looks: Array
var _robots: Dictionary = {}
var _bombs: Array = []
var _tick := -1
var _now := 0
var _bomb_art: Dictionary = {}
var _exp_art: Dictionary = {}
var _items: Dictionary = {}
var _spent_arms: Array = []
## `ConveyorBelt.addDisappearAni`'s clips still on the board.
var _disappearing: Array = []
var _item_art: Dictionary = {}
## `AbstractItem.getMc`'s PixelClip arguments (tx, ty, xOffset, yOffset).
const PIXEL_CLIP := [10, 20, 2, 0]


func _init(screen: Node2D, board: RefCounted, looks: Array = []) -> void:
	_screen = screen
	_board = board
	_art = board.actor_art
	_looks = looks
	# bomb0 by (root frame, spark frame), exp0 by root frame and nested frame.
	for age in _art.get("played", {}).get("bomb0", {}):
		var art: Dictionary = _art.played.bomb0[age]
		var frames: Dictionary = art.get("frames", {})
		var key := "%d|%d" % [int(frames.get("/", 1)), int(frames.values().back() if frames.size() > 1 else 1)]
		if not _bomb_art.has(key): _bomb_art[key] = art
	_exp_art = _art.get("nested", {}).get("exp0", {})
	var items := ProjectSettings.globalize_path("res://original/screens/game/items/items.json")
	if FileAccess.file_exists(items):
		_item_art = JSON.parse_string(FileAccess.get_file_as_string(items)).get("items", {})


## Every snapshot; the clips advance once per tick.
func update(snapshot: Dictionary) -> void:
	var tick := int(snapshot.get("tick", 0))
	if _tick < 0:
		_tick = tick
		_create_robots(snapshot)
		return
	if tick <= _tick:
		return
	for step in tick - _tick:
		_now = _tick + step + 1
		_step(snapshot, step == tick - _tick - 1)
	_tick = tick


func _create_robots(snapshot: Dictionary) -> void:
	var seat := 0
	for id in snapshot.get("actors", {}):
		var actor: Dictionary = snapshot.actors[id]
		var look: Array = _looks[seat] if seat < _looks.size() else [int(actor.get("body", 0)), int(actor.get("hat", 0))]
		var view := {"id": id, "robot": int(actor.get("robot", seat)), "cloth": maxi(0, int(look[0])), "hat": maxi(0, int(look[1])),
			"robot_row": 4 if id == &"human" else 3, "row": 0, "layer": "", "item": {}, "children": [], "class": "", "suffix": "_Down",
			"frame": 1, "playing": false, "fresh": 0, "direction": Vector2i.ZERO, "blink": 0, "bright": false, "blinking": true,
			"dead": false, "removed": false, "position": actor.get("position", Vector2.ZERO), "blink_until": int(actor.get("blink_until", 0)),
			"vehicle": StringName(actor.get("vehicle", &"")), "vehicle_hit": -1, "loop_age": 0, "loop_count": 0,
			"weapon": &"", "ammo": 0, "weapon_class": "", "weapon_frame": 1, "weapon_playing": false, "weapon_fresh": 0,
			"play_class": "", "play_started": -1,
			"shield": false, "shield_class": "", "shield_frame": 1, "shield_playing": false, "shield_fresh": 0, "alpha": 1.0, "transit": false,
			"inv_from": 0, "inv_play": -1, "filter": {}, "filter_count": 0}
		_robots[id] = view
		# RobotView(): `_mainContainer = getDisArr(yN).getChildAt(3)` while yPos is still 0.
		_place(view, 0, 3)
		_set_robot_mc(view, "_Down")
		# Made before the round starts (`initStage`), the clip's loops stand at their fourth
		# frame on the round's first frame (recorded, gameplay-cinema-start); a frame further
		# per frame from there.
		view.loop_age = ROUND_START_LOOP_AGE
		view.fresh = 0
		_show(view)
		seat += 1


func _step(snapshot: Dictionary, last: bool) -> void:
	var commands := {}
	for command in snapshot.get("commands", []):
		commands[command.actor_id] = command.direction
	var attacks := {}
	for attack in snapshot.get("attacks", []):
		attacks[attack.actor_id] = attack
	for id in _robots:
		var view: Dictionary = _robots[id]
		var actor: Dictionary = snapshot.actors.get(id, {})
		if view.dead and actor.get("alive", false): _relive(view, actor)
		if view.removed: continue
		var direction := _direction(commands.get(id, Vector2.ZERO))
		var human: bool = id == &"human"
		if not actor.get("alive", true) and not view.dead:
			_kill(view)
		if view.dead:
			_count_dead(view)
			continue
		# A key press reaches the robot between frames (robot_turnHandler).
		# (in a portal the robot's key listener is off: `stopMoveListener`)
		if human and not view.transit and direction != Vector2i.ZERO and direction != view.direction: _turn(view, direction)
		# The frame's timeline advance.
		if view.playing and view.fresh == 0:
			view.frame = _next_frame(view.class, view.frame)
		view.fresh = maxi(0, view.fresh - 1)
		# The shield's clip plays on its own: made playing, `robotTurn` plays it, `normalStop`
		# stops it (a key for the way it already faces plays only the robot's clip; recorded).
		if view.shield_playing and view.shield_fresh == 0 and view.shield_class != "":
			view.shield_frame = view.shield_frame % _effect_total(view.shield_class) + 1
		view.shield_fresh = maxi(0, view.shield_fresh - 1)
		if view.weapon_playing and view.weapon_fresh == 0 and view.weapon_class != "":
			view.weapon_frame = view.weapon_frame % _weapon_total("held", view.weapon_class) + 1
		view.weapon_fresh = maxi(0, view.weapon_fresh - 1)
		view.loop_age += 1
		# The engine tick: resetMainContainer (from where it stood), the AI's turns, moveStop.
		_reset_main_container(view)
		# PushRobotCommand.moveFuc: while a toy hand pushes it, the robot only moves (its position
		# below); `resetRobot`, where it stops, makes its clip again (`robotMoveStart`, then
		# `resetRobotMc`: `setRobotMc` facing `robotDirect`, the weapon's clip with it).
		var pushed: bool = not actor.get("pushed", {}).is_empty()
		if view.get("pushed", false) and not pushed and actor.get("alive", false): _set_robot_mc(view, view.suffix)
		view.pushed = pushed
		if not human and direction != Vector2i.ZERO and direction != view.direction: _turn(view, direction)
		_vehicle(view, actor)
		_weapon(view, actor, attacks.get(id, {}))
		_shield(view, actor)
		_invincibility_prop(view, actor)
		_send_robot(view, actor)
		if direction == Vector2i.ZERO:
			view.playing = false
			view.weapon_playing = false
			view.shield_playing = false
		view.direction = direction
		if int(actor.get("blink_until", 0)) > view.blink_until:
			# robotRelive: a new InvincibilityCommand.
			view.blink_until = int(actor.blink_until)
			view.blink = 0
			view.blinking = true
		_invincibility(view)
		view.position = actor.get("position", view.position)
		if last: _show(view)
	if last:
		for view in _robots.values():
			if view.dead and not view.removed: _show(view)
	_update_bombs(snapshot)
	_update_items(snapshot)


static func _direction(v: Vector2) -> Vector2i:
	if v == Vector2.ZERO: return Vector2i.ZERO
	return Vector2i(int(signf(v.x)), 0) if absf(v.x) >= absf(v.y) else Vector2i(0, int(signf(v.y)))


## `RobotView.robotTurn` (a new clip, playing, its weapon playing too) or, facing that way
## already, `robot_turnHandler`'s `mc.play()` (the weapon stays as it is).
## The new clip shows its first frame on the next frame and plays from the one after (a key
## press between frames, and the AI's turn alike: recorded, gameplay-cinema-ai).
func _turn(view: Dictionary, direction: Vector2i, hold := 1) -> void:
	var suffix: String = DIRECTIONS[direction]
	if view.suffix != suffix:
		_set_robot_mc(view, suffix)
		view.fresh = hold
		view.weapon_playing = true
		view.weapon_fresh = hold
		view.shield_fresh = hold
	view.playing = true


func _clip_class(view: Dictionary, suffix: String) -> String:
	return "_r%d%s%s" % [view.robot, "" if suffix == "_Dead" else VEHICLE_CLIPS.get(view.vehicle, ""), suffix]


## `RobotView.setRobotMc`: the clip of this robot, ride and direction, with its look, stopped
## at its first frame and put at the bottom of the robot's container (`addChildAt(_mc, 0)`).
## The look is set by sending the innermost `bodyMc` to clothID + 1 and `hatMc` to hatID + 1;
## a clip without them takes those frames itself (the `_Dead` clips, `_r0_Down` with no hat).
## Then the weapon's clip is made again (`updateWeaponDisplay`).
func _set_robot_mc(view: Dictionary, suffix: String) -> void:
	view.suffix = suffix
	view.class = _clip_class(view, suffix)
	var clip: Dictionary = _art.get("robots", {}).get(view.class, {})
	view.frame = 1
	if not clip.is_empty():
		if not clip.hat: view.frame = view.hat + 1
		elif not clip.body: view.frame = view.cloth + 1
		view.frame = clampi(view.frame, 1, int(clip.frames))
	view.playing = false
	# Made during the frame's scripts, the clip shows its first frame on the next frame too
	# (a ride's clip after the pickup, the robot after a swing; recorded).
	view.fresh = 1
	view.loop_age = 0
	# A new MovieClip: alpha 1 (SendRobotCommand faded the old one); the shield's new
	# `nombril<direction>` where the clip has a `hand2` (`gotoAndPlay(_mc.currentFrame)`).
	view.alpha = 1.0
	view.shield_class = ""
	if view.shield and not suffix.begins_with("_Dead") and _effects().get("hand2", {}).has(view.class):
		view.shield_class = "nombril" + suffix
		view.shield_frame = clampi(view.frame, 1, _effect_total(view.shield_class))
		view.shield_playing = true
		view.shield_fresh = 1
	var mc: Dictionary = _child(view, "mc")
	if not mc.is_empty():
		view.children.erase(mc)
		view.children.insert(0, mc)
		_arrange(view)
	if view.weapon != &"" and suffix != "_Dead":
		_update_weapon_display(view)


## The frame after `frame` of a playing robot clip, as the art pass saw it play (a ride's clip
## loops over its driving frames only); else the next frame, wrapping.
func _next_frame(cls: String, frame: int) -> int:
	var nxt: Dictionary = _art.get("robots", {}).get(cls, {}).get("next", {})
	if nxt.has(str(frame)): return int(nxt[str(frame)])
	return frame % _total(cls) + 1


func _total(cls: String) -> int:
	return int(_art.get("robots", {}).get(cls, {}).get("frames", 24))


## `AbstractRobot.kill`: the `_Dead` clip, stopped; RobotDeadCommand advances it. The robot's
## weapon goes with it (`clearWeapon`).
func _kill(view: Dictionary) -> void:
	view.dead = true
	view.offset = false
	_clear_weapon(view)
	_set_robot_mc(view, "_Dead")
	# `clearDisplay`: the container keeps only the clip (the item Sprite goes too).
	_remove_child(view, "item")
	view.inv_play = -1
	view.filter = {}


## `AbstractPlayer.robotRelive` (a mode that brings robots back: Battle Royale, Green Zone,
## Pac-Man): the robot stands on its start cell again; `AbstractRobot.relive` clears its
## weapon, `RobotModel.initModel` faces it down on foot, `RobotController.initStage` makes its
## clip again (`resetRobotMc`) and `resetMainContainer` puts its container back on its row.
## The new InvincibilityCommand comes with the round's `blink_until`.
func _relive(view: Dictionary, actor: Dictionary) -> void:
	if view.removed:
		view.layer = ""
	view.dead = false
	view.removed = false
	view.offset = false
	_clear_weapon(view)
	view.vehicle = &""
	view.vehicle_hit = -1
	view.direction = Vector2i.ZERO
	view.position = actor.get("position", view.position)
	_place(view, floori((view.position as Vector2).y + 0.5), view.robot_row)
	_set_robot_mc(view, "_Down")


## `RobotDeadCommand.countDead`, once per tick.
func _count_dead(view: Dictionary) -> void:
	if view.frame >= _total(view.class) - 1:
		_board.detach(view.layer, view.item)
		view.removed = true
	else:
		view.frame += 1


## `InvincibilityCommand.execute`, once per tick.
func _invincibility(view: Dictionary) -> void:
	if not view.blinking: return
	if view.blink > INVINCIBILITY_FRAMES:
		view.blinking = false
		view.bright = false
		view.blink = 0
		return
	view.blink += 1
	if view.blink % 4 == 0: view.bright = not view.bright


## Rides (`CarProp.changeStage` / `MotoCycleProp.changeStage`: `resetStage`, the vehicle, then
## `resetRobotMc`); a hit (`TryToKillCommandChain`: `gotoAndStop("dead")`, then a 1 s TweenMax
## to the clip's last frame, on the host's clock) and `vehicleComplete`'s `resetStage` (on foot).
func _vehicle(view: Dictionary, actor: Dictionary) -> void:
	var vehicle := StringName(actor.get("vehicle", &""))
	if vehicle != view.vehicle:
		view.vehicle = vehicle
		view.vehicle_hit = -1
		_set_robot_mc(view, view.suffix)
		return
	if vehicle == &"": return
	var recovery := int(actor.get("vehicle_recovery_until", 0))
	if recovery > 0 and view.vehicle_hit < 0:
		view.vehicle_hit = 0
		view.playing = false
		view.weapon_playing = false
	if view.vehicle_hit >= 0:
		var clip: Dictionary = _art.get("robots", {}).get(view.class, {})
		var dead := int(clip.get("labels", {}).get("dead", clip.get("frames", 1)))
		var total := int(clip.get("frames", dead))
		view.frame = dead + roundi((total - dead) * minf(1.0, float(view.vehicle_hit) / VEHICLE_HIT_TICKS))
		view.vehicle_hit += 1


# ------------------------------------------------------------------ weapons

## The robot's weapon (`AbstractWeapon`): a pickup's `changeStage` (showTimes, then the held
## clip), `bombDown` (the held clip goes, the `_Play` clip comes; the count goes down), the end
## of the action (`HammerPlayCommand`: the `_Play` clip goes, `robotMoveStart` makes the robot's
## clip again; the last use's `initWeapon` takes the weapon off).
func _weapon(view: Dictionary, actor: Dictionary, attack: Dictionary) -> void:
	var kind := StringName(actor.get("weapon", &""))
	if not WEAPON_NAMES.has(kind): kind = &""
	var ammo := int(actor.get("ammo", 0))
	var acting: bool = not attack.is_empty()
	if view.play_class != "" and (not acting or int(attack.started) != view.play_started):
		# The action is over: the `_Play` clip goes and the robot's clip is made again.
		_remove_child(view, "play")
		view.play_class = ""
		view.play_started = -1
		if kind != view.weapon or ammo <= 0: _clear_weapon(view)
		_set_robot_mc(view, view.suffix)
	if kind != view.weapon and not acting:
		_clear_weapon(view)
		if kind != &"":
			# `AbstractWeapon.changeStage`: `setWeaponTimesMc` (showTimes on top), `setWeaponMc`.
			view.weapon = kind
			view.ammo = ammo
			_add_child(view, {"kind": "times"}, -1)
			_update_weapon_display(view)
	if acting and view.play_class == "" and view.weapon != &"" and attack.get("kind", &"") == view.weapon:
		view.ammo = ammo
		if view.weapon == &"hammer":
			# `bombDown`: `robotMoveStop(true)` (the robot's clip stops, the held clip goes), the
			# `_Play` clip at `_playPos` (under the robot facing up or left).
			view.playing = false
			view.weapon_playing = false
			_remove_child(view, "weapon")
			view.weapon_class = ""
			view.play_class = "%s%s_Play" % [WEAPON_NAMES[view.weapon], view.suffix]
			view.play_started = int(attack.started)
			_add_child(view, {"kind": "play"}, 0 if view.suffix in PLAY_BEHIND else -1)
	if view.weapon != &"" and ammo != view.ammo and not acting:
		view.ammo = ammo


## `updateWeaponDisplay`: a new held clip `<name><direction>` at the robot's hand (where the
## new robot clip's `hand` is at its first frame), playing from the robot's frame; on a ride it
## is made but not added. Its place in the container depends on the weapon and direction.
func _update_weapon_display(view: Dictionary) -> void:
	_remove_child(view, "weapon")
	view.weapon_class = ""
	var clip: Dictionary = _art.get("robots", {}).get(view.class, {})
	if not clip.has("hand") or view.vehicle != &"": return
	var name: String = WEAPON_NAMES[view.weapon]
	view.weapon_class = name + view.suffix
	view.weapon_frame = clampi(view.frame, 1, maxi(1, _weapon_total("held", view.weapon_class)))
	view.weapon_playing = false
	var behind: bool = view.suffix == "_Left" or (name not in BEHIND_LEFT_ONLY and view.suffix == "_Up")
	_add_child(view, {"kind": "weapon"}, 0 if behind else -1)


## `clearWeapon` / `initWeapon`: the weapon's clips and counter leave the robot.
func _clear_weapon(view: Dictionary) -> void:
	for kind in ["weapon", "play", "times"]: _remove_child(view, kind)
	view.weapon = &""
	view.weapon_class = ""
	view.play_class = ""
	view.play_started = -1


func _weapon_total(bucket: String, cls: String) -> int:
	return int(_art.get("weapons", {}).get(bucket, {}).get(cls, {}).get("frames", 1))


# ------------------------------------------------------------------ effects

func _effects() -> Dictionary:
	return _art.get("effects", {})


func _effect_total(cls: String) -> int:
	return maxi(1, int(_effects().get("clips", {}).get(cls, {}).get("frames", 1)))


## `ShieldProp.changeStage` (`initMc`: `resetRobotMc`, so a new robot clip with its nombril)
## and `addUseNum` (the shield used: its nombril leaves the clip).
func _shield(view: Dictionary, actor: Dictionary) -> void:
	var on: bool = int(actor.get("shield", 0)) > 0 and not view.dead
	if on == view.shield: return
	view.shield = on
	if on:
		_set_robot_mc(view, view.suffix)
	else:
		view.shield_class = ""


## `InvincibilityProp.changeStage`, `CountMcPlayCommand` and `CountInvincibilityCommand`, once
## per tick, timed by the snapshot: the introduction runs from the pickup to
## `invincible_active_from` (29 ticks), the filter from there to `invincible_until`.
func _invincibility_prop(view: Dictionary, actor: Dictionary) -> void:
	var from := int(actor.get("invincible_active_from", 0))
	var until := int(actor.get("invincible_until", 0))
	if from != view.inv_from and from > _now and until > _now:
		# A pickup: `gotoAndPlay(1)` on a running introduction; else a new `invincibityPlay` in
		# `itemMc`, which `setItemMc` puts on top of the container (the chain before it goes;
		# its filter stays on the clip until the new chain sets one).
		view.inv_from = from
		if view.inv_play < 0:
			_remove_child(view, "item")
			_add_child(view, {"kind": "item"}, -1)
		view.inv_play = _now
	if view.inv_play >= 0 and _now >= view.inv_from:
		# CountMcPlayCommand: the clip off on its frame totalFrames - 1; the filter's chain.
		view.inv_play = -1
		view.filter_count = 0
	if view.inv_play < 0 and view.inv_from > 0 and _now >= view.inv_from:
		if _now < until:
			# CountInvincibilityCommand.execute: `_colortime += _step`; below -20 it is 0 again and
			# the colours turn by one.
			view.filter_count += 1
			var colortime: int = FILER_STEP if view.filter_count % 2 == 1 else 0
			var turns: int = view.filter_count / 2
			var colors := []
			for k in FILER_COLOR.size(): colors.append(FILER_COLOR[(k + turns) % FILER_COLOR.size()])
			var ratios := []
			var alphas := []
			for value in FILER_STR:
				ratios.append(value + colortime)
				alphas.append(FILER_ALPHA)
			view.filter = {"type": "GradientGlowFilter", "distance": -20, "angle": 60, "colors": colors, "alphas": alphas,
				"ratios": ratios, "blur_x": 18, "blur_y": 18, "strength": 1, "quality": 3, "inner": true, "knockout": false}
		elif not view.filter.is_empty():
			# `_time > _totalTime`: `mc.filters = []`, the weapon's too.
			view.filter = {}
			view.inv_from = 0


## `SendRobotCommand.execute`: the clip fades for 29 callbacks; the 30th (`robotMoveStart`,
## `sendEnd`) makes the robot's clip again where the other portal is.
func _send_robot(view: Dictionary, actor: Dictionary) -> void:
	var until := int(actor.get("transit_until", 0))
	if until > _now:
		if not view.transit:
			# Portal.runEngine: `robotMoveStop` (RobotView.robotMoveStop(false): the clip stops,
			# the weapon's goes to frame 1).
			view.transit = true
			view.playing = false
			view.weapon_playing = false
			view.weapon_frame = 1
		var frame_count := SEND_TOTAL_FRAME - (until - _now)
		view.alpha = 1.0 - frame_count / GAME_FRAMERATE
	elif view.transit:
		view.transit = false
		_set_robot_mc(view, view.suffix)


## The shield's nombril in the robot's clip: drawn with the clip (a baked node), at hand2.
func _show_shield(view: Dictionary, mc_path: String, at: Transform2D, offset: Color) -> void:
	var path := mc_path + "/~shield"
	var shown: bool = _screen.by_path.has(path)
	if view.shield_class == "" or view.dead:
		if shown: _screen.remove_node(path)
		return
	if not shown: _add_art_node(path, mc_path, _a(at))
	var hand: Array = _effects().get("hand2", {}).get(view.class, [0, 0])
	_screen.move_node(path, _a(at * Transform2D(0.0, Vector2(hand[0], hand[1]))))
	var images: Dictionary = _effects().get("clips", {}).get(view.shield_class, {}).get("images", {})
	_screen.set_node_art(path, images.get(str(view.shield_frame), {}))
	_screen.set_node_offset(path, offset)
	# `setRobotMc`: `addChildAt(_shieldContainer, 0)` facing right, else `addChild`.
	_screen.set_node_under(path, view.suffix == "_Right")


# ------------------------------------------------------------------ the robot's container

## `resetMainContainer`: on its row's `robotRow` layer, judged from where it stood.
func _reset_main_container(view: Dictionary) -> void:
	var row := floori((view.position as Vector2).y + 0.5)
	if row != view.row or view.layer == "":
		_place(view, row, view.robot_row)


## The robot's container (`_container`) on a row layer, with its children in their order.
func _place(view: Dictionary, row: int, layer_index: int) -> void:
	if view.layer != "": _board.detach(view.layer, view.item)
	view.row = row
	view.layer = _board.layer_of(row, layer_index)
	view.item = {}
	_board.attach(view.layer, view.item, _board.cell_matrix(view.position))
	if view.children.is_empty(): view.children.append({"kind": "mc"})
	for child in view.children:
		child.erase("rel")
	view.loop_count = 0
	_arrange(view)


func _child(view: Dictionary, kind: String) -> Dictionary:
	for child in view.children:
		if child.kind == kind: return child
	return {}


## `addChild` (index -1) or `addChildAt(child, index)` in the robot's container.
func _add_child(view: Dictionary, child: Dictionary, index: int) -> void:
	if index < 0: view.children.append(child)
	else: view.children.insert(index, child)
	_arrange(view)


func _remove_child(view: Dictionary, kind: String) -> void:
	var child := _child(view, kind)
	if child.is_empty(): return
	if child.has("rel"): _screen.remove_node(_path(view, child))
	if kind == "mc": view.loop_count = 0
	view.children.erase(child)
	_arrange(view)


## A child's path on the screen: the container's (renamed when its row layer changes) and its
## own name in the container.
static func _path(view: Dictionary, child: Dictionary) -> String:
	return "%s/%s" % [view.item.path, child.rel]


## The container's children on the screen: each at its display-list path (`@0` alone, `@0#k`
## among several) and drawn in that order.
func _arrange(view: Dictionary) -> void:
	if view.item.is_empty(): return
	var base: String = view.item.path
	var n: int = view.children.size()
	# Two passes, so a child can take a path another one leaves.
	for k in n:
		var child: Dictionary = view.children[k]
		if child.has("rel"):
			_screen.rename_node(_path(view, child), "%s/~%d" % [base, k])
			child.rel = "~%d" % k
	for k in n:
		var child: Dictionary = view.children[k]
		var rel := "@0" if n == 1 else "@0#%d" % k
		var path := "%s/%s" % [base, rel]
		if child.has("rel"):
			_screen.rename_node(_path(view, child), path)
			child.rel = rel
		else:
			child.rel = rel
			var matrix: Array = _board.cell_matrix(view.position)
			# (the item Sprite holds a clip of its own; a Sprite reports frame 0)
			var item: bool = child.kind == "item"
			_screen.add_node({"path": path, "parent": base, "stage_matrix": matrix, "role": "group" if item else "piece",
				"kind": "movie_clip", "effective_visible": true, "frame": 0 if item else 1})
			if child.kind == "mc":
				view.loop_count = 0
			elif child.kind == "times":
				# showTimes draws its showWeaponMc in its art; its count is a node of its own.
				_add_art_node(path + "/~count", path, matrix)
		var node: Node2D = _screen.by_path.get(path)
		if node != null: node.get_parent().move_child(node, k)


## A node that only draws (no display-list path of its own: drawn inside a baked clip).
func _add_art_node(path: String, parent: String, matrix: Array) -> void:
	_screen.add_node({"path": path, "parent": parent, "stage_matrix": matrix, "role": "piece", "kind": "movie_clip",
		"effective_visible": true})
	var node: Node2D = _screen.by_path.get(path)
	if node != null:
		node.remove_meta("swf_path")
		node.set_meta("swf_art", true)


func _show(view: Dictionary) -> void:
	if view.removed or view.item.is_empty(): return
	var matrix: Array = _board.cell_matrix(view.position)
	var at := _m(matrix)
	_screen.move_node(view.item.path, matrix)
	var on: bool = view.bright and not view.dead
	var offset := Color(50.0 / 255, 50.0 / 255, 50.0 / 255, 1) if on else Color(0, 0, 0, 0)
	var art_at := _m(_art.get("at", matrix))
	for child in view.children:
		var path := _path(view, child)
		# InvincibilityCommand's offset is on the robot's container: every child takes it.
		_screen.set_node_offset(path, offset)
		match child.kind:
			"mc":
				_screen.move_node(path, matrix)
				var art := _robot_art(view)
				_screen.set_node_art(path, art, view.frame)
				_show_loops(view, path, at, art, offset)
				_show_shield(view, path, at, offset)
				_screen.set_node_alpha(path, view.alpha)
				_screen.set_node_filter(path, view.filter)
			"item":
				# The `itemMc` Sprite (at the container's origin) and its `invincibityPlay`.
				_screen.move_node(path, matrix)
				var play := path + "/@0"
				var playing: bool = view.inv_play >= 0
				if playing and not _screen.by_path.has(play):
					_screen.add_node({"path": play, "parent": path, "stage_matrix": matrix, "role": "piece", "kind": "movie_clip",
						"effective_visible": true, "frame": 1})
				elif not playing and _screen.by_path.has(play):
					_screen.remove_node(play)
				if playing:
					var frame: int = clampi(_tick_now() - view.inv_play, 1, _effect_total("invincibityPlay"))
					_screen.move_node(play, matrix)
					_screen.set_node_offset(play, offset)
					_screen.set_node_art(play, _effects().get("clips", {}).get("invincibityPlay", {}).get("images", {}).get(str(frame), {}), frame)
			"weapon":
				# The hand where the robot clip's first frame was rendered (its own `at`).
				var clip: Dictionary = _art.get("robots", {}).get(view.class, {})
				var first: Dictionary = clip.get("looks", {}).values()[0].get("1", {}) if not clip.get("looks", {}).is_empty() else {}
				var clip_at := _m(first.get("at", _a(art_at)))
				var hand: Vector2 = (clip_at.affine_inverse() * _m(clip.get("hand", _a(clip_at)))).origin
				_screen.move_node(path, _a(at * Transform2D(0.0, hand)))
				var images: Dictionary = _art.get("weapons", {}).get("held", {}).get(view.weapon_class, {}).get("images", {})
				_screen.set_node_art(path, images.get(str(view.weapon_frame), {}), view.weapon_frame)
				# CountInvincibilityCommand: `weaponMc.filters` as the clip's.
				_screen.set_node_filter(path, view.filter)
			"play":
				var frame: int = clampi(_tick_now() - view.play_started + 1, 1, maxi(1, _weapon_total("play", view.play_class)))
				_screen.move_node(path, _a(at * Transform2D(0.0, HAMMER_PLAY_POS.get(view.suffix, Vector2.ZERO))))
				var images: Dictionary = _art.get("weapons", {}).get("play", {}).get(view.play_class, {}).get("images", {})
				_screen.set_node_art(path, images.get(str(frame), {}), frame)
			"times":
				var times := at * Transform2D(0.0, TIMES_AT)
				_screen.move_node(path, _a(times))
				_screen.set_node_art(path, _art.get("weapons", {}).get("times", {}).get(String(view.weapon), {}), 1)
				var digit: Dictionary = _art.get("weapons", {}).get("digits", {}).get(str(view.ammo), {})
				if not digit.is_empty():
					_screen.move_node(path + "/~count", _a(times * _m(digit.times_at).affine_inverse() * _m(digit.at)))
				_screen.set_node_art(path + "/~count", digit)
				_screen.set_node_offset(path + "/~count", offset)


## The robot clip's own loops (eyes blinking, a feather): each its own node over the clip,
## where the art pass found it at this root frame, at its own frame (made with the clip, it
## shows its first frame twice, then one frame per frame).
func _show_loops(view: Dictionary, mc_path: String, at: Transform2D, art: Dictionary, offset: Color) -> void:
	var loops: Array = art.get("loops", [])
	while view.loop_count < loops.size():
		_add_art_node("%s/~loop%d" % [mc_path, view.loop_count], mc_path, _a(at))
		view.loop_count += 1
	var robot_at := _m(art.get("at", _a(at)))
	for k in view.loop_count:
		var path := "%s/~loop%d" % [mc_path, k]
		if k >= loops.size():
			_screen.set_node_art(path, {})
			continue
		var loop: Dictionary = loops[k]
		var frames: Dictionary = _art.get("loop_art", {}).get(loop.art, {})
		var frame: int = maxi(0, view.loop_age - 1) % maxi(1, frames.size()) + 1
		_screen.move_node(path, _a(at * robot_at.affine_inverse() * _m(loop.at)))
		_screen.set_node_art(path, frames.get(str(frame), {}))
		_screen.set_node_offset(path, offset)


## The tick being shown (`update` steps through the ticks since the last snapshot).
func _tick_now() -> int:
	return _now


func _robot_art(view: Dictionary) -> Dictionary:
	var clip: Dictionary = _art.get("robots", {}).get(view.class, {})
	if clip.is_empty(): return {}
	var key := "%d|%d" % [view.cloth if clip.body else -1, view.hat if clip.hat else -1]
	var looks: Dictionary = clip.looks
	# A look the pack has no art for (record_screen.py actors --looks all renders every one)
	# shows the robot's default look.
	var frames: Dictionary = looks.get(key, looks.get("%d|%d" % [0 if clip.body else -1, 0 if clip.hat else -1], {}))
	return frames.get(str(view.frame), {})


static func _m(m: Array) -> Transform2D:
	return Transform2D(Vector2(m[0], m[1]), Vector2(m[2], m[3]), Vector2(m[4], m[5]))


static func _a(t: Transform2D) -> Array:
	return [t.x.x, t.x.y, t.y.x, t.y.y, t.origin.x, t.origin.y]


# ------------------------------------------------------------------ bombs

## `Bomb`: placed bombs, their blasts (the snapshot's flames) and `ended`.
func _update_bombs(snapshot: Dictionary) -> void:
	for arm in _spent_arms.duplicate():
		arm.age += 1
		_screen.set_node_art(arm.item.path, _exp(arm.frame, arm.age + 1), arm.frame)
		if arm.age + 1 >= _exp_art.get(str(arm.frame), {}).size(): _spent_arms.erase(arm)
	var live := {}
	var shown: Array = snapshot.get("bomb_display", [])
	var bombs: Array = snapshot.get("bombs", [])
	for k in bombs.size():
		# The simulation's display fields for this bomb (serial, flying), when it gives them.
		var bomb: Dictionary = bombs[k].merged(shown[k]) if k < shown.size() else bombs[k]
		live[_bomb_key(bomb)] = bomb
	var flames := {}
	for flame in snapshot.get("flames", []):
		var bomb: Dictionary = flame.get("bomb", {})
		if not bomb.is_empty(): flames[_bomb_key(bomb)] = flame
	for view in _bombs.duplicate():
		view.age += 1
		if view.blasted:
			# `ended`: `_continueTime > 15`.
			if view.age >= BLAST_TICKS:
				_board.detach(view.layer, view.item)
				_bombs.erase(view)
				# The flames stay on the display list (`deleFire` takes no clip off), their nested
				# blast playing on to its last, empty frame (recorded: frame 18 at age 17).
				for arm in view.arms:
					arm.age = view.age
					_spent_arms.append(arm)
				continue
		elif flames.has(view.key) and not live.has(view.key):
			_blast(view, flames[view.key])
		elif not live.has(view.key):
			# `disappear`: taken off without a blast.
			_board.detach(view.layer, view.item)
			_bombs.erase(view)
			continue
		else:
			var bomb: Dictionary = live[view.key]
			# `Bomb.kickedFly` -> `shootFunc`: `resetDisplay` (on the row it stood on), then the step.
			if bomb.get("flying", false): _reset_bomb_display(view, floori((view.position as Vector2).y + 0.5))
			view.cell = bomb.cell
			view.position = bomb.get("position", Vector2(bomb.cell))
		_show_bomb(view)
	for key in live:
		if _bombs.any(func(v): return v.key == key): continue
		var bomb: Dictionary = live[key]
		# A bomb the AI drops during the frame's scripts shows its first frame once more than
		# one dropped by key between frames (recorded, gameplay-cinema-ai).
		var view := {"key": key, "cell": bomb.cell, "power": int(bomb.power), "age": 0 if bomb.actor_id == &"human" else -1, "blasted": false,
			"position": bomb.get("position", Vector2(bomb.cell)), "arms": []}
		# Bomb.init: a Sprite on its row's bomb layer (2).
		view.layer = _board.layer_of(floori((view.position as Vector2).y + 0.5), 2)
		view.item = {}
		_board.attach(view.layer, view.item, _board.cell_matrix(view.position))
		_screen.add_node({"path": view.item.path + "/@0", "parent": view.item.path, "stage_matrix": _board.cell_matrix(view.position),
			"role": "piece", "kind": "movie_clip", "effective_visible": true, "frame": 1})
		_bombs.append(view)
		_show_bomb(view)
	# `ConveyorBelt.bombMove`: `resetDisplay` on the row the bomb now stands on, in the belt's order.
	for moved in _belt_moved(snapshot):
		if moved[0] != "bomb": continue
		for view in _bombs:
			if view.key == "s%d" % int(moved[1]) and not view.blasted: _reset_bomb_display(view, int(moved[2]))


static func _key(actor_id, cell) -> String:
	return "%s|%s" % [actor_id, cell]


## One bomb's views follow it by its serial (display field), so a carried or thrown bomb keeps
## its clip (and its frame) from cell to cell.
static func _bomb_key(bomb: Dictionary) -> String:
	return "s%d" % int(bomb.serial) if bomb.has("serial") else _key(bomb.actor_id, bomb.cell)


## `Bomb.resetDisplay`: the bomb's Sprite leaves its layer and is added again, last, to the
## bomb layer (2) of row `row` (`game.getDisArr(yN).getChildAt(2)`).
func _reset_bomb_display(view: Dictionary, row: int) -> void:
	_board.detach(view.layer, view.item)
	view.layer = _board.layer_of(row, 2)
	view.item = {}
	_board.attach(view.layer, view.item, _board.cell_matrix(view.position))
	_screen.add_node({"path": view.item.path + "/@0", "parent": view.item.path, "stage_matrix": _board.cell_matrix(view.position),
		"role": "piece", "kind": "movie_clip", "effective_visible": true, "frame": 1})
	_show_bomb(view)


## This tick's `resetDisplay` calls of the Candy Factory belt (`ConveyorBelt.runEngine`, display
## field `moved`: `[kind, id, row]` in its order).
static func _belt_moved(snapshot: Dictionary) -> Array:
	for state: Dictionary in snapshot.get("features", []):
		if state.get("kind") == &"belt": return state.get("moved", [])
	return []


## `Bomb.blast`: exp0 replaces the bomb clip, and an exp0 per flame cell goes on that row's
## platform layer at `xPos + EXCURSION_X ± k * GRID_WIDTH` (the bomb's position, not its cell's).
func _blast(view: Dictionary, flame: Dictionary) -> void:
	view.blasted = true
	view.age = 0
	var centre: Vector2i = view.cell
	for cell: Vector2i in flame.get("cells", []):
		if cell == centre: continue
		var offset := cell - centre
		var distance := absi(offset.x) + absi(offset.y)
		var ray := offset / distance
		var frame: int = ARM_FRAMES[ray][1 if distance == view.power else 0]
		var arm := {"frame": frame, "item": {}, "layer": _board.layer_of(cell.y, 0), "cell": cell}
		# At the bomb's own position (`xPos + EXCURSION_X + _mc.x`, ± k * GRID_WIDTH): off the grid
		# when a belt carried it.
		_board.attach(arm.layer, arm.item, _board.cell_matrix(view.position + Vector2(offset)), {}, "piece")
		view.arms.append(arm)


func _show_bomb(view: Dictionary) -> void:
	var matrix: Array = _board.cell_matrix(view.position)
	_screen.move_node(view.item.path, matrix)
	_screen.move_node(view.item.path + "/@0", matrix)
	if not view.blasted:
		var age := maxi(0, int(view.age))
		var key := "%d|%d" % [age % 27 + 1, age % 14 + 1]
		_screen.set_node_art(view.item.path + "/@0", _bomb_art.get(key, {}), age % 27 + 1)
		return
	_screen.set_node_art(view.item.path + "/@0", _exp(1, maxi(1, view.age + 1)), 1)
	for arm in view.arms:
		_screen.set_node_art(arm.item.path, _exp(arm.frame, view.age + 1), arm.frame)


## exp0 stopped at `root`, its nested blast at `nested` (it stops on its last frame).
func _exp(root: int, nested: int) -> Dictionary:
	var by_nested: Dictionary = _exp_art.get(str(root), {})
	if by_nested.is_empty(): return {}
	return by_nested.get(str(mini(nested, by_nested.size())), {})


# ------------------------------------------------------------------ pickups

## `AbstractItem` per pickup of the snapshot (`pickups`: cell -> kind), once per tick. A pickup
## the Candy Factory belt carries (its `carried` display field: cell -> [id, position]) is one
## view from cell to cell, at its position between cells (`ConveyorBelt.propMove`), and keeps
## its PixelClip's loop.
func _update_items(snapshot: Dictionary) -> void:
	var pickups: Dictionary = snapshot.get("pickups", {})
	var burning := {}
	for flame in snapshot.get("flames", []):
		for cell in flame.get("cells", []): burning[cell] = true
	var carried := {}
	for state: Dictionary in snapshot.get("features", []):
		match state.get("kind"):
			&"belt": carried = state.get("carried", {})
			# `Crocodile.eat` on each open tick: the pickup on its cell goes by `deleProp`.
			&"crocodile":
				if int(state.frame) > 264 and int(state.frame) <= 324: burning[Vector2i(state.cell)] = true
	var present := {}
	for cell in pickups:
		if pickups[cell] == &"coin": continue
		present["p%d" % int(carried[cell][0]) if carried.has(cell) else cell] = cell
	for key in _items.keys():
		var view: Dictionary = _items[key]
		view.age += 1
		if view.has("brick"):
			_count_brick_exp(view)
		elif not present.has(key) or pickups.get(present[key], &"") != view.kind:
			if burning.has(view.cell): _dele_prop(view)
			else: _eat_prop(view)
		else:
			view.cell = present[key]
			if carried.has(view.cell): view.position = carried[view.cell][1]
			_play_arr(view)
	for key in present:
		if _items.has(key): continue
		var cell: Vector2i = present[key]
		_init_item(key, cell, pickups[cell], carried[cell][1] if carried.has(cell) else Vector2(cell))
	# `ConveyorBelt.propMove`: `resetDisplay` puts the item's Sprite last on the row it now stands on.
	for moved in _belt_moved(snapshot):
		if moved[0] == "prop" and _items.has("p%d" % int(moved[1])):
			_reset_item_display(_items["p%d" % int(moved[1])], int(moved[2]))
	_update_disappear(snapshot)


## `ConveyorBelt.addDisappearAni`: where a carried item leaves the belt (its last cell), a
## stopped `Art_Prop_Disappear` at `(xN + 0.5) * GRID_WIDTH + EXCURSION_X - 5`,
## `(yN + 0.5) * GRID_WIDTH + EXCURSION_Y`, turned to the last segment's direction
## (`mVector.angle`, degrees), last on that row's platform layer (`getDisArr(yN).getChildAt(0)`).
## `countDisappearAni` runs on the brick explosion handlers, after the engine handlers that
## made it, so the clip is first drawn on frame 2, one frame further per tick, and taken off
## on the tick it reaches its last frame (`currentFrame == totalFrames`).
func _update_disappear(snapshot: Dictionary) -> void:
	var clip: Dictionary = _board.stopped_art("Art_Prop_Disappear")
	var frames: Dictionary = clip.get("frames", {})
	var total := int(clip.get("total", 0))
	for view in _disappearing.duplicate():
		view.frame += 1
		if view.frame >= total:
			_board.detach(view.layer, view.item)
			_disappearing.erase(view)
		else:
			_screen.set_node_art(view.item.path, frames.get(str(view.frame), {}), view.frame)
	if total == 0: return
	for state: Dictionary in snapshot.get("features", []):
		if state.get("kind") != &"belt": continue
		for gone: Array in state.get("disappeared", []):
			var cell: Vector2i = gone[0]
			var view := {"frame": 2, "item": {}, "layer": _board.layer_of(cell.y, 0)}
			var at := _rotate(_board.cell_matrix(Vector2(cell) + Vector2(0.5 - 5.0 / 30.0, 0.5)), float(gone[1]))
			_board.attach(view.layer, view.item, at, {}, "piece", false, view.frame)
			if view.frame >= total:
				_board.detach(view.layer, view.item)
				continue
			_screen.set_node_art(view.item.path, frames.get(str(view.frame), {}), view.frame)
			_disappearing.append(view)


## A Flash `rotation` (degrees) set on a child at stage matrix `m`.
static func _rotate(m: Array, degrees: float) -> Array:
	var c := cos(deg_to_rad(degrees))
	var s := sin(deg_to_rad(degrees))
	return [m[0] * c + m[2] * s, m[1] * c + m[3] * s, m[2] * c - m[0] * s, m[3] * c - m[1] * s, m[4], m[5]]


## `AbstractItem.init` / `setProp` / `getMc`: the Sprite on its row at the cell, the
## PixelClip's Sprite and empty Bitmap inside it.
func _init_item(key, cell: Vector2i, kind: StringName, position: Vector2) -> void:
	var view := {"key": key, "cell": cell, "kind": kind, "age": 0, "item": {}, "row": _board.row_of(cell.y), "shown": -1,
		"position": position}
	_add_item_display(view)
	_items[key] = view


func _add_item_display(view: Dictionary) -> void:
	var at: Array = _board.cell_matrix(view.position)
	_board.attach(view.row, view.item, at)
	var holder := _translate(at, Vector2(int(15 - PIXEL_CLIP[0] / 2.0) + PIXEL_CLIP[2], int(15 - PIXEL_CLIP[1] / 2.0) + PIXEL_CLIP[3]))
	_screen.add_node({"path": view.item.path + "/@0", "parent": view.item.path, "stage_matrix": holder,
		"role": "group", "kind": "movie_clip", "effective_visible": true, "frame": 0})
	_screen.add_node({"path": view.item.path + "/@0/@0", "parent": view.item.path + "/@0", "stage_matrix": _translate(holder, Vector2(-15, -15)),
		"role": "piece", "kind": "bitmap", "effective_visible": true})


## `AbstractItem.resetDisplay`: `_mainContainer.removeChild(_container)`, then
## `game.getDisArr(yN).addChild(_container)`, at the item's position (`xPos`, `yPos`).
func _reset_item_display(view: Dictionary, row: int) -> void:
	_board.detach(view.row, view.item)
	view.row = _board.row_of(row)
	view.item = {}
	_add_item_display(view)
	view.shown = -1
	_play_arr(view)


## `PixelClip.playArr`: the bitmap shown at this age (see the header for the recorded start).
func _play_arr(view: Dictionary) -> void:
	var art: Dictionary = _item_art.get(String(view.kind), {})
	if view.age < 1 or art.is_empty(): return
	var index: int = ((view.age - 1) / 4) % maxi(1, int(art.cycle))
	if index == view.shown: return
	view.shown = index
	# The bitmaps were rendered as the item's Sprite (record_screen.py items): drawn on it.
	_screen.set_node_art(view.item.path, art.bitmaps[index])


## `eatProp`: the Sprite leaves its row.
func _eat_prop(view: Dictionary) -> void:
	_board.detach(view.row, view.item)
	_items.erase(view.key)


## `deleProp` -> `brickExp`: the PixelClip goes, `brickExp` plays in the Sprite.
func _dele_prop(view: Dictionary) -> void:
	_screen.remove_node(view.item.path + "/@0")
	view.brick = 0
	_screen.add_node({"path": view.item.path + "/@0", "parent": view.item.path, "stage_matrix": _board.cell_matrix(view.position),
		"role": "piece", "kind": "movie_clip", "effective_visible": true, "frame": 1})
	_count_brick_exp(view)


## `countBrickExp`, once per frame after the swap: off its row on the clip's last frame.
func _count_brick_exp(view: Dictionary) -> void:
	var frames: Dictionary = _art.get("still", {}).get("brickExp", {})
	var total := frames.size() if not frames.is_empty() else 11
	view.brick += 1
	var frame := maxi(1, int(view.brick) - 1)
	if frame >= total:
		_eat_prop(view)
		return
	_screen.set_node_art(view.item.path + "/@0", frames.get(str(frame), {}), frame)


static func _translate(m: Array, by: Vector2) -> Array:
	return [m[0], m[1], m[2], m[3], m[4] + m[0] * by.x + m[2] * by.y, m[5] + m[1] * by.x + m[3] * by.y]

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
##   again.
## - Every weapon's action (checkpoint 5): each `bombDown` and its command, ported from
##   items/weapons/*Prop.as and commands/weapon/*Command.as (`_start_action`, `_advance_action`):
##   BoxingProp's `boxing<direction>_Play[_2|_3]`, LaserGunProp's `lasergun_Play` and the Laser
##   (ShootLaserCommand's laserCartoon pieces, LaserEndCommand), FlamerProp's
##   `thrower<direction>_Play` scaled by FlamerFire, ShotGunProp's `fireball<direction>_Play`,
##   LandminePlayCommand's LandmineBomb (`mine_bomb`); the projectiles `TripleShootGunBomb`
##   (`bullet_fire`) and `FireballBomb` (`ninjialBomb_fire`) follow the snapshot's `projectiles`.
##   The clips count their frames from the action's start as the commands do, on the same ticks
##   as the simulation's weapon callbacks (`weapons.gd`).
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
## `ShotGunProp.initPlayPos` (the fireball) and `BoxingProp.initPlayPos`.
const FIREBALL_PLAY_POS := {"_Left": Vector2(-10, -2), "_Right": Vector2(-5, 0), "_Up": Vector2(20, 3), "_Down": Vector2(3, 8)}
const BOXING_PLAY_POS := {"_Left": Vector2(15.4, 16.7), "_Right": Vector2(15, 17), "_Up": Vector2(24.4, 14.8), "_Down": Vector2(7, 15)}
## `BoxingProp.createWeaponPlay` by `checkAttactDistance` (0, 1, 2).
const BOXING_VARIANTS := ["_3", "_2", ""]
## `bombDown` adds the `_Play` clip at the container's bottom facing up or left.
const PLAY_BEHIND := ["_Up", "_Left"]
const DIRECTION_OF := {"_Down": Vector2i(0, 1), "_Left": Vector2i(-1, 0), "_Right": Vector2i(1, 0), "_Up": Vector2i(0, -1)}
## `GameConfig.GRID_WIDTH`.
const GRID_WIDTH := 30.0
## `lasergun_Play` (12 frames: LaserGunPlayCommand shoots at 11), LaserEndCommand's runs
## (`_continueTime > 9`), `Laser._startWid`, and ShootLaserCommand's `_chosMcArr` per direction.
const LASER_CHARGE_FRAMES := 12
const LASER_END_RUNS := 11
const LASER_START_WID := 6.0
## A Sprite scaled to nothing (`width = height = 0`): kept invertible on screen, drawn empty.
const LASER_NO_SCALE := 0.0001
const LASER_PIECES := {Vector2i(1, 0): [1, 2, 3], Vector2i(-1, 0): [10, 11, 12], Vector2i(0, 1): [6, 5, 4], Vector2i(0, -1): [9, 8, 7]}
## `fire_Play` in `thrower<Direction>_Play` (FlamerPlayCommand stops at `totalFrames - 1`).
const FLAMER_FIRE_FRAMES := 24
## The projectiles' clips (`TripleShootGunBomb` / `FireballBomb.createMC`): frame and offset of
## `_mc` per direction; both fade in (`TweenMax.from(_mc, 0.2, {alpha: 0})`).
const SHOT_CLIPS := {&"triple": "bullet_fire", &"shotgun": "ninjialBomb_fire"}
const SHOT_FRAMES := {
	&"triple": {Vector2i(-1, 0): [3, Vector2(-15, 5)], Vector2i(1, 0): [1, Vector2(25, 5)], Vector2i(0, -1): [2, Vector2(15, 0)], Vector2i(0, 1): [4, Vector2(5, 5)]},
	&"shotgun": {Vector2i(-1, 0): [3, Vector2(0, -5)], Vector2i(1, 0): [1, Vector2(20, -5)], Vector2i(0, -1): [4, Vector2(10, -10)], Vector2i(0, 1): [2, Vector2(0, 0)]}}
const SHOT_FADE_TICKS := 7.0
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
## The snapshot being stepped (for the commands that read the board: ShootLaserCommand,
## BoxingPlayCommand.checkAttactDistance, LandminePlayCommand).
var _snapshot: Dictionary = {}
## LandmineBombs made by LandminePlayCommand, until the snapshot's mine shows up.
var _pending_mines: Array = []
## The projectiles (`TripleShootGunBomb`, `FireballBomb`) by owner and birth tick.
var _shots: Dictionary = {}
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
			"action": {}, "last_started": -1,
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
	_snapshot = snapshot
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
		# A weapon's action stops the robot's move listener until `robotMoveStart`.
		var busy: bool = not view.action.is_empty() and not view.action.ended
		# A key press reaches the robot between frames (robot_turnHandler).
		# (in a portal the robot's key listener is off: `stopMoveListener`)
		if human and not view.transit and not busy and direction != Vector2i.ZERO and direction != view.direction: _turn(view, direction)
		# The frame's timeline advance. A ride clip's loop frame script (`_r0_Car_Down.frame11`:
		# `gotoAndPlay(1)`) runs after the frame's engine, so it plays the clip again even when
		# moveStop stopped it this frame: after a release on the loop's last frame the clip
		# shows one frame more (recorded, gameplay-cinema-ride: 10, then 1 and 2, stopped).
		var replay := false
		# (only while the same clip stays: a new clip from setRobotMc is not that one)
		var replay_class: String = view.class
		if view.playing and view.fresh == 0:
			replay = _jumps(view.class, view.frame)
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
		if not human and not busy and direction != Vector2i.ZERO and direction != view.direction: _turn(view, direction)
		_vehicle(view, actor)
		_weapon(view, actor, attacks.get(id, {}))
		_shield(view, actor)
		_invincibility_prop(view, actor)
		_send_robot(view, actor)
		if direction == Vector2i.ZERO:
			view.playing = false
			view.weapon_playing = false
			view.shield_playing = false
		if replay and view.class == replay_class and view.fresh == 0: view.playing = true
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
	_update_shots(snapshot)
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


## Whether the clip's frame after `frame` comes from a frame script (`gotoAndPlay`), not the
## playhead's own step (the art pass's `next`: how the clip plays).
func _jumps(cls: String, frame: int) -> bool:
	var nxt: Dictionary = _art.get("robots", {}).get(cls, {}).get("next", {})
	return nxt.has(str(frame)) and int(nxt[str(frame)]) != frame % _total(cls) + 1


func _total(cls: String) -> int:
	return int(_art.get("robots", {}).get(cls, {}).get("frames", 24))


## `AbstractRobot.kill`: the `_Dead` clip, stopped; RobotDeadCommand advances it. The robot's
## weapon goes with it (`clearWeapon`).
func _kill(view: Dictionary) -> void:
	view.dead = true
	view.offset = false
	_clear_weapon(view)
	view.action = {}
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
	view.action = {}
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
## clip); the snapshot's attack starts the weapon's `bombDown` (`_start_action`), whose command
## then runs once per engine tick (`_advance_action`) until its own end; the snapshot's attack
## ending (the simulation's recovery) ends it too. The last use's `initWeapon` takes the weapon off.
func _weapon(view: Dictionary, actor: Dictionary, attack: Dictionary) -> void:
	var kind := StringName(actor.get("weapon", &""))
	if not WEAPON_NAMES.has(kind): kind = &""
	var ammo := int(actor.get("ammo", 0))
	# An action whose command ends on its first run (LandminePlayCommand) is gone from the
	# snapshot's attacks on the tick it starts; the actor's `action_started_tick` still shows it.
	if attack.is_empty() and int(actor.get("action_started_tick", -1)) == _tick_now() and view.weapon != &"":
		attack = {"kind": view.weapon, "started": _tick_now()}
	var acting: bool = not attack.is_empty()
	var action: Dictionary = view.action
	if not action.is_empty() and (not acting or int(attack.started) != int(action.started)):
		if not action.ended: _end_action(view, ammo)
		view.action = {}
		if kind != view.weapon or ammo <= 0: _clear_weapon(view)
	elif not action.is_empty() and not action.ended:
		_advance_action(view, attack, ammo)
	if kind != view.weapon and not acting:
		_clear_weapon(view)
		if kind != &"":
			# `AbstractWeapon.changeStage`: `setWeaponTimesMc` (showTimes on top), `setWeaponMc`.
			view.weapon = kind
			view.ammo = ammo
			_add_child(view, {"kind": "times"}, -1)
			_update_weapon_display(view)
	if acting and view.action.is_empty() and view.weapon != &"" and attack.get("kind", &"") == view.weapon \
			and int(attack.started) != view.last_started:
		view.ammo = ammo
		_start_action(view, attack)
	if view.weapon != &"" and ammo != view.ammo and not acting:
		view.ammo = ammo


## `bombDown` of the robot's weapon, on the tick the action starts (the key was pressed between
## frames; the command it adds first runs on this engine tick).
func _start_action(view: Dictionary, attack: Dictionary) -> void:
	var weapon: StringName = view.weapon
	var suffix: String = view.suffix
	var name: String = WEAPON_NAMES[weapon]
	view.action = {"kind": weapon, "started": int(attack.started), "ended": false, "suffix": suffix}
	view.last_started = int(attack.started)
	# `robotMoveStop`: the robot's clip stops; HammerProp, BoxingProp and LandmineProp pass
	# `true` (`RobotView.robotMoveStop`: the held clip goes), the others leave the held clip
	# at its frame 1.
	view.playing = false
	view.weapon_playing = false
	if weapon in [&"hammer", &"boxing", &"landmine"]:
		_remove_child(view, "weapon")
		view.weapon_class = ""
	else:
		view.weapon_frame = 1
	match weapon:
		&"hammer", &"shotgun":
			# AbstractWeapon.bombDown: `<name><Direction>_Play` at `_playPos`, under the robot
			# facing up or left (HammerProp, ShotGunProp).
			var pos: Dictionary = HAMMER_PLAY_POS if weapon == &"hammer" else FIREBALL_PLAY_POS
			_add_child(view, {"kind": "play", "cls": "%s%s_Play" % [name, suffix], "pos": pos.get(suffix, Vector2.ZERO)},
				0 if suffix in PLAY_BEHIND else -1)
		&"boxing":
			# BoxingProp.bombDown: `createWeaponPlay` picks `_Play`, `_Play_2` or `_Play_3` by
			# `checkAttactDistance`; under the robot facing left only.
			var variant: String = BOXING_VARIANTS[_check_attact_distance(view, _snapshot)]
			_add_child(view, {"kind": "play", "cls": "boxing%s_Play%s" % [suffix, variant], "pos": BOXING_PLAY_POS.get(suffix, Vector2.ZERO)},
				0 if suffix == "_Left" else -1)
		&"laser", &"flamer":
			# LaserGunProp.bombDown (`lasergun_Play`) / FlamerProp.bombDown (`thrower<Direction>_Play`)
			# at the held clip's `gunpoint`; under the robot facing up only.
			var cls := "lasergun_Play" if weapon == &"laser" else "%s%s_Play" % [name, suffix]
			_add_child(view, {"kind": "play", "cls": cls, "pos": _gun_point(view)}, 0 if suffix == "_Up" else -1)
		&"triple", &"landmine":
			# TripleShootGunProp / LandmineProp: `createWeaponPlay` is an empty MovieClip, which
			# NinjialPlayCommand / LandminePlayCommand take off on their first run, this tick.
			pass
	_advance_action(view, attack, int(view.ammo))


## The weapon's command on this engine tick (`age` ticks after `bombDown`): HammerPlayCommand,
## BoxingPlayCommand, LaserGunPlayCommand with the Laser's ShootLaserCommand and LaserEndCommand,
## FlamerPlayCommand, ShotGunPlayCommand, LandminePlayCommand (NinjialPlayCommand only shoots:
## its projectiles are the snapshot's, its end the simulation's recovery). Each clip shows frame
## age + 1 (made between frames, it advances from the next frame on).
func _advance_action(view: Dictionary, attack: Dictionary, ammo: int) -> void:
	var action: Dictionary = view.action
	var age: int = _tick_now() - int(action.started)
	match action.kind:
		&"hammer":
			# `currentFrame >= totalFrames - 1` (24 of 25).
			if age + 1 >= _weapon_total("play", _child(view, "play").get("cls", "")) - 1: _end_action(view, ammo)
		&"boxing":
			var play: Dictionary = _child(view, "play")
			var total := _weapon_total("play", play.get("cls", ""))
			# `currentFrame == floor(totalFrames / 2)`: facing up, the clip goes under the robot.
			if age + 1 == total / 2 and action.suffix == "_Up":
				view.children.erase(play)
				view.children.insert(0, play)
				_arrange(view)
			if age + 1 >= total - 1: _end_action(view, ammo)
		&"flamer":
			# FlamerFire.shootFire scales the clip to a fixed box (the simulation's `scale`);
			# FlamerPlayCommand ends when `fire_Play` reaches `totalFrames - 1` (23 of 24).
			var play: Dictionary = _child(view, "play")
			if attack.has("scale"):
				var s := float(attack.scale)
				play.scale = Vector2(s, 1.0) if action.suffix in ["_Left", "_Right"] else Vector2(1.0, s)
			if age + 1 >= FLAMER_FIRE_FRAMES - 1: _end_action(view, ammo)
		&"laser":
			# LaserGunPlayCommand: at frame `totalFrames - 1` (11) the clip stops and the Laser
			# is made; ShootLaserCommand draws it this tick; LaserEndCommand's eleventh run
			# (`_continueTime > 9`) takes it off and gives the robot back.
			# (frame totalFrames - 1 shows `totalFrames - 2` ticks after bombDown)
			var shot: int = LASER_CHARGE_FRAMES - 2
			if age == shot: _shoot_laser(view, attack)
			elif age >= shot + LASER_END_RUNS: _end_action(view, ammo)
		&"shotgun":
			# ShotGunPlayCommand: at `currentFrame == totalFrames` (14) the clip goes and the
			# FireballBomb is made (the snapshot's projectile); the robot waits for the recovery.
			var play: Dictionary = _child(view, "play")
			if not play.is_empty() and age + 1 >= _weapon_total("play", play.cls):
				_remove_child(view, "play")
		&"landmine":
			# LandminePlayCommand: the LandmineBomb on the robot's cell (`mine_bomb`, made here;
			# the snapshot's mine takes it over), `robotMoveStart`, the last use's `initWeapon`.
			var cell: Vector2i = _snapshot.get("actors", {}).get(view.id, {}).get("cell", Vector2i.ZERO)
			_pending_mines.append({"actor_id": view.id, "cell": cell, "made": _tick_now()})
			_end_action(view, ammo)


## The action's end: its clips go and `robotMoveStart` makes the robot's clip again
## (`setRobotMc`, the held clip with it); the last use's `initWeapon` takes the weapon off.
func _end_action(view: Dictionary, ammo: int) -> void:
	view.action.ended = true
	_remove_child(view, "play")
	_remove_child(view, "laser")
	if ammo <= 0: _clear_weapon(view)
	_set_robot_mc(view, view.suffix)


## `AbstractWeapon.updateWeaponDisplay`'s place for the held clip (the new robot clip's `hand`
## at its first frame) plus its `gunpoint` (LaserGunProp `_laserPos`, FlamerProp `countFirePos`).
func _gun_point(view: Dictionary) -> Vector2:
	var gun: Array = _art.get("weapons", {}).get("held", {}).get(view.weapon_class, {}).get("gunpoint", [0, 0])
	return _hand(view) + Vector2(float(gun[0]), float(gun[1]))


## The robot clip's `hand` in the robot's container, where the art pass found it at frame 1.
func _hand(view: Dictionary) -> Vector2:
	var clip: Dictionary = _art.get("robots", {}).get(view.class, {})
	var first: Dictionary = clip.get("looks", {}).values()[0].get("1", {}) if not clip.get("looks", {}).is_empty() else {}
	var clip_at := _m(first.get("at", _art.get("at", [1, 0, 0, 1, 0, 0])))
	return (clip_at.affine_inverse() * _m(clip.get("hand", _a(clip_at)))).origin


## Whether this tick's laser pass broke a soft block or set off a bomb on `cell`.
func _struck(attack: Dictionary, cell: Vector2i) -> bool:
	if cell not in attack.get("cells", []): return false
	if cell in _snapshot.get("broken_soft_blocks", []): return true
	return _snapshot.get("blasts", []).any(func(b): return b.get("cell") == cell)


## BoxingPlayCommand.checkAttactDistance: the first of the two cells ahead holding a fixed box,
## a box that is there or a bomb; past the two it reads cell (0, 0) (`_loc2_[4]` is undefined),
## the board's corner wall, so it returns 2 when neither holds one.
func _check_attact_distance(view: Dictionary, snapshot: Dictionary) -> int:
	var actor: Dictionary = snapshot.get("actors", {}).get(view.id, {})
	var cell: Vector2i = actor.get("cell", Vector2i.ZERO)
	var ahead: Vector2i = DIRECTION_OF[view.suffix]
	for k in 2:
		var at: Vector2i = cell + ahead * (k + 1)
		if _is_box(snapshot, at) or _has_bomb(snapshot, at): return k
	return 2


## `Grid.box`: a fixed or breakable box on the cell.
static func _is_box(snapshot: Dictionary, cell: Vector2i) -> bool:
	return snapshot.get("board", {}).get(cell, &"solid") in [&"solid", &"soft"]


static func _has_bomb(snapshot: Dictionary, cell: Vector2i) -> bool:
	return snapshot.get("bombs", []).any(func(b): return b.cell == cell and not b.has("position"))


## ShootLaserCommand.execute: from the robot's cell along the direction, every cell that does
## not block (no box or bomb) or holds robots gets a middle piece (`_chosMcArr[1]`) in one
## Sprite, the first other one the end piece (`_chosMcArr[2]`); the start piece
## (`_chosMcArr[0]`) is at the gun. The middle pieces follow the start piece's width, 29 apart;
## the end piece and the Sprite's scale come from the last middle cell's far edge. The walk
## draws and hits cell by cell, so a cell the simulation's laser pass of this same tick struck
## (the attack's `cells`: a soft block it broke, a bomb it set off) still blocks the walk.
func _shoot_laser(view: Dictionary, attack: Dictionary) -> void:
	var direct: Vector2i = DIRECTION_OF[view.action.suffix]
	var chos: Array = LASER_PIECES[direct]
	var actor: Dictionary = _snapshot.get("actors", {}).get(view.id, {})
	var grid: Vector2i = actor.get("cell", Vector2i.ZERO)
	var laser_pos := _gun_point(view)
	var robot_pos: Vector2 = Vector2(actor.get("position", view.position)) * GRID_WIDTH
	var x_pos := laser_pos.x + robot_pos.x
	var y_pos := laser_pos.y + robot_pos.y
	var size: Vector2i = _snapshot.get("board_meta", {}).get("size", Vector2i(17, 15))
	var start := _laser_size(chos[0])
	var mids: Array = []
	var end_at = null
	var loc5 := 0.0
	var loc6 := 0.0
	for k in size.x:
		var cell: Vector2i = grid + direct * k
		if not (cell.y > -1 and cell.y < size.y and cell.x > -1 and cell.x < size.x): break
		var blocked: bool = _is_box(_snapshot, cell) or _has_bomb(_snapshot, cell) or _struck(attack, cell)
		var robots: bool = _snapshot.get("actors", {}).values().any(func(a): return a.get("alive", false) and a.get("cell") == cell)
		if not blocked or robots:
			if mids.is_empty(): mids.append(Vector2(direct.x * start.x, direct.y * start.y))
			else: mids.append(mids.back() + Vector2(direct) * 29)
			if direct.y > 0: loc5 = (grid.y + direct.y * k) * GRID_WIDTH + GRID_WIDTH - y_pos - direct.y * LASER_START_WID
			elif direct.y < 0: loc5 = absf((grid.y + direct.y * k) * GRID_WIDTH - y_pos) + direct.y * LASER_START_WID
			elif direct.x > 0: loc6 = (grid.x + direct.x * k) * GRID_WIDTH + GRID_WIDTH - x_pos - direct.x * LASER_START_WID
			else: loc6 = absf((grid.x + direct.x * k) * GRID_WIDTH - x_pos) + direct.x * LASER_START_WID
		else:
			# (a blocking cell is never empty)
			end_at = Vector2(direct) * LASER_START_WID
			break
	var scale := Vector2.ONE
	if end_at != null and mids.size() >= 2:
		end_at = Vector2(direct.x * loc6 + direct.x * LASER_START_WID, direct.y * loc5 + direct.y * LASER_START_WID)
		var box := _laser_union(chos[1], mids)
		if loc6 != 0: scale.x = absf(end_at.x - direct.x * LASER_START_WID) / box.size.x
		if loc5 != 0: scale.y = absf(end_at.y - direct.y * LASER_START_WID) / box.size.y
	elif end_at != null:
		# `_loc7_.width = _loc7_.height = 0`
		scale = Vector2.ONE * LASER_NO_SCALE
	var pieces: Array = [{"root": chos[0], "at": Transform2D()}]
	if not mids.is_empty():
		pieces.append({"group": true, "at": Transform2D(0.0, scale, 0.0, Vector2.ZERO), "mids": mids, "root": chos[1]})
	if end_at != null: pieces.append({"root": chos[2], "at": Transform2D(0.0, end_at)})
	# Laser.init: the Laser's container at `_laserPos`, under the robot facing up only.
	_add_child(view, {"kind": "laser", "pos": laser_pos, "pieces": pieces, "shot": _tick_now(), "built": false},
		0 if view.action.suffix == "_Up" else -1)


## A laserCartoon frame's `width` and `height` (the art pass's bounds of that frame).
func _laser_size(root: int) -> Vector2:
	var b: Array = _art.get("weapons", {}).get("bounds", {}).get("laserCartoon", {}).get(str(root), [0, 0, 0, 0])
	return Vector2(float(b[2]) - float(b[0]), float(b[3]) - float(b[1]))


## The bounds of the middle pieces in their Sprite (its `width` and `height` at scale 1).
func _laser_union(root: int, mids: Array) -> Rect2:
	var b: Array = _art.get("weapons", {}).get("bounds", {}).get("laserCartoon", {}).get(str(root), [0, 0, 0, 0])
	var offset := Vector2(float(b[0]), float(b[1]))
	var size := Vector2(float(b[2]) - float(b[0]), float(b[3]) - float(b[1]))
	var box := Rect2(mids[0] + offset, size)
	for at: Vector2 in mids:
		box = box.merge(Rect2(at + offset, size))
	return box


## The Laser's pieces as nodes under its container (made once, after the container's node).
func _build_laser(view: Dictionary, child: Dictionary) -> void:
	var base := _path(view, child)
	var n: int = child.pieces.size()
	for k in n:
		var piece: Dictionary = child.pieces[k]
		piece.rel = "@0" if n == 1 else "@0#%d" % k
		var path := "%s/%s" % [base, piece.rel]
		_screen.add_node({"path": path, "parent": base, "stage_matrix": _art.get("at"), "role": "group" if piece.get("group", false) else "piece",
			"kind": "movie_clip", "effective_visible": true, "frame": 0 if piece.get("group", false) else piece.root})
		if piece.get("group", false):
			var m: int = piece.mids.size()
			for j in m:
				_screen.add_node({"path": "%s/%s" % [path, "@0" if m == 1 else "@0#%d" % j], "parent": path, "stage_matrix": _art.get("at"),
					"role": "piece", "kind": "movie_clip", "effective_visible": true, "frame": piece.root})
	child.built = true


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
	for kind in ["weapon", "play", "laser", "times"]: _remove_child(view, kind)
	view.weapon = &""
	view.weapon_class = ""


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


## The length of the loop `key` plays in such a table (the most frames the art pass saw it at).
static func _nested_total(table: Dictionary, key: String) -> int:
	var total := 1
	for art: Dictionary in table.values(): total = maxi(total, int(art.get("frames", {}).get(key, 1)))
	return total


## An image of a clip that plays on its own (`weapons.played`: by age since it was made, or
## `weapons.aged`: stopped at `root`, by age), the first whose clip `key` shows `frame`.
func _aged_art(table: Dictionary, key: String, frame: int) -> Dictionary:
	for age in table:
		var art: Dictionary = table[age]
		if int(art.get("frames", {}).get(key, 1)) == frame: return art
	return table.get("0", {})


## The action clip's image this tick (`age` ticks after bombDown: frame age + 1).
func _play_art(view: Dictionary, child: Dictionary, age: int) -> Array:
	var cls: String = child.cls
	var weapons: Dictionary = _art.get("weapons", {})
	match view.action.get("kind", &""):
		&"laser":
			# Stopped at 11; its nested 2-frame clip flickers on from bombDown (recorded,
			# gameplay-cinema-laser: frame 2 eleven ticks in, 1 sixteen ticks in).
			var frame := mini(age + 1, LASER_CHARGE_FRAMES - 1)
			return [_aged_art(weapons.get("aged", {}).get(cls, {}).get(str(frame), {}), "/@3", age % 2 + 1), frame]
		&"flamer":
			# Its one frame holds `fire_Play`, which plays: frame age + 1.
			return [_aged_art(weapons.get("played", {}).get(cls, {}), "/fire_Play", mini(age + 1, FLAMER_FIRE_FRAMES)), 1]
	var frame: int = clampi(age + 1, 1, maxi(1, _weapon_total("play", cls)))
	return [weapons.get("play", {}).get(cls, {}).get("images", {}).get(str(frame), {}), frame]


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
			# (the item Sprite holds a clip of its own, the Laser's container its pieces; a
			# Sprite reports frame 0)
			var group: bool = child.kind in ["item", "laser"]
			_screen.add_node({"path": path, "parent": base, "stage_matrix": matrix, "role": "group" if group else "piece",
				"kind": "movie_clip", "effective_visible": true, "frame": 0 if group else 1})
			if child.kind == "laser":
				_build_laser(view, child)
			elif child.kind == "mc":
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
				_screen.move_node(path, _a(at * Transform2D(0.0, _hand(view))))
				var images: Dictionary = _art.get("weapons", {}).get("held", {}).get(view.weapon_class, {}).get("images", {})
				_screen.set_node_art(path, images.get(str(view.weapon_frame), {}), view.weapon_frame)
				# CountInvincibilityCommand: `weaponMc.filters` as the clip's.
				_screen.set_node_filter(path, view.filter)
			"play":
				var age: int = _tick_now() - int(view.action.get("started", _tick_now()))
				var scale: Vector2 = child.get("scale", Vector2.ONE)
				_screen.move_node(path, _a(at * Transform2D(0.0, scale, 0.0, child.pos)))
				var shown: Array = _play_art(view, child, age)
				_screen.set_node_art(path, shown[0], shown[1])
			"laser":
				_show_laser(view, child, path, at, offset)
			"times":
				var times := at * Transform2D(0.0, TIMES_AT)
				_screen.move_node(path, _a(times))
				_screen.set_node_art(path, _art.get("weapons", {}).get("times", {}).get(String(view.weapon), {}), 1)
				var digit: Dictionary = _art.get("weapons", {}).get("digits", {}).get(str(view.ammo), {})
				if not digit.is_empty():
					_screen.move_node(path + "/~count", _a(times * _m(digit.times_at).affine_inverse() * _m(digit.at)))
				_screen.set_node_art(path + "/~count", digit)
				_screen.set_node_offset(path + "/~count", offset)


## The Laser's container at `_laserPos` in the robot's container and its pieces (see
## `_shoot_laser`). Each laserCartoon stands at its frame while its nested 10-frame clip plays:
## made during the engine tick, it shows its first nested frame on the next frame too
## (recorded, gameplay-cinema-laser: 1 one tick after the shot, 6 six ticks after).
func _show_laser(view: Dictionary, child: Dictionary, path: String, at: Transform2D, offset: Color) -> void:
	var container := at * Transform2D(0.0, child.pos)
	_screen.move_node(path, _a(container))
	var aged: Dictionary = _art.get("weapons", {}).get("aged", {}).get("laserCartoon", {})
	var nested: int = (maxi(1, _tick_now() - int(child.shot)) - 1) % _nested_total(aged.get("2", {}), "/@1") + 1
	for piece: Dictionary in child.pieces:
		var piece_path := "%s/%s" % [path, piece.rel]
		var piece_at: Transform2D = container * piece.at
		_screen.move_node(piece_path, _a(piece_at))
		var art := _aged_art(aged.get(str(piece.root), {}), "/@1", nested)
		if not piece.get("group", false):
			_screen.set_node_art(piece_path, art, piece.root)
			_screen.set_node_offset(piece_path, offset)
			continue
		var m: int = piece.mids.size()
		for j in m:
			var mid_path := "%s/%s" % [piece_path, "@0" if m == 1 else "@0#%d" % j]
			_screen.move_node(mid_path, _a(piece_at * Transform2D(0.0, piece.mids[j])))
			# (a Sprite scaled to nothing draws nothing)
			_screen.set_node_art(mid_path, art if piece.at.get_scale().x > LASER_NO_SCALE else {}, piece.root)
			_screen.set_node_offset(mid_path, offset)


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
	var mines := {}
	for k in bombs.size():
		# The simulation's display fields for this bomb (serial, flying), when it gives them.
		var bomb: Dictionary = bombs[k].merged(shown[k]) if k < shown.size() else bombs[k]
		live[_bomb_key(bomb)] = bomb
		if bomb.get("kind", &"bomb") == &"mine": mines[_key(bomb.actor_id, bomb.cell)] = _bomb_key(bomb)
	# A LandmineBomb LandminePlayCommand made this tick or the last, before the simulation's
	# mine registers (both on the command's first run); the simulation's mine takes its view over.
	for mine in _pending_mines.duplicate():
		var key := _key(mine.actor_id, mine.cell)
		if mines.has(key):
			for view in _bombs:
				if view.key == key: view.key = mines[key]
			_pending_mines.erase(mine)
		elif _tick_now() - int(mine.made) > 1:
			_pending_mines.erase(mine)
		else:
			live[key] = {"actor_id": mine.actor_id, "cell": mine.cell, "power": 2, "kind": &"mine", "made": mine.made}
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
			"position": bomb.get("position", Vector2(bomb.cell)), "arms": [], "mine": bomb.get("kind", &"bomb") == &"mine"}
		if view.mine: view.age = _tick_now() - int(bomb.get("made", _tick_now()))
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
	if not view.blasted and view.get("mine", false):
		# LandmineBomb's `mine_bomb` (Bomb.createMC), playing and looping; made during the engine
		# tick, it shows its first frame twice (recorded, gameplay-cinema-landmine: frame 3 at age 30).
		var played: Dictionary = _art.get("weapons", {}).get("played", {}).get("mine_bomb", {})
		var frame: int = (maxi(1, int(view.age)) - 1) % _nested_total(played, "/") + 1
		_screen.set_node_art(view.item.path + "/@0", _aged_art(played, "/", frame), frame)
		return
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


# ------------------------------------------------------------------ projectiles

## The triple gun's and the fireball gun's projectiles (`TripleShootGunBomb`, `FireballBomb`,
## both `Bomb`s): the snapshot's `projectiles`, by owner and birth tick. `Bomb.init` puts a
## Sprite on its row's bomb layer (2) at its cell, `createMC` the clip at the direction's frame
## and offset, fading in; each move (`shootFunc`) first runs `resetDisplay` (off its row and
## on again, on the row it stands on); `blast` takes the clip off, `ended` the Sprite after
## its eleventh run (the snapshot drops the projectile then).
func _update_shots(snapshot: Dictionary) -> void:
	var seen := {}
	for projectile: Dictionary in snapshot.get("projectiles", []):
		var key := "%s|%s" % [projectile.actor_id, projectile.born]
		seen[key] = true
		var view: Dictionary = _shots.get(key, {})
		var position: Vector2 = projectile.position
		if view.is_empty():
			var kind: StringName = projectile.kind
			var dir: Vector2i = projectile.direction
			view = {"kind": kind, "dir": dir, "item": {}, "row": floori(position.y + 0.5), "born": _tick_now(), "clip": true,
				"position": position}
			view.layer = _board.layer_of(view.row, 2)
			_board.attach(view.layer, view.item, _board.cell_matrix(position))
			var frame: int = SHOT_FRAMES[kind][dir][0]
			_screen.add_node({"path": view.item.path + "/@0", "parent": view.item.path, "stage_matrix": _board.cell_matrix(position),
				"role": "piece", "kind": "movie_clip", "effective_visible": true, "frame": frame})
			_shots[key] = view
		elif projectile.phase != &"cleanup" and (position != view.position or view.clip):
			if position != view.position:
				# `shootFunc` -> `resetDisplay`, on the row it stood on before this move.
				_board.detach(view.layer, view.item)
				view.layer = _board.layer_of(floori(view.position.y + 0.5), 2)
				_board.attach(view.layer, view.item, _board.cell_matrix(view.position))
				_add_shot_clip(view)
		if projectile.phase == &"cleanup" and view.clip:
			# `blast`: the clip goes; the Sprite stays until `ended`.
			_screen.remove_node(view.item.path + "/@0")
			view.clip = false
		view.position = position
		_show_shot(view)
	for key in _shots.keys():
		if seen.has(key): continue
		_board.detach(_shots[key].layer, _shots[key].item)
		_shots.erase(key)


## The projectile's clip again under its Sprite (the Sprite was taken off its row and put back).
func _add_shot_clip(view: Dictionary) -> void:
	if not view.clip or _screen.by_path.has(view.item.path + "/@0"): return
	_screen.add_node({"path": view.item.path + "/@0", "parent": view.item.path, "stage_matrix": _board.cell_matrix(view.position),
		"role": "piece", "kind": "movie_clip", "effective_visible": true, "frame": SHOT_FRAMES[view.kind][view.dir][0]})


func _show_shot(view: Dictionary) -> void:
	var matrix: Array = _board.cell_matrix(view.position)
	_screen.move_node(view.item.path, matrix)
	if not view.clip: return
	var how: Array = SHOT_FRAMES[view.kind][view.dir]
	var clip_path: String = view.item.path + "/@0"
	_screen.move_node(clip_path, _a(_m(matrix) * Transform2D(0.0, how[1])))
	var age: int = _tick_now() - int(view.born)
	var aged: Dictionary = _art.get("weapons", {}).get("aged", {}).get(SHOT_CLIPS[view.kind], {}).get(str(how[0]), {})
	# The fireball's nested 35-frame clip plays from the frame after (made during the tick).
	var nested := (maxi(1, age) - 1) % _nested_total(aged, "/@1") + 1
	_screen.set_node_art(clip_path, _aged_art(aged, "/@1", nested) if view.kind == &"shotgun" else aged.get("0", {}), how[0])
	# `TweenMax.from(_mc, 0.2, {alpha: 0})`: TweenLite's default ease (Quad.easeOut) over 0.2 s.
	var t := clampf(age / SHOT_FADE_TICKS, 0.0, 1.0)
	_screen.set_node_alpha(clip_path, 1.0 - (1.0 - t) * (1.0 - t))


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

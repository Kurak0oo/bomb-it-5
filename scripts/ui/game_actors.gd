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
##   set on its innermost `bodyMc`/`hatMc`); it starts on row 0's layer 3 (the constructor,
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
## Frame timing recorded in the reference player (gameplay-cinema-bomb): a clip made between
## frames (a key press turning the robot, a bomb dropped by key) shows its first frame on the
## next frame and advances from the one after; `play()` on a key press advances the clip on
## the next frame; a key release stops it on the next engine tick, after that frame's advance.
## Nested clips: bomb0's spark loops (14 frames) with its root (27); exp0's nested blast
## shows frames 1, 1, 2, … at the centre and 1, 2, 3, … on an arm.

const DIRECTIONS := {Vector2i(0, 1): "_Down", Vector2i(-1, 0): "_Left", Vector2i(1, 0): "_Right", Vector2i(0, -1): "_Up"}
## `Bomb.blast`'s exp0 frames per ray (middle, end).
const ARM_FRAMES := {Vector2i(0, -1): [2, 3], Vector2i(0, 1): [8, 9], Vector2i(-1, 0): [6, 7], Vector2i(1, 0): [4, 5]}
const INVINCIBILITY_FRAMES := 80
const BLAST_TICKS := 16

var _screen: Node2D
var _board: RefCounted
var _art: Dictionary
## Seat looks of a recorded round ([clothID, hatID] per seat), else from the snapshot.
var _looks: Array
var _robots: Dictionary = {}
var _bombs: Array = []
var _tick := -1
var _bomb_art: Dictionary = {}
var _exp_art: Dictionary = {}


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
		_step(snapshot, step == tick - _tick - 1)
	_tick = tick


func _create_robots(snapshot: Dictionary) -> void:
	var seat := 0
	for id in snapshot.get("actors", {}):
		var actor: Dictionary = snapshot.actors[id]
		var look: Array = _looks[seat] if seat < _looks.size() else [int(actor.get("body", 0)), int(actor.get("hat", 0))]
		var view := {"id": id, "robot": int(actor.get("robot", seat)), "cloth": maxi(0, int(look[0])), "hat": maxi(0, int(look[1])),
			"robot_row": 4 if id == &"human" else 3, "row": 0, "layer": "", "item": {}, "class": "", "frame": 1,
			"playing": false, "fresh": false, "direction": Vector2i.ZERO, "blink": 0, "bright": false, "blinking": true,
			"dead": false, "removed": false, "position": actor.get("position", Vector2.ZERO), "blink_until": int(actor.get("blink_until", 0))}
		_robots[id] = view
		# RobotView(): `_mainContainer = getDisArr(yN).getChildAt(3)` while yPos is still 0.
		_place(view, 0, 3)
		_set_robot_mc(view, "_Down")
		_show(view)
		seat += 1


func _step(snapshot: Dictionary, last: bool) -> void:
	var commands := {}
	for command in snapshot.get("commands", []):
		commands[command.actor_id] = command.direction
	for id in _robots:
		var view: Dictionary = _robots[id]
		if view.removed: continue
		var actor: Dictionary = snapshot.actors.get(id, {})
		var direction := _direction(commands.get(id, Vector2.ZERO))
		var human: bool = id == &"human"
		if not actor.get("alive", true) and not view.dead:
			_kill(view)
		if view.dead:
			_count_dead(view)
			continue
		# A key press reaches the robot between frames (robot_turnHandler).
		if human and direction != Vector2i.ZERO and direction != view.direction: _turn(view, direction)
		# The frame's timeline advance.
		if view.playing and not view.fresh:
			view.frame = view.frame % _total(view.class) + 1
		view.fresh = false
		# The engine tick: resetMainContainer (from where it stood), the AI's turns, moveStop.
		_reset_main_container(view)
		if not human and direction != Vector2i.ZERO and direction != view.direction: _turn(view, direction)
		if direction == Vector2i.ZERO: view.playing = false
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


static func _direction(v: Vector2) -> Vector2i:
	if v == Vector2.ZERO: return Vector2i.ZERO
	return Vector2i(int(signf(v.x)), 0) if absf(v.x) >= absf(v.y) else Vector2i(0, int(signf(v.y)))


## `RobotView.robotTurn` (a new clip, playing) or, facing that way already,
## `robot_turnHandler`'s `mc.play()`.
func _turn(view: Dictionary, direction: Vector2i) -> void:
	var suffix: String = DIRECTIONS[direction]
	if view.class != "_r%d%s" % [view.robot, suffix]:
		_set_robot_mc(view, suffix)
		view.fresh = true
	view.playing = true


## `RobotView.setRobotMc`: the clip of this robot and direction, with its look. The look is
## set by sending the innermost `bodyMc` to clothID + 1 and `hatMc` to hatID + 1; a clip
## without them takes those frames itself (the `_Dead` clips, `_r0_Down` with no hat).
func _set_robot_mc(view: Dictionary, suffix: String) -> void:
	view.class = "_r%d%s" % [view.robot, suffix]
	var clip: Dictionary = _art.get("robots", {}).get(view.class, {})
	view.frame = 1
	if not clip.is_empty():
		if not clip.hat: view.frame = view.hat + 1
		elif not clip.body: view.frame = view.cloth + 1
		view.frame = clampi(view.frame, 1, int(clip.frames))
	view.playing = false


func _total(cls: String) -> int:
	return int(_art.get("robots", {}).get(cls, {}).get("frames", 24))


## `AbstractRobot.kill`: the `_Dead` clip, stopped; RobotDeadCommand advances it.
func _kill(view: Dictionary) -> void:
	view.dead = true
	view.offset = false
	_set_robot_mc(view, "_Dead")


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


## `resetMainContainer`: on its row's `robotRow` layer, judged from where it stood.
func _reset_main_container(view: Dictionary) -> void:
	var row := floori((view.position as Vector2).y + 0.5)
	if row != view.row or view.layer == "":
		_place(view, row, view.robot_row)


func _place(view: Dictionary, row: int, layer_index: int) -> void:
	if view.layer != "": _board.detach(view.layer, view.item)
	view.row = row
	view.layer = _board.layer_of(row, layer_index)
	view.item = {}
	_board.attach(view.layer, view.item, _board.cell_matrix(view.position))
	_screen.add_node({"path": view.item.path + "/@0", "parent": view.item.path, "stage_matrix": _board.cell_matrix(view.position),
		"role": "piece", "kind": "movie_clip", "effective_visible": true, "frame": view.frame})
	view.erase("shown_key")


func _show(view: Dictionary) -> void:
	if view.removed: return
	var matrix: Array = _board.cell_matrix(view.position)
	_screen.move_node(view.item.path, matrix)
	_screen.move_node(view.item.path + "/@0", matrix)
	_screen.set_node_art(view.item.path + "/@0", _robot_art(view), view.frame)
	var on: bool = view.bright and not view.dead
	_screen.set_node_offset(view.item.path + "/@0", Color(50.0 / 255, 50.0 / 255, 50.0 / 255, 1) if on else Color(0, 0, 0, 0))


func _robot_art(view: Dictionary) -> Dictionary:
	var clip: Dictionary = _art.get("robots", {}).get(view.class, {})
	if clip.is_empty(): return {}
	var key := "%d|%d" % [view.cloth if clip.body else -1, view.hat if clip.hat else -1]
	var looks: Dictionary = clip.looks
	# A look the pack has no art for (record_screen.py actors --looks all renders every one)
	# shows the robot's default look.
	var frames: Dictionary = looks.get(key, looks.get("%d|%d" % [0 if clip.body else -1, 0 if clip.hat else -1], {}))
	return frames.get(str(view.frame), {})


# ------------------------------------------------------------------ bombs

## `Bomb`: placed bombs, their blasts (the snapshot's flames) and `ended`.
func _update_bombs(snapshot: Dictionary) -> void:
	var live := {}
	for bomb in snapshot.get("bombs", []):
		live[_key(bomb.actor_id, bomb.cell)] = bomb
	var flames := {}
	for flame in snapshot.get("flames", []):
		var bomb: Dictionary = flame.get("bomb", {})
		if not bomb.is_empty(): flames[_key(bomb.actor_id, bomb.cell)] = flame
	for view in _bombs.duplicate():
		view.age += 1
		if view.blasted:
			# `ended`: `_continueTime > 15`.
			if view.age >= BLAST_TICKS:
				_board.detach(view.layer, view.item)
				_bombs.erase(view)
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
			if bomb.has("position"): view.position = bomb.position
		_show_bomb(view)
	for key in live:
		if _bombs.any(func(v): return v.key == key): continue
		var bomb: Dictionary = live[key]
		var view := {"key": key, "cell": bomb.cell, "power": int(bomb.power), "age": 0, "blasted": false,
			"position": bomb.get("position", Vector2(bomb.cell)), "arms": []}
		# Bomb.init: a Sprite on its row's bomb layer (2).
		view.layer = _board.layer_of(int(bomb.cell.y), 2)
		view.item = {}
		_board.attach(view.layer, view.item, _board.cell_matrix(view.position))
		_screen.add_node({"path": view.item.path + "/@0", "parent": view.item.path, "stage_matrix": _board.cell_matrix(view.position),
			"role": "piece", "kind": "movie_clip", "effective_visible": true, "frame": 1})
		_bombs.append(view)
		_show_bomb(view)


static func _key(actor_id, cell) -> String:
	return "%s|%s" % [actor_id, cell]


## `Bomb.blast`: exp0 replaces the bomb clip, and an exp0 per flame cell goes on that row's
## platform layer at `xPos + EXCURSION_X ± k * GRID_WIDTH`.
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
		_board.attach(arm.layer, arm.item, _board.cell_matrix(Vector2(cell)), {}, "piece")
		view.arms.append(arm)


func _show_bomb(view: Dictionary) -> void:
	var matrix: Array = _board.cell_matrix(view.position)
	_screen.move_node(view.item.path, matrix)
	_screen.move_node(view.item.path + "/@0", matrix)
	if not view.blasted:
		var key := "%d|%d" % [view.age % 27 + 1, view.age % 14 + 1]
		_screen.set_node_art(view.item.path + "/@0", _bomb_art.get(key, {}), view.age % 27 + 1)
		return
	_screen.set_node_art(view.item.path + "/@0", _exp(1, maxi(1, view.age)), 1)
	for arm in view.arms:
		_screen.set_node_art(arm.item.path, _exp(arm.frame, view.age + 1), arm.frame)


## exp0 stopped at `root`, its nested blast at `nested` (it stops on its last frame).
func _exp(root: int, nested: int) -> Dictionary:
	var by_nested: Dictionary = _exp_art.get(str(root), {})
	if by_nested.is_empty(): return {}
	return by_nested.get(str(mini(nested, by_nested.size())), {})

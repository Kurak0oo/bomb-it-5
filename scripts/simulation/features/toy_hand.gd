extends RefCounted
## Birthday Party toy hand (`ToyHand.as`); see edition-5-birthday-party.md. The hand cell
## holds an invisible indestructible box; the arm reaches up to three cells.

const LENGTH_MAX := 3
const PUSH_SPEED := 0.5
const HAND_FRAMES := 14
## `pushComplete` frame of the hand clip per direction and reach `g0..g3` (SWF sprites).
const PUSH_FRAME := {Vector2i.UP: [6, 9, 9, 11], Vector2i.DOWN: [11, 10, 11, 11],
	Vector2i.LEFT: [9, 11, 11, 11], Vector2i.RIGHT: [9, 11, 11, 11]}
const DIRECTIONS := {"up": Vector2i.UP, "down": Vector2i.DOWN, "left": Vector2i.LEFT, "right": Vector2i.RIGHT}

var cell: Vector2i
var direction: Vector2i
var is_open := false
var current_frame := 0
var total_frame := 3 * 35
var hand_frame := 0
var push_step := 0
var touched: Array[Vector2i] = []
var robots_push: Array[StringName] = []
var bombs_push: Array[Dictionary] = []


func _init(at: Vector2i, detail: String) -> void:
	cell = at
	direction = DIRECTIONS.get(detail, Vector2i.DOWN)


func advance(round_state: RefCounted, _inputs: Dictionary) -> void:
	if not is_open:
		current_frame += 1
		if current_frame == total_frame:
			current_frame = 0
			total_frame = 35 * (2 + int(round_state.draw_random() * 2 * 10))
			is_open = true
			_push_setting(round_state)
			hand_frame = 1
		return
	hand_frame += 1
	if hand_frame == PUSH_FRAME[direction][push_step]:
		if round_state.mode().name != &"pac_man": _dispose_props(round_state)
		for bomb in bombs_push:
			if round_state.bombs().has(bomb): round_state.throw_bomb(bomb, direction, PUSH_SPEED)
		for id in robots_push:
			var actor: Dictionary = round_state.actors()[id]
			if actor.alive: actor.pushed = {"direction": direction, "speed": PUSH_SPEED}
	elif hand_frame == HAND_FRAMES:
		is_open = false
		# handShrinkSetting releases only cells 1..pushStep; cells scanned beyond stay touched.
		for step in range(1, push_step + 1): touched.erase(cell + direction * step)


## handPushSetting: scan up to three cells; a box ends the reach, otherwise the arm stops
## before the farthest bomb or robot.
func _push_setting(round_state: RefCounted) -> void:
	push_step = LENGTH_MAX
	robots_push.clear()
	bombs_push.clear()
	var reach := -2
	for step in range(1, LENGTH_MAX + 1):
		var target := cell + direction * step
		if round_state.board().get(target) in [&"solid", &"soft", &"toy_hand", null]:
			push_step = step - 1
			reach = push_step
			break
		if target not in touched: touched.append(target)
		var occupied := false
		for bomb in round_state.bombs():
			if bomb.cell == target and not bomb.get("flying", false):
				bombs_push.append(bomb)
				occupied = true
		for id in round_state.actors():
			var actor: Dictionary = round_state.actors()[id]
			if actor.alive and actor.cell == target:
				robots_push.append(id)
				occupied = true
		if occupied:
			push_step = step - 1
			reach = maxi(reach, push_step)
	if reach != -2: push_step = reach


func _dispose_props(round_state: RefCounted) -> void:
	for step in range(1, push_step + 1):
		var target := cell + direction * step
		if round_state.pickups().has(target):
			var kind: StringName = round_state.pickups()[target]
			round_state.pickups().erase(target)
			round_state.mode().pickup_removed(round_state, kind, &"")


## Cells `getAllEmptyPosition` and `containerMove` skip while the arm marks them.
func blocked_cells() -> Array[Vector2i]:
	return touched


func public_state() -> Dictionary:
	return {"kind": &"toy_hand", "cell": cell, "direction": direction, "open": is_open,
		"frame": hand_frame, "reach": push_step if is_open else 0, "touched": touched.duplicate()}

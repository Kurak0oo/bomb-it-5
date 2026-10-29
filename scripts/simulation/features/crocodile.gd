extends RefCounted
## Zoo crocodile (`Crocodile.as`); see edition-5-zoo.md. All crocodiles start closed at
## frame 0 and run in lockstep: 240 closed, 24 opening, 60 open (eating), 21 closing.

const CLOSED := 240
const OPENING := 24
const OPEN := 60
const CLOSING := 21
const CYCLE := CLOSED + OPENING + OPEN + CLOSING

var cell: Vector2i
var frame := 0


func _init(at: Vector2i) -> void:
	cell = at


func advance(round_state: RefCounted, _inputs: Dictionary) -> void:
	frame = frame % CYCLE + 1
	if frame == CLOSED + OPENING: round_state.play_sound(&"lavaOpen")
	if is_eating(): round_state.eat_cell(cell)


## `isDanger` turns on during the 240th closed tick and off when the mouth shuts.
func is_danger() -> bool:
	return frame >= CLOSED


func is_eating() -> bool:
	return frame > CLOSED + OPENING and frame <= CLOSED + OPENING + OPEN


func phase() -> StringName:
	if frame < CLOSED: return &"closed"
	if frame <= CLOSED + OPENING: return &"opening"
	if frame <= CLOSED + OPENING + OPEN: return &"open"
	return &"closing"


func blocked_cells() -> Array[Vector2i]:
	return []


func public_state() -> Dictionary:
	return {"kind": &"crocodile", "cell": cell, "phase": phase(), "danger": is_danger(), "frame": frame}

extends SceneTree
## #82: the `HitMove` port replays the recorded movement probes frame by frame
## (docs/evidence/edition-5-movement-runtime-probes.md; fixture from
## tools/extract_hitmove_fixtures.py). Input at counter N moves on frame N+1; the cell is
## registered from the position before the step, as the original's `view.xN` lags.

const Movement = preload("res://scripts/simulation/movement.gd")
const FIXTURE := "res://tests/fixtures/hitmove-probes.json"
const KEYS := {"right": Vector2.RIGHT, "left": Vector2.LEFT, "up": Vector2.UP, "down": Vector2.DOWN}
const TOLERANCE := 1e-4
var failures := 0
var checks := 0


func _initialize() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var board := {}
	for y in 15:
		for x in 17: board[Vector2i(x, y)] = &"floor"
	for box in fixture.boxes: board[Vector2i(box[0], box[1])] = &"solid"
	for name in fixture.cases:
		_replay(name, fixture.cases[name], board)
	_samples()
	print("%s: %d hitmove checks" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)


func _replay(name: String, recorded: Dictionary, board: Dictionary) -> void:
	var actor := {"position": Vector2(recorded.start[0], recorded.start[1]) / 30.0, "velocity": Vector2.ZERO,
		"speed": 1.6, "departures": [], "facing": Vector2.DOWN}
	actor.position = (actor.position * 600.0).round() / 600.0
	var bombs: Array = []
	var held: Array = []
	var mismatch := ""
	for row in recorded.expected:
		var frame: int = row[0]
		for key in recorded["keys"]:
			if key[0] != frame - 1: continue
			if key[2] == "space":
				if key[1] == "kd": bombs.append({"cell": Vector2i((actor.position + Vector2.ONE * 0.5).floor()), "kind": &"bomb"})
				continue
			held.erase(key[2])
			if key[1] == "kd": held.append(key[2])
		actor.cell = Vector2i((actor.position + Vector2.ONE * 0.5).floor())
		Movement.step_hit_move(actor, Vector2.ZERO if held.is_empty() else KEYS[held.back()], board, bombs)
		var at: Vector2 = actor.position * 30.0
		var speed: Vector2 = actor.velocity * 30.0
		if mismatch == "" and (absf(at.x - row[1]) > TOLERANCE or absf(at.y - row[2]) > TOLERANCE
				or absf(speed.x - row[3]) > TOLERANCE or absf(speed.y - row[4]) > TOLERANCE):
			mismatch = "frame %d: got %s v%s, recorded (%s, %s) v(%s, %s)" % [frame, at, speed, row[1], row[2], row[3], row[4]]
	_expect(mismatch == "", "%s replays every recorded frame (%d frames) %s" % [name, recorded.expected.size(), mismatch])


## Named source behaviours, independent of the replays.
func _samples() -> void:
	var board := {}
	for y in 15:
		for x in 17: board[Vector2i(x, y)] = &"solid" if x == 0 or y == 0 or x == 16 or y == 14 or (x % 2 == 0 and y % 2 == 0) else &"floor"
	var actor := {"position": Vector2(1, 1), "velocity": Vector2.ZERO, "speed": 1.6, "departures": [], "cell": Vector2i(1, 1)}
	var speeds: Array = []
	for frame in 4:
		Movement.step_hit_move(actor, Vector2.RIGHT, board, [])
		speeds.append(actor.velocity.x * 30.0)
	var recurrence := [1.6, 2.56, 3.136, 3.4816]
	_expect(range(4).all(func(index): return absf(speeds[index] - recurrence[index]) < TOLERANCE), "acceleration is v = 0.6v + 1.6 per held frame")
	var still: Vector2 = actor.position
	Movement.step_hit_move(actor, Vector2.ZERO, board, [])
	_expect(actor.position == still and absf(actor.velocity.x * 30.0 - 3.4816 * 0.6) < TOLERANCE, "release stops displacement while speed decays")
	var mine := {"position": Vector2(1, 1), "velocity": Vector2.ZERO, "speed": 1.6, "departures": [], "cell": Vector2i(1, 1)}
	for frame in 12:
		mine.cell = Vector2i((mine.position + Vector2.ONE * 0.5).floor())
		Movement.step_hit_move(mine, Vector2.RIGHT, board, [{"cell": Vector2i(2, 1), "kind": &"mine"}])
	_expect(mine.position.x > 2.0, "a landmine does not block movement")
	var bomb := {"position": Vector2(3, 1), "velocity": Vector2.ZERO, "speed": 1.6, "departures": [], "cell": Vector2i(3, 1)}
	for frame in 12:
		bomb.cell = Vector2i((bomb.position + Vector2.ONE * 0.5).floor())
		Movement.step_hit_move(bomb, Vector2.LEFT, board, [{"cell": Vector2i(2, 1)}])
	_expect(is_equal_approx(bomb.position.x, 3.0), "an ordinary bomb stops a robot at its edge")


func _expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr(label)

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
	_belt_ride()
	_toy_hand_pushes()
	_rides()
	_pac_man_catch()
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


## #83: an idle robot on the Candy Factory belt (`ConveyorBelt.robotMove` drives its own
## `HitMove`, vertical pair swapped), recorded in tests/fixtures/belt-ride.json.
func _belt_ride() -> void:
	var Simulation = load("res://scripts/simulation/bomb_simulation.gd")
	var Layouts = load("res://scripts/simulation/layouts.gd")
	var ArcadeMode = load("res://scripts/simulation/modes/arcade_mode.gd")
	var recorded: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/belt-ride.json"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var board: Dictionary = Layouts.roll(recorded.layout, 0.0, rng)
	var start := Vector2(recorded.start[0], recorded.start[1]) / 30.0
	var round = Simulation.new([&"human"] as Array[StringName], {&"human": {"cell": Vector2i(start), "position": start}}, board.cells,
		{"movement": true, "hit_move": true, "features": board.features, "center": board.center, "skin": board.skin,
		"mode": ArcadeMode.new(&"normal", &"candy_factory")})
	var mismatch := ""
	var idle: Array[Dictionary] = [{"actor_id": &"human", "direction": Vector2.ZERO, "bomb_events": []}]
	for row in recorded.frames:
		var state: Dictionary = round.advance(idle)
		var at: Vector2 = state.actors[&"human"].position * 30.0
		if mismatch == "" and (absf(at.x - row[1]) > TOLERANCE or absf(at.y - row[2]) > TOLERANCE):
			mismatch = "frame %d: got %s, recorded (%s, %s)" % [row[0], at, row[1], row[2]]
	_expect(mismatch == "", "an idle belt ride matches the recorded twip positions for %d frames %s" % [recorded.frames.size(), mismatch])


## #83: two toy-hand pushes of a robot at (12,7) with boxes at (13,7) and (14,7), as recorded
## on Birthday Party seed 11. The first push snaps straight back (no visible movement); the
## second, with the command's stale checked cell, moves 360 → 375 → 390 and stops in the box cell.
func _toy_hand_pushes() -> void:
	var Simulation = load("res://scripts/simulation/bomb_simulation.gd")
	var board := {}
	for y in 15:
		for x in 17: board[Vector2i(x, y)] = &"solid" if x == 0 or y == 0 or x == 16 or y == 14 else &"floor"
	board[Vector2i(13, 7)] = &"solid"
	board[Vector2i(14, 7)] = &"solid"
	var round = Simulation.new([&"human"] as Array[StringName], {&"human": {"cell": Vector2i(12, 7)}}, board, {"movement": true, "hit_move": true})
	var idle: Array[Dictionary] = [{"actor_id": &"human", "direction": Vector2.ZERO, "bomb_events": []}]
	var runs: Array = []
	for push in 2:
		round.actors()[&"human"].pushed = {"direction": Vector2i.RIGHT, "speed": 0.5}
		var xs: Array = []
		for frame in 4: xs.append(roundi(round.advance(idle).actors[&"human"].position.x * 30.0))
		runs.append(xs)
	_expect(runs == [[360, 360, 360, 360], [375, 390, 390, 390]], "toy-hand pushes follow the recorded stale-check behaviour: %s" % [runs])


## #83: a horse jumping a box and a dragon crashing a soft box, right held from the frame
## after the recorded key-down (tests/fixtures/rides.json).
func _rides() -> void:
	var Simulation = load("res://scripts/simulation/bomb_simulation.gd")
	var recorded: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/rides.json"))
	for ride in ["horse", "dragon"]:
		var spec: Dictionary = recorded[ride]
		var board := {}
		for y in 15:
			for x in 17: board[Vector2i(x, y)] = &"solid" if x == 0 or y == 0 or x == 16 or y == 14 else &"floor"
		for box in spec.boxes: board[Vector2i(box[0], box[1])] = &"solid"
		for box in spec.soft: board[Vector2i(box[0], box[1])] = &"soft"
		var start := Vector2i(spec.start[0], spec.start[1])
		var round = Simulation.new([&"human"] as Array[StringName], {&"human": {"cell": start, "vehicle": StringName(ride), "drive_speed": spec.drive_speed}},
			board, {"movement": true, "hit_move": true})
		var right: Array[Dictionary] = [{"actor_id": &"human", "direction": Vector2.RIGHT, "bomb_events": []}]
		var mismatch := ""
		for row in spec.frames:
			var at: Vector2 = round.advance(right).actors[&"human"].position * 30.0
			if mismatch == "" and (absf(at.x - row[1]) > TOLERANCE or absf(at.y - row[2]) > TOLERANCE):
				mismatch = "frame %d: got %s, recorded (%s, %s)" % [row[0], at, row[1], row[2]]
		_expect(mismatch == "", "the %s ride matches the recorded positions %s" % [ride, mismatch])


## #83: an invincible Pac-Man player catches a stopped ghost on the step after its position
## enters the ghost's cell (recorded: x 435.1 on frame 860, ghost dead on 861), because the
## cell registers from the position before each step.
func _pac_man_catch() -> void:
	var Simulation = load("res://scripts/simulation/bomb_simulation.gd")
	var PacMan = load("res://scripts/simulation/modes/pac_man_mode.gd")
	var board := {}
	for y in 15:
		for x in 17: board[Vector2i(x, y)] = &"solid" if x == 0 or y == 0 or x == 16 or y == 14 else &"floor"
	var round = Simulation.new([&"human", &"ruby"] as Array[StringName], {&"human": {"cell": Vector2i(2, 1)}, &"ruby": {"cell": Vector2i(15, 1)}},
		board, {"movement": true, "hit_move": true, "damage": true, "drops": true, "drop_chance": 0.0, "mode": PacMan.new(&"normal", &"cinema")})
	round.actors()[&"human"].invincible_until = 100000
	round.actors()[&"human"].invincible_active_from = 0
	var commands: Array[Dictionary] = [{"actor_id": &"human", "direction": Vector2.RIGHT, "bomb_events": []},
		{"actor_id": &"ruby", "direction": Vector2.ZERO, "bomb_events": []}]
	var entered := -1
	var caught := -1
	for frame in 200:
		var state: Dictionary = round.advance(commands)
		if entered < 0 and floori(state.actors[&"human"].position.x + 0.5) == 15: entered = frame
		if caught < 0 and not state.actors[&"ruby"].alive: caught = frame
	_expect(entered >= 0 and caught == entered + 1, "an invincible player catches a ghost one step after entering its cell (entered %d, caught %d)" % [entered, caught])


func _expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr(label)

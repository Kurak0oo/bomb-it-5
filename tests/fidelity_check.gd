extends SceneTree
## Source-derived public regressions; provenance is in fidelity-comparisons.json.

const Simulation = preload("res://scripts/simulation/bomb_simulation.gd")
const Scheduler = preload("res://scripts/simulation/tick_scheduler.gd")
const AI = preload("res://scripts/simulation/ai_controller.gd")
var checks := 0
var failures := 0
var simulation: RefCounted
var scheduler: Node
var roster: Array[StringName] = []
var ai: RefCounted
var comparisons: Array[Dictionary] = []
var fixtures: Array[Dictionary] = []
var current_fixture := -1


func _initialize() -> void:
	_stationary_protection_expiry()
	_retained_bomb_cleanup()
	_overlap_callbacks()
	_movement_registration()
	_protection_and_vehicle_stages()
	_pickup_awards()
	_exhausted_vehicle_draw()
	_hammer_action_frames()
	_laser_single_pass()
	_mine_contact_and_external_blast()
	_flamer_native_endpoints()
	_projectile_emission_and_recovery()
	_projectile_cleanup()
	_death_settlement()
	_ai_source_item_targeting()
	_ai_random_item_and_cost()
	_ai_upward_danger()
	_ai_equipment_actions()
	_portal_arrival_registration()
	_action_pickup_replacement()
	_drop_animation_boundary()
	_protected_mine_contact_credit()
	_practice_death_animation()
	_direction_and_action_share_input_phase()
	_chain_contact_order()
	_external_blast_hits_every_stacked_bomb()
	_ai_perception_rotation()
	if is_instance_valid(scheduler): scheduler.free()
	var folder := ProjectSettings.globalize_path("res://.scratch/fidelity-port")
	DirAccess.make_dir_recursive_absolute(folder)
	var report := FileAccess.open(folder.path_join("comparisons.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"schema": "edition5-public-comparisons-v1", "checks": checks,
		"failures": failures, "fixtures": fixtures, "comparisons": comparisons,
		"first_difference": comparisons.filter(func(row): return not row.passed).slice(0, 1)}, "  "))
	print("%s: %d fidelity checks" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)


func _open_board() -> Dictionary:
	var board := {}
	for y in 15:
		for x in 17:
			board[Vector2i(x, y)] = &"solid" if x == 0 or y == 0 or x == 16 or y == 14 else &"floor"
	return board


func _start(actors: Dictionary, rules: Dictionary = {}, board: Dictionary = {}) -> void:
	if is_instance_valid(scheduler): scheduler.free()
	roster.assign(actors.keys())
	if board.is_empty(): board = _open_board()
	simulation = Simulation.new(roster, actors, board, rules)
	scheduler = Scheduler.new(roster, simulation)
	current_fixture = fixtures.size()
	fixtures.append({"id": current_fixture, "initial_actors": actors.duplicate(true),
		"initial_board": board.duplicate(true), "rules": rules.duplicate(true),
		"clock": "accepted 35Hz simulation; callback/host-clock conversions are documented separately",
		"input_mapping": "enqueue before tick cutoff; one admitted interval per step; uniform bomb birth exclusion"})


func _step(count: int = 1, directions: Dictionary = {}, events: Dictionary = {}) -> Dictionary:
	for id in directions: scheduler.set_direction(id, directions[id])
	for id in events:
		for event in events[id]: scheduler.enqueue_bomb_event(id, event)
	var state: Dictionary = simulation.snapshot()
	for index in count:
		var update: Dictionary = scheduler.advance_time(1.0 / 35.0)
		if not update.ticks.is_empty(): state = update.ticks[-1]
	return state


func _expect(condition: bool, label: String) -> void:
	checks += 1
	var state: Dictionary = simulation.snapshot()
	comparisons.append({"fixture": current_fixture, "requirement": label, "passed": condition,
		"tick": state.tick, "actors": state.actors, "fire": state.fire, "bombs": state.bomb_occupancy,
		"attacks": state.attacks, "projectiles": state.projectiles, "outcome": state.outcome,
		"round_stage": state.round_stage})
	if not condition:
		failures += 1
		printerr(label)


func _stationary_protection_expiry() -> void:
	# Movement supplement stationary-expiry: eligibility changing alone does not poll fire.
	_start({&"human": {"cell": Vector2i(3, 3), "protected_until": 80}}, {"damage": true, "movement": true})
	_step(1, {}, {&"human": [&"down"]})
	var state := _step(80)
	_expect(state.actors[&"human"].alive and state.fire.has(Vector2i(3, 3)),
		"stationary protection expiry in existing fire does not synthesize a contact command")


func _retained_bomb_cleanup() -> void:
	# Contact and chain probes: capacity releases at blast; map membership lasts through ended.
	_start({&"human": {"cell": Vector2i(3, 3), "protected_until": 200}}, {"damage": true})
	_step(1, {}, {&"human": [&"down"]})
	var state := _step(72)
	_expect(state.bombs.is_empty() and state.get("bomb_occupancy", []).size() == 1,
		"detonated bomb releases capacity but retains map occupancy until cleanup")
	state = _step(16)
	_expect(state.fire.is_empty() and state.get("bomb_occupancy", []).is_empty(),
		"unskipped ended callbacks clear ordinary fire and retained occupancy together")


func _overlap_callbacks() -> void:
	# Both spatial orders in overlap probes: 11 callback separation from 10-frame placement gap.
	for reverse in [false, true]:
		_start({&"human": {"cell": Vector2i(1 if not reverse else 3, 3), "protected_until": 500},
			&"ai": {"cell": Vector2i(3 if not reverse else 1, 3), "protected_until": 500}}, {"damage": true})
		_step(1, {}, {&"human": [&"down"]})
		_step(9)
		_step(1, {}, {&"ai": [&"down"]})
		var state := _step(78)
		_expect(state.tick == 89 and not state.fire.has(Vector2i(2, 3)) and state.flames.size() == 1,
			"older cleanup clears shared Boolean fire while the younger visual remains in either owner order")
		_expect(state.flames[0].count == 5, "live cleanup removal skips the younger callback")


func _movement_registration() -> void:
	# motion-frames: six physical steps cross the midpoint; logical contact updates next callback.
	_start({&"human": {"cell": Vector2i(1, 3)}}, {"movement": true})
	var state := _step(6, {&"human": Vector2.RIGHT})
	_expect(state.actors[&"human"].position.x > 1.5 and state.actors[&"human"].cell == Vector2i(1, 3),
		"logical map registration trails physical midpoint crossing by one accepted tick")
	state = _step()
	_expect(state.actors[&"human"].cell == Vector2i(2, 3), "next robot registration updates the logical cell")


func _protection_and_vehicle_stages() -> void:
	_start({&"human": {"cell": Vector2i(3, 3)}}, {"damage": true, "drops": true,
		"pickups": {Vector2i(3, 3): &"invincible"}})
	var state := _step()
	_expect(state.actors[&"human"].score == 0 and state.actors[&"human"].get("protection_stage") == &"introduction",
		"Invincibility collection has an introduction and awards zero points")
	state = _step(29)
	_expect(state.actors[&"human"].get("protection_stage") == &"active", "Invincibility starts active contact after introduction")
	_start({&"human": {"cell": Vector2i(3, 3)}}, {"damage": true, "drops": true,
		"pickups": {Vector2i(3, 3): &"car"}})
	_step()
	_step(1, {}, {&"human": [&"down"]})
	state = _step(72)
	_expect(state.actors[&"human"].vehicle == &"car" and state.actors[&"human"].get("vehicle_recovery_until", 0) > state.tick,
		"vehicle stays attached during its one-second damage recovery")
	state = _step(35)
	_expect(state.actors[&"human"].vehicle == &"" and state.actors[&"human"].protected_until > state.tick,
		"vehicle completion removes the ride then starts blinking protection")


func _pickup_awards() -> void:
	_start({&"human": {"cell": Vector2i(3, 3), "capacity": 9}, &"ai": {"cell": Vector2i(5, 3)}},
		{"drops": true, "pickups": {Vector2i(3, 3): &"capacity", Vector2i(5, 3): &"life"}})
	var state := _step()
	_expect(state.actors[&"human"].capacity == 9 and state.actors[&"human"].score == 100 and state.pickups.is_empty(),
		"capped upgrades still collect and award 100")
	_expect(state.actors[&"ai"].lives == 1 and state.actors[&"ai"].score == 100,
		"AI LifeProp collects and scores without increasing survival or retry lives")


func _exhausted_vehicle_draw() -> void:
	var board := _open_board()
	board[Vector2i(4, 3)] = &"soft"
	# Explicit captured-state fixture: Car,Car,Moto slots; no vehicle budget; ordinary quota 23.
	_start({&"human": {"cell": Vector2i(3, 3), "protected_until": 10000}},
		{"damage": true, "drops": true, "vehicle_budget": 0, "drop_count": 23,
		"random_draws": [0.9, 0.9, 0.1, 0.1, 0.98, 0.1, 0.2, 0.999, 0.0]}, board)
	_step(1, {}, {&"human": [&"down"]})
	var state := _step(90)
	_expect(not state.pickups.has(Vector2i(4, 3)), "zero-budget vehicle draw creates no item")
	state = _step(2009)
	_expect(state.pickups.values().has(&"car"), "timed spawn can use the Car slot left by partial shared-list mutation")


func _hammer_action_frames() -> void:
	_start({&"human": {"cell": Vector2i(3, 3), "facing": Vector2.UP}},
		{"drops": true, "pickups": {Vector2i(3, 3): &"hammer"}})
	_step()
	_step(1, {}, {&"human": [&"down"]})
	var state := _step(12)
	_expect(state.attacks.size() == 1 and state.attacks[0].get("frame") == 12 and state.attacks[0].get("layer") == &"behind",
		"up hammer attachment changes layer at source clip frame twelve")
	_step(12)
	state = _step(1, {}, {&"human": [&"down"]})
	_expect(state.actors[&"human"].weapon == &"hammer" and state.actors[&"human"].ammo == 0,
		"second use retains held equipment until the active action completes")
	state = _step(24)
	_expect(state.actors[&"human"].weapon == &"" and state.attacks.is_empty(),
		"hammer impact restores default equipment once after its second use")


func _laser_single_pass() -> void:
	var board := _open_board()
	board[Vector2i(4, 3)] = &"portal"
	board[Vector2i(6, 3)] = &"soft"
	board[Vector2i(7, 3)] = &"soft"
	_start({&"human": {"cell": Vector2i(3, 3), "facing": Vector2.RIGHT}},
		{"drops": true, "pickups": {Vector2i(3, 3): &"laser"}}, board)
	_step()
	_step(1, {}, {&"human": [&"down"]})
	var state := _step(10)
	_expect(state.board[Vector2i(6, 3)] == &"soft", "laser waits for charge frame eleven")
	state = _step()
	_expect(state.board[Vector2i(6, 3)] == &"floor" and state.board[Vector2i(7, 3)] == &"soft",
		"laser passes a bare portal and ends the same pass at the first soft blocker")
	state = _step(10)
	_expect(state.attacks.size() == 1 and state.fire.is_empty(), "visible beam has no repeated pass or tiled fire")
	state = _step()
	_expect(state.attacks.is_empty(), "eleventh laser cleanup callback restores control and removes the beam")


func _mine_contact_and_external_blast() -> void:
	_start({&"human": {"cell": Vector2i(3, 3), "protected_until": 1000},
		&"ai": {"cell": Vector2i(4, 3), "protected_until": 1000}},
		{"drops": true, "damage": true, "pickups": {Vector2i(3, 3): &"landmine"}})
	_step()
	var state := _step(1, {}, {&"human": [&"down"]})
	_expect(state.bombs.is_empty(), "mine down queues placement for the next action callback")
	state = _step(1, {}, {&"ai": [&"down"]})
	_expect(state.bombs.size() == 2, "mine and adjacent ordinary bomb use separate capacity paths")
	state = _step(72)
	_expect(state.actors[&"human"].bomb_count == -1,
		"external blast of an unarmed mine preserves original ordinary-capacity underflow")
	_start({&"human": {"cell": Vector2i(3, 3), "protected_until": 1000}},
		{"drops": true, "damage": true, "movement": true, "pickups": {Vector2i(3, 3): &"landmine"}})
	_step()
	_step(1, {}, {&"human": [&"down"]})
	_step(14, {&"human": Vector2.RIGHT})
	_step(14, {&"human": Vector2.LEFT})
	state = _step(1, {&"human": Vector2.ZERO})
	_expect(state.actors[&"human"].bomb_count == 0, "contact mine never decrements ordinary capacity")


func _flamer_native_endpoints() -> void:
	# Compare against independent original getter results, not a Godot-generated envelope.
	var directions := {"up": Vector2.UP, "down": Vector2.DOWN, "left": Vector2.LEFT, "right": Vector2.RIGHT}
	for direction in directions:
		var oracle: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
			"res://docs/evidence/reference-2026-10-19/weapon-survey/flamer-geometry-%s-01/geometry-summary.json" % direction))
		_start({&"human": {"cell": Vector2i(1, 1), "facing": directions[direction]}},
			{"drops": true, "pickups": {Vector2i(1, 1): &"flamer"}})
		_step()
		_step(1, {}, {&"human": [&"down"]})
		for row in oracle.rows:
			var state := _step()
			var expected := Vector2i(int(row.actual.xN), int(row.actual.yN))
			_expect(not state.attacks.is_empty() and state.attacks[0].get("endpoint") == expected,
				"flamer %s frame %d agrees with original endpoint getter" % [direction, int(row.fire_frame)])


func _projectile_emission_and_recovery() -> void:
	_start({&"human": {"cell": Vector2i(1, 3), "facing": Vector2.RIGHT}},
		{"drops": true, "pickups": {Vector2i(1, 3): &"triple"}})
	_step()
	var state := _step(1, {}, {&"human": [&"down"]})
	_expect(state.projectiles.is_empty(), "triple-shot down does not run its first action callback immediately")
	state = _step(31)
	_expect(state.projectiles.size() == 3 and state.actors[&"human"].busy_until > state.tick,
		"three inline emissions are fifteen callbacks apart and precede independent recovery")
	scheduler.pause()
	var before: Dictionary = simulation.snapshot()
	scheduler.advance_time(10.0)
	_expect(simulation.snapshot() == before, "pending projectile recovery and travel freeze while paused")
	scheduler.resume()
	state = _step(11)
	_expect(state.attacks.is_empty() and state.actors[&"human"].busy_until <= state.tick,
		"explicit simulation-time conversion completes 0.3-second recovery after the final emission")
	_start({&"human": {"cell": Vector2i(1, 3), "facing": Vector2.RIGHT}},
		{"drops": true, "pickups": {Vector2i(1, 3): &"shotgun"}})
	_step()
	_step(1, {}, {&"human": [&"down"]})
	state = _step(13)
	_expect(state.projectiles.is_empty(), "fireball waits for its final frame fourteen")
	state = _step()
	_expect(state.projectiles.size() == 1, "fireball releases on its own frame-fourteen boundary")


func _projectile_cleanup() -> void:
	var board := _open_board()
	board[Vector2i(3, 3)] = &"soft"
	_start({&"human": {"cell": Vector2i(1, 3), "facing": Vector2.RIGHT}},
		{"drops": true, "pickups": {Vector2i(1, 3): &"shotgun"}}, board)
	_step()
	_step(1, {}, {&"human": [&"down"]})
	_step(14)
	# Three ten-unit moves reach the free cell anchor; the fourth attempts blocked entry.
	var state := _step(4)
	_expect(state.board[Vector2i(3, 3)] == &"floor" and state.projectiles.size() == 1 and state.projectiles[0].get("phase") == &"cleanup",
		"projectile collision affects the additional cell and retains an invisible cleanup callback")
	state = _step(11)
	_expect(state.projectiles.size() == 1, "projectile remains through eleven cleanup callbacks")
	state = _step()
	_expect(state.projectiles.is_empty(), "twelfth projectile cleanup callback removes it")


func _death_settlement() -> void:
	_start({&"human": {"cell": Vector2i(3, 3)}, &"ai": {"cell": Vector2i(4, 3)}},
		{"damage": true, "round": true})
	_step(1, {}, {&"human": [&"down"]})
	var state := _step(72)
	_expect(not state.actors[&"human"].alive and state.actors[&"human"].lives == 3 and state.outcome == &"running",
		"simultaneous death detaches actors without spending hearts or settling the result")
	state = _step(59)
	_expect(state.get("round_stage") == &"ending" and state.get("pending_outcome") == &"lost",
		"death-animation completion judges zero humans before zero enemies")
	state = _step(104)
	_expect(state.actors[&"human"].lives == 3 and state.outcome == &"running", "three-second ending cartoon precedes settlement")
	state = _step()
	_expect(state.outcome == &"lost" and state.actors[&"human"].lives == 2 and state.result_score == 300,
		"one loss settlement spends one heart and preserves attributed kills")
	var settled: Dictionary = simulation.snapshot()
	_step(20)
	_expect(simulation.snapshot() == settled, "settled round cannot spend or credit again")


func _ai_source_item_targeting() -> void:
	_start({&"human": {"cell": Vector2i(12, 12)}, &"ai": {"cell": Vector2i(3, 3)}},
		{"movement": true, "drops": true, "pickups": {Vector2i(3, 4): &"speed", Vector2i(5, 3): &"capacity"}})
	ai = AI.new(42)
	scheduler.set_controller(&"ai", func(): return ai.command(simulation.snapshot(), &"ai"))
	var state := _step(4)
	_expect(state.get("controller_observations", {}).has(&"ai"), "real round result exposes copied AI decision observations")
	if state.get("controller_observations", {}).has(&"ai"):
		var observed: Dictionary = state.controller_observations[&"ai"]
		_expect(not observed.perception.items.has(Vector2i(3, 4)) and observed.perception.items.has(Vector2i(5, 3)),
			"Normal parser excludes Speed targeting while retaining capacity pickups")


func _ai_random_item_and_cost() -> void:
	var board := _open_board()
	for cell in board: board[cell] = &"solid"
	for cell in [Vector2i(3, 8), Vector2i(3, 9), Vector2i(4, 9), Vector2i(5, 9), Vector2i(4, 7), Vector2i(12, 12)]:
		board[cell] = &"floor"
	board[Vector2i(3, 9)] = &"portal"
	# Declared route excerpt reproduces source cost 62 (60 + 2 + zero-cost goal), not BFS length.
	_start({&"human": {"cell": Vector2i(12, 12)}, &"ai": {"cell": Vector2i(3, 8)}},
		{"pickups": {Vector2i(4, 7): &"capacity", Vector2i(5, 9): &"power"}}, board)
	ai = AI.new(42, [0.99, 0.99, 0.1, 0.7361214081756771])
	scheduler.set_controller(&"ai", func(): return ai.command(simulation.snapshot(), &"ai"))
	var state := _step(4)
	var observed: Dictionary = state.controller_observations[&"ai"]
	_expect(observed.state == &"GetItem" and observed.target == Vector2i(5, 9) and observed.path_cost == 62,
		"randomized first acceptable item uses source estimate-price cost rather than nearest-item BFS")


func _ai_upward_danger() -> void:
	_start({&"human": {"cell": Vector2i(3, 8)}, &"ai": {"cell": Vector2i(8, 8)}}, {})
	_step(1, {}, {&"human": [&"down"]})
	ai = AI.new(42)
	scheduler.set_controller(&"ai", func(): return ai.command(simulation.snapshot(), &"ai"))
	var state := _step(40)
	var perception: Dictionary = state.controller_observations[&"ai"].perception
	_expect(not perception.danger.has(Vector2i(3, 7)) and perception.danger.has(Vector2i(2, 8)),
		"upward bomb danger excludes remaining thirty while other rays are already perceived")
	state = _step(2)
	_expect(state.controller_observations[&"ai"].perception.danger.has(Vector2i(3, 7)),
		"strict less-than-thirty upward danger appears on the following source counter")


func _ai_equipment_actions() -> void:
	for kind in [&"landmine", &"hammer", &"flamer", &"laser", &"triple", &"shotgun"]:
		_start({&"human": {"cell": Vector2i(5, 5)}, &"ai": {"cell": Vector2i(4, 5)}},
			{"movement": true, "damage": true, "drops": true, "pickups": {Vector2i(4, 5): kind}})
		_step()
		var draws: Array = []
		draws.resize(300)
		draws.fill(0.04)
		ai = AI.new(42, draws)
		scheduler.set_controller(&"ai", func(): return ai.command(simulation.snapshot(), &"ai"))
		var used := false
		var state: Dictionary = {}
		for index in 110:
			state = _step()
			used = used or not state.attacks.is_empty() or state.bombs.any(func(b): return b.get("kind") == &"mine")
		_expect(used, "Normal AI dispatches %s through admitted weapon input" % kind)
		if kind != &"landmine":
			_expect(not state.actors[&"human"].alive, "source adjacent-target %s attack kills through the real damage path" % kind)


func _portal_arrival_registration() -> void:
	var pairs := {Vector2i(8, 1): Vector2i(8, 13), Vector2i(8, 13): Vector2i(8, 1),
		Vector2i(4, 7): Vector2i(12, 7), Vector2i(12, 7): Vector2i(4, 7)}
	for origin in pairs:
		var board := _open_board()
		for mouth in pairs: board[mouth] = &"portal"
		_start({&"human": {"cell": origin}}, {"movement": true, "portals": pairs}, board)
		var state := _step(30, {&"human": Vector2.RIGHT})
		_expect(state.actors[&"human"].position == Vector2(pairs[origin]) and state.actors[&"human"].cell == origin,
			"portal physical arrival precedes logical registration and ignores interrupted held movement")
		state = _step(1, {&"human": Vector2.ZERO})
		_expect(state.actors[&"human"].cell == pairs[origin] and state.actors[&"human"].blink_until > state.tick and state.actors[&"human"].protected_until <= state.tick,
			"portal destination registration restores vulnerability before the separate blink ends")


func _action_pickup_replacement() -> void:
	_start({&"human": {"cell": Vector2i(3, 3), "weapon": &"flamer", "ammo": 2, "facing": Vector2.RIGHT}},
		{"drops": true, "pickups": {Vector2i(3, 3): &"hammer"}})
	_step(1, {}, {&"human": [&"down"]})
	var state := _step()
	_expect(state.actors[&"human"].weapon == &"flamer" and state.pickups.is_empty() and state.attacks.size() == 1,
		"initial flamer own-cell hit destroys an incoming pickup before collection")
	_start({&"human": {"cell": Vector2i(3, 3), "weapon": &"hammer", "ammo": 2}},
		{"drops": true, "pickups": {Vector2i(3, 3): &"laser"}})
	_step(1, {}, {&"human": [&"down"]})
	state = _step()
	_expect(state.actors[&"human"].weapon == &"laser" and state.attacks.is_empty() and state.actors[&"human"].busy_until <= state.tick,
		"genuine equipment replacement disposes the old action and restores controls")


func _drop_animation_boundary() -> void:
	var board := _open_board()
	board[Vector2i(4, 3)] = &"soft"
	_start({&"human": {"cell": Vector2i(3, 3), "protected_until": 200}},
		{"damage": true, "drops": true, "random_draws": [0.1, 0.1, 0.1, 0.1, 0.0]}, board)
	_step(1, {}, {&"human": [&"down"]})
	_step(81)
	var state := _step()
	_expect(state.pickups.get(Vector2i(4, 3)) == &"capacity" and state.fire.has(Vector2i(4, 3)),
		"source brick reveal can produce a pickup ten callbacks after destruction while fire remains")


func _protected_mine_contact_credit() -> void:
	_start({&"human": {"cell": Vector2i(3, 3), "weapon": &"landmine", "ammo": 1, "protected_until": 1000},
		&"ai": {"cell": Vector2i(5, 3), "protected_until": 1000}}, {"movement": true, "damage": true})
	_step(1, {}, {&"human": [&"down"]})
	_step(15, {&"human": Vector2.LEFT})
	var state := _step(20, {&"human": Vector2.ZERO, &"ai": Vector2.LEFT})
	_expect(state.actors[&"ai"].alive and state.actors[&"human"].score == 100 and state.actors[&"human"].kills == 1,
		"mine contact source award increments score and kill counter even when the protected target survives")


func _practice_death_animation() -> void:
	_start({&"human": {"cell": Vector2i(3, 3)}}, {"damage": true})
	_step(1, {}, {&"human": [&"down"]})
	var state := _step(102)
	_expect(state.actors[&"human"].death_frame > 1 and state.outcome == &"running",
		"practice advances death feedback without installing match settlement")


func _direction_and_action_share_input_phase() -> void:
	_start({&"human": {"cell": Vector2i(3, 3), "weapon": &"laser", "ammo": 2}}, {"movement": true})
	var state := _step(1, {&"human": Vector2.RIGHT}, {&"human": [&"down"]})
	_expect(state.attacks[0].direction == Vector2i.RIGHT and state.actors[&"human"].position == Vector2(3, 3),
		"admitted heading can turn and begin a locked action before physical movement for either controller")


func _chain_contact_order() -> void:
	# Bomb.blast sets center fire/damage before rays; rays visit distance before direction.
	_start({&"human": {"cell": Vector2i(3, 3)}, &"ai": {"cell": Vector2i(4, 3)}}, {"damage": true})
	_step(1, {}, {&"human": [&"down"], &"ai": [&"down"]})
	var state := _step(72)
	_expect(not state.actors[&"human"].alive and state.actors[&"ai"].kills == 0,
		"initiating center self-hit occurs before a recursive neighbor can receive that kill credit")
	_start({&"human": {"cell": Vector2i(3, 3), "power": 2, "protected_until": 1000},
		&"upper": {"cell": Vector2i(3, 1), "protected_until": 1000},
		&"right": {"cell": Vector2i(4, 3), "power": 2, "protected_until": 1000},
		&"victim": {"cell": Vector2i(4, 1)}}, {"damage": true})
	_step(1, {}, {&"human": [&"down"], &"upper": [&"down"], &"right": [&"down"]})
	state = _step(72)
	_expect(state.actors[&"right"].kills == 1 and state.actors[&"upper"].kills == 0,
		"distance-one Right chain delivers damage before the initiating distance-two Up chain")


func _external_blast_hits_every_stacked_bomb() -> void:
	_start({&"human": {"cell": Vector2i(4, 3), "protected_until": 1000},
		&"ai": {"cell": Vector2i(3, 3), "protected_until": 1000}},
		{"damage": true, "drops": true, "pickups": {Vector2i(3, 3): &"landmine"}})
	_step(1, {}, {&"human": [&"down"], &"ai": [&"down"]})
	_step(1, {}, {&"ai": [&"down"]})
	var state := _step(71)
	_expect(state.bombs.is_empty() and state.actors[&"ai"].bomb_count == -1,
		"external BLAST visits both ordinary and mine entries in a legal same-cell stack")


func _ai_perception_rotation() -> void:
	_start({&"human": {"cell": Vector2i(9, 5), "protected_until": 1000},
		&"a": {"cell": Vector2i(3, 3)}, &"b": {"cell": Vector2i(4, 3)}, &"c": {"cell": Vector2i(5, 3)}}, {})
	ai = AI.new(42)
	for id in [&"a", &"b", &"c"]:
		scheduler.set_controller(id, _produce_ai.bind(id))
	_step(15)
	_step(1, {}, {&"human": [&"down"]})
	var state := _step()
	_expect(state.controller_observations[&"b"].perception.danger.has(Vector2i(9, 5)) and not state.controller_observations[&"c"].perception.danger.has(Vector2i(9, 5)),
		"new bombs enter only the selected brain's cached perception while off-turn routes retain their previous observation")


func _produce_ai(id: StringName) -> Dictionary:
	return ai.command(simulation.snapshot(), id)

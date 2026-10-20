extends SceneTree
## Explicit real-round desktop art fixtures; never included in the gameplay flow.

const Simulation = preload("res://scripts/simulation/bomb_simulation.gd")
const Scheduler = preload("res://scripts/simulation/tick_scheduler.gd")
const View = preload("res://scripts/game_view.gd")
const IDS: Array[StringName] = [&"human", &"ruby", &"mint", &"gold"]
var host: Node2D
var view: Node2D
var simulation: RefCounted
var scheduler: Node
var last: Dictionary
var captures: Array[Dictionary] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	host = Node2D.new()
	root.add_child(host)
	view = View.new()
	host.add_child(view)
	var equipment := [&"capacity", &"power", &"speed", &"life", &"shield", &"invincible",
		&"car", &"moto", &"landmine", &"hammer", &"flamer", &"laser", &"triple", &"shotgun"]
	var pickups := {}
	for n in equipment.size(): pickups[Vector2i(2 + (n % 7) * 2, 10 + (n / 7) * 2)] = equipment[n]
	_start({&"human": {"cell": Vector2i(3, 3), "shield": 1},
		&"ruby": {"cell": Vector2i(6, 3), "vehicle": &"car"},
		&"mint": {"cell": Vector2i(10, 3), "vehicle": &"moto"},
		&"gold": {"cell": Vector2i(13, 3)}}, {"pickups": pickups})
	_step(1)
	await _capture("items-rides-shield")
	for n in 8:
		_step(1, Vector2.RIGHT)
		if n in [1, 6]: await _capture("walk-%d" % n)
	_step(1)
	await _capture("release-idle")
	# Repeated rendering at one admitted tick must neither advance nor mutate play.
	var before: Dictionary = simulation.snapshot()
	_present(true)
	await _drawn()
	var first := root.get_texture().get_image().get_data()
	for n in 4:
		_present(true)
		await _drawn()
	assert(root.get_texture().get_image().get_data() == first, "paused art must remain pixel-identical")
	assert(simulation.snapshot() == before, "rendering must not mutate the admitted round")
	checks += 2
	await _capture("paused-fixture", true)
	_start({&"human": {"cell": Vector2i(3, 3)}, &"ruby": {"cell": Vector2i(6, 3)},
		&"mint": {"cell": Vector2i(10, 3)}, &"gold": {"cell": Vector2i(13, 3)}},
		{"pickups": {Vector2i(3, 3): &"invincible"}})
	_step(8)
	await _capture("invincibility-introduction")
	_step(30)
	await _capture("invincibility-active")
	_start({&"human": {"cell": Vector2i(3, 3), "vehicle": &"car"},
		&"ruby": {"cell": Vector2i(6, 3), "vehicle": &"moto"},
		&"mint": {"cell": Vector2i(10, 3)}, &"gold": {"cell": Vector2i(13, 3)}}, {})
	scheduler.enqueue_bomb_event(&"human", &"down")
	scheduler.enqueue_bomb_event(&"ruby", &"down")
	_step(73)
	await _capture("ride-loss-recovery")
	_step(35)
	await _capture("ride-recovery-complete")
	scheduler.free()
	var folder := ProjectSettings.globalize_path("res://.scratch/presentation-captures")
	var file := FileAccess.open(folder.path_join("checks.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "captures": captures}, "  "))
	print("PASS: %d desktop presentation checks" % checks)
	quit(0)


func _start(actors: Dictionary, extra: Dictionary) -> void:
	if is_instance_valid(scheduler): scheduler.free()
	var board := {}
	for y in 15:
		for x in 17:
			board[Vector2i(x, y)] = &"solid" if x == 0 or y == 0 or x == 16 or y == 14 else &"floor"
	var rules := {"movement": true, "damage": true, "drops": true}
	rules.merge(extra, true)
	simulation = Simulation.new(IDS, actors, board, rules)
	scheduler = Scheduler.new(IDS, simulation)
	last = simulation.snapshot()
	_present()


func _step(count: int, direction: Vector2 = Vector2.ZERO) -> void:
	scheduler.set_direction(&"human", direction)
	for n in count:
		last = scheduler.advance_time(1.0 / 35.0).ticks[0]
		_present()


func _present(is_paused: bool = false) -> void:
	var observed := last.duplicate(true)
	observed.session = {"lives": 3, "total_score": 0, "game_over": false}
	observed.comparison_fixture = true
	view.present(observed, true, is_paused)


func _drawn() -> void:
	await process_frame
	await RenderingServer.frame_post_draw


func _capture(label: String, is_paused: bool = false) -> void:
	_present(is_paused)
	await _drawn()
	var folder := ProjectSettings.globalize_path("res://.scratch/presentation-captures")
	DirAccess.make_dir_recursive_absolute(folder)
	assert(root.get_texture().get_image().save_png(folder.path_join(label + ".png")) == OK)
	captures.append({"label": label, "tick": last.tick})
	print("CAPTURE: ", label)

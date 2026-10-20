extends SceneTree
## Explicit controlled desktop fixtures; production sessions never use this board.
const Simulation = preload("res://scripts/simulation/bomb_simulation.gd")
const Scheduler = preload("res://scripts/simulation/tick_scheduler.gd")
const View = preload("res://scripts/game_view.gd")
var host: Node2D
var view: Node2D
var simulation: RefCounted
var scheduler: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	host = Node2D.new()
	root.add_child(host)
	view = View.new()
	host.add_child(view)
	_start(&"hammer", Vector2.UP)
	_step(12)
	await _capture("hammer-layer-frame12")
	_start(&"laser", Vector2.RIGHT)
	_step(10)
	await _capture("laser-charge")
	_step(1)
	await _capture("laser-beam")
	_start(&"flamer", Vector2.RIGHT)
	_step(5)
	await _capture("flamer-first-tip")
	_step(17)
	await _capture("flamer-final-tip")
	_start(&"triple", Vector2.RIGHT)
	_step(31)
	await _capture("triple-third-emission")
	_start(&"shotgun", Vector2.RIGHT)
	_step(13)
	await _capture("fireball-charge")
	_step(12)
	await _capture("fireball-independent-recovery")
	scheduler.free()
	quit(0)


func _start(weapon: StringName, facing: Vector2) -> void:
	if is_instance_valid(scheduler): scheduler.free()
	var board := {}
	for y in 15:
		for x in 17:
			board[Vector2i(x, y)] = &"solid" if x == 0 or y == 0 or x == 16 or y == 14 else &"floor"
	board[Vector2i(4, 3)] = &"portal"
	board[Vector2i(6, 3)] = &"soft"
	simulation = Simulation.new([&"human"], {&"human": {"cell": Vector2i(3, 3),
		"weapon": weapon, "ammo": 2, "facing": facing}}, board, {"damage": true})
	scheduler = Scheduler.new([&"human"], simulation)
	scheduler.enqueue_bomb_event(&"human", &"down")
	scheduler.advance_time(1.0 / 35.0)


func _step(count: int) -> void:
	for index in count: scheduler.advance_time(1.0 / 35.0)


func _capture(label: String) -> void:
	var state: Dictionary = simulation.snapshot()
	state.session = {"lives": 3, "total_score": 0, "game_over": false}
	state.comparison_fixture = true
	view.present(state, true, false)
	await process_frame
	await RenderingServer.frame_post_draw
	var folder := ProjectSettings.globalize_path("res://.scratch/fidelity-port/captures")
	DirAccess.make_dir_recursive_absolute(folder)
	assert(root.get_texture().get_image().save_png(folder.path_join(label + ".png")) == OK)
	print("CAPTURE: ", label)

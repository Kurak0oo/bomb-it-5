extends SceneTree
## Diagnostic measurements for the desktop feel audit; not an SWF parity test.
const Simulation = preload("res://scripts/simulation/bomb_simulation.gd")

func _initialize() -> void:
	_hazards()
	_weapons()
	quit(0)

func command(id: StringName, direction: Vector2 = Vector2.ZERO, bomb: bool = false) -> Dictionary:
	return {"actor_id": id, "direction": direction, "bomb_events": [&"down"] if bomb else []}

func weapon_command(events: Array = []) -> Dictionary:
	return {"actor_id": &"human", "direction": Vector2.RIGHT, "bomb_events": events}

func _hazards() -> void:
	for wait_ticks in [10, 11]:
		var board: Dictionary = {}
		for y in 7:
			for x in 9: board[Vector2i(x,y)] = &"floor" if x>0 and x<8 and y>0 and y<6 else &"solid"
		var game = Simulation.new([&"owner", &"entrant"], {&"owner": {"cell": Vector2i(2,3), "protected_until":1000}, &"entrant": {"cell":Vector2i(4,3)}}, board, {"movement":true,"damage":true})
		game.advance([command(&"owner",Vector2.ZERO,true),command(&"entrant")])
		for i in 72 + wait_ticks: game.advance([command(&"owner"),command(&"entrant")])
		var state: Dictionary
		for i in 6: state=game.advance([command(&"owner"),command(&"entrant",Vector2.LEFT)])
		print("entry_tick=",state.tick," cell=",state.actors[&"entrant"].cell," alive=",state.actors[&"entrant"].alive," visible_flames=",state.flames.size()," fire_cells=",state.fire.size())
		assert(state.actors[&"entrant"].alive == (wait_ticks==11))
	print("PASS: entry lethal on detonation+16, safe on detonation+17; no extra hazard beyond flame removal")


func _weapons() -> void:
	for kind in [&"hammer", &"flamer", &"laser", &"triple", &"shotgun"]:
		var board: Dictionary = {}
		for y in 7:
			for x in 17: board[Vector2i(x,y)] = &"floor" if x>0 and x<16 and y>0 and y<6 else &"solid"
		var game = Simulation.new([&"human"], {&"human":{"cell":Vector2i(2,3)}}, board, {"movement":true,"drops":true,"pickups":{Vector2i(2,3):kind}})
		game.advance([weapon_command()])
		var started: Dictionary=game.advance([weapon_command([&"down"])])
		var at: Vector2=started.actors[&"human"].position
		var moved_again: int=-1
		for i in 50:
			var state: Dictionary=game.advance([weapon_command([&"up"] if i==0 else [])])
			if state.actors[&"human"].position!=at:
				moved_again=state.tick-started.tick
				break
		print(kind," windup_ticks=",started.attacks[0].ready-started.tick," movement_locked_ticks=",moved_again," lock_seconds=",snappedf(moved_again/35.0,0.001))
		assert(moved_again>0 and moved_again<50)
	print("PASS: public action/input trace reproduces fixed movement lock for each equipped weapon")

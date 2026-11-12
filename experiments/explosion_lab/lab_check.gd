extends SceneTree
## Explosion lab: checks the presentation ordering against the real simulation.
## godot --headless --path . --script res://experiments/explosion_lab/lab_check.gd

const Simulation = preload("res://scripts/simulation/bomb_simulation.gd")
const ChainOrder = preload("res://experiments/explosion_lab/chain_order.gd")

var _checks := 0
var _failures := 0


func _initialize() -> void:
	_a_chain_gets_increasing_depths()
	_segments_mark_tips_and_arms()
	_same_tick_fuses_follow_the_countdown_pass()
	_a_flame_never_crosses_a_bomb_that_still_shows()
	if _failures == 0:
		print("PASS: %d explosion lab checks" % _checks)
	else:
		printerr("FAIL: %d of %d explosion lab checks" % [_failures, _checks])
	quit(0 if _failures == 0 else 1)


func _a_chain_gets_increasing_depths() -> void:
	var run := _run_row([2, 1_000_000, 1_000_000])
	_expect(run.blasts.size(), 3, "one fuse sets off the whole row in a single tick")
	_expect(run.depth_by_cell, {Vector2i(1, 1): 0, Vector2i(3, 1): 1, Vector2i(5, 1): 2},
		"depth counts the links from the bomb whose fuse ran out")


func _segments_mark_tips_and_arms() -> void:
	var run := _run_row([2, 1_000_000, 1_000_000])
	var last: Dictionary = run.blasts.filter(func(blast: Dictionary) -> bool: return blast.cell == Vector2i(5, 1))[0]
	var kinds := {}
	for segment in ChainOrder.segments(last):
		kinds[segment.cell] = segment.kind
	_expect(kinds, {Vector2i(5, 1): ChainOrder.KIND_CENTER, Vector2i(4, 1): ChainOrder.KIND_TIP,
		Vector2i(6, 1): ChainOrder.KIND_ARM, Vector2i(7, 1): ChainOrder.KIND_TIP},
		"a ray stopped by a bomb ends in a tip; a full-power ray has arm then tip")
	_expect(ChainOrder.reach(last), 2, "reach is the longest ray")


func _same_tick_fuses_follow_the_countdown_pass() -> void:
	var run := _run_row([2, 2, 1_000_000])
	_expect(run.depth_by_cell[Vector2i(3, 1)], 1,
		"a bomb due this tick but reached first is chained, as in the countdown pass")
	# In the simulation two bombs due on one tick split over two ticks (`_detonate` erases
	# from `_countdowns` mid-pass), so roots sharing a batch are checked on plain data.
	var blasts := [{"cell": Vector2i(1, 1), "cells": [Vector2i(1, 1), Vector2i(2, 1)]},
		{"cell": Vector2i(5, 1), "cells": [Vector2i(5, 1), Vector2i(4, 1), Vector2i(6, 1)]}]
	_expect(ChainOrder.depths(blasts, [true, true]), [0, 0] as Array[int],
		"roots that do not touch both stay at depth 0")


func _a_flame_never_crosses_a_bomb_that_still_shows() -> void:
	# Plain data: the root's ray runs through the cell of a bomb that a longer branch of
	# the chain (root -> link -> passed) had already set off in the simulation.
	var blasts := [
		{"cell": Vector2i(1, 1), "cells": [Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(1, 2)]},
		{"cell": Vector2i(1, 3), "cells": [Vector2i(1, 3), Vector2i(2, 3)]},
		{"cell": Vector2i(3, 1), "cells": [Vector2i(3, 1)]},
		{"cell": Vector2i(3, 3), "cells": [Vector2i(3, 3), Vector2i(3, 2)]}]
	var starts := ChainOrder.starts(blasts, [true, false, false, false], 0.07, 0.022)
	_expect(snappedf(starts[1], 0.001), 0.07, "a bomb that stopped a ray goes off one chain step later")
	_expect(snappedf(starts[2], 0.001), 0.044, "a bomb under a passing flame goes off when that flame arrives")
	_expect(snappedf(starts[3], 0.001), 0.14, "the rest of the chain keeps its chain steps")
	# In the real simulation, in the dense cluster: no flame cell may show before the
	# blast of a bomb that sat on that cell.
	var run := _run_cluster()
	var early := 0
	for parent in run.blasts.size():
		for child in run.blasts.size():
			var offset: Vector2i = run.blasts[child].cell - run.blasts[parent].cell
			if child != parent and run.blasts[parent].cells.has(run.blasts[child].cell):
				var arrives: float = run.starts[parent] + (absi(offset.x) + absi(offset.y)) * 0.022
				if arrives < run.starts[child] - 0.0001:
					early += 1
	_expect(run.blasts.size(), 25, "the cluster goes off in one tick")
	_expect(early, 0, "no flame reaches a cluster bomb before that bomb's own blast shows")


func _run_cluster() -> Dictionary:
	var board := {}
	for y in 9:
		for x in 9:
			board[Vector2i(x, y)] = &"solid" if x == 0 or y == 0 or x == 8 or y == 8 else &"floor"
	var ids: Array[StringName] = [&"human"]
	var simulation := Simulation.new(ids, {&"human": {"cell": Vector2i(1, 1)}}, board, {"seed": 5})
	var bombs: Array[Dictionary] = []
	for y in range(2, 7):
		for x in range(2, 7):
			var bomb := {"actor_id": &"lab", "cell": Vector2i(x, y), "power": 3, "fuse": 2 if Vector2i(x, y) == Vector2i(4, 4) else 1_000_000}
			simulation.add_bomb(bomb)
			bombs.append(bomb)
	var commands: Array[Dictionary] = [{"actor_id": &"human", "direction": Vector2.ZERO, "bomb_events": []}]
	for tick in 10:
		var result: Dictionary = simulation.advance(commands)
		if result.blasts.is_empty():
			continue
		var roots: Array = []
		for blast in result.blasts:
			var bomb: Dictionary = bombs.filter(func(b: Dictionary) -> bool: return b.cell == blast.cell)[0]
			roots.append(bomb.age >= bomb.fuse)
		return {"blasts": result.blasts, "starts": ChainOrder.starts(result.blasts, roots, 0.07, 0.022)}
	return {"blasts": [], "starts": []}


func _run_row(fuses: Array) -> Dictionary:
	var board := {}
	var rows := ["#########", "#.......#", "#########"]
	for y in rows.size():
		for x in rows[y].length():
			board[Vector2i(x, y)] = &"solid" if rows[y][x] == "#" else &"floor"
	var ids: Array[StringName] = [&"human"]
	var simulation := Simulation.new(ids, {&"human": {"cell": Vector2i(7, 1)}}, board, {"seed": 5})
	var bombs: Array[Dictionary] = []
	for index in fuses.size():
		var bomb := {"actor_id": &"lab", "cell": Vector2i(1 + index * 2, 1), "power": 2, "fuse": fuses[index]}
		simulation.add_bomb(bomb)
		bombs.append(bomb)
	var commands: Array[Dictionary] = [{"actor_id": &"human", "direction": Vector2.ZERO, "bomb_events": []}]
	for tick in 10:
		var result: Dictionary = simulation.advance(commands)
		if result.blasts.is_empty():
			continue
		var roots: Array = []
		for blast in result.blasts:
			var bomb: Dictionary = bombs.filter(func(b: Dictionary) -> bool: return b.cell == blast.cell)[0]
			roots.append(bomb.age >= bomb.fuse)
		var depths := ChainOrder.depths(result.blasts, roots)
		var depth_by_cell := {}
		for index in result.blasts.size():
			depth_by_cell[result.blasts[index].cell] = depths[index]
		return {"blasts": result.blasts, "depth_by_cell": depth_by_cell}
	return {"blasts": [], "depth_by_cell": {}}


func _expect(actual: Variant, expected: Variant, description: String) -> void:
	_checks += 1
	if actual != expected:
		_failures += 1
		printerr("FAIL: %s\n  expected: %s\n  actual: %s" % [description, expected, actual])

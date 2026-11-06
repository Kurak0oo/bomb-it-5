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

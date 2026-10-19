extends RefCounted
## Headless ordinary bombs; see DESIGN.md and docs/evidence/edition-5-gameplay-phases.md.

const CommandModule = preload("res://scripts/simulation/command_boundary.gd")
const FUSE_TICKS: int = 72

var _commands: CommandModule
var _actor_ids: Array[StringName]
var _actors: Dictionary
var _board: Dictionary
var _bombs: Array[Dictionary] = []


func _init(actor_ids: Array[StringName], actors: Dictionary, board: Dictionary) -> void:
	_actor_ids = actor_ids.duplicate()
	_actors = actors.duplicate(true)
	_board = board.duplicate(true)
	_commands = CommandModule.new(_actor_ids)


func advance(commands: Array[Dictionary]) -> Dictionary:
	var result: Dictionary = _commands.advance(commands)
	var blasts: Array[Dictionary] = []
	var broken_soft_blocks: Array[Vector2i] = []
	if result.accepted:
		var by_actor: Dictionary = {}
		for command in commands:
			by_actor[command.actor_id] = command
		for actor_id in _actor_ids:
			var command: Dictionary = by_actor[actor_id]
			for event in command.bomb_events:
				if event == &"down":
					var actor: Dictionary = _actors[command.actor_id]
					if _board.get(actor.cell) != &"floor":
						continue
					var owned_bombs: int = _bombs.filter(
						func(bomb: Dictionary): return bomb.actor_id == command.actor_id).size()
					if owned_bombs >= actor.get("capacity", 1):
						continue
					if _bombs.any(func(bomb: Dictionary): return bomb.cell == actor.cell):
						continue
					_bombs.append({"actor_id": command.actor_id, "cell": actor.cell,
						"power": actor.get("power", 1), "detonation_tick": result.tick + FUSE_TICKS})
		for bomb in _bombs.duplicate():
			if _bombs.has(bomb) and result.tick >= bomb.detonation_tick:
				_detonate(bomb, blasts, broken_soft_blocks)
	result.board = _board.duplicate(true)
	result.bombs = _bombs.map(func(bomb: Dictionary): return {
		"actor_id": bomb.actor_id, "cell": bomb.cell, "power": bomb.power})
	result.blasts = blasts
	result.broken_soft_blocks = broken_soft_blocks
	return result


func _detonate(bomb: Dictionary, blasts: Array[Dictionary], broken: Array[Vector2i]) -> void:
	# Removal before tracing also prevents a chain from detonating its parent again.
	_bombs.erase(bomb)
	var cells: Array[Vector2i] = [bomb.cell]
	for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		for distance in range(1, bomb.power + 1):
			var cell: Vector2i = bomb.cell + direction * distance
			var tile: Variant = _board.get(cell)
			if tile not in [&"floor", &"soft"]:
				break
			cells.append(cell)
			var hit_bombs: Array[Dictionary] = _bombs.filter(
				func(other: Dictionary): return other.cell == cell)
			if not hit_bombs.is_empty():
				_detonate(hit_bombs[0], blasts, broken)
				break
			if tile == &"soft":
				_board[cell] = &"floor"
				broken.append(cell)
				break
	blasts.append({"actor_id": bomb.actor_id, "cell": bomb.cell, "cells": cells})

extends RefCounted
## Mode registry: Game Settings names to mode modules. New modes register here.

const ArcadeMode = preload("res://scripts/simulation/modes/arcade_mode.gd")
const TITLES := {&"arcade": "ARCADE"}
const GOALS := {&"arcade": "Place your bombs tactically to kill all enemies!"}


static func available() -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(TITLES.keys())
	return result


static func create(mode: StringName, difficulty: StringName, stage_set: StringName) -> RefCounted:
	match mode:
		_: return ArcadeMode.new(difficulty, stage_set)

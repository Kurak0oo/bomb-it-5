extends RefCounted
## Mode registry: Game Settings names to mode modules. New modes register here.

const ArcadeMode = preload("res://scripts/simulation/modes/arcade_mode.gd")
const KillMode = preload("res://scripts/simulation/modes/kill_mode.gd")
const TITLES := {&"arcade": "ARCADE", &"kill": "BATTLE ROYALE"}
const GOALS := {&"arcade": "Place your bombs tactically to kill all enemies!", &"kill": "Be the 1st to kill 10 enemies!"}


static func available() -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(TITLES.keys())
	return result


static func create(mode: StringName, difficulty: StringName, stage_set: StringName) -> RefCounted:
	match mode:
		&"kill": return KillMode.new(difficulty, stage_set)
		_: return ArcadeMode.new(difficulty, stage_set)

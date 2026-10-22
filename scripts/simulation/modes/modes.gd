extends RefCounted
## Mode registry: Game Settings names to mode modules. New modes register here.

const ArcadeMode = preload("res://scripts/simulation/modes/arcade_mode.gd")
const KillMode = preload("res://scripts/simulation/modes/kill_mode.gd")
const GreenZoneMode = preload("res://scripts/simulation/modes/green_zone_mode.gd")
const PacManMode = preload("res://scripts/simulation/modes/pac_man_mode.gd")
const TITLES := {&"arcade": "ARCADE", &"kill": "BATTLE ROYALE", &"pac_man": "PAC-MAN", &"green_zone": "GREEN ZONE"}
const GOALS := {&"arcade": "Place your bombs tactically to kill all enemies!", &"kill": "Be the 1st to kill 10 enemies!",
	&"green_zone": "Stay at the green zone for enough time to occupy it!",
	&"pac_man": "Avoid the enemies and collect all of the coins!"}


static func available() -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(TITLES.keys())
	return result


static func create(mode: StringName, difficulty: StringName, stage_set: StringName) -> RefCounted:
	match mode:
		&"kill": return KillMode.new(difficulty, stage_set)
		&"green_zone": return GreenZoneMode.new(difficulty, stage_set)
		&"pac_man": return PacManMode.new(difficulty, stage_set)
		_: return ArcadeMode.new(difficulty, stage_set)

extends "res://scripts/simulation/modes/game_mode.gd"
## ArcadeMode: eliminate every AI; see runtime systems and modes-and-flow evidence.

const DIFF_POINT := {&"easy": 1000, &"normal": 2000, &"hard": 3000}


func _init(difficulty_name: StringName = &"normal", stage: StringName = &"cinema") -> void:
	name = &"arcade"
	difficulty = difficulty_name
	stage_set = stage


func soft_chance() -> float:
	return 0.6


func timed_pickup_count(tick: int) -> int:
	# ArcadeMode.timePassed uses >45, so the first timed spawn is at 60 seconds.
	if tick > 45 * 35 and tick % (15 * 35) == 0:
		return 1 if stage_set in [&"candy_factory", &"magic_library"] else 2
	return 0


func judge(round_state: RefCounted, judgment_ready: bool, tick: int) -> StringName:
	var human: Dictionary = round_state.human()
	var enemy_alive: bool = round_state.enemies().any(func(actor: Dictionary): return actor.alive)
	# ArcadeMode.end checks surviving humans before checking surviving AI.
	if judgment_ready and not human.alive:
		return &"lost"
	if judgment_ready and not enemy_alive:
		return &"won"
	if tick >= round_ticks():
		# Accepted adaptation: timeout with enemies remaining is a loss (DESIGN.md).
		return &"lost" if not human.alive else &"won" if not enemy_alive else &"timeout"
	return &""


func settle(round_state: RefCounted, outcome: StringName, gameplay_end_tick: int) -> int:
	var human: Dictionary = round_state.human()
	var score: int = human.kills * 300
	if outcome == &"won":
		score += DIFF_POINT.get(difficulty, 2000) + remaining_seconds(gameplay_end_tick) * 10
	else:
		human.lives = maxi(0, human.lives - 1)
	return score

extends "res://scripts/simulation/modes/game_mode.gd"
## KillMode ("Battle Royale"): first to 10 kills, unlimited hammer, 1 s respawn.
## See edition-5-kill-mode.md and modes-and-flow evidence.

const DIFF_POINT := {&"easy": 1000, &"normal": 2000, &"hard": 3000}
const WIN_KILLS := 10
## Rules XML `KillMode/prop`, keyed like Pickups.WEIGHTS (round(value * 100)).
const WEIGHTS := {&"capacity": 0, &"power": 0, &"speed": 15, &"life": 5, &"shield": 0,
	&"reserved_kick": 0, &"invincible": 5, &"reserved_boxing": 15, &"landmine": 10,
	&"flamer": 15, &"laser": 10, &"hammer": 0, &"triple": 10, &"shotgun": 15, &"vehicle": 5}


func _init(difficulty_name: StringName = &"normal", stage: StringName = &"cinema") -> void:
	name = &"kill"
	difficulty = difficulty_name
	stage_set = stage


func drop_weights() -> Dictionary:
	return WEIGHTS


func soft_chance() -> float:
	return 0.55


func timed_pickup_count(tick: int) -> int:
	if tick > 45 * 35 and tick % (15 * 35) == 0:
		return 1 if stage_set == &"candy_factory" else 0 if stage_set == &"magic_library" else 2
	return 0


func respawn_ticks(_is_human: bool) -> int:
	return 35


func base_weapon(_is_human: bool) -> StringName:
	return &"hammer"


func keeps_weapon_pickups() -> bool:
	return true


## killSelfHandler: an own-attack death costs a point if there is one.
func on_self_kill(actor: Dictionary) -> void:
	actor.kills = maxi(0, actor.kills - 1)


## KillMode.end judges after a death movie, players in order: a human at 10 wins first.
## Timeout (judgeHandler): the human wins unless some AI has more kills; ties go to the human.
func judge(round_state: RefCounted, judgment_ready: bool, tick: int) -> StringName:
	var human: Dictionary = round_state.human()
	if judgment_ready:
		if human.kills >= WIN_KILLS: return &"won"
		if round_state.enemies().any(func(actor: Dictionary): return actor.kills >= WIN_KILLS): return &"lost"
	if tick >= round_ticks():
		return &"lost" if round_state.enemies().any(func(actor: Dictionary): return actor.kills > human.kills) else &"won"
	return &""


func settle(round_state: RefCounted, outcome: StringName, gameplay_end_tick: int) -> int:
	var human: Dictionary = round_state.human()
	breakdown = {"kills": human.kills * 100, "time": 0, "difficulty": 0}
	if outcome == &"won":
		breakdown.time = remaining_seconds(gameplay_end_tick) * 10
		breakdown.difficulty = DIFF_POINT.get(difficulty, 2000)
	else:
		human.lives = maxi(0, human.lives - 1)
	return breakdown.kills + breakdown.time + breakdown.difficulty


func points(actor: Dictionary) -> int:
	return actor.kills

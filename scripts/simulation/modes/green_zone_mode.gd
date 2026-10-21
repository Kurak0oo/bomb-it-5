extends "res://scripts/simulation/modes/game_mode.gd"
## GreenZoneMode: capture the flag 10 times (`GreenZoneMode.as`, `maps/platform/Flag.as`).
## See edition-5-green-zone.md.

const DIFF_POINT := {&"easy": 1000, &"normal": 2000, &"hard": 3000}
const WIN_FLAGS := 10
## Rules XML `flag` (3 on every difficulty) × 35 frames.
const CAPTURE_TICKS := 105
## Flag.complete → TweenMax.delayedCall(3, move): host seconds as simulation ticks.
const MOVE_TICKS := 105
const WEIGHTS := {&"capacity": 0, &"power": 0, &"speed": 15, &"life": 5, &"shield": 0,
	&"reserved_kick": 0, &"invincible": 5, &"reserved_boxing": 15, &"landmine": 10,
	&"flamer": 15, &"laser": 10, &"hammer": 0, &"triple": 10, &"shotgun": 10, &"vehicle": 5}

var flag: Variant = null
## Actor id → hold progress 0..CAPTURE_TICKS (HoldStatus.totalTime).
var progress := {}
var moving_until := -1
var _pending_judgment := false


func _init(difficulty_name: StringName = &"normal", stage: StringName = &"cinema") -> void:
	name = &"green_zone"
	difficulty = difficulty_name
	stage_set = stage


func drop_weights() -> Dictionary:
	return WEIGHTS


func timed_pickup_count(tick: int) -> int:
	if tick > 10 * 35 and tick % (15 * 35) == 0:
		return 1 if stage_set == &"candy_factory" else 0 if stage_set == &"magic_library" else 2
	return 0


func player_speed() -> float:
	return 1.8


func respawn_ticks(_is_human: bool) -> int:
	return 35


func base_weapon(_is_human: bool) -> StringName:
	return &"hammer"


func keeps_weapon_pickups() -> bool:
	return true


## mapLoadOver: a flag away from the edges, then two random pickups.
func begin(round_state: RefCounted) -> void:
	for id in round_state.actors(): round_state.actors()[id].flags = round_state.actors()[id].get("flags", 0)
	_place(round_state)
	round_state.spawn_random_pickups(2)


## Flag.runEngine: robots on the flag gain 1 per tick, the rest lose 1; a full bar scores
## and the flag moves after its delay, when the mode judges (Flag.move → judge).
func tick(round_state: RefCounted, tick_now: int) -> void:
	if moving_until >= 0:
		if tick_now >= moving_until:
			moving_until = -1
			_place(round_state)
			_pending_judgment = true
		return
	if flag == null: return
	var holders := {}
	for id in round_state.actors():
		var actor: Dictionary = round_state.actors()[id]
		if actor.alive and actor.cell == flag: holders[id] = true
	for id in holders:
		if not progress.has(id): progress[id] = 0
	for id in progress.keys():
		progress[id] += 1 if holders.has(id) else -1
		if progress[id] >= CAPTURE_TICKS:
			round_state.actors()[id].flags = round_state.actors()[id].get("flags", 0) + 1
			progress.clear()
			flag = null
			moving_until = tick_now + MOVE_TICKS
			return
		if progress[id] < 0: progress.erase(id)


func judge(round_state: RefCounted, _judgment_ready: bool, tick: int) -> StringName:
	if _pending_judgment:
		_pending_judgment = false
		if round_state.human().get("flags", 0) >= WIN_FLAGS: return &"won"
		if round_state.enemies().any(func(actor: Dictionary): return actor.get("flags", 0) >= WIN_FLAGS): return &"lost"
	if tick >= round_ticks():
		var human_flags: int = round_state.human().get("flags", 0)
		return &"lost" if round_state.enemies().any(func(actor: Dictionary): return actor.get("flags", 0) > human_flags) else &"won"
	return &""


func settle(round_state: RefCounted, outcome: StringName, gameplay_end_tick: int) -> int:
	var human: Dictionary = round_state.human()
	breakdown = {"kills": human.get("flags", 0) * 100, "time": 0, "difficulty": 0}
	if outcome == &"won":
		breakdown.time = remaining_seconds(gameplay_end_tick) * 10
		breakdown.difficulty = DIFF_POINT.get(difficulty, 2000)
	else:
		human.lives = maxi(0, human.lives - 1)
	return breakdown.kills + breakdown.time + breakdown.difficulty


func points(actor: Dictionary) -> int:
	return actor.get("flags", 0)


func public_state() -> Dictionary:
	return {"flag": flag, "progress": progress.duplicate(), "capture_ticks": CAPTURE_TICKS}


## containerMove(map, 2, 2, 2, 2): an empty cell, so not a portal or other platform.
func _place(round_state: RefCounted) -> void:
	var free: Array[Vector2i] = round_state.free_cells(2).filter(func(cell): return round_state.board().get(cell) == &"floor")
	flag = free[int(round_state.draw_random() * free.size())] if not free.is_empty() else null

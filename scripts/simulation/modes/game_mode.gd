extends RefCounted
## Mode rules on the shared round (ADR 0007). Subclasses override only what differs.

const Pickups = preload("res://scripts/simulation/pickups.gd")
const ROUND_TICKS := 6300

var name: StringName = &"mode"
var difficulty: StringName = &"normal"
var stage_set: StringName = &"cinema"
## Level-score parts of the last settlement, for the score screen (`countScore`).
var breakdown := {}


func drop_weights() -> Dictionary:
	return Pickups.WEIGHTS


## Rules XML `box`: chance that a soft-block candidate holds a block.
func soft_chance() -> float:
	return 0.0


## Pickups to place at random free cells on this tick (mode `timePassed`).
func timed_pickup_count(_tick: int) -> int:
	return 0


func round_ticks() -> int:
	return ROUND_TICKS


## Simulation ticks before a dead actor returns to its spawn; -1 means no respawn.
func respawn_ticks(_is_human: bool) -> int:
	return -1


## Action that replaces bomb placement for the whole round (KillModeWeapon, PacModeWeapon).
func base_weapon(_is_human: bool) -> StringName:
	return &""


func can_collect(_is_human: bool, _kind: StringName) -> bool:
	return true


## Called once per admitted tick while playing; returns a pending outcome or &"".
func judge(_round: RefCounted, _judgment_ready: bool, _tick: int) -> StringName:
	return &""


## Level score settled after the ending cartoon; also spends a retry heart on loss.
func settle(_round: RefCounted, _outcome: StringName, _gameplay_end_tick: int) -> int:
	return 0


func remaining_seconds(gameplay_end_tick: int) -> int:
	return ceili(maxi(0, round_ticks() - gameplay_end_tick) / 35.0)

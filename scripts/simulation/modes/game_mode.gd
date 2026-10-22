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


## Rules XML `propProp`: chance a broken soft block drops a pickup (`MapMaster`).
func drop_chance() -> float:
	return {&"easy": 0.6, &"normal": 0.5, &"hard": 0.4}.get(difficulty, 0.5)


## Pickups placed when the map loads (`mapLoadOver`), keyed by cell.
func opening_pickups(_human_spawn: Vector2i) -> Dictionary:
	return {}


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


## Invincibility pickup length (29-tick introduction excluded): 351 ticks, 175 in Pac-Man.
func invincibility_ticks() -> int:
	return 351


## Whether ordinary bombs, blasts and mines hurt this robot.
func bomb_hits(_is_human: bool) -> bool:
	return true


## Whether attacks and blasts destroy pickups they reach (`AbstractBomb.destroyProp`).
func destroys_pickups() -> bool:
	return true


## A pickup left the board, eaten (`by` is the actor) or destroyed (`by` empty).
func pickup_removed(_round: RefCounted, _kind: StringName, _by: StringName) -> void:
	pass


## Weapons picked up are kept for the death scatter (`AbstractWeapon.addWeaponProp`).
func keeps_weapon_pickups() -> bool:
	return false


## A robot killed by its own attack (`AbstractPlayer.killSelfHandler`).
func on_self_kill(_actor: Dictionary) -> void:
	pass


## Called once per admitted tick while playing; returns a pending outcome or &"".
func judge(_round: RefCounted, _judgment_ready: bool, _tick: int) -> StringName:
	return &""


## Level score settled after the ending cartoon; also spends a retry heart on loss.
func settle(_round: RefCounted, _outcome: StringName, _gameplay_end_tick: int) -> int:
	return 0


## Rules XML `player/<difficulty>/<mode>/model@moveSpeed` for humans.
func player_speed() -> float:
	return 1.6


## Map load (`mapLoadOver`), after the board and actors exist.
func begin(_round: RefCounted) -> void:
	pass


## Once per admitted tick while playing, after movement, pickups and deaths.
func tick(_round: RefCounted, _tick: int) -> void:
	pass


## Mode objects the view draws (flags, coins, progress); copied into snapshots.
func public_state() -> Dictionary:
	return {}


func points_goal() -> int:
	return 10


## The HUD's per-player mode score (`scoreData`); -1 shows the ordinary score.
func points(_actor: Dictionary) -> int:
	return -1


func remaining_seconds(gameplay_end_tick: int) -> int:
	return ceili(maxi(0, round_ticks() - gameplay_end_tick) / 35.0)

extends "res://scripts/simulation/modes/game_mode.gd"
## PacManMode: eat every coin while flamer ghosts chase you (`PacManMode.as`, `CoinProp`).
## See edition-5-pac-man.md.

const DIFF_POINT := {&"easy": 1000, &"normal": 2000, &"hard": 3000}
## Rules XML `PacManMode/prop`, keyed like Pickups.WEIGHTS.
const WEIGHTS := {&"capacity": 0, &"power": 0, &"speed": 40, &"life": 5, &"shield": 25,
	&"reserved_kick": 0, &"invincible": 30, &"reserved_boxing": 0, &"landmine": 0,
	&"flamer": 0, &"laser": 0, &"hammer": 0, &"triple": 0, &"shotgun": 0, &"vehicle": 0}
const ITEM_COUNT := 4

var coins_total := 0
var eaten := 0


func _init(difficulty_name: StringName = &"normal", stage: StringName = &"cinema") -> void:
	name = &"pac_man"
	difficulty = difficulty_name
	stage_set = stage


func drop_weights() -> Dictionary:
	return WEIGHTS


func timed_pickup_count(tick: int) -> int:
	if stage_set != &"magic_library" and tick > 10 * 35 and tick % (15 * 35) == 0:
		return 2
	return 0


## Human death loses the round (`PacManMode.end`); ghosts return after 1 s.
func respawn_ticks(is_human: bool) -> int:
	return -1 if is_human else 35


## PersonPlayer: NullWeapon (no action); AIPlayer: PacModeWeapon (unlimited flamer).
func base_weapon(is_human: bool) -> StringName:
	return &"none" if is_human else &"flamer"


## Empty `propsEated.ai`: ghosts eat nothing.
func can_collect(is_human: bool, _kind: StringName) -> bool:
	return is_human


func invincibility_ticks() -> int:
	return 5 * 35


func opening_pickups(human_spawn: Vector2i) -> Dictionary:
	return {human_spawn: &"shield"} if difficulty == &"easy" else {}


## Bombs and blasts skip ghosts (`AbstractBomb.hitRobotUnderPoint`).
func bomb_hits(is_human: bool) -> bool:
	return is_human


## PacModeWeapon clears `destroyProp`: ghost flames leave coins and items alone.
func destroys_pickups() -> bool:
	return false


## mapLoadOver: four pickups in separate quadrants, then a coin on every other empty
## cell; the player's spawn holds its NullWeapon and gets none.
func begin(round_state: RefCounted) -> void:
	var human_spawn: Vector2i = round_state.human().spawn
	var empty: Array[Vector2i] = []
	# getAllEmptyPosition ignores robots: ghost spawns get coins too.
	for cell in round_state.board():
		if round_state.board()[cell] == &"floor" and cell != human_spawn and not round_state.pickups().has(cell): empty.append(cell)
	empty.sort()
	var quadrants: Array = [[], [], [], []]
	for cell in empty:
		quadrants[(0 if cell.y < 7 else 3) if cell.x < 8 else (1 if cell.y < 7 else 2)].append(cell)
	var chosen: Array[Vector2i] = []
	while chosen.size() < ITEM_COUNT and not quadrants.is_empty():
		var quadrant: Array = []
		while not quadrants.is_empty():
			quadrant = quadrants.pop_at(int(round_state.draw_random() * quadrants.size()))
			if not quadrant.is_empty(): break
		while not quadrant.is_empty():
			var cell: Vector2i = quadrant.pop_at(int(round_state.draw_random() * quadrant.size()))
			if not chosen.any(func(other: Vector2i): return absi(other.x - cell.x) <= 1 and absi(other.y - cell.y) <= 1):
				chosen.append(cell)
				break
	for cell in chosen: round_state.place_drawn_pickup(cell)
	for cell in empty:
		if cell not in chosen and not round_state.pickups().has(cell):
			round_state.pickups()[cell] = &"coin"
			coins_total += 1


## Eating a coin counts (`CoinProp.eatProp`); `deleProp` would too, but nothing in
## Pac-Man destroys coins.
func pickup_removed(round_state: RefCounted, kind: StringName, _by: StringName) -> void:
	if kind != &"coin": return
	eaten += 1
	round_state.human().coins = eaten


func judge(round_state: RefCounted, judgment_ready: bool, tick: int) -> StringName:
	var human: Dictionary = round_state.human()
	if coins_total > 0 and eaten >= coins_total: return &"won"
	if judgment_ready and not human.alive: return &"lost"
	if tick >= round_ticks(): return &"lost"
	return &""


func settle(round_state: RefCounted, outcome: StringName, gameplay_end_tick: int) -> int:
	var human: Dictionary = round_state.human()
	breakdown = {"kills": eaten * 10, "time": 0, "difficulty": 0}
	if outcome == &"won":
		breakdown.time = remaining_seconds(gameplay_end_tick) * 10
		breakdown.difficulty = DIFF_POINT.get(difficulty, 2000)
	else:
		human.lives = maxi(0, human.lives - 1)
	return breakdown.kills + breakdown.time + breakdown.difficulty


func points(actor: Dictionary) -> int:
	return eaten if actor.get("is_human", false) else -1


func points_goal() -> int:
	return coins_total


func public_state() -> Dictionary:
	return {"coins_total": coins_total, "eaten": eaten}

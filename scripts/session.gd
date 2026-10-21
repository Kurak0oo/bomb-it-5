extends RefCounted
## One player's run of levels: settings, robot choice, lives, totals and stage rotation
## (`UIManager.gamePlay/gameReStart`, `AbstractGameMode.winHandler/loseHandler`).

const StageSets = preload("res://scripts/simulation/stage_sets.gd")
const LEVEL_CHOICES: Array[int] = [5, 10, 15, 20]
const ROBOTS: Array[StringName] = [&"human", &"ruby", &"lime", &"gold", &"violet", &"slate", &"mint", &"snow"]
const ROBOT_TITLES: Array[String] = ["Blue", "Ruby", "Lime", "Gold", "Violet", "Slate", "Mint", "Snow"]
const START_LIVES := 3

enum Result { LEVEL_WIN, LEVEL_RESTART, GAME_WIN, GAME_OVER }

var mode: StringName = &"arcade"
var enemies := 3
var levels := 5
## &"random" or a stage-set id.
var stage: StringName = &"random"
var difficulty: StringName = &"normal"
var robot := 0
var hat := 0
var body := 0

var level := 1
var lives := START_LIVES
var total_score := 0
var current_set: StringName = &""
var ai_robots: Array[int] = []
var last_result: Result = Result.LEVEL_RESTART
var _rotation: Array[StringName] = []
var _rng := RandomNumberGenerator.new()


func _init(seed_value: int = -1) -> void:
	if seed_value >= 0: _rng.seed = seed_value
	else: _rng.randomize()


## START on character select: fresh lives, totals and AI robots, first stage set.
func begin() -> void:
	level = 1
	lives = START_LIVES
	total_score = 0
	var others: Array[int] = []
	for index in ROBOTS.size():
		if index != robot: others.append(index)
	ai_robots.clear()
	for seat in 3:
		ai_robots.append(others.pop_at(_rng.randi_range(0, others.size() - 1)))
	_rotation = StageSets.available_sets()
	current_set = stage if stage != &"random" else _draw_set()


## Records a settled level; `lives_after` is the human's retry hearts after settlement.
func settle(outcome: StringName, level_score: int, lives_after: int) -> Result:
	total_score += level_score
	lives = lives_after
	if outcome == &"won":
		last_result = Result.LEVEL_WIN if level < levels else Result.GAME_WIN
	else:
		last_result = Result.LEVEL_RESTART if lives > 0 else Result.GAME_OVER
	return last_result


## NEXT after a level win draws a new set; TRY AGAIN keeps the set for a fresh layout.
func advance() -> void:
	if last_result == Result.LEVEL_WIN:
		level += 1
		if stage == &"random": current_set = _draw_set()


func finished() -> bool:
	return last_result in [Result.GAME_WIN, Result.GAME_OVER]


func level_text() -> String:
	return "%d / %d" % [level, levels]


func next_seed() -> int:
	return _rng.randi()


## Random arena: draw without repeats, refilling once every available set was used.
func _draw_set() -> StringName:
	if _rotation.is_empty(): _rotation = StageSets.available_sets()
	var chosen: StringName = _rotation.pop_at(_rng.randi_range(0, _rotation.size() - 1))
	if _rotation.is_empty(): _rotation = StageSets.available_sets()
	return chosen

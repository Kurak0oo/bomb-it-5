extends SceneTree
## Session rules: levels, lives, totals, stage rotation and AI robots (#59).

const Session = preload("res://scripts/session.gd")
const StageSets = preload("res://scripts/simulation/stage_sets.gd")
var failures := 0
var checks := 0


func _initialize() -> void:
	var session := Session.new(5)
	_expect(session.levels == 5 and session.enemies == 3 and session.stage == &"random", "defaults: 5 levels, 3 enemies, random arena")
	_expect(session.difficulty == &"easy", "original: a session starts on Easy (GameModel.init)")
	session.robot = 4
	session.begin()
	_expect(session.ai_robots.size() == 3 and 4 not in session.ai_robots, "AI robots exclude the player's robot")
	_expect(session.ai_robots[0] != session.ai_robots[1] and session.ai_robots[1] != session.ai_robots[2] and session.ai_robots[0] != session.ai_robots[2],
		"AI robots are distinct")
	_expect(session.current_set in StageSets.available_sets(), "the first level draws an available set")

	var visited: Array[StringName] = [session.current_set]
	for level in 3:
		_expect(session.settle(&"won", 1000, 3) == Session.Result.LEVEL_WIN, "a won level before the last advances")
		session.advance()
		visited.append(session.current_set)
	_expect(visited[0] != visited[1], "random arenas do not repeat until every set was used")
	_expect(session.level == 4 and session.total_score == 3000, "levels and totals accumulate")

	var same_set := session.current_set
	_expect(session.settle(&"lost", 300, 2) == Session.Result.LEVEL_RESTART and session.lives == 2, "a loss with lives left restarts the level")
	session.advance()
	_expect(session.level == 4 and session.current_set == same_set, "a restart keeps the level and its stage set")
	_expect(session.settle(&"won", 0, 2) == Session.Result.LEVEL_WIN, "level 4 of 5 wins onward")
	session.advance()
	_expect(session.settle(&"won", 500, 2) == Session.Result.GAME_WIN and session.finished(), "winning the last level completes the game")

	session = Session.new(1)
	session.stage = &"luxury_stores"
	session.levels = 10
	session.begin()
	for level in 3:
		session.settle(&"won", 0, 3)
		session.advance()
		_expect(session.current_set == &"luxury_stores", "a chosen arena repeats every level")
	_expect(session.settle(&"lost", 0, 0) == Session.Result.GAME_OVER and session.finished(), "losing the last heart ends the game")
	session.begin()
	_expect(session.level == 1 and session.lives == 3 and session.total_score == 0, "a new start clears lives and totals")
	_expect(Session.LEVEL_CHOICES == [5, 10, 15, 20], "levels are offered as labelled (5-sets-1 defect fixed)")
	_finish()


func _expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr(label)


func _finish() -> void:
	print("%s: %d session checks" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)

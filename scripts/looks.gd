extends RefCounted
## Unlockable looks per robot (unlock XML `sets`, `GameConfig.UNLOCK_SCORE_n`, `ClothesPanel`).
## Look n (1-8) of robot r is LOOKS[r][n - 1]: a hat or body number. Hat/body 0 means none.

## Session total needed for look n, checked on every score screen.
const THRESHOLDS: Array[int] = [2500, 7200, 12000, 19200, 24000, 31200, 36000, 48000]
const LOOKS := [
	[[&"hat", 1], [&"hat", 2], [&"hat", 3], [&"body", 1], [&"body", 2], [&"body", 3], [&"body", 4], [&"body", 5]],
	[[&"hat", 1], [&"hat", 2], [&"hat", 3], [&"body", 1], [&"body", 2], [&"body", 3], [&"body", 4], [&"body", 5]],
	[[&"hat", 1], [&"hat", 2], [&"hat", 3], [&"body", 1], [&"body", 2], [&"body", 3], [&"body", 4], [&"body", 5]],
	[[&"hat", 1], [&"hat", 2], [&"hat", 3], [&"hat", 4], [&"body", 1], [&"body", 2], [&"body", 3], [&"body", 4]],
	[[&"hat", 1], [&"hat", 2], [&"body", 1], [&"body", 2], [&"body", 3], [&"body", 4], [&"body", 5], [&"body", 6]],
	[[&"hat", 1], [&"hat", 2], [&"hat", 3], [&"body", 1], [&"body", 2], [&"body", 3], [&"body", 4], [&"body", 5]],
	[[&"hat", 1], [&"hat", 2], [&"hat", 3], [&"body", 1], [&"body", 2], [&"body", 3], [&"body", 4], [&"body", 5]],
	[[&"hat", 1], [&"hat", 2], [&"hat", 3], [&"hat", 4], [&"body", 1], [&"body", 2], [&"body", 3], [&"body", 4]],
]


static func look(robot: int, number: int) -> Array:
	return LOOKS[robot][number - 1]


static func count(robot: int, kind: StringName) -> int:
	return LOOKS[robot].filter(func(entry): return entry[0] == kind).size()


## Look number for a robot's hat or body, or 0.
static func number(robot: int, kind: StringName, index: int) -> int:
	for n in 8:
		if LOOKS[robot][n] == [kind, index]: return n + 1
	return 0


## Looks a session total newly earns for a robot, given those already unlocked.
static func newly_unlocked(robot: int, total: int, unlocked: Array) -> Array[int]:
	var result: Array[int] = []
	for n in range(1, 9):
		if total >= THRESHOLDS[n - 1] and n not in unlocked: result.append(n)
	return result


static func title(robot: int, number: int) -> String:
	var entry: Array = look(robot, number)
	return "%s %d" % ["HAT" if entry[0] == &"hat" else "OUTFIT", entry[1]]

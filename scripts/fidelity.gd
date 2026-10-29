extends RefCounted
## Fidelity profile (ADR 0008). `original` follows the edition 5 design exactly;
## `adapted` keeps the accepted new-game adaptations in DESIGN.md.
## The original-replica branch runs `original`; checks of an adaptation switch it off.

static var original := true


## `ArcadeMode.timeOut` completes the level even with enemies alive; adapted play loses.
static func timeout_wins() -> bool:
	return original


## `GameSettingsUI.levelsHandle` sets 1 for the button named five.
static func levels_for_button(count: int) -> int:
	return 1 if original and count == 5 else count


## `GameModel.init` starts on Easy; adapted play starts on Normal.
static func default_difficulty() -> StringName:
	return &"easy" if original else &"normal"

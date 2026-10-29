extends SceneTree
## #75: sound classes raised by the round and `SoundManger`'s music rules
## (docs/evidence/edition-5-audio.md). Runs with or without the local pack.

const Simulation = preload("res://scripts/simulation/bomb_simulation.gd")
const Audio = preload("res://scripts/original_audio.gd")
const SaveStore = preload("res://scripts/save_store.gd")
const SAVE := "user://audio-check-save.json"
var failures := 0
var checks := 0


func _initialize() -> void:
	_round_sounds()
	_music_rules()
	_switches()
	print("%s: %d audio checks" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)


func _round_sounds() -> void:
	var board := {}
	for y in 15:
		for x in 17: board[Vector2i(x, y)] = &"solid" if x == 0 or y == 0 or x == 16 or y == 14 else &"floor"
	var round = Simulation.new([&"human", &"ruby"] as Array[StringName], {&"human": {"cell": Vector2i(1, 1)}, &"ruby": {"cell": Vector2i(15, 13)}},
		board, {"movement": true, "damage": true, "drops": true, "drop_chance": 0.0, "pickups": {Vector2i(2, 1): &"car"}})
	var heard: Array = []
	var idle := {"actor_id": &"ruby", "direction": Vector2.ZERO, "bomb_events": []}
	var first: Dictionary = round.advance([{"actor_id": &"human", "direction": Vector2.ZERO, "bomb_events": [&"down", &"up", &"down"]}, idle] as Array[Dictionary])
	_expect(first.sounds == [&"addBomb"], "placing a bomb raises addBomb once per step: %s" % [first.sounds])
	for frame in 100:
		var state: Dictionary = round.advance([{"actor_id": &"human", "direction": Vector2.RIGHT if frame < 6 else Vector2.ZERO, "bomb_events": []}, idle] as Array[Dictionary])
		heard.append_array(state.sounds)
	_expect(&"getCar" in heard and &"eatProp" in heard, "taking a car raises getCar and eatProp: %s" % [heard])
	_expect(&"bomb" in heard, "a detonation raises bomb")
	var round2 = Simulation.new([&"human", &"ruby"] as Array[StringName], {&"human": {"cell": Vector2i(1, 1)}, &"ruby": {"cell": Vector2i(2, 1)}},
		board, {"movement": true, "damage": true, "drops": true, "drop_chance": 0.0})
	round2.actors()[&"ruby"].shield = 1
	var all: Array = []
	for frame in 90:
		all.append_array(round2.advance([{"actor_id": &"human", "direction": Vector2.ZERO, "bomb_events": [&"down"] if frame == 0 else []}, idle] as Array[Dictionary]).sounds)
	_expect(&"useNombril" in all and &"dead" in all, "a shield hit raises useNombril and a death raises dead: %s" % [all])


func _music_rules() -> void:
	var draws := [0.9]
	var audio := Audio.new(func(): return draws.pop_front() if not draws.is_empty() else 0.0)
	root.add_child(audio)
	_expect(audio.order == ["gameMusic_1", "gameMusic_3", "gameMusic_2"], "round music starts with gameMusic_1, then the other two in a drawn order")
	audio.create_game_music()
	audio.pause_game_music()
	audio.restart_game_music()
	audio.null_game_music()
	audio.create_game_music()
	audio.null_game_music()
	audio.create_game_music()
	audio.null_game_music()
	audio.create_game_music()
	_expect(audio.played == [&"gameMusic_1", &"gameMusic_1", &"gameMusic_3", &"gameMusic_2", &"gameMusic_1"],
		"each round plays the next track and a resume replays the paused one: %s" % [audio.played])
	audio.played.clear()
	audio.pause_game_music()
	audio.set_music(false, false)
	audio.restart_game_music()
	audio.set_music(true, false)
	_expect(audio.played.is_empty() and audio.game_paused, "music switched off on the pause screen keeps the round silent after resume")
	audio.sound_on = false
	audio.play_sounds([&"bomb", &"noSuchClass"])
	_expect(not &"bomb" in audio.played, "the sound switch silences sounds")
	audio.sound_on = true
	audio.play_sounds([&"noSuchClass"])
	_expect(audio.stream("noSuchClass") == null, "a class the SWF never defined stays silent")
	audio.queue_free()


func _switches() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	var store := SaveStore.new(SAVE)
	_expect(store.sound_on and store.music_on, "both switches default to on")
	store.sound_on = false
	store.save_file()
	var reloaded := SaveStore.new(SAVE)
	_expect(not reloaded.sound_on and reloaded.music_on, "the switches persist in the save file")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))


func _expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr(label)

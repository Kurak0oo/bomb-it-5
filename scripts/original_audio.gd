extends Node
## Edition 5 sound and music (#75), ported from `SoundManger` and its callers; see
## docs/evidence/edition-5-audio.md. Plays the ignored local pack built by
## `tools/art_pipeline/original_audio.py` (`original/audio/<Class>.mp3`); without it, or for
## a class the SWF never defined, it stays silent.

const PACK := "res://original/audio/"

## The node the app owns; game and widgets reach it here, and do nothing when it is absent.
static var current: Node

## `Cookie.soundEnable` / `musicEnable`, both true by default.
var sound_on := true
var music_on := true
## Persists the switches (`Cookie`); receives (sound_on, music_on).
var persist := Callable()
## Round music order: `gameMusic_1`, then `gameMusic_2` and `gameMusic_3` in a random order
## drawn once (`createMusicOrder`), cycled per round (`levelMusicNum`).
var order: Array[String] = []
var level_music := 0
var game_paused := false
## Class names played, in order; checks read it.
var played: Array[StringName] = []

var _streams := {}
var _ui: AudioStreamPlayer
var _game: AudioStreamPlayer
var _game_stream: AudioStream
## `gameMusicChannel != null`.
var _channel := false
var _jingle: AudioStreamPlayer
var _ui_after_jingle := false


func _init(rng_draw: Callable = Callable()) -> void:
	var draw := rng_draw if rng_draw.is_valid() else func() -> float: return randf()
	var rest: Array[String] = ["gameMusic_2", "gameMusic_3"]
	order = ["gameMusic_1"]
	for index in 2:
		var pick := int(draw.call() * rest.size())
		order.append(rest[pick])
		rest.remove_at(pick)
	_ui = _player("UiMusic")
	_game = _player("GameMusic")
	_jingle = _player("Jingle")
	_jingle.finished.connect(_jingle_finished)


func _enter_tree() -> void:
	current = self


func _exit_tree() -> void:
	if current == self: current = null


func _player(name_text: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = name_text
	add_child(player)
	return player


## The class's sound from the pack, or null (no pack, or no such class in the SWF).
func stream(sound: String, loop := false) -> AudioStream:
	var key := sound + ("@loop" if loop else "")
	if _streams.has(key): return _streams[key]
	var path := PACK + sound + ".mp3"
	var result: AudioStream = null
	if FileAccess.file_exists(path):
		var mp3 := AudioStreamMP3.new()
		mp3.data = FileAccess.get_file_as_bytes(path)
		mp3.loop = loop
		result = mp3
	_streams[key] = result
	return result


## `createSound`: one play per class per step; the caller passes a step's de-duplicated list.
func play_sounds(sounds: Array) -> void:
	for sound in sounds: play_sound(sound)


func play_sound(sound: StringName) -> void:
	if not sound_on: return
	played.append(sound)
	var source := stream(sound)
	if source == null or not is_inside_tree(): return
	var player := AudioStreamPlayer.new()
	player.stream = source
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()


func menu_touch() -> void:
	play_sound(&"menuTouch")


func menu_press() -> void:
	play_sound(&"menuPress")


func create_ui_music() -> void:
	if not music_on or _ui.playing: return
	_ui.stream = stream("uiMusic", true)
	if _ui.stream != null and is_inside_tree(): _ui.play()
	played.append(&"uiMusic")


## `createOverUiMusic`: the menu music waits for a win or lose jingle still playing.
func create_over_ui_music() -> void:
	if _jingle.playing: _ui_after_jingle = true
	else: create_ui_music()


func null_ui_music() -> void:
	_ui.stop()


func create_game_music() -> void:
	if music_on:
		if _game_stream == null: _game_stream = stream(order[level_music], true)
		_game.stream = _game_stream
		if _game_stream != null and is_inside_tree(): _game.play()
		_channel = true
		played.append(StringName(order[level_music]))
	level_music = (level_music + 1) % order.size()


## `pauseGameMusic`: stops the channel; `restartGameMusic` plays the track again from 0.
func pause_game_music() -> void:
	if game_paused or not music_on or not _channel: return
	game_paused = true
	_channel = false
	_game.stop()


func restart_game_music() -> void:
	if not music_on: return
	if game_paused and _game_stream != null:
		game_paused = false
		_game.stream = _game_stream
		if is_inside_tree(): _game.play()
		_channel = true
		played.append(StringName(order[(level_music + order.size() - 1) % order.size()]))
	else:
		create_game_music()


func null_game_music() -> void:
	_game_stream = null
	game_paused = false
	_channel = false
	_game.stop()


func create_level_complete_music() -> void:
	_play_jingle("levelComplete")


func create_level_failed_music() -> void:
	_play_jingle("levelFailed")


func _play_jingle(sound: String) -> void:
	if not music_on: return
	_ui_after_jingle = false
	_jingle.stream = stream(sound)
	played.append(StringName(sound))
	if _jingle.stream != null and is_inside_tree(): _jingle.play()


func _jingle_finished() -> void:
	if _ui_after_jingle:
		_ui_after_jingle = false
		create_ui_music()


## The main menu's sound switch, and the pause screen's (`soundCtlHandle`).
func set_sound(on: bool) -> void:
	sound_on = on
	_save()


## The main menu's music switch also stops or starts the menu music (`closeUiMusic`,
## `startUiMusic`); the pause screen's only sets the flag (`in_menu` false).
func set_music(on: bool, in_menu := true) -> void:
	music_on = on
	if in_menu:
		if on: create_ui_music()
		else: null_ui_music()
	_save()


func _save() -> void:
	if persist.is_valid(): persist.call(sound_on, music_on)

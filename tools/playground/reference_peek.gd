extends Node
## Dev playground plugin: the original's captured frame next to or over the stage.
##
## Local reference captures (original art, never committed) live at
## `<repo>/.scratch/compare/<case>/reference/<capture>.png`, 700x510, and exist only on the
## machine that recorded them. A capture matches the stage only at the frame the runner
## reached when the case was loaded to it, so the status compares both frames.
##
## Off hides the reference; Ghost paints it over the overlay at the slider's opacity; Side by
## side opens it in a separate 700x510 window titled with the case and capture.

const STAGE_SIZE := Vector2i(700, 510)
const MODES := ["Off", "Ghost", "Side by side"]
const DEFAULT_OPACITY := 0.5

var _playground = null
var _mode_option: OptionButton
var _opacity: HSlider
var _status: Label
var _ghost: TextureRect = null
var _window: Window = null
var _window_texture: TextureRect = null
var _texture: ImageTexture = null
## The runner frame the loaded capture was taken at; -1 without a capture.
var reference_frame := -1
var _reference_label := ""


func setup(playground) -> void:
	name = "ReferencePeek"
	_playground = playground

	var header := Label.new()
	header.text = "Reference"
	playground.plugin_box.add_child(header)

	_mode_option = OptionButton.new()
	for mode in MODES:
		_mode_option.add_item(mode)
	_mode_option.item_selected.connect(_on_mode_selected)
	playground.plugin_box.add_child(_mode_option)

	_opacity = HSlider.new()
	_opacity.min_value = 0.0
	_opacity.max_value = 1.0
	_opacity.step = 0.01
	_opacity.value = DEFAULT_OPACITY
	_opacity.tooltip_text = "Reference opacity"
	_opacity.value_changed.connect(_on_opacity_changed)
	playground.plugin_box.add_child(_opacity)

	_status = Label.new()
	_status.text = "no local reference (record on the SWF machine)"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	playground.plugin_box.add_child(_status)

	playground.case_loaded.connect(_on_case_loaded)
	playground.stepped.connect(_on_stepped)


## Load a reference PNG into the plugin's texture. False when the file is missing, unreadable or
## not the 700x510 local capture size (a failed load keeps the current reference).
func load_reference(path: String) -> bool:
	if path.is_empty() or not FileAccess.file_exists(path):
		return false
	var image := Image.new()
	if image.load(path) != OK:
		return false
	if image.get_width() != STAGE_SIZE.x or image.get_height() != STAGE_SIZE.y:
		return false
	var texture := ImageTexture.create_from_image(image)
	if texture == null:
		return false
	_texture = texture
	_apply_mode()
	_refresh_status()
	return true


## Select Off / Ghost / Side by side, as the OptionButton does.
func set_mode(index: int) -> void:
	_mode_option.select(clampi(index, 0, MODES.size() - 1))
	_apply_mode()


func _on_case_loaded(case_name: String, capture_name: String) -> void:
	_clear_reference()
	if capture_name.is_empty():
		_refresh_status()
		return
	var path := ProjectSettings.globalize_path("res://").path_join(".scratch/compare") \
		.path_join(case_name).path_join("reference").path_join(capture_name + ".png")
	_reference_label = "%s/%s" % [case_name, capture_name]
	reference_frame = int(_playground.runner.frame) if _playground.runner != null else -1
	if not load_reference(path):
		_apply_mode()
	_refresh_status()


func _on_stepped(_frame: int) -> void:
	_refresh_status()


func _on_mode_selected(index: int) -> void:
	set_mode(index)


func _on_opacity_changed(value: float) -> void:
	if _ghost != null and is_instance_valid(_ghost):
		_ghost.modulate.a = value


func _apply_mode() -> void:
	var mode: int = _mode_option.selected
	if mode == 1 and _texture != null:
		var ghost := _ensure_ghost()
		ghost.texture = _texture
		ghost.modulate.a = _opacity.value
		ghost.visible = true
	elif _ghost != null and is_instance_valid(_ghost):
		_ghost.visible = false
	if mode == 2 and _texture != null:
		_show_window()
	else:
		_hide_window()


func _ensure_ghost() -> TextureRect:
	if _ghost == null or not is_instance_valid(_ghost):
		_ghost = TextureRect.new()
		_ghost.name = "ReferenceGhost"
		_ghost.position = Vector2.ZERO
		_ghost.size = Vector2(STAGE_SIZE)
		_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ghost.visible = false
		_playground.overlay.add_child(_ghost)
	return _ghost


func _show_window() -> void:
	if _window == null or not is_instance_valid(_window):
		_window = Window.new()
		_window.size = STAGE_SIZE
		_window.visible = false
		add_child(_window)
		_window_texture = TextureRect.new()
		_window_texture.name = "ReferenceTexture"
		_window_texture.position = Vector2.ZERO
		_window_texture.size = Vector2(STAGE_SIZE)
		_window_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_window.add_child(_window_texture)
	_window.title = "Reference %s" % _reference_label
	_window_texture.texture = _texture
	_window.show()


func _hide_window() -> void:
	if _window != null and is_instance_valid(_window):
		_window.hide()


func _clear_reference() -> void:
	_texture = null
	reference_frame = -1
	_reference_label = ""
	if _ghost != null and is_instance_valid(_ghost):
		_ghost.texture = null
		_ghost.visible = false
	if _window != null and is_instance_valid(_window):
		_window.hide()
		_window.queue_free()
		_window = null
		_window_texture = null


func _refresh_status() -> void:
	if _texture == null:
		_status.text = "no local reference (record on the SWF machine)"
		return
	var stage: int = int(_playground.runner.frame) if _playground.runner != null else -1
	var text := "reference = frame %d, stage = frame %d" % [reference_frame, stage]
	if reference_frame >= 0 and stage == reference_frame:
		text += " (matches)"
	_status.text = text

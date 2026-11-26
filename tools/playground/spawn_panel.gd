extends Node
## Dev playground plugin: the compare fixtures' round changes as panel buttons. A case drives
## these through the CaseRunner (`ai-stop N`, `pickup KIND`, `reposition X Y`); here a person
## does the same to the paused round. Every action calls the Game method the runner calls and
## writes one line to a small log.
##
## The controls follow the loaded app: disabled on the title screen and while the round has no
## actors (`state.actors` empty), re-checked on `case_loaded` and `stepped`.

const KINDS: Array[StringName] = [&"capacity", &"power", &"speed", &"life", &"shield",
	&"invincible", &"landmine", &"flamer", &"laser", &"hammer", &"triple", &"shotgun",
	&"boxing", &"car", &"moto", &"horse", &"dragon", &"kick", &"coin"]
const LOG_LINES := 4

var _playground = null
var _kind_option: OptionButton
var _give_button: Button
var _stop_buttons: Array[Button] = []
var _spin_x: SpinBox
var _spin_y: SpinBox
var _move_button: Button
var _log: Label
var _lines: Array[String] = []
var _controls: Array[Control] = []


func setup(playground) -> void:
	name = "SpawnPanel"
	_playground = playground

	var header := Label.new()
	header.text = "Spawn"
	playground.plugin_box.add_child(header)

	_kind_option = OptionButton.new()
	for kind in KINDS:
		_kind_option.add_item(String(kind))
	playground.plugin_box.add_child(_kind_option)

	_give_button = Button.new()
	_give_button.text = "Give to player"
	_give_button.pressed.connect(func() -> void:
		var index: int = maxi(0, _kind_option.selected)
		give(KINDS[index]))
	playground.plugin_box.add_child(_give_button)

	var stop_row := HBoxContainer.new()
	playground.plugin_box.add_child(stop_row)
	for seat in [1, 2, 3]:
		var button := Button.new()
		button.text = "Stop AI %d" % seat
		button.pressed.connect(func() -> void: stop_ai(seat))
		stop_row.add_child(button)
		_stop_buttons.append(button)

	var move_row := HBoxContainer.new()
	playground.plugin_box.add_child(move_row)
	_spin_x = _spin(16, "x ")
	_spin_y = _spin(14, "y ")
	move_row.add_child(_spin_x)
	move_row.add_child(_spin_y)
	_move_button = Button.new()
	_move_button.text = "Move player"
	_move_button.pressed.connect(func() -> void:
		move_player(Vector2i(int(_spin_x.value), int(_spin_y.value))))
	playground.plugin_box.add_child(_move_button)

	_log = Label.new()
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log.custom_minimum_size = Vector2(0, 18)
	playground.plugin_box.add_child(_log)

	_controls = [_kind_option, _give_button, _spin_x, _spin_y, _move_button]
	_controls.append_array(_stop_buttons)
	playground.case_loaded.connect(_on_case_loaded)
	playground.stepped.connect(_on_stepped)
	_refresh_enabled()


## The `pickup KIND` fixture: `Game.give_pickup` puts the pickup on the human's cell; the next
## round tick collects it.
func give(kind: StringName) -> void:
	var running = _game()
	if running == null:
		return
	running.give_pickup(kind)
	_note("frame %d: gave %s" % [_frame(), kind])


## The `ai-stop N` fixture: `Game.stop_ai` gives the AI robot at roster seat N no more commands.
func stop_ai(seat: int) -> void:
	var running = _game()
	if running == null:
		return
	running.stop_ai(seat)
	_note("frame %d: stopped AI %d" % [_frame(), seat])


## The `reposition X Y` fixture: `Game.reposition_human` puts the player on that floor cell.
func move_player(cell: Vector2i) -> void:
	var running = _game()
	if running == null:
		return
	running.reposition_human(cell)
	_note("frame %d: moved player to %d,%d" % [_frame(), cell.x, cell.y])


func _game():
	if _playground == null:
		return null
	var running = _playground.game()
	if running == null or not is_instance_valid(running):
		return null
	var state = running.get("state")
	if not state is Dictionary or state.is_empty():
		return null
	var actors = state.get("actors", {})
	if not actors is Dictionary or actors.is_empty():
		return null
	return running


func _frame() -> int:
	return int(_playground.runner.frame) if _playground.runner != null else 0


func _spin(maximum: int, prefix: String) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = 0
	spin.max_value = maximum
	spin.step = 1
	spin.allow_greater = false
	spin.allow_lesser = false
	spin.prefix = prefix
	spin.custom_minimum_size = Vector2(64, 0)
	return spin


func _note(line: String) -> void:
	_lines.append(line)
	while _lines.size() > LOG_LINES:
		_lines.pop_front()
	_log.text = "\n".join(_lines)


func _refresh_enabled() -> void:
	var on: bool = _game() != null
	for control in _controls:
		if control is BaseButton:
			(control as BaseButton).disabled = not on
		elif control is SpinBox:
			(control as SpinBox).editable = on


func _on_case_loaded(_case_name: String, _capture_name: String) -> void:
	_refresh_enabled()


func _on_stepped(_frame_number: int) -> void:
	_refresh_enabled()

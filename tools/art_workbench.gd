extends Control
## Desktop development tool. Draft art never changes the real round rules.

const Catalog = preload("res://scripts/art/catalog.gd")
const VisualSkin = preload("res://scripts/art/skin.gd")
const ComponentCanvas = preload("res://scripts/art/component_canvas.gd")
const Game = preload("res://scripts/game.gd")
const Session = preload("res://scripts/session.gd")
const StageSets = preload("res://scripts/simulation/stage_sets.gd")
const CATEGORIES := ["All", "Board", "Stage sets", "Characters", "Looks", "Pickups", "Weapons", "Effects", "Modes",
	"Controls", "Interface", "Screens", "Outcomes"]
## Preview launches: practice stays first (the default); the rest start a real level.
const PREVIEW_MODES := [[&"practice", "Practice"], [&"arcade", "Arcade"], [&"kill", "Battle Royale"],
	[&"pac_man", "Pac-Man"], [&"green_zone", "Green Zone"]]
const ACCENT := Color("85d5c8")
var draft: RefCounted
var applied: RefCounted
var selected := "effect.bomb"
var category := "All"
var definitions: Array[Dictionary] = Catalog.entries()
var cards: Dictionary = {}
var grid: GridContainer
var search: LineEdit
var filter: OptionButton
var heading: Label
var filename: Label
var status: Label
var changes: Label
var apply_button: Button
var current_preview: Node2D
var draft_preview: Node2D
var reference: TextureRect
var reference_note: Label
var file_dialog: FileDialog
var form: Dictionary = {}
var updating := false
var preview_window: Window
var inspector_title: Label
var settings_note: Label
var play_button: Button
var preview_mode: OptionButton
var preview_set: OptionButton


func _ready() -> void:
	get_window().title = "Bomb It 5 · Art Workbench"
	get_window().content_scale_size = Vector2i(1600, 900)
	get_window().min_size = Vector2i(1100, 680)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	applied = VisualSkin.new()
	draft = VisualSkin.new()
	draft.restore_draft()
	theme = Theme.new()
	theme.default_font_size = 16
	var background := ColorRect.new()
	background.color = Color("101821")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 16)
	margin.add_child(root_box)
	var toolbar := HBoxContainer.new()
	root_box.add_child(toolbar)
	var title := VBoxContainer.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(title)
	title.add_child(_label("ART WORKBENCH", 27, Color("edf4f4")))
	changes = _label("Choose a component. Preview a change. Apply when ready.", 14, Color("8ba6b8"))
	title.add_child(changes)
	_button(toolbar, "Undo", _undo, "Undo")
	preview_mode = OptionButton.new()
	preview_mode.name = "PreviewMode"
	for entry in PREVIEW_MODES: preview_mode.add_item(entry[1])
	preview_mode.tooltip_text = "Practice is the default preview; other modes start a real level."
	toolbar.add_child(preview_mode)
	preview_set = OptionButton.new()
	preview_set.name = "PreviewSet"
	preview_set.add_item("Random set")
	for set_id in StageSets.ORDER: preview_set.add_item(StageSets.title(set_id).capitalize())
	preview_set.tooltip_text = "Stage set for a mode preview."
	toolbar.add_child(preview_set)
	_button(toolbar, "Preview in game", _play_preview, "PreviewGame")
	apply_button = _button(toolbar, "Apply to game", _apply, "Apply")
	apply_button.add_theme_color_override("font_color", ACCENT)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_child(body)
	_build_categories(body)
	var centre := VBoxContainer.new()
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(centre)
	var query := HBoxContainer.new()
	centre.add_child(query)
	search = LineEdit.new()
	search.name = "Search"
	search.placeholder_text = "Search components…"
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.text_changed.connect(func(_value): _build_grid())
	query.add_child(search)
	filter = OptionButton.new()
	for item in ["All slots", "Draft replacements", "Using defaults"]: filter.add_item(item)
	filter.item_selected.connect(func(_index): _build_grid())
	query.add_child(filter)
	heading = _label("Components", 14, Color("8ba6b8"))
	centre.add_child(heading)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	centre.add_child(scroll)
	grid = GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)
	_build_inspector(body)
	status = _label("Images and sprite sheets · PNG / JPG / WebP · drag a file onto the window to replace the selected slot.", 14, Color("a6b8c5"))
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root_box.add_child(status)
	file_dialog = FileDialog.new()
	file_dialog.title = "Choose your replacement artwork"
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.add_filter("*.png,*.jpg,*.jpeg,*.webp", "Images")
	file_dialog.current_dir = ProjectSettings.globalize_path("res://")
	file_dialog.file_selected.connect(_import)
	add_child(file_dialog)
	get_window().files_dropped.connect(func(paths):
		if not paths.is_empty(): _import(paths[0]))
	draft.changed.connect(_draft_changed)
	_build_grid()
	_select(selected)
	_draft_changed()


func _build_categories(parent: Control) -> void:
	var nav := VBoxContainer.new()
	nav.custom_minimum_size.x = 172
	nav.add_theme_constant_override("separation", 8)
	parent.add_child(nav)
	nav.add_child(_label("LIBRARY", 13, Color("7893a7")))
	for name in CATEGORIES:
		var count := definitions.filter(func(entry): return name == "All" or entry.category == name).size()
		var button := _button(nav, "%s   %d" % [name, count], func():
			category = name
			_build_grid())
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	nav.add_child(spacer)
	var note := _label("DEFAULTS ARE BACK\n\nThe rejected artwork is reverted. Pick your replacements here, one component at a time.", 13, Color("89a3b4"))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nav.add_child(note)
	_button(nav, "Open asset folder", func():
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(VisualSkin.IMPORTS))
		OS.shell_open(ProjectSettings.globalize_path(VisualSkin.IMPORTS)))


func _build_grid() -> void:
	if grid == null: return
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	cards.clear()
	var query := search.text.strip_edges().to_lower()
	for entry in definitions:
		if category != "All" and category != entry.category: continue
		if query != "" and not (entry.title + " " + entry.id).to_lower().contains(query): continue
		var assigned: bool = not draft.entry(entry.id).is_empty()
		if filter.selected == 1 and not assigned or filter.selected == 2 and assigned: continue
		var button := Button.new()
		button.name = entry.id.replace(".", "_")
		button.custom_minimum_size = Vector2(208, 155)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_select.bind(entry.id))
		button.add_theme_stylebox_override("normal", _style(Color("182532"), Color("34475a")))
		button.add_theme_stylebox_override("hover", _style(Color("203444"), ACCENT))
		grid.add_child(button)
		var box := VBoxContainer.new()
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		box.offset_left = 10
		box.offset_right = -10
		box.offset_top = 7
		box.offset_bottom = -7
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(box)
		var preview := _preview(box, draft, entry.id, Vector2(180, 87), false)
		var label := _label(entry.title, 14, Color("e5edf1"))
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		box.add_child(label)
		var badge := _label("Replacement" if assigned else "Default drawing", 12, ACCENT if assigned else Color("839bae"))
		box.add_child(badge)
		cards[entry.id] = {"button": button, "badge": badge, "canvas": preview,
			"viewport": preview.get_parent()}
	heading.text = "%d visible · %s" % [cards.size(), category]
	_highlight()


func _build_inspector(parent: Control) -> void:
	var outer := VBoxContainer.new()
	outer.custom_minimum_size.x = 470
	outer.add_theme_constant_override("separation", 9)
	parent.add_child(outer)
	inspector_title = _label("Component", 22, Color("edf4f4"))
	outer.add_child(inspector_title)
	var comparisons := HBoxContainer.new()
	comparisons.add_theme_constant_override("separation", 10)
	outer.add_child(comparisons)
	for side in ["APPLIED IN GAME", "YOUR DRAFT"]:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		comparisons.add_child(column)
		column.add_child(_label(side, 12, Color("8ba6b8")))
		var preview := _preview(column, applied if side == "APPLIED IN GAME" else draft, selected, Vector2(225, 160), true)
		if side == "APPLIED IN GAME": current_preview = preview
		else: draft_preview = preview
	var playback := HBoxContainer.new()
	outer.add_child(playback)
	play_button = _button(playback, "Pause animation", func():
		draft_preview.playing = not draft_preview.playing
		current_preview.playing = draft_preview.playing
		play_button.text = "Pause animation" if draft_preview.playing else "Play animation")
	play_button.custom_minimum_size.x = 150
	var facing := OptionButton.new()
	for name in ["Face down", "Face right", "Face up", "Face left"]: facing.add_item(name)
	facing.item_selected.connect(func(index):
		draft_preview.facing = [Vector2.DOWN, Vector2.RIGHT, Vector2.UP, Vector2.LEFT][index]
		current_preview.facing = draft_preview.facing)
	playback.add_child(facing)
	var scrub := HSlider.new()
	scrub.name = "Scrub"
	scrub.max_value = 70
	scrub.step = 1
	scrub.value = 12
	scrub.custom_minimum_size.x = 125
	scrub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scrub.tooltip_text = "Scrub the visual preview (0–70 ticks). This does not change gameplay timing."
	scrub.value_changed.connect(func(value):
		draft_preview.playing = false
		current_preview.playing = false
		draft_preview.sample_tick = value
		current_preview.sample_tick = value
		play_button.text = "Play animation")
	playback.add_child(scrub)
	var import_row := HBoxContainer.new()
	outer.add_child(import_row)
	_button(import_row, "Replace image…", func(): file_dialog.popup_centered(Vector2i(1040, 660)), "Replace")
	_button(import_row, "Use default", func(): draft.reset_slot(selected), "ResetSlot")
	_button(import_row, "Reference", _open_reference)
	filename = _label("Default drawing", 13, Color("8ba6b8"))
	filename.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outer.add_child(filename)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 8)
	scroll.add_child(detail)
	detail.add_child(_label("SPRITE SETTINGS", 13, Color("8ba6b8")))
	var settings := GridContainer.new()
	settings.columns = 2
	settings.add_theme_constant_override("h_separation", 16)
	detail.add_child(settings)
	for spec in [["columns", "Frames across", 1, 64, 1], ["rows", "Facing rows (1 or 4)", 1, 4, 3],
		["fps", "Preview / loop fps", 0, 35, 1], ["scale", "Scale", 0.1, 4, 0.05],
		["x", "Offset X · game pixels", -128, 128, 1], ["y", "Offset Y · game pixels", -128, 128, 1]]:
		settings.add_child(_label(spec[1], 14, Color("c1d1dc")))
		var spin := SpinBox.new()
		spin.name = spec[0]
		spin.min_value = spec[2]
		spin.max_value = spec[3]
		spin.step = spec[4]
		spin.custom_minimum_size.x = 175
		spin.value_changed.connect(func(value):
			if not updating: draft.configure(selected, {spec[0]: value}))
		settings.add_child(spin)
		form[spec[0]] = spin
	settings.add_child(_label("Image tint", 14, Color("c1d1dc")))
	var tint := ColorPickerButton.new()
	tint.custom_minimum_size = Vector2(175, 30)
	tint.color_changed.connect(func(color):
		if not updating: draft.configure(selected, {"tint": color.to_html()}))
	settings.add_child(tint)
	form.tint = tint
	var help := _label("Frames run left → right. Four facing rows: Down, Right, Up, Left. Action animation follows the game's phase; these settings do not change hit timing.", 13, Color("7893a7"))
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(help)
	settings_note = help
	var original_toggle := CheckButton.new()
	original_toggle.text = "Original SWF reference · view only"
	original_toggle.button_pressed = true
	detail.add_child(original_toggle)
	reference = TextureRect.new()
	reference.custom_minimum_size = Vector2(440, 195)
	reference.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	reference.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	detail.add_child(reference)
	reference_note = _label("", 12, Color("7893a7"))
	reference_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(reference_note)
	original_toggle.toggled.connect(func(visible):
		reference.visible = visible
		reference_note.visible = visible)
	_button(detail, "Open full reference", _open_reference)


func _preview(parent: Control, library: RefCounted, id: String, dimensions: Vector2, animate: bool) -> Node2D:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = dimensions
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _style(Color("0c141e"), Color("293d50")))
	parent.add_child(panel)
	var container := SubViewportContainer.new()
	container.custom_minimum_size = dimensions
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(container)
	var viewport := SubViewport.new()
	viewport.transparent_bg = true
	viewport.size = Vector2i(dimensions)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if animate else SubViewport.UPDATE_ONCE
	container.add_child(viewport)
	var canvas := ComponentCanvas.new()
	canvas.skin = library
	canvas.component_id = id
	canvas.playing = animate
	viewport.add_child(canvas)
	return canvas


func _select(id: String) -> void:
	selected = id
	var entry := Catalog.find(id)
	inspector_title.text = entry.title
	current_preview.component_id = id
	draft_preview.component_id = id
	current_preview.sample_tick = 12
	draft_preview.sample_tick = 12
	var path: String = entry.reference
	var image := Image.new()
	if FileAccess.file_exists(path) and image.load(path) == OK:
		reference.texture = ImageTexture.create_from_image(image)
		reference_note.text = "Original context, not an isolated exported sprite. Research reference only.\n" + path.trim_prefix("res://")
	else:
		reference.texture = null
		reference_note.text = "No preserved reference image for this slot. The replacement still works."
	_update_form()
	_highlight()


func _highlight() -> void:
	for id in cards:
		cards[id].button.add_theme_stylebox_override("normal", _style(Color("203c43") if id == selected else Color("182532"), ACCENT if id == selected else Color("34475a")))


func _update_form() -> void:
	updating = true
	var values: Dictionary = draft.entry(selected)
	var menu_button := selected.begins_with("ui.button_")
	filename.text = values.get("label", "Default drawing · no replacement assigned")
	for key in form:
		if key == "tint":
			form[key].color = Color(values.get("tint", "ffffffff"))
			form[key].disabled = values.is_empty()
		else:
			form[key].editable = not values.is_empty() and (not menu_button or key == "columns")
			form[key].value = values.get(key, 1 if key in ["columns", "rows", "scale"] else 8 if key == "fps" else 0)
	updating = false
	settings_note.text = "Menu button images use the first frame and stretch to the existing button. Text and click areas stay unchanged." if menu_button else "Frames run left → right. Four facing rows: Down, Right, Up, Left. Action animation follows the game's phase; these settings do not change hit timing."


func _draft_changed() -> void:
	var records: Dictionary = draft.records()
	var active: Dictionary = applied.records()
	var keys := records.keys()
	for key in active:
		if key not in keys: keys.append(key)
	var different := keys.filter(func(key): return records.get(key) != active.get(key)).size()
	changes.text = "%d components · %d draft replacements · %d unapplied changes" % [definitions.size(), records.size(), different]
	apply_button.disabled = different == 0
	if filter.selected != 0: _build_grid()
	for id in cards:
		var assigned: bool = not draft.entry(id).is_empty()
		cards[id].badge.text = "Replacement" if assigned else "Default drawing"
		cards[id].badge.modulate = ACCENT if assigned else Color("839bae")
		cards[id].viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_update_form()
	status.text = "Draft saved. Preview in game to try it; Apply to game saves these choices for normal play."


func _import(path: String) -> void:
	var error: String = draft.import_image(selected, path)
	if error != "": status.text = error


func _undo() -> void:
	if not draft.undo(): status.text = "Nothing to undo in this session."


func _apply() -> void:
	var error: String = draft.apply()
	if error != "":
		status.text = error
		return
	applied = VisualSkin.new()
	current_preview.skin = applied
	_draft_changed()
	status.text = "Applied to game. New game launches now use these assets. Gameplay rules are unchanged."


func _play_preview() -> void:
	if is_instance_valid(preview_window): preview_window.queue_free()
	preview_window = Window.new()
	preview_window.title = "Draft preview · real game · changes not yet applied"
	preview_window.size = Vector2i(1280, 720)
	preview_window.content_scale_size = Vector2i(1280, 720)
	preview_window.close_requested.connect(preview_window.queue_free)
	add_child(preview_window)
	var game := Game.new()
	game.visual_skin = draft
	var mode: StringName = PREVIEW_MODES[maxi(0, preview_mode.selected)][0]
	if mode != &"practice":
		var session := Session.new(3)
		session.mode = mode
		if preview_set.selected > 0: session.stage = StageSets.ORDER[preview_set.selected - 1]
		session.begin()
		game.session = session
		game.auto_start = false
	preview_window.add_child(game)
	if mode != &"practice": game.play_level()
	preview_window.popup_centered()


func _open_reference() -> void:
	var path: String = Catalog.find(selected).reference
	if FileAccess.file_exists(path): OS.shell_open(ProjectSettings.globalize_path(path))
	else: status.text = "No preserved reference file for this component."


func _label(caption: String, size_px: int, color: Color) -> Label:
	var label := Label.new()
	label.text = caption
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	return label


func _button(parent: Control, caption: String, action: Callable, node_name: String = "") -> Button:
	var button := Button.new()
	if node_name != "": button.name = node_name
	button.text = caption
	button.custom_minimum_size.y = 38
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_stylebox_override("normal", _style(Color("23384a"), Color("3b5368")))
	button.add_theme_stylebox_override("hover", _style(Color("2c4d5b"), ACCENT))
	button.add_theme_stylebox_override("pressed", _style(Color("142630"), ACCENT))
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _style(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(9)
	box.content_margin_left = 12
	box.content_margin_right = 12
	return box

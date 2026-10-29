extends RefCounted
## Native menu widgets in the game's panel style; workbench `ui.button_*` replacements apply.

const Audio = preload("res://scripts/original_audio.gd")
const FONT_COLOR := Color("dfede7")
const ACCENT := Color("ffd989")


static func button(parent: Node, text: String, rect: Rect2, action: Callable, skin: RefCounted = null, font_px := 20) -> Button:
	var widget := Button.new()
	widget.text = text
	widget.position = rect.position
	widget.size = rect.size
	widget.focus_mode = Control.FOCUS_ALL
	widget.add_theme_font_size_override("font_size", font_px)
	for state_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = {"normal": Color("285768"), "hover": Color("39788a"), "pressed": Color("1b4052"),
			"disabled": Color("1d3a47"), "focus": Color(0, 0, 0, 0)}[state_name]
		style.border_color = Color("ffd989") if state_name == "focus" else Color("7fb6b7") if state_name != "disabled" else Color("3b616a")
		style.set_border_width_all(3 if state_name == "focus" else 1)
		style.set_corner_radius_all(10)
		style.draw_center = state_name != "focus"
		widget.add_theme_stylebox_override(state_name, style)
		if skin != null and state_name != "focus":
			var texture: Texture2D = skin.button_texture("ui.button_" + state_name)
			if texture != null:
				var texture_style := StyleBoxTexture.new()
				texture_style.texture = texture
				widget.add_theme_stylebox_override(state_name, texture_style)
	widget.add_theme_color_override("font_disabled_color", Color("6f8c94"))
	widget.pressed.connect(action)
	menu_sounds(widget)
	parent.add_child(widget)
	return widget


## Original buttons play `menuTouch` on roll-over and `menuPress` on mouse-down.
static func menu_sounds(widget: BaseButton) -> void:
	widget.mouse_entered.connect(func(): if Audio.current != null: Audio.current.menu_touch())
	widget.button_down.connect(func(): if Audio.current != null: Audio.current.menu_press())


## A two-frame switch (`sound`, `music`): frame 1 on, frame 2 off. Off draws a slash over the
## icon, which the sheets paint only in the on state.
static func switch(parent: Node, name: StringName, caption: String, rect: Rect2, on: bool, toggled: Callable) -> Switch:
	var widget := Switch.new()
	widget.name = name
	widget.caption = caption
	widget.on = on
	widget.position = rect.position
	widget.size = rect.size
	widget.focus_mode = Control.FOCUS_NONE
	widget.add_theme_font_size_override("font_size", 13)
	widget.pressed.connect(func():
		widget.on = not widget.on
		widget.refresh()
		toggled.call(widget.on))
	widget.refresh()
	parent.add_child(widget)
	return widget


class Switch extends Button:
	var on := true
	var caption := ""

	func refresh() -> void:
		text = "%s %s" % [caption, "ON" if on else "OFF"]
		queue_redraw()

	func _draw() -> void:
		if on: return
		draw_line(Vector2(size.x * 0.2, size.y * 0.8), Vector2(size.x * 0.8, size.y * 0.2), Color("e8584f"), 4, true)


## A row of mutually exclusive choices; `options` holds [label, value, enabled] entries.
## `names` and `place` let a page put each choice on its painted hotspot (#76).
static func choices(parent: Node, at: Vector2, options: Array, selected: Variant, on_select: Callable, width := 116.0,
		names: Array = [], place := Callable()) -> Array[Button]:
	var group := ButtonGroup.new()
	var result: Array[Button] = []
	for index in options.size():
		var option: Array = options[index]
		var value: Variant = option[1]
		var rect := Rect2(at + Vector2(index * (width + 10), 0), Vector2(width, 44))
		if place.is_valid() and index < names.size():
			var placed: Variant = place.call(StringName(names[index]), rect)
			if placed is Rect2: rect = placed
		var widget := button(parent, option[0], rect, func(): on_select.call(value), null, 19)
		if index < names.size(): widget.name = names[index]
		widget.toggle_mode = true
		widget.button_group = group
		widget.disabled = not option[2]
		widget.button_pressed = value == selected
		var chosen := StyleBoxFlat.new()
		chosen.bg_color = Color("c8743f")
		chosen.border_color = Color("ffd989")
		chosen.set_border_width_all(2)
		chosen.set_corner_radius_all(10)
		widget.add_theme_stylebox_override("pressed", chosen)
		widget.set_meta("value", value)
		result.append(widget)
	return result


## A transparent widget whose pixels the screen art already paints: real text, rect, hit
## test and focus, no visible face. Pressed (a toggle's selected state) keeps a tint and
## focus keeps a ring, so selection and keyboard focus stay visible over the art (#76).
static func ghost(control: Control) -> void:
	for state_name in ["normal", "hover", "disabled"]:
		var clear := StyleBoxFlat.new()
		clear.bg_color = Color(0, 0, 0, 0)
		clear.draw_center = false
		control.add_theme_stylebox_override(state_name, clear)
	var chosen := StyleBoxFlat.new()
	chosen.bg_color = Color(1.0, 0.85, 0.54, 0.28)
	chosen.border_color = ACCENT
	chosen.set_border_width_all(2)
	chosen.set_corner_radius_all(8)
	control.add_theme_stylebox_override("pressed", chosen)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0, 0, 0, 0)
	focus.border_color = ACCENT
	focus.set_border_width_all(3)
	focus.set_corner_radius_all(8)
	focus.draw_center = false
	control.add_theme_stylebox_override("focus", focus)
	for colour in ["font_color", "font_pressed_color", "font_hover_color", "font_disabled_color",
		"font_hover_pressed_color", "font_focus_color"]:
		control.add_theme_color_override(colour, Color(0, 0, 0, 0))


## A ghost whose popup arrow the art already paints.
static func ghost_option(widget: OptionButton) -> void:
	ghost(widget)
	var blank := ImageTexture.create_from_image(Image.create(1, 1, false, Image.FORMAT_RGBA8))
	widget.add_theme_icon_override("arrow", blank)


## A label whose pixels the art paints; its text stays for checks and accessibility.
static func ghost_label(widget: Label) -> void:
	for colour in ["font_color", "font_shadow_color", "font_outline_color"]:
		widget.add_theme_color_override(colour, Color(0, 0, 0, 0))


## An opaque rectangle that hides art a live widget replaces (`ScreenLayout.plate`).
static func plate(parent: Node, rect: Rect2, colour: Color) -> ColorRect:
	var widget := ColorRect.new()
	widget.position = rect.position
	widget.size = rect.size
	widget.color = colour
	widget.mouse_filter = Control.MOUSE_FILTER_IGNORE
	widget.z_index = -1
	parent.add_child(widget)
	return widget


static func label(parent: Node, text: String, at: Vector2, font_px := 20, color := FONT_COLOR, width := -1.0,
		align := HORIZONTAL_ALIGNMENT_LEFT, carrier := false) -> Label:
	var widget := Label.new()
	widget.add_theme_font_size_override("font_size", font_px)
	widget.add_theme_color_override("font_color", color)
	widget.horizontal_alignment = align
	if width > 0:
		# Wrap and width before the text, or the label sizes itself to one long line.
		widget.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		widget.custom_minimum_size.x = width
		widget.size.x = width
	widget.text = text
	widget.position = at
	# A carrier paints its own text on a plate, so gating must never ghost it.
	if carrier: widget.set_meta("carrier", true)
	parent.add_child(widget)
	return widget


static func panel(parent: Node, rect: Rect2, fill := Color("214c60"), border := Color("c9c7a0"), radius := 18) -> Panel:
	var widget := Panel.new()
	widget.position = rect.position
	widget.size = rect.size
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	widget.add_theme_stylebox_override("panel", style)
	widget.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(widget)
	return widget

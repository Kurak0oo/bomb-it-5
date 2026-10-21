extends RefCounted
## Native menu widgets in the game's panel style; workbench `ui.button_*` replacements apply.

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
	parent.add_child(widget)
	return widget


## A row of mutually exclusive choices; `options` holds [label, value, enabled] entries.
static func choices(parent: Node, at: Vector2, options: Array, selected: Variant, on_select: Callable, width := 116.0) -> Array[Button]:
	var group := ButtonGroup.new()
	var result: Array[Button] = []
	for index in options.size():
		var option: Array = options[index]
		var value: Variant = option[1]
		var widget := button(parent, option[0], Rect2(at + Vector2(index * (width + 10), 0), Vector2(width, 44)),
			func(): on_select.call(value), null, 19)
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


static func label(parent: Node, text: String, at: Vector2, font_px := 20, color := FONT_COLOR, width := -1.0,
		align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var widget := Label.new()
	widget.text = text
	widget.position = at
	widget.add_theme_font_size_override("font_size", font_px)
	widget.add_theme_color_override("font_color", color)
	widget.horizontal_alignment = align
	if width > 0:
		widget.size.x = width
		widget.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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

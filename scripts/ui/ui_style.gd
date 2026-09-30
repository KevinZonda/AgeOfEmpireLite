extends RefCounted

const THEME = preload("res://assets/ui/game_theme.tres")

static func _hud_panel_style(color: Color, margin: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("a7894f")
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.38)
	style.shadow_size = 5
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = margin
	style.content_margin_bottom = margin
	return style

static func _button_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style

static func _parchment_style(fill: Color, margin: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = Color("4a321d")
	style.set_border_width_all(5)
	style.set_corner_radius_all(3)
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 12
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = margin
	style.content_margin_bottom = margin
	return style

static func _style_menu_button(button: BaseButton, selected := false) -> void:
	var fill := Color("5a3b22") if selected else Color("e5d4a9")
	var edge := Color("b98c48") if selected else Color("9b784b")
	button.add_theme_stylebox_override("normal", _button_style(fill, edge))
	button.add_theme_stylebox_override("hover", _button_style(fill.lightened(0.08), Color("d3a85f")))
	button.add_theme_stylebox_override("pressed", _button_style(fill.darkened(0.12), Color("ad854e")))
	button.add_theme_color_override("font_color", Color("f7e8bd") if selected else Color("3d2b1d"))
	button.add_theme_color_override("font_hover_color", Color("fff1cf") if selected else Color("3d2b1d"))
	button.add_theme_color_override("font_pressed_color", Color("f7e8bd") if selected else Color("3d2b1d"))

static func _style_button(button: BaseButton, primary := false) -> void:
	var base := Color("715028") if primary else Color("3d3224")
	button.add_theme_stylebox_override("normal", _button_style(base, Color("a88b56")))
	button.add_theme_stylebox_override("hover", _button_style(base.lightened(0.14), Color("dfc584")))
	button.add_theme_stylebox_override("pressed", _button_style(base.darkened(0.16), Color("f0d791")))
	button.add_theme_stylebox_override("disabled", _button_style(Color("302b24"), Color("615844")))
	button.add_theme_color_override("font_color", Color("f5e4bf"))
	button.add_theme_color_override("font_hover_color", Color("fff2d2"))
	button.add_theme_color_override("font_pressed_color", Color("ffe4a3"))
	button.add_theme_color_override("font_disabled_color", Color("948876"))

static func _style_progress_bar(bar: ProgressBar, fill_color: Color) -> void:
	var background := StyleBoxFlat.new()
	background.bg_color = Color("1a1712")
	background.border_color = Color("8d7448")
	background.set_border_width_all(1)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)

static func page_panel(fill: Color, border: Color, margin: float, radius := 3) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(margin)
	return box

static func load_font() -> void:
	var font_data := FileAccess.get_file_as_bytes("res://assets/fonts/NotoSansSC-Regular.otf")
	if font_data.is_empty():
		push_error("Unable to read the bundled UI font")
		return
	var font := FontFile.new()
	font.data = font_data
	ThemeDB.fallback_font = font
	var default_theme := ThemeDB.get_default_theme()
	default_theme.default_font = font
	for font_name in ["bold_font", "italics_font", "bold_italics_font"]:
		var variation := default_theme.get_font(font_name, "RichTextLabel") as FontVariation
		if variation != null:
			variation.base_font = font

static func menu_label(parent: Node, value: String, size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("f0ddb1"))
	parent.add_child(label)
	return label

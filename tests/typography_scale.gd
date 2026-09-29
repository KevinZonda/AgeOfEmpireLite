extends SceneTree

const TYPOGRAPHY = preload("res://scripts/ui/typography.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Variant = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game._apply_window_resolution(Vector2i(1920, 1080), false)
	game._show_tech_tree("English")
	await process_frame
	var title: Label
	for label in game.tech_tree_overlay.find_children("*", "Label", true, false):
		if label.text.contains("英格兰  ·  科技树"):
			title = label
			break
	assert(title != null)
	var chart := RtsStatisticsChart.new()
	game.ui_root.add_child(chart)
	for pair in [[0.75, 1.0], [1.0, 1.5], [1.5, 2.0]]:
		game.ui_scale = pair[0]
		game.text_scale = pair[1]
		game._apply_ui_scales()
		await process_frame
		var actual_ui_scale: float = game.ui_root.scale.x
		var expected_title := TYPOGRAPHY.ui_font_size(TYPOGRAPHY.PAGE_TITLE, game.text_scale, actual_ui_scale)
		assert(title.get_theme_font_size("font_size") == expected_title)
		assert(absf(expected_title * actual_ui_scale - TYPOGRAPHY.PAGE_TITLE * game.text_scale) <= actual_ui_scale * 0.5)
		assert(is_equal_approx(chart.ui_scale, actual_ui_scale) and is_equal_approx(chart.text_scale, game.text_scale))
		var chart_size := TYPOGRAPHY.ui_font_size(TYPOGRAPHY.CAPTION, chart.text_scale, chart.ui_scale)
		assert(absf(chart_size * actual_ui_scale - TYPOGRAPHY.CAPTION * game.text_scale) <= actual_ui_scale * 0.5)
		assert(ThemeDB.get_default_theme().get_font_size("font_size", "TooltipLabel") == TYPOGRAPHY.screen_font_size(game.base_tooltip_font_size, game.text_scale))
	game.tech_tree_civilization_choice.show_popup()
	await process_frame
	var dropdown: PopupMenu = game.tech_tree_civilization_choice.get_popup()
	assert(is_equal_approx(dropdown.content_scale_factor, game.ui_root.scale.x))
	assert(absf(dropdown.get_theme_font_size("font_size") * dropdown.content_scale_factor - 16.0 * game.text_scale) <= dropdown.content_scale_factor * 0.5)
	dropdown.hide()
	var visible_rect := Rect2(Vector2.ZERO, game.get_viewport_rect().size)
	var tile: PanelContainer
	for panel in game.tech_tree_overlay.find_children("*", "PanelContainer", true, false):
		if not panel.tooltip_text.is_empty() and visible_rect.has_point(panel.get_global_rect().get_center()):
			tile = panel
			break
	assert(tile != null)
	var motion := InputEventMouseMotion.new()
	motion.position = tile.get_global_transform_with_canvas() * (tile.size * 0.5)
	root.push_input(motion, true)
	await create_timer(0.7).timeout
	var tooltip: PopupPanel
	for node in root.find_children("*", "PopupPanel", true, false):
		tooltip = node
		break
	assert(tooltip != null and tooltip.visible)
	var tooltip_label := tooltip.find_children("*", "Label", true, false)[0] as Label
	assert(absf(tooltip_label.get_theme_font_size("font_size") * tooltip.content_scale_factor - game.base_tooltip_font_size * game.text_scale) <= 1.0)
	assert(tooltip_label.get_meta("base_ui_font_size") == game.base_tooltip_font_size)
	game.free()
	print("TYPOGRAPHY_SCALE_OK")
	quit()

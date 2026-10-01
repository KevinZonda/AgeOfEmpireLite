extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	# Exercise a fixed 720p / 100% configuration independently of startup defaults.
	root.size = Vector2i(1280, 720)
	var game = load("res://scenes/main.tscn").instantiate()
	game.selected_view_mode_25d = false
	game.ui_scale = 1.0
	game.text_scale = 1.0
	game.minimap_size = 216
	root.add_child(game)
	await process_frame
	assert(game.menu_panel.visible)
	var home_settings: Button
	for child in game.menu_panel.get_child(0).get_children():
		if child is Button and child.text == "设 置": home_settings = child
	assert(home_settings != null)
	home_settings.pressed.emit()
	assert(game.settings_overlay.visible and not game.menu_panel.visible)
	var settings_title: Label = game.settings_overlay.find_children("*", "Label", true, false).filter(func(node: Node) -> bool: return (node as Label).text == "设置")[0] as Label
	assert(settings_title.get_theme_font_size("font_size") == 28, "settings should use the shared page title size")
	assert(game.settings_overlay.get_child(0).get_global_rect() == Rect2(Vector2.ZERO, game.get_viewport_rect().size), "settings should fill the game view")
	assert(game.settings_tabs.get_tab_count() == 2)
	assert(game.settings_tabs.get_tab_title(0) == "显示设置")
	assert(game.settings_tabs.get_tab_title(1) == "操作设置")
	assert(not game.settings_tabs.tabs_visible)
	assert(game.settings_tab_buttons.size() == 2)
	await process_frame
	var first_tab_rect: Rect2 = game.settings_tab_buttons[0].get_global_rect()
	var second_tab_rect: Rect2 = game.settings_tab_buttons[1].get_global_rect()
	var content_rect: Rect2 = game.settings_tabs.get_global_rect()
	assert(first_tab_rect.end.x < content_rect.position.x)
	assert(first_tab_rect.position.y < second_tab_rect.position.y)
	game.settings_tab_buttons[1].pressed.emit()
	assert(game.settings_tabs.current_tab == 1)
	await process_frame
	for toggle in [game.edge_scroll_toggle, game.zoom_gesture_toggle]:
		assert(toggle.size.x < 240 and toggle.get_parent().size.x < 430, "control switches should stay next to their labels")
	game.settings_tab_buttons[0].pressed.emit()
	assert(game.settings_tabs.current_tab == 0)
	await process_frame
	assert(game.resolution_values.has(Vector2i(1280, 720)))
	assert(game.resolution_values.has(Vector2i(1600, 900)))
	assert(game.resolution_values[0] == Vector2i.ZERO and game.resolution_choice.get_item_text(0).begins_with("自动（"))
	assert(game._fit_window_size_to_screen(Vector2i(1920, 1080)) == Vector2i(1728, 972))
	assert(game._fit_window_size_to_screen(Vector2i(1366, 768)) == Vector2i(1229, 691))
	assert(game._fit_window_size_to_screen(Vector2i(1024, 768)) == Vector2i(960, 691))
	assert(game.ui_scale_values == [0.75, 1.0])
	assert(game.ui_scale_choice.selected == 1)
	assert(game.text_scale_choice.item_count == 6 and game.text_scale_choice.selected == 1)
	assert(game.text_scale_choice.get_item_text(4) == "175%" and game.text_scale_choice.get_item_text(5) == "200%")
	assert(game.minimap_size_choice.item_count == 3 and game.minimap_size_choice.selected == 1)
	assert(game.health_bar_mode == "damaged" and game.health_bar_choice.selected == 1)
	assert(game.health_bar_choice.item_count == 3)
	assert(game.health_bar_choice.get_item_text(0) == "总是")
	assert(game.health_bar_choice.get_item_text(1) == "非满血时显示")
	assert(game.health_bar_choice.get_item_text(2) == "变动时显示")
	for setting in [
		[game.window_mode_choice, "显示模式"],
		[game.resolution_choice, "窗口分辨率"],
		[game.projection_choice, "视角"],
		[game.health_bar_choice, "血量显示"],
		[game.minimap_size_choice, "小地图大小"],
		[game.ui_scale_choice, "界面缩放"],
		[game.text_scale_choice, "文字缩放"],
	]:
		var choice: OptionButton = setting[0]
		var row: HBoxContainer = choice.get_parent()
		var label: Label = row.get_child(0)
		assert(row.get_parent().name == "显示设置")
		assert(label.text == setting[1])
		assert(label.get_global_rect().end.x < choice.get_global_rect().position.x)
		assert(label.get_global_rect().end.y > choice.get_global_rect().position.y)
		assert(choice.size.x <= 300 and row.size.x < 450, "settings selectors should stay compact")
		assert(absf(row.get_global_rect().get_center().x - row.get_parent().get_global_rect().get_center().x) < 1.0, "settings rows should be centered in the page")
	for toggle in [game.building_icons_toggle, game.building_names_toggle, game.fps_toggle]:
		assert(toggle.size.x < 240 and toggle.get_parent().size.x < 430, "display switches should stay next to their labels")
	assert(game.window_mode_choice.get_item_text(0) == "窗口化")
	assert(game.window_mode_choice.get_item_text(1) == "全屏")
	assert(game.window_mode_choice.selected == 0)
	assert(game.edge_scroll_toggle.button_pressed)
	assert(game.zoom_gesture_toggle.button_pressed)
	assert(game.building_icons_toggle.button_pressed and game.building_names_toggle.button_pressed)
	assert(not game.show_fps and not game.fps_toggle.button_pressed and not game.fps_label.visible)
	game.building_icons_toggle.button_pressed = false
	game.building_names_toggle.button_pressed = false
	game.fps_toggle.button_pressed = true
	game.health_bar_choice.select(0)
	game.projection_choice.select(1)
	game.window_mode_choice.select(1)
	game.resolution_choice.select(game.resolution_values.find(Vector2i(1280, 720)))
	game.ui_scale_choice.select(game.ui_scale_values.find(0.75))
	game.text_scale_choice.select(game.TEXT_SCALE_OPTIONS.find(1.25))
	game.minimap_size_choice.select(game.MINIMAP_SIZE_OPTIONS.find(264))
	game.settings_tabs.current_tab = 1
	game.edge_scroll_toggle.button_pressed = false
	game.zoom_gesture_toggle.button_pressed = false
	game._close_settings()
	assert(game.edge_scroll_enabled, "return should discard unsaved control changes")
	assert(game.show_building_icons and game.show_building_names, "return should discard unsaved building display changes")
	assert(not game.show_fps and not game.fps_label.visible, "return should discard unsaved FPS changes")
	assert(game.health_bar_mode == "damaged", "return should discard unsaved health bar changes")
	assert(game.zoom_gesture_enabled and not game.selected_view_mode_25d, "return should discard unsaved view and gesture changes")
	assert(game.ui_scale == 1.0 and game.text_scale == 1.0 and game.minimap_size == 216, "return should discard unsaved scale changes")
	assert(not game._window_is_fullscreen(), "return should discard unsaved window mode")
	assert(not game.settings_overlay.visible and game.menu_panel.visible)
	home_settings.pressed.emit()
	assert(game.window_mode_choice.selected == 0)
	assert(game.edge_scroll_toggle.button_pressed)
	assert(game.zoom_gesture_toggle.button_pressed and game.projection_choice.selected == 0)
	assert(game.building_icons_toggle.button_pressed and game.building_names_toggle.button_pressed)
	assert(not game.fps_toggle.button_pressed)
	assert(game.health_bar_choice.selected == 1)
	game.building_icons_toggle.button_pressed = false
	game.building_names_toggle.button_pressed = false
	game.fps_toggle.button_pressed = true
	game.health_bar_choice.select(2)
	game.projection_choice.select(1)
	game.window_mode_choice.select(1)
	game.resolution_choice.select(game.resolution_values.find(Vector2i(1280, 720)))
	game.ui_scale_choice.select(game.ui_scale_values.find(0.75))
	game.text_scale_choice.select(game.TEXT_SCALE_OPTIONS.find(2.0))
	game.minimap_size_choice.select(game.MINIMAP_SIZE_OPTIONS.find(264))
	game.settings_tabs.current_tab = 1
	game.edge_scroll_toggle.button_pressed = false
	game.zoom_gesture_toggle.button_pressed = false
	var settings_path: String = game.SETTINGS_PATH
	var had_settings := FileAccess.file_exists(settings_path)
	var old_settings := FileAccess.get_file_as_bytes(settings_path) if had_settings else PackedByteArray()
	var save_button: Button
	for child in game.settings_overlay.find_children("*", "Button", true, false):
		if child.text == "保存设置": save_button = child
	assert(save_button != null)
	save_button.pressed.emit()
	var saved := ConfigFile.new()
	var save_result := saved.load(settings_path)
	var saved_edge_scroll: Variant = saved.get_value("controls", "edge_scroll_enabled", null) if save_result == OK else null
	var saved_zoom_gesture: Variant = saved.get_value("controls", "zoom_gesture_enabled", null) if save_result == OK else null
	var saved_view: Variant = saved.get_value("display", "view_mode_25d", null) if save_result == OK else null
	var saved_ui_scale: Variant = saved.get_value("display", "ui_scale", null) if save_result == OK else null
	var saved_text_scale: Variant = saved.get_value("display", "text_scale", null) if save_result == OK else null
	var saved_minimap_size: Variant = saved.get_value("display", "minimap_size", null) if save_result == OK else null
	var saved_health_bar_mode: Variant = saved.get_value("display", "health_bar_mode", null) if save_result == OK else null
	var saved_show_fps: Variant = saved.get_value("display", "show_fps", null) if save_result == OK else null
	var saved_fullscreen: Variant = saved.get_value("display", "fullscreen", null) if save_result == OK else null
	var saved_window_size: Variant = saved.get_value("display", "window_size", null) if save_result == OK else null
	if had_settings:
		var previous_file := FileAccess.open(settings_path, FileAccess.WRITE)
		previous_file.store_buffer(old_settings)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))
	assert(save_result == OK and saved_edge_scroll == false and saved_zoom_gesture == false and saved_view == true)
	assert(saved_ui_scale == 0.75 and saved_text_scale == 2.0 and saved_minimap_size == 264)
	assert(saved_health_bar_mode == "changed" and game.health_bar_mode == "changed")
	assert(saved_show_fps == true and game.show_fps and not game.fps_label.visible, "FPS should stay hidden in the main menu")
	assert(saved.get_value("display", "show_building_icons", null) == false)
	assert(saved.get_value("display", "show_building_names", null) == false)
	assert(not game.show_building_icons and not game.show_building_names)
	assert(is_equal_approx(game.ui_root.scale.x, 0.75))
	assert(is_equal_approx(game.ui_root.size.x, game.get_viewport_rect().size.x / 0.75))
	var top_base_font: int = game.top_label.get_meta("base_ui_font_size")
	assert(absf(game.top_label.get_theme_font_size("font_size") * 0.75 - top_base_font * 2.0) < 1.0)
	assert(saved_fullscreen == true and saved_window_size == Vector2i(1280, 720))
	assert(game._window_is_fullscreen())
	game._apply_window_mode(false, false)
	assert(not game._window_is_fullscreen())
	if DisplayServer.get_name() != "headless": assert(game.get_window().mode == Window.MODE_WINDOWED)
	assert(game.get_window().size == Vector2i(1280, 720))
	assert(not game.edge_scroll_enabled)
	assert(not game.zoom_gesture_enabled and game.selected_view_mode_25d)
	game.ui_scale = 1.0
	game.text_scale = 1.0
	game._apply_ui_scales()
	assert(game._edge_pan_direction(Vector2(2, 360), Vector2(1280, 720)) == Vector2.ZERO)
	game.edge_scroll_enabled = true
	assert(game._edge_pan_direction(Vector2(2, 360), Vector2(1280, 720)) == Vector2.LEFT)
	game.start_game("English", 12345)
	await process_frame
	assert(game.fps_label.visible, "FPS should appear with the gameplay HUD")
	assert(game.fps_label.text.begins_with("FPS: "))
	assert(game.fps_label.get_parent() == game.ui_root, "FPS should float outside the top HUD")
	assert(game.fps_label.get_global_rect().position.y >= game.hud_top.get_global_rect().end.y)
	assert(game.fps_label.get_global_rect().end.x <= game.hud_top.get_global_rect().end.x)
	assert(game.fps_label.get_global_rect().end.x >= game.hud_top.get_global_rect().end.x - 24.0)
	assert(game.global_queue_panel.get_global_rect().position.y >= game.fps_label.get_global_rect().end.y)
	game.ui_scale = 0.75
	game._apply_ui_scales()
	await process_frame
	assert(game.fps_label.get_global_rect().position.y >= game.hud_top.get_global_rect().end.y, "FPS should stay below a scaled HUD")
	var bottom_transform: Transform2D = game.hud_bottom.get_global_transform_with_canvas()
	assert(game._selection_point_over_hud(bottom_transform * Vector2(20, 20)))
	game.ui_scale = 1.0
	game._apply_ui_scales()
	assert(game.view_mode_25d, "saved view preference should apply to a new match")
	var magnify := InputEventMagnifyGesture.new()
	magnify.factor = 1.2
	magnify.position = Vector2(640, 360)
	var zoom_before: float = game.camera.zoom.x
	game._unhandled_input(magnify)
	assert(is_equal_approx(game.camera.zoom.x, zoom_before), "disabled magnify gesture should not zoom")
	game.zoom_gesture_enabled = true
	game._unhandled_input(magnify)
	assert(game.camera.zoom.x > zoom_before, "enabled magnify gesture should zoom")
	assert(not game.minimap.clip_contents)
	assert(game.minimap.size.is_equal_approx(game.minimap.get_parent().size), "the 2.5D map should fit its configured slot")
	assert(game.hud_bottom.get_global_rect().end.y <= game.get_viewport_rect().size.y)
	assert(game.minimap.get_global_rect().end.y <= game.get_viewport_rect().size.y)
	game._set_paused(true)
	var pause_panel: PanelContainer = game.pause_overlay.get_child(0)
	assert(pause_panel.get_global_rect().end.y <= game.get_viewport_rect().size.y)
	game._set_paused(false)
	for resolution in [Vector2i(1600, 900), Vector2i(1920, 1080)]:
		game._apply_window_resolution(resolution, false)
		await process_frame
		assert(game.get_window().size == resolution)
		assert(game.hud_bottom.get_global_rect().end.y <= game.get_viewport_rect().size.y)
		assert(game.minimap.get_global_rect().end.y <= game.get_viewport_rect().size.y)
	game._set_paused(true)
	var pause_settings: Button
	for child in game.pause_overlay.get_child(0).get_child(0).get_children():
		if child is Button and child.text == "设置": pause_settings = child
	assert(pause_settings != null)
	pause_settings.pressed.emit()
	assert(not game.building_icons_toggle.button_pressed and not game.building_names_toggle.button_pressed)
	assert(game.ui_scale_values == [0.75, 1.0, 1.25, 1.5])
	game.ui_scale = 1.5
	game._apply_ui_scales()
	await process_frame
	var scaled_panel: Control = game.settings_overlay.get_child(0)
	var scaled_transform: Transform2D = scaled_panel.get_global_transform_with_canvas()
	var scaled_rect := Rect2(scaled_transform * Vector2.ZERO, scaled_transform * scaled_panel.size - scaled_transform * Vector2.ZERO)
	assert(scaled_rect.position.is_equal_approx(Vector2.ZERO))
	assert(scaled_rect.size.is_equal_approx(Vector2(1920, 1080)), "paused settings should fill the view with UI scaling")
	assert(absf(game.top_label.get_theme_font_size("font_size") * 1.5 - top_base_font) < 1.0)
	game.text_scale = 1.25
	game._apply_ui_scales()
	assert(absf(game.window_mode_choice.get_popup().get_theme_font_size("font_size") * 1.5 - 20.0) <= 1.0, "dropdown text should reach 125% on screen after UI scaling")
	game.text_scale = 1.5
	game._apply_ui_scales()
	await process_frame
	assert(game.window_mode_choice.size.x <= 300 and game.window_mode_choice.get_parent().size.x < 450, "selectors should remain compact at 150% UI and text scale")
	assert(game.building_icons_toggle.size.x < 240, "switches should remain compact at 150% UI and text scale")
	game.text_scale = 2.0
	game._apply_ui_scales()
	await process_frame
	assert(absf(game.window_mode_choice.get_popup().get_theme_font_size("font_size") * 1.5 - 32.0) <= 1.0)
	assert(game.text_scale_choice.get_item_text(5) == "200%" and game.text_scale_choice.size.x <= 300)
	game.text_scale = 1.0
	game._apply_ui_scales()
	game.ui_scale = 1.0
	game._apply_ui_scales()
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	game._input(escape)
	assert(game.paused and game.pause_overlay.visible and not game.settings_overlay.visible)
	game._apply_window_resolution(Vector2i(1280, 720), false)
	game.text_scale = 1.5
	game._apply_ui_scales()
	game._show_menu()
	assert(not game.fps_label.visible, "FPS should hide when returning to the menu")
	game.menu_ui._show_setup_menu()
	await process_frame
	var scaled_title: Label
	for label in game.menu_panel.find_children("*", "Label", true, false):
		if label.text == "对 局 设 置": scaled_title = label
	assert(scaled_title != null and scaled_title.get_theme_font_size("font_size") == 42)
	var menu_rect: Rect2 = game.menu_panel.get_global_rect()
	assert(menu_rect.position.is_equal_approx(Vector2.ZERO))
	assert(menu_rect.size.is_equal_approx(Vector2(1280, 720)), "match setup should fill the game view")
	root.size = Vector2i(1920, 1080)
	await process_frame
	menu_rect = game.menu_panel.get_global_rect()
	assert(menu_rect.position.is_equal_approx(Vector2.ZERO))
	assert(menu_rect.size.is_equal_approx(Vector2(1920, 1080)), "match setup should fill a resized view")
	game.ui_scale = 0.75
	game._apply_ui_scales()
	await process_frame
	var setup_transform: Transform2D = game.menu_panel.get_global_transform_with_canvas()
	var scaled_setup_size: Vector2 = setup_transform * game.menu_panel.size - setup_transform * Vector2.ZERO
	assert(scaled_setup_size.is_equal_approx(Vector2(1920, 1080)), "match setup should also fill the view with UI scaling")
	game.ui_scale = 1.0
	game._apply_ui_scales()
	root.size = Vector2i(1280, 720)
	await process_frame
	game._show_settings()
	await process_frame
	var settings_rect: Rect2 = game.settings_overlay.get_child(0).get_global_rect()
	assert(settings_rect == Rect2(Vector2.ZERO, Vector2(1280, 720)), "settings should fill the view from match setup")
	game.resolution_choice.select(0)
	save_button.pressed.emit()
	assert(game.adaptive_resolution_enabled and game.windowed_resolution == game._adaptive_window_resolution())
	var adaptive_settings := ConfigFile.new()
	assert(adaptive_settings.load(settings_path) == OK)
	assert(adaptive_settings.get_value("display", "adaptive_resolution", false) == true)
	game._apply_window_mode(true, false)
	game._apply_window_mode(false, false)
	assert(game.adaptive_resolution_enabled and game.get_window().size == game._adaptive_window_resolution())
	game._show_settings()
	assert(game.resolution_choice.selected == 0)
	if had_settings:
		var previous_file := FileAccess.open(settings_path, FileAccess.WRITE)
		previous_file.store_buffer(old_settings)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))
	game.free()
	print("DISPLAY_SETTINGS_OK")
	quit()

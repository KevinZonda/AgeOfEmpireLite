extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	assert(game.menu_panel.visible)
	var home_settings: Button
	for child in game.menu_panel.get_child(0).get_children():
		if child is Button and child.text == "设 置": home_settings = child
	assert(home_settings != null)
	home_settings.pressed.emit()
	assert(game.settings_overlay.visible and not game.menu_panel.visible)
	assert(game.settings_overlay.get_child(0).get_global_rect().end.y <= game.get_viewport_rect().size.y)
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
	game.settings_tab_buttons[0].pressed.emit()
	assert(game.settings_tabs.current_tab == 0)
	assert(game.resolution_values.has(Vector2i(1280, 720)))
	assert(game.resolution_values.has(Vector2i(1600, 900)))
	assert(game.window_mode_choice.get_parent().name == "显示设置")
	assert(game.window_mode_choice.get_item_text(0) == "窗口化")
	assert(game.window_mode_choice.get_item_text(1) == "全屏")
	assert(game.window_mode_choice.selected == 0)
	assert(game.edge_scroll_toggle.button_pressed)
	assert(game.zoom_gesture_toggle.button_pressed)
	assert(game.projection_choice.get_parent().name == "显示设置")
	game.projection_choice.select(1)
	game.window_mode_choice.select(1)
	game.resolution_choice.select(game.resolution_values.find(Vector2i(1280, 720)))
	game.settings_tabs.current_tab = 1
	game.edge_scroll_toggle.button_pressed = false
	game.zoom_gesture_toggle.button_pressed = false
	game._close_settings()
	assert(game.edge_scroll_enabled, "return should discard unsaved control changes")
	assert(game.zoom_gesture_enabled and not game.selected_view_mode_25d, "return should discard unsaved view and gesture changes")
	assert(not game._window_is_fullscreen(), "return should discard unsaved window mode")
	assert(not game.settings_overlay.visible and game.menu_panel.visible)
	home_settings.pressed.emit()
	assert(game.window_mode_choice.selected == 0)
	assert(game.edge_scroll_toggle.button_pressed)
	assert(game.zoom_gesture_toggle.button_pressed and game.projection_choice.selected == 0)
	game.projection_choice.select(1)
	game.window_mode_choice.select(1)
	game.resolution_choice.select(game.resolution_values.find(Vector2i(1280, 720)))
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
	var saved_fullscreen: Variant = saved.get_value("display", "fullscreen", null) if save_result == OK else null
	var saved_window_size: Variant = saved.get_value("display", "window_size", null) if save_result == OK else null
	if had_settings:
		var previous_file := FileAccess.open(settings_path, FileAccess.WRITE)
		previous_file.store_buffer(old_settings)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))
	assert(save_result == OK and saved_edge_scroll == false and saved_zoom_gesture == false and saved_view == true)
	assert(saved_fullscreen == true and saved_window_size == Vector2i(1280, 720))
	assert(game._window_is_fullscreen())
	game._apply_window_mode(false, false)
	assert(not game._window_is_fullscreen())
	if DisplayServer.get_name() != "headless": assert(game.get_window().mode == Window.MODE_WINDOWED)
	assert(game.get_window().size == Vector2i(1280, 720))
	assert(not game.edge_scroll_enabled)
	assert(not game.zoom_gesture_enabled and game.selected_view_mode_25d)
	assert(game._edge_pan_direction(Vector2(2, 360), Vector2(1280, 720)) == Vector2.ZERO)
	game.edge_scroll_enabled = true
	assert(game._edge_pan_direction(Vector2(2, 360), Vector2(1280, 720)) == Vector2.LEFT)
	game.start_game("English", 12345)
	await process_frame
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
	assert(game.minimap.clip_contents)
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
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	game._input(escape)
	assert(game.paused and game.pause_overlay.visible and not game.settings_overlay.visible)
	game.free()
	print("DISPLAY_SETTINGS_OK")
	quit()

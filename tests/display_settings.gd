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
		if child is Button and child.text == "显 示 设 置": home_settings = child
	assert(home_settings != null)
	home_settings.pressed.emit()
	assert(game.settings_overlay.visible and not game.menu_panel.visible)
	assert(game.settings_overlay.get_child(0).get_global_rect().end.y <= game.get_viewport_rect().size.y)
	assert(game.resolution_values.has(Vector2i(1280, 720)))
	assert(game.resolution_values.has(Vector2i(1600, 900)))
	game._close_display_settings()
	assert(not game.settings_overlay.visible and game.menu_panel.visible)
	game.start_game("English", 12345)
	await process_frame
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
		if child is Button and child.text == "显示设置": pause_settings = child
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

extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	assert(game.menu_panel.visible)
	game._show_display_settings()
	assert(game.settings_overlay.visible and not game.menu_panel.visible)
	assert(game.resolution_values.has(Vector2i(1280, 720)))
	assert(game.resolution_values.has(Vector2i(1600, 900)))
	game._close_display_settings()
	assert(not game.settings_overlay.visible and game.menu_panel.visible)
	game.start_game("English", 12345)
	await process_frame
	assert(game.minimap.clip_contents)
	assert(game.hud_bottom.get_global_rect().end.y <= game.get_viewport_rect().size.y)
	assert(game.minimap.get_global_rect().end.y <= game.get_viewport_rect().size.y)
	game._apply_window_resolution(Vector2i(1600, 900), false)
	await process_frame
	assert(game.get_window().size == Vector2i(1600, 900))
	assert(game.hud_bottom.get_global_rect().end.y <= game.get_viewport_rect().size.y)
	assert(game.minimap.get_global_rect().end.y <= game.get_viewport_rect().size.y)
	game._set_paused(true)
	game._show_display_settings(true)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	game._input(escape)
	assert(game.paused and game.pause_overlay.visible and not game.settings_overlay.visible)
	game.free()
	print("DISPLAY_SETTINGS_OK")
	quit()

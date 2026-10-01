extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _capture() -> Image:
	for i in 3:
		await process_frame
		await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var output := args[0] if not args.is_empty() else "res://docs/weather-refinement"
	DirAccess.make_dir_recursive_absolute(output)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game("English", 12345)
	game.paused = true
	game.set_process(false)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_size = Vector2i(1280, 720)
	root.size = Vector2i(1280, 720)
	var weather: Node2D = game.weather
	var baseline := OS.get_environment("RTS_WEATHER_BASELINE")
	if not baseline.is_empty():
		game.weather.hide()
		weather = load(baseline).new()
		weather.z_index = -6
		game.add_child(weather)
		weather.setup(game, 12345, game.world_size)
		weather.set_process(false)
	var prefix := "before-" if not baseline.is_empty() else "after-"
	for iso in [false, true]:
		if game.view_mode_25d != iso: game._toggle_view_mode()
		game.camera.position = game.spawn_point_for(0)
		game.camera.zoom = Vector2(1.5, 0.75 if iso else 1.5)
		game.camera.force_update_scroll()
		weather.rain_active = true
		weather.elapsed = 3.0
		if weather is RtsWeather:
			weather._rain_time = 3.0
			weather.rain_intensity = 1.0
			weather._sync_intensity()
			weather._renderer.queue_redraw()
		else:
			weather.queue_redraw()
		var shot := await _capture()
		var name := prefix + ("25d" if iso else "2d") + ".png"
		assert(shot.save_png(output.path_join(name)) == OK)
		print("WEATHER_PREVIEW_OK: ", name)
	quit()

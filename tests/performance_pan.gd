extends SceneTree

# Run without --headless to measure camera frame pacing on the target display.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game("English", 4242)
	game.ai_controllers.clear()
	game.weather.weather_remaining = 1000.0
	for projection in ["2d", "2.5d"]:
		if game.view_mode_25d != (projection == "2.5d"): game._toggle_view_mode()
		game.camera.position = game.world_size * 0.5
		game.camera.force_update_scroll()
		for warmup in 30: await process_frame
		var intervals: Array[float] = []
		var previous: int = Time.get_ticks_usec()
		for frame in 120:
			game._move_camera_screen_delta(Vector2(4.0 if frame < 60 else -4.0, 0.0))
			await process_frame
			var now: int = Time.get_ticks_usec()
			intervals.append(float(now - previous) / 1000.0)
			previous = now
		intervals.sort()
		print("PAN_PERFORMANCE projection=%s median_ms=%.2f p95_ms=%.2f draw_calls=%d" % [projection, intervals[60], intervals[114], Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
	quit()

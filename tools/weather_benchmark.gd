extends SceneTree

# Time actual CanvasItem draw callbacks in a frozen, seeded match.
# An optional baseline script must have its class_name declaration removed.
const SAMPLES := 180
const WARMUP := 30

class ProfileRain extends RtsWeather:
	var draw_samples := PackedFloat64Array()
	func _draw_rain(item: CanvasItem) -> void:
		var start := Time.get_ticks_usec()
		super._draw_rain(item)
		draw_samples.append(Time.get_ticks_usec() - start)

func _initialize() -> void:
	call_deferred("_run")

func _stats(values: PackedFloat64Array) -> Dictionary:
	values.sort()
	return {"median_us": values[values.size() / 2], "p95_us": values[int(values.size() * 0.95)], "samples": values.size()}

func _frames(count: int, weather: Node2D) -> void:
	for i in count:
		if weather is RtsWeather:
			weather._rain_time += 1.0 / 120.0
			weather._renderer.queue_redraw()
		else:
			weather.elapsed += 1.0 / 120.0
			weather.queue_redraw()
		await process_frame
		# A frozen window may skip automatic redraws; force the benchmark sample.
		RenderingServer.force_draw(false)

func _run() -> void:
	var baseline := OS.get_environment("RTS_WEATHER_BASELINE")
	var versions: Array[String] = ["after"]
	var legacy_script: Script
	if not baseline.is_empty():
		var source := FileAccess.get_file_as_string(baseline)
		source = source.replace("func _draw() -> void:", "func _baseline_draw() -> void:")
		source += "\nvar draw_samples := PackedFloat64Array()\nfunc _draw() -> void:\n\tvar start := Time.get_ticks_usec()\n\t_baseline_draw()\n\tdraw_samples.append(Time.get_ticks_usec() - start)\n"
		var path := "res://build/weather-baseline/profile.gd"
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var source_file := FileAccess.open(path, FileAccess.WRITE)
		source_file.store_string(source)
		source_file.close()
		legacy_script = load(path)
		versions.push_front("before")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game("English", 12345)
	game.paused = true
	game.set_process(false)
	game.weather.hide()
	root.mode = Window.MODE_WINDOWED
	# Let the OS finish applying the startup display settings before resizing.
	for i in 6: await process_frame
	var results: Array[Dictionary] = []
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	for resolution in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		# Fix render size independently of macOS fullscreen/window animation.
		root.content_scale_size = resolution
		root.size = resolution
		await process_frame
		for iso in [false, true]:
			if game.view_mode_25d != iso: game._toggle_view_mode()
			game.camera.position = game.spawn_point_for(0)
			game.camera.zoom = Vector2(1.5, 0.75 if iso else 1.5)
			game.camera.force_update_scroll()
			for version in versions:
				var weather: Node2D = ProfileRain.new() if version == "after" else legacy_script.new()
				game.add_child(weather)
				weather.setup(game, 12345, game.world_size)
				weather.set_process(false)
				if weather is RtsWeather:
					weather.rain_intensity = 1.0
					weather._sync_intensity()
					weather._renderer.set_process(false)
				else:
					weather.z_index = -6
				await _frames(WARMUP, weather)
				weather.draw_samples.clear()
				await _frames(SAMPLES, weather)
				var result := _stats(weather.draw_samples)
				var viewport: Vector2 = weather.get_viewport_rect().size
				result.merge({"version": version, "resolution": "%dx%d" % [viewport.x, viewport.y], "view": "25d" if iso else "2d", "drops": (weather._far_segments.size() + weather._near_segments.size()) / 2 if weather is RtsWeather else weather.drops.size()})
				if weather is RtsWeather:
					RenderingServer.force_draw(false)
					weather.draw_samples.clear()
					weather._renderer.redraw_elapsed = 0.0
					game.paused = false
					for i in SAMPLES:
						weather._renderer._process(1.0 / 120.0)
						await process_frame
						RenderingServer.force_draw(false)
					game.paused = true
					result["redraws_per_180_ticks_at_120hz"] = weather.draw_samples.size()
					assert(weather.draw_samples.size() >= 89 and weather.draw_samples.size() <= 91, "rain should draw at 60 Hz with a stable 120 Hz camera")
				results.append(result)
				print("WEATHER_BENCHMARK: ", JSON.stringify(result))
				weather.free()
	var args := OS.get_cmdline_user_args()
	var output := args[0] if not args.is_empty() else "res://build/weather-benchmark.json"
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine": Engine.get_version_info().string, "seed": 12345, "scope": "CPU time of rain draw callback, not total frame time or GPU time", "results": results}, "\t") + "\n")
	file.close()
	print("WEATHER_BENCHMARK_OK: ", output)
	quit()

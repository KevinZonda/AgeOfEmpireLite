extends SceneTree

class Fog extends RefCounted:
	var explored := true
	func is_explored(_owner: int, _point: Vector2) -> bool: return explored

class Context extends Node2D:
	var started := true
	var paused := false
	var game_over := false
	var fog := Fog.new()

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var context := Context.new()
	root.add_child(context)
	var weather := RtsWeather.new()
	context.add_child(weather)
	weather.setup(context, 12345, Vector2(10000, 10000))
	weather.set_process(false)
	assert(weather.rain_active and weather.rain_intensity == 0.0)
	assert(not weather._renderer.visible and not weather._renderer.is_processing())
	weather._process(0.7)
	assert(is_equal_approx(weather.rain_intensity, 0.5), "rain must fade in rather than pop in")
	weather._process(0.7)
	assert(weather.rain_intensity == 1.0 and weather._renderer.visible)
	var cycle_rng := weather.rng.state
	for size in [Vector2(1280, 720), Vector2(3840, 2160)]:
		weather._resize_buffers(size)
		assert((weather._far_segments.size() + weather._near_segments.size()) / 2 <= RtsWeather.MAX_DROPS)
	assert(weather.rng.state == cycle_rng, "resize must not change future weather durations")
	weather._resize_buffers(Vector2(1280, 720))
	var tested := 0
	for iso in [false, true]:
		for zoom in [0.5, 1.0, 2.0]:
			var canvas := Transform2D(Vector2(0.70710678, 0.35355339) * zoom, Vector2(-0.70710678, 0.35355339) * zoom, Vector2.ZERO) if iso else Transform2D(0.0, Vector2.ONE * zoom, 0.0, Vector2.ZERO)
			canvas.origin = Vector2(640, 360) - canvas.basis_xform(Vector2(5000, 5000))
			weather._build_rain_segments(canvas.affine_inverse())
			for segments in [weather._far_segments, weather._near_segments]:
				for i in segments.size() / 2:
					var direction: Vector2 = segments[i * 2 + 1] - segments[i * 2]
					assert(direction.y > 0 and is_equal_approx(direction.x / direction.y, RtsWeather.WIND), "camera projection must not rotate or squash rain")
					tested += 1
	context.fog.explored = false
	weather._build_rain_segments(Transform2D.IDENTITY)
	for segments in [weather._far_segments, weather._near_segments]:
		for point in segments: assert(point == Vector2(-64, -64), "unexplored terrain must not show raindrops")
	var clock := weather._rain_time
	context.paused = true
	weather._renderer._process(1.0)
	weather._process(1.0)
	assert(weather._rain_time == clock and weather.rain_intensity == 1.0)
	context.paused = false
	weather.weather_remaining = 0.01
	weather._process(0.02)
	assert(not weather.rain_active and weather.rain_intensity > 0.0, "rain must fade out after the state changes")
	weather._process(1.4)
	assert(weather.rain_intensity == 0.0 and not weather._renderer.visible and not weather._renderer.is_processing(), "clear weather must stop presentation work")
	weather.weather_remaining = 0.01
	weather._process(0.02)
	assert(weather.rain_active and weather.weather_remaining >= 10.0 and weather.weather_remaining <= 16.0)
	weather.setup(context, 12345, Vector2(10000, 10000))
	assert(weather._rain_time == 0.0 and weather.rain_intensity == 0.0)
	assert(weather.z_index > 2808, "rain must draw above depth-sorted world actors")
	context.free()
	# The live match owns the controller at 30 Hz, but leaves the renderer at
	# display cadence. Check pause, hidden menu and restart on that actual tree.
	var match_game = load("res://scenes/main.tscn").instantiate()
	root.add_child(match_game)
	await process_frame
	match_game.start_game("English", 12345)
	match_game.set_process(false)
	var live_weather: RtsWeather = match_game.weather
	assert(match_game.simulation.actors.has(live_weather.get_instance_id()))
	assert(not live_weather.is_processing())
	assert(not match_game.simulation.actors.has(live_weather._renderer.get_instance_id()))
	live_weather._process(1.4)
	clock = live_weather._rain_time
	await process_frame
	await process_frame
	assert(live_weather._rain_time > clock, "presentation must continue between match simulation steps")
	match_game.paused = true
	clock = live_weather._rain_time
	await process_frame
	await process_frame
	assert(live_weather._rain_time == clock, "live pause must freeze the rain renderer")
	match_game.paused = false
	live_weather.hide()
	await process_frame
	await process_frame
	assert(live_weather._rain_time == clock, "hidden weather must not animate in the menu")
	match_game.start_game("English", 12345)
	assert(live_weather.visible and live_weather._rain_time == 0.0 and live_weather.rain_intensity == 0.0)
	match_game.free()
	print("WEATHER_OK projection/zoom probes=", tested, " fade, cycle, pause, restart, fog, bounded buffers, idle processing and live match integration")
	quit()

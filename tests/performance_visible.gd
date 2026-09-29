extends SceneTree

# Run without --headless on the target computer. Measures rendered frame pacing
# with 400 visible moving units in both map projections.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	seed(4242)
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game("English", 4242)
	game.ai_controllers.clear()
	var center: Vector2 = game.world_size * 0.5
	var army: Array[RtsUnit] = []
	for i in 400:
		var unit: RtsUnit = game.spawn_unit(0, "spearman", center + Vector2((i % 25 - 12) * 30, (i / 25 - 8) * 30))
		unit.order_stop()
		army.append(unit)
	game.camera.position = center
	game.camera.zoom = Vector2(0.85, 0.85)
	game.fog.update_visibility()
	var idle := OS.get_environment("RTS_BENCH_IDLE") == "1"
	var no_fog := OS.get_environment("RTS_BENCH_NO_FOG") == "1"
	if no_fog:
		game.fog.active = false
		game.fog.hide()
	var projections := ["2d", "2.5d"]
	var requested_projection := OS.get_environment("RTS_BENCH_PROJECTION")
	if requested_projection in projections: projections = [requested_projection]
	for projection in projections:
		if game.view_mode_25d != (projection == "2.5d"): game._toggle_view_mode()
		game.camera.position = center
		game.camera.force_update_scroll()
		if not idle: game.issue_group_order(army, center + Vector2(700, 35), true)
		for warmup in 20: await process_frame
		var intervals: Array[float] = []
		var previous := Time.get_ticks_usec()
		for frame in 90:
			await process_frame
			var now := Time.get_ticks_usec()
			intervals.append(float(now - previous) / 1000.0)
			previous = now
		intervals.sort()
		var median: float = intervals[intervals.size() / 2]
		var p95: float = intervals[mini(intervals.size() - 1, ceili(intervals.size() * 0.95))]
		print("VISIBLE_PERFORMANCE projection=%s units=400 idle=%s fog=%s median_ms=%.2f p95_ms=%.2f median_fps=%.1f p95_fps=%.1f" % [projection, str(idle), str(not no_fog), median, p95, 1000.0 / median, 1000.0 / p95])
	quit()

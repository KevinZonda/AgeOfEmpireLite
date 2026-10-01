extends SceneTree

# Isolate sustained independent movement from UI, AI and rendering work.
const Fixture = preload("res://tests/helpers/navigation_fixture.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := Fixture.new()
	root.add_child(game)
	game.initialize(Vector2(3000, 3000))
	game.navigation.route_budget_enabled = OS.get_environment("RTS_ROUTE_BUDGET") == "1"
	for i in 400:
		var unit := game.spawn_unit(Vector2(125 + (i % 20) * 75, 125 + (i / 20) * 130))
		unit.destination = unit.position + Vector2(1000, 0)
	game.navigation.invalidate_spatial_index()
	game.navigation.reset_profile()
	var durations: Array[int] = []
	var total_us := 0
	var first_step_us := 0
	var steady_peak_us := 0
	for step in 180:
		# Each iteration represents one simulation frame, including index rebuilds.
		game.navigation.invalidate_spatial_index()
		var started := Time.get_ticks_usec()
		game.navigation.tick_jobs(true, step)
		for unit in game.units: unit._move_toward(unit.destination, 1.0 / 30.0, 6.0)
		var elapsed := Time.get_ticks_usec() - started
		durations.append(elapsed)
		total_us += elapsed
		if step == 0: first_step_us = elapsed
		else: steady_peak_us = maxi(steady_peak_us, elapsed)
	durations.sort()
	print("PERFORMANCE_NAVIGATION units=400 steps=180 avg_ms=%.2f p95_ms=%.2f p99_ms=%.2f first_step_ms=%.2f steady_peak_ms=%.2f" % [total_us / 180000.0, durations[170] / 1000.0, durations[178] / 1000.0, first_step_us / 1000.0, steady_peak_us / 1000.0])
	print("ROUTE_BUDGET_PROFILE enabled=%s metrics=%s pending=%d" % [game.navigation.route_budget_enabled, JSON.stringify(game.navigation.route_jobs.metrics), game.navigation.route_jobs.pending.size()])
	print("NAV_PROFILE ", JSON.stringify(game.navigation.profile_snapshot()))
	var distances: Array[float] = []
	for unit in game.units: distances.append(unit.position.distance_to(unit.destination))
	distances.sort()
	print("NAVIGATION_PROGRESS sample_steps=180 remaining_median=%.1f remaining_max=%.1f" % [distances[distances.size() / 2], distances[-1]])
	# Keep the initial 180-tick performance sample above unchanged. Both
	# admission modes now stagger expensive first routes: the explicit queue
	# and the inline CPU cost cap. Verify bounded real completion separately.
	for step in range(180, 480):
		game.navigation.invalidate_spatial_index()
		game.navigation.tick_jobs(true, step)
		for unit in game.units: unit.orders.tick(unit, 1.0 / 30.0)
	var max_remaining := 0.0
	var idle_units := 0
	for unit in game.units:
		max_remaining = maxf(max_remaining, unit.position.distance_to(unit.destination))
		if unit.order == "idle" and unit.command_queue.is_empty(): idle_units += 1
	print("NAVIGATION_COMPLETION total_steps=480 idle=%d remaining_max=%.3f" % [idle_units, max_remaining])
	for unit in game.units:
		assert(unit.position.distance_to(unit.destination) <= 6.5, "all 400 routes must arrive within 480 ticks in either admission mode")
		assert(unit.order == "idle" and unit.command_queue.is_empty(), "arrival must finish the actual move order and queue")
	game.navigation.background_jobs.shutdown()
	game.free()
	quit()

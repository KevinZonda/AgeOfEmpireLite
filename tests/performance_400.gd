extends SceneTree

# Headless simulation benchmark. It reports CPU timings; rendering FPS still
# needs a visible build on the target machine.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	seed(4242)
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game("English", 4242)
	var army_size := int(OS.get_environment("RTS_BENCH_UNITS"))
	if army_size <= 0: army_size = 400
	army_size = clampi(army_size, 100, 400)
	var army: Array[RtsUnit] = []
	for i in army_size:
		var unit := RtsUnit.new()
		unit.position = Vector2(470 + (i % 25) * 25, 600 + (i / 25) * 25)
		game.add_child(unit)
		unit.setup(game, 0, "spearman")
		game.units.append(unit)
		unit.order_stop()
		army.append(unit)
	game.navigation.invalidate_spatial_index()
	var start := Time.get_ticks_usec()
	game.issue_group_order(army, Vector2(1660, 760))
	var command_us := Time.get_ticks_usec() - start
	var platoons: Array[RtsMovementGroup] = []
	for unit in army:
		if unit.movement_group != null and not platoons.has(unit.movement_group): platoons.append(unit.movement_group)
	start = Time.get_ticks_usec()
	for group in platoons: game.navigation.path_between(group.members[0].position, group.goal, group.members[0])
	var paths_us := Time.get_ticks_usec() - start
	start = Time.get_ticks_usec()
	for unit in army: game.navigation.nearest_walkable_point(unit.position + Vector2(650, 0), unit.radius(), unit, false)
	var destinations_us := Time.get_ticks_usec() - start
	start = Time.get_ticks_usec()
	for unit in army:
		if unit.movement_group != null: unit.movement_group.target_for(unit)
	var target_us := Time.get_ticks_usec() - start
	start = Time.get_ticks_usec()
	for unit in army:
		game.navigation.move_step(unit, unit.position + Vector2(3, 0))
	var collision_us := Time.get_ticks_usec() - start
	var total_us := 0
	var peak_us := 0
	var steps := maxi(12, int(OS.get_environment("RTS_BENCH_STEPS")))
	var frame_times: Array[int] = []
	game.navigation.reset_profile()
	for frame in steps:
		for group in platoons: group.last_frame = -1
		game.navigation.invalidate_spatial_index()
		start = Time.get_ticks_usec()
		for unit in army:
			if unit.order != "idle": unit._process(1.0 / 30.0)
		var frame_us := Time.get_ticks_usec() - start
		total_us += frame_us
		peak_us = maxi(peak_us, frame_us)
		frame_times.append(frame_us)
	start = Time.get_ticks_usec()
	game.fog.update_visibility()
	var fog_us := Time.get_ticks_usec() - start
	frame_times.sort()
	print("PERFORMANCE_%d command_ms=%.1f paths_ms=%.1f destinations_ms=%.1f target_ms=%.1f collision_ms=%.1f simulation_avg_ms=%.1f simulation_peak_ms=%.1f fog_ms=%.1f squads=%d steps=%d p95_ms=%.1f" % [army_size, command_us / 1000.0, paths_us / 1000.0, destinations_us / 1000.0, target_us / 1000.0, collision_us / 1000.0, total_us / (steps * 1000.0), peak_us / 1000.0, fog_us / 1000.0, platoons.size(), steps, frame_times[ceili(steps * 0.95) - 1] / 1000.0])
	if game.navigation.profiling_enabled: print("NAV_PROFILE ", JSON.stringify(game.navigation.profile_snapshot()))
	assert(platoons.size() >= ceili(army_size / 12.0) and platoons.size() <= army_size)
	quit()

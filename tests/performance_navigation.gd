extends SceneTree

# Isolate sustained independent movement from UI, AI and rendering work.
const Fixture = preload("res://tests/helpers/navigation_fixture.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := Fixture.new()
	root.add_child(game)
	game.initialize(Vector2(3000, 3000))
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
		for unit in game.units: unit._move_toward(unit.destination, 1.0 / 30.0, 6.0)
		var elapsed := Time.get_ticks_usec() - started
		durations.append(elapsed)
		total_us += elapsed
		if step == 0: first_step_us = elapsed
		else: steady_peak_us = maxi(steady_peak_us, elapsed)
	durations.sort()
	print("PERFORMANCE_NAVIGATION units=400 steps=180 avg_ms=%.2f p95_ms=%.2f p99_ms=%.2f first_step_ms=%.2f steady_peak_ms=%.2f" % [total_us / 180000.0, durations[170] / 1000.0, durations[178] / 1000.0, first_step_us / 1000.0, steady_peak_us / 1000.0])
	print("NAV_PROFILE ", JSON.stringify(game.navigation.profile_snapshot()))
	for unit in game.units:
		assert(unit.position.distance_to(unit.destination) < 530.0, "all units should make sustained forward progress")
	quit()

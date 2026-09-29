extends "res://tests/navigation_dense_poc.gd"

func _run() -> void:
	var game := fixture()
	var fort := building(game, Vector2(725, 525), Vector2(100, 100))
	for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		var guard := game.spawn_unit(fort.position + direction * 66.0)
		guard.order = "hold"
	var attacker := game.spawn_unit(Vector2(425, 525))
	attacker.order = "attack"
	var animal := resource(game, Vector2(1225, 825), 8.0)
	game.navigation.profiling_enabled = true
	game.navigation.reset_profile()
	var started := Time.get_ticks_usec()
	for step in 90:
		var previous := animal.position
		animal.position.x += 0.1
		game.navigation.resource_moved(animal, previous)
		attacker._move_toward(fort.position, 1.0 / 30.0, 66.0)
	var calls: int = game.navigation.profile_snapshot().get("path_to_range", {}).get("calls", 0)
	print("RETRY_POC steps=90 searches=%d elapsed_ms=%.3f" % [calls, (Time.get_ticks_usec() - started) / 1000.0])
	check(attacker.route.is_empty(), "occupied_attack_ring_has_no_route")
	check(calls <= 6, "distant_animal_must_not_cancel_failure_backoff", "searches=%d" % calls)
	# Resource movement must still rebuild collision geometry immediately.
	var revision: int = game.navigation.obstacle_revision
	var retry_revision: int = game.navigation.retry_obstacle_revision
	var previous := animal.position
	animal.position = Vector2(900, 525)
	game.navigation.resource_moved(animal, previous)
	game.navigation._ensure_current()
	check(game.navigation.obstacle_revision > revision, "animal_motion_invalidates_geometry")
	check(game.navigation.retry_obstacle_revision == retry_revision, "animal_motion_preserves_retry_revision")
	check(not game.navigation.can_occupy(animal.position, attacker.radius(), attacker, false), "moved_animal_still_blocks_collision")
	# An explicit terrain/building edit still interrupts the longest wait.
	attacker.route_retry = 3.0
	game.navigation.invalidate_obstacles()
	attacker._move_toward(fort.position, 1.0 / 30.0, 66.0)
	var new_calls: int = game.navigation.profile_snapshot().get("path_to_range", {}).get("calls", 0)
	check(new_calls == calls + 1, "structural_edit_wakes_failed_route")
	# Temporary crowding must clear under normal retries, even without a
	# structural edit or a change of command.
	for guard in game.units.duplicate():
		if guard == attacker: continue
		game.units.erase(guard)
		guard.free()
	game.navigation.invalidate_spatial_index()
	var arrived := false
	for step in 240:
		arrived = attacker._move_toward(fort.position, 1.0 / 30.0, 66.0)
		if arrived: break
	check(arrived, "cleared_attack_ring_eventually_reached")
	game.free()
	print("NAVIGATION_BATTLE_RETRY_POC checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)

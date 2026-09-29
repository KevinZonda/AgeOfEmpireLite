extends "res://tests/navigation_dense_poc.gd"

const Recovery = preload("res://scripts/world/navigation_recovery.gd")
const ParallelPoc = preload("res://tests/navigation_parallel_poc.gd")

func _drain(game) -> void:
	var deadline := Time.get_ticks_msec() + 15000
	while not game.navigation.background_jobs.pending.is_empty() or not game.navigation.background_jobs.active.is_empty():
		game.navigation.background_jobs.tick(game.navigation)
		if Time.get_ticks_msec() > deadline:
			check(false, "worker_deadline")
			game.navigation.background_jobs.shutdown()
			return
		await process_frame

func _submit(game, unit, goal: Vector2) -> void:
	unit.route_goal = goal
	game.navigation.background_jobs.request(unit, goal, Vector2.INF)
	game.navigation.background_jobs.tick(game.navigation)

func _run() -> void:
	Engine.max_fps = 120
	var lane = ParallelPoc.Lane.new(0, 1, "recovery")
	var game = lane.game
	# Six buildings, 80 soldiers, 150 resources including eight deer. Compare
	# against the original live-object implementation, not the new kernel itself.
	var serial_started := Time.get_ticks_usec()
	var reference := []
	for unit in game.units:
		reference.append(game.navigation._path_around_units(unit, Vector2(1375, 1115)))
	var serial_us := Time.get_ticks_usec() - serial_started
	var mismatches := 0
	var kernel_started := Time.get_ticks_usec()
	for i in game.units.size():
		var snapshot = Recovery.capture(game.navigation, game.units[i])
		if snapshot.recover(Vector2(1375, 1115)) != reference[i]: mismatches += 1
	var kernel_us := Time.get_ticks_usec() - kernel_started
	check(mismatches == 0, "snapshot_paths_match_live_oracle", "mismatches=%d" % mismatches)
	var grid_mismatch := 0
	for index in [0, 7, 20, 41]:
		var unit: RtsUnit = game.units[index]
		var old: AStarGrid2D = game.navigation._local_unit_grid(unit, 2, 96)
		var snapshot = Recovery.capture(game.navigation, unit)
		var fresh: AStarGrid2D = snapshot.make_grid(2, 96)
		for y in fresh.region.size.y:
			for x in fresh.region.size.x:
				if fresh.is_point_solid(Vector2i(x, y)) != old.is_point_solid(Vector2i(x, y)): grid_mismatch += 1
	check(grid_mismatch == 0, "snapshot_grid_matches_live_oracle", "cells=148996 mismatches=%d" % grid_mismatch)
	# Submit every soldier once, then keep advancing the main loop while the
	# bounded service does real production recovery work across frames.
	for unit in game.units:
		unit.route_goal = Vector2(1375, 1115)
		game.navigation.background_jobs.request(unit, unit.route_goal, Vector2.INF)
	var async_started := Time.get_ticks_usec()
	var ticks := 0
	var main_us := 0
	var max_tick_us := 0
	var async_results := {}
	while not game.navigation.background_jobs.pending.is_empty() or not game.navigation.background_jobs.active.is_empty():
		var tick_started := Time.get_ticks_usec()
		game.navigation.background_jobs.tick(game.navigation)
		for i in game.units.size():
			var output: Dictionary = game.navigation.background_jobs.take(game.units[i], Vector2(1375, 1115), game.navigation)
			if not output.is_empty(): async_results[i] = output.path
		var elapsed := Time.get_ticks_usec() - tick_started
		main_us += elapsed
		max_tick_us = maxi(max_tick_us, elapsed)
		ticks += 1
		await process_frame
	var async_us := Time.get_ticks_usec() - async_started
	var async_mismatch := 0
	for i in game.units.size():
		if not async_results.has(i) or async_results[i] != reference[i]: async_mismatch += 1
	check(async_mismatch == 0, "background_paths_match_live_oracle", "mismatches=%d" % async_mismatch)
	check(ticks > 1 and game.navigation.background_jobs.metrics.max_active <= 2, "bounded_workers_yield_main_loop")
	print("ASYNC_NAV_PROFILE ", JSON.stringify({"units": 80, "buildings": 6, "resources": 150, "deer": 8, "serial_us": serial_us, "snapshot_kernel_us": kernel_us, "async_wall_us": async_us, "main_work_us": main_us, "max_main_tick_us": max_tick_us, "ticks": ticks, "metrics": game.navigation.background_jobs.metrics}))
	game.navigation.background_jobs.shutdown()
	lane.dispose()
	# Terrain/owner/overlap cases exercise snapshot filtering as well as the
	# shared math helpers. Future changes must keep both input paths equivalent.
	for naval in [false, true]:
		for allied in [false, true]:
			game = fixture()
			game.world_map.cells.fill(RtsWorldMap.Terrain.WATER if naval else RtsWorldMap.Terrain.GRASS)
			var mover: RtsUnit = game.spawn_unit(Vector2(300.25, 300.125))
			mover.stats["tags"] = ["naval"] if naval else []
			mover.stats["radius"] = 11.7
			var gate := building(game, Vector2(350, 300), Vector2(30, 60))
			gate.kind = "stone_gate"
			gate.owner_id = mover.owner_id if allied else 1
			resource(game, mover.position + Vector2(15, 0), 12.3)
			game.spawn_unit(mover.position + Vector2(0, 20)).stats["radius"] = 10.6
			game.world_map.cells[5 * game.world_map.grid_size.x + 5] = RtsWorldMap.Terrain.MOUNTAIN
			var snapshot = Recovery.capture(game.navigation, mover)
			var old: AStarGrid2D = game.navigation._local_unit_grid(mover, 2, 48)
			var fresh: AStarGrid2D = snapshot.make_grid(2, 48)
			var differences := 0
			for y in fresh.region.size.y:
				for x in fresh.region.size.x:
					if fresh.is_point_solid(Vector2i(x, y)) != old.is_point_solid(Vector2i(x, y)): differences += 1
			check(differences == 0, "naval_gate_overlap_snapshot", "naval=%s allied=%s differences=%d" % [naval, allied, differences])
			game.free()
	# Lifecycle and live collision checks use a small, unambiguous open scene.
	game = fixture()
	var unit: RtsUnit = game.spawn_unit(Vector2(300, 300))
	var goal := Vector2(450, 300)
	_submit(game, unit, goal)
	unit._reset_route()
	await _drain(game)
	check(game.navigation.background_jobs.take(unit, goal, game.navigation).is_empty(), "new_order_discards_inflight_result")
	_submit(game, unit, goal)
	await _drain(game)
	game.navigation.refresh()
	check(game.navigation.background_jobs.take(unit, goal, game.navigation).is_empty(), "structural_revision_discards_result")
	_submit(game, unit, goal)
	await _drain(game)
	check(game.navigation.background_jobs.take(unit, goal + Vector2(80, 0), game.navigation).is_empty(), "moving_target_discards_result")
	_submit(game, unit, goal)
	await _drain(game)
	unit.position += Vector2(0, 80)
	check(game.navigation.background_jobs.take(unit, goal, game.navigation).is_empty(), "moved_unit_discards_result")
	unit.position = Vector2(300, 300)
	var deer := resource(game, Vector2(800, 500), 12.0)
	_submit(game, unit, goal)
	await _drain(game)
	var previous := deer.position
	deer.position = Vector2(324, 300)
	game.navigation.resource_moved(deer, previous)
	game.navigation._ensure_current()
	var before := unit.position
	check(game.navigation.background_jobs.take(unit, goal, game.navigation).is_empty(), "moving_deer_rechecks_live_collision")
	check(unit.position == before, "result_never_teleports_mover")
	deer.position = previous
	game.navigation.invalidate_spatial_index()
	_submit(game, unit, goal)
	unit.queue_free()
	await process_frame
	await _drain(game)
	check(game.navigation.background_jobs.current.is_empty() and game.navigation.background_jobs.completed.is_empty(), "dead_unit_releases_request")
	unit = game.spawn_unit(Vector2(300, 300))
	_submit(game, unit, goal)
	game.navigation.background_jobs.shutdown()
	check(game.navigation.background_jobs.active.is_empty() and game.navigation.background_jobs.current.is_empty(), "reset_joins_workers_and_drops_results")
	_submit(game, unit, goal)
	await _drain(game)
	check(not game.navigation.background_jobs.take(unit, goal, game.navigation).is_empty(), "service_reusable_after_reset")
	# Drive the actual unit integration: a stationary enemy blocks the direct
	# route. Recovery must be requested by _move_toward and applied safely.
	game.navigation.background_recovery_enabled = true
	var blocker: RtsUnit = game.spawn_unit(Vector2(340, 300))
	blocker.owner_id = 1
	blocker.order = "hold"
	unit._reset_route()
	unit.destination = goal
	unit.route_stalled_time = RtsUnit.ROUTE_STALL_SECONDS
	unit._move_toward(goal, 1.0 / 60.0, 6.0)
	check(game.navigation.background_jobs.has_request(unit), "real_unit_submits_background_recovery")
	var arrived := false
	var legal_steps := true
	var accepted_before: int = game.navigation.background_jobs.metrics.accepted
	for frame in 400:
		game.navigation.background_jobs.tick(game.navigation)
		var start := unit.position
		arrived = unit._move_toward(goal, 1.0 / 60.0, 6.0)
		if start.distance_to(unit.position) > unit.effective_speed() / 60.0 + 0.01: legal_steps = false
		if unit.position.distance_to(blocker.position) < unit.radius() + blocker.radius() - 0.01: legal_steps = false
		if arrived: break
		await process_frame
	check(arrived and game.navigation.background_jobs.metrics.accepted > accepted_before, "real_unit_follows_background_detour", str(unit.position))
	check(legal_steps, "background_detour_preserves_speed_and_collision")
	game.navigation.background_jobs.shutdown()
	# Cancellation must free queued slots, duplicate requests must coalesce,
	# and an oversized army must not allocate an unbounded backlog.
	var rejected := 0
	for i in 140:
		var queued: RtsUnit = game.spawn_unit(Vector2(700, 700))
		queued.route_goal = goal
		if not game.navigation.background_jobs.request(queued, goal, Vector2.INF): rejected += 1
	check(rejected == 12 and game.navigation.background_jobs.pending.size() == 128, "queue_capacity_is_bounded")
	var queued_unit: RtsUnit = game.units[-20]
	game.navigation.background_jobs.request(queued_unit, goal, Vector2.INF)
	check(game.navigation.background_jobs.pending.size() == 128, "duplicate_request_is_coalesced")
	queued_unit._reset_route()
	check(game.navigation.background_jobs.pending.size() == 127, "new_order_releases_queued_slot")
	game.navigation.background_jobs.shutdown()
	game.free()
	print("NAVIGATION_ASYNC_POC checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)

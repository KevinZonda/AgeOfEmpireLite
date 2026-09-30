extends "res://tests/navigation_dense_poc.gd"

func _run() -> void:
	Engine.max_fps = 0
	await process_frame
	await process_frame
	_test_cache_and_spatial_ownership()
	await _test_fifo_and_lifecycle()
	await _test_required_fine_connector()
	await _test_moving_queued_target()
	await _test_budgeted_movement()
	_test_bounded_admission()
	print("NAVIGATION_BOUNDARIES checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)

func _test_cache_and_spatial_ownership() -> void:
	var game := fixture()
	var nav := game.navigation
	var unit := game.spawn_unit(Vector2(125, 125))
	var tree := resource(game, Vector2(725, 525))
	var deer := resource(game, Vector2(225, 225), 8.0)
	deer.appearance = "deer"
	deer.wildlife_hp = 12.0
	nav._ensure_current()
	var grid := nav._grid_for(unit)
	nav._fine_grid_for(unit)
	nav.grid_components[grid.get_instance_id()] = PackedInt32Array([0])
	nav.grid_component_sizes[grid.get_instance_id()] = PackedInt32Array([1])
	nav.corner_graphs[Vector3.ZERO] = {}
	var revision := nav.obstacle_revision
	var structural := nav.retry_obstacle_revision
	nav.nearby_resources(deer.position, 1.0)
	var previous := deer.position
	deer.position += Vector2(160, 0)
	nav.resource_moved(deer, previous)
	nav._ensure_current()
	check(nav.obstacle_revision == revision and nav._grid_for(unit) == grid, "mobile_motion_preserves_geometry")
	check(nav.nearby_resources(deer.position, 1.0).has(deer) and not nav.nearby_resources(previous, 1.0).has(deer), "mobile_motion_updates_same_frame_bucket")
	previous = tree.position
	tree.position += Vector2(10, 0)
	nav.resource_moved(tree, previous)
	nav._ensure_current()
	check(nav.obstacle_revision == revision + 1 and nav.retry_obstacle_revision == structural, "resource_relocation_invalidates_geometry_without_waking_retries")
	# World fine grids survive as stale answers while workers rebuild them
	# (queries revalidate returned edges against live geometry). Every other
	# derived structure is dropped with its component labels.
	var rebuilds_dispatched := not nav.fine_grids.is_empty()
	for key in nav.fine_grids:
		var dispatched := false
		for job in nav.grid_builds.active:
			if job.key == key: dispatched = true
		if not dispatched: rebuilds_dispatched = false
	check(nav.clearance_grids.is_empty() and nav.local_fine_grids.is_empty() and nav.grid_components.is_empty() and nav.grid_component_sizes.is_empty() and nav.corner_graphs.is_empty(), "dropped_geometry_invalidates_together")
	if nav.async_geometry_enabled:
		check(rebuilds_dispatched, "fine_grids_rebuild_asynchronously")
	else:
		check(nav.fine_grids.is_empty(), "fine_grids_invalidate_synchronously")
	building(game, Vector2(900, 700), Vector2(55, 55))
	nav._ensure_current()
	check(nav.retry_obstacle_revision > structural, "structural_edit_wakes_failed_routes")
	structural = nav.retry_obstacle_revision
	deer.wildlife_hp = 0.0
	nav.refresh(false)
	check(nav.retry_obstacle_revision > structural, "wildlife_becoming_static_wakes_retry_revision")
	game.free()

func _test_fifo_and_lifecycle() -> void:
	var game := fixture()
	var nav := game.navigation
	nav.route_jobs.max_queries_per_frame = 1
	nav.route_jobs.budget_us = 1
	var units: Array[RtsUnit] = []
	var goals: Array[Vector2] = []
	var reference: Array[PackedVector2Array] = []
	for i in 9:
		var unit := game.spawn_unit(Vector2(125, 125 + i * 80))
		var goal := Vector2(725, unit.position.y)
		units.append(unit)
		goals.append(goal)
		reference.append(nav.path_to_range(unit.position, goal, 60.0, unit) if i % 2 else nav.path_between(unit.position, goal, unit))
		nav.request_route(unit, goal, 60.0, bool(i % 2))
		nav.request_route(unit, goal, 60.0, bool(i % 2))
	check(nav.route_jobs.pending.size() == 9, "route_requests_coalesce")
	for i in 9:
		nav.route_jobs.tick(nav)
		var finished: int = nav.route_jobs.metrics.finished
		nav.route_jobs.tick(nav)
		check(nav.route_jobs.metrics.finished == finished and finished == i + 1, "one_dispatch_budget_per_frame_%d" % i)
		var result := nav.take_route(units[i], goals[i], 60.0, bool(i % 2))
		check(not result.is_empty() and result.path == reference[i], "fifo_route_matches_sync_oracle_%d" % i)
		await process_frame
	var queued_first := units[0]
	var queued_second := units[1]
	nav.request_route(queued_first, goals[0], 6.0, false)
	nav.request_route(queued_second, goals[1], 6.0, false)
	nav.request_route(queued_first, goals[0] + Vector2(100, 0), 6.0, false)
	nav.route_jobs.tick(nav)
	check(not nav.take_route(queued_first, goals[0] + Vector2(100, 0), 6.0, false).is_empty(), "moving_pending_target_retains_fifo_priority")
	nav.cancel_route_request(queued_second)
	await process_frame
	var drifting := units[0]
	nav.request_route(drifting, goals[0], 6.0, false)
	nav.request_route(drifting, goals[0] + Vector2(5, 0), 6.0, false)
	check(nav.route_jobs.pending.size() == 1, "small_target_drift_preserves_queue_position")
	nav.route_jobs.tick(nav)
	check(not nav.take_route(drifting, goals[0] + Vector2(5, 0), 6.0, false).is_empty(), "small_target_drift_accepts_completed_route")
	await process_frame
	var unit := units[0]
	var goal := goals[0]
	nav.request_route(unit, goal, 6.0, false)
	unit._reset_route()
	check(nav.route_jobs.pending.is_empty() and not nav.route_jobs.has_request(unit), "new_command_releases_route_request")
	nav.request_route(unit, goal, 6.0, false)
	nav.route_jobs.tick(nav)
	nav.invalidate_obstacles()
	check(nav.take_route(unit, goal, 6.0, false).is_empty(), "structural_change_discards_completed_route")
	await process_frame
	nav.request_route(unit, goal, 6.0, false)
	nav.route_jobs.tick(nav)
	check(nav.take_route(unit, goal + Vector2(50, 0), 6.0, false).is_empty(), "retarget_discards_completed_route")
	await process_frame
	nav.request_route(unit, goal, 6.0, false)
	unit.queue_free()
	await process_frame
	nav.route_jobs.tick(nav)
	check(nav.route_jobs.current.is_empty(), "dead_unit_releases_route_request")
	nav.request_route(units[1], goals[1], 6.0, false)
	nav.route_budget_enabled = true
	nav.tick_jobs(false)
	check(nav.route_jobs.pending.size() == 1 and nav.route_jobs.completed.is_empty(), "paused_match_does_not_dispatch_routes")
	nav.shutdown_jobs()
	check(nav.route_jobs.pending.is_empty() and nav.route_jobs.current.is_empty() and nav.route_jobs.completed.is_empty(), "reset_drops_all_route_requests")
	nav.request_route(units[1], goals[1], 6.0, false)
	nav.route_jobs.tick(nav)
	check(not nav.take_route(units[1], goals[1], 6.0, false).is_empty(), "route_service_reusable_after_reset")
	game.free()

func _test_required_fine_connector() -> void:
	var game := Fixture.new()
	root.add_child(game)
	game.initialize(Vector2(2400, 2400))
	var nav := game.navigation
	nav.route_budget_enabled = true
	# The dense house lattice blocks coarse attachments; the fine path must
	# enter the narrow strip above the house at (1150, 550).
	for lane in 12:
		for col in 8:
			building(game, Vector2(550 + col * 100, roundf((200 + lane * 90) / 25.0) * 25.0), Vector2(48, 46))
	var unit := game.spawn_unit(Vector2(1093.740, 528.5929))
	unit.stats["radius"] = 10.0
	unit.stats["speed"] = 220.0
	var goal := Vector2(1710, 560)
	unit.destination = goal
	var reference := nav.path_between(unit.position, goal, unit)
	check(reference.size() > 1 and unit.position.distance_to(reference[0]) < 1.0 and nav._static_segment_clear(unit.position, reference[0], unit.radius(), unit) and not nav._static_segment_clear(unit.position, reference[1], unit.radius(), unit), "fine_route_requires_subpixel_corner_connector", str(reference))
	nav.request_route(unit, goal, 6.0, false)
	nav.tick_jobs(true, 0)
	var output := nav.take_route(unit, goal, 6.0, false)
	check(not output.is_empty() and output.path.size() == reference.size() + 1 and output.path[0] == unit.position and output.path[1] == reference[0], "budgeted_result_preserves_required_connector")
	var arrived := false
	var legal := true
	for frame in range(1, 260):
		nav.tick_jobs(true, frame)
		var previous := unit.position
		arrived = unit._move_toward(goal, 0.05, 6.0)
		if previous.distance_to(unit.position) > unit.effective_speed() * 0.05 + 0.01 or not nav.can_occupy(unit.position, unit.radius(), unit, false, false): legal = false
		if arrived: break
	check(arrived, "budgeted_movement_follows_required_connector_and_arrives", str(unit.position))
	check(legal, "required_connector_preserves_speed_and_building_clearance")
	nav.shutdown_jobs()
	game.free()
	await process_frame

func _test_moving_queued_target() -> void:
	var game := fixture()
	var nav := game.navigation
	nav.route_jobs.max_queries_per_frame = 1
	var units: Array[RtsUnit] = []
	for i in 12:
		var unit := game.spawn_unit(Vector2(125, 125 + i * 55))
		units.append(unit)
		nav.request_route(unit, Vector2(725, unit.position.y), 6.0, false)
	var tail := units[-1]
	var output: Dictionary = {}
	var final_target := Vector2.ZERO
	for frame in 12:
		final_target = Vector2(725 + frame * 8, tail.position.y)
		nav.request_route(tail, final_target, 6.0, false)
		nav.route_jobs.tick(nav)
		output = nav.take_route(tail, final_target, 6.0, false)
		if not output.is_empty(): break
		await process_frame
	check(not output.is_empty() and output.path[-1] == final_target and nav.route_jobs.metrics.finished == 12, "slowly_moving_tail_target_does_not_starve_fifo")
	nav.shutdown_jobs()
	await process_frame
	# A small legal displacement while waiting must not make the unit backtrack
	# to a captured origin; the validated next advancing segment is retained.
	var mover := units[0]
	var goal := Vector2(725, mover.position.y)
	nav.request_route(mover, goal, 6.0, false)
	nav.route_jobs.tick(nav)
	var previous := mover.position
	mover.position += Vector2(10, 0)
	nav.unit_moved(mover, previous)
	output = nav.take_route(mover, goal, 6.0, false)
	check(not output.is_empty() and output.path[0] == mover.position and output.path[-1] == goal, "accepted_route_rebases_origin_without_backtracking")
	nav.route_budget_enabled = true
	mover.destination = goal
	nav.request_route(mover, goal, 6.0, false)
	previous = mover.position
	mover.position = goal
	nav.unit_moved(mover, previous)
	check(mover._move_toward(goal, 0.05, 6.0) and not nav.route_jobs.has_request(mover), "reaching_range_releases_unconsumed_request")
	nav.shutdown_jobs()
	game.free()

func _test_budgeted_movement() -> void:
	var game := fixture()
	var nav := game.navigation
	nav.route_budget_enabled = true
	nav.route_jobs.max_queries_per_frame = 1
	for y in 15: block(game, 12, y)
	nav.invalidate_obstacles()
	var units: Array[RtsUnit] = []
	for i in 12:
		var unit := game.spawn_unit(Vector2(225, 125 + i * 50))
		unit.stats["speed"] = 220.0
		unit.destination = Vector2(1000, 125 + i * 50)
		if i % 2: unit.order = "attack"
		units.append(unit)
		unit._move_toward(unit.destination, 0.05, 40.0 if i % 2 else 6.0)
		check(unit.route_failures == 0 and unit.route_retry == 0.0 and unit.route.is_empty(), "queue_wait_is_not_failure_%d" % i)
	var arrived: Dictionary = {}
	var legal := true
	for frame in 400:
		nav.tick_jobs()
		for i in units.size():
			if arrived.has(i): continue
			var unit := units[i]
			var previous := unit.position
			if unit._move_toward(unit.destination, 0.05, 40.0 if i % 2 else 6.0): arrived[i] = true
			if previous.distance_to(unit.position) > unit.effective_speed() * 0.05 + 0.01: legal = false
			if not nav._terrain_can_occupy(unit.position, unit.radius(), false): legal = false
		if arrived.size() == units.size(): break
		await process_frame
	check(arrived.size() == units.size(), "budgeted_move_and_range_eventually_arrive", "arrived=%d/%d" % [arrived.size(), units.size()])
	check(legal, "budgeted_movement_preserves_speed_and_terrain")
	check(nav.route_jobs.metrics.finished >= units.size(), "ordinary_and_range_queries_use_budgeted_service")
	nav.shutdown_jobs()
	game.free()

func _test_bounded_admission() -> void:
	var game := fixture()
	var rejected := 0
	for i in 513:
		var unit := game.spawn_unit(Vector2(125, 125))
		if not game.navigation.request_route(unit, Vector2(725, 125), 6.0, false): rejected += 1
	check(rejected == 1 and game.navigation.route_jobs.pending.size() == 512, "route_queue_capacity_bounded")
	game.navigation.shutdown_jobs()
	game.free()

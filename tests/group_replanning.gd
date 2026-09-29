extends "res://tests/navigation_dense_poc.gd"

func _run() -> void:
	var game := fixture()
	game.navigation.profiling_enabled = true
	var army: Array[RtsUnit] = []
	for i in 4: army.append(game.spawn_unit(Vector2(225, 425 + i * 35)))
	var group := RtsMovementGroup.new(game, army, Vector2(1100, 450))
	for unit in army: unit.issue_command("group_move", group.requested_goal, null, false, group)
	check(not group.route.is_empty(), "shared_route_created")
	var original_route := group.route.duplicate()
	var original_destinations := group.final_destinations.duplicate()
	var distant := resource(game, Vector2(900, 850), 22)
	game.navigation.reset_profile()
	for i in 8:
		var previous := distant.position
		distant.position.x += 10.0
		game.navigation.resource_moved(distant, previous)
		group.last_frame = -1
		group.target_for(army[0])
	check(game.navigation.profile_snapshot().get("path_between", {}).get("calls", 0) == 0, "distant_motion_reuses_shared_route")
	check(group.route == original_route and group.final_destinations == original_destinations, "distant_motion_preserves_route_and_slots")
	check(group.last_obstacle_revision == game.navigation.obstacle_revision, "shared_route_tracks_verified_revision")
	# A new building across the route must still trigger an immediate detour.
	building(game, Vector2(675, 450), Vector2(90, 170))
	game.navigation.reset_profile()
	group.last_frame = -1
	group.target_for(army[0])
	check(game.navigation.profile_snapshot().get("path_between", {}).get("calls", 0) > 0, "construction_replans_blocked_shared_route")
	check(safe_route(game, army[0], group.route), "shared_detour_respects_new_building")
	# Empty routes need to retry after the map opens up.
	group.route.clear()
	game.navigation.invalidate_obstacles()
	group.last_frame = -1
	group.target_for(army[0])
	check(not group.route.is_empty(), "empty_shared_route_retries_on_change")
	# A resource on the clicked goal shifts the fallback; its removal restores it.
	var blocker := resource(game, group.requested_goal, 30)
	group.last_frame = -1
	group.target_for(army[0])
	check(group.goal.distance_to(group.requested_goal) > 1.0, "blocked_shared_goal_uses_fallback")
	game.resources.erase(blocker)
	blocker.free()
	game.navigation.invalidate_obstacles()
	group.last_frame = -1
	group.target_for(army[0])
	check(group.goal == group.requested_goal, "cleared_shared_goal_restored")
	game.free()
	print("GROUP_REPLANNING checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)

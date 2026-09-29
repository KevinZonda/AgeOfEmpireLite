extends "res://tests/navigation_dense_poc.gd"

class CountedNavigation extends RtsNavigation:
	var flood_cells := 0
	var astar_queries := 0
	func _point_path(grid: AStarGrid2D, start: Vector2i, end: Vector2i) -> PackedVector2Array:
		astar_queries += 1
		return super._point_path(grid, start, end)
	func _local_reachable_cells(grid: AStarGrid2D, start: Vector2i) -> Array[Vector2i]:
		var cells := super._local_reachable_cells(grid, start)
		flood_cells += cells.size()
		return cells

func _run() -> void:
	var game := fixture()
	var nav := CountedNavigation.new(game, game.world_map)
	game.navigation = nav
	var unit := game.spawn_unit(Vector2(725, 525))
	unit.route_failures = 3
	var blocker := game.spawn_unit(unit.position + Vector2(24, 0))
	blocker.order = "hold"
	blocker.owner_id = 1
	var started := Time.get_ticks_usec()
	for attempt in 10:
		check(nav.path_around_units(unit, blocker.position).is_empty(), "occupied_waypoint_has_no_improving_exit")
	print("GOAL_POC requests=10 elapsed_ms=%.3f flood_cells=%d" % [(Time.get_ticks_usec() - started) / 1000.0, nav.flood_cells])
	check(nav.flood_cells == 0, "no_flood_when_all_candidate_exits_are_useless")
	# Compare the perimeter/disk enumeration against the former whole-grid
	# predicate, including clamped targets beyond the local window.
	for resolution in [Vector2i(8, 24), Vector2i(2, 96)]:
		var grid := nav._local_unit_grid(unit, resolution.x, resolution.y)
		for offset in [Vector2(24, 0), Vector2(110, 75), Vector2(-900, 800)]:
			var target: Vector2 = unit.position + offset
			var local := Vector2i(((target - grid.offset) / grid.cell_size).round()).clamp(Vector2i.ZERO, grid.region.size - Vector2i.ONE)
			var expected := {}
			for y in grid.region.size.y:
				for x in grid.region.size.x:
					var cell := Vector2i(x, y)
					if cell != local and x != 0 and y != 0 and x != grid.region.size.x - 1 and y != grid.region.size.y - 1 and cell.distance_squared_to(local) > 9: continue
					if grid.is_point_solid(cell) or grid.get_point_position(cell).distance_to(target) >= unit.position.distance_to(target) - 4.0: continue
					expected[cell] = true
			check(nav._local_exit_candidates(grid, unit.position, target) == expected, "exit_candidates_match_exhaustive_scan")
	var goal := unit.position + Vector2(180, 0)
	var path := nav.path_around_units(unit, goal)
	check(path.size() > 2 and safe_route(game, unit, path), "farther_goal_still_detours_around_blocker")
	game.free()
	print("NAVIGATION_BATTLE_GOAL_POC checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)

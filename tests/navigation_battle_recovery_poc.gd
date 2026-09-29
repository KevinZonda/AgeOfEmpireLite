extends "res://tests/navigation_dense_poc.gd"

func _run() -> void:
	var game := fixture()
	var unit := game.spawn_unit(Vector2(725, 525))
	unit.route_failures = 3
	var guards: Array[RtsUnit] = []
	for i in 8:
		var guard := game.spawn_unit(unit.position + Vector2.from_angle(i * TAU / 8.0) * 25.0)
		guard.order = "hold"
		guard.owner_id = 1
		guards.append(guard)
	var target := unit.position + Vector2(220, 0)
	var started := Time.get_ticks_usec()
	for attempt in 10:
		check(game.navigation.path_around_units(unit, target).is_empty(), "surrounded_unit_has_no_escape")
	print("RECOVERY_POC trapped_requests=10 elapsed_ms=%.3f" % ((Time.get_ticks_usec() - started) / 1000.0))
	if game.navigation.has_method("_local_reachable_cells"):
		for resolution in [Vector2i(8, 24), Vector2i(2, 48), Vector2i(8, 48), Vector2i(8, 96), Vector2i(2, 96)]:
			var grid := game.navigation._local_unit_grid(unit, resolution.x, resolution.y)
			var start := Vector2i(resolution.y, resolution.y)
			grid.set_point_solid(start, false)
			var labels := game.navigation._components_for(grid, false)
			var component: int = labels[start.y * grid.region.size.x + start.x]
			var reachable: Array[Vector2i] = game.navigation._local_reachable_cells(grid, start)
			var expected := 0
			for label in labels:
				if label == component: expected += 1
			check(reachable.size() == expected, "reachable_set_matches_full_components")
			for cell in reachable:
				check(labels[cell.y * grid.region.size.x + cell.x] == component, "reachable_cell_is_connected")
			check(reachable.size() < 100, "trapped_search_only_visits_small_pocket")
	# Opening the eastern half of the ring must immediately restore movement.
	for index in [0, 1, 7]:
		game.units.erase(guards[index])
		guards[index].free()
	game.navigation.invalidate_spatial_index()
	var path := game.navigation.path_around_units(unit, target)
	check(path.size() >= 2 and safe_route(game, unit, path), "opened_ring_has_safe_escape")
	game.free()
	print("NAVIGATION_BATTLE_RECOVERY_POC checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)

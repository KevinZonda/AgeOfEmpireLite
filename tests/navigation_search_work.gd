extends "res://tests/navigation_dense_poc.gd"

# Count search work on real geometry, while checking the resulting destinations.
class MeasuredNavigation extends RtsNavigation:
	var coarse_requests: Dictionary = {}
	var refinements := 0

	func _path_between(from: Vector2, to: Vector2, unit: RtsUnit, smooth: bool, allow_fine := true) -> PackedVector2Array:
		coarse_requests[to] = coarse_requests.get(to, 0) + 1
		return super._path_between(from, to, unit, smooth, allow_fine)

	func _fine_static_path(from: Vector2, to: Vector2, unit: RtsUnit) -> PackedVector2Array:
		refinements += 1
		return super._fine_static_path(from, to, unit)

func _run() -> void:
	_test_direct_destination_work()
	_test_range_refinement_work()
	print("NAVIGATION_SEARCH_WORK checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)

func _test_direct_destination_work() -> void:
	var game := fixture()
	var unit := game.spawn_unit(Vector2(225, 525))
	var goal := Vector2(925, 525)
	game.navigation.profiling_enabled = true
	game.navigation.reset_profile()
	var point := game.navigation.nearest_walkable_point(goal, unit.radius(), unit, true)
	var calls: int = game.navigation.profile_snapshot().get("can_occupy", {}).get("calls", 0)
	check(point == goal, "direct_destination_preserved")
	check(calls < 10, "direct_destination_avoids_map_raster", "occupancy_checks=%d" % calls)
	# A later obstacle must still invalidate the straight route and force a detour.
	building(game, Vector2(575, 525), Vector2(100, 200))
	var path := game.navigation.path_between(unit.position, goal, unit)
	check(path.size() > 2 and safe_route(game, unit, path), "lazy_grid_observes_new_obstacle")
	game.free()

func _test_range_refinement_work() -> void:
	var game := fixture()
	for y in game.world_map.grid_size.y: block(game, 12, y)
	var measured := MeasuredNavigation.new(game, game.world_map)
	game.navigation = measured
	measured.refresh()
	var unit := game.spawn_unit(Vector2(225, 525))
	var goal := Vector2(925, 525)
	var path := measured.path_to_range(unit.position, goal, 50.0, unit)
	check(path.is_empty() and measured.refinements > 0, "sealed_range_exhausts_refinement")
	var most_requests := 0
	for count in measured.coarse_requests.values(): most_requests = maxi(most_requests, count)
	check(most_requests == 1, "range_refinement_does_not_repeat_coarse_search", "maximum_requests_per_destination=%d" % most_requests)
	# Opening the wall must restore reachability after the failed cached search.
	game.world_map.cells[10 * game.world_map.grid_size.x + 12] = RtsWorldMap.Terrain.GRASS
	measured.refresh()
	path = measured.path_to_range(unit.position, goal, 50.0, unit)
	check(safe_route(game, unit, path) and path[path.size() - 1].distance_to(goal) <= 50.5, "opened_range_is_reachable")
	game.free()

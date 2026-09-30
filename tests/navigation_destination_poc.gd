extends "res://tests/navigation_dense_poc.gd"

class CountedNavigation extends RtsNavigation:
	var origin_connections := 0
	var refinements := 0
	func _find_connected_cell(point: Vector2, grid: AStarGrid2D, radius: float, unit: RtsUnit) -> Vector2i:
		if point == unit.position: origin_connections += 1
		return super._find_connected_cell(point, grid, radius, unit)
	func _fine_static_path(from: Vector2, to: Vector2, unit: RtsUnit, corner_fallback := true) -> PackedVector2Array:
		refinements += 1
		return super._fine_static_path(from, to, unit, corner_fallback)

func _run() -> void:
	_test_isolated_source()
	_test_isolated_fine_component()
	_test_enclosed_corner_direction()
	_test_query_lifetime()
	print("NAVIGATION_DESTINATION_POC checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)

func _test_isolated_source() -> void:
	var game := fixture()
	var nav := CountedNavigation.new(game, game.world_map)
	game.navigation = nav
	# A legal 2px pocket contains the unit's center but no grid center.
	# There is no path out, even though most of the world is open.
	building(game, Vector2(185, 223), Vector2(50, 150))
	building(game, Vector2(261, 223), Vector2(50, 150))
	building(game, Vector2(223, 185), Vector2(150, 50))
	building(game, Vector2(223, 261), Vector2(150, 50))
	var unit := game.spawn_unit(Vector2(223, 223))
	check(nav.can_occupy(unit.position, unit.radius(), unit, false, false), "pocket_source_is_legal")
	var goal := Vector2(1225, 725)
	var result := nav.nearest_walkable_point(goal, unit.radius(), unit, true)
	check(result == unit.position, "failed_destination_holds_position", str(result))
	check(nav.origin_connections <= 1, "source_attachment_computed_once", str(nav.origin_connections))
	check(nav.destination_query_unit == null and nav.destination_origin_cells.is_empty() and nav.range_query_segments.is_empty(), "destination_query_releases_caches")
	# Overlap escape permits this source, but strict corner routing does not.
	# Once its fine connectivity fails, other components need no full search.
	resource(game, Vector2(213, 223), 2.0)
	nav.refinements = 0
	result = nav.nearest_walkable_point(goal, unit.radius(), unit, true)
	check(result == unit.position, "overlapped_isolated_source_holds_position")
	check(nav.refinements <= 1, "isolated_source_does_not_refine_every_destination", str(nav.refinements))
	# Opening the pocket must immediately allow the same request to succeed.
	for node in game.buildings: node.free()
	game.buildings.clear()
	nav.invalidate_obstacles()
	result = nav.nearest_walkable_point(goal, unit.radius(), unit, true)
	check(result == goal and safe_route(game, unit, nav.path_between(unit.position, result, unit)), "opened_pocket_observed_on_next_query")
	game.free()

func _test_isolated_fine_component() -> void:
	var game := fixture()
	var nav := CountedNavigation.new(game, game.world_map)
	game.navigation = nav
	building(game, Vector2(175, 223), Vector2(50, 150))
	building(game, Vector2(261, 223), Vector2(50, 150))
	building(game, Vector2(223, 175), Vector2(150, 50))
	building(game, Vector2(223, 273), Vector2(150, 50))
	var unit := game.spawn_unit(Vector2(223, 223))
	resource(game, Vector2(233, 223), 2.0)
	check(nav.can_occupy(unit.position, unit.radius(), unit, false), "fine_pocket_overlap_can_escape")
	check(not nav.can_occupy(unit.position, unit.radius(), unit, false, false), "fine_pocket_cannot_use_strict_corners")
	var result := nav.nearest_walkable_point(Vector2(1225, 725), unit.radius(), unit, true)
	check(result == unit.position, "disconnected_fine_component_holds_position")
	check(not nav.grid_components.is_empty(), "fine_pocket_exercises_component_filter")
	check(nav.refinements <= 1, "fine_component_reused_for_all_destinations", str(nav.refinements))
	game.free()

func _test_query_lifetime() -> void:
	var game := fixture()
	var unit := game.spawn_unit(Vector2(225, 525))
	var goal := Vector2(925, 525)
	check(game.navigation.nearest_walkable_point(goal, unit.radius(), unit, true) == goal, "destination_direct_fast_path")
	var occupant := game.spawn_unit(goal)
	var shifted := game.navigation.nearest_walkable_point(goal, unit.radius(), unit, true)
	check(shifted != goal and shifted.distance_to(occupant.position) >= unit.radius() + occupant.radius(), "new_unit_occupancy_is_not_cached")
	game.units.erase(occupant)
	occupant.free()
	game.navigation.invalidate_spatial_index()
	check(game.navigation.nearest_walkable_point(goal, unit.radius(), unit, true) == goal, "removed_unit_occupancy_is_not_cached")
	game.free()

func _test_enclosed_corner_direction() -> void:
	var game := fixture()
	var nav := CountedNavigation.new(game, game.world_map)
	game.navigation = nav
	var goal := Vector2(900, 525)
	building(game, goal + Vector2(-60, 0), Vector2(20, 140))
	var door := building(game, goal + Vector2(60, 0), Vector2(20, 140))
	building(game, goal + Vector2(0, -60), Vector2(140, 20))
	building(game, goal + Vector2(0, 60), Vector2(140, 20))
	var unit := game.spawn_unit(Vector2(225, 525))
	check(nav.path_between(unit.position, goal, unit).is_empty(), "enclosed_goal_has_no_route")
	check(nav._corner_search_from_target(unit.position, goal, unit), "corner_search_starts_in_smaller_component")
	game.buildings.erase(door)
	door.free()
	nav.refresh()
	check(nav.grid_component_sizes.is_empty(), "component_sizes_invalidated_by_opening")
	var path := nav._obstacle_corner_path(unit.position, goal, unit)
	check(safe_route(game, unit, path) and path[0] == unit.position and path[-1] == goal, "opened_corner_route_keeps_original_direction")
	game.free()

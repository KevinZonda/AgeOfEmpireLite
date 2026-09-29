extends "res://tests/navigation_dense_poc.gd"

class CountedNavigation extends RtsNavigation:
	var labeled_cells := 0
	var native_searches := 0
	func _components_for(grid: AStarGrid2D, cache := true) -> PackedInt32Array:
		if not cache or not grid_components.has(grid.get_instance_id()): labeled_cells += grid.region.size.x * grid.region.size.y
		return super._components_for(grid, cache)
	func _point_path(grid: AStarGrid2D, from: Vector2i, to: Vector2i) -> PackedVector2Array:
		native_searches += 1
		return super._point_path(grid, from, to)

func _run() -> void:
	var game := fixture()
	game.world_map.free()
	game.initialize(Vector2(3200, 2400))
	var nav := CountedNavigation.new(game, game.world_map)
	game.navigation = nav
	var mover := game.spawn_unit(Vector2(205, 205))
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(0, 0, 320, 240)
	grid.cell_size = Vector2.ONE * 10
	grid.offset = Vector2.ONE * 5
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	var started := Time.get_ticks_usec()
	var path := nav._safe_point_path(grid, Vector2i(20, 20), Vector2i(40, 20), mover)
	var open_us := Time.get_ticks_usec() - started
	check(not path.is_empty() and safe_route(game, mover, path), "short_fine_route_is_safe")
	print("RANGE_STALL_OPEN ", JSON.stringify({"us": open_us, "labeled_cells": nav.labeled_cells, "native_searches": nav.native_searches}))
	check(nav.labeled_cells == 0, "reachable_short_route_does_not_flood_whole_world")
	# Once a native search actually fails, connectivity should still reject
	# subsequent disconnected goals without repeating exhaustive native A*.
	grid.fill_solid_region(Rect2i(30, 0, 1, 240))
	nav.grid_components.clear()
	nav.native_searches = 0
	check(nav._safe_point_path(grid, Vector2i(20, 20), Vector2i(40, 20), mover).is_empty(), "sealed_wall_is_unreachable")
	var probes := nav.native_searches
	check(nav._safe_point_path(grid, Vector2i(20, 20), Vector2i(50, 30), mover).is_empty(), "second_disconnected_goal_is_unreachable")
	check(nav.native_searches == probes, "failed_component_is_reused")
	game.free()
	print("NAVIGATION_RANGE_STALL_POC checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)

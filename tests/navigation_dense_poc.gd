extends "res://tests/navigation_poc.gd"

# Witness routes prove these are reachable, not legitimately sealed targets.
func building(game: Fixture, point: Vector2, dimensions: Vector2) -> RtsBuilding:
	var node := RtsBuilding.new()
	node.game = game
	node.kind = "house"
	node.stats = {"size": dimensions}
	node.position = point
	game.add_child(node)
	node.set_process(false)
	node.hide()
	game.buildings.append(node)
	game.navigation.invalidate_obstacles()
	return node

func _run() -> void:
	_test_interaction_angles()
	_test_fine_detours()
	_test_blocked_click_through_slit()
	_test_boundary_interactions()
	_test_attack_ground()
	_test_resource_cache()
	_test_working_traffic()
	_test_building_alley_matrix()
	_test_large_fixed_corral()
	_test_corner_cache_changes()
	print("NAVIGATION_DENSE_POC checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)

func _test_interaction_angles() -> void:
	for job in ["gather", "repair", "build"]:
		for angle in 8:
			var game := fixture()
			var target := building(game, Vector2(725, 525), Vector2(55, 55))
			var unit := game.spawn_unit(target.position + Vector2.from_angle((angle + 0.5) * TAU / 8.0) * 250)
			unit.order = job
			var reach := 27.5 + unit.radius() + (2.0 if job == "gather" else 5.5 if job == "build" else 0.0)
			var path := game.navigation.path_to_range(unit.position, target.position, reach, unit)
			check(safe_route(game, unit, path) and path[path.size() - 1].distance_to(target.position) <= reach + 0.5,
				"%s_oblique_%d" % [job, angle], str(path))
			check(arrive(unit, target.position, reach, 180), "%s_oblique_%d_arrives" % [job, angle], str(unit.position))
			game.free()

func _test_fine_detours() -> void:
	for large in [false, true]:
		var game := fixture()
		if large:
			game.world_map.free()
			game.initialize(Vector2(4000, 2000))
		var column := 39 if large else 12
		var gap := 20 if large else 15
		for y in game.world_map.grid_size.y:
			if y != gap: block(game, column, y)
		var crossing := Vector2(column * 50 + 25, gap * 50 + 13)
		resource(game, crossing + Vector2(0, 27), 8)
		var unit := game.spawn_unit(Vector2(225, 125) if large else Vector2(425, 325))
		var goal := Vector2(3725, 1825) if large else Vector2(825, 325)
		var witness := PackedVector2Array([unit.position, Vector2(column * 50 - 50, crossing.y), Vector2(column * 50 + 100, crossing.y), goal])
		check(safe_route(game, unit, witness), "fine_detour_%s_witness" % large)
		var path := game.navigation.path_between(unit.position, goal, unit)
		check(safe_route(game, unit, path), "fine_detour_%s_route" % large, "points=%d" % path.size())
		unit.stats["speed"] = 260.0
		check(arrive(unit, goal, 6, 800), "fine_detour_%s_arrives" % large, str(unit.position))
		game.free()

func _test_building_alley_matrix() -> void:
	for radius in [10.0, 12.0, 18.0, 24.0, 28.0]:
		for margin in [1.0, 4.0, 10.0]:
			for offset in [0.0, 3.0, 11.0]:
				var game := fixture()
				var y: float = 525.0 + offset
				var half: float = radius + margin * 0.5
				building(game, Vector2(625, (y - half) * 0.5), Vector2(50, y - half))
				building(game, Vector2(625, (1000 + y + half) * 0.5), Vector2(50, 1000 - y - half))
				var unit := game.spawn_unit(Vector2(225, 425))
				unit.stats["radius"] = radius
				var goal := Vector2(1025, 625)
				var witness := PackedVector2Array([unit.position, Vector2(500, y), Vector2(750, y), goal])
				var path := game.navigation.path_between(unit.position, goal, unit)
				check(safe_route(game, unit, witness) and safe_route(game, unit, path),
					"alley_radius%d_margin%d_offset%d" % [radius, margin, offset], "points=%d" % path.size())
				unit.stats["speed"] = 180.0
				check(arrive(unit, goal, 6, 800), "alley_radius%d_margin%d_offset%d_arrives" % [radius, margin, offset], str(unit.position))
				game.free()

func _test_large_fixed_corral() -> void:
	var game := fixture()
	var unit := game.spawn_unit(Vector2(425, 525))
	for i in 24:
		var guard := game.spawn_unit(Vector2(525, 249 + i * 24))
		guard.owner_id = 1
		guard.order = "hold"
		guard.stance = "hold"
	for i in 14:
		for y in [249.0, 801.0]:
			var guard := game.spawn_unit(Vector2(189 + i * 24, y))
			guard.owner_id = 1
			guard.order = "hold"
			guard.stance = "hold"
	unit.stats["speed"] = 180.0
	check(arrive(unit, Vector2(1125, 525), 6, 1200), "large_fixed_corral_can_backtrack_to_exit", str(unit.position))
	game.free()

func _test_corner_cache_changes() -> void:
	var game := fixture()
	building(game, Vector2(625, 254.75), Vector2(50, 509.5))
	building(game, Vector2(625, 767.25), Vector2(50, 465.5))
	var unit := game.spawn_unit(Vector2(225, 425))
	var goal := Vector2(1025, 625)
	check(safe_route(game, unit, game.navigation.path_between(unit.position, goal, unit)), "cached_corner_route_exists")
	var seal := building(game, Vector2(625, 522), Vector2(50, 50))
	check(game.navigation.path_between(unit.position, goal, unit).is_empty(), "cached_corner_route_invalidated_by_construction")
	game.buildings.erase(seal)
	seal.free()
	game.navigation.invalidate_obstacles()
	check(safe_route(game, unit, game.navigation.path_between(unit.position, goal, unit)), "cached_corner_route_reopens_after_demolition")
	var animal := resource(game, Vector2(625, 506), 3)
	check(safe_route(game, unit, game.navigation.path_between(unit.position, goal, unit)), "corner_route_before_small_resource_motion")
	var previous := animal.position
	animal.position.y = 507.8
	game.navigation.resource_moved(animal, previous)
	check(game.navigation.path_between(unit.position, goal, unit).is_empty(), "corner_edges_rechecked_below_resource_refresh_threshold")
	game.free()

func _test_blocked_click_through_slit() -> void:
	var game := fixture()
	for y in 20:
		if y != 10: block(game, 12, y)
	resource(game, Vector2(625, 540), 8)
	resource(game, Vector2(1025, 525), 22)
	var unit := game.spawn_unit(Vector2(225, 525))
	var goal := game.navigation.nearest_walkable_point(Vector2(1025, 525), unit.radius(), unit, true)
	check(goal.distance_to(Vector2(1025, 525)) < 60, "blocked_click_keeps_reachable_far_side", str(goal))
	game.free()

func _test_boundary_interactions() -> void:
	for side in 4:
		var game := fixture()
		var points := [Vector2(14, 425), Vector2(1486, 425), Vector2(725, 14), Vector2(725, 986)]
		var goal: Vector2 = points[side]
		var unit := game.spawn_unit(goal.move_toward(Vector2(750, 500), 200))
		unit.order = "relic"
		check(arrive(unit, goal, 6, 180), "edge_interaction_%d" % side, str(unit.position))
		game.free()

func _test_attack_ground() -> void:
	var game := fixture()
	var target := building(game, Vector2(725, 525), Vector2(110, 100))
	var unit := game.spawn_unit(Vector2(225, 525))
	unit.order = "attack_ground"
	check(arrive(unit, target.position, 180, 180), "attack_ground_approaches_occupied_target", str(unit.position))
	game.free()

func _test_resource_cache() -> void:
	var game := fixture()
	resource(game, Vector2(625, 525), 22)
	var overlapping := game.spawn_unit(Vector2(625, 525))
	var other := game.spawn_unit(Vector2(225, 525))
	var grid := game.navigation._grid_for(overlapping)
	check(grid.is_point_solid(Vector2i(12, 10)), "overlapping_resource_not_cached_as_walkable")
	check(not game.navigation.can_occupy(Vector2(625, 525), 12, other, false), "other_unit_resource_collision_stays_strict")
	game.free()

func _test_working_traffic() -> void:
	# Active workers face each other in an alley; there is room to pass.
	for job in ["gather", "build", "repair", "trade"]:
		var game := fixture()
		building(game, Vector2(725, 400), Vector2(1000, 170))
		building(game, Vector2(725, 650), Vector2(1000, 170))
		var units: Array[RtsUnit] = []
		for i in 8:
			var unit := game.spawn_unit(Vector2(325 + i * 85, 525))
			unit.order = job
			unit.destination = Vector2(1200 - i * 85, 525)
			units.append(unit)
		for step in 1000:
			for unit in units: unit._move_toward(unit.destination, 0.05, 10)
		check(units.all(func(u: RtsUnit) -> bool: return u.position.distance_to(u.destination) < 11),
			"opposing_%s_workers_arrive" % job, str(units.map(func(u: RtsUnit) -> Variant: return u.position)))
		game.free()

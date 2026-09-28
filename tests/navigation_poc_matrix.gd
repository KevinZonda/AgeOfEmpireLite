extends "res://tests/navigation_poc.gd"

const Orders = preload("res://scripts/player/player_orders.gd")

func _run() -> void:
	_test_formations()
	_test_random_routes()
	_test_water_and_gate()
	_test_orders_and_obstacles()
	_test_boundaries()
	_test_dynamic_seal()
	_test_subcell_passage()
	_test_snap_approach_side()
	_test_fixed_unit_corral()
	print("NAVIGATION_POC_MATRIX checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)

func _test_formations() -> void:
	for formation in ["balanced", "line", "compact", "column"]:
		for angle in 8:
			for distance in [80.0, 350.0]:
				var game := fixture()
				var units: Array[RtsUnit] = []
				for i in 12: units.append(game.spawn_unit(Vector2(650 + i % 4 * 34, 450 + i / 4 * 34)))
				var goal: Vector2 = Vector2(701, 484) + Vector2.from_angle(angle * TAU / 8.0) * distance
				var group := group_for(game, units, goal, formation)
				tick_group(group, 800)
				var arrived := units.filter(func(u: RtsUnit) -> bool: return u.order == "idle").size()
				check(arrived == units.size(), "formation_%s_angle%d_distance%d" % [formation, angle, distance], "arrived=%d/12" % arrived)
				if arrived < 12 and OS.get_environment("RTS_POC_TRACE") == "1":
					for u in units:
						if u.order != "idle": print("TRACE ", formation, " angle=", angle, " pos=", u.position, " goal=", u.destination, " occupied=", not game.navigation.can_occupy(u.destination, u.radius(), u), " group=", u.movement_group != null, " route=", u.route)
				game.free()

func _test_random_routes() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260928
	for radius in [10.0, 12.0, 18.0, 24.0, 28.0]:
		var invalid := 0
		var empty := 0
		var stuck := 0
		for sample in 20:
			var game := fixture()
			for i in 12:
				resource(game, Vector2(rng.randf_range(400, 1050), rng.randf_range(150, 850)), rng.randf_range(6, 40))
			for i in 15: block(game, rng.randi_range(7, 23), rng.randi_range(3, 16))
			game.navigation.refresh()
			var unit := game.spawn_unit(Vector2(175, rng.randf_range(125, 875)))
			unit.stats["radius"] = radius
			unit.stats["speed"] = 180.0
			var goal := Vector2(1325, rng.randf_range(125, 875))
			var path := game.navigation.path_between(unit.position, goal, unit)
			if path.is_empty(): empty += 1
			elif not safe_route(game, unit, path): invalid += 1
			if not arrive(unit, goal, 6.0, 900): stuck += 1
			game.free()
		check(invalid == 0 and empty == 0 and stuck == 0, "seeded_routes_radius%d" % radius, "unsafe=%d empty=%d stuck=%d /20" % [invalid, empty, stuck])

func _test_water_and_gate() -> void:
	var game := fixture()
	for y in 20:
		for x in range(14, 30): game.world_map.cells[y * 30 + x] = RtsWorldMap.Terrain.WATER
	game.navigation.refresh()
	var land := game.spawn_unit(Vector2(225, 525))
	var ship := game.spawn_unit(Vector2(825, 525))
	ship.stats["tags"] = ["naval"]
	check(arrive(ship, Vector2(1275, 825)), "naval_reaches_water_goal")
	check(game.navigation.path_between(land.position, Vector2(1025, 525), land).is_empty(), "land_does_not_cross_water")
	check(game.navigation.path_between(ship.position, Vector2(225, 525), ship).is_empty(), "ship_does_not_cross_land")
	game.free()
	game = fixture()
	for y in 20:
		if y != 10: block(game, 12, y)
	var gate := RtsBuilding.new()
	gate.kind = "palisade_gate"
	gate.owner_id = 0
	gate.position = Vector2(625, 525)
	gate.stats = {"size": Vector2(30, 40)}
	gate.build_remaining = 0.0
	game.add_child(gate)
	gate.set_process(false)
	gate.hide()
	game.buildings.append(gate)
	game.navigation.refresh()
	land = game.spawn_unit(Vector2(225, 525))
	check(arrive(land, Vector2(1025, 525)), "friendly_gate_passable")
	land.owner_id = 1
	check(game.navigation.path_between(land.position, Vector2(225, 525), land).is_empty(), "enemy_gate_impassable")
	game.free()

func _test_orders_and_obstacles() -> void:
	var game := fixture()
	var units: Array[RtsUnit] = []
	for i in 6: units.append(game.spawn_unit(Vector2(225 + i % 2 * 34, 325 + i / 2 * 34)))
	Orders.issue_group_order(game, units, Vector2(1025, 350))
	var first := units[0].movement_group
	Orders.issue_group_order(game, units, Vector2(1025, 750), false, true)
	var second: RtsMovementGroup = units[0].command_queue[0]["group"]
	for step in 1000:
		first.last_frame = -1
		second.last_frame = -1
		for unit in units:
			if unit.order != "idle": unit._process(0.05)
	check(units.all(func(u: RtsUnit) -> bool: return u.order == "idle" and u.command_queue.is_empty() and u.position.distance_to(Vector2(1025, 750)) < 140.0), "queued_group_commands")
	game.free()
	game = fixture()
	units = [game.spawn_unit(Vector2(225, 525)), game.spawn_unit(Vector2(225, 565))]
	var group := group_for(game, units, Vector2(1225, 525))
	tick_group(group, 30)
	var tree := resource(game, Vector2(1225, 525), 60.0)
	group.last_frame = -1
	group.target_for(units[0])
	check(units.all(func(u: RtsUnit) -> bool: return u.destination == group.destination_for(u)), "obstructed_group_goal_synchronized")
	tick_group(group, 1000)
	check(units.all(func(u: RtsUnit) -> bool: return u.order == "idle"), "obstructed_group_goal_finishes")
	game.resources.erase(tree)
	tree.free()
	game.navigation.invalidate_obstacles()
	game.free()
	game = fixture()
	var unit := game.spawn_unit(Vector2(225, 525))
	unit.issue_command("move", Vector2(1225, 525))
	for step in 10: unit._process(0.05)
	unit.issue_command("move", Vector2(125, 125))
	for step in 400:
		if unit.order != "idle": unit._process(0.05)
	check(unit.order == "idle" and unit.position.distance_to(Vector2(125, 125)) < 7.0, "new_command_replaces_route")
	game.free()

func _test_boundaries() -> void:
	var game := fixture()
	var unit := game.spawn_unit(Vector2(125, 125))
	for point in [Vector2(12, 12), Vector2(1488, 988), Vector2(1488, 12), Vector2(12, 988)]:
		check(game.navigation.can_occupy(point, 12.0, unit, false), "map_edge_%s" % point)
	game.free()

func _test_dynamic_seal() -> void:
	var game := fixture()
	var units: Array[RtsUnit] = [game.spawn_unit(Vector2(225, 525)), game.spawn_unit(Vector2(225, 565))]
	var group := group_for(game, units, Vector2(1225, 525))
	for y in 20: block(game, 12, y)
	game.navigation.invalidate_obstacles()
	tick_group(group, 800)
	check(units.all(func(u: RtsUnit) -> bool: return u.order == "idle" and u.position.x < 600.0), "sealed_route_finishes_at_reachable_edge")
	game.free()

func _test_subcell_passage() -> void:
	var game := fixture()
	for y in 20:
		if y != 10: block(game, 12, y)
	resource(game, Vector2(625, 540), 8.0)
	game.navigation.refresh()
	var unit := game.spawn_unit(Vector2(225, 525))
	var witness := PackedVector2Array([unit.position, Vector2(575, 513), Vector2(675, 513), Vector2(1025, 525)])
	check(safe_route(game, unit, witness), "subcell_passage_witness")
	check(safe_route(game, unit, game.navigation.path_between(unit.position, Vector2(1025, 525), unit)), "subcell_passage_safe_route")
	check(arrive(unit, Vector2(1025, 525)), "subcell_passage_arrival")
	unit.position = Vector2(225, 525)
	unit.order = "attack"
	unit._reset_route()
	game.navigation.invalidate_spatial_index()
	check(arrive(unit, Vector2(1025, 525), 90.0), "subcell_passage_interaction")
	game.free()

func _test_snap_approach_side() -> void:
	var game := fixture()
	resource(game, Vector2(625, 525), 22.0)
	var unit := game.spawn_unit(Vector2(225, 525))
	var goal := game.navigation.nearest_walkable_point(Vector2(625, 525), unit.radius(), unit, true)
	check(goal.x < 625.0, "blocked_click_snaps_to_near_side", str(goal))
	game.free()

func _test_fixed_unit_corral() -> void:
	var game := fixture()
	var unit := game.spawn_unit(Vector2(425, 525))
	var parked: Array[RtsUnit] = []
	for i in 8:
		for point in [Vector2(500, 441 + i * 24), Vector2(332 + i * 24, 441), Vector2(332 + i * 24, 609)]:
			# Skip duplicate corner units.
			if parked.any(func(u: RtsUnit) -> bool: return u.position == point): continue
			var guard := game.spawn_unit(point)
			guard.owner_id = 1
			guard.order = "hold"
			guard.stance = "hold"
			parked.append(guard)
	var positions := parked.map(func(u: RtsUnit) -> Vector2: return u.position)
	check(arrive(unit, Vector2(825, 525), 6.0, 1200), "routes_around_fixed_unit_corral", str(unit.position))
	check(positions == parked.map(func(u: RtsUnit) -> Vector2: return u.position), "enemies_and_hold_units_are_not_pushed")
	game.free()

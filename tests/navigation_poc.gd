extends SceneTree

# Deterministic regressions. Reports every case, including failures, before exiting.
const Fixture = preload("res://tests/helpers/navigation_fixture.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String, detail := "") -> void:
	checks += 1
	if not ok: failures += 1
	print("POC_%s %s %s" % ["PASS" if ok else "FAIL", label, detail])

func fixture() -> Fixture:
	var game := Fixture.new()
	root.add_child(game)
	game.initialize(Vector2(1500, 1000))
	return game

func block(game: Fixture, x: int, y: int) -> void:
	game.world_map.cells[y * game.world_map.grid_size.x + x] = RtsWorldMap.Terrain.MOUNTAIN

func resource(game: Fixture, point: Vector2, size := 22.0) -> RtsResource:
	var node := RtsResource.new()
	node.position = point
	node.radius = size
	game.add_child(node)
	node.set_process(false)
	node.hide()
	game.resources.append(node)
	game.navigation.invalidate_obstacles()
	return node

func safe_route(game: Fixture, unit: RtsUnit, path: PackedVector2Array) -> bool:
	if path.is_empty(): return false
	var previous := unit.position
	for point in path:
		if not game.navigation._static_segment_clear(previous, point, unit.radius(), unit): return false
		previous = point
	return true

func arrive(unit: RtsUnit, goal: Vector2, reach := 6.0, steps := 800) -> bool:
	for step in steps:
		if unit._move_toward(goal, 0.05, reach): return true
	return false

func group_for(game: Fixture, units: Array[RtsUnit], goal: Vector2, formation := "balanced") -> RtsMovementGroup:
	var group := RtsMovementGroup.new(game, units, goal, formation)
	for unit in units: unit.issue_command("group_move", goal, null, false, group)
	return group

func tick_group(group: RtsMovementGroup, steps: int) -> void:
	for step in steps:
		group.last_frame = -1
		for unit in group.members:
			if unit.order == "idle": continue
			unit._process(0.05)

func _run() -> void:
	_test_large_unit()
	_test_range_interior()
	_test_group_replan()
	_test_group_short_move()
	_test_start_near_obstacle()
	_test_resource_routes()
	_test_frame_speed()
	_test_same_cell_resource_move()
	_test_group_wall()
	_test_parked_formation()
	print("NAVIGATION_POC checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)

func _test_large_unit() -> void:
	var game := fixture()
	for y in 17:
		if y != 5: block(game, 12, y)
	game.navigation.refresh()
	var unit := game.spawn_unit(Vector2(225, 275))
	unit.stats["radius"] = 28.0
	var goal := Vector2(1025, 275)
	var path := game.navigation.path_between(unit.position, goal, unit)
	check(safe_route(game, unit, path), "large_unit_safe_route", str(path))
	check(arrive(unit, goal, 6.0, 1200), "large_unit_uses_wide_detour", str(unit.position))
	game.free()

func _test_range_interior() -> void:
	var game := fixture()
	game.world_map.cells.fill(RtsWorldMap.Terrain.MOUNTAIN)
	for x in 30: game.world_map.cells[10 * 30 + x] = RtsWorldMap.Terrain.GRASS
	game.navigation.refresh()
	var unit := game.spawn_unit(Vector2(125, 525))
	unit.order = "attack"
	var goal := Vector2(625, 545)
	check(game.navigation.can_occupy(Vector2(600, 525), unit.radius(), unit, false), "range_interior_witness")
	var path := game.navigation.path_to_range(unit.position, goal, 90.0, unit)
	check(not path.is_empty(), "range_search_includes_interior", str(path))
	check(arrive(unit, goal, 90.0), "range_target_arrival", str(unit.position))
	game.free()

func _test_group_replan() -> void:
	var game := fixture()
	var units: Array[RtsUnit] = []
	for i in 6: units.append(game.spawn_unit(Vector2(225 + i % 2 * 34, 325 + i / 2 * 34)))
	var group := group_for(game, units, Vector2(1025, 325))
	tick_group(group, 30)
	resource(game, Vector2(1375, 875))
	group.last_frame = -1
	group.target_for(units[0])
	var synced := true
	for unit in units:
		if unit.movement_group == group and unit.destination.distance_to(group.destination_for(unit)) > 0.1: synced = false
	check(synced, "group_replan_destination_sync")
	tick_group(group, 800)
	check(units.all(func(u: RtsUnit) -> bool: return u.order == "idle"), "group_replan_finishes", str(units.map(func(u: RtsUnit) -> Variant: return [u.position, u.destination, u.order])))
	game.free()

func _test_group_short_move() -> void:
	for formation in ["balanced", "column", "compact"]:
		var game := fixture()
		var units: Array[RtsUnit] = []
		for i in 12: units.append(game.spawn_unit(Vector2(325 + i % 3 * 34, 325 + i / 3 * 34)))
		var group := group_for(game, units, Vector2(440, 380), formation)
		tick_group(group, 600)
		check(units.all(func(u: RtsUnit) -> bool: return u.order == "idle"), "short_move_" + formation, str(units.map(func(u: RtsUnit) -> Variant: return snappedf(u.position.distance_to(u.destination), 0.1))))
		if OS.get_environment("RTS_POC_TRACE") == "1":
			for u in units:
				if u.order != "idle": print("TRACE ", formation, " pos=", u.position, " goal=", u.destination, " group=", u.movement_group != null, " stuck=", u.group_stuck_time, " retry=", u.route_retry, " stall=", u.route_stalled_time, " path=", u.route, " local=", game.navigation.path_around_units(u, u.destination))
		game.free()

func _test_start_near_obstacle() -> void:
	var game := fixture()
	# The unit is legally placed in the left half of a cell whose center is blocked.
	resource(game, Vector2(299, 275), 22.0)
	var unit := game.spawn_unit(Vector2(257, 275))
	var goal := Vector2(525, 275)
	check(game.navigation.can_occupy(unit.position, unit.radius(), unit, false), "off_grid_start_witness")
	var path := game.navigation.path_between(unit.position, goal, unit)
	check(safe_route(game, unit, path), "off_grid_start_safe_route", str(path))
	check(arrive(unit, goal), "off_grid_start_arrival", str(unit.position))
	game.free()

func _test_resource_routes() -> void:
	var invalid := 0
	var total := 0
	var examples: Array = []
	for radius in [10.0, 12.0, 18.0, 24.0, 28.0]:
		for offset in [0.0, 9.0, 19.0, 29.0, 39.0, 49.0]:
			var game := fixture()
			resource(game, Vector2(700 + offset, 475), 22.0)
			var unit := game.spawn_unit(Vector2(225, 475))
			unit.stats["radius"] = radius
			var goal := Vector2(1225, 475)
			var path := game.navigation.path_between(unit.position, goal, unit)
			total += 1
			if not safe_route(game, unit, path):
				invalid += 1
				examples.append([radius, offset])
			game.free()
	check(invalid == 0, "resource_clearance_matrix", "%d/%d unsafe %s" % [invalid, total, examples])

func _test_frame_speed() -> void:
	var distances: Array = []
	for delta in [1.0 / 120.0, 1.0 / 60.0, 1.0 / 30.0, 0.05]:
		var game := fixture()
		var unit := game.spawn_unit(Vector2(125, 125))
		unit.stats["speed"] = 260.0
		for step in roundi(1.0 / delta): unit._move_toward(Vector2(1225, 125), delta, 6.0)
		distances.append(unit.position.x - 125.0)
		game.free()
	check(distances.all(func(d: float) -> bool: return absf(d - 260.0) < 1.0), "speed_independent_of_frame_rate", str(distances))

func _test_same_cell_resource_move() -> void:
	var game := fixture()
	var tree := resource(game, Vector2(702, 475), 22.0)
	game.navigation.refresh()
	var before := game.navigation.obstacle_revision
	var old := tree.position
	tree.position = Vector2(748, 475)
	game.navigation.resource_moved(tree, old)
	game.navigation._ensure_current()
	check(game.navigation.obstacle_revision > before, "resource_motion_within_cell_invalidates")
	var unit := game.spawn_unit(Vector2(1025, 475))
	check(safe_route(game, unit, game.navigation.path_between(unit.position, Vector2(225, 475), unit)), "moved_resource_safe_route")
	game.free()

func _test_group_wall() -> void:
	for opening in [1, 2, 3]:
		var game := fixture()
		for y in 20:
			if y < 9 or y >= 9 + opening: block(game, 12, y)
		game.navigation.refresh()
		var units: Array[RtsUnit] = []
		for i in 12: units.append(game.spawn_unit(Vector2(325 + i % 3 * 34, 425 + i / 3 * 34)))
		var group := group_for(game, units, Vector2(1025, 475))
		tick_group(group, 1400)
		check(units.all(func(u: RtsUnit) -> bool: return u.order == "idle"), "group_gap_%d_cells" % opening, str(units.map(func(u: RtsUnit) -> Variant: return [u.position, u.order])))
		if OS.get_environment("RTS_POC_TRACE") == "1":
			for u in units:
				if u.order != "idle": print("TRACE gap=", opening, " pos=", u.position, " goal=", u.destination, " group=", u.movement_group != null, " point=", group.target_for(u), " stuck=", u.group_stuck_time, " route=", u.route, " local=", game.navigation.path_around_units(u, u.destination))
		game.free()

func _test_parked_formation() -> void:
	var game := fixture()
	var unit := game.spawn_unit(Vector2(225, 525))
	var goal := Vector2(625, 525)
	for i in 8:
		var parked := game.spawn_unit(goal + Vector2.from_angle(i * TAU / 8.0) * 34.0)
		parked.order = "idle"
	check(arrive(unit, goal, 6.0, 1200), "friendly_idle_units_yield", str(unit.position))
	game.free()

extends SceneTree

const Fixture = preload("res://tests/helpers/navigation_fixture.gd")

func _initialize() -> void:
	call_deferred("_run")

func _fixture() -> Fixture:
	var game := Fixture.new()
	root.add_child(game)
	game.initialize(Vector2(1500, 1000))
	game.navigation.profiling_enabled = true
	game.navigation.reset_profile()
	return game

func _calls(game: Node2D, operation := "path_between") -> int:
	return game.navigation.profile_snapshot().get(operation, {}).get("calls", 0)

func _arrive(unit: RtsUnit, point: Vector2, reach := 6.0) -> bool:
	for step in 1200:
		if unit._move_toward(point, 0.05, reach): return true
	return false

func _run() -> void:
	for test in [_test_reuse_and_retarget, _test_obstacle_changes, _test_failure_recovery, _test_dynamic_blocker, _test_range_target, _test_nearest_fallback]:
		if not test.call():
			quit(1)
			return
	print("NAVIGATION_REPLANNING_OK")
	quit()

func _test_nearest_fallback() -> bool:
	var game := _fixture()
	var unit := game.spawn_unit(Vector2(125, 525))
	var obstacle := RtsResource.new()
	obstacle.position = Vector2(825, 525)
	obstacle.radius = 260.0
	game.add_child(obstacle)
	obstacle.set_process(false)
	obstacle.hide()
	game.resources.append(obstacle)
	game.navigation.invalidate_obstacles()
	# Every local-ring sample is inside this obstacle. The four nearest free
	# grid centers are equally distant; preserve the top-left tie-break.
	var result := game.navigation.nearest_walkable_point(obstacle.position, unit.radius(), unit, true)
	assert(result == Vector2(625, 325), "global fallback must select the nearest reachable point with stable ties")
	assert(not game.navigation.path_between(unit.position, result, unit).is_empty())
	game.free()
	return true

func _test_reuse_and_retarget() -> bool:
	var game := _fixture()
	var unit := game.spawn_unit(Vector2(125, 125))
	var goal := Vector2(1225, 125)
	assert(_arrive(unit, goal), "a reused route must still reach its destination")
	assert(_calls(game) == 1, "unobstructed travel should retain its route")
	# A small target movement below the retarget threshold still needs a new
	# path when the old endpoint is reached outside interaction range.
	goal += Vector2(20, 0)
	assert(_arrive(unit, goal), "small endpoint changes must not leave the unit stuck")
	assert(_calls(game) == 2)
	unit._reset_route()
	for step in 20: unit._move_toward(Vector2(125, 125), 0.05, 6.0)
	var before := _calls(game)
	assert(_arrive(unit, Vector2(1225, 825)), "moving targets should trigger a new route")
	assert(_calls(game) == before + 1)
	game.free()
	return true

func _test_obstacle_changes() -> bool:
	var game := _fixture()
	var unit := game.spawn_unit(Vector2(125, 125))
	var goal := Vector2(1225, 125)
	for step in 10: unit._move_toward(goal, 0.05, 6.0)
	var resource := RtsResource.new()
	resource.position = Vector2(725, 825)
	game.add_child(resource)
	resource.set_process(false)
	resource.hide()
	game.resources.append(resource)
	game.navigation.invalidate_obstacles()
	for step in 10: unit._move_toward(goal, 0.05, 6.0)
	assert(_calls(game) == 1, "a distant obstacle should not discard a valid route")
	var previous := resource.position
	resource.position = Vector2(725, 125)
	game.navigation.resource_moved(resource, previous)
	var arrived := false
	for step in 600:
		arrived = unit._move_toward(goal, 0.05, 6.0)
		assert(unit.position.distance_to(resource.position) >= unit.radius() + resource.radius, "new obstacles must never be crossed")
		if arrived: break
	assert(arrived, "a blocked route must be replaced with a detour")
	assert(_calls(game) == 2, "one obstacle change should require only one replacement route")
	assert(_calls(game, "astar") > 0, "detouring should exercise and count A* searches")
	game.free()
	return true

func _test_failure_recovery() -> bool:
	var game := _fixture()
	for y in 20: game.world_map.cells[y * 30 + 12] = RtsWorldMap.Terrain.MOUNTAIN
	game.navigation.invalidate_obstacles()
	var unit := game.spawn_unit(Vector2(125, 125))
	var goal := Vector2(1225, 125)
	for step in 200: unit._move_toward(goal, 0.05, 6.0)
	assert(_calls(game) <= 5, "unreachable targets should back off repeated searches")
	assert(unit.position == Vector2(125, 125))
	var failed_calls := _calls(game)
	for step in 10: unit._move_toward(Vector2(325, 125), 0.05, 6.0)
	assert(_calls(game) == failed_calls + 1 and unit.position.x > 125.0, "a target moving into reachability must not inherit long failure backoff")
	for step in 200: unit._move_toward(goal, 0.05, 6.0)
	# Open the wall while this unit is in its longest retry interval.
	var before := _calls(game)
	for y in 20: game.world_map.cells[y * 30 + 12] = RtsWorldMap.Terrain.GRASS
	game.navigation.invalidate_obstacles()
	unit._move_toward(goal, 0.05, 6.0)
	assert(_calls(game) == before + 1, "opening a route should interrupt failure backoff")
	assert(_arrive(unit, goal))
	game.free()
	return true

func _test_dynamic_blocker() -> bool:
	var game := _fixture()
	# A one-cell corridor cannot accommodate passing two radius-14 units.
	game.world_map.cells.fill(RtsWorldMap.Terrain.MOUNTAIN)
	for x in 30: game.world_map.cells[10 * 30 + x] = RtsWorldMap.Terrain.GRASS
	game.navigation.invalidate_obstacles()
	var unit := game.spawn_unit(Vector2(125, 525))
	unit.stats["radius"] = 14.0
	var blocker := game.spawn_unit(Vector2(225, 525))
	blocker.stats["radius"] = 14.0
	var goal := Vector2(1225, 525)
	for step in 200: unit._move_toward(goal, 0.05, 6.0)
	assert(unit.position.x < blocker.position.x, "units must respect a stationary blocker")
	assert(_calls(game) > 1 and _calls(game) <= 6, "stalled movement should retry with backoff even when A* finds a path")
	game.units.erase(blocker)
	blocker.free()
	game.navigation.invalidate_spatial_index()
	assert(_arrive(unit, goal), "removing a dynamic blocker should allow movement to resume")
	game.free()
	return true

func _test_range_target() -> bool:
	var game := _fixture()
	var unit := game.spawn_unit(Vector2(125, 125))
	unit.order = "attack"
	var target := Vector2(1225, 125)
	assert(_arrive(unit, target, 100.0))
	assert(_calls(game, "path_to_range") == 1, "an unchanged interaction target should reuse its approach")
	assert(_arrive(unit, target, 30.0), "a changed attack range must invalidate the old endpoint")
	assert(_calls(game, "path_to_range") == 2)
	game.free()
	return true

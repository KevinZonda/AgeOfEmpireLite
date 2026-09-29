extends "res://tests/navigation_poc.gd"

# Live matches stutter when a villager keeps retrying an unreachable order:
# wandering wildlife invalidated every navigation cache each frame, so each
# retry rebuilt world fine grids, flood fills and corner graphs from scratch.
# This PoC pins the cheap-cache behavior and the collision guarantees that
# moving animals must still provide.

const BIG_MAP := Vector2(4000, 2000)
const WALL_COLUMN := 40


func _run() -> void:
	_test_wildlife_cache_churn()
	_test_stuck_retry_cost()
	print("NAVIGATION_WILDLIFE_CHURN_POC checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)


func _big_fixture() -> Fixture:
	var game := Fixture.new()
	root.add_child(game)
	game.initialize(BIG_MAP)
	return game


func wildlife(game: Fixture, point: Vector2, size := 8.0) -> RtsResource:
	var node := resource(game, point, size)
	node.appearance = "deer"
	node.wildlife_hp = 12.0
	game.navigation.invalidate_obstacles()
	return node


# A deposit on the far side of a full-height mountain wall: every approach
# point is open ground, yet no body can reach it from the west half.
func _walled_target(game: Fixture) -> RtsResource:
	for y in game.world_map.grid_size.y:
		block(game, WALL_COLUMN, y)
	var target := resource(game, Vector2(3025, 1025), 8.0)
	game.navigation.invalidate_obstacles()
	return target


func _wander(game: Fixture, deer: RtsResource, steps: int, stride := 0.0) -> void:
	for step in steps:
		var previous := deer.position
		if stride > 0.0:
			deer.position += Vector2(stride, stride * 0.6)
		else:
			# The home orbit of resource_node._process_deer, ~14 px around home.
			deer.position = Vector2(225, 225) + Vector2(sin(step * 0.75) * 14.0, cos(step * 0.52) * 10.0)
		game.navigation.resource_moved(deer, previous)
		game.navigation._ensure_current()


func _test_wildlife_cache_churn() -> void:
	var game := _big_fixture()
	var target := _walled_target(game)
	var unit := game.spawn_unit(Vector2(425, 1025))
	unit.order = "gather"
	var deer := wildlife(game, Vector2(225, 225), 8.0)
	var reach := target.radius + unit.radius() + 2.0
	# One hopeless search warms the expensive caches (fine grid, components).
	check(game.navigation.path_to_range(unit.position, target.position, reach, unit).is_empty(), "sealed_target_has_no_route")
	var revision: int = game.navigation.obstacle_revision
	var fine_count: int = game.navigation.fine_grids.size()
	check(fine_count > 0, "failed_search_built_fine_grid", "fine=%d" % fine_count)
	_wander(game, deer, 30)
	check(game.navigation.obstacle_revision == revision, "wildlife_orbit_preserves_obstacle_revision",
		"revision %d -> %d" % [revision, game.navigation.obstacle_revision])
	check(game.navigation.fine_grids.size() == fine_count, "wildlife_orbit_preserves_fine_grids",
		"fine %d -> %d" % [fine_count, game.navigation.fine_grids.size()])
	# Collision and spatial queries track the animal's live position.
	var vacated := Vector2(225, 225) + Vector2(14.0, 10.0)
	check(not game.navigation.can_occupy(deer.position, unit.radius(), unit, false), "moved_wildlife_still_blocks")
	check(game.navigation.can_occupy(vacated, unit.radius(), unit, false), "vacated_orbit_spot_is_open")
	check(game.navigation.nearby_resources(deer.position, 4.0).has(deer), "moved_wildlife_stays_indexed")
	game.free()


func _test_stuck_retry_cost() -> void:
	var game := _big_fixture()
	var target := _walled_target(game)
	var unit := game.spawn_unit(Vector2(425, 1025))
	unit.order = "gather"
	var deer := wildlife(game, Vector2(225, 225), 8.0)
	var reach := target.radius + unit.radius() + 2.0
	var retries := 10
	# Warm baseline: the world stands still between retries.
	game.navigation.profiling_enabled = true
	game.navigation.path_to_range(unit.position, target.position, reach, unit)
	var local_after_warmup: int = game.navigation.local_fine_grids.size()
	game.navigation.reset_profile()
	var started := Time.get_ticks_usec()
	for retry in retries:
		game.navigation.path_to_range(unit.position, target.position, reach, unit)
	var warm_ms := (Time.get_ticks_usec() - started) / 1000.0
	print("CHURN_POC warm_profile=%s" % JSON.stringify(game.navigation.profile_snapshot()))
	# Live-match pattern: a distant deer moves between every retry.
	started = Time.get_ticks_usec()
	for retry in retries:
		_wander(game, deer, 1, 0.5)
		game.navigation.path_to_range(unit.position, target.position, reach, unit)
	var cold_ms := (Time.get_ticks_usec() - started) / 1000.0
	print("CHURN_POC warm_%d_retries_ms=%.1f wildlife_%d_retries_ms=%.1f" % [retries, warm_ms, retries, cold_ms])
	check(cold_ms <= warm_ms * 1.5 + 2.0, "wildlife_retries_stay_cheap", "warm=%.1f cold=%.1f" % [warm_ms, cold_ms])
	check(game.navigation.local_fine_grids.size() == local_after_warmup, "disconnected_target_skips_local_grids",
		"local %d -> %d" % [local_after_warmup, game.navigation.local_fine_grids.size()])
	check(game.navigation.fine_grids.size() == 1, "disconnected_target_reuses_world_fine_grid",
		"fine=%d" % game.navigation.fine_grids.size())
	game.free()

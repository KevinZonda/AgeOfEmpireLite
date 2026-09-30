extends SceneTree

# Verifies the asynchronous world fine-grid rebuild path:
#  1. Worker-built grids are cell-for-cell identical to the synchronous builder
#     (deterministic fixture world, no wildlife movement).
#  2. On a real late-game map, a geometry invalidation keeps the main thread
#     cheap: refresh dispatches worker rebuilds, stale grids keep answering,
#     failing queries fail fast, and the fresh grid + components swap in
#     atomically without a main-thread flood.
func _initialize() -> void:
	call_deferred("_run")

var failures := 0
var checks := 0

func check(ok: bool, label: String, detail := "") -> void:
	checks += 1
	if not ok: failures += 1
	print("ASYNC_%s %s %s" % ["PASS" if ok else "FAIL", label, detail])

func _report(label: String, start_us: int) -> float:
	var ms := (Time.get_ticks_usec() - start_us) / 1000.0
	print("%-52s %8.2f ms" % [label, ms])
	return ms

func _drain(nav, game: Node2D, max_frames := 600) -> void:
	var frames := 0
	while not nav.grid_builds.active.is_empty() and frames < max_frames:
		nav.grid_builds.poll(nav)
		await process_frame
		frames += 1
	check(frames < max_frames, "worker_rebuilds_completed", "frames=%d" % frames)

func _run() -> void:
	seed(4242)
	_test_worker_grid_parity()
	await _test_invalidation_storm()
	print("ASYNC_PROBE checks=%d failures=%d" % [checks, failures])
	print("ASYNC_PROBE_OK" if failures == 0 else "ASYNC_PROBE_FAILED")
	quit(1 if failures else 0)

func _test_worker_grid_parity() -> void:
	var fixture_scene = load("res://tests/helpers/navigation_fixture.gd")
	var game: Node2D = fixture_scene.new()
	root.add_child(game)
	game.initialize(Vector2(1200, 900))
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	# Mixed terrain, buildings, a gate, and static resources: exercise every
	# rasterization input the snapshot must preserve.
	for i in 60:
		game.world_map.cells[rng.randi_range(0, game.world_map.cells.size() - 1)] = [RtsWorldMap.Terrain.WATER, RtsWorldMap.Terrain.MOUNTAIN][rng.randi_range(0, 1)]
	for i in 6:
		var building := RtsBuilding.new()
		building.game = game
		building.kind = "house"
		building.stats = {"size": Vector2(rng.randf_range(30, 90), rng.randf_range(30, 90))}
		building.position = Vector2(rng.randf_range(100, 1100), rng.randf_range(100, 800))
		game.add_child(building)
		game.buildings.append(building)
	var gate := RtsBuilding.new()
	gate.game = game
	gate.kind = "palisade_gate"
	gate.stats = {"size": Vector2(75, 25)}
	gate.position = Vector2(600, 450)
	game.add_child(gate)
	game.buildings.append(gate)
	for i in 10:
		var node := RtsResource.new()
		node.position = Vector2(rng.randf_range(60, 1140), rng.randf_range(60, 840))
		node.radius = rng.randf_range(6, 20)
		game.add_child(node)
		game.resources.append(node)
	# Mobile wildlife joins rasterization but not strict corner endpoints.
	var deer := RtsResource.new()
	deer.appearance = "deer"
	deer.wildlife_hp = 10.0
	deer.position = Vector2(300, 300)
	deer.radius = 10.0
	game.add_child(deer)
	game.resources.append(deer)
	game.navigation.refresh()
	var unit: RtsUnit = game.spawn_unit(Vector2(100, 100))
	var nav = game.navigation
	for naval in [false, true]:
		unit.stats["tags"] = ["naval"] if naval else []
		for owner_id in [0, 1]:
			for radius in [10.0, 12.0, 24.0]:
				unit.owner_id = owner_id
				unit.stats["radius"] = radius
				var key: Vector3 = nav._grid_key(unit)
				var label := "owner%d_radius%d_naval%s" % [owner_id, radius, naval]
				var snapshot = nav.grid_builds._capture(nav, key)
				var worker_grid: AStarGrid2D = snapshot.build_grid()
				snapshot.build_corners()
				var live_grid: AStarGrid2D = nav._make_fine_grid(unit, Rect2(Vector2.ZERO, game.world_map.world_size))
				check(worker_grid.region == live_grid.region and worker_grid.cell_size == live_grid.cell_size and worker_grid.offset == live_grid.offset,
					"parity_shape_%s" % label)
				var mismatch := 0
				for y in live_grid.region.size.y:
					for x in live_grid.region.size.x:
						var cell := Vector2i(x, y)
						if worker_grid.is_point_solid(cell) != live_grid.is_point_solid(cell): mismatch += 1
				check(mismatch == 0, "parity_cells_%s" % label, "mismatch=%d" % mismatch)
				check(snapshot.corners == _reference_corners(game, unit), "parity_corners_%s" % label)
	game.free()

func _reference_corners(game: Node2D, unit: RtsUnit) -> PackedVector2Array:
	# Mirrors the point generation in RtsNavigation._obstacle_corner_path.
	var nav = game.navigation
	var corners := PackedVector2Array()
	for obstacle in game.buildings:
		if not is_instance_valid(obstacle) or obstacle.is_queued_for_deletion(): continue
		if nav._gate_passable(obstacle, unit.owner_id): continue
		var bounds := Rect2(obstacle.position - obstacle.size() * 0.5, obstacle.size()).grow(unit.radius() + 0.05)
		for point in [bounds.position, bounds.end, Vector2(bounds.position.x, bounds.end.y), Vector2(bounds.end.x, bounds.position.y)]:
			if not corners.has(point) and nav._can_occupy(point, unit.radius(), unit, false, Vector2.INF, false, true): corners.append(point)
	var naval: bool = unit.stats.get("tags", []).has("naval")
	for y in game.world_map.grid_size.y:
		for x in game.world_map.grid_size.x:
			var terrain: int = game.world_map.cells[y * game.world_map.grid_size.x + x]
			if nav._terrain_passable(terrain, naval): continue
			var bounds := Rect2(Vector2(x, y) * RtsWorldMap.CELL_SIZE, Vector2.ONE * RtsWorldMap.CELL_SIZE).grow(unit.radius() + 0.05)
			for point in [bounds.position, bounds.end, Vector2(bounds.position.x, bounds.end.y), Vector2(bounds.end.x, bounds.position.y)]:
				if not corners.has(point) and nav._can_occupy(point, unit.radius(), unit, false, Vector2.INF, false, true): corners.append(point)
	return corners

func _test_invalidation_storm() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game("English", 4242, "French")
	await process_frame
	for i in 300:
		var unit := RtsUnit.new()
		unit.position = Vector2(300 + (i % 30) * 45.0, 400 + (i / 30) * 45.0)
		game.add_child(unit)
		unit.setup(game, i % game.players.size(), "spearman")
		game.units.append(unit)
	# Freeze the simulation: no AI placement or wildlife movement may change
	# geometry while worker results are awaited.
	game.paused = true
	var nav = game.navigation
	var probe: RtsUnit = game.units[0]
	var key: Vector3 = nav._grid_key(probe)
	var from := probe.position
	var reachable := Vector2(game.world_map.world_size.x - from.x, game.world_map.world_size.y - from.y)
	# Warm-up: the first build of a body type stays synchronous by design.
	var start := Time.get_ticks_usec()
	nav._fine_grid_for(probe)
	_report("first build (sync, once per body type)", start)
	# Reach steady state: a rebuilt grid carrying its components.
	nav.grid_builds.request(nav, key)
	await _drain(nav, game)
	# Seal a destination with a ring of houses: genuinely unreachable.
	var sealed := Vector2(game.world_map.world_size.x * 0.5, game.world_map.world_size.y * 0.25)
	for i in 8:
		game.spawn_building(1, "house", sealed + Vector2.from_angle(TAU * i / 8.0) * 55.0)
	nav.refresh()
	nav.grid_builds.request(nav, key)
	await _drain(nav, game)
	var baseline := Time.get_ticks_usec()
	var blocked: PackedVector2Array = nav._fine_static_path(from, sealed, probe)
	_report("failing query, steady state", baseline)
	check(blocked.is_empty(), "sealed_target_fails_steady")

	# The storm: invalidate geometry as a building placement/destruction does.
	var stale: AStarGrid2D = nav.fine_grids[key]
	start = Time.get_ticks_usec()
	nav.refresh()
	var refresh_ms := _report("refresh() + worker dispatch [main thread]", start)
	check(nav.fine_grids[key] == stale, "stale_grid_kept_during_rebuild")
	check(not nav.grid_builds.active.is_empty(), "rebuild_dispatched")
	# The first failing coarse-path query used to pay grid build + BFS flood
	# synchronously here. It must now answer from the stale grid quickly.
	start = Time.get_ticks_usec()
	blocked = nav._fine_static_path(from, sealed, probe)
	var fail_stale_ms := _report("failing query on stale grid [main thread]", start)
	check(blocked.is_empty(), "sealed_target_fails_during_rebuild")
	start = Time.get_ticks_usec()
	var open: PackedVector2Array = nav._fine_static_path(from, reachable, probe)
	var open_stale_ms := _report("reachable query on stale grid [main thread]", start)
	check(not open.is_empty(), "reachable_target_still_paths_during_rebuild")
	await _drain(nav, game)
	var fresh: AStarGrid2D = nav.fine_grids[key]
	check(fresh != stale, "fresh_grid_swapped_in")
	check(nav.grid_components.has(fresh.get_instance_id()), "components_delivered_with_grid")
	start = Time.get_ticks_usec()
	blocked = nav._fine_static_path(from, sealed, probe)
	var fail_fresh_ms := _report("failing query after swap [main thread]", start)
	check(blocked.is_empty(), "sealed_target_fails_after_swap")
	# The remaining cost is the exact corner-fallback visibility search, which
	# caches its edges: a second failing query is cheap.
	start = Time.get_ticks_usec()
	blocked = nav._fine_static_path(from, sealed, probe)
	var fail_warm_ms := _report("failing query, corner cache warm", start)
	check(blocked.is_empty(), "sealed_target_fails_warm")
	start = Time.get_ticks_usec()
	open = nav._fine_static_path(from, reachable, probe)
	_report("reachable query after swap [main thread]", start)
	check(not open.is_empty(), "reachable_target_paths_after_swap")
	check(refresh_ms < 5.0, "refresh_under_5ms", "%.2f" % refresh_ms)
	# A failing query inside the stale window answers from retained corner
	# portals with per-anchor batched edge sweeps; a cold exhaustive visibility
	# scan must stay under one frame's simulation budget.
	check(fail_stale_ms < 10.0, "stale_window_failure_under_10ms", "%.2f" % fail_stale_ms)
	# Corner points now arrive with the worker grid; the residual cost of the
	# first failing query is the exact visibility search itself (pre-existing).
	check(fail_fresh_ms < 40.0, "post_swap_failure_bounded", "%.2f" % fail_fresh_ms)
	check(fail_warm_ms < 5.0, "warm_failure_under_5ms", "%.2f" % fail_warm_ms)
	print("stale-window costs: fail=%.2f ms reachable=%.2f ms" % [fail_stale_ms, open_stale_ms])
	print("worker metrics: %s" % nav.grid_builds.metrics)
	game.free()

extends "res://tests/navigation_dense_poc.gd"

func _run() -> void:
	var game := fixture()
	game.world_map.free()
	game.initialize(Vector2(3200, 2400))
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for i in game.world_map.cells.size():
		if rng.randf() < 0.12: game.world_map.cells[i] = RtsWorldMap.Terrain.WATER
	for i in 6:
		building(game, Vector2(1350 + (i % 3) * 155, 1100 + (i / 3) * 170), Vector2(90, 90))
	for i in 150:
		resource(game, Vector2(rng.randf_range(50, 3150), rng.randf_range(50, 2350)), rng.randf_range(8, 24))
	var mover := game.spawn_unit(Vector2(1200, 1000))
	game.navigation.refresh()
	var grid: AStarGrid2D
	var started := Time.get_ticks_usec()
	for i in 30:
		game.navigation.clearance_grids.clear()
		grid = game.navigation._grid_for(mover)
	var coarse_ms := (Time.get_ticks_usec() - started) / 1000.0
	started = Time.get_ticks_usec()
	for i in 30: grid = game.navigation._local_unit_grid(mover, 2, 96)
	var local_ms := (Time.get_ticks_usec() - started) / 1000.0
	print("STATIC_GRID_POC buildings=6 resources=150 requests=30 coarse_ms=%.3f local_ms=%.3f" % [coarse_ms, local_ms])
	var compared := 0
	for naval in [false, true]:
		mover.stats["tags"] = ["naval"] if naval else []
		for radius in [10.0, 18.0, 28.0]:
			mover.stats["radius"] = radius
			game.navigation.clearance_grids.clear()
			compared += _compare(game, mover, game.navigation._grid_for(mover), false)
			for point in [Vector2(1200.25, 1000.125), Vector2(20, 20), Vector2(3180, 2380)]:
				mover.position = point
				compared += _compare(game, mover, game.navigation._local_unit_grid(mover, 2, 48), true)
	game.free()
	print("NAVIGATION_BATTLE_STATIC_GRID_POC checks=%d failures=%d cells=%d" % [checks, failures, compared])
	quit(1 if failures else 0)

func _compare(game: Fixture, unit: RtsUnit, grid: AStarGrid2D, escape: bool) -> int:
	var differences := 0
	for y in grid.region.size.y:
		for x in grid.region.size.x:
			var cell := Vector2i(x, y)
			var expected := not game.navigation.can_occupy(grid.get_point_position(cell), unit.radius(), unit, escape, escape)
			if grid.is_point_solid(cell) != expected: differences += 1
	check(differences == 0, "static_grid_matches_collision", "radius=%s naval=%s local=%s origin=%s differences=%d" % [unit.radius(), unit.stats["tags"], escape, grid.offset, differences])
	return grid.region.size.x * grid.region.size.y

extends "res://tests/navigation_dense_poc.gd"

func _run() -> void:
	var game := fixture()
	var unit := game.spawn_unit(Vector2(725.25, 525.125))
	for y in 11:
		for x in 11:
			if x == 5 and y == 5: continue
			game.spawn_unit(unit.position + Vector2(x - 5, y - 5) * 27.0)
	var started := Time.get_ticks_usec()
	var grid: AStarGrid2D
	for attempt in 10: grid = game.navigation._local_unit_grid(unit, 2, 96)
	print("RASTER_POC units=%d requests=10 elapsed_ms=%.3f" % [game.units.size(), (Time.get_ticks_usec() - started) / 1000.0])
	var mismatch := 0
	for y in grid.region.size.y:
		for x in grid.region.size.x:
			var cell := Vector2i(x, y)
			var expected := not game.navigation.can_occupy(grid.get_point_position(cell), unit.radius(), unit)
			if grid.is_point_solid(cell) != expected: mismatch += 1
	check(mismatch == 0, "dense_raster_matches_continuous_occupancy", "mismatches=%d cells=%d" % [mismatch, grid.region.size.x * grid.region.size.y])
	game.free()
	print("NAVIGATION_BATTLE_RASTER_POC checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)

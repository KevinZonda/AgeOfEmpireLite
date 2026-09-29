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
	# Exact contacts and pre-existing overlaps include float32 Vector2 rounding.
	# Compare the span implementation with the original per-cell predicate.
	for offset in [Vector2.ZERO, Vector2(0, 1.1), Vector2(1.1, 0), Vector2(24, 0), Vector2(12.25, 7.125)]:
		var center := Vector2(725.1, 525.7)
		var origin: Vector2 = center + offset
		var current := origin.distance_squared_to(center)
		var local := AStarGrid2D.new()
		local.region = Rect2i(0, 0, 49, 49)
		local.cell_size = Vector2.ONE * 2.0
		local.offset = origin - Vector2.ONE * 48.0
		local.update()
		game.navigation._rasterize_unit_circle(local, center, 24.0, current)
		var differences := 0
		for y in 49:
			for x in 49:
				var cell := Vector2i(x, y)
				var distance := local.get_point_position(cell).distance_squared_to(center)
				if local.is_point_solid(cell) != (distance < 24.0 * 24.0 and distance <= current): differences += 1
		check(differences == 0, "circle_contact_and_escape_predicate", "offset=%s differences=%d" % [offset, differences])
	game.free()
	print("NAVIGATION_BATTLE_RASTER_POC checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)

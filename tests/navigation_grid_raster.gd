extends "res://tests/navigation_dense_poc.gd"

# Compare every raster cell against the independent collision contract, for
# both map-wide and offset local grids. This protects the faster cold build.
func _run() -> void:
	var game := fixture()
	game.world_map.free()
	game.initialize(Vector2(450, 400))
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260929
	for i in game.world_map.cells.size():
		game.world_map.cells[i] = [RtsWorldMap.Terrain.GRASS, RtsWorldMap.Terrain.WATER, RtsWorldMap.Terrain.MOUNTAIN][rng.randi_range(0, 2)]
	for i in 8:
		building(game, Vector2(rng.randf_range(40, 410), rng.randf_range(40, 360)), Vector2(rng.randf_range(25, 90), rng.randf_range(25, 90)))
		resource(game, Vector2(rng.randf_range(40, 410), rng.randf_range(40, 360)), rng.randf_range(5, 24))
	var gate := building(game, Vector2(225, 175), Vector2(75, 25))
	gate.kind = "palisade_gate"
	gate.wall_vertical = true
	game.navigation.refresh()
	var unit := game.spawn_unit(Vector2(125, 125))
	var compared := 0
	for naval in [false, true]:
		unit.stats["tags"] = ["naval"] if naval else []
		for owner in [0, 1]:
			unit.owner_id = owner
			for radius in [10.0, 12.0, 18.0, 24.0, 28.0]:
				unit.stats["radius"] = radius
				for bounds in [Rect2(Vector2.ZERO, game.world_size), Rect2(37, 53, 235, 249)]:
					var grid := game.navigation._make_fine_grid(unit, bounds)
					var mismatch := 0
					for y in grid.region.size.y:
						for x in grid.region.size.x:
							var cell := Vector2i(x, y)
							var expected := not game.navigation.can_occupy(grid.get_point_position(cell), radius, unit, false, false)
							if grid.is_point_solid(cell) != expected: mismatch += 1
							compared += 1
					check(mismatch == 0, "raster_naval%s_owner%d_radius%d_origin%s" % [naval, owner, radius, bounds.position], "mismatch=%d" % mismatch)
	game.free()
	print("NAVIGATION_GRID_RASTER checks=%d failures=%d cells=%d" % [checks, failures, compared])
	quit(1 if failures else 0)

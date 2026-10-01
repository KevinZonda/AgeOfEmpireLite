extends SceneTree

const Contours = preload("res://scripts/world/terrain_contours.gd")

func _initialize() -> void:
	var map := RtsWorldMap.new()
	map.generate(431, Vector2(500, 500))
	map.cells.fill(RtsWorldMap.Terrain.GRASS)
	# A convex corner, a one-cell pond and a one-cell land crossing must survive.
	for y in range(2, 7):
		for x in range(2, 7): map.cells[map._index(Vector2i(x, y))] = RtsWorldMap.Terrain.WATER
	for x in range(2, 7): map.cells[map._index(Vector2i(x, 4))] = RtsWorldMap.Terrain.ROAD
	map.cells[map._index(Vector2i(8, 8))] = RtsWorldMap.Terrain.WATER
	var cells_before := map.cells.duplicate()
	var rng_before := map.rng.state
	for y in map.grid_size.y:
		for x in map.grid_size.x:
			var cell := Vector2i(x, y)
			var expected := 1.0 if map.cells[map._index(cell)] == RtsWorldMap.Terrain.WATER else 0.0
			assert(is_equal_approx(Contours.water_at(map, map.cell_center(cell)), expected), "contours erased a pond or a crossing")
	# Old filled rectangles include this entire corner. The curved waterline cuts
	# inside it, while retaining water in the interior of the same cell.
	assert(Contours.water_at(map, Vector2(102, 102)) < 0.5, "the convex shore still has a square corner")
	assert(Contours.water_at(map, Vector2(120, 120)) > 0.5)
	for axis in [Vector2.RIGHT, Vector2.DOWN]:
		for step in range(1, 499):
			var point: Vector2 = Vector2(100, 100) + axis * step * 0.6
			var a := Contours.water_at(map, point - axis * 0.001)
			var b := Contours.water_at(map, point + axis * 0.001)
			assert(absf(a - b) < 0.001, "water material jumps at a sample boundary")
	var first := Contours.overview_image(map)
	assert(first.get_data() == Contours.overview_image(map).get_data(), "overview must be deterministic")
	assert(map.cells == cells_before and map.rng.state == rng_before, "visual sampling changed the simulation")
	# A saddle distinguishes the new curved patch from the old diagonal plane.
	map.elevation_vertices.fill(0.0)
	map.elevation_vertices[map._vertex_index(3, 3)] = 100.0
	assert(is_equal_approx(map.elevation_at(Vector2(125, 125)), 25.0))
	for y in range(0, 500, 7):
		for x in range(0, 500, 7):
			assert(is_finite(map.elevation_at(Vector2(x, y))) and map.elevation_at(Vector2(x, y)) >= 0.0)
	map.free()
	print("TERRAIN_CONTOURS_OK cell_centres=100 continuous_probes=996 rounded_corner=1 pond=1 crossing=1")
	quit()

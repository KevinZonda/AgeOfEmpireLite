extends SceneTree

const Surface = preload("res://scripts/world/terrain_surface.gd")
const Generation = preload("res://tests/terrain_generation.gd")
# Existing navigation, resources, decorations, objectives and RNG sequence.
const LAYOUT_HASHES := ["c0ee61ff50138792ec965c305da5ac166408d30d495630c059e9d7455009fc8e", "3a849211715fe20cc6eb85ca668bde986143ce21d417e506d13b2f0727382dc4", "4c8c112e4e820f2a0cb130b1a026539fea3e528742d7996aa50f6eec6ff3d243", "97983e2d5e0c1ab57850fe63b4fa326dda01a1c0b2383c0eec32cfd82565a822", "c0ee61ff50138792ec965c305da5ac166408d30d495630c059e9d7455009fc8e", "8489606e9f56386d3aa23485622fcd2082cf693f91176ac8a0723c497a44cf89"]

func _initialize() -> void:
	var water_vertices := 0
	var blends := 0
	var seams := 0
	for case in Generation.CASES.size():
		var inputs: Array = Generation.CASES[case]
		var map := RtsWorldMap.new()
		map.generate(inputs[0], inputs[1], inputs[2], inputs[3])
		var hash := HashingContext.new()
		hash.start(HashingContext.HASH_SHA256)
		hash.update(var_to_bytes([map.cells, map.elevation_levels, map.reachable_cells, map.plants, map.stealth_patches, map.resource_specs, map.layout_bases, map.terrain_shapes, map.sacred_site_references, map.trade_site_references, map.fish_site_references, map.crossing_references, map.rng.state]))
		assert(hash.finish().hex_encode() == LAYOUT_HASHES[case], "terrain refinement changed gameplay layout in case %d" % case)
		var surface := Surface.new()
		surface.build(map)
		var again := Surface.new()
		again.build(map)
		assert(surface.colors == again.colors, "terrain materials must be reproducible")
		for y in map.grid_size.y + 1:
			for x in map.grid_size.x + 1:
				var index := map._vertex_index(x, y)
				assert(is_finite(map.elevation_vertices[index]) and map.elevation_vertices[index] >= 0.0)
				if map._vertex_touches_water(x, y):
					assert(map.elevation_vertices[index] == 0.0, "a shoreline or lake vertex was raised")
					water_vertices += 1
				if surface.rocks[index] > 0.05 and surface.rocks[index] < 0.95: blends += 1
		for y in range(1, map.grid_size.y - 1):
			for x in range(1, map.grid_size.x):
				var point := Vector2(x * RtsWorldMap.CELL_SIZE, (y + 0.4) * RtsWorldMap.CELL_SIZE)
				var left := surface.color_at(map, point - Vector2(0.01, 0))
				var right := surface.color_at(map, point + Vector2(0.01, 0))
				assert(absf(left.r - right.r) + absf(left.g - right.g) + absf(left.b - right.b) < 0.005, "material jumps at a terrain cell seam")
				assert(absf(map.elevation_at(point - Vector2(0.01, 0)) - map.elevation_at(point + Vector2(0.01, 0))) < 0.1, "height jumps at a terrain cell seam")
				seams += 1
		map.free()
	assert(blends > 100 and water_vertices > 100)
	print("TERRAIN_SURFACE_OK layouts=6 blended_vertices=%d water_vertices=%d continuous_seams=%d" % [blends, water_vertices, seams])
	quit()

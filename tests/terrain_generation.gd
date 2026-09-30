extends SceneTree

const CASES := [
	[12345, Vector2(2400, 1800), "balanced", 2],
	[67890, Vector2(2400, 1800), "lakes", 3],
	[13579, Vector2(3200, 2200), "highlands", 4],
	[24680, Vector2(3200, 2200), "islands", 2],
	[12345, Vector2(2400, 1800), "invalid", 1],
	[67890, Vector2(3200, 2200), "balanced", 8],
]

# Baseline hashes include terrain, decoration/resource ordering, elevations and RNG state.
const EXPECTED := ["82e3e26cc3b908882df1f612a69b23959188d3efcacaf88849fa5cc21420bd1a", "96a1c63800bbd3b1948c806fb3ea376b3c8d2a6ca3fbdfdd0c629dec35b52871", "efd048fed4c2e27a2a7d43957d36b0512713413e7a0dd19b6cac08a84e8d0fb4", "ea3223b6685280e4e904ac0df189453e8d5817959defc1ff606a77fe7c1c896e", "82e3e26cc3b908882df1f612a69b23959188d3efcacaf88849fa5cc21420bd1a", "1071af2847d8fcc359f8c867a63b4be9465c72ed98a6478034b5ef86c5e288da"]

func _initialize() -> void:
	for i in CASES.size():
		var inputs: Array = CASES[i]
		var map := RtsWorldMap.new()
		map.generate(inputs[0], inputs[1], inputs[2], inputs[3])
		var hash := HashingContext.new()
		hash.start(HashingContext.HASH_SHA256)
		hash.update(var_to_bytes([map.cells, map.elevation_levels, map.elevation_vertices, map.reachable_cells, map.plants, map.stealth_patches, map.resource_specs, map.layout_bases, map.terrain_shapes, map.sacred_site_references, map.trade_site_references, map.fish_site_references, map.crossing_references, map.rng.state]))
		assert(hash.finish().hex_encode() == EXPECTED[i], "full map generation changed for case %d" % i)
		var preview := RtsWorldMap.new()
		preview.generate_terrain(inputs[0], inputs[1], inputs[2], inputs[3])
		assert(preview.cells == map.cells and preview.layout_bases == map.layout_bases)
		assert(preview.spawn_positions() == map.spawn_positions())
		assert(preview.sacred_site_positions() == map.sacred_site_positions())
		assert(preview.trade_post_positions() == map.trade_post_positions())
		assert(preview.resource_specs.is_empty() and preview.plants.is_empty())
		assert(preview.map_style == map.map_style and preview.player_count == map.player_count)
		preview.free()
		map.generate_terrain(inputs[0], inputs[1], inputs[2], inputs[3])
		assert(map.resource_specs.is_empty() and map.plants.is_empty(), "terrain-only reuse must clear old decorations")
		map.free()
	print("TERRAIN_GENERATION_OK")
	quit()

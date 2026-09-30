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
# Refined deterministic ridges; water-adjacent shared vertices remain at zero.
# tests/terrain_surface.gd separately pins the unchanged gameplay layout.
const EXPECTED := ["e71ad761591c6b5c9270d3f60a7dd8d0b4dcee1df8ebdf9ea1265b4a918cf979", "084a58c38fbc5bb8cf52608f511c35b276845e310a6da9c1148c68735add10b6", "674fbb0a10a708c22f40b1b4561e413ca2cd08a68d36c4b02ef3d3e8e4a7f8bd", "ea3223b6685280e4e904ac0df189453e8d5817959defc1ff606a77fe7c1c896e", "e71ad761591c6b5c9270d3f60a7dd8d0b4dcee1df8ebdf9ea1265b4a918cf979", "55735e6d3a35524cb86189f283df105d480b33dadcc1b477aabe59850a63a15a"]

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

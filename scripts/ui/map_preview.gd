class_name RtsMapPreview
extends RefCounted

const PIXELS_PER_CELL := 4
const TERRAIN_COLORS := [
	Color("789b68"), Color("9db477"), Color("467f9f"),
	Color("777d76"), Color("b7a577"),
]

static func create_texture(seed_value: int, world_size: Vector2, style: String, player_colors: Array[Color]) -> ImageTexture:
	# Mirror the terrain phase of RtsWorldMap.generate without building resources,
	# paths, or elevation meshes just to draw a small setup preview.
	var map := RtsWorldMap.new()
	map.map_seed = seed_value
	map.world_size = world_size
	map.grid_size = Vector2i(ceili(world_size.x / map.CELL_SIZE), ceili(world_size.y / map.CELL_SIZE))
	map.map_style = style
	map.player_count = player_colors.size()
	map.rng.seed = seed_value
	map._plan_layout()
	map.cells.resize(map.grid_size.x * map.grid_size.y)
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.004
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3
	for y in map.grid_size.y:
		for x in map.grid_size.x:
			var point := map._reference_point(map.cell_center(Vector2i(x, y)))
			map.cells[y * map.grid_size.x + x] = map._layout_terrain(point, noise.get_noise_2d(point.x, point.y))
	map._setup_pathfinder()
	var image := Image.create_empty(map.grid_size.x * PIXELS_PER_CELL, map.grid_size.y * PIXELS_PER_CELL, false, Image.FORMAT_RGBA8)
	for y in map.grid_size.y:
		for x in map.grid_size.x:
			var terrain: int = map.cells[y * map.grid_size.x + x]
			image.fill_rect(Rect2i(x * PIXELS_PER_CELL, y * PIXELS_PER_CELL, PIXELS_PER_CELL, PIXELS_PER_CELL), TERRAIN_COLORS[terrain])
	for post in map.trade_post_positions(): _dot(image, map, post, Color("9b5fbd"), 6)
	for site in map.sacred_site_positions(): _dot(image, map, site, Color("ffe29a"), 7)
	var spawns := map.spawn_positions()
	for index in spawns.size():
		_dot(image, map, spawns[index], Color("27302c"), 10)
		_dot(image, map, spawns[index], player_colors[index], 7)
	map.free()
	return ImageTexture.create_from_image(image)

static func _dot(image: Image, map: RtsWorldMap, point: Vector2, color: Color, diameter: int) -> void:
	var pixel := Vector2i(point / map.world_size * Vector2(image.get_size()))
	image.fill_rect(Rect2i(pixel - Vector2i(diameter / 2, diameter / 2), Vector2i(diameter, diameter)), color)

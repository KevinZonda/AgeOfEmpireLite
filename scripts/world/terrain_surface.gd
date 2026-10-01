extends RefCounted

# Shared material samples at terrain vertices. Adjacent cells use the exact
# same blend, so the rock/soil/grass transition does not reveal the tile grid.
var colors := PackedColorArray()
var rocks := PackedFloat32Array()
var noise := FastNoiseLite.new()
var detail_noise := FastNoiseLite.new()

func build(map: RtsWorldMap) -> void:
	noise.seed = map.map_seed
	noise.frequency = 0.004
	noise.fractal_octaves = 3
	detail_noise.seed = map.map_seed ^ 0x217f
	detail_noise.frequency = 0.016
	detail_noise.fractal_octaves = 2
	var width := map.grid_size.x + 1
	colors.resize(width * (map.grid_size.y + 1))
	rocks.resize(colors.size())
	for y in map.grid_size.y + 1:
		for x in width:
			var point := Vector2(x, y) * RtsWorldMap.CELL_SIZE
			var reference := map._reference_point(point)
			var variation := noise.get_noise_2d(reference.x, reference.y)
			var detail := detail_noise.get_noise_2d(reference.x, reference.y)
			var mountain := 0.0
			var road := 0.0
			var samples := 0.0
			for offset in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i.ZERO]:
				var cell: Vector2i = Vector2i(x, y) + offset
				if cell.x < 0 or cell.y < 0 or cell.x >= map.grid_size.x or cell.y >= map.grid_size.y: continue
				samples += 1.0
				var terrain: int = map.cells[map._index(cell)]
				if terrain == RtsWorldMap.Terrain.MOUNTAIN: mountain += 1.0
				if terrain == RtsWorldMap.Terrain.ROAD: road += 1.0
			var rock := smoothstep(0.10, 0.90, mountain / maxf(samples, 1.0) + detail * 0.12)
			var height := map._visual_vertex_height(x, y)
			var east := (map._visual_vertex_height(x + 1, y) - map._visual_vertex_height(x - 1, y)) / (2.0 * RtsWorldMap.CELL_SIZE)
			var south := (map._visual_vertex_height(x, y + 1) - map._visual_vertex_height(x, y - 1)) / (2.0 * RtsWorldMap.CELL_SIZE)
			var slope := Vector2(east, south).length()
			var grass := Color("658756").lerp(Color("849b65"), smoothstep(-0.45, 0.45, variation))
			# Dry grass and exposed soil gather on slopes in broad irregular patches.
			var soil := clampf(slope * 0.18 + height * 0.0007 + maxf(detail, 0.0) * 0.30, 0.0, 0.34)
			grass = grass.lerp(Color("a59a72"), soil)
			grass = grass.lerp(Color("9a9872"), road / maxf(samples, 1.0) * 0.72)
			var stone := Color("68715f").lerp(Color("c8c3a8"), smoothstep(45.0, 180.0, height))
			stone = stone.lerp(Color("a49b7e"), clampf(0.18 + detail * 0.2, 0.0, 0.4))
			var color := grass.lerp(stone, rock)
			# The top-down view still reads slope lighting and rock strata.
			color *= lerpf(clampf(0.97 - east * 0.18 - south * 0.14, 0.71, 1.18), 1.0, rock * 0.85 if map.isometric_view else 0.0)
			color.a = 1.0
			colors[y * width + x] = color
			rocks[y * width + x] = rock

func color_at(map: RtsWorldMap, point: Vector2) -> Color:
	var cell := map.cell_at(point)
	var fraction := ((point - Vector2(cell) * RtsWorldMap.CELL_SIZE) / RtsWorldMap.CELL_SIZE).clamp(Vector2.ZERO, Vector2.ONE)
	var index := cell.y * (map.grid_size.x + 1) + cell.x
	var width := map.grid_size.x + 1
	return colors[index].lerp(colors[index + 1], fraction.x).lerp(colors[index + width].lerp(colors[index + width + 1], fraction.x), fraction.y)

func rock_at(map: RtsWorldMap, point: Vector2) -> float:
	var cell := map.cell_at(point)
	var fraction := ((point - Vector2(cell) * RtsWorldMap.CELL_SIZE) / RtsWorldMap.CELL_SIZE).clamp(Vector2.ZERO, Vector2.ONE)
	var index := cell.y * (map.grid_size.x + 1) + cell.x
	var width := map.grid_size.x + 1
	return lerpf(lerpf(rocks[index], rocks[index + 1], fraction.x), lerpf(rocks[index + width], rocks[index + width + 1], fraction.x), fraction.y)

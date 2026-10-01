extends RefCounted

# A continuous material field derived from the navigation cells. Sampling cell
# centres preserves small lakes, narrow crossings and edited/manual maps.
const PALETTE := [Color("789b68"), Color("9db477"), Color("437e9f"), Color("777d76"), Color("a6a078")]
const SUBDIVISIONS := 4
const SHORE_SUBDIVISIONS := 8

static func _cubic(a: float, b: float, c: float, d: float, t: float) -> float:
	return b + 0.5 * t * (c - a + t * (2.0 * a - 5.0 * b + 4.0 * c - d + t * (3.0 * (b - c) + d - a)))

static func _terrain(map: RtsWorldMap, x: int, y: int) -> int:
	return map.cells[map._index(Vector2i(clampi(x, 0, map.grid_size.x - 1), clampi(y, 0, map.grid_size.y - 1)))]

static func water_at(map: RtsWorldMap, point: Vector2) -> float:
	var local := point / RtsWorldMap.CELL_SIZE - Vector2.ONE * 0.5
	var cell := Vector2i(floori(local.x), floori(local.y))
	var fraction := local - Vector2(cell)
	var rows := PackedFloat32Array()
	for y in range(-1, 3):
		var values := PackedFloat32Array()
		for x in range(-1, 3):
			values.append(1.0 if _terrain(map, cell.x + x, cell.y + y) == RtsWorldMap.Terrain.WATER else 0.0)
		rows.append(_cubic(values[0], values[1], values[2], values[3], fraction.x))
	return clampf(_cubic(rows[0], rows[1], rows[2], rows[3], fraction.y), 0.0, 1.0)

static func near_shore(map: RtsWorldMap, x: int, y: int) -> bool:
	var water := _terrain(map, x, y) == RtsWorldMap.Terrain.WATER
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if (_terrain(map, x + dx, y + dy) == RtsWorldMap.Terrain.WATER) != water: return true
	return false

static func shore_color(land: Color, water: float) -> Color:
	var bank := land.lerp(Color("b3b38a"), smoothstep(0.08, 0.43, water) * 0.86)
	var shallow := Color("82b5b6").lerp(Color("437e9f"), smoothstep(0.53, 1.0, water))
	return bank.lerp(shallow, smoothstep(0.43, 0.57, water))

static func _land_color(map: RtsWorldMap, x: int, y: int) -> Color:
	var terrain := _terrain(map, x, y)
	return PALETTE[0 if terrain == RtsWorldMap.Terrain.WATER else terrain]

static func overview_image(map: RtsWorldMap, pixels_per_cell := 4) -> Image:
	var image := Image.create(map.grid_size.x * pixels_per_cell, map.grid_size.y * pixels_per_cell, false, Image.FORMAT_RGBA8)
	for y in image.get_height():
		for x in image.get_width():
			var point := (Vector2(x, y) + Vector2.ONE * 0.5) * RtsWorldMap.CELL_SIZE / pixels_per_cell
			var local := point / RtsWorldMap.CELL_SIZE - Vector2.ONE * 0.5
			var cell := Vector2i(floori(local.x), floori(local.y))
			var fraction := local - Vector2(cell)
			var top := _land_color(map, cell.x, cell.y).lerp(_land_color(map, cell.x + 1, cell.y), fraction.x)
			var bottom := _land_color(map, cell.x, cell.y + 1).lerp(_land_color(map, cell.x + 1, cell.y + 1), fraction.x)
			var land := top.lerp(bottom, fraction.y)
			# Water is composited once from the same field as the main view.
			image.set_pixel(x, y, shore_color(land, water_at(map, point)))
	return image

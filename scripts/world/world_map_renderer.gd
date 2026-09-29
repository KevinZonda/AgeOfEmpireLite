extends RefCounted

# Drawing stays on the map CanvasItem, so existing queue_redraw calls and z order apply.
const GRASS_DARK := Color("688e5e")
const GRASS_LIGHT := Color("7d9b64")
static var white_texture: ImageTexture


class MapMeshBuilder:
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	func triangle(a: Vector2, b: Vector2, c: Vector2, ca: Color, cb: Color, cc: Color) -> void:
		var first := vertices.size()
		vertices.append(Vector3(a.x, a.y, 0.0))
		vertices.append(Vector3(b.x, b.y, 0.0))
		vertices.append(Vector3(c.x, c.y, 0.0))
		colors.append_array(PackedColorArray([ca, cb, cc]))
		indices.append_array(PackedInt32Array([first, first + 1, first + 2]))

	func quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, ca: Color, cb: Color, cc: Color, cd: Color) -> void:
		var first := vertices.size()
		for point in [a, b, c, d]: vertices.append(Vector3(point.x, point.y, 0.0))
		colors.append_array(PackedColorArray([ca, cb, cc, cd]))
		indices.append_array(PackedInt32Array([first, first + 1, first + 2, first, first + 2, first + 3]))

	func line(a: Vector2, b: Vector2, color: Color, width: float) -> void:
		var side := (b - a).normalized().orthogonal() * width * 0.5
		quad(a - side, b - side, b + side, a + side, color, color, color, color)

	func circle(center: Vector2, radius: float, color: Color) -> void:
		for step in 8:
			var a := center + Vector2.from_angle(TAU * step / 8.0) * radius
			var b := center + Vector2.from_angle(TAU * (step + 1) / 8.0) * radius
			triangle(center, a, b, color, color, color)

	func finish() -> ArrayMesh:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return mesh


static func _white_texture() -> ImageTexture:
	if white_texture == null:
		var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		image.fill(Color.WHITE)
		white_texture = ImageTexture.create_from_image(image)
	return white_texture


static func _ground_mesh(map: RtsWorldMap, grass_colors: PackedColorArray) -> ArrayMesh:
	var builder := MapMeshBuilder.new()
	var stride := map.grid_size.x + 1
	for y in map.grid_size.y:
		for x in map.grid_size.x:
			var cell := Vector2i(x, y)
			var terrain: int = map.cells[map._index(cell)]
			var point := Vector2(x * RtsWorldMap.CELL_SIZE, y * RtsWorldMap.CELL_SIZE)
			var end := point + Vector2.ONE * RtsWorldMap.CELL_SIZE
			if terrain in [RtsWorldMap.Terrain.GRASS, RtsWorldMap.Terrain.MEADOW]:
				builder.quad(point, Vector2(end.x, point.y), end, Vector2(point.x, end.y), grass_colors[y * stride + x], grass_colors[y * stride + x + 1], grass_colors[(y + 1) * stride + x + 1], grass_colors[(y + 1) * stride + x])
			else:
				var color := Color("437e9f") if terrain == RtsWorldMap.Terrain.WATER else Color("879468") if terrain == RtsWorldMap.Terrain.ROAD else Color("686f68").lerp(Color("adb0a1"), clampf((map.elevation_at(point + Vector2.ONE * RtsWorldMap.CELL_SIZE * 0.5) - 60.0) / 140.0, 0.0, 1.0))
				builder.quad(point, Vector2(end.x, point.y), end, Vector2(point.x, end.y), color, color, color, color)
	return builder.finish()


static func _plants_mesh(map: RtsWorldMap) -> ArrayMesh:
	var builder := MapMeshBuilder.new()
	for plant in map.plants:
		var point: Vector2 = plant["position"]
		if map.isometric_view: point += tile_lift(map, map.elevation_at(point))
		var size: float = plant["size"]
		if plant["flower"]:
			builder.circle(point, size * 0.45, Color("e2c078"))
			builder.circle(point + Vector2(3, 2), size * 0.25, Color("f1e5c4"))
		else:
			builder.line(point, point + Vector2(-size * 0.6, -size), Color("3e7041"), 2.0)
			builder.line(point, point + Vector2(size * 0.5, -size * 0.8), Color("467b43"), 2.0)
	return builder.finish()


static func _accents_mesh(map: RtsWorldMap) -> ArrayMesh:
	var builder := MapMeshBuilder.new()
	for y in map.grid_size.y:
		for x in map.grid_size.x:
			var terrain: int = map.cells[map._index(Vector2i(x, y))]
			var point := Vector2(x * RtsWorldMap.CELL_SIZE, y * RtsWorldMap.CELL_SIZE)
			if terrain == RtsWorldMap.Terrain.WATER:
				builder.line(point + Vector2(9, 19), point + Vector2(27, 19), Color("8fc3cf", 0.45), 2.0)
				builder.line(point + Vector2(24, 35), point + Vector2(43, 35), Color("8fc3cf", 0.34), 2.0)
				if y > 0 and map.cells[map._index(Vector2i(x, y - 1))] != RtsWorldMap.Terrain.WATER:
					builder.line(point, point + Vector2(RtsWorldMap.CELL_SIZE, 0), Color("b8c6a0", 0.7), 2.0)
				if x > 0 and map.cells[map._index(Vector2i(x - 1, y))] != RtsWorldMap.Terrain.WATER:
					builder.line(point, point + Vector2(0, RtsWorldMap.CELL_SIZE), Color("b8c6a0", 0.7), 2.0)
			elif terrain == RtsWorldMap.Terrain.MOUNTAIN and not map.isometric_view:
				var color := Color("686f68").lerp(Color("adb0a1"), clampf((map.elevation_at(point + Vector2.ONE * RtsWorldMap.CELL_SIZE * 0.5) - 60.0) / 140.0, 0.0, 1.0))
				if (x * 7 + y * 11) % 4 == 0:
					builder.line(point + Vector2(9, 31), point + Vector2(23, 18), color.lightened(0.19), 2.0)
					builder.line(point + Vector2(23, 18), point + Vector2(32, 21), color.darkened(0.24), 2.0)
				if map.elevation_at(point + Vector2.ONE * RtsWorldMap.CELL_SIZE * 0.5) > 145.0:
					builder.line(point + Vector2(17, 12), point + Vector2(31, 9), Color("dedecf", 0.55), 3.0)
			elif terrain == RtsWorldMap.Terrain.ROAD and x % 3 == 0 and y % 2 == 0:
				builder.line(point + Vector2(10, 27), point + Vector2(35, 25), Color("b1aa75", 0.25), 2.0)
			elif terrain in [RtsWorldMap.Terrain.GRASS, RtsWorldMap.Terrain.MEADOW] and (x * 13 + y * 7) % 5 == 0:
				var color := Color("7d9b64") if terrain == RtsWorldMap.Terrain.MEADOW else Color("688e5e")
				builder.line(point + Vector2(11, 34), point + Vector2(14, 29), color.lightened(0.10), 1.0)
				builder.line(point + Vector2(14, 29), point + Vector2(18, 33), color.darkened(0.08), 1.0)
	return builder.finish()


static func _apron_mesh(map: RtsWorldMap) -> ArrayMesh:
	var builder := MapMeshBuilder.new()
	for y in range(-RtsWorldMap.VISUAL_APRON_CELLS, map.grid_size.y + RtsWorldMap.VISUAL_APRON_CELLS):
		for x in range(-RtsWorldMap.VISUAL_APRON_CELLS, map.grid_size.x + RtsWorldMap.VISUAL_APRON_CELLS):
			if x >= 0 and y >= 0 and x < map.grid_size.x and y < map.grid_size.y: continue
			var point := Vector2(x, y) * RtsWorldMap.CELL_SIZE
			var end := point + Vector2.ONE * RtsWorldMap.CELL_SIZE
			builder.quad(point, Vector2(end.x, point.y), end, Vector2(point.x, end.y), RtsWorldMap.OUTSIDE_COLOR, RtsWorldMap.OUTSIDE_COLOR, RtsWorldMap.OUTSIDE_COLOR, RtsWorldMap.OUTSIDE_COLOR)
	return builder.finish()


static func _relief_mesh(map: RtsWorldMap, grass_colors: PackedColorArray) -> ArrayMesh:
	var builder := MapMeshBuilder.new()
	for y in range(-RtsWorldMap.VISUAL_APRON_CELLS, map.grid_size.y + RtsWorldMap.VISUAL_APRON_CELLS):
		for x in range(-RtsWorldMap.VISUAL_APRON_CELLS, map.grid_size.x + RtsWorldMap.VISUAL_APRON_CELLS):
			var h_nw := visual_vertex_height(map, x, y)
			var h_ne := visual_vertex_height(map, x + 1, y)
			var h_se := visual_vertex_height(map, x + 1, y + 1)
			var h_sw := visual_vertex_height(map, x, y + 1)
			if maxf(maxf(h_nw, h_ne), maxf(h_se, h_sw)) < 0.5: continue
			var nw := projected_vertex(map, x, y)
			var ne := projected_vertex(map, x + 1, y)
			var se := projected_vertex(map, x + 1, y + 1)
			var sw := projected_vertex(map, x, y + 1)
			var terrain: int = map.cells[map._index(Vector2i(clampi(x, 0, map.grid_size.x - 1), clampi(y, 0, map.grid_size.y - 1)))]
			var outside := x < 0 or y < 0 or x >= map.grid_size.x or y >= map.grid_size.y
			if outside:
				builder.quad(nw, ne, se, sw, RtsWorldMap.OUTSIDE_COLOR, RtsWorldMap.OUTSIDE_COLOR, RtsWorldMap.OUTSIDE_COLOR, RtsWorldMap.OUTSIDE_COLOR)
				continue
			if not outside and terrain in [RtsWorldMap.Terrain.GRASS, RtsWorldMap.Terrain.MEADOW]:
				var stride := map.grid_size.x + 1
				var c_nw := grass_colors[y * stride + x]
				var c_ne := grass_colors[y * stride + x + 1]
				var c_se := grass_colors[(y + 1) * stride + x + 1]
				var c_sw := grass_colors[(y + 1) * stride + x]
				builder.quad(nw, ne, se, sw, c_nw, c_ne, c_se, c_sw)
				continue
			var average := (h_nw + h_ne + h_se + h_sw) * 0.25
			var color := RtsWorldMap.OUTSIDE_COLOR if outside else relief_color(terrain, average)
			var east_slope := (h_ne + h_se - h_nw - h_sw) / (2.0 * RtsWorldMap.CELL_SIZE)
			var south_slope := (h_sw + h_se - h_nw - h_ne) / (2.0 * RtsWorldMap.CELL_SIZE)
			var light := clampf(0.98 - east_slope * 0.16 - south_slope * 0.12, 0.72, 1.15)
			builder.triangle(nw, ne, se, color * light, color * light, color * light)
			var second := color * clampf(light - (h_sw - h_ne) / 500.0, 0.69, 1.13)
			builder.triangle(nw, se, sw, second, second, second)
			if not outside and terrain == RtsWorldMap.Terrain.MOUNTAIN and average > 65.0 and (x * 7 + y * 11) % 4 == 0:
				var scratch := nw.lerp(se, 0.37)
				builder.line(scratch, scratch.lerp(ne, 0.30), Color(color.darkened(0.20), 0.55), 1.2)
				if average > 105.0: builder.line(nw.lerp(ne, 0.38), nw.lerp(se, 0.53), Color("eee9d4", 0.40), 1.4)
	return builder.finish()

static func tile_lift(map: RtsWorldMap, height: float) -> Vector2:
	return map.lift_per_height * height


static func visual_vertex_height(map: RtsWorldMap, x: int, y: int) -> float:
	var inside_x := clampi(x, 0, map.grid_size.x)
	var inside_y := clampi(y, 0, map.grid_size.y)
	var outside := maxi(absi(x - inside_x), absi(y - inside_y))
	return map._vertex_height(inside_x, inside_y) * clampf(1.0 - float(outside) / RtsWorldMap.VISUAL_APRON_CELLS, 0.0, 1.0)


static func projected_vertex(map: RtsWorldMap, x: int, y: int) -> Vector2:
	return Vector2(x, y) * RtsWorldMap.CELL_SIZE + tile_lift(map, visual_vertex_height(map, x, y))


static func relief_color(terrain: int, height: float) -> Color:
	if terrain == RtsWorldMap.Terrain.MOUNTAIN:
		return Color("777b71").lerp(Color("d8d6c5"), clampf((height - 70.0) / 110.0, 0.0, 1.0))
	var grass := Color("88a36e") if terrain == RtsWorldMap.Terrain.MEADOW else Color("759761")
	return grass.lerp(Color("a49d79"), clampf(height / 105.0, 0.0, 0.78))


static func grass_vertex_colors(map: RtsWorldMap) -> PackedColorArray:
	var noise := FastNoiseLite.new()
	noise.seed = map.map_seed
	noise.frequency = 0.004
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3
	var width := map.grid_size.x + 1
	var colors := PackedColorArray()
	colors.resize(width * (map.grid_size.y + 1))
	for y in map.grid_size.y + 1:
		for x in width:
			var point := Vector2(x, y) * RtsWorldMap.CELL_SIZE
			var reference := map._reference_point(point)
			var variation := noise.get_noise_2d(reference.x, reference.y)
			var color := GRASS_DARK.lerp(GRASS_LIGHT, smoothstep(-0.2, 0.45, variation))
			if map.isometric_view:
				var height := visual_vertex_height(map, x, y)
				color = color.lerp(Color("a49d79"), clampf(height / 105.0, 0.0, 0.78))
				var east_slope := (visual_vertex_height(map, x + 1, y) - visual_vertex_height(map, x - 1, y)) / (2.0 * RtsWorldMap.CELL_SIZE)
				var south_slope := (visual_vertex_height(map, x, y + 1) - visual_vertex_height(map, x, y - 1)) / (2.0 * RtsWorldMap.CELL_SIZE)
				color *= clampf(0.98 - east_slope * 0.16 - south_slope * 0.12, 0.72, 1.15)
				color.a = 1.0
			colors[y * width + x] = color
	return colors


static func draw_relief_tile(map: RtsWorldMap, x: int, y: int, grass_colors: PackedColorArray) -> void:
	var h_nw := visual_vertex_height(map, x, y)
	var h_ne := visual_vertex_height(map, x + 1, y)
	var h_se := visual_vertex_height(map, x + 1, y + 1)
	var h_sw := visual_vertex_height(map, x, y + 1)
	if maxf(maxf(h_nw, h_ne), maxf(h_se, h_sw)) < 0.5: return
	var nw := projected_vertex(map, x, y)
	var ne := projected_vertex(map, x + 1, y)
	var se := projected_vertex(map, x + 1, y + 1)
	var sw := projected_vertex(map, x, y + 1)
	var terrain: int = map.cells[map._index(Vector2i(clampi(x, 0, map.grid_size.x - 1), clampi(y, 0, map.grid_size.y - 1)))]
	var average := (h_nw + h_ne + h_se + h_sw) * 0.25
	var outside := x < 0 or y < 0 or x >= map.grid_size.x or y >= map.grid_size.y
	if outside:
		map.draw_colored_polygon(PackedVector2Array([nw, ne, se, sw]), RtsWorldMap.OUTSIDE_COLOR)
		return
	if not outside and terrain in [RtsWorldMap.Terrain.GRASS, RtsWorldMap.Terrain.MEADOW]:
		var stride := map.grid_size.x + 1
		var c_nw := grass_colors[y * stride + x]
		var c_ne := grass_colors[y * stride + x + 1]
		var c_se := grass_colors[(y + 1) * stride + x + 1]
		var c_sw := grass_colors[(y + 1) * stride + x]
		map.draw_polygon(PackedVector2Array([nw, ne, se]), PackedColorArray([c_nw, c_ne, c_se]))
		map.draw_polygon(PackedVector2Array([nw, se, sw]), PackedColorArray([c_nw, c_se, c_sw]))
		return
	var color := RtsWorldMap.OUTSIDE_COLOR if outside else relief_color(terrain, average)
	var east_slope := (h_ne + h_se - h_nw - h_sw) / (2.0 * RtsWorldMap.CELL_SIZE)
	var south_slope := (h_sw + h_se - h_nw - h_ne) / (2.0 * RtsWorldMap.CELL_SIZE)
	var light := clampf(0.98 - east_slope * 0.16 - south_slope * 0.12, 0.72, 1.15)
	map.draw_colored_polygon(PackedVector2Array([nw, ne, se]), color * light)
	map.draw_colored_polygon(PackedVector2Array([nw, se, sw]), color * clampf(light - (h_sw - h_ne) / 500.0, 0.69, 1.13))
	if not outside and terrain == RtsWorldMap.Terrain.MOUNTAIN and average > 65.0 and (x * 7 + y * 11) % 4 == 0:
		var rock_ink := color.darkened(0.20)
		var scratch := nw.lerp(se, 0.37)
		map.draw_line(scratch, scratch.lerp(ne, 0.30), Color(rock_ink, 0.55), 1.2)
		if average > 105.0:
			map.draw_line(nw.lerp(ne, 0.38), nw.lerp(se, 0.53), Color("eee9d4", 0.40), 1.4)


static func draw_map(map: RtsWorldMap) -> void:
	var grass_colors := grass_vertex_colors(map)
	map.draw_rect(Rect2(-map.world_size * 2.0, map.world_size * 5.0), RtsWorldMap.OUTSIDE_COLOR)
	if map.isometric_view:
		var camera := map.get_viewport().get_camera_2d()
		map.lift_per_height = RtsIsoProjection.world_delta(map.get_viewport().get_canvas_transform(), Vector2(0, -camera.zoom.x)) if camera != null else Vector2.ZERO
		map.apron_mesh = _apron_mesh(map)
		map.draw_mesh(map.apron_mesh, _white_texture())
	map.ground_mesh = _ground_mesh(map, grass_colors)
	map.draw_mesh(map.ground_mesh, _white_texture())
	map.accents_mesh = _accents_mesh(map)
	map.draw_mesh(map.accents_mesh, _white_texture())
	if map.isometric_view:
		map.relief_mesh = _relief_mesh(map, grass_colors)
		map.draw_mesh(map.relief_mesh, _white_texture())
		var border := Color("d1bc86", 0.74)
		for x in map.grid_size.x:
			map.draw_line(projected_vertex(map, x, 0), projected_vertex(map, x + 1, 0), border, 2.0)
			map.draw_line(projected_vertex(map, x, map.grid_size.y), projected_vertex(map, x + 1, map.grid_size.y), border, 2.0)
		for y in map.grid_size.y:
			map.draw_line(projected_vertex(map, 0, y), projected_vertex(map, 0, y + 1), border, 2.0)
			map.draw_line(projected_vertex(map, map.grid_size.x, y), projected_vertex(map, map.grid_size.x, y + 1), border, 2.0)
	for patch in map.stealth_patches:
		var center: Vector2 = patch["position"]
		if map.isometric_view: center += tile_lift(map, map.elevation_at(center))
		var radius: float = patch["radius"]
		map.draw_circle(center, radius, Color("254f37", 0.28))
		map.draw_arc(center, radius, 0.0, TAU, 48, Color("a1bc80", 0.5), 2.0)
	map.plants_mesh = _plants_mesh(map)
	map.draw_mesh(map.plants_mesh, _white_texture())

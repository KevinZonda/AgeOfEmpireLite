extends RefCounted

# Static ground draws on the map. Mountain patches also enter entity depth order.
const Surface = preload("res://scripts/world/terrain_surface.gd")
static var white_texture: ImageTexture


class MapMeshBuilder:
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var uvs := PackedVector2Array()

	func triangle(a: Vector2, b: Vector2, c: Vector2, ca: Color, cb: Color, cc: Color, uv_a := Vector2.ZERO, uv_b := Vector2.ZERO, uv_c := Vector2.ZERO) -> void:
		var first := vertices.size()
		vertices.append(Vector3(a.x, a.y, 0.0))
		vertices.append(Vector3(b.x, b.y, 0.0))
		vertices.append(Vector3(c.x, c.y, 0.0))
		colors.append_array(PackedColorArray([ca, cb, cc]))
		uvs.append_array(PackedVector2Array([uv_a, uv_b, uv_c]))
		indices.append_array(PackedInt32Array([first, first + 1, first + 2]))

	func quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, ca: Color, cb: Color, cc: Color, cd: Color) -> void:
		var first := vertices.size()
		for point in [a, b, c, d]: vertices.append(Vector3(point.x, point.y, 0.0))
		colors.append_array(PackedColorArray([ca, cb, cc, cd]))
		uvs.append_array(PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]))
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
		if vertices.is_empty(): return ArrayMesh.new()
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_TEX_UV] = uvs
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


static func _ground_mesh(map: RtsWorldMap, surface) -> ArrayMesh:
	var builder := MapMeshBuilder.new()
	for y in map.grid_size.y:
		for x in map.grid_size.x:
			var cell := Vector2i(x, y)
			var terrain: int = map.cells[map._index(cell)]
			var point := Vector2(x * RtsWorldMap.CELL_SIZE, y * RtsWorldMap.CELL_SIZE)
			var end := point + Vector2.ONE * RtsWorldMap.CELL_SIZE
			if map.isometric_view and maxf(maxf(visual_vertex_height(map, x, y), visual_vertex_height(map, x + 1, y)), maxf(visual_vertex_height(map, x, y + 1), visual_vertex_height(map, x + 1, y + 1))) >= 0.5: continue
			if terrain == RtsWorldMap.Terrain.WATER:
				var color := Color("437e9f")
				builder.quad(point, Vector2(end.x, point.y), end, Vector2(point.x, end.y), color, color, color, color)
			else:
				var points := [point, Vector2(end.x, point.y), end, Vector2(point.x, end.y)]
				if map.isometric_view: points = [projected_vertex(map, x, y), projected_vertex(map, x + 1, y), projected_vertex(map, x + 1, y + 1), projected_vertex(map, x, y + 1)]
				_surface_quad(builder, map, surface, x, y, points)
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


static func _relief_mesh(map: RtsWorldMap, surface, occluders: Dictionary) -> ArrayMesh:
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
			if terrain == RtsWorldMap.Terrain.WATER:
				var water := Color("437e9f")
				builder.quad(nw, ne, se, sw, water, water, water, water)
			else:
				_surface_quad(builder, map, surface, x, y, [nw, ne, se, sw], occluders if terrain == RtsWorldMap.Terrain.MOUNTAIN else null)
	return builder.finish()


static func _surface_quad(builder, map: RtsWorldMap, surface, x: int, y: int, points: Array, occluders = null) -> void:
	var stride := map.grid_size.x + 1
	var indices := [y * stride + x, y * stride + x + 1, (y + 1) * stride + x + 1, (y + 1) * stride + x]
	var heights := [visual_vertex_height(map, x, y), visual_vertex_height(map, x + 1, y), visual_vertex_height(map, x + 1, y + 1), visual_vertex_height(map, x, y + 1)]
	for triangle in [[0, 1, 2], [0, 2, 3]]:
		var east: float = (heights[1] - heights[0]) / RtsWorldMap.CELL_SIZE if triangle[1] == 1 else (heights[2] - heights[3]) / RtsWorldMap.CELL_SIZE
		var south: float = (heights[2] - heights[1]) / RtsWorldMap.CELL_SIZE if triangle[1] == 1 else (heights[3] - heights[0]) / RtsWorldMap.CELL_SIZE
		var light := clampf(0.59 + Vector3(-east, -south, 1).normalized().dot(Vector3(-0.55, -0.35, 0.76).normalized()) * 0.53, 0.60, 1.13)
		var shades: Array[Color] = []
		for corner in triangle:
			var color: Color = surface.colors[indices[corner]] * lerpf(1.0, light, surface.rocks[indices[corner]] if map.isometric_view else 0.0)
			color.a = 1.0
			shades.append(color)
		builder.triangle(points[triangle[0]], points[triangle[1]], points[triangle[2]], shades[0], shades[1], shades[2])
		if occluders != null:
			var corners := [Vector2(x, y), Vector2(x + 1, y), Vector2(x + 1, y + 1), Vector2(x, y + 1)]
			var a: Vector2 = corners[triangle[0]] * RtsWorldMap.CELL_SIZE
			var b: Vector2 = corners[triangle[1]] * RtsWorldMap.CELL_SIZE
			var c: Vector2 = corners[triangle[2]] * RtsWorldMap.CELL_SIZE
			var ab := (a + b) * 0.5
			var bc := (b + c) * 0.5
			var ca := (c + a) * 0.5
			var color_ab := shades[0].lerp(shades[1], 0.5)
			var color_bc := shades[1].lerp(shades[2], 0.5)
			var color_ca := shades[2].lerp(shades[0], 0.5)
			_occlusion_triangle(occluders, map, a, ab, ca, shades[0], color_ab, color_ca)
			_occlusion_triangle(occluders, map, ab, b, bc, color_ab, shades[1], color_bc)
			_occlusion_triangle(occluders, map, ca, bc, c, color_ca, color_bc, shades[2])
			_occlusion_triangle(occluders, map, ab, bc, ca, color_ab, color_bc, color_ca)


static func _occlusion_triangle(groups: Dictionary, map: RtsWorldMap, a: Vector2, b: Vector2, c: Vector2, ca: Color, cb: Color, cc: Color) -> void:
	# Decal jitter must not create hundreds of extra draw depths. Use the same
	# half-subtile depth bands as the coplanar mountain patches.
	var depth := clampi(roundi(snappedf((a.x + a.y + b.x + b.y + c.x + c.y) / 6.0, RtsWorldMap.CELL_SIZE * 0.25)), 0, 2800)
	if not groups.has(depth): groups[depth] = MapMeshBuilder.new()
	var extent := Vector2(map.grid_size) * RtsWorldMap.CELL_SIZE
	groups[depth].triangle(surface_point(map, a), surface_point(map, b), surface_point(map, c), ca, cb, cc, a / extent, b / extent, c / extent)


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
	# Generated lakes are flat. Preserve water material for legacy/manual maps
	# whose raised water vertices still require a projected relief surface.
	if terrain == RtsWorldMap.Terrain.WATER: return Color("437e9f")
	if terrain == RtsWorldMap.Terrain.MOUNTAIN:
		return Color("777b71").lerp(Color("d8d6c5"), clampf((height - 70.0) / 110.0, 0.0, 1.0))
	var grass := Color("88a36e") if terrain == RtsWorldMap.Terrain.MEADOW else Color("759761")
	return grass.lerp(Color("a49d79"), clampf(height / 105.0, 0.0, 0.78))


static func grass_vertex_colors(map: RtsWorldMap) -> PackedColorArray:
	var surface := Surface.new()
	surface.build(map)
	return surface.colors


static func surface_point(map: RtsWorldMap, point: Vector2) -> Vector2:
	return point + tile_lift(map, map.elevation_at(point)) if map.isometric_view else point


static func _details_mesh(map: RtsWorldMap, surface, occluders: Dictionary) -> ArrayMesh:
	var builder := MapMeshBuilder.new()
	var random := RandomNumberGenerator.new()
	for y in map.grid_size.y:
		for x in map.grid_size.x:
			var terrain: int = map.cells[map._index(Vector2i(x, y))]
			if terrain == RtsWorldMap.Terrain.WATER: continue
			random.seed = map.map_seed ^ (x * 73856093) ^ (y * 19349663)
			var count := 3 if terrain == RtsWorldMap.Terrain.MOUNTAIN else 1
			for sample in count:
				var point := (Vector2(x, y) + Vector2(random.randf_range(0.16, 0.84), random.randf_range(0.16, 0.84))) * RtsWorldMap.CELL_SIZE
				var base: Color = surface.color_at(map, point)
				var rock := terrain == RtsWorldMap.Terrain.MOUNTAIN or (map.elevation_at(point) > 35.0 and random.randf() < 0.40)
				if rock:
					var size := random.randf_range(1.5, 4.1)
					var a := surface_point(map, point + Vector2(-size, 0))
					var b := surface_point(map, point + Vector2(-size * 0.2, -size * 0.8))
					var c := surface_point(map, point + Vector2(size, size * 0.1))
					var d := surface_point(map, point + Vector2(size * 0.3, size * 0.7))
					builder.triangle(a, b, c, base.lightened(0.09), base.lightened(0.09), base.lightened(0.09))
					builder.triangle(a, c, d, base.darkened(0.18), base.darkened(0.18), base.darkened(0.18))
					if map.isometric_view and terrain == RtsWorldMap.Terrain.MOUNTAIN:
						var wa := point + Vector2(-size, 0)
						var wb := point + Vector2(-size * 0.2, -size * 0.8)
						var wc := point + Vector2(size, size * 0.1)
						var wd := point + Vector2(size * 0.3, size * 0.7)
						var light := base.lightened(0.09)
						var dark := base.darkened(0.18)
						_occlusion_triangle(occluders, map, wa, wb, wc, light, light, light)
						_occlusion_triangle(occluders, map, wa, wc, wd, dark, dark, dark)

					if random.randf() < 0.28:
						builder.line(surface_point(map, point + Vector2(-5, -8)), surface_point(map, point + Vector2(5, -11)), base.darkened(0.13), 0.8)
				elif terrain != RtsWorldMap.Terrain.ROAD and random.randf() < 0.55:
					var size := random.randf_range(2.0, 5.0)
					var center := surface_point(map, point)
					builder.line(center, surface_point(map, point + Vector2(-size * 0.5, -size)), base.darkened(0.13), 1.0)
					builder.line(center, surface_point(map, point + Vector2(size * 0.4, -size * 0.9)), base.lightened(0.05), 1.0)
	return builder.finish()


static func draw_map(map: RtsWorldMap) -> void:
	var surface := Surface.new()
	surface.build(map)
	var occluders := {}
	map.draw_rect(Rect2(-map.world_size * 2.0, map.world_size * 5.0), RtsWorldMap.OUTSIDE_COLOR)
	if map.isometric_view:
		var camera := map.get_viewport().get_camera_2d()
		map.lift_per_height = RtsIsoProjection.world_delta(map.get_viewport().get_canvas_transform(), Vector2(0, -camera.zoom.x)) if camera != null else Vector2.ZERO
		map.apron_mesh = _apron_mesh(map)
		map.draw_mesh(map.apron_mesh, _white_texture())
	map.ground_mesh = _ground_mesh(map, surface)
	map.draw_mesh(map.ground_mesh, _white_texture())
	map.accents_mesh = _accents_mesh(map)
	map.draw_mesh(map.accents_mesh, _white_texture())
	if map.isometric_view:
		map.relief_mesh = _relief_mesh(map, surface, occluders)
		map.draw_mesh(map.relief_mesh, _white_texture())
		var border := Color("d1bc86", 0.74)
		for x in map.grid_size.x:
			map.draw_line(projected_vertex(map, x, 0), projected_vertex(map, x + 1, 0), border, 2.0)
			map.draw_line(projected_vertex(map, x, map.grid_size.y), projected_vertex(map, x + 1, map.grid_size.y), border, 2.0)
		for y in map.grid_size.y:
			map.draw_line(projected_vertex(map, 0, y), projected_vertex(map, 0, y + 1), border, 2.0)
			map.draw_line(projected_vertex(map, map.grid_size.x, y), projected_vertex(map, map.grid_size.x, y + 1), border, 2.0)
	map.details_mesh = _details_mesh(map, surface, occluders)
	map.draw_mesh(map.details_mesh, _white_texture())
	for patch in map.stealth_patches:
		var center: Vector2 = patch["position"]
		if map.isometric_view: center += tile_lift(map, map.elevation_at(center))
		var radius: float = patch["radius"]
		map.draw_circle(center, radius, Color("254f37", 0.28))
		map.draw_arc(center, radius, 0.0, TAU, 48, Color("a1bc80", 0.5), 2.0)
	map.plants_mesh = _plants_mesh(map)
	map.draw_mesh(map.plants_mesh, _white_texture())
	map.update_terrain_occlusion(occluders, _white_texture())

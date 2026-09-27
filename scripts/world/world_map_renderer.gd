extends RefCounted

# Drawing stays on the map CanvasItem, so existing queue_redraw calls and z order apply.
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


static func draw_relief_tile(map: RtsWorldMap, x: int, y: int) -> void:
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
	if map.isometric_view:
		var camera := map.get_viewport().get_camera_2d()
		map.lift_per_height = RtsIsoProjection.world_delta(map.get_viewport().get_canvas_transform(), Vector2(0, -camera.zoom.x)) if camera != null else Vector2.ZERO
		map.draw_rect(Rect2(-map.world_size * 2.0, map.world_size * 5.0), RtsFogOfWar.UNEXPLORED_COLOR)
		for y in range(-RtsWorldMap.VISUAL_APRON_CELLS, map.grid_size.y + RtsWorldMap.VISUAL_APRON_CELLS):
			for x in range(-RtsWorldMap.VISUAL_APRON_CELLS, map.grid_size.x + RtsWorldMap.VISUAL_APRON_CELLS):
				if x >= 0 and y >= 0 and x < map.grid_size.x and y < map.grid_size.y: continue
				map.draw_rect(Rect2(Vector2(x, y) * RtsWorldMap.CELL_SIZE, Vector2.ONE * RtsWorldMap.CELL_SIZE), RtsWorldMap.OUTSIDE_COLOR)
	for y in map.grid_size.y:
		for x in map.grid_size.x:
			var cell := Vector2i(x, y)
			var terrain: int = map.cells[map._index(cell)]
			var point := Vector2(x * RtsWorldMap.CELL_SIZE, y * RtsWorldMap.CELL_SIZE)
			var color := Color("688e5e")
			match terrain:
				RtsWorldMap.Terrain.MEADOW: color = Color("7d9b64")
				RtsWorldMap.Terrain.WATER: color = Color("437e9f")
				RtsWorldMap.Terrain.MOUNTAIN: color = Color("686f68").lerp(Color("adb0a1"), clampf((map.elevation_at(point + Vector2.ONE * RtsWorldMap.CELL_SIZE * 0.5) - 60.0) / 140.0, 0.0, 1.0))
				RtsWorldMap.Terrain.ROAD: color = Color("879468")
			map.draw_rect(Rect2(point, Vector2(RtsWorldMap.CELL_SIZE, RtsWorldMap.CELL_SIZE)), color)
			if terrain == RtsWorldMap.Terrain.WATER:
				map.draw_line(point + Vector2(9, 19), point + Vector2(27, 19), Color("8fc3cf", 0.45), 2)
				map.draw_line(point + Vector2(24, 35), point + Vector2(43, 35), Color("8fc3cf", 0.34), 2)
				if y > 0 and map.cells[map._index(Vector2i(x, y - 1))] != RtsWorldMap.Terrain.WATER:
					map.draw_line(point, point + Vector2(RtsWorldMap.CELL_SIZE, 0), Color("b8c6a0", 0.7), 2.0)
				if x > 0 and map.cells[map._index(Vector2i(x - 1, y))] != RtsWorldMap.Terrain.WATER:
					map.draw_line(point, point + Vector2(0, RtsWorldMap.CELL_SIZE), Color("b8c6a0", 0.7), 2.0)
			elif terrain == RtsWorldMap.Terrain.MOUNTAIN and not map.isometric_view:
				if (x * 7 + y * 11) % 4 == 0:
					map.draw_line(point + Vector2(9, 31), point + Vector2(23, 18), color.lightened(0.19), 2)
					map.draw_line(point + Vector2(23, 18), point + Vector2(32, 21), color.darkened(0.24), 2)
				if map.elevation_at(point + Vector2.ONE * RtsWorldMap.CELL_SIZE * 0.5) > 145.0:
					map.draw_line(point + Vector2(17, 12), point + Vector2(31, 9), Color("dedecf", 0.55), 3)
			elif terrain == RtsWorldMap.Terrain.ROAD and x % 3 == 0 and y % 2 == 0:
				map.draw_line(point + Vector2(10, 27), point + Vector2(35, 25), Color("b1aa75", 0.25), 2)
			elif terrain in [RtsWorldMap.Terrain.GRASS, RtsWorldMap.Terrain.MEADOW] and (x * 13 + y * 7) % 5 == 0:
				map.draw_line(point + Vector2(11, 34), point + Vector2(14, 29), color.lightened(0.10), 1)
				map.draw_line(point + Vector2(14, 29), point + Vector2(18, 33), color.darkened(0.08), 1)
	if map.isometric_view:
		for y in range(-RtsWorldMap.VISUAL_APRON_CELLS, map.grid_size.y + RtsWorldMap.VISUAL_APRON_CELLS):
			for x in range(-RtsWorldMap.VISUAL_APRON_CELLS, map.grid_size.x + RtsWorldMap.VISUAL_APRON_CELLS):
				draw_relief_tile(map, x, y)
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
	for plant in map.plants:
		var point: Vector2 = plant["position"]
		if map.isometric_view: point += tile_lift(map, map.elevation_at(point))
		var size: float = plant["size"]
		if plant["flower"]:
			map.draw_circle(point, size * 0.45, Color("e2c078"))
			map.draw_circle(point + Vector2(3, 2), size * 0.25, Color("f1e5c4"))
		else:
			map.draw_line(point, point + Vector2(-size * 0.6, -size), Color("3e7041"), 2)
			map.draw_line(point, point + Vector2(size * 0.5, -size * 0.8), Color("467b43"), 2)

class_name RtsWorldMap
extends Node2D

const WorldMapRenderer = preload("res://scripts/world/world_map_renderer.gd")
const TerrainOcclusion = preload("res://scripts/world/terrain_occlusion.gd")

const CELL_SIZE := 50
const VISUAL_APRON_CELLS := 12
const OUTSIDE_COLOR := Color.BLACK
enum Terrain {GRASS, MEADOW, WATER, MOUNTAIN, ROAD}

var world_size := Vector2.ZERO
var grid_size := Vector2i.ZERO
var map_seed := 0
var map_style := "balanced"
var player_count := 2
var isometric_view := false
var cells := PackedByteArray()
var elevation_levels := PackedByteArray()
var elevation_vertices := PackedFloat32Array()
var maximum_elevation := 0.0
var reachable_cells := PackedByteArray()
var plants: Array[Dictionary] = []
var stealth_patches: Array[Dictionary] = []
var resource_specs: Array[Dictionary] = []
var layout_bases: Array[Vector2] = []
var terrain_shapes: Array[Dictionary] = []
var sacred_site_references: Array[Vector2] = []
var trade_site_references: Array[Vector2] = []
var fish_site_references: Array[Vector2] = []
var crossing_references: Array[float] = []
var barrier_x := 1200.0
var pathfinder := AStarGrid2D.new()
var rng := RandomNumberGenerator.new()
var lift_per_height := Vector2.ZERO
var ground_mesh: ArrayMesh
var accents_mesh: ArrayMesh
var plants_mesh: ArrayMesh
var apron_mesh: ArrayMesh
var relief_mesh: ArrayMesh
var details_mesh: ArrayMesh
var relief_noise := FastNoiseLite.new()
var occlusion_layer: Node2D
var occlusion_fog: Texture2D

func set_occlusion_fog(texture: Texture2D) -> void:
	occlusion_fog = texture
	if occlusion_layer != null: occlusion_layer.set_fog(texture)

func update_terrain_occlusion(groups: Dictionary, white: Texture2D) -> void:
	if not isometric_view:
		if occlusion_layer != null: occlusion_layer.hide()
		return
	if occlusion_layer == null:
		occlusion_layer = TerrainOcclusion.new()
		add_child(occlusion_layer)
	occlusion_layer.rebuild(groups, white, occlusion_fog)

func generate(seed_value: int, map_size: Vector2, style := "balanced", participants := 2) -> void:
	generate_terrain(seed_value, map_size, style, participants)
	_mark_reachable_cells()
	_generate_stealth_patches()
	_generate_plants()
	_generate_starter_resources()
	_generate_contested_resources()
	_generate_resource_clusters()
	_generate_sheep()
	_generate_wildlife()
	_generate_fish()
	_ensure_starter_access()
	_build_elevations()
	queue_redraw()

# The setup preview shares this deterministic terrain phase with full generation.
# It leaves the RNG at exactly the point where decorations/resources begin.
func generate_terrain(seed_value: int, map_size: Vector2, style := "balanced", participants := 2) -> void:
	map_seed = seed_value
	player_count = clampi(participants, 2, 4)
	map_style = style if ["balanced", "lakes", "highlands", "islands"].has(style) else "balanced"
	world_size = map_size
	grid_size = Vector2i(ceili(map_size.x / CELL_SIZE), ceili(map_size.y / CELL_SIZE))
	rng.seed = seed_value
	_plan_layout()
	cells.resize(grid_size.x * grid_size.y)
	plants.clear()
	stealth_patches.clear()
	resource_specs.clear()
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.004
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3
	for y in grid_size.y:
		for x in grid_size.x:
			var point := _reference_point(cell_center(Vector2i(x, y)))
			var variation := noise.get_noise_2d(point.x, point.y)
			var terrain := _layout_terrain(point, variation)
			cells[_index(Vector2i(x, y))] = terrain
	_setup_pathfinder()

func _plan_layout() -> void:
	terrain_shapes.clear()
	layout_bases.clear()
	sacred_site_references.clear()
	trade_site_references.clear()
	fish_site_references.clear()
	crossing_references.clear()
	barrier_x = 1200.0 + rng.randf_range(-85.0, 85.0)
	var base_y := 720.0 + rng.randf_range(-65.0, 65.0)
	if player_count <= 2:
		layout_bases.append_array([Vector2(330, base_y), Vector2(2070, base_y)])
	else:
		var upper_y := 420.0 + rng.randf_range(-45.0, 45.0)
		layout_bases.append_array([Vector2(330, upper_y), Vector2(2070, 1500.0 - upper_y), Vector2(330, 1500.0 - upper_y), Vector2(2070, upper_y)])
	if map_style == "balanced":
		terrain_shapes.append(_shape(Terrain.MOUNTAIN, Vector2(790 + rng.randf_range(-145, 145), 255 + rng.randf_range(-65, 65)), Vector2(275, 190)))
		terrain_shapes.append(_shape(Terrain.MOUNTAIN, Vector2(1660 + rng.randf_range(-165, 165), 265 + rng.randf_range(-70, 70)), Vector2(260, 185)))
		terrain_shapes.append(_shape(Terrain.WATER, Vector2(800 + rng.randf_range(-120, 120), 1220 + rng.randf_range(-60, 60)), Vector2(270, 195)))
		terrain_shapes.append(_shape(Terrain.WATER, Vector2(1580 + rng.randf_range(-170, 170), 1190 + rng.randf_range(-70, 70)), Vector2(280, 205)))
		sacred_site_references.append_array([Vector2(barrier_x - 125, 360), Vector2(barrier_x, 750), Vector2(barrier_x + 125, 1130)])
		trade_site_references.append_array([Vector2(barrier_x, 175), Vector2(barrier_x, 1325)])
		for shape in terrain_shapes:
			if shape["kind"] == Terrain.WATER: fish_site_references.append(shape["center"])
	elif map_style == "lakes":
		crossing_references.append_array([350.0 + rng.randf_range(-45, 45), 750.0 + rng.randf_range(-45, 45), 1150.0 + rng.randf_range(-45, 45)])
		terrain_shapes.append(_shape(Terrain.MOUNTAIN, Vector2(745 + rng.randf_range(-60, 60), 220), Vector2(180, 140)))
		terrain_shapes.append(_shape(Terrain.MOUNTAIN, Vector2(1660 + rng.randf_range(-60, 60), 240), Vector2(180, 140)))
		for y in crossing_references: sacred_site_references.append(Vector2(_barrier_center(y), y))
		trade_site_references.append_array([Vector2(barrier_x - 245, 175), Vector2(barrier_x + 245, 1325)])
		var upper_water := (crossing_references[0] + crossing_references[1]) * 0.5
		var lower_water := (crossing_references[1] + crossing_references[2]) * 0.5
		fish_site_references.append_array([Vector2(_barrier_center(170), 170), Vector2(_barrier_center(upper_water), upper_water), Vector2(_barrier_center(lower_water), lower_water), Vector2(_barrier_center(1330), 1330)])
	elif map_style == "highlands":
		crossing_references.append_array([340.0 + rng.randf_range(-50, 50), 750.0 + rng.randf_range(-45, 45), 1160.0 + rng.randf_range(-50, 50)])
		terrain_shapes.append(_shape(Terrain.MOUNTAIN, Vector2(845 + rng.randf_range(-85, 85), 205), Vector2(215, 165)))
		terrain_shapes.append(_shape(Terrain.MOUNTAIN, Vector2(1570 + rng.randf_range(-85, 85), 225), Vector2(215, 165)))
		terrain_shapes.append(_shape(Terrain.WATER, Vector2(790 + rng.randf_range(-100, 100), 1260), Vector2(175, 130)))
		terrain_shapes.append(_shape(Terrain.WATER, Vector2(1620 + rng.randf_range(-100, 100), 1260), Vector2(175, 130)))
		for y in crossing_references: sacred_site_references.append(Vector2(_barrier_center(y), y))
		trade_site_references.append_array([Vector2(barrier_x - 255, 170), Vector2(barrier_x + 255, 1330)])
		for shape in terrain_shapes:
			if shape["kind"] == Terrain.WATER: fish_site_references.append(shape["center"])
	else:
		sacred_site_references.append_array([Vector2(barrier_x, 350), Vector2(barrier_x, 750), Vector2(barrier_x, 1150)])
		trade_site_references.append_array([Vector2(600, 750), Vector2(1800, 750)])
		fish_site_references.append_array([Vector2(800, 750), Vector2(1600, 750)])
	# Three and four player maps use the same terrain rules, with bases protected
	# separately. The small seeded shifts avoid identical openings each match.

func _shape(kind: int, center: Vector2, radius: Vector2) -> Dictionary:
	return {"kind": kind, "center": center, "radius": radius}

func _barrier_center(y: float) -> float:
	return barrier_x + sin(y / 210.0 + float(map_seed % 31)) * 45.0

func _is_crossing(point: Vector2) -> bool:
	for y in crossing_references:
		if absf(point.y - y) < (58.0 if map_style == "highlands" else 67.0) and absf(point.x - _barrier_center(point.y)) < 270.0: return true
	return false

func _layout_terrain(point: Vector2, variation: float) -> int:
	if map_style == "islands":
		var on_island := _ellipse(point, Vector2(330, 750), Vector2(435, 690)) < 1.0 + variation * 0.09 or _ellipse(point, Vector2(2070, 750), Vector2(435, 690)) < 1.0 + variation * 0.09 or _ellipse(point, Vector2(barrier_x, 750), Vector2(350, 650)) < 1.0 + variation * 0.09
		return Terrain.MEADOW if on_island and variation > 0.13 else Terrain.GRASS if on_island else Terrain.WATER
	if _is_base_clearance(point): return Terrain.GRASS
	if (map_style == "balanced" and _is_road(point)) or (map_style != "balanced" and _is_crossing(point)): return Terrain.ROAD
	if map_style == "lakes":
		var river_width := 115.0 + 18.0 * sin(point.y / 145.0)
		if absf(point.x - _barrier_center(point.y)) < river_width or _ellipse(point, Vector2(barrier_x, 125), Vector2(280, 270)) < 1.0 + variation * 0.1 or _ellipse(point, Vector2(barrier_x, 1375), Vector2(295, 255)) < 1.0 + variation * 0.1: return Terrain.WATER
	elif map_style == "highlands":
		if absf(point.x - _barrier_center(point.y)) < 112.0 + 18.0 * variation: return Terrain.MOUNTAIN
	for shape in terrain_shapes:
		var edge := 1.0 + variation * (0.24 if shape["kind"] == Terrain.MOUNTAIN else -0.2)
		if _ellipse(point, shape["center"], shape["radius"]) < edge: return shape["kind"]
	return Terrain.MEADOW if variation > 0.13 else Terrain.GRASS

func sacred_site_positions() -> Array[Vector2]:
	var result: Array[Vector2] = []
	for reference in sacred_site_references: result.append(nearest_walkable_point(_world_point(reference)))
	return result

func trade_post_positions() -> Array[Vector2]:
	var result: Array[Vector2] = []
	for reference in trade_site_references: result.append(nearest_walkable_point(_world_point(reference)))
	return result

func _build_elevations() -> void:
	# Separate from layout RNG: refinements cannot move resources or mountain passes.
	relief_noise.seed = map_seed ^ 0x53a9
	relief_noise.frequency = 0.011
	relief_noise.fractal_octaves = 2
	elevation_levels.resize(cells.size())
	elevation_levels.fill(0)
	for y in grid_size.y:
		for x in grid_size.x:
			var cell := Vector2i(x, y)
			var terrain: int = cells[_index(cell)]
			if terrain == Terrain.MOUNTAIN:
				elevation_levels[_index(cell)] = 3
				continue
			if terrain == Terrain.WATER: continue
			var nearest := 3
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					var neighbor := cell + Vector2i(dx, dy)
					if neighbor.x < 0 or neighbor.y < 0 or neighbor.x >= grid_size.x or neighbor.y >= grid_size.y: continue
					if cells[_index(neighbor)] == Terrain.MOUNTAIN:
						nearest = mini(nearest, maxi(absi(dx), absi(dy)))
			elevation_levels[_index(cell)] = 2 if nearest == 1 else 1 if nearest == 2 else 0
	elevation_vertices.resize((grid_size.x + 1) * (grid_size.y + 1))
	maximum_elevation = 0.0
	for y in grid_size.y + 1:
		for x in grid_size.x + 1:
			# Water is a horizontal plane. Shore cells share these same vertices,
			# so their slopes meet the waterline without a crack or raised lake.
			var height := 0.0 if _vertex_touches_water(x, y) else _mountain_height_at(Vector2(x, y) * CELL_SIZE)
			elevation_vertices[_vertex_index(x, y)] = height
			maximum_elevation = maxf(maximum_elevation, height)

func _vertex_touches_water(x: int, y: int) -> bool:
	for cell_y in [y - 1, y]:
		if cell_y < 0 or cell_y >= grid_size.y: continue
		for cell_x in [x - 1, x]:
			if cell_x < 0 or cell_x >= grid_size.x: continue
			if cells[_index(Vector2i(cell_x, cell_y))] == Terrain.WATER: return true
	return false

func elevation_at(point: Vector2) -> float:
	if elevation_vertices.is_empty(): return 0.0
	var cell := cell_at(point)
	var fraction := (point - Vector2(cell) * CELL_SIZE) / float(CELL_SIZE)
	fraction = fraction.clamp(Vector2.ZERO, Vector2.ONE)
	var nw := _vertex_height(cell.x, cell.y)
	var se := _vertex_height(cell.x + 1, cell.y + 1)
	var ne := _vertex_height(cell.x + 1, cell.y)
	var sw := _vertex_height(cell.x, cell.y + 1)
	# Bilinear patches remove the fixed diagonal crease of each old tile.
	# Terrain, actors and fog all sample this same surface.
	return lerpf(lerpf(nw, ne, fraction.x), lerpf(sw, se, fraction.x), fraction.y)

func elevation_span(area: Rect2) -> float:
	var low := INF
	var high := 0.0
	for y in [area.position.y, area.position.y + area.size.y * 0.5, area.end.y]:
		for x in [area.position.x, area.position.x + area.size.x * 0.5, area.end.x]:
			var height := elevation_at(Vector2(x, y))
			low = minf(low, height)
			high = maxf(high, height)
	return high - low

func _vertex_index(x: int, y: int) -> int:
	return y * (grid_size.x + 1) + x

func _vertex_height(x: int, y: int) -> float:
	return elevation_vertices[_vertex_index(x, y)]

func _mountain_height_at(point: Vector2) -> float:
	var cell := cell_at(point)
	var nearest := INF
	for y in range(maxi(0, cell.y - 5), mini(grid_size.y - 1, cell.y + 5) + 1):
		for x in range(maxi(0, cell.x - 5), mini(grid_size.x - 1, cell.x + 5) + 1):
			if cells[_index(Vector2i(x, y))] != Terrain.MOUNTAIN: continue
			nearest = minf(nearest, point.distance_to(cell_center(Vector2i(x, y))))
	if nearest == INF: return 0.0
	var shoulder := clampf(1.0 - nearest / (CELL_SIZE * 4.5), 0.0, 1.0)
	var reference := _reference_point(point)
	var variation := relief_noise.get_noise_2d(reference.x, reference.y)
	var coverage := 0.0
	for offset in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i.ZERO]:
		var neighbor: Vector2i = cell + offset
		if neighbor.x < 0 or neighbor.y < 0 or neighbor.x >= grid_size.x or neighbor.y >= grid_size.y: continue
		if cells[_index(neighbor)] == Terrain.MOUNTAIN: coverage += 0.25
	var height := 74.0 * shoulder * shoulder * (3.0 - 2.0 * shoulder) * (0.92 + variation * 0.22)
	# Interior ridges have saddles and uneven shoulders instead of a flat plateau.
	height += smoothstep(0.35, 1.0, coverage) * (35.0 + 46.0 * variation) * shoulder
	var world_scale := Vector2(world_size.x / 2400.0, world_size.y / 1500.0)
	for shape in terrain_shapes:
		if shape["kind"] != Terrain.MOUNTAIN: continue
		var center: Vector2 = shape["center"] * world_scale
		var radius: Vector2 = shape["radius"] * world_scale
		var local := (point - center) / radius
		var phase := float(map_seed % 101) * 0.17
		local += Vector2(sin(local.y * 4.0 + phase), cos(local.x * 5.0 + phase)) * 0.09
		local.x += local.y * 0.12
		var radial := local.length_squared()
		if radial >= 1.0: continue
		var crest: float = pow(1.0 - sqrt(radial), 0.72)
		height = maxf(height, (180.0 if map_style == "highlands" else 155.0 if map_style == "lakes" else 190.0) * crest * (0.97 + variation * 0.16))
	return height

func spawn_positions() -> Array[Vector2]:
	var result: Array[Vector2] = []
	for index in mini(player_count, layout_bases.size()): result.append(_world_point(layout_bases[index]))
	return result

func fairness_report() -> Dictionary:
	var counts: Array[Dictionary] = []
	var distances: Array[Dictionary] = []
	var fair := true
	for base in spawn_positions():
		var nearest := {"wood": INF, "food": INF, "gold": INF, "stone": INF}
		var local := {"wood": 0, "food": 0, "gold": 0, "stone": 0}
		for spec in resource_specs:
			var kind: String = spec["kind"]
			if not nearest.has(kind) or spec["appearance"] in ["fish", "sheep", "boar"]: continue
			var distance := base.distance_to(spec["position"])
			if distance <= 430.0: local[kind] += 1
			nearest[kind] = minf(nearest[kind], distance)
		for kind in local:
			if local[kind] < (3 if kind != "wood" else 5): fair = false
		counts.append(local)
		distances.append(nearest)
	for kind in ["wood", "food", "gold", "stone"]:
		var minimum := INF
		var maximum := 0.0
		for sample in distances:
			minimum = minf(minimum, sample[kind])
			maximum = maxf(maximum, sample[kind])
		if maximum > minimum * 1.4 + 40.0: fair = false
	return {"fair": fair, "counts": counts, "nearest": distances}

func _ensure_starter_access() -> void:
	var starter_count := player_count * 15
	for index in mini(starter_count, resource_specs.size()):
		var spec: Dictionary = resource_specs[index]
		if is_walkable(spec["position"]) and not path_between(spawn_positions()[index / 15], spec["position"]).is_empty(): continue
		spec["position"] = nearest_walkable_point(spec["position"])
		resource_specs[index] = spec

func _generate_wildlife() -> void:
	for reference in [Vector2(barrier_x - 305, 650), Vector2(barrier_x + 305, 850)]:
		var point := nearest_walkable_point(_world_point(reference))
		resource_specs.append({"kind": "food", "appearance": "boar", "position": point, "amount": 420})

func _reference_point(point: Vector2) -> Vector2:
	return point * Vector2(2400.0 / world_size.x, 1500.0 / world_size.y)

func _world_point(point: Vector2) -> Vector2:
	return point * Vector2(world_size.x / 2400.0, world_size.y / 1500.0)

func _starter_point(base: Vector2, offset: Vector2) -> Vector2:
	return _world_point(base) + offset

func _ellipse(point: Vector2, center: Vector2, radius: Vector2) -> float:
	var delta := (point - center) / radius
	return delta.length_squared()

func _is_road(point: Vector2) -> bool:
	return absf(point.y - (750.0 + sin(point.x / 245.0) * 24.0)) <= 43.0

func _is_corridor_clearance(point: Vector2) -> bool:
	if map_style == "balanced" and _is_road(point): return true
	for site in sacred_site_references:
		if point.distance_to(site) < 115.0: return true
	if _is_crossing(point): return true
	return false

func _is_base_clearance(point: Vector2) -> bool:
	for base in layout_bases:
		if _ellipse(point, base, Vector2(280, 245) if player_count > 2 else Vector2(390, 335)) < 1.0: return true
	return false

func _index(cell: Vector2i) -> int:
	return cell.y * grid_size.x + cell.x

func cell_at(point: Vector2) -> Vector2i:
	return Vector2i(clampi(floori(point.x / CELL_SIZE), 0, grid_size.x - 1), clampi(floori(point.y / CELL_SIZE), 0, grid_size.y - 1))

func cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell) * CELL_SIZE + Vector2(CELL_SIZE * 0.5, CELL_SIZE * 0.5)

func terrain_at(point: Vector2) -> int:
	return cells[_index(cell_at(point))]

func forest_patch_at(point: Vector2) -> int:
	for index in stealth_patches.size():
		var patch: Dictionary = stealth_patches[index]
		if point.distance_squared_to(patch["position"]) <= float(patch["radius"]) * float(patch["radius"]): return index
	return -1

func is_high_ground(point: Vector2) -> bool:
	return is_walkable(point) and not elevation_levels.is_empty() and elevation_levels[_index(cell_at(point))] > 0

func is_walkable(point: Vector2) -> bool:
	var terrain := terrain_at(point)
	return terrain != Terrain.WATER and terrain != Terrain.MOUNTAIN

func is_navigable(point: Vector2) -> bool:
	return terrain_at(point) == Terrain.WATER

func nearest_water_point(point: Vector2) -> Vector2:
	var origin := cell_at(point)
	if is_navigable(cell_center(origin)): return cell_center(origin)
	for radius in range(1, maxi(grid_size.x, grid_size.y)):
		var best := Vector2.INF
		var best_distance := INF
		for y in range(maxi(0, origin.y - radius), mini(grid_size.y - 1, origin.y + radius) + 1):
			for x in range(maxi(0, origin.x - radius), mini(grid_size.x - 1, origin.x + radius) + 1):
				if absi(x - origin.x) != radius and absi(y - origin.y) != radius: continue
				var candidate := cell_center(Vector2i(x, y))
				if not is_navigable(candidate): continue
				var distance := point.distance_squared_to(candidate)
				if distance < best_distance:
					best = candidate
					best_distance = distance
		if best != Vector2.INF: return best
	return point

func has_adjacent_water(point: Vector2) -> bool:
	var cell := cell_at(point)
	for y in range(maxi(0, cell.y - 2), mini(grid_size.y - 1, cell.y + 2) + 1):
		for x in range(maxi(0, cell.x - 2), mini(grid_size.x - 1, cell.x + 2) + 1):
			if cells[_index(Vector2i(x, y))] == Terrain.WATER: return true
	return false

func is_area_buildable(area: Rect2) -> bool:
	var first := cell_at(area.position)
	var last := cell_at(area.end - Vector2.ONE)
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			var terrain: int = cells[_index(Vector2i(x, y))]
			if terrain == Terrain.WATER or terrain == Terrain.MOUNTAIN: return false
	return true

func _setup_pathfinder() -> void:
	pathfinder = AStarGrid2D.new()
	pathfinder.region = Rect2i(Vector2i.ZERO, grid_size)
	pathfinder.cell_size = Vector2(CELL_SIZE, CELL_SIZE)
	pathfinder.offset = Vector2(CELL_SIZE * 0.5, CELL_SIZE * 0.5)
	pathfinder.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	pathfinder.update()
	for y in grid_size.y:
		for x in grid_size.x:
			var cell := Vector2i(x, y)
			if not is_walkable(cell_center(cell)): pathfinder.set_point_solid(cell)

func _mark_reachable_cells() -> void:
	reachable_cells.resize(cells.size())
	reachable_cells.fill(0)
	var origin := nearest_walkable_cell(_world_point(Vector2(1200, 750)))
	var frontier: Array[Vector2i] = [origin]
	reachable_cells[_index(origin)] = 1
	var head := 0
	while head < frontier.size():
		var current := frontier[head]
		head += 1
		for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = current + offset
			if next.x < 0 or next.y < 0 or next.x >= grid_size.x or next.y >= grid_size.y: continue
			var index := _index(next)
			if reachable_cells[index] == 1 or pathfinder.is_point_solid(next): continue
			reachable_cells[index] = 1
			frontier.append(next)

func nearest_walkable_cell(point: Vector2) -> Vector2i:
	return nearest_open_cell(point, pathfinder)

func nearest_open_cell(point: Vector2, grid: AStarGrid2D) -> Vector2i:
	# Both terrain and navigation coarse grids use this map's cell alignment.
	var origin := cell_at(point)
	if not grid.is_point_solid(origin): return origin
	for radius in range(1, maxi(grid_size.x, grid_size.y)):
		var best := Vector2i(-1, -1)
		var best_distance := INF
		for y in range(maxi(0, origin.y - radius), mini(grid_size.y - 1, origin.y + radius) + 1):
			for x in range(maxi(0, origin.x - radius), mini(grid_size.x - 1, origin.x + radius) + 1):
				if absi(x - origin.x) != radius and absi(y - origin.y) != radius: continue
				var cell := Vector2i(x, y)
				if grid.is_point_solid(cell): continue
				var distance := point.distance_squared_to(cell_center(cell))
				if distance < best_distance:
					best_distance = distance
					best = cell
		if best.x >= 0: return best
	return origin

func nearest_walkable_point(point: Vector2) -> Vector2:
	var clamped := point.clamp(Vector2(24, 24), world_size - Vector2(24, 24))
	if is_walkable(clamped): return clamped
	return cell_center(nearest_walkable_cell(clamped))

func path_between(from: Vector2, to: Vector2) -> PackedVector2Array:
	return pathfinder.get_point_path(nearest_walkable_cell(from), nearest_walkable_cell(to))

func _random_open_point() -> Vector2:
	for attempt in 160:
		var point := Vector2(rng.randf_range(110, world_size.x - 110), rng.randf_range(100, world_size.y - 100))
		if _is_corridor_clearance(_reference_point(point)) or _is_base_clearance(_reference_point(point)) or not is_walkable(point): continue
		if reachable_cells[_index(cell_at(point))] == 0: continue
		return point
	return _world_point(Vector2(1200, 520))

func _generate_plants() -> void:
	for group in 28:
		var center := _random_open_point()
		var count := rng.randi_range(7, 16)
		for i in count:
			var angle := rng.randf_range(0, TAU)
			var distance := rng.randf_range(0, 95)
			var point := center + Vector2.from_angle(angle) * distance
			if point.x < 25 or point.y < 25 or point.x > world_size.x - 25 or point.y > world_size.y - 25 or not is_walkable(point): continue
			plants.append({"position": point, "flower": rng.randf() < 0.28, "size": rng.randf_range(4.0, 9.0)})

func _generate_stealth_patches() -> void:
	for index in 10:
		var center := _random_open_point()
		var radius := rng.randf_range(75.0, 105.0)
		var valid := true
		for patch in stealth_patches:
			if center.distance_to(patch["position"]) < radius + float(patch["radius"]) + 35.0: valid = false
		if valid: stealth_patches.append({"position": center, "radius": radius})

func _generate_resource_clusters() -> void:
	for cluster in 6: _add_cluster("wood", "tree", rng.randi_range(4, 7), 450)
	for cluster in 4: _add_cluster("food", "berry", rng.randi_range(3, 5), 300)
	for cluster in 3: _add_cluster("food", "deer", rng.randi_range(4, 6), 170)
	for cluster in 3: _add_cluster("gold", "ore", rng.randi_range(2, 3), 550)
	for cluster in 3: _add_cluster("stone", "ore", rng.randi_range(2, 3), 500)

func _generate_contested_resources() -> void:
	if map_style == "islands":
		_add_cluster_near("gold", "ore", 3, 550, Vector2(barrier_x - 115, 650))
		_add_cluster_near("gold", "ore", 3, 550, Vector2(barrier_x + 115, 850))
		_add_cluster_near("food", "deer", 4, 170, Vector2(barrier_x, 530))
		_add_cluster_near("wood", "tree", 5, 500, Vector2(barrier_x, 1040))
		return
	var upper: float = crossing_references[0] if not crossing_references.is_empty() else 390.0
	var lower: float = crossing_references.back() if not crossing_references.is_empty() else 1110.0
	for side in [-1.0, 1.0]:
		var x: float = barrier_x + side * (330.0 if map_style == "balanced" else 295.0)
		_add_cluster_near("gold", "ore", 3, 550, Vector2(x, upper + 95.0))
		_add_cluster_near("stone", "ore", 2, 500, Vector2(x, lower - 95.0))
		_add_cluster_near("food", "deer", 3, 170, Vector2(x, 760.0))

func _add_cluster_near(kind: String, appearance: String, count: int, amount: int, reference: Vector2) -> void:
	var center := _world_point(reference)
	var placed := 0
	for attempt in 120:
		if placed >= count: break
		var point := center + Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(20.0, 115.0)
		if point.x < 45.0 or point.y < 45.0 or point.x > world_size.x - 45.0 or point.y > world_size.y - 45.0: continue
		if not is_area_buildable(Rect2(point - Vector2(24, 24), Vector2(48, 48))): continue
		if _is_base_clearance(_reference_point(point)) or _is_corridor_clearance(_reference_point(point)): continue
		var clear := true
		for spec in resource_specs:
			if point.distance_squared_to(spec["position"]) < 42.0 * 42.0:
				clear = false
				break
		if not clear: continue
		resource_specs.append({"kind": kind, "appearance": appearance, "position": point, "amount": amount})
		placed += 1

func _generate_sheep() -> void:
	for cluster in 5:
		for retry in 40:
			var center := _random_open_point()
			if _is_base_clearance(_reference_point(center)): continue
			var placed := 0
			for i in 3:
				var point := center + Vector2.from_angle(TAU * float(i) / 3.0) * 34.0
				if not is_walkable(point): continue
				resource_specs.append({"kind": "food", "appearance": "sheep", "position": point, "amount": 220})
				placed += 1
			if placed > 0: break

func _generate_starter_resources() -> void:
	if player_count > 2:
		for owner_id in player_count:
			var base: Vector2 = layout_bases[owner_id]
			var outward := -1.0 if base.x < 1200.0 else 1.0
			var vertical := -1.0 if base.y < 750.0 else 1.0
			for i in 5:
				resource_specs.append({"kind": "wood", "appearance": "tree", "position": _starter_point(base, Vector2(outward * (170 + (i % 2) * 40), vertical * (20 + (i / 2) * 47))), "amount": 500})
			for i in 4:
				resource_specs.append({"kind": "food", "appearance": "berry", "position": _starter_point(base, Vector2(-outward * (125 + (i % 2) * 43), vertical * (80 + (i / 2) * 40))), "amount": 420})
			for i in 3:
				resource_specs.append({"kind": "gold", "appearance": "ore", "position": _starter_point(base, Vector2(outward * (60 + i * 48), -vertical * 190)), "amount": 580})
			for i in 3:
				resource_specs.append({"kind": "stone", "appearance": "ore", "position": _starter_point(base, Vector2(-outward * (70 + i * 48), vertical * 180)), "amount": 560})
		return
	for side in [0, 1]:
		var base: Vector2 = layout_bases[side]
		for i in 5:
			resource_specs.append({"kind": "wood", "appearance": "tree", "position": _starter_point(base, Vector2((-270 if side == 0 else 270) + (i % 2) * 52, -150 + (i / 2) * 57)), "amount": 500})
		for i in 4:
			resource_specs.append({"kind": "food", "appearance": "berry", "position": _starter_point(base, Vector2((120 if side == 0 else -120) + (i % 2) * 55, -160 + (i / 2) * 55)), "amount": 420})
		for i in 3:
			resource_specs.append({"kind": "gold", "appearance": "ore", "position": _starter_point(base, Vector2((-180 if side == 0 else 180) + i * 50, 210)), "amount": 580})
		for i in 3:
			resource_specs.append({"kind": "stone", "appearance": "ore", "position": _starter_point(base, Vector2((100 if side == 0 else -100) + i * 50, 250)), "amount": 560})

func _add_cluster(kind: String, appearance: String, count: int, amount: int) -> void:
	for retry in 16:
		var center := _random_open_point()
		var pending: Array[Dictionary] = []
		for attempt in 180:
			if pending.size() >= count: break
			var point := center + Vector2.from_angle(rng.randf_range(0, TAU)) * rng.randf_range(12, 105)
			if point.x < 40 or point.y < 40 or point.x > world_size.x - 40 or point.y > world_size.y - 40: continue
			if not is_area_buildable(Rect2(point - Vector2(24, 24), Vector2(48, 48))) or _is_corridor_clearance(_reference_point(point)) or _is_base_clearance(_reference_point(point)): continue
			if reachable_cells[_index(cell_at(point))] == 0: continue
			var clear := true
			for spec in resource_specs + pending:
				if point.distance_squared_to(spec["position"]) < 38.0 * 38.0:
					clear = false
					break
			if clear: pending.append({"kind": kind, "appearance": appearance, "position": point, "amount": amount})
		if pending.size() == count:
			resource_specs.append_array(pending)
			return

func _generate_fish() -> void:
	for reference in fish_site_references:
		var center: Vector2 = _world_point(reference)
		var placed := 0
		for attempt in 70:
			if placed >= 7: break
			var point := center + Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(20.0, 125.0)
			point = nearest_water_point(point)
			if not is_navigable(point): continue
			var clear := true
			for spec in resource_specs:
				if spec["appearance"] == "fish" and point.distance_squared_to(spec["position"]) < 48.0 * 48.0:
					clear = false
					break
			if clear:
				resource_specs.append({"kind": "food", "appearance": "fish", "position": point, "amount": 420})
				placed += 1

func _visual_vertex_height(x: int, y: int) -> float:
	return WorldMapRenderer.visual_vertex_height(self, x, y)

func _draw() -> void:
	WorldMapRenderer.draw_map(self)

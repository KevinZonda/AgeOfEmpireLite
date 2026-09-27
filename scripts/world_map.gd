class_name RtsWorldMap
extends Node2D

const CELL_SIZE := 50
const VISUAL_APRON_CELLS := 12
const OUTSIDE_COLOR := Color("202c2e")
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
var pathfinder := AStarGrid2D.new()
var rng := RandomNumberGenerator.new()
var lift_per_height := Vector2.ZERO

func generate(seed_value: int, map_size: Vector2, style := "balanced", participants := 2) -> void:
	map_seed = seed_value
	player_count = clampi(participants, 2, 4)
	map_style = style if ["balanced", "lakes", "highlands", "islands"].has(style) else "balanced"
	world_size = map_size
	grid_size = Vector2i(ceili(map_size.x / CELL_SIZE), ceili(map_size.y / CELL_SIZE))
	rng.seed = seed_value
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
			var terrain := Terrain.GRASS
			if map_style == "islands":
				var on_island := _ellipse(point, Vector2(330, 750), Vector2(435, 690)) < 1.0 or _ellipse(point, Vector2(2070, 750), Vector2(435, 690)) < 1.0 or _ellipse(point, Vector2(1200, 750), Vector2(350, 650)) < 1.0
				terrain = Terrain.MEADOW if on_island and variation > 0.13 else Terrain.GRASS if on_island else Terrain.WATER
			elif _is_road(point):
				terrain = Terrain.ROAD
			elif _is_base_clearance(point) or _is_corridor_clearance(point):
				terrain = Terrain.MEADOW if variation > 0.13 else Terrain.GRASS
			elif _ellipse(point, Vector2(790, 255), Vector2(285, 205) * _mountain_scale()) < 1.0 + variation * 0.24 or _ellipse(point, Vector2(1660, 265), Vector2(270, 195) * _mountain_scale()) < 1.0 + variation * 0.22:
				terrain = Terrain.MOUNTAIN
			elif _ellipse(point, Vector2(800, 1220), Vector2(270, 195) * _water_scale()) < 1.0 - variation * 0.25 or _ellipse(point, Vector2(1580, 1190), Vector2(290, 205) * _water_scale()) < 1.0 - variation * 0.25:
				terrain = Terrain.WATER
			elif variation > 0.13:
				terrain = Terrain.MEADOW
			cells[_index(Vector2i(x, y))] = terrain
	_setup_pathfinder()
	_mark_reachable_cells()
	_generate_stealth_patches()
	_generate_plants()
	_generate_starter_resources()
	_generate_resource_clusters()
	_generate_sheep()
	_generate_wildlife()
	_generate_fish()
	_ensure_starter_access()
	_build_elevations()
	queue_redraw()

func _build_elevations() -> void:
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
			var height := _mountain_height_at(Vector2(x, y) * CELL_SIZE)
			elevation_vertices[_vertex_index(x, y)] = height
			maximum_elevation = maxf(maximum_elevation, height)

func elevation_at(point: Vector2) -> float:
	if elevation_vertices.is_empty(): return 0.0
	var cell := cell_at(point)
	var fraction := (point - Vector2(cell) * CELL_SIZE) / float(CELL_SIZE)
	fraction = fraction.clamp(Vector2.ZERO, Vector2.ONE)
	var nw := _vertex_height(cell.x, cell.y)
	var se := _vertex_height(cell.x + 1, cell.y + 1)
	if fraction.x >= fraction.y:
		var ne := _vertex_height(cell.x + 1, cell.y)
		return nw * (1.0 - fraction.x) + ne * (fraction.x - fraction.y) + se * fraction.y
	var sw := _vertex_height(cell.x, cell.y + 1)
	return nw * (1.0 - fraction.y) + sw * (fraction.y - fraction.x) + se * fraction.x

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
	var height := 74.0 * shoulder * shoulder * (3.0 - 2.0 * shoulder)
	var world_scale := Vector2(world_size.x / 2400.0, world_size.y / 1500.0)
	var peak_scale := 1.2 if map_style == "highlands" else 0.85 if map_style == "lakes" else 1.0
	for peak in [
		[Vector2(790, 255), Vector2(285, 205), 195.0],
		[Vector2(705, 190), Vector2(145, 118), 135.0],
		[Vector2(1660, 265), Vector2(270, 195), 190.0],
		[Vector2(1740, 208), Vector2(142, 110), 130.0],
	]:
		var center: Vector2 = peak[0] * world_scale
		var radius: Vector2 = peak[1] * world_scale * _mountain_scale()
		var radial := ((point - center) / radius).length_squared()
		if radial >= 1.0: continue
		var crest: float = pow(1.0 - sqrt(radial), 0.82)
		height = maxf(height, float(peak[2]) * peak_scale * crest)
	return height

func spawn_positions() -> Array[Vector2]:
	var references := [Vector2(330, 720), Vector2(2070, 720)] if player_count <= 2 else [Vector2(330, 420), Vector2(2070, 1080), Vector2(330, 1080), Vector2(2070, 420)]
	var result: Array[Vector2] = []
	for index in player_count: result.append(_world_point(references[index]))
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
	for reference in [Vector2(900, 690), Vector2(1500, 810)]:
		var point := nearest_walkable_point(_world_point(reference))
		resource_specs.append({"kind": "food", "appearance": "boar", "position": point, "amount": 420})

func _reference_point(point: Vector2) -> Vector2:
	return point * Vector2(2400.0 / world_size.x, 1500.0 / world_size.y)

func _world_point(point: Vector2) -> Vector2:
	return point * Vector2(world_size.x / 2400.0, world_size.y / 1500.0)

func _starter_point(base: Vector2, offset: Vector2) -> Vector2:
	return _world_point(base) + offset

func _mountain_scale() -> float:
	return 1.3 if map_style == "highlands" else 0.85 if map_style == "lakes" else 1.0

func _water_scale() -> float:
	return 1.35 if map_style == "lakes" else 0.8 if map_style == "highlands" else 1.0

func _ellipse(point: Vector2, center: Vector2, radius: Vector2) -> float:
	var delta := (point - center) / radius
	return delta.length_squared()

func _is_road(point: Vector2) -> bool:
	return absf(point.y - (750.0 + sin(point.x / 245.0) * 24.0)) <= 43.0

func _is_corridor_clearance(point: Vector2) -> bool:
	if point.y >= 550 and point.y <= 950: return true
	if player_count <= 2: return false
	for base: Vector2 in [Vector2(330, 420), Vector2(2070, 1080), Vector2(330, 1080), Vector2(2070, 420)]:
		var to_center: Vector2 = Vector2(1200, 750) - base
		var fraction := clampf((point - base).dot(to_center) / to_center.length_squared(), 0.0, 1.0)
		if point.distance_to(base + to_center * fraction) < 65.0: return true
	return false

func _is_base_clearance(point: Vector2) -> bool:
	if player_count > 2:
		for base in [Vector2(330, 420), Vector2(2070, 1080), Vector2(330, 1080), Vector2(2070, 420)]:
			if _ellipse(point, base, Vector2(280, 245)) < 1.0: return true
	return _ellipse(point, Vector2(330, 720), Vector2(390, 335)) < 1.0 or _ellipse(point, Vector2(2070, 720), Vector2(390, 335)) < 1.0

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
	var origin := cell_at(point)
	if not pathfinder.is_point_solid(origin): return origin
	for radius in range(1, maxi(grid_size.x, grid_size.y)):
		var best := Vector2i(-1, -1)
		var best_distance := INF
		for y in range(maxi(0, origin.y - radius), mini(grid_size.y - 1, origin.y + radius) + 1):
			for x in range(maxi(0, origin.x - radius), mini(grid_size.x - 1, origin.x + radius) + 1):
				if absi(x - origin.x) != radius and absi(y - origin.y) != radius: continue
				var cell := Vector2i(x, y)
				if pathfinder.is_point_solid(cell): continue
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
		var bases := [Vector2(330, 420), Vector2(2070, 1080), Vector2(330, 1080), Vector2(2070, 420)]
		for owner_id in player_count:
			var base: Vector2 = bases[owner_id]
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
		var x := 330.0 if side == 0 else 2070.0
		var base := Vector2(x, 720)
		for i in 5:
			resource_specs.append({"kind": "wood", "appearance": "tree", "position": _starter_point(base, Vector2((-270 if side == 0 else 270) + (i % 2) * 52, -150 + (i / 2) * 57)), "amount": 500})
		for i in 4:
			resource_specs.append({"kind": "food", "appearance": "berry", "position": _starter_point(base, Vector2((120 if side == 0 else -120) + (i % 2) * 55, -160 + (i / 2) * 55)), "amount": 420})
		for i in 3:
			resource_specs.append({"kind": "gold", "appearance": "ore", "position": _starter_point(base, Vector2((-180 if side == 0 else 180) + i * 50, 210)), "amount": 580})
		for i in 3:
			resource_specs.append({"kind": "stone", "appearance": "ore", "position": _starter_point(base, Vector2((100 if side == 0 else -100) + i * 50, 250)), "amount": 560})
	for i in 7:
		resource_specs.append({"kind": "wood", "appearance": "tree", "position": _world_point(Vector2(1100 + (i % 3) * 60, 350 + (i / 3) * 60)), "amount": 550})
	for i in 5:
		resource_specs.append({"kind": "gold", "appearance": "ore", "position": _world_point(Vector2(1100 + (i % 3) * 60, 1130 + (i / 3) * 60)), "amount": 550})

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
	for center: Vector2 in [_world_point(Vector2(800, 1220)), _world_point(Vector2(1580, 1190))]:
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

func _tile_lift(height: float) -> Vector2:
	return lift_per_height * height

func _visual_vertex_height(x: int, y: int) -> float:
	var inside_x := clampi(x, 0, grid_size.x)
	var inside_y := clampi(y, 0, grid_size.y)
	var outside := maxi(absi(x - inside_x), absi(y - inside_y))
	return _vertex_height(inside_x, inside_y) * clampf(1.0 - float(outside) / VISUAL_APRON_CELLS, 0.0, 1.0)

func projected_vertex(x: int, y: int) -> Vector2:
	return Vector2(x, y) * CELL_SIZE + _tile_lift(_visual_vertex_height(x, y))

func _relief_color(terrain: int, height: float) -> Color:
	if terrain == Terrain.MOUNTAIN:
		return Color("777b71").lerp(Color("d8d6c5"), clampf((height - 70.0) / 110.0, 0.0, 1.0))
	var grass := Color("88a36e") if terrain == Terrain.MEADOW else Color("759761")
	return grass.lerp(Color("a49d79"), clampf(height / 105.0, 0.0, 0.78))

func _draw_relief_tile(x: int, y: int) -> void:
	var h_nw := _visual_vertex_height(x, y)
	var h_ne := _visual_vertex_height(x + 1, y)
	var h_se := _visual_vertex_height(x + 1, y + 1)
	var h_sw := _visual_vertex_height(x, y + 1)
	if maxf(maxf(h_nw, h_ne), maxf(h_se, h_sw)) < 0.5: return
	var nw := projected_vertex(x, y)
	var ne := projected_vertex(x + 1, y)
	var se := projected_vertex(x + 1, y + 1)
	var sw := projected_vertex(x, y + 1)
	var terrain: int = cells[_index(Vector2i(clampi(x, 0, grid_size.x - 1), clampi(y, 0, grid_size.y - 1)))]
	var average := (h_nw + h_ne + h_se + h_sw) * 0.25
	var outside := x < 0 or y < 0 or x >= grid_size.x or y >= grid_size.y
	var color := OUTSIDE_COLOR if outside else _relief_color(terrain, average)
	var east_slope := (h_ne + h_se - h_nw - h_sw) / (2.0 * CELL_SIZE)
	var south_slope := (h_sw + h_se - h_nw - h_ne) / (2.0 * CELL_SIZE)
	var light := clampf(0.98 - east_slope * 0.16 - south_slope * 0.12, 0.72, 1.15)
	draw_colored_polygon(PackedVector2Array([nw, ne, se]), color * light)
	draw_colored_polygon(PackedVector2Array([nw, se, sw]), color * clampf(light - (h_sw - h_ne) / 500.0, 0.69, 1.13))
	if not outside and terrain == Terrain.MOUNTAIN and average > 65.0 and (x * 7 + y * 11) % 4 == 0:
		var rock_ink := color.darkened(0.20)
		var scratch := nw.lerp(se, 0.37)
		draw_line(scratch, scratch.lerp(ne, 0.30), Color(rock_ink, 0.55), 1.2)
		if average > 105.0:
			draw_line(nw.lerp(ne, 0.38), nw.lerp(se, 0.53), Color("eee9d4", 0.40), 1.4)

func _draw() -> void:
	if isometric_view:
		var camera := get_viewport().get_camera_2d()
		lift_per_height = RtsIsoProjection.world_delta(get_viewport().get_canvas_transform(), Vector2(0, -camera.zoom.x)) if camera != null else Vector2.ZERO
		draw_rect(Rect2(-world_size * 2.0, world_size * 5.0), RtsFogOfWar.UNEXPLORED_COLOR)
		for y in range(-VISUAL_APRON_CELLS, grid_size.y + VISUAL_APRON_CELLS):
			for x in range(-VISUAL_APRON_CELLS, grid_size.x + VISUAL_APRON_CELLS):
				if x >= 0 and y >= 0 and x < grid_size.x and y < grid_size.y: continue
				draw_rect(Rect2(Vector2(x, y) * CELL_SIZE, Vector2.ONE * CELL_SIZE), OUTSIDE_COLOR)
	for y in grid_size.y:
		for x in grid_size.x:
			var cell := Vector2i(x, y)
			var terrain: int = cells[_index(cell)]
			var point := Vector2(x * CELL_SIZE, y * CELL_SIZE)
			var color := Color("688e5e")
			match terrain:
				Terrain.MEADOW: color = Color("7d9b64")
				Terrain.WATER: color = Color("437e9f")
				Terrain.MOUNTAIN: color = Color("686f68").lerp(Color("adb0a1"), clampf((elevation_at(point + Vector2.ONE * CELL_SIZE * 0.5) - 60.0) / 140.0, 0.0, 1.0))
				Terrain.ROAD: color = Color("879468")
			draw_rect(Rect2(point, Vector2(CELL_SIZE, CELL_SIZE)), color)
			if terrain == Terrain.WATER:
				draw_line(point + Vector2(9, 19), point + Vector2(27, 19), Color("8fc3cf", 0.45), 2)
				draw_line(point + Vector2(24, 35), point + Vector2(43, 35), Color("8fc3cf", 0.34), 2)
				if y > 0 and cells[_index(Vector2i(x, y - 1))] != Terrain.WATER:
					draw_line(point, point + Vector2(CELL_SIZE, 0), Color("b8c6a0", 0.7), 2.0)
				if x > 0 and cells[_index(Vector2i(x - 1, y))] != Terrain.WATER:
					draw_line(point, point + Vector2(0, CELL_SIZE), Color("b8c6a0", 0.7), 2.0)
			elif terrain == Terrain.MOUNTAIN and not isometric_view:
				if (x * 7 + y * 11) % 4 == 0:
					draw_line(point + Vector2(9, 31), point + Vector2(23, 18), color.lightened(0.19), 2)
					draw_line(point + Vector2(23, 18), point + Vector2(32, 21), color.darkened(0.24), 2)
				if elevation_at(point + Vector2.ONE * CELL_SIZE * 0.5) > 145.0:
					draw_line(point + Vector2(17, 12), point + Vector2(31, 9), Color("dedecf", 0.55), 3)
			elif terrain == Terrain.ROAD and x % 3 == 0 and y % 2 == 0:
				draw_line(point + Vector2(10, 27), point + Vector2(35, 25), Color("b1aa75", 0.25), 2)
			elif terrain in [Terrain.GRASS, Terrain.MEADOW] and (x * 13 + y * 7) % 5 == 0:
				draw_line(point + Vector2(11, 34), point + Vector2(14, 29), color.lightened(0.10), 1)
				draw_line(point + Vector2(14, 29), point + Vector2(18, 33), color.darkened(0.08), 1)
	if isometric_view:
		for y in range(-VISUAL_APRON_CELLS, grid_size.y + VISUAL_APRON_CELLS):
			for x in range(-VISUAL_APRON_CELLS, grid_size.x + VISUAL_APRON_CELLS):
				_draw_relief_tile(x, y)
		var border := Color("d1bc86", 0.74)
		for x in grid_size.x:
			draw_line(projected_vertex(x, 0), projected_vertex(x + 1, 0), border, 2.0)
			draw_line(projected_vertex(x, grid_size.y), projected_vertex(x + 1, grid_size.y), border, 2.0)
		for y in grid_size.y:
			draw_line(projected_vertex(0, y), projected_vertex(0, y + 1), border, 2.0)
			draw_line(projected_vertex(grid_size.x, y), projected_vertex(grid_size.x, y + 1), border, 2.0)
	for patch in stealth_patches:
		var center: Vector2 = patch["position"]
		if isometric_view: center += _tile_lift(elevation_at(center))
		var radius: float = patch["radius"]
		draw_circle(center, radius, Color("254f37", 0.28))
		draw_arc(center, radius, 0.0, TAU, 48, Color("a1bc80", 0.5), 2.0)
	for plant in plants:
		var point: Vector2 = plant["position"]
		if isometric_view: point += _tile_lift(elevation_at(point))
		var size: float = plant["size"]
		if plant["flower"]:
			draw_circle(point, size * 0.45, Color("e2c078"))
			draw_circle(point + Vector2(3, 2), size * 0.25, Color("f1e5c4"))
		else:
			draw_line(point, point + Vector2(-size * 0.6, -size), Color("3e7041"), 2)
			draw_line(point, point + Vector2(size * 0.5, -size * 0.8), Color("467b43"), 2)

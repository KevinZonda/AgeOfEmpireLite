class_name RtsNavigation
extends RefCounted

# Terrain is owned by RtsWorldMap. This layer adds changing entity footprints.
const CLEARANCE := 16.0
const SPATIAL_CELL_SIZE := 64.0
const SMOOTH_LOOKAHEAD := 8
const RESOURCE_REPLAN_DISTANCE := 8.0

var game: Node2D
var world_map: RtsWorldMap
var pathfinder := AStarGrid2D.new()
var enemy_pathfinder := AStarGrid2D.new()
var water_pathfinder := AStarGrid2D.new()
var owner_pathfinders: Array[AStarGrid2D] = []
var clearance_grids: Dictionary = {}
var obstacle_signature := -1
var obstacle_revision := 0
var obstacle_check_frame := -1
var spatial_frame := -1
var indexed_unit_count := -1
var indexed_resource_count := -1
var indexed_building_count := -1
var max_dynamic_radius := 0.0
var units_by_cell: Dictionary = {}
var resources_by_cell: Dictionary = {}
var buildings_by_cell: Dictionary = {}
var profiling_enabled := OS.get_environment("RTS_NAV_PROFILE") == "1"
var profile: Dictionary = {}

func reset_profile() -> void:
	profile.clear()

func profile_snapshot() -> Dictionary:
	return profile.duplicate(true)

func _record_profile(operation: StringName, started: int) -> void:
	var elapsed := Time.get_ticks_usec() - started
	if not profile.has(operation): profile[operation] = {"calls": 0, "total_us": 0, "max_us": 0}
	var entry: Dictionary = profile[operation]
	entry["calls"] += 1
	entry["total_us"] += elapsed
	entry["max_us"] = maxi(entry["max_us"], elapsed)

func _point_path(grid: AStarGrid2D, start: Vector2i, end: Vector2i) -> PackedVector2Array:
	if not profiling_enabled: return grid.get_point_path(start, end)
	var started := Time.get_ticks_usec()
	var result := grid.get_point_path(start, end)
	_record_profile(&"astar", started)
	return result

func _id_path(grid: AStarGrid2D, start: Vector2i, end: Vector2i) -> Array[Vector2i]:
	if not profiling_enabled: return grid.get_id_path(start, end)
	var started := Time.get_ticks_usec()
	var result := grid.get_id_path(start, end)
	_record_profile(&"astar", started)
	return result

func _init(game_ref: Node2D, map_ref: RtsWorldMap) -> void:
	game = game_ref
	world_map = map_ref

func refresh() -> void:
	var started := Time.get_ticks_usec() if profiling_enabled else 0
	_refresh_grids()
	if profiling_enabled: _record_profile(&"grid_refresh", started)

func _refresh_grids() -> void:
	clearance_grids.clear()
	obstacle_revision += 1
	obstacle_signature = _obstacle_signature()
	obstacle_check_frame = Engine.get_process_frames()
	invalidate_spatial_index()
	owner_pathfinders.clear()
	for owner_id in game.players.size(): owner_pathfinders.append(AStarGrid2D.new())
	pathfinder = owner_pathfinders[0]
	enemy_pathfinder = owner_pathfinders[1]
	var grids: Array[AStarGrid2D] = owner_pathfinders.duplicate()
	grids.append(water_pathfinder)
	for grid in grids:
		grid.clear()
		grid.region = Rect2i(Vector2i.ZERO, world_map.grid_size)
		grid.cell_size = Vector2(RtsWorldMap.CELL_SIZE, RtsWorldMap.CELL_SIZE)
		grid.offset = Vector2.ONE * RtsWorldMap.CELL_SIZE * 0.5
		grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		grid.update()
	for y in world_map.grid_size.y:
		for x in world_map.grid_size.x:
			var cell := Vector2i(x, y)
			var center := world_map.cell_center(cell)
			if not world_map.is_walkable(center):
				for grid in owner_pathfinders: grid.set_point_solid(cell)
			if not world_map.is_navigable(center): water_pathfinder.set_point_solid(cell)
	for building in game.buildings:
		if not is_instance_valid(building) or building.is_queued_for_deletion(): continue
		var footprint := Rect2(building.position - building.size() * 0.5, building.size()).grow(CLEARANCE)
		if building.kind.ends_with("_gate") and building.is_complete():
			for owner_id in owner_pathfinders.size():
				if game.is_enemy(owner_id, building.owner_id): _mark_rect(footprint, owner_pathfinders[owner_id])
		else:
			for grid in owner_pathfinders: _mark_rect(footprint, grid)
		_mark_rect(footprint, water_pathfinder)
	for resource in game.resources:
		if not is_instance_valid(resource) or resource.is_queued_for_deletion(): continue
		for grid in grids:
			_mark_circle(resource.position, resource.radius + CLEARANCE, grid)
	for building in game.buildings:
		if not is_instance_valid(building) or building.is_queued_for_deletion() or not building.is_complete() or not building.kind.ends_with("_gate"): continue
		var first := world_map.cell_at(building.position - Vector2.ONE * RtsWorldMap.CELL_SIZE)
		var last := world_map.cell_at(building.position + Vector2.ONE * RtsWorldMap.CELL_SIZE)
		for y in range(first.y, last.y + 1):
			for x in range(first.x, last.x + 1):
				var cell := Vector2i(x, y)
				var delta: Vector2 = world_map.cell_center(cell) - building.position
				var along := absf(delta.y) if building.wall_vertical else absf(delta.x)
				var across := absf(delta.x) if building.wall_vertical else absf(delta.y)
				if along <= RtsWorldMap.CELL_SIZE * 0.55 and across <= RtsWorldMap.CELL_SIZE * 1.1 and world_map.is_walkable(world_map.cell_center(cell)):
					for owner_id in owner_pathfinders.size():
						if not game.is_enemy(owner_id, building.owner_id): owner_pathfinders[owner_id].set_point_solid(cell, false)

func _obstacle_signature() -> int:
	var signature := 0
	for building in game.buildings:
		if is_instance_valid(building) and not building.is_queued_for_deletion():
			signature = hash([signature, building.get_instance_id(), building.position, building.size(), building.owner_id, building.kind, building.is_complete()])
	for resource in game.resources:
		if is_instance_valid(resource) and not resource.is_queued_for_deletion():
			signature = hash([signature, resource.get_instance_id(), resource.position.snapped(Vector2.ONE * RESOURCE_REPLAN_DISTANCE), resource.radius])
	return signature

func _ensure_current() -> void:
	var frame := Engine.get_process_frames()
	if obstacle_check_frame == frame: return
	obstacle_check_frame = frame
	if obstacle_signature != _obstacle_signature(): refresh()

func invalidate_spatial_index() -> void:
	spatial_frame = -1

func invalidate_obstacles() -> void:
	obstacle_signature = -1
	obstacle_check_frame = -1
	invalidate_spatial_index()

func _spatial_cell(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / SPATIAL_CELL_SIZE), floori(point.y / SPATIAL_CELL_SIZE))

func _ensure_spatial_index() -> void:
	var frame := Engine.get_process_frames()
	if spatial_frame == frame and indexed_unit_count == game.units.size() and indexed_resource_count == game.resources.size() and indexed_building_count == game.buildings.size(): return
	units_by_cell.clear()
	resources_by_cell.clear()
	buildings_by_cell.clear()
	max_dynamic_radius = 0.0
	for unit in game.units:
		if not is_instance_valid(unit) or unit.is_queued_for_deletion() or unit.garrisoned_in != null: continue
		max_dynamic_radius = maxf(max_dynamic_radius, unit.radius())
		var cell := _spatial_cell(unit.position)
		if not units_by_cell.has(cell): units_by_cell[cell] = []
		units_by_cell[cell].append(unit)
	for resource in game.resources:
		if not is_instance_valid(resource) or resource.is_queued_for_deletion(): continue
		max_dynamic_radius = maxf(max_dynamic_radius, resource.radius)
		var cell := _spatial_cell(resource.position)
		if not resources_by_cell.has(cell): resources_by_cell[cell] = []
		resources_by_cell[cell].append(resource)
	for building in game.buildings:
		if not is_instance_valid(building) or building.is_queued_for_deletion(): continue
		var bounds := Rect2(building.position - building.size() * 0.5, building.size()).grow(48.0)
		var first := _spatial_cell(bounds.position)
		var last := _spatial_cell(bounds.end)
		for y in range(first.y, last.y + 1):
			for x in range(first.x, last.x + 1):
				var cell := Vector2i(x, y)
				if not buildings_by_cell.has(cell): buildings_by_cell[cell] = []
				buildings_by_cell[cell].append(building)
	spatial_frame = frame
	indexed_unit_count = game.units.size()
	indexed_resource_count = game.resources.size()
	indexed_building_count = game.buildings.size()

func nearby_units(point: Vector2, radius: float) -> Array[RtsUnit]:
	_ensure_spatial_index()
	var result: Array[RtsUnit] = []
	var first := _spatial_cell(point - Vector2.ONE * radius)
	var last := _spatial_cell(point + Vector2.ONE * radius)
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			for unit in units_by_cell.get(Vector2i(x, y), []):
				if is_instance_valid(unit) and not unit.is_queued_for_deletion() and unit.garrisoned_in == null and point.distance_squared_to(unit.position) <= radius * radius:
					result.append(unit)
	return result

func nearby_resources(point: Vector2, radius: float) -> Array[RtsResource]:
	_ensure_spatial_index()
	var result: Array[RtsResource] = []
	var first := _spatial_cell(point - Vector2.ONE * radius)
	var last := _spatial_cell(point + Vector2.ONE * radius)
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			for resource in resources_by_cell.get(Vector2i(x, y), []):
				if is_instance_valid(resource) and not resource.is_queued_for_deletion() and point.distance_squared_to(resource.position) <= radius * radius: result.append(resource)
	return result

func nearby_buildings(point: Vector2, radius: float) -> Array[RtsBuilding]:
	_ensure_spatial_index()
	var result: Array[RtsBuilding] = []
	var seen: Dictionary = {}
	var first := _spatial_cell(point - Vector2.ONE * radius)
	var last := _spatial_cell(point + Vector2.ONE * radius)
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			for building in buildings_by_cell.get(Vector2i(x, y), []):
				if not is_instance_valid(building) or building.is_queued_for_deletion() or seen.has(building.get_instance_id()): continue
				seen[building.get_instance_id()] = true
				if point.distance_squared_to(building.position) <= pow(radius + maxf(building.size().x, building.size().y), 2): result.append(building)
	return result

func unit_moved(unit: RtsUnit, previous_position: Vector2) -> void:
	if spatial_frame != Engine.get_process_frames(): return
	_move_in_index(units_by_cell, unit, previous_position)

func resource_moved(resource: RtsResource, previous_position: Vector2) -> void:
	if previous_position.snapped(Vector2.ONE * RESOURCE_REPLAN_DISTANCE) != resource.position.snapped(Vector2.ONE * RESOURCE_REPLAN_DISTANCE): invalidate_obstacles()
	if spatial_frame != Engine.get_process_frames(): return
	_move_in_index(resources_by_cell, resource, previous_position)

func _move_in_index(index: Dictionary, entity: Node2D, previous_position: Vector2) -> void:
	var old_cell := _spatial_cell(previous_position)
	var new_cell := _spatial_cell(entity.position)
	if old_cell == new_cell: return
	if index.has(old_cell): index[old_cell].erase(entity)
	if not index.has(new_cell): index[new_cell] = []
	index[new_cell].append(entity)

func _mark_rect(area: Rect2, grid: AStarGrid2D) -> void:
	var first := world_map.cell_at(area.position)
	var last := world_map.cell_at(area.end)
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			var cell := Vector2i(x, y)
			var center := world_map.cell_center(cell)
			if area.has_point(center): grid.set_point_solid(cell)

func _mark_circle(center: Vector2, radius: float, grid: AStarGrid2D) -> void:
	var first := world_map.cell_at(center - Vector2.ONE * radius)
	var last := world_map.cell_at(center + Vector2.ONE * radius)
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			var cell := Vector2i(x, y)
			if center.distance_to(world_map.cell_center(cell)) < radius:
				grid.set_point_solid(cell)

func _grid_for(unit: RtsUnit) -> AStarGrid2D:
	if unit == null: return pathfinder
	var naval: bool = unit.stats.get("tags", []).has("naval")
	var key := Vector3(unit.owner_id, unit.radius(), 1.0 if naval else 0.0)
	if clearance_grids.has(key): return clearance_grids[key]
	# The search and movement must agree on the body's actual clearance.
	# Cache per owner/body size; allied gates are handled by can_occupy too.
	var grid := AStarGrid2D.new()
	grid.region = pathfinder.region
	grid.cell_size = pathfinder.cell_size
	grid.offset = pathfinder.offset
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for y in world_map.grid_size.y:
		for x in world_map.grid_size.x:
			var cell := Vector2i(x, y)
			if not can_occupy(world_map.cell_center(cell), unit.radius(), unit, false): grid.set_point_solid(cell)
	clearance_grids[key] = grid
	return grid

func _connected_cell(point: Vector2, grid: AStarGrid2D, radius: float, unit: RtsUnit) -> Vector2i:
	var origin := world_map.cell_at(point)
	var best := Vector2i(-1, -1)
	var best_distance := INF
	for y in range(maxi(0, origin.y - 2), mini(world_map.grid_size.y, origin.y + 3)):
		for x in range(maxi(0, origin.x - 2), mini(world_map.grid_size.x, origin.x + 3)):
			var cell := Vector2i(x, y)
			if grid.is_point_solid(cell): continue
			var center := world_map.cell_center(cell)
			var distance := point.distance_squared_to(center)
			if distance < best_distance and _static_segment_clear(point, center, radius, unit):
				best = cell
				best_distance = distance
	return best

func _visible_cells(point: Vector2, grid: AStarGrid2D, radius: float, unit: RtsUnit) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var origin := world_map.cell_at(point)
	for y in range(maxi(0, origin.y - 2), mini(world_map.grid_size.y, origin.y + 3)):
		for x in range(maxi(0, origin.x - 2), mini(world_map.grid_size.x, origin.x + 3)):
			var cell := Vector2i(x, y)
			if not grid.is_point_solid(cell) and _static_segment_clear(point, world_map.cell_center(cell), radius, unit): result.append(cell)
	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return point.distance_squared_to(world_map.cell_center(a)) < point.distance_squared_to(world_map.cell_center(b)))
	return result

func _safe_point_path(grid: AStarGrid2D, start: Vector2i, end: Vector2i, unit: RtsUnit) -> PackedVector2Array:
	if start.x < 0 or end.x < 0: return PackedVector2Array()
	var radius := unit.radius() if unit != null else CLEARANCE
	# Two clear cell centers can still have a resource between them. Repair
	# that edge conservatively for this search, restoring the shared grid after.
	var blocked: Array[Vector2i] = []
	var result := PackedVector2Array()
	for attempt in 32:
		var raw := _point_path(grid, start, end)
		if raw.is_empty(): break
		var invalid := -1
		for i in range(1, raw.size()):
			if not _static_segment_clear(raw[i - 1], raw[i], radius, unit):
				invalid = i
				break
		if invalid < 0:
			result = raw
			break
		var cell := world_map.cell_at(raw[invalid])
		if cell == end: cell = world_map.cell_at(raw[invalid - 1])
		if cell == start: break
		grid.set_point_solid(cell)
		blocked.append(cell)
	for cell in blocked: grid.set_point_solid(cell, false)
	return result

func nearest_open_cell(point: Vector2, grid: AStarGrid2D = null) -> Vector2i:
	if grid == null: grid = pathfinder
	var origin := world_map.cell_at(point)
	if not grid.is_point_solid(origin): return origin
	var best := Vector2i(-1, -1)
	var best_distance := INF
	for radius in range(1, maxi(world_map.grid_size.x, world_map.grid_size.y)):
		for y in range(maxi(0, origin.y - radius), mini(world_map.grid_size.y - 1, origin.y + radius) + 1):
			for x in range(maxi(0, origin.x - radius), mini(world_map.grid_size.x - 1, origin.x + radius) + 1):
				if absi(x - origin.x) != radius and absi(y - origin.y) != radius: continue
				var cell := Vector2i(x, y)
				if grid.is_point_solid(cell): continue
				var distance := point.distance_squared_to(world_map.cell_center(cell))
				if distance < best_distance:
					best = cell
					best_distance = distance
		if best.x >= 0: return best
	return origin

func path_between(from: Vector2, to: Vector2, unit: RtsUnit = null, smooth := true) -> PackedVector2Array:
	if not profiling_enabled: return _path_between(from, to, unit, smooth)
	var started := Time.get_ticks_usec()
	var result := _path_between(from, to, unit, smooth)
	_record_profile(&"path_between", started)
	return result

func _path_between(from: Vector2, to: Vector2, unit: RtsUnit, smooth: bool) -> PackedVector2Array:
	_ensure_current()
	var radius := unit.radius() if unit != null else CLEARANCE
	if unit != null and (not can_occupy(from, radius, unit, false) or not can_occupy(to, radius, unit, false)): return PackedVector2Array()
	if smooth and _static_segment_clear(from, to, radius, unit):
		return PackedVector2Array([from, to]) if from.distance_squared_to(to) > 1.0 else PackedVector2Array([from])
	var grid := _grid_for(unit)
	var start := _connected_cell(from, grid, radius, unit) if unit != null else nearest_open_cell(from, grid)
	var end := _connected_cell(to, grid, radius, unit) if unit != null else nearest_open_cell(to, grid)
	var raw := _safe_point_path(grid, start, end, unit)
	if raw.is_empty() and unit != null:
		# Try other visible attachments at BOTH ends: the nearest center can
		# be isolated by geometry that fits between coarse grid centers.
		var starts := _visible_cells(from, grid, radius, unit)
		var ends := _visible_cells(to, grid, radius, unit)
		for last in ends:
			for first in starts:
				if first == start and last == end: continue
				raw = _safe_point_path(grid, first, last, unit)
				if not raw.is_empty(): break
			if not raw.is_empty(): break

	if raw.is_empty() and unit != null: return _fine_static_path(from, to, unit)
	if smooth: return _simplify_path(raw, from, to, unit)
	if not raw.is_empty():
		if from.distance_squared_to(raw[0]) > 1.0: raw.insert(0, from)
		if to.distance_squared_to(raw[raw.size() - 1]) > 1.0: raw.append(to)
	return raw

func _fine_static_path(from: Vector2, to: Vector2, unit: RtsUnit) -> PackedVector2Array:
	# Coarse centers can miss a physically open slit beside a resource. Only
	# failed strategic searches pay for this finer, bounded fallback.
	var step := maxf(6.0, minf(12.0, unit.radius() * 0.75))
	var bounds := Rect2(from, Vector2.ZERO).expand(to).grow(150.0)
	bounds = bounds.intersection(Rect2(Vector2.ZERO, world_map.world_size))
	var origin := from + ((bounds.position - from) / step).floor() * step
	var size := Vector2i(((bounds.end - origin) / step).ceil()) + Vector2i.ONE
	if size.x * size.y > 16000: return PackedVector2Array()
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(Vector2i.ZERO, size)
	grid.offset = origin
	grid.cell_size = Vector2.ONE * step
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for y in size.y:
		for x in size.x:
			var cell := Vector2i(x, y)
			if not can_occupy(grid.get_point_position(cell), unit.radius(), unit, false): grid.set_point_solid(cell)
	var start := Vector2i(((from - origin) / step).round())
	var end := Vector2i(((to - origin) / step).round())
	for y in range(maxi(0, end.y - 1), mini(size.y, end.y + 2)):
		for x in range(maxi(0, end.x - 1), mini(size.x, end.x + 2)):
			var cell := Vector2i(x, y)
			if grid.is_point_solid(cell) or not _static_segment_clear(grid.get_point_position(cell), to, unit.radius(), unit): continue
			var raw := _point_path(grid, start, cell)
			if raw.is_empty(): continue
			var valid := true
			for i in range(1, raw.size()):
				if not _static_segment_clear(raw[i - 1], raw[i], unit.radius(), unit):
					valid = false
					break
			if not valid: continue
			return _simplify_path(raw, from, to, unit)
	return PackedVector2Array()

func _simplify_path(raw: PackedVector2Array, from: Vector2, to: Vector2, unit: RtsUnit) -> PackedVector2Array:
	if raw.is_empty(): return raw
	var radius := unit.radius() if unit != null else CLEARANCE
	var points := PackedVector2Array()
	if _static_segment_clear(from, raw[0], radius, unit) and from.distance_squared_to(raw[0]) > 1.0:
		points.append(from)
	points.append_array(raw)
	if _static_segment_clear(raw[raw.size() - 1], to, radius, unit) and to.distance_squared_to(raw[raw.size() - 1]) > 1.0:
		points.append(to)
	if points.size() <= 2: return points
	if _static_segment_clear(points[0], points[points.size() - 1], radius, unit):
		return PackedVector2Array([points[0], points[points.size() - 1]])
	# Keep the search bounded when many units request long paths together.
	var result := PackedVector2Array([points[0]])
	var anchor := 0
	while anchor < points.size() - 1:
		var furthest := anchor + 1
		for candidate in range(anchor + 2, mini(points.size(), anchor + SMOOTH_LOOKAHEAD + 1)):
			if not _static_segment_clear(points[anchor], points[candidate], radius, unit): break
			furthest = candidate
		result.append(points[furthest])
		anchor = furthest
	return result

func _static_segment_clear(from: Vector2, to: Vector2, radius: float, unit: RtsUnit) -> bool:
	var samples := maxi(1, ceili(from.distance_to(to) / maxf(6.0, minf(12.0, radius * 0.75))))
	for i in range(samples + 1):
		if not can_occupy(from.lerp(to, float(i) / samples), radius, unit, false): return false
	return true

func _path_length(path: PackedVector2Array) -> float:
	var length := 0.0
	for i in range(1, path.size()): length += path[i - 1].distance_to(path[i])
	return length

func path_to_range(from: Vector2, target: Vector2, reach: float, unit: RtsUnit) -> PackedVector2Array:
	if not profiling_enabled: return _path_to_range(from, target, reach, unit)
	var started := Time.get_ticks_usec()
	var result := _path_to_range(from, target, reach, unit)
	_record_profile(&"path_to_range", started)
	return result

func _path_to_range(from: Vector2, target: Vector2, reach: float, unit: RtsUnit) -> PackedVector2Array:
	_ensure_current()
	var grid := _grid_for(unit)
	var direction := (from - target).normalized()
	if direction.is_zero_approx(): direction = Vector2.RIGHT
	var approaches: Array[Vector2] = []
	for offset in [0.0, PI / 4.0, -PI / 4.0, PI / 2.0, -PI / 2.0, 3.0 * PI / 4.0, -3.0 * PI / 4.0, PI]:
		approaches.append(target + direction.rotated(offset) * maxf(0.0, reach - 0.25))
	approaches.sort_custom(func(a: Vector2, b: Vector2) -> bool: return from.distance_squared_to(a) < from.distance_squared_to(b))
	var best := PackedVector2Array()
	var best_length := INF
	for approach in approaches:
		if from.distance_to(approach) >= best_length: break
		if not can_occupy(approach, unit.radius(), unit): continue
		if _static_segment_clear(from, approach, unit.radius(), unit):
			return PackedVector2Array([from, approach])
		var candidate := _path_between(from, approach, unit, true)
		if candidate.is_empty(): continue
		if candidate[candidate.size() - 1].distance_squared_to(approach) > 1.0: candidate.append(approach)
		var length := from.distance_to(candidate[0]) + _path_length(candidate)
		if length < best_length:
			best = candidate
			best_length = length
	if not best.is_empty(): return best
	# A thin corridor may intersect the interaction disk without intersecting
	# any of the eight sampled points on its circumference.
	var candidates: Array[Vector2] = []
	var first := world_map.cell_at(target - Vector2.ONE * reach)
	var last := world_map.cell_at(target + Vector2.ONE * reach)
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			var cell := Vector2i(x, y)
			var point := world_map.cell_center(cell)
			if not grid.is_point_solid(cell) and point.distance_to(target) <= reach and can_occupy(point, unit.radius(), unit): candidates.append(point)
	candidates.sort_custom(func(a: Vector2, b: Vector2) -> bool: return from.distance_squared_to(a) < from.distance_squared_to(b))
	for point in candidates:
		if from.distance_to(point) >= best_length: break
		var candidate := _path_between(from, point, unit, true)
		if candidate.is_empty(): continue
		var length := _path_length(candidate)
		if length < best_length:
			best = candidate
			best_length = length
	return best

func nearest_walkable_point(point: Vector2, radius := CLEARANCE, self_unit: RtsUnit = null, require_path := false, include_units := true) -> Vector2:
	if not profiling_enabled: return _nearest_walkable_point(point, radius, self_unit, require_path, include_units)
	var started := Time.get_ticks_usec()
	var result := _nearest_walkable_point(point, radius, self_unit, require_path, include_units)
	_record_profile(&"nearest_walkable_point", started)
	return result

func _nearest_walkable_point(point: Vector2, radius: float, self_unit: RtsUnit, require_path: bool, include_units: bool) -> Vector2:
	_ensure_current()
	var grid := _grid_for(self_unit)
	var clamped := point.clamp(Vector2(24, 24), world_map.world_size - Vector2(24, 24))
	var start := nearest_open_cell(self_unit.position, grid) if require_path and self_unit != null else Vector2i(-1, -1)
	if _valid_destination(clamped, radius, self_unit, start, grid, include_units): return clamped
	var approach_angle := (self_unit.position - clamped).angle() if self_unit != null else 0.0
	for ring in range(1, 17):
		for i in 16:
			# Equal-distance alternatives should face the approaching unit;
			# an east-first scan can send a west-side unit around the obstacle.
			var angular_step := ceili(i / 2.0) * (1 if i % 2 == 1 else -1)
			var candidate := clamped + Vector2.from_angle(approach_angle + TAU * angular_step / 16.0) * ring * maxf(radius, 12.0)
			if _valid_destination(candidate, radius, self_unit, start, grid, include_units, false): return candidate
	if start.x >= 0:
		var best := Vector2.INF
		var best_distance := INF
		for y in world_map.grid_size.y:
			for x in world_map.grid_size.x:
				var cell := Vector2i(x, y)
				if grid.is_point_solid(cell): continue
				var candidate := world_map.cell_center(cell)
				var distance := candidate.distance_squared_to(clamped)
				if distance >= best_distance or not can_occupy(candidate, radius, self_unit, include_units): continue
				if _id_path(grid, start, cell).is_empty(): continue
				if self_unit != null and _path_between(self_unit.position, candidate, self_unit, true).is_empty(): continue
				best = candidate
				best_distance = distance
		if best != Vector2.INF: return best
	return world_map.cell_center(nearest_open_cell(clamped, grid))

func _valid_destination(point: Vector2, radius: float, self_unit: RtsUnit, start: Vector2i, grid: AStarGrid2D, include_units := true, allow_disconnected := true) -> bool:
	if not can_occupy(point, radius, self_unit, include_units): return false
	if start.x < 0: return true
	if not allow_disconnected and _id_path(grid, start, nearest_open_cell(point, grid)).is_empty(): return false
	if self_unit != null:
		return not _path_between(self_unit.position, point, self_unit, true).is_empty()
	var end := world_map.cell_at(point)
	return not grid.is_point_solid(end) and not _id_path(grid, start, end).is_empty()

func _segment_clear(from: Vector2, to: Vector2, radius: float, self_unit: RtsUnit) -> bool:
	var samples := maxi(1, ceili(from.distance_to(to) / maxf(1.0, radius * 0.5)))
	for i in range(samples + 1):
		if not can_occupy(from.lerp(to, float(i) / samples), radius, self_unit): return false
	return true

func has_fixed_unit_blocker(unit: RtsUnit, target: Vector2) -> bool:
	for other in nearby_units(unit.position, 160.0):
		if other == unit: continue
		if not game.is_enemy(unit.owner_id, other.owner_id) and other.stance != "hold" and other.order in ["idle", "move", "attack_move"]: continue
		var closest := Geometry2D.get_closest_point_to_segment(other.position, unit.position, target)
		if closest.distance_to(other.position) < unit.radius() + other.radius() + 4.0: return true
	return false

func path_around_units(unit: RtsUnit, target: Vector2) -> PackedVector2Array:
	# Recovery only: a local fine grid can route between parked formation
	# members that the 50-pixel strategic grid cannot represent.
	const STEP := 8.0
	const HALF := 24
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(0, 0, HALF * 2 + 1, HALF * 2 + 1)
	grid.cell_size = Vector2.ONE * STEP
	grid.offset = unit.position - Vector2.ONE * HALF * STEP
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for y in grid.region.size.y:
		for x in grid.region.size.x:
			var cell := Vector2i(x, y)
			if not can_occupy(grid.get_point_position(cell), unit.radius(), unit): grid.set_point_solid(cell)
	var start := Vector2i(HALF, HALF)
	grid.set_point_solid(start, false)
	var local_target := Vector2i(((target - grid.offset) / STEP).round()).clamp(Vector2i.ZERO, grid.region.size - Vector2i.ONE)
	var candidates: Array[Vector2i] = [local_target]
	for y in grid.region.size.y:
		for x in grid.region.size.x:
			var cell := Vector2i(x, y)
			if cell == local_target or grid.is_point_solid(cell): continue
			if x == 0 or y == 0 or x == grid.region.size.x - 1 or y == grid.region.size.y - 1 or cell.distance_squared_to(local_target) <= 9:
				candidates.append(cell)
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return grid.get_point_position(a).distance_squared_to(target) < grid.get_point_position(b).distance_squared_to(target))
	for cell in candidates:
		if grid.is_point_solid(cell): continue
		var raw := _point_path(grid, start, cell)
		if raw.size() < 2: continue
		if raw[raw.size() - 1].distance_to(target) >= unit.position.distance_to(target) - 4.0: continue
		var result := PackedVector2Array([unit.position])
		var anchor := 0
		while anchor < raw.size() - 1:
			var next := anchor + 1
			if not _segment_clear(raw[anchor], raw[next], unit.radius(), unit): break
			for index in range(anchor + 2, mini(raw.size(), anchor + 12)):
				if not _segment_clear(raw[anchor], raw[index], unit.radius(), unit): break
				next = index
			result.append(raw[next])
			anchor = next
		if anchor != raw.size() - 1: continue
		if _segment_clear(result[result.size() - 1], target, unit.radius(), unit): result.append(target)
		return result
	return PackedVector2Array()

func _yield_allies(unit: RtsUnit, destination: Vector2, yielding: Array[int] = []) -> bool:
	if yielding.size() >= 3 or yielding.has(unit.get_instance_id()): return false
	yielding = yielding.duplicate()
	yielding.append(unit.get_instance_id())
	if not _static_segment_clear(unit.position, destination, unit.radius(), unit): return false
	var forward := (destination - unit.position).normalized()
	var changed := false
	for other in nearby_units(destination, unit.radius() + max_dynamic_radius + 2.0):
		if yielding.has(other.get_instance_id()) or other.stance == "hold" or game.is_enemy(unit.owner_id, other.owner_id): continue
		var stalled := other.order in ["move", "attack_move"] and (other.route_stalled_time >= RtsUnit.ROUTE_STALL_SECONDS or other.group_stuck_time >= 0.9)
		if other.order != "idle" and not (stalled and unit.get_instance_id() < other.get_instance_id()): continue
		if other.position.distance_to(destination) >= unit.radius() + other.radius(): continue
		var lateral := Vector2(-forward.y, forward.x)
		if (other.position - unit.position).dot(lateral) < 0.0: lateral = -lateral
		var distance := minf(other.radius() * 0.6, maxf(2.0, unit.position.distance_to(destination)))
		for angle in [0.0, PI / 4.0, -PI / 4.0, PI, 3.0 * PI / 4.0, -3.0 * PI / 4.0]:
			var point := other.position + lateral.rotated(angle) * distance
			if not _motion_clear(other, point):
				if not _yield_allies(other, point, yielding) or not _motion_clear(other, point): continue
			var previous := other.position
			other.position = point
			if other.order != "idle": other.yield_timer = 0.3
			unit_moved(other, previous)
			other._update_facing(previous)
			other._refresh_slope_visual(previous)
			changed = true
			break
	return changed

func move_step(unit: RtsUnit, desired_position: Vector2) -> Vector2:
	var movement := desired_position - unit.position
	if movement.is_zero_approx(): return unit.position
	# Sweep the full requested displacement, preserving speed at ordinary
	# simulation rates while bounding pathological pauses to eight substeps.
	var max_step := unit.radius() * 0.6
	if movement.length() > max_step + 0.001:
		var origin := unit.position
		var steps := mini(8, ceili(movement.length() / max_step))
		var step := movement.normalized() * minf(max_step, movement.length() / steps)
		for i in steps:
			var previous := unit.position
			unit.position = move_step(unit, unit.position + step)
			unit_moved(unit, previous)
			if unit.position == previous: break
		var result := unit.position
		unit.position = origin
		unit_moved(unit, result)
		return result
	var direction := movement.normalized()
	var distance := movement.length()
	if _motion_clear(unit, desired_position): return desired_position
	if unit.movement_group != null:
		if unit.avoidance_cooldown > 0.0: return unit.position
		unit.avoidance_cooldown = 0.18
	if unit.yield_request_cooldown <= 0.0:
		unit.yield_request_cooldown = 0.18
		if _yield_allies(unit, desired_position) and _motion_clear(unit, desired_position): return desired_position
	var side := 1.0 if unit.get_instance_id() % 2 == 0 else -1.0
	var offsets := [side * PI / 4.0, -side * PI / 4.0] if unit.movement_group != null else [side * PI / 4.0, -side * PI / 4.0, side * PI / 2.0, -side * PI / 2.0, side * PI * 0.75, -side * PI * 0.75]
	for offset in offsets:
		var candidate_direction := direction.rotated(offset)
		var candidate: Vector2 = unit.position + candidate_direction * distance
		if _motion_clear(unit, candidate): return candidate
	return unit.position

func _motion_clear(unit: RtsUnit, destination: Vector2) -> bool:
	var distance := unit.position.distance_to(destination)
	# A sub-radius step cannot jump across a unit or a blocked terrain cell.
	# Checking its endpoint once avoids repeated neighborhood scans for every
	# member of a moving army on ordinary rendered frames.
	if distance <= unit.radius() * 0.6: return can_occupy(destination, unit.radius(), unit)
	var samples := maxi(1, ceili(distance / maxf(1.0, unit.radius() * 0.6)))
	for i in range(1, samples + 1):
		var fraction := float(i) / samples
		if not can_occupy(unit.position.lerp(destination, fraction), unit.radius(), unit): return false
	return true

func can_occupy(point: Vector2, radius: float, self_unit: RtsUnit, include_units := true) -> bool:
	if not profiling_enabled: return _can_occupy(point, radius, self_unit, include_units)
	var started := Time.get_ticks_usec()
	var result := _can_occupy(point, radius, self_unit, include_units)
	_record_profile(&"can_occupy", started)
	return result

func _can_occupy(point: Vector2, radius: float, self_unit: RtsUnit, include_units: bool) -> bool:
	_ensure_spatial_index()
	if point.x < radius or point.y < radius or point.x > world_map.world_size.x - radius or point.y > world_map.world_size.y - radius: return false
	var naval: bool = self_unit != null and self_unit.stats.get("tags", []).has("naval")
	var cell_size := float(RtsWorldMap.CELL_SIZE)
	var first_x := floori((point.x - radius) / cell_size)
	var last_x := mini(world_map.grid_size.x - 1, floori((point.x + radius) / cell_size))
	var first_y := floori((point.y - radius) / cell_size)
	var last_y := mini(world_map.grid_size.y - 1, floori((point.y + radius) / cell_size))
	for cy in range(first_y, last_y + 1):
		for cx in range(first_x, last_x + 1):
			var terrain: int = world_map.cells[cy * world_map.grid_size.x + cx]
			if (terrain == RtsWorldMap.Terrain.WATER) == naval and terrain != RtsWorldMap.Terrain.MOUNTAIN: continue
			var closest := Vector2(clampf(point.x, cx * cell_size, (cx + 1) * cell_size), clampf(point.y, cy * cell_size, (cy + 1) * cell_size))
			if point.distance_squared_to(closest) < radius * radius: return false
	for building in buildings_by_cell.get(_spatial_cell(point), []):
		if not is_instance_valid(building) or building.is_queued_for_deletion(): continue
		if self_unit != null and not game.is_enemy(self_unit.owner_id, building.owner_id) and building.kind.ends_with("_gate") and building.is_complete(): continue
		if Rect2(building.position - building.size() * 0.5, building.size()).grow(radius).has_point(point): return false
	var center_cell := _spatial_cell(point)
	var search_radius := ceili((radius + max_dynamic_radius) / SPATIAL_CELL_SIZE)
	for y in range(center_cell.y - search_radius, center_cell.y + search_radius + 1):
		for x in range(center_cell.x - search_radius, center_cell.x + search_radius + 1):
			var cell := Vector2i(x, y)
			for resource in resources_by_cell.get(cell, []):
				if not is_instance_valid(resource) or resource.is_queued_for_deletion(): continue
				var distance_limit: float = radius + resource.radius
				if point.distance_squared_to(resource.position) < distance_limit * distance_limit: return false
			if not include_units: continue
			for other in units_by_cell.get(cell, []):
				if not is_instance_valid(other) or other.is_queued_for_deletion() or other == self_unit: continue
				var personal_space: float = radius + other.radius()
				if point.distance_squared_to(other.position) < personal_space * personal_space:
					if self_unit == null or point.distance_squared_to(other.position) <= self_unit.position.distance_squared_to(other.position): return false
	return true

class_name RtsNavigation
extends RefCounted

# Terrain is owned by RtsWorldMap. This layer adds changing entity footprints.
const CLEARANCE := 16.0
const SPATIAL_CELL_SIZE := 64.0
const SMOOTH_LOOKAHEAD := 8
const MAX_FINE_GRIDS := 4

var game: Node2D
var world_map: RtsWorldMap
# Generic queries retain their fixed-clearance grid, built only when requested.
var pathfinder: AStarGrid2D:
	get:
		_ensure_current()
		if _default_grid == null: _default_grid = _make_default_grid()
		return _default_grid
var _default_grid: AStarGrid2D
var clearance_grids: Dictionary = {}
var fine_grids: Dictionary = {}
var local_fine_grids: Array[Dictionary] = []
var grid_components: Dictionary = {}
var corner_graphs: Dictionary = {}
var obstacle_signature := -1
var obstacle_revision := 0
# Resource motion changes collision geometry, but must not wake every failed
# route in the match. Structural edits still interrupt retry backoff.
var retry_obstacle_revision := 0
var retry_obstacle_signature := -1
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

func _init(game_ref: Node2D, map_ref: RtsWorldMap) -> void:
	game = game_ref
	world_map = map_ref

func refresh(wake_failed_routes := true) -> void:
	if wake_failed_routes: retry_obstacle_signature = -1
	var started := Time.get_ticks_usec() if profiling_enabled else 0
	_refresh_grids()
	if profiling_enabled: _record_profile(&"grid_refresh", started)

func _refresh_grids() -> void:
	clearance_grids.clear()
	fine_grids.clear()
	local_fine_grids.clear()
	grid_components.clear()
	corner_graphs.clear()
	obstacle_revision += 1
	obstacle_signature = _obstacle_signature()
	var retry_signature := _obstacle_signature(true)
	if retry_signature != retry_obstacle_signature:
		retry_obstacle_signature = retry_signature
		retry_obstacle_revision += 1
	obstacle_check_frame = Engine.get_process_frames()
	invalidate_spatial_index()
	_default_grid = null

func _make_default_grid() -> AStarGrid2D:
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(Vector2i.ZERO, world_map.grid_size)
	grid.cell_size = Vector2.ONE * RtsWorldMap.CELL_SIZE
	grid.offset = Vector2.ONE * RtsWorldMap.CELL_SIZE * 0.5
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for y in world_map.grid_size.y:
		for x in world_map.grid_size.x:
			var cell := Vector2i(x, y)
			if not world_map.is_walkable(world_map.cell_center(cell)): grid.set_point_solid(cell)
	for building in game.buildings:
		if not is_instance_valid(building) or building.is_queued_for_deletion(): continue
		if not _gate_passable(building, 0):
			_mark_rect(Rect2(building.position - building.size() * 0.5, building.size()).grow(CLEARANCE), grid)
	for resource in game.resources:
		if not is_instance_valid(resource) or resource.is_queued_for_deletion(): continue
		_mark_circle(resource.position, resource.radius + CLEARANCE, grid)
	# Preserve the generic query's player-zero gate corridor. Unit queries use
	# their actual body size and owner through _grid_for instead.
	for building in game.buildings:
		if not is_instance_valid(building) or building.is_queued_for_deletion() or not _gate_passable(building, 0): continue
		var first := world_map.cell_at(building.position - Vector2.ONE * RtsWorldMap.CELL_SIZE)
		var last := world_map.cell_at(building.position + Vector2.ONE * RtsWorldMap.CELL_SIZE)
		for y in range(first.y, last.y + 1):
			for x in range(first.x, last.x + 1):
				var cell := Vector2i(x, y)
				var delta: Vector2 = world_map.cell_center(cell) - building.position
				var along := absf(delta.y) if building.wall_vertical else absf(delta.x)
				var across := absf(delta.x) if building.wall_vertical else absf(delta.y)
				if along <= RtsWorldMap.CELL_SIZE * 0.55 and across <= RtsWorldMap.CELL_SIZE * 1.1 and world_map.is_walkable(world_map.cell_center(cell)):
					grid.set_point_solid(cell, false)
	return grid

func _obstacle_signature(ignore_resource_positions := false) -> int:
	var signature := 0
	for building in game.buildings:
		if is_instance_valid(building) and not building.is_queued_for_deletion():
			signature = hash([signature, building.get_instance_id(), building.position, building.size(), building.owner_id, building.kind, building.is_complete()])
	for resource in game.resources:
		if is_instance_valid(resource) and not resource.is_queued_for_deletion():
			signature = hash([signature, resource.get_instance_id(), Vector2.ZERO if ignore_resource_positions else resource.position, resource.radius])
	return signature

func _ensure_current() -> void:
	var frame := Engine.get_process_frames()
	if obstacle_check_frame == frame: return
	obstacle_check_frame = frame
	if obstacle_signature != _obstacle_signature(): refresh(false)

func invalidate_spatial_index() -> void:
	spatial_frame = -1

func invalidate_obstacles(wake_failed_routes := true) -> void:
	if wake_failed_routes: retry_obstacle_signature = -1
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
	if previous_position != resource.position: invalidate_obstacles(false)

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

func _grid_key(unit: RtsUnit) -> Vector3:
	return Vector3(unit.owner_id, unit.radius(), 1.0 if unit.stats.get("tags", []).has("naval") else 0.0)

func _gate_passable(building: RtsBuilding, owner_id: int) -> bool:
	return building.kind.ends_with("_gate") and building.is_complete() and not game.is_enemy(owner_id, building.owner_id)

func _terrain_passable(terrain: int, naval: bool, boarding := false) -> bool:
	return terrain != RtsWorldMap.Terrain.MOUNTAIN and (boarding or (terrain == RtsWorldMap.Terrain.WATER) == naval)

func _grid_for(unit: RtsUnit) -> AStarGrid2D:
	if unit == null: return pathfinder
	var key := _grid_key(unit)
	if clearance_grids.has(key): return clearance_grids[key]
	# The search and movement must agree on the body's actual clearance.
	# Cache per owner/body size; allied gates are handled by can_occupy too.
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(Vector2i.ZERO, world_map.grid_size)
	grid.cell_size = Vector2.ONE * RtsWorldMap.CELL_SIZE
	grid.offset = Vector2.ONE * RtsWorldMap.CELL_SIZE * 0.5
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for y in world_map.grid_size.y:
		for x in world_map.grid_size.x:
			var cell := Vector2i(x, y)
			if not can_occupy(world_map.cell_center(cell), unit.radius(), unit, false, false): grid.set_point_solid(cell)
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

func _visible_cells(point: Vector2, grid: AStarGrid2D, radius: float, unit: RtsUnit, origin: Vector2i, extent: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in range(maxi(0, origin.y - extent), mini(grid.region.size.y, origin.y + extent + 1)):
		for x in range(maxi(0, origin.x - extent), mini(grid.region.size.x, origin.x + extent + 1)):
			var cell := Vector2i(x, y)
			if not grid.is_point_solid(cell) and _static_segment_clear(point, grid.get_point_position(cell), radius, unit): result.append(cell)
	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return point.distance_squared_to(grid.get_point_position(a)) < point.distance_squared_to(grid.get_point_position(b)))
	return result

func _safe_point_path(grid: AStarGrid2D, start: Vector2i, end: Vector2i, unit: RtsUnit) -> PackedVector2Array:
	if start.x < 0 or end.x < 0: return PackedVector2Array()
	var components := _components_for(grid)
	if components[start.y * grid.region.size.x + start.x] != components[end.y * grid.region.size.x + end.x]: return PackedVector2Array()
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
		var cell := Vector2i(((raw[invalid] - grid.offset) / grid.cell_size).round())
		if cell == end: cell = Vector2i(((raw[invalid - 1] - grid.offset) / grid.cell_size).round())
		if cell == start: break
		grid.set_point_solid(cell)
		blocked.append(cell)
	for cell in blocked: grid.set_point_solid(cell, false)
	return result

func _components_for(grid: AStarGrid2D, cache := true) -> PackedInt32Array:
	var key := grid.get_instance_id()
	if cache and grid_components.has(key): return grid_components[key]
	# Diagonals cannot cross blocked corners, so four-neighbor components are
	# also valid for the eight-neighbor search. Reject disconnected candidates
	# once, rather than exhausting A* for every worker/interaction sample.
	var size := grid.region.size
	var labels := PackedInt32Array()
	labels.resize(size.x * size.y)
	labels.fill(-1)
	var queue := PackedInt32Array()
	queue.resize(labels.size())
	var component := 0
	for index in labels.size():
		if labels[index] != -1: continue
		var origin := Vector2i(index % size.x, index / size.x)
		if grid.is_point_solid(origin):
			labels[index] = -2
			continue
		labels[index] = component
		queue[0] = index
		var head := 0
		var tail := 1
		while head < tail:
			var current := queue[head]
			head += 1
			var cell := Vector2i(current % size.x, current / size.x)
			for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var next: Vector2i = cell + offset
				if next.x < 0 or next.y < 0 or next.x >= size.x or next.y >= size.y: continue
				var neighbor := next.y * size.x + next.x
				if labels[neighbor] != -1: continue
				if grid.is_point_solid(next):
					labels[neighbor] = -2
					continue
				labels[neighbor] = component
				queue[tail] = neighbor
				tail += 1
		component += 1
	if cache: grid_components[key] = labels
	return labels

func nearest_open_cell(point: Vector2, grid: AStarGrid2D = null) -> Vector2i:
	return world_map.nearest_open_cell(point, pathfinder if grid == null else grid)

func path_between(from: Vector2, to: Vector2, unit: RtsUnit = null, smooth := true) -> PackedVector2Array:
	if not profiling_enabled: return _path_between(from, to, unit, smooth)
	var started := Time.get_ticks_usec()
	var result := _path_between(from, to, unit, smooth)
	_record_profile(&"path_between", started)
	return result

func _path_between(from: Vector2, to: Vector2, unit: RtsUnit, smooth: bool, allow_fine := true) -> PackedVector2Array:
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
		var starts := _visible_cells(from, grid, radius, unit, world_map.cell_at(from), 2)
		var ends := _visible_cells(to, grid, radius, unit, world_map.cell_at(to), 2)
		for last in ends:
			for first in starts:
				if first == start and last == end: continue
				raw = _safe_point_path(grid, first, last, unit)
				if not raw.is_empty(): break
			if not raw.is_empty(): break

	if raw.is_empty() and unit != null:
		return _fine_static_path(from, to, unit) if allow_fine else PackedVector2Array()
	if smooth: return _simplify_path(raw, from, to, unit)
	if not raw.is_empty():
		if from.distance_squared_to(raw[0]) > 1.0: raw.insert(0, from)
		if to.distance_squared_to(raw[raw.size() - 1]) > 1.0: raw.append(to)
	return raw

func _fine_static_path(from: Vector2, to: Vector2, unit: RtsUnit) -> PackedVector2Array:
	# Reachability cannot depend on the request's bounding box: the only
	# opening may lie far beyond it. Share a world-wide fallback by body type
	# and obstacle revision instead of rebuilding a local grid for every worker.
	var key := _grid_key(unit)
	if not fine_grids.has(key):
		var local := _local_fine_grid_for(from, to, unit, key)
		if local != null:
			var path := _search_fine_grid(from, to, unit, local)
			if not path.is_empty(): return path
	var path := _search_fine_grid(from, to, unit, _fine_grid_for(unit))
	return path if not path.is_empty() else _obstacle_corner_path(from, to, unit)

func _search_fine_grid(from: Vector2, to: Vector2, unit: RtsUnit, grid: AStarGrid2D) -> PackedVector2Array:
	var starts := _fine_visible_cells(from, grid, unit)
	var ends := _fine_visible_cells(to, grid, unit)
	for start in starts:
		for end in ends:
			var raw := _safe_point_path(grid, start, end, unit)
			if not raw.is_empty(): return _simplify_path(raw, from, to, unit)
	return PackedVector2Array()

func _fine_step(unit: RtsUnit) -> float:
	return float(RtsWorldMap.CELL_SIZE) / ceili(RtsWorldMap.CELL_SIZE / maxf(6.0, minf(12.0, unit.radius() * 0.75)))

func _local_fine_grid_for(from: Vector2, to: Vector2, unit: RtsUnit, key: Vector3) -> AStarGrid2D:
	# Nearby squads reuse the same small refinement. Failure here must still
	# fall through to the world grid; this is a fast path, never a reachability cap.
	for entry in local_fine_grids:
		if entry["key"] == key and entry["bounds"].has_point(from) and entry["bounds"].has_point(to): return entry["grid"]
	var bounds := Rect2(from, Vector2.ZERO).expand(to).grow(150.0).intersection(Rect2(Vector2.ZERO, world_map.world_size))
	var step := _fine_step(unit)
	var origin := (bounds.position / step).floor() * step
	var size := Vector2i(((bounds.end - origin) / step).ceil()) + Vector2i.ONE
	if size.x * size.y > 16000: return null
	if local_fine_grids.size() >= MAX_FINE_GRIDS:
		var oldest: Dictionary = local_fine_grids.pop_front()
		grid_components.erase(oldest["grid"].get_instance_id())
	var grid := _make_fine_grid(unit, bounds)
	local_fine_grids.append({"key": key, "bounds": bounds, "grid": grid})
	return grid

func _obstacle_corner_path(from: Vector2, to: Vector2, unit: RtsUnit) -> PackedVector2Array:
	# Even a fine lattice can miss a legal 1px-wide band between expanded
	# footprints or terrain and a resource. Boundary corners provide portals
	# independent of the lattice; every connecting edge still uses a full sweep.
	var key := _grid_key(unit)
	if not corner_graphs.has(key):
		var corners := PackedVector2Array()
		for obstacle in game.buildings:
			if not is_instance_valid(obstacle) or obstacle.is_queued_for_deletion(): continue
			if _gate_passable(obstacle, unit.owner_id): continue
			var bounds := Rect2(obstacle.position - obstacle.size() * 0.5, obstacle.size()).grow(unit.radius() + 0.05)
			for point in [bounds.position, bounds.end, Vector2(bounds.position.x, bounds.end.y), Vector2(bounds.end.x, bounds.position.y)]:
				if not corners.has(point) and can_occupy(point, unit.radius(), unit, false, false): corners.append(point)
		var naval: bool = unit.stats.get("tags", []).has("naval")
		for y in world_map.grid_size.y:
			for x in world_map.grid_size.x:
				var terrain: int = world_map.cells[y * world_map.grid_size.x + x]
				if _terrain_passable(terrain, naval): continue
				var bounds := Rect2(Vector2(x, y) * RtsWorldMap.CELL_SIZE, Vector2.ONE * RtsWorldMap.CELL_SIZE).grow(unit.radius() + 0.05)
				for point in [bounds.position, bounds.end, Vector2(bounds.position.x, bounds.end.y), Vector2(bounds.end.x, bounds.position.y)]:
					if not corners.has(point) and can_occupy(point, unit.radius(), unit, false, false): corners.append(point)
		corner_graphs[key] = {"points": corners, "edges": {}}
	var graph: Dictionary = corner_graphs[key]
	var points := PackedVector2Array([from, to])
	points.append_array(graph["points"])
	var costs := PackedFloat64Array()
	costs.resize(points.size())
	costs.fill(INF)
	costs[0] = 0.0
	var closed := PackedByteArray()
	closed.resize(points.size())
	var parents := PackedInt32Array()
	parents.resize(points.size())
	parents.fill(-1)
	# Lazy visibility A*: only test edges out of expanded nodes; keep static
	# corner-to-corner results for other workers sharing the same obstacles.
	while true:
		var current := -1
		var best := INF
		for i in points.size():
			if closed[i]: continue
			var estimate := costs[i] + points[i].distance_to(to)
			if estimate < best:
				best = estimate
				current = i
		if current < 0: return PackedVector2Array()
		if current == 1:
			var result := PackedVector2Array()
			while current >= 0:
				result.append(points[current])
				current = parents[current]
			result.reverse()
			return result
		closed[current] = 1
		for next in points.size():
			if closed[next]: continue
			var cost := costs[current] + points[current].distance_to(points[next])
			if cost >= costs[next] or cost + points[next].distance_to(to) > costs[1]: continue
			var edge := Vector2i(mini(current, next), maxi(current, next))
			var clear: bool
			if edge.x >= 2 and graph["edges"].has(edge): clear = graph["edges"][edge]
			else:
				clear = _static_segment_clear(points[current], points[next], unit.radius(), unit, false)
				if edge.x >= 2: graph["edges"][edge] = clear
			if clear:
				costs[next] = cost
				parents[next] = current
	# GDScript requires a terminal return even though the loop exits above.
	return PackedVector2Array()

func _fine_grid_for(unit: RtsUnit) -> AStarGrid2D:
	var key := _grid_key(unit)
	if fine_grids.has(key): return fine_grids[key]
	if fine_grids.size() >= MAX_FINE_GRIDS:
		var oldest: Vector3 = fine_grids.keys()[0]
		grid_components.erase(fine_grids[oldest].get_instance_id())
		fine_grids.erase(oldest)
	var grid := _make_fine_grid(unit, Rect2(Vector2.ZERO, world_map.world_size))
	fine_grids[key] = grid
	return grid

func _make_fine_grid(unit: RtsUnit, bounds: Rect2) -> AStarGrid2D:
	var step := _fine_step(unit)
	var origin := (bounds.position / step).floor() * step
	var size := Vector2i(((bounds.end - origin) / step).ceil()) + Vector2i.ONE
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(Vector2i.ZERO, size)
	grid.offset = origin
	grid.cell_size = Vector2.ONE * step
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	_rasterize_static_grid(unit, grid)
	return grid

func _rasterize_static_grid(unit: RtsUnit, grid: AStarGrid2D, allow_resource_escape := false) -> void:
	# Rasterize static geometry once. Querying all spatial buckets for every
	# fine cell made the first shared route stall a large army's command frame.
	var step := grid.cell_size.x
	var origin := grid.offset
	var size := grid.region.size
	var radius := unit.radius()
	var first := Vector2i(((Vector2.ONE * radius - origin) / step).ceil()).clamp(Vector2i.ZERO, size)
	var last := Vector2i(((world_map.world_size - Vector2.ONE * radius - origin) / step).floor()).clamp(-Vector2i.ONE, size - Vector2i.ONE)
	grid.fill_solid_region(Rect2i(0, 0, first.x, size.y))
	grid.fill_solid_region(Rect2i(last.x + 1, 0, size.x - last.x - 1, size.y))
	grid.fill_solid_region(Rect2i(0, 0, size.x, first.y))
	grid.fill_solid_region(Rect2i(0, last.y + 1, size.x, size.y - last.y - 1))
	var naval: bool = unit.stats.get("tags", []).has("naval")
	for y in world_map.grid_size.y:
		for x in world_map.grid_size.x:
			var terrain: int = world_map.cells[y * world_map.grid_size.x + x]
			if _terrain_passable(terrain, naval): continue
			var tile := Rect2(Vector2(x, y) * RtsWorldMap.CELL_SIZE, Vector2.ONE * RtsWorldMap.CELL_SIZE)
			var region := _fine_region(grid, tile.grow(radius))
			for cy in range(region.position.y, region.end.y):
				for cx in range(region.position.x, region.end.x):
					var cell := Vector2i(cx, cy)
					if grid.is_point_solid(cell): continue
					var point := grid.get_point_position(cell)
					if point.distance_squared_to(point.clamp(tile.position, tile.end)) < radius * radius: grid.set_point_solid(cell)
	for obstacle in game.buildings:
		if not is_instance_valid(obstacle) or obstacle.is_queued_for_deletion(): continue
		if _gate_passable(obstacle, unit.owner_id): continue
		var footprint := Rect2(obstacle.position - obstacle.size() * 0.5, obstacle.size()).grow(radius)
		var region := _fine_region(grid, footprint)
		for y in range(region.position.y, region.end.y):
			for x in range(region.position.x, region.end.x):
				var cell := Vector2i(x, y)
				if footprint.has_point(grid.get_point_position(cell)): grid.set_point_solid(cell)
	for obstacle in game.resources:
		if not is_instance_valid(obstacle) or obstacle.is_queued_for_deletion(): continue
		var reach: float = radius + obstacle.radius
		var current := unit.position.distance_squared_to(obstacle.position)
		var region := _fine_region(grid, Rect2(obstacle.position - Vector2.ONE * reach, Vector2.ONE * reach * 2))
		for y in range(region.position.y, region.end.y):
			for x in range(region.position.x, region.end.x):
				var cell := Vector2i(x, y)
				var distance := grid.get_point_position(cell).distance_squared_to(obstacle.position)
				if distance < reach * reach and (not allow_resource_escape or current >= reach * reach or distance + 0.001 < current): grid.set_point_solid(cell)

func _fine_region(grid: AStarGrid2D, bounds: Rect2) -> Rect2i:
	var first := Vector2i(((bounds.position - grid.offset) / grid.cell_size).floor())
	var last := Vector2i(((bounds.end - grid.offset) / grid.cell_size).ceil()) + Vector2i.ONE
	return Rect2i(first, last - first).intersection(grid.region)

func _fine_visible_cells(point: Vector2, grid: AStarGrid2D, unit: RtsUnit) -> Array[Vector2i]:
	var origin := Vector2i(((point - grid.offset) / grid.cell_size).round())
	return _visible_cells(point, grid, unit.radius(), unit, origin, 1)

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

func _static_segment_clear(from: Vector2, to: Vector2, radius: float, unit: RtsUnit, allow_resource_escape := true, boarding := false) -> bool:
	# Point samples alone can jump over the very short chord where a segment
	# grazes a circle or a building corner, especially inside narrow passages.
	var center := (from + to) * 0.5
	var extent := from.distance_to(to) * 0.5
	var samples := maxi(1, ceili(from.distance_to(to) / maxf(6.0, minf(12.0, radius * 0.75))))
	for obstacle in nearby_buildings(center, extent + radius):
		if unit != null and _gate_passable(obstacle, unit.owner_id): continue
		var bounds := Rect2(obstacle.position - obstacle.size() * 0.5, obstacle.size()).grow(radius)
		if _segment_hits_rect(from, to, bounds.grow(-0.0001)): return false
		# Preserve Rect2's half-open boundary rule on exact edge tangencies.
		# The ordinary case needs no per-point entity checks.
		if _segment_hits_rect(from, to, bounds):
			for i in range(samples + 1):
				if bounds.has_point(from.lerp(to, float(i) / samples)): return false
	for obstacle in nearby_resources(center, extent + radius + max_dynamic_radius):
		var limit := radius + obstacle.radius
		var closest := Geometry2D.get_closest_point_to_segment(obstacle.position, from, to)
		var distance := closest.distance_squared_to(obstacle.position)
		if distance >= limit * limit: continue
		var current := unit.position.distance_squared_to(obstacle.position) if unit != null else INF
		if not allow_resource_escape or current >= limit * limit or distance + 0.001 < current: return false
	var naval: bool = unit != null and unit.stats.get("tags", []).has("naval")
	return _terrain_segment_clear(from, to, radius, naval, boarding)

func _terrain_segment_clear(from: Vector2, to: Vector2, radius: float, naval: bool, boarding := false) -> bool:
	var bounds := Rect2(Vector2.ONE * radius, world_map.world_size - Vector2.ONE * radius * 2)
	if from != from.clamp(bounds.position, bounds.end) or to != to.clamp(bounds.position, bounds.end): return false
	var region := Rect2(from, Vector2.ZERO).expand(to).grow(radius)
	var first := world_map.cell_at(region.position)
	var last := world_map.cell_at(region.end)
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			var terrain: int = world_map.cells[y * world_map.grid_size.x + x]
			if _terrain_passable(terrain, naval, boarding): continue
			var tile := Rect2(Vector2(x, y) * RtsWorldMap.CELL_SIZE, Vector2.ONE * RtsWorldMap.CELL_SIZE)
			# A rounded rectangle is two strips plus four corner circles.
			if _segment_hits_rect(from, to, Rect2(tile.position - Vector2(radius, 0), tile.size + Vector2(radius * 2, 0)).grow(-0.00001)): return false
			if _segment_hits_rect(from, to, Rect2(tile.position - Vector2(0, radius), tile.size + Vector2(0, radius * 2)).grow(-0.00001)): return false
			for corner in [tile.position, tile.end, Vector2(tile.position.x, tile.end.y), Vector2(tile.end.x, tile.position.y)]:
				if corner.distance_squared_to(Geometry2D.get_closest_point_to_segment(corner, from, to)) < radius * radius - 0.0001: return false
	return true

func boarding_clear(from: Vector2, carrier_position: Vector2, unit: RtsUnit) -> bool:
	# Boarding crosses a shoreline, but never walls, mountains or resources.
	return _static_segment_clear(from, carrier_position, unit.radius(), unit, false, true)

func _segment_hits_rect(from: Vector2, to: Vector2, bounds: Rect2) -> bool:
	var delta := to - from
	var low := 0.0
	var high := 1.0
	for axis in 2:
		if is_zero_approx(delta[axis]):
			if from[axis] < bounds.position[axis] or from[axis] > bounds.end[axis]: return false
			continue
		var first := (bounds.position[axis] - from[axis]) / delta[axis]
		var last := (bounds.end[axis] - from[axis]) / delta[axis]
		low = maxf(low, minf(first, last))
		high = minf(high, maxf(first, last))
		if low > high: return false
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
	var boarding := unit.order == "board_transport"
	if from.distance_to(target) <= reach + 0.5 and (not boarding or boarding_clear(from, target, unit)): return PackedVector2Array([from])
	var direction := (from - target).normalized()
	if direction.is_zero_approx(): direction = Vector2.RIGHT
	var approaches: Array[Vector2] = []
	for offset in [0.0, PI / 4.0, -PI / 4.0, PI / 2.0, -PI / 2.0, 3.0 * PI / 4.0, -3.0 * PI / 4.0, PI]:
		approaches.append(target + direction.rotated(offset) * maxf(0.0, reach - 0.25))
	# A square footprint can leave only tiny usable arcs in the interaction
	# disk. Relative angles alone miss all four sides when approaching obliquely.
	# Include the boundary tolerance used by _move_toward so contact repairs
	# do not request points a quarter pixel INSIDE the building's collision box.
	var limit := reach + 0.25
	for i in 32:
		approaches.append(target + Vector2.from_angle(TAU * i / 32.0) * limit)
	for obstacle in nearby_buildings(target, reach + unit.radius()):
		var bounds := Rect2(obstacle.position - obstacle.size() * 0.5, obstacle.size()).grow(unit.radius() + 0.05)
		for x in [bounds.position.x, bounds.end.x]:
			var dx: float = absf(x - target.x)
			if dx > limit: continue
			var span := sqrt(maxf(0.0, limit * limit - dx * dx))
			var low := maxf(bounds.position.y, target.y - span)
			var high := minf(bounds.end.y, target.y + span)
			if low <= high: approaches.append(Vector2(x, clampf(from.y, low, high)))
		for y in [bounds.position.y, bounds.end.y]:
			var dy: float = absf(y - target.y)
			if dy > limit: continue
			var span := sqrt(maxf(0.0, limit * limit - dy * dy))
			var low := maxf(bounds.position.x, target.x - span)
			var high := minf(bounds.end.x, target.x + span)
			if low <= high: approaches.append(Vector2(clampf(from.x, low, high), y))
	approaches.sort_custom(func(a: Vector2, b: Vector2) -> bool: return from.distance_squared_to(a) < from.distance_squared_to(b))
	var candidates: Array[Vector2] = []
	# Consider all clear approaches before paying for a detour. A blocked
	# nearest arc must not trigger a full fine-grid build when another side
	# of the same building is directly accessible.
	for approach in approaches:
		if boarding and not boarding_clear(approach, target, unit): continue
		if not can_occupy(approach, unit.radius(), unit): continue
		if _static_segment_clear(from, approach, unit.radius(), unit):
			return PackedVector2Array([from, approach])
		candidates.append(approach)
	# Include the disk interior for corridors that miss its circumference.
	var grid := _grid_for(unit)
	var first := world_map.cell_at(target - Vector2.ONE * reach)
	var last := world_map.cell_at(target + Vector2.ONE * reach)
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			var cell := Vector2i(x, y)
			var point := world_map.cell_center(cell)
			if boarding and not boarding_clear(point, target, unit): continue
			if not grid.is_point_solid(cell) and point.distance_to(target) <= reach and can_occupy(point, unit.radius(), unit): candidates.append(point)
	candidates.sort_custom(func(a: Vector2, b: Vector2) -> bool: return from.distance_squared_to(a) < from.distance_squared_to(b))
	if not can_occupy(from, unit.radius(), unit, false): return PackedVector2Array()
	# Candidates already passed occupancy checks. After every coarse route
	# fails, refine directly without repeating those same coarse searches.
	for refine in [false, true]:
		var best := PackedVector2Array()
		var best_length := INF
		for point in candidates:
			if from.distance_to(point) >= best_length: break
			var candidate := _fine_static_path(from, point, unit) if refine else _path_between(from, point, unit, true, false)
			if candidate.is_empty(): continue
			var length := from.distance_to(candidate[0]) + _path_length(candidate)
			if length < best_length:
				best = candidate
				best_length = length
		if not best.is_empty(): return best
	return PackedVector2Array()

func nearest_walkable_point(point: Vector2, radius := CLEARANCE, self_unit: RtsUnit = null, require_path := false, include_units := true) -> Vector2:
	if not profiling_enabled: return _nearest_walkable_point(point, radius, self_unit, require_path, include_units)
	var started := Time.get_ticks_usec()
	var result := _nearest_walkable_point(point, radius, self_unit, require_path, include_units)
	_record_profile(&"nearest_walkable_point", started)
	return result

func _nearest_walkable_point(point: Vector2, radius: float, self_unit: RtsUnit, require_path: bool, include_units: bool) -> Vector2:
	_ensure_current()
	# Directly reachable points need no grid, even when a path is required.
	var check_path := require_path and self_unit != null
	var clamped := point.clamp(Vector2.ONE * radius, world_map.world_size - Vector2.ONE * radius)
	if _valid_destination(clamped, radius, self_unit, check_path, include_units): return clamped
	var approach_angle := (self_unit.position - clamped).angle() if self_unit != null else 0.0
	for ring in range(1, 17):
		for i in 16:
			# Equal-distance alternatives should face the approaching unit;
			# an east-first scan can send a west-side unit around the obstacle.
			var angular_step := ceili(i / 2.0) * (1 if i % 2 == 1 else -1)
			var candidate := clamped + Vector2.from_angle(approach_angle + TAU * angular_step / 16.0) * ring * maxf(radius, 12.0)
			if _valid_destination(candidate, radius, self_unit, check_path, include_units): return candidate
	var grid := _grid_for(self_unit)
	if check_path:
		var candidates: Array[Vector2] = []
		for y in world_map.grid_size.y:
			for x in world_map.grid_size.x:
				var cell := Vector2i(x, y)
				if grid.is_point_solid(cell): continue
				candidates.append(world_map.cell_center(cell))
		# The row-major scan used to search paths to successive record minima
		# across the whole map. Nearest-first gives the same result with early
		# exit; preserve row/column ordering when distances tie.
		candidates.sort_custom(func(a: Vector2, b: Vector2) -> bool:
			var da := a.distance_squared_to(clamped)
			var db := b.distance_squared_to(clamped)
			if da != db: return da < db
			return a.y < b.y if a.y != b.y else a.x < b.x
		)
		for candidate in candidates:
			if not can_occupy(candidate, radius, self_unit, include_units, false): continue
			if _path_between(self_unit.position, candidate, self_unit, true).is_empty(): continue
			return candidate
	return world_map.cell_center(nearest_open_cell(clamped, grid))

# Final destinations cannot use movement-only overlap escape allowances.
func _valid_destination(point: Vector2, radius: float, self_unit: RtsUnit, require_path: bool, include_units: bool) -> bool:
	if not can_occupy(point, radius, self_unit, include_units, false): return false
	return not require_path or not _path_between(self_unit.position, point, self_unit, true).is_empty()

func _segment_clear(from: Vector2, to: Vector2, radius: float, self_unit: RtsUnit) -> bool:
	if not _static_segment_clear(from, to, radius, self_unit): return false
	var center := (from + to) * 0.5
	for other in nearby_units(center, from.distance_to(to) * 0.5 + radius + max_dynamic_radius):
		if other == self_unit: continue
		var limit := radius + other.radius()
		var closest := Geometry2D.get_closest_point_to_segment(other.position, from, to)
		var distance := closest.distance_squared_to(other.position)
		if distance >= limit * limit: continue
		# An existing overlap may only shrink along the entire displacement.
		var current := from.distance_squared_to(other.position)
		if current >= limit * limit or distance + 0.001 < current or to.distance_squared_to(other.position) <= current: return false
	return true

func has_fixed_unit_blocker(unit: RtsUnit, target: Vector2) -> bool:
	for other in nearby_units(unit.position, 160.0):
		if other == unit: continue
		# Ordinary moving allies can clear the lane themselves. Recover around
		# idle or stalled allies, without rebuilding local grids for traffic
		# that is still making progress through a chokepoint.
		if not game.is_enemy(unit.owner_id, other.owner_id) and other.stance != "hold" and other.order in ["move", "attack_move"]:
			if other.route_failures < 2 and other.route_stalled_time < RtsUnit.ROUTE_STALL_SECONDS and (other.movement_group == null or other.group_stuck_time < 0.9): continue
		var closest := Geometry2D.get_closest_point_to_segment(other.position, unit.position, target)
		if closest.distance_to(other.position) < unit.radius() + other.radius() + 4.0: return true
	return false

func path_around_units(unit: RtsUnit, target: Vector2) -> PackedVector2Array:
	if not profiling_enabled: return _path_around_units(unit, target)
	var started := Time.get_ticks_usec()
	var result := _path_around_units(unit, target)
	_record_profile(&"path_around_units", started)
	return result

func _path_around_units(unit: RtsUnit, target: Vector2) -> PackedVector2Array:
	# Recovery only: a local fine grid can route between parked formation
	# members that the 50-pixel strategic grid cannot represent. A wide corral
	# may require backtracking beyond the first window before making progress.
	for resolution in [Vector2i(8, 24), Vector2i(2, 48), Vector2i(8, 48), Vector2i(8, 96), Vector2i(2, 96)]:
		# Let short-lived work-site traffic clear before escalating. Persistent
		# blockers still get the fine/wider search under the unit's retry backoff.
		if resolution != Vector2i(8, 24) and unit.route_failures < 3: break
		var path := _local_unit_path(unit, target, resolution.x, resolution.y)
		if not path.is_empty(): return path
	return PackedVector2Array()

func _local_unit_grid(unit: RtsUnit, step: float, half: int) -> AStarGrid2D:
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(0, 0, half * 2 + 1, half * 2 + 1)
	grid.cell_size = Vector2.ONE * step
	grid.offset = unit.position - Vector2.ONE * half * step
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	_rasterize_static_grid(unit, grid, true)
	# Mark each nearby unit's footprint once instead of querying every
	# neighborhood for each of the up to 37,249 recovery-grid cells.
	_ensure_spatial_index()
	var extent := float(half) * step
	for other in nearby_units(unit.position, sqrt(2.0) * extent + unit.radius() + max_dynamic_radius):
		if other == unit: continue
		_rasterize_unit_circle(grid, other.position, unit.radius() + other.radius(), unit.position.distance_squared_to(other.position))
	return grid

func _rasterize_unit_circle(grid: AStarGrid2D, center: Vector2, radius: float, current_distance_squared: float) -> void:
	# A circle intersects each grid row in one span. Fill that span natively
	# instead of doing a GDScript distance test and setter for every cell.
	# Retain the exact strict contact / inclusive overlap-escape predicates at
	# both endpoints; sqrt/rounding alone can change tangent-cell occupancy.
	var radius_squared := radius * radius
	var limit := minf(radius_squared, current_distance_squared)
	var region := _fine_region(grid, Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0))
	for y in range(region.position.y, region.end.y):
		var dy := grid.get_point_position(Vector2i(0, y)).y - center.y
		var span_squared := limit - dy * dy
		# Keep the nearest column even for a marginally negative span: Vector2
		# distance rounding can still include an overlap-escape tangent.
		var span := sqrt(maxf(0.0, span_squared))
		var first := maxi(region.position.x, floori((center.x - span - grid.offset.x) / grid.cell_size.x))
		var last := mini(region.end.x - 1, ceili((center.x + span - grid.offset.x) / grid.cell_size.x))
		while first <= last:
			var distance := grid.get_point_position(Vector2i(first, y)).distance_squared_to(center)
			if distance < radius_squared and distance <= current_distance_squared: break
			first += 1
		while last >= first:
			var distance := grid.get_point_position(Vector2i(last, y)).distance_squared_to(center)
			if distance < radius_squared and distance <= current_distance_squared: break
			last -= 1
		if first <= last: grid.fill_solid_region(Rect2i(first, y, last - first + 1, 1))

func _local_reachable_cells(grid: AStarGrid2D, start: Vector2i) -> Array[Vector2i]:
	# Recovery needs only the mover's component. Labeling every disconnected
	# island scanned up to 37,249 cells even when the mover was boxed into one.
	# Four-neighbor connectivity is equivalent for no-corner-cutting A*.
	var size := grid.region.size
	var visited := PackedByteArray()
	visited.resize(size.x * size.y)
	var cells: Array[Vector2i] = [start]
	visited[start.y * size.x + start.x] = 1
	var head := 0
	while head < cells.size():
		var cell := cells[head]
		head += 1
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + offset
			if not grid.region.has_point(next): continue
			var index := next.y * size.x + next.x
			if visited[index]: continue
			visited[index] = 1
			if not grid.is_point_solid(next): cells.append(next)
	return cells

func _local_exit_candidates(grid: AStarGrid2D, origin: Vector2, target: Vector2) -> Dictionary:
	var result := {}
	var size := grid.region.size
	var local_target := Vector2i(((target - grid.offset) / grid.cell_size).round()).clamp(Vector2i.ZERO, size - Vector2i.ONE)
	var limit := origin.distance_to(target) - 4.0
	for y in range(maxi(0, local_target.y - 3), mini(size.y, local_target.y + 4)):
		for x in range(maxi(0, local_target.x - 3), mini(size.x, local_target.x + 4)):
			var cell := Vector2i(x, y)
			if cell.distance_squared_to(local_target) <= 9: _add_local_exit(result, grid, cell, target, limit)
	for x in size.x:
		_add_local_exit(result, grid, Vector2i(x, 0), target, limit)
		_add_local_exit(result, grid, Vector2i(x, size.y - 1), target, limit)
	for y in range(1, size.y - 1):
		_add_local_exit(result, grid, Vector2i(0, y), target, limit)
		_add_local_exit(result, grid, Vector2i(size.x - 1, y), target, limit)
	return result

func _add_local_exit(exits: Dictionary, grid: AStarGrid2D, cell: Vector2i, target: Vector2, limit: float) -> void:
	if not grid.is_point_solid(cell) and grid.get_point_position(cell).distance_to(target) < limit:
		exits[cell] = true

func _local_unit_path(unit: RtsUnit, target: Vector2, step: float, half: int) -> PackedVector2Array:
	var grid := _local_unit_grid(unit, step, half)
	var start := Vector2i(half, half)
	grid.set_point_solid(start, false)
	# Only the perimeter and the 3-cell disk around the target can be exits.
	# Reject occupied/non-improving exits BEFORE flooding tens of thousands of
	# cells. At contact with a parked unit there is often no useful exit at all.
	var exits := _local_exit_candidates(grid, unit.position, target)
	if exits.is_empty(): return PackedVector2Array()
	var candidates: Array[Vector2i] = []
	candidates.assign(exits.keys())
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return grid.get_point_position(a).distance_squared_to(target) < grid.get_point_position(b).distance_squared_to(target))
	var connectivity_checked := false
	var reachable := {}
	for cell in candidates:
		if connectivity_checked and not reachable.has(cell): continue
		# Native A* usually reaches the nearest usable exit immediately. Avoid
		# a GDScript flood of the entire open region before that cheap search.
		# On failure, filter once so disconnected exits cannot multiply A* work.
		var raw := _point_path(grid, start, cell)
		if raw.size() < 2:
			if not connectivity_checked:
				for point in _local_reachable_cells(grid, start): reachable[point] = true
				connectivity_checked = true
			continue
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

func request_passage(unit: RtsUnit, target: Vector2) -> bool:
	# Recovery requests consider the whole blocked segment. A tiny sidestep
	# can select alternating sides forever in a packed formation at a wall.
	for other in nearby_units(unit.position, 160.0):
		if other == unit or other.order != "idle" or other.stance == "hold" or game.is_enemy(unit.owner_id, other.owner_id): continue
		var limit := unit.radius() + other.radius() + 4.0
		if other.position.distance_to(Geometry2D.get_closest_point_to_segment(other.position, unit.position, target)) >= limit: continue
		var choices: Array[Vector2] = []
		for ring in range(1, 7):
			for i in 16:
				var point := other.position + Vector2.from_angle(TAU * i / 16.0) * ring * other.radius()
				if point.distance_to(Geometry2D.get_closest_point_to_segment(point, unit.position, target)) < limit: continue
				if not can_occupy(point, other.radius(), other, true, false): continue
				if _static_segment_clear(other.position, point, other.radius(), other): choices.append(point)
			if not choices.is_empty(): break
		if choices.is_empty(): continue
		choices.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(unit.position) > b.distance_squared_to(unit.position))
		for choice in choices:
			var step := other.position.move_toward(choice, other.radius() * 0.6)
			if not _motion_clear(other, step):
				if not _yield_allies(other, step, [unit.get_instance_id()]) or not _motion_clear(other, step): continue
			var previous := other.position
			other.position = step
			unit_moved(other, previous)
			other._update_facing(previous)
			other._refresh_slope_visual(previous)
			return true
	return false

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
	if not profiling_enabled: return _move_step(unit, desired_position)
	var started := Time.get_ticks_usec()
	var result := _move_step(unit, desired_position)
	_record_profile(&"move_step", started)
	return result

func _move_step(unit: RtsUnit, desired_position: Vector2) -> Vector2:
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
	return _segment_clear(unit.position, destination, unit.radius(), unit)

func can_occupy(point: Vector2, radius: float, self_unit: RtsUnit, include_units := true, allow_overlap_escape := true) -> bool:
	if not profiling_enabled: return _can_occupy(point, radius, self_unit, include_units, Vector2.INF, allow_overlap_escape)
	var started := Time.get_ticks_usec()
	var result := _can_occupy(point, radius, self_unit, include_units, Vector2.INF, allow_overlap_escape)
	_record_profile(&"can_occupy", started)
	return result

func _can_occupy(point: Vector2, radius: float, self_unit: RtsUnit, include_units: bool, escape_from := Vector2.INF, allow_overlap_escape := true) -> bool:
	var naval: bool = self_unit != null and self_unit.stats.get("tags", []).has("naval")
	if not _terrain_can_occupy(point, radius, naval): return false
	_ensure_spatial_index()
	for building in buildings_by_cell.get(_spatial_cell(point), []):
		if not is_instance_valid(building) or building.is_queued_for_deletion(): continue
		if self_unit != null and _gate_passable(building, self_unit.owner_id): continue
		var bounds := Rect2(building.position - building.size() * 0.5, building.size()).grow(radius)
		if bounds.has_point(point):
			# Only the dedicated overlap recovery may leave an existing overlap.
			# Ordinary collision checks and cached pathfinding grids remain strict.
			if escape_from == Vector2.INF or not bounds.has_point(escape_from): return false
			if _rect_depth(bounds, point) > _rect_depth(bounds, escape_from) + 0.001: return false
	var reach := Vector2.ONE * (radius + max_dynamic_radius)
	var first := _spatial_cell(point - reach)
	var last := _spatial_cell(point + reach)
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			var cell := Vector2i(x, y)
			for resource in resources_by_cell.get(cell, []):
				if not is_instance_valid(resource) or resource.is_queued_for_deletion(): continue
				var distance_limit: float = radius + resource.radius
				var distance_to_resource := point.distance_squared_to(resource.position)
				if distance_to_resource < distance_limit * distance_limit:
					if not allow_overlap_escape: return false
					# A moving boar can overlap a villager before the next path search.
					# Let an already-overlapping unit move outward from that resource.
					var current_distance := self_unit.position.distance_squared_to(resource.position) if self_unit != null else INF
					if current_distance >= distance_limit * distance_limit or distance_to_resource + 0.001 < current_distance: return false
			if not include_units: continue
			for other in units_by_cell.get(cell, []):
				if not is_instance_valid(other) or other.is_queued_for_deletion() or other == self_unit: continue
				var personal_space: float = radius + other.radius()
				if point.distance_squared_to(other.position) < personal_space * personal_space:
					if not allow_overlap_escape or self_unit == null or point.distance_squared_to(other.position) <= self_unit.position.distance_squared_to(other.position): return false
	return true

func _terrain_can_occupy(point: Vector2, radius: float, naval: bool) -> bool:
	if point.x < radius or point.y < radius or point.x > world_map.world_size.x - radius or point.y > world_map.world_size.y - radius: return false
	var cell_size := float(RtsWorldMap.CELL_SIZE)
	var first_x := floori((point.x - radius) / cell_size)
	var last_x := mini(world_map.grid_size.x - 1, floori((point.x + radius) / cell_size))
	var first_y := floori((point.y - radius) / cell_size)
	var last_y := mini(world_map.grid_size.y - 1, floori((point.y + radius) / cell_size))
	for cy in range(first_y, last_y + 1):
		for cx in range(first_x, last_x + 1):
			var terrain: int = world_map.cells[cy * world_map.grid_size.x + cx]
			if _terrain_passable(terrain, naval): continue
			var closest := Vector2(clampf(point.x, cx * cell_size, (cx + 1) * cell_size), clampf(point.y, cy * cell_size, (cy + 1) * cell_size))
			if point.distance_squared_to(closest) < radius * radius: return false
	return true

func _rect_depth(bounds: Rect2, point: Vector2) -> float:
	return minf(minf(point.x - bounds.position.x, bounds.end.x - point.x), minf(point.y - bounds.position.y, bounds.end.y - point.y))

func _building_escape_clear(unit: RtsUnit, destination: Vector2) -> bool:
	var samples := maxi(1, ceili(unit.position.distance_to(destination) / maxf(1.0, unit.radius() * 0.3)))
	var previous := unit.position
	for i in range(1, samples + 1):
		var point := unit.position.lerp(destination, float(i) / samples)
		if not _can_occupy(point, unit.radius(), unit, true, previous): return false
		previous = point
	return true

func recover_building_overlap(unit: RtsUnit, delta: float) -> bool:
	if not profiling_enabled: return _recover_building_overlap(unit, delta)
	var started := Time.get_ticks_usec()
	var result := _recover_building_overlap(unit, delta)
	_record_profile(&"recover_building_overlap", started)
	return result

func _recover_building_overlap(unit: RtsUnit, delta: float) -> bool:
	# Foundations can be placed over builders and bystanders. Walk them out
	# before doing work, preserving their command queue and normal movement speed.
	_ensure_spatial_index()
	var candidates: Array[Vector2] = []
	var overlapping := false
	for building in buildings_by_cell.get(_spatial_cell(unit.position), []):
		if not is_instance_valid(building) or building.is_queued_for_deletion(): continue
		if _gate_passable(building, unit.owner_id): continue
		var bounds := Rect2(building.position - building.size() * 0.5, building.size()).grow(unit.radius())
		if not bounds.has_point(unit.position): continue
		overlapping = true
		bounds = bounds.grow(1.0)
		candidates.append(Vector2(bounds.position.x, unit.position.y))
		candidates.append(Vector2(bounds.end.x, unit.position.y))
		candidates.append(Vector2(unit.position.x, bounds.position.y))
		candidates.append(Vector2(unit.position.x, bounds.end.y))
		# Sample each edge too: a neighboring building or unit may block the
		# closest perpendicular exit while leaving a diagonal exit available.
		var segments := maxi(2, ceili(maxf(bounds.size.x, bounds.size.y) / unit.radius()))
		for i in range(segments + 1):
			var fraction := float(i) / segments
			candidates.append(Vector2(lerpf(bounds.position.x, bounds.end.x, fraction), bounds.position.y))
			candidates.append(Vector2(lerpf(bounds.position.x, bounds.end.x, fraction), bounds.end.y))
			candidates.append(Vector2(bounds.position.x, lerpf(bounds.position.y, bounds.end.y, fraction)))
			candidates.append(Vector2(bounds.end.x, lerpf(bounds.position.y, bounds.end.y, fraction)))
	if not overlapping: return false
	candidates.sort_custom(func(a: Vector2, b: Vector2) -> bool: return unit.position.distance_squared_to(a) < unit.position.distance_squared_to(b))
	for candidate in candidates:
		if not can_occupy(candidate, unit.radius(), unit) or not _building_escape_clear(unit, candidate): continue
		var previous := unit.position
		unit.position = unit.position.move_toward(candidate, minf(unit.effective_speed() * delta, unit.radius() * 4.8))
		unit_moved(unit, previous)
		unit._reset_route()
		unit._update_facing(previous)
		unit._refresh_slope_visual(previous)
		break
	return true

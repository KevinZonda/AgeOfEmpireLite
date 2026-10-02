class_name RtsNavigation
extends RefCounted

# Terrain is owned by RtsWorldMap. This layer adds changing entity footprints.
const CLEARANCE := 16.0
const SPATIAL_CELL_SIZE := preload("res://scripts/world/navigation_spatial_index.gd").CELL_SIZE
const SMOOTH_LOOKAHEAD := 8
const MAX_FINE_GRIDS := 4
const MAX_CORNER_ATTACHMENTS := 64
const MAX_RANGE_CORNER_ATTEMPTS := 4
const MAX_RANGE_SEGMENTS := 8192
const RecoveryKernel = preload("res://scripts/world/navigation_recovery.gd")
const SearchKernel = preload("res://scripts/world/navigation_search_kernel.gd")
const GeometryCache = preload("res://scripts/world/navigation_cache.gd")
const SpatialIndex = preload("res://scripts/world/navigation_spatial_index.gd")
var geometry_cache := GeometryCache.new()
var spatial_index := SpatialIndex.new()
const BackgroundJobs = preload("res://scripts/world/navigation_jobs.gd")
var background_jobs = BackgroundJobs.new()
var background_recovery_enabled := false
const RouteJobs = preload("res://scripts/world/navigation_route_jobs.gd")
var route_jobs := RouteJobs.new()
# Immediate queries are the default; live matches may opt into admission.
var route_budget_enabled := false
const GridBuilds = preload("res://scripts/world/navigation_grid_build.gd")
var grid_builds = GridBuilds.new()
# Geometry revisions keep stale world fine grids answering while workers
# rasterize replacements and their components. Disable to restore synchronous
# rebuild-on-invalidation for debugging.
var async_geometry_enabled := OS.get_environment("RTS_ASYNC_GEOMETRY") != "0"

var simulation_frame := -1

func frame_id() -> int:
	# Separate clock namespaces so a renderer frame never aliases a manual tick.
	return -simulation_frame - 2 if simulation_frame >= 0 else Engine.get_process_frames()

var game: Node2D
# Query the live owner directly; fixture worlds provide the same collections.
var _entities: Object
var world_map: RtsWorldMap
# Generic queries retain their fixed-clearance grid, built only when requested.
var pathfinder: AStarGrid2D:
	get:
		_ensure_current()
		if _default_grid == null: _default_grid = _make_default_grid()
		return _default_grid
var _default_grid: AStarGrid2D:
	get: return geometry_cache._default_grid
	set(value): geometry_cache._default_grid = value
# Shared containers retain identity when their owner clears/rebuilds them.
# Direct aliases avoid a property call for every cell in hot collision loops.
var clearance_grids: Dictionary = geometry_cache.clearance_grids
var fine_grids: Dictionary = geometry_cache.fine_grids
var local_fine_grids: Array[Dictionary] = geometry_cache.local_fine_grids
var grid_components: Dictionary = geometry_cache.grid_components
var grid_component_sizes: Dictionary = geometry_cache.grid_component_sizes
var corner_graphs: Dictionary = geometry_cache.corner_graphs
# Valid only within a single synchronous range query. It avoids repeating
# identical geometry sweeps while comparing candidate approaches, and is
# discarded before returning so moving deer never reuse stale segment results.
var range_query_unit: RtsUnit
var range_query_radius := 0.0
var range_query_segments: Array[Dictionary] = []
var destination_query_unit: RtsUnit
var destination_origin_cells: Dictionary = {}
var destination_origin_connections: Dictionary = {}
var destination_origin_components: Dictionary = {}
# Valid only within a single corner fallback search: strict edge sweeps share
# per-anchor obstacle candidates instead of repeating the broad phase per edge.
var corner_sweep_unit: RtsUnit
var corner_sweep_anchors: Dictionary = {}
var corner_sweep_points := PackedVector2Array()
var corner_sweep_from := Vector2.ZERO
var corner_sweep_to := Vector2.ZERO
var obstacle_signature: int:
	get: return geometry_cache.obstacle_signature
	set(value): geometry_cache.obstacle_signature = value
var obstacle_revision: int:
	get: return geometry_cache.obstacle_revision
	set(value): geometry_cache.obstacle_revision = value
# Resource motion changes collision geometry, but must not wake every failed
# route in the match. Structural edits still interrupt retry backoff.
var retry_obstacle_revision: int:
	get: return geometry_cache.retry_obstacle_revision
	set(value): geometry_cache.retry_obstacle_revision = value
var retry_obstacle_signature: int:
	get: return geometry_cache.retry_obstacle_signature
	set(value): geometry_cache.retry_obstacle_signature = value
var obstacle_check_frame: int:
	get: return geometry_cache.obstacle_check_frame
	set(value): geometry_cache.obstacle_check_frame = value
var spatial_frame: int:
	get: return spatial_index.spatial_frame
	set(value): spatial_index.spatial_frame = value
var indexed_unit_count: int:
	get: return spatial_index.indexed_unit_count
	set(value): spatial_index.indexed_unit_count = value
var indexed_resource_count: int:
	get: return spatial_index.indexed_resource_count
	set(value): spatial_index.indexed_resource_count = value
var indexed_building_count: int:
	get: return spatial_index.indexed_building_count
	set(value): spatial_index.indexed_building_count = value
var max_dynamic_radius: float:
	get: return spatial_index.max_dynamic_radius
	set(value): spatial_index.max_dynamic_radius = value
var units_by_cell: Dictionary = spatial_index.units_by_cell
var resources_by_cell: Dictionary = spatial_index.resources_by_cell
var buildings_by_cell: Dictionary = spatial_index.buildings_by_cell
var profiling_enabled := OS.get_environment("RTS_NAV_PROFILE") == "1"
var profile: Dictionary = {}

func tick_jobs(allow_dispatch := true, simulation_frame := -1) -> void:
	if route_budget_enabled and allow_dispatch: route_jobs.tick(self, simulation_frame)
	if background_recovery_enabled: background_jobs.tick(self, allow_dispatch)
	# Geometry rebuilds are independent of the crowd-recovery opt-out: their
	# results must be reaped in every mode.
	if not grid_builds.active.is_empty(): grid_builds.poll(self)

func shutdown_jobs() -> void:
	route_jobs.reset()
	background_jobs.shutdown()
	grid_builds.shutdown()

func request_route(unit: RtsUnit, target: Vector2, reach: float, use_range: bool) -> bool:
	return route_jobs.request(unit, target, reach, use_range)

func take_route(unit: RtsUnit, target: Vector2, reach: float, use_range: bool) -> Dictionary:
	return route_jobs.take(unit, target, reach, use_range, self)

func cancel_route_request(unit: RtsUnit) -> void:
	route_jobs.cancel(unit)

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
	var session = game.get("session")
	_entities = session.entities if session != null else game

func refresh(wake_failed_routes := true) -> void:
	if wake_failed_routes: retry_obstacle_signature = -1
	var started := Time.get_ticks_usec() if profiling_enabled else 0
	_refresh_grids()
	if profiling_enabled: _record_profile(&"grid_refresh", started)

func _refresh_grids() -> void:
	var stale_keys: Array = fine_grids.keys() if async_geometry_enabled else []
	geometry_cache.rebuild(_entities, async_geometry_enabled)
	geometry_cache.obstacle_check_frame = frame_id()
	invalidate_spatial_index()
	# Rebuild surviving world fine grids off-thread. Queries keep using the
	# stale grids (revalidating edges against live geometry) until each swap.
	for key in stale_keys:
		grid_builds.request(self, key)

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
	for building in _entities.buildings:
		if not is_instance_valid(building) or building.is_queued_for_deletion(): continue
		if not _gate_passable(building, 0):
			_mark_rect(Rect2(building.position - building.size() * 0.5, building.size()).grow(CLEARANCE), grid)
	for resource in _entities.resources:
		if not is_instance_valid(resource) or resource.is_queued_for_deletion(): continue
		_mark_circle(resource.position, resource.radius + CLEARANCE, grid)
	# Preserve the generic query's player-zero gate corridor. Unit queries use
	# their actual body size and owner through _grid_for instead.
	for building in _entities.buildings:
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
	return geometry_cache.signature(_entities, ignore_resource_positions)

func _is_mobile_wildlife(resource: RtsResource) -> bool:
	return GeometryCache.is_mobile_wildlife(resource)

func _ensure_current() -> void:
	var frame := frame_id()
	if geometry_cache.obstacle_check_frame == frame: return
	geometry_cache.obstacle_check_frame = frame
	# Explicit invalidation marks the signature invalid. The only geometry
	# inputs that can change without invalidation are construction completion
	# and wildlife death; the cache polls just those watched entities, keeping
	# the per-frame guard O(watched) with no per-entity hashing.
	if geometry_cache.obstacle_signature == -1 or geometry_cache.silent_geometry_changed(): refresh(false)

func invalidate_spatial_index() -> void:
	spatial_index.invalidate()

func invalidate_obstacles(wake_failed_routes := true) -> void:
	geometry_cache.invalidate(wake_failed_routes)
	invalidate_spatial_index()

func _spatial_cell(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / SPATIAL_CELL_SIZE), floori(point.y / SPATIAL_CELL_SIZE))

func _ensure_spatial_index() -> void:
	# Within one frame the index is reused as-is. A frame boundary pays one
	# cheap reconcile pass; only invalidation or a count mismatch rebuilds.
	# Keep the hot-path guard inline to avoid a call per collision query.
	var frame := frame_id()
	if spatial_index.spatial_frame == frame and spatial_index.indexed_unit_count == _entities.units.size() and spatial_index.indexed_resource_count == _entities.resources.size() and spatial_index.indexed_building_count == _entities.buildings.size(): return
	spatial_index.ensure_current(_entities, frame)

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
	spatial_index.unit_moved(unit, previous_position, frame_id())

func resource_moved(resource: RtsResource, previous_position: Vector2) -> void:
	if previous_position == resource.position: return
	if _is_mobile_wildlife(resource):
		# Wildlife move constantly; rebuilding world geometry for every step
		# stalled frames whenever a stuck order retried. Collision queries read
		# live positions through the spatial index, so a bucket move suffices.
		spatial_index.resource_moved(resource, previous_position, frame_id())
		geometry_cache.wildlife_moved(previous_position, resource.position, resource.radius)
		return
	invalidate_obstacles(false)

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
	return RecoveryKernel._terrain_passable(terrain, naval, boarding)

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
	_rasterize_static_grid(unit, grid)
	clearance_grids[key] = grid
	return grid

func _connected_cell(point: Vector2, grid: AStarGrid2D, radius: float, unit: RtsUnit) -> Vector2i:
	var cache_origin := unit != null and unit == destination_query_unit and point == unit.position
	var key := grid.get_instance_id()
	if cache_origin and destination_origin_connections.has(key): return destination_origin_connections[key]
	var result := _find_connected_cell(point, grid, radius, unit)
	if cache_origin: destination_origin_connections[key] = result
	return result

func _find_connected_cell(point: Vector2, grid: AStarGrid2D, radius: float, unit: RtsUnit) -> Vector2i:
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
	# A destination query changes only the endpoint. Reuse the same source
	# attachments, including an empty set, across its candidate searches.
	var cache_origin := unit != null and unit == destination_query_unit and point == unit.position
	var key := [grid.get_instance_id(), origin, extent, radius]
	if cache_origin and destination_origin_cells.has(key): return destination_origin_cells[key]
	var result: Array[Vector2i] = []
	for y in range(maxi(0, origin.y - extent), mini(grid.region.size.y, origin.y + extent + 1)):
		for x in range(maxi(0, origin.x - extent), mini(grid.region.size.x, origin.x + extent + 1)):
			var cell := Vector2i(x, y)
			if not grid.is_point_solid(cell) and _static_segment_clear(point, grid.get_point_position(cell), radius, unit): result.append(cell)
	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return point.distance_squared_to(grid.get_point_position(a)) < point.distance_squared_to(grid.get_point_position(b)))
	if cache_origin: destination_origin_cells[key] = result
	return result

func _safe_point_path(grid: AStarGrid2D, start: Vector2i, end: Vector2i, unit: RtsUnit) -> PackedVector2Array:
	if start.x < 0 or end.x < 0: return PackedVector2Array()
	# A short reachable query must not first flood the entire fine world grid.
	# Reuse connectivity if a previous failed query needed it; otherwise try
	# native A* first and build the rejection cache only on actual failure.
	var key := grid.get_instance_id()
	if grid_components.has(key):
		var components: PackedInt32Array = grid_components[key]
		if components[start.y * grid.region.size.x + start.x] != components[end.y * grid.region.size.x + end.x]: return PackedVector2Array()
	var radius := unit.radius() if unit != null else CLEARANCE
	return SearchKernel.safe_point_path(grid, start, end, _point_path, _static_segment_clear.bind(radius, unit), _components_for)

func _components_for(grid: AStarGrid2D, cache := true) -> PackedInt32Array:
	var key := grid.get_instance_id()
	if cache and grid_components.has(key): return grid_components[key]
	var started := Time.get_ticks_usec() if profiling_enabled else 0
	var components := SearchKernel.components_for(grid)
	var labels: PackedInt32Array = components.labels
	var sizes: PackedInt32Array = components.sizes
	if cache:
		grid_components[key] = labels
		grid_component_sizes[key] = sizes
	if profiling_enabled: _record_profile(&"components", started)
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
	if _destination_source_disconnected(from, to, unit): return PackedVector2Array()
	var grid := _grid_for(unit)
	var start := _connected_cell(from, grid, radius, unit) if unit != null else nearest_open_cell(from, grid)
	var end := Vector2i(-1, -1)
	var raw := PackedVector2Array()
	if start.x >= 0:
		end = _connected_cell(to, grid, radius, unit) if unit != null else nearest_open_cell(to, grid)
		raw = _safe_point_path(grid, start, end, unit)
	if raw.is_empty() and unit != null:
		# Try other visible attachments at BOTH ends: the nearest center can
		# be isolated by geometry that fits between coarse grid centers.
		var starts := _visible_cells(from, grid, radius, unit, world_map.cell_at(from), 2)
		var ends: Array[Vector2i] = []
		if not starts.is_empty(): ends = _visible_cells(to, grid, radius, unit, world_map.cell_at(to), 2)
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

func _destination_source_disconnected(from: Vector2, to: Vector2, unit: RtsUnit) -> bool:
	if unit == null or unit != destination_query_unit or from != unit.position: return false
	var key := _grid_key(unit)
	if not fine_grids.has(key): return false
	var grid: AStarGrid2D = fine_grids[key]
	var id := grid.get_instance_id()
	if not destination_origin_components.has(id):
		# A fine-grid rejection alone is not authoritative: a narrow passage
		# may still have a coarse or exact corner route. Only use it when
		# BOTH of those alternatives cannot attach this particular source.
		var coarse := _grid_for(unit)
		var coarse_starts := _visible_cells(from, coarse, unit.radius(), unit, world_map.cell_at(from), 2)
		var rejectable := coarse_starts.is_empty() and not _static_segment_clear(from, from, unit.radius(), unit, false)
		var components := {}
		var fine_starts: Array[Vector2i] = []
		if rejectable: fine_starts = _fine_visible_cells(from, grid, unit)
		if rejectable and grid_components.has(id):
			var labels: PackedInt32Array = grid_components[id]
			for cell in fine_starts:
				var label := labels[cell.y * grid.region.size.x + cell.x]
				if label >= 0: components[label] = true
		# Do not retain a negative result before the first failed native A*
		# has built connectivity. The next candidate can then reuse it.
		if not rejectable: destination_origin_components[id] = {"rejectable": false}
		elif fine_starts.is_empty(): destination_origin_components[id] = {"rejectable": true, "empty": true}
		elif grid_components.has(id): destination_origin_components[id] = {"rejectable": true, "empty": false, "labels": components}
		else: return false
	var source: Dictionary = destination_origin_components[id]
	if not source.rejectable: return false
	# Local fine grids use the same world-aligned lattice and footprints;
	# their source neighborhood cannot provide an attachment missing here.
	if source.empty: return true
	var labels: PackedInt32Array = grid_components[id]
	var origin := Vector2i(((to - grid.offset) / grid.cell_size).round())
	# This is only a necessary-condition filter. Include every neighboring
	# label, even without a clear endpoint sweep, so it cannot reject a route
	# the fine search would accept. Direct paths were checked by the caller.
	for y in range(maxi(0, origin.y - 1), mini(grid.region.size.y, origin.y + 2)):
		for x in range(maxi(0, origin.x - 1), mini(grid.region.size.x, origin.x + 2)):
			if source.labels.has(labels[y * grid.region.size.x + x]): return false
	return true

func _fine_static_path(from: Vector2, to: Vector2, unit: RtsUnit, corner_fallback := true) -> PackedVector2Array:
	# Reachability cannot depend on the request's bounding box: the only
	# opening may lie far beyond it. Share a world-wide fallback by body type
	# and obstacle revision instead of rebuilding a local grid for every worker.
	var key := _grid_key(unit)
	if fine_grids.has(key):
		var world: AStarGrid2D = fine_grids[key]
		if _fine_components_disconnect(from, to, unit, world):
			# A previous failure already flooded the world grid: skip hopeless
			# local builds and A* retries, keep only the exact corner fallback.
			# The corner search runs against live geometry, so it stays correct
			# even while a worker rebuild of this grid is in flight.
			return _obstacle_corner_path(from, to, unit) if corner_fallback else PackedVector2Array()
	else:
		var local := _local_fine_grid_for(from, to, unit, key)
		if local != null:
			var path := _search_fine_grid(from, to, unit, local)
			if not path.is_empty(): return path
	var path := _search_fine_grid(from, to, unit, _fine_grid_for(unit))
	return path if not path.is_empty() or not corner_fallback else _obstacle_corner_path(from, to, unit)

func _fine_components_disconnect(from: Vector2, to: Vector2, unit: RtsUnit, grid: AStarGrid2D) -> bool:
	var key := grid.get_instance_id()
	if not grid_components.has(key): return false
	var components: PackedInt32Array = grid_components[key]
	var width := grid.region.size.x
	var from_labels := {}
	for cell in _fine_visible_cells(from, grid, unit): from_labels[components[cell.y * width + cell.x]] = true
	if from_labels.is_empty(): return false
	for cell in _fine_visible_cells(to, grid, unit):
		if from_labels.has(components[cell.y * width + cell.x]): return false
	return true

func _search_fine_grid(from: Vector2, to: Vector2, unit: RtsUnit, grid: AStarGrid2D) -> PackedVector2Array:
	var starts := _fine_visible_cells(from, grid, unit)
	if starts.is_empty(): return PackedVector2Array()
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
		geometry_cache._forget_components(oldest["grid"])
	var grid := _make_fine_grid(unit, bounds)
	local_fine_grids.append({"key": key, "bounds": bounds, "grid": grid})
	return grid

func _obstacle_corner_path(from: Vector2, to: Vector2, unit: RtsUnit) -> PackedVector2Array:
	# Corner edges use STRICT static sweeps. If an endpoint already overlaps
	# a resource/building, no such edge can leave/enter it. Ordinary coarse and
	# fine routing still handle legal overlap escape before this fallback.
	var key := _grid_key(unit)
	if not _corner_endpoint_clear(from, unit, key) or not _corner_endpoint_clear(to, unit, key): return PackedVector2Array()
	# Strict corner edges are symmetric. An enclosed destination can have a
	# tiny component while the origin sees most of the map: search from the
	# smaller side instead of exhausting the whole outside visibility graph.
	# Connectivity chooses a direction only; it never rejects narrow routes.
	var reverse_search := _corner_search_from_target(from, to, unit)
	if reverse_search:
		var original_from := from
		from = to
		to = original_from
	# Even a fine lattice can miss a legal 1px-wide band between expanded
	# footprints or terrain and a resource. Boundary corners provide portals
	# independent of the lattice; every connecting edge still uses a full sweep.
	if not corner_graphs.has(key):
		var corners := PackedVector2Array()
		# While a worker rebuild of this body type is in flight, reuse the
		# previous revision's portals: rebuilding them here stalled the first
		# query after every invalidation. Stale portals can only add candidates
		# (every edge is re-swept against live geometry), and the worker installs
		# a fresh set with the new grid. Without a pending rebuild, regenerate.
		if geometry_cache.corner_point_stash.has(key) and _corner_rebuild_pending(key):
			corners = geometry_cache.corner_point_stash[key]
		else:
			for obstacle in _entities.buildings:
				if not is_instance_valid(obstacle) or obstacle.is_queued_for_deletion(): continue
				if _gate_passable(obstacle, unit.owner_id): continue
				var bounds := Rect2(obstacle.position - obstacle.size() * 0.5, obstacle.size()).grow(unit.radius() + 0.05)
				for point in [bounds.position, bounds.end, Vector2(bounds.position.x, bounds.end.y), Vector2(bounds.end.x, bounds.position.y)]:
					if not corners.has(point) and _can_occupy(point, unit.radius(), unit, false, Vector2.INF, false, true): corners.append(point)
			var naval: bool = unit.stats.get("tags", []).has("naval")
			for y in world_map.grid_size.y:
				for x in world_map.grid_size.x:
					var terrain: int = world_map.cells[y * world_map.grid_size.x + x]
					if _terrain_passable(terrain, naval): continue
					var bounds := Rect2(Vector2(x, y) * RtsWorldMap.CELL_SIZE, Vector2.ONE * RtsWorldMap.CELL_SIZE).grow(unit.radius() + 0.05)
					for point in [bounds.position, bounds.end, Vector2(bounds.position.x, bounds.end.y), Vector2(bounds.end.x, bounds.position.y)]:
						if not corners.has(point) and _can_occupy(point, unit.radius(), unit, false, Vector2.INF, false, true): corners.append(point)
		geometry_cache.corner_point_stash.erase(key)
		corner_graphs[key] = {"points": corners, "edges": {}, "attachments": {}}
	var graph: Dictionary = corner_graphs[key]
	corner_sweep_unit = unit
	corner_sweep_anchors = {}
	corner_sweep_points = graph["points"]
	corner_sweep_from = from
	corner_sweep_to = to
	var path := SearchKernel.corner_path(from, to, graph, _static_segment_clear.bind(unit.radius(), unit, false), reverse_search, MAX_CORNER_ATTACHMENTS)
	corner_sweep_unit = null
	corner_sweep_anchors = {}
	return path

func _corner_endpoint_clear(point: Vector2, unit: RtsUnit, key: Vector3) -> bool:
	# Endpoint occupancy uses the same strict predicate as corner edges. Range
	# candidates share an origin, so cache both acceptance and rejection before
	# creating a world corner graph. Geometry resets it; wildlife movement
	# invalidates only nearby endpoints along with affected visibility segments.
	if not geometry_cache.corner_endpoint_validity.has(key): geometry_cache.corner_endpoint_validity[key] = {}
	var endpoints: Dictionary = geometry_cache.corner_endpoint_validity[key]
	if endpoints.has(point):
		var existing: bool = endpoints[point]
		endpoints.erase(point)
		endpoints[point] = existing
		return existing
	var clear := _static_segment_clear(point, point, unit.radius(), unit, false)
	if endpoints.size() >= MAX_CORNER_ATTACHMENTS: endpoints.erase(endpoints.keys()[0])
	endpoints[point] = clear
	if geometry_cache.corner_endpoint_bounds.has(key): geometry_cache.corner_endpoint_bounds[key] = geometry_cache.corner_endpoint_bounds[key].expand(point)
	else: geometry_cache.corner_endpoint_bounds[key] = Rect2(point, Vector2.ZERO)
	return clear

func _corner_search_from_target(from: Vector2, to: Vector2, unit: RtsUnit) -> bool:
	var key := _grid_key(unit)
	if not fine_grids.has(key): return false
	var grid: AStarGrid2D = fine_grids[key]
	var id := grid.get_instance_id()
	if not grid_components.has(id) or not grid_component_sizes.has(id): return false
	var labels: PackedInt32Array = grid_components[id]
	var sizes: PackedInt32Array = grid_component_sizes[id]
	var counts: Array[int] = []
	for point in [from, to]:
		var count := 0
		var seen := {}
		for cell in _fine_visible_cells(point, grid, unit):
			var label := labels[cell.y * grid.region.size.x + cell.x]
			if label < 0 or seen.has(label): continue
			seen[label] = true
			count += sizes[label]
		counts.append(count)
	return counts[1] < counts[0]

func _corner_rebuild_pending(key: Vector3) -> bool:
	if not async_geometry_enabled: return false
	for job in grid_builds.active:
		if job.key == key: return true
	return false

func _fine_grid_for(unit: RtsUnit) -> AStarGrid2D:
	var key := _grid_key(unit)
	if fine_grids.has(key): return fine_grids[key]
	# Deterministic tests drive queries without ticking jobs; reap finished
	# rebuilds lazily so the fresh grid lands without a frame loop.
	if not grid_builds.active.is_empty():
		grid_builds.poll(self)
		if fine_grids.has(key): return fine_grids[key]
	if fine_grids.size() >= MAX_FINE_GRIDS:
		var oldest: Vector3 = fine_grids.keys()[0]
		geometry_cache._forget_components(fine_grids[oldest])
		fine_grids.erase(oldest)
	var grid := _make_fine_grid(unit, Rect2(Vector2.ZERO, world_map.world_size))
	fine_grids[key] = grid
	return grid

func _make_fine_grid(unit: RtsUnit, bounds: Rect2) -> AStarGrid2D:
	var started := Time.get_ticks_usec() if profiling_enabled else 0
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
	if profiling_enabled: _record_profile(&"fine_grid_build", started)
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
	# Only tiles whose expanded footprint can reach this grid may block it.
	# Local crowd recovery used to scan the whole map for every small grid.
	var map_first := Vector2i(((origin - Vector2.ONE * radius) / RtsWorldMap.CELL_SIZE).floor()).clamp(Vector2i.ZERO, world_map.grid_size)
	var map_end := Vector2i(((origin + Vector2(size - Vector2i.ONE) * step + Vector2.ONE * radius) / RtsWorldMap.CELL_SIZE).floor()) + Vector2i.ONE
	map_end = map_end.clamp(Vector2i.ZERO, world_map.grid_size)
	for y in range(map_first.y, map_end.y):
		for x in range(map_first.x, map_end.x):
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
	for obstacle in _entities.buildings:
		if not is_instance_valid(obstacle) or obstacle.is_queued_for_deletion(): continue
		if _gate_passable(obstacle, unit.owner_id): continue
		var footprint := Rect2(obstacle.position - obstacle.size() * 0.5, obstacle.size()).grow(radius)
		var region := _fine_region(grid, footprint)
		for y in range(region.position.y, region.end.y):
			for x in range(region.position.x, region.end.x):
				var cell := Vector2i(x, y)
				if footprint.has_point(grid.get_point_position(cell)): grid.set_point_solid(cell)
	for obstacle in _entities.resources:
		if not is_instance_valid(obstacle) or obstacle.is_queued_for_deletion(): continue
		var reach: float = radius + obstacle.radius
		if not allow_resource_escape:
			# Native row-span fill with the exact same circle predicate as the
			# per-cell loop below; resource disks dominate cold build time.
			RecoveryKernel._rasterize_unit_circle(grid, obstacle.position, reach, INF)
			continue
		var current := unit.position.distance_squared_to(obstacle.position)
		var region := _fine_region(grid, Rect2(obstacle.position - Vector2.ONE * reach, Vector2.ONE * reach * 2))
		for y in range(region.position.y, region.end.y):
			for x in range(region.position.x, region.end.x):
				var cell := Vector2i(x, y)
				var distance := grid.get_point_position(cell).distance_squared_to(obstacle.position)
				if distance < reach * reach and (current >= reach * reach or distance + 0.001 < current): grid.set_point_solid(cell)

func _fine_region(grid: AStarGrid2D, bounds: Rect2) -> Rect2i:
	return RecoveryKernel._fine_region(grid, bounds)

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
	if unit != null and unit == range_query_unit and radius == range_query_radius:
		var cache: Dictionary = range_query_segments[int(allow_resource_escape) + 2 * int(boarding)]
		var key := Vector4(from.x, from.y, to.x, to.y)
		if cache.has(key): return cache[key]
		var clear := _compute_static_segment_clear(from, to, radius, unit, allow_resource_escape, boarding)
		if cache.size() < MAX_RANGE_SEGMENTS: cache[key] = clear
		return clear
	return _compute_static_segment_clear(from, to, radius, unit, allow_resource_escape, boarding)

func _compute_static_segment_clear(from: Vector2, to: Vector2, radius: float, unit: RtsUnit, allow_resource_escape: bool, boarding: bool) -> bool:
	if unit != null and unit == corner_sweep_unit and not allow_resource_escape and not boarding:
		return _corner_sweep_segment_clear(from, to, radius, unit)
	# Point samples alone can jump over the very short chord where a segment
	# grazes a circle or a building corner, especially inside narrow passages.
	var center := (from + to) * 0.5
	var extent := from.distance_to(to) * 0.5
	var samples := maxi(1, ceili(from.distance_to(to) / maxf(6.0, minf(12.0, radius * 0.75))))
	_ensure_spatial_index()
	# A spatial hash is efficient for local movement, but a long segment can
	# visit thousands of empty buckets to find a handful of buildings. Choose
	# the smaller broad phase; the exact segment predicates remain unchanged.
	var building_span := ceili((extent + radius) * 2.0 / SPATIAL_CELL_SIZE) + 1
	var building_candidates: Array[RtsBuilding] = _entities.buildings if building_span * building_span > _entities.buildings.size() * 4 else nearby_buildings(center, extent + radius)
	for obstacle in building_candidates:
		if not is_instance_valid(obstacle) or obstacle.is_queued_for_deletion(): continue
		if unit != null and _gate_passable(obstacle, unit.owner_id): continue
		var bounds := Rect2(obstacle.position - obstacle.size() * 0.5, obstacle.size()).grow(radius)
		if _segment_hits_rect(from, to, bounds.grow(-0.0001)): return false
		# Preserve Rect2's half-open boundary rule on exact edge tangencies.
		# The ordinary case needs no per-point entity checks.
		if _segment_hits_rect(from, to, bounds):
			for i in range(samples + 1):
				if bounds.has_point(from.lerp(to, float(i) / samples)): return false
	var resource_span := ceili((extent + radius + spatial_index.max_dynamic_radius) * 2.0 / SPATIAL_CELL_SIZE) + 1
	var resource_candidates: Array[RtsResource] = _entities.resources if resource_span * resource_span > _entities.resources.size() * 4 else nearby_resources(center, extent + radius + spatial_index.max_dynamic_radius)
	for obstacle in resource_candidates:
		if not is_instance_valid(obstacle) or obstacle.is_queued_for_deletion(): continue
		var limit := radius + obstacle.radius
		var closest := Geometry2D.get_closest_point_to_segment(obstacle.position, from, to)
		var distance := closest.distance_squared_to(obstacle.position)
		if distance >= limit * limit: continue
		var current := unit.position.distance_squared_to(obstacle.position) if unit != null else INF
		if not allow_resource_escape or current >= limit * limit or distance + 0.001 < current: return false
	var naval: bool = unit != null and unit.stats.get("tags", []).has("naval")
	return _terrain_segment_clear(from, to, radius, naval, boarding)

func _corner_sweep_segment_clear(from: Vector2, to: Vector2, radius: float, unit: RtsUnit) -> bool:
	# The exact predicates of _compute_static_segment_clear with no resource
	# escape and no boarding, but the obstacle broad phase is gathered once per
	# anchor: a corner search tests many edges out of each expanded node, and
	# every edge midpoint lies within half the edge length of its anchor, so a
	# disk reaching the farthest corner candidate is a conservative superset.
	var candidates: Dictionary = corner_sweep_anchors.get(from, {})
	if candidates.is_empty():
		candidates = _corner_sweep_candidates(from, radius, unit)
		corner_sweep_anchors[from] = candidates
	var edge_len := from.distance_to(to)
	var samples := maxi(1, ceili(edge_len / maxf(6.0, minf(12.0, radius * 0.75))))
	# Candidates are sorted by anchor distance with a suffix-max slack, so an
	# edge skips every obstacle too far away to touch it. This only prunes
	# candidates the exact predicates would reject anyway.
	var wall_dist: PackedFloat64Array = candidates.wall_dist
	var wall_slack: PackedFloat64Array = candidates.wall_slack
	var wall_tight: Array = candidates.wall_tight
	var wall_bounds: Array = candidates.wall_bounds
	for i in wall_bounds.size():
		var wall_limit := edge_len + wall_slack[i]
		if wall_dist[i] > wall_limit * wall_limit: break
		if _segment_hits_rect(from, to, wall_tight[i]): return false
		# Preserve Rect2's half-open boundary rule on exact edge tangencies.
		if _segment_hits_rect(from, to, wall_bounds[i]):
			for s in range(samples + 1):
				if wall_bounds[i].has_point(from.lerp(to, float(s) / samples)): return false
	var resource_dist: PackedFloat64Array = candidates.resource_dist
	var resource_slack: PackedFloat64Array = candidates.resource_slack
	var resource_positions: PackedVector2Array = candidates.resource_positions
	var resource_limits: PackedFloat64Array = candidates.resource_limits
	for i in resource_positions.size():
		var resource_limit := edge_len + resource_slack[i]
		if resource_dist[i] > resource_limit * resource_limit: break
		var obstacle := resource_positions[i]
		if Geometry2D.get_closest_point_to_segment(obstacle, from, to).distance_squared_to(obstacle) < resource_limits[i]: return false
	var naval: bool = unit.stats.get("tags", []).has("naval")
	return _terrain_segment_clear(from, to, radius, naval)

func _corner_sweep_candidates(anchor: Vector2, radius: float, unit: RtsUnit) -> Dictionary:
	var reach := sqrt(maxf(maxf(anchor.distance_squared_to(corner_sweep_from), anchor.distance_squared_to(corner_sweep_to)), _farthest_squared(anchor, corner_sweep_points))) + radius
	_ensure_spatial_index()
	# Mirror the broad-phase choice of the general sweep: a huge anchor reach
	# is cheaper as one full scan than as thousands of empty bucket visits.
	var building_span := ceili(reach * 2.0 / SPATIAL_CELL_SIZE) + 1
	var building_candidates: Array[RtsBuilding] = _entities.buildings if building_span * building_span > _entities.buildings.size() * 4 else nearby_buildings(anchor, reach)
	# Sorted by anchor distance; slack is a suffix maximum so an edge can stop
	# at the first obstacle too far away to touch it (slack bounds the distance
	# from the obstacle's position to any point of its radius-grown footprint).
	var wall_entries := []
	for obstacle in building_candidates:
		if not is_instance_valid(obstacle) or obstacle.is_queued_for_deletion(): continue
		if _gate_passable(obstacle, unit.owner_id): continue
		var bounds := Rect2(obstacle.position - obstacle.size() * 0.5, obstacle.size()).grow(radius)
		wall_entries.append([anchor.distance_squared_to(obstacle.position), sqrt(2.0) * (maxf(obstacle.size().x, obstacle.size().y) * 0.5 + radius), bounds.grow(-0.0001), bounds])
	wall_entries.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var wall_dist := PackedFloat64Array()
	var wall_slack := PackedFloat64Array()
	var wall_tight: Array[Rect2] = []
	var wall_bounds: Array[Rect2] = []
	wall_dist.resize(wall_entries.size())
	wall_slack.resize(wall_entries.size())
	wall_tight.resize(wall_entries.size())
	wall_bounds.resize(wall_entries.size())
	var wall_suffix := 0.0
	for i in range(wall_entries.size() - 1, -1, -1):
		wall_suffix = maxf(wall_suffix, wall_entries[i][1])
		wall_dist[i] = wall_entries[i][0]
		wall_slack[i] = wall_suffix
		wall_tight[i] = wall_entries[i][2]
		wall_bounds[i] = wall_entries[i][3]
	var resource_reach := reach + spatial_index.max_dynamic_radius
	var resource_span := ceili(resource_reach * 2.0 / SPATIAL_CELL_SIZE) + 1
	var resource_candidates: Array[RtsResource] = _entities.resources if resource_span * resource_span > _entities.resources.size() * 4 else nearby_resources(anchor, resource_reach)
	var resource_entries := []
	for obstacle in resource_candidates:
		if not is_instance_valid(obstacle) or obstacle.is_queued_for_deletion(): continue
		var limit := radius + obstacle.radius
		resource_entries.append([anchor.distance_squared_to(obstacle.position), limit, obstacle.position, limit * limit])
	resource_entries.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var resource_dist := PackedFloat64Array()
	var resource_slack := PackedFloat64Array()
	var resource_positions := PackedVector2Array()
	var resource_limits := PackedFloat64Array()
	resource_dist.resize(resource_entries.size())
	resource_slack.resize(resource_entries.size())
	resource_positions.resize(resource_entries.size())
	resource_limits.resize(resource_entries.size())
	var resource_suffix := 0.0
	for i in range(resource_entries.size() - 1, -1, -1):
		resource_suffix = maxf(resource_suffix, resource_entries[i][1])
		resource_dist[i] = resource_entries[i][0]
		resource_slack[i] = resource_suffix
		resource_positions[i] = resource_entries[i][2]
		resource_limits[i] = resource_entries[i][3]
	return {"wall_dist": wall_dist, "wall_slack": wall_slack, "wall_tight": wall_tight, "wall_bounds": wall_bounds,
		"resource_dist": resource_dist, "resource_slack": resource_slack, "resource_positions": resource_positions, "resource_limits": resource_limits}

func _farthest_squared(anchor: Vector2, points: PackedVector2Array) -> float:
	var farthest := 0.0
	for point in points:
		farthest = maxf(farthest, anchor.distance_squared_to(point))
	return farthest

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
	return RecoveryKernel._segment_hits_rect(from, to, bounds)

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
	var previous_unit := range_query_unit
	var previous_radius := range_query_radius
	var previous_segments := range_query_segments
	range_query_unit = unit
	range_query_radius = unit.radius()
	range_query_segments = [{}, {}, {}, {}]
	var result := _search_path_to_range(from, target, reach, unit)
	range_query_unit = previous_unit
	range_query_radius = previous_radius
	range_query_segments = previous_segments
	return result

func _search_path_to_range(from: Vector2, target: Vector2, reach: float, unit: RtsUnit) -> PackedVector2Array:
	_ensure_current()
	var boarding := unit.order == "board_transport"
	if from.distance_to(target) <= reach + 0.5 and (not boarding or boarding_clear(from, target, unit)): return PackedVector2Array([from])
	var footprints: Array[Rect2] = []
	for obstacle in nearby_buildings(target, reach + unit.radius()):
		footprints.append(Rect2(obstacle.position - obstacle.size() * 0.5, obstacle.size()))
	var approaches := SearchKernel.range_approaches(from, target, reach, unit.radius(), footprints)
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
		var corner_attempts := 0
		for point in candidates:
			if from.distance_to(point) >= best_length: break
			# The exact corner fallback costs a visibility search per candidate.
			# Reserve it for the nearest few; a distant corner route around
			# geometry the fine grid calls disconnected is never the best pick.
			var allow_corner: bool = not refine or corner_attempts < MAX_RANGE_CORNER_ATTEMPTS
			var candidate := _fine_static_path(from, point, unit, allow_corner) if refine else _path_between(from, point, unit, true, false)
			if refine: corner_attempts += 1
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
	if not require_path or self_unit == null:
		return _search_nearest_walkable_point(point, radius, self_unit, require_path, include_units)
	# These caches live only for this synchronous query. In particular, deer
	# movement, another unit, or a later obstacle edit cannot reuse them.
	var previous_unit := destination_query_unit
	var previous_cells := destination_origin_cells
	var previous_connections := destination_origin_connections
	var previous_components := destination_origin_components
	var previous_range_unit := range_query_unit
	var previous_radius := range_query_radius
	var previous_segments := range_query_segments
	destination_query_unit = self_unit
	destination_origin_cells = {}
	destination_origin_connections = {}
	destination_origin_components = {}
	range_query_unit = self_unit
	range_query_radius = radius
	range_query_segments = [{}, {}, {}, {}]
	var result := _search_nearest_walkable_point(point, radius, self_unit, require_path, include_units)
	destination_query_unit = previous_unit
	destination_origin_cells = previous_cells
	destination_origin_connections = previous_connections
	destination_origin_components = previous_components
	range_query_unit = previous_range_unit
	range_query_radius = previous_radius
	range_query_segments = previous_segments
	return result

func _search_nearest_walkable_point(point: Vector2, radius: float, self_unit: RtsUnit, require_path: bool, include_units: bool) -> Vector2:
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
		# An open cell is not necessarily reachable from this source. Holding
		# position finishes an impossible move instead of retrying a false goal.
		return self_unit.position
	return world_map.cell_center(nearest_open_cell(clamped, grid))

# Final destinations cannot use movement-only overlap escape allowances.
func _valid_destination(point: Vector2, radius: float, self_unit: RtsUnit, require_path: bool, include_units: bool) -> bool:
	if not can_occupy(point, radius, self_unit, include_units, false): return false
	return not require_path or not _path_between(self_unit.position, point, self_unit, true).is_empty()

func _segment_clear(from: Vector2, to: Vector2, radius: float, self_unit: RtsUnit) -> bool:
	# Both halves are pure predicates; checking unit blockers first skips the
	# static sweep whenever a crowded step is already denied, and iterating the
	# buckets inline avoids materializing the neighborhood array per query.
	var center := (from + to) * 0.5
	var reach := from.distance_to(to) * 0.5 + radius + spatial_index.max_dynamic_radius
	_ensure_spatial_index()
	var reach_squared := reach * reach
	var first := _spatial_cell(center - Vector2.ONE * reach)
	var last := _spatial_cell(center + Vector2.ONE * reach)
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			for other: RtsUnit in units_by_cell.get(Vector2i(x, y), []):
				if other == self_unit or not is_instance_valid(other) or other.is_queued_for_deletion() or other.garrisoned_in != null: continue
				if center.distance_squared_to(other.position) > reach_squared: continue
				var limit: float = radius + other.radius()
				var closest := Geometry2D.get_closest_point_to_segment(other.position, from, to)
				var distance := closest.distance_squared_to(other.position)
				if distance >= limit * limit: continue
				# An existing overlap may only shrink along the entire displacement.
				var current := from.distance_squared_to(other.position)
				if current >= limit * limit or distance + 0.001 < current or to.distance_squared_to(other.position) <= current: return false
	return _static_segment_clear(from, to, radius, self_unit)

func has_fixed_unit_blocker(unit: RtsUnit, target: Vector2) -> bool:
	for other in nearby_units(unit.position, 160.0):
		if other == unit: continue
		# Ordinary moving allies can clear the lane themselves. Recover around
		# idle or stalled allies, without rebuilding local grids for traffic
		# that is still making progress through a chokepoint.
		if not game.is_enemy(unit.owner_id, other.owner_id) and other.stance != "hold" and other.order in ["move", "attack_move"]:
			if other.movement.route_failures < 2 and other.movement.route_stalled_time < RtsUnit.ROUTE_STALL_SECONDS and (other.movement.movement_group == null or other.movement.group_stuck_time < 0.9): continue
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
	# Recovery only: retain live queries while sharing the worker's search policy.
	return RecoveryKernel.recover_path(unit.movement.route_failures,
		func(step: float, half: int) -> PackedVector2Array: return _local_unit_path(unit, target, step, half))

func _local_unit_grid(unit: RtsUnit, step: float, half: int) -> AStarGrid2D:
	var grid := RecoveryKernel.make_local_grid(unit.position, step, half)
	_rasterize_static_grid(unit, grid, true)
	# Mark each nearby unit's footprint once instead of querying every
	# neighborhood for each of the up to 37,249 recovery-grid cells.
	_ensure_spatial_index()
	var extent := float(half) * step
	for other in nearby_units(unit.position, sqrt(2.0) * extent + unit.radius() + spatial_index.max_dynamic_radius):
		if other == unit: continue
		_rasterize_unit_circle(grid, other.position, unit.radius() + other.radius(), unit.position.distance_squared_to(other.position))
	return grid

func _rasterize_unit_circle(grid: AStarGrid2D, center: Vector2, radius: float, current_distance_squared: float) -> void:
	RecoveryKernel._rasterize_unit_circle(grid, center, radius, current_distance_squared)

func _local_reachable_cells(grid: AStarGrid2D, start: Vector2i) -> Array[Vector2i]:
	return RecoveryKernel._local_reachable_cells(grid, start)

func _local_exit_candidates(grid: AStarGrid2D, origin: Vector2, target: Vector2) -> Dictionary:
	return RecoveryKernel._local_exit_candidates(grid, origin, target)

func _local_unit_path(unit: RtsUnit, target: Vector2, step: float, half: int) -> PackedVector2Array:
	var grid := _local_unit_grid(unit, step, half)
	return RecoveryKernel.search_local_grid(grid, Vector2i(half, half), unit.position, target,
		_point_path, _segment_clear.bind(unit.radius(), unit), _local_reachable_cells, _local_exit_candidates)

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
	for other in nearby_units(destination, unit.radius() + spatial_index.max_dynamic_radius + 2.0):
		if yielding.has(other.get_instance_id()) or other.stance == "hold" or game.is_enemy(unit.owner_id, other.owner_id): continue
		# Travelling workers can block a narrow passage just like moving troops.
		# Keep actors already within work/interaction range at their job.
		var travelling_worker := other.order in ["build", "repair", "gather"] and is_instance_valid(other.target) and not other.target.is_queued_for_deletion() and other.movement.route_stop_distance >= 0.0 and other.movement.route_goal.is_finite() and other.position.distance_to(other.movement.route_goal) > other.movement.route_stop_distance + 0.5 and other.position.distance_to(other.target.position) > other.movement.route_stop_distance + 0.5
		var stalled := (other.order in ["move", "attack_move"] and (other.movement.route_stalled_time >= RtsUnit.ROUTE_STALL_SECONDS or other.movement.group_stuck_time >= 0.9)) or (travelling_worker and other.movement.travel_stalled_time >= RtsUnit.ROUTE_STALL_SECONDS)
		if other.order != "idle" and not (stalled and unit.get_instance_id() < other.get_instance_id()): continue
		if other.position.distance_to(destination) >= unit.radius() + other.radius(): continue
		var lateral := Vector2(-forward.y, forward.x)
		if (other.position - unit.position).dot(lateral) < 0.0: lateral = -lateral
		var distance := minf(other.radius() * 0.6, maxf(2.0, unit.position.distance_to(destination)))
		for angle in [0.0, PI / 4.0, -PI / 4.0, PI, 3.0 * PI / 4.0, -3.0 * PI / 4.0, PI / 2.0, -PI / 2.0]:
			var point := other.position + lateral.rotated(angle) * distance
			if not _motion_clear(other, point):
				if not _yield_allies(other, point, yielding) or not _motion_clear(other, point): continue
			var previous := other.position
			other.position = point
			if other.order != "idle": other.movement.yield_timer = 0.3
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
	if unit.movement.movement_group != null:
		if unit.movement.avoidance_cooldown > 0.0: return unit.position
		unit.movement.avoidance_cooldown = 0.18
	if unit.movement.yield_request_cooldown <= 0.0:
		unit.movement.yield_request_cooldown = 0.18
		if _yield_allies(unit, desired_position) and _motion_clear(unit, desired_position): return desired_position
	var side := 1.0 if unit.get_instance_id() % 2 == 0 else -1.0
	var offsets := [side * PI / 4.0, -side * PI / 4.0] if unit.movement.movement_group != null else [side * PI / 4.0, -side * PI / 4.0, side * PI / 2.0, -side * PI / 2.0, side * PI * 0.75, -side * PI * 0.75]
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

func _can_occupy(point: Vector2, radius: float, self_unit: RtsUnit, include_units: bool, escape_from := Vector2.INF, allow_overlap_escape := true, static_resources_only := false) -> bool:
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
	var reach := Vector2.ONE * (radius + spatial_index.max_dynamic_radius)
	var first := _spatial_cell(point - reach)
	var last := _spatial_cell(point + reach)
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			var cell := Vector2i(x, y)
			for resource in resources_by_cell.get(cell, []):
				if not is_instance_valid(resource) or resource.is_queued_for_deletion(): continue
				if static_resources_only and _is_mobile_wildlife(resource): continue
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

extends RefCounted

# Background world fine-grid rebuilds. A geometry revision used to erase every
# fine grid, so the next failing coarse query rebuilt one synchronously on the
# main thread (~10ms rasterization) and flooded its connected components there
# (~60ms of interpreted BFS). Refresh now keeps the previous grids answering —
# stale geometry is safe because every returned edge is revalidated against
# live obstacles — while workers rasterize replacements AND their components
# from pure value snapshots. The swap is atomic per body-type key.
const Recovery = preload("res://scripts/world/navigation_recovery.gd")
const SearchKernel = preload("res://scripts/world/navigation_search_kernel.gd")
const GeometryCache = preload("res://scripts/world/navigation_cache.gd")

class Snapshot:
	# Main-thread capture produces value data only. After submission the
	# snapshot belongs exclusively to its worker until reaped.
	var radius: float
	var naval: bool
	var world_size: Vector2
	var grid_size: Vector2i
	var cells: PackedByteArray
	var buildings: Array[Rect2] = []
	var resources := PackedVector2Array()
	var resource_radii := PackedFloat64Array()
	# Living wildlife is excluded from strict corner endpoints, exactly like the
	# static_resources_only occupancy checks the main thread performs.
	var resource_mobile := PackedByteArray()
	var grid: AStarGrid2D
	var labels: PackedInt32Array
	var sizes: PackedInt32Array
	# Obstacle boundary portals for the exact corner fallback. These are a pure
	# function of the captured geometry (strict occupancy never consults the
	# querying unit's position), so the worker can precompute them.
	var corners := PackedVector2Array()
	var elapsed_us := 0

	func run() -> void:
		var started := Time.get_ticks_usec()
		grid = build_grid()
		var components := SearchKernel.components_for(grid)
		labels = components.labels
		sizes = components.sizes
		build_corners()
		elapsed_us = Time.get_ticks_usec() - started

	func build_corners() -> void:
		# Mirrors the point generation in RtsNavigation._obstacle_corner_path.
		for footprint in buildings:
			var bounds := footprint.grow(radius + 0.05)
			for point in [bounds.position, bounds.end, Vector2(bounds.position.x, bounds.end.y), Vector2(bounds.end.x, bounds.position.y)]:
				if not corners.has(point) and _can_occupy_point(point): corners.append(point)
		for y in grid_size.y:
			for x in grid_size.x:
				var terrain: int = cells[y * grid_size.x + x]
				if Recovery._terrain_passable(terrain, naval): continue
				var bounds := Rect2(Vector2(x, y) * RtsWorldMap.CELL_SIZE, Vector2.ONE * RtsWorldMap.CELL_SIZE).grow(radius + 0.05)
				for point in [bounds.position, bounds.end, Vector2(bounds.position.x, bounds.end.y), Vector2(bounds.end.x, bounds.position.y)]:
					if not corners.has(point) and _can_occupy_point(point): corners.append(point)

	func _can_occupy_point(point: Vector2) -> bool:
		# Strict static occupancy: RtsNavigation._can_occupy with no units, no
		# overlap escape and static resources only.
		if point.x < radius or point.y < radius or point.x > world_size.x - radius or point.y > world_size.y - radius: return false
		var cell_size := float(RtsWorldMap.CELL_SIZE)
		var first_x := floori((point.x - radius) / cell_size)
		var last_x: int = mini(grid_size.x - 1, floori((point.x + radius) / cell_size))
		var first_y := floori((point.y - radius) / cell_size)
		var last_y: int = mini(grid_size.y - 1, floori((point.y + radius) / cell_size))
		for cy in range(first_y, last_y + 1):
			for cx in range(first_x, last_x + 1):
				var terrain: int = cells[cy * grid_size.x + cx]
				if Recovery._terrain_passable(terrain, naval): continue
				var closest := Vector2(clampf(point.x, cx * cell_size, (cx + 1) * cell_size), clampf(point.y, cy * cell_size, (cy + 1) * cell_size))
				if point.distance_squared_to(closest) < radius * radius: return false
		for footprint in buildings:
			if footprint.grow(radius).has_point(point): return false
		for i in resources.size():
			if resource_mobile[i]: continue
			var limit := radius + resource_radii[i]
			if point.distance_squared_to(resources[i]) < limit * limit: return false
		return true

	func build_grid() -> AStarGrid2D:
		# Mirrors RtsNavigation._make_fine_grid for the full world bounds.
		var step := float(RtsWorldMap.CELL_SIZE) / ceili(RtsWorldMap.CELL_SIZE / maxf(6.0, minf(12.0, radius * 0.75)))
		var size := Vector2i((world_size / step).ceil()) + Vector2i.ONE
		var grid := AStarGrid2D.new()
		grid.region = Rect2i(Vector2i.ZERO, size)
		grid.offset = Vector2.ZERO
		grid.cell_size = Vector2.ONE * step
		grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		grid.update()
		rasterize(grid)
		return grid

	func rasterize(grid: AStarGrid2D) -> void:
		# Mirrors RtsNavigation._rasterize_static_grid with no overlap escape:
		# identical predicates over the captured values, never scene objects.
		var step := grid.cell_size.x
		var origin := grid.offset
		var size := grid.region.size
		var first := Vector2i(((Vector2.ONE * radius - origin) / step).ceil()).clamp(Vector2i.ZERO, size)
		var last := Vector2i(((world_size - Vector2.ONE * radius - origin) / step).floor()).clamp(-Vector2i.ONE, size - Vector2i.ONE)
		grid.fill_solid_region(Rect2i(0, 0, first.x, size.y))
		grid.fill_solid_region(Rect2i(last.x + 1, 0, size.x - last.x - 1, size.y))
		grid.fill_solid_region(Rect2i(0, 0, size.x, first.y))
		grid.fill_solid_region(Rect2i(0, last.y + 1, size.x, size.y - last.y - 1))
		var map_first := Vector2i(((origin - Vector2.ONE * radius) / RtsWorldMap.CELL_SIZE).floor()).clamp(Vector2i.ZERO, grid_size)
		var map_end := Vector2i(((origin + Vector2(size - Vector2i.ONE) * step + Vector2.ONE * radius) / RtsWorldMap.CELL_SIZE).floor()) + Vector2i.ONE
		map_end = map_end.clamp(Vector2i.ZERO, grid_size)
		for y in range(map_first.y, map_end.y):
			for x in range(map_first.x, map_end.x):
				var terrain: int = cells[y * grid_size.x + x]
				if Recovery._terrain_passable(terrain, naval): continue
				var tile := Rect2(Vector2(x, y) * RtsWorldMap.CELL_SIZE, Vector2.ONE * RtsWorldMap.CELL_SIZE)
				var region := Recovery._fine_region(grid, tile.grow(radius))
				for cy in range(region.position.y, region.end.y):
					for cx in range(region.position.x, region.end.x):
						var cell := Vector2i(cx, cy)
						if grid.is_point_solid(cell): continue
						var point := grid.get_point_position(cell)
						if point.distance_squared_to(point.clamp(tile.position, tile.end)) < radius * radius: grid.set_point_solid(cell)
		for footprint in buildings:
			var grown := footprint.grow(radius)
			var region := Recovery._fine_region(grid, grown)
			for y in range(region.position.y, region.end.y):
				for x in range(region.position.x, region.end.x):
					if grown.has_point(grid.get_point_position(Vector2i(x, y))): grid.set_point_solid(Vector2i(x, y))
		for i in resources.size():
			Recovery._rasterize_unit_circle(grid, resources[i], radius + resource_radii[i], INF)

var active: Array[Dictionary] = []
var metrics := {"submitted": 0, "installed": 0, "discarded": 0, "capture_us": 0, "worker_us": 0}

func request(navigation, key: Vector3) -> void:
	# One in-flight build per body type and revision; a newer geometry revision
	# supersedes older workers, whose results are discarded when reaped.
	var revision: int = navigation.obstacle_revision
	for job in active:
		if job.key == key and job.revision == revision: return
	if not navigation.fine_grids.has(key): return
	var started := Time.get_ticks_usec()
	var snapshot := _capture(navigation, key)
	metrics.capture_us += Time.get_ticks_usec() - started
	var task := WorkerThreadPool.add_task(snapshot.run, false, "RTS fine grid rebuild")
	active.append({"key": key, "revision": revision, "previous_grid": navigation.fine_grids[key], "task": task, "snapshot": snapshot})
	metrics.submitted += 1

func poll(navigation) -> void:
	# Never join incomplete work on the frame loop. Reaping a completed task
	# establishes ownership of its output and releases the engine task record.
	for i in range(active.size() - 1, -1, -1):
		var job: Dictionary = active[i]
		if not WorkerThreadPool.is_task_completed(job.task): continue
		WorkerThreadPool.wait_for_task_completion(job.task)
		active.remove_at(i)
		_install(navigation, job)

func _install(navigation, job: Dictionary) -> void:
	var snapshot = job.snapshot
	metrics.worker_us += snapshot.elapsed_us
	var fine_grids: Dictionary = navigation.fine_grids
	# A newer revision or an evicted/replaced grid makes this result stale.
	if job.revision != navigation.obstacle_revision or fine_grids.get(job.key) != job.previous_grid:
		metrics.discarded += 1
		return
	if job.previous_grid != null:
		navigation.geometry_cache._forget_components(job.previous_grid)
	fine_grids[job.key] = snapshot.grid
	navigation.grid_components[snapshot.grid.get_instance_id()] = snapshot.labels
	navigation.grid_component_sizes[snapshot.grid.get_instance_id()] = snapshot.sizes
	# Fresh corner portals for the exact fallback; lazy edge/attachment caches
	# are revalidated against live geometry as queries use them.
	navigation.corner_graphs[job.key] = {"points": snapshot.corners, "edges": {}, "attachments": {}}
	metrics.installed += 1

func _capture(navigation, key: Vector3) -> Snapshot:
	var snapshot := Snapshot.new()
	snapshot.radius = key.y
	snapshot.naval = key.z > 0.5
	snapshot.world_size = navigation.world_map.world_size
	snapshot.grid_size = navigation.world_map.grid_size
	# Explicit copy: terrain edits during a job cannot change the worker input.
	snapshot.cells = navigation.world_map.cells.duplicate()
	var owner_id := int(key.x)
	for building in navigation._entities.buildings:
		if not is_instance_valid(building) or building.is_queued_for_deletion(): continue
		if navigation._gate_passable(building, owner_id): continue
		snapshot.buildings.append(Rect2(building.position - building.size() * 0.5, building.size()))
	for resource in navigation._entities.resources:
		if not is_instance_valid(resource) or resource.is_queued_for_deletion(): continue
		snapshot.resources.append(resource.position)
		snapshot.resource_radii.append(resource.radius)
		snapshot.resource_mobile.append(1 if GeometryCache.is_mobile_wildlife(resource) else 0)
	return snapshot

func shutdown() -> void:
	# Waiting is confined to scene teardown/reset, never normal frame dispatch.
	for job in active: WorkerThreadPool.wait_for_task_completion(job.task)
	active.clear()

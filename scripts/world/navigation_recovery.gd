extends RefCounted

# Main-thread capture produces value data only. After submission this object
# belongs exclusively to one worker until its task has completed and been reaped.
const CELL_SIZE := RtsWorldMap.CELL_SIZE
var origin: Vector2
var radius: float
var naval: bool
var failures: int
var world_size: Vector2
var grid_size: Vector2i
var cells: PackedByteArray
var buildings: Array[Rect2] = []
var resources := PackedVector2Array()
var resource_radii := PackedFloat64Array()
var units := PackedVector2Array()
var unit_radii := PackedFloat64Array()
var target: Vector2
var fallback := Vector2.INF
var result := PackedVector2Array()
var elapsed_us := 0

static func capture(navigation, unit: RtsUnit):
	var snapshot = new()
	snapshot.origin = unit.position
	snapshot.radius = unit.radius()
	snapshot.naval = unit.stats.get("tags", []).has("naval")
	snapshot.failures = unit.route_failures
	snapshot.world_size = navigation.world_map.world_size
	snapshot.grid_size = navigation.world_map.grid_size
	# Explicit copy: terrain edits during a job cannot change the worker input.
	snapshot.cells = navigation.world_map.cells.duplicate()
	for building in navigation.game.buildings:
		if not is_instance_valid(building) or building.is_queued_for_deletion(): continue
		if navigation._gate_passable(building, unit.owner_id): continue
		snapshot.buildings.append(Rect2(building.position - building.size() * 0.5, building.size()))
	for resource in navigation.game.resources:
		if not is_instance_valid(resource) or resource.is_queued_for_deletion(): continue
		snapshot.resources.append(resource.position)
		snapshot.resource_radii.append(resource.radius)
	for other in navigation.game.units:
		if not is_instance_valid(other) or other.is_queued_for_deletion() or other == unit or other.garrisoned_in != null: continue
		snapshot.units.append(other.position)
		snapshot.unit_radii.append(other.radius())
	return snapshot

func run() -> void:
	var started := Time.get_ticks_usec()
	result = recover(target)
	if result.is_empty() and fallback != Vector2.INF: result = recover(fallback)
	elapsed_us = Time.get_ticks_usec() - started

func recover(goal: Vector2) -> PackedVector2Array:
	return recover_path(failures, func(step: float, half: int) -> PackedVector2Array: return local_path(goal, step, half))

static func recover_path(failures: int, search: Callable) -> PackedVector2Array:
	# Let transient traffic clear before escalating to fine/wider recovery.
	for resolution in [Vector2i(8, 24), Vector2i(2, 48), Vector2i(8, 48), Vector2i(8, 96), Vector2i(2, 96)]:
		if resolution != Vector2i(8, 24) and failures < 3: break
		var path: PackedVector2Array = search.call(resolution.x, resolution.y)
		if not path.is_empty(): return path
	return PackedVector2Array()

static func make_local_grid(origin: Vector2, step: float, half: int) -> AStarGrid2D:
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(0, 0, half * 2 + 1, half * 2 + 1)
	grid.cell_size = Vector2.ONE * step
	grid.offset = origin - Vector2.ONE * half * step
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	return grid

func make_grid(step: float, half: int) -> AStarGrid2D:
	var grid := make_local_grid(origin, step, half)
	rasterize_static(grid)
	for i in units.size():
		var center := units[i]
		_rasterize_unit_circle(grid, center, radius + unit_radii[i], origin.distance_squared_to(center))
	return grid

func rasterize_static(grid: AStarGrid2D) -> void:
	# Rasterize static geometry once. Querying all spatial buckets for every
	# fine cell made the first shared route stall a large army's command frame.
	var step := grid.cell_size.x
	var offset := grid.offset
	var size := grid.region.size
	var first := Vector2i(((Vector2.ONE * radius - offset) / step).ceil()).clamp(Vector2i.ZERO, size)
	var last := Vector2i(((world_size - Vector2.ONE * radius - offset) / step).floor()).clamp(-Vector2i.ONE, size - Vector2i.ONE)
	grid.fill_solid_region(Rect2i(0, 0, first.x, size.y))
	grid.fill_solid_region(Rect2i(last.x + 1, 0, size.x - last.x - 1, size.y))
	grid.fill_solid_region(Rect2i(0, 0, size.x, first.y))
	grid.fill_solid_region(Rect2i(0, last.y + 1, size.x, size.y - last.y - 1))
	# Only tiles whose expanded footprint can reach this grid may block it.
	# Local crowd recovery used to scan the whole map for every small grid.
	var map_first := Vector2i(((offset - Vector2.ONE * radius) / CELL_SIZE).floor()).clamp(Vector2i.ZERO, grid_size)
	var map_end := Vector2i(((offset + Vector2(size - Vector2i.ONE) * step + Vector2.ONE * radius) / CELL_SIZE).floor()) + Vector2i.ONE
	map_end = map_end.clamp(Vector2i.ZERO, grid_size)
	for y in range(map_first.y, map_end.y):
		for x in range(map_first.x, map_end.x):
			var terrain: int = cells[y * grid_size.x + x]
			if _terrain_passable(terrain, naval): continue
			var tile := Rect2(Vector2(x, y) * CELL_SIZE, Vector2.ONE * CELL_SIZE)
			var region := _fine_region(grid, tile.grow(radius))
			for cy in range(region.position.y, region.end.y):
				for cx in range(region.position.x, region.end.x):
					var cell := Vector2i(cx, cy)
					if grid.is_point_solid(cell): continue
					var point := grid.get_point_position(cell)
					if point.distance_squared_to(point.clamp(tile.position, tile.end)) < radius * radius: grid.set_point_solid(cell)
	for bounds in buildings:
		var footprint := bounds.grow(radius)
		var region := _fine_region(grid, footprint)
		for y in range(region.position.y, region.end.y):
			for x in range(region.position.x, region.end.x):
				var cell := Vector2i(x, y)
				if footprint.has_point(grid.get_point_position(cell)): grid.set_point_solid(cell)
	for i in resources.size():
		var center := resources[i]
		var reach := radius + resource_radii[i]
		var current := origin.distance_squared_to(center)
		var region := _fine_region(grid, Rect2(center - Vector2.ONE * reach, Vector2.ONE * reach * 2))
		for y in range(region.position.y, region.end.y):
			for x in range(region.position.x, region.end.x):
				var cell := Vector2i(x, y)
				var distance := grid.get_point_position(cell).distance_squared_to(center)
				if distance < reach * reach and (current >= reach * reach or distance + 0.001 < current): grid.set_point_solid(cell)

func local_path(target: Vector2, step: float, half: int) -> PackedVector2Array:
	var grid := make_grid(step, half)
	return search_local_grid(grid, Vector2i(half, half), origin, target,
		func(_grid: AStarGrid2D, start: Vector2i, end: Vector2i) -> PackedVector2Array: return _grid.get_point_path(start, end),
		_segment_clear, _local_reachable_cells, _local_exit_candidates)

# Callbacks preserve the live navigation's profiling/override hooks. Worker
# calls use only the privately owned snapshot and its grid, never scene objects.
static func search_local_grid(grid: AStarGrid2D, start: Vector2i, origin: Vector2, target: Vector2,
		point_path: Callable, segment_clear: Callable, reachable_cells: Callable, exit_candidates: Callable) -> PackedVector2Array:
	grid.set_point_solid(start, false)
	# Only the perimeter and the 3-cell disk around the target can be exits.
	# Reject occupied/non-improving exits BEFORE flooding tens of thousands of
	# cells. At contact with a parked unit there is often no useful exit at all.
	var exits: Dictionary = exit_candidates.call(grid, origin, target)
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
		var raw: PackedVector2Array = point_path.call(grid, start, cell)
		if raw.size() < 2:
			if not connectivity_checked:
				for point in reachable_cells.call(grid, start): reachable[point] = true
				connectivity_checked = true
			continue
		var result := PackedVector2Array([origin])
		var anchor := 0
		while anchor < raw.size() - 1:
			var next := anchor + 1
			if not segment_clear.call(raw[anchor], raw[next]): break
			for index in range(anchor + 2, mini(raw.size(), anchor + 12)):
				if not segment_clear.call(raw[anchor], raw[index]): break
				next = index
			result.append(raw[next])
			anchor = next
		if anchor != raw.size() - 1: continue
		if segment_clear.call(result[result.size() - 1], target): result.append(target)
		return result
	return PackedVector2Array()

func _static_segment_clear(from: Vector2, to: Vector2) -> bool:
	# Point samples alone can jump over the very short chord where a segment
	# grazes a circle or a building corner, especially inside narrow passages.
	var samples := maxi(1, ceili(from.distance_to(to) / maxf(6.0, minf(12.0, radius * 0.75))))
	for footprint in buildings:
		var bounds := footprint.grow(radius)
		if _segment_hits_rect(from, to, bounds.grow(-0.0001)): return false
		# Preserve Rect2's half-open boundary rule on exact edge tangencies.
		# The ordinary case needs no per-point entity checks.
		if _segment_hits_rect(from, to, bounds):
			for i in range(samples + 1):
				if bounds.has_point(from.lerp(to, float(i) / samples)): return false
	for i in resources.size():
		var center := resources[i]
		var limit := radius + resource_radii[i]
		var closest := Geometry2D.get_closest_point_to_segment(center, from, to)
		var distance := closest.distance_squared_to(center)
		if distance >= limit * limit: continue
		var current := origin.distance_squared_to(center)
		if current >= limit * limit or distance + 0.001 < current: return false
	return _terrain_segment_clear(from, to)

func _terrain_segment_clear(from: Vector2, to: Vector2) -> bool:
	var bounds := Rect2(Vector2.ONE * radius, world_size - Vector2.ONE * radius * 2)
	if from != from.clamp(bounds.position, bounds.end) or to != to.clamp(bounds.position, bounds.end): return false
	var region := Rect2(from, Vector2.ZERO).expand(to).grow(radius)
	var first := cell_at(region.position)
	var last := cell_at(region.end)
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			var terrain: int = cells[y * grid_size.x + x]
			if _terrain_passable(terrain, naval): continue
			var tile := Rect2(Vector2(x, y) * CELL_SIZE, Vector2.ONE * CELL_SIZE)
			# A rounded rectangle is two strips plus four corner circles.
			if _segment_hits_rect(from, to, Rect2(tile.position - Vector2(radius, 0), tile.size + Vector2(radius * 2, 0)).grow(-0.00001)): return false
			if _segment_hits_rect(from, to, Rect2(tile.position - Vector2(0, radius), tile.size + Vector2(0, radius * 2)).grow(-0.00001)): return false
			for corner in [tile.position, tile.end, Vector2(tile.position.x, tile.end.y), Vector2(tile.end.x, tile.position.y)]:
				if corner.distance_squared_to(Geometry2D.get_closest_point_to_segment(corner, from, to)) < radius * radius - 0.0001: return false
	return true

func _segment_clear(from: Vector2, to: Vector2) -> bool:
	if not _static_segment_clear(from, to): return false
	for i in units.size():
		var center := units[i]
		var limit := radius + unit_radii[i]
		var closest := Geometry2D.get_closest_point_to_segment(center, from, to)
		var distance := closest.distance_squared_to(center)
		if distance >= limit * limit: continue
		# An existing overlap may only shrink along the entire displacement.
		var current := from.distance_squared_to(center)
		if current >= limit * limit or distance + 0.001 < current or to.distance_squared_to(center) <= current: return false
	return true

static func _fine_region(grid: AStarGrid2D, bounds: Rect2) -> Rect2i:
	var first := Vector2i(((bounds.position - grid.offset) / grid.cell_size).floor())
	var last := Vector2i(((bounds.end - grid.offset) / grid.cell_size).ceil()) + Vector2i.ONE
	return Rect2i(first, last - first).intersection(grid.region)

static func _rasterize_unit_circle(grid: AStarGrid2D, center: Vector2, radius: float, current_distance_squared: float) -> void:
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

static func _local_reachable_cells(grid: AStarGrid2D, start: Vector2i) -> Array[Vector2i]:
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

static func _local_exit_candidates(grid: AStarGrid2D, origin: Vector2, target: Vector2) -> Dictionary:
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

static func _add_local_exit(exits: Dictionary, grid: AStarGrid2D, cell: Vector2i, target: Vector2, limit: float) -> void:
	if not grid.is_point_solid(cell) and grid.get_point_position(cell).distance_to(target) < limit:
		exits[cell] = true

static func _segment_hits_rect(from: Vector2, to: Vector2, bounds: Rect2) -> bool:
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

static func _terrain_passable(terrain: int, naval: bool, boarding := false) -> bool:
	return terrain != RtsWorldMap.Terrain.MOUNTAIN and (boarding or (terrain == RtsWorldMap.Terrain.WATER) == naval)

func cell_at(point: Vector2) -> Vector2i:
	return Vector2i(clampi(floori(point.x / CELL_SIZE), 0, grid_size.x - 1), clampi(floori(point.y / CELL_SIZE), 0, grid_size.y - 1))

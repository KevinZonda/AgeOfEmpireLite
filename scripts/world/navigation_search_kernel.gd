extends RefCounted

# Search policy uses geometry values and explicit collision/search callbacks.
# No scene nodes, owner lookup, frame clock, cache revisions or job lifecycle
# belong here. A callback supplied by the facade is MAIN-THREAD ONLY. Workers
# may use these algorithms only with a privately owned grid/graph and value
# snapshot callbacks; a shared AStarGrid2D is never a worker input.

static func safe_point_path(grid: AStarGrid2D, start: Vector2i, end: Vector2i, point_path: Callable, segment_clear: Callable, failed_search: Callable) -> PackedVector2Array:
	# Two clear cell centers can still have a resource between them. Repair
	# that edge conservatively for this search, restoring the shared grid after.
	var blocked: Array[Vector2i] = []
	var result := PackedVector2Array()
	for attempt in 32:
		var raw: PackedVector2Array = point_path.call(grid, start, end)
		if raw.is_empty():
			# Temporary edge-repair blocks must never enter a shared cache.
			if blocked.is_empty(): failed_search.call(grid)
			break
		var invalid := -1
		for i in range(1, raw.size()):
			if not segment_clear.call(raw[i - 1], raw[i]):
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

static func components_for(grid: AStarGrid2D) -> Dictionary:
	# Diagonals cannot cross blocked corners, so four-neighbor components are
	# also valid for the eight-neighbor search. Reject disconnected candidates
	# once, rather than exhausting A* for every worker/interaction sample.
	# Integer index math only: per-cell Vector2i/offset-array allocation made a
	# world-grid flood dominate a frame. Solidity is snapshotted once so the
	# flood itself performs no native calls.
	var size := grid.region.size
	var width := size.x
	var count := width * size.y
	var solid := PackedByteArray()
	solid.resize(count)
	var index := 0
	for y in size.y:
		for x in width:
			if grid.is_point_solid(Vector2i(x, y)): solid[index] = 1
			index += 1
	var labels := PackedInt32Array()
	labels.resize(count)
	labels.fill(-1)
	var queue := PackedInt32Array()
	queue.resize(count)
	var component := 0
	var sizes := PackedInt32Array()
	for start in count:
		if labels[start] != -1: continue
		if solid[start]:
			labels[start] = -2
			continue
		labels[start] = component
		queue[0] = start
		var head := 0
		var tail := 1
		while head < tail:
			var current := queue[head]
			head += 1
			if current % width > 0:
				var left := current - 1
				if labels[left] == -1:
					if solid[left]: labels[left] = -2
					else:
						labels[left] = component
						queue[tail] = left
						tail += 1
			if current % width < width - 1:
				var right := current + 1
				if labels[right] == -1:
					if solid[right]: labels[right] = -2
					else:
						labels[right] = component
						queue[tail] = right
						tail += 1
			if current >= width:
				var up := current - width
				if labels[up] == -1:
					if solid[up]: labels[up] = -2
					else:
						labels[up] = component
						queue[tail] = up
						tail += 1
			if current < count - width:
				var down := current + width
				if labels[down] == -1:
					if solid[down]: labels[down] = -2
					else:
						labels[down] = component
						queue[tail] = down
						tail += 1
		sizes.append(tail)
		component += 1
	return {"labels": labels, "sizes": sizes}

static func corner_path(from: Vector2, to: Vector2, graph: Dictionary, segment_clear: Callable, reverse_search := false, max_attachments := 64) -> PackedVector2Array:
	# Conservative coverage permits distant wildlife invalidation to skip this
	# graph without scanning edges. Stale bounds after LRU eviction are safe.
	if not graph.has("visibility_bounds"):
		var bounds := Rect2(from, Vector2.ZERO).expand(to)
		for point in graph.points: bounds = bounds.expand(point)
		graph.visibility_bounds = bounds
	else: graph.visibility_bounds = graph.visibility_bounds.expand(from).expand(to)
	# A range query tries many destinations from the SAME origin. Rechecking
	# every origin-to-corner sweep made an unreachable unit block a full frame.
	# These strict static sweeps depend on geometry/body type, not unit traffic.
	for anchor in [from, to]:
		if graph["attachments"].has(anchor):
			var existing: Dictionary = graph["attachments"][anchor]
			graph["attachments"].erase(anchor)
			graph["attachments"][anchor] = existing
			continue
		if graph["attachments"].size() >= max_attachments:
			graph["attachments"].erase(graph["attachments"].keys()[0])
		graph["attachments"][anchor] = {}
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
			if reverse_search: result.reverse()
			return result
		closed[current] = 1
		for next in points.size():
			if closed[next]: continue
			var cost := costs[current] + points[current].distance_to(points[next])
			if cost >= costs[next] or cost + points[next].distance_to(to) > costs[1]: continue
			var edge := Vector2i(mini(current, next), maxi(current, next))
			var clear: bool
			if edge.x >= 2 and graph["edges"].has(edge): clear = graph["edges"][edge]
			elif edge.x < 2 and edge.y >= 2:
				var attachment: Dictionary = graph["attachments"][points[edge.x]]
				if not attachment.has(edge.y):
					attachment[edge.y] = segment_clear.call(points[edge.x], points[edge.y])
				clear = attachment[edge.y]
			else:
				clear = segment_clear.call(points[current], points[next])
				if edge.x >= 2: graph["edges"][edge] = clear
			if clear:
				costs[next] = cost
				parents[next] = current
	# GDScript requires a terminal return even though the loop exits above.
	return PackedVector2Array()

static func range_approaches(from: Vector2, target: Vector2, reach: float, radius: float, footprints: Array[Rect2]) -> Array[Vector2]:
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
	for footprint in footprints:
		var bounds := footprint.grow(radius + 0.05)
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
	return approaches

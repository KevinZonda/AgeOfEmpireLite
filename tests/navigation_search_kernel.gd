extends SceneTree

const Kernel = preload("res://scripts/world/navigation_search_kernel.gd")
var checks := 0
var failures := 0
var origin_corner_sweeps := 0
var failure_cache_calls := 0
class OwnedGridJob extends RefCounted:
	var result := PackedVector2Array()
	func run() -> void:
		var grid := AStarGrid2D.new()
		grid.region = Rect2i(0, 0, 6, 1)
		grid.cell_size = Vector2.ONE
		grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		grid.update()
		result = Kernel.safe_point_path(grid, Vector2i.ZERO, Vector2i(5, 0),
			func(owned: AStarGrid2D, start: Vector2i, end: Vector2i) -> PackedVector2Array: return owned.get_point_path(start, end),
			func(_a: Vector2, _b: Vector2) -> bool: return true,
			func(_grid_ref: AStarGrid2D) -> void: pass)

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("POC_%s %s" % ["PASS" if ok else "FAIL", label])

func _run() -> void:
	_test_component_labels()
	_test_edge_repair()
	_test_visibility_search()
	_test_negative_visibility_cache()
	_test_range_approaches()
	# A worker owns its grid and value-only callbacks. This deliberately has
	# no game/fixture/units, shared facade cache or live scene in its inputs.
	var owned_job := OwnedGridJob.new()
	var task := WorkerThreadPool.add_task(owned_job.run, false, "search kernel ownership test")
	while not WorkerThreadPool.is_task_completed(task): await process_frame
	WorkerThreadPool.wait_for_task_completion(task)
	check(owned_job.result.size() == 6, "private_kernel_grid_runs_without_scene_dependencies")
	print("NAVIGATION_SEARCH_KERNEL checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)

func _grid(size: Vector2i) -> AStarGrid2D:
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(Vector2i.ZERO, size)
	grid.cell_size = Vector2.ONE
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	return grid

func _test_component_labels() -> void:
	var grid := _grid(Vector2i(6, 5))
	for y in 5: grid.set_point_solid(Vector2i(2, y))
	grid.set_point_solid(Vector2i(4, 0))
	var data := Kernel.components_for(grid)
	check(data.sizes == PackedInt32Array([10, 14]), "component_sizes_cover_all_open_cells")
	for a in [Vector2i(0, 0), Vector2i(3, 0), Vector2i(5, 4)]:
		for y in 5:
			for x in 6:
				var b := Vector2i(x, y)
				var label: int = data.labels[y * 6 + x]
				if grid.is_point_solid(b):
					check(label == -2, "solid_label_%s" % b)
				else:
					check((data.labels[a.y * 6 + a.x] == label) == (not grid.get_point_path(a, b).is_empty()), "component_native_reachability_%s_%s" % [a, b])

func _native_path(grid: AStarGrid2D, from: Vector2i, to: Vector2i) -> PackedVector2Array:
	return grid.get_point_path(from, to)

func _failed_search(_grid_ref: AStarGrid2D) -> void:
	failure_cache_calls += 1

func _test_edge_repair() -> void:
	var grid := _grid(Vector2i(5, 3))
	var start := Vector2i(0, 1)
	var end := Vector2i(4, 1)
	var obstacle := Vector2(1.5, 1)
	var clear := func(a: Vector2, b: Vector2) -> bool:
		return obstacle.distance_squared_to(Geometry2D.get_closest_point_to_segment(obstacle, a, b)) >= 0.16
	var path := Kernel.safe_point_path(grid, start, end, _native_path, clear, _failed_search)
	check(not path.is_empty() and path[0] == Vector2(start) and path[-1] == Vector2(end), "edge_repair_finds_connected_detour")
	for i in range(1, path.size()): check(clear.call(path[i - 1], path[i]), "edge_repair_safe_segment_%d" % i)
	for y in 3:
		for x in 5: check(not grid.is_point_solid(Vector2i(x, y)), "temporary_block_restored_%d_%d" % [x, y])
	check(failure_cache_calls == 0, "successful_repair_does_not_publish_connectivity")
	var narrow := _grid(Vector2i(5, 1))
	path = Kernel.safe_point_path(narrow, Vector2i.ZERO, Vector2i(4, 0), _native_path, func(_a: Vector2, _b: Vector2) -> bool: return false, _failed_search)
	check(path.is_empty() and failure_cache_calls == 0, "failed_repaired_grid_never_enters_component_cache")
	for x in 5: check(not narrow.is_point_solid(Vector2i(x, 0)), "failed_repair_restores_%d" % x)
	narrow.set_point_solid(Vector2i(2, 0))
	Kernel.safe_point_path(narrow, Vector2i.ZERO, Vector2i(4, 0), _native_path, func(_a: Vector2, _b: Vector2) -> bool: return true, _failed_search)
	check(failure_cache_calls == 1, "genuine_disconnection_publishes_components_once")

func _graph(corners: PackedVector2Array) -> Dictionary:
	return {"points": corners, "edges": {}, "attachments": {}}

func _length(path: PackedVector2Array) -> float:
	var length := 0.0
	for i in range(1, path.size()): length += path[i - 1].distance_to(path[i])
	return length

func _test_visibility_search() -> void:
	var corners := PackedVector2Array([Vector2(3, -2), Vector2(7, -2), Vector2(3, 2), Vector2(7, 2)])
	# Value-only visibility oracle: any edge crossing x=5 at |y|<1 is blocked.
	var clear := func(a: Vector2, b: Vector2) -> bool:
		if a.x == b.x: return true
		var t := (5.0 - a.x) / (b.x - a.x)
		return t <= 0 or t >= 1 or absf(a.lerp(b, t).y) >= 1.0
	for origin in [Vector2(0, -4), Vector2(0, 0), Vector2(0, 4)]:
		for target in [Vector2(10, -4), Vector2(10, 0), Vector2(10, 4)]:
			var graph := _graph(corners)
			var path := Kernel.corner_path(origin, target, graph, clear)
			var reverse := Kernel.corner_path(target, origin, graph, clear, true)
			check(not path.is_empty() and path[0] == origin and path[-1] == target, "corner_endpoints_%s_%s" % [origin, target])
			check(reverse[0] == origin and reverse[-1] == target, "reverse_search_preserves_route_direction_%s_%s" % [origin, target])
			check(is_equal_approx(_length(path), _full_graph_distance(origin, target, corners, clear)), "lazy_corner_matches_independent_dijkstra_%s_%s" % [origin, target])
			for i in range(1, path.size()): check(clear.call(path[i - 1], path[i]), "corner_safe_segment_%s_%s_%d" % [origin, target, i])

# Independent exhaustive graph + Dijkstra oracle, no lazy caches or heuristic.
func _full_graph_distance(origin: Vector2, target: Vector2, corners: PackedVector2Array, clear: Callable) -> float:
	var points := PackedVector2Array([origin, target])
	points.append_array(corners)
	var distances := PackedFloat64Array()
	distances.resize(points.size())
	distances.fill(INF)
	distances[0] = 0
	var visited := {}
	for iteration in points.size():
		var current := -1
		for i in points.size():
			if not visited.has(i) and (current < 0 or distances[i] < distances[current]): current = i
		if current < 0: break
		visited[current] = true
		for next in points.size():
			if visited.has(next) or not clear.call(points[current], points[next]): continue
			distances[next] = minf(distances[next], distances[current] + points[current].distance_to(points[next]))
	return distances[1]

func _test_negative_visibility_cache() -> void:
	var origin := Vector2.ZERO
	var corners := PackedVector2Array([Vector2(3, -2), Vector2(7, -2), Vector2(3, 2), Vector2(7, 2)])
	var graph := _graph(corners)
	var clear := func(a: Vector2, b: Vector2) -> bool:
		if a == origin and corners.has(b): origin_corner_sweeps += 1
		return false
	for i in 80:
		check(Kernel.corner_path(origin, Vector2(10, i), graph, clear).is_empty(), "negative_cached_origin_%d" % i)
	check(origin_corner_sweeps == corners.size(), "negative_origin_attachment_cached_across_targets_and_eviction")
	check(graph.attachments.size() <= 64, "visibility_attachment_cache_bounded")

func _test_range_approaches() -> void:
	var footprints: Array[Rect2] = [Rect2(Vector2(-20, -20), Vector2(40, 40))]
	var approaches := Kernel.range_approaches(Vector2(-100, 5), Vector2.ZERO, 32, 12, footprints)
	var previous := -1.0
	for point in approaches:
		check(point.distance_to(Vector2.ZERO) <= 32.251, "range_candidate_within_contact_tolerance")
		var distance := point.distance_squared_to(Vector2(-100, 5))
		check(distance >= previous, "range_candidates_nearest_first")
		previous = distance
	check(approaches.any(func(point: Vector2) -> bool: return is_equal_approx(point.x, -32.05)), "range_includes_exact_footprint_side")

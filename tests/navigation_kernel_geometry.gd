extends "res://tests/navigation_dense_poc.gd"

func _run() -> void:
	_test_endpoint_negative_cache()
	_test_endpoint_body_owner_keys()
	_test_mobile_visibility_invalidation()
	_test_distant_herd_preserves_visibility()
	_test_local_edge_entry_and_exit()
	_test_mobile_corner_candidates()
	print("NAVIGATION_KERNEL_GEOMETRY checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)

func _test_endpoint_negative_cache() -> void:
	var game := fixture()
	var nav := game.navigation
	var unit := game.spawn_unit(Vector2(300, 300))
	var tree := resource(game, unit.position, 10)
	nav._ensure_current()
	for i in 100:
		check(nav._obstacle_corner_path(unit.position, Vector2(600, i + 300), unit).is_empty(), "overlapped_endpoint_rejects_before_graph_%d" % i)
	check(nav.corner_graphs.is_empty(), "negative_endpoint_never_builds_corner_graph")
	var key := nav._grid_key(unit)
	check(nav.geometry_cache.corner_endpoint_validity[key].size() == 1, "negative_origin_stops_target_visibility_work")
	var previous := tree.position
	tree.position += Vector2(200, 200)
	nav.resource_moved(tree, previous)
	nav._ensure_current()
	var path := nav._obstacle_corner_path(unit.position, Vector2(600, 300), unit)
	check(not path.is_empty() and safe_route(game, unit, path), "static_resource_motion_invalidates_negative_endpoint")
	for i in 100: nav._corner_endpoint_clear(Vector2(600, i + 200), unit, key)
	check(nav.geometry_cache.corner_endpoint_validity[key].size() <= nav.MAX_CORNER_ATTACHMENTS, "endpoint_validation_cache_bounded")
	game.free()

func _test_endpoint_body_owner_keys() -> void:
	var game := fixture()
	var nav := game.navigation
	var unit := game.spawn_unit(Vector2(300, 300))
	var gate := building(game, unit.position, Vector2(40, 40))
	gate.kind = "palisade_gate"
	gate.build_remaining = 0
	nav.refresh()
	check(nav._corner_endpoint_clear(unit.position, unit, nav._grid_key(unit)), "friendly_gate_endpoint_accepted")
	unit.owner_id = 1
	check(not nav._corner_endpoint_clear(unit.position, unit, nav._grid_key(unit)), "hostile_gate_uses_distinct_owner_endpoint_cache")
	unit.owner_id = 0
	game.buildings.erase(gate)
	gate.free()
	var tree := resource(game, unit.position + Vector2(25, 0), 10)
	unit.stats["radius"] = 12
	nav.refresh()
	check(nav._corner_endpoint_clear(unit.position, unit, nav._grid_key(unit)), "small_body_endpoint_accepted")
	unit.stats["radius"] = 20
	check(not nav._corner_endpoint_clear(unit.position, unit, nav._grid_key(unit)), "larger_body_uses_distinct_radius_endpoint_cache")
	game.free()

func _test_mobile_visibility_invalidation() -> void:
	var game := fixture()
	var nav := game.navigation
	var unit := game.spawn_unit(Vector2(300, 300))
	var goal := Vector2(600, 300)
	var deer := resource(game, Vector2(450, 450), 10)
	deer.appearance = "deer"
	deer.wildlife_hp = 12
	nav._ensure_current()
	var revision := nav.obstacle_revision
	var retry_revision := nav.retry_obstacle_revision
	var key := nav._grid_key(unit)
	var path := nav._obstacle_corner_path(unit.position, goal, unit)
	check(not path.is_empty(), "mobile_open_origin_creates_visibility")
	var previous := deer.position
	deer.position = unit.position
	nav.resource_moved(deer, previous)
	check(nav.corner_graphs.has(key) and not nav.geometry_cache.corner_endpoint_validity[key].has(unit.position) and nav.geometry_cache.corner_endpoint_validity[key].has(goal), "wildlife_motion_invalidates_local_endpoint_and_preserves_distant_cache")
	check(nav.obstacle_revision == revision and nav.retry_obstacle_revision == retry_revision, "wildlife_visibility_invalidation_does_not_wake_routes_or_rebuild_grids")
	path = nav._obstacle_corner_path(unit.position, goal, unit)
	check(path.is_empty() and nav.corner_graphs.has(key), "wildlife_entering_endpoint_invalidates_positive_cache_without_rebuilding_graph")
	previous = deer.position
	deer.position = Vector2(450, 450)
	nav.resource_moved(deer, previous)
	path = nav._obstacle_corner_path(unit.position, goal, unit)
	check(not path.is_empty() and safe_route(game, unit, path), "wildlife_leaving_endpoint_invalidates_negative_cache")
	game.free()

func _test_distant_herd_preserves_visibility() -> void:
	var game := fixture()
	var nav := game.navigation
	var unit := game.spawn_unit(Vector2(300, 300))
	building(game, Vector2(500, 300), Vector2(50, 100))
	var herd: Array[RtsResource] = []
	for i in 20:
		var deer := resource(game, Vector2(1000 + i * 10, 800), 8)
		deer.appearance = "deer"
		deer.wildlife_hp = 12
		herd.append(deer)
	nav._ensure_current()
	var goal := Vector2(700, 300)
	var path := nav._obstacle_corner_path(unit.position, goal, unit)
	check(not path.is_empty() and safe_route(game, unit, path), "herd_warm_route_safe")
	var key := nav._grid_key(unit)
	var graph: Dictionary = nav.corner_graphs[key]
	var edges: Dictionary = graph.edges.duplicate(true)
	var attachments: Dictionary = graph.attachments.duplicate(true)
	var endpoints: Dictionary = nav.geometry_cache.corner_endpoint_validity[key].duplicate(true)
	var points: PackedVector2Array = graph.points.duplicate()
	check(not edges.is_empty() and not attachments.is_empty(), "herd_case_warms_actual_visibility_work")
	for step in 30:
		for deer in herd:
			var previous := deer.position
			deer.position += Vector2(0.5, -0.25)
			nav.resource_moved(deer, previous)
	check(is_same(graph, nav.corner_graphs[key]) and graph.points == points, "distant_herd_preserves_corner_graph_and_points")
	check(graph.edges == edges and graph.attachments == attachments, "distant_herd_preserves_positive_and_negative_visibility_work")
	check(nav.geometry_cache.corner_endpoint_validity[key] == endpoints, "distant_herd_preserves_endpoint_checks")
	path = nav._obstacle_corner_path(unit.position, goal, unit)
	check(not path.is_empty() and safe_route(game, unit, path), "distant_herd_route_stays_safe")
	game.free()

func _test_local_edge_entry_and_exit() -> void:
	var game := fixture()
	var nav := game.navigation
	var unit := game.spawn_unit(Vector2(300, 300))
	var deer := resource(game, Vector2(450, 450), 10)
	deer.appearance = "deer"
	deer.wildlife_hp = 12
	nav._ensure_current()
	var key := nav._grid_key(unit)
	var graph := {"points": PackedVector2Array([Vector2(400, 300), Vector2(500, 300)]),
		"edges": {Vector2i(2, 3): true}, "attachments": {Vector2(300, 300): {2: true, 3: true}},
		"visibility_bounds": Rect2(300, 300, 300, 0)}
	nav.corner_graphs[key] = graph
	var previous := deer.position
	deer.position = Vector2(450, 300)
	nav.resource_moved(deer, previous)
	check(not graph.edges.has(Vector2i(2, 3)) and not graph.attachments[Vector2(300, 300)].has(3), "animal_entry_invalidates_intersecting_positive_edges")
	check(graph.attachments[Vector2(300, 300)].has(2), "animal_entry_preserves_unaffected_nearby_edge")
	check(not nav._static_segment_clear(graph.points[0], graph.points[1], unit.radius(), unit, false), "animal_entry_strict_edge_blocks")
	graph.edges[Vector2i(2, 3)] = false
	graph.attachments[Vector2(300, 300)][3] = false
	previous = deer.position
	deer.position = Vector2(450, 450)
	nav.resource_moved(deer, previous)
	check(not graph.edges.has(Vector2i(2, 3)) and not graph.attachments[Vector2(300, 300)].has(3), "animal_exit_invalidates_intersecting_negative_edges")
	check(nav._static_segment_clear(graph.points[0], graph.points[1], unit.radius(), unit, false), "animal_exit_strict_edge_reopens")
	game.free()

func _test_mobile_corner_candidates()-> void:
	var game := fixture()
	var nav := game.navigation
	var unit := game.spawn_unit(Vector2(300, 300))
	var wall := building(game, Vector2(500, 300), Vector2(50, 100))
	var candidate := wall.position - wall.size() * 0.5 - Vector2.ONE * (unit.radius() + 0.05)
	var deer := resource(game, candidate, 10)
	deer.appearance = "deer"
	deer.wildlife_hp = 12
	nav._ensure_current()
	var path := nav._obstacle_corner_path(unit.position, Vector2(700, 300), unit)
	var key := nav._grid_key(unit)
	check(nav.corner_graphs[key].points.has(candidate), "corner_candidates_depend_on_static_geometry_even_under_animal")
	check(not nav._static_segment_clear(candidate, candidate, unit.radius(), unit, false), "stable_corner_candidate_still_requires_live_strict_sweep")
	var graph: Dictionary = nav.corner_graphs[key]
	var previous := deer.position
	deer.position = Vector2(1000, 800)
	nav.resource_moved(deer, previous)
	check(is_same(graph, nav.corner_graphs[key]) and graph.points.has(candidate), "animal_exit_preserves_previously_occupied_corner_candidate")
	path = nav._obstacle_corner_path(unit.position, Vector2(700, 300), unit)
	check(not path.is_empty() and safe_route(game, unit, path), "animal_exit_recovers_safe_route_without_rebuilding_candidates")
	game.free()

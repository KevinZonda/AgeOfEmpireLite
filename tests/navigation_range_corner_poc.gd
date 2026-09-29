extends "res://tests/navigation_dense_poc.gd"

class CountedNavigation extends RtsNavigation:
	var origin: Vector2
	var origin_sweeps := 0
	func _static_segment_clear(from: Vector2, to: Vector2, radius: float, unit: RtsUnit, allow_resource_escape := true, boarding := false) -> bool:
		if from == origin and to.x < 550 and not allow_resource_escape: origin_sweeps += 1
		return super._static_segment_clear(from, to, radius, unit, allow_resource_escape, boarding)

func _run() -> void:
	var game := fixture()
	var nav := CountedNavigation.new(game, game.world_map)
	game.navigation = nav
	var mover := game.spawn_unit(Vector2(300, 300))
	nav.origin = mover.position
	var walls := []
	walls.append(building(game, Vector2(240, 300), Vector2(20, 140)))
	walls.append(building(game, Vector2(360, 300), Vector2(20, 140)))
	walls.append(building(game, Vector2(300, 240), Vector2(140, 20)))
	walls.append(building(game, Vector2(300, 360), Vector2(140, 20)))
	var started := Time.get_ticks_usec()
	var first_sweeps := 0
	for i in 40:
		check(nav._obstacle_corner_path(mover.position, Vector2(600, 200 + i), mover).is_empty(), "sealed_origin_stays_unreachable")
		if i == 0: first_sweeps = nav.origin_sweeps
	print("RANGE_CORNER_POC ", JSON.stringify({"us": Time.get_ticks_usec() - started, "sweeps": nav.origin_sweeps, "first_sweeps": first_sweeps}))
	check(first_sweeps > 0 and nav.origin_sweeps == first_sweeps, "range_candidates_reuse_origin_visibility")
	game.buildings.erase(walls[1])
	walls[1].free()
	nav.refresh()
	var path := nav._obstacle_corner_path(mover.position, Vector2(600, 300), mover)
	check(not path.is_empty() and safe_route(game, mover, path), "opening_wall_invalidates_negative_attachments")
	# This is the real siege's expensive failure: strict corner sweeps cannot
	# leave an existing resource overlap, regardless of how many goals we try.
	resource(game, mover.position + Vector2(8, 0), 22)
	nav.refresh()
	check(nav._obstacle_corner_path(mover.position, Vector2(600, 300), mover).is_empty(), "strict_corner_fallback_rejects_overlapped_origin")
	check(nav.corner_graphs.is_empty(), "invalid_endpoint_does_not_build_world_corner_graph")
	# Normal routing must still escape the overlap outward.
	path = nav.path_between(mover.position, mover.position - Vector2(100, 0), mover)
	# The corral's west wall blocks that endpoint; a direct short escape stays
	# inside the open pocket and must retain the existing escape predicate.
	check(nav._static_segment_clear(mover.position, mover.position - Vector2(15, 0), mover.radius(), mover), "ordinary_resource_overlap_escape_is_preserved")
	game.free()
	print("NAVIGATION_RANGE_CORNER_POC checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)

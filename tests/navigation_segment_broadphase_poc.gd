extends "res://tests/navigation_dense_poc.gd"

class BucketReference extends RtsNavigation:
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

func _run() -> void:
	var game := fixture()
	game.world_map.free()
	game.initialize(Vector2(3200, 2400))
	for i in 6: building(game, Vector2(1400 + i * 100, 2200), Vector2(70, 65))
	var rng := RandomNumberGenerator.new()
	rng.seed = 66572
	for i in 150: resource(game, Vector2(rng.randf_range(800, 3000), rng.randf_range(600, 2200)), 12.3 if i < 8 else 22.0)
	var mover := game.spawn_unit(Vector2(100, 100))
	var reference := BucketReference.new(game, game.world_map)
	var times := []
	for nav in [reference, game.navigation]:
		var started := Time.get_ticks_usec()
		for i in 100: nav._static_segment_clear(Vector2(100, 100), Vector2(2900, 200), 12.0, mover)
		times.append(Time.get_ticks_usec() - started)
	print("SEGMENT_BROADPHASE_POC ", JSON.stringify({"bucket_us": times[0], "adaptive_us": times[1], "requests": 100, "buildings": 6, "resources": 150}))
	var mismatch := 0
	var clear_cases := 0
	var blocked_cases := 0
	for i in 1200:
		var radius := float([10.0, 12.3, 28.0][i % 3])
		mover.stats["radius"] = radius
		var from := Vector2(rng.randf_range(radius, 3200 - radius), rng.randf_range(radius, 2400 - radius))
		var to := Vector2(rng.randf_range(radius, 3200 - radius), rng.randf_range(radius, 2400 - radius))
		if i % 2 == 0: to = from + Vector2(rng.randf_range(-40, 40), rng.randf_range(-40, 40))
		mover.position = from
		for escape in [false, true]:
			var expected := reference._static_segment_clear(from, to, radius, mover, escape)
			var actual := game.navigation._static_segment_clear(from, to, radius, mover, escape)
			if expected != actual: mismatch += 1
			if expected: clear_cases += 1
			else: blocked_cases += 1
	check(mismatch == 0, "adaptive_broadphase_matches_bucket_reference", "comparisons=2400 mismatches=%d" % mismatch)
	check(clear_cases > 20 and blocked_cases > 20, "oracle_exercises_clear_and_blocked_segments")
	game.free()
	print("NAVIGATION_SEGMENT_BROADPHASE_POC checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)

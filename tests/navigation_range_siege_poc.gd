extends "res://tools/battle_deer_poc.gd"

# A frozen capture of the real six-building siege, queried identically before
# and after the fix. Separates initial path planning from movement/scheduling.
class MeasuredNavigation extends RtsNavigation:
	var measured := {}
	func _init(owner_game, map) -> void:
		super(owner_game, map)
	func record(name: String, start: int) -> void:
		var elapsed := Time.get_ticks_usec() - start
		if not measured.has(name): measured[name] = {"calls": 0, "us": 0, "max_us": 0}
		measured[name].calls += 1
		measured[name].us += elapsed
		measured[name].max_us = maxi(measured[name].max_us, elapsed)
	func _components_for(grid: AStarGrid2D, cache := true) -> PackedInt32Array:
		var started := Time.get_ticks_usec()
		var result := super._components_for(grid, cache)
		record("components", started)
		return result
	func _obstacle_corner_path(from: Vector2, to: Vector2, unit: RtsUnit) -> PackedVector2Array:
		var started := Time.get_ticks_usec()
		var result := super._obstacle_corner_path(from, to, unit)
		record("corners", started)
		return result
	func _fine_grid_for(unit: RtsUnit) -> AStarGrid2D:
		var started := Time.get_ticks_usec()
		var result := super._fine_grid_for(unit)
		record("fine_grid", started)
		return result

func _run() -> void:
	await super._run()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.navigation.background_jobs.shutdown()
	game.navigation = MeasuredNavigation.new(game, game.world_map)
	var times := []
	var paths := []
	var unsafe := 0
	for unit in attackers:
		var reach: float = float(unit.stats["range"]) + maxf(forts[0].size().x, forts[0].size().y) * 0.5 + unit.radius() + 3.0
		var started := Time.get_ticks_usec()
		var path: PackedVector2Array = game.navigation.path_to_range(unit.position, forts[0].position, reach, unit)
		times.append((Time.get_ticks_usec() - started) / 1000.0)
		paths.append(str(path))
		for i in range(1, path.size()):
			if not game.navigation._static_segment_clear(path[i - 1], path[i], unit.radius(), unit): unsafe += 1
		if not path.is_empty() and path[-1].distance_to(forts[0].position) > reach + 0.5: unsafe += 1
	print("RANGE_SIEGE_PROFILE ", JSON.stringify({"timings_ms": times, "paths": paths, "unsafe": unsafe, "costs": game.navigation.measured}))
	print("NAVIGATION_RANGE_SIEGE_POC_OK" if unsafe == 0 else "POC_FAIL unsafe_route")
	quit(0 if unsafe == 0 else 1)

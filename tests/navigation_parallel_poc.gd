extends SceneTree

# Execute the production recovery code on exclusive, detached scene copies.
# This isolates scaling without concurrently touching any live game nodes.
# Snapshot construction is included separately; these clones are a diagnostic
# adapter, not a proposed per-frame production architecture.
const Fixture = preload("res://tests/helpers/navigation_fixture.gd")
const REQUESTS := 80

class Lane extends RefCounted:
	var game: Node2D
	var first: int
	var stride: int
	var results := {}
	var elapsed_us := 0
	var worker_id := 0
	var mode: String

	func _init(index: int, count: int, job_mode: String) -> void:
		first = index
		stride = count
		mode = job_mode
		if mode == "arithmetic_control": return
		game = Fixture.new()
		game.initialize(Vector2(3200, 2400))
		var rng := RandomNumberGenerator.new()
		rng.seed = 4242
		for i in game.world_map.cells.size():
			if rng.randf() < 0.08: game.world_map.cells[i] = RtsWorldMap.Terrain.WATER
		# The siege courtyard is dry; surrounding terrain still needs rasterization.
		for y in range(16, 33):
			for x in range(24, 41): game.world_map.cells[y * game.world_map.grid_size.x + x] = RtsWorldMap.Terrain.GRASS
		for i in 6:
			var fort := RtsBuilding.new()
			fort.game = game
			fort.kind = "house"
			fort.stats = {"size": Vector2(90, 90)}
			fort.position = Vector2(1600 + (i % 3 - 1) * 155, 1200 + (i / 3 - 0.5) * 170)
			game.add_child(fort)
			game.buildings.append(fort)
		for i in 150:
			var resource := RtsResource.new()
			resource.position = Vector2(rng.randf_range(50, 3150), rng.randf_range(50, 2350))
			if i < 8:
				resource.appearance = "deer"
				resource.position = Vector2(1880 + (i % 4) * 28, 1380 + (i / 4) * 32)
			resource.radius = 12.0 if i < 8 else 22.0
			game.add_child(resource)
			game.resources.append(resource)
		for i in REQUESTS:
			var point := Vector2(1600, 1200) + Vector2.from_angle(TAU * (i % 16) / 16.0) * (330 + (i / 16) * 27)
			var unit: RtsUnit = game.spawn_unit(point)
			unit.owner_id = 1
			unit.route_failures = 3
		game.navigation.refresh()

	func run() -> void:
		worker_id = OS.get_thread_caller_id()
		var started := Time.get_ticks_usec()
		for index in range(first, REQUESTS, stride):
			if mode == "arithmetic_control":
				var checksum := index + 1
				for iteration in 20000: checksum = (checksum * 1664525 + 1013904223) & 0x7fffffff
				results[index] = checksum
				continue
			var unit: RtsUnit = game.units[index]
			if mode == "grid":
				var grid: AStarGrid2D = game.navigation._local_unit_grid(unit, 2, 96)
				# Compare all occupancy bits after timing the job, not just path existence.
				results[index] = grid
			else:
				results[index] = game.navigation._local_unit_path(unit, Vector2(1375, 1115), 2, 96)
		elapsed_us = Time.get_ticks_usec() - started

	func dispose() -> void:
		if game != null: game.free()

var lanes: Array[Lane] = []
var failures := 0
var high_priority := OS.get_environment("RTS_PARALLEL_HIGH_PRIORITY") == "1"

func _initialize() -> void:
	call_deferred("_run")

func _execute_lane(index: int) -> void:
	lanes[index].run()

func _run() -> void:
	Engine.max_fps = 120
	var report := []
	for mode in ["arithmetic_control", "grid", "recovery"]:
		var reference := {}
		for pass_index in 2:
			for workers in ([0, 1, 2, 4] if pass_index == 0 else [4, 2, 1, 0]):
				var built := Time.get_ticks_usec()
				lanes.clear()
				for i in maxi(1, workers): lanes.append(Lane.new(i, maxi(1, workers), mode))
				var snapshot_us := Time.get_ticks_usec() - built
				var started := Time.get_ticks_usec()
				if workers == 0: _execute_lane(0)
				else:
					var task := WorkerThreadPool.add_group_task(_execute_lane, workers, workers, high_priority)
					WorkerThreadPool.wait_for_group_task_completion(task)
				var elapsed := Time.get_ticks_usec() - started
				var signatures := _signatures(mode)
				if reference.is_empty(): reference = signatures
				if reference != signatures: failures += 1
				report.append({"mode": mode, "pass": pass_index + 1, "workers": workers, "worker_ids": lanes.map(func(lane: Lane): return lane.worker_id), "snapshot_ms": snapshot_us / 1000.0, "batch_ms": elapsed / 1000.0, "matches_serial": reference == signatures})
				if mode == "recovery":
					var successful := signatures.values().filter(func(path: PackedVector2Array): return path.size() >= 2).size()
					report[-1]["successful_routes"] = successful
					if successful == 0: failures += 1
				print("PARALLEL_PROGRESS ", JSON.stringify(report[-1]))
				for lane in lanes: lane.dispose()
		# The same four workers, but the main loop polls completion across frames.
		lanes.clear()
		for i in 4: lanes.append(Lane.new(i, 4, mode))
		var started := Time.get_ticks_usec()
		var task := WorkerThreadPool.add_group_task(_execute_lane, 4, 4, high_priority)
		var submitted_us := Time.get_ticks_usec() - started
		var ticks := 0
		var last_tick := started
		var maximum_gap := 0
		while not WorkerThreadPool.is_group_task_completed(task):
			await process_frame
			ticks += 1
			var now := Time.get_ticks_usec()
			maximum_gap = maxi(maximum_gap, now - last_tick)
			last_tick = now
		WorkerThreadPool.wait_for_group_task_completion(task)
		var elapsed := Time.get_ticks_usec() - started
		var signatures := _signatures(mode)
		if reference != signatures: failures += 1
		report.append({"mode": mode, "workers": 4, "async": true, "batch_ms": elapsed / 1000.0, "main_submit_ms": submitted_us / 1000.0, "main_loop_ticks": ticks, "max_main_tick_gap_ms": maximum_gap / 1000.0, "matches_serial": reference == signatures})
		for lane in lanes: lane.dispose()
	lanes.clear()
	print("NAVIGATION_PARALLEL_POC ", JSON.stringify({"requests": REQUESTS, "buildings": 6, "deer": 8, "high_priority": high_priority, "failures": failures, "runs": report}))
	quit(0 if failures == 0 else 1)

func _signatures(mode: String) -> Dictionary:
	var result := {}
	for lane in lanes:
		for index in lane.results:
			if mode == "grid":
				var grid: AStarGrid2D = lane.results[index]
				var bits := PackedByteArray()
				bits.resize(grid.region.size.x * grid.region.size.y)
				for y in grid.region.size.y:
					for x in grid.region.size.x: bits[y * grid.region.size.x + x] = int(grid.is_point_solid(Vector2i(x, y)))
				result[index] = bits
			else: result[index] = lane.results[index]
	return result

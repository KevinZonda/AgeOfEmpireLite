extends "res://tests/navigation_construction_poc.gd"

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game("English", 4242)
	game.ai_controllers.clear()
	game.set_process(false)
	if OS.get_environment("RTS_TASKS_DENSE_ONLY") == "1":
		_test_dense_build_queue()
		for voice in game.feedback_audio.voices:
			voice.stop()
			voice.stream = null
		game.free()
		print("NAVIGATION_TASKS_POC checks=%d failures=%d" % [checks, failures])
		quit(1 if failures else 0)
		return
	_test_repair_queue()
	_test_dense_build_queue()
	_test_farm_workers()
	_test_trade_round_trip()
	_test_deleted_queued_target()
	_test_sealed_jobs_resume()
	for voice in game.feedback_audio.voices:
		voice.stop()
		voice.stream = null
	game.free()
	print("NAVIGATION_TASKS_POC checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)

func _test_repair_queue() -> void:
	for kind in ["farm", "blacksmith", "monastery", "keep", "wonder"]:
		reset()
		var unit := worker(Vector2(350, 350))
		var target: RtsBuilding = game.spawn_building(0, kind, Vector2(700, 550))
		target.set_process(false)
		target.hp -= 24
		unit.issue_command("repair", Vector2.INF, target)
		unit.issue_command("move", Vector2(350, 650), null, true)
		tick([unit], 650)
		check(target.hp == target.max_hp, kind + "_repair_completes", "hp=%.1f/%.1f pos=%s" % [target.hp, target.max_hp, unit.position])
		check(unit.order == "idle" and unit.command_queue.is_empty() and unit.position.distance_to(Vector2(350, 650)) < 7,
			kind + "_repair_queue_advances", unit.order)

func _test_dense_build_queue() -> void:
	for count in [1, 12, 48, 96]:
		if OS.get_environment("RTS_TASKS_COUNT") != "" and count != int(OS.get_environment("RTS_TASKS_COUNT")): continue
		reset()
		game.navigation.reset_profile()
		var units: Array[RtsUnit] = []
		var sites: Array[RtsBuilding] = []
		# Twelve independent lanes, 8 sites per lane; 96 buildings, up to 768
		# queued construction jobs. Every site has physically open approaches.
		for lane in 12:
			for col in 8:
				var site: RtsBuilding = game.spawn_building(0, "house", Vector2(550 + col * 100, 200 + lane * 90), true)
				site.set_process(false)
				sites.append(site)
		for i in count:
			var lane: int = i % 12
			var unit := worker(Vector2(200 + (i / 12) * 40, 200 + lane * 90))
			units.append(unit)
			for col in 8: unit.issue_command("build", Vector2.INF, sites[lane * 8 + col], col > 0)
			unit.issue_command("move", Vector2(1550 + (i / 12) * 40, 200 + lane * 90), null, true)
		var start := Time.get_ticks_usec()
		tick(units, 2600)
		var expected := mini(count, 12) * 8
		var completed := sites.filter(func(b: RtsBuilding) -> bool: return b.is_complete()).size()
		# Finished allies may step aside for a later arrival. Verify completion
		# and the exit side, not permanent ownership of an exact parking spot.
		var arrived := units.filter(func(u: RtsUnit) -> bool: return u.order == "idle" and u.command_queue.is_empty() and u.position.x > 1450).size()
		check(completed == expected, "dense_%d_workers_build_all" % count, "%d/%d in %.2fs" % [completed, expected, (Time.get_ticks_usec() - start) / 1e6])
		check(arrived == count, "dense_%d_workers_finish_queues" % count, "%d/%d" % [arrived, count])
		if arrived < count:
			for u in units:
				if u.order != "idle": print("STUCK order=%s pos=%s goal=%s queue=%d route=%s" % [u.order, u.position, u.destination, u.command_queue.size(), u.route])
		check(max_step <= units[0].effective_speed() * 0.05 + 0.01, "dense_%d_workers_no_teleport" % count)
		if game.navigation.profiling_enabled: print("DENSE_PROFILE ", JSON.stringify(game.navigation.profile_snapshot()))

func _test_farm_workers() -> void:
	for count in [1, 4, 8]:
		reset()
		var units: Array[RtsUnit] = []
		for i in count:
			var direction := Vector2.from_angle((i + 0.5) * TAU / 8)
			var farm: RtsBuilding = game.spawn_building(0, "farm", Vector2(800, 800) + direction * 160)
			farm.set_process(false)
			var unit := worker(farm.position + direction * 230)
			unit.issue_command("gather", Vector2.INF, farm)
			units.append(unit)
		tick(units, 600)
		var arrived := units.filter(func(u: RtsUnit) -> bool: return is_instance_valid(u.target) and u.position.distance_to(u.target.position) <= 27.5 + u.radius() + 2.5).size()
		check(arrived == count, "farm_%d_workers_use_assigned_farms" % count, "%d working" % arrived)

func _test_trade_round_trip() -> void:
	reset()
	var market: RtsBuilding = game.spawn_building(0, "market", Vector2(800, 600))
	var post := RtsTradePost.new()
	post.position = Vector2(1300, 700)
	game.add_child(post)
	post.set_process(false)
	game.trade_posts.append(post)
	var trader: RtsUnit = game.spawn_unit(0, "trader", Vector2(1100, 500))
	trader.set_process(false)
	trader.engagement = "passive"
	trader.issue_command("trade", Vector2.INF, post)
	var trips := 0
	for step in 1200:
		var returning := trader.trade_returning
		tick([trader], 1)
		if returning != trader.trade_returning: trips += 1
	check(trader.trade_home == market and trips >= 4, "trader_completes_multiple_round_trips", "legs=%d pos=%s" % [trips, trader.position])

func _test_deleted_queued_target() -> void:
	reset()
	var unit := worker(Vector2(300, 300))
	unit.issue_command("move", Vector2(500, 300))
	var gone: RtsBuilding = game.spawn_building(0, "house", Vector2(700, 500), true)
	unit.issue_command("build", Vector2.INF, gone, true)
	unit.issue_command("move", Vector2(500, 600), null, true)
	game.buildings.erase(gone)
	gone.free()
	game.navigation.invalidate_obstacles()
	tick([unit], 400)
	check(unit.order == "idle" and unit.position.distance_to(Vector2(500, 600)) < 7, "deleted_queued_build_is_skipped")

func _test_sealed_jobs_resume() -> void:
	reset()
	var barrier: RtsBuilding = game.spawn_building(0, "house", Vector2(800, 1200))
	barrier.position = Vector2(800, 1200)
	barrier.stats["size"] = Vector2(50, 2400)
	barrier.set_process(false)
	var units: Array[RtsUnit] = []
	var targets: Array[RtsBuilding] = []
	for i in 12:
		var target: RtsBuilding = game.spawn_building(0, "blacksmith", Vector2(1150, 300 + i * 100))
		target.set_process(false)
		target.hp -= 24
		targets.append(target)
		var unit := worker(Vector2(350, 300 + i * 100))
		unit.issue_command("repair", Vector2.INF, target)
		unit.issue_command("move", unit.position, null, true)
		units.append(unit)
	game.navigation.invalidate_obstacles()
	tick(units, 100)
	check(units.all(func(u: RtsUnit) -> bool: return u.position.x < 775 and u.command_queue.size() == 1), "sealed_jobs_wait_and_preserve_queues")
	check(targets.all(func(b: RtsBuilding) -> bool: return b.hp == b.max_hp - 24), "sealed_jobs_do_not_work_through_barrier")
	game.buildings.erase(barrier)
	barrier.free()
	game.navigation.invalidate_obstacles()
	tick(units, 1000)
	check(targets.all(func(b: RtsBuilding) -> bool: return b.hp == b.max_hp), "demolition_wakes_all_repair_jobs")
	check(units.all(func(u: RtsUnit) -> bool: return u.order == "idle" and u.command_queue.is_empty() and u.position.x < 400), "demolition_all_queues_finish")

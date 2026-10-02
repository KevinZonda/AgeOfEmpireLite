extends "res://poc/exploration-2026-10-02/explore.gd"

func _run() -> void:
	for id in ["supervise_town_center", "supervise_barracks"]:
		setup_case()
		await run_case(id)
		assert(results.back().status == "pass", "Official must supervise from a reachable position: " + id)
		game.navigation.shutdown_jobs()
		game.queue_free()
		await process_frame
	setup_case()
	game.civilizations[0] = "Chinese"
	var building: RtsBuilding = game.spawn_building(0, "barracks", free_site("barracks"))
	var official := soldier("imperial_official", 0, building.position + Vector2(120, 0))
	official.issue_command("supervise", Vector2.INF, building)
	assert(game.train_unit(building, "spearman"))
	building.supervise_scan_timer = 0.0
	building._process(0.01)
	assert(is_equal_approx(building.supervise_work_rate, 1.0))
	official.position = building.position + Vector2(building.supervise_distance(official), 0)
	assert(game.navigation.can_occupy(official.position, official.radius(), official, false))
	building.supervise_scan_timer = 0.0
	building._process(0.01)
	assert(is_equal_approx(building.supervise_work_rate, 1.5))
	official.position.x += 2.0
	building.supervise_scan_timer = 0.0
	building._process(0.01)
	assert(is_equal_approx(building.supervise_work_rate, 1.0))
	official.order_stop()
	var controller := RtsAiController.new(game, 0)
	controller._assign_official(official)
	assert(official.order == "supervise" and official.target == building)
	tick_units([official], 100)
	building.supervise_scan_timer = 0.0
	building._process(0.01)
	assert(is_equal_approx(building.supervise_work_rate, 1.5))
	game.navigation.shutdown_jobs()
	game.queue_free()
	await process_frame
	print("EXPLORATION_B06_OK")
	quit()

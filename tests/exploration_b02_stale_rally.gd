extends "res://poc/exploration-2026-10-02/explore.gd"

func _run() -> void:
	for id in ["rally_dead_fish", "rally_dead_tree", "rally_dead_farm", "rally_queued_target"]:
		setup_case()
		await run_case(id)
		assert(results.back().id == id and results.back().status == "pass", "Training must survive expired rally targets: " + id)
		game.navigation.shutdown_jobs()
		game.queue_free()
		await process_frame
	setup_case()
	var center: RtsBuilding = game._player_center(0)
	var tree: RtsResource = game.find_nearest_resource(center.position, "wood", INF, 0)
	center.rally_point = tree.position
	center.rally_target = tree
	center.rally_resource_kind = "wood"
	assert(game.train_unit(center, "villager"))
	assert(game.train_unit(center, "villager"))
	tree.queue_free()
	await process_frame
	var before: int = game.units.size()
	center._process(100.0)
	assert(game.units.size() == before + 1 and center.rally_target == null)
	assert(game.units.back().order in ["gather", "move"])
	center._process(100.0)
	assert(game.units.size() == before + 2 and center.production_queue.is_empty())
	game.navigation.shutdown_jobs()
	game.queue_free()
	await process_frame
	print("EXPLORATION_B02_OK")
	quit()

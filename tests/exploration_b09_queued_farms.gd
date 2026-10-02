extends "res://poc/exploration-2026-10-02/explore.gd"

func _run() -> void:
	for id in ["queued_farm_frees_later", "queued_farm_alternative", "farm_exclusive", "queued_invalid_target"]:
		setup_case()
		await run_case(id)
		assert(results.back().status == "pass", "Queued farm intent must survive admission: " + id)
		game.navigation.shutdown_jobs()
		game.queue_free()
		await process_frame
	setup_case()
	var farm: RtsBuilding = game.spawn_building(0, "farm", free_site("farm"))
	var first := soldier("villager", 0, farm.position + Vector2(70, 0))
	first.order_gather(farm)
	var next := soldier("villager", 0, farm.position + Vector2(-300, 0))
	next.issue_command("move", farm.position + Vector2(-200, 0))
	next.issue_command("gather", Vector2.INF, farm, true)
	next.issue_command("move", farm.position + Vector2(-220, 40), null, true)
	assert(next.command_queue.size() == 2)
	# A still-busy farm with no alternative skips safely to the next order.
	next._advance_command()
	assert(next.order == "move" and next.command_queue.is_empty() and first.target == farm)
	var foreign: RtsBuilding = game.spawn_building(1, "farm", free_site("farm", farm.position + Vector2(400, 0)))
	next.issue_command("gather", Vector2.INF, foreign, true)
	assert(next.command_queue.is_empty())
	game.navigation.shutdown_jobs()
	game.queue_free()
	await process_frame
	print("EXPLORATION_B09_OK")
	quit()

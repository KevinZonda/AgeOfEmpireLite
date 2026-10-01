extends "res://poc/exploration-2026-10-02/explore.gd"

func _run() -> void:
	for id in ["construction_damage", "construction_zero", "construction_repair", "construction_completion_damage", "construction_real_worker"]:
		setup_case()
		await run_case(id)
		assert(results.back().id == id and results.back().status == "pass", "Construction must preserve damage: " + id)
		game.navigation.shutdown_jobs()
		game.queue_free()
		await process_frame
	setup_case()
	var house: RtsBuilding = game.spawn_building(0, "house", free_site("house"), true)
	var before: float = house.hp
	var remaining: float = house.build_remaining
	house.advance_construction(-1.0)
	assert(is_equal_approx(house.hp, before) and is_equal_approx(house.build_remaining, remaining))
	# Overshooting the completion time cannot grant extra health.
	house.take_damage(20.0)
	house.advance_construction(remaining + 100.0)
	assert(house.is_complete() and is_equal_approx(house.hp, house.max_hp - 20.0))
	house.advance_construction(100.0)
	assert(is_equal_approx(house.hp, house.max_hp - 20.0))
	var fresh: RtsBuilding = game.spawn_building(0, "house", free_site("house"), true)
	fresh.advance_construction(fresh.build_remaining)
	assert(fresh.is_complete() and is_equal_approx(fresh.hp, fresh.max_hp))
	game.navigation.shutdown_jobs()
	game.queue_free()
	await process_frame
	print("EXPLORATION_B04_OK")
	quit()

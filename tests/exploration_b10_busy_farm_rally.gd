extends "res://poc/exploration-2026-10-02/explore.gd"

func _run() -> void:
	setup_case()
	var center: RtsBuilding = game._player_center(0)
	var farm: RtsBuilding = game.spawn_building(0, "farm", free_site("farm", center.position + Vector2(200, 0)))
	var farmer := soldier("villager", 0, farm.position + Vector2(65, 0))
	farmer.order_gather(farm)
	center.rally_point = farm.position
	center.rally_target = farm
	assert(game.train_unit(center, "villager"))
	center._process(100.0)
	var trained: RtsUnit = game.units.back()
	assert(trained.order == "move" and game.farm_worker(farm, trained) == farmer)
	assert(game.navigation.can_occupy(trained.destination, trained.radius(), trained, false))
	tick_units([trained], 600)
	assert(trained.order == "idle" and trained.position.distance_to(trained.destination) < 8.0)
	# A farm with no worker still assigns the new villager normally.
	farmer.order_stop()
	assert(game.train_unit(center, "villager"))
	center._process(100.0)
	assert(game.units.back().order == "gather" and game.units.back().target == farm)
	game.navigation.shutdown_jobs()
	game.queue_free()
	await process_frame
	print("EXPLORATION_B10_OK")
	quit()

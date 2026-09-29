extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game("English", 44127, "French")
	var farm: RtsBuilding = game.spawn_building(0, "farm", Vector2(900, 700))
	assert(farm.farm_stage == "sowing" and is_zero_approx(farm.farm_crop_fraction()))
	assert(farm.work_farm(1.1, 1.0, 72) == 0)
	assert(is_equal_approx(farm.farm_crop_fraction(), 0.5), "half-sown farm should show half its crop rows")
	var paused_progress := farm.farm_stage_progress
	await process_frame
	assert(is_equal_approx(farm.farm_stage_progress, paused_progress), "work must pause without a farmer")
	assert(farm.work_farm(1.1, 1.0, 72) == 0)
	assert(farm.farm_stage == "harvesting" and is_equal_approx(farm.farm_crop_fraction(), 1.0), "sown farm should show all crop rows")
	assert(farm.work_farm(2.2, 1.0, 72) == 36)
	assert(is_equal_approx(farm.farm_crop_fraction(), 0.5), "harvesting should remove crop rows")
	assert(farm.work_farm(2.2, 1.0, 72) == 36)
	assert(farm.farm_stage == "sowing" and is_zero_approx(farm.farm_crop_fraction()), "harvest should leave an empty field")
	assert(farm.work_farm(1.1, 2.0, 54) == 0 and farm.farm_stage == "harvesting", "work speed should shorten sowing")
	assert(farm.work_farm(2.2, 2.0, 54) == 54 and farm.farm_stage == "sowing", "work speed should shorten harvesting")
	var working_farm: RtsBuilding = game.spawn_building(0, "farm", Vector2(1020, 700))
	var worker: RtsUnit = game.spawn_unit(0, "villager", working_farm.position + Vector2(48, 0))
	worker.position = working_farm.position + Vector2(48, 0)
	worker.order_gather(working_farm)
	assert(is_equal_approx(worker.gathering_per_second(), 72.0 / 6.6))
	var food_before: int = game.players[0]["food"]
	worker._process_gather_order(1.1)
	assert(game.players[0]["food"] == food_before and is_equal_approx(working_farm.farm_crop_fraction(), 0.5))
	game.selected.clear()
	game.selected.append(working_farm)
	game._update_hud()
	assert(game.queue_label.text.contains("播种 50%") and game.queue_label.text.contains("速度") and game.detail_label.text.contains("收获 4.4 工作量"))
	worker._process_gather_order(1.1)
	assert(working_farm.farm_stage == "harvesting" and game.players[0]["food"] == food_before)
	worker._process_gather_order(4.4)
	assert(game.players[0]["food"] == food_before + 72 and working_farm.farm_stage == "sowing", "villager harvest should credit one crop")
	var base_speed := worker.farm_work_speed()
	game.spawn_building(0, "mill", working_farm.position + Vector2(0, 100))
	assert(is_equal_approx(worker.farm_work_speed(), base_speed * 1.15), "nearby mill should speed both phases")
	game.players[0]["researched"].append("horticulture")
	assert(is_equal_approx(worker.farm_work_speed(), base_speed * 1.15 * 1.15), "food technology should speed both phases")
	worker.order_stop()
	assert(game.farm_worker(working_farm) == null and is_zero_approx(working_farm.farm_stage_progress))
	game.free()
	await process_frame
	print("FARM_CYCLE_OK")
	quit()

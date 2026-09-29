extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game("English", 12345)
	game.players[0]["food"] = 1000
	var center: RtsBuilding = game._player_center(0)
	var initial_count: int = game.units.size()
	if not game.train_unit(center, "villager") or not game.train_unit(center, "villager"):
		_fail("two villagers should both enter the queue")
		return
	if center.production_queue.size() != 2 or center.queued_unit_count("villager") != 2:
		_fail("two jobs should be queued")
		return
	var duration: float = center._training_time("villager")
	center._process(duration + 0.01)
	if game.units.size() != initial_count + 1 or center.production_queue.size() != 1 or center.production_remaining <= 0.0:
		_fail("first villager should finish and second should start")
		return
	center._process(duration + 0.01)
	if game.units.size() != initial_count + 2 or not center.production_queue.is_empty() or center.queued_unit_count() != 0:
		_fail("second villager should finish")
		return
	var barracks: RtsBuilding = game.spawn_building(0, "barracks", center.position + Vector2(0, -180))
	game.players[0]["age"] = 2
	game.selected.clear()
	game.selected.append(barracks)
	game._rebuild_actions()
	var train_button: RtsCommandButton
	for button in game.command_buttons:
		if button.icon_kind == "spearman":
			train_button = button
			break
	if train_button == null or train_button.disabled:
		_fail("spearman training button should be available")
		return
	initial_count = game.units.size()
	train_button.pressed.emit()
	train_button.pressed.emit()
	if barracks.production_queue.size() != 2:
		_fail("two button presses should queue two spearmen")
		return
	var remaining_before: float = barracks.production_remaining
	for frame in 10:
		await process_frame
	if barracks.production_remaining >= remaining_before:
		_fail("training should progress during normal game frames")
		return
	duration = barracks._training_time("spearman")
	barracks._process(duration + 0.01)
	if game.units.size() != initial_count + 1 or barracks.production_queue.size() != 1:
		_fail("first spearman should finish and second should remain queued")
		return
	remaining_before = barracks.production_remaining
	for frame in 10:
		await process_frame
	if barracks.production_remaining >= remaining_before:
		_fail("second spearman should progress during normal game frames")
		return
	barracks._process(duration + 0.01)
	if game.units.size() != initial_count + 2 or not barracks.production_queue.is_empty():
		_fail("second spearman should finish")
		return
	if not _test_mixed_queue(game, barracks) or not _test_official_limit(game):
		_fail("mixed queue or official limit regression failed")
		return
	game.free()
	print("PRODUCTION_QUEUE_REGRESSION_OK")
	quit()

func _test_mixed_queue(game: Node2D, barracks: RtsBuilding) -> bool:
	for resource in ["food", "wood", "gold", "stone"]: game.players[0][resource] = 10000
	game.spawn_building(0, "house", barracks.position + Vector2(-180, 0))
	var population_before: int = game.population_used(0)
	var second: RtsBuilding = game.spawn_building(0, "barracks", barracks.position + Vector2(180, 0))
	assert(game.train_unit(barracks, "spearman"))
	assert(game.research_technology(barracks, "forged_weapons"))
	assert(game.train_unit(barracks, "spearman"))
	assert(barracks.queued_unit_count() == 2 and barracks.queued_unit_count("villager") == 0)
	assert(barracks.queued_research_ids() == ["forged_weapons"])
	assert(game.population_used(0) == population_before + 2, "research should reserve no population")
	assert(not game.research_technology(second, "forged_weapons"), "queued research should block duplicates across buildings")
	barracks._process(1.0)
	var remaining: float = barracks.production_remaining
	var gold_before: int = game.players[0]["gold"]
	assert(game.cancel_production_job(barracks, 1))
	assert(game.players[0]["gold"] == gold_before + RtsTechTree.get_technology("forged_weapons")["cost"]["gold"])
	assert(barracks.production_remaining == remaining, "canceling a waiting job should preserve active progress")
	assert(game.queued_research(0).is_empty())
	assert(game.cancel_production_job(barracks, 1))
	assert(game.population_used(0) == population_before + 1, "canceling one duplicate unit should release exactly its population")
	assert(barracks.queued_unit_count("spearman") == 1)
	assert(game.research_technology(barracks, "forged_weapons"), "canceled research should be available again")
	assert(game.train_unit(barracks, "spearman"))
	assert(game.cancel_production_job(barracks, 0))
	assert(barracks.current_job()["type"] == "research")
	assert(barracks.production_remaining == RtsTechTree.get_technology("forged_weapons")["time"], "canceling the active job should start the next at full duration")
	assert(game.population_used(0) == population_before + 1)
	var unit_count: int = game.units.size()
	barracks._process(barracks.production_remaining + 0.01)
	assert(game.units.size() == unit_count and game.players[0]["researched"].has("forged_weapons"))
	assert(game.queued_research(0).is_empty() and barracks.queued_unit_count() == 1)
	barracks._process(barracks.production_remaining + 0.01)
	assert(game.units.size() == unit_count + 1 and barracks.production_queue.is_empty())
	assert(game.population_used(0) == population_before + 1, "finishing training should replace reserved population with the spawned unit")
	game.players[0]["age"] = 3
	var siege: RtsBuilding = game.spawn_building(0, "siege_workshop", barracks.position + Vector2(180, 180))
	assert(game.train_unit(siege, "mangonel"))
	assert(siege.queued_population_cost() == RtsBalanceData.population_cost("mangonel"), "queue accounting should preserve unit-specific population costs")
	assert(game.population_used(0) == population_before + 1 + RtsBalanceData.population_cost("mangonel"))
	assert(game.cancel_production_job(siege))
	assert(not game.cancel_production_job(siege), "canceling an empty queue should fail")
	return true

func _test_official_limit(game: Node2D) -> bool:
	game.start_game("Chinese", 12345)
	for resource in ["food", "wood", "gold", "stone"]: game.players[0][resource] = 10000
	var first: RtsBuilding = game._player_center(0)
	var second: RtsBuilding = game.spawn_building(0, "town_center", first.position + Vector2(250, 0))
	var officials := 0
	for unit in game.units:
		if unit.owner_id == 0 and unit.kind == "imperial_official": officials += 1
	for index in 4 - officials:
		assert(game.train_unit(first if index % 2 == 0 else second, "imperial_official"))
	assert(not game.train_unit(second, "imperial_official"), "official limit should include queues in every producer")
	assert(game.cancel_production_job(first))
	assert(game.train_unit(second, "imperial_official"), "canceling an official should release its reserved slot")
	return true

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

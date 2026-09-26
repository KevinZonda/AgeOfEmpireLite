extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	assert(RtsTechTree.trainable_units("Chinese", 2, "archery_range") == ["archer"])
	assert(RtsTechTree.trainable_units("Chinese", 2, "archery_range", [], "Song").has("zhuge_nu"))
	assert(RtsTechTree.trainable_units("Chinese", 3, "barracks").has("palace_guard"))
	assert(not RtsTechTree.can_train("English", 2, "archery_range", "zhuge_nu"))
	assert(not RtsTechTree.can_train("Chinese", 2, "archery_range", "longbow"))
	var game: Variant = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game("Chinese", 4242, "English")
	assert(game.civilizations == ["Chinese", "English"])
	assert(RtsLandmarkCatalog.choices_for("Chinese", 1).size() == 2)
	assert(game.advance_age(0, "zh_imperial_academy"), "China should be able to build its first age II landmark")
	var first: RtsBuilding = game.buildings.back()
	assert(first.landmark_id == "zh_imperial_academy")
	first.advance_construction(100.0)
	assert(game.players[0]["age"] == 2 and game.players[0]["dynasty"] == "")
	assert(RtsLandmarkCatalog.choice_status("Chinese", 2, game.players[0]["landmarks"], "zh_barbican")["available"])
	var archery: RtsBuilding = game.spawn_building(0, "archery_range", Vector2(700, 700))
	assert(not game.train_unit(archery, "zhuge_nu"))
	assert(game.train_unit(archery, "archer"))
	game.credit_resource(0, "food", 700)
	game.credit_resource(0, "gold", 500)
	assert(game.construct_landmark(0, "zh_barbican"), "China should be able to build a second age II landmark")
	var second: RtsBuilding = game.buildings.back()
	second.advance_construction(100.0)
	assert(game.players[0]["age"] == 2 and game.players[0]["dynasty"] == "Song")
	assert(game.train_unit(archery, "zhuge_nu"))
	assert(is_equal_approx(game._player_center(0)._training_time("villager"), RtsBalanceData.training_seconds("villager") * 0.8))
	assert(not RtsLandmarkCatalog.choice_status("Chinese", 2, game.players[0]["landmarks"], "zh_barbican")["available"])
	var palace_guard: RtsUnit = game.spawn_unit(0, "palace_guard", Vector2(700, 800))
	var base_speed: float = palace_guard.stats["speed"]
	game.complete_age(0, 3, "zh_clocktower")
	assert(game.players[0]["age"] == 3 and game.players[0]["dynasty"] == "Song")
	base_speed = palace_guard.stats["speed"]
	game.complete_age(0, 3, "zh_imperial_palace")
	assert(game.players[0]["age"] == 3 and game.players[0]["dynasty"] == "Yuan")
	assert(palace_guard.stats["speed"] == base_speed + 8.0)
	assert(is_equal_approx(game._player_center(0)._training_time("villager"), RtsBalanceData.training_seconds("villager")))
	game.complete_age(0, 4, "zh_gatehouse")
	game.complete_age(0, 4, "zh_spirit_way")
	assert(game.players[0]["dynasty"] == "Ming" and palace_guard.stats["speed"] == base_speed)
	assert(palace_guard.stats["hp"] >= GameData.UNITS["palace_guard"]["hp"] + 15.0)
	var worker: RtsUnit = game.units[0]
	var house: RtsBuilding = game.spawn_building(0, "house", Vector2(700, 900), true)
	worker.position = house.position + Vector2(40, 0)
	worker.order_build(house)
	var remaining := house.build_remaining
	worker._process(1.0)
	assert(is_equal_approx(house.build_remaining, remaining - 1.15), "Chinese villagers should construct 15% faster")
	game.start_game("English", 4242, "Chinese")
	assert(game.civilizations[1] == "Chinese")
	game.complete_age(1, 2, "zh_imperial_academy")
	var ai_archery: RtsBuilding = game.spawn_building(1, "archery_range", Vector2(1750, 700))
	game.ai.tick()
	assert(ai_archery.training_queue.has("archer"), "Chinese AI should train archers before unlocking Song")
	var dynasty_landmark_started := false
	for building in game.buildings:
		if building.owner_id == 1 and building.kind == "landmark" and building.landmark_id == "zh_barbican": dynasty_landmark_started = true
	assert(dynasty_landmark_started, "Chinese AI should start its second landmark when it can afford a dynasty")
	print("CHINESE_OK")
	quit()

extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for map_seed in [431, 73, 4242]:
		var game: Node2D = load("res://scenes/main.tscn").instantiate()
		root.add_child(game)
		await process_frame
		game.process_mode = Node.PROCESS_MODE_DISABLED
		game.start_game("English", map_seed, "French")
		game.ai_controllers.clear()
		game.players[1]["age"] = 4
		for resource in ["food", "wood", "gold", "stone"]: game.players[1][resource] = 10000
		for unit in game.units: unit.order_stop()
		var base: Vector2 = game.spawn_point_for(1)
		var stable_point := Vector2.INF
		for radius in [200.0, 270.0, 340.0]:
			for step in 16:
				var point: Vector2 = base + Vector2.from_angle(TAU * float(step) / 16.0) * radius
				if game.can_place("stable", point):
					stable_point = point
					break
			if stable_point != Vector2.INF: break
		assert(stable_point != Vector2.INF)
		var stable: RtsBuilding = game.spawn_building(1, "stable", stable_point)
		var bank_before: Dictionary = game.players[1].duplicate()
		game.ai._economy._construct_french_keep()
		var keep: RtsBuilding
		for building in game.buildings:
			if building.owner_id == 1 and building.kind == "keep":
				assert(keep == null, "one AI construction attempt places exactly one keep")
				keep = building
		assert(keep != null, "a valid influential keep site exists for this seed")
		assert(keep.position == game.snap_build_point("keep", keep.position))
		assert(keep.position.distance_to(stable.position) <= 180.0, "the final grid center must be within French influence")
		assert(game.count_builders(keep) > 0 and not keep.is_complete(), "the AI actually assigns construction instead of directly spawning a finished keep")
		for resource in GameData.BUILDINGS["keep"]["cost"]:
			assert(game.players[1][resource] == bank_before[resource] - GameData.BUILDINGS["keep"]["cost"][resource], "the legal placement is charged exactly once")
		assert(not RtsCivilizationRules.french_keep_influence(game, stable), "unfinished keeps must not grant the discount")
		keep.advance_construction(100.0)
		assert(RtsCivilizationRules.french_keep_influence(game, stable))
		var actual_cost := RtsCivilizationRules.training_cost(game, stable, "royal_knight")
		var expected_cost := RtsCivilizationRules.discounted_training_cost("royal_knight", 0.8)
		assert(actual_cost == expected_cost, "the completed snapped placement really activates the intended training discount")
		game.free()
		await process_frame
	print("EXPLORATION_B18_FRENCH_KEEP_GRID_OK")
	quit()

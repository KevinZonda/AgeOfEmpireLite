extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.match_mode = "team2"
	game.start_game("English", 431, "French")
	game.ai_controllers.clear()
	game.view_mode_25d = false
	for unit in game.units:
		unit.position = game.spawn_point_for(unit.owner_id)
		unit.order_stop()
	var point: Vector2 = game.world_map.stealth_patches[0]["position"]
	# A small forest makes the near/far scout checks independent of the rule
	# that an observer inside the same forest can also detect its occupants.
	game.world_map.stealth_patches.clear()
	game.world_map.stealth_patches.append({"position": point, "radius": 20.0})
	var sight: RtsBuilding = game.spawn_building(0, "outpost", point + Vector2(180, 0))
	var ally: RtsUnit = game.spawn_unit(2, "spearman", point)
	ally.position = point
	game.fog.update_visibility()
	assert(game.fog.can_detect_unit(0, ally) and ally.visible, "allied forest occupants are visible through shared vision")
	ally.position = game.spawn_point_for(2)
	var enemy: RtsUnit = game.spawn_unit(1, "spearman", point)
	enemy.position = point
	game.fog.update_visibility()
	assert(game.fog.can_see(0, point), "terrain visibility alone is available")
	assert(not game.fog.can_detect_unit(0, enemy) and not enemy.visible, "terrain sight alone must not reveal a forest enemy")
	var scout: RtsUnit = game.spawn_unit(2, "scout", point + Vector2(145, 0))
	scout.position = point + Vector2(145, 0)
	game.fog.update_visibility()
	assert(game.fog.can_detect_unit(0, enemy) and enemy.visible, "an allied scout shares forest detection at the inclusive scout range")
	scout.position = point + Vector2(146, 0)
	game.fog.update_visibility()
	assert(not game.fog.can_detect_unit(0, enemy), "a scout outside detection range supplies terrain sight only")
	scout.position = point + Vector2(55, 0)
	scout.garrisoned_in = sight
	game.fog.update_visibility()
	assert(not game.fog.can_detect_unit(0, enemy), "garrisoned allies cannot detect concealed enemies")
	scout.garrisoned_in = null
	scout.owner_id = 1
	game.navigation.invalidate_spatial_index()
	game.fog.update_visibility()
	assert(not game.fog.can_detect_unit(0, enemy), "an enemy scout cannot grant detection")
	scout.owner_id = 0
	game.navigation.invalidate_spatial_index()
	game.fog.update_visibility()
	assert(game.fog.can_detect_unit(0, enemy), "the original own-scout behavior is preserved")
	scout.owner_id = 2
	game.navigation.invalidate_spatial_index()
	game.teams.clear()
	game.teams.append_array([0, 1, 2, 3])
	game.fog.update_visibility()
	assert(not game.fog.can_detect_unit(0, enemy), "FFA players do not share forest detection")
	game.free()
	print("EXPLORATION_B16_TEAM_DETECTION_OK")
	quit()

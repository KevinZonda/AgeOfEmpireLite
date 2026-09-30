extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game("English", 12345)
	var enemy: RtsUnit
	for unit in game.units:
		if unit.owner_id == 1:
			enemy = unit
			break
	var scout: RtsUnit = game.spawn_unit(0, "scout", enemy.position + Vector2(45, 0))
	game.fog.update_visibility()
	assert(game.fog.can_detect_unit(0, enemy))
	game._select_area(enemy.position, enemy.position, false)
	await process_frame
	assert(game.selected == [enemy])
	assert(game.info_label.text.begins_with("敌方 · "))
	assert(game.detail_label.text.contains("生命"))
	assert(game.detail_label.size.x >= 300, "unit details need enough width to wrap by line")
	assert(game.command_buttons.is_empty(), "enemy inspection must not expose commands")
	scout.position = game.spawn_point_for(0)
	game.fog.update_visibility()
	assert(game.selected.is_empty() and game.info_label.text == "未选择")
	var enemy_building: RtsBuilding = game._player_center(1)
	var building_id := enemy_building.get_instance_id()
	scout.position = enemy_building.position + Vector2(-75, 0)
	game.fog.update_visibility()
	assert(game.fog.can_see(0, enemy_building.position))
	game._select_area(enemy_building.position, enemy_building.position, false)
	await process_frame
	assert(game.selected == [enemy_building], "visible enemy buildings should be inspectable")
	assert(game.info_label.text.begins_with("敌方 · "))
	assert(game.detail_label.text.contains("生命"))
	assert(game.command_title.text == "敌方建筑 · 情报")
	assert(game.command_buttons.is_empty(), "enemy building inspection must not expose commands")
	scout.position = game.spawn_point_for(0)
	game.fog.update_visibility()
	var ghost: Node2D = game.fog.remembered_buildings[building_id]["ghost"]
	assert(not ghost is RtsBuilding, "building memory must use a display-only node")
	assert(not enemy_building.visible and ghost.visible, "last-known building should remain on the map")
	assert(game.selected.is_empty() and game.info_label.text == "未选择", "hidden building details must close immediately")
	assert(game._entity_at(enemy_building.position) == null, "building memory must not be clickable")
	game._select_area(enemy_building.position, enemy_building.position, false)
	assert(game.selected.is_empty(), "clicking building memory must not reveal current details")
	scout.position = enemy_building.position + Vector2(-75, 0)
	game.fog.update_visibility()
	game._select_area(enemy_building.position, enemy_building.position, false)
	assert(game.selected == [enemy_building], "regaining vision should allow inspection again")
	game.free()
	print("ENEMY_INSPECTION_OK")
	quit()

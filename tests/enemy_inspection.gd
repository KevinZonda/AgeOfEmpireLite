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
	print("ENEMY_INSPECTION_OK")
	quit()

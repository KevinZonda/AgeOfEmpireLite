extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game("English", 12345)
	var unit: RtsUnit
	for candidate in game.units:
		if candidate.owner_id == 0:
			unit = candidate
			break
	var building: RtsBuilding = game._player_center(0)
	assert(unit != null and building != null)
	assert(unit.hp == unit.max_hp and building.hp == building.max_hp)
	assert(unit.health_bar_timer == 0.0 and building.health_bar_timer == 0.0, "new entities should not count as health changes")

	game.health_bar_mode = "damaged"
	assert(not game.should_show_health_bar(unit.hp, unit.max_hp, unit.health_bar_timer))
	assert(not game.should_show_health_bar(building.hp, building.max_hp, building.health_bar_timer))
	unit.take_damage(5.0)
	building.take_damage(25.0)
	assert(game.should_show_health_bar(unit.hp, unit.max_hp, unit.health_bar_timer))
	assert(game.should_show_health_bar(building.hp, building.max_hp, building.health_bar_timer))
	unit.hp = unit.max_hp
	building.hp = building.max_hp
	assert(not game.should_show_health_bar(unit.hp, unit.max_hp, unit.health_bar_timer))
	assert(not game.should_show_health_bar(building.hp, building.max_hp, building.health_bar_timer))

	game.health_bar_mode = "changed"
	assert(game.should_show_health_bar(unit.hp, unit.max_hp, unit.health_bar_timer), "healing to full should briefly show the bar")
	assert(game.should_show_health_bar(building.hp, building.max_hp, building.health_bar_timer))
	unit._process(game.HEALTH_BAR_CHANGE_DURATION + 0.01)
	building._process(game.HEALTH_BAR_CHANGE_DURATION + 0.01)
	assert(not game.should_show_health_bar(unit.hp, unit.max_hp, unit.health_bar_timer))
	assert(not game.should_show_health_bar(building.hp, building.max_hp, building.health_bar_timer))

	game.health_bar_mode = "always"
	assert(game.should_show_health_bar(unit.hp, unit.max_hp, unit.health_bar_timer))
	assert(game.should_show_health_bar(building.hp, building.max_hp, building.health_bar_timer))
	game.free()
	print("HEALTH_BAR_VISIBILITY_OK")
	quit()

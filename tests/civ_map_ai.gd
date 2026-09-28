extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var french: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(french)
	await process_frame
	french.start_game("English", 431, "French")
	assert(french.ai._production_order()[0] == "stable", "French should open with cavalry on open ground")
	french.players[1]["wood"] = 100
	assert(french.ai._french_trade_resource() == "wood")
	french.players[1]["wood"] = 420
	french.players[1]["food"] = 100
	assert(french.ai._french_trade_resource() == "food")
	french.players[1]["food"] = 420
	assert(french.ai._french_trade_resource() == "gold")
	french.players[1]["age"] = 3
	french.players[1]["stone"] = 1000
	french.players[1]["wood"] = 1000
	var stable_point := Vector2.INF
	var base: Vector2 = french.spawn_point_for(1)
	for radius in [200.0, 270.0, 340.0]:
		for step in 16:
			var point: Vector2 = base + Vector2.from_angle(TAU * float(step) / 16.0) * radius
			if french.can_place("stable", point):
				stable_point = point
				break
		if stable_point != Vector2.INF: break
	assert(stable_point != Vector2.INF)
	var stable: RtsBuilding = french.spawn_building(1, "stable", stable_point)
	french.ai._economy._construct_french_keep()
	var keep: RtsBuilding
	for building in french.buildings:
		if building.owner_id == 1 and building.kind == "keep": keep = building
	assert(keep != null and keep.position.distance_to(stable.position) <= 180.0, "French AI should build within influence range of its stable")
	keep.advance_construction(100.0)
	assert(RtsCivilizationRules.french_keep_influence(french, stable))
	french.free()

	var chinese: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(chinese)
	await process_frame
	chinese.selected_map_style = "highlands"
	chinese.start_game("English", 431, "Chinese")
	assert(chinese.ai._production_order()[0] == "barracks", "Chinese should defend mountain passes with infantry")
	chinese.players[1]["age"] = 2
	chinese.players[1]["food"] = 1000
	chinese.players[1]["gold"] = 60
	chinese.ai.tick()
	assert(chinese.ai._unit_count("imperial_official") >= 1, "Chinese AI should train an official to use its economy")
	var official: RtsUnit = chinese.spawn_unit(1, "imperial_official", chinese.spawn_point_for(1) + Vector2(60, 0))
	chinese.ai._assign_official(official)
	assert(official.order == "supervise", "The first official should supervise a working production building")
	chinese.free()
	print("CIV_MAP_AI_OK")
	quit()

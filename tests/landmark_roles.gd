extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var french: Variant = load("res://scenes/main.tscn").instantiate()
	root.add_child(french)
	await process_frame
	french.start_game("French", 22334, "English")
	french.players[0]["age"] = 3
	french.players[0]["food"] = 3000
	french.players[0]["wood"] = 3000
	french.players[0]["gold"] = 3000
	var institute: RtsBuilding = french.spawn_building(0, "landmark", Vector2(710, 730), false, "fr_royal_institute")
	var base_cost: Dictionary = RtsTechTree.get_technology("ranged_attack_2")["cost"]
	var gold_before: int = french.players[0]["gold"]
	assert(french.research_technology(institute, "ranged_attack_2"))
	assert(gold_before - int(french.players[0]["gold"]) == ceili(float(base_cost["gold"]) * 0.5), "Royal Institute should charge its reduced research cost")
	var guild: RtsBuilding = french.spawn_building(0, "landmark", Vector2(850, 730), false, "fr_guild_hall")
	guild._process(4.1)
	assert(int(guild.landmark_stockpile["food"]) > 0)
	var food_before: int = french.players[0]["food"]
	assert(guild.collect_stockpile() and int(french.players[0]["food"]) > food_before)
	var college: RtsBuilding = french.spawn_building(0, "landmark", Vector2(950, 730), false, "fr_college_of_artillery")
	french.players[0]["age"] = 4
	var baseline: float = RtsStatResolver.unit("French", "trebuchet", 4)["hp"]
	assert(french.train_unit(college, "trebuchet"))
	college._process(college._training_time("trebuchet") + 1.0)
	var artillery: RtsUnit = french.units.back()
	assert(artillery.kind == "trebuchet" and artillery.max_hp > baseline, "College siege units should retain their producer bonus")
	var chinese: Variant = load("res://scenes/main.tscn").instantiate()
	root.add_child(chinese)
	await process_frame
	chinese.start_game("Chinese", 22334, "French")
	chinese.players[0]["age"] = 4
	chinese.players[0]["dynasty"] = "Ming"
	chinese.players[0]["food"] = 3000
	chinese.players[0]["wood"] = 3000
	chinese.players[0]["gold"] = 3000
	var clocktower: RtsBuilding = chinese.spawn_building(0, "landmark", Vector2(700, 730), false, "zh_clocktower")
	var base_ram: float = RtsStatResolver.unit("Chinese", "battering_ram", 4)["hp"]
	assert(chinese.train_unit(clocktower, "battering_ram"))
	clocktower._process(clocktower._training_time("battering_ram") + 1.0)
	assert(chinese.units.back().max_hp > base_ram)
	var gatehouse: RtsBuilding = chinese.spawn_building(0, "landmark", Vector2(900, 730), false, "zh_gatehouse")
	var wall: RtsBuilding = chinese.spawn_building(0, "stone_wall", gatehouse.position + Vector2(95, 0))
	wall.refresh_stats()
	assert(float(wall.stats["armor"]["melee"]) == float(GameData.BUILDINGS["stone_wall"]["armor"]["melee"]) + 4.0)
	var palace: RtsBuilding = chinese.spawn_building(0, "landmark", Vector2(1090, 730), false, "zh_imperial_palace")
	assert(palace.activate_landmark_ability() and palace.landmark_ability_cooldown > 0.0)
	assert(not palace.activate_landmark_ability())
	chinese.selected.clear()
	chinese.selected.append(palace)
	chinese._rebuild_actions()
	var spy_button: RtsCommandButton
	for button in chinese.command_buttons:
		if button.icon_kind == "spy": spy_button = button
	assert(spy_button != null and spy_button.disabled and spy_button.availability_reason.contains("冷却"))
	french.free()
	chinese.free()
	print("LANDMARK_ROLES_OK")
	quit()

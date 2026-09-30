extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Variant = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game("English", 44127, "French")
	assert(game.population_label.text == "%d/%d" % [game.population_used(0), game.population_cap(0)] and game.population_label.tooltip_text.contains("空余"), "population icon readout must show used/capacity and free slots")
	var worker: RtsUnit = game.units[0]
	worker.order_stop()
	game._update_hud()
	assert(not game.idle_villager_button.disabled and game.idle_villager_button.text.contains("1"))
	game.idle_villager_button.pressed.emit()
	assert(game.selected.size() == 1 and game.selected[0] == worker)
	var resource: RtsResource = game.find_nearest_resource(worker.position, "wood", INF, 0)
	worker.order_gather(resource)
	game._update_hud()
	assert(game.detail_label.text.get_slice("\n", 0).contains("工作速度") and game.detail_label.text.contains("/秒"), "gathering speed must be visible before combat stats in the compact details pane")
	assert(is_equal_approx(worker.gathering_per_second(), float(worker.gathering_amount()) / 1.1))
	var food_labels := {"berry": "浆果", "deer": "鹿肉", "sheep": "羊肉", "boar": "野猪肉", "fish": "鱼群"}
	for appearance in food_labels:
		var food: RtsResource = game.spawn_resource("food", worker.position + Vector2(30, 0), 200, appearance)
		if appearance == "sheep": food.claimed_by = worker.owner_id
		var collector: RtsUnit = game.spawn_unit(0, "fishing_boat", worker.position) if appearance == "fish" else worker
		game.selected.assign([collector])
		collector.order_gather(food)
		game._update_hud()
		var first_line: String = game.detail_label.text.get_slice("\n", 0)
		assert(first_line.contains(food_labels[appearance]))
		assert(first_line.contains("%.2f/秒" % collector.gathering_per_second()))
		food.free()
		if collector != worker: collector.free()
	game.selected.assign([worker])
	var farm: RtsBuilding = game.spawn_building(0, "farm", worker.position + Vector2(70, 0))
	worker.order_gather(farm)
	game._update_hud()
	assert(game.detail_label.text.begins_with("采集农田  ·  工作速度 %.2f/秒" % worker.gathering_per_second()))
	worker.order_stop()
	farm.free()
	game._update_hud()
	assert(game.detail_label.text.begins_with("未采集资源  ·  工作速度 0.00/秒"))
	assert(RtsCivilizationRules.building_cost("English", "farm")["wood"] < RtsCivilizationRules.building_cost("French", "farm")["wood"])
	var ram := RtsStatResolver.unit("English", "battering_ram", 3)
	var springald := RtsStatResolver.unit("English", "springald", 3)
	assert(is_equal_approx(float(ram["resistance"]["ranged"]), 0.95))
	assert(is_equal_approx(float(springald["resistance"]["ranged"]), 0.60))
	assert(RtsCombatRules.volley_damage(springald, RtsStatResolver.unit("English", "man_at_arms", 3), springald["profiles"][springald["primary_profile"]]) > RtsCombatRules.volley_damage(springald, RtsStatResolver.unit("English", "knight", 3), springald["profiles"][springald["primary_profile"]]))
	assert(RtsTechTree.can_train("French", 4, "siege_workshop", "cannon"))
	assert(RtsTechTree.can_train("English", 4, "siege_workshop", "bombard"))
	assert(RtsTechTree.can_train("Chinese", 4, "siege_workshop", "bombard"))
	assert(not RtsTechTree.can_train("French", 4, "siege_workshop", "bombard"))
	assert(RtsTechTree.can_train("Chinese", 3, "siege_workshop", "nest_of_bees"))
	assert(not game.world_map.stealth_patches.is_empty())
	var forest: Vector2 = game.world_map.stealth_patches[0]["position"]
	var enemy: RtsUnit = game.spawn_unit(1, "spearman", forest)
	var scout: RtsUnit = game.spawn_unit(0, "scout", forest + Vector2(230, 0))
	scout.position = enemy.position + Vector2(230, 0)
	game.fog.update_visibility()
	assert(game.fog.can_see(0, enemy.position) and not game.fog.can_detect_unit(0, enemy))
	scout.position = forest + Vector2(45, 0)
	game.fog.update_visibility()
	assert(game.fog.can_detect_unit(0, enemy))
	game.free()
	var chinese: Variant = load("res://scenes/main.tscn").instantiate()
	root.add_child(chinese)
	await process_frame
	chinese.start_game("Chinese", 44127, "English")
	var center: RtsBuilding = chinese._player_center(0)
	var official: RtsUnit = chinese.spawn_unit(0, "imperial_official", center.position + Vector2(80, 0))
	# Test tax collection from a legal point already inside collection range;
	# starting inside the center instead exercises foundation-overlap recovery.
	official.position = center.position + Vector2(center.size().x * 0.5 + official.radius() + 0.1, 0)
	center.tax_stockpile = 10
	var gold_before: int = chinese.players[0]["gold"]
	official.issue_command("collect_tax", Vector2.INF, center)
	official._process(0.2)
	assert(chinese.players[0]["gold"] == gold_before + 10 and center.tax_stockpile == 0)
	var gate: RtsBuilding = chinese.spawn_building(0, "stone_gate", Vector2(850, 760))
	var wall: RtsBuilding = chinese.spawn_building(0, "stone_wall", Vector2(916, 760))
	var archer: RtsUnit = chinese.spawn_unit(0, "archer", gate.position + Vector2(20, 0))
	assert(RtsSiegeRules.wall_entry(chinese, archer, wall) == gate)
	archer.issue_command("board_wall", Vector2.INF, wall)
	archer._process(0.2)
	assert(archer.wall_host == wall and archer.order == "wall")
	var gatehouse: RtsBuilding = chinese.spawn_building(0, "landmark", Vector2(1030, 760), false, "zh_gatehouse")
	assert(RtsCivilizationRules.wall_ranged_multiplier(chinese, archer) > 1.0)
	archer.order_move(Vector2(950, 860))
	assert(archer.wall_host == null)
	var enemy_wall: RtsBuilding = chinese.spawn_building(1, "stone_wall", Vector2(1130, 980))
	var tower: RtsUnit = chinese.spawn_unit(0, "siege_tower", enemy_wall.position + Vector2(70, 0))
	tower.order = "siege_tower_docked"
	assert(RtsSiegeRules.wall_entry(chinese, archer, enemy_wall) == tower)
	chinese.free()
	var french: Variant = load("res://scenes/main.tscn").instantiate()
	root.add_child(french)
	await process_frame
	french.start_game("French", 44127, "English")
	french.players[0]["age"] = 3
	var keep: RtsBuilding = french.spawn_building(0, "keep", Vector2(750, 710))
	var range_building: RtsBuilding = french.spawn_building(0, "archery_range", Vector2(900, 710))
	assert(RtsCivilizationRules.training_cost(french, range_building, "arbaletrier")["gold"] < GameData.unit_cost("arbaletrier")["gold"])
	var trader: RtsUnit = french.spawn_unit(0, "trader", Vector2(750, 820))
	french.selected.clear()
	french.selected.append(trader)
	french._rebuild_actions()
	var food_button: RtsCommandButton
	for button in french.command_buttons:
		if button.icon_kind == "food": food_button = button
	assert(food_button != null)
	food_button.pressed.emit()
	assert(trader.trade_resource_kind == "food")
	var chamber: RtsBuilding = french.spawn_building(0, "landmark", Vector2(1050, 850), false, "fr_chamber_of_commerce")
	assert(chamber.is_complete())
	var trader_count := 0
	for unit in french.units:
		if is_instance_valid(unit) and unit.owner_id == 0 and unit.kind == "trader": trader_count += 1
	french.complete_research(0, "horticulture")
	var new_trader_count := 0
	for unit in french.units:
		if is_instance_valid(unit) and unit.owner_id == 0 and unit.kind == "trader": new_trader_count += 1
	assert(new_trader_count == trader_count + 1)
	assert(RtsCivilizationRules.economic_gather_multiplier(french, 0, "food") > 1.0)
	french.players[0]["age"] = 4
	var college_cannon: RtsUnit = french.spawn_unit(0, "cannon", Vector2(1140, 850))
	var base_damage: float = float(college_cannon.stats["profiles"][college_cannon.stats["primary_profile"]]["damage"])
	college_cannon.producer_landmark_id = "fr_college_of_artillery"
	college_cannon.refresh_stats()
	assert(float(college_cannon.stats["profiles"][college_cannon.stats["primary_profile"]]["damage"]) > base_damage)
	assert(college_cannon.activate_ability("artillery_shot") and college_cannon.artillery_shot_ready)
	french.free()
	print("AOE4_REQUESTED_SYSTEMS_OK")
	quit()

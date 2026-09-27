extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for archived_kind in RtsBalanceData.document()["units"]: assert(GameData.UNITS.has(archived_kind))
	assert(int(GameData.unit_cost("royal_knight")["food"]) == 140 and int(GameData.unit_cost("royal_knight")["gold"]) == 100)
	assert(int(GameData.unit_cost("zhuge_nu")["food"]) == 30 and int(GameData.unit_cost("zhuge_nu")["wood"]) == 30 and int(GameData.unit_cost("zhuge_nu")["gold"]) == 20)
	var spear := RtsStatResolver.unit("English", "spearman", 2)
	assert(RtsStatResolver.unit("English", "scout", 2)["primary_profile"] == "melee", "scout bows are for hunting, not their default combat attack")
	var archer := RtsStatResolver.unit("Chinese", "archer", 2)
	var heavy := RtsStatResolver.unit("English", "man_at_arms", 3)
	var crossbow := RtsStatResolver.unit("English", "crossbowman", 3)
	assert(RtsCombatRules.volley_damage(archer, spear, archer["profiles"]["ranged"]) > RtsCombatRules.volley_damage(archer, heavy, archer["profiles"]["ranged"]), "bows should counter light melee infantry")
	assert(RtsCombatRules.volley_damage(crossbow, heavy, crossbow["profiles"]["ranged"]) > RtsCombatRules.volley_damage(crossbow, spear, crossbow["profiles"]["ranged"]), "crossbows should counter heavy units")
	var zhuge := RtsStatResolver.unit("Chinese", "zhuge_nu", 2)
	assert(zhuge["profiles"]["ranged"]["hits"] == 3)
	assert(RtsCombatRules.volley_damage(zhuge, heavy, zhuge["profiles"]["ranged"]) == 3.0, "armor should apply to each bolt")
	var ram := RtsStatResolver.unit("English", "battering_ram", 3)
	var normal_target: Dictionary = ram.duplicate(true)
	normal_target.erase("kind")
	assert(RtsCombatRules.profile_damage(spear, ram, spear["profiles"]["melee"]) > RtsCombatRules.profile_damage(spear, normal_target, spear["profiles"]["melee"]), "rams should take extra melee damage")
	var wall: Dictionary = GameData.BUILDINGS["stone_wall"].duplicate(true)
	assert(RtsCombatRules.volley_damage(ram, wall, ram["profiles"]["siege"]) >= 500.0)
	var trebuchet := RtsStatResolver.unit("English", "trebuchet", 3)
	assert(trebuchet["profiles"]["siege"]["min_range"] > 0.0 and trebuchet["profiles"]["siege"]["splash_radius"] > 0.0)
	assert(RtsTechTree.unit_status("Chinese", 2, "archery_range", "zhuge_nu")["reason"].contains("宋"))
	assert(RtsTechTree.unit_status("Chinese", 2, "archery_range", "zhuge_nu", [], "Song")["available"])
	assert(RtsTechTree.research_status("English", 3, "barracks", "rank_spearman_3")["available"])
	assert(not RtsTechTree.research_status("English", 4, "barracks", "rank_spearman_4")["available"])
	var veteran := RtsStatResolver.unit("English", "spearman", 3, ["rank_spearman_3"])
	assert(veteran["hp"] > spear["hp"] and veteran["rank_age"] == 3)
	var free_french := RtsStatResolver.unit("French", "royal_knight", 2, ["melee_attack_2"])
	var plain_french := RtsStatResolver.unit("French", "royal_knight", 2)
	assert(free_french["damage"] == plain_french["damage"] + 1.0)
	var game: Variant = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game("English", 13462, "French")
	game.players[0]["food"] = 3000
	game.players[0]["wood"] = 3000
	game.players[0]["gold"] = 3000
	var camp_site := Vector2.INF
	for y in range(600, 1050, 60):
		for x in range(600, 1050, 60):
			var candidate := Vector2(x, y)
			if game.can_place("scout_camp", candidate + Vector2(46, 0)):
				camp_site = candidate
				break
		if camp_site != Vector2.INF: break
	assert(camp_site != Vector2.INF)
	var scout: RtsUnit = game.spawn_unit(0, "scout", camp_site)
	var wood_before: int = game.players[0]["wood"]
	assert(scout.activate_ability("camp") and int(game.players[0]["wood"]) == wood_before - 25)
	assert(game.advance_age(0, "eng_council_hall"))
	var hall: RtsBuilding = game.buildings.back()
	hall.advance_construction(100.0)
	assert(hall.producer_kind() == "archery_range" and game.train_unit(hall, "longbow"))
	assert(hall._training_time("longbow") < RtsBalanceData.training_seconds("longbow"))
	game.players[0]["age"] = 3
	var smith: RtsBuilding = game.spawn_building(0, "blacksmith", Vector2(780, 720))
	assert(game.research_technology(smith, "ranged_attack_2"))
	smith._process(40.0)
	assert(game.players[0]["researched"].has("ranged_attack_2"))
	var longbow: RtsUnit = game.spawn_unit(0, "longbow", Vector2(800, 800))
	assert(longbow.activate_ability("palings") and longbow.is_braced())
	longbow.order_move(Vector2(850, 800))
	assert(not longbow.is_braced())
	game.selected.clear()
	game.selected.append(longbow)
	game._rebuild_actions()
	var volley_button: RtsCommandButton
	for button in game.command_buttons:
		if button.icon_kind == "volley": volley_button = button
	assert(volley_button != null and not volley_button.disabled)
	volley_button.pressed.emit()
	assert(longbow.volley_timer > 0.0)
	var warship: RtsUnit = game.spawn_unit(0, "warship", Vector2(1570, 1190))
	var boat_speed := warship.effective_speed()
	assert(warship.activate_ability("helmsman") and warship.effective_speed() > boat_speed)
	var monk: RtsUnit = game.spawn_unit(0, "monk", Vector2(840, 840))
	game.selected.clear()
	game.selected.append(monk)
	game._rebuild_actions()
	var convert_button: RtsCommandButton
	for button in game.command_buttons:
		if button.icon_kind == "convert": convert_button = button
	assert(convert_button != null and convert_button.disabled and convert_button.availability_reason.contains("圣物"))
	monk.carried_relic = game.relics[0]
	var convert_target: RtsUnit = game.spawn_unit(1, "spearman", monk.position + Vector2(55, 0))
	game._refresh_action_buttons()
	assert(not convert_button.disabled)
	convert_button.pressed.emit()
	monk._process(3.1)
	assert(convert_target.owner_id == 0 and monk.conversion_cooldown > 0.0, "relic conversion should change nearby enemy ownership")
	var french_game: Variant = load("res://scenes/main.tscn").instantiate()
	root.add_child(french_game)
	await process_frame
	french_game.start_game("French", 13462, "English")
	french_game.complete_age(0, 2, "fr_school_of_cavalry")
	assert(french_game.players[0]["researched"].has("melee_attack_2"))
	game.free()
	french_game.free()
	print("BALANCE_SYSTEM_OK")
	quit()

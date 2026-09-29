extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game("English", 7219)
	for kind in ["food", "wood", "gold", "stone"]: game.players[0][kind] = 10000
	game.players[0]["age"] = 3
	var worker: RtsUnit = game.units[0]
	var center: RtsBuilding = game._player_center(0)
	var house: RtsBuilding = game.spawn_building(0, "house", center.position + Vector2(150, 0))
	house.hp -= 35.0
	worker.position = house.position + Vector2(45, 0)
	worker.work_timer = 0.0
	worker.issue_command("repair", Vector2.INF, house)
	for step in 40:
		worker._process(0.1)
		if house.hp > house.max_hp - 35.0: break
	assert(house.hp > house.max_hp - 35.0)
	var resource: RtsResource = game.find_nearest_resource(center.position, "wood", INF, 0)
	worker.issue_command("gather", Vector2.INF, resource)
	worker.position = center.position + Vector2(50, 0)
	game.ring_town_bell(center)
	assert(worker.order == "garrison")
	worker._process(0.1)
	assert(worker.garrisoned_in == center)
	center.ungarrison_all(true)
	assert(worker.order == "gather" and worker.target == resource)
	var market: RtsBuilding = game.spawn_building(0, "market", center.position + Vector2(220, 160))
	var trader: RtsUnit = game.spawn_unit(0, "trader", market.position + Vector2(55, 0))
	var post: RtsTradePost = game.trade_posts[0]
	trader.issue_command("trade", Vector2.INF, post)
	trader.position = post.position
	var gold_before: int = game.players[0]["gold"]
	trader._process_trade_order(0.1)
	assert(game.players[0]["gold"] > gold_before)
	trader.position = market.position
	gold_before = game.players[0]["gold"]
	trader._process_trade_order(0.1)
	assert(game.players[0]["gold"] > gold_before)
	var first: RtsBuilding = game.spawn_building(0, "barracks", Vector2(620, 650))
	var second: RtsBuilding = game.spawn_building(0, "barracks", Vector2(750, 650))
	game.selected.assign([first, second])
	game._rebuild_actions()
	for button in game.command_buttons:
		if button.icon_kind == "spearman":
			button.pressed.emit()
			break
	assert(first.production_queue.size() == 1 and second.production_queue.size() == 1)
	var bind := InputEventKey.new()
	bind.keycode = KEY_1
	bind.ctrl_pressed = true
	game._handle_control_group(bind)
	game.selected.clear()
	var recall := InputEventKey.new()
	recall.keycode = KEY_1
	game._handle_control_group(recall)
	assert(game.selected.size() == 2)
	var infantry: RtsUnit = game.spawn_unit(0, "spearman", Vector2(900, 650))
	game.selected.assign([infantry])
	var siege_site: Vector2 = game.navigation.nearest_walkable_point(infantry.position + Vector2(50, 0), 20.0)
	assert(game.place_field_siege("battering_ram", siege_site))
	var ram: RtsUnit = game.units.back()
	assert(ram.kind == "battering_ram" and ram.field_build_remaining > 0.0)
	infantry.position = ram.position + Vector2(35, 0)
	infantry._process(1.0)
	assert(ram.field_build_remaining < ram.field_build_total)
	ram.field_build_remaining = 0.0
	assert(ram.garrison_unit(infantry))
	assert(ram.passengers.size() == 1 and infantry.garrisoned_in == ram)
	ram.ungarrison_all()
	assert(infantry.garrisoned_in == null)
	var enemy_wall: RtsBuilding = game.spawn_building(1, "stone_wall", Vector2(1300, 650))
	var tower: RtsUnit = game.spawn_unit(0, "siege_tower", enemy_wall.position + Vector2(75, 0))
	infantry.position = game.navigation.nearest_walkable_point(tower.position + Vector2(25, 0), infantry.radius(), infantry)
	assert(game.navigation.can_occupy(infantry.position, infantry.radius(), infantry, false, false))
	assert(tower.garrison_unit(infantry))
	tower.position = enemy_wall.position + Vector2(60, 0)
	tower.issue_command("assault_wall", Vector2.INF, enemy_wall)
	tower._process(0.1)
	assert(tower.order == "siege_tower_docked" and infantry.wall_host == enemy_wall)
	assert(RtsSiegeRules.wall_entry(game, infantry, enemy_wall) == enemy_wall)
	assert(RtsTechTree.can_train("English", 3, "dock", "springald_ship"))
	assert(RtsTechTree.can_train("English", 3, "dock", "incendiary_ship"))
	var siege: RtsUnit = game.spawn_unit(0, "mangonel", Vector2(1050, 750))
	var enemy: RtsUnit = game.spawn_unit(1, "spearman", Vector2(1150, 750))
	siege.position = enemy.position + Vector2(-180, 0)
	siege.attack_timer = 0.0
	siege.issue_command("attack_ground", enemy.position)
	siege._process_attack_ground(0.1)
	var shot: RtsProjectile
	for child in game.get_children():
		if child is RtsProjectile: shot = child
	assert(shot != null)
	var enemy_hp := enemy.hp
	shot._process(2.0)
	assert(enemy.hp < enemy_hp)
	var boar: RtsResource = game.spawn_resource("food", Vector2(1050, 650), 420, "boar")
	assert(boar.harvest(10) == 0)
	boar.take_damage(90.0)
	assert(boar.harvest(10) == 10)
	game.free()
	print("ECONOMY_SIEGE_CONTROLS_OK")
	quit()

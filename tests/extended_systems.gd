extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game("English", 6789)
	assert(game.trade_posts.size() == 2 and game.relics.size() == 3)
	var fish: RtsResource
	for resource in game.resources:
		if resource.appearance == "fish":
			fish = resource
			break
	assert(fish != null and game.world_map.is_navigable(fish.position))
	var boat: RtsUnit = game.spawn_unit(0, "fishing_boat", fish.position + Vector2(60, 0))
	assert(game.world_map.is_navigable(boat.position))
	boat.issue_command("gather", Vector2.INF, fish)
	assert(boat.order == "gather")
	var food_before: int = game.players[0]["food"]
	for step in 200:
		boat._process(0.1)
		if game.players[0]["food"] > food_before: break
	assert(game.players[0]["food"] > food_before, "fishing boat should harvest fish")
	var land_unit: RtsUnit = game.units[0]
	assert(not game.navigation.can_occupy(fish.position, land_unit.radius(), land_unit))
	var dock_point := Vector2.INF
	for y in range(950, 1400, 25):
		for x in range(520, 1080, 25):
			var candidate := Vector2(x, y)
			if game.can_place("dock", candidate):
				dock_point = candidate
				break
		if dock_point != Vector2.INF: break
	assert(dock_point != Vector2.INF, "there should be a buildable shore")
	game.players[0]["age"] = 3
	game.players[0]["wood"] = 2000
	game.players[0]["gold"] = 1000
	var workers: Array[RtsUnit] = [game.units[0]]
	game.selected.clear()
	game.selected.append(workers[0])
	game.build_page = 4
	game._rebuild_actions()
	assert(game.command_buttons[0].icon_kind == "market" and game.command_buttons[1].icon_kind == "dock" and game.command_buttons[2].icon_kind == "monastery")
	game.build_page = 0
	assert(game.place_building(0, "dock", dock_point, workers))
	var dock: RtsBuilding = game.buildings.back()
	dock.advance_construction(100.0)
	assert(game.train_unit(dock, "warship"))
	dock._process(100.0)
	assert(game.units.back().kind == "warship" and game.world_map.is_navigable(game.units.back().position))
	var market_point := Vector2(600, 780)
	assert(game.can_place("market", market_point))
	assert(game.place_building(0, "market", market_point, workers))
	var market: RtsBuilding = game.buildings.back()
	market.advance_construction(100.0)
	var trader: RtsUnit = game.spawn_unit(0, "trader", market.position + Vector2(80, 0))
	trader.issue_command("trade", Vector2.INF, game.trade_posts[0])
	assert(trader.order == "trade")
	trader.position = game.trade_posts[0].position
	trader._process(0.0)
	assert(trader.trade_returning)
	var gold_before: int = game.players[0]["gold"]
	trader.position = market.position + Vector2(45, 0)
	trader._process(0.0)
	assert(game.players[0]["gold"] > gold_before, "completed trade route should earn gold")
	var monastery_point := Vector2(680, 860)
	assert(game.can_place("monastery", monastery_point))
	assert(game.place_building(0, "monastery", monastery_point, workers))
	var monastery: RtsBuilding = game.buildings.back()
	monastery.advance_construction(100.0)
	var relic: RtsRelic = game.relics[0]
	var monk: RtsUnit = game.spawn_unit(0, "monk", relic.position + Vector2(45, 0))
	monk.issue_command("relic", Vector2.INF, relic)
	monk.position = relic.position
	monk._process(0.0)
	assert(monk.carried_relic == relic and monk.order == "deposit_relic")
	monk.position = monastery.position + Vector2(48, 0)
	monk._process(0.0)
	assert(relic.stored_in == monastery and monastery.relics.size() == 1)
	gold_before = game.players[0]["gold"]
	monastery._process(4.1)
	assert(game.players[0]["gold"] == gold_before + 12)
	var second_monk: RtsUnit = game.spawn_unit(0, "monk", game.objectives.sacred_sites[0]["position"])
	game.objectives._process(8.1)
	assert(game.objectives.sacred_sites[0]["owner_id"] == 0)
	var wall_start := Vector2(600, 650)
	var wall_end := wall_start + Vector2(136, 0)
	for point in game._wall_positions(wall_start, wall_end): assert(game.can_place("palisade_wall", point))
	game.selected.clear()
	game.selected.append(workers[0])
	game.build_mode = "palisade_wall"
	var count_before: int = game.buildings.size()
	game._confirm_wall_line(wall_start, wall_end)
	assert(game.buildings.size() == count_before + 3)
	var gate: RtsBuilding = game.buildings.back()
	gate.advance_construction(100.0)
	assert(game.convert_wall_to_gate(gate))
	assert(gate.kind == "palisade_gate")
	assert(not game.navigation.pathfinder.is_point_solid(game.world_map.cell_at(gate.position)))
	assert(game.navigation.enemy_pathfinder.is_point_solid(game.world_map.cell_at(gate.position)))
	var passer: RtsUnit = game.spawn_unit(0, "spearman", gate.position + Vector2(0, -85))
	passer.order_move(gate.position + Vector2(0, 85))
	for step in 200:
		passer._process(0.05)
		if passer.order == "idle": break
	assert(passer.order == "idle" and passer.position.distance_to(gate.position + Vector2(0, 85)) < 20.0, "friendly units should cross the gate")
	var enemy: RtsUnit = game.units[5]
	assert(not game.navigation.can_occupy(gate.position, enemy.radius(), enemy), "enemy units should be blocked by the gate")
	var breached_cell: Vector2i = game.world_map.cell_at(gate.position)
	gate.take_damage(2000.0)
	game.navigation.path_between(enemy.position, game.world_map.cell_center(breached_cell), enemy)
	assert(not game.navigation.enemy_pathfinder.is_point_solid(breached_cell), "breaching the gate should open the route")
	game.selected_map_size = Vector2(3000, 1800)
	game.selected_map_style = "lakes"
	game.start_game("Chinese", 6789)
	assert(game.world_size == Vector2(3000, 1800) and game.world_map.map_style == "lakes")
	assert(not game.world_map.path_between(game._scaled_point(Vector2(330, 720)), game._scaled_point(Vector2(2070, 720))).is_empty())
	game.players[1]["age"] = 2
	game.players[1]["wood"] = 2000
	game.ai._construct_dock(game.units[5])
	assert(game.ai._has_building("dock"), "AI should find a reachable shore on large lake maps")
	var same := RtsWorldMap.new()
	same.generate(6789, Vector2(3000, 1800), "lakes")
	assert(same.cells == game.world_map.cells and same.resource_specs == game.world_map.resource_specs)
	var lake_cells := same.cells.count(RtsWorldMap.Terrain.WATER)
	var lake_mountains := same.cells.count(RtsWorldMap.Terrain.MOUNTAIN)
	same.generate(6789, Vector2(3000, 1800), "highlands")
	assert(same.cells.count(RtsWorldMap.Terrain.WATER) < lake_cells)
	assert(same.cells.count(RtsWorldMap.Terrain.MOUNTAIN) > lake_mountains)
	assert(not same.path_between(Vector2(412, 864), Vector2(2588, 864)).is_empty())
	same.free()
	game.free()
	print("EXTENDED_SYSTEMS_OK")
	quit()

extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game("French", 12345)
	var center: RtsBuilding = game._player_center(0)
	assert(game.train_unit(center, "villager"))
	assert(game.train_unit(center, "villager"))
	game._toggle_global_queue()
	assert(game.global_queue_panel.visible and game.global_queue_list.get_child_count() >= 3)
	var food_before := int(game.players[0]["food"])
	assert(game.cancel_production_job(center, 1))
	assert(int(game.players[0]["food"]) > food_before and center.production_queue.size() == 1)
	var market: RtsBuilding = game.spawn_building(0, "market", center.position + Vector2(0, -160))
	game.selected.clear()
	game.selected.append(market)
	game._rebuild_actions()
	assert(game.command_buttons.any(func(button: RtsCommandButton) -> bool: return button.caption.contains("卖木")))
	game.players[0]["wood"] = 500
	var sale: int = game.market_quote("wood", false)
	assert(game.exchange_resource(0, "wood", false))
	assert(int(game.players[0]["wood"]) == 400 and game.market_quote("wood", false) < sale)
	var purchase: int = game.market_quote("food", true)
	var gold_before := int(game.players[0]["gold"])
	assert(game.exchange_resource(0, "food", true))
	assert(int(game.players[0]["gold"]) == gold_before - purchase)
	assert(market.is_complete())
	var scout: RtsUnit = game.units.filter(func(unit: RtsUnit) -> bool: return unit.owner_id == 0 and unit.kind == "scout")[0]
	scout.position = center.position + Vector2(300, 0)
	var sheep: RtsResource = game.spawn_resource("food", scout.position + Vector2(50, 0), 200, "sheep")
	sheep._process(0.4)
	assert(sheep.claimed_by == 0 and sheep.shepherd == scout)
	var original_sheep := sheep.position
	scout.position += Vector2(110, 0)
	sheep._process(0.4)
	assert(sheep.position != original_sheep, "claimed sheep should follow the scout")
	var infantry: RtsUnit = game.spawn_unit(0, "spearman", center.position + Vector2(180, 0))
	game.selected.clear()
	game.selected.append(infantry)
	game._rebuild_actions()
	assert(game.hotkey_buttons.has(KEY_3) and game.hotkey_buttons.has(KEY_4) and game.hotkey_buttons.has(KEY_5))
	game.order_mode = "patrol"
	assert(game._cursor_state_at(infantry.position) == "patrol")
	game.order_mode = ""
	infantry.issue_command("patrol", infantry.position + Vector2(95, 0))
	assert(infantry.order == "patrol")
	infantry.position = infantry.patrol_destination
	infantry._process(0.01)
	assert(infantry.destination == infantry.patrol_origin)
	infantry.issue_command("hold")
	assert(infantry.order == "hold" and infantry.stance == "hold")
	game.view_button.pressed.emit()
	assert(game.view_mode_25d and game.camera.rotation != 0.0 and game.camera.zoom.x != game.camera.zoom.y)
	game.view_button.pressed.emit()
	assert(not game.view_mode_25d and game.camera.rotation == 0.0 and is_equal_approx(game.camera.zoom.x, game.camera.zoom.y))
	var boat: RtsUnit = game.spawn_unit(0, "transport_ship", Vector2(800, 1220))
	var landing: Dictionary = game.find_landing_pair(boat, Vector2(800, 1080))
	assert(not landing.is_empty())
	boat.position = landing["water"]
	infantry.position = landing["land"]
	game.selected.clear()
	game.selected.append(infantry)
	assert(game._cursor_state_at(boat.position) == "board")
	game._issue_order(boat.position)
	assert(infantry.order == "board_transport")
	assert(boat.garrison_unit(infantry) and infantry.garrisoned_in == boat)
	game.selected.clear()
	game.selected.append(boat)
	game._issue_order(landing["land"])
	assert(boat.order == "unload")
	boat.position = boat.destination
	boat._process(0.01)
	assert(boat.passengers.is_empty() and infantry.garrisoned_in == null and game.world_map.is_walkable(infantry.position))
	var islands := RtsWorldMap.new()
	islands.generate(2233, Vector2(2400, 1500), "islands")
	assert(islands.path_between(Vector2(330, 720), Vector2(2070, 720)).is_empty(), "islands should require transports")
	islands.free()
	game.selected_map_style = "islands"
	game.start_game("English", 2233)
	game.players[1]["age"] = 2
	game.players[1]["wood"] = 2000
	game.ai._construct_dock(game.units[5])
	assert(game.ai._has_building("dock"), "island AI should establish a dock")
	game.free()
	print("STRATEGIC_EXPANSION_OK")
	quit()

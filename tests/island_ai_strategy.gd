extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.selected_map_style = "islands"
	game.start_game("English", 2233, "French")
	var base: Vector2 = game.spawn_point_for(1)
	var trader: RtsUnit = game.spawn_unit(1, "trader", base + Vector2(-100, 0))
	assert(game.ai._reachable_trade_post(trader) == game.trade_posts[1], "island traders must use their own reachable post")
	var water: Vector2 = game.world_map.nearest_water_point(base + Vector2(-520, 0))
	var boat: RtsUnit = game.spawn_unit(1, "transport_ship", water)
	var monk: RtsUnit = game.spawn_unit(1, "monk", base + Vector2(-150, 0))
	game.ai._assign_transport(boat)
	if boat.order == "move":
		boat.position = boat.destination
		boat.order_stop()
		game.ai._assign_transport(boat)
	assert(monk.order == "board_transport" and monk.target == boat, "island monks must board transports")
	monk.position = boat.position + Vector2(45, 0)
	assert(boat.garrison_unit(monk))
	game.ai._assign_transport(boat)
	assert(boat.order == "unload", "a monk transport must sail to the central island")
	var site: Vector2 = game.objectives.sacred_sites[1]["position"]
	assert(boat.landing_position.distance_to(site) < 750.0 and not game.world_map.path_between(boat.landing_position, site).is_empty())
	game.free()
	print("ISLAND_AI_STRATEGY_OK")
	quit()

extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game("English", 4242)
	# Build a mountain wall with a three-cell opening across the middle road.
	var wall_x := 21
	for y in game.world_map.grid_size.y:
		game.world_map.cells[y * game.world_map.grid_size.x + wall_x] = RtsWorldMap.Terrain.GRASS if y in [14, 15, 16] else RtsWorldMap.Terrain.MOUNTAIN
	game.world_map._setup_pathfinder()
	game.navigation.refresh()
	var squad: Array[RtsUnit] = []
	for i in 12:
		var unit: RtsUnit = game.spawn_unit(0, "spearman", Vector2(600 + (i % 4) * 30, 710 + (i / 4) * 30))
		unit.order_stop()
		squad.append(unit)
	game.issue_group_order(squad, Vector2(1470, 760))
	var group: RtsMovementGroup = squad[0].movement_group
	assert(group != null and group.route.size() > 1)
	var crossed := 0
	var furthest_route_index := group.route_index
	for step in 950:
		group.last_frame = -1
		for unit in squad:
			if unit.order != "idle": unit._process(0.05)
		furthest_route_index = maxi(furthest_route_index, group.route_index)
		if step % 100 == 0:
			crossed = 0
			for unit in squad:
				if unit.position.x > 1120.0: crossed += 1
		if squad.all(func(unit: RtsUnit) -> bool: return unit.order == "idle"): break
	if crossed != squad.size():
		push_error("only %d of %d units crossed the opening" % [crossed, squad.size()])
		quit(1)
		return
	for unit in squad: assert(unit.position.distance_to(Vector2(1470, 760)) < 160.0, "the squad should reform near its destination")
	assert(furthest_route_index > 1, "the group center should advance its shared route through the opening")
	print("GROUP_CHOKEPOINT_OK")
	quit()

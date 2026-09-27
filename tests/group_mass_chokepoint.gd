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
	for x in range(wall_x - 3, wall_x + 4):
		for y in [14, 15, 16]: game.world_map.cells[y * game.world_map.grid_size.x + x] = RtsWorldMap.Terrain.GRASS
	for resource in game.resources.duplicate():
		if resource.position.x >= 875.0 and resource.position.x <= 1275.0 and resource.position.y >= 650.0 and resource.position.y <= 875.0:
			game.resources.erase(resource)
			resource.queue_free()
	game.world_map._setup_pathfinder()
	game.navigation.refresh()
	var squad: Array[RtsUnit] = []
	for i in 100:
		var unit: RtsUnit = game.spawn_unit(0, "spearman", Vector2(560 + (i % 12) * 27, 610 + (i / 12) * 27))
		unit.order_stop()
		squad.append(unit)
	game.issue_group_order(squad, Vector2(1470, 760))
	var group: RtsMovementGroup = squad[0].movement_group
	var groups: Array[RtsMovementGroup] = []
	for unit in squad:
		if not groups.has(unit.movement_group): groups.append(unit.movement_group)
	assert(group != null and group.route.size() > 1)
	var crossed := 0
	for step in 2200:
		for platoon in groups: platoon.last_frame = -1
		for unit in squad:
			if unit.order != "idle": unit._process(0.05)
		if squad.all(func(unit: RtsUnit) -> bool: return unit.order == "idle"): break
	crossed = 0
	for unit in squad:
		if unit.position.x > 1120.0: crossed += 1
	if crossed != squad.size():
		push_error("only %d of %d units crossed the opening" % [crossed, squad.size()])
		quit(1)
		return
	print("GROUP_MASS_CHOKEPOINT_OK")
	quit()

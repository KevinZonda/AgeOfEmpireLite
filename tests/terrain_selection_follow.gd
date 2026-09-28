extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game("English", 4242)
	game.ai_controllers.clear()
	game.fog.clear()
	game._toggle_view_mode()
	var from := Vector2.INF
	var to := Vector2.INF
	for y in game.world_map.grid_size.y:
		for x in game.world_map.grid_size.x - 1:
			var first: Vector2 = game.world_map.cell_center(Vector2i(x, y))
			var second: Vector2 = game.world_map.cell_center(Vector2i(x + 1, y))
			if not game.world_map.is_walkable(first) or not game.world_map.is_walkable(second): continue
			if absf(game.world_map.elevation_at(first) - game.world_map.elevation_at(second)) < 7.0: continue
			if not game.navigation.can_occupy(first, 14.0, null) or not game.navigation.can_occupy(second, 14.0, null): continue
			if game.navigation.path_between(first, second).is_empty(): continue
			from = first
			to = second
			break
		if from != Vector2.INF: break
	assert(from != Vector2.INF, "test map needs an accessible slope")
	var unit: RtsUnit = game.spawn_unit(0, "spearman", from)
	game.selected.clear()
	game.selected.append(unit)
	game._rebuild_actions()
	game._issue_order(to + RtsIsoProjection.ground_lift(game, to))
	assert(unit.movement_group != null and unit.movement_group.goal.distance_to(to) < 2.0, "a click on the visible slope should order movement to that ground point")
	game.order_markers.clear()
	await process_frame
	var redraws := {"unit": 0, "selection": 0}
	unit.draw.connect(func() -> void: redraws["unit"] += 1)
	game.draw.connect(func() -> void: redraws["selection"] += 1)
	var previous: Vector2 = unit.position
	var previous_height: float = game.world_map.elevation_at(previous)
	for step in 15:
		unit._process(0.12)
		assert(unit.position.distance_to(previous) <= unit.effective_speed() * 0.12 + 0.1, "movement must stay within the speed budget for this frame")
		previous = unit.position
	await process_frame
	assert(absf(game.world_map.elevation_at(unit.position) - previous_height) > 1.0, "the unit should traverse the slope")
	assert(redraws["unit"] > 0, "the projected unit must update as ground height changes")
	assert(redraws["selection"] > 0, "the selection ring must follow the moving unit")
	print("TERRAIN_SELECTION_FOLLOW_OK")
	quit()

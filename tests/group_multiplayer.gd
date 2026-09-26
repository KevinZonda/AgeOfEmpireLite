extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.match_mode = "team2"
	game.start_game("English", 4242)
	assert(game.players.size() == 4 and game.ai_controllers.size() == 3)
	assert(not game.is_enemy(0, 2) and game.is_enemy(0, 1))
	assert(game.fog.visible_cells.size() == 4)
	assert(game.fog.can_see(0, game.spawn_point_for(2)), "allies should share current vision")
	for index in game.objectives.sacred_sites.size():
		game.objectives.sacred_sites[index]["owner_id"] = 2 if index == 1 else 0
	assert(game.objectives.status_for(0)["sacred_owned"] == 3, "allied sacred sites should count together")
	game.objectives.reset()
	for owner_id in 4:
		var base: Vector2 = game.spawn_point_for(owner_id)
		assert(game.world_map.is_walkable(base), "every multiplayer base must be walkable")
		assert(not game.world_map.path_between(game.spawn_point_for(0), base).is_empty(), "all bases should connect through land")
		assert(game._player_center(owner_id) != null)
		if owner_id > 0: game.ai_controllers[owner_id - 1].tick()
	var gate: RtsBuilding = game.spawn_building(2, "palisade_gate", Vector2(900, 750))
	game.navigation.refresh()
	var gate_cell: Vector2i = game.world_map.cell_at(gate.position)
	assert(not game.navigation.owner_pathfinders[0].is_point_solid(gate_cell), "allied gates should open for pathfinding")
	assert(game.navigation.owner_pathfinders[1].is_point_solid(gate_cell), "enemy gates should block pathfinding")
	var squad: Array[RtsUnit] = []
	for i in 5:
		var unit: RtsUnit = game.spawn_unit(0, "spearman", Vector2(550 + i * 29, 760))
		unit.order_stop()
		squad.append(unit)
	var distant: RtsUnit = game.spawn_unit(0, "spearman", Vector2(1900, 760))
	var clustered: Array[RtsUnit] = squad.duplicate()
	clustered.append(distant)
	assert(RtsMovementGroup.split_squads(clustered).size() == 2)
	var goal := Vector2(1480, 760)
	game.issue_group_order(squad, goal)
	var group: RtsMovementGroup = squad[0].movement_group
	assert(group != null and group.route.size() > 1)
	for unit in squad: assert(unit.movement_group == group)
	for step in 650:
		group.last_frame = -1
		for unit in squad:
			if unit.order != "idle": unit._process(0.05)
		if squad.all(func(unit: RtsUnit) -> bool: return unit.order == "idle"): break
	for unit in squad:
		assert(unit.position.distance_to(goal) < 150.0, "squad member should reach the shared destination")
	var large_army: Array[RtsUnit] = []
	for i in 48:
		large_army.append(game.spawn_unit(0, "spearman", Vector2(540 + (i % 8) * 27, 900 + (i / 8) * 27)))
	var platoons := RtsMovementGroup.split_squads(large_army)
	assert(platoons.size() == 4, "large armies should form bounded platoons")
	for platoon in platoons: assert(platoon.size() <= RtsMovementGroup.MAX_MEMBERS)
	game.issue_group_order(large_army, Vector2(1560, 800))
	var destinations: Dictionary = {}
	for unit in large_army:
		assert(unit.movement_group != null)
		destinations[unit.movement_group.get_instance_id()] = unit.movement_group.goal
	assert(destinations.size() == 4, "platoons should use separate shared routes")
	# A defeated player in a team game does not end the match while an ally survives.
	game.entity_destroyed(game._player_center(1))
	assert(not game.game_over)
	game.entity_destroyed(game._player_center(3))
	assert(game.game_over)
	game.match_mode = "ffa3"
	game.start_game("French", 4242)
	assert(game.players.size() == 3 and game.teams == [0, 1, 2])
	assert(game.is_enemy(1, 2) and game.ai_controllers.size() == 2)
	game.entity_destroyed(game._player_center(1))
	assert(not game.game_over, "FFA continues while another rival survives")
	game.entity_destroyed(game._player_center(2))
	assert(game.game_over, "the last surviving team wins")
	game.match_mode = "ffa4"
	game.start_game("Chinese", 4242)
	assert(game.players.size() == 4 and game.teams == [0, 1, 2, 3])
	print("GROUP_MULTIPLAYER_OK")
	quit()

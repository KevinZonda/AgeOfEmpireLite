extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game("English", 12345)
	var own_center: RtsBuilding = game._player_center(0)
	var enemy_center: RtsBuilding = game._player_center(1)
	assert(game.fog.active)
	assert(game.fog.can_see(0, own_center.position))
	assert(game.fog.can_see(1, enemy_center.position))
	assert(not game.fog.can_see(0, enemy_center.position))
	assert(not game.fog.is_explored(0, enemy_center.position))
	assert(game.fog.mask_image.get_pixelv(game.world_map.cell_at(enemy_center.position)).a > 0.99)
	assert(not enemy_center.visible)
	assert(game._entity_at(enemy_center.position) == null, "hidden enemies cannot be targeted by clicking")
	assert(game.fog.can_show_resource(0, game.resources[0]), "starter resources should be revealed")
	var enemy_unit: RtsUnit = game.units[5]
	var enemy_unit_position := enemy_unit.position
	enemy_unit.position = own_center.position + Vector2(165, 0)
	game.fog.update_visibility()
	assert(enemy_unit.visible and game._entity_at(enemy_unit.position) == enemy_unit)
	enemy_unit.position = enemy_unit_position
	game.fog.update_visibility()
	assert(not enemy_unit.visible)
	var source: Vector2i = game.world_map.cell_at(Vector2(500, 255))
	var target: Vector2i = game.world_map.cell_at(Vector2(1075, 255))
	assert(not game.fog._line_of_sight(source, target), "mountains should block vision")
	var scout: RtsUnit = game.units[0]
	var original_position := scout.position
	scout.position = enemy_center.position + Vector2(-145, 0)
	game.fog.update_visibility()
	assert(game.fog.can_see(0, enemy_center.position))
	assert(game.fog.mask_image.get_pixelv(game.world_map.cell_at(enemy_center.position)).a < 0.01)
	assert(game.fog.is_explored(0, enemy_center.position))
	assert(enemy_center.visible)
	assert(game._entity_at(enemy_center.position) == enemy_center)
	scout.position = original_position
	game.fog.update_visibility()
	assert(not game.fog.can_see(0, enemy_center.position))
	assert(game.fog.is_explored(0, enemy_center.position))
	assert(game.fog.mask_image.get_pixelv(game.world_map.cell_at(enemy_center.position)).a > 0.6)
	assert(not enemy_center.visible)
	assert(game._entity_at(enemy_center.position) == null)
	var hidden_wood: RtsResource
	var hidden_deer: RtsResource
	for resource in game.resources:
		if game.fog.is_explored(0, resource.position): continue
		if hidden_wood == null and resource.kind == "wood": hidden_wood = resource
		if hidden_deer == null and resource.appearance == "deer": hidden_deer = resource
	assert(hidden_wood != null and hidden_deer != null)
	scout.position = hidden_wood.position + Vector2(25, 0)
	game.fog.update_visibility()
	assert(hidden_wood.visible)
	scout.position = original_position
	game.fog.update_visibility()
	assert(hidden_wood.visible, "discovered static resources should stay on the map")
	scout.position = hidden_deer.position + Vector2(25, 0)
	game.fog.update_visibility()
	assert(hidden_deer.visible)
	scout.position = original_position
	game.fog.update_visibility()
	assert(not hidden_deer.visible, "deer should disappear outside current vision")
	game._set_paused(true)
	scout.position = enemy_center.position + Vector2(-145, 0)
	game.fog._process(1.0)
	assert(not game.fog.can_see(0, enemy_center.position), "vision should freeze while paused")
	game._set_paused(false)
	game.fog._process(0.2)
	assert(game.fog.can_see(0, enemy_center.position))
	game.start_game("English", 12345)
	assert(not game.fog.is_explored(0, game._player_center(1).position), "a new match should reset exploration")
	print("FOG_OF_WAR_OK")
	quit()

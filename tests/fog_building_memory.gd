extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game("English", 12345)
	var enemy_center: RtsBuilding = game._player_center(1)
	var house: RtsBuilding = game.spawn_building(1, "house", enemy_center.position + Vector2(-190, 0))
	var building_id := house.get_instance_id()
	game.fog.update_visibility()
	assert(not game.fog.remembered_buildings.has(building_id), "undiscovered buildings must not enter memory")
	var scout: RtsUnit = game.units[0]
	var original_position := scout.position
	scout.position = house.position + Vector2(-75, 0)
	game.fog.update_visibility()
	assert(house.visible and game.fog.remembered_buildings.has(building_id))
	var ghost: RtsBuilding = game.fog.remembered_buildings[building_id]["ghost"]
	assert(not ghost.visible and not game.buildings.has(ghost), "memory must not duplicate a visible or interactive building")
	house.hp -= 30.0
	game.fog.update_visibility()
	var last_seen_hp := ghost.hp
	scout.position = original_position
	game.fog.update_visibility()
	assert(not house.visible and ghost.visible, "a discovered building must remain visible as a memory")
	assert(game._entity_at(house.position) == null, "a remembered building cannot be selected or attacked")
	house.hp -= 50.0
	house.build_remaining = 5.0
	game.fog.update_visibility()
	assert(ghost.hp == last_seen_hp and ghost.build_remaining == 0.0, "hidden building state must not leak through memory")
	scout.position = house.position + Vector2(-75, 0)
	game.fog.update_visibility()
	assert(not ghost.visible and ghost.hp == house.hp and ghost.build_remaining == house.build_remaining, "returning vision refreshes the remembered state")
	scout.position = original_position
	game.fog.update_visibility()
	assert(ghost.visible)
	game.entity_destroyed(house)
	game.fog.update_visibility()
	assert(ghost.visible and game.fog.remembered_buildings.has(building_id), "unseen destruction must not remove the last known building")
	scout.position = ghost.position + Vector2(-75, 0)
	game.fog.update_visibility()
	assert(not game.fog.remembered_buildings.has(building_id), "new vision must clear a destroyed building memory")
	game.start_game("English", 12345)
	assert(game.fog.remembered_buildings.is_empty(), "a new match must clear building memory")
	game.free()
	print("FOG_BUILDING_MEMORY_OK")
	quit()

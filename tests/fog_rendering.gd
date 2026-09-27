extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game("English", 12345)
	game._toggle_view_mode()
	game.camera.force_update_scroll()
	var scout: RtsUnit = game.units[0]
	var high_ground := Vector2(1025, 225)
	assert(game.world_map.is_walkable(high_ground) and game.world_map.elevation_at(high_ground) > 50.0)
	scout.position = high_ground
	game.fog.update_visibility()
	var head: Vector2 = high_ground + RtsIsoProjection.ground_lift(game, high_ground)
	head += RtsIsoProjection.world_delta(game.get_viewport().get_canvas_transform(), Vector2(0, -24 * game.camera.zoom.x))
	assert(game.fog.can_see(0, high_ground))
	assert(game.fog.mask_image.get_pixelv(game.world_map.cell_at(head)).a > 0.6, "a raised unit can project into a fogged cell")
	assert(scout.visible and game.world_map.z_index < game.fog.z_index and game.fog.z_index < scout.z_index, "own units must render above the fog surface")
	assert(game.world_map.z_index < game.objectives.z_index and game.objectives.z_index < game.fog.z_index, "unexplored objectives must stay under the fog")
	var enemy_center: RtsBuilding = game._player_center(1)
	assert(not enemy_center.visible, "moving fog behind units must not reveal unseen enemies")
	game.free()
	print("FOG_RENDERING_OK")
	quit()

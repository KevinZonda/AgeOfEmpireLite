extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.selected_view_mode_25d = false
	game.edge_scroll_enabled = false
	root.size = Vector2i(1280, 720)
	game.start_game("English", 12345)
	game._toggle_view_mode()
	game.camera.force_update_scroll()
	var scout: RtsUnit = game.units[0]
	# Locate this rendering case in the generated relief instead of assuming a
	# coordinate tied to an older map size or the user's saved lobby settings.
	var high_ground := Vector2.INF
	var head := Vector2.ZERO
	for y in game.world_map.grid_size.y:
		for x in game.world_map.grid_size.x:
			var candidate: Vector2 = game.world_map.cell_center(Vector2i(x, y))
			if not game.world_map.is_walkable(candidate) or game.world_map.elevation_at(candidate) <= 50.0: continue
			scout.position = candidate
			game.fog.update_visibility()
			head = candidate + RtsIsoProjection.ground_lift(game, candidate)
			head += RtsIsoProjection.world_delta(game.get_viewport().get_canvas_transform(), Vector2(0, -24 * game.camera.zoom.x))
			if game.fog.mask_image.get_pixelv(game.world_map.cell_at(head)).a <= 0.6: continue
			high_ground = candidate
			break
		if high_ground != Vector2.INF: break
	assert(high_ground != Vector2.INF, "fixture needs a raised unit projecting into a fogged cell")
	assert(game.fog.can_see(0, high_ground))
	assert(game.fog.mask_image.get_pixelv(game.world_map.cell_at(head)).a > 0.6, "a raised unit can project into a fogged cell")
	assert(scout.visible and game.world_map.z_index < game.fog.z_index and game.fog.z_index < scout.z_index, "own units must render above the fog surface")
	assert(game.world_map.z_index < game.objectives.z_index and game.objectives.z_index < game.fog.z_index, "unexplored objectives must stay under the fog")
	var enemy_center: RtsBuilding = game._player_center(1)
	assert(not enemy_center.visible, "moving fog behind units must not reveal unseen enemies")
	game.free()
	print("FOG_RENDERING_OK")
	quit()

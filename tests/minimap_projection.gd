extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Variant = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game("English", 4242)
	if not game.view_mode_25d: game._toggle_view_mode()
	await process_frame
	var minimap: RtsMinimap = game.minimap
	var center := minimap.size * 0.5
	assert(minimap.world_to_map(Vector2.ZERO).is_equal_approx(Vector2(center.x, 0.0)), "the northwest corner should be the diamond's top point")
	assert(minimap.world_to_map(game.world_size).is_equal_approx(Vector2(center.x, minimap.size.y)), "the southeast corner should be the diamond's bottom point")
	for point in [Vector2.ZERO, game.world_size, game.world_size * Vector2(0.27, 0.63), game.world_size * 0.5]:
		assert(minimap.map_to_world(minimap.world_to_map(point)).distance_to(point) < 1.0, "diamond map coordinates should round-trip")
	var camera_before: Vector2 = game.camera.position
	var outside_click := InputEventMouseButton.new()
	outside_click.button_index = MOUSE_BUTTON_LEFT
	outside_click.pressed = true
	outside_click.position = Vector2(2, 2)
	minimap._gui_input(outside_click)
	assert(game.camera.position == camera_before, "clicks outside the diamond should not move the camera")
	outside_click.position = center
	minimap._gui_input(outside_click)
	assert(game.camera.position.distance_to(game.world_size * 0.5) < 1.0, "clicking the diamond center should locate the map center")
	game._toggle_view_mode()
	await process_frame
	assert(minimap.world_to_map(Vector2.ZERO).is_equal_approx(Vector2.ZERO), "the 2D minimap should keep square coordinates")
	assert(minimap.map_to_world(minimap.size * 0.5).distance_to(game.world_size * 0.5) < 1.0)
	print("MINIMAP_PROJECTION_OK")
	quit()

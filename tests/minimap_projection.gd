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
	var panel_rect: Rect2 = game.hud_ui.minimap_panel.get_global_rect()
	var map_rect: Rect2 = minimap.get_global_rect()
	assert(map_rect.position.y >= panel_rect.position.y, "the default diamond should fit inside its panel")
	assert(map_rect.position.x >= panel_rect.position.x and map_rect.end.x <= panel_rect.end.x, "the panel should reserve the diamond's full width")
	assert(map_rect.end.y <= panel_rect.end.y, "the diamond should remain inside the screen's lower edge")
	var information_panel: Control = game.hud_ui.minimap_anchor.get_parent().get_child(1)
	assert(information_panel.get_global_rect().end.x <= map_rect.position.x, "the diamond should not cover the information panel")
	assert(minimap.size.is_equal_approx(Vector2.ONE * game.minimap_size), "both projections should use the selected minimap footprint")
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
	var tip_point := center + Vector2(0, -minimap.size.y * 0.45)
	assert(minimap._inside_map(tip_point))
	assert((minimap.get_global_transform_with_canvas() * tip_point).y >= game.hud_bottom.get_global_rect().position.y, "the default diamond should not cover the battlefield")
	assert(game._selection_point_over_hud(minimap.get_global_transform_with_canvas() * tip_point), "selection should not pass through the minimap")
	game.camera.position = game.world_size * 0.5
	var protruding_click := InputEventMouseButton.new()
	protruding_click.button_index = MOUSE_BUTTON_LEFT
	protruding_click.pressed = true
	protruding_click.position = minimap.get_global_transform_with_canvas() * tip_point
	game.get_viewport().push_input(protruding_click, true)
	assert(game.camera.position.distance_to(minimap.map_to_world(tip_point)) < 1.0, "clicks on the diamond should reach the minimap")
	game.minimap_size = 264
	game.hud_ui._apply_minimap_size()
	await process_frame
	assert(information_panel.get_global_rect().end.x <= minimap.get_global_rect().position.x, "the largest diamond should not overlap the information panel at 1280px")
	game._toggle_view_mode()
	await process_frame
	assert(minimap.size.is_equal_approx(Vector2.ONE * game.minimap_size), "the 2D map should remain square")
	assert(minimap.world_to_map(Vector2.ZERO).is_equal_approx(Vector2.ZERO), "the 2D minimap should keep square coordinates")
	assert(minimap.map_to_world(minimap.size * 0.5).distance_to(game.world_size * 0.5) < 1.0)
	print("MINIMAP_PROJECTION_OK")
	quit()

extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Variant = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.selected_view_mode_25d = false
	game.edge_scroll_enabled = false
	root.size = Vector2i(1280, 720)
	game.start_game("English", 4242)
	assert(is_equal_approx(game.camera_zoom_ratio(), 1.0), "a new match should start at the normalized 1x magnification")
	assert(game.camera.zoom.is_equal_approx(Vector2.ONE * 1.65), "2D 1x must preserve the previous maximum screen size")
	game.camera.force_update_scroll()
	var home_screen: Vector2 = game.get_viewport().get_canvas_transform() * game._player_center(0).position
	assert(home_screen.x > 150.0 and home_screen.x < 1000.0 and home_screen.y > 150.0 and home_screen.y < 400.0, "opening zoom must keep the town center comfortably inside the battlefield")
	game.camera.position = game.world_size * 0.5
	if not game.view_mode_25d: game._toggle_view_mode()
	await process_frame
	var fog_mesh: Mesh = game.fog.relief_mesh.mesh
	assert(fog_mesh != null, "2.5D fog should have a terrain mesh")
	var terrain_lift: Vector2 = game.world_map.lift_per_height
	var mountain_mesh: Mesh = game.world_map.occlusion_layer.pieces[0].mesh
	var anchor := Vector2(830, 310)
	assert(game.camera.zoom.is_equal_approx(Vector2(1.65, 0.825)), "2.5D must preserve normalized zoom and the 2:1 ground projection")
	for factor in [1.0 / 1.12, 1.0 / 1.08, 1.12, 1.08]:
		game.camera.force_update_scroll()
		var before: Vector2 = game.get_viewport().get_canvas_transform().affine_inverse() * anchor
		game._adjust_zoom(factor, anchor)
		game.camera.force_update_scroll()
		var after: Vector2 = game.get_viewport().get_canvas_transform().affine_inverse() * anchor
		assert(before.distance_to(after) < 2.0, "pinch zoom should keep the map point under the fingers")
		assert(game.fog.relief_mesh.mesh == fog_mesh, "pinch zoom should reuse the fog mesh")
		assert(game.world_map.occlusion_layer.pieces[0].mesh == mountain_mesh, "pinch zoom should reuse mountain occlusion geometry")
		assert(game.world_map.lift_per_height.distance_to(terrain_lift) < 0.001, "terrain relief should not need rebuilding for a fixed projection")
		assert(terrain_lift.distance_to(RtsIsoProjection.world_delta(game.get_viewport().get_canvas_transform(), Vector2(0, -game.camera.zoom.x))) < 0.001, "cached terrain relief should match the current camera")
		await process_frame
	game._toggle_view_mode()
	game.camera.position = game.world_size * 0.5
	game._adjust_zoom(1.0 / 1.1, anchor)
	game.camera.force_update_scroll()
	var before_2d: Vector2 = game.get_viewport().get_canvas_transform().affine_inverse() * anchor
	game._adjust_zoom(1.1, anchor)
	game.camera.force_update_scroll()
	var after_2d: Vector2 = game.get_viewport().get_canvas_transform().affine_inverse() * anchor
	assert(before_2d.distance_to(after_2d) < 2.0, "2D zoom should also keep the pointer anchor")
	game._adjust_zoom(100.0, anchor)
	assert(is_equal_approx(game.camera_zoom_ratio(), 1.0), "zooming in must stop at normalized 1x")
	game._adjust_zoom(0.001, anchor)
	assert(is_equal_approx(game.camera.zoom.x, 0.7), "zooming out must preserve the old minimum screen size")
	assert(is_equal_approx(game.camera_zoom_ratio(), game.MIN_CAMERA_ZOOM))
	game.start_game("English", 4242)
	assert(is_equal_approx(game.camera_zoom_ratio(), 1.0), "starting another match must restore the default zoom")
	print("ZOOM_PROJECTION_OK")
	quit()

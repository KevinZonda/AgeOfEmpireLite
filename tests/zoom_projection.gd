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
	game.paused = true
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
	assert(is_equal_approx(game.camera_zoom_ratio(), 1.5), "virtual zoom should allow 150% of the resolution default")
	assert(is_equal_approx(game.camera.zoom.x, 2.475))
	game._adjust_zoom(0.001, anchor)
	assert(is_equal_approx(game.camera.zoom.x, 0.825))
	assert(is_equal_approx(game.camera_zoom_ratio(), 0.5), "virtual zoom should stop at 50% of the resolution default")
	game._adjust_zoom(1.6, anchor)
	var unit: RtsUnit = game.units[0]
	var unit_radius := unit.radius()
	var building_size: Vector2 = game._player_center(0).size()
	for projected in [false, true]:
		if game.view_mode_25d != projected: game._toggle_view_mode()
		game.camera.position = game.world_size * 0.5
		await process_frame
		await process_frame
		fog_mesh = game.fog.relief_mesh.mesh
		mountain_mesh = game.world_map.occlusion_layer.pieces[0].mesh
		for resolution in [Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1080), Vector2i(1280, 720)]:
			var center_before: Vector2 = game.camera.position
			root.size = resolution
			await process_frame
			game.camera.force_update_scroll()
			var expected_physical := 1.1 if resolution.y == 900 else (1.2 if resolution.y == 1080 else 1.0)
			assert(is_equal_approx(game.camera_physical_scale, expected_physical), "resolution should only change physical scale; width should not affect it")
			assert(is_equal_approx(game.camera_zoom_ratio(), 0.8), "resizing must preserve player virtual zoom")
			var expected_zoom := 1.65 * expected_physical * 0.8
			assert(game.camera.zoom.is_equal_approx(Vector2(expected_zoom, expected_zoom * 0.5 if projected else expected_zoom)))
			assert(game.camera.position.distance_to(center_before) < 0.001, "resizing should preserve the world center away from map edges")
			assert(unit.radius() == unit_radius and game._player_center(0).size() == building_size, "camera scaling must not change collision or building footprint")
			if projected:
				assert(game.fog.relief_mesh.mesh == fog_mesh, "resolution changes must reuse fog geometry")
				assert(game.world_map.occlusion_layer.pieces[0].mesh == mountain_mesh, "resolution changes must reuse mountain geometry")
			var screen_anchor := Vector2(resolution) * Vector2(0.6, 0.45)
			var world_anchor: Vector2 = game.get_viewport().get_canvas_transform().affine_inverse() * screen_anchor
			game._adjust_zoom(1.1, screen_anchor)
			game.camera.force_update_scroll()
			assert(world_anchor.distance_to(game.get_viewport().get_canvas_transform().affine_inverse() * screen_anchor) < 2.0, "pointer anchoring must work at every resolution")
			game._adjust_zoom(1.0 / 1.1, screen_anchor)
	var ground_mesh: Mesh = game.world_map.ground_mesh
	game.world_map.queue_redraw()
	await process_frame
	await process_frame
	assert(game.world_map.ground_mesh == ground_mesh, "a redraw with unchanged terrain should reuse geometry")
	game.world_map.elevation_vertices[game.world_map._vertex_index(20, 20)] += 10.0
	game.world_map.queue_redraw()
	await process_frame
	await process_frame
	assert(game.world_map.ground_mesh != ground_mesh, "terrain edits must invalidate cached geometry")
	root.size = Vector2i(1920, 1080)
	await process_frame
	game.selected_view_mode_25d = true
	game.start_game("English", 4242)
	assert(is_equal_approx(game.camera_zoom_ratio(), 1.0), "starting another match must restore virtual 100%")
	assert(is_equal_approx(game.camera_physical_scale, 1.2) and is_equal_approx(game.camera.zoom.x, 1.98), "a 1080p match should start at its own resolution default")
	assert(game.camera.position.distance_to(game.spawn_point_for(0)) < 0.001, "another 2.5D match should still center the home spawn")
	root.size = Vector2i(1280, 720)
	await process_frame
	assert(is_equal_approx(game.camera_zoom_ratio(), 1.0) and is_equal_approx(game.camera.zoom.x, 1.65))
	print("ZOOM_PROJECTION_OK")
	quit()

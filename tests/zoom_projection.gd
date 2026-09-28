extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Variant = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game("English", 4242)
	game.camera.position = game.world_size * 0.5
	if not game.view_mode_25d: game._toggle_view_mode()
	await process_frame
	var fog_mesh: Mesh = game.fog.relief_mesh.mesh
	assert(fog_mesh != null, "2.5D fog should have a terrain mesh")
	var terrain_lift: Vector2 = game.world_map.lift_per_height
	var anchor := Vector2(830, 310)
	for factor in [1.12, 1.08, 1.0 / 1.12, 1.0 / 1.08]:
		game.camera.force_update_scroll()
		var before: Vector2 = game.get_viewport().get_canvas_transform().affine_inverse() * anchor
		game._adjust_zoom(factor, anchor)
		game.camera.force_update_scroll()
		var after: Vector2 = game.get_viewport().get_canvas_transform().affine_inverse() * anchor
		assert(before.distance_to(after) < 2.0, "pinch zoom should keep the map point under the fingers")
		assert(game.fog.relief_mesh.mesh == fog_mesh, "pinch zoom should reuse the fog mesh")
		assert(game.world_map.lift_per_height.distance_to(terrain_lift) < 0.001, "terrain relief should not need rebuilding for a fixed projection")
		assert(terrain_lift.distance_to(RtsIsoProjection.world_delta(game.get_viewport().get_canvas_transform(), Vector2(0, -game.camera.zoom.x))) < 0.001, "cached terrain relief should match the current camera")
		await process_frame
	game._toggle_view_mode()
	game.camera.position = game.world_size * 0.5
	game.camera.force_update_scroll()
	var before_2d: Vector2 = game.get_viewport().get_canvas_transform().affine_inverse() * anchor
	game._adjust_zoom(1.1, anchor)
	game.camera.force_update_scroll()
	var after_2d: Vector2 = game.get_viewport().get_canvas_transform().affine_inverse() * anchor
	assert(before_2d.distance_to(after_2d) < 2.0, "2D zoom should also keep the pointer anchor")
	print("ZOOM_PROJECTION_OK")
	quit()

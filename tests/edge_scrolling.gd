extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game("English", 4242)
	game.set_process(false)
	game.edge_scroll_enabled = true
	for setup in [[Vector2i(1280, 720), 1.0], [Vector2i(1920, 1080), 1.5]]:
		root.size = setup[0]
		game.ui_scale = setup[1]
		game.text_scale = 2.0
		game._apply_ui_scales()
		for frame in 3: await process_frame
		var size: Vector2 = game.get_viewport_rect().size
		var top := Vector2(size.x * 0.5, 1)
		var bottom := Vector2(size.x * 0.5, size.y - 1)
		assert(game.hud_top.get_global_rect().has_point(top))
		assert(game.hud_bottom.get_global_rect().has_point(bottom))
		assert(game._edge_pan_direction(top, size) == Vector2.UP, "top HUD must not block scrolling at the window edge")
		assert(game._edge_pan_direction(bottom, size) == Vector2.DOWN, "bottom HUD must not block scrolling at the window edge")
		assert(game._edge_pan_direction(Vector2(1, size.y * 0.4), size) == Vector2.LEFT)
		assert(game._edge_pan_direction(Vector2(size.x - 1, size.y * 0.4), size) == Vector2.RIGHT)
		assert(game._edge_pan_direction(Vector2.ZERO, size) == Vector2(-1, -1))
		assert(game._edge_pan_direction(size, size) == Vector2.ONE)
		assert(game._edge_pan_direction(Vector2(size.x * 0.5, -10), size) == Vector2.UP)
		assert(game._edge_pan_direction(Vector2(size.x * 0.5, size.y + 10), size) == Vector2.DOWN)
		assert(game._edge_pan_direction(Vector2(size.x * 0.5, 14), size) == Vector2.ZERO, "resource bar interior must not pan the camera")
		assert(game._edge_pan_direction(Vector2(size.x * 0.5, size.y - 14), size) == Vector2.ZERO, "command bar interior must not pan the camera")
		assert(game._edge_pan_direction(size * 0.5, size) == Vector2.ZERO)
		for projected in [false, true]:
			if game.view_mode_25d != projected: game._toggle_view_mode()
			for point in [top, bottom]:
				game.camera.position = game.world_size * 0.5
				var before: Vector2 = game.camera.position
				var direction: Vector2 = game._edge_pan_direction(point, size)
				game._move_camera_screen_delta(direction * game.CAMERA_PAN_SPEED * 0.1)
				var movement: Vector2 = (game.camera.position - before).rotated(-game.camera.rotation) * game.camera.zoom
				assert(movement.is_equal_approx(direction * game.CAMERA_PAN_SPEED * 0.1), "vertical edge movement must follow screen axes in both projections")
		game.edge_scroll_enabled = false
		assert(game._edge_pan_direction(top, size) == Vector2.ZERO)
		assert(game._edge_pan_direction(bottom, size) == Vector2.ZERO)
		game.edge_scroll_enabled = true
	print("EDGE_SCROLLING_OK")
	game.queue_free()
	await process_frame
	quit()

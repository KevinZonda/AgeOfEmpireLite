extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game("English", 4242)
	game.set_process(false)
	game.ai_controllers.clear()
	game.edge_scroll_enabled = false
	game.camera.position = game.world_size * 0.5
	game.camera.force_update_scroll()
	var position: Vector2 = game.camera.position
	var scale: float = game.camera_virtual_scale
	gesture(game, ["pan", 16.0, 24.0, 600.0, 250.0])
	assert(game.camera.position != position, "Web two-finger scroll must pan")
	assert(is_equal_approx(game.camera_virtual_scale, scale), "Web pan must not zoom")
	gesture(game, ["magnify", 1.1, 0.0, 600.0, 250.0])
	assert(game.camera_virtual_scale > scale, "Web pinch must zoom")
	scale = game.camera_virtual_scale
	game.zoom_gesture_enabled = false
	gesture(game, ["magnify", 1.1, 0.0, 600.0, 250.0])
	assert(is_equal_approx(game.camera_virtual_scale, scale), "Pinch must respect the setting")
	position = game.camera.position
	gesture(game, ["pan", 16.0, 24.0, 600.0, 250.0])
	assert(game.camera.position != position, "Disabling pinch must not disable pan")
	position = game.camera.position
	game.paused = true
	gesture(game, ["pan", 16.0, 24.0, 600.0, 250.0])
	assert(game.camera.position == position, "Paused Web gestures must not move the camera")
	game.paused = false
	game.tech_tree_overlay = ColorRect.new()
	game.add_child(game.tech_tree_overlay)
	gesture(game, ["pan", 16.0, 24.0, 600.0, 250.0])
	assert(game.camera.position == position, "An input overlay must block Web camera movement")
	print("WEB_GESTURES_GD_OK")
	game.queue_free()
	await process_frame
	quit()

func gesture(game: Node, args: Array) -> void:
	game.platform_pointer._on_web_gesture(args)
	Input.flush_buffered_events()

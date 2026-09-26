extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Variant = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game("English", 4242)
	var worker: RtsUnit = game.units[0]
	var scout: RtsUnit = game.spawn_unit(0, "scout", Vector2(800, 700))
	var distant_worker: RtsUnit = game.spawn_unit(0, "villager", Vector2(2100, 820))
	game.camera.force_update_scroll()
	var double_click := InputEventMouseButton.new()
	double_click.button_index = MOUSE_BUTTON_LEFT
	double_click.pressed = true
	double_click.double_click = true
	double_click.position = game.get_viewport().get_canvas_transform() * worker.position
	game._unhandled_input(double_click)
	assert(game.selected.size() == 5, "double clicking a worker should select only visible workers of the same kind")
	assert(not game.selected.has(scout) and not game.selected.has(distant_worker))
	game.selected.clear()
	game.selected.append(scout)
	double_click.shift_pressed = true
	game._unhandled_input(double_click)
	assert(game.selected.size() == 6 and game.selected.has(scout), "Shift should add matching units to the selection")
	game.camera.position = Vector2(1950, 720)
	game.camera.force_update_scroll()
	game._select_same_type_visible(distant_worker, false)
	assert(game.selected.size() == 1 and game.selected.has(distant_worker), "moving the camera should select only units on the current screen")
	print("SELECTION_OK")
	quit()

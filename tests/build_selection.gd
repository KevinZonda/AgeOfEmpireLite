extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Variant = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game("English", 4242)
	await process_frame
	var worker: RtsUnit = game.units[0]
	game.selected.assign([worker])
	game._rebuild_actions()
	var site := Vector2.ZERO
	for x in range(450, 1150, 25):
		for y in range(450, 1150, 25):
			var candidate := Vector2(x, y)
			var screen_candidate: Vector2 = game.get_viewport().get_canvas_transform() * candidate
			if game.can_place("house", candidate) and not game._selection_point_over_hud(screen_candidate):
				site = candidate
				break
		if site != Vector2.ZERO: break
	assert(site != Vector2.ZERO)
	game.camera.position += site - game.get_global_mouse_position()
	game.camera.force_update_scroll()
	var screen_point: Vector2 = game.get_viewport().get_canvas_transform() * site
	var house_button: RtsCommandButton
	for command in game.command_buttons:
		if command.icon_kind == "house": house_button = command
	assert(house_button != null, "worker commands must include house construction")
	house_button.pressed.emit()
	assert(game.build_mode == "house")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = screen_point
	game._unhandled_input(press)
	assert(game.buildings.back().kind == "house", "left press should place the house")
	assert(game.selected == [worker], "placing a building should keep its builder selected")
	assert(game.selection_drag_phase == game.SelectionDragPhase.BLOCKED and game.selection_previous_left_down, "placement press must not become a selection press")
	game._advance_selection_pointer(screen_point, true)
	assert(game.selected == [worker] and not game.dragging, "selection polling must not select the new building")
	game._advance_selection_pointer(screen_point, false)
	assert(game.selection_drag_phase == game.SelectionDragPhase.IDLE, "release should re-enable later selections")
	print("BUILD_SELECTION_OK")
	quit()

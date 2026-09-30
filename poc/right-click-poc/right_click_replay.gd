extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Variant = load("res://poc/right-click-poc/right_click_fixture.gd").new()
	root.add_child(game)
	await process_frame
	game.start_game("English", 12345)
	game.set_process(false)
	game.fog.active = false
	game.camera.force_update_scroll()
	var scout: RtsUnit
	for unit in game.units:
		if unit.kind == "scout" and unit.owner_id == 0: scout = unit
	assert(scout != null)
	# Find empty visible land, so a stray selection completion clears selection.
	var target := Vector2.ZERO
	var screen := Vector2.ZERO
	for y in range(130, 440, 40):
		for x in range(200, 1000, 40):
			var point := Vector2(x, y)
			var world: Vector2 = root.get_canvas_transform().affine_inverse() * point
			if game.world_map.is_walkable(world) and game._entity_at(world) == null and game._resource_at(world) == null and not game._selection_point_over_hud(point):
				target = world
				screen = point
				break
		if screen != Vector2.ZERO: break
	assert(screen != Vector2.ZERO)
	var rows := []
	for scenario in ["right_only", "right_event_left_poll_after", "right_event_left_poll_before", "left_then_right_same_batch", "left_only"]:
		game.replay_left = false
		game.replay_point = screen
		game._cancel_selection_drag()
		game._reset_selection_pointer()
		game.selected.assign([scout])
		scout.order_stop()
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT if scenario == "left_only" else MOUSE_BUTTON_RIGHT
		event.pressed = true
		event.position = screen
		event.button_mask = MOUSE_BUTTON_MASK_RIGHT if scenario == "right_only" else MOUSE_BUTTON_MASK_LEFT
		if scenario == "left_then_right_same_batch":
			var early_left := InputEventMouseButton.new()
			early_left.button_index = MOUSE_BUTTON_LEFT
			early_left.pressed = true
			early_left.position = screen
			game.replay_left = true
			game._input(early_left)
			game._unhandled_input(early_left)
		if scenario == "right_event_left_poll_before":
			game.replay_left = true
			game._advance_selection_pointer(screen, true)
		else:
			game.replay_left = scenario != "right_only"
		game._input(event)
		game._unhandled_input(event)
		game._advance_selection_pointer(screen, game.replay_left)
		var dragging_after_press: bool = game.dragging
		var order_after_press: String = scout.order
		game.replay_left = false
		event.pressed = false
		event.button_mask = 0
		game._input(event)
		game._unhandled_input(event)
		game._advance_selection_pointer(screen, false)
		rows.append({"scenario": scenario, "synthetic": true, "target": [target.x, target.y], "order_after_press": order_after_press, "dragging_after_press": dragging_after_press, "selected_after_release": game.selected.size(), "selection_lost": not game.selected.has(scout)})
		if scenario in ["right_only", "right_event_left_poll_before", "left_then_right_same_batch"]:
			assert(game.selected.has(scout) and order_after_press == "move", "normal right or an already pending left must preserve selected scout")
		else:
			assert(game.selected.is_empty(), "left polling after right, or actual left click, should reproduce selection loss")
	var report := {"kind": "synthetic_event_state_replay", "physical_trackpad_reproduction": false, "rows": rows}
	var path := OS.get_environment("AOE_RIGHT_CLICK_REPLAY")
	if path != "":
		var file := FileAccess.open(path, FileAccess.WRITE)
		assert(file != null)
		file.store_line(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	print("RIGHT_CLICK_REPLAY_OK")
	quit()

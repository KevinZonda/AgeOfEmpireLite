extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Variant = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game("English", 4242)
	await process_frame
	assert(game.hud_bottom.get_rect().end.y <= game.get_viewport_rect().size.y, "bottom HUD should remain inside the default viewport")
	assert(game.hud_ui.selection_summary.visible and not game.hud_ui.selection_details_scroll.visible, "selection should start with a compact summary")
	var worker: RtsUnit = game.units[0]
	game.selected.clear()
	game.selected.append(worker)
	game._update_hud()
	assert(game.hud_ui.selection_summary.text.contains("工作速度"), "the compact summary should show the villager's current work")
	game.hud_ui.selection_details_button.pressed.emit()
	await process_frame
	assert(game.hud_ui.selection_details_scroll.visible and game.hud_ui.selection_details_scroll.size.y >= 70.0, "full unit details should be readable on demand")
	game.hud_ui.selection_details_button.pressed.emit()
	game.selected.clear()
	var scout: RtsUnit = game.spawn_unit(0, "scout", Vector2(800, 700))
	var distant_worker: RtsUnit = game.spawn_unit(0, "villager", Vector2(2100, 820))
	game.selected.clear()
	game.selected.append(worker)
	game.selected.append(scout)
	game.selected.append(distant_worker)
	game._rebuild_actions()
	game._update_hud()
	assert(game.hud_ui.multi_selection_grid.get_child_count() == 3, "multi-selection should show one icon per unit")
	var scout_icon: Button = game.hud_ui.multi_selection_grid.get_child(1)
	assert(scout_icon.tooltip_text.contains("侦察兵"), "each icon should identify its unit")
	scout_icon.pressed.emit()
	assert(game.selected.size() == 1 and game.selected[0] == scout, "clicking a multi-selection icon should select that unit alone")
	assert(game.info_label.text == "侦察兵" and game.hud_ui.multi_selection_grid.get_child_count() == 0, "unit details should replace the icon grid")
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
	game.fog.active = false
	for expected in [{"appearance": "berry", "label": "浆果"}, {"appearance": "deer", "label": "鹿"}, {"kind": "stone", "label": "石矿"}]:
		var resource: RtsResource
		for candidate in game.resources:
			if (expected.has("appearance") and candidate.appearance != expected["appearance"]) or (expected.has("kind") and candidate.kind != expected["kind"]): continue
			if game._entity_at(candidate.position) == null and game._resource_at(candidate.position) == candidate:
				resource = candidate
				break
		assert(resource != null, "test needs a clickable %s" % expected["label"])
		game._select_area(resource.position, resource.position, false)
		assert(game.selected.size() == 1 and game.selected[0] == resource, "click should select %s" % expected["label"])
		assert(game.info_label.text == expected["label"] and game.queue_label.text.contains(str(resource.amount)), "selected resource should show its name and amount")
		assert(game.detail_label.text.contains("资源类型") and game.detail_label.text.contains("当前状态"))
		assert(game.command_title.text == "采集方式")
		assert(game._cursor_state_at(resource.position) == "select")
		if expected["label"] == "浆果":
			game._select_area(worker.position, worker.position, true)
			assert(game.selected.size() == 1 and game.selected[0] == worker, "Shift-selecting a unit should replace resource details")
		if expected["label"] == "石矿":
			resource.harvest(resource.amount)
			game._prune_hidden_enemy_selection()
			assert(game.selected.is_empty(), "depleted resource should leave selection")
	print("SELECTION_OK")
	quit()

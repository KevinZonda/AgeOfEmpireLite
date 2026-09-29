extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game("English", 4242)
	var center: RtsBuilding = game._player_center(0)
	assert(game.selected.size() == 1 and game.selected[0] == center)
	game.ui_scale = 1.0
	for text_scale in [1.0, 1.25, 1.5, 2.0]:
		game.text_scale = text_scale
		game._apply_ui_scales()
		game._update_hud()
		for frame in 3: await process_frame
		var before := _panel_rects(game)
		var outer_before := before.slice(0, 3)
		game.selected.clear()
		game.selected.append(game.units[0])
		game._rebuild_actions()
		game._update_hud()
		for frame in 3: await process_frame
		assert(_panel_rects(game).slice(0, 3) == outer_before, "switching from the town center to a villager must not move the HUD at %s text scale" % text_scale)
		game.selected.clear()
		game.selected.append(center)
		game._rebuild_actions()
		game._update_hud()
		for frame in 3: await process_frame
		assert(_panel_rects(game).slice(0, 3) == outer_before, "switching back to the town center must not move the HUD at %s text scale" % text_scale)
		assert(game.hud_ui.queue_scroll.visible, "a production building should reserve queue space before training")
		var train_button: Button
		for button in game.command_buttons:
			if button.icon_kind == "villager": train_button = button
		assert(train_button != null, "the town center should have a villager button")
		var button_edge := train_button.get_global_rect().position + Vector2(2.0, train_button.size.y * 0.5)
		assert(game._edge_pan_direction(button_edge, game.get_viewport_rect().size) == Vector2.ZERO, "hovering the first command button must not pan the camera")
		var battlefield_y: float = (game.hud_top.get_global_rect().end.y + game.hud_bottom.get_global_rect().position.y) * 0.5
		assert(game._edge_pan_direction(Vector2(2.0, battlefield_y), game.get_viewport_rect().size) == Vector2.LEFT, "edge scrolling should still work over the battlefield")
		assert(game.train_unit(center, "villager"), "the town center should train a villager")
		for frame in 3: await process_frame
		assert(_panel_rects(game) == before, "training must not move the bottom HUD or its panels at %s text scale" % text_scale)
		assert(game.queue_controls.get_child_count() == 1 and game.queue_controls.get_child(0) is Button, "the queued villager should appear")
		assert(game.cancel_production_job(center), "the queued villager should be cancellable")
		for frame in 3: await process_frame
		assert(_panel_rects(game) == before, "cancelling training must not move the bottom HUD or its panels at %s text scale" % text_scale)
		assert(game.queue_controls.get_child_count() == 1 and game.queue_controls.get_child(0) is Label, "the empty queue should have a placeholder")
	root.size = Vector2i(2940, 1840)
	game.ui_scale = 1.5
	game.text_scale = 1.75
	game._apply_ui_scales()
	game._update_hud()
	for frame in 3: await process_frame
	var large_screen_rects := _panel_rects(game).slice(0, 3)
	game.selected.clear()
	game.selected.append(game.units[0])
	game._rebuild_actions()
	game._update_hud()
	for frame in 3: await process_frame
	assert(_panel_rects(game).slice(0, 3) == large_screen_rects, "villager selection must keep the town center panel size at 2940x1840")
	game.selected.clear()
	game.selected.append(center)
	game._rebuild_actions()
	game._update_hud()
	for frame in 3: await process_frame
	assert(_panel_rects(game).slice(0, 3) == large_screen_rects, "town center selection must keep the panel size at 2940x1840")
	assert(game.train_unit(center, "villager"))
	for frame in 3: await process_frame
	assert(_panel_rects(game).slice(0, 3) == large_screen_rects, "training at 2940x1840 must keep the panel size")
	print("HUD_QUEUE_LAYOUT_OK")
	quit()

func _panel_rects(game: Node) -> Array[Rect2]:
	var dock: Control = game.hud_bottom.get_child(0)
	return [
		game.hud_bottom.get_global_rect(),
		dock.get_child(0).get_global_rect(),
		dock.get_child(1).get_global_rect(),
		game.hud_ui.queue_scroll.get_global_rect(),
	]

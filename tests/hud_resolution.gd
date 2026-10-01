extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Variant = load("res://scenes/main.tscn").instantiate()
	game.ui_scale = 1.0
	game.text_scale = 1.0
	game.minimap_size = 216
	root.add_child(game)
	await process_frame
	game.start_game("English", 4242)
	game.selected.clear()
	game.selected.append(game.units[0])
	game.build_page = 0
	game._rebuild_actions()
	await process_frame
	if game.view_mode_25d:
		game._toggle_view_mode()
		await process_frame
	assert(game.action_bar.get_child_count() == 15, "the construction page should keep all twelve commands")
	assert(game.action_bar.get_rect().end.y <= game.action_bar.get_parent().size.y, "all command rows should be visible")
	for resolution in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		root.size = resolution
		await process_frame
		assert(game.get_viewport_rect().size == Vector2(resolution), "game view should follow window resolution")
		assert(game.hud_bottom.size.y <= 241.0, "bottom HUD should leave more room for the battlefield")
		assert(game.hud_top.size.y <= 54.0, "resource HUD should be a compact single row")
		assert(is_equal_approx(game.hud_bottom.get_rect().end.y, float(resolution.y)), "bottom HUD should stay at the window edge")
		assert(is_equal_approx(game.minimap.size.x, game.minimap.size.y), "the 2D minimap should remain square at every resolution")
		assert(is_equal_approx(game.hud_ui.minimap_panel.size.x, game.hud_ui.minimap_panel.size.y), "the minimap panel should have a 1:1 footprint")
		assert(is_equal_approx(game.hud_ui.minimap_panel.size.y, 230.0), "the default minimap frame should fit a 216px map with 7px padding")
		assert(game.hud_bottom.size.y + game.hud_top.size.y <= 295.0, "default HUD panels should reserve at least 425px of battlefield at 720p")
		assert(game.minimap.get_global_rect().position.y >= game.hud_bottom.get_global_rect().position.y, "the default minimap should stay inside the battlefield edge")
	root.size = Vector2i(1280, 720)
	game.minimap_size = 264
	game.hud_ui._apply_minimap_size()
	await process_frame
	assert(is_equal_approx(game.hud_bottom.size.y, 241.0), "changing minimap size should not change the bottom HUD height")
	assert(is_equal_approx(game.hud_bottom.get_rect().end.y, 720.0), "a large minimap should not push the HUD below the screen")
	assert(game.minimap.size.is_equal_approx(Vector2(264, 264)), "the 2D minimap should follow its size setting")
	assert(game.hud_ui.minimap_panel.get_global_rect().position.y < game.hud_bottom.get_global_rect().position.y, "the large 2D minimap should extend above the bottom HUD")
	var protruding_map_point := Vector2(game.minimap.size.x * 0.5, 10.0)
	var protruding_click := InputEventMouseButton.new()
	protruding_click.button_index = MOUSE_BUTTON_LEFT
	protruding_click.pressed = true
	protruding_click.position = game.minimap.get_global_transform_with_canvas() * protruding_map_point
	game.get_viewport().push_input(protruding_click, true)
	assert(game.camera.position.distance_to(game.minimap.map_to_world(protruding_map_point)) < 1.0, "the protruding 2D map should remain clickable")
	game.minimap_size = 160
	game.hud_ui._apply_minimap_size()
	await process_frame
	assert(game.hud_ui.minimap_panel.size.is_equal_approx(Vector2(174, 174)), "switching from large to small should shrink the frame")
	game.minimap_size = 216
	game.hud_ui._apply_minimap_size()
	await process_frame
	var center: RtsBuilding = game._player_center(0)
	center.enqueue("villager")
	game.selected.clear()
	game.selected.append(center)
	game._rebuild_actions()
	game._update_hud()
	await process_frame
	assert(game.queue_controls.visible, "production queue controls should remain visible")
	assert(game.hud_bottom.size.y <= 241.0, "production queue should fit in the bottom HUD")
	assert(game.queue_controls.get_global_rect().end.y <= game.hud_bottom.get_global_rect().end.y, "queued units must remain fully inside the HUD")
	assert(game.hud_ui.notice_label.get_global_rect().end.y <= game.hud_bottom.get_global_rect().end.y, "queue controls must leave room for feedback")
	game.ui_scale = 1.5
	game.text_scale = 2.0
	game._apply_ui_scales()
	game.civilizations[0] = "Chinese"
	game.players[0]["dynasty"] = "Tang"
	game._update_hud()
	for frame in 3: await process_frame
	assert(game.hud_top.get_global_rect().end.x <= 1280.0, "large Chinese top HUD should fit within the screen")
	assert(game.hud_ui.top_tools.get_parent() == game.hud_ui.top_column, "top tools should wrap when large text needs another row")
	assert(is_equal_approx(game.hud_bottom.get_global_rect().end.y, 720.0), "large text must not push the bottom HUD off screen")
	game.selected.clear()
	game.selected.append(game.units[0])
	game.build_page = 0
	game._rebuild_actions()
	game._update_hud()
	for frame in 3: await process_frame
	assert(game.action_bar.get_child_count() == 15, "large text should retain the full villager construction page")
	assert(game.action_bar.get_rect().end.y <= game.action_bar.get_parent().size.y, "all construction commands should remain visible with large text")
	assert(game.hud_bottom.size.y <= 300.0, "compact selection summary should preserve battlefield space")
	root.size = Vector2i(1920, 1080)
	for frame in 3: await process_frame
	assert(game.hud_ui.top_tools.get_parent() == game.hud_ui.top_row, "top tools should return to a single row when space allows")
	assert(is_equal_approx(game.hud_bottom.get_global_rect().end.y, 1080.0), "bottom HUD should track a larger screen")
	print("HUD_RESOLUTION_OK")
	quit()

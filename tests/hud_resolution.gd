extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Variant = load("res://scenes/main.tscn").instantiate()
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
	assert(game.action_bar.get_child_count() == 12, "the construction page should keep all twelve commands")
	assert(game.action_bar.get_rect().end.y <= game.action_bar.get_parent().size.y, "all command rows should be visible")
	for resolution in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		root.size = resolution
		await process_frame
		assert(game.get_viewport_rect().size == Vector2(resolution), "game view should follow window resolution")
		assert(game.hud_bottom.size.y <= 244.0, "bottom HUD should keep a fixed height")
		assert(is_equal_approx(game.hud_bottom.get_rect().end.y, float(resolution.y)), "bottom HUD should stay at the window edge")
		assert(is_equal_approx(game.minimap.size.x, game.minimap.size.y), "the 2D minimap should remain square at every resolution")
		assert(is_equal_approx(game.hud_ui.minimap_panel.size.x, game.hud_ui.minimap_panel.size.y), "the minimap panel should have a 1:1 footprint")
		assert(is_equal_approx(game.hud_ui.minimap_panel.size.y, game.hud_bottom.size.y - 14.0), "the minimap panel should fill the bottom HUD without vertical gaps")
	root.size = Vector2i(1280, 720)
	game.minimap_size = 264
	game.hud_ui._apply_minimap_size()
	await process_frame
	assert(is_equal_approx(game.hud_bottom.get_rect().end.y, 720.0), "a large minimap should not push the HUD below the screen")
	assert(game.minimap.size.is_equal_approx(Vector2(264, 264)), "the 2D minimap should follow its size setting")
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
	assert(game.hud_bottom.size.y <= 244.0, "production queue should fit in the bottom HUD")
	print("HUD_RESOLUTION_OK")
	quit()

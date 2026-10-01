extends "res://poc/exploration-2026-10-02/explore.gd"

# Render the real game state left by three deterministic exploratory cases.
# Only this test's in-memory display preferences are adjusted; nothing is saved.
func _run() -> void:
	Engine.max_fps = 60
	for id in ["trade_return_market", "supervise_town_center", "selection_after_garrison"]:
		setup_case()
		game.ui_scale = 1.0
		game.text_scale = 1.0
		game._apply_ui_scales()
		if game.view_mode_25d: game._toggle_view_mode()
		await run_case(id)
		var point: Vector2
		if id == "trade_return_market":
			var trader: RtsUnit = game.units.filter(func(u): return u.kind == "trader")[0]
			game.selected.assign([trader])
			point = trader.trade_home.position
		else:
			point = game._player_center(0).position
		game.camera.position = point
		game.camera.zoom = Vector2(1.4, 1.4)
		game.camera.force_update_scroll()
		game._update_hud()
		game._rebuild_actions()
		var layer := CanvasLayer.new()
		game.add_child(layer)
		var panel := PanelContainer.new()
		panel.position = Vector2(15, 65)
		panel.size = Vector2(1050, 90)
		layer.add_child(panel)
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 18)
		label.text = "PoC: " + id + "\n" + JSON.stringify(results.back().evidence)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		panel.add_child(label)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var path := "res://poc/exploration-2026-10-02/screenshots/%s.png" % id
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://poc/exploration-2026-10-02/screenshots"))
		var error := root.get_texture().get_image().save_png(path)
		print("WITNESS ", id, " saved=", error)
		game.navigation.shutdown_jobs()
		game.queue_free()
		await process_frame
	quit()

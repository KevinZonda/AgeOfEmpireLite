extends SceneTree

# Recreate the old map marker for a reproducible comparison without changing
# objective rules or replacing the live objective manager.
class OldMarker extends Node2D:
	var site: Dictionary
	func _draw() -> void:
		var color := Color("b7b0a0")
		draw_circle(Vector2.ZERO, 28.0, Color(color, 0.2))
		draw_arc(Vector2.ZERO, 31.0, 0.0, TAU, 36, color, 4.0)
		draw_arc(Vector2.ZERO, RtsObjectiveManager.SITE_RADIUS, 0.0, TAU, 48, Color(color, 0.32), 2.0)
		draw_string(ThemeDB.fallback_font, Vector2(-8, 7), "II", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.selected_map_style = "balanced"
	game.start_game("English", 12345)
	game.paused = true
	game.fog.active = false
	game.fog.hide()
	game.weather.hide()
	root.size = Vector2i(1280, 720)
	var site: Dictionary = game.objectives.sacred_sites[1]
	var point: Vector2 = site["position"]
	var monk: RtsUnit = game.spawn_unit(0, "monk", game.world_map.nearest_walkable_point(point + Vector2(55, 35)))
	monk.show()
	monk._face_direction(point - monk.position)
	game.selected.clear()
	game.selected.append(monk)
	game._rebuild_actions()
	game._update_hud()
	var baseline := OS.get_cmdline_user_args().has("--before")
	if baseline:
		game.objectives.hide()
		var marker := OldMarker.new()
		marker.site = site
		marker.position = point
		marker.z_index = -7
		game.add_child(marker)
	var directory := "res://docs/sacred-site-refinement"
	DirAccess.make_dir_recursive_absolute(directory)
	for iso in [true, false]:
		if game.view_mode_25d != iso: game._toggle_view_mode()
		game.camera.position = point
		game.camera.zoom = Vector2(2.4, 1.2 if iso else 2.4)
		game.camera.force_update_scroll()
		game.camera.position += root.get_canvas_transform().affine_inverse().basis_xform(Vector2(0, 90))
		game.camera.force_update_scroll()
		if not baseline:
			for state in ["neutral", "captured"]:
				site["owner_id"] = 0 if state == "captured" else -1
				game.objectives.queue_redraw()
				for visual in game.objectives.get_children():
					if visual.has_method("sync_visual"): visual.sync_visual()
				await _capture(directory.path_join("in-game-%s-%s.png" % [state, "25d" if iso else "2d"]))
		else:
			await _capture(directory.path_join("before-in-game-%s.png" % ("25d" if iso else "2d")))
	print("SACRED_SITE_GAME_PREVIEW_OK")
	quit()

func _capture(path: String) -> void:
	for frame in 4:
		await process_frame
		await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(path) == OK)

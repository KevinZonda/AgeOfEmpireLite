extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _site(game: Node, kind: String, target: Vector2) -> Vector2:
	for radius in range(0, 256, 16):
		for i in 32:
			var candidate: Vector2 = game.snap_build_point(kind, target + Vector2(radius, 0).rotated(TAU * i / 32))
			if not game.can_place(kind, candidate): continue
			var clear: Rect2 = game.build_footprint_rect(kind, candidate).grow(24)
			var valid := true
			for building in game.buildings:
				if clear.intersects(game.build_footprint_rect(building.kind, building.position)): valid = false
			for resource in game.resources:
				if clear.grow(resource.radius).has_point(resource.position): valid = false
			if valid: return candidate
	assert(false, "No clear demo location")
	return target
func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var output := OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "res://docs/western-landmark-refinement"
	DirAccess.make_dir_recursive_absolute(output)
	game.selected_map_style = "lakes"
	game.start_game("English", 431)
	game.paused = true
	if not game.view_mode_25d: game._toggle_view_mode()
	var center: Vector2 = game.spawn_point_for(0) + Vector2(350, 250)
	var group: Array[RtsBuilding] = []
	for i in 4:
		var id: String = ["eng_council_hall", "eng_wynguard_palace", "fr_chamber_of_commerce", "fr_college_of_artillery"][i]
		var kind := "landmark"
		var delta := Vector2([-260, -90, 70, 235][i], 0).rotated(-PI / 4)
		group.append(game.spawn_building(0, kind, _site(game, kind, center + delta), false, id))
	center = Vector2.ZERO
	for building in group: center += building.position / 4
	game.camera.position = center + Vector2(0, 110).rotated(-PI / 4)
	game.camera.zoom = Vector2(1.4, 0.7)
	game.fog.active = false
	game.fog.hide()
	game.weather.hide()
	for building in game.buildings:
		building.show()
		building.modulate = Color.WHITE
	game.selected.clear()
	game.selected.append(group[3])
	game._rebuild_actions()
	game._update_hud()
	root.size = Vector2i(1280, 720)
	game.camera.force_update_scroll()
	for i in 4:
		await process_frame
		await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output.path_join("in-game.png")) == OK)
	print("WESTERN_LANDMARK_GAME_CAPTURE_OK: ", output.path_join("in-game.png"))
	quit()

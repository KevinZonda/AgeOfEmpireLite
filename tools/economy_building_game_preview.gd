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
	DirAccess.make_dir_recursive_absolute("res://docs/economy-building-refinement")
	game.start_game("English", 12345)
	game.paused = true
	if not game.view_mode_25d: game._toggle_view_mode()
	var center: Vector2 = game.spawn_point_for(0) + Vector2(400, 300)
	var group: Array[RtsBuilding] = []
	for i in 5:
		var kind: String = ["town_center", "mill", "lumber_camp", "mining_camp", "siege_workshop"][i]
		var delta := Vector2([-320, -160, 0, 160, 320][i], 0).rotated(-PI / 4)
		group.append(game.spawn_building(0, kind, _site(game, kind, center + delta)))
	center = Vector2.ZERO
	for building in group: center += building.position / 5
	game.camera.position = center + Vector2(0, 110).rotated(-PI / 4)
	game.camera.zoom = Vector2(1.4, 0.7)
	game.fog.active = false
	game.fog.hide()
	game.weather.hide()
	for building in game.buildings:
		building.show()
		building.modulate = Color.WHITE
	game.selected.clear()
	game.selected.append(group[4])
	game._rebuild_actions()
	game._update_hud()
	root.size = Vector2i(1600, 900)
	game.camera.force_update_scroll()
	for i in 5:
		await process_frame
		await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://docs/economy-building-refinement/in-game.png") == OK)
	print("ECONOMY_BUILDING_GAME_CAPTURE_OK")
	quit()

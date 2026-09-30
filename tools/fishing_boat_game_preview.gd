extends SceneTree

const VisualState = preload("res://scripts/entities/visuals/unit_visual_state.gd")

# Reproducible production scene: working and sailing boats beside a real dock.
func _initialize() -> void:
	call_deferred("_run")

func _dock_site(game, fish: Vector2) -> Vector2:
	for distance in range(64, 480, 16):
		for direction in 32:
			var candidate: Vector2 = game.snap_build_point("dock", fish + Vector2(distance, 0).rotated(direction * TAU / 32.0))
			if game.can_place("dock", candidate): return candidate
	return Vector2.INF

func _working_spot(game, fish: Vector2, index: int) -> Vector2:
	for turn in 32:
		var candidate := fish + Vector2(34, 0).rotated(index * PI + turn * TAU / 32.0)
		var clear := true
		for side in 8:
			if not game.world_map.is_navigable(candidate + Vector2(14, 0).rotated(side * TAU / 8.0)):
				clear = false
		if clear: return candidate
	return Vector2.INF

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.selected_map_style = "lakes"
	game.start_game("English", 431)
	game.paused = true
	var fish: RtsResource
	var dock_point := Vector2.INF
	for resource in game.resources:
		if resource.appearance != "fish": continue
		if _working_spot(game, resource.position, 0) == Vector2.INF or _working_spot(game, resource.position, 1) == Vector2.INF: continue
		dock_point = _dock_site(game, resource.position)
		if dock_point != Vector2.INF:
			fish = resource
			break
	assert(fish != null, "The demo seed needs fish near a valid dock site")
	game.spawn_building(0, "dock", dock_point)
	var boats: Array[RtsUnit] = []
	for index in 4:
		var offset := Vector2(34, 0).rotated(index * PI / 2.0) if index < 2 else Vector2(110, 0).rotated(index * PI / 2.0)
		var spot: Vector2 = _working_spot(game, fish.position, index) if index < 2 else game.world_map.nearest_water_point(fish.position + offset)
		var boat: RtsUnit = game.spawn_unit(0, "fishing_boat", spot)
		# Spawn snaps to cell centers; place these paused working examples at the
		# checked point so their real snapshot lies inside harvesting distance.
		boat.position = spot
		boat.visual_last_position = spot
		boat.visual_phase = index * 0.9 + 0.5
		if index < 2:
			boat.order_gather(fish)
			boat.work_timer = 0.3 if index == 0 else 0.8
			boat._face_direction(fish.position - spot)
			assert(VisualState.capture(boat).fishing_active, "Working examples must render from a real active fishing snapshot")
		else:
			boat.visual_moving = true
			boat._face_direction(Vector2(-1, 1) if index == 2 else Vector2(1, -1))
		boats.append(boat)
	game.fog.active = false
	game.fog.hide()
	game.weather.hide()
	for resource in game.resources: resource.show()
	for building in game.buildings: building.show()
	for boat in boats: boat.show()
	game.selected.clear()
	game.selected.append(boats[0])
	game._rebuild_actions()
	game._update_hud()
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute("res://docs/fishing-boat-refinement")
	for iso in [false, true]:
		if game.view_mode_25d != iso: game._toggle_view_mode()
		game.camera.position = fish.position.lerp(dock_point, 0.35)
		game.camera.zoom = Vector2(2.0, 1.0 if iso else 2.0)
		game.camera.force_update_scroll()
		# Center the scene in the map area above the HUD.
		game.camera.position += root.get_canvas_transform().affine_inverse().basis_xform(Vector2(0, 85))
		game.camera.force_update_scroll()
		for boat in boats: boat.queue_redraw()
		for frame in 4:
			await process_frame
			await RenderingServer.frame_post_draw
		var suffix := "25d" if iso else "2d"
		assert(root.get_texture().get_image().save_png("res://docs/fishing-boat-refinement/in-game-%s.png" % suffix) == OK)
	print("FISHING_GAME_PREVIEW_OK")
	quit()

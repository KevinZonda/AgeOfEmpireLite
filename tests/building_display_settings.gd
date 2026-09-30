extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.selected_view_mode_25d = false
	game.start_game("English", 12345)
	game.paused = true
	var own_center: RtsBuilding = game._player_center(0)
	var enemy_center: RtsBuilding = game._player_center(1)
	var house: RtsBuilding = game.spawn_building(1, "house", enemy_center.position + Vector2(-190, 0))
	var scout: RtsUnit = game.units[0]
	var original_position := scout.position
	for isometric in [false, true]:
		if game.view_mode_25d != isometric: game._toggle_view_mode()
		scout.position = house.position + Vector2(-75, 0)
		game.fog.update_visibility()
		assert(house.visible)
		if not await _check_toggles(game, [own_center, house]):
			quit(1)
			return
		var ghost = game.fog.remembered_buildings[house.get_instance_id()]["ghost"]
		scout.position = original_position
		game.fog.update_visibility()
		assert(ghost.visible and not house.visible)
		var last_seen_hp: float = ghost.state.hp
		house.hp -= 10.0
		if not await _check_toggles(game, [own_center, ghost]):
			quit(1)
			return
		assert(ghost.state.hp == last_seen_hp, "display refresh must preserve last-seen simulation values")
	game.free()
	print("BUILDING_DISPLAY_SETTINGS_OK")
	quit()

func _check_toggles(game, visuals: Array) -> bool:
	for preferences in [[true, true], [false, true], [true, false], [false, false], [true, true]]:
		game.show_building_icons = preferences[0]
		game.show_building_names = preferences[1]
		# This is the refresh path used when saving settings, with no camera change.
		game._redraw_projected_entities()
		await process_frame
		await process_frame
		for visual in visuals:
			var state = visual.building_visual_state if visual is RtsBuilding else visual.state
			if state.show_building_icons != preferences[0] or state.show_building_names != preferences[1]:
				push_error("Building display did not refresh: %s, isometric=%s, icons=%s, names=%s" % [visual.name, game.view_mode_25d, preferences[0], preferences[1]])
				return false
	return true

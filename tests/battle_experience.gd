extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game("English", 4242)
	game.camera.position = game.world_size * 0.5
	game._toggle_view_mode()
	var before_pan: Vector2 = game.camera.position
	game.camera.force_update_scroll()
	var tracked_before: Vector2 = game.get_viewport().get_canvas_transform() * (game.world_size * 0.5)
	game._move_camera_screen_delta(Vector2(0, 120))
	assert(game.camera.position.y > before_pan.y + 50.0, "2.5D vertical panning must not be pinned")
	game.camera.force_update_scroll()
	var tracked_after: Vector2 = game.get_viewport().get_canvas_transform() * (game.world_size * 0.5)
	assert(tracked_after.distance_to(tracked_before - Vector2(0, 120)) < 2.0, "2.5D panning should follow screen axes")
	game.camera.position = game.world_size * 0.5
	game.camera.force_update_scroll()
	var anchor := Vector2(830, 310)
	var before_zoom: Vector2 = game.get_viewport().get_canvas_transform().affine_inverse() * anchor
	game._adjust_zoom(1.1, anchor)
	game.camera.force_update_scroll()
	var after_zoom: Vector2 = game.get_viewport().get_canvas_transform().affine_inverse() * anchor
	assert(before_zoom.distance_to(after_zoom) < 2.0, "zoom should retain the map point under the cursor")
	var soldiers: Array[RtsUnit] = []
	for i in 8:
		var soldier: RtsUnit = game.spawn_unit(0, "spearman", game._scaled_point(Vector2(520 + (i % 4) * 30, 650 + (i / 4) * 30)))
		soldier.order_stop()
		soldiers.append(soldier)
	game.selected.clear()
	game.selected.append(soldiers[0])
	game._rebuild_actions()
	var line_button: RtsCommandButton
	for button in game.command_buttons:
		if button.caption.contains("横队阵型"):
			line_button = button
			break
	assert(line_button != null)
	line_button.pressed.emit()
	assert(game.formation_mode == "line")
	var line := RtsMovementGroup.new(game, soldiers, game._scaled_point(Vector2(940, 700)), "line", 8)
	line.activate()
	assert(line.slots.size() == 8)
	var lateral_positions: Array[float] = []
	var lateral := Vector2(-line.heading.y, line.heading.x)
	for soldier in soldiers: lateral_positions.append(line.slots[soldier.get_instance_id()].dot(lateral))
	assert(lateral_positions.max() - lateral_positions.min() > 190.0, "line width should spread the squad")
	var enemy: RtsUnit = game.spawn_unit(1, "spearman", soldiers[0].position + Vector2(70, 0))
	soldiers[0].engagement = "passive"
	soldiers[0]._process_idle_order()
	assert(soldiers[0].order == "idle", "passive units should not acquire targets")
	soldiers[0].engagement = "defensive"
	soldiers[0].awareness_timer = 0.0
	soldiers[0]._process_idle_order()
	assert(soldiers[0].order == "attack" and soldiers[0].target == enemy)
	soldiers[0].position += Vector2(230, 0)
	soldiers[0]._process_attack_order(0.01)
	assert(soldiers[0].order == "move" and soldiers[0].destination.distance_to(soldiers[0].engagement_origin) <= RtsWorldMap.CELL_SIZE, "defensive units should return after pursuing")
	game.credit_resource(0, "wood", 25)
	game.match_statistics.tick(5.1)
	assert(game.match_statistics.samples.size() >= 2)
	assert(game.match_statistics.samples.back()["players"][0]["income"] >= 25)
	game._finish_game(true)
	game._show_match_report(true, "测试")
	assert(game.result_panel.find_children("*", "RtsStatisticsChart", true, false).size() == 1)
	assert(game.result_panel.find_children("*", "RtsBattleReplayMap", true, false).size() == 1)
	game._return_to_menu()
	await process_frame
	assert(game.result_panel.get_child_count() == 0, "report playback should be released on exit")
	print("BATTLE_EXPERIENCE_OK")
	quit()

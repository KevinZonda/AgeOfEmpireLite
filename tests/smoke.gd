extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://scenes/main.tscn")
	var game: Variant = scene.instantiate()
	root.add_child(game)
	await process_frame
	game.start_game("English")
	assert(game.units.size() == 10, "both civilizations should have starting villagers")
	assert(game.buildings.size() == 2, "both civilizations should have town centers")
	assert(game.population_cap(0) == 10)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	game._input(escape)
	assert(game.paused and game.pause_overlay.visible)
	assert(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	assert(not game.cursor.visible)
	var frozen_position: Vector2 = game.units[0].position
	game.units[0]._process(1.0)
	assert(game.units[0].position == frozen_position)
	game._input(escape)
	assert(not game.paused and not game.pause_overlay.visible)
	assert(game.cursor.visible)
	assert(game._edge_pan_direction(Vector2(640, 360), Vector2(1280, 720)) == Vector2.ZERO)
	assert(game._edge_pan_direction(Vector2(2, 360), Vector2(1280, 720)) == Vector2.LEFT)
	assert(game._edge_pan_direction(Vector2(1278, 718), Vector2(1280, 720)) == Vector2(1, 1))
	assert(game._edge_pan_direction(Vector2(-2, 360), Vector2(1280, 720)) == Vector2.ZERO)
	assert(game._cursor_state_at(game.units[0].position) == "select")
	var center: RtsBuilding = game._player_center(0)
	game.selected.append(center)
	game._rebuild_actions()
	assert(game.command_buttons.size() == 2, "Town Center should have train and age-up commands")
	assert(game.hotkey_buttons.has(KEY_1))
	game.command_buttons[0].pressed.emit()
	assert(center.training_queue.size() == 1, "train command should enqueue a villager")
	game.selected.clear()
	var midpoint: Vector2 = game.minimap.map_to_world(game.minimap.size * 0.5)
	assert(midpoint.distance_to(game.world_size * 0.5) < 1.0)
	var map_click := InputEventMouseButton.new()
	map_click.button_index = MOUSE_BUTTON_LEFT
	map_click.pressed = true
	map_click.position = game.minimap.size * 0.5
	game.minimap._gui_input(map_click)
	assert(game.camera.position.distance_to(game.world_size * 0.5) < 1.0)
	assert(game.advance_age(0))
	assert(game.players[0]["age"] == 2)
	var worker: RtsUnit = game.units[0]
	game.selected.append(worker)
	game._rebuild_actions()
	assert(game.command_buttons.size() == 5, "villager should see all unlocked construction commands")
	game.command_buttons[1].pressed.emit()
	assert(game.build_mode == "farm", "second construction command should select a farm")
	game.build_mode = ""
	assert(game._cursor_state_at(game._player_center(1).position) == "attack")
	assert(game._cursor_state_at(game.resources[0].position) == "gather")
	assert(game._cursor_state_at(Vector2(700, 700)) == "move")
	assert(game._cursor_state_at(Vector2(700, 700), true) == "default")
	var helper: RtsUnit = game.units[1]
	game.selected.append(helper)
	var wood_before: int = game.players[0]["wood"]
	game.build_mode = "barracks"
	game._confirm_build(Vector2(570, 800))
	assert(game.players[0]["wood"] == wood_before - 160, "building cost is paid once")
	game.build_mode = "house"
	assert(game._cursor_state_at(Vector2(570, 800)) == "build_invalid")
	assert(game._cursor_state_at(Vector2(700, 800)) == "build_valid")
	game.build_mode = ""
	var barracks: RtsBuilding = game.buildings.back()
	assert(worker.order == "build" and helper.order == "build")
	assert(game.count_builders(barracks) == 2)
	worker.position = barracks.position + Vector2(50, 0)
	helper.position = barracks.position + Vector2(-50, 0)
	worker._process(1.0)
	helper._process(1.0)
	assert(is_equal_approx(barracks.build_remaining, barracks.build_total - 2.0), "two builders should double construction progress")
	worker.order_move(Vector2(700, 800))
	helper.order_move(Vector2(700, 800))
	var saved_progress: float = barracks.build_remaining
	assert(game.count_builders(barracks) == 0)
	game._issue_order(barracks.position)
	assert(worker.order == "build" and helper.order == "build", "right click should resume construction")
	assert(game._cursor_state_at(barracks.position) == "construct")
	assert(is_equal_approx(barracks.build_remaining, saved_progress), "interruption should preserve progress")
	worker._process(1.0)
	helper._process(1.0)
	assert(is_equal_approx(barracks.build_remaining, saved_progress - 2.0))
	barracks.advance_construction(100.0)
	assert(barracks.is_complete())
	assert(game.train_unit(barracks, "spearman"))
	game.start_game("French")
	var unfinished_ai_building: RtsBuilding = game.spawn_building(1, "house", Vector2(1750, 850), true)
	assert(game.count_builders(unfinished_ai_building) == 0)
	game.ai.tick()
	assert(game.count_builders(unfinished_ai_building) > 0, "AI should resume an abandoned building")
	assert(game.civilizations[0] == "French")
	assert(not GameData.can_use_unit("French", "longbow"))
	assert(GameData.can_use_unit("French", "knight"))
	assert(GameData.gathered_amount("English", "food", true) > GameData.gathered_amount("French", "food", true))
	assert(GameData.training_time("French", "stable", "knight") < GameData.UNITS["knight"]["time"])
	for i in 20:
		await process_frame
	assert(game.players[1]["age"] == 2, "AI should advance to age 2")
	game._player_center(1).take_damage(2000)
	assert(game.game_over, "destroying the opposing Town Center should end the match")
	print("SMOKE_OK")
	quit()

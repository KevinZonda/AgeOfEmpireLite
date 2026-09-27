extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	assert(not game.started and game.menu_panel.visible)
	var home_start: Button
	for child in game.menu_panel.get_child(0).get_children():
		if child is Button and child.text == "开 始 游 戏": home_start = child
	assert(home_start != null)
	home_start.pressed.emit()
	assert(game.player_list.get_child_count() == 2)
	game.add_player_button.pressed.emit()
	game.add_player_button.pressed.emit()
	assert(game.lobby_players.size() == 4 and game.add_player_button.disabled)
	game.lobby_players[1]["difficulty"] = "easy"
	game.lobby_players[1]["civilization"] = "Chinese"
	game.lobby_players[2]["difficulty"] = "hard"
	game.lobby_players[3]["civilization"] = "French"
	game.map_style_choice.select(3)
	game.map_size_choice.select(1)
	game.projection_choice.select(1)
	game.initial_resources_choice.select(2)
	game.team_choice.select(1)
	game.map_seed_input.text = "54321"
	game._begin_menu_match()
	assert(game.started and game.players.size() == 4)
	assert(game.teams == [0, 1, 0, 1])
	assert(game.civilizations == ["English", "Chinese", "Chinese", "French"])
	assert(game.players[0]["food"] == 700 and game.players[3]["stone"] == 300)
	assert(game.map_seed == 54321 and game.map_style == "islands")
	assert(game.world_size == Vector2(3000, 1800) and game.view_mode_25d)
	game._process(0.01)
	assert(game.ai_think_timers[1] == 6.0 and game.ai_think_timers[2] == 1.5)
	game._return_to_menu()
	assert(not game.started and game.menu_panel.visible and not game.use_lobby_setup)
	print("LOBBY_SETUP_OK")
	quit()

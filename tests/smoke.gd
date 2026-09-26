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
	assert(game.train_unit(center, "villager"))
	assert(center.training_queue.size() == 1)
	assert(game.advance_age(0))
	assert(game.players[0]["age"] == 2)
	var worker: RtsUnit = game.units[0]
	game.selected.append(worker)
	assert(game._cursor_state_at(game._player_center(1).position) == "attack")
	assert(game._cursor_state_at(game.resources[0].position) == "gather")
	assert(game._cursor_state_at(Vector2(700, 700)) == "move")
	assert(game._cursor_state_at(Vector2(700, 700), true) == "default")
	assert(game.place_building(0, "barracks", Vector2(570, 800), worker))
	game.build_mode = "house"
	assert(game._cursor_state_at(Vector2(570, 800)) == "build_invalid")
	assert(game._cursor_state_at(Vector2(700, 800)) == "build_valid")
	game.build_mode = ""
	assert(worker.order == "build")
	var barracks: RtsBuilding = game.buildings.back()
	barracks.advance_construction(100.0)
	assert(barracks.is_complete())
	assert(game.train_unit(barracks, "spearman"))
	game.start_game("French")
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

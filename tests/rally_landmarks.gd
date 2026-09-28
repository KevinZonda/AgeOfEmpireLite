extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Variant = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game("English", 4242)
	game.players[0]["age"] = 3
	var white_tower: RtsBuilding = game.spawn_building(0, "landmark", game._scaled_point(Vector2(700, 950)), false, "eng_white_tower")
	var blacksmith: RtsBuilding = game.spawn_building(0, "blacksmith", game._scaled_point(Vector2(1000, 950)))
	assert(white_tower.can_set_rally(), "White Tower should support a rally point")
	assert(not blacksmith.can_set_rally(), "research-only buildings should not support a rally point")
	game.selected.clear()
	game.selected.append(white_tower)
	var destination: Vector2 = game._scaled_point(Vector2(800, 720))
	assert(game._cursor_state_at(destination) == "rally", "White Tower should show the rally cursor")
	game._issue_order(destination)
	assert(white_tower.rally_point == destination, "right click should update White Tower's rally point")
	white_tower.enqueue("spearman")
	white_tower._process(white_tower._training_time("spearman") + 1.0)
	var trained: RtsUnit = game.units.back()
	assert(trained.kind == "spearman" and trained.order == "move" and trained.destination == destination, "White Tower recruits should follow the rally point")
	print("RALLY_LANDMARKS_OK")
	quit()

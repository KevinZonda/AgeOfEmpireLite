extends SceneTree

const UNIT_LANDMARKS := [
	"eng_council_hall", "eng_white_tower", "eng_abbey", "eng_wynguard_palace",
	"fr_school_of_cavalry", "fr_chamber_of_commerce", "fr_college_of_artillery",
	"zh_imperial_academy", "zh_clocktower",
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Variant = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game("English", 4242)
	# This command-routing fixture supplies ground coordinates directly.
	# Projection-specific screen picking is covered by the input regressions.
	if game.view_mode_25d:
		game._toggle_view_mode()
		await process_frame
	game.players[0]["age"] = 3
	var white_tower: RtsBuilding = game.spawn_building(0, "landmark", game._scaled_point(Vector2(700, 950)), false, "eng_white_tower")
	var blacksmith: RtsBuilding = game.spawn_building(0, "blacksmith", game._scaled_point(Vector2(1000, 950)))
	for kind in ["town_center", "market", "dock", "monastery", "barracks", "archery_range", "stable", "siege_workshop"]:
		assert(game.spawn_building(0, kind, Vector2(1200, 950)).can_set_rally(0), "%s should support a rally point" % kind)
	assert(white_tower.can_set_rally(0), "White Tower should support a rally point")
	assert(not blacksmith.can_set_rally(0), "research-only buildings should not support a rally point")
	assert(not game.spawn_building(0, "university", Vector2(1250, 950)).can_set_rally(0), "universities should not support a rally point")
	var unfinished_barracks: RtsBuilding = game.spawn_building(0, "barracks", Vector2(1300, 950), true)
	assert(not unfinished_barracks.can_set_rally(0), "unfinished buildings should not support a rally point")
	var enemy_barracks: RtsBuilding = game.spawn_building(1, "barracks", Vector2(1350, 950))
	assert(not enemy_barracks.can_set_rally(0), "enemy buildings should not accept player rally orders")
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
	for unavailable in [blacksmith, unfinished_barracks, enemy_barracks]:
		game.selected.clear()
		game.selected.append(unavailable)
		game._update_hud()
		assert(not game.detail_label.text.contains("右键设置集结点"), "unavailable buildings should not show the rally hint")
		assert(game._cursor_state_at(destination) != "rally", "unavailable buildings should not show the rally cursor")
		var previous_rally: Vector2 = unavailable.rally_point
		game._issue_order(destination)
		assert(unavailable.rally_point == previous_rally, "unavailable buildings should ignore rally orders")
	for civilization in ["English", "French", "Chinese"]:
		var match_game: Variant = load("res://scenes/main.tscn").instantiate()
		root.add_child(match_game)
		await process_frame
		match_game.start_game(civilization, 4242)
		for landmark_id in RtsLandmarkCatalog.LANDMARKS:
			if RtsLandmarkCatalog.LANDMARKS[landmark_id]["civilization"] != civilization: continue
			var landmark: RtsBuilding = match_game.spawn_building(0, "landmark", Vector2(750, 950), false, landmark_id)
			assert(landmark.can_set_rally(0) == UNIT_LANDMARKS.has(landmark_id), "%s has the wrong rally capability" % landmark_id)
	print("RALLY_LANDMARKS_OK")
	quit()

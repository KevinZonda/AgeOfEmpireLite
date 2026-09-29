extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game("English", 12345)
	game.players[0]["food"] = 1000
	var center: RtsBuilding = game._player_center(0)
	var initial_count: int = game.units.size()
	if not game.train_unit(center, "villager") or not game.train_unit(center, "villager"):
		_fail("two villagers should both enter the queue")
		return
	if center.production_queue.size() != 2 or center.training_queue.size() != 2:
		_fail("two jobs should be queued")
		return
	var duration: float = center._training_time("villager")
	center._process(duration + 0.01)
	if game.units.size() != initial_count + 1 or center.production_queue.size() != 1 or center.production_remaining <= 0.0:
		_fail("first villager should finish and second should start")
		return
	center._process(duration + 0.01)
	if game.units.size() != initial_count + 2 or not center.production_queue.is_empty() or not center.training_queue.is_empty():
		_fail("second villager should finish")
		return
	var barracks: RtsBuilding = game.spawn_building(0, "barracks", center.position + Vector2(0, -180))
	game.players[0]["age"] = 2
	game.selected.clear()
	game.selected.append(barracks)
	game._rebuild_actions()
	var train_button: RtsCommandButton
	for button in game.command_buttons:
		if button.icon_kind == "spearman":
			train_button = button
			break
	if train_button == null or train_button.disabled:
		_fail("spearman training button should be available")
		return
	initial_count = game.units.size()
	train_button.pressed.emit()
	train_button.pressed.emit()
	if barracks.production_queue.size() != 2:
		_fail("two button presses should queue two spearmen")
		return
	var remaining_before: float = barracks.production_remaining
	for frame in 10:
		await process_frame
	if barracks.production_remaining >= remaining_before:
		_fail("training should progress during normal game frames")
		return
	duration = barracks._training_time("spearman")
	barracks._process(duration + 0.01)
	if game.units.size() != initial_count + 1 or barracks.production_queue.size() != 1:
		_fail("first spearman should finish and second should remain queued")
		return
	remaining_before = barracks.production_remaining
	for frame in 10:
		await process_frame
	if barracks.production_remaining >= remaining_before:
		_fail("second spearman should progress during normal game frames")
		return
	barracks._process(duration + 0.01)
	if game.units.size() != initial_count + 2 or not barracks.production_queue.is_empty():
		_fail("second spearman should finish")
		return
	game.free()
	print("PRODUCTION_QUEUE_REGRESSION_OK")
	quit()

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

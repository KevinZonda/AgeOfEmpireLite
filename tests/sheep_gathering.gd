extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game("English", 44127, "French")
	game.fog.active = false
	var worker: RtsUnit = game.units.filter(func(unit: RtsUnit) -> bool: return unit.owner_id == 0 and unit.kind == "villager")[0]
	game.selected.clear()
	game.selected.append(worker)
	for claimant in [-1, 1]:
		var sheep: RtsResource = game.spawn_resource("food", worker.position + Vector2(80, 0), 200, "sheep")
		sheep.claimed_by = claimant
		assert(game.find_nearest_resource(sheep.position, "food", 1.0, 0) == sheep)
		assert(game._cursor_state_at(sheep.position) == "gather")
		game._issue_order(sheep.position)
		assert(worker.order == "gather" and worker.target == sheep, "villager should gather sheep regardless of ownership")
		worker.position = sheep.position
		worker.work_timer = 0.0
		var food_before: int = game.players[0]["food"]
		worker._process_gather_order(0.1)
		assert(game.players[0]["food"] > food_before and sheep.amount < 200)
		worker.order_stop()
		sheep.free()
	var enemy_worker: RtsUnit = game.spawn_unit(1, "villager", worker.position + Vector2(80, 0))
	var owned_sheep: RtsResource = game.spawn_resource("food", enemy_worker.position + Vector2(80, 0), 200, "sheep")
	owned_sheep.claimed_by = 0
	enemy_worker.issue_command("gather", Vector2.INF, owned_sheep)
	assert(enemy_worker.order == "gather" and enemy_worker.target == owned_sheep)
	game.free()
	print("SHEEP_GATHERING_OK")
	quit()

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
	worker.order_stop()
	var deer: RtsResource = game.spawn_resource("food", worker.position + Vector2(40, 0), 170, "deer")
	worker.position = deer.position + Vector2(40, 0)
	game.selected.assign([worker])
	assert(deer.harvest(10) == 0, "living deer must not yield food")
	game._issue_order(deer.position)
	assert(worker.order == "gather" and worker.target == deer, "right-clicking deer should start hunting")
	var food_before: int = game.players[0]["food"]
	worker._process_gather_order(0.1)
	assert(deer.wildlife_hp == 0.0, "villager should kill deer before gathering")
	assert(game.players[0]["food"] == food_before and deer.amount == 170, "killing deer must not grant food")
	worker._process_gather_order(0.1)
	assert(game.players[0]["food"] > food_before and deer.amount < 170, "villager should gather meat from the carcass")
	game.free()
	print("DEER_GATHERING_OK")
	quit()

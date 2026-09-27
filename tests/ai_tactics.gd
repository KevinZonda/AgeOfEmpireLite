extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game("English", 4242)
	var ai: RtsAiController = game.ai_controllers[0]
	assert(ai.worker_goal() == 10)
	game.players[1]["age"] = 3
	assert(ai.worker_goal() == 25, "worker target must grow with age")
	var home: Vector2 = game.spawn_point_for(1)
	var soldiers: Array[RtsUnit] = []
	for i in 5:
		var soldier: RtsUnit = game.spawn_unit(1, "horseman", home + Vector2(-85 + i * 24, 60))
		soldier.order_stop()
		soldiers.append(soldier)
	var intruder: RtsUnit = game.spawn_unit(0, "spearman", home + Vector2(-180, 30))
	game.fog.update_visibility()
	assert(game.fog.can_detect_unit(1, intruder))
	assert(ai._tactical_orders(soldiers))
	assert(ai.last_tactic == "defend")
	for soldier in soldiers: assert(soldier.order == "attack_move")
	ai.tactic_cooldown = 0.0
	game.entity_destroyed(intruder)
	await process_frame
	for soldier in soldiers: soldier.order_stop()
	var wounded: RtsUnit = soldiers[0]
	wounded.hp = wounded.max_hp * 0.2
	var pursuer: RtsUnit = game.spawn_unit(0, "spearman", wounded.position + Vector2(45, 0))
	game.fog.update_visibility()
	ai._tactical_orders(soldiers)
	assert(wounded.order == "move", "wounded unit should withdraw")
	game.entity_destroyed(pursuer)
	await process_frame
	for soldier in soldiers.slice(1): soldier.order_stop()
	for i in 5:
		var raider: RtsUnit = game.spawn_unit(1, "horseman", home + Vector2(-140 + i * 20, 100))
		raider.order_stop()
		soldiers.append(raider)
	var raid_point := home + Vector2(-500, 0)
	game.spawn_unit(1, "scout", raid_point + Vector2(25, 0))
	var enemy_worker: RtsUnit = game.spawn_unit(0, "villager", raid_point)
	game.fog.update_visibility()
	assert(game.fog.can_detect_unit(1, enemy_worker))
	ai.tactic_cooldown = 0.0
	ai._tactical_orders(soldiers)
	assert(ai.last_tactic == "raid", "visible gatherer should trigger a cavalry raid")
	game.entity_destroyed(enemy_worker)
	await process_frame
	game.players[1]["wood"] = 1000
	game.spawn_building(1, "barracks", home + Vector2(-280, 180))
	var workers: Array[RtsUnit] = []
	for unit in game.units:
		if is_instance_valid(unit) and unit.owner_id == 1 and unit.kind == "villager": workers.append(unit)
	for i in 20:
		workers.append(game.spawn_unit(1, "villager", home + Vector2(i * 8, 90)))
	ai._expand_production(workers, 20, 3)
	assert(ai._building_count("barracks") >= 2, "AI should build additional production")
	print("AI_TACTICS_OK goal=%d barracks=%d" % [ai.worker_goal(), ai._building_count("barracks")])
	quit()

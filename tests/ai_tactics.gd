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
	var stuck_attacker: RtsUnit = game.spawn_unit(1, "spearman", home + Vector2(-110, -30))
	var stuck_target: RtsUnit = game.spawn_unit(0, "spearman", home + Vector2(-210, -30))
	stuck_attacker.order_attack(stuck_target)
	game.fog.update_visibility()
	ai.attack_watch[stuck_attacker.get_instance_id()] = {"target_id": stuck_target.get_instance_id(), "position": stuck_attacker.position, "since": game.match_statistics.elapsed - 10.0}
	ai._recover_stalled_attacks([stuck_attacker])
	assert(stuck_attacker.order != "attack", "stalled attacks must flank or reacquire")
	game.entity_destroyed(stuck_target)
	await process_frame
	var first_monk: RtsUnit = game.spawn_unit(1, "monk", home + Vector2(0, 90))
	var second_monk: RtsUnit = game.spawn_unit(1, "monk", home + Vector2(20, 90))
	var first_site := ai._sacred_site_for(first_monk)
	assert(first_site >= 0)
	ai._assign_monk(first_monk)
	assert(first_monk.order == "move" and first_monk.destination.distance_to(game.objectives.sacred_sites[first_site]["position"]) < 80.0, "monk should prioritize the sacred site")
	assert(ai._sacred_site_for(second_monk) != first_site, "monks should spread across sacred sites")
	game.objectives.sacred_sites[first_site]["contested"] = true
	ai._secure_sacred_site(soldiers)
	assert(ai.last_tactic == "secure_site", "army should contest a blocked sacred site")
	game.objectives.sacred_sites[first_site]["contested"] = false
	game.players[1]["wood"] = 1000
	game.spawn_building(1, "barracks", home + Vector2(-280, 180))
	game.spawn_building(1, "siege_workshop", home + Vector2(-280, -180))
	var workers: Array[RtsUnit] = []
	for unit in game.units:
		if is_instance_valid(unit) and unit.owner_id == 1 and unit.kind == "villager": workers.append(unit)
	for i in 20:
		workers.append(game.spawn_unit(1, "villager", home + Vector2(i * 8, 90)))
	var initial_production := ai._building_count("barracks") + ai._building_count("archery_range") + ai._building_count("stable")
	assert(ai._unit_count("battering_ram") == 0)
	ai._expand_production(workers, 20, 3)
	assert(ai._building_count("barracks") + ai._building_count("archery_range") + ai._building_count("stable") == initial_production, "siege production should precede extra barracks")
	game.spawn_unit(1, "battering_ram", home + Vector2(-180, -90))
	game.spawn_building(1, "monastery", home + Vector2(-360, -160))
	ai._expand_production(workers, 20, 3)
	assert(ai._building_count("barracks") + ai._building_count("archery_range") + ai._building_count("stable") > initial_production, "AI should build additional production")
	print("AI_TACTICS_OK goal=%d barracks=%d" % [ai.worker_goal(), ai._building_count("barracks")])
	quit()

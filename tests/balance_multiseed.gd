extends SceneTree

# Deterministic, accelerated AI-versus-AI balance probe. Set RTS_BALANCE_SEEDS
# and RTS_BALANCE_SECONDS to expand the sample without editing the script.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var requested: String = OS.get_environment("RTS_BALANCE_SEEDS")
	var seeds: Array[int] = [17, 431, 9021, 4242]
	if requested != "":
		seeds.clear()
		for part in requested.split(","):
			if part.strip_edges().is_valid_int(): seeds.append(int(part))
	var seconds := int(OS.get_environment("RTS_BALANCE_SECONDS"))
	if seconds <= 0: seconds = 480
	var wins := [0, 0]
	var draws := 0
	for map_seed in seeds:
		seed(map_seed)
		var game: Node2D = load("res://scenes/main.tscn").instantiate()
		root.add_child(game)
		await process_frame
		game.start_game("English", map_seed, "French")
		var victory_owner := [-1]
		game.objectives.victory.connect(func(owner_id: int, _reason: String) -> void: victory_owner[0] = owner_id)
		var fairness: Dictionary = game.world_map.fairness_report()
		assert(fairness["fair"])
		var first_ai := RtsAiController.new(game, 0, "normal")
		var ages := [[0, -1, -1, -1], [0, -1, -1, -1]]
		var peak_army := [0, 0]
		var peak_workers := [0, 0]
		var peak_production := [0, 0]
		for step in seconds * 10:
			if game.game_over: break
			game._process(0.1)
			if step % 30 == 0: first_ai.tick()
			for building in game.buildings.duplicate():
				if is_instance_valid(building) and not building.is_queued_for_deletion(): building._process(0.1)
			for unit in game.units.duplicate():
				if is_instance_valid(unit) and not unit.is_queued_for_deletion(): unit._process(0.1)
			game.objectives._process(0.1)
			if step % 50 != 0: continue
			for owner in 2:
				var age: int = game.players[owner]["age"]
				for reached in range(2, age + 1):
					if ages[owner][reached - 1] < 0: ages[owner][reached - 1] = step / 10
				var military := 0
				var workers := 0
				var production := 0
				for unit in game.units:
					if not is_instance_valid(unit) or unit.owner_id != owner: continue
					if unit.kind == "villager": workers += 1
					elif unit.stats.get("tags", []).has("military"): military += 1
				for building in game.buildings:
					if is_instance_valid(building) and building.owner_id == owner and building.kind in ["barracks", "archery_range", "stable"]: production += 1
				peak_army[owner] = maxi(peak_army[owner], military)
				peak_workers[owner] = maxi(peak_workers[owner], workers)
				peak_production[owner] = maxi(peak_production[owner], production)
		var winner: int = victory_owner[0]
		if game.defeated_players.has(0) and not game.defeated_players.has(1): winner = 1
		elif game.defeated_players.has(1) and not game.defeated_players.has(0): winner = 0
		if winner < 0: draws += 1
		else: wins[winner] += 1
		var army_distance := [0.0, 0.0]
		var army_counts := [0, 0]
		var army_orders := [{}, {}]
		var attack_distance := [0.0, 0.0]
		var attack_counts := [0, 0]
		var center_hp := [0.0, 0.0]
		for unit in game.units:
			if is_instance_valid(unit) and unit.stats.get("tags", []).has("military") and unit.owner_id in [0, 1]:
				army_distance[unit.owner_id] += unit.position.distance_to(game.spawn_point_for(1 - unit.owner_id))
				army_counts[unit.owner_id] += 1
				army_orders[unit.owner_id][unit.order] = int(army_orders[unit.owner_id].get(unit.order, 0)) + 1
				if unit.order == "attack" and is_instance_valid(unit.target):
					attack_distance[unit.owner_id] += unit.position.distance_to(unit.target.position)
					attack_counts[unit.owner_id] += 1
		for owner in 2:
			if army_counts[owner] > 0: army_distance[owner] /= army_counts[owner]
			if attack_counts[owner] > 0: attack_distance[owner] /= attack_counts[owner]
			var center: RtsBuilding = game._player_center(owner)
			center_hp[owner] = center.hp / center.max_hp if center != null else 0.0
		print("BALANCE seed=%d ages=%s peak_workers=%s peak_army=%s production=%s army_distance=%s attack_distance=%s army_orders=%s tactics=%s center_hp=%s winner=%d fairness=%s" % [map_seed, str(ages), str(peak_workers), str(peak_army), str(peak_production), str(army_distance), str(attack_distance), str(army_orders), str([first_ai.last_tactic, game.ai_controllers[0].last_tactic]), str(center_hp), winner, str(fairness)])
		game.queue_free()
		await process_frame
	print("BALANCE_SUMMARY seeds=%d wins=%s draws=%d" % [seeds.size(), str(wins), draws])
	quit()

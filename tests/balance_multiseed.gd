extends SceneTree

# Deterministic, accelerated AI-versus-AI balance probe. RTS_BALANCE_MATRIX=1
# covers both sides of three civilization pairings, four map styles and three difficulties.
# RTS_BALANCE_SEEDS and RTS_BALANCE_SECONDS control the sample and time limit.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var requested: String = OS.get_environment("RTS_BALANCE_SEEDS")
	var seeds: Array[int] = [17, 431, 9021, 4242]
	if requested != "":
		seeds.clear()
		for part in requested.split(","):
			if part.strip_edges().is_valid_int(): seeds.append(int(part))
	if seeds.is_empty():
		push_error("RTS_BALANCE_SEEDS must contain at least one integer")
		quit(1)
		return
	var seconds := int(OS.get_environment("RTS_BALANCE_SECONDS"))
	if seconds <= 0: seconds = 480
	var cases: Array[Dictionary] = []
	if OS.get_environment("RTS_BALANCE_MATRIX") == "1":
		var pairings := [["English", "French"], ["French", "English"], ["French", "Chinese"], ["Chinese", "French"], ["Chinese", "English"], ["English", "Chinese"]]
		var styles := ["balanced", "highlands", "lakes", "islands"]
		var difficulties := ["normal", "hard", "easy"]
		for pair_index in pairings.size():
			for style_index in styles.size():
				var matchup_index: int = pair_index / 2
				cases.append({"seed": seeds[(matchup_index + style_index) % seeds.size()], "civilizations": pairings[pair_index], "style": styles[style_index], "difficulty": difficulties[(matchup_index + style_index) % difficulties.size()]})
	else:
		for map_seed in seeds: cases.append({"seed": map_seed, "civilizations": ["English", "French"], "style": "balanced", "difficulty": "normal"})
	var wins := [0, 0]
	var unfinished := 0
	var civilization_wins := {"English": 0, "French": 0, "Chinese": 0}
	var style_outcomes: Dictionary = {}
	for case in cases:
		var map_seed: int = case["seed"]
		var civilizations: Array = case["civilizations"]
		var style: String = case["style"]
		var difficulty: String = case["difficulty"]
		seed(map_seed)
		var game: Node2D = load("res://scenes/main.tscn").instantiate()
		root.add_child(game)
		await process_frame
		game.selected_map_style = style
		game.selected_initial_resources = 1
		game.use_lobby_setup = true
		game.lobby_players.clear()
		game.lobby_players.append({"civilization": civilizations[0], "difficulty": "human", "team": 1})
		game.lobby_players.append({"civilization": civilizations[1], "difficulty": difficulty, "team": 2})
		game.start_game(civilizations[0], map_seed, civilizations[1])
		var victory_owner := [-1]
		game.objectives.victory.connect(func(owner_id: int, _reason: String) -> void: victory_owner[0] = owner_id)
		var fairness: Dictionary = game.world_map.fairness_report()
		assert(fairness["fair"])
		var first_ai := RtsAiController.new(game, 0, difficulty)
		var think_steps: int = {"easy": 60, "normal": 30, "hard": 15}[difficulty]
		var ages := [[0, -1, -1, -1], [0, -1, -1, -1]]
		var peak_army := [0, 0]
		var peak_workers := [0, 0]
		var peak_production := [0, 0]
		for step in seconds * 10:
			if game.game_over: break
			if step % think_steps == 0: first_ai.tick()
			game.step(0.1)
			if OS.get_environment("RTS_BALANCE_TRACE") == "1" and step % 600 == 0:
				for owner in 2:
					var controller: RtsAiController = first_ai if owner == 0 else game.ai_controllers[0]
					var orders: Dictionary = {}
					for unit in game.units:
						if not is_instance_valid(unit) or unit.owner_id != owner or unit.kind != "villager": continue
						var resource: String = unit.target.kind if unit.order == "gather" and is_instance_valid(unit.target) and unit.target is RtsResource else unit.order
						orders[resource] = int(orders.get(resource, 0)) + 1
					var visible_wood := 0
					for resource in game.resources:
						if not is_instance_valid(resource) or resource.is_queued_for_deletion() or resource.kind != "wood": continue
						if game.fog.can_show_resource(owner, resource): visible_wood += 1
					print("BALANCE_TRACE t=%d owner=%d age=%d bank=%s workers=%s visible_wood=%d buildings=%s ram=%d" % [step / 10, owner, game.players[owner]["age"], str({"food": game.players[owner]["food"], "wood": game.players[owner]["wood"], "gold": game.players[owner]["gold"]}), str(orders), visible_wood, str({"farms": controller._building_count("farm"), "houses": controller._building_count("house"), "workshops": controller._building_count("siege_workshop"), "monasteries": controller._building_count("monastery")}), controller._unit_count("battering_ram")])
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
		if winner < 0: unfinished += 1
		else:
			wins[winner] += 1
			civilization_wins[civilizations[winner]] += 1
		if not style_outcomes.has(style): style_outcomes[style] = {"finished": 0, "unfinished": 0}
		style_outcomes[style]["finished" if winner >= 0 else "unfinished"] += 1
		var army_distance := [0.0, 0.0]
		var army_counts := [0, 0]
		var army_orders := [{}, {}]
		var attack_distance := [0.0, 0.0]
		var attack_counts := [0, 0]
		var empty_attack_routes := [0, 0]
		var siege_counts := [0, 0]
		var center_hp := [0.0, 0.0]
		var strategic_assets := [{}, {}]
		var monk_states := [[], []]
		for unit in game.units:
			if is_instance_valid(unit) and unit.owner_id in [0, 1] and unit.kind == "monk":
				var destination: Vector2 = unit.destination if unit.order == "move" else unit.target.position if is_instance_valid(unit.target) else unit.position
				monk_states[unit.owner_id].append({"order": unit.order, "position": unit.position.round(), "destination": destination.round()})
			if is_instance_valid(unit) and unit.stats.get("tags", []).has("military") and unit.owner_id in [0, 1]:
				army_distance[unit.owner_id] += unit.position.distance_to(game.spawn_point_for(1 - unit.owner_id))
				army_counts[unit.owner_id] += 1
				army_orders[unit.owner_id][unit.order] = int(army_orders[unit.owner_id].get(unit.order, 0)) + 1
				if unit.order == "attack" and is_instance_valid(unit.target):
					attack_distance[unit.owner_id] += unit.position.distance_to(unit.target.position)
					attack_counts[unit.owner_id] += 1
					if unit.route.is_empty(): empty_attack_routes[unit.owner_id] += 1
				if unit.stats.get("tags", []).has("siege"): siege_counts[unit.owner_id] += 1
		for owner in 2:
			if army_counts[owner] > 0: army_distance[owner] /= army_counts[owner]
			if attack_counts[owner] > 0: attack_distance[owner] /= attack_counts[owner]
			var center: RtsBuilding = game._player_center(owner)
			center_hp[owner] = center.hp / center.max_hp if center != null else 0.0
			var controller: RtsAiController = first_ai if owner == 0 else game.ai_controllers[0]
			strategic_assets[owner] = {"wood": game.players[owner]["wood"], "gold": game.players[owner]["gold"], "workshops": controller._building_count("siege_workshop"), "monasteries": controller._building_count("monastery"), "monks": controller._unit_count("monk"), "ram_orders": controller._unit_count("battering_ram")}
		print("BALANCE seed=%d civs=%s style=%s difficulty=%s ages=%s peak_workers=%s peak_army=%s production=%s army_distance=%s attack_distance=%s empty_attack_routes=%s siege=%s assets=%s sites=%s monks=%s army_orders=%s tactics=%s center_hp=%s winner=%d fairness=%s" % [map_seed, str(civilizations), style, difficulty, str(ages), str(peak_workers), str(peak_army), str(peak_production), str(army_distance), str(attack_distance), str(empty_attack_routes), str(siege_counts), str(strategic_assets), str(game.objectives.sacred_sites.map(func(site: Dictionary) -> int: return site["owner_id"])), str(monk_states), str(army_orders), str([first_ai.last_tactic, game.ai_controllers[0].last_tactic]), str(center_hp), winner, str(fairness)])
		game.queue_free()
		await process_frame
	print("BALANCE_SUMMARY cases=%d wins=%s unfinished=%d civilization_wins=%s map_styles=%s" % [cases.size(), str(wins), unfinished, str(civilization_wins), str(style_outcomes)])
	quit()

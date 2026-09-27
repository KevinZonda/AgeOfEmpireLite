class_name RtsAiController
extends RefCounted

var game: Node2D
var owner_id := 1
var difficulty := "normal"
var transport_wait: Dictionary = {}
var construction_watch: Dictionary = {}
var rng := RandomNumberGenerator.new()

func _init(game_ref: Node2D, player_id := 1, chosen_difficulty := "normal") -> void:
	game = game_ref
	owner_id = player_id
	difficulty = chosen_difficulty if chosen_difficulty in ["easy", "normal", "hard"] else "normal"
	rng.seed = int(game.map_seed) + player_id * 104729

func worker_goal() -> int:
	return {"easy": 7, "normal": 10, "hard": 14}[difficulty]

func attack_threshold() -> int:
	return {"easy": 8, "normal": 5, "hard": 3}[difficulty]

func _has_unfinished_house() -> bool:
	for building in game.buildings:
		if is_instance_valid(building) and building.owner_id == owner_id and building.kind == "house" and not building.is_complete(): return true
	return false

func tick() -> void:
	var workers: Array[RtsUnit] = []
	var army: Array[RtsUnit] = []
	for unit in game.units:
		if not is_instance_valid(unit) or unit.owner_id != owner_id or unit.garrisoned_in != null: continue
		if unit.kind == "villager": workers.append(unit)
		elif unit.kind == "scout":
			if unit.order == "idle": _assign_scout(unit)
		elif unit.kind == "transport_ship":
			if unit.order == "idle": _assign_transport(unit)
		elif unit.kind == "warship":
			if unit.order == "idle":
				var target: Node2D = game.nearest_enemy(unit, 350.0)
				if target != null: unit.order_attack(target)
		elif unit.stats.get("tags", []).has("military"): army.append(unit)
		elif unit.kind == "trader" and unit.order == "idle" and not game.trade_posts.is_empty(): unit.issue_command("trade", Vector2.INF, game.trade_posts[0])
		elif unit.kind == "fishing_boat" and unit.order == "idle":
			var fish: RtsResource = game.find_nearest_resource(unit.position, "food", INF, owner_id, true)
			if fish != null: unit.issue_command("gather", Vector2.INF, fish)
		elif unit.kind == "monk" and unit.order == "idle": _assign_monk(unit)
	_resume_construction(workers)
	for worker in workers:
		if worker.order == "gather" and is_instance_valid(worker.target):
			var reach: float = worker.target.radius + worker.radius() + 2.0 if worker.target is RtsResource else worker.target.size().x * 0.5 + worker.radius() + 2.0
			if worker.position.distance_to(worker.target.position) > reach + 5.0 and worker.route.is_empty(): worker.order_stop()
		if worker.order == "idle":
			var resource_kind := "food" if game.players[owner_id]["food"] < 330 else "wood" if game.players[owner_id]["wood"] < 230 else "gold"
			var resource: RtsResource = game.find_nearest_resource(worker.position, resource_kind, INF, owner_id, false, worker)
			if resource != null: worker.order_gather(resource)
			elif resource_kind == "food":
				var farm: RtsBuilding = game.find_nearest_free_farm(owner_id, worker.position, 520.0, worker)
				if farm != null: worker.order_gather(farm)
	if game.players[owner_id]["age"] == 1:
		if game._player_center(owner_id) != null: game.advance_age(owner_id)
		if army.is_empty(): return
	var center: RtsBuilding = game._player_center(owner_id)
	var age: int = game.players[owner_id]["age"]
	if center != null and not workers.is_empty() and age < RtsTechTree.MAX_AGE and not game.is_age_queued(owner_id):
		var timing: float = {"easy": 220.0, "normal": 150.0, "hard": 105.0}[difficulty]
		var should_advance: bool = game.highest_enemy_age(owner_id) > age or army.size() >= attack_threshold() + 2 or game.match_statistics.elapsed >= timing * float(age - 1)
		if should_advance and game.can_afford(owner_id, RtsTechTree.age_cost(age)):
			game.advance_age(owner_id)
	if game.civilizations[owner_id] == "Chinese" and not game.is_age_queued(owner_id):
		for choice in RtsLandmarkCatalog.choices_for("Chinese", age, game.players[owner_id]["landmarks"]):
			if choice["age"] > age or not game.can_afford(owner_id, choice["cost"]): continue
			if game.construct_landmark(owner_id, choice["id"]): break
	if center != null and _unit_count("villager") < worker_goal(): game.train_unit(center, "villager")
	if not workers.is_empty() and game.population_cap(owner_id) - game.population_used(owner_id) <= 4 and not _has_unfinished_house():
		_construct("house", workers[0])
	if not workers.is_empty() and age >= 2 and game.players[owner_id]["food"] < 320 and _building_count("farm") < mini(7, maxi(2, workers.size() / 2)) and not _has_unfinished_building("farm"):
		_construct("farm", workers[0])
	if not workers.is_empty() and not _has_building("barracks"):
		_construct("barracks", workers[0])
	elif not workers.is_empty() and not _has_building("archery_range"):
		_construct("archery_range", workers[0])
	elif not workers.is_empty() and not _has_building("stable"):
		_construct("stable", workers[0])
	elif not workers.is_empty() and not _has_building("blacksmith"):
		_construct("blacksmith", workers[0])
	if not workers.is_empty() and age >= 2 and not _has_building("outpost") and game.can_afford(owner_id, GameData.BUILDINGS["outpost"]["cost"]):
		_construct("outpost", workers[0])
	if not workers.is_empty() and age >= 3 and not _has_building("siege_workshop") and game.can_afford(owner_id, GameData.BUILDINGS["siege_workshop"]["cost"]):
		_construct("siege_workshop", workers[0])
	if not workers.is_empty() and age >= 2 and not _has_building("market") and game.can_afford(owner_id, GameData.BUILDINGS["market"]["cost"]):
		_construct("market", workers[0])
	if not workers.is_empty() and age >= 2 and not _has_building("dock") and game.can_afford(owner_id, GameData.BUILDINGS["dock"]["cost"]):
		_construct_dock(workers[0])
	if not workers.is_empty() and age >= 3 and not _has_building("monastery") and game.can_afford(owner_id, GameData.BUILDINGS["monastery"]["cost"]):
		_construct("monastery", workers[0])
	_balance_market(age)
	var age_cost := RtsTechTree.age_cost(age)
	var save_time: float = {"easy": 220.0, "normal": 150.0, "hard": 105.0}[difficulty] * float(age - 1)
	var saving_for_age: bool = not age_cost.is_empty() and not game.is_age_queued(owner_id) and (game.match_statistics.elapsed >= save_time or game.highest_enemy_age(owner_id) > age)
	var enemy_profile := _enemy_profile()
	for building in game.buildings:
		if not is_instance_valid(building) or building.owner_id != owner_id or not building.is_complete(): continue
		if building.landmark_id == "fr_guild_hall" and int(building.landmark_stockpile.get("gold", 0)) >= 120: building.collect_stockpile()
		if building.landmark_id == "zh_imperial_palace" and building.landmark_ability_cooldown <= 0.0: building.activate_landmark_ability()
		if building.production_queue.size() >= (2 if difficulty == "easy" else 3): continue
		if saving_for_age and building.producer_kind() in ["barracks", "archery_range", "stable", "siege_workshop", "white_tower", "wynguard"]: continue
		if not saving_for_age:
			for tech_id in RtsTechTree.all_researches(game.civilizations[owner_id], building.producer_kind()):
				if RtsTechTree.can_research(game.civilizations[owner_id], age, building.producer_kind(), tech_id, game.players[owner_id]["researched"]):
					if game.research_technology(building, tech_id): break
		if building.producer_kind() == "barracks":
			var infantry_kind := "spearman" if enemy_profile["cavalry"] >= enemy_profile["ranged"] or age < 3 else "man_at_arms"
			game.train_unit(building, RtsUnitCatalog.replacement_for(game.civilizations[owner_id], infantry_kind))
		if building.producer_kind() == "archery_range":
			var ranged_kind := RtsUnitCatalog.replacement_for(game.civilizations[owner_id], "crossbowman")
			if age < 3 or enemy_profile["heavy"] == 0: ranged_kind = RtsUnitCatalog.replacement_for(game.civilizations[owner_id], "archer")
			if game.civilizations[owner_id] == "Chinese" and game.players[owner_id].get("dynasty", "") in ["Song", "Yuan", "Ming"] and enemy_profile["heavy"] == 0: ranged_kind = "zhuge_nu"
			game.train_unit(building, ranged_kind)
		if building.producer_kind() == "stable":
			var cavalry_kind := "horseman"
			if enemy_profile["ranged"] == 0 and not saving_for_age:
				if game.civilizations[owner_id] == "French": cavalry_kind = "royal_knight"
				elif age >= 3: cavalry_kind = "knight"
			game.train_unit(building, cavalry_kind)
		if building.producer_kind() == "siege_workshop" and not saving_for_age and game.can_afford(owner_id, GameData.unit_cost("battering_ram")):
			game.train_unit(building, "battering_ram")
		if building.producer_kind() == "white_tower":
			game.train_unit(building, "spearman" if enemy_profile["cavalry"] > 0 else "longbow")
		if building.producer_kind() == "wynguard": game.train_unit(building, "longbow")
		if building.producer_kind() == "town_center" and building != center and workers.size() < 10: game.train_unit(building, "villager")
		if building.producer_kind() == "market" and _unit_count("trader") < 1:
			game.train_unit(building, "trader")
		if building.kind == "dock" and _unit_count("fishing_boat") < 2:
			game.train_unit(building, "fishing_boat")
		if building.kind == "dock" and _unit_count("fishing_boat") >= 1 and _unit_count("warship") < 1:
			game.train_unit(building, "warship")
		if building.kind == "dock" and _unit_count("arrow_ship") < 2:
			game.train_unit(building, "arrow_ship")
		if building.kind == "dock" and game.map_style == "islands" and _unit_count("transport_ship") < 1:
			game.train_unit(building, "transport_ship")
		if building.kind == "monastery" and _unit_count("monk") < 3:
			game.train_unit(building, "monk")
	if army.size() >= attack_threshold():
		var target: Node2D = game.strategic_target_for(owner_id)
		if target == null:
			for building in game.buildings:
				if is_instance_valid(building) and game.is_enemy(owner_id, building.owner_id) and building.kind == "landmark":
					target = building
					break
		if target != null:
			var idle_army: Array[RtsUnit] = []
			for soldier in army:
				if soldier.order == "idle": idle_army.append(soldier)
			if not idle_army.is_empty(): game.issue_group_order(idle_army, target.position, true)

func _assign_scout(scout: RtsUnit) -> void:
	var center: RtsBuilding = game.find_nearest_owned_building(owner_id, "town_center", scout.position)
	for sheep in game.resources:
		if is_instance_valid(sheep) and sheep.appearance == "sheep" and sheep.shepherd == scout and center != null and sheep.position.distance_to(center.position) > 120.0:
			scout.issue_command("move", center.position)
			return
	var nearest_sheep: RtsResource
	var sheep_distance := 800.0 * 800.0
	for sheep in game.resources:
		if not is_instance_valid(sheep) or sheep.appearance != "sheep" or sheep.claimed_by == owner_id or not game.fog.can_see(owner_id, sheep.position): continue
		var distance := scout.position.distance_squared_to(sheep.position)
		if distance < sheep_distance and not game.navigation.path_between(scout.position, sheep.position, scout).is_empty():
			nearest_sheep = sheep
			sheep_distance = distance
	if nearest_sheep != null:
		scout.issue_command("move", nearest_sheep.position)
		return
	var candidates: Array[Dictionary] = []
	for y in range(1, game.world_map.grid_size.y - 1, 4):
		for x in range(1, game.world_map.grid_size.x - 1, 4):
			var point: Vector2 = game.world_map.cell_center(Vector2i(x, y))
			if not game.world_map.is_walkable(point) or game.fog.is_explored(owner_id, point): continue
			var distance := scout.position.distance_squared_to(point)
			if distance > 180.0 * 180.0: candidates.append({"point": point, "distance": distance})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["distance"] < b["distance"])
	for candidate in candidates.slice(0, mini(24, candidates.size())):
		if not game.navigation.path_between(scout.position, candidate["point"], scout).is_empty():
			scout.issue_command("move", candidate["point"])
			return

func _assign_transport(boat: RtsUnit) -> void:
	if not boat.passengers.is_empty():
		var waiting := 0
		for soldier in game.units:
			if is_instance_valid(soldier) and soldier.order == "board_transport" and soldier.target == boat: waiting += 1
		var boat_id := boat.get_instance_id()
		if waiting > 0 and boat.passengers.size() < 4:
			transport_wait[boat_id] = int(transport_wait.get(boat_id, 0)) + 1
			if int(transport_wait[boat_id]) < 5: return
		transport_wait.erase(boat_id)
		var target: Node2D = game.strategic_target_for(owner_id)
		if target != null: boat.issue_command("unload", target.position)
		return
	if game.map_style != "islands": return
	var boarded := 0
	for soldier in game.units:
		if not is_instance_valid(soldier) or soldier.owner_id != owner_id or soldier.garrisoned_in != null or soldier.kind == "scout" or not soldier.stats.get("tags", []).has("military") or soldier.stats.get("tags", []).has("naval"): continue
		if soldier.position.distance_to(boat.position) > 700.0: continue
		soldier.issue_command("board_transport", Vector2.INF, boat)
		boarded += 1
		if boarded >= 6: break

func _enemy_profile() -> Dictionary:
	var profile := {"cavalry": 0, "ranged": 0, "heavy": 0}
	for unit in game.units:
		if not is_instance_valid(unit) or not game.is_enemy(owner_id, unit.owner_id) or unit.kind == "villager": continue
		if game.fog.active and not game.fog.can_detect_unit(owner_id, unit): continue
		for tag in profile:
			if unit.stats.get("tags", []).has(tag): profile[tag] += 1
	return profile

func _has_building(kind: String) -> bool:
	for building in game.buildings:
		if is_instance_valid(building) and building.owner_id == owner_id and building.kind == kind: return true
	return false

func _building_count(kind: String) -> int:
	var count := 0
	for building in game.buildings:
		if is_instance_valid(building) and building.owner_id == owner_id and building.kind == kind: count += 1
	return count

func _has_unfinished_building(kind: String) -> bool:
	for building in game.buildings:
		if is_instance_valid(building) and building.owner_id == owner_id and building.kind == kind and not building.is_complete(): return true
	return false

func _unit_count(kind: String) -> int:
	var count := 0
	for unit in game.units:
		if is_instance_valid(unit) and unit.owner_id == owner_id and unit.kind == kind: count += 1
	for building in game.buildings:
		if is_instance_valid(building) and building.owner_id == owner_id: count += building.training_queue.count(kind)
	return count

func _balance_market(age: int) -> void:
	if game.find_nearest_owned_building(owner_id, "market", game.spawn_point_for(owner_id)) == null: return
	var bank: Dictionary = game.players[owner_id]
	var age_cost := RtsTechTree.age_cost(age)
	var gold_goal := int(age_cost.get("gold", 180)) + 50
	if bank["food"] > maxi(650, int(age_cost.get("food", 0)) + 150) and bank["gold"] < gold_goal:
		game.exchange_resource(owner_id, "food", false)
	elif bank["food"] < 140 and bank["wood"] >= 200 and bank["gold"] <= game.market_quote("food", true, owner_id) + 120:
		game.exchange_resource(owner_id, "wood", false)
	elif bank["food"] < 140 and bank["gold"] > game.market_quote("food", true, owner_id) + 120:
		game.exchange_resource(owner_id, "food", true)
	elif bank["wood"] < 100 and bank["gold"] > game.market_quote("wood", true, owner_id) + gold_goal:
		game.exchange_resource(owner_id, "wood", true)
	elif bank["wood"] > 600 and bank["gold"] < gold_goal:
		game.exchange_resource(owner_id, "wood", false)

func _assign_monk(monk: RtsUnit) -> void:
	if monk.carried_relic != null:
		var monastery: RtsBuilding = game.find_nearest_owned_building(owner_id, "monastery", monk.position)
		if monastery != null: monk.issue_command("deposit_relic", Vector2.INF, monastery)
		return
	for relic in game.relics:
		if is_instance_valid(relic) and relic.available() and monk.position.distance_to(relic.position) < 460.0:
			monk.issue_command("relic", Vector2.INF, relic)
			return
	for site in game.objectives.sacred_sites:
		if site["owner_id"] < 0 or game.is_enemy(owner_id, site["owner_id"]):
			monk.issue_command("move", site["position"])
			return

func _resume_construction(workers: Array[RtsUnit]) -> void:
	var now: float = game.match_statistics.elapsed
	for building in game.buildings.duplicate():
		if not is_instance_valid(building) or building.owner_id != owner_id or building.is_complete(): continue
		var building_id: int = building.get_instance_id()
		var state: Dictionary = construction_watch.get(building_id, {"remaining": building.build_remaining, "progress_at": now, "created_at": now, "tried": []})
		if building.build_remaining < float(state["remaining"]) - 0.01:
			state["progress_at"] = now
			state["created_at"] = now
			state["tried"] = []
		state["remaining"] = building.build_remaining
		if now - float(state["created_at"]) > 90.0 and building.kind not in ["landmark", "wonder"]:
			for worker in workers:
				if worker.order == "build" and worker.target == building: worker.order_stop()
			for resource in GameData.BUILDINGS[building.kind]["cost"]:
				game.credit_resource(owner_id, resource, int(GameData.BUILDINGS[building.kind]["cost"][resource]))
			game.entity_destroyed(building)
			construction_watch.erase(building_id)
			continue
		if now - float(state["progress_at"]) > 22.0:
			for worker in workers:
				if worker.order == "build" and worker.target == building:
					state["tried"].append(worker.get_instance_id())
					worker.order_stop()
			state["progress_at"] = now
		if game.count_builders(building) == 0:
			var candidates := workers.duplicate()
			candidates.sort_custom(func(a: RtsUnit, b: RtsUnit) -> bool: return a.position.distance_squared_to(building.position) < b.position.distance_squared_to(building.position))
			for worker in candidates:
				if worker.order == "build" or state["tried"].has(worker.get_instance_id()): continue
				if game.navigation.path_to_range(worker.position, building.position, building.size().x * 0.6 + worker.radius(), worker).is_empty(): continue
				worker.order_build(building)
				break
			if game.count_builders(building) == 0: state["tried"] = []
		construction_watch[building_id] = state

func _construction_worker(point: Vector2) -> RtsUnit:
	var candidates: Array[RtsUnit] = []
	for unit in game.units:
		if is_instance_valid(unit) and unit.owner_id == owner_id and unit.kind == "villager" and unit.garrisoned_in == null and unit.order != "build":
			candidates.append(unit)
	candidates.sort_custom(func(a: RtsUnit, b: RtsUnit) -> bool: return a.position.distance_squared_to(point) < b.position.distance_squared_to(point))
	for unit in candidates.slice(0, mini(4, candidates.size())):
		if not game.navigation.path_between(unit.position, point, unit).is_empty(): return unit
	return null

func _construct(kind: String, _worker: RtsUnit) -> void:
	if not game.can_afford(owner_id, GameData.BUILDINGS[kind]["cost"]): return
	var base: Vector2 = game.spawn_point_for(owner_id)
	if kind == "farm":
		for unit in game.units:
			if not is_instance_valid(unit) or unit.owner_id != owner_id or unit.kind != "villager" or unit.order == "build": continue
			for attempt in 10:
				var nearby: Vector2 = unit.position + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(85.0, 155.0)
				if nearby.distance_to(base) > 490.0 or not game.can_place(kind, nearby): continue
				var approach: Vector2 = nearby + (unit.position - nearby).normalized() * (float(GameData.BUILDINGS[kind]["size"].x) * 0.6 + unit.radius())
				if not game.navigation._segment_clear(unit.position, approach, unit.radius(), unit): continue
				var farm_builders: Array[RtsUnit] = [unit]
				game.place_building(owner_id, kind, nearby, farm_builders)
				return
	for attempt in 24:
		var point := base + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(105, 245) if kind == "farm" else base + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(120, 360)
		if game.can_place(kind, point):
			var worker := _construction_worker(point)
			if worker == null: continue
			var builders: Array[RtsUnit] = [worker]
			game.place_building(owner_id, kind, point, builders)
			return

func _construct_dock(_worker: RtsUnit) -> void:
	var lake_center: Vector2 = game._scaled_point(Vector2(1580, 1190))
	var scale: float = game.world_size.x / 2400.0
	for radius in [180.0, 220.0, 260.0, 300.0, 340.0, 390.0, 440.0]:
		for step in 16:
			var point: Vector2 = lake_center + Vector2.from_angle(TAU * step / 16.0) * float(radius) * scale
			if game.can_place("dock", point):
				var worker := _construction_worker(point)
				if worker == null: continue
				var builders: Array[RtsUnit] = [worker]
				game.place_building(owner_id, "dock", point, builders)
				return

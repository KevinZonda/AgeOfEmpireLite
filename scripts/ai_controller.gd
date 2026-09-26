class_name RtsAiController
extends RefCounted

var game: Node2D

func _init(game_ref: Node2D) -> void:
	game = game_ref

func tick() -> void:
	var workers: Array[RtsUnit] = []
	var army: Array[RtsUnit] = []
	for unit in game.units:
		if not is_instance_valid(unit) or unit.owner_id != 1 or unit.garrisoned_in != null: continue
		if unit.kind == "villager": workers.append(unit)
		else: army.append(unit)
	_resume_construction(workers)
	for worker in workers:
		if worker.order == "idle":
			var resource_kind := "food" if game.players[1]["food"] < 330 else "wood" if game.players[1]["wood"] < 230 else "gold"
			var resource: RtsResource = game.find_nearest_resource(worker.position, resource_kind, INF, 1)
			if resource != null: worker.order_gather(resource)
	if game.players[1]["age"] == 1:
		if game._player_center(1) != null: game.advance_age(1)
		if army.is_empty(): return
	var center: RtsBuilding = game._player_center(1)
	var age: int = game.players[1]["age"]
	if center != null and not workers.is_empty() and age < RtsTechTree.MAX_AGE and not game.is_age_queued(1):
		var should_advance: bool = game.players[0]["age"] > age or army.size() >= 7
		if should_advance and game.can_afford(1, RtsTechTree.age_cost(age)):
			game.advance_age(1)
	if game.civilizations[1] == "Chinese" and not game.is_age_queued(1):
		for choice in RtsLandmarkCatalog.choices_for("Chinese", age, game.players[1]["landmarks"]):
			if choice["age"] > age or not game.can_afford(1, choice["cost"]): continue
			if game.construct_landmark(1, choice["id"]): break
	if center != null and workers.size() < 8: game.train_unit(center, "villager")
	if not workers.is_empty() and game.population_cap(1) - game.population_used(1) <= 3 and not _has_building("house"):
		_construct("house", workers[0])
	if not workers.is_empty() and not _has_building("barracks"):
		_construct("barracks", workers[0])
	elif not workers.is_empty() and not _has_building("archery_range"):
		_construct("archery_range", workers[0])
	elif not workers.is_empty() and not _has_building("stable"):
		_construct("stable", workers[0])
	if not workers.is_empty() and age >= 2 and not _has_building("outpost") and game.can_afford(1, GameData.BUILDINGS["outpost"]["cost"]):
		_construct("outpost", workers[0])
	if not workers.is_empty() and age >= 3 and not _has_building("siege_workshop") and game.can_afford(1, GameData.BUILDINGS["siege_workshop"]["cost"]):
		_construct("siege_workshop", workers[0])
	var enemy_profile := _enemy_profile()
	for building in game.buildings:
		if not is_instance_valid(building) or building.owner_id != 1 or not building.is_complete(): continue
		if building.production_queue.size() >= 3: continue
		for tech_id in RtsTechTree.all_researches(game.civilizations[1], building.kind):
			if RtsTechTree.can_research(game.civilizations[1], age, building.kind, tech_id, game.players[1]["researched"]):
				if game.research_technology(building, tech_id): break
		if building.kind == "barracks":
			var infantry_kind := "spearman" if enemy_profile["cavalry"] >= enemy_profile["ranged"] or age < 3 else "man_at_arms"
			game.train_unit(building, RtsUnitCatalog.replacement_for(game.civilizations[1], infantry_kind))
		if building.kind == "archery_range":
			var ranged_kind := RtsUnitCatalog.replacement_for(game.civilizations[1], "crossbowman")
			if age < 3 or enemy_profile["heavy"] == 0: ranged_kind = RtsUnitCatalog.replacement_for(game.civilizations[1], "archer")
			game.train_unit(building, ranged_kind)
		if building.kind == "stable":
			var cavalry_kind := "horseman"
			if enemy_profile["ranged"] == 0:
				if game.civilizations[1] == "French": cavalry_kind = "royal_knight"
				elif age >= 3: cavalry_kind = "knight"
			game.train_unit(building, cavalry_kind)
		if building.kind == "siege_workshop" and game.can_afford(1, GameData.UNITS["battering_ram"]["cost"]):
			game.train_unit(building, "battering_ram")
	if army.size() >= 4:
		var enemy_center: RtsBuilding = game._player_center(0)
		var target: RtsBuilding = enemy_center
		if target == null:
			for building in game.buildings:
				if is_instance_valid(building) and building.owner_id == 0 and building.kind == "landmark":
					target = building
					break
		if target != null:
			for soldier in army:
				if soldier.order == "idle": soldier.order_attack(target)

func _enemy_profile() -> Dictionary:
	var profile := {"cavalry": 0, "ranged": 0, "heavy": 0}
	for unit in game.units:
		if not is_instance_valid(unit) or unit.owner_id != 0 or unit.kind == "villager": continue
		if game.fog.active and not game.fog.can_see(1, unit.position): continue
		for tag in profile:
			if unit.stats.get("tags", []).has(tag): profile[tag] += 1
	return profile

func _has_building(kind: String) -> bool:
	for building in game.buildings:
		if is_instance_valid(building) and building.owner_id == 1 and building.kind == kind: return true
	return false

func _resume_construction(workers: Array[RtsUnit]) -> void:
	for building in game.buildings:
		if not is_instance_valid(building) or building.owner_id != 1 or building.is_complete(): continue
		if game.count_builders(building) > 0: continue
		for worker in workers:
			if worker.order != "build":
				worker.order_build(building)
				break

func _construct(kind: String, worker: RtsUnit) -> void:
	if worker.order == "build" or not game.can_afford(1, GameData.BUILDINGS[kind]["cost"]): return
	var base := Vector2(2070, 720)
	for attempt in 24:
		var point := base + Vector2(-randf_range(90, 380), randf_range(-300, 300))
		if game.can_place(kind, point):
			var builders: Array[RtsUnit] = [worker]
			game.place_building(1, kind, point, builders)
			return

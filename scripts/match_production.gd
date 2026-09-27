extends RefCounted

# Training and research transactions. The game root exposes the original
# methods as a stable API while these rules live together here.
static func train_unit(game: Node2D, building: RtsBuilding, unit_kind: String) -> bool:
	if game.game_over or not is_instance_valid(building) or not building.is_complete(): return false
	if not RtsTechTree.can_train(game.civilizations[building.owner_id], game.players[building.owner_id]["age"], building.producer_kind(), unit_kind, game.players[building.owner_id]["researched"], game.players[building.owner_id].get("dynasty", "")): return false
	if unit_kind == "imperial_official":
		var officials := 0
		for unit in game.units:
			if is_instance_valid(unit) and unit.owner_id == building.owner_id and unit.kind == "imperial_official": officials += 1
		for producer in game.buildings:
			if is_instance_valid(producer) and producer.owner_id == building.owner_id: officials += producer.training_queue.count("imperial_official")
		if officials >= 4: return false
	if game.population_used(building.owner_id) + RtsBalanceData.population_cost(unit_kind) > game.population_cap(building.owner_id):
		if building.owner_id == 0: game.notify_player("人口已满，请建造房屋")
		return false
	var paid_cost: Dictionary = RtsCivilizationRules.training_cost(game, building, unit_kind)
	if not game.spend(building.owner_id, paid_cost):
		if building.owner_id == 0: game.notify_player("资源不足")
		return false
	building.enqueue(unit_kind, paid_cost)
	if building.owner_id == 0: game.notify_player("正在训练%s" % GameData.UNITS[unit_kind]["label"])
	game._update_hud()
	return true

static func queued_research(game: Node2D, owner_id: int) -> Array[String]:
	var result: Array[String] = []
	for building in game.buildings:
		if not is_instance_valid(building) or building.owner_id != owner_id: continue
		for tech_id in building.research_queue:
			if not result.has(tech_id): result.append(tech_id)
	return result

static func research_technology(game: Node2D, building: RtsBuilding, tech_id: String) -> bool:
	if game.game_over or not is_instance_valid(building) or not building.is_complete(): return false
	var owner_id: int = building.owner_id
	if not RtsTechTree.can_research(game.civilizations[owner_id], game.players[owner_id]["age"], building.producer_kind(), tech_id, game.players[owner_id]["researched"]): return false
	if game.queued_research(owner_id).has(tech_id): return false
	var technology: Dictionary = RtsTechTree.get_technology(tech_id)
	var paid_cost: Dictionary = RtsCivilizationRules.research_cost(game.civilizations[owner_id], building.landmark_id, technology)
	if not game.spend(owner_id, paid_cost):
		if owner_id == 0: game.notify_player("研究所需资源不足")
		return false
	var research_time: float = float(technology["time"]) * (0.5 if building.landmark_id == "zh_spirit_way" else 1.0)
	building.enqueue_research(tech_id, research_time, paid_cost)
	if owner_id == 0: game.notify_player("正在研究%s" % technology["label"])
	game._update_hud()
	return true

static func complete_research(game: Node2D, owner_id: int, tech_id: String) -> void:
	if game.players[owner_id]["researched"].has(tech_id): return
	game.players[owner_id]["researched"].append(tech_id)
	if game.civilizations[owner_id] == "French" and RtsTechTree.get_technology(tech_id).get("economy", false):
		for landmark in game.buildings:
			if is_instance_valid(landmark) and landmark.owner_id == owner_id and landmark.landmark_id == "fr_chamber_of_commerce" and landmark.is_complete():
				if game.population_used(owner_id) < game.population_cap(owner_id): game.spawn_unit(owner_id, "trader", game.find_spawn_position(landmark))
				break
	for unit in game.units:
		if is_instance_valid(unit) and unit.owner_id == owner_id: unit.refresh_stats()
	if owner_id == 0:
		game.notify_player("%s研究完成" % RtsTechTree.get_technology(tech_id)["label"])
		game._rebuild_actions()
	game._update_hud()

static func cancel_job(game: Node2D, building: RtsBuilding, index: int) -> bool:
	if not is_instance_valid(building) or building.is_queued_for_deletion() or index < 0: return false
	var job: Dictionary = building.cancel_queue_entry(index)
	if job.is_empty(): return false
	for resource in job["cost"]:
		game.players[building.owner_id][resource] += job["cost"][resource]
	if building.owner_id == 0: game.notify_player("已取消，资源已返还")
	game._update_hud()
	return true

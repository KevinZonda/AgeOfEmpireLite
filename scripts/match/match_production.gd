extends RefCounted

# Training and research transactions. The game root exposes the original
# methods as a stable API while these rules live together here.
static func train_unit(game: Node2D, building: RtsBuilding, unit_kind: String) -> bool:
	var status := RtsActionAvailability.production(game, building, "train", unit_kind)
	if not status["available"]:
		if is_instance_valid(building) and building.owner_id == 0: game.notify_player(status["reason"])
		return false
	var paid_cost: Dictionary = status["cost"]
	if not game.spend(building.owner_id, paid_cost): return false
	building.enqueue(unit_kind, paid_cost)
	if building.owner_id == 0: game.notify_player("正在训练%s" % GameData.UNITS[unit_kind]["label"])
	game._update_hud()
	return true

static func queued_research(game: Node2D, owner_id: int) -> Array[String]:
	var result: Array[String] = []
	for building in game.buildings:
		if not is_instance_valid(building) or building.owner_id != owner_id or building.production_queue.is_empty(): continue
		for tech_id in building.queued_research_ids():
			if not result.has(tech_id): result.append(tech_id)
	return result

static func research_technology(game: Node2D, building: RtsBuilding, tech_id: String) -> bool:
	var status := RtsActionAvailability.production(game, building, "research", tech_id)
	if not status["available"]:
		if is_instance_valid(building) and building.owner_id == 0: game.notify_player(status["reason"])
		return false
	var owner_id: int = building.owner_id
	var technology := RtsTechTree.get_technology(tech_id)
	var paid_cost: Dictionary = status["cost"]
	if not game.spend(owner_id, paid_cost): return false
	var research_time: float = float(technology["time"]) * (0.5 if building.landmark_id == "zh_spirit_way" else 1.0)
	building.enqueue_research(tech_id, research_time, paid_cost)
	if owner_id == 0: game.notify_player("正在研究%s" % technology["label"])
	game._update_hud()
	return true

static func complete_research(game: Node2D, owner_id: int, tech_id: String) -> void:
	if not game.session.player(owner_id).complete_research(tech_id): return
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
		game.session.player(building.owner_id).credit(resource, job["cost"][resource])
	if building.owner_id == 0: game.notify_player("已取消，资源已返还")
	game._update_hud()
	return true

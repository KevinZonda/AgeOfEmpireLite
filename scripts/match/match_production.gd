extends RefCounted

# Training and research transactions. The game root exposes the original
# methods as a stable API. Committed facts and feedback are presentation-neutral.
static func train_unit(game: Node2D, building: RtsBuilding, unit_kind: String) -> bool:
	var status := RtsActionAvailability.production(game, building, "train", unit_kind)
	if not status["available"]:
		if is_instance_valid(building): game.session.changes.feedback(building.owner_id, status["reason"])
		return false
	var paid_cost: Dictionary = status["cost"]
	game.session.changes.begin_transaction()
	if not game.spend(building.owner_id, paid_cost):
		game.session.changes.end_transaction()
		return false
	building.enqueue(unit_kind, paid_cost)
	game.session.changes.mark(building.owner_id, &"production")
	game.session.changes.feedback(building.owner_id, "正在训练%s" % GameData.UNITS[unit_kind]["label"])
	game.session.changes.end_transaction()
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
		if is_instance_valid(building): game.session.changes.feedback(building.owner_id, status["reason"])
		return false
	var owner_id: int = building.owner_id
	var technology := RtsTechTree.get_technology(tech_id)
	var paid_cost: Dictionary = status["cost"]
	game.session.changes.begin_transaction()
	if not game.spend(owner_id, paid_cost):
		game.session.changes.end_transaction()
		return false
	var research_time: float = float(technology["time"]) * (0.5 if building.landmark_id == "zh_spirit_way" else 1.0)
	building.enqueue_research(tech_id, research_time, paid_cost)
	game.session.changes.mark(owner_id, &"production")
	game.session.changes.feedback(owner_id, "正在研究%s" % technology["label"])
	game.session.changes.end_transaction()
	return true

static func complete_research(game: Node2D, owner_id: int, tech_id: String) -> void:
	if not game.session.player(owner_id).complete_research(tech_id): return
	game.session.changes.begin_transaction()
	if game.civilizations[owner_id] == "French" and RtsTechTree.get_technology(tech_id).get("economy", false):
		for landmark in game.buildings:
			if is_instance_valid(landmark) and landmark.owner_id == owner_id and landmark.landmark_id == "fr_chamber_of_commerce" and landmark.is_complete():
				if game.population_used(owner_id) < game.population_cap(owner_id): game.spawn_unit(owner_id, "trader", game.find_spawn_position(landmark))
				break
	for unit in game.units:
		if is_instance_valid(unit) and unit.owner_id == owner_id: unit.refresh_stats()
	game.session.changes.mark(owner_id, &"research")
	game.session.changes.feedback(owner_id, "%s研究完成" % RtsTechTree.get_technology(tech_id)["label"])
	game.session.changes.end_transaction()

static func cancel_job(game: Node2D, building: RtsBuilding, index: int) -> bool:
	if not is_instance_valid(building) or building.is_queued_for_deletion() or index < 0: return false
	var job: Dictionary = building.cancel_queue_entry(index)
	if job.is_empty(): return false
	game.session.changes.begin_transaction()
	for resource in job["cost"]:
		game.session.player(building.owner_id).credit(resource, job["cost"][resource])
	game.session.changes.mark(building.owner_id, &"resources")
	game.session.changes.mark(building.owner_id, &"production")
	game.session.changes.feedback(building.owner_id, "已取消，资源已返还")
	game.session.changes.end_transaction()
	return true

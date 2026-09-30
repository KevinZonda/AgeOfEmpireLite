extends RefCounted

# Producers expose queue operations, not a concrete RtsBuilding dependency.
# Battlefield effects are requests handled at the assembly boundary.
signal unit_spawn_requested(owner_id: int, kind: String, producer: Object)
signal age_advanced(owner_id: int, age: int)
var _session: RefCounted
var _economy: RefCounted
var _entities: RefCounted

func _init(session: RefCounted, economy: RefCounted, entities: RefCounted) -> void:
	_session = session
	_economy = economy
	_entities = entities

func context_for(owner_id: int, producer: Object = null) -> Dictionary:
	var bank: Dictionary = _session.player(owner_id).bank
	return RtsActionAvailability.for_producer({
		"owner_id": owner_id, "civilization": _session.civilizations[owner_id], "age": bank["age"],
		"dynasty": bank.get("dynasty", ""), "researched": bank["researched"],
		"landmarks": bank["landmarks"], "active_landmark": _entities.active_landmark_id(owner_id),
		"resources": bank, "population_used": _economy.population_used(owner_id), "population_cap": _economy.population_cap(owner_id),
		"queued_research": queued_research(owner_id), "official_count": _entities.official_count(owner_id),
		"has_wonder": _entities.has_building(owner_id, "wonder"), "entity_queries": _entities,
	}, producer)

func availability(producer: Object, action_type: String, kind: String) -> Dictionary:
	if _session.game_over: return {"available": false, "reason": "对局已结束", "cost": {}}
	if not is_instance_valid(producer) or producer.is_queued_for_deletion():
		return {"available": false, "reason": "建筑已移除", "cost": {}}
	return RtsActionAvailability.evaluate(action_type, kind, context_for(producer.owner_id, producer))

func train_unit(producer: Object, unit_kind: String) -> bool:
	var status := availability(producer, "train", unit_kind)
	if not status["available"]:
		if is_instance_valid(producer): _session.changes.feedback(producer.owner_id, status["reason"])
		return false
	var paid_cost: Dictionary = status["cost"]
	_session.changes.begin_transaction()
	if not _economy.spend(producer.owner_id, paid_cost):
		_session.changes.end_transaction()
		return false
	producer.enqueue(unit_kind, paid_cost)
	_session.changes.mark(producer.owner_id, &"production")
	_session.changes.feedback(producer.owner_id, "正在训练%s" % GameData.UNITS[unit_kind]["label"])
	_session.changes.end_transaction()
	return true

func queued_research(owner_id: int) -> Array[String]:
	return _entities.queued_research(owner_id)

func research_technology(producer: Object, tech_id: String) -> bool:
	var status := availability(producer, "research", tech_id)
	if not status["available"]:
		if is_instance_valid(producer): _session.changes.feedback(producer.owner_id, status["reason"])
		return false
	var owner_id: int = producer.owner_id
	var technology := RtsTechTree.get_technology(tech_id)
	var paid_cost: Dictionary = status["cost"]
	_session.changes.begin_transaction()
	if not _economy.spend(owner_id, paid_cost):
		_session.changes.end_transaction()
		return false
	var research_time: float = float(technology["time"]) * (0.5 if producer.landmark_id == "zh_spirit_way" else 1.0)
	producer.enqueue_research(tech_id, research_time, paid_cost)
	_session.changes.mark(owner_id, &"production")
	_session.changes.feedback(owner_id, "正在研究%s" % technology["label"])
	_session.changes.end_transaction()
	return true

func complete_research(owner_id: int, tech_id: String) -> void:
	if _session.player(owner_id).bank["researched"].has(tech_id): return
	_session.changes.begin_transaction()
	_session.player(owner_id).complete_research(tech_id)
	if _session.civilizations[owner_id] == "French" and RtsTechTree.get_technology(tech_id).get("economy", false):
		var landmark: Object = _entities.completed_landmark(owner_id, "fr_chamber_of_commerce")
		if landmark != null and _economy.population_used(owner_id) < _economy.population_cap(owner_id):
			unit_spawn_requested.emit(owner_id, "trader", landmark)
	_entities.refresh_stats(owner_id)
	_session.changes.mark(owner_id, &"research")
	_session.changes.feedback(owner_id, "%s研究完成" % RtsTechTree.get_technology(tech_id)["label"])
	_session.changes.end_transaction()

func complete_age(owner_id: int, target_age: int, landmark_id := "") -> void:
	_session.changes.begin_transaction()
	var result: Dictionary = _session.player(owner_id).complete_age(_session.civilizations[owner_id], target_age, landmark_id)
	if result.is_empty():
		_session.changes.end_transaction()
		return
	_entities.refresh_stats(owner_id, true)
	for domain in result["domains"]: _session.changes.mark(owner_id, domain)
	if result["aged_up"]:
		age_advanced.emit(owner_id, target_age)
		_session.changes.feedback(owner_id, "进入时代 %d！" % target_age)
	if result["dynasty_changed"]:
		_session.changes.feedback(owner_id, "进入%s朝：王朝加成已生效" % RtsLandmarkCatalog.DYNASTY_NAMES[result["dynasty"]])
	_session.changes.end_transaction()

func cancel_job(producer: Object, index: int) -> bool:
	if not is_instance_valid(producer) or producer.is_queued_for_deletion() or index < 0: return false
	_session.changes.begin_transaction()
	var job: Dictionary = producer.cancel_queue_entry(index)
	if job.is_empty():
		_session.changes.end_transaction()
		return false
	for resource in job["cost"]: _session.player(producer.owner_id).credit(resource, job["cost"][resource])
	_session.changes.mark(producer.owner_id, &"resources")
	_session.changes.mark(producer.owner_id, &"production")
	_session.changes.feedback(producer.owner_id, "已取消，资源已返还")
	_session.changes.end_transaction()
	return true

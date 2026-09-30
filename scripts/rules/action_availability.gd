class_name RtsActionAvailability
extends RefCounted

# Pure validation is shared by panel descriptions and command transactions.
# Transactions validate again immediately before spending or enqueuing.
static func context_for(game: Node2D, owner_id: int, building: RtsBuilding = null) -> Dictionary:
	var bank: Dictionary = game.players[owner_id]
	var officials := 0
	var has_wonder := false
	for unit in game.units:
		if is_instance_valid(unit) and unit.owner_id == owner_id and unit.kind == "imperial_official": officials += 1
	for producer in game.buildings:
		if not is_instance_valid(producer) or producer.owner_id != owner_id: continue
		officials += producer.queued_unit_count("imperial_official")
		if producer.kind == "wonder": has_wonder = true
	return {
		"game": game, "civilization": game.civilizations[owner_id], "age": bank["age"],
		"dynasty": bank.get("dynasty", ""), "researched": bank["researched"],
		"landmarks": bank["landmarks"], "active_landmark": game.active_landmark_id(owner_id),
		"resources": bank, "population_used": game.population_used(owner_id), "population_cap": game.population_cap(owner_id),
		"queued_research": game.queued_research(owner_id), "official_count": officials, "has_wonder": has_wonder,
		"producer_building": building, "producer": building.producer_kind() if building != null else "",
		"production_complete": building.is_complete() if building != null else true,
		"landmark_id": building.landmark_id if building != null else "",
		"landmark_cooldown": building.landmark_ability_cooldown if building != null else 0.0,
		"landmark_stockpile": building.landmark_stockpile if building != null else {},
	}

static func production(game: Node2D, building: RtsBuilding, action_type: String, kind: String) -> Dictionary:
	if game.game_over: return {"available": false, "reason": "对局已结束", "cost": {}}
	if not is_instance_valid(building) or building.is_queued_for_deletion():
		return {"available": false, "reason": "建筑已移除", "cost": {}}
	return evaluate(action_type, kind, context_for(game, building.owner_id, building))

static func construction(game: Node2D, owner_id: int, kind: String, point: Vector2, vertical := false, landmark_id := "") -> Dictionary:
	var bank: Dictionary = game.players[owner_id]
	var context := {"civilization": game.civilizations[owner_id], "age": bank["age"], "resources": bank,
		"landmarks": bank["landmarks"], "active_landmark": game.active_landmark_id(owner_id) if kind == "landmark" else ""}
	if kind == "wonder":
		for building in game.buildings:
			if is_instance_valid(building) and building.owner_id == owner_id and building.kind == "wonder":
				context["has_wonder"] = true
				break
	var status := evaluate("landmark" if kind == "landmark" else "build", landmark_id if kind == "landmark" else kind, context)
	if status["available"] and not game.can_place(kind, point, vertical):
		return {"available": false, "reason": "这里不能建造", "cost": status["cost"]}
	return status

static func evaluate(action_type: String, kind: String, context: Dictionary) -> Dictionary:
	var civilization: String = context.get("civilization", "")
	var age: int = context.get("age", 1)
	var producer: String = context.get("producer", "")
	var researched: Array = context.get("researched", [])
	var cost: Dictionary = {}
	var status: Dictionary = {"available": false, "reason": "未知命令"}
	match action_type:
		"order":
			status = {"available": true, "reason": ""}
		"landmark_ability":
			if not context.get("production_complete", false): status = {"available": false, "reason": "地标尚未建成"}
			elif kind == "spy" and context.get("landmark_id", "") == "zh_imperial_palace":
				var cooldown := float(context.get("landmark_cooldown", 0.0))
				status = {"available": cooldown <= 0.0, "reason": "冷却 %.0f 秒" % cooldown if cooldown > 0.0 else ""}
			elif kind == "collect_stockpile" and context.get("landmark_id", "") == "fr_guild_hall":
				var total := 0
				for amount in context.get("landmark_stockpile", {}).values(): total += int(amount)
				status = {"available": total > 0, "reason": "尚无可提取资源" if total <= 0 else ""}
		"convert_gate":
			if producer.ends_with("_wall") and kind == ("stone_gate" if producer == "stone_wall" else "palisade_gate"):
				var resource := "stone" if kind == "stone_gate" else "wood"
				cost = {resource: GameData.BUILDINGS[kind]["cost"][resource] - GameData.BUILDINGS[producer]["cost"][resource]}
				status = {"available": context.get("production_complete", false), "reason": "城墙尚未建成"}
		"build":
			if GameData.BUILDINGS.has(kind):
				cost = RtsCivilizationRules.building_cost(civilization, kind)
				status = RtsTechTree.building_status(civilization, age, kind)
				if kind == "wonder" and context.get("has_wonder", false): status = {"available": false, "reason": "已有奇观"}
		"train":
			if GameData.UNITS.has(kind):
				cost = GameData.unit_cost(kind)
				if context.get("game") != null and context.get("producer_building") is RtsBuilding:
					cost = RtsCivilizationRules.training_cost(context["game"], context["producer_building"], kind)
				status = RtsTechTree.unit_status(civilization, age, producer, kind, researched, context.get("dynasty", ""))
		"research":
			var technology := RtsTechTree.get_technology(kind)
			if not technology.is_empty():
				cost = RtsCivilizationRules.research_cost(civilization, context.get("landmark_id", ""), technology)
				status = RtsTechTree.research_status(civilization, age, producer, kind, researched)
		"age":
			cost = RtsTechTree.age_cost(age)
			status = {"available": RtsTechTree.can_advance(age), "reason": "已达最高时代"}
		"landmark":
			cost = RtsLandmarkCatalog.landmark(kind).get("cost", {})
			status = RtsLandmarkCatalog.choice_status(civilization, age, context.get("landmarks", []), kind, context.get("active_landmark", ""))
	var reason: String = status.get("reason", "尚未解锁")
	if not status.get("available", false): return {"available": false, "reason": reason, "cost": cost}
	if (action_type == "train" or action_type == "research" or action_type == "age" or action_type == "landmark" and producer != "") and not context.get("production_complete", true):
		return {"available": false, "reason": "建筑尚未建成", "cost": cost}
	if action_type == "research" and context.get("queued_research", []).has(kind):
		return {"available": false, "reason": "正在研究", "cost": cost}
	if action_type == "train" and kind == "imperial_official" and int(context.get("official_count", 0)) >= 4:
		return {"available": false, "reason": "已达到 4 名命官上限", "cost": cost}
	if action_type == "train" and int(context.get("population_used", 0)) + RtsBalanceData.population_cost(kind) > int(context.get("population_cap", 0)):
		return {"available": false, "reason": "人口已满", "cost": cost}
	var bank: Dictionary = context.get("resources", {})
	for resource in GameData.RESOURCE_NAMES:
		var required: int = cost.get(resource, 0)
		var available: int = bank.get(resource, 0)
		if available < required:
			return {"available": false, "reason": "%s不足：差%d" % [GameData.RESOURCE_LABELS[resource], required - available], "cost": cost}
	return {"available": true, "reason": "", "cost": cost}

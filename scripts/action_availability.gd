class_name RtsActionAvailability
extends RefCounted

# A single source for panel lock reasons. The game still validates commands when
# clicked; this class only explains their current state to the player.
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
		"unit_ability":
			var ready: bool = context.get("ability_ready", {}).get(kind, false)
			if kind == "camp": cost = {"wood": 25}
			var locked_reason: String = "已达到 5 座营地上限" if kind == "camp" and int(context.get("camp_count", 0)) >= 5 else context.get("ability_reason", {}).get(kind, "技能冷却中")
			status = {"available": ready, "reason": locked_reason if not ready else ""}
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
	if action_type == "train" and int(context.get("population_used", 0)) + RtsBalanceData.population_cost(kind) > int(context.get("population_cap", 0)):
		return {"available": false, "reason": "人口已满", "cost": cost}
	var bank: Dictionary = context.get("resources", {})
	for resource in GameData.RESOURCE_NAMES:
		var required: int = cost.get(resource, 0)
		var available: int = bank.get(resource, 0)
		if available < required:
			return {"available": false, "reason": "%s不足：差%d" % [GameData.RESOURCE_LABELS[resource], required - available], "cost": cost}
	return {"available": true, "reason": "", "cost": cost}

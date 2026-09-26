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
		"build":
			if GameData.BUILDINGS.has(kind):
				cost = GameData.BUILDINGS[kind]["cost"]
				status = RtsTechTree.building_status(civilization, age, kind)
		"train":
			if GameData.UNITS.has(kind):
				cost = GameData.UNITS[kind]["cost"]
				status = RtsTechTree.unit_status(civilization, age, producer, kind, researched)
		"research":
			if RtsTechTree.TECHNOLOGIES.has(kind):
				cost = RtsTechTree.TECHNOLOGIES[kind]["cost"]
				status = RtsTechTree.research_status(civilization, age, producer, kind, researched)
		"age":
			cost = RtsTechTree.age_cost(age)
			status = {"available": RtsTechTree.can_advance(age), "reason": "已达最高时代"}
	var reason: String = status.get("reason", "尚未解锁")
	if not status.get("available", false): return {"available": false, "reason": reason, "cost": cost}
	if (action_type == "train" or action_type == "research" or action_type == "age") and not context.get("production_complete", true):
		return {"available": false, "reason": "建筑尚未建成", "cost": cost}
	if action_type == "research" and context.get("queued_research", []).has(kind):
		return {"available": false, "reason": "正在研究", "cost": cost}
	if action_type == "train" and int(context.get("population_used", 0)) >= int(context.get("population_cap", 0)):
		return {"available": false, "reason": "人口已满", "cost": cost}
	var bank: Dictionary = context.get("resources", {})
	for resource in GameData.RESOURCE_NAMES:
		var required: int = cost.get(resource, 0)
		var available: int = bank.get(resource, 0)
		if available < required:
			return {"available": false, "reason": "%s不足：差%d" % [GameData.RESOURCE_LABELS[resource], required - available], "cost": cost}
	return {"available": true, "reason": "", "cost": cost}

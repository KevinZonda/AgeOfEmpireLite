class_name RtsCivilizationRules
extends RefCounted

# Civilization effects that depend on battlefield state live here. Catalogs
# describe what exists; these rules decide when a spatial bonus is active.
static func building_cost(civilization: String, kind: String) -> Dictionary:
	var cost: Dictionary = GameData.BUILDINGS[kind]["cost"].duplicate(true)
	if civilization == "English" and kind == "farm": cost["wood"] = 40
	return cost

static func economic_gather_multiplier(game: Node2D, owner_id: int, resource_kind: String) -> float:
	var multiplier := 1.0
	for tech_id in game.players[owner_id].get("researched", []):
		var tech: Dictionary = RtsTechTree.get_technology(tech_id)
		if tech.get("economy", false) and (tech.get("gather_kind", "") == resource_kind or tech.get("gather_kind", "") == "gold" and resource_kind == "stone"):
			multiplier *= float(tech.get("gather_multiplier", 1.0))
	return multiplier

static func economic_site_multiplier(game: Node2D, owner_id: int, resource_kind: String, source: Node2D) -> float:
	var site_kind := "mill" if resource_kind == "food" else "lumber_camp" if resource_kind == "wood" else "mining_camp"
	for building in game.buildings:
		if not is_instance_valid(building) or building.owner_id != owner_id or building.kind != site_kind or not building.is_complete(): continue
		if building.position.distance_to(source.position) <= 170.0: return 1.15
	return 1.0

static func french_keep_influence(game: Node2D, producer: RtsBuilding) -> bool:
	if game.civilizations[producer.owner_id] != "French" or producer.producer_kind() not in ["archery_range", "stable"]: return false
	for building in game.buildings:
		if not is_instance_valid(building) or building.owner_id != producer.owner_id or not building.is_complete(): continue
		if building.kind != "keep" and building.landmark_id != "fr_red_palace": continue
		if building.position.distance_to(producer.position) <= 180.0: return true
	return false

static func training_cost(game: Node2D, producer: RtsBuilding, unit_kind: String) -> Dictionary:
	var cost: Dictionary = GameData.unit_cost(unit_kind).duplicate(true)
	if french_keep_influence(game, producer):
		for resource in cost: cost[resource] = ceili(float(cost[resource]) * 0.8)
	return cost

static func research_cost(civilization: String, landmark_id: String, technology: Dictionary) -> Dictionary:
	var cost: Dictionary = technology.get("cost", {}).duplicate(true)
	var discount := RtsLandmarkCatalog.research_discount(landmark_id)
	if civilization == "French" and technology.get("economy", false): discount *= 0.7
	for resource in cost: cost[resource] = ceili(float(cost[resource]) * discount)
	return cost

static func english_network_rate(game: Node2D, unit: RtsUnit) -> float:
	if game.civilizations[unit.owner_id] != "English" or not unit.stats.get("tags", []).has("military") or unit.stats.get("tags", []).has("siege"): return 1.0
	for building in game.buildings:
		if not is_instance_valid(building) or building.owner_id != unit.owner_id or not building.is_complete(): continue
		if building.kind not in ["town_center", "outpost", "keep"] and building.landmark_id not in ["eng_white_tower", "eng_berkshire_fortress"]: continue
		if building.position.distance_to(unit.position) > 220.0: continue
		for enemy in game.units:
			if is_instance_valid(enemy) and game.is_enemy(unit.owner_id, enemy.owner_id) and enemy.position.distance_to(building.position) <= 250.0 and (not game.fog.active or game.fog.can_detect_unit(unit.owner_id, enemy)):
				return 1.2
	return 1.0

static func spirit_way_active(game: Node2D, owner_id: int) -> bool:
	if game.civilizations[owner_id] != "Chinese": return false
	for building in game.buildings:
		if is_instance_valid(building) and building.owner_id == owner_id and building.landmark_id == "zh_spirit_way" and building.is_complete(): return true
	return false

static func is_dynasty_unit(kind: String) -> bool:
	return kind in ["zhuge_nu", "fire_lancer", "grenadier"]

static func wall_ranged_multiplier(game: Node2D, unit: RtsUnit) -> float:
	if game.civilizations[unit.owner_id] != "Chinese" or not is_instance_valid(unit.wall_host) or unit.wall_host.owner_id != unit.owner_id: return 1.0
	for building in game.buildings:
		if is_instance_valid(building) and building.owner_id == unit.owner_id and building.landmark_id == "zh_gatehouse" and building.is_complete(): return 1.25
	return 1.0

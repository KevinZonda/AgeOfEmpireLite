class_name RtsTechTree
extends RefCounted

# Progression rules and research definitions; unit/building balance lives in GameData.
const MAX_AGE := 4
const AGE_ADVANCE_COSTS := {
	1: {"food": 220, "gold": 100},
	2: {"food": 400, "gold": 200},
	3: {"food": 650, "gold": 350},
}
const AGE_ADVANCE_TIMES := {1: 25.0, 2: 35.0, 3: 45.0}

const BUILD_MENU := ["house", "farm", "market", "dock", "barracks", "archery_range", "stable", "blacksmith", "monastery", "outpost", "palisade_wall", "palisade_gate", "stone_wall", "stone_gate", "keep", "siege_workshop", "wonder"]
const BUILDING_AGE := {
	"town_center": 1,
	"house": 1,
	"farm": 1,
	"market": 2,
	"dock": 2,
	"barracks": 2,
	"archery_range": 2,
	"stable": 2,
	"blacksmith": 2,
	"monastery": 3,
	"outpost": 2,
	"palisade_wall": 2,
	"palisade_gate": 2,
	"stone_wall": 3,
	"stone_gate": 3,
	"keep": 3,
	"siege_workshop": 3,
	"wonder": 4,
	"white_tower": 3,
	"wynguard": 4,
	"royal_institute": 3,
	"imperial_academy": 2,
	"spirit_way": 4,
}

# Base roster; civilization substitutions are declared in RtsUnitCatalog.
const PRODUCTION := {
	"town_center": ["villager", "imperial_official"],
	"imperial_academy": ["imperial_official"],
	"market": ["trader"],
	"dock": ["fishing_boat", "arrow_ship", "warship", "transport_ship"],
	"monastery": ["monk"],
	"barracks": ["spearman", "man_at_arms"],
	"archery_range": ["archer", "crossbowman", "handcannoneer"],
	"stable": ["scout", "horseman", "knight"],
	"blacksmith": [],
	"siege_workshop": ["battering_ram", "siege_tower", "springald", "mangonel", "trebuchet", "bombard"],
	"white_tower": ["spearman", "man_at_arms", "archer", "crossbowman", "horseman", "knight"],
	"wynguard": ["spearman", "man_at_arms", "archer", "trebuchet"],
	"royal_institute": [],
	"spirit_way": [],
}
const UNIT_AGE := {
	"villager": 1,
	"imperial_official": 1,
	"scout": 2,
	"spearman": 2,
	"man_at_arms": 3,
	"palace_guard": 3,
	"archer": 2,
	"zhuge_nu": 2,
	"fire_lancer": 3,
	"grenadier": 4,
	"longbow": 2,
	"crossbowman": 3,
	"arbaletrier": 3,
	"horseman": 2,
	"knight": 3,
	"royal_knight": 2,
	"battering_ram": 3,
	"trebuchet": 3,
	"handcannoneer": 4,
	"mangonel": 3,
	"springald": 3,
	"bombard": 4,
	"cannon": 4,
	"nest_of_bees": 3,
	"siege_tower": 3,
	"trader": 2,
	"fishing_boat": 2,
	"warship": 2,
	"arrow_ship": 2,
	"transport_ship": 2,
	"monk": 3,
}
const UNIT_AGE_OVERRIDES := {
	"English": {"man_at_arms": 2},
}
const UNIT_CIVILIZATION := {
	"imperial_official": "Chinese",
	"longbow": "English",
	"arbaletrier": "French",
	"royal_knight": "French",
	"zhuge_nu": "Chinese",
	"fire_lancer": "Chinese",
	"grenadier": "Chinese",
	"palace_guard": "Chinese",
	"cannon": "French",
	"nest_of_bees": "Chinese",
}
const UNIT_REQUIRES := {} # Unit-specific research prerequisites can be added here.

# Effects add to effective unit definitions; existing units can be refreshed using
# RtsUnitCatalog.unit_definition(civilization, unit_kind, researched).
const TECHNOLOGIES := {
	"forged_weapons": {"label": "锻造武器", "age": 2, "building": "barracks", "cost": {"food": 100, "gold": 75}, "time": 15.0, "requires": [], "target_tags": ["infantry"], "effects": {"damage": 2.0}},
	"iron_armor": {"label": "铁甲", "age": 3, "building": "town_center", "cost": {"food": 150, "gold": 125}, "time": 20.0, "requires": [], "target_tags": ["military"], "effects": {"armor_melee": 1.0, "armor_ranged": 1.0}},
	"veteran_training": {"label": "老兵训练", "age": 3, "building": "barracks", "cost": {"food": 180, "gold": 120}, "time": 22.0, "requires": ["forged_weapons"], "target_tags": ["infantry"], "effects": {"hp": 20.0}},
	"elite_training": {"label": "精锐训练", "age": 4, "building": "town_center", "cost": {"food": 280, "gold": 220}, "time": 30.0, "requires": ["iron_armor", "veteran_training"], "target_tags": ["military"], "effects": {"damage": 3.0, "hp": 20.0}},
	"melee_attack_2": {"label": "熟铁块吹炼法", "age": 2, "building": "blacksmith", "cost": {"food": 50, "gold": 125}, "time": 33.0, "requires": [], "civilizations": ["English", "Chinese"], "target_tags": ["military"], "exclude_tags": ["siege", "naval"], "effects": {"damage_melee": 1.0}},
	"melee_attack_3": {"label": "脱碳", "age": 3, "building": "blacksmith", "cost": {"food": 100, "gold": 250}, "time": 33.0, "requires": ["melee_attack_2"], "civilizations": ["English", "Chinese"], "target_tags": ["military"], "exclude_tags": ["siege", "naval"], "effects": {"damage_melee": 1.0}},
	"melee_attack_4": {"label": "大马士革钢", "age": 4, "building": "blacksmith", "cost": {"food": 150, "gold": 350}, "time": 33.0, "requires": ["melee_attack_3"], "civilizations": ["English", "Chinese"], "target_tags": ["military"], "exclude_tags": ["siege", "naval"], "effects": {"damage_melee": 1.0}},
	"ranged_attack_2": {"label": "钢制箭头", "age": 2, "building": "blacksmith", "cost": {"wood": 50, "gold": 125}, "time": 33.0, "requires": [], "target_tags": ["ranged"], "exclude_tags": ["siege", "naval", "gunpowder"], "effects": {"damage_ranged": 1.0}},
	"ranged_attack_3": {"label": "平衡炮弹", "age": 3, "building": "blacksmith", "cost": {"wood": 100, "gold": 250}, "time": 33.0, "requires": ["ranged_attack_2"], "target_tags": ["ranged"], "exclude_tags": ["siege", "naval", "gunpowder"], "effects": {"damage_ranged": 1.0}},
	"ranged_attack_4": {"label": "箭头穿孔板甲", "age": 4, "building": "blacksmith", "cost": {"wood": 150, "gold": 350}, "time": 33.0, "requires": ["ranged_attack_3"], "target_tags": ["ranged"], "exclude_tags": ["siege", "naval", "gunpowder"], "effects": {"damage_ranged": 1.0}},
	"melee_armor_2": {"label": "合身皮具", "age": 2, "building": "blacksmith", "cost": {"food": 50, "gold": 125}, "time": 33.0, "requires": [], "target_tags": ["military"], "exclude_tags": ["siege", "naval"], "effects": {"armor_melee": 1.0}},
	"melee_armor_3": {"label": "绝缘头盔", "age": 3, "building": "blacksmith", "cost": {"food": 100, "gold": 250}, "time": 33.0, "requires": ["melee_armor_2"], "target_tags": ["military"], "exclude_tags": ["siege", "naval"], "effects": {"armor_melee": 1.0}},
	"melee_armor_4": {"label": "铁匠大师", "age": 4, "building": "blacksmith", "cost": {"food": 150, "gold": 350}, "time": 33.0, "requires": ["melee_armor_3"], "target_tags": ["military"], "exclude_tags": ["siege", "naval"], "effects": {"armor_melee": 1.0}},
	"ranged_armor_2": {"label": "铁制底网", "age": 2, "building": "blacksmith", "cost": {"food": 50, "gold": 125}, "time": 33.0, "requires": [], "target_tags": ["military"], "exclude_tags": ["siege", "naval"], "effects": {"armor_ranged": 1.0}},
	"ranged_armor_3": {"label": "楔形铆钉", "age": 3, "building": "blacksmith", "cost": {"food": 100, "gold": 250}, "time": 33.0, "requires": ["ranged_armor_2"], "target_tags": ["military"], "exclude_tags": ["siege", "naval"], "effects": {"armor_ranged": 1.0}},
	"ranged_armor_4": {"label": "斜面", "age": 4, "building": "blacksmith", "cost": {"food": 150, "gold": 350}, "time": 33.0, "requires": ["ranged_armor_3"], "target_tags": ["military"], "exclude_tags": ["siege", "naval"], "effects": {"armor_ranged": 1.0}},
	"military_academy": {"label": "军事学院", "age": 3, "building": "blacksmith", "cost": {"food": 100, "gold": 250}, "time": 33.0, "requires": [], "target_tags": [], "effects": {}},
	"enclosures": {"label": "圈地法", "age": 4, "building": "town_center", "cost": {"wood": 200, "gold": 350}, "time": 45.0, "requires": [], "civilizations": ["English"], "target_tags": [], "effects": {}},
	"horticulture": {"label": "园艺学", "age": 2, "building": "town_center", "cost": {"food": 100, "gold": 75}, "time": 25.0, "requires": [], "economy": true, "gather_kind": "food", "gather_multiplier": 1.15, "target_tags": [], "effects": {}},
	"double_broadaxe": {"label": "双刃斧", "age": 2, "building": "town_center", "cost": {"wood": 100, "gold": 75}, "time": 25.0, "requires": [], "economy": true, "gather_kind": "wood", "gather_multiplier": 1.15, "target_tags": [], "effects": {}},
	"specialized_pick": {"label": "专用镐", "age": 2, "building": "town_center", "cost": {"food": 100, "gold": 75}, "time": 25.0, "requires": [], "economy": true, "gather_kind": "gold", "gather_multiplier": 1.15, "target_tags": [], "effects": {}},
}

static func can_advance(age: int) -> bool:
	return AGE_ADVANCE_COSTS.has(age) and age < MAX_AGE

static func age_cost(age: int) -> Dictionary:
	var cost: Dictionary = AGE_ADVANCE_COSTS.get(age, {})
	return cost.duplicate(true)

static func age_time(age: int) -> float:
	return AGE_ADVANCE_TIMES.get(age, 0.0)

static func all_buildings(civilization: String) -> Array[String]:
	var result: Array[String] = []
	if not GameData.CIVILIZATIONS.has(civilization): return result
	result.assign(BUILD_MENU)
	return result

static func building_status(civilization: String, age: int, building_kind: String) -> Dictionary:
	if not GameData.CIVILIZATIONS.has(civilization): return _locked("未知文明")
	if not BUILD_MENU.has(building_kind) or not BUILDING_AGE.has(building_kind): return _locked("不可建造")
	if age < int(BUILDING_AGE[building_kind]): return _locked("需要时代 %s" % _age_name(BUILDING_AGE[building_kind]))
	return _available()

static func can_build(civilization: String, age: int, building_kind: String) -> bool:
	return building_status(civilization, age, building_kind)["available"]

static func buildable_buildings(civilization: String, age: int) -> Array[String]:
	var result: Array[String] = []
	for building_kind in all_buildings(civilization):
		if can_build(civilization, age, building_kind): result.append(building_kind)
	return result

static func all_train_units(civilization: String, building_kind: String) -> Array[String]:
	var result: Array[String] = []
	if not GameData.CIVILIZATIONS.has(civilization) or not PRODUCTION.has(building_kind): return result
	for base_kind in PRODUCTION[building_kind]:
		var unit_kind := RtsUnitCatalog.replacement_for(civilization, base_kind)
		if not result.has(unit_kind): result.append(unit_kind)
	var extras: Dictionary = RtsUnitCatalog.EXTRA_UNITS.get(civilization, {})
	for unit_kind in extras.get(building_kind, []):
		if not result.has(unit_kind): result.append(unit_kind)
	return result

static func unit_status(civilization: String, age: int, building_kind: String, unit_kind: String, researched: Array = [], dynasty := "") -> Dictionary:
	if not GameData.CIVILIZATIONS.has(civilization): return _locked("未知文明")
	if not BUILDING_AGE.has(building_kind) or not PRODUCTION.has(building_kind): return _locked("需要生产建筑")
	if not GameData.UNITS.has(unit_kind): return _locked("未知兵种")
	if not all_train_units(civilization, building_kind).has(unit_kind):
		var replacement := RtsUnitCatalog.replacement_for(civilization, unit_kind)
		if replacement != unit_kind: return _locked("由%s替代" % GameData.UNITS[replacement]["label"])
		if UNIT_CIVILIZATION.has(unit_kind): return _locked("仅限%s" % GameData.CIVILIZATIONS[UNIT_CIVILIZATION[unit_kind]]["label"])
		return _locked("需要对应的生产建筑")
	var required_age: int = int(UNIT_AGE.get(unit_kind, MAX_AGE + 1))
	var overrides: Dictionary = UNIT_AGE_OVERRIDES.get(civilization, {})
	required_age = int(overrides.get(unit_kind, required_age))
	required_age = maxi(required_age, int(BUILDING_AGE[building_kind]))
	if age < required_age: return _locked("需要时代 %s" % _age_name(required_age))
	if unit_kind == "zhuge_nu" and dynasty != "Song" and dynasty != "Yuan" and dynasty != "Ming": return _locked("需要宋朝王朝")
	if unit_kind == "fire_lancer" and dynasty != "Yuan" and dynasty != "Ming": return _locked("需要元朝王朝")
	if unit_kind == "grenadier" and dynasty != "Ming": return _locked("需要明朝王朝")
	for prerequisite in UNIT_REQUIRES.get(unit_kind, []):
		if not researched.has(prerequisite): return _locked("需要研究%s" % TECHNOLOGIES[prerequisite]["label"])
	return _available()

static func can_train(civilization: String, age: int, building_kind: String, unit_kind: String, researched: Array = [], dynasty := "") -> bool:
	return unit_status(civilization, age, building_kind, unit_kind, researched, dynasty)["available"]

static func trainable_units(civilization: String, age: int, building_kind: String, researched: Array = [], dynasty := "") -> Array[String]:
	var result: Array[String] = []
	for unit_kind in all_train_units(civilization, building_kind):
		if can_train(civilization, age, building_kind, unit_kind, researched, dynasty): result.append(unit_kind)
	return result

static func get_technology(tech_id: String) -> Dictionary:
	if TECHNOLOGIES.has(tech_id): return TECHNOLOGIES[tech_id].duplicate(true)
	if not tech_id.begins_with("rank_"): return {}
	var separator := tech_id.rfind("_")
	if separator <= 5: return {}
	var unit_kind := tech_id.substr(5, separator - 5)
	var age := int(tech_id.substr(separator + 1))
	if not GameData.UNITS.has(unit_kind) or age <= RtsBalanceData.first_rank_age(unit_kind): return {}
	var source: Dictionary = RtsBalanceData.line(unit_kind)
	if not source.get("upgrade_costs", {}).has(str(age)): return {}
	var source_cost: Dictionary = source["upgrade_costs"][str(age)].duplicate(true)
	var duration: float = float(source_cost.get("seconds", 45.0)) * float(RtsBalanceData.document().get("time_scale", 1.0))
	source_cost.erase("seconds")
	for resource in source_cost: source_cost[resource] = int(source_cost[resource])
	var producer := producer_for_unit(unit_kind)
	var prerequisites: Array[String] = []
	if source.get("upgrade_costs", {}).has(str(age - 1)) and age - 1 > RtsBalanceData.first_rank_age(unit_kind): prerequisites.append(RtsBalanceData.rank_tech_id(unit_kind, age - 1))
	return {"label": ("精锐" if age == 4 else "老练") + GameData.UNITS[unit_kind]["label"], "age": age, "building": producer, "cost": source_cost, "time": duration, "requires": prerequisites, "target_tags": [], "effects": {}, "rank_unit": unit_kind}

static func producer_for_unit(unit_kind: String) -> String:
	var base := unit_kind
	for civilization in RtsUnitCatalog.REPLACEMENTS:
		base = RtsUnitCatalog.base_unit_for(civilization, unit_kind)
		if base != unit_kind: break
	for building_kind in ["town_center", "barracks", "archery_range", "stable", "siege_workshop", "market", "dock", "monastery"]:
		if PRODUCTION.get(building_kind, []).has(base): return building_kind
	for civilization in RtsUnitCatalog.EXTRA_UNITS:
		for building_kind in RtsUnitCatalog.EXTRA_UNITS[civilization]:
			if RtsUnitCatalog.EXTRA_UNITS[civilization][building_kind].has(unit_kind): return building_kind
	return ""

static func all_researches(civilization: String, building_kind: String) -> Array[String]:
	var result: Array[String] = []
	if not GameData.CIVILIZATIONS.has(civilization): return result
	for tech_id in TECHNOLOGIES:
		if TECHNOLOGIES[tech_id]["building"] == building_kind and _technology_civilization_available(civilization, TECHNOLOGIES[tech_id]): result.append(tech_id)
	if civilization == "Chinese" and building_kind == "spirit_way":
		for unit_kind in ["zhuge_nu", "fire_lancer", "grenadier"]:
			for age_key in RtsBalanceData.line(unit_kind).get("upgrade_costs", {}):
				if int(age_key) > RtsBalanceData.first_rank_age(unit_kind): result.append(RtsBalanceData.rank_tech_id(unit_kind, int(age_key)))
	if civilization == "French" and building_kind == "royal_institute":
		for tech_id in TECHNOLOGIES:
			if _technology_civilization_available(civilization, TECHNOLOGIES[tech_id]) and not result.has(tech_id): result.append(tech_id)
		for producer_kind in ["barracks", "archery_range", "stable"]:
			for unit_kind in all_train_units(civilization, producer_kind):
				for age_key in RtsBalanceData.line(unit_kind).get("upgrade_costs", {}):
					if int(age_key) <= RtsBalanceData.first_rank_age(unit_kind): continue
					var tech_id := RtsBalanceData.rank_tech_id(unit_kind, int(age_key))
					if not result.has(tech_id): result.append(tech_id)
	for unit_kind in all_train_units(civilization, building_kind):
		for age_key in RtsBalanceData.line(unit_kind).get("upgrade_costs", {}):
			if int(age_key) <= RtsBalanceData.first_rank_age(unit_kind): continue
			var tech_id := RtsBalanceData.rank_tech_id(unit_kind, int(age_key))
			if not result.has(tech_id): result.append(tech_id)
	return result

static func research_status(civilization: String, age: int, building_kind: String, tech_id: String, researched: Array = []) -> Dictionary:
	if not GameData.CIVILIZATIONS.has(civilization): return _locked("未知文明")
	var definition: Dictionary = get_technology(tech_id)
	if definition.is_empty(): return _locked("未知科技")
	if not _technology_civilization_available(civilization, definition): return _locked("该文明自动获得此科技")
	var royal_override := civilization == "French" and building_kind == "royal_institute" and all_researches(civilization, building_kind).has(tech_id)
	var spirit_override := civilization == "Chinese" and building_kind == "spirit_way" and definition.has("rank_unit") and all_researches(civilization, building_kind).has(tech_id)
	if definition.has("rank_unit") and not all_train_units(civilization, building_kind).has(definition["rank_unit"]) and not royal_override and not spirit_override: return _locked("该文明没有此兵种")
	var rank_producer := definition.has("rank_unit") and all_train_units(civilization, building_kind).has(definition["rank_unit"])
	if definition["building"] != building_kind and not royal_override and not spirit_override and not rank_producer: return _locked("需要%s" % GameData.BUILDINGS.get(definition["building"], {"label": "对应生产建筑"})["label"])
	if researched.has(tech_id): return _locked("已研究")
	if age < int(definition["age"]): return _locked("需要时代 %s" % _age_name(definition["age"]))
	for prerequisite in definition["requires"]:
		if not researched.has(prerequisite): return _locked("需要研究%s" % get_technology(prerequisite)["label"])
	return _available()

static func can_research(civilization: String, age: int, building_kind: String, tech_id: String, researched: Array = []) -> bool:
	return research_status(civilization, age, building_kind, tech_id, researched)["available"]

static func _available() -> Dictionary:
	return {"available": true, "reason": ""}

static func _technology_civilization_available(civilization: String, definition: Dictionary) -> bool:
	return not definition.has("civilizations") or definition["civilizations"].has(civilization)

static func _locked(reason: String) -> Dictionary:
	return {"available": false, "reason": reason}

static func _age_name(age: int) -> String:
	return ["", "I", "II", "III", "IV"][clampi(age, 1, MAX_AGE)]

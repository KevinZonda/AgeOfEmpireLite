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

const BUILD_MENU := ["house", "farm", "barracks", "archery_range", "stable", "outpost", "palisade_wall", "stone_wall", "keep", "siege_workshop", "wonder"]
const BUILDING_AGE := {
	"town_center": 1,
	"house": 1,
	"farm": 1,
	"barracks": 2,
	"archery_range": 2,
	"stable": 2,
	"outpost": 2,
	"palisade_wall": 2,
	"stone_wall": 3,
	"keep": 3,
	"siege_workshop": 3,
	"wonder": 4,
}

# Base roster; civilization substitutions are declared in RtsUnitCatalog.
const PRODUCTION := {
	"town_center": ["villager"],
	"barracks": ["spearman", "man_at_arms"],
	"archery_range": ["archer", "crossbowman"],
	"stable": ["scout", "horseman", "knight"],
	"siege_workshop": ["battering_ram", "trebuchet"],
}
const UNIT_AGE := {
	"villager": 1,
	"scout": 2,
	"spearman": 2,
	"man_at_arms": 3,
	"palace_guard": 3,
	"archer": 2,
	"zhuge_nu": 2,
	"longbow": 2,
	"crossbowman": 3,
	"arbaletrier": 3,
	"horseman": 2,
	"knight": 3,
	"royal_knight": 2,
	"battering_ram": 3,
	"trebuchet": 3,
}
const UNIT_AGE_OVERRIDES := {
	"English": {"man_at_arms": 2},
}
const UNIT_CIVILIZATION := {
	"longbow": "English",
	"arbaletrier": "French",
	"royal_knight": "French",
	"zhuge_nu": "Chinese",
	"palace_guard": "Chinese",
}
const UNIT_REQUIRES := {} # Unit-specific research prerequisites can be added here.

# Effects add to effective unit definitions; existing units can be refreshed using
# RtsUnitCatalog.unit_definition(civilization, unit_kind, researched).
const TECHNOLOGIES := {
	"forged_weapons": {"label": "锻造武器", "age": 2, "building": "barracks", "cost": {"food": 100, "gold": 75}, "time": 15.0, "requires": [], "target_tags": ["infantry"], "effects": {"damage": 2.0}},
	"iron_armor": {"label": "铁甲", "age": 3, "building": "town_center", "cost": {"food": 150, "gold": 125}, "time": 20.0, "requires": [], "target_tags": ["military"], "effects": {"armor_melee": 1.0, "armor_ranged": 1.0}},
	"veteran_training": {"label": "老兵训练", "age": 3, "building": "barracks", "cost": {"food": 180, "gold": 120}, "time": 22.0, "requires": ["forged_weapons"], "target_tags": ["infantry"], "effects": {"hp": 20.0}},
	"elite_training": {"label": "精锐训练", "age": 4, "building": "town_center", "cost": {"food": 280, "gold": 220}, "time": 30.0, "requires": ["iron_armor", "veteran_training"], "target_tags": ["military"], "effects": {"damage": 3.0, "hp": 20.0}},
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
	return result

static func unit_status(civilization: String, age: int, building_kind: String, unit_kind: String, researched: Array = []) -> Dictionary:
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
	for prerequisite in UNIT_REQUIRES.get(unit_kind, []):
		if not researched.has(prerequisite): return _locked("需要研究%s" % TECHNOLOGIES[prerequisite]["label"])
	return _available()

static func can_train(civilization: String, age: int, building_kind: String, unit_kind: String, researched: Array = []) -> bool:
	return unit_status(civilization, age, building_kind, unit_kind, researched)["available"]

static func trainable_units(civilization: String, age: int, building_kind: String, researched: Array = []) -> Array[String]:
	var result: Array[String] = []
	for unit_kind in all_train_units(civilization, building_kind):
		if can_train(civilization, age, building_kind, unit_kind, researched): result.append(unit_kind)
	return result

static func all_researches(civilization: String, building_kind: String) -> Array[String]:
	var result: Array[String] = []
	if not GameData.CIVILIZATIONS.has(civilization): return result
	for tech_id in TECHNOLOGIES:
		if TECHNOLOGIES[tech_id]["building"] == building_kind: result.append(tech_id)
	return result

static func research_status(civilization: String, age: int, building_kind: String, tech_id: String, researched: Array = []) -> Dictionary:
	if not GameData.CIVILIZATIONS.has(civilization): return _locked("未知文明")
	if not TECHNOLOGIES.has(tech_id): return _locked("未知科技")
	var technology: Dictionary = TECHNOLOGIES[tech_id]
	if technology["building"] != building_kind: return _locked("需要%s" % GameData.BUILDINGS[technology["building"]]["label"])
	if researched.has(tech_id): return _locked("已研究")
	if age < int(technology["age"]): return _locked("需要时代 %s" % _age_name(technology["age"]))
	for prerequisite in technology["requires"]:
		if not researched.has(prerequisite): return _locked("需要研究%s" % TECHNOLOGIES[prerequisite]["label"])
	return _available()

static func can_research(civilization: String, age: int, building_kind: String, tech_id: String, researched: Array = []) -> bool:
	return research_status(civilization, age, building_kind, tech_id, researched)["available"]

static func _available() -> Dictionary:
	return {"available": true, "reason": ""}

static func _locked(reason: String) -> Dictionary:
	return {"available": false, "reason": reason}

static func _age_name(age: int) -> String:
	return ["", "I", "II", "III", "IV"][clampi(age, 1, MAX_AGE)]

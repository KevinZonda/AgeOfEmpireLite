class_name RtsTechTree
extends RefCounted

# Progression rules live here. GameData contains unit/building balance and labels.
const MAX_AGE := 4
const AGE_ADVANCE_COSTS := {
	1: {"food": 220, "gold": 100},
	2: {"food": 400, "gold": 200},
	3: {"food": 650, "gold": 350},
}

const BUILD_MENU := ["house", "farm", "barracks", "archery_range", "stable"]
const BUILDING_AGE := {
	"town_center": 1,
	"house": 1,
	"farm": 1,
	"barracks": 2,
	"archery_range": 2,
	"stable": 2,
}

# A unit becomes trainable only when its producer, age, and civilization match.
const PRODUCTION := {
	"town_center": ["villager"],
	"barracks": ["spearman"],
	"archery_range": ["archer", "longbow"],
	"stable": ["horseman", "knight"],
}
const UNIT_AGE := {
	"villager": 1,
	"spearman": 2,
	"archer": 2,
	"longbow": 2,
	"horseman": 2,
	"knight": 2,
}
const UNIT_CIVILIZATION := {
	"longbow": "English",
	"knight": "French",
}

static func can_advance(age: int) -> bool:
	return AGE_ADVANCE_COSTS.has(age) and age < MAX_AGE

static func age_cost(age: int) -> Dictionary:
	var cost: Dictionary = AGE_ADVANCE_COSTS.get(age, {})
	return cost.duplicate(true)

static func can_build(civilization: String, age: int, building_kind: String) -> bool:
	if not GameData.CIVILIZATIONS.has(civilization): return false
	return BUILD_MENU.has(building_kind) and BUILDING_AGE.has(building_kind) and age >= BUILDING_AGE[building_kind]

static func buildable_buildings(civilization: String, age: int) -> Array[String]:
	var result: Array[String] = []
	for building_kind in BUILD_MENU:
		if can_build(civilization, age, building_kind): result.append(building_kind)
	return result

static func can_train(civilization: String, age: int, building_kind: String, unit_kind: String) -> bool:
	if not GameData.CIVILIZATIONS.has(civilization): return false
	if not BUILDING_AGE.has(building_kind) or age < BUILDING_AGE[building_kind]: return false
	if not PRODUCTION.has(building_kind) or not PRODUCTION[building_kind].has(unit_kind): return false
	if not UNIT_AGE.has(unit_kind) or age < UNIT_AGE[unit_kind]: return false
	return not UNIT_CIVILIZATION.has(unit_kind) or UNIT_CIVILIZATION[unit_kind] == civilization

static func trainable_units(civilization: String, age: int, building_kind: String) -> Array[String]:
	var result: Array[String] = []
	if not PRODUCTION.has(building_kind): return result
	for unit_kind in PRODUCTION[building_kind]:
		if can_train(civilization, age, building_kind, unit_kind): result.append(unit_kind)
	return result

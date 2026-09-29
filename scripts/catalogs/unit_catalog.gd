class_name RtsUnitCatalog
extends RefCounted

# Civilization identity is expressed as substitutions and small stat changes.
# The shared unit definitions and combat rules remain in GameData.
const REPLACEMENTS := {
	"English": {"archer": "longbow"},
	"French": {"crossbowman": "arbaletrier", "knight": "royal_knight", "bombard": "cannon"},
	"Chinese": {"man_at_arms": "palace_guard", "mangonel": "nest_of_bees"},
}

const EXTRA_UNITS := {
	"Chinese": {"archery_range": ["zhuge_nu", "grenadier"], "stable": ["fire_lancer"]},
}

const CIVILIZATION_BONUSES := {
	"English": {"man_at_arms": {"hp": 10.0}},
	"French": {"horseman": {"speed": 5.0}},
}

static func replacement_for(civilization: String, unit_kind: String) -> String:
	var replacements: Dictionary = REPLACEMENTS.get(civilization, {})
	return str(replacements.get(unit_kind, unit_kind))

static func base_unit_for(civilization: String, unit_kind: String) -> String:
	var replacements: Dictionary = REPLACEMENTS.get(civilization, {})
	for base_kind in replacements:
		if replacements[base_kind] == unit_kind: return str(base_kind)
	return unit_kind

static func unit_definition(civilization: String, unit_kind: String, researched: Array = [], age := 2, landmarks: Array = [], dynasty := "", producer_landmark_id := "") -> Dictionary:
	return RtsStatResolver.unit(civilization, unit_kind, age, researched, landmarks, dynasty, producer_landmark_id)

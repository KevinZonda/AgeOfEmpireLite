class_name RtsUnitCatalog
extends RefCounted

# Civilization identity is expressed as substitutions and small stat changes.
# The shared unit definitions and combat rules remain in GameData.
const REPLACEMENTS := {
	"English": {"archer": "longbow"},
	"French": {"crossbowman": "arbaletrier", "knight": "royal_knight"},
	"Chinese": {"archer": "zhuge_nu", "man_at_arms": "palace_guard"},
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

static func unit_definition(civilization: String, unit_kind: String, researched: Array = []) -> Dictionary:
	if not GameData.UNITS.has(unit_kind): return {}
	var definition: Dictionary = GameData.UNITS[unit_kind].duplicate(true)
	var bonuses: Dictionary = CIVILIZATION_BONUSES.get(civilization, {})
	var unit_bonus: Dictionary = bonuses.get(unit_kind, {})
	for stat in unit_bonus:
		definition[stat] = float(definition.get(stat, 0.0)) + float(unit_bonus[stat])
	for tech_id in researched:
		if not RtsTechTree.TECHNOLOGIES.has(tech_id): continue
		var technology: Dictionary = RtsTechTree.TECHNOLOGIES[tech_id]
		if not _matches_tags(definition.get("tags", []), technology.get("target_tags", [])): continue
		_apply_effects(definition, technology.get("effects", {}))
	return definition

static func building_definition(building_kind: String) -> Dictionary:
	if not GameData.BUILDINGS.has(building_kind): return {}
	return GameData.BUILDINGS[building_kind].duplicate(true)

static func _matches_tags(tags: Array, required_tags: Array) -> bool:
	if required_tags.is_empty(): return true
	for tag in required_tags:
		if tags.has(tag): return true
	return false

static func _apply_effects(definition: Dictionary, effects: Dictionary) -> void:
	for stat in effects:
		if stat == "armor_melee" or stat == "armor_ranged":
			var armor: Dictionary = definition["armor"]
			var armor_kind := "melee" if stat == "armor_melee" else "ranged"
			armor[armor_kind] = float(armor.get(armor_kind, 0.0)) + float(effects[stat])
		else:
			definition[stat] = float(definition.get(stat, 0.0)) + float(effects[stat])

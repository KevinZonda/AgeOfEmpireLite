class_name RtsSiegeRules
extends RefCounted

# Fortification and siege behavior is derived from GameData so simulation,
# action availability, and combat calculations use the same definitions.
static func garrison_capacity(building_kind: String) -> int:
	var definition: Dictionary = GameData.BUILDINGS.get(building_kind, {})
	return int(definition.get("garrison_capacity", 0))

static func can_garrison(unit_definition: Dictionary, building_kind: String) -> bool:
	if garrison_capacity(building_kind) <= 0: return false
	var tags: Array = unit_definition.get("tags", [])
	return tags.has("worker") or (tags.has("military") and not tags.has("siege"))

static func defense_stats(building_kind: String, garrison_count: int = 0) -> Dictionary:
	var definition: Dictionary = GameData.BUILDINGS.get(building_kind, {})
	var defense: Dictionary = definition.get("defense", {})
	if defense.is_empty(): return {}
	var count: int = clampi(garrison_count, 0, garrison_capacity(building_kind))
	return {
		"damage": float(defense.get("damage", 0.0)) + count * float(defense.get("garrison_bonus", 0.0)),
		"range": float(defense.get("range", 0.0)),
		"cooldown": float(defense.get("cooldown", 1.0)),
		"projectile_speed": float(defense.get("projectile_speed", 400.0)),
		"attack_type": "ranged",
		"bonus": {},
		"tags": ["building", "structure", "fortification"],
	}

static func defense_range(building_kind: String) -> float:
	return float(defense_stats(building_kind).get("range", 0.0))

static func defense_cooldown(building_kind: String) -> float:
	return float(defense_stats(building_kind).get("cooldown", 0.0))

static func defense_projectile_speed(building_kind: String) -> float:
	return float(defense_stats(building_kind).get("projectile_speed", 0.0))

static func can_attack_target(attacker_definition: Dictionary, _defender_definition: Dictionary, distance: float) -> bool:
	return distance >= float(attacker_definition.get("min_range", 0.0)) and distance <= float(attacker_definition.get("range", 0.0))

static func is_wall(building_kind: String) -> bool:
	var definition: Dictionary = GameData.BUILDINGS.get(building_kind, {})
	return definition.get("tags", []).has("wall")

static func is_siege(unit_kind: String) -> bool:
	var definition: Dictionary = GameData.UNITS.get(unit_kind, {})
	return definition.get("tags", []).has("siege")

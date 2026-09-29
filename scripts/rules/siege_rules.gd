class_name RtsSiegeRules
extends RefCounted

# Season Nine changed siege protection from flat ranged armor to percentage
# resistance, and changed the Springald's target role. Keep these overrides
# separate from the archived unit sheets, which describe an older patch.
const RANGED_RESISTANCE := {
	"battering_ram": 0.95, "siege_tower": 0.95,
	"bombard": 0.85, "cannon": 0.85, "trebuchet": 0.80,
	"mangonel": 0.85, "nest_of_bees": 0.85, "springald": 0.60,
}

static func apply_current_balance(stats: Dictionary) -> void:
	var kind: String = stats.get("kind", "")
	if not RANGED_RESISTANCE.has(kind): return
	stats["armor"]["ranged"] = 0.0
	var resistance: Dictionary = stats.get("resistance", {})
	resistance["ranged"] = RANGED_RESISTANCE[kind]
	stats["resistance"] = resistance
	if kind == "springald":
		for profile_id in stats.get("profiles", {}):
			var profile: Dictionary = stats["profiles"][profile_id]
			if float(profile.get("damage", 0.0)) <= 0.0: continue
			profile["damage"] = 14.0
			profile["bonuses"] = [{"required_tags": ["infantry", "melee_unit"], "amount": 20.0, "source_label": "近战步兵"}]
			profile["pierce_width"] = 18.0
			profile["pierce_length"] = 70.0

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

static func can_attack_target(attacker_definition: Dictionary, _defender_definition: Dictionary, distance: float) -> bool:
	return distance >= float(attacker_definition.get("min_range", 0.0)) and distance <= float(attacker_definition.get("range", 0.0))

static func is_wall(building_kind: String) -> bool:
	var definition: Dictionary = GameData.BUILDINGS.get(building_kind, {})
	return definition.get("tags", []).has("wall")

static func is_siege(unit_kind: String) -> bool:
	var definition: Dictionary = GameData.UNITS.get(unit_kind, {})
	return definition.get("tags", []).has("siege")

static func wall_entry(game: Node2D, unit: RtsUnit, wall: RtsBuilding) -> Node2D:
	if wall.kind != "stone_wall" or not wall.is_complete() or not unit.stats.get("tags", []).has("military") or unit.stats.get("tags", []).has("siege"): return null
	if is_instance_valid(unit.wall_host) and unit.wall_host.owner_id == wall.owner_id and walls_connected(unit.wall_host, wall): return unit.wall_host
	if wall.owner_id == unit.owner_id:
		for building in game.buildings:
			if is_instance_valid(building) and building.owner_id == unit.owner_id and building.kind == "stone_gate" and building.is_complete() and walls_connected(building, wall): return building
	else:
		for siege in game.units:
			if is_instance_valid(siege) and siege.owner_id == unit.owner_id and siege.kind == "siege_tower" and siege.order == "siege_tower_docked" and siege.position.distance_to(wall.position) <= 95.0: return siege
	return null

static func walls_connected(a: RtsBuilding, b: RtsBuilding) -> bool:
	if not is_instance_valid(a) or not is_instance_valid(b) or not a.is_complete() or not b.is_complete() or a.owner_id != b.owner_id: return false
	if a.kind not in ["stone_wall", "stone_gate"] or b.kind not in ["stone_wall", "stone_gate"]: return false
	return a.position.distance_to(b.position) <= 82.0

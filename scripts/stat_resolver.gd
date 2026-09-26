class_name RtsStatResolver
extends RefCounted

# One resolution path for simulation and UI. The reference rank is applied
# before game-specific civilization, research, landmark and dynasty effects.
static func unit(civilization: String, unit_kind: String, age: int, researched: Array = [], landmarks: Array = [], dynasty := "", producer_landmark_id := "") -> Dictionary:
	if not GameData.UNITS.has(unit_kind): return {}
	var stats: Dictionary = GameData.UNITS[unit_kind].duplicate(true)
	stats["kind"] = unit_kind
	var source := RtsBalanceData.line(unit_kind)
	stats["cost"] = RtsBalanceData.unit_cost(unit_kind)
	stats["population_cost"] = RtsBalanceData.population_cost(unit_kind)
	stats["time"] = RtsBalanceData.training_seconds(unit_kind)
	stats["source_url"] = source.get("source_url", "")
	stats["target_tags"] = target_tags(unit_kind, stats)
	stats["profiles"] = {}
	var rank := RtsBalanceData.rank(unit_kind, age, researched)
	stats["rank_age"] = RtsBalanceData.available_rank_age(unit_kind, age, researched)
	if not rank.is_empty():
		stats["hp"] = float(rank.get("hp", stats["hp"]))
		var armor: Dictionary = stats["armor"].duplicate(true)
		armor["melee"] = float(rank.get("melee_armor", armor.get("melee", 0.0)))
		armor["ranged"] = float(rank.get("ranged_armor", armor.get("ranged", 0.0)))
		armor["fire"] = float(rank.get("fire_armor", 0.0))
		stats["resistance"] = {}
		if armor["ranged"] >= 50.0:
			stats["resistance"]["ranged"] = armor["ranged"] / 100.0
			armor["ranged"] = 0.0
		stats["armor"] = armor
		if source.get("move_tiles_per_second") != null:
			stats["speed"] = float(source["move_tiles_per_second"]) * float(RtsBalanceData.document().get("speed_pixels_per_tile_per_second", 80.0))
		for profile_id in rank.get("attacks", {}):
			stats["profiles"][profile_id] = RtsBalanceData.scaled_profile(rank["attacks"][profile_id])
	if stats["profiles"].is_empty() and float(stats.get("damage", 0.0)) > 0.0:
		var fallback_bonuses: Array[Dictionary] = []
		for target_tag in stats.get("bonus", {}):
			fallback_bonuses.append({"required_tags": [target_tag], "amount": float(stats["bonus"][target_tag]), "source_label": target_tag})
		stats["profiles"]["ranged" if stats.get("attack_type") == "ranged" else "melee"] = {
			"damage": float(stats["damage"]), "damage_kind": stats.get("attack_type", "melee"),
			"range": float(stats["range"]), "cooldown": float(stats["cooldown"]), "hits": 1, "bonuses": fallback_bonuses,
		}
	if stats["tags"].has("siege"): RtsSiegeRules.apply_current_balance(stats)
	var primary := primary_profile(stats)
	stats["primary_profile"] = primary
	_apply_legacy_primary(stats)
	var civ_effects: Dictionary = RtsUnitCatalog.CIVILIZATION_BONUSES.get(civilization, {}).get(unit_kind, {})
	_apply_effects(stats, civ_effects)
	for tech_id in researched:
		var technology: Dictionary = RtsTechTree.get_technology(tech_id)
		if technology.is_empty() or not _matches_tags(stats["tags"], technology.get("target_tags", [])): continue
		var excluded := false
		for tag in technology.get("exclude_tags", []):
			if stats["tags"].has(tag): excluded = true
		if excluded: continue
		_apply_effects(stats, technology.get("effects", {}))
	_apply_effects(stats, RtsLandmarkCatalog.unit_bonus(civilization, landmarks, unit_kind, stats["tags"]))
	_apply_effects(stats, RtsLandmarkCatalog.dynasty_unit_bonus(civilization, dynasty, stats["tags"]))
	if stats["tags"].has("siege"):
		stats["hp"] = float(stats["hp"]) * RtsLandmarkCatalog.produced_siege_hp(producer_landmark_id)
		var damage_multiplier := RtsLandmarkCatalog.produced_siege_damage(producer_landmark_id)
		for profile_id in stats.get("profiles", {}): stats["profiles"][profile_id]["damage"] = float(stats["profiles"][profile_id]["damage"]) * damage_multiplier
	_apply_legacy_primary(stats)
	return stats

static func target_tags(unit_kind: String, definition: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var tags: Array = definition.get("tags", [])
	for tag in tags:
		if not result.has(tag): result.append(tag)
	if tags.has("siege"):
		result.append("siege_engine")
	elif tags.has("naval"):
		result.append("ship")
	elif tags.has("infantry"):
		result.append("light_unit" if tags.has("light") else "heavy_unit")
		result.append("ranged_unit" if tags.has("ranged") else "melee_unit")
	elif tags.has("cavalry"):
		result.append("light_unit" if tags.has("light") else "heavy_unit")
		result.append("ranged_unit" if tags.has("ranged") else "melee_unit")
	if unit_kind == "arbaletrier": result.append("shielded_ranged")
	if unit_kind == "spearman": result.append("spear")
	return result

static func primary_profile(stats: Dictionary) -> String:
	var profiles: Dictionary = stats.get("profiles", {})
	if stats.get("tags", []).has("scout") and profiles.has("melee"): return "melee"
	for key in ["ranged", "melee", "siege", "charge"]:
		if profiles.has(key): return key
	return ""

static func attack_profile(stats: Dictionary, defender: Dictionary, charging := false) -> Dictionary:
	var profiles: Dictionary = stats.get("profiles", {})
	var target_tags: Array = defender.get("target_tags", defender.get("tags", []))
	if target_tags.has("structure") or target_tags.has("building"):
		for key in ["structure", "torch", "siege"]:
			if profiles.has(key): return profiles[key]
	if charging and profiles.has("charge"): return profiles["charge"]
	var primary: String = stats.get("primary_profile", "")
	return profiles.get(primary, {})

static func _apply_legacy_primary(stats: Dictionary) -> void:
	var primary: Dictionary = stats.get("profiles", {}).get(stats.get("primary_profile", ""), {})
	if primary.is_empty(): return
	stats["damage"] = float(primary.get("damage", 0.0))
	stats["range"] = float(primary.get("range", 20.0))
	stats["cooldown"] = float(primary.get("cooldown", 1.0))
	stats["attack_type"] = "ranged" if primary.get("damage_kind") == "ranged" or stats["primary_profile"] == "siege" and float(primary.get("range", 0.0)) > 70.0 else "melee"

static func _matches_tags(tags: Array, required: Array) -> bool:
	if required.is_empty(): return true
	for tag in required:
		if tags.has(tag): return true
	return false

static func _apply_effects(stats: Dictionary, effects: Dictionary) -> void:
	for key in effects:
		var value := float(effects[key])
		if str(key).begins_with("armor_"):
			var armor_key := str(key).trim_prefix("armor_")
			stats["armor"][armor_key] = float(stats["armor"].get(armor_key, 0.0)) + value
		elif key == "damage":
			var primary: String = stats.get("primary_profile", "")
			if stats.get("profiles", {}).has(primary):
				stats["profiles"][primary]["damage"] = float(stats["profiles"][primary]["damage"]) + value
			else:
				stats["damage"] = float(stats.get("damage", 0.0)) + value
		elif str(key).begins_with("damage_"):
			var damage_kind: String = str(key).trim_prefix("damage_")
			for profile_id in stats.get("profiles", {}):
				if stats["profiles"][profile_id].get("damage_kind", "") == damage_kind:
					stats["profiles"][profile_id]["damage"] = float(stats["profiles"][profile_id].get("damage", 0.0)) + value
		else:
			stats[key] = float(stats.get(key, 0.0)) + value

class_name RtsBalanceData
extends RefCounted

# The checked-in JSON is generated from docs/aoe4-units. The conversions are
# explicit because the source's tile distances and this game's pixels differ.
const DATA_PATH := "res://data/aoe4_balance.json"
static var _document: Dictionary = {}

static func document() -> Dictionary:
	if _document.is_empty():
		var file := FileAccess.open(DATA_PATH, FileAccess.READ)
		if file == null:
			push_error("Missing balance reference: %s" % DATA_PATH)
			return {}
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary: _document = parsed
	return _document

static func line(unit_kind: String) -> Dictionary:
	return document().get("units", {}).get(unit_kind, {})

static func unit_cost(unit_kind: String) -> Dictionary:
	var source := line(unit_kind)
	if source.is_empty(): return GameData.UNITS.get(unit_kind, {}).get("cost", {}).duplicate(true)
	var cost := {}
	for resource in source.get("cost", {}): cost[resource] = int(source["cost"][resource])
	return cost

static func population_cost(unit_kind: String) -> int:
	return maxi(1, int(line(unit_kind).get("population_cost", 1)))

static func training_seconds(unit_kind: String) -> float:
	var source := line(unit_kind)
	if source.is_empty() or source.get("train_seconds") == null:
		return float(GameData.UNITS.get(unit_kind, {}).get("time", 1.0))
	return maxf(1.0, float(source["train_seconds"]) * float(document().get("time_scale", 1.0)))

static func available_rank_age(unit_kind: String, current_age: int, researched: Array = []) -> int:
	var ranks: Dictionary = line(unit_kind).get("ranks", {})
	var first := 0
	var available := 0
	for age in range(1, 5):
		if not ranks.has(str(age)): continue
		if first == 0: first = age
		if age > current_age: break
		if age > first and line(unit_kind).get("upgrade_costs", {}).has(str(age)) and not researched.has(rank_tech_id(unit_kind, age)):
			break
		available = age
	return available

static func rank_tech_id(unit_kind: String, age: int) -> String:
	return "rank_%s_%d" % [unit_kind, age]

static func first_rank_age(unit_kind: String) -> int:
	for age in range(1, 5):
		if line(unit_kind).get("ranks", {}).has(str(age)): return age
	return 0

static func rank(unit_kind: String, current_age: int, researched: Array = []) -> Dictionary:
	var age := available_rank_age(unit_kind, current_age, researched)
	if age <= 0: return {}
	return line(unit_kind).get("ranks", {}).get(str(age), {}).duplicate(true)

static func attack_bonus(label: String, amount: float) -> Dictionary:
	var required: Array[String] = []
	if "墙" in label:
		required.append("wall")
	elif "攻城器" in label:
		required.append("siege_engine")
	elif "船" in label:
		required.append("ship")
	elif "建筑" in label:
		required.append("structure")
	elif "骑兵" in label:
		required.append("cavalry")
	elif "重型" in label:
		required.append("heavy_unit")
	elif "轻型" in label:
		required.append("light_unit")
	if "步兵" in label: required.append("infantry")
	if "侦察兵" in label: required.append("scout")
	if "远程" in label: required.append("ranged_unit")
	if "近战" in label: required.append("melee_unit")
	if "火药" in label: required.append("gunpowder")
	if required.is_empty(): return {}
	return {"required_tags": required, "amount": amount, "source_label": label}

static func scaled_profile(source: Dictionary) -> Dictionary:
	var bonuses: Array[Dictionary] = []
	for label in source.get("bonuses", {}):
		var bonus := attack_bonus(str(label), float(source["bonuses"][label]))
		if not bonus.is_empty(): bonuses.append(bonus)
	return {
		"damage": float(source.get("damage", 0.0)),
		"damage_kind": str(source.get("damage_kind", "melee")),
		"range": maxf(20.0, float(source.get("range_tiles", 0.0) if source.get("range_tiles") != null else 0.0) * float(document().get("distance_pixels_per_tile", 30.0))),
		"min_range": float(source.get("min_range_tiles", 0.0) if source.get("min_range_tiles") != null else 0.0) * float(document().get("distance_pixels_per_tile", 30.0)),
		"splash_radius": float(source.get("splash_tiles", 0.0) if source.get("splash_tiles") != null else 0.0) * float(document().get("distance_pixels_per_tile", 30.0)),
		"cooldown": maxf(0.2, float(source.get("interval", 1.0) if source.get("interval") != null else 1.0)),
		"hits": maxi(1, int(source.get("hits", 1))),
		"bonuses": bonuses,
	}

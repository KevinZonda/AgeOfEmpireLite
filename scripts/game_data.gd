class_name GameData
extends RefCounted

# All balance values live here. The simulation and UI consume the same definitions.
const RESOURCE_NAMES := ["food", "wood", "gold", "stone"]
const RESOURCE_LABELS := {"food": "食物", "wood": "木材", "gold": "黄金", "stone": "石料"}

const CIVILIZATIONS := {
	"English": {"label": "英格兰", "color": Color("3976b8"), "description": "农田 +25% 产出，长弓兵"},
	"French": {"label": "法兰西", "color": Color("b94b4b"), "description": "骑士冲锋伤害，骑兵训练更快"},
}

const UNITS := {
	"villager": {"label": "村民", "hp": 45.0, "speed": 100.0, "damage": 3.0, "range": 20.0, "cooldown": 1.0, "radius": 10.0, "cost": {"food": 50}, "time": 5.0, "age": 1},
	"spearman": {"label": "长矛兵", "hp": 90.0, "speed": 88.0, "damage": 12.0, "range": 23.0, "cooldown": 1.15, "radius": 12.0, "cost": {"food": 60, "wood": 20}, "time": 7.0, "age": 2},
	"archer": {"label": "弓箭手", "hp": 65.0, "speed": 93.0, "damage": 9.0, "range": 135.0, "cooldown": 1.25, "radius": 11.0, "cost": {"wood": 60, "food": 30}, "time": 8.0, "age": 2},
	"longbow": {"label": "长弓兵", "hp": 70.0, "speed": 90.0, "damage": 11.0, "range": 175.0, "cooldown": 1.35, "radius": 11.0, "cost": {"wood": 65, "food": 35}, "time": 8.0, "age": 2, "civ": "English"},
	"horseman": {"label": "骑兵", "hp": 145.0, "speed": 145.0, "damage": 16.0, "range": 28.0, "cooldown": 1.2, "radius": 14.0, "cost": {"food": 90, "wood": 30}, "time": 10.0, "age": 2},
	"knight": {"label": "骑士", "hp": 185.0, "speed": 136.0, "damage": 22.0, "range": 28.0, "cooldown": 1.25, "radius": 15.0, "cost": {"food": 110, "gold": 75}, "time": 12.0, "age": 2, "civ": "French"},
}

const BUILDINGS := {
	"town_center": {"label": "城镇中心", "hp": 1050.0, "size": Vector2(90, 90), "cost": {}, "time": 0.0, "age": 1, "pop": 10, "trains": ["villager"]},
	"house": {"label": "房屋", "hp": 260.0, "size": Vector2(55, 50), "cost": {"wood": 80}, "time": 6.0, "age": 1, "pop": 10, "trains": []},
	"farm": {"label": "农田", "hp": 170.0, "size": Vector2(55, 55), "cost": {"wood": 60}, "time": 5.0, "age": 1, "pop": 0, "trains": []},
	"barracks": {"label": "兵营", "hp": 490.0, "size": Vector2(70, 65), "cost": {"wood": 160}, "time": 10.0, "age": 2, "pop": 0, "trains": ["spearman"]},
	"archery_range": {"label": "靶场", "hp": 430.0, "size": Vector2(70, 65), "cost": {"wood": 160}, "time": 10.0, "age": 2, "pop": 0, "trains": ["archer", "longbow"]},
	"stable": {"label": "马厩", "hp": 460.0, "size": Vector2(70, 65), "cost": {"wood": 180}, "time": 11.0, "age": 2, "pop": 0, "trains": ["horseman", "knight"]},
}

static func can_use_unit(civ: String, unit_kind: String) -> bool:
	return not UNITS[unit_kind].has("civ") or UNITS[unit_kind]["civ"] == civ

static func gathered_amount(civ: String, resource_kind: String, from_farm: bool) -> int:
	var amount := 9 if resource_kind == "food" else 7
	if civ == "English" and from_farm: amount = 12
	return amount

static func training_time(civ: String, building_kind: String, unit_kind: String) -> float:
	var duration: float = UNITS[unit_kind]["time"]
	if civ == "French" and building_kind == "stable": duration *= 0.85
	return duration

static func first_strike_bonus(civ: String, unit_kind: String, charging: bool) -> float:
	if civ == "French" and unit_kind == "knight" and charging: return 16.0
	return 0.0

static func cost_text(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for resource in RESOURCE_NAMES:
		if cost.has(resource):
			parts.append("%s%d" % [RESOURCE_LABELS[resource], cost[resource]])
	return " ".join(parts)

static func age_cost(age: int) -> Dictionary:
	match age:
		1: return {"food": 220, "gold": 100}
		2: return {"food": 400, "gold": 200}
		3: return {"food": 650, "gold": 350}
	return {}

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
	"villager": {"label": "村民", "hp": 45.0, "speed": 100.0, "damage": 3.0, "range": 20.0, "cooldown": 1.0, "radius": 10.0, "cost": {"food": 50}, "time": 5.0, "tags": ["worker", "light"], "armor": {"melee": 0.0, "ranged": 0.0}, "attack_type": "melee", "bonus": {}},
	"scout": {"label": "侦察兵", "hp": 105.0, "speed": 164.0, "damage": 6.0, "range": 23.0, "cooldown": 1.1, "radius": 12.0, "cost": {"food": 70}, "time": 8.0, "tags": ["military", "cavalry", "light", "scout"], "armor": {"melee": 0.0, "ranged": 1.0}, "attack_type": "melee", "bonus": {}},
	"spearman": {"label": "长矛兵", "hp": 90.0, "speed": 88.0, "damage": 12.0, "range": 23.0, "cooldown": 1.15, "radius": 12.0, "cost": {"food": 60, "wood": 20}, "time": 7.0, "tags": ["military", "infantry", "light", "anti_cavalry"], "armor": {"melee": 0.0, "ranged": 0.0}, "attack_type": "melee", "bonus": {"cavalry": 18.0}, "brace_bonus": 16.0},
	"man_at_arms": {"label": "重装步兵", "hp": 155.0, "speed": 83.0, "damage": 15.0, "range": 23.0, "cooldown": 1.2, "radius": 12.0, "cost": {"food": 100, "gold": 20}, "time": 10.0, "tags": ["military", "infantry", "heavy", "armored"], "armor": {"melee": 3.0, "ranged": 3.0}, "attack_type": "melee", "bonus": {}},
	"archer": {"label": "弓箭手", "hp": 65.0, "speed": 93.0, "damage": 9.0, "range": 135.0, "cooldown": 1.25, "radius": 11.0, "cost": {"wood": 60, "food": 30}, "time": 8.0, "tags": ["military", "infantry", "light", "ranged"], "armor": {"melee": 0.0, "ranged": 0.0}, "attack_type": "ranged", "bonus": {"light": 3.0}, "projectile_speed": 350.0},
	"longbow": {"label": "长弓兵", "hp": 70.0, "speed": 90.0, "damage": 11.0, "range": 175.0, "cooldown": 1.35, "radius": 11.0, "cost": {"wood": 65, "food": 35}, "time": 8.0, "tags": ["military", "infantry", "light", "ranged", "unique"], "armor": {"melee": 0.0, "ranged": 0.0}, "attack_type": "ranged", "bonus": {"light": 4.0}, "projectile_speed": 380.0},
	"crossbowman": {"label": "弩手", "hp": 75.0, "speed": 86.0, "damage": 13.0, "range": 125.0, "cooldown": 1.55, "radius": 11.0, "cost": {"food": 70, "gold": 40}, "time": 10.0, "tags": ["military", "infantry", "light", "ranged", "anti_armor"], "armor": {"melee": 0.0, "ranged": 0.0}, "attack_type": "ranged", "bonus": {"heavy": 12.0}, "projectile_speed": 420.0},
	"arbaletrier": {"label": "弩炮手", "hp": 85.0, "speed": 86.0, "damage": 14.0, "range": 130.0, "cooldown": 1.5, "radius": 11.0, "cost": {"food": 75, "gold": 45}, "time": 10.0, "tags": ["military", "infantry", "light", "ranged", "anti_armor", "unique"], "armor": {"melee": 1.0, "ranged": 1.0}, "attack_type": "ranged", "bonus": {"heavy": 14.0}, "projectile_speed": 430.0},
	"horseman": {"label": "轻骑兵", "hp": 145.0, "speed": 145.0, "damage": 16.0, "range": 28.0, "cooldown": 1.2, "radius": 14.0, "cost": {"food": 90, "wood": 30}, "time": 10.0, "tags": ["military", "cavalry", "light"], "armor": {"melee": 0.0, "ranged": 1.0}, "attack_type": "melee", "bonus": {"ranged": 9.0}, "charge_bonus": 4.0},
	"knight": {"label": "重骑士", "hp": 185.0, "speed": 136.0, "damage": 22.0, "range": 28.0, "cooldown": 1.25, "radius": 15.0, "cost": {"food": 110, "gold": 75}, "time": 12.0, "tags": ["military", "cavalry", "heavy", "armored"], "armor": {"melee": 3.0, "ranged": 3.0}, "attack_type": "melee", "bonus": {}, "charge_bonus": 11.0},
	"royal_knight": {"label": "皇家骑士", "hp": 195.0, "speed": 138.0, "damage": 23.0, "range": 28.0, "cooldown": 1.25, "radius": 15.0, "cost": {"food": 110, "gold": 75}, "time": 12.0, "tags": ["military", "cavalry", "heavy", "armored", "unique"], "armor": {"melee": 3.0, "ranged": 3.0}, "attack_type": "melee", "bonus": {}, "charge_bonus": 16.0},
}

const BUILDINGS := {
	"town_center": {"label": "城镇中心", "hp": 1050.0, "size": Vector2(90, 90), "cost": {}, "time": 0.0, "pop": 10, "tags": ["building"], "armor": {"melee": 2.0, "ranged": 4.0}},
	"house": {"label": "房屋", "hp": 260.0, "size": Vector2(55, 50), "cost": {"wood": 80}, "time": 6.0, "pop": 10, "tags": ["building"], "armor": {"melee": 0.0, "ranged": 2.0}},
	"farm": {"label": "农田", "hp": 170.0, "size": Vector2(55, 55), "cost": {"wood": 60}, "time": 5.0, "pop": 0, "tags": ["building"], "armor": {"melee": 0.0, "ranged": 0.0}},
	"barracks": {"label": "兵营", "hp": 490.0, "size": Vector2(70, 65), "cost": {"wood": 160}, "time": 10.0, "pop": 0, "tags": ["building"], "armor": {"melee": 1.0, "ranged": 3.0}},
	"archery_range": {"label": "靶场", "hp": 430.0, "size": Vector2(70, 65), "cost": {"wood": 160}, "time": 10.0, "pop": 0, "tags": ["building"], "armor": {"melee": 1.0, "ranged": 3.0}},
	"stable": {"label": "马厩", "hp": 460.0, "size": Vector2(70, 65), "cost": {"wood": 180}, "time": 11.0, "pop": 0, "tags": ["building"], "armor": {"melee": 1.0, "ranged": 3.0}},
}

static func gathered_amount(civ: String, resource_kind: String, from_farm: bool) -> int:
	var amount := 9 if resource_kind == "food" else 7
	if civ == "English" and from_farm: amount = 12
	return amount

static func training_time(civ: String, building_kind: String, unit_kind: String) -> float:
	var duration: float = UNITS[unit_kind]["time"]
	if civ == "French" and building_kind == "stable": duration *= 0.85
	return duration

static func cost_text(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for resource in RESOURCE_NAMES:
		if cost.has(resource):
			parts.append("%s%d" % [RESOURCE_LABELS[resource], cost[resource]])
	return " ".join(parts)

class_name GameData
extends RefCounted

# All balance values live here. The simulation and UI consume the same definitions.
const RESOURCE_NAMES := ["food", "wood", "gold", "stone"]
const RESOURCE_LABELS := {"food": "食物", "wood": "木材", "gold": "黄金", "stone": "石料"}

const CIVILIZATIONS := {
	"English": {"label": "英格兰", "color": Color("3976b8"), "description": "农田 +25% 产出，长弓兵"},
	"French": {"label": "法兰西", "color": Color("b94b4b"), "description": "骑士冲锋伤害，骑兵训练更快"},
	"Chinese": {"label": "中国", "color": Color("c69a38"), "description": "建造更快，诸葛弩与宫廷卫士，双地标解锁王朝"},
}

const UNITS := {
	"villager": {"label": "村民", "hp": 45.0, "speed": 100.0, "damage": 3.0, "range": 20.0, "cooldown": 1.0, "radius": 10.0, "cost": {"food": 50}, "time": 5.0, "tags": ["worker", "light"], "armor": {"melee": 0.0, "ranged": 0.0}, "attack_type": "melee", "bonus": {}},
	"scout": {"label": "侦察兵", "hp": 105.0, "speed": 164.0, "damage": 6.0, "range": 23.0, "cooldown": 1.1, "radius": 12.0, "cost": {"food": 70}, "time": 8.0, "tags": ["military", "cavalry", "light", "scout"], "armor": {"melee": 0.0, "ranged": 1.0}, "attack_type": "melee", "bonus": {}},
	"spearman": {"label": "长矛兵", "hp": 90.0, "speed": 88.0, "damage": 12.0, "range": 23.0, "cooldown": 1.15, "radius": 12.0, "cost": {"food": 60, "wood": 20}, "time": 7.0, "tags": ["military", "infantry", "light", "anti_cavalry"], "armor": {"melee": 0.0, "ranged": 0.0}, "attack_type": "melee", "bonus": {"cavalry": 18.0}, "brace_bonus": 16.0},
	"man_at_arms": {"label": "重装步兵", "hp": 155.0, "speed": 83.0, "damage": 15.0, "range": 23.0, "cooldown": 1.2, "radius": 12.0, "cost": {"food": 100, "gold": 20}, "time": 10.0, "tags": ["military", "infantry", "heavy", "armored"], "armor": {"melee": 3.0, "ranged": 3.0}, "attack_type": "melee", "bonus": {}},
	"palace_guard": {"label": "宫廷卫士", "hp": 145.0, "speed": 105.0, "damage": 15.0, "range": 23.0, "cooldown": 1.15, "radius": 12.0, "cost": {"food": 105, "gold": 25}, "time": 11.0, "tags": ["military", "infantry", "heavy", "armored", "unique"], "armor": {"melee": 2.0, "ranged": 2.0}, "attack_type": "melee", "bonus": {}},
	"archer": {"label": "弓箭手", "hp": 65.0, "speed": 93.0, "damage": 9.0, "range": 135.0, "cooldown": 1.25, "radius": 11.0, "cost": {"wood": 60, "food": 30}, "time": 8.0, "tags": ["military", "infantry", "light", "ranged"], "armor": {"melee": 0.0, "ranged": 0.0}, "attack_type": "ranged", "bonus": {"light": 3.0}, "projectile_speed": 350.0},
	"longbow": {"label": "长弓兵", "hp": 70.0, "speed": 90.0, "damage": 11.0, "range": 175.0, "cooldown": 1.35, "radius": 11.0, "cost": {"wood": 65, "food": 35}, "time": 8.0, "tags": ["military", "infantry", "light", "ranged", "unique"], "armor": {"melee": 0.0, "ranged": 0.0}, "attack_type": "ranged", "bonus": {"light": 4.0}, "projectile_speed": 380.0},
	"zhuge_nu": {"label": "诸葛弩", "hp": 68.0, "speed": 90.0, "damage": 5.0, "range": 115.0, "cooldown": 0.65, "radius": 11.0, "cost": {"food": 40, "wood": 55}, "time": 9.0, "tags": ["military", "infantry", "light", "ranged", "unique"], "armor": {"melee": 0.0, "ranged": 0.0}, "attack_type": "ranged", "bonus": {"light": 4.0}, "projectile_speed": 390.0},
	"crossbowman": {"label": "弩手", "hp": 75.0, "speed": 86.0, "damage": 13.0, "range": 125.0, "cooldown": 1.55, "radius": 11.0, "cost": {"food": 70, "gold": 40}, "time": 10.0, "tags": ["military", "infantry", "light", "ranged", "anti_armor"], "armor": {"melee": 0.0, "ranged": 0.0}, "attack_type": "ranged", "bonus": {"heavy": 12.0}, "projectile_speed": 420.0},
	"arbaletrier": {"label": "弩炮手", "hp": 85.0, "speed": 86.0, "damage": 14.0, "range": 130.0, "cooldown": 1.5, "radius": 11.0, "cost": {"food": 75, "gold": 45}, "time": 10.0, "tags": ["military", "infantry", "light", "ranged", "anti_armor", "unique"], "armor": {"melee": 1.0, "ranged": 1.0}, "attack_type": "ranged", "bonus": {"heavy": 14.0}, "projectile_speed": 430.0},
	"horseman": {"label": "轻骑兵", "hp": 145.0, "speed": 145.0, "damage": 16.0, "range": 28.0, "cooldown": 1.2, "radius": 14.0, "cost": {"food": 90, "wood": 30}, "time": 10.0, "tags": ["military", "cavalry", "light"], "armor": {"melee": 0.0, "ranged": 1.0}, "attack_type": "melee", "bonus": {"ranged": 9.0}, "charge_bonus": 4.0},
	"knight": {"label": "重骑士", "hp": 185.0, "speed": 136.0, "damage": 22.0, "range": 28.0, "cooldown": 1.25, "radius": 15.0, "cost": {"food": 110, "gold": 75}, "time": 12.0, "tags": ["military", "cavalry", "heavy", "armored"], "armor": {"melee": 3.0, "ranged": 3.0}, "attack_type": "melee", "bonus": {}, "charge_bonus": 11.0},
	"royal_knight": {"label": "皇家骑士", "hp": 195.0, "speed": 138.0, "damage": 23.0, "range": 28.0, "cooldown": 1.25, "radius": 15.0, "cost": {"food": 110, "gold": 75}, "time": 12.0, "tags": ["military", "cavalry", "heavy", "armored", "unique"], "armor": {"melee": 3.0, "ranged": 3.0}, "attack_type": "melee", "bonus": {}, "charge_bonus": 16.0},
	"battering_ram": {"label": "攻城槌", "hp": 360.0, "speed": 52.0, "damage": 15.0, "range": 24.0, "cooldown": 2.3, "radius": 18.0, "cost": {"wood": 250}, "time": 22.0, "tags": ["military", "siege", "heavy"], "armor": {"melee": 2.0, "ranged": 12.0}, "attack_type": "melee", "bonus": {"structure": 80.0}},
	"trebuchet": {"label": "投石机", "hp": 175.0, "speed": 45.0, "damage": 28.0, "range": 350.0, "min_range": 95.0, "cooldown": 5.5, "radius": 19.0, "cost": {"wood": 270, "gold": 150}, "time": 30.0, "tags": ["military", "siege", "heavy", "ranged"], "armor": {"melee": 0.0, "ranged": 6.0}, "attack_type": "ranged", "bonus": {"structure": 105.0}, "projectile_speed": 330.0},
}

const BUILDINGS := {
	"town_center": {"label": "城镇中心", "hp": 1050.0, "size": Vector2(90, 90), "cost": {}, "time": 0.0, "pop": 10, "tags": ["building", "structure"], "armor": {"melee": 2.0, "ranged": 4.0}, "garrison_capacity": 10, "defense": {"damage": 7.0, "range": 160.0, "cooldown": 1.5, "projectile_speed": 430.0, "garrison_bonus": 1.5}},
	"house": {"label": "房屋", "hp": 260.0, "size": Vector2(55, 50), "cost": {"wood": 80}, "time": 6.0, "pop": 10, "tags": ["building", "structure"], "armor": {"melee": 0.0, "ranged": 2.0}},
	"farm": {"label": "农田", "hp": 170.0, "size": Vector2(55, 55), "cost": {"wood": 60}, "time": 5.0, "pop": 0, "tags": ["building", "structure"], "armor": {"melee": 0.0, "ranged": 0.0}},
	"barracks": {"label": "兵营", "hp": 490.0, "size": Vector2(70, 65), "cost": {"wood": 160}, "time": 10.0, "pop": 0, "tags": ["building", "structure"], "armor": {"melee": 1.0, "ranged": 3.0}},
	"archery_range": {"label": "靶场", "hp": 430.0, "size": Vector2(70, 65), "cost": {"wood": 160}, "time": 10.0, "pop": 0, "tags": ["building", "structure"], "armor": {"melee": 1.0, "ranged": 3.0}},
	"stable": {"label": "马厩", "hp": 460.0, "size": Vector2(70, 65), "cost": {"wood": 180}, "time": 11.0, "pop": 0, "tags": ["building", "structure"], "armor": {"melee": 1.0, "ranged": 3.0}},
	"outpost": {"label": "哨塔", "hp": 500.0, "size": Vector2(42, 42), "cost": {"wood": 120}, "time": 13.0, "pop": 0, "tags": ["building", "structure", "fortification"], "armor": {"melee": 2.0, "ranged": 6.0}, "garrison_capacity": 5, "defense": {"damage": 8.0, "range": 175.0, "cooldown": 1.7, "projectile_speed": 460.0, "garrison_bonus": 2.0}},
	"palisade_wall": {"label": "木墙", "hp": 320.0, "size": Vector2(68, 20), "cost": {"wood": 45}, "time": 7.0, "pop": 0, "tags": ["building", "structure", "fortification", "wall"], "armor": {"melee": 2.0, "ranged": 8.0}},
	"stone_wall": {"label": "石墙", "hp": 850.0, "size": Vector2(68, 24), "cost": {"stone": 95}, "time": 12.0, "pop": 0, "tags": ["building", "structure", "fortification", "wall"], "armor": {"melee": 5.0, "ranged": 12.0}},
	"keep": {"label": "城堡", "hp": 1500.0, "size": Vector2(82, 82), "cost": {"stone": 400, "wood": 100}, "time": 28.0, "pop": 0, "tags": ["building", "structure", "fortification"], "armor": {"melee": 6.0, "ranged": 9.0}, "garrison_capacity": 10, "defense": {"damage": 17.0, "range": 225.0, "cooldown": 1.8, "projectile_speed": 480.0, "garrison_bonus": 2.0}},
	"siege_workshop": {"label": "攻城器械厂", "hp": 540.0, "size": Vector2(75, 70), "cost": {"wood": 240, "gold": 80}, "time": 18.0, "pop": 0, "tags": ["building", "structure"], "armor": {"melee": 2.0, "ranged": 4.0}},
	"wonder": {"label": "奇观", "hp": 2100.0, "size": Vector2(118, 118), "cost": {"food": 600, "wood": 600, "gold": 600, "stone": 600}, "time": 80.0, "pop": 0, "tags": ["building", "structure", "wonder"], "armor": {"melee": 5.0, "ranged": 7.0}},
	"landmark": {"label": "地标", "hp": 1350.0, "size": Vector2(110, 100), "cost": {}, "time": 25.0, "pop": 0, "tags": ["building", "structure", "landmark"], "armor": {"melee": 4.0, "ranged": 6.0}},
}

static func gathered_amount(civ: String, resource_kind: String, from_farm: bool) -> int:
	var amount := 9 if resource_kind == "food" else 7
	if civ == "English" and from_farm: amount = 12
	return amount

static func training_time(civ: String, building_kind: String, unit_kind: String) -> float:
	var duration: float = UNITS[unit_kind]["time"]
	if civ == "French" and building_kind == "stable": duration *= 0.85
	return duration

static func construction_multiplier(civ: String) -> float:
	return 1.15 if civ == "Chinese" else 1.0

static func cost_text(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for resource in RESOURCE_NAMES:
		if cost.has(resource):
			parts.append("%s%d" % [RESOURCE_LABELS[resource], cost[resource]])
	return " ".join(parts)

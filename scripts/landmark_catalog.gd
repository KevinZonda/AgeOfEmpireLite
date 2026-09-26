class_name RtsLandmarkCatalog
extends RefCounted

# English and French choose one landmark per age. China may complete the other
# landmark later to unlock that age's dynasty.
# The names evoke the civilizations, while the balance is specific to this game.
const LANDMARKS := {
	"eng_council_hall": {"label": "议政厅", "civilization": "English", "age": 2, "description": "靶场训练速度提高 25%", "effects": {"production": {"archery_range": 0.75}}},
	"eng_kings_mill": {"label": "王家磨坊", "civilization": "English", "age": 2, "description": "农田食物采集提高 25%", "effects": {"gather": {"farm_food": 1.25}}},
	"eng_white_tower": {"label": "白塔", "civilization": "English", "age": 3, "description": "建筑生命值 +100，远程护甲 +2", "effects": {"building": {"all": {"hp": 100.0, "armor_ranged": 2.0}}}},
	"eng_abbey": {"label": "修道院", "civilization": "English", "age": 3, "description": "步兵生命值 +15", "effects": {"unit": {"infantry": {"hp": 15.0}}}},
	"eng_berkshire_fortress": {"label": "伯克郡堡垒", "civilization": "English", "age": 4, "description": "建筑生命值 +200，近战护甲 +2", "effects": {"building": {"all": {"hp": 200.0, "armor_melee": 2.0}}}},
	"eng_wynguard_palace": {"label": "温加德宫殿", "civilization": "English", "age": 4, "description": "全军训练速度提高 10%，远程单位伤害 +2", "effects": {"production": {"all": 0.9}, "unit": {"ranged": {"damage": 2.0}}}},
	"fr_school_of_cavalry": {"label": "骑兵学院", "civilization": "French", "age": 2, "description": "马厩训练速度提高 25%", "effects": {"production": {"stable": 0.75}}},
	"fr_chamber_of_commerce": {"label": "商会", "civilization": "French", "age": 2, "description": "黄金采集提高 20%", "effects": {"gather": {"gold": 1.2}}},
	"fr_royal_institute": {"label": "皇家学院", "civilization": "French", "age": 3, "description": "骑兵生命值 +15，马厩训练速度提高 10%", "effects": {"production": {"stable": 0.9}, "unit": {"cavalry": {"hp": 15.0}}}},
	"fr_guild_hall": {"label": "行会大厅", "civilization": "French", "age": 3, "description": "石料采集提高 20%", "effects": {"gather": {"stone": 1.2}}},
	"fr_red_palace": {"label": "红宫", "civilization": "French", "age": 4, "description": "建筑生命值 +150，远程护甲 +2", "effects": {"building": {"all": {"hp": 150.0, "armor_ranged": 2.0}}}},
	"fr_college_of_artillery": {"label": "炮兵学院", "civilization": "French", "age": 4, "description": "军事单位伤害 +1，攻城单位额外伤害 +4", "effects": {"unit": {"military": {"damage": 1.0}, "siege": {"damage": 4.0}}}},
	"zh_imperial_academy": {"label": "国子监", "civilization": "Chinese", "age": 2, "description": "黄金采集提高 10%", "effects": {"gather": {"gold": 1.1}}},
	"zh_barbican": {"label": "边关箭楼", "civilization": "Chinese", "age": 2, "description": "建筑远程护甲 +1", "effects": {"building": {"all": {"armor_ranged": 1.0}}}},
	"zh_clocktower": {"label": "工部钟楼", "civilization": "Chinese", "age": 3, "description": "攻城器械训练速度提高 15%", "effects": {"production": {"siege_workshop": 0.85}}},
	"zh_imperial_palace": {"label": "皇城", "civilization": "Chinese", "age": 3, "description": "步兵生命值 +10", "effects": {"unit": {"infantry": {"hp": 10.0}}}},
	"zh_gatehouse": {"label": "长城关楼", "civilization": "Chinese", "age": 4, "description": "建筑生命值 +100", "effects": {"building": {"all": {"hp": 100.0}}}},
	"zh_spirit_way": {"label": "神机营", "civilization": "Chinese", "age": 4, "description": "远程单位伤害 +2", "effects": {"unit": {"ranged": {"damage": 2.0}}}},
}
const LANDMARK_HP := 1350.0
const LANDMARK_SIZE := Vector2(110, 100)
const DYNASTY_NAMES := {"Song": "宋", "Yuan": "元", "Ming": "明"}


static func landmark(landmark_id: String) -> Dictionary:
	if not LANDMARKS.has(landmark_id): return {}
	var definition: Dictionary = LANDMARKS[landmark_id].duplicate(true)
	definition["id"] = landmark_id
	definition["cost"] = RtsTechTree.age_cost(int(definition["age"]) - 1)
	definition["time"] = RtsTechTree.age_time(int(definition["age"]) - 1)
	definition["hp"] = LANDMARK_HP
	definition["size"] = LANDMARK_SIZE
	return definition


static func choices_for(civilization: String, current_age: int, completed: Array = []) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not GameData.CIVILIZATIONS.has(civilization): return result
	for landmark_id in LANDMARKS:
		var definition: Dictionary = LANDMARKS[landmark_id]
		if definition["civilization"] != civilization: continue
		var landmark_age: int = definition["age"]
		if landmark_age == current_age + 1 and RtsTechTree.can_advance(current_age):
			result.append(landmark(landmark_id))
		elif civilization == "Chinese" and landmark_age <= current_age and not completed.has(landmark_id) and _completed_at_age(completed, civilization, landmark_age) == 1:
			result.append(landmark(landmark_id))
	return result


static func choice_status(civilization: String, current_age: int, completed: Array, landmark_id: String, active_id: String = "") -> Dictionary:
	if not GameData.CIVILIZATIONS.has(civilization): return _locked("未知文明")
	if not LANDMARKS.has(landmark_id): return _locked("未知地标")
	var definition: Dictionary = LANDMARKS[landmark_id]
	if definition["civilization"] != civilization: return _locked("仅限%s" % GameData.CIVILIZATIONS[definition["civilization"]]["label"])
	if not active_id.is_empty(): return _locked("已有地标正在建造")
	var landmark_age: int = definition["age"]
	var count := _completed_at_age(completed, civilization, landmark_age)
	if completed.has(landmark_id): return _locked("地标已建成")
	if landmark_age == current_age + 1:
		if not RtsTechTree.can_advance(current_age): return _locked("已达到最高时代")
		if count > 0: return _locked("该时代已选择地标")
	elif civilization == "Chinese" and landmark_age <= current_age and landmark_age >= 2:
		if count != 1: return _locked("先建造该时代的第一座地标")
	else:
		return _locked("需要先进入前一时代")
	return {"available": true, "reason": ""}


static func dynasty_for(completed: Array) -> String:
	if _completed_at_age(completed, "Chinese", 4) >= 2: return "Ming"
	if _completed_at_age(completed, "Chinese", 3) >= 2: return "Yuan"
	if _completed_at_age(completed, "Chinese", 2) >= 2: return "Song"
	return ""


static func dynasty_training_multiplier(civilization: String, dynasty: String, building_kind: String, unit_kind: String) -> float:
	if civilization == "Chinese" and dynasty == "Song" and building_kind == "town_center" and unit_kind == "villager": return 0.8
	return 1.0


static func dynasty_unit_bonus(civilization: String, dynasty: String, tags: Array) -> Dictionary:
	if civilization != "Chinese" or not tags.has("military"): return {}
	if dynasty == "Yuan": return {"speed": 8.0}
	if dynasty == "Ming": return {"hp": 15.0}
	return {}


static func _completed_at_age(completed: Array, civilization: String, age: int) -> int:
	var count := 0
	var seen := {}
	for landmark_id in completed:
		if seen.has(landmark_id) or not LANDMARKS.has(landmark_id): continue
		seen[landmark_id] = true
		var definition: Dictionary = LANDMARKS[landmark_id]
		if definition["civilization"] == civilization and int(definition["age"]) == age: count += 1
	return count


static func gather_multiplier(civilization: String, completed: Array, resource_kind: String, from_farm: bool = false) -> float:
	var multiplier := 1.0
	for definition in _active_landmarks(civilization, completed):
		var effects: Dictionary = definition["effects"].get("gather", {})
		multiplier *= float(effects.get("all", 1.0))
		multiplier *= float(effects.get(resource_kind, 1.0))
		if from_farm and resource_kind == "food": multiplier *= float(effects.get("farm_food", 1.0))
	return multiplier


static func training_multiplier(civilization: String, completed: Array, building_kind: String, _unit_kind: String = "") -> float:
	var multiplier := 1.0
	for definition in _active_landmarks(civilization, completed):
		var effects: Dictionary = definition["effects"].get("production", {})
		multiplier *= float(effects.get("all", 1.0))
		multiplier *= float(effects.get(building_kind, 1.0))
	return multiplier


static func unit_bonus(civilization: String, completed: Array, unit_kind: String, tags: Array) -> Dictionary:
	var bonus := {}
	for definition in _active_landmarks(civilization, completed):
		var effects: Dictionary = definition["effects"].get("unit", {})
		for selector in effects:
			if selector == unit_kind or tags.has(selector): _accumulate(bonus, effects[selector])
	return bonus


static func building_bonus(civilization: String, completed: Array, building_kind: String) -> Dictionary:
	var bonus := {}
	for definition in _active_landmarks(civilization, completed):
		var effects: Dictionary = definition["effects"].get("building", {})
		for selector in effects:
			if selector == "all" or selector == building_kind: _accumulate(bonus, effects[selector])
	return bonus


static func _active_landmarks(civilization: String, completed: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen := {}
	for landmark_id in completed:
		if seen.has(landmark_id) or not LANDMARKS.has(landmark_id): continue
		seen[landmark_id] = true
		var definition: Dictionary = LANDMARKS[landmark_id]
		if definition["civilization"] == civilization: result.append(definition)
	return result


static func _accumulate(bonus: Dictionary, effect: Dictionary) -> void:
	for stat in effect: bonus[stat] = float(bonus.get(stat, 0.0)) + float(effect[stat])


static func _locked(reason: String) -> Dictionary:
	return {"available": false, "reason": reason}

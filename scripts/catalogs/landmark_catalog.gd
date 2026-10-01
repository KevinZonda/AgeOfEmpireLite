class_name RtsLandmarkCatalog
extends RefCounted

# English and French choose one landmark per age. China may complete the other
# landmark later to unlock that age's dynasty.
# The displayed names follow the three reference civilizations. Roles and
# timings are scaled for this game's existing economy and 2D battlefield.
const LANDMARKS := {
	"eng_council_hall": {"label": "议会厅", "civilization": "English", "age": 2, "description": "可训练长弓兵与靶场单位；训练时间减半", "producer": "archery_range", "training_rate": 0.5, "effects": {}},
	"eng_kings_mill": {"label": "列王修道院", "civilization": "English", "age": 2, "description": "附近 160 范围内未在攻击的友军每 4 秒恢复 4 生命", "healing_aura": 160.0, "effects": {}},
	"eng_white_tower": {"label": "白塔", "civilization": "English", "age": 3, "description": "拥有城堡防御；可训练六类陆军，训练时间减半", "producer": "white_tower", "training_rate": 0.5, "defense_kind": "keep", "effects": {}},
	"eng_abbey": {"label": "王宫", "civilization": "English", "age": 3, "description": "兼作城镇中心，可训练村民并提供 10 人口", "producer": "town_center", "population": 10, "effects": {}},
	"eng_berkshire_fortress": {"label": "伯克郡宫殿", "civilization": "English", "age": 4, "description": "防御射程 300、伤害 23；普通城堡为 225、17", "defense_kind": "berkshire", "effects": {}},
	"eng_wynguard_palace": {"label": "温嘉德宫殿", "civilization": "English", "age": 4, "description": "可训练长矛兵、重装步兵、长弓兵和投石机", "producer": "wynguard", "effects": {}},
	"fr_school_of_cavalry": {"label": "骑兵学校", "civilization": "French", "age": 2, "description": "兼作马厩；骑兵训练时间再减少 25%", "producer": "stable", "training_rate": 0.75, "effects": {}},
	"fr_chamber_of_commerce": {"label": "商会", "civilization": "French", "age": 2, "description": "每完成一项经济科技免费训练商人", "producer": "market", "effects": {}},
	"fr_royal_institute": {"label": "皇家学院", "civilization": "French", "age": 3, "description": "可研究陆军与攻城科技，研究费用减半", "producer": "royal_institute", "research_discount": 0.5, "effects": {}},
	"fr_guild_hall": {"label": "公会大厅", "civilization": "French", "age": 3, "description": "每 4 秒积累各 12 单位资源，可主动提取", "stockpile": true, "effects": {}},
	"fr_red_palace": {"label": "红宫", "civilization": "French", "age": 4, "description": "防御射击伤害 30；普通城堡为 17", "defense_kind": "red_palace", "effects": {}},
	"fr_college_of_artillery": {"label": "炮兵学院", "civilization": "French", "age": 4, "description": "攻城器械训练时间减少 33%，伤害提高 30%", "producer": "siege_workshop", "training_rate": 0.67, "produced_siege_damage": 1.3, "effects": {}},
	"zh_imperial_academy": {"label": "翰林院", "civilization": "Chinese", "age": 2, "description": "训练朝廷命官；附近 180 范围建筑产税翻倍", "producer": "imperial_academy", "tax_radius": 180.0, "effects": {}},
	"zh_barbican": {"label": "烈日瓮城", "civilization": "Chinese", "age": 2, "description": "可驻军防御，射程 205、伤害 16", "defense_kind": "barbican", "effects": {}},
	"zh_clocktower": {"label": "天文钟楼", "civilization": "Chinese", "age": 3, "description": "兼作攻城器械厂；本地生产的攻城器械生命提高 50%", "producer": "siege_workshop", "produced_siege_hp": 1.5, "effects": {}},
	"zh_imperial_palace": {"label": "皇宫", "civilization": "Chinese", "age": 3, "description": "每 60 秒可侦察敌方村民 10 秒", "active_ability": "spy", "effects": {}},
	"zh_gatehouse": {"label": "长城门楼", "civilization": "Chinese", "age": 4, "description": "双发防御炮；石墙守军远程伤害提高 25%", "defense_kind": "gatehouse", "effects": {}},
	"zh_spirit_way": {"label": "皇陵", "civilization": "Chinese", "age": 4, "description": "王朝兵升级费用与时间减半；阵亡鼓舞友军", "producer": "spirit_way", "research_discount": 0.5, "effects": {}},
}
const LANDMARK_HP := 1350.0
const LANDMARK_SIZE := Vector2(92, 92) * GameData.BUILDING_SCALE
const DYNASTY_NAMES := {"Tang": "唐", "Song": "宋", "Yuan": "元", "Ming": "明"}


static func landmark(landmark_id: String) -> Dictionary:
	if not LANDMARKS.has(landmark_id): return {}
	var definition: Dictionary = LANDMARKS[landmark_id].duplicate(true)
	definition["id"] = landmark_id
	definition["cost"] = RtsTechTree.age_cost(int(definition["age"]) - 1)
	definition["time"] = RtsTechTree.age_time(int(definition["age"]) - 1)
	definition["hp"] = LANDMARK_HP
	definition["size"] = LANDMARK_SIZE
	definition["defense"] = defense(landmark_id)
	definition["garrison_capacity"] = 10 if not definition["defense"].is_empty() or definition.get("producer", "") == "town_center" else 0
	definition["population"] = int(definition.get("population", 0))
	return definition

static func producer(landmark_id: String) -> String:
	return str(LANDMARKS.get(landmark_id, {}).get("producer", ""))

static func defense(landmark_id: String) -> Dictionary:
	var role: String = LANDMARKS.get(landmark_id, {}).get("defense_kind", "")
	if role.is_empty(): return {}
	var base: Dictionary = GameData.BUILDINGS["keep"]["defense"].duplicate(true)
	if role == "berkshire":
		base["range"] = 300.0
		base["damage"] = 23.0
	elif role == "red_palace":
		base["damage"] = 30.0
	elif role == "barbican":
		base["range"] = 205.0
		base["damage"] = 16.0
	elif role == "gatehouse":
		base["range"] = 235.0
		base["damage"] = 16.0
		base["salvo"] = 2
		base["splash_radius"] = 28.0
	return base

static func training_rate(landmark_id: String) -> float:
	return float(LANDMARKS.get(landmark_id, {}).get("training_rate", 1.0))

static func produced_siege_hp(landmark_id: String) -> float:
	return float(LANDMARKS.get(landmark_id, {}).get("produced_siege_hp", 1.0))

static func produced_siege_damage(landmark_id: String) -> float:
	return float(LANDMARKS.get(landmark_id, {}).get("produced_siege_damage", 1.0))

static func research_discount(landmark_id: String) -> float:
	return float(LANDMARKS.get(landmark_id, {}).get("research_discount", 1.0))

static func trade_multiplier(civilization: String, completed: Array) -> float:
	var result := 1.0
	for definition in _active_landmarks(civilization, completed):
		result *= float(definition.get("trade_multiplier", 1.0))
	return result


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

static func preferred_landmark(civilization: String, current_age: int, map_style: String) -> String:
	# AI choices express each civilization's existing economy and battlefield
	# strengths without applying arbitrary terrain-based stat modifiers.
	match civilization:
		"English":
			if current_age == 1: return "eng_kings_mill" if map_style == "islands" else "eng_council_hall"
			if current_age == 2: return "eng_white_tower" if map_style in ["lakes", "highlands"] else "eng_abbey"
			if current_age == 3: return "eng_berkshire_fortress" if map_style in ["lakes", "highlands"] else "eng_wynguard_palace"
		"French":
			if current_age == 1: return "fr_chamber_of_commerce" if map_style in ["lakes", "islands"] else "fr_school_of_cavalry"
			if current_age == 2: return "fr_guild_hall" if map_style in ["lakes", "islands"] else "fr_royal_institute"
			if current_age == 3: return "fr_college_of_artillery" if map_style == "balanced" else "fr_red_palace"
		"Chinese":
			if current_age == 1: return "zh_barbican" if map_style in ["lakes", "highlands"] else "zh_imperial_academy"
			if current_age == 2: return "zh_imperial_palace" if map_style == "islands" else "zh_clocktower"
			if current_age == 3: return "zh_gatehouse" if map_style in ["lakes", "highlands"] else "zh_spirit_way"
	return ""


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
	return "Tang"


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

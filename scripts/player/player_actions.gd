extends RefCounted

# Actions carry callbacks and gameplay availability, never Control instances.
# IDs expire on rebuild so a stale button cannot execute a new selection's action.
signal rebuilt
signal age_choice_requested
signal view_refresh_requested

const BUILD_HELP := {
	"town_center": "训练村民并提供人口上限，也可驻军防守。",
	"house": "提高人口上限，让你能训练更多单位。",
	"farm": "供一位村民循环播种和收获食物；离开时进度暂停。",
	"mill": "存放食物，并研究食物采集科技。",
	"lumber_camp": "存放木材，并研究伐木科技。",
	"mining_camp": "存放黄金和石料，并研究采矿科技。",
	"market": "训练商人，也可用黄金买卖资源。",
	"dock": "建造船只并研究海军科技。",
	"barracks": "训练近战步兵并研究步兵科技。",
	"archery_range": "训练远程步兵并研究射击科技。",
	"stable": "训练骑兵并研究骑兵科技。",
	"blacksmith": "研究武器、护甲和军队科技。",
	"university": "研究高级军队科技。",
	"monastery": "训练修士，治疗友军并收集圣物。",
	"outpost": "驻军和射击防御附近的敌人。",
	"palisade_wall": "用木墙阻挡敌军；可拖拽连续铺设。",
	"palisade_gate": "在木墙上设置可供友军通行的城门。",
	"stone_wall": "用更坚固的石墙阻挡敌军；可拖拽连续铺设。",
	"stone_gate": "在石墙上设置可供友军通行的城门。",
	"keep": "坚固的防御建筑，可驻军并攻击敌人。",
	"siege_workshop": "训练攻城器械并研究攻城科技。",
	"wonder": "建成后守住奇观一段时间即可获胜。",
}
const UNIT_HELP := {
	"villager": "采集资源、修建建筑并修复设施。",
	"imperial_official": "中国经济单位，可监督建筑并收取税金。",
	"scout": "高速侦察单位，用来探索地图与发现敌人。",
	"spearman": "反骑兵近战步兵，可迎击冲锋。",
	"man_at_arms": "披甲近战步兵，适合承受正面攻击。",
	"palace_guard": "中国重装步兵，移动速度更快。",
	"archer": "远程步兵，适合对付轻甲单位。",
	"longbow": "射程更远的英格兰弓兵。",
	"zhuge_nu": "中国连发弩兵，能快速射击。",
	"fire_lancer": "中国轻骑兵，冲锋并擅长攻击建筑。",
	"grenadier": "投掷火药的中国远程步兵。",
	"crossbowman": "远程步兵，擅长对付重甲单位。",
	"arbaletrier": "法兰西弩手，擅长对付重甲单位。",
	"horseman": "快速轻骑兵，适合追击远程单位。",
	"knight": "重甲骑兵，擅长冲锋和正面作战。",
	"royal_knight": "法兰西重甲骑兵，冲锋伤害更高。",
	"battering_ram": "近距离攻城器械，擅长摧毁建筑。",
	"trebuchet": "远距离攻城器械，擅长攻击建筑。",
	"handcannoneer": "高伤害火药步兵。",
	"mangonel": "范围攻击攻城器械，适合打击成群步兵。",
	"springald": "远程攻城器械，可攻击敌方单位和器械。",
	"bombard": "重型火炮，擅长摧毁建筑。",
	"cannon": "法兰西重型火炮，擅长摧毁建筑。",
	"nest_of_bees": "中国范围攻击器械，适合打击成群步兵。",
	"siege_tower": "运送步兵越过敌方城墙。",
	"fishing_boat": "在水域采集食物。",
	"warship": "重型战船，可攻击敌方船只。",
	"springald_ship": "装有弩炮的战船，擅长远程作战。",
	"incendiary_ship": "高速火攻船，接近敌舰后造成高额伤害。",
	"arrow_ship": "轻型战船，以箭矢攻击敌船。",
	"transport_ship": "运送陆地单位跨越水域。",
	"trader": "往返贸易站，为你带回资源。",
	"monk": "治疗友军，并可收集圣物。",
}
const COMMAND_HELP := {
	"age": "选择地标并进入下一个时代，解锁新建筑和单位。",
	"next_page": "切换到下一组建造选项。",
	"attack_ground": "命令攻城器械攻击指定地面位置。",
	"attack_move": "向指定位置移动，沿途主动攻击敌人。",
	"patrol": "在当前位置与目标位置之间往返巡逻。",
	"hold": "留在原地并攻击射程内的敌人。",
	"focus": "让选中的部队集中攻击同一目标。",
	"retreat": "命令选中的部队撤离战斗。",
	"formation": "调整部队行进阵型或宽度。",
	"stance": "切换单位主动交战的行为。",
	"unload": "放出船上或建筑内的单位。",
	"ungarrison": "放出建筑内驻扎的单位。",
	"stop": "停止选中单位当前的命令。",
	"field_ram": "让部队在野外建造攻城槌。",
	"field_tower": "让部队在野外建造攻城塔。",
	"market_buy": "用黄金购买 100 单位资源；价格随交易变化。",
	"market_sell": "卖出 100 单位资源换取黄金；价格随交易变化。",
	"town_bell": "召集村民到城镇中心避险。",
	"return_work": "让避险的村民返回原来的工作。",
	"collect_stockpile": "领取公会大厅累积的资源。",
	"spy": "暂时侦察敌方村民的位置。",
	"trade": "让商人恢复与贸易站之间的往返贸易。",
	"palings": "长弓兵架设拒马，阻挡敌方骑兵冲锋。",
	"volley": "长弓兵短时间内加快射击。",
	"pavise": "弩手展开或收起大盾，提高防护。",
	"helmsman": "战船短时间内提高机动能力。",
	"convert": "携带圣物的修士招降附近敌军。",
	"camp": "消耗 25 木材在附近建立预备营地。",
	"artillery_shot": "让大炮下一次攻击使用强化炮击。",
}
const STAT_LABELS := {
	"hp": "生命", "damage": "攻击", "damage_melee": "近战攻击",
	"damage_ranged": "远程攻击", "armor_melee": "近战护甲",
	"armor_ranged": "远程护甲", "speed": "移动速度",
}
const BUILD_PAGES := [
	{"title": "经济", "kinds": ["house", "lumber_camp", "mining_camp", "mill", "farm", "market", "dock", "age", "blacksmith", "monastery", "university", "wonder"]},
	{"title": "军事", "kinds": ["barracks", "archery_range", "stable", "siege_workshop", "outpost", "keep", "", "", "palisade_wall", "stone_wall", "palisade_gate", "stone_gate"]},
]

const COMMANDS_PER_PAGE := 12
const GRID_KEYS := [KEY_Q, KEY_W, KEY_E, KEY_R, KEY_A, KEY_S, KEY_D, KEY_F, KEY_Z, KEY_X, KEY_C, KEY_V]
const SIDE_KEYS := [KEY_T, KEY_G, KEY_B]
var descriptors: Array[Dictionary] = []
var current_build_pages: Array = []
var command_page := 0
var command_selection_id := 0
var interaction_allowed: Callable
var game: Node2D
var actions: Dictionary = {}
var hotkeys: Dictionary = {}
var generation := 0
var selection_ids: Array[int] = []

func _init(game_ref: Node2D, can_interact: Callable) -> void:
	game = game_ref
	interaction_allowed = can_interact

func clear() -> void:
	actions.clear()
	hotkeys.clear()
	generation += 1
	selection_ids = _selection_ids()

func register(action_type: String, kind: String, keycode: int, callback: Callable) -> String:
	var id := "%d:%s:%s:%d" % [generation, action_type, kind, actions.size()]
	actions[id] = {"type": action_type, "kind": kind, "callback": callback, "active": true}
	if keycode != KEY_NONE: hotkeys[keycode] = id
	return id

func set_active(action_id: String, active: bool) -> void:
	if actions.has(action_id): actions[action_id]["active"] = active

func has_hotkey(keycode: int) -> bool:
	return hotkeys.has(keycode)

func execute_hotkey(keycode: int) -> bool:
	return execute(hotkeys[keycode]) if hotkeys.has(keycode) else false

func execute(action_id: String) -> bool:
	if not actions.has(action_id) or not actions[action_id]["active"]: return false
	if not interaction_allowed.is_valid() or not interaction_allowed.call(): return false
	if selection_ids != _selection_ids(): return false
	var action: Dictionary = actions[action_id]
	if not availability(action["type"], action["kind"])["available"]: return false
	var callback: Callable = action["callback"]
	if not callback.is_valid(): return false
	callback.call()
	return true

func _selection_ids() -> Array[int]:
	var ids: Array[int] = []
	for entity in game.selected:
		if is_instance_valid(entity) and not entity.is_queued_for_deletion(): ids.append(entity.get_instance_id())
	return ids

func availability(action_type: String, action_kind: String, context: Dictionary = {}) -> Dictionary:
	if game.players.is_empty(): return {"available": false, "reason": "对局尚未开始", "cost": {}}
	var producer: RtsBuilding
	if not game.selected.is_empty() and is_instance_valid(game.selected[0]) and game.selected[0] is RtsBuilding:
		producer = game.selected[0]
	if context.is_empty(): context = RtsActionAvailability.context_for(game, 0, producer)
	var status: Dictionary
	if action_type in ["train", "research"]:
		status = RtsActionAvailability.production(game, producer, action_type, action_kind, context)
		var found_producer := false
		for candidate in game.selected:
			if not is_instance_valid(candidate) or not candidate is RtsBuilding or candidate.owner_id != 0: continue
			# A union of selected producers supplies the visible actions. Pick failure
			# details from a producer that actually offers this action as well.
			var offered: Array = RtsTechTree.all_train_units(game.civilizations[0], candidate.producer_kind()) if action_type == "train" else RtsTechTree.all_researches(game.civilizations[0], candidate.producer_kind())
			if not offered.has(action_kind): continue
			var candidate_status := RtsActionAvailability.production(game, candidate, action_type, action_kind, context)
			if not found_producer or candidate_status["available"]: status = candidate_status
			found_producer = true
			if candidate_status["available"]: break
	elif action_type == "unit_ability":
		status = _selected_ability_availability(action_kind)
	else:
		status = RtsActionAvailability.evaluate(action_type, action_kind, context)
	return status

func _selected_ability_availability(ability_id: String) -> Dictionary:
	var status := {"available": false, "reason": "没有可使用此技能的单位", "cost": {}}
	var found := false
	for ability in game.UNIT_ABILITY_ACTIONS:
		if ability["id"] != ability_id: continue
		for candidate in game.selected:
			if not is_instance_valid(candidate) or not candidate is RtsUnit or candidate.owner_id != 0: continue
			if not ability["kinds"].has(candidate.kind): continue
			if ability.has("civilization") and game.civilizations[0] != ability["civilization"]: continue
			if ability.has("producer_landmark") and candidate.producer_landmark_id != ability["producer_landmark"]: continue
			var candidate_status: Dictionary = candidate.ability_availability(ability_id)
			if not found or candidate_status["available"]: status = candidate_status
			found = true
			if candidate_status["available"]: return status
	return status


# Command construction is independent of Controls and HUD lifetime. Rebuild
# invalidates callbacks, computes page visibility, and publishes a value view.
func rebuild() -> void:
	clear()
	descriptors.clear()
	current_build_pages.clear()
	if game.selected.is_empty() or not is_instance_valid(game.selected[0]):
		command_page = 0
		command_selection_id = 0
		rebuilt.emit()
		return
	var item: Node2D = game.selected[0]
	var selection_id := item.get_instance_id()
	if selection_id != command_selection_id:
		command_page = 0
		command_selection_id = selection_id
	if item is RtsResource or item.owner_id != 0:
		rebuilt.emit()
		return
	if item is RtsUnit: _build_unit_actions(item)
	elif item is RtsBuilding: _build_building_actions(item)
	_layout_commands()
	rebuilt.emit()

func _build_unit_actions(item: RtsUnit) -> void:
	var any_worker := false
	var any_military := false
	var any_special := false
	var worker_count := 0
	var military_count := 0
	for unit in game.selected:
		if not is_instance_valid(unit) or not unit is RtsUnit or unit.owner_id != 0: continue
		if unit.kind == "villager": worker_count += 1
		if unit.stats.get("tags", []).has("military"): military_count += 1
		if unit.kind == "monk": any_special = true
	any_worker = worker_count > 0 and worker_count >= military_count
	any_military = military_count > 0 and military_count > worker_count
	if any_worker:
		var pages := BUILD_PAGES.duplicate(true)
		if game.civilizations[0] == "Chinese": pages.append({"title": "王朝", "kinds": []})
		game.build_page = posmod(game.build_page, pages.size())
		var page: Dictionary = pages[game.build_page]
		current_build_pages = pages
		for kind in page["kinds"]:
			if kind.is_empty():
				_add_action_spacer()
			elif kind == "age":
				if RtsTechTree.can_advance(game.players[0]["age"]): _add_action("age", "(%s) 升时代" % ["", "II", "III", "IV"][game.players[0]["age"]], {}, "order", func() -> void: age_choice_requested.emit())
				else: _add_action_spacer()
			else:
				_add_build_action(kind)
		if game.civilizations[0] == "Chinese" and game.build_page == 2:
			for choice in RtsLandmarkCatalog.choices_for(game.civilizations[0], game.players[0]["age"], game.players[0]["landmarks"]):
				if int(choice["age"]) > game.players[0]["age"]: continue
				_add_landmark_action(choice)
	if (any_military or any_special) and not any_worker:
		if any_military:
			if game.players[0]["age"] >= 3 and game.selected.any(func(chosen: Node2D) -> bool: return chosen is RtsUnit and chosen.owner_id == 0 and chosen.stats.get("tags", []).has("infantry") and not chosen.stats.get("tags", []).has("siege")):
				for field_kind in ["field_ram", "field_tower"]:
					var mode_id: String = field_kind
					var label_text := "野外建造攻城槌" if field_kind == "field_ram" else "野外建造攻城塔"
					_add_action(field_kind, label_text, GameData.unit_cost("battering_ram" if field_kind == "field_ram" else "siege_tower"), "order", func() -> void:
						game.order_mode = mode_id
						game.notify_player("点击地面指定建造位置")
					)
			if game.selected.any(func(chosen: Node2D) -> bool: return chosen is RtsUnit and chosen.owner_id == 0 and chosen.kind in ["mangonel", "nest_of_bees", "trebuchet", "bombard", "cannon"]):
				_add_action("attack_ground", "攻击地面", {}, "order", func() -> void:
					game.order_mode = "attack_ground"
					game.notify_player("点击地面指定炮击位置")
				)
			_add_action("attack_move", "攻击移动", {}, "order", func() -> void:
				game.order_mode = "attack_move"
				game.build_mode = ""
				game.notify_player("点击地图攻击移动；Shift 点击连续下令")
			)
			_add_action("patrol", "巡逻", {}, "order", func() -> void:
				game.order_mode = "patrol"
				game.notify_player("点击地图设置巡逻终点")
			)
			_add_action("hold", "坚守", {}, "order", func() -> void:
				for unit in game.selected:
					if is_instance_valid(unit) and unit is RtsUnit and unit.owner_id == 0: unit.issue_command("hold")
			)
			_add_action("focus", "集火", {}, "order", func() -> void:
				game.order_mode = "focus"
				game.notify_player("点击敌方单位或建筑集火")
			)
			_add_action("retreat", "撤退", {}, "order", func() -> void: game._retreat_selected())
			for shape in ["balanced", "line", "compact", "column"]:
				var shape_id: String = shape
				var shape_label: String = {"balanced": "默认", "line": "横队", "compact": "密集", "column": "纵队"}[shape]
				_add_action("formation", "%s阵型%s" % [shape_label, " ✓" if game.formation_mode == shape else ""], {}, "order", func() -> void:
					game.formation_mode = shape_id
					game.notify_player("下一次群体移动采用%s阵型" % shape_label)
					rebuild()
				)
			_add_action("formation", "队宽 - (%d)" % game.formation_width, {}, "order", func() -> void:
				game.formation_width = maxi(2, game.formation_width - 1)
				rebuild()
			)
			_add_action("formation", "队宽 + (%d)" % game.formation_width, {}, "order", func() -> void:
				game.formation_width = mini(8, game.formation_width + 1)
				rebuild()
			)
			for behavior in ["aggressive", "defensive", "passive"]:
				var behavior_id: String = behavior
				var behavior_label: String = {"aggressive": "主动", "defensive": "防御", "passive": "被动"}[behavior]
				_add_action("stance", "%s交战%s" % [behavior_label, " ✓" if item.engagement == behavior_id else ""], {}, "order", func() -> void:
					for chosen in game.selected:
						if is_instance_valid(chosen) and chosen is RtsUnit and chosen.owner_id == 0 and chosen.stats.get("tags", []).has("military"): chosen.engagement = behavior_id
					game.notify_player("已设为%s交战" % behavior_label)
					rebuild()
					view_refresh_requested.emit()
				)
		for ability in game.UNIT_ABILITY_ACTIONS:
			if not _selected_has_ability(ability): continue
			var ability_id: String = ability["id"]
			_add_action(ability_id, ability["label"], {}, "unit_ability", func() -> void: game._activate_selected_ability(ability_id))
	if item.kind == "transport_ship":
		_add_action("unload", "登陆", {}, "order", func() -> void:
			game.order_mode = "unload"
			game.notify_player("点击陆地让运输船靠岸并卸载乘员")
		)
	if item.kind in ["battering_ram", "siege_tower"]:
		_add_action("unload", "放出乘员", {}, "order", func() -> void:
			for chosen in game.selected:
				if is_instance_valid(chosen) and chosen is RtsUnit and chosen.owner_id == 0 and chosen.kind in ["battering_ram", "siege_tower"]: chosen.ungarrison_all()
		)
	if item.kind == "trader" and game.civilizations[0] == "French":
		for resource_kind in ["food", "wood", "gold"]:
			_add_action(resource_kind, "贸易换%s" % GameData.RESOURCE_LABELS[resource_kind], {}, "order", func() -> void: game._set_selected_trade_resource(resource_kind))
	if item.kind == "trader":
		_add_action("trade", "恢复贸易", {}, "order", func() -> void:
			for chosen in game.selected:
				if is_instance_valid(chosen) and chosen is RtsUnit and chosen.owner_id == 0 and chosen.kind == "trader" and is_instance_valid(chosen.trade_post): chosen.issue_command("trade", Vector2.INF, chosen.trade_post)
		)
	if not any_worker: _add_action("stop", "停止", {}, "order", func() -> void: game._stop_selected_units())

func _selected_has_ability(ability: Dictionary) -> bool:
	if ability.has("civilization") and game.civilizations[0] != ability["civilization"]: return false
	for unit in game.selected:
		if not is_instance_valid(unit) or not unit is RtsUnit or unit.owner_id != 0 or unit.kind not in ability["kinds"]: continue
		if ability.has("producer_landmark") and unit.producer_landmark_id != ability["producer_landmark"]: continue
		return true
	return false

func _build_building_actions(item: RtsBuilding) -> void:
	if item.kind.ends_with("_wall"):
		var gate_kind := "stone_gate" if item.kind == "stone_wall" else "palisade_gate"
		var resource := "stone" if gate_kind == "stone_gate" else "wood"
		var extra: int = GameData.BUILDINGS[gate_kind]["cost"][resource] - GameData.BUILDINGS[item.kind]["cost"][resource]
		_add_action(gate_kind, "改建城门", {resource: extra}, "convert_gate", func() -> void: game.convert_wall_to_gate(item))
	var train_kinds: Array[String] = []
	var research_kinds: Array[String] = []
	for candidate in game.selected:
		if not is_instance_valid(candidate) or not candidate is RtsBuilding or candidate.owner_id != 0: continue
		for kind in RtsTechTree.all_train_units(game.civilizations[0], candidate.producer_kind()):
			if not train_kinds.has(kind): train_kinds.append(kind)
		for kind in RtsTechTree.all_researches(game.civilizations[0], candidate.producer_kind()):
			if not research_kinds.has(kind): research_kinds.append(kind)
	for kind in train_kinds:
		_add_train_action(kind)
	for kind in research_kinds:
		_add_research_action(kind)
	if item.kind == "market":
		for resource_kind in ["food", "wood", "stone"]:
			var sell_price: int = game.market_quote(resource_kind, false)
			var buy_price: int = game.market_quote(resource_kind, true)
			var short_name := "粮" if resource_kind == "food" else "木" if resource_kind == "wood" else "石"
			_add_action("market_sell", "卖%s +%d金" % [short_name, sell_price], {}, "order", func() -> void: game.exchange_resource(0, resource_kind, false))
			_add_action("market_buy", "买%s -%d金" % [short_name, buy_price], {}, "order", func() -> void: game.exchange_resource(0, resource_kind, true))
	if item.garrison_capacity() > 0:
		_add_action("ungarrison", "放出驻军", {}, "order", func() -> void: item.ungarrison_all())
	if item.kind == "town_center":
		_add_action("town_bell", "镇钟：村民避险", {}, "order", func() -> void: game.ring_town_bell(item))
		_add_action("return_work", "返回原工作", {}, "order", func() -> void: item.ungarrison_all(true))
	if item.landmark_id == "fr_guild_hall":
		_add_action("collect_stockpile", "提取公会资源", {}, "landmark_ability", func() -> void: item.collect_stockpile())
	if item.landmark_id == "zh_imperial_palace":
		_add_action("spy", "侦察敌方村民", {}, "landmark_ability", func() -> void: item.activate_landmark_ability())

func _add_build_action(kind: String) -> void:
	var cost: Dictionary = RtsCivilizationRules.building_cost(game.civilizations[0], kind)
	_add_action(kind, GameData.BUILDINGS[kind]["label"], cost, "build", func() -> void:
		game.build_mode = kind
		game.pending_landmark_id = ""
		game.notify_player("拖拽铺设%s；空格旋转；Shift 连续建造" % GameData.BUILDINGS[kind]["label"] if kind.ends_with("_wall") else "点击地图放置%s；空格旋转墙门；Shift 连续建造" % GameData.BUILDINGS[kind]["label"])
	)

func _add_landmark_action(choice: Dictionary) -> void:
	var choice_id: String = choice["id"]
	_add_action(choice_id, choice["label"], choice["cost"], "landmark", func() -> void: game._select_landmark_for_placement(choice_id))

func _add_train_action(kind: String) -> void:
	_add_action(kind, GameData.UNITS[kind]["label"], GameData.unit_cost(kind), "train", func() -> void:
		for candidate in game.selected:
			if is_instance_valid(candidate) and candidate is RtsBuilding and candidate.owner_id == 0 and RtsTechTree.all_train_units(game.civilizations[0], candidate.producer_kind()).has(kind): game.train_unit(candidate, kind)
	)

func _add_research_action(kind: String) -> void:
	var technology: Dictionary = RtsTechTree.get_technology(kind)
	_add_action(kind, technology["label"], technology["cost"], "research", func() -> void:
		for candidate in game.selected:
			if is_instance_valid(candidate) and candidate is RtsBuilding and candidate.owner_id == 0 and RtsTechTree.all_researches(game.civilizations[0], candidate.producer_kind()).has(kind):
				if game.research_technology(candidate, kind): break
	)

func _add_action_spacer() -> void:
	descriptors.append({"view": "spacer", "visible": true})

func _add_action(icon_kind: String, label_text: String, cost: Dictionary, action_type: String, callback: Callable) -> void:
	var description := ""
	if action_type == "train" and GameData.UNITS.has(icon_kind):
		var source_landmark: String = game.selected[0].landmark_id if not game.selected.is_empty() and game.selected[0] is RtsBuilding else ""
		var unit_stats := RtsUnitCatalog.unit_definition(game.civilizations[0], icon_kind, game.players[0]["researched"], game.players[0]["age"], game.players[0]["landmarks"], game.players[0].get("dynasty", ""), source_landmark)
		var profile: Dictionary = unit_stats.get("profiles", {}).get(unit_stats.get("primary_profile", ""), {})
		var train_seconds: float = game.selected[0]._training_time(icon_kind) if not game.selected.is_empty() and game.selected[0] is RtsBuilding else GameData.training_time(game.civilizations[0], "", icon_kind)
		description = ("%s\n生命 %.0f · 攻击 %d×%.0f · 训练 %.1f 秒" % [str(UNIT_HELP.get(icon_kind, "训练并指挥此单位。")), float(unit_stats.get("hp", 0.0)), int(profile.get("hits", 1)), float(profile.get("damage", 0.0)), train_seconds])
	elif action_type == "research":
		var technology: Dictionary = RtsTechTree.get_technology(icon_kind)
		description = (_research_description(icon_kind, technology))
	elif action_type == "build":
		description = (str(BUILD_HELP.get(icon_kind, "建造此建筑。")))
	elif action_type == "landmark":
		description = (str(RtsLandmarkCatalog.landmark(icon_kind).get("description", "建造地标并解锁时代能力。")))
	elif action_type == "convert_gate":
		description = ("将现有城墙改建为可供友军通行的城门。")
	elif COMMAND_HELP.has(icon_kind):
		description = (str(COMMAND_HELP[icon_kind]))
	elif GameData.RESOURCE_LABELS.has(icon_kind):
		description = ("设置商人贸易所得的%s。" % GameData.RESOURCE_LABELS[icon_kind])
	elif action_type == "unit_ability":
		description = ("让选中单位使用此能力。")
	var id := register(action_type, icon_kind, KEY_NONE, callback)
	descriptors.append({"view": "command", "id": id, "kind": icon_kind, "label": label_text, "description": description, "cost": cost, "keycode": KEY_NONE, "type": action_type, "visible": true})

func _side_action(symbol: String, description: String, callback: Callable, direction := 0) -> Dictionary:
	return {"view": "side", "id": register("order", "page" if direction != 0 else "side", KEY_NONE, callback), "symbol": symbol, "description": description, "direction": direction, "keycode": KEY_NONE, "side_order": 0 if direction <= 0 else 1, "visible": true}

# Twelve command slots plus a fixed stop and page-navigation column. Hidden
# commands retain their descriptors for inspection but cannot be executed.
func _layout_commands() -> void:
	var commands := descriptors.duplicate()
	var stop: Dictionary = {}
	for command in commands:
		if command.get("kind", "") == "stop":
			stop = command
			commands.erase(command)
			break
	var is_build_page := not current_build_pages.is_empty()
	var page_count := current_build_pages.size() if is_build_page else maxi(1, ceili(float(commands.size()) / COMMANDS_PER_PAGE))
	command_page = clampi(command_page, 0, page_count - 1)
	var page_index: int = game.build_page if is_build_page else command_page
	var first := 0 if is_build_page else command_page * COMMANDS_PER_PAGE
	var visible_commands: Array[Dictionary] = []
	for index in commands.size():
		commands[index]["visible"] = index >= first and index < first + COMMANDS_PER_PAGE
		if commands[index].has("id"): set_active(commands[index]["id"], commands[index]["visible"])
		if commands[index]["visible"]: visible_commands.append(commands[index])
	while visible_commands.size() < COMMANDS_PER_PAGE:
		var spacer := {"view": "spacer", "visible": true}
		descriptors.append(spacer)
		visible_commands.append(spacer)
	var navigation := {"view": "spacer", "visible": true}
	var middle := {"view": "spacer", "visible": true}
	if page_count > 1 and (is_build_page or game.selected[0] is RtsBuilding):
		for direction in [-1, 1]:
			var next_index := posmod(page_index + direction, page_count)
			var hint := "上一页" if direction == -1 else "下一页"
			if is_build_page: hint += "：%s → %s" % [current_build_pages[page_index]["title"], current_build_pages[next_index]["title"]]
			else: hint += "（%d/%d）" % [page_index + 1, page_count]
			var arrow := _side_action("", hint, func() -> void:
				if is_build_page: game.build_page = next_index
				else: command_page = next_index
				rebuild()
			, direction)
			if direction == -1: middle = arrow
			else: navigation = arrow
	elif page_count > 1:
		navigation = _side_action("⋯", "更多命令（%d/%d）" % [page_index + 1, page_count], func() -> void:
			command_page = posmod(command_page + 1, page_count)
			rebuild()
		)
	if stop.is_empty():
		stop = _side_action("■", "停止选中单位当前的命令", func() -> void: game._stop_selected_units()) if game.selected[0] is RtsUnit else {"view": "spacer", "visible": true}
	stop["side_order"] = 2
	var side := [stop, middle, navigation]
	for command in side:
		if not descriptors.any(func(existing: Dictionary) -> bool: return is_same(existing, command)): descriptors.append(command)
	# Rendering order is a separate value; command registration order stays stable
	# so button/tool inspection remains compatible with selection action order.
	for index in descriptors.size(): descriptors[index]["slot"] = 15 + index
	for row in 3:
		for column in 4: visible_commands[row * 4 + column]["slot"] = row * 5 + column
		side[row]["slot"] = row * 5 + 4
	# Bind after pagination: every visible position has one key on every page.
	hotkeys.clear()
	for command in descriptors:
		if command.has("id"): command["keycode"] = KEY_NONE
	for index in visible_commands.size():
		_bind_command_key(visible_commands[index], GRID_KEYS[index])
	for row in side.size():
		_bind_command_key(side[row], SIDE_KEYS[row])

func _bind_command_key(command: Dictionary, keycode: int) -> void:
	if not command.has("id"): return
	command["keycode"] = keycode
	hotkeys[keycode] = command["id"]

func _research_description(kind: String, technology: Dictionary) -> String:
	var purpose := ""
	if technology.has("rank_unit"):
		purpose = "将此兵种升级到更高等级，提升战斗属性。"
	elif kind == "military_academy":
		purpose = "军事单位的训练时间缩短 25%。"
	elif kind == "enclosures":
		purpose = "英格兰村民在农田工作时持续获得黄金。"
	elif technology.get("economy", false):
		var resource: String = GameData.RESOURCE_LABELS.get(technology.get("gather_kind", ""), "资源")
		var bonus := roundi((float(technology.get("gather_multiplier", 1.0)) - 1.0) * 100.0)
		purpose = "%s采集效率提高 %d%%。" % [resource, bonus]
	else:
		var targets: Array = technology.get("target_tags", [])
		var target_label := "相关单位"
		if targets.has("naval"): target_label = "船只"
		elif targets.has("siege"): target_label = "攻城器械"
		elif targets.has("cavalry"): target_label = "骑兵"
		elif targets.has("infantry"): target_label = "步兵"
		elif targets.has("ranged"): target_label = "远程单位"
		var effects: Array[String] = []
		for stat in technology.get("effects", {}):
			effects.append("%s +%.0f" % [str(STAT_LABELS.get(stat, stat)), float(technology["effects"][stat])])
		purpose = "提高%s属性：%s。" % [target_label, "、".join(effects)] if not effects.is_empty() else "强化相关单位。"
	var lines: Array[String] = [purpose, "研究时间：%.0f 秒" % float(technology.get("time", 0.0))]
	var prerequisites: Array[String] = []
	for required in technology.get("requires", []): prerequisites.append(str(RtsTechTree.get_technology(str(required)).get("label", required)))
	if not prerequisites.is_empty(): lines.append("前置科技：%s" % "、".join(prerequisites))
	return "\n".join(lines)

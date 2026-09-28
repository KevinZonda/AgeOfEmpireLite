class_name RtsGameHudUi
extends CanvasLayer

# Owns the HUD tree and renders command state from the game root.
const BUILD_HELP := {
	"town_center": "训练村民并提供人口上限，也可驻军防守。",
	"house": "提高人口上限，让你能训练更多单位。",
	"farm": "供村民持续采集食物。",
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
var game: Node2D
var build_tab_bar: HBoxContainer
var command_page := 0
var command_selection_id := 0

func _init(game_ref: Node2D) -> void:
	game = game_ref

func _create_hud() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	root.size = game.get_viewport_rect().size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	game.ui_root = root
	game.menu_backdrop = game.MENU_BACKDROP.new()
	game.menu_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game.menu_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(game.menu_backdrop)
	var top := PanelContainer.new()
	game.hud_top = top
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 66
	top.add_theme_stylebox_override("panel", game._hud_panel_style(Color("251e17"), 8))
	root.add_child(top)
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 5)
	top.add_child(top_row)
	game.top_label = Label.new()
	game.top_label.custom_minimum_size.x = 170
	game.top_label.add_theme_font_size_override("font_size", 16)
	game.top_label.add_theme_color_override("font_color", Color("f4dfaa"))
	game.top_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top_row.add_child(game.top_label)
	for kind in ["food", "wood", "gold", "stone"]:
		game._add_resource_readout(top_row, kind)
	game.population_label = Label.new()
	game.population_label.custom_minimum_size.x = 102
	game.population_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	game.population_label.add_theme_font_size_override("font_size", 15)
	game.population_label.add_theme_color_override("font_color", Color("eee2c7"))
	top_row.add_child(game.population_label)
	var top_tools := HBoxContainer.new()
	top_tools.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_tools.alignment = BoxContainer.ALIGNMENT_END
	top_tools.add_theme_constant_override("separation", 5)
	top_row.add_child(top_tools)
	var global_queue_button := Button.new()
	global_queue_button.text = "队列 [F]"
	game._style_button(global_queue_button)
	global_queue_button.pressed.connect(_toggle_global_queue)
	top_tools.add_child(global_queue_button)
	game.idle_villager_button = Button.new()
	game.idle_villager_button.text = "村民 0"
	game._style_button(game.idle_villager_button)
	game.idle_villager_button.tooltip_text = "选中下一个空闲村民（句号键）"
	game.idle_villager_button.pressed.connect(game._select_next_idle_villager)
	top_tools.add_child(game.idle_villager_button)
	game.view_button = Button.new()
	game.view_button.text = "2.5D 视角"
	game._style_button(game.view_button)
	game.view_button.pressed.connect(func() -> void: game._toggle_view_mode(true))
	top_tools.add_child(game.view_button)
	game.global_queue_panel = PanelContainer.new()
	game.global_queue_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	game.global_queue_panel.offset_left = -390
	game.global_queue_panel.offset_right = -8
	game.global_queue_panel.offset_top = 70
	game.global_queue_panel.offset_bottom = 415
	game.global_queue_panel.add_theme_stylebox_override("panel", game._hud_panel_style(Color("2c241b"), 12))
	root.add_child(game.global_queue_panel)
	var queue_scroll := ScrollContainer.new()
	game.global_queue_panel.add_child(queue_scroll)
	game.global_queue_list = VBoxContainer.new()
	game.global_queue_list.custom_minimum_size.x = 350
	queue_scroll.add_child(game.global_queue_list)
	game.global_queue_panel.hide()
	var bottom := PanelContainer.new()
	game.hud_bottom = bottom
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -244
	bottom.add_theme_stylebox_override("panel", game._hud_panel_style(Color("241d16"), 7))
	root.add_child(bottom)
	var dock := HBoxContainer.new()
	dock.add_theme_constant_override("separation", 9)
	bottom.add_child(dock)
	var command_panel := PanelContainer.new()
	command_panel.custom_minimum_size.x = 300
	command_panel.add_theme_stylebox_override("panel", game._hud_panel_style(Color("30261b"), 7))
	dock.add_child(command_panel)
	var command_column := VBoxContainer.new()
	command_column.add_theme_constant_override("separation", 6)
	command_panel.add_child(command_column)
	var command_header := HBoxContainer.new()
	command_header.add_theme_constant_override("separation", 4)
	command_column.add_child(command_header)
	game.command_title = Label.new()
	game.command_title.text = "命令"
	game.command_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game.command_title.add_theme_font_size_override("font_size", 17)
	game.command_title.add_theme_color_override("font_color", Color("e8cb85"))
	command_header.add_child(game.command_title)
	build_tab_bar = HBoxContainer.new()
	build_tab_bar.add_theme_constant_override("separation", 3)
	build_tab_bar.hide()
	command_header.add_child(build_tab_bar)
	var action_scroll := ScrollContainer.new()
	action_scroll.custom_minimum_size = Vector2(280, 172)
	action_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	action_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	action_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	command_column.add_child(action_scroll)
	game.action_bar = GridContainer.new()
	game.action_bar.columns = 4
	game.action_bar.add_theme_constant_override("h_separation", 6)
	game.action_bar.add_theme_constant_override("v_separation", 5)
	action_scroll.add_child(game.action_bar)
	var selection_panel := PanelContainer.new()
	selection_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection_panel.add_theme_stylebox_override("panel", game._hud_panel_style(Color("30271c"), 8))
	dock.add_child(selection_panel)
	var selection_row := HBoxContainer.new()
	selection_row.add_theme_constant_override("separation", 10)
	selection_panel.add_child(selection_row)
	game.selection_portrait = game.SELECTION_PORTRAIT.new()
	game.selection_portrait.custom_minimum_size = Vector2(102, 142)
	selection_row.add_child(game.selection_portrait)
	var selection_column := VBoxContainer.new()
	selection_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection_column.add_theme_constant_override("separation", 4)
	selection_row.add_child(selection_column)
	game.info_label = Label.new()
	game.info_label.text = "未选择"
	game.info_label.add_theme_font_size_override("font_size", 19)
	game.info_label.add_theme_color_override("font_color", Color("f0dfb6"))
	selection_column.add_child(game.info_label)
	game.detail_label = Label.new()
	game.detail_label.text = "左键选择 · 右键下令"
	game.detail_label.add_theme_font_size_override("font_size", 14)
	game.detail_label.add_theme_color_override("font_color", Color("d3c5a8"))
	game.detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	game.detail_label.custom_minimum_size.x = 420
	game.detail_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var detail_scroll := ScrollContainer.new()
	detail_scroll.custom_minimum_size.y = 50
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	selection_column.add_child(detail_scroll)
	detail_scroll.add_child(game.detail_label)
	game.selection_health = ProgressBar.new()
	game.selection_health.show_percentage = false
	game.selection_health.custom_minimum_size = Vector2(285, 11)
	game.selection_health.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game._style_progress_bar(game.selection_health, Color("80ad68"))
	game.selection_health.hide()
	selection_column.add_child(game.selection_health)
	game.selection_progress = ProgressBar.new()
	game.selection_progress.show_percentage = false
	game.selection_progress.custom_minimum_size = Vector2(285, 9)
	game.selection_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game._style_progress_bar(game.selection_progress, Color("d4af62"))
	game.selection_progress.hide()
	selection_column.add_child(game.selection_progress)
	game.queue_label = Label.new()
	game.queue_label.add_theme_font_size_override("font_size", 13)
	game.queue_label.add_theme_color_override("font_color", Color("e5d1a1"))
	selection_column.add_child(game.queue_label)
	game.queue_controls = HBoxContainer.new()
	game.queue_controls.hide()
	selection_column.add_child(game.queue_controls)
	game.queue_choice = OptionButton.new()
	game.queue_choice.custom_minimum_size.x = 205
	game._style_button(game.queue_choice)
	game.queue_controls.add_child(game.queue_choice)
	game.cancel_queue_button = Button.new()
	game.cancel_queue_button.text = "取消并退款"
	game._style_button(game.cancel_queue_button)
	game.cancel_queue_button.pressed.connect(game._cancel_selected_job)
	game.queue_controls.add_child(game.cancel_queue_button)
	game.notice_label = Label.new()
	game.notice_label.add_theme_color_override("font_color", Color("f0d783"))
	game.notice_label.add_theme_font_size_override("font_size", 13)
	selection_column.add_child(game.notice_label)
	var map_panel := PanelContainer.new()
	map_panel.custom_minimum_size.x = 180
	map_panel.add_theme_stylebox_override("panel", game._hud_panel_style(Color("30261b"), 7))
	dock.add_child(map_panel)
	game.minimap = RtsMinimap.new()
	map_panel.add_child(game.minimap)
	game.minimap.setup(game)

	game.menu_panel = PanelContainer.new()
	game.menu_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	game.menu_panel.custom_minimum_size = Vector2(1050, 610)
	game.menu_panel.offset_left = -525
	game.menu_panel.offset_top = -305
	game.menu_panel.offset_right = 525
	game.menu_panel.offset_bottom = 305
	game.menu_panel.add_theme_stylebox_override("panel", game._parchment_style(Color("d1bb8c"), 23))
	root.add_child(game.menu_panel)
	game.result_panel = PanelContainer.new()
	game.result_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	game.result_panel.custom_minimum_size = Vector2(400, 220)
	game.result_panel.offset_left = -200
	game.result_panel.offset_top = -110
	game.result_panel.offset_right = 200
	game.result_panel.offset_bottom = 110
	game.result_panel.add_theme_stylebox_override("panel", game._hud_panel_style(Color("30271c"), 18))
	game.result_panel.hide()
	root.add_child(game.result_panel)
	game.pause_overlay = ColorRect.new()
	game.pause_overlay.color = Color(0.08, 0.06, 0.04, 0.72)
	game.pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game.pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	game.pause_overlay.hide()
	root.add_child(game.pause_overlay)
	var pause_panel := PanelContainer.new()
	pause_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	pause_panel.custom_minimum_size = Vector2(380, 340)
	pause_panel.offset_left = -190
	pause_panel.offset_top = -170
	pause_panel.offset_right = 190
	pause_panel.offset_bottom = 170
	pause_panel.add_theme_stylebox_override("panel", game._hud_panel_style(Color("30271c"), 20))
	game.pause_overlay.add_child(pause_panel)
	var pause_box := VBoxContainer.new()
	pause_box.add_theme_constant_override("separation", 12)
	pause_panel.add_child(pause_box)
	game._add_menu_label(pause_box, "游戏已暂停", 27)
	game._add_menu_label(pause_box, "按 Esc 继续游戏", 16)
	game._add_pause_button(pause_box, "继续游戏", func() -> void: game._set_paused(false))
	game._add_pause_button(pause_box, "设置", func() -> void: game._show_settings(true))
	game._add_pause_button(pause_box, "重新开始", func() -> void: game.start_game(game.selected_civ, -1, game.selected_opponent_civ))
	game._add_pause_button(pause_box, "返回主界面", func() -> void: game._return_to_menu())
	game._add_pause_button(pause_box, "退出游戏", func() -> void: game.get_tree().quit())
	game._create_settings(root)

func _update_hud() -> void:
	if game.top_label == null or game.players.is_empty(): return
	game._prune_hidden_enemy_selection()
	if game.global_queue_panel.visible: _refresh_global_queue_panel()
	_update_population_hud()
	_refresh_action_buttons()
	_update_selection_hud()

func _update_population_hud() -> void:
	var bank: Dictionary = game.players[0]
	var dynasty_text := " · %s朝" % RtsLandmarkCatalog.DYNASTY_NAMES[bank["dynasty"]] if bank["dynasty"] != "" else ""
	var used: int = game.population_used(0)
	var capacity: int = game.population_cap(0)
	var age_names := ["", "黑暗时代", "封建时代", "城堡时代", "帝王时代"]
	game.top_label.text = "%s\n%s · %s%s" % [GameData.CIVILIZATIONS[game.civilizations[0]]["label"], age_names[clampi(bank["age"], 1, 4)], ["", "I", "II", "III", "IV"][clampi(bank["age"], 1, 4)], dynasty_text]
	for kind in ["food", "wood", "gold", "stone"]:
		game.resource_readouts[kind].text = str(bank[kind])
	game.population_label.text = "人口\n%d / %d" % [used, capacity]
	game.population_label.tooltip_text = "空余 %d" % maxi(0, capacity - used)
	var idle_count: int = game.idle_villagers().size()
	game.idle_villager_button.text = "村民 %d" % idle_count
	game.idle_villager_button.disabled = idle_count == 0

func _update_selection_hud() -> void:
	game.selection_health.hide()
	game.selection_progress.hide()
	game.queue_label.text = ""
	game.queue_controls.hide()
	if game.selected.is_empty() or not is_instance_valid(game.selected[0]):
		game.selection_portrait.show_subject(null)
		game.info_label.text = "未选择"
		game.detail_label.text = "左键选择 · 双击同型单位 · 右键下令 · Esc 暂停"
		return
	var item: Node2D = game.selected[0]
	game.selection_portrait.show_subject(item, Color("b6a877") if item is RtsResource else game.player_color(item.owner_id))
	if item is RtsResource:
		game.info_label.text = _resource_label(item)
		game.detail_label.text = "资源类型  %s\n采集单位  %s\n当前状态  %s" % [GameData.RESOURCE_LABELS.get(item.kind, item.kind), "渔船" if item.appearance == "fish" else "村民", _resource_status(item)]
		game.selection_progress.max_value = maxi(1, item.initial_amount)
		game.selection_progress.value = item.amount
		game.selection_progress.show()
		game.queue_label.text = "剩余 %d / %d" % [item.amount, item.initial_amount]
		return
	if game.selected.size() > 1:
		game.info_label.text = "已选中 %d 个单位" % game.selected.size()
		var counts: Dictionary = {}
		for entity in game.selected:
			if not is_instance_valid(entity): continue
			var label_text: String = GameData.UNITS[entity.kind]["label"] if entity is RtsUnit else entity.display_label()
			counts[label_text] = counts.get(label_text, 0) + 1
		var parts: Array[String] = []
		for label_text in counts: parts.append("%s ×%d" % [label_text, counts[label_text]])
		game.detail_label.text = "  ".join(parts)
		return
	var name: String = GameData.UNITS[item.kind]["label"] if item is RtsUnit else item.display_label()
	game.info_label.text = "敌方 · %s" % name if game.is_enemy(0, item.owner_id) else name
	game.selection_health.max_value = item.max_hp
	game.selection_health.value = maxf(0.0, item.hp)
	game.selection_health.show()
	if item is RtsUnit:
		game.detail_label.text = _unit_stats_text(item)
		if item.field_build_remaining > 0.0:
			game.selection_progress.max_value = item.field_build_total
			game.selection_progress.value = item.field_build_total - item.field_build_remaining
			game.selection_progress.show()
			game.queue_label.text = "野外建造 %d%%" % roundi(100.0 * game.selection_progress.value / game.selection_progress.max_value)
		if item.kind in ["transport_ship", "battering_ram", "siege_tower"]: game.detail_label.text += "   乘员 %d/%d" % [item.passengers.size(), 10 if item.kind == "siege_tower" else 8]
		if item.kind == "trader": game.detail_label.text += "   右键贸易站往返交易"
		if item.kind == "monk": game.detail_label.text += "   携带圣物" if item.carried_relic != null else "   可占圣地、拾取圣物"
		if item.kind == "fishing_boat": game.detail_label.text += "   右键鱼群捕鱼"
	else:
		game.detail_label.text = "生命 %.0f/%.0f   %s" % [item.hp, item.max_hp, "建造中" if not item.is_complete() else "已建成"]
		if item.kind == "monastery": game.detail_label.text += "   圣物 %d（每 4 秒每件 +12 黄金）" % item.relics.size()
		if not item.garrisoned_units.is_empty(): game.detail_label.text += "   驻军 %d/%d" % [item.garrisoned_units.size(), item.garrison_capacity()]
		if item.is_complete() and RtsTechTree.PRODUCTION.has(item.producer_kind()):
			game.detail_label.text += "   右键设置集结点"
		_update_building_progress(item)
		_refresh_queue_controls(item)

func _resource_label(resource: RtsResource) -> String:
	return {"berry": "浆果", "deer": "鹿", "sheep": "绵羊", "boar": "野猪", "fish": "鱼群"}.get(resource.appearance, {"wood": "树木", "gold": "金矿", "stone": "石矿"}.get(resource.kind, GameData.RESOURCE_LABELS.get(resource.kind, resource.kind)))

func _resource_status(resource: RtsResource) -> String:
	if resource.appearance == "boar" and resource.wildlife_hp > 0.0: return "野猪存活 · 生命 %.0f/90" % resource.wildlife_hp
	if resource.appearance == "sheep":
		if resource.claimed_by < 0: return "尚未认领"
		return "我方已认领" if resource.claimed_by == 0 else "敌方已认领"
	return "可采集"

func _resource_guide(resource: RtsResource) -> String:
	match resource.appearance:
		"boar": return "先选中可攻击的单位，右键攻击野猪。击杀后选中村民，右键采集。"
		"sheep": return "让侦察兵靠近羊群认领，再选中村民右键采集。"
		"fish": return "选中渔船，右键点击鱼群捕鱼。"
		"deer": return "选中村民，右键点击鹿群狩猎；鹿会躲避靠近的军队。"
	return "选中村民，右键点击%s采集%s。" % [_resource_label(resource), GameData.RESOURCE_LABELS.get(resource.kind, resource.kind)]

func _update_building_progress(building: RtsBuilding) -> void:
	if not building.is_complete():
		game.selection_progress.max_value = maxf(0.1, building.build_total)
		game.selection_progress.value = building.build_total - building.build_remaining
		game.selection_progress.show()
		game.queue_label.text = "施工 %d%% · 村民 %d · 选村民右键继续" % [int(100.0 * game.selection_progress.value / game.selection_progress.max_value), game.count_builders(building)]
	elif not building.production_queue.is_empty():
		var job: Dictionary = building.current_job()
		game.selection_progress.max_value = job["time"]
		game.selection_progress.value = job["time"] - job["remaining"]
		game.selection_progress.show()
		game.queue_label.text = "%s   队列 %d" % [_job_label(job), building.production_queue.size()]

func _unit_stats_text(unit: RtsUnit) -> String:
	var stats: Dictionary = unit.stats
	var armor: Dictionary = stats.get("armor", {})
	var resistance: Dictionary = stats.get("resistance", {})
	var rank: int = int(stats.get("rank_age", 0))
	var lines: Array[String] = ["生命 %.0f/%.0f  ·  近甲 %.0f  ·  远甲 %.0f  ·  移速 %.2f 格/秒%s" % [unit.hp, unit.max_hp, float(armor.get("melee", 0.0)), float(armor.get("ranged", 0.0)), unit.effective_speed() / 80.0, "  ·  等级 %d" % rank if rank > 0 else ""]]
	if stats.get("tags", []).has("military"):
		lines.append("交战规则：%s" % {"aggressive": "主动追击", "defensive": "短距防御", "passive": "只响应手动攻击"}.get(unit.engagement, unit.engagement))
	if float(resistance.get("ranged", 0.0)) > 0.0: lines.append("远程减伤 %.0f%%" % (float(resistance["ranged"]) * 100.0))
	if RtsCivilizationRules.english_network_rate(game, unit) > 1.0: lines.append("城堡网络：攻击速度 +20%")
	if is_instance_valid(unit.wall_host): lines.append("正在石墙上驻守  ·  远程护甲 +2")
	var profiles: Dictionary = stats.get("profiles", {})
	for profile_id in profiles:
		var profile: Dictionary = profiles[profile_id]
		if float(profile.get("damage", 0.0)) <= 0.0: continue
		var label_text: String = {"melee": "近战", "ranged": "远程", "siege": "攻城", "charge": "冲锋", "structure": "对建筑", "torch": "火炬", "hunt_melee": "狩猎近战", "hunt_ranged": "狩猎远程"}.get(profile_id, str(profile_id))
		var description := "%s %d×%.0f  ·  间隔 %.2f 秒  ·  射程 %.1f 格" % [label_text, int(profile.get("hits", 1)), float(profile["damage"]), float(profile.get("cooldown", 1.0)), float(profile.get("range", 0.0)) / 30.0]
		for bonus in profile.get("bonuses", []): description += "  ·  %s +%.0f" % [bonus.get("source_label", "加成"), float(bonus.get("amount", 0.0))]
		lines.append(description)
	if unit.kind in ["villager", "fishing_boat"]:
		# Keep work information in the first visible line of the compact details pane.
		if unit.order == "gather" and is_instance_valid(unit.target):
			var resource_kind: String = "food" if unit.target is RtsBuilding else unit.target.kind
			var source_label: String = GameData.RESOURCE_LABELS.get(resource_kind, resource_kind)
			if unit.target is RtsBuilding:
				source_label = "农田"
			elif resource_kind == "food":
				source_label = {"berry": "浆果", "deer": "鹿肉", "sheep": "羊肉", "boar": "野猪肉", "fish": "鱼群"}.get(unit.target.appearance, source_label)
			lines.insert(0, "采集%s  ·  工作速度 %.2f/秒" % [source_label, unit.gathering_per_second()])
		else:
			lines.insert(0, "未采集资源  ·  工作速度 0.00/秒")
	if unit.kind == "trader" and game.civilizations[unit.owner_id] == "French": lines.append("贸易运回：%s" % GameData.RESOURCE_LABELS[unit.trade_resource_kind])
	return "\n".join(lines)

func _job_label(job: Dictionary) -> String:
	match job["type"]:
		"train": return "训练：%s" % GameData.UNITS[job["kind"]]["label"]
		"research": return "研究：%s" % RtsTechTree.get_technology(job["kind"])["label"]
		"age": return "升级到时代 %d" % job["target_age"]
	return "未知任务"

func _refresh_queue_controls(building: RtsBuilding) -> void:
	if building.owner_id != 0 or building.production_queue.is_empty(): return
	game.queue_controls.show()
	var previous: int = game.queue_choice.get_selected_id()
	var needs_rebuild: bool = game.queue_choice.item_count != building.production_queue.size()
	if not needs_rebuild:
		for index in building.production_queue.size():
			if game.queue_choice.get_item_text(index) != "%d. %s" % [index + 1, _job_label(building.production_queue[index])]:
				needs_rebuild = true
				break
	if not needs_rebuild: return
	game.queue_choice.clear()
	for index in building.production_queue.size():
		game.queue_choice.add_item("%d. %s" % [index + 1, _job_label(building.production_queue[index])], index)
	game.queue_choice.select(clampi(previous, 0, building.production_queue.size() - 1))

func _toggle_global_queue() -> void:
	game.global_queue_panel.visible = not game.global_queue_panel.visible
	if game.global_queue_panel.visible: _refresh_global_queue_panel()

func _refresh_global_queue_panel() -> void:
	for child in game.global_queue_list.get_children(): child.queue_free()
	var heading := Label.new()
	heading.text = "全局生产队列 · 点击定位建筑"
	game.global_queue_list.add_child(heading)
	var count := 0
	for building in game.buildings:
		if not is_instance_valid(building) or building.owner_id != 0 or building.production_queue.is_empty(): continue
		for index in building.production_queue.size():
			var job: Dictionary = building.production_queue[index]
			var row := HBoxContainer.new()
			game.global_queue_list.add_child(row)
			var locate := Button.new()
			locate.text = "%s · %s%s" % [building.display_label(), _job_label(job), " %.0fs" % building.production_remaining if index == 0 else ""]
			locate.custom_minimum_size.x = 275
			locate.pressed.connect(func() -> void:
				if not is_instance_valid(building): return
				game.selected.clear()
				game.selected.append(building)
				game.camera.position = building.position
				_rebuild_actions()
				_update_hud()
			)
			row.add_child(locate)
			var cancel := Button.new()
			cancel.text = "×"
			cancel.pressed.connect(func() -> void:
				if is_instance_valid(building): game.cancel_production_job(building, index)
				_refresh_global_queue_panel()
			)
			row.add_child(cancel)
			count += 1
	if count == 0:
		var empty := Label.new()
		empty.text = "当前没有训练、研究或升级任务"
		game.global_queue_list.add_child(empty)

func _refresh_action_buttons() -> void:
	if game.players.is_empty(): return
	var producer := ""
	var complete := true
	var landmark_id := ""
	var landmark_cooldown := 0.0
	var landmark_stockpile := {}
	var ability_ready := {}
	for ability in game.UNIT_ABILITY_ACTIONS: ability_ready[ability["id"]] = false
	var ability_reason := {"convert": "需要携带圣物"}
	var camp_count := 0
	for building in game.buildings:
		if is_instance_valid(building) and building.owner_id == 0 and building.kind == "scout_camp": camp_count += 1
	for selection in game.selected:
		if not is_instance_valid(selection) or not selection is RtsUnit: continue
		if selection.kind == "longbow":
			if selection.paling_cooldown <= 0.0: ability_ready["palings"] = true
			if selection.volley_cooldown <= 0.0: ability_ready["volley"] = true
		if selection.kind == "arbaletrier": ability_ready["pavise"] = true
		if selection.kind == "warship" and selection.helm_cooldown <= 0.0: ability_ready["helmsman"] = true
		if selection.kind == "cannon" and selection.producer_landmark_id == "fr_college_of_artillery" and selection.artillery_shot_cooldown <= 0.0: ability_ready["artillery_shot"] = true
		if selection.kind == "monk":
			if selection.carried_relic != null and selection.conversion_cooldown <= 0.0: ability_ready["convert"] = true
			elif selection.carried_relic != null: ability_reason["convert"] = "技能冷却中"
		if game.civilizations[0] == "English" and selection.kind in ["scout", "man_at_arms"] and camp_count < 5: ability_ready["camp"] = true
	if not game.selected.is_empty() and is_instance_valid(game.selected[0]) and game.selected[0] is RtsBuilding:
		producer = game.selected[0].producer_kind()
		complete = game.selected[0].is_complete()
		landmark_id = game.selected[0].landmark_id
		landmark_cooldown = game.selected[0].landmark_ability_cooldown
		landmark_stockpile = game.selected[0].landmark_stockpile
	var context := {
		"civilization": game.civilizations[0], "age": game.players[0]["age"], "dynasty": game.players[0].get("dynasty", ""), "producer": producer,
		"researched": game.players[0]["researched"], "queued_research": game.queued_research(0),
		"landmarks": game.players[0]["landmarks"], "active_landmark": game.active_landmark_id(0),
		"has_wonder": _has_wonder(0),
		"resources": game.players[0], "population_used": game.population_used(0), "population_cap": game.population_cap(0),
		"production_complete": complete,
		"landmark_id": landmark_id, "landmark_cooldown": landmark_cooldown, "landmark_stockpile": landmark_stockpile,
		"ability_ready": ability_ready, "ability_reason": ability_reason, "camp_count": camp_count,
		"producer_building": game.selected[0] if not game.selected.is_empty() and game.selected[0] is RtsBuilding else null, "game": game,
	}
	for button in game.command_buttons:
		if not is_instance_valid(button) or button.is_queued_for_deletion(): continue
		var action_type: String = button.get_meta("action_type")
		var action_kind: String = button.get_meta("action_kind")
		var status := RtsActionAvailability.evaluate(action_type, action_kind, context)
		if action_type in ["train", "research"] and game.selected.size() > 1:
			for candidate in game.selected:
				if not is_instance_valid(candidate) or not candidate is RtsBuilding or candidate.owner_id != 0: continue
				var candidate_context: Dictionary = context.duplicate()
				candidate_context["producer"] = candidate.producer_kind()
				candidate_context["production_complete"] = candidate.is_complete()
				candidate_context["producer_building"] = candidate
				var candidate_status := RtsActionAvailability.evaluate(action_type, action_kind, candidate_context)
				if candidate_status["available"]:
					status = candidate_status
					break
		button.set_availability(status["available"], status["reason"], status["cost"])

func _has_wonder(owner_id: int) -> bool:
	for building in game.buildings:
		if is_instance_valid(building) and building.owner_id == owner_id and building.kind == "wonder": return true
	return false

func _rebuild_actions() -> void:
	if game.action_bar == null: return
	for child in game.action_bar.get_children():
		game.action_bar.remove_child(child)
		child.queue_free()
	game.command_buttons.clear()
	game.hotkey_buttons.clear()
	game.command_title.text = "命令"
	build_tab_bar.hide()
	if game.selected.is_empty() or not is_instance_valid(game.selected[0]):
		command_page = 0
		command_selection_id = 0
		return
	var item: Node2D = game.selected[0]
	var selection_id := item.get_instance_id()
	if selection_id != command_selection_id:
		command_page = 0
		command_selection_id = selection_id
	game.action_bar.columns = 4
	if item is RtsResource:
		game.command_title.text = "采集方式"
		game.action_bar.columns = 1
		var guide := Label.new()
		guide.text = _resource_guide(item)
		guide.custom_minimum_size.x = 270
		guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		guide.add_theme_font_size_override("font_size", 15)
		guide.add_theme_color_override("font_color", Color("e9dbbd"))
		game.action_bar.add_child(guide)
		return
	if item.owner_id != 0:
		game.command_title.text = "敌方单位 · 情报"
		return
	if item is RtsUnit: _build_unit_actions(item)
	elif item is RtsBuilding: _build_building_actions(item)
	_refresh_action_buttons()
	if not build_tab_bar.visible: _paginate_actions()

func _build_unit_actions(item: RtsUnit) -> void:
	var keys := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9]
	var action_index := 0
	var any_worker := false
	var any_military := false
	var any_special := false
	var worker_count := 0
	var military_count := 0
	for unit in game.selected:
		if not is_instance_valid(unit) or not unit is RtsUnit: continue
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
		game.command_title.text = "村民 · 建造"
		_show_build_tabs(pages)
		for kind in page["kinds"]:
			if kind.is_empty():
				_add_action_spacer()
			elif kind == "age":
				if RtsTechTree.can_advance(game.players[0]["age"]): _add_action("age", "(%s) 升时代" % ["", "II", "III", "IV"][game.players[0]["age"]], {}, KEY_NONE, "order", _show_age_choice)
				else: _add_action_spacer()
			else:
				_add_build_action(kind, keys[action_index] if action_index < keys.size() else KEY_NONE)
			action_index += 1
		if game.civilizations[0] == "Chinese" and game.build_page == 2:
			for choice in RtsLandmarkCatalog.choices_for(game.civilizations[0], game.players[0]["age"], game.players[0]["landmarks"]):
				if int(choice["age"]) > game.players[0]["age"]: continue
				_add_landmark_action(choice, keys[action_index] if action_index < keys.size() else KEY_NONE)
				action_index += 1
	if (any_military or any_special) and not any_worker:
		game.command_title.text = "部队 · 命令"
		if any_military:
			if game.players[0]["age"] >= 3 and game.selected.any(func(chosen: Node2D) -> bool: return chosen is RtsUnit and chosen.stats.get("tags", []).has("infantry") and not chosen.stats.get("tags", []).has("siege")):
				for field_kind in ["field_ram", "field_tower"]:
					var mode_id: String = field_kind
					var label_text := "野外建造攻城槌" if field_kind == "field_ram" else "野外建造攻城塔"
					_add_action(field_kind, label_text, GameData.unit_cost("battering_ram" if field_kind == "field_ram" else "siege_tower"), KEY_NONE, "order", func() -> void:
						game.order_mode = mode_id
						game.notify_player("点击地面指定建造位置")
					)
			if game.selected.any(func(chosen: Node2D) -> bool: return chosen is RtsUnit and chosen.kind in ["mangonel", "nest_of_bees", "trebuchet", "bombard", "cannon"]):
				_add_action("attack_ground", "攻击地面", {}, KEY_NONE, "order", func() -> void:
					game.order_mode = "attack_ground"
					game.notify_player("点击地面指定炮击位置")
				)
			_add_action("attack_move", "攻击移动", {}, KEY_1, "order", func() -> void:
				game.order_mode = "attack_move"
				game.build_mode = ""
				game.notify_player("点击地图攻击移动；Shift 点击连续下令")
			)
			_add_action("patrol", "巡逻", {}, KEY_3, "order", func() -> void:
				game.order_mode = "patrol"
				game.notify_player("点击地图设置巡逻终点")
			)
			_add_action("hold", "坚守", {}, KEY_4, "order", func() -> void:
				for unit in game.selected:
					if is_instance_valid(unit) and unit is RtsUnit: unit.issue_command("hold")
			)
			_add_action("focus", "集火", {}, KEY_5, "order", func() -> void:
				game.order_mode = "focus"
				game.notify_player("点击敌方单位或建筑集火")
			)
			_add_action("retreat", "撤退", {}, KEY_7, "order", func() -> void: game._retreat_selected())
			for shape in ["balanced", "line", "compact", "column"]:
				var shape_id: String = shape
				var shape_label: String = {"balanced": "默认", "line": "横队", "compact": "密集", "column": "纵队"}[shape]
				_add_action("formation", "%s阵型%s" % [shape_label, " ✓" if game.formation_mode == shape else ""], {}, KEY_NONE, "order", func() -> void:
					game.formation_mode = shape_id
					game.notify_player("下一次群体移动采用%s阵型" % shape_label)
					_rebuild_actions()
				)
			_add_action("formation", "队宽 - (%d)" % game.formation_width, {}, KEY_NONE, "order", func() -> void:
				game.formation_width = maxi(2, game.formation_width - 1)
				_rebuild_actions()
			)
			_add_action("formation", "队宽 + (%d)" % game.formation_width, {}, KEY_NONE, "order", func() -> void:
				game.formation_width = mini(8, game.formation_width + 1)
				_rebuild_actions()
			)
			for behavior in ["aggressive", "defensive", "passive"]:
				var behavior_id: String = behavior
				var behavior_label: String = {"aggressive": "主动", "defensive": "防御", "passive": "被动"}[behavior]
				_add_action("stance", "%s交战%s" % [behavior_label, " ✓" if item.engagement == behavior_id else ""], {}, KEY_NONE, "order", func() -> void:
					for chosen in game.selected:
						if is_instance_valid(chosen) and chosen is RtsUnit and chosen.stats.get("tags", []).has("military"): chosen.engagement = behavior_id
					game.notify_player("已设为%s交战" % behavior_label)
					_rebuild_actions()
					_update_hud()
				)
		for ability in game.UNIT_ABILITY_ACTIONS:
			if not _selected_has_ability(ability): continue
			var ability_id: String = ability["id"]
			_add_action(ability_id, ability["label"], {}, KEY_NONE, "unit_ability", func() -> void: game._activate_selected_ability(ability_id))
	if item.kind == "transport_ship":
		_add_action("unload", "登陆", {}, KEY_1, "order", func() -> void:
			game.order_mode = "unload"
			game.notify_player("点击陆地让运输船靠岸并卸载乘员")
		)
	if item.kind in ["battering_ram", "siege_tower"]:
		_add_action("unload", "放出乘员", {}, KEY_NONE, "order", func() -> void:
			for chosen in game.selected:
				if is_instance_valid(chosen) and chosen is RtsUnit and chosen.kind in ["battering_ram", "siege_tower"]: chosen.ungarrison_all()
		)
	if item.kind == "trader" and game.civilizations[0] == "French":
		for resource_kind in ["food", "wood", "gold"]:
			_add_action(resource_kind, "贸易换%s" % GameData.RESOURCE_LABELS[resource_kind], {}, KEY_NONE, "order", func() -> void: game._set_selected_trade_resource(resource_kind))
	if item.kind == "trader":
		_add_action("trade", "恢复贸易", {}, KEY_NONE, "order", func() -> void:
			for chosen in game.selected:
				if is_instance_valid(chosen) and chosen is RtsUnit and chosen.kind == "trader" and is_instance_valid(chosen.trade_post): chosen.issue_command("trade", Vector2.INF, chosen.trade_post)
		)
	if not any_worker: _add_action("stop", "停止", {}, KEY_2, "order", func() -> void: game._stop_selected_units())

func _show_build_tabs(pages: Array) -> void:
	_clear_command_tabs()
	build_tab_bar.show()
	for index in pages.size():
		var tab_index := index
		var tab := Button.new()
		tab.text = pages[index]["title"]
		tab.custom_minimum_size = Vector2(40, 26)
		game._style_button(tab, tab_index == game.build_page)
		tab.pressed.connect(func() -> void:
			game.build_page = tab_index
			_rebuild_actions()
		)
		build_tab_bar.add_child(tab)
	var stop := Button.new()
	stop.text = "■"
	stop.tooltip_text = "停止选中村民当前的命令"
	stop.custom_minimum_size = Vector2(26, 26)
	game._style_button(stop)
	stop.pressed.connect(func() -> void: game._stop_selected_units())
	build_tab_bar.add_child(stop)

func _paginate_actions() -> void:
	var actions: Array[Node] = game.action_bar.get_children()
	var page_count := ceili(float(actions.size()) / COMMANDS_PER_PAGE)
	if page_count <= 1: return
	command_page = clampi(command_page, 0, page_count - 1)
	var first := command_page * COMMANDS_PER_PAGE
	for index in actions.size(): actions[index].visible = index >= first and index < first + COMMANDS_PER_PAGE
	_clear_command_tabs()
	build_tab_bar.show()
	for index in page_count:
		var page_index := index
		var tab := Button.new()
		tab.text = str(index + 1)
		tab.tooltip_text = "命令第 %d 页" % (index + 1)
		tab.custom_minimum_size = Vector2(26, 26)
		game._style_button(tab, index == command_page)
		tab.pressed.connect(func() -> void:
			command_page = page_index
			_rebuild_actions()
		)
		build_tab_bar.add_child(tab)

func _clear_command_tabs() -> void:
	for child in build_tab_bar.get_children():
		build_tab_bar.remove_child(child)
		child.queue_free()

func _selected_has_ability(ability: Dictionary) -> bool:
	if ability.has("civilization") and game.civilizations[0] != ability["civilization"]: return false
	for unit in game.selected:
		if not is_instance_valid(unit) or not unit is RtsUnit or unit.kind not in ability["kinds"]: continue
		if ability.has("producer_landmark") and unit.producer_landmark_id != ability["producer_landmark"]: continue
		return true
	return false

func _build_building_actions(item: RtsBuilding) -> void:
	var keys := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9]
	var action_index := 0
	game.command_title.text = "%s · 训练与研究" % item.display_label()
	if item.kind.ends_with("_wall"):
		var gate_kind := "stone_gate" if item.kind == "stone_wall" else "palisade_gate"
		var resource := "stone" if gate_kind == "stone_gate" else "wood"
		var extra: int = GameData.BUILDINGS[gate_kind]["cost"][resource] - GameData.BUILDINGS[item.kind]["cost"][resource]
		_add_action(gate_kind, "改建城门", {resource: extra}, KEY_1, "convert_gate", func() -> void: game.convert_wall_to_gate(item))
		action_index += 1
	var train_kinds: Array[String] = []
	var research_kinds: Array[String] = []
	for candidate in game.selected:
		if not is_instance_valid(candidate) or not candidate is RtsBuilding or candidate.owner_id != 0: continue
		for kind in RtsTechTree.all_train_units(game.civilizations[0], candidate.producer_kind()):
			if not train_kinds.has(kind): train_kinds.append(kind)
		for kind in RtsTechTree.all_researches(game.civilizations[0], candidate.producer_kind()):
			if not research_kinds.has(kind): research_kinds.append(kind)
	for kind in train_kinds:
		_add_train_action(kind, keys[action_index] if action_index < keys.size() else KEY_NONE)
		action_index += 1
	for kind in research_kinds:
		_add_research_action(kind, keys[action_index] if action_index < keys.size() else KEY_NONE)
		action_index += 1
	if item.kind == "market":
		for resource_kind in ["food", "wood", "stone"]:
			var sell_price: int = game.market_quote(resource_kind, false)
			var buy_price: int = game.market_quote(resource_kind, true)
			var short_name := "粮" if resource_kind == "food" else "木" if resource_kind == "wood" else "石"
			_add_action("market_sell", "卖%s +%d金" % [short_name, sell_price], {}, keys[action_index] if action_index < keys.size() else KEY_NONE, "order", func() -> void: game.exchange_resource(0, resource_kind, false))
			action_index += 1
			_add_action("market_buy", "买%s -%d金" % [short_name, buy_price], {}, keys[action_index] if action_index < keys.size() else KEY_NONE, "order", func() -> void: game.exchange_resource(0, resource_kind, true))
			action_index += 1
	if item.garrison_capacity() > 0:
		_add_action("ungarrison", "放出驻军", {}, keys[action_index] if action_index < keys.size() else KEY_NONE, "order", func() -> void: item.ungarrison_all())
		action_index += 1
	if item.kind == "town_center":
		_add_action("town_bell", "镇钟：村民避险", {}, KEY_NONE, "order", func() -> void: game.ring_town_bell(item))
		_add_action("return_work", "返回原工作", {}, KEY_NONE, "order", func() -> void: item.ungarrison_all(true))
	if item.landmark_id == "fr_guild_hall":
		_add_action("collect_stockpile", "提取公会资源", {}, keys[action_index] if action_index < keys.size() else KEY_NONE, "landmark_ability", func() -> void: item.collect_stockpile())
		action_index += 1
	if item.landmark_id == "zh_imperial_palace":
		_add_action("spy", "侦察敌方村民", {}, keys[action_index] if action_index < keys.size() else KEY_NONE, "landmark_ability", func() -> void: item.activate_landmark_ability())

func _add_build_action(kind: String, keycode: int) -> void:
	var cost: Dictionary = RtsCivilizationRules.building_cost(game.civilizations[0], kind)
	_add_action(kind, GameData.BUILDINGS[kind]["label"], cost, keycode, "build", func() -> void:
		game.build_mode = kind
		game.pending_landmark_id = ""
		game.notify_player("拖拽铺设%s；R 旋转；Shift 连续建造" % GameData.BUILDINGS[kind]["label"] if kind.ends_with("_wall") else "点击地图放置%s；R 旋转墙门；Shift 连续建造" % GameData.BUILDINGS[kind]["label"])
	)

func _add_landmark_action(choice: Dictionary, keycode: int) -> void:
	var choice_id: String = choice["id"]
	_add_action(choice_id, choice["label"], choice["cost"], keycode, "landmark", func() -> void: game._select_landmark_for_placement(choice_id))

func _show_age_choice() -> void:
	if not game.started or game.game_over or game.age_choice_overlay != null: return
	var current_age: int = game.players[0]["age"]
	if not RtsTechTree.can_advance(current_age): return
	var choices: Array[Dictionary] = []
	for choice in RtsLandmarkCatalog.choices_for(game.civilizations[0], current_age, game.players[0]["landmarks"]):
		if int(choice["age"]) == current_age + 1: choices.append(choice)
	if choices.is_empty(): return
	var target_age := current_age + 1
	game.age_choice_overlay = ColorRect.new()
	game.age_choice_overlay.color = Color("100f0d", 0.87)
	game.age_choice_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game.age_choice_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	game.hud_bottom.get_parent().add_child(game.age_choice_overlay)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -310
	panel.offset_right = 310
	panel.offset_top = -190
	panel.offset_bottom = 190
	panel.add_theme_stylebox_override("panel", game._hud_panel_style(Color("30271c"), 18))
	game.age_choice_overlay.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var heading := Label.new()
	heading.text = "选择进入 %s 时代的地标" % ["", "I", "II", "III", "IV"][target_age]
	heading.add_theme_font_size_override("font_size", 23)
	heading.add_theme_color_override("font_color", Color("f3d59c"))
	column.add_child(heading)
	var summary := Label.new()
	summary.text = "%s  ·  升时代费用：%s" % [RtsTechTree.AGE_UNLOCK_TEXT[target_age], GameData.cost_text(RtsTechTree.age_cost(current_age))]
	summary.add_theme_color_override("font_color", Color("e5d1a1"))
	column.add_child(summary)
	var options := HBoxContainer.new()
	options.add_theme_constant_override("separation", 10)
	column.add_child(options)
	for choice in choices:
		var chosen_id: String = choice["id"]
		var button := Button.new()
		button.custom_minimum_size = Vector2(280, 210)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		game._style_button(button)
		var card := VBoxContainer.new()
		card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		card.offset_left = 8
		card.offset_top = 8
		card.offset_right = -8
		card.offset_bottom = -8
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_theme_constant_override("separation", 4)
		button.add_child(card)
		var icon := TextureRect.new()
		icon.texture = RtsCommandButton._texture_at("res://assets/ui/command_icons/%s.png" % chosen_id)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.custom_minimum_size = Vector2(80, 80)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(icon)
		var name_label := Label.new()
		name_label.text = choice["label"]
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_label.add_theme_font_size_override("font_size", 17)
		card.add_child(name_label)
		var effect_label := Label.new()
		effect_label.text = choice["description"]
		effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		effect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		effect_label.custom_minimum_size.y = 48
		effect_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(effect_label)
		var cost_label := Label.new()
		cost_label.text = "建造：%s" % GameData.cost_text(choice["cost"])
		cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(cost_label)
		var status := RtsLandmarkCatalog.choice_status(game.civilizations[0], current_age, game.players[0]["landmarks"], chosen_id, game.active_landmark_id(0))
		button.disabled = not status["available"] or not game.can_afford(0, choice["cost"])
		if button.disabled:
			card.modulate.a = 0.55
			button.tooltip_text = status["reason"] if not status["available"] else "资源不足"
		button.pressed.connect(func() -> void:
			_close_age_choice()
			game._select_landmark_for_placement(chosen_id)
		)
		options.add_child(button)
	var cancel := Button.new()
	cancel.text = "返回"
	cancel.custom_minimum_size.y = 36
	game._style_button(cancel)
	cancel.pressed.connect(_close_age_choice)
	column.add_child(cancel)

func _close_age_choice() -> void:
	if game.age_choice_overlay == null: return
	game.age_choice_overlay.queue_free()
	game.age_choice_overlay = null

func _add_train_action(kind: String, keycode: int) -> void:
	_add_action(kind, GameData.UNITS[kind]["label"], GameData.unit_cost(kind), keycode, "train", func() -> void:
		for candidate in game.selected:
			if is_instance_valid(candidate) and candidate is RtsBuilding and candidate.owner_id == 0 and RtsTechTree.all_train_units(game.civilizations[0], candidate.producer_kind()).has(kind): game.train_unit(candidate, kind)
	)

func _add_research_action(kind: String, keycode: int) -> void:
	var technology: Dictionary = RtsTechTree.get_technology(kind)
	_add_action(kind, technology["label"], technology["cost"], keycode, "research", func() -> void:
		for candidate in game.selected:
			if is_instance_valid(candidate) and candidate is RtsBuilding and candidate.owner_id == 0 and RtsTechTree.all_researches(game.civilizations[0], candidate.producer_kind()).has(kind):
				if game.research_technology(candidate, kind): break
	)

func _add_action_spacer() -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(54, 54)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.action_bar.add_child(spacer)

func _add_action(icon_kind: String, label_text: String, cost: Dictionary, keycode: int, action_type: String, callback: Callable) -> void:
	var button := RtsCommandButton.new()
	var key_text := OS.get_keycode_string(keycode) if keycode != KEY_NONE else ""
	button.configure(icon_kind, label_text, key_text, game.command_buttons.size())
	if action_type == "train" and GameData.UNITS.has(icon_kind):
		var source_landmark: String = game.selected[0].landmark_id if not game.selected.is_empty() and game.selected[0] is RtsBuilding else ""
		var unit_stats := RtsUnitCatalog.unit_definition(game.civilizations[0], icon_kind, game.players[0]["researched"], game.players[0]["age"], game.players[0]["landmarks"], game.players[0].get("dynasty", ""), source_landmark)
		var profile: Dictionary = unit_stats.get("profiles", {}).get(unit_stats.get("primary_profile", ""), {})
		var train_seconds: float = game.selected[0]._training_time(icon_kind) if not game.selected.is_empty() and game.selected[0] is RtsBuilding else GameData.training_time(game.civilizations[0], "", icon_kind)
		button.set_description("%s\n生命 %.0f · 攻击 %d×%.0f · 训练 %.1f 秒" % [str(UNIT_HELP.get(icon_kind, "训练并指挥此单位。")), float(unit_stats.get("hp", 0.0)), int(profile.get("hits", 1)), float(profile.get("damage", 0.0)), train_seconds])
	elif action_type == "research":
		var technology: Dictionary = RtsTechTree.get_technology(icon_kind)
		button.set_description(_research_description(icon_kind, technology))
	elif action_type == "build":
		button.set_description(str(BUILD_HELP.get(icon_kind, "建造此建筑。")))
	elif action_type == "landmark":
		button.set_description(str(RtsLandmarkCatalog.landmark(icon_kind).get("description", "建造地标并解锁时代能力。")))
	elif action_type == "convert_gate":
		button.set_description("将现有城墙改建为可供友军通行的城门。")
	elif COMMAND_HELP.has(icon_kind):
		button.set_description(str(COMMAND_HELP[icon_kind]))
	elif GameData.RESOURCE_LABELS.has(icon_kind):
		button.set_description("设置商人贸易所得的%s。" % GameData.RESOURCE_LABELS[icon_kind])
	elif action_type == "unit_ability":
		button.set_description("让选中单位使用此能力。")
	button.set_meta("cost", cost)
	button.set_meta("action_type", action_type)
	button.set_meta("action_kind", icon_kind)
	button.pressed.connect(callback)
	game.action_bar.add_child(button)
	game.command_buttons.append(button)
	if keycode != KEY_NONE: game.hotkey_buttons[keycode] = button

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

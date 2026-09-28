class_name RtsUnitPreviewPage
extends ColorRect

signal close_requested

const AGE_LABELS := ["", "I 黑暗时代", "II 封建时代", "III 城堡时代", "IV 帝王时代"]
const PROFILE_LABELS := {"melee": "近战", "ranged": "远程", "siege": "攻城", "charge": "冲锋", "structure": "对建筑", "torch": "火炬", "hunt_melee": "狩猎近战", "hunt_ranged": "狩猎远程"}
const UNIT_INTRO := {
	"villager": "采集资源、建造建筑并修复友方设施。",
	"imperial_official": "中国的经济单位，可监督生产并征收税金。",
	"scout": "快速探索地图，寻找资源和敌方动向。",
	"spearman": "廉价的近战步兵，擅长迎击骑兵。",
	"man_at_arms": "披甲近战步兵，适合在前线承受伤害。",
	"palace_guard": "中国的快速重装步兵，可压迫敌方阵线。",
	"archer": "轻型远程步兵，适合攻击无甲目标。",
	"longbow": "英格兰远程步兵，射程较远，并可部署拒马。",
	"zhuge_nu": "中国连弩兵，以密集射击压制轻型目标。",
	"fire_lancer": "中国轻骑兵，冲锋并威胁攻城器械。",
	"grenadier": "中国火药步兵，以投掷攻击压制敌军。",
	"crossbowman": "远程反甲步兵，适合对付重装目标。",
	"arbaletrier": "法兰西弩手，可部署大盾增强防护。",
	"horseman": "快速轻骑兵，适合追击远程单位。",
	"knight": "高生命值的重骑兵，擅长冲锋。",
	"royal_knight": "法兰西重骑兵，拥有更强的冲锋伤害。",
	"battering_ram": "带护棚的攻城槌，近距离撞击建筑与城墙。",
	"trebuchet": "长射程攻城器械，用巨石攻击建筑。",
	"handcannoneer": "高伤害火药步兵，适合近距离齐射。",
	"mangonel": "抛射石弹的攻城器械，威胁成群步兵。",
	"springald": "大型弩炮，以重矢攻击地面目标。",
	"bombard": "重型手推炮，用火炮轰击建筑。",
	"cannon": "法兰西加农炮，拥有强力远程炮击。",
	"nest_of_bees": "中国多管火箭车，可向成群敌军齐射。",
	"siege_tower": "载运步兵接近城墙并协助登墙。",
	"fishing_boat": "在水域收集鱼类资源。",
	"warship": "重型战船，适合海上远程交战。",
	"springald_ship": "装有大型弩炮的战船，擅长攻击重型目标。",
	"incendiary_ship": "快速接近敌船并发动火攻。",
	"arrow_ship": "轻型箭船，适合早期水面交战。",
	"transport_ship": "运输陆军跨越水域。",
	"trader": "在市场之间往返以获取黄金。",
	"monk": "治疗友军、携带圣物并尝试招降敌军。",
}

class PreviewContext:
	extends Node2D
	var view_mode_25d := true
	var world_map: Node2D
	var camera := Camera2D.new()

	func _ready() -> void:
		camera.enabled = false
		add_child(camera)

	func player_color(_owner_id: int) -> Color:
		return Color("4e9bea")

class PreviewBackdrop:
	extends Node2D

	func _draw() -> void:
		var bounds := get_viewport_rect().size
		draw_rect(Rect2(Vector2.ZERO, bounds), Color("253b35"))
		for index in 5:
			var y := bounds.y * 0.54 + index * bounds.y * 0.09
			draw_line(Vector2(0, y), Vector2(bounds.x, y), Color("799068", 0.13), 1.0)
		var center := Vector2(bounds.x * 0.5, bounds.y * 0.63)
		draw_arc(center, minf(bounds.x, bounds.y) * 0.23, 0.0, TAU, 48, Color("a6bb8b", 0.24), 1.5)
		draw_circle(center, 4.0, Color("d2bc7b", 0.5))

var civilization := "English"
var age := 2
var selected_kind := "villager"
var dynasty := ""
var producer_landmark := ""
var selected_research: Dictionary = {}
var roster: Array[String] = []
var unit_buttons: Dictionary = {}
var civilization_choice: OptionButton
var age_choice: OptionButton
var list_box: VBoxContainer
var stats_box: VBoxContainer
var bonus_box: VBoxContainer
var preview_viewport: SubViewport
var preview_context: PreviewContext
var preview_unit: RtsUnit
var preview_mode_choice: OptionButton
var style_button: Callable
var refresh_timer := 0.0

func build(parent: Control, initial_civilization: String, button_style: Callable) -> void:
	style_button = button_style
	civilization = initial_civilization if GameData.CIVILIZATIONS.has(initial_civilization) else "English"
	color = Color("100f0d")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(self)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 24
	panel.offset_top = 20
	panel.offset_right = -24
	panel.offset_bottom = -20
	panel.add_theme_stylebox_override("panel", _style(Color("26211a"), Color("9f7b43"), 16))
	add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	panel.add_child(layout)
	_build_header(layout)
	var divider := ColorRect.new()
	divider.color = Color("8a6a3e")
	divider.custom_minimum_size.y = 2
	layout.add_child(divider)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	layout.add_child(body)
	_build_list(body)
	_build_model(body)
	_build_details(body)
	_refresh_roster()
	_refresh_selection()

func _build_header(parent: VBoxContainer) -> void:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	parent.add_child(header)
	var title := _label(header, "单 位 预 览", 26, Color("f4dfae"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(header, "文明", 15, Color("e4d6b9"))
	civilization_choice = OptionButton.new()
	civilization_choice.custom_minimum_size = Vector2(135, 38)
	var civilization_ids := GameData.CIVILIZATIONS.keys()
	for civ in civilization_ids: civilization_choice.add_item(str(GameData.CIVILIZATIONS[civ]["label"]))
	civilization_choice.select(civilization_ids.find(civilization))
	style_button.call(civilization_choice)
	civilization_choice.item_selected.connect(func(index: int) -> void:
		civilization = str(civilization_ids[index])
		selected_research.clear()
		dynasty = ""
		producer_landmark = ""
		_refresh_roster()
		_refresh_selection()
	)
	header.add_child(civilization_choice)
	_label(header, "时代", 15, Color("e4d6b9"))
	age_choice = OptionButton.new()
	age_choice.custom_minimum_size = Vector2(150, 38)
	for era in range(1, 5): age_choice.add_item(AGE_LABELS[era])
	age_choice.select(age - 1)
	style_button.call(age_choice)
	age_choice.item_selected.connect(func(index: int) -> void:
		age = index + 1
		if dynasty == "Ming" and age < 4 or dynasty == "Yuan" and age < 3 or dynasty == "Song" and age < 2: dynasty = ""
		producer_landmark = ""
		_refresh_roster()
		_refresh_selection()
	)
	header.add_child(age_choice)
	var close_button := Button.new()
	close_button.text = "返回主菜单"
	close_button.custom_minimum_size = Vector2(120, 38)
	style_button.call(close_button)
	close_button.pressed.connect(func() -> void: close_requested.emit())
	header.add_child(close_button)

func _build_list(parent: HBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 248
	panel.add_theme_stylebox_override("panel", _style(Color("352b20"), Color("6f5634"), 10))
	parent.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 7)
	panel.add_child(content)
	_label(content, "单位列表", 19, Color("e4bd79"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	list_box = VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 4)
	scroll.add_child(list_box)

func _build_model(parent: HBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 375
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _style(Color("352b20"), Color("6f5634"), 10))
	parent.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 7)
	panel.add_child(content)
	var heading := HBoxContainer.new()
	content.add_child(heading)
	var title := _label(heading, "游戏内造型", 19, Color("e4bd79"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_mode_choice = OptionButton.new()
	preview_mode_choice.custom_minimum_size = Vector2(118, 34)
	preview_mode_choice.add_item("2D 俯视")
	preview_mode_choice.add_item("2.5D 斜视")
	preview_mode_choice.select(1)
	style_button.call(preview_mode_choice)
	preview_mode_choice.item_selected.connect(func(index: int) -> void:
		preview_context.view_mode_25d = index == 1
		_refresh_preview()
	)
	heading.add_child(preview_mode_choice)
	var frame := PanelContainer.new()
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_theme_stylebox_override("panel", _style(Color("253b35"), Color("98784b"), 0))
	content.add_child(frame)
	var container := SubViewportContainer.new()
	container.stretch = true
	container.custom_minimum_size = Vector2(350, 390)
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(container)
	preview_viewport = SubViewport.new()
	preview_viewport.size = Vector2i(400, 420)
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(preview_viewport)
	var backdrop := PreviewBackdrop.new()
	preview_viewport.add_child(backdrop)
	preview_viewport.size_changed.connect(func() -> void:
		backdrop.queue_redraw()
		_refresh_preview()
	)
	preview_context = PreviewContext.new()
	preview_viewport.add_child(preview_context)
	preview_unit = RtsUnit.new()
	preview_unit.game = preview_context
	preview_unit.owner_id = 0
	preview_unit.kind = selected_kind
	preview_context.add_child(preview_unit)
	preview_unit.set_process(false)
	preview_unit.scale = Vector2.ONE * 4.0
	_label(content, "显示该单位在战场上的实际外形", 13, Color("c4b492"))

func _build_details(parent: HBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 430
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _style(Color("352b20"), Color("6f5634"), 10))
	parent.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	panel.add_child(content)
	_label(content, "介绍与数值", 19, Color("e4bd79"))
	var stats_scroll := ScrollContainer.new()
	stats_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stats_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(stats_scroll)
	stats_box = VBoxContainer.new()
	stats_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_box.add_theme_constant_override("separation", 7)
	stats_scroll.add_child(stats_box)
	var divider := ColorRect.new()
	divider.color = Color("6f5634")
	divider.custom_minimum_size.y = 1
	content.add_child(divider)
	_label(content, "加成选项", 16, Color("e4bd79"))
	var bonus_scroll := ScrollContainer.new()
	bonus_scroll.custom_minimum_size.y = 178
	bonus_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(bonus_scroll)
	bonus_box = VBoxContainer.new()
	bonus_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bonus_box.add_theme_constant_override("separation", 3)
	bonus_scroll.add_child(bonus_box)

func _refresh_roster() -> void:
	roster.clear()
	for building_kind in RtsTechTree.PRODUCTION:
		for unit_kind in RtsTechTree.all_train_units(civilization, building_kind):
			if not roster.has(unit_kind): roster.append(unit_kind)
	if not roster.has(selected_kind): selected_kind = roster[0] if not roster.is_empty() else ""
	_clear(list_box)
	unit_buttons.clear()
	for unit_kind in GameData.UNITS:
		if not roster.has(unit_kind): continue
		var button := Button.new()
		var required_age: int = _required_age(unit_kind)
		button.text = "%s   ·   %s" % [GameData.UNITS[unit_kind]["label"], AGE_LABELS[required_age].split(" ")[0]]
		button.icon = RtsCommandButton._texture_at("res://assets/ui/command_icons/%s.png" % unit_kind)
		button.custom_minimum_size.y = 39
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.button_pressed = unit_kind == selected_kind
		style_button.call(button)
		var chosen_kind: String = unit_kind
		button.pressed.connect(func() -> void:
			selected_kind = chosen_kind
			producer_landmark = ""
			_refresh_selection()
		)
		list_box.add_child(button)
		unit_buttons[unit_kind] = button

func _refresh_selection() -> void:
	for unit_kind in unit_buttons:
		unit_buttons[unit_kind].set_pressed_no_signal(unit_kind == selected_kind)
	_refresh_preview()
	_refresh_stats()
	_refresh_bonuses()

func _refresh_preview() -> void:
	if selected_kind.is_empty() or preview_unit == null: return
	var stats := _resolved_stats()
	preview_unit.kind = selected_kind
	preview_unit.stats = stats
	preview_unit.max_hp = float(stats.get("hp", 1.0))
	preview_unit.hp = preview_unit.max_hp
	var view_size := Vector2(preview_viewport.size)
	preview_unit.position = Vector2(view_size.x * 0.5, view_size.y * (0.63 if preview_context.view_mode_25d else 0.52))
	preview_unit.scale = Vector2.ONE * clampf(minf(view_size.x / 400.0, view_size.y / 420.0) * 4.0, 3.4, 6.0)
	preview_unit.queue_redraw()

func _refresh_stats() -> void:
	_clear(stats_box)
	if selected_kind.is_empty(): return
	var stats := _resolved_stats()
	var base := RtsUnitCatalog.unit_definition(civilization, selected_kind, [], age, [], dynasty)
	var name_label := _label(stats_box, str(stats.get("label", selected_kind)), 24, Color("f4dfae"))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var intro := _label(stats_box, UNIT_INTRO.get(selected_kind, ""), 15, Color("e4d6b9"))
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var producer := RtsTechTree.producer_for_unit(selected_kind)
	var status := RtsTechTree.unit_status(civilization, age, producer, selected_kind, _research_ids(), dynasty)
	var availability := "本时代可训练" if status.get("available", false) else str(status.get("reason", "当前不可训练"))
	_label(stats_box, availability, 14, Color("9dd6a2") if status.get("available", false) else Color("dfaa83"))
	var rank_age := int(stats.get("rank_age", 0))
	if rank_age > 0: _label(stats_box, "兵种等级：%s" % AGE_LABELS[rank_age], 14, Color("d8bc7e"))
	var cost: Dictionary = stats.get("cost", {})
	_label(stats_box, "费用：%s   ·   人口：%d" % [GameData.cost_text(cost), int(stats.get("population_cost", 1))], 14, Color("e2d3b0"))
	_label(stats_box, "训练：%.1f 秒   ·   速度：%.2f 格/秒%s" % [float(stats.get("time", 0.0)), float(stats.get("speed", 0.0)) / 80.0, _delta(float(stats.get("speed", 0.0)) / 80.0, float(base.get("speed", 0.0)) / 80.0, 2)], 14, Color("e2d3b0"))
	_label(stats_box, "生命：%.0f%s" % [float(stats.get("hp", 0.0)), _delta(float(stats.get("hp", 0.0)), float(base.get("hp", 0.0)), 0)], 15, Color("f0ddb1"))
	var armor: Dictionary = stats.get("armor", {})
	var base_armor: Dictionary = base.get("armor", {})
	_label(stats_box, "近战护甲：%.0f%s   ·   远程护甲：%.0f%s" % [float(armor.get("melee", 0.0)), _delta(float(armor.get("melee", 0.0)), float(base_armor.get("melee", 0.0)), 0), float(armor.get("ranged", 0.0)), _delta(float(armor.get("ranged", 0.0)), float(base_armor.get("ranged", 0.0)), 0)], 14, Color("e2d3b0"))
	var resistance: Dictionary = stats.get("resistance", {})
	if float(resistance.get("ranged", 0.0)) > 0.0: _label(stats_box, "远程减伤：%.0f%%" % [float(resistance["ranged"]) * 100.0], 14, Color("e2d3b0"))
	var profiles: Dictionary = stats.get("profiles", {})
	var has_attack := false
	for profile_id in profiles:
		if float(profiles[profile_id].get("damage", 0.0)) > 0.0: has_attack = true
	if has_attack:
		_label(stats_box, "攻击方式", 16, Color("e4bd79"))
		for profile_id in profiles:
			var profile: Dictionary = profiles[profile_id]
			if float(profile.get("damage", 0.0)) <= 0.0: continue
			var line := "%s：%d × %.0f  ·  间隔 %.2f 秒  ·  射程 %.1f 格" % [PROFILE_LABELS.get(profile_id, profile_id), int(profile.get("hits", 1)), float(profile.get("damage", 0.0)), float(profile.get("cooldown", 0.0)), float(profile.get("range", 0.0)) / 30.0]
			var attack_label := _label(stats_box, line, 13, Color("e2d3b0"))
			attack_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			for bonus in profile.get("bonuses", []):
				var bonus_label := _label(stats_box, "   %s +%.0f" % [bonus.get("source_label", "额外伤害"), float(bonus.get("amount", 0.0))], 12, Color("b9d4f0"))
				bonus_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else:
		_label(stats_box, "无直接攻击", 13, Color("c4b492"))

func _refresh_bonuses() -> void:
	_clear(bonus_box)
	if selected_kind.is_empty(): return
	if civilization == "Chinese":
		_add_option_row("王朝", ["无王朝", "宋", "元", "明"].slice(0, age), ["", "Song", "Yuan", "Ming"].slice(0, age), dynasty, func(value: String) -> void:
			dynasty = value
			_refresh_preview()
			_refresh_stats()
		)
	if GameData.UNITS[selected_kind]["tags"].has("siege"):
		var producers: Array[String] = [""]
		var labels: Array[String] = ["普通生产"]
		if civilization == "Chinese" and age >= 3:
			producers.append("zh_clocktower")
			labels.append("天文钟楼生产 · 生命 +50%")
		if civilization == "French" and age >= 4:
			producers.append("fr_college_of_artillery")
			labels.append("炮兵学院生产 · 伤害 +30%")
		if not producers.has(producer_landmark): producer_landmark = ""
		_add_option_row("生产地标", labels, producers, producer_landmark, func(value: String) -> void:
			producer_landmark = value
			_refresh_preview()
			_refresh_stats()
		)
	var technologies := _available_technologies()
	if technologies.is_empty():
		_label(bonus_box, "当前时代没有适用的单位科技。", 13, Color("c4b492"))
		return
	for tech_id in technologies:
		var technology: Dictionary = RtsTechTree.get_technology(tech_id)
		var toggle := CheckButton.new()
		toggle.text = "%s  ·  %s" % [technology.get("label", tech_id), AGE_LABELS[int(technology.get("age", 1))].split(" ")[0]]
		toggle.button_pressed = bool(selected_research.get(tech_id, false))
		toggle.add_theme_font_size_override("font_size", 13)
		toggle.add_theme_color_override("font_color", Color("e2d3b0"))
		var chosen_id: String = tech_id
		toggle.toggled.connect(func(pressed: bool) -> void:
			if pressed: _enable_research(chosen_id)
			else: _disable_research(chosen_id)
			_refresh_preview()
			_refresh_stats()
			_refresh_bonuses()
		)
		bonus_box.add_child(toggle)

func _add_option_row(title: String, labels: Array, ids: Array, selected: String, on_change: Callable) -> void:
	var row := HBoxContainer.new()
	bonus_box.add_child(row)
	var caption := _label(row, title, 13, Color("c4b492"))
	caption.custom_minimum_size.x = 75
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for label_text in labels: option.add_item(str(label_text))
	option.select(maxi(0, ids.find(selected)))
	style_button.call(option)
	option.item_selected.connect(func(index: int) -> void: on_change.call(str(ids[index])))
	row.add_child(option)

func _available_technologies() -> Array[String]:
	var result: Array[String] = []
	var tags: Array = GameData.UNITS[selected_kind]["tags"]
	for tech_id in RtsTechTree.TECHNOLOGIES:
		var technology: Dictionary = RtsTechTree.TECHNOLOGIES[tech_id]
		if int(technology["age"]) > age or technology.get("effects", {}).is_empty(): continue
		if technology.has("civilizations") and not technology["civilizations"].has(civilization): continue
		var target_tags: Array = technology.get("target_tags", [])
		if target_tags.is_empty(): continue
		var applies := false
		for tag in target_tags:
			if tags.has(tag): applies = true
		if not applies: continue
		for tag in technology.get("exclude_tags", []):
			if tags.has(tag): applies = false
		if applies: result.append(tech_id)
	for age_key in RtsBalanceData.line(selected_kind).get("upgrade_costs", {}):
		var rank_age := int(age_key)
		if rank_age > RtsBalanceData.first_rank_age(selected_kind) and rank_age <= age:
			result.push_front(RtsBalanceData.rank_tech_id(selected_kind, rank_age))
	return result

func _enable_research(tech_id: String) -> void:
	selected_research[tech_id] = true
	for required in RtsTechTree.get_technology(tech_id).get("requires", []): _enable_research(required)

func _disable_research(tech_id: String) -> void:
	selected_research.erase(tech_id)
	for other_id in selected_research.keys():
		if RtsTechTree.get_technology(other_id).get("requires", []).has(tech_id):
			_disable_research(other_id)

func _research_ids() -> Array[String]:
	var result: Array[String] = []
	for tech_id in _available_technologies():
		if bool(selected_research.get(tech_id, false)): result.append(tech_id)
	return result

func _resolved_stats() -> Dictionary:
	return RtsUnitCatalog.unit_definition(civilization, selected_kind, _research_ids(), age, [], dynasty, producer_landmark)

func _required_age(unit_kind: String) -> int:
	var overrides: Dictionary = RtsTechTree.UNIT_AGE_OVERRIDES.get(civilization, {})
	return int(overrides.get(unit_kind, RtsTechTree.UNIT_AGE.get(unit_kind, 4)))

func _delta(value: float, base: float, precision: int) -> String:
	if is_equal_approx(value, base): return ""
	var format := "%.0f" if precision == 0 else "%.2f"
	return " (%s%s)" % ["+" if value > base else "", format % (value - base)]

func _label(parent: Node, value: String, font_size: int, font_color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	parent.add_child(label)
	return label

func _style(fill: Color, border: Color, margin: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(5)
	box.set_content_margin_all(margin)
	return box

func _clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func _process(delta: float) -> void:
	if preview_unit == null: return
	refresh_timer += delta
	if refresh_timer < 0.1: return
	refresh_timer = 0.0
	preview_unit.visual_phase += 0.18
	preview_unit.queue_redraw()

extends RefCounted
class_name RtsTechTreePage

signal civilization_selected(civilization: String)
signal close_requested

var overlay: ColorRect
var civilization_choice: OptionButton

func build(parent: Control, civilization: String, style_button: Callable) -> void:
	overlay = ColorRect.new()
	overlay.color = Color("100f0d")
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(overlay)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 24
	panel.offset_top = 20
	panel.offset_right = -24
	panel.offset_bottom = -20
	panel.add_theme_stylebox_override("panel", _tech_tree_style(Color("26211a"), Color("9f7b43"), 16))
	overlay.add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	panel.add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	var title := _tech_tree_label(header, "%s  ·  科技树" % GameData.CIVILIZATIONS[civilization]["label"], 26, Color("f4dfae"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tech_tree_label(header, "切换国家", 15, Color("e4d6b9"))
	civilization_choice = OptionButton.new()
	civilization_choice.custom_minimum_size = Vector2(135, 38)
	var civilization_ids := GameData.CIVILIZATIONS.keys()
	for civ in civilization_ids: civilization_choice.add_item(str(GameData.CIVILIZATIONS[civ]["label"]))
	civilization_choice.select(civilization_ids.find(civilization))
	style_button.call(civilization_choice)
	civilization_choice.item_selected.connect(func(index: int) -> void: civilization_selected.emit(str(civilization_ids[index])))
	header.add_child(civilization_choice)
	var close_button := Button.new()
	close_button.text = "返回"
	close_button.custom_minimum_size = Vector2(90, 38)
	style_button.call(close_button)
	close_button.pressed.connect(func() -> void: close_requested.emit())
	header.add_child(close_button)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	layout.add_child(body)
	var sidebar_panel := PanelContainer.new()
	sidebar_panel.custom_minimum_size.x = 205
	sidebar_panel.add_theme_stylebox_override("panel", _tech_tree_style(Color("352b20"), Color("6f5634"), 12))
	body.add_child(sidebar_panel)
	var sidebar := VBoxContainer.new()
	sidebar.add_theme_constant_override("separation", 10)
	sidebar_panel.add_child(sidebar)
	_tech_tree_label(sidebar, "文明特色", 18, Color("e4bd79"))
	var description := _tech_tree_label(sidebar, str(GameData.CIVILIZATIONS[civilization]["description"]), 15, Color("e4d6b9"))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tech_tree_label(sidebar, "特色单位", 18, Color("e4bd79"))
	var unique_units: Array[String] = []
	for building_kind in RtsTechTree.PRODUCTION:
		for unit_kind in RtsTechTree.all_train_units(civilization, building_kind):
			if GameData.UNITS[unit_kind]["tags"].has("unique") and not unique_units.has(unit_kind): unique_units.append(unit_kind)
	for unit_kind in unique_units:
		_tech_tree_label(sidebar, "◆ %s" % GameData.UNITS[unit_kind]["label"], 14, Color("b9d4f0"))
	_tech_tree_label(sidebar, "图例", 18, Color("e4bd79"))
	_tech_tree_label(sidebar, "◆ 建筑与地标", 14, Color("e4bd79"))
	_tech_tree_label(sidebar, "◆ 可训练单位", 14, Color("a9cdef"))
	_tech_tree_label(sidebar, "◆ 可研究科技", 14, Color("a9d8ae"))
	var hint := _tech_tree_label(sidebar, "悬停可查看费用、属性和前置要求。滚动查看各时代。", 13, Color("c4b492"))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	var ages := HBoxContainer.new()
	ages.add_theme_constant_override("separation", 12)
	scroll.add_child(ages)
	for age in range(1, 5): _build_tech_tree_age(ages, civilization, age)

func _build_tech_tree_age(parent: HBoxContainer, civilization: String, age: int) -> void:
	var column_panel := PanelContainer.new()
	column_panel.custom_minimum_size.x = 250
	column_panel.add_theme_stylebox_override("panel", _tech_tree_style(Color("30281e"), Color("6f5634"), 10))
	parent.add_child(column_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	column_panel.add_child(column)
	_tech_tree_label(column, ["", "I  黑暗时代", "II  封建时代", "III  城堡时代", "IV  帝王时代"][age], 19, Color("f3d59c"))
	if age > 1:
		var landmarks := _tech_tree_card(column, "时代地标", "选择其一升至该时代", Color("edc781"))
		var unlocks := _tech_tree_label(landmarks, str(RtsTechTree.AGE_UNLOCK_TEXT[age]), 12, Color("d4c8ae"))
		unlocks.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		for landmark_id in RtsLandmarkCatalog.LANDMARKS:
			var landmark: Dictionary = RtsLandmarkCatalog.LANDMARKS[landmark_id]
			if landmark["civilization"] != civilization or int(landmark["age"]) != age: continue
			var details: Dictionary = RtsLandmarkCatalog.landmark(landmark_id)
			_tech_tree_entry(landmarks, str(landmark["label"]), Color("edc781"), "%s\n费用：%s" % [landmark["description"], GameData.cost_text(details["cost"])])
			var landmark_effect := _tech_tree_label(landmarks, "   %s" % landmark["description"], 12, Color("d4c8ae"))
			landmark_effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for building_kind in ["town_center"] + RtsTechTree.BUILD_MENU:
		var building_age: int = int(RtsTechTree.BUILDING_AGE.get(building_kind, 99))
		if building_age > age: continue
		var units: Array[String] = []
		for unit_kind in RtsTechTree.all_train_units(civilization, building_kind):
			var unit_age: int = maxi(int(RtsTechTree.UNIT_AGE.get(unit_kind, 99)), building_age)
			unit_age = int(RtsTechTree.UNIT_AGE_OVERRIDES.get(civilization, {}).get(unit_kind, unit_age))
			if unit_age == age: units.append(unit_kind)
		var researches: Array[String] = []
		for tech_id in RtsTechTree.all_researches(civilization, building_kind):
			if int(RtsTechTree.get_technology(tech_id).get("age", 99)) == age: researches.append(tech_id)
		if building_age != age and units.is_empty() and researches.is_empty(): continue
		var building: Dictionary = GameData.BUILDINGS[building_kind]
		var card := _tech_tree_card(column, str(building["label"]), "建造费用：%s" % (GameData.cost_text(building["cost"]) if not building["cost"].is_empty() else "初始建筑"), Color("edc781"))
		if not units.is_empty(): _tech_tree_label(card, "训练单位", 12, Color("a9cdef"))
		for unit_kind in units:
			var unit: Dictionary = GameData.UNITS[unit_kind]
			var unit_label := "%s%s" % ["★ " if unit["tags"].has("unique") else "", unit["label"]]
			var requirements := ""
			if unit_kind == "zhuge_nu": requirements = "\n需要宋朝王朝"
			elif unit_kind == "fire_lancer": requirements = "\n需要元朝王朝"
			elif unit_kind == "grenadier": requirements = "\n需要明朝王朝"
			_tech_tree_entry(card, unit_label, Color("a9cdef"), "训练费用：%s\n生命：%d  攻击：%d%s" % [GameData.cost_text(GameData.unit_cost(unit_kind)), int(unit["hp"]), int(unit["damage"]), requirements])
		var rank_researches: Array[String] = []
		var special_researches: Array[String] = []
		for tech_id in researches:
			if RtsTechTree.get_technology(tech_id).has("rank_unit"): rank_researches.append(tech_id)
			else: special_researches.append(tech_id)
		for group in [rank_researches, special_researches]:
			if group.is_empty(): continue
			_tech_tree_label(card, "兵种升级" if group == rank_researches else "建筑科技", 12, Color("a9d8ae"))
			for tech_id in group:
				var tech: Dictionary = RtsTechTree.get_technology(tech_id)
				var requirements: Array[String] = []
				for prerequisite in tech["requires"]: requirements.append(str(RtsTechTree.get_technology(prerequisite)["label"]))
				var tooltip := "研究费用：%s" % GameData.cost_text(tech["cost"])
				if not requirements.is_empty(): tooltip += "\n前置科技：%s" % "、".join(requirements)
				_tech_tree_entry(card, str(tech["label"]), Color("a9d8ae"), tooltip)

func _tech_tree_card(parent: VBoxContainer, heading: String, tooltip: String, accent: Color) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _tech_tree_style(Color("403223"), Color("745735"), 8))
	panel.tooltip_text = tooltip
	parent.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	panel.add_child(content)
	_tech_tree_label(content, heading, 16, accent)
	return content

func _tech_tree_entry(parent: VBoxContainer, value: String, color: Color, tooltip: String) -> void:
	var label := _tech_tree_label(parent, "◆ %s" % value, 14, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.tooltip_text = tooltip

func _tech_tree_label(parent: Node, value: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _tech_tree_style(fill: Color, border: Color, margin: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(margin)
	return style

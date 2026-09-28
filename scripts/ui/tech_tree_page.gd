extends RefCounted
class_name RtsTechTreePage

signal civilization_selected(civilization: String, age: int)
signal close_requested

const AGE_LABELS := ["", "I  黑暗时代", "II  封建时代", "III  城堡时代", "IV  帝王时代"]
const ICON_ROOT := "res://assets/ui/command_icons/"

class UnlockLink:
	extends Control

	func _init() -> void:
		custom_minimum_size = Vector2(34, 48)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var y := size.y * 0.5
		var ink := Color("b99556")
		draw_line(Vector2(3, y), Vector2(size.x - 9, y), ink, 2.0)
		draw_colored_polygon(PackedVector2Array([
			Vector2(size.x - 11, y - 5), Vector2(size.x - 3, y), Vector2(size.x - 11, y + 5),
		]), ink)

var overlay: ColorRect
var civilization_choice: OptionButton
var age_scroll: ScrollContainer
var age_buttons: Array[Button] = []
var age_pages: Array[VBoxContainer] = []
var selected_age := 1

func build(parent: Control, civilization: String, style_button: Callable, initial_age := 1) -> void:
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
	layout.add_theme_constant_override("separation", 10)
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
	civilization_choice.item_selected.connect(func(index: int) -> void: civilization_selected.emit(str(civilization_ids[index]), selected_age))
	header.add_child(civilization_choice)
	var close_button := Button.new()
	close_button.text = "返回"
	close_button.custom_minimum_size = Vector2(90, 38)
	style_button.call(close_button)
	close_button.pressed.connect(func() -> void: close_requested.emit())
	header.add_child(close_button)
	var age_bar := HBoxContainer.new()
	age_bar.add_theme_constant_override("separation", 7)
	layout.add_child(age_bar)
	for age in range(1, 5):
		var button := Button.new()
		button.text = AGE_LABELS[age]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 42
		button.focus_mode = Control.FOCUS_NONE
		var target_age := age
		button.pressed.connect(func() -> void: show_age(target_age))
		age_bar.add_child(button)
		age_buttons.append(button)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	layout.add_child(body)
	_build_sidebar(body, civilization)
	age_scroll = ScrollContainer.new()
	age_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	age_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	age_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(age_scroll)
	var page_stack := VBoxContainer.new()
	page_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	age_scroll.add_child(page_stack)
	for age in range(1, 5):
		var page := VBoxContainer.new()
		page.name = "Age%d" % age
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page.add_theme_constant_override("separation", 10)
		page_stack.add_child(page)
		_build_tech_tree_age(page, civilization, age)
		age_pages.append(page)
	show_age(initial_age)

func show_age(age: int) -> void:
	selected_age = clampi(age, 1, 4)
	for index in age_pages.size(): age_pages[index].visible = index == selected_age - 1
	for index in age_buttons.size():
		var button := age_buttons[index]
		var active := index == selected_age - 1
		button.add_theme_stylebox_override("normal", _tech_tree_style(Color("76552e") if active else Color("33291e"), Color("e0b86c") if active else Color("705739"), 5))
		button.add_theme_color_override("font_color", Color("fff0ca") if active else Color("c7b797"))
	if age_scroll != null: age_scroll.scroll_vertical = 0

func _build_sidebar(parent: HBoxContainer, civilization: String) -> void:
	var sidebar_panel := PanelContainer.new()
	sidebar_panel.custom_minimum_size.x = 190
	sidebar_panel.add_theme_stylebox_override("panel", _tech_tree_style(Color("352b20"), Color("6f5634"), 12))
	parent.add_child(sidebar_panel)
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
		var label := _tech_tree_label(sidebar, "◆ %s" % GameData.UNITS[unit_kind]["label"], 14, Color("b9d4f0"))
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tech_tree_label(sidebar, "阅读方式", 18, Color("e4bd79"))
	var hint := _tech_tree_label(sidebar, "左侧建筑 → 右侧本时代解锁的兵种与科技。选择时代可直接跳转；悬停查看完整数值。", 13, Color("c4b492"))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _build_tech_tree_age(parent: VBoxContainer, civilization: String, age: int) -> void:
	_tech_tree_label(parent, AGE_LABELS[age], 22, Color("f3d59c"))
	if age > 1: _build_landmarks(parent, civilization, age)
	_tech_tree_label(parent, "本时代开放", 15, Color("bca77e"))
	for building_kind in ["town_center"] + RtsTechTree.BUILD_MENU:
		var building_age: int = int(RtsTechTree.BUILDING_AGE.get(building_kind, 99))
		if building_age > age: continue
		var unlocks: Array[Dictionary] = []
		for unit_kind in RtsTechTree.all_train_units(civilization, building_kind):
			var unit_age: int = maxi(int(RtsTechTree.UNIT_AGE.get(unit_kind, 99)), building_age)
			unit_age = int(RtsTechTree.UNIT_AGE_OVERRIDES.get(civilization, {}).get(unit_kind, unit_age))
			if unit_age != age: continue
			var unit: Dictionary = GameData.UNITS[unit_kind]
			var requirement := ""
			if unit_kind == "zhuge_nu": requirement = "宋朝王朝"
			elif unit_kind == "fire_lancer": requirement = "元朝王朝"
			elif unit_kind == "grenadier": requirement = "明朝王朝"
			var unit_tip := "训练费用：%s\n生命：%d  攻击：%d" % [GameData.cost_text(GameData.unit_cost(unit_kind)), int(unit["hp"]), int(unit["damage"])]
			if requirement != "": unit_tip += "\n需要%s" % requirement
			unlocks.append({"kind": unit_kind, "label": str(unit["label"]), "category": "特色兵种" if unit["tags"].has("unique") else "训练兵种", "requirement": requirement, "cost": GameData.cost_text(GameData.unit_cost(unit_kind)), "tooltip": unit_tip, "color": Color("a9cdef")})
		for tech_id in RtsTechTree.all_researches(civilization, building_kind):
			var tech: Dictionary = RtsTechTree.get_technology(tech_id)
			if int(tech.get("age", 99)) != age: continue
			var requirements: Array[String] = []
			for prerequisite in tech["requires"]: requirements.append(str(RtsTechTree.get_technology(prerequisite)["label"]))
			var prerequisite_text := "、".join(requirements)
			var tech_tip := "研究费用：%s" % GameData.cost_text(tech["cost"])
			if prerequisite_text != "": tech_tip += "\n前置科技：%s" % prerequisite_text
			unlocks.append({"kind": tech_id, "label": str(tech["label"]), "category": "兵种升级" if tech.has("rank_unit") else "研究科技", "requirement": prerequisite_text, "cost": GameData.cost_text(tech["cost"]), "tooltip": tech_tip, "color": Color("a9d8ae")})
		if building_age != age and unlocks.is_empty(): continue
		_build_building_row(parent, civilization, building_kind, unlocks, building_age == age)

func _build_landmarks(parent: VBoxContainer, civilization: String, age: int) -> void:
	var section := PanelContainer.new()
	section.add_theme_stylebox_override("panel", _tech_tree_style(Color("3b3020"), Color("b18c4e"), 10))
	parent.add_child(section)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 7)
	section.add_child(content)
	_tech_tree_label(content, "升至本时代 · 选择一座地标", 16, Color("edc781"))
	var age_cost := GameData.cost_text(RtsTechTree.age_cost(age - 1))
	_tech_tree_label(content, "时代费用：%s    %s" % [age_cost, RtsTechTree.AGE_UNLOCK_TEXT[age]], 12, Color("d4c8ae"))
	var choices := GridContainer.new()
	choices.columns = 2
	choices.add_theme_constant_override("h_separation", 8)
	choices.add_theme_constant_override("v_separation", 6)
	content.add_child(choices)
	for landmark_id in RtsLandmarkCatalog.LANDMARKS:
		var landmark: Dictionary = RtsLandmarkCatalog.LANDMARKS[landmark_id]
		if landmark["civilization"] != civilization or int(landmark["age"]) != age: continue
		var details: Dictionary = RtsLandmarkCatalog.landmark(landmark_id)
		var tooltip := "%s\n费用：%s" % [landmark["description"], GameData.cost_text(details["cost"])]
		_unlock_tile(choices, landmark_id, str(landmark["label"]), str(landmark["description"]), tooltip, Color("edc781"), 280)

func _build_building_row(parent: VBoxContainer, civilization: String, building_kind: String, unlocks: Array[Dictionary], new_building: bool) -> void:
	var building: Dictionary = GameData.BUILDINGS[building_kind]
	var actual_cost := RtsCivilizationRules.building_cost(civilization, building_kind)
	var row_panel := PanelContainer.new()
	row_panel.add_theme_stylebox_override("panel", _tech_tree_style(Color("30281e"), Color("6f5634"), 9))
	parent.add_child(row_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row_panel.add_child(row)
	var producer := VBoxContainer.new()
	producer.custom_minimum_size.x = 165
	producer.add_theme_constant_override("separation", 4)
	row.add_child(producer)
	var producer_header := HBoxContainer.new()
	producer_header.add_theme_constant_override("separation", 7)
	producer.add_child(producer_header)
	_add_icon(producer_header, building_kind, 36)
	var producer_name := _tech_tree_label(producer_header, str(building["label"]), 16, Color("edc781"))
	producer_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var cost_text := "本时代可建造" if new_building else "此前已解锁"
	if new_building: cost_text += "\n%s" % (GameData.cost_text(actual_cost) if not actual_cost.is_empty() else "初始建筑")
	var cost_label := _tech_tree_label(producer, cost_text, 12, Color("c4b492"))
	cost_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	producer.tooltip_text = "建造费用：%s" % (GameData.cost_text(actual_cost) if not actual_cost.is_empty() else "初始建筑")
	var link := UnlockLink.new()
	link.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(link)
	if unlocks.is_empty():
		var empty := _tech_tree_label(row, "开放建造", 14, Color("c4b492"))
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		return
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	row.add_child(grid)
	for item in unlocks:
		var meta := str(item["category"])
		if str(item["requirement"]) != "": meta += " · 需%s" % item["requirement"]
		meta += "\n%s" % item["cost"]
		_unlock_tile(grid, str(item["kind"]), str(item["label"]), meta, str(item["tooltip"]), item["color"], 175)

func _unlock_tile(parent: Node, icon_kind: String, title: String, detail: String, tooltip: String, accent: Color, width: float) -> void:
	var tile := PanelContainer.new()
	tile.custom_minimum_size.x = width
	tile.add_theme_stylebox_override("panel", _tech_tree_style(Color("433525"), Color("80623a"), 5))
	tile.tooltip_text = tooltip
	parent.add_child(tile)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	tile.add_child(row)
	_add_icon(row, icon_kind, 36)
	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 1)
	row.add_child(text_box)
	var name_label := _tech_tree_label(text_box, title, 14, accent)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var detail_label := _tech_tree_label(text_box, detail, 11, Color("c5b89e"))
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _add_icon(parent: Node, icon_kind: String, side: float) -> void:
	var icon := TextureRect.new()
	icon.texture = RtsCommandButton._texture_at("%s%s.png" % [ICON_ROOT, icon_kind])
	icon.custom_minimum_size = Vector2.ONE * side
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(icon)

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

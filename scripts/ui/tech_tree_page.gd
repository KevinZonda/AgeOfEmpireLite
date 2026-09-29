extends RefCounted
class_name RtsTechTreePage
const RtsUiTypography = preload("res://scripts/ui/typography.gd")

signal civilization_selected(civilization: String, age: int)
signal close_requested

const AGE_LABELS := ["", "I  黑暗时代", "II  封建时代", "III  城堡时代", "IV  帝王时代"]
const ICON_ROOT := "res://assets/ui/command_icons/"
const AGE_COLUMN_WIDTH := 252.0
const BUILDING_COLUMN_WIDTH := 224.0

var overlay: ColorRect
var civilization_choice: OptionButton
var age_scroll: ScrollContainer
var age_rail: VBoxContainer
var matrix_header: HBoxContainer
var age_pages: Array[HBoxContainer] = []
var building_columns: Array[String] = []
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
	var title := _tech_tree_label(header, "%s  ·  科技树" % GameData.CIVILIZATIONS[civilization]["label"], RtsUiTypography.PAGE_TITLE, Color("f4dfae"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tech_tree_label(header, "切换国家", RtsUiTypography.BODY, Color("e4d6b9"))
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
	var header_strip := HBoxContainer.new()
	header_strip.add_theme_constant_override("separation", 6)
	layout.add_child(header_strip)
	var corner := _matrix_cell(header_strip, AGE_COLUMN_WIDTH, Color("3c3020"), Color("a7854c"))
	_tech_tree_label(corner, "时代 ↓   建筑 →", RtsUiTypography.SUBSECTION_TITLE, Color("f3d59c"))
	var header_view := Control.new()
	header_view.clip_contents = true
	header_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_strip.add_child(header_view)
	building_columns.assign(["town_center"] + RtsTechTree.BUILD_MENU)
	_build_matrix_header(header_view)
	header_view.custom_minimum_size.y = matrix_header.get_combined_minimum_size().y
	matrix_header.minimum_size_changed.connect(func() -> void: header_view.custom_minimum_size.y = matrix_header.get_combined_minimum_size().y)
	var matrix_body := HBoxContainer.new()
	matrix_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	matrix_body.add_theme_constant_override("separation", 6)
	layout.add_child(matrix_body)
	var rail_view := Control.new()
	rail_view.custom_minimum_size.x = AGE_COLUMN_WIDTH
	rail_view.clip_contents = true
	matrix_body.add_child(rail_view)
	age_rail = VBoxContainer.new()
	age_rail.add_theme_constant_override("separation", 6)
	rail_view.add_child(age_rail)
	age_scroll = ScrollContainer.new()
	age_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	age_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	age_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	matrix_body.add_child(age_scroll)
	age_scroll.get_v_scroll_bar().value_changed.connect(_on_vertical_scroll)
	age_scroll.get_h_scroll_bar().value_changed.connect(func(value: float) -> void: matrix_header.position.x = -value)
	var matrix := VBoxContainer.new()
	matrix.add_theme_constant_override("separation", 6)
	age_scroll.add_child(matrix)
	for age in range(1, 5):
		var page := HBoxContainer.new()
		page.name = "Age%d" % age
		page.add_theme_constant_override("separation", 6)
		matrix.add_child(page)
		_build_tech_tree_age(page, age_rail, civilization, age)
		page.resized.connect(_align_age_rail)
		age_pages.append(page)
	_align_age_rail.call_deferred()
	show_age(initial_age)

func show_age(age: int) -> void:
	selected_age = clampi(age, 1, 4)
	if age_scroll != null and not age_pages.is_empty():
		age_scroll.call_deferred("set_v_scroll", int(age_pages[selected_age - 1].position.y))

func _on_vertical_scroll(value: float) -> void:
	age_rail.position.y = -value
	var scrollbar := age_scroll.get_v_scroll_bar()
	var max_scroll := scrollbar.max_value - scrollbar.page
	if max_scroll > 0.0 and value >= max_scroll - 1.0:
		selected_age = 4
		return
	selected_age = 1
	for index in age_pages.size():
		if age_pages[index].position.y <= value + 20.0: selected_age = index + 1

func _build_matrix_header(parent: Control) -> void:
	matrix_header = HBoxContainer.new()
	matrix_header.name = "BuildingHeader"
	matrix_header.add_theme_constant_override("separation", 6)
	parent.add_child(matrix_header)
	for building_kind in building_columns:
		var cell := _matrix_cell(matrix_header, BUILDING_COLUMN_WIDTH, Color("3c3020"), Color("a7854c"))
		cell.set_meta("building_kind", building_kind)
		var title := HBoxContainer.new()
		title.add_theme_constant_override("separation", 7)
		cell.add_child(title)
		_add_icon(title, building_kind, 34)
		var name_label := _tech_tree_label(title, str(GameData.BUILDINGS[building_kind]["label"]), RtsUiTypography.BODY, Color("edc781"))
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_tech_tree_label(cell, "%s时代可建造" % AGE_LABELS[int(RtsTechTree.BUILDING_AGE[building_kind])].split("  ")[0], RtsUiTypography.CAPTION, Color("bca77e"))

func _build_tech_tree_age(parent: HBoxContainer, rail: VBoxContainer, civilization: String, age: int) -> void:
	var age_cell := _matrix_cell(rail, AGE_COLUMN_WIDTH, Color("352b20"), Color("9f7b43"))
	_tech_tree_label(age_cell, AGE_LABELS[age], RtsUiTypography.SECTION_TITLE, Color("f3d59c"))
	if age > 1: _build_landmarks(age_cell, civilization, age)
	else: _tech_tree_label(age_cell, "起始时代", RtsUiTypography.CAPTION, Color("c4b492"))
	for building_kind in building_columns:
		_build_building_cell(parent, civilization, building_kind, age)

func _align_age_rail() -> void:
	if age_rail == null or age_pages.size() != 4: return
	for index in age_pages.size():
		(age_rail.get_child(index) as Control).custom_minimum_size.y = age_pages[index].size.y

func _build_landmarks(parent: VBoxContainer, civilization: String, age: int) -> void:
	_tech_tree_label(parent, "升级：%s" % GameData.cost_text(RtsTechTree.age_cost(age - 1)), RtsUiTypography.CAPTION, Color("d4c8ae"))
	_tech_tree_label(parent, "时代地标（二选一）", RtsUiTypography.CAPTION, Color("edc781"))
	for landmark_id in RtsLandmarkCatalog.LANDMARKS:
		var landmark: Dictionary = RtsLandmarkCatalog.LANDMARKS[landmark_id]
		if landmark["civilization"] != civilization or int(landmark["age"]) != age: continue
		var details: Dictionary = RtsLandmarkCatalog.landmark(landmark_id)
		var tooltip := "%s\n费用：%s" % [landmark["description"], GameData.cost_text(details["cost"])]
		_unlock_tile(parent, landmark_id, str(landmark["label"]), "地标", tooltip, Color("edc781"), AGE_COLUMN_WIDTH - 24)

func _build_building_cell(parent: HBoxContainer, civilization: String, building_kind: String, age: int) -> void:
	var building_age: int = int(RtsTechTree.BUILDING_AGE.get(building_kind, 99))
	var new_building := building_age == age
	var cell := _matrix_cell(parent, BUILDING_COLUMN_WIDTH, Color("30281e") if building_age <= age else Color("29241e"), Color("80623a") if new_building else Color("594832"))
	cell.set_meta("building_kind", building_kind)
	cell.set_meta("age", age)
	if building_age > age:
		_tech_tree_label(cell, "需要%s" % AGE_LABELS[building_age], RtsUiTypography.CAPTION, Color("8d806c"))
		return
	if new_building:
		var actual_cost := RtsCivilizationRules.building_cost(civilization, building_kind)
		var cost_text := GameData.cost_text(actual_cost) if not actual_cost.is_empty() else "初始建筑"
		var new_label := _tech_tree_label(cell, "◆ 开放建造 · %s" % cost_text, RtsUiTypography.CAPTION, Color("edc781"))
		new_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var unlocks := _unlocks_for(civilization, building_kind, age)
	if unlocks.is_empty():
		if not new_building: _tech_tree_label(cell, "—", RtsUiTypography.CAPTION, Color("8d806c"))
		return
	for item in unlocks:
		var detail := str(item["category"])
		if str(item["requirement"]) != "": detail += " · 需%s" % item["requirement"]
		_unlock_tile(cell, str(item["kind"]), str(item["label"]), detail, str(item["tooltip"]), item["color"], BUILDING_COLUMN_WIDTH - 24)

func _unlocks_for(civilization: String, building_kind: String, age: int) -> Array[Dictionary]:
	var unlocks: Array[Dictionary] = []
	var building_age: int = int(RtsTechTree.BUILDING_AGE.get(building_kind, 99))
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
		unlocks.append({"kind": unit_kind, "label": str(unit["label"]), "category": "特色兵种" if unit["tags"].has("unique") else "训练兵种", "requirement": requirement, "tooltip": unit_tip, "color": Color("a9cdef")})
	for tech_id in RtsTechTree.all_researches(civilization, building_kind):
		var tech: Dictionary = RtsTechTree.get_technology(tech_id)
		if int(tech.get("age", 99)) != age: continue
		var requirements: Array[String] = []
		for prerequisite in tech["requires"]: requirements.append(str(RtsTechTree.get_technology(prerequisite)["label"]))
		var prerequisite_text := "、".join(requirements)
		var tech_tip := "研究费用：%s" % GameData.cost_text(tech["cost"])
		if prerequisite_text != "": tech_tip += "\n前置科技：%s" % prerequisite_text
		unlocks.append({"kind": tech_id, "label": str(tech["label"]), "category": "兵种升级" if tech.has("rank_unit") else "研究科技", "requirement": prerequisite_text, "tooltip": tech_tip, "color": Color("a9d8ae")})
	return unlocks

func _matrix_cell(parent: Node, width: float, fill: Color, border: Color) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = width
	panel.add_theme_stylebox_override("panel", _tech_tree_style(fill, border, 8))
	parent.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	panel.add_child(content)
	return content

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
	var name_label := _tech_tree_label(text_box, title, RtsUiTypography.BODY, accent)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var detail_label := _tech_tree_label(text_box, detail, RtsUiTypography.CAPTION, Color("c5b89e"))
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

class_name RtsGameMenuUi
extends RefCounted
const RtsUiTypography = preload("res://scripts/ui/typography.gd")

# Owns settings and lobby presentation; match state stays in the game root.
signal match_requested(settings: Dictionary)

const SETTINGS_LABEL_WIDTH := 120.0
const SETTINGS_FIELD_WIDTH := 240.0
const SETTINGS_ROW_SPACING := 12.0

var game: Node2D

func _init(game_ref: Node2D) -> void:
	game = game_ref

func _create_settings(parent: Control) -> void:
	game.settings_overlay = ColorRect.new()
	game.settings_overlay.color = Color(0.08, 0.06, 0.04, 0.78)
	game.settings_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game.settings_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(game.settings_overlay)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", game._hud_panel_style(Color("30271c"), 20))
	game.settings_overlay.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	_add_menu_label(box, "设置", RtsUiTypography.PAGE_TITLE)
	var settings_layout := HBoxContainer.new()
	settings_layout.add_theme_constant_override("separation", 12)
	settings_layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(settings_layout)
	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size.x = 126
	sidebar.alignment = BoxContainer.ALIGNMENT_CENTER
	sidebar.add_theme_constant_override("separation", 8)
	settings_layout.add_child(sidebar)
	game.settings_tabs = TabContainer.new()
	game.settings_tabs.tabs_visible = false
	game.settings_tabs.custom_minimum_size = Vector2(420, 275)
	game.settings_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game.settings_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	settings_layout.add_child(game.settings_tabs)
	var display_scroll := ScrollContainer.new()
	display_scroll.name = "显示设置"
	display_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	display_scroll.follow_focus = true
	game.settings_tabs.add_child(display_scroll)
	var display_tab := VBoxContainer.new()
	display_tab.name = "显示设置"
	display_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	display_tab.alignment = BoxContainer.ALIGNMENT_CENTER
	display_tab.add_theme_constant_override("separation", 12)
	display_scroll.add_child(display_tab)
	display_scroll.resized.connect(func() -> void: display_tab.custom_minimum_size.y = display_scroll.size.y)
	game.window_mode_choice = OptionButton.new()
	game.window_mode_choice.add_item("窗口化")
	game.window_mode_choice.add_item("全屏")
	game.window_mode_choice.custom_minimum_size.y = 42
	game._style_button(game.window_mode_choice)
	game.window_mode_choice.item_selected.connect(func(_index: int) -> void: _refresh_ui_scale_options())
	_add_settings_option_row(display_tab, "显示模式", game.window_mode_choice)
	game.resolution_choice = OptionButton.new()
	game.resolution_choice.tooltip_text = "自动模式会按当前屏幕可用区域的 90% 设置窗口；全屏始终使用屏幕尺寸。"
	game.resolution_choice.custom_minimum_size.y = 42
	game._style_button(game.resolution_choice)
	game.resolution_choice.item_selected.connect(func(_index: int) -> void: _refresh_ui_scale_options())
	_add_settings_option_row(display_tab, "窗口分辨率", game.resolution_choice)
	game.projection_choice = OptionButton.new()
	game.projection_choice.add_item("2D 俯视")
	game.projection_choice.add_item("2.5D 斜视")
	game.projection_choice.custom_minimum_size.y = 42
	game._style_button(game.projection_choice)
	_add_settings_option_row(display_tab, "视角", game.projection_choice)
	game.building_icons_toggle = CheckButton.new()
	game.building_icons_toggle.text = "显示建筑图标"
	game.building_icons_toggle.tooltip_text = "显示地图上建筑上方的图标"
	game.building_icons_toggle.custom_minimum_size.y = 42
	game.building_icons_toggle.add_theme_color_override("font_color", Color("f5e4bf"))
	_add_settings_toggle_row(display_tab, game.building_icons_toggle)
	game.building_names_toggle = CheckButton.new()
	game.building_names_toggle.text = "显示建筑名称"
	game.building_names_toggle.tooltip_text = "显示地图上建筑下方的名称"
	game.building_names_toggle.custom_minimum_size.y = 42
	game.building_names_toggle.add_theme_color_override("font_color", Color("f5e4bf"))
	_add_settings_toggle_row(display_tab, game.building_names_toggle)
	game.minimap_size_choice = OptionButton.new()
	game.minimap_size_choice.tooltip_text = "单独调整小地图尺寸；2.5D 菱形会伸出底部面板。"
	for index in game.MINIMAP_SIZE_OPTIONS.size():
		game.minimap_size_choice.add_item(["小", "中", "大"][index])
	game.minimap_size_choice.custom_minimum_size.y = 42
	game._style_button(game.minimap_size_choice)
	_add_settings_option_row(display_tab, "小地图大小", game.minimap_size_choice)
	game.ui_scale_choice = OptionButton.new()
	game.ui_scale_choice.tooltip_text = "调整按钮、图标和面板大小；不改变地图与镜头。"
	game.ui_scale_choice.custom_minimum_size.y = 42
	game._style_button(game.ui_scale_choice)
	_add_settings_option_row(display_tab, "界面缩放", game.ui_scale_choice)
	game.text_scale_choice = OptionButton.new()
	game.text_scale_choice.tooltip_text = "调整菜单、战斗界面和提示文字大小。"
	for scale in game.TEXT_SCALE_OPTIONS: game.text_scale_choice.add_item("%d%%" % roundi(scale * 100.0))
	game.text_scale_choice.custom_minimum_size.y = 42
	game._style_button(game.text_scale_choice)
	_add_settings_option_row(display_tab, "文字缩放", game.text_scale_choice)
	_add_menu_label(display_tab, "高于当前屏幕可用尺寸的选项不会显示。", RtsUiTypography.CAPTION)
	var controls_tab := VBoxContainer.new()
	controls_tab.name = "操作设置"
	controls_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls_tab.alignment = BoxContainer.ALIGNMENT_CENTER
	controls_tab.add_theme_constant_override("separation", 12)
	game.settings_tabs.add_child(controls_tab)
	game.edge_scroll_toggle = CheckButton.new()
	game.edge_scroll_toggle.text = "启用边缘卷页"
	game.edge_scroll_toggle.tooltip_text = "鼠标靠近窗口边缘时移动镜头"
	game.edge_scroll_toggle.custom_minimum_size.y = 42
	game.edge_scroll_toggle.add_theme_color_override("font_color", Color("f5e4bf"))
	_add_settings_toggle_row(controls_tab, game.edge_scroll_toggle)
	game.zoom_gesture_toggle = CheckButton.new()
	game.zoom_gesture_toggle.text = "启用缩放手势"
	game.zoom_gesture_toggle.tooltip_text = "双指捏合时缩放镜头；鼠标滚轮不受影响"
	game.zoom_gesture_toggle.custom_minimum_size.y = 42
	game.zoom_gesture_toggle.add_theme_color_override("font_color", Color("f5e4bf"))
	_add_settings_toggle_row(controls_tab, game.zoom_gesture_toggle)
	game.settings_tab_buttons.clear()
	for tab_index in game.settings_tabs.get_tab_count():
		var tab_button := Button.new()
		tab_button.text = game.settings_tabs.get_tab_title(tab_index)
		tab_button.custom_minimum_size.y = 46
		var index: int = tab_index
		tab_button.pressed.connect(func() -> void: game.settings_tabs.current_tab = index)
		sidebar.add_child(tab_button)
		game.settings_tab_buttons.append(tab_button)
	game.settings_tabs.tab_changed.connect(_update_settings_tab_buttons)
	_update_settings_tab_buttons(game.settings_tabs.current_tab)
	_add_menu_label(box, "保存后立即生效，下次启动仍会保留。", RtsUiTypography.CAPTION)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	box.add_child(buttons)
	var back_button := Button.new()
	back_button.text = "返回"
	back_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game._style_button(back_button)
	back_button.pressed.connect(_close_settings)
	buttons.add_child(back_button)
	var apply_button := Button.new()
	apply_button.text = "保存设置"
	apply_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game._style_button(apply_button, true)
	apply_button.pressed.connect(func() -> void:
		var index: int = game.resolution_choice.selected
		if index < 0 or index >= game.resolution_values.size(): return
		var resolution: Vector2i = game.resolution_values[index]
		if game.window_mode_choice.selected == 1:
			game.adaptive_resolution_enabled = resolution == Vector2i.ZERO
			game.windowed_resolution = game._adaptive_window_resolution() if game.adaptive_resolution_enabled else resolution
			game._apply_window_mode(true, false)
		else:
			game._apply_window_resolution(resolution, false)
		game.edge_scroll_enabled = game.edge_scroll_toggle.button_pressed
		game.zoom_gesture_enabled = game.zoom_gesture_toggle.button_pressed
		game.show_building_icons = game.building_icons_toggle.button_pressed
		game.show_building_names = game.building_names_toggle.button_pressed
		game._redraw_projected_entities()
		game.selected_view_mode_25d = game.projection_choice.selected == 1
		game.ui_scale = game.ui_scale_values[game.ui_scale_choice.selected]
		game.text_scale = game.TEXT_SCALE_OPTIONS[game.text_scale_choice.selected]
		game.minimap_size = game.MINIMAP_SIZE_OPTIONS[game.minimap_size_choice.selected]
		game.hud_ui._apply_minimap_size()
		game._apply_ui_scales()
		if game.started and game.view_mode_25d != game.selected_view_mode_25d: game._toggle_view_mode()
		game._save_settings()
		_close_settings()
	)
	buttons.add_child(apply_button)
	game.settings_overlay.hide()

func _add_settings_option_row(parent: VBoxContainer, title: String, choice: OptionButton) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size.x = SETTINGS_LABEL_WIDTH + SETTINGS_ROW_SPACING + SETTINGS_FIELD_WIDTH
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.add_theme_constant_override("separation", SETTINGS_ROW_SPACING)
	parent.add_child(row)
	var label := Label.new()
	label.text = title
	label.custom_minimum_size.x = SETTINGS_LABEL_WIDTH
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", RtsUiTypography.BODY)
	label.add_theme_color_override("font_color", Color("f0ddb1"))
	row.add_child(label)
	choice.custom_minimum_size.x = SETTINGS_FIELD_WIDTH
	choice.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(choice)

func _add_settings_toggle_row(parent: VBoxContainer, toggle: CheckButton) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size.x = SETTINGS_LABEL_WIDTH + SETTINGS_ROW_SPACING + SETTINGS_FIELD_WIDTH
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	parent.add_child(row)
	toggle.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(toggle)

func _update_settings_tab_buttons(active_tab: int) -> void:
	for index in game.settings_tab_buttons.size():
		game._style_menu_button(game.settings_tab_buttons[index], index == active_tab)

func _show_settings(from_pause := false) -> void:
	game.settings_from_pause = from_pause
	if not game._window_is_fullscreen() and not game.adaptive_resolution_enabled: game.windowed_resolution = game.get_window().size
	_refresh_resolution_options()
	game.window_mode_choice.select(1 if game._window_is_fullscreen() else 0)
	_refresh_ui_scale_options()
	game.text_scale_choice.select(game.TEXT_SCALE_OPTIONS.find(game.text_scale))
	game.edge_scroll_toggle.button_pressed = game.edge_scroll_enabled
	game.zoom_gesture_toggle.button_pressed = game.zoom_gesture_enabled
	game.building_icons_toggle.button_pressed = game.show_building_icons
	game.building_names_toggle.button_pressed = game.show_building_names
	game.projection_choice.select(1 if game.selected_view_mode_25d else 0)
	game.minimap_size_choice.select(game.MINIMAP_SIZE_OPTIONS.find(game.minimap_size))
	game.settings_tabs.current_tab = 0
	if not from_pause: game.menu_panel.hide()
	game.settings_overlay.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if game.cursor != null: game.cursor.hide()

func _close_settings() -> void:
	game.settings_overlay.hide()
	if game.settings_from_pause:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		game.menu_panel.show()
	game.settings_from_pause = false

func _refresh_resolution_options() -> void:
	game.resolution_choice.clear()
	game.resolution_values.clear()
	var adaptive_size: Vector2i = game._adaptive_window_resolution()
	game.resolution_values.append(Vector2i.ZERO)
	game.resolution_choice.add_item("自动（%d × %d）" % [adaptive_size.x, adaptive_size.y])
	var current: Vector2i = game.windowed_resolution if game._window_is_fullscreen() else game.get_window().size
	var usable := DisplayServer.screen_get_usable_rect(game.get_window().current_screen).size
	for resolution in game.WINDOW_RESOLUTIONS:
		if DisplayServer.get_name() != "headless" and resolution != current and (resolution.x > usable.x or resolution.y > usable.y): continue
		game.resolution_values.append(resolution)
		game.resolution_choice.add_item("%d × %d" % [resolution.x, resolution.y])
	if not game.resolution_values.has(current):
		game.resolution_values.append(current)
		game.resolution_choice.add_item("当前窗口：%d × %d" % [current.x, current.y])
	game.resolution_choice.select(0 if game.adaptive_resolution_enabled else game.resolution_values.find(current))

func _refresh_ui_scale_options() -> void:
	var wanted_scale: float = game.ui_scale
	if game.ui_scale_choice.selected >= 0 and game.ui_scale_choice.selected < game.ui_scale_values.size():
		wanted_scale = game.ui_scale_values[game.ui_scale_choice.selected]
	var available_size: Vector2
	if game.window_mode_choice.selected == 1 and DisplayServer.get_name() != "headless":
		available_size = Vector2(DisplayServer.screen_get_size(game.get_window().current_screen))
	elif game.resolution_choice.selected >= 0 and game.resolution_choice.selected < game.resolution_values.size():
		var selected_resolution: Vector2i = game.resolution_values[game.resolution_choice.selected]
		available_size = Vector2(game._adaptive_window_resolution() if selected_resolution == Vector2i.ZERO else selected_resolution)
	else:
		available_size = game.get_viewport_rect().size
	game.ui_scale_choice.clear()
	game.ui_scale_values.clear()
	for scale in game.UI_SCALE_OPTIONS:
		if game.MIN_UI_VIEWPORT_SIZE.x * scale > available_size.x or game.MIN_UI_VIEWPORT_SIZE.y * scale > available_size.y: continue
		game.ui_scale_values.append(scale)
		game.ui_scale_choice.add_item("%d%%" % roundi(scale * 100.0))
	if game.ui_scale_values.is_empty():
		game.ui_scale_values.append(game.UI_SCALE_OPTIONS[0])
		game.ui_scale_choice.add_item("%d%%" % roundi(game.UI_SCALE_OPTIONS[0] * 100.0))
	var chosen_index: int = game.ui_scale_values.find(wanted_scale)
	game.ui_scale_choice.select(chosen_index if chosen_index >= 0 else game.ui_scale_values.size() - 1)

func _show_menu() -> void:
	game.paused = false
	game.use_lobby_setup = false
	if game.pause_overlay != null: game.pause_overlay.hide()
	if game.settings_overlay != null: game.settings_overlay.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if game.cursor != null: game.cursor.hide()
	game.menu_backdrop.show()
	game.hud_top.hide()
	game.hud_bottom.hide()
	game.global_queue_panel.hide()
	_show_home_menu()

func _menu_panel_size(dimensions: Vector2) -> void:
	game.menu_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	game.menu_panel.custom_minimum_size = dimensions
	game.menu_panel.add_theme_stylebox_override("panel", game._parchment_style(Color("d1bb8c"), 23))
	game.menu_panel.offset_left = -dimensions.x * 0.5
	game.menu_panel.offset_top = -dimensions.y * 0.5
	game.menu_panel.offset_right = dimensions.x * 0.5
	game.menu_panel.offset_bottom = dimensions.y * 0.5
	_clear_menu_panel()

func _menu_panel_full_view() -> void:
	game.menu_panel.custom_minimum_size = Vector2.ZERO
	game.menu_panel.add_theme_stylebox_override("panel", game._parchment_style(Color("d1bb8c"), 16))
	game.menu_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_clear_menu_panel()

func _clear_menu_panel() -> void:
	for child in game.menu_panel.get_children():
		game.menu_panel.remove_child(child)
		child.queue_free()

func _show_home_menu() -> void:
	_menu_panel_size(Vector2(600, 550))
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 20)
	game.menu_panel.add_child(box)
	var title := _menu_ink_label(box, "帝 国 时 代", RtsUiTypography.HERO)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var subtitle := _menu_ink_label(box, "AGE OF EMPIRE LITE", RtsUiTypography.SUBSECTION_TITLE)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var rule := ColorRect.new()
	rule.color = Color("88663d")
	rule.custom_minimum_size.y = 2
	box.add_child(rule)
	var description := _menu_ink_label(box, "建立帝国，探索战场，争夺胜利。", RtsUiTypography.BODY)
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var start_button := Button.new()
	start_button.text = "开 始 游 戏"
	start_button.custom_minimum_size.y = 55
	game._style_button(start_button, true)
	start_button.pressed.connect(_show_setup_menu)
	box.add_child(start_button)
	var unit_preview_button := Button.new()
	unit_preview_button.text = "单 位 预 览"
	unit_preview_button.custom_minimum_size.y = 43
	game._style_menu_button(unit_preview_button)
	unit_preview_button.pressed.connect(func() -> void: _show_unit_preview(str(game.lobby_players[0]["civilization"])))
	box.add_child(unit_preview_button)
	var tech_tree_button := Button.new()
	tech_tree_button.text = "查看科技树"
	tech_tree_button.custom_minimum_size.y = 43
	game._style_menu_button(tech_tree_button)
	tech_tree_button.pressed.connect(func() -> void: _show_tech_tree(str(game.lobby_players[0]["civilization"])))
	box.add_child(tech_tree_button)
	var settings_button := Button.new()
	settings_button.text = "设 置"
	settings_button.custom_minimum_size.y = 43
	game._style_menu_button(settings_button)
	settings_button.pressed.connect(func() -> void: _show_settings())
	box.add_child(settings_button)
	var quit_button := Button.new()
	quit_button.text = "退 出 游 戏"
	quit_button.custom_minimum_size.y = 43
	game._style_menu_button(quit_button)
	quit_button.pressed.connect(func() -> void: game.get_tree().quit())
	box.add_child(quit_button)
	game.menu_panel.show()

func _show_setup_menu() -> void:
	_menu_panel_full_view()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	game.menu_panel.add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	var title := _menu_ink_label(header, "对 局 设 置", RtsUiTypography.PAGE_TITLE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var subtitle := _menu_ink_label(header, "SKIRMISH SETUP", RtsUiTypography.CAPTION)
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	var divider := ColorRect.new()
	divider.color = Color("80613a")
	divider.custom_minimum_size.y = 2
	box.add_child(divider)
	var body_scroll := ScrollContainer.new()
	body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(body_scroll)
	var body := HBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	body_scroll.add_child(body)
	body_scroll.resized.connect(func() -> void: body.custom_minimum_size.y = body_scroll.size.y)
	var players_column := _menu_section(body, "玩家信息", 0)
	players_column.get_parent().size_flags_stretch_ratio = 1.7
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 6)
	players_column.add_child(heading)
	var player_heading := _menu_ink_label(heading, "玩家", RtsUiTypography.CAPTION)
	player_heading.custom_minimum_size.x = 80
	player_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_heading.size_flags_stretch_ratio = 1.2
	var difficulty_heading := _menu_ink_label(heading, "AI 强度", RtsUiTypography.CAPTION)
	difficulty_heading.custom_minimum_size.x = 100
	difficulty_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nation_heading := _menu_ink_label(heading, "国家", RtsUiTypography.CAPTION)
	nation_heading.custom_minimum_size.x = 115
	nation_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nation_heading.size_flags_stretch_ratio = 1.2
	var team_heading := _menu_ink_label(heading, "队伍", RtsUiTypography.CAPTION)
	team_heading.custom_minimum_size.x = 58
	team_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	team_heading.size_flags_stretch_ratio = 0.7
	var color_heading := _menu_ink_label(heading, "颜色", RtsUiTypography.CAPTION)
	color_heading.custom_minimum_size.x = 58
	color_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	color_heading.size_flags_stretch_ratio = 0.7
	_menu_ink_label(heading, "科技树", RtsUiTypography.CAPTION).custom_minimum_size.x = 72
	_menu_ink_label(heading, "", RtsUiTypography.CAPTION).custom_minimum_size.x = 32
	game.player_list = VBoxContainer.new()
	game.player_list.add_theme_constant_override("separation", 7)
	players_column.add_child(game.player_list)
	game.add_player_button = Button.new()
	game.add_player_button.text = "+  新增玩家"
	game.add_player_button.custom_minimum_size.y = 40
	game._style_menu_button(game.add_player_button)
	game.add_player_button.pressed.connect(func() -> void:
		if game.lobby_players.size() >= 4: return
		var civilization_ids := GameData.CIVILIZATIONS.keys()
		game.lobby_players.append({"civilization": civilization_ids[game.lobby_players.size() % civilization_ids.size()], "difficulty": "normal", "team": mini(game.lobby_players.size() + 1, 3), "color": game.lobby_players.size()})
		_refresh_player_rows()
	)
	players_column.add_child(game.add_player_button)
	var player_hint := _menu_ink_label(players_column, "同队共享视野与胜利；至少需要两个队伍。", RtsUiTypography.CAPTION)
	player_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var settings_column := _menu_section(body, "对局设置", 0)
	_menu_ink_label(settings_column, "地图选择", RtsUiTypography.CAPTION)
	game.map_style_choice = OptionButton.new()
	for option in ["平衡", "大湖", "高地", "群岛"]: game.map_style_choice.add_item(option)
	game.map_style_choice.selected = ["balanced", "lakes", "highlands", "islands"].find(game.selected_map_style)
	game._style_menu_button(game.map_style_choice)
	settings_column.add_child(game.map_style_choice)
	_menu_ink_label(settings_column, "地图大小", RtsUiTypography.CAPTION)
	game.map_size_choice = OptionButton.new()
	game.map_size_choice.add_item("标准地图")
	game.map_size_choice.add_item("大型地图")
	game.map_size_choice.selected = 1 if game.selected_map_size.x > game.WORLD_SIZE.x else 0
	game._style_menu_button(game.map_size_choice)
	settings_column.add_child(game.map_size_choice)
	_menu_ink_label(settings_column, "初始资源", RtsUiTypography.CAPTION)
	game.initial_resources_choice = OptionButton.new()
	for option in ["较少", "标准", "丰富"]: game.initial_resources_choice.add_item(option)
	game.initial_resources_choice.selected = game.selected_initial_resources
	game._style_menu_button(game.initial_resources_choice)
	settings_column.add_child(game.initial_resources_choice)
	_menu_ink_label(settings_column, "战争迷雾", RtsUiTypography.CAPTION)
	game.fog_mode_choice = OptionButton.new()
	for option in ["开启", "完整关闭", "显示地形"]: game.fog_mode_choice.add_item(option)
	game.fog_mode_choice.selected = ["enabled", "disabled", "terrain"].find(game.selected_fog_mode)
	game._style_menu_button(game.fog_mode_choice)
	settings_column.add_child(game.fog_mode_choice)
	_menu_ink_label(settings_column, "地图种子", RtsUiTypography.CAPTION)
	game.map_seed_input = LineEdit.new()
	game.map_seed_input.placeholder_text = "留空则随机生成"
	game.map_seed_input.add_theme_stylebox_override("normal", game._button_style(Color("eadbb4"), Color("9b784b")))
	game.map_seed_input.add_theme_color_override("font_color", Color("3d2b1d"))
	game.map_seed_input.add_theme_color_override("font_placeholder_color", Color("826949"))
	settings_column.add_child(game.map_seed_input)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	box.add_child(footer)
	var back_button := Button.new()
	back_button.text = "返 回"
	back_button.custom_minimum_size = Vector2(160, 47)
	game._style_menu_button(back_button)
	back_button.pressed.connect(_show_home_menu)
	footer.add_child(back_button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	game.setup_warning_label = _menu_ink_label(footer, "", RtsUiTypography.CAPTION)
	game.setup_warning_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	game.setup_start_button = Button.new()
	game.setup_start_button.text = "开 始 对 局"
	game.setup_start_button.custom_minimum_size = Vector2(210, 47)
	game._style_button(game.setup_start_button, true)
	game.setup_start_button.pressed.connect(_begin_menu_match)
	footer.add_child(game.setup_start_button)
	_refresh_player_rows()
	game.menu_panel.show()

func _refresh_player_rows() -> void:
	if game.player_list == null: return
	for child in game.player_list.get_children():
		game.player_list.remove_child(child)
		child.queue_free()
	var civilization_ids := GameData.CIVILIZATIONS.keys()
	for index in game.lobby_players.size():
		var slot: int = index
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		game.player_list.add_child(row)
		var player_name := _menu_ink_label(row, "玩家 %d%s" % [slot + 1, " (你)" if slot == 0 else ""], RtsUiTypography.BODY)
		player_name.custom_minimum_size.x = 80
		player_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		player_name.size_flags_stretch_ratio = 1.2
		player_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var difficulty := OptionButton.new()
		difficulty.custom_minimum_size.x = 100
		difficulty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if slot == 0:
			difficulty.add_item("人类")
			difficulty.disabled = true
		else:
			for label in ["简单", "普通", "困难"]: difficulty.add_item(label)
			difficulty.selected = ["easy", "normal", "hard"].find(game.lobby_players[slot]["difficulty"])
			difficulty.item_selected.connect(func(value: int) -> void:
				game.lobby_players[slot]["difficulty"] = ["easy", "normal", "hard"][value]
			)
		game._style_menu_button(difficulty)
		row.add_child(difficulty)
		var civilization := OptionButton.new()
		civilization.custom_minimum_size.x = 115
		civilization.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		civilization.size_flags_stretch_ratio = 1.2
		for civ in civilization_ids: civilization.add_item(GameData.CIVILIZATIONS[civ]["label"])
		civilization.selected = civilization_ids.find(game.lobby_players[slot]["civilization"])
		civilization.item_selected.connect(func(value: int) -> void:
			game.lobby_players[slot]["civilization"] = civilization_ids[value]
		)
		game._style_menu_button(civilization)
		row.add_child(civilization)
		var team := OptionButton.new()
		team.custom_minimum_size.x = 58
		team.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		team.size_flags_stretch_ratio = 0.7
		for team_id in range(1, 4): team.add_item(str(team_id))
		team.selected = clampi(int(game.lobby_players[slot].get("team", slot + 1)) - 1, 0, 2)
		team.item_selected.connect(func(value: int) -> void:
			game.lobby_players[slot]["team"] = value + 1
			_update_lobby_team_state()
		)
		game._style_menu_button(team)
		row.add_child(team)
		var color_choice := OptionButton.new()
		color_choice.custom_minimum_size.x = 58
		color_choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		color_choice.size_flags_stretch_ratio = 0.7
		for color_index in game.PLAYER_COLORS.size():
			color_choice.add_item("")
			color_choice.set_item_icon(color_index, _color_swatch(game.PLAYER_COLORS[color_index]))
		color_choice.selected = clampi(int(game.lobby_players[slot].get("color", slot)), 0, game.PLAYER_COLORS.size() - 1)
		color_choice.tooltip_text = game.PLAYER_COLOR_NAMES[color_choice.selected]
		color_choice.item_selected.connect(func(value: int) -> void:
			_set_lobby_player_color(slot, value)
		)
		game._style_menu_button(color_choice)
		row.add_child(color_choice)
		var tree_button := Button.new()
		tree_button.text = "科技树"
		tree_button.custom_minimum_size.x = 72
		game._style_menu_button(tree_button)
		tree_button.pressed.connect(func() -> void: _show_tech_tree(str(game.lobby_players[slot]["civilization"])))
		row.add_child(tree_button)
		var remove_button := Button.new()
		remove_button.text = "×"
		remove_button.custom_minimum_size.x = 32
		remove_button.disabled = slot == 0 or game.lobby_players.size() <= 2
		remove_button.tooltip_text = "移除玩家"
		game._style_menu_button(remove_button)
		remove_button.pressed.connect(func() -> void:
			game.lobby_players.remove_at(slot)
			_refresh_player_rows()
		)
		row.add_child(remove_button)
	game.add_player_button.disabled = game.lobby_players.size() >= 4
	_update_lobby_team_state()

func _color_swatch(color: Color) -> ImageTexture:
	var swatch := Image.create(20, 20, false, Image.FORMAT_RGBA8)
	swatch.fill(color)
	return ImageTexture.create_from_image(swatch)

func _set_lobby_player_color(slot: int, color_index: int) -> void:
	var previous_color := int(game.lobby_players[slot].get("color", slot))
	for other_slot in game.lobby_players.size():
		if other_slot != slot and int(game.lobby_players[other_slot].get("color", other_slot)) == color_index:
			game.lobby_players[other_slot]["color"] = previous_color
			break
	game.lobby_players[slot]["color"] = color_index
	_refresh_player_rows()

func _show_tech_tree(civilization: String, age := 1) -> void:
	if not GameData.CIVILIZATIONS.has(civilization): return
	if game.tech_tree_overlay != null: game.tech_tree_overlay.queue_free()
	game.tech_tree_page = game.TECH_TREE_PAGE.new()
	game.tech_tree_page.civilization_selected.connect(_show_tech_tree)
	game.tech_tree_page.close_requested.connect(_close_tech_tree)
	game.tech_tree_page.build(game.menu_panel.get_parent(), civilization, game._style_button, age)
	game.tech_tree_overlay = game.tech_tree_page.overlay
	game.tech_tree_civilization_choice = game.tech_tree_page.civilization_choice
	game.menu_panel.hide()

func _show_unit_preview(civilization: String) -> void:
	if game.unit_preview_page != null: game.unit_preview_page.queue_free()
	game.unit_preview_page = game.UNIT_PREVIEW_PAGE.new()
	game.unit_preview_page.close_requested.connect(_close_unit_preview)
	game.unit_preview_page.build(game.menu_panel.get_parent(), civilization, game._style_button)
	game.menu_panel.hide()

func _close_unit_preview() -> void:
	if game.unit_preview_page != null:
		game.unit_preview_page.queue_free()
		game.unit_preview_page = null
	game.menu_panel.show()

func _close_tech_tree() -> void:
	if game.tech_tree_overlay != null:
		game.tech_tree_overlay.queue_free()
		game.tech_tree_overlay = null
		game.tech_tree_civilization_choice = null
	game.tech_tree_page = null
	game.menu_panel.show()

func _update_lobby_team_state() -> void:
	var unique_teams := {}
	for player in game.lobby_players: unique_teams[int(player.get("team", 1))] = true
	var valid := unique_teams.size() >= 2
	game.setup_start_button.disabled = not valid
	game.setup_warning_label.text = "至少需要两个队伍" if not valid else ""

func _menu_ink_label(parent: Node, value: String, size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("3a2a1b"))
	parent.add_child(label)
	return label

func _menu_section(parent: HBoxContainer, heading: String, width: float) -> VBoxContainer:
	var panel := PanelContainer.new()
	if width > 0: panel.custom_minimum_size.x = width
	else: panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", game._parchment_style(Color("deca9e"), 14))
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	panel.add_child(column)
	_menu_ink_label(column, heading, RtsUiTypography.SECTION_TITLE)
	return column

func _begin_menu_match() -> void:
	var unique_teams := {}
	for player in game.lobby_players: unique_teams[int(player.get("team", 1))] = true
	if unique_teams.size() < 2: return
	var count: int = game.lobby_players.size()
	var requested := int(game.map_seed_input.text) if game.map_seed_input.text.is_valid_int() else -1
	match_requested.emit({
		"match_mode": "duel" if count == 2 else "ffa3" if count == 3 else "ffa4",
		"map_size": Vector2(3000, 3000) if game.map_size_choice.selected == 1 else game.WORLD_SIZE,
		"map_style": ["balanced", "lakes", "highlands", "islands"][game.map_style_choice.selected],
		"initial_resources": game.initial_resources_choice.selected,
		"fog_mode": ["enabled", "disabled", "terrain"][game.fog_mode_choice.selected],
		"seed": requested,
	})

func _add_menu_label(parent: Node, value: String, size: int) -> void:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("f0ddb1"))
	parent.add_child(label)

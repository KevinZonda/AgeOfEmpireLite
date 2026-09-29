extends Node2D
const RtsUiTypography = preload("res://scripts/ui/typography.gd")

const WORLD_SIZE := Vector2(2400, 2400)
const START_CAMERA_POINT := Vector2(630, 820)
const WINDOW_RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1440, 810), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const UI_SCALE_OPTIONS := [0.75, 1.0, 1.25, 1.5]
const TEXT_SCALE_OPTIONS := [0.75, 1.0, 1.25, 1.5, 1.75, 2.0]
static var base_tooltip_font_size := -1
const MINIMAP_SIZE_OPTIONS := [160, 216, 264]
const MIN_UI_VIEWPORT_SIZE := Vector2(1280, 720)
const SETTINGS_PATH := "user://settings.cfg"
const LEGACY_DISPLAY_SETTINGS_PATH := "user://display.cfg"
const CAMERA_PAN_SPEED := 570.0
const GESTURE_PAN_PIXELS := 32.0
const EDGE_SCROLL_MARGIN := 28.0
const SELECTION_DRAG_THRESHOLD := 12.0
const SELECTION_DRAG_VISUAL_THRESHOLD := 1.0
const UNIT_SCENE := preload("res://scripts/entities/unit.gd")
const BUILDING_SCENE := preload("res://scripts/entities/building.gd")
const BUILD_GRID_SIZE := 25.0 # Half a terrain cell keeps existing building art near its current scale.
const RESOURCE_SCENE := preload("res://scripts/entities/resource_node.gd")
const SELECTION_DRAG_OVERLAY := preload("res://scripts/ui/selection_drag_overlay.gd")
const SELECTION_PORTRAIT := preload("res://scripts/ui/selection_portrait.gd")
const MENU_BACKDROP := preload("res://scripts/ui/menu_backdrop.gd")
const TECH_TREE_PAGE := preload("res://scripts/ui/tech_tree_page.gd")
const UNIT_PREVIEW_PAGE := preload("res://scripts/ui/unit_preview_page.gd")
const MENU_UI := preload("res://scripts/ui/game_menu_ui.gd")
const HUD_UI := preload("res://scripts/ui/game_hud_ui.gd")
const PlayerSelection = preload("res://scripts/player/player_selection.gd")
const PlayerOrders = preload("res://scripts/player/player_orders.gd")
const MATCH_ECONOMY := preload("res://scripts/match/match_economy.gd")
const MATCH_PRODUCTION := preload("res://scripts/match/match_production.gd")
const FEEDBACK_AUDIO := preload("res://scripts/ui/feedback_audio.gd")
const MILITARY_RESEARCH_BUILDINGS := ["barracks", "archery_range", "stable", "siege_workshop", "dock", "white_tower", "wynguard", "royal_institute"]
const UNIT_ABILITY_ACTIONS := [
	{"id": "palings", "label": "架设拒马", "kinds": ["longbow"]},
	{"id": "volley", "label": "万箭齐发", "kinds": ["longbow"]},
	{"id": "pavise", "label": "部署大盾", "kinds": ["arbaletrier"]},
	{"id": "helmsman", "label": "掌舵人", "kinds": ["warship"]},
	{"id": "convert", "label": "招降", "kinds": ["monk"]},
	{"id": "camp", "label": "预备营地", "kinds": ["scout", "man_at_arms"], "civilization": "English"},
	{"id": "artillery_shot", "label": "炮击齐射", "kinds": ["cannon"], "producer_landmark": "fr_college_of_artillery"},
]

enum SelectionDragPhase { IDLE, BLOCKED, CANDIDATE, ACTIVE }
const PLAYER_COLOR_NAMES := ["蓝色", "红色", "黄色", "绿色", "青色", "紫色", "橙色", "粉色"]
const PLAYER_COLORS := [
	Color("4e9bea"), Color("e65852"), Color("e5c44b"), Color("4ac57b"),
	Color("4ac5c5"), Color("a77bd8"), Color("e5ae4b"), Color("e58fba"),
]

var world_size := WORLD_SIZE
var civilizations := ["English", "French"]
var teams: Array[int] = [0, 1]
var match_mode := "duel"
var defeated_players: Array[int] = []
var players: Array[Dictionary] = []
var units: Array[RtsUnit] = []
var buildings: Array[RtsBuilding] = []
var resources: Array[RtsResource] = []
var trade_posts: Array[RtsTradePost] = []
var relics: Array[RtsRelic] = []
var market_supply := {"food": 0, "wood": 0, "stone": 0}
var selected: Array[Node2D] = []
var control_groups: Dictionary = {}
var last_group_key := -1
var last_group_press_time := -10.0
var camera: Camera2D
var world_map: RtsWorldMap
var navigation: RtsNavigation
var weather: RtsWeather
var fog: RtsFogOfWar
var objectives: RtsObjectiveManager
var map_seed := 0
var map_style := "balanced"
var selected_map_size := WORLD_SIZE
var selected_map_style := "balanced"
var map_size_choice: OptionButton
var map_style_choice: OptionButton
var map_seed_input: LineEdit
var projection_choice: OptionButton
var initial_resources_choice: OptionButton
var fog_mode_choice: OptionButton
var player_list: VBoxContainer
var add_player_button: Button
var setup_start_button: Button
var setup_warning_label: Label
var lobby_players: Array[Dictionary] = [
	{"civilization": "English", "difficulty": "human", "team": 1, "color": 0},
	{"civilization": "French", "difficulty": "normal", "team": 2, "color": 1},
]
var use_lobby_setup := false
var selected_initial_resources := 1
var selected_fog_mode := "enabled"
var selected_view_mode_25d := false
var started := false
var game_over := false
var paused := false
var view_mode_25d := false
var formation_mode := "balanced"
var formation_width := 5
var selected_civ := "English"
var selected_opponent_civ := "French"
var build_mode := ""
var pending_landmark_id := ""
var build_page := 0
var order_mode := ""
var dragging := false
var wall_dragging := false
var wall_vertical := false
var wall_start := Vector2.ZERO
var wall_end := Vector2.ZERO
var drag_start_screen := Vector2.ZERO
var drag_current_screen := Vector2.ZERO
var selection_drag_phase := SelectionDragPhase.IDLE
var selection_drag_additive := false
var selection_previous_left_down := false
var ai_think_timers: Dictionary = {}
var iso_sort_timer := 0.0
var ai: RtsAiController
var ai_controllers: Array[RtsAiController] = []
var hud_timer := 0.0
var notice_timer := 0.0
var hit_lines: Array[Dictionary] = []
var order_markers: Array[Dictionary] = []
var world_effects: Array[Dictionary] = []
var feedback_audio: Node
var match_statistics := RtsMatchStatistics.new()

var top_label: Label
var resource_readouts: Dictionary = {}
var population_label: Label
var hud_top: PanelContainer
var hud_bottom: PanelContainer
var menu_backdrop: Control
var idle_villager_button: Button
var info_label: Label
var detail_label: Label
var selection_portrait
var selection_health: ProgressBar
var selection_progress: ProgressBar
var queue_label: Label
var queue_controls: HBoxContainer
var global_queue_panel: PanelContainer
var global_queue_list: VBoxContainer
var view_button: Button
var command_title: Label
var notice_label: Label
var action_bar: GridContainer
var command_buttons: Array[RtsCommandButton] = []
var hotkey_buttons: Dictionary = {}
var minimap: RtsMinimap
var menu_ui: MENU_UI
var hud_ui: HUD_UI
var ui_root: Control
var ui_scale := 1.0
var text_scale := 1.0
var applied_world_text_scale := -1.0
var minimap_size := 216
var show_building_icons := true
var show_building_names := true
var building_icons_toggle: CheckButton
var building_names_toggle: CheckButton
var ui_scale_choice: OptionButton
var text_scale_choice: OptionButton
var minimap_size_choice: OptionButton
var ui_scale_values: Array[float] = []
var ui_scale_update_pending := false
var menu_panel: PanelContainer
var tech_tree_overlay: ColorRect
var tech_tree_civilization_choice: OptionButton
var tech_tree_page
var unit_preview_page
var age_choice_overlay: ColorRect
var result_panel: PanelContainer
var pause_overlay: ColorRect
var settings_overlay: ColorRect
var settings_tabs: TabContainer
var settings_tab_buttons: Array[Button] = []
var window_mode_choice: OptionButton
var resolution_choice: OptionButton
var resolution_values: Array[Vector2i] = []
var windowed_resolution := Vector2i.ZERO
var adaptive_resolution_enabled := false
var adaptive_usable_rect := Rect2i()
var adaptive_resolution_check_timer := 0.0
var fullscreen_enabled := false
var edge_scroll_toggle: CheckButton
var edge_scroll_enabled := true
var zoom_gesture_toggle: CheckButton
var zoom_gesture_enabled := true
var settings_from_pause := false
var cursor: GameCursor
var selection_drag_overlay: Variant

func _ready() -> void:
	_load_ui_font()
	if base_tooltip_font_size < 0:
		base_tooltip_font_size = ThemeDB.get_default_theme().get_font_size("font_size", "TooltipLabel")
	# The headless display starts at 64×64 with stretch disabled; use the
	# game's minimum supported viewport for simulation and UI tests.
	if DisplayServer.get_name() == "headless" and get_window().size == Vector2i(64, 64):
		get_window().size = Vector2i(1280, 720)
	_load_settings()
	world_map = RtsWorldMap.new()
	world_map.z_index = -10
	add_child(world_map)
	world_map.hide()
	navigation = RtsNavigation.new(self, world_map)
	camera = Camera2D.new()
	camera.position = START_CAMERA_POINT
	# We clamp the rotated viewport ourselves. Camera2D's axis-aligned limits
	# would otherwise pin the projected view against the map edge.
	camera.limit_left = -100000
	camera.limit_top = -100000
	camera.limit_right = 100000
	camera.limit_bottom = 100000
	camera.ignore_rotation = false
	add_child(camera)
	camera.make_current()
	feedback_audio = FEEDBACK_AUDIO.new()
	add_child(feedback_audio)
	weather = RtsWeather.new()
	weather.z_index = -6
	add_child(weather)
	weather.hide()
	fog = RtsFogOfWar.new()
	fog.z_index = -5
	add_child(fog)
	fog.setup(self)
	fog.hide()
	objectives = RtsObjectiveManager.new()
	objectives.z_index = -7
	add_child(objectives)
	objectives.victory.connect(func(owner_id: int, reason: String) -> void: _finish_game(not is_enemy(0, owner_id), reason))
	objectives.site_captured.connect(func(_index: int, owner_id: int) -> void:
		match_statistics.record_event(owner_id, "占领圣地")
		if owner_id == 0: notify_player("圣地已占领")
	)
	ai = RtsAiController.new(self)
	_create_hud()
	get_viewport().size_changed.connect(_apply_ui_scales)
	get_tree().node_added.connect(_on_ui_node_added)
	_apply_ui_scales()
	_create_cursor()
	_show_menu()
	queue_redraw()

func _load_ui_font() -> void:
	var font_data := FileAccess.get_file_as_bytes("res://assets/fonts/NotoSansSC-Regular.otf")
	if font_data.is_empty():
		push_error("Unable to read the bundled UI font")
		return
	var font := FontFile.new()
	font.data = font_data
	ThemeDB.fallback_font = font
	var default_theme := ThemeDB.get_default_theme()
	default_theme.default_font = font
	for font_name in ["bold_font", "italics_font", "bold_italics_font"]:
		var variation := default_theme.get_font(font_name, "RichTextLabel") as FontVariation
		if variation != null:
			variation.base_font = font

func _exit_tree() -> void:
	if get_tree().node_added.is_connected(_on_ui_node_added): get_tree().node_added.disconnect(_on_ui_node_added)
	_cancel_selection_drag()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_cancel_selection_drag()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN and started and not paused and not game_over:
		_apply_gameplay_mouse_mode()
		_reset_selection_pointer()

func _create_cursor() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	selection_drag_overlay = SELECTION_DRAG_OVERLAY.new()
	layer.add_child(selection_drag_overlay)
	cursor = GameCursor.new()
	cursor.text_scale = text_scale
	layer.add_child(cursor)
	cursor.hide()

func _create_hud() -> void:
	menu_ui = MENU_UI.new(self)
	menu_ui.match_requested.connect(_start_lobby_match)
	hud_ui = HUD_UI.new(self)
	add_child(hud_ui)
	hud_ui._create_hud()

func _on_ui_node_added(node: Node) -> void:
	if ui_root == null or not (node is Control or node is PopupMenu) or not ui_root.is_ancestor_of(node) or ui_scale_update_pending: return
	ui_scale_update_pending = true
	call_deferred("_apply_ui_scales")

func _apply_ui_scales() -> void:
	ui_scale_update_pending = false
	if ui_root == null or not is_instance_valid(ui_root): return
	var viewport_size := get_viewport_rect().size
	var max_scale := minf(viewport_size.x / MIN_UI_VIEWPORT_SIZE.x, viewport_size.y / MIN_UI_VIEWPORT_SIZE.y)
	var effective_scale := maxf(0.5, minf(ui_scale, max_scale))
	# CanvasItem font oversampling sees Control transforms, but not CanvasLayer transforms.
	ui_root.scale = Vector2.ONE * effective_scale
	ui_root.size = viewport_size / effective_scale
	RtsUiTypography.apply_tree(ui_root, text_scale, effective_scale, base_tooltip_font_size)
	hud_ui.call_deferred("_fit_top_hud")
	hud_ui.call_deferred("_fit_bottom_hud")
	if cursor != null:
		cursor.text_scale = text_scale
		cursor.queue_redraw()
	if not is_equal_approx(applied_world_text_scale, text_scale):
		applied_world_text_scale = text_scale
		_redraw_projected_entities()
		if objectives != null: objectives.queue_redraw()
		queue_redraw()

func _hud_panel_style(color: Color, margin: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("a7894f")
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.38)
	style.shadow_size = 5
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = margin
	style.content_margin_bottom = margin
	return style

func _add_resource_readout(parent: HBoxContainer, kind: String) -> void:
	var chip := PanelContainer.new()
	chip.custom_minimum_size.x = 92
	chip.add_theme_stylebox_override("panel", _hud_panel_style(Color("352b1e"), 5))
	parent.add_child(chip)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	chip.add_child(row)
	var icon := TextureRect.new()
	icon.texture = RtsCommandButton._texture_at("res://assets/ui/resource_icons/%s.png" % kind)
	icon.custom_minimum_size = Vector2(30, 28)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var value := Label.new()
	value.text = "0"
	value.add_theme_font_size_override("font_size", RtsUiTypography.BODY)
	value.add_theme_color_override("font_color", Color("f4e6c4"))
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(value)
	resource_readouts[kind] = value
	chip.tooltip_text = GameData.RESOURCE_LABELS[kind]

func _button_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style

func _parchment_style(fill: Color, margin: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = Color("4a321d")
	style.set_border_width_all(5)
	style.set_corner_radius_all(3)
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 12
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = margin
	style.content_margin_bottom = margin
	return style

func _style_menu_button(button: BaseButton, selected := false) -> void:
	var fill := Color("5a3b22") if selected else Color("e5d4a9")
	var edge := Color("b98c48") if selected else Color("9b784b")
	button.add_theme_stylebox_override("normal", _button_style(fill, edge))
	button.add_theme_stylebox_override("hover", _button_style(fill.lightened(0.08), Color("d3a85f")))
	button.add_theme_stylebox_override("pressed", _button_style(fill.darkened(0.12), Color("ad854e")))
	button.add_theme_color_override("font_color", Color("f7e8bd") if selected else Color("3d2b1d"))
	button.add_theme_color_override("font_hover_color", Color("fff1cf") if selected else Color("3d2b1d"))
	button.add_theme_color_override("font_pressed_color", Color("f7e8bd") if selected else Color("3d2b1d"))

func _style_button(button: BaseButton, primary := false) -> void:
	var base := Color("715028") if primary else Color("3d3224")
	button.add_theme_stylebox_override("normal", _button_style(base, Color("a88b56")))
	button.add_theme_stylebox_override("hover", _button_style(base.lightened(0.14), Color("dfc584")))
	button.add_theme_stylebox_override("pressed", _button_style(base.darkened(0.16), Color("f0d791")))
	button.add_theme_stylebox_override("disabled", _button_style(Color("302b24"), Color("615844")))
	button.add_theme_color_override("font_color", Color("f5e4bf"))
	button.add_theme_color_override("font_hover_color", Color("fff2d2"))
	button.add_theme_color_override("font_pressed_color", Color("ffe4a3"))
	button.add_theme_color_override("font_disabled_color", Color("948876"))

func _style_progress_bar(bar: ProgressBar, fill_color: Color) -> void:
	var background := StyleBoxFlat.new()
	background.bg_color = Color("1a1712")
	background.border_color = Color("8d7448")
	background.set_border_width_all(1)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)

func _add_pause_button(parent: Node, label_text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size.y = 36
	_style_button(button)
	button.pressed.connect(action)
	parent.add_child(button)

func _create_settings(parent: Control) -> void:
	menu_ui._create_settings(parent)

func _update_settings_tab_buttons(active_tab: int) -> void:
	menu_ui._update_settings_tab_buttons(active_tab)

func _show_settings(from_pause := false) -> void:
	menu_ui._show_settings(from_pause)

func _close_settings() -> void:
	menu_ui._close_settings()

func _refresh_resolution_options() -> void:
	menu_ui._refresh_resolution_options()

static func _fit_window_size_to_screen(usable_size: Vector2i) -> Vector2i:
	var minimum := Vector2i(MIN_UI_VIEWPORT_SIZE * UI_SCALE_OPTIONS[0])
	return Vector2i(
		mini(usable_size.x, maxi(minimum.x, floori(usable_size.x * 0.9))),
		mini(usable_size.y, maxi(minimum.y, floori(usable_size.y * 0.9)))
	)

func _adaptive_window_resolution() -> Vector2i:
	if DisplayServer.get_name() == "headless": return get_window().size
	return _fit_window_size_to_screen(DisplayServer.screen_get_usable_rect(get_window().current_screen).size)

func _apply_window_resolution(resolution: Vector2i, save_setting := true) -> void:
	var adaptive := resolution == Vector2i.ZERO
	if not adaptive and not WINDOW_RESOLUTIONS.has(resolution) and resolution != windowed_resolution and resolution != get_window().size: return
	var target := _adaptive_window_resolution() if adaptive else resolution
	var window := get_window()
	window.mode = Window.MODE_WINDOWED
	window.size = target
	windowed_resolution = target
	adaptive_resolution_enabled = adaptive
	fullscreen_enabled = false
	if DisplayServer.get_name() != "headless":
		var usable := DisplayServer.screen_get_usable_rect(window.current_screen)
		window.position = usable.position + (usable.size - target) / 2
		adaptive_usable_rect = usable if adaptive else Rect2i()
	if started: call_deferred("_clamp_camera_position")
	if save_setting: _save_settings()

func _window_is_fullscreen() -> bool:
	if DisplayServer.get_name() == "headless": return fullscreen_enabled
	return get_window().mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]

func _apply_window_mode(fullscreen: bool, save_setting := true) -> void:
	fullscreen_enabled = fullscreen
	if fullscreen:
		get_window().mode = Window.MODE_FULLSCREEN
	else:
		_apply_window_resolution(Vector2i.ZERO if adaptive_resolution_enabled else windowed_resolution, false)
	if started: call_deferred("_clamp_camera_position")
	if save_setting: _save_settings()

func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("display", "window_size", windowed_resolution)
	config.set_value("display", "adaptive_resolution", adaptive_resolution_enabled)
	config.set_value("display", "fullscreen", _window_is_fullscreen())
	config.set_value("display", "view_mode_25d", selected_view_mode_25d)
	config.set_value("display", "ui_scale", ui_scale)
	config.set_value("display", "text_scale", text_scale)
	config.set_value("display", "minimap_size", minimap_size)
	config.set_value("display", "show_building_icons", show_building_icons)
	config.set_value("display", "show_building_names", show_building_names)
	config.set_value("controls", "edge_scroll_enabled", edge_scroll_enabled)
	config.set_value("controls", "zoom_gesture_enabled", zoom_gesture_enabled)
	config.save(SETTINGS_PATH)

func _load_settings() -> void:
	windowed_resolution = get_window().size
	if DisplayServer.get_name() == "headless": return
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK and config.load(LEGACY_DISPLAY_SETTINGS_PATH) != OK: return
	selected_view_mode_25d = bool(config.get_value("display", "view_mode_25d", false))
	show_building_icons = bool(config.get_value("display", "show_building_icons", true))
	show_building_names = bool(config.get_value("display", "show_building_names", true))
	var saved_ui_scale: float = float(config.get_value("display", "ui_scale", 1.0))
	var saved_text_scale: float = float(config.get_value("display", "text_scale", 1.0))
	var saved_minimap_size: int = int(config.get_value("display", "minimap_size", 216))
	ui_scale = saved_ui_scale if UI_SCALE_OPTIONS.has(saved_ui_scale) else 1.0
	text_scale = saved_text_scale if TEXT_SCALE_OPTIONS.has(saved_text_scale) else 1.0
	minimap_size = saved_minimap_size if MINIMAP_SIZE_OPTIONS.has(saved_minimap_size) else 216
	edge_scroll_enabled = bool(config.get_value("controls", "edge_scroll_enabled", true))
	zoom_gesture_enabled = bool(config.get_value("controls", "zoom_gesture_enabled", true))
	var resolution: Variant = config.get_value("display", "window_size", Vector2i.ZERO)
	if bool(config.get_value("display", "adaptive_resolution", false)):
		_apply_window_resolution(Vector2i.ZERO, false)
	elif resolution is Vector2i and resolution.x > 0 and resolution.y > 0:
		var usable := DisplayServer.screen_get_usable_rect(get_window().current_screen).size
		if resolution.x <= usable.x and resolution.y <= usable.y:
			windowed_resolution = resolution
			_apply_window_resolution(resolution, false)
	if bool(config.get_value("display", "fullscreen", false)):
		_apply_window_mode(true, false)

func _show_menu() -> void:
	menu_ui._show_menu()

func _menu_panel_size(dimensions: Vector2) -> void:
	menu_ui._menu_panel_size(dimensions)

func _show_home_menu() -> void:
	menu_ui._show_home_menu()

func _show_setup_menu() -> void:
	menu_ui._show_setup_menu()

func _refresh_player_rows() -> void:
	menu_ui._refresh_player_rows()

func _color_swatch(color: Color) -> ImageTexture:
	return menu_ui._color_swatch(color)

func _set_lobby_player_color(slot: int, color_index: int) -> void:
	menu_ui._set_lobby_player_color(slot, color_index)

func _show_tech_tree(civilization: String) -> void:
	menu_ui._show_tech_tree(civilization)

func _close_tech_tree() -> void:
	menu_ui._close_tech_tree()

func _update_lobby_team_state() -> void:
	menu_ui._update_lobby_team_state()

func _menu_ink_label(parent: Node, value: String, size: int) -> Label:
	return menu_ui._menu_ink_label(parent, value, size)

func _menu_section(parent: HBoxContainer, heading: String, width: float) -> VBoxContainer:
	return menu_ui._menu_section(parent, heading, width)

func _begin_menu_match() -> void:
	menu_ui._begin_menu_match()

func _start_lobby_match(settings: Dictionary) -> void:
	match_mode = settings["match_mode"]
	selected_map_size = settings["map_size"]
	selected_map_style = settings["map_style"]
	selected_initial_resources = settings["initial_resources"]
	selected_fog_mode = settings["fog_mode"]
	use_lobby_setup = true
	start_game(lobby_players[0]["civilization"], settings["seed"], lobby_players[1]["civilization"])

func _add_menu_label(parent: Node, value: String, size: int) -> void:
	menu_ui._add_menu_label(parent, value, size)

func start_game(civ: String, requested_seed := -1, opponent_civ := "") -> void:
	if not GameData.CIVILIZATIONS.has(civ): return
	var civilization_ids := GameData.CIVILIZATIONS.keys()
	if opponent_civ == "" or not GameData.CIVILIZATIONS.has(opponent_civ):
		opponent_civ = civilization_ids[(civilization_ids.find(civ) + 1) % civilization_ids.size()]
	_clear_world()
	paused = false
	pause_overlay.hide()
	selected_civ = civ
	selected_opponent_civ = opponent_civ
	var player_count := lobby_players.size() if use_lobby_setup else 2 if match_mode == "duel" else 3 if match_mode == "ffa3" else 4
	teams.clear()
	civilizations.clear()
	players.clear()
	defeated_players.clear()
	market_supply = {"food": 0, "wood": 0, "stone": 0}
	for owner_id in player_count:
		teams.append(int(lobby_players[owner_id].get("team", owner_id + 1)) - 1 if use_lobby_setup else 0 if owner_id == 0 or match_mode == "team2" and owner_id == 2 else 1 if match_mode == "team2" else owner_id)
		civilizations.append(lobby_players[owner_id]["civilization"] if use_lobby_setup else civ if owner_id == 0 else civilization_ids[(civilization_ids.find(opponent_civ) + owner_id - 1) % civilization_ids.size()])
		var bank := {"food": 340 if owner_id == 0 else 420, "wood": 360 if owner_id == 0 else 420, "gold": 150 if owner_id == 0 else 170, "stone": 100, "age": 1, "researched": [], "landmarks": [], "dynasty": "Tang" if civilizations[owner_id] == "Chinese" else ""}
		if use_lobby_setup:
			var presets := [
				{"food": 200, "wood": 220, "gold": 100, "stone": 0},
				{"food": 340, "wood": 360, "gold": 150, "stone": 100},
				{"food": 700, "wood": 700, "gold": 400, "stone": 300},
			]
			bank.merge(presets[clampi(selected_initial_resources, 0, 2)], true)
		players.append(bank)
	started = true
	game_over = false
	map_seed = requested_seed if requested_seed >= 0 else randi_range(1, 2147483647)
	world_size = selected_map_size
	map_style = selected_map_style
	world_map.generate(map_seed, world_size, map_style, player_count)
	world_map.show()
	weather.setup(self, map_seed, world_size)
	weather.show()
	build_mode = ""
	pending_landmark_id = ""
	build_page = 0
	order_mode = ""
	ai_think_timers.clear()
	camera.position = spawn_point_for(0) + _scaled_point(START_CAMERA_POINT - Vector2(330, 720))
	menu_panel.hide()
	menu_backdrop.hide()
	hud_top.show()
	hud_bottom.show()
	result_panel.hide()
	_apply_gameplay_mouse_mode()
	_reset_selection_pointer()
	cursor.show()
	_spawn_map_resources()
	objectives.setup(self)
	_spawn_neutral_sites()
	for owner_id in player_count:
		var base := spawn_point_for(owner_id)
		spawn_building(owner_id, "town_center", base)
		for i in 5:
			var worker := spawn_unit(owner_id, "villager", base + Vector2((i % 3) * 29 - 30, 80 + (i / 3) * 28))
			var resource := find_nearest_resource(worker.position, "food" if i < 2 else "wood" if i < 4 else "gold", INF, -1, false, worker)
			if resource != null: worker.order_gather(resource)
	for owner_id in player_count:
		spawn_unit(owner_id, "scout", spawn_point_for(owner_id) + Vector2(-100, -90))
	selected.clear()
	var home_center := _player_center(0)
	if home_center != null: selected.append(home_center)
	navigation.refresh()
	fog.reset(selected_fog_mode if use_lobby_setup else "enabled")
	match_statistics.reset(self)
	ai_controllers.clear()
	for owner_id in range(1, player_count):
		var ai_difficulty: String = lobby_players[owner_id]["difficulty"] if use_lobby_setup else "normal"
		ai_controllers.append(RtsAiController.new(self, owner_id, ai_difficulty))
		ai_think_timers[owner_id] = 0.0
	ai = ai_controllers[0]
	if view_mode_25d != selected_view_mode_25d: _toggle_view_mode()
	_update_hud()
	_rebuild_actions()
	queue_redraw()

func _clear_world() -> void:
	_close_age_choice()
	_cancel_selection_drag()
	if world_map != null: world_map.hide()
	if weather != null: weather.hide()
	if fog != null: fog.clear()
	for unit in units: if is_instance_valid(unit): unit.queue_free()
	for building in buildings: if is_instance_valid(building): building.queue_free()
	for resource in resources: if is_instance_valid(resource): resource.queue_free()
	for post in trade_posts: if is_instance_valid(post): post.queue_free()
	for relic in relics: if is_instance_valid(relic): relic.queue_free()
	units.clear()
	buildings.clear()
	resources.clear()
	trade_posts.clear()
	relics.clear()
	if objectives != null: objectives.reset()
	selected.clear()
	control_groups.clear()
	hit_lines.clear()
	order_markers.clear()
	world_effects.clear()

func _scaled_point(point: Vector2) -> Vector2:
	return point * Vector2(world_size.x / 2400.0, world_size.y / 1500.0)

func spawn_point_for(owner_id: int) -> Vector2:
	var positions := world_map.spawn_positions()
	return positions[owner_id] if owner_id >= 0 and owner_id < positions.size() else _scaled_point(Vector2(330, 720))

func is_enemy(a: int, b: int) -> bool:
	return a >= 0 and b >= 0 and a < teams.size() and b < teams.size() and teams[a] != teams[b]

func player_color(owner_id: int) -> Color:
	if use_lobby_setup and owner_id >= 0 and owner_id < lobby_players.size():
		return PLAYER_COLORS[clampi(int(lobby_players[owner_id].get("color", owner_id)), 0, PLAYER_COLORS.size() - 1)]
	return PLAYER_COLORS[posmod(owner_id, PLAYER_COLORS.size())]

func highest_enemy_age(owner_id: int) -> int:
	var age := 1
	for rival in players.size():
		if is_enemy(owner_id, rival): age = maxi(age, int(players[rival]["age"]))
	return age

func nearest_enemy_center(owner_id: int) -> RtsBuilding:
	var home := Vector2.ZERO
	var allies := 0
	for ally_id in players.size():
		if not is_enemy(owner_id, ally_id) and not defeated_players.has(ally_id):
			home += spawn_point_for(ally_id)
			allies += 1
	if allies > 0: home /= allies
	var best: RtsBuilding
	var distance := INF
	for building in buildings:
		if not is_instance_valid(building) or not is_enemy(owner_id, building.owner_id) or building.kind != "town_center": continue
		var candidate := home.distance_squared_to(building.position)
		if candidate < distance:
			best = building
			distance = candidate
	return best

func strategic_target_for(owner_id: int) -> Node2D:
	# An AI first helps a nearby ally whose base is being attacked. Allied AIs
	# then converge on the same enemy center chosen from their team's midpoint.
	var threat: RtsUnit
	var threat_score := INF
	for building in buildings:
		if not is_instance_valid(building) or building.kind != "town_center" or is_enemy(owner_id, building.owner_id): continue
		for unit in units:
			if not is_instance_valid(unit) or not is_enemy(owner_id, unit.owner_id) or not unit.stats.get("tags", []).has("military"): continue
			var distance := building.position.distance_squared_to(unit.position)
			if distance < 340.0 * 340.0 and distance < threat_score and (not fog.active or fog.can_detect_unit(owner_id, unit)):
				threat = unit
				threat_score = distance
	if threat != null: return threat
	return nearest_enemy_center(owner_id)

func _spawn_neutral_sites() -> void:
	for desired in world_map.trade_post_positions():
		var post := RtsTradePost.new()
		post.game = self
		post.position = desired
		add_child(post)
		trade_posts.append(post)
	for site in objectives.sacred_sites:
		var relic := RtsRelic.new()
		relic.position = world_map.nearest_walkable_point(site["position"] + Vector2(70, 45))
		relic.game = self
		add_child(relic)
		relics.append(relic)

func _set_paused(value: bool) -> void:
	if not started or game_over: return
	paused = value
	_cancel_selection_drag()
	wall_dragging = false
	pause_overlay.visible = value
	if not value and settings_overlay != null: settings_overlay.hide()
	if value:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		_apply_gameplay_mouse_mode()
		_reset_selection_pointer()
	cursor.visible = not value
	queue_redraw()

func _return_to_menu() -> void:
	_clear_world()
	started = false
	game_over = false
	paused = false
	build_mode = ""
	order_mode = ""
	result_panel.hide()
	for child in result_panel.get_children(): child.queue_free()
	top_label.text = ""
	_rebuild_actions()
	_show_menu()
	queue_redraw()

func _spawn_map_resources() -> void:
	for spec in world_map.resource_specs:
		spawn_resource(spec["kind"], spec["position"], spec["amount"], spec["appearance"])

func spawn_resource(kind: String, world_point: Vector2, amount: int, appearance := "") -> RtsResource:
	var resource: RtsResource = RESOURCE_SCENE.new()
	resource.position = world_point
	resource.game = self
	add_child(resource)
	resource.setup(kind, amount, appearance)
	resources.append(resource)
	navigation.invalidate_obstacles()
	return resource

func spawn_unit(owner_id: int, kind: String, world_point: Vector2, rally := Vector2.INF, rally_target: Node2D = null, rally_resource_kind := "") -> RtsUnit:
	var unit: RtsUnit = UNIT_SCENE.new()
	unit.position = world_map.nearest_water_point(world_point) if GameData.UNITS[kind]["tags"].has("naval") else world_map.nearest_walkable_point(world_point)
	add_child(unit)
	unit.setup(self, owner_id, kind)
	unit.position = navigation.nearest_walkable_point(unit.position, unit.radius(), unit)
	units.append(unit)
	navigation.invalidate_spatial_index()
	if rally != Vector2.INF:
		if kind == "trader" and rally_target is RtsTradePost:
			unit.issue_command("trade", Vector2.INF, rally_target)
		elif kind == "fishing_boat" and rally_target is RtsResource and rally_target.appearance == "fish":
			unit.issue_command("gather", Vector2.INF, rally_target)
		elif kind == "villager" and is_instance_valid(rally_target) and not rally_target.is_queued_for_deletion() and (rally_target is RtsResource or rally_target is RtsBuilding and rally_target.kind == "farm" and rally_target.is_complete()):
			unit.issue_command("gather", Vector2.INF, rally_target)
		elif kind == "villager" and rally_resource_kind != "":
			var replacement := find_nearest_resource(rally, rally_resource_kind, 220.0, owner_id)
			if replacement != null: unit.issue_command("gather", Vector2.INF, replacement)
			else: unit.issue_command("move", rally)
		else: unit.issue_command("move", rally)
	_update_hud()
	return unit

func spawn_building(owner_id: int, kind: String, world_point: Vector2, under_construction := false, landmark_id := "", vertical := false) -> RtsBuilding:
	var building: RtsBuilding = BUILDING_SCENE.new()
	building.position = snap_build_point(kind, world_point, vertical)
	building.wall_vertical = vertical
	add_child(building)
	building.setup(self, owner_id, kind, under_construction, landmark_id)
	buildings.append(building)
	navigation.invalidate_obstacles()
	_update_hud()
	return building

func find_spawn_position(building: RtsBuilding) -> Vector2:
	if building.kind == "dock": return world_map.nearest_water_point(building.position)
	var direction := 1 if spawn_point_for(building.owner_id).x < world_size.x * 0.5 else -1
	return building.position + Vector2(direction * (building.size().x * 0.5 + 27), randf_range(-25, 25))

func building_completed(building: RtsBuilding) -> void:
	if building.kind.ends_with("_gate"): navigation.refresh()
	if building.kind == "landmark":
		complete_age(building.owner_id, int(RtsLandmarkCatalog.landmark(building.landmark_id).get("age", 0)), building.landmark_id)
	if building.owner_id == 0:
		notify_player("%s建造完成" % building.display_label())
		play_feedback("complete")
		world_effects.append({"point": building.position, "kind": "complete", "time": 0.9})
	_rebuild_actions()
	_update_hud()

func entity_destroyed(entity: Node2D) -> void:
	if not is_instance_valid(entity) or entity.is_queued_for_deletion(): return
	if not fog.active or fog.can_see(0, entity.position):
		world_effects.append({"point": entity.position, "kind": "death" if entity is RtsUnit else "collapse", "color": player_color(entity.owner_id), "time": 0.9})
		if entity.owner_id == 0 and entity is RtsUnit: play_feedback("alert")
	selected.erase(entity)
	if entity is RtsUnit:
		if not entity.passengers.is_empty(): entity.ungarrison_all()
		units.erase(entity)
		navigation.invalidate_spatial_index()
	elif entity is RtsBuilding:
		if entity.kind in ["town_center", "landmark", "wonder", "keep"]:
			match_statistics.record_event(entity.owner_id, "%s被摧毁" % entity.display_label())
		for unit in units:
			if is_instance_valid(unit) and unit.wall_host == entity: unit.leave_wall()
		for relic in entity.relics:
			if is_instance_valid(relic):
				relic.stored_in = null
				relic.position = world_map.nearest_walkable_point(entity.position + Vector2(65, 0))
		entity.relics.clear()
		entity.ungarrison_all()
		objectives.on_building_destroyed(entity)
		buildings.erase(entity)
		navigation.invalidate_obstacles()
		if entity.landmark_id == "zh_gatehouse":
			for building in buildings:
				if is_instance_valid(building) and building.owner_id == entity.owner_id and building.kind in ["stone_wall", "stone_gate"]: building.refresh_stats()
		if entity.kind == "town_center" or entity.kind == "landmark":
			var has_landmark := false
			for building in buildings:
				if is_instance_valid(building) and building.owner_id == entity.owner_id and building.is_complete() and (building.kind == "town_center" or building.kind == "landmark"):
					has_landmark = true
					break
			if not has_landmark:
				defeated_players.append(entity.owner_id)
				_eliminate_player(entity.owner_id)
				_check_match_end()
	entity.queue_free()
	_rebuild_actions()
	_update_hud()

func _eliminate_player(owner_id: int) -> void:
	for unit in units.duplicate():
		if is_instance_valid(unit) and unit.owner_id == owner_id:
			selected.erase(unit)
			units.erase(unit)
			unit.queue_free()
	for building in buildings.duplicate():
		if is_instance_valid(building) and building.owner_id == owner_id:
			for relic in building.relics:
				if is_instance_valid(relic):
					relic.stored_in = null
					relic.position = world_map.nearest_walkable_point(building.position + Vector2(60, 0))
			building.relics.clear()
			objectives.on_building_destroyed(building)
			selected.erase(building)
			buildings.erase(building)
			building.queue_free()
	navigation.refresh()
	if fog.active: fog.update_visibility()

func _check_match_end() -> void:
	var surviving_teams: Dictionary = {}
	for owner_id in players.size():
		if not defeated_players.has(owner_id): surviving_teams[teams[owner_id]] = true
	if not surviving_teams.has(teams[0]):
		_finish_game(false, "landmarks")
	elif surviving_teams.size() == 1:
		_finish_game(true, "landmarks")

func _finish_game(won: bool, reason := "landmarks") -> void:
	if game_over: return
	_cancel_selection_drag()
	match_statistics.record_event(0, "对局结束")
	match_statistics.sample()
	game_over = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	cursor.hide()
	for child in result_panel.get_children(): child.queue_free()
	result_panel.custom_minimum_size = Vector2(400, 220)
	result_panel.offset_left = -200
	result_panel.offset_top = -110
	result_panel.offset_right = 200
	result_panel.offset_bottom = 110
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	result_panel.add_child(box)
	_add_menu_label(box, "胜利！" if won else "战败", RtsUiTypography.PAGE_TITLE)
	var result_reason: String = {"landmarks": "城镇中心与地标全部摧毁", "sacred": "控制全部圣地", "wonder": "奇观守护成功"}.get(reason, reason)
	_add_menu_label(box, result_reason, RtsUiTypography.BODY)
	var button := Button.new()
	button.text = "返回文明选择"
	button.pressed.connect(func() -> void: _return_to_menu())
	box.add_child(button)
	var report := Button.new()
	report.text = "查看战后统计与战局回看"
	report.pressed.connect(func() -> void: _show_match_report(won, result_reason))
	box.add_child(report)
	result_panel.show()

func _show_match_report(won: bool, result_reason: String) -> void:
	for child in result_panel.get_children(): child.queue_free()
	result_panel.custom_minimum_size = Vector2(820, 620)
	result_panel.offset_left = -410
	result_panel.offset_top = -310
	result_panel.offset_right = 410
	result_panel.offset_bottom = 310
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	result_panel.add_child(layout)
	_add_menu_label(layout, ("胜利" if won else "战败") + " · " + result_reason, RtsUiTypography.PAGE_TITLE)
	var legend := HBoxContainer.new()
	layout.add_child(legend)
	var colors: Array[Color] = []
	for owner_id in players.size():
		var color := player_color(owner_id)
		colors.append(color)
		var caption := Label.new()
		caption.text = "%s  %s    " % ["●", civilizations[owner_id]]
		caption.add_theme_color_override("font_color", color)
		legend.add_child(caption)
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(tabs)
	var trend_tab := VBoxContainer.new()
	trend_tab.name = "数据走势"
	tabs.add_child(trend_tab)
	var metric_picker := OptionButton.new()
	for metric_name in ["资源库存", "累计收入", "人口", "军队", "科技", "地图控制率"]: metric_picker.add_item(metric_name)
	trend_tab.add_child(metric_picker)
	var chart := RtsStatisticsChart.new()
	chart.statistics = match_statistics
	chart.player_colors = colors
	chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	trend_tab.add_child(chart)
	metric_picker.item_selected.connect(func(index: int) -> void:
		chart.show_metric(["stock", "income", "population", "military", "technology", "control"][index])
	)
	var last_sample: Dictionary = match_statistics.samples.back()
	var summary := Label.new()
	var details: Array[String] = []
	for owner_id in players.size():
		var row: Dictionary = last_sample["players"][owner_id]
		details.append("%s：人口 %d · 军队 %d · 科技 %d · 控图 %.0f%%" % [civilizations[owner_id], row["population"], row["military"], row["technology"], row["control"]])
	summary.text = "\n".join(details)
	trend_tab.add_child(summary)
	var replay_tab := VBoxContainer.new()
	replay_tab.name = "战局回看"
	tabs.add_child(replay_tab)
	var replay_map := RtsBattleReplayMap.new()
	replay_map.statistics = match_statistics
	replay_map.player_colors = colors
	replay_map.prepare(world_map)
	replay_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	replay_tab.add_child(replay_map)
	var replay_time := Label.new()
	replay_tab.add_child(replay_time)
	var timeline := HSlider.new()
	timeline.min_value = 0
	timeline.max_value = maxi(0, match_statistics.samples.size() - 1)
	timeline.step = 1
	timeline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	replay_tab.add_child(timeline)
	var playback := Timer.new()
	playback.wait_time = 0.35
	playback.autostart = false
	replay_tab.add_child(playback)
	var controls := HBoxContainer.new()
	replay_tab.add_child(controls)
	var play_button := Button.new()
	play_button.text = "播放"
	controls.add_child(play_button)
	var event_picker := OptionButton.new()
	event_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	event_picker.add_item("跳到关键事件")
	for event in match_statistics.events:
		event_picker.add_item("%02d:%02d  %s · %s" % [int(event["time"]) / 60, int(event["time"]) % 60, civilizations[event["owner"]], event["label"]])
	controls.add_child(event_picker)
	timeline.value_changed.connect(func(value: float) -> void:
		replay_map.seek(roundi(value))
		var current: Dictionary = match_statistics.samples[replay_map.sample_index]
		replay_time.text = "战局时间 %02d:%02d · 单位 %d · 建筑 %d" % [int(current["time"]) / 60, int(current["time"]) % 60, current["units"].size(), current["buildings"].size()]
	)
	event_picker.item_selected.connect(func(index: int) -> void:
		if index > 0: timeline.value = match_statistics.nearest_sample_index(float(match_statistics.events[index - 1]["time"]))
	)
	play_button.pressed.connect(func() -> void:
		if playback.is_stopped():
			if timeline.value >= timeline.max_value: timeline.value = 0
			playback.start()
			play_button.text = "暂停"
		else:
			playback.stop()
			play_button.text = "播放"
	)
	playback.timeout.connect(func() -> void:
		if timeline.value < timeline.max_value: timeline.value += 1
		else:
			playback.stop()
			play_button.text = "播放"
	)
	timeline.value = timeline.max_value
	var back := Button.new()
	back.text = "返回文明选择"
	back.pressed.connect(func() -> void: _return_to_menu())
	layout.add_child(back)

func credit_resource(owner_id: int, kind: String, amount: int) -> void:
	MATCH_ECONOMY.credit_resource(self, owner_id, kind, amount)

func market_quote(resource_kind: String, buy: bool, owner_id := 0) -> int:
	return MATCH_ECONOMY.market_quote(self, resource_kind, buy, owner_id)

func exchange_resource(owner_id: int, resource_kind: String, buy: bool) -> bool:
	return MATCH_ECONOMY.exchange_resource(self, owner_id, resource_kind, buy)

func find_landing_pair(boat: RtsUnit, requested: Vector2) -> Dictionary:
	navigation._ensure_current()
	var candidates: Array[Dictionary] = []
	for y in world_map.grid_size.y:
		for x in world_map.grid_size.x:
			var land := world_map.cell_center(Vector2i(x, y))
			if not world_map.is_walkable(land) or land.distance_to(requested) > 750.0: continue
			var free := true
			for passenger in boat.passengers:
				if is_instance_valid(passenger) and not navigation.can_occupy(land, passenger.radius(), passenger, false, false):
					free = false
					break
			if not free: continue
			for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var cell: Vector2i = Vector2i(x, y) + offset
				if cell.x < 0 or cell.y < 0 or cell.x >= world_map.grid_size.x or cell.y >= world_map.grid_size.y: continue
				var water := world_map.cell_center(cell)
				if not navigation.can_occupy(water, boat.radius(), boat, false, false): continue
				candidates.append({"land": land, "water": water, "score": land.distance_to(requested) + water.distance_to(boat.position) * 0.12})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["score"] < b["score"])
	for candidate in candidates:
		if not navigation.path_between(boat.position, candidate["water"], boat).is_empty():
			return {"land": candidate["land"], "water": candidate["water"]}
	return {}

func can_afford(owner_id: int, cost: Dictionary) -> bool:
	return MATCH_ECONOMY.can_afford(self, owner_id, cost)

func spend(owner_id: int, cost: Dictionary) -> bool:
	return MATCH_ECONOMY.spend(self, owner_id, cost)

func population_used(owner_id: int) -> int:
	return MATCH_ECONOMY.population_used(self, owner_id)

func population_cap(owner_id: int) -> int:
	return MATCH_ECONOMY.population_cap(self, owner_id)

func train_unit(building: RtsBuilding, unit_kind: String) -> bool:
	return MATCH_PRODUCTION.train_unit(self, building, unit_kind)

func queued_research(owner_id: int) -> Array[String]:
	return MATCH_PRODUCTION.queued_research(self, owner_id)

func research_technology(building: RtsBuilding, tech_id: String) -> bool:
	return MATCH_PRODUCTION.research_technology(self, building, tech_id)

func complete_research(owner_id: int, tech_id: String) -> void:
	MATCH_PRODUCTION.complete_research(self, owner_id, tech_id)

func is_age_queued(owner_id: int) -> bool:
	for building in buildings:
		if is_instance_valid(building) and building.owner_id == owner_id and building.kind == "landmark" and not building.is_complete(): return true
	return false

func active_landmark_id(owner_id: int) -> String:
	for building in buildings:
		if is_instance_valid(building) and building.owner_id == owner_id and building.kind == "landmark" and not building.is_complete(): return building.landmark_id
	return ""

func place_landmark(owner_id: int, landmark_id: String, world_point: Vector2, workers: Array[RtsUnit], append_order := false) -> bool:
	world_point = snap_build_point("landmark", world_point)
	var status := RtsLandmarkCatalog.choice_status(civilizations[owner_id], players[owner_id]["age"], players[owner_id]["landmarks"], landmark_id, active_landmark_id(owner_id))
	if not status["available"]:
		if owner_id == 0: notify_player(status["reason"])
		return false
	var builders: Array[RtsUnit] = []
	for worker in workers:
		if is_instance_valid(worker) and worker.owner_id == owner_id and worker.kind == "villager": builders.append(worker)
	if builders.is_empty(): return false
	if not can_place("landmark", world_point):
		if owner_id == 0: notify_player("这里不能建造地标")
		return false
	var choice := RtsLandmarkCatalog.landmark(landmark_id)
	if not spend(owner_id, choice["cost"]):
		if owner_id == 0: notify_player("地标资源不足")
		return false
	var building := spawn_building(owner_id, "landmark", world_point, true, landmark_id)
	for worker in builders: worker.issue_command("build", Vector2.INF, building, append_order)
	if owner_id == 0: notify_player("正在建造%s" % choice["label"])
	_rebuild_actions()
	return true

func advance_age(owner_id: int, landmark_id := "") -> bool:
	var age: int = players[owner_id]["age"]
	if not RtsTechTree.can_advance(age) or is_age_queued(owner_id): return false
	var center := _player_center(owner_id)
	if center == null or not center.is_complete(): return false
	var choices := RtsLandmarkCatalog.choices_for(civilizations[owner_id], age, players[owner_id]["landmarks"])
	if choices.is_empty(): return false
	if landmark_id.is_empty():
		for choice in choices:
			if choice["age"] == age + 1:
				landmark_id = choice["id"]
				break
	if landmark_id.is_empty(): return false
	return construct_landmark(owner_id, landmark_id)

func construct_landmark(owner_id: int, landmark_id: String) -> bool:
	var age: int = players[owner_id]["age"]
	if not RtsLandmarkCatalog.choice_status(civilizations[owner_id], age, players[owner_id]["landmarks"], landmark_id, active_landmark_id(owner_id))["available"]: return false
	var center := _player_center(owner_id)
	if center == null or not center.is_complete(): return false
	var workers: Array[RtsUnit] = []
	for unit in units:
		if is_instance_valid(unit) and unit.owner_id == owner_id and unit.kind == "villager": workers.append(unit)
	workers.sort_custom(func(a: RtsUnit, b: RtsUnit) -> bool: return a.position.distance_squared_to(center.position) < b.position.distance_squared_to(center.position))
	if workers.size() > 2: workers.resize(2)
	var inward := 180.0 if spawn_point_for(owner_id).x < world_size.x * 0.5 else -180.0
	var candidates := [Vector2(0, 180), Vector2(0, -180), Vector2(inward, 0), Vector2(inward, 180), Vector2(inward, -180)]
	for radius in [250.0, 340.0, 440.0, 540.0]:
		for spoke in 16:
			candidates.append(Vector2.from_angle(TAU * spoke / 16.0) * radius)
	for offset in candidates:
		if can_place("landmark", center.position + offset): return place_landmark(owner_id, landmark_id, center.position + offset, workers)
	# A developed base may occupy every preferred landmark slot. Search the
	# surrounding buildable area so age progression cannot deadlock there.
	for radius in [240.0, 310.0, 380.0, 450.0, 520.0, 590.0]:
		for step in 16:
			var point: Vector2 = center.position + Vector2.from_angle(TAU * float(step) / 16.0) * radius
			if not can_place("landmark", point): continue
			var nearby_workers: Array[RtsUnit] = []
			for unit in units:
				if is_instance_valid(unit) and unit.owner_id == owner_id and unit.kind == "villager" and unit.garrisoned_in == null: nearby_workers.append(unit)
			nearby_workers.sort_custom(func(a: RtsUnit, b: RtsUnit) -> bool: return a.position.distance_squared_to(point) < b.position.distance_squared_to(point))
			for worker in nearby_workers:
				if navigation.path_to_range(worker.position, point, float(GameData.BUILDINGS["landmark"]["size"].x) * 0.6 + worker.radius(), worker).is_empty(): continue
				var builders: Array[RtsUnit] = [worker]
				return place_landmark(owner_id, landmark_id, point, builders)
	return false

func complete_age(owner_id: int, target_age: int, landmark_id := "") -> void:
	var current_age: int = players[owner_id]["age"]
	var aged_up := target_age == current_age + 1
	if not aged_up and (landmark_id.is_empty() or civilizations[owner_id] != "Chinese" or target_age > current_age): return
	if landmark_id != "" and players[owner_id]["landmarks"].has(landmark_id): return
	if aged_up: players[owner_id]["age"] = target_age
	if aged_up: match_statistics.record_event(owner_id, "进入时代 %d" % target_age)
	if aged_up and civilizations[owner_id] == "French" and target_age >= 2:
		for upgrade_age in range(2, target_age + 1):
			var free_upgrade := "melee_attack_%d" % upgrade_age
			if not players[owner_id]["researched"].has(free_upgrade): players[owner_id]["researched"].append(free_upgrade)
	if landmark_id != "": players[owner_id]["landmarks"].append(landmark_id)
	var previous_dynasty: String = players[owner_id].get("dynasty", "")
	players[owner_id]["dynasty"] = RtsLandmarkCatalog.dynasty_for(players[owner_id]["landmarks"]) if civilizations[owner_id] == "Chinese" else ""
	for unit in units:
		if is_instance_valid(unit) and unit.owner_id == owner_id: unit.refresh_stats()
	for building in buildings:
		if is_instance_valid(building) and building.owner_id == owner_id: building.refresh_stats()
	if owner_id == 0:
		if aged_up: notify_player("进入时代 %d！" % target_age)
		if players[owner_id]["dynasty"] != previous_dynasty:
			notify_player("进入%s朝：王朝加成已生效" % RtsLandmarkCatalog.DYNASTY_NAMES[players[owner_id]["dynasty"]])
		_rebuild_actions()
	_update_hud()

func cancel_production_job(building: RtsBuilding, index: int = 0) -> bool:
	return MATCH_PRODUCTION.cancel_job(self, building, index)

func build_footprint_size(kind: String, vertical := false) -> Vector2:
	var dimensions: Vector2 = GameData.BUILDINGS[kind]["size"]
	if vertical and (kind.ends_with("_wall") or kind.ends_with("_gate")): dimensions = Vector2(dimensions.y, dimensions.x)
	var padding := 0.0 if kind.ends_with("_wall") or kind.ends_with("_gate") else 9.0
	dimensions += Vector2.ONE * padding * 2.0
	return Vector2(ceili(dimensions.x / BUILD_GRID_SIZE), ceili(dimensions.y / BUILD_GRID_SIZE)) * BUILD_GRID_SIZE

func snap_build_point(kind: String, world_point: Vector2, vertical := false) -> Vector2:
	var half := build_footprint_size(kind, vertical) * 0.5
	return (world_point - half).snapped(Vector2.ONE * BUILD_GRID_SIZE) + half

func build_footprint_rect(kind: String, world_point: Vector2, vertical := false) -> Rect2:
	var dimensions := build_footprint_size(kind, vertical)
	return Rect2(world_point - dimensions * 0.5, dimensions)

func can_place(kind: String, world_point: Vector2, vertical := false) -> bool:
	var snapped := snap_build_point(kind, world_point, vertical)
	var footprint := build_footprint_rect(kind, snapped, vertical)
	if footprint.position.x < 20 or footprint.position.y < 70: return false
	if footprint.end.x > world_size.x - 20 or footprint.end.y > world_size.y - 20: return false
	if world_map != null and not world_map.is_area_buildable(footprint): return false
	if kind == "dock" and not world_map.has_adjacent_water(snapped): return false
	for building in buildings:
		if is_instance_valid(building):
			var other := build_footprint_rect(building.kind, building.position, building.wall_vertical)
			if footprint.intersects(other): return false
	for resource in resources:
		if is_instance_valid(resource) and footprint.grow(resource.radius * 0.5).has_point(resource.position): return false
	for post in trade_posts:
		if is_instance_valid(post) and footprint.grow(28).has_point(post.position): return false
	for relic in relics:
		if is_instance_valid(relic) and relic.available() and footprint.grow(18).has_point(relic.position): return false
	return true

func place_building(owner_id: int, kind: String, world_point: Vector2, workers: Array[RtsUnit], append_order := false, vertical := false) -> bool:
	world_point = snap_build_point(kind, world_point, vertical)
	if not RtsTechTree.can_build(civilizations[owner_id], players[owner_id]["age"], kind): return false
	if kind == "wonder":
		for existing in buildings:
			if is_instance_valid(existing) and existing.owner_id == owner_id and existing.kind == "wonder":
				if owner_id == 0: notify_player("已有奇观")
				return false
	var builders: Array[RtsUnit] = []
	for worker in workers:
		if is_instance_valid(worker) and worker.owner_id == owner_id and worker.kind == "villager":
			builders.append(worker)
	if builders.is_empty(): return false
	if not can_place(kind, world_point, vertical):
		if owner_id == 0: notify_player("这里不能建造")
		return false
	if not spend(owner_id, RtsCivilizationRules.building_cost(civilizations[owner_id], kind)):
		if owner_id == 0: notify_player("建造资源不足")
		return false
	var building := spawn_building(owner_id, kind, world_point, true, "", vertical)
	for worker in builders: worker.issue_command("build", Vector2.INF, building, append_order)
	if owner_id == 0: notify_player("%d 名村民正在建造%s" % [builders.size(), GameData.BUILDINGS[kind]["label"]])
	return true

func convert_wall_to_gate(building: RtsBuilding) -> bool:
	if not is_instance_valid(building) or not building.is_complete() or not building.kind.ends_with("_wall"): return false
	var gate_kind := "stone_gate" if building.kind == "stone_wall" else "palisade_gate"
	var resource := "stone" if gate_kind == "stone_gate" else "wood"
	var extra: int = GameData.BUILDINGS[gate_kind]["cost"][resource] - GameData.BUILDINGS[building.kind]["cost"][resource]
	if not spend(building.owner_id, {resource: extra}): return false
	building.kind = gate_kind
	building.refresh_stats()
	navigation.refresh()
	if building.owner_id == 0:
		notify_player("城墙已改建为城门")
		_rebuild_actions()
	return true

func count_builders(building: RtsBuilding) -> int:
	var count := 0
	for unit in units:
		if is_instance_valid(unit) and unit.order == "build" and unit.target == building:
			count += 1
	return count

func find_nearest_resource(world_point: Vector2, kind: String, max_distance := INF, viewer_id := -1, naval := false, for_unit: RtsUnit = null) -> RtsResource:
	var nearest: RtsResource
	var shortest := max_distance * max_distance
	for resource in resources:
		if not is_instance_valid(resource) or resource.is_queued_for_deletion() or resource.kind != kind: continue
		if naval != (resource.appearance == "fish"): continue
		if viewer_id >= 0 and fog.active and not fog.can_show_resource(viewer_id, resource): continue
		var distance := world_point.distance_squared_to(resource.position)
		if distance < shortest:
			if for_unit != null and navigation.path_to_range(world_point, resource.position, resource.radius + for_unit.radius() + 2.0, for_unit).is_empty(): continue
			shortest = distance
			nearest = resource
	return nearest

func find_nearest_owned_building(owner_id: int, kind: String, point: Vector2) -> RtsBuilding:
	var nearest: RtsBuilding
	var best := INF
	for building in buildings:
		if not is_instance_valid(building) or building.is_queued_for_deletion() or building.owner_id != owner_id or building.kind != kind or not building.is_complete(): continue
		var distance := point.distance_squared_to(building.position)
		if distance < best:
			nearest = building
			best = distance
	return nearest

func nearest_enemy(unit: RtsUnit, max_distance: float) -> Node2D:
	var best: Node2D
	var best_score := INF
	for other in navigation.nearby_units(unit.position, max_distance):
		if unit.kind == "battering_ram": break
		if not is_instance_valid(other) or other == unit or not is_enemy(unit.owner_id, other.owner_id) or other.garrisoned_in != null: continue
		if fog.active and not fog.can_detect_unit(unit.owner_id, other): continue
		var d := unit.position.distance_squared_to(other.position)
		var score := d - _counter_priority(unit, other.stats) * 160.0
		if score < best_score:
			best_score = score
			best = other
	for building in navigation.nearby_buildings(unit.position, max_distance):
		if not is_instance_valid(building) or not is_enemy(unit.owner_id, building.owner_id): continue
		if fog.active and not fog.can_see(unit.owner_id, building.position): continue
		var d := unit.position.distance_squared_to(building.position)
		if d > max_distance * max_distance: continue
		var score := d + (8000.0 if unit.kind != "battering_ram" else 0.0)
		if score < best_score:
			best_score = score
			best = building
	return best

func _counter_priority(attacker: RtsUnit, defender_stats: Dictionary) -> float:
	var profile: Dictionary = attacker.stats.get("profiles", {}).get(attacker.stats.get("primary_profile", ""), {})
	var tags: Array = defender_stats.get("target_tags", defender_stats.get("tags", []))
	var bonus := 0.0
	for entry in profile.get("bonuses", []):
		for tag in entry.get("required_tags", []):
			if tags.has(tag):
				bonus = maxf(bonus, float(entry.get("amount", 0.0)))
				break
	return bonus

func show_hit(from: Vector2, to: Vector2, owner_id: int, style := "melee") -> void:
	hit_lines.append({"from": from, "to": to, "owner": owner_id, "time": 0.24, "style": style})
	if not fog.active or fog.can_see(0, to):
		world_effects.append({"point": to, "kind": style, "time": 0.36 if style == "siege" else 0.24})
		play_feedback("impact")
	queue_redraw()

func play_feedback(cue: String) -> void:
	if feedback_audio != null: feedback_audio.play_cue(cue)

func show_resource_gain(point: Vector2, kind: String, amount: int) -> void:
	if world_effects.size() >= 80: return
	world_effects.append({"point": point, "kind": "resource", "resource": kind, "amount": amount, "time": 0.85})
	queue_redraw()

func _show_order_feedback(point: Vector2, kind: String, queued := false) -> void:
	var color := Color("e97871") if kind in ["attack", "invalid"] else Color("8fd49b") if kind in ["gather", "build"] else Color("95c7ef")
	order_markers.append({"point": point, "time": 0.82, "kind": kind, "queued": queued, "color": color})
	play_feedback("invalid" if kind == "invalid" else "attack" if kind == "attack" else "gather" if kind == "gather" else "build" if kind == "build" else "move")
	queue_redraw()

func notify_player(message: String) -> void:
	notice_label.text = message
	notice_timer = 3.5

func _process(delta: float) -> void:
	if adaptive_resolution_enabled and not _window_is_fullscreen() and DisplayServer.get_name() != "headless":
		adaptive_resolution_check_timer -= delta
		if adaptive_resolution_check_timer <= 0.0:
			adaptive_resolution_check_timer = 1.0
			if DisplayServer.screen_get_usable_rect(get_window().current_screen) != adaptive_usable_rect:
				_apply_window_resolution(Vector2i.ZERO, false)
	if not started or game_over or paused: return
	if _uses_native_selection_pointer():
		_poll_selection_pointer()
	elif dragging:
		_update_selection_drag(get_viewport().get_mouse_position())
	match_statistics.tick(delta)
	if view_mode_25d:
		iso_sort_timer -= delta
		if iso_sort_timer <= 0.0:
			_update_iso_depths()
			iso_sort_timer = 0.1
	_pan_camera(delta)
	_update_cursor()
	if notice_timer > 0.0:
		notice_timer -= delta
		if notice_timer <= 0.0: notice_label.text = ""
	for controller in ai_controllers:
		if defeated_players.has(controller.owner_id): continue
		var owner_id := controller.owner_id
		ai_think_timers[owner_id] = float(ai_think_timers.get(owner_id, 0.0)) - delta
		if ai_think_timers[owner_id] <= 0.0:
			controller.tick()
			var difficulty: String = lobby_players[owner_id]["difficulty"] if use_lobby_setup else "normal"
			ai_think_timers[owner_id] = {"easy": 6.0, "normal": 3.0, "hard": 1.5}.get(difficulty, 3.0)
	hud_timer -= delta
	if hud_timer <= 0.0:
		_update_hud()
		hud_timer = 0.4
	for line in hit_lines:
		line["time"] -= delta
	hit_lines = hit_lines.filter(func(line: Dictionary) -> bool: return line["time"] > 0.0)
	for marker in order_markers: marker["time"] -= delta
	order_markers = order_markers.filter(func(marker: Dictionary) -> bool: return marker["time"] > 0.0)
	for effect in world_effects: effect["time"] -= delta
	world_effects = world_effects.filter(func(effect: Dictionary) -> bool: return effect["time"] > 0.0)
	if build_mode != "" or not hit_lines.is_empty() or not order_markers.is_empty() or not world_effects.is_empty() or selected.any(func(entity: Node2D) -> bool: return is_instance_valid(entity) and entity is RtsUnit): queue_redraw()

func _pan_camera(delta: float) -> void:
	var direction := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): direction.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): direction.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): direction.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): direction.y += 1
	# A pointer resting at the screen edge must not cancel or skew WASD movement.
	if direction == Vector2.ZERO and get_window().has_focus():
		direction = _edge_pan_direction(_selection_pointer_screen_position(), get_viewport_rect().size)
	if direction != Vector2.ZERO:
		_move_camera_screen_delta(direction.normalized() * CAMERA_PAN_SPEED * delta)

func _move_camera_screen_delta(screen_delta: Vector2) -> void:
	var world_delta := Vector2(screen_delta.x / camera.zoom.x, screen_delta.y / camera.zoom.y).rotated(camera.rotation)
	camera.position += world_delta
	_clamp_camera_position()

func _clamp_camera_position() -> void:
	var half_view := get_viewport_rect().size * 0.5 / camera.zoom
	var angle := camera.rotation
	var extents := Vector2(absf(cos(angle)) * half_view.x + absf(sin(angle)) * half_view.y, absf(sin(angle)) * half_view.x + absf(cos(angle)) * half_view.y)
	# A diamond-shaped projected view cannot fit inside the standard map.
	# Keep its center navigable and allow some background at the corners.
	var margin := extents.min(world_size * (0.12 if view_mode_25d else 0.5))
	camera.position = camera.position.clamp(margin, world_size - margin)

func _toggle_view_mode(save_setting := false) -> void:
	var at_starting_camera := started and match_statistics.elapsed < 2.0 and camera.position.distance_to(spawn_point_for(0) + _scaled_point(START_CAMERA_POINT - Vector2(330, 720))) < 2.0
	view_mode_25d = not view_mode_25d
	world_map.isometric_view = view_mode_25d
	world_map.queue_redraw()
	hud_ui._apply_minimap_size()
	var base_zoom := camera.zoom.x
	camera.rotation = -PI / 4.0 if view_mode_25d else 0.0
	camera.zoom = Vector2(base_zoom, base_zoom * 0.5 if view_mode_25d else base_zoom)
	if view_mode_25d and at_starting_camera: camera.position = spawn_point_for(0)
	_clamp_camera_position()
	camera.force_update_scroll()
	fog.update_projection()
	view_button.text = "2D 视角" if view_mode_25d else "2.5D 视角"
	if save_setting:
		selected_view_mode_25d = view_mode_25d
		_save_settings()
	_redraw_projected_entities()
	_update_iso_depths()
	queue_redraw()

func _redraw_projected_entities() -> void:
	for building in buildings:
		if is_instance_valid(building): building.queue_redraw()
	for unit in units:
		if is_instance_valid(unit): unit.queue_redraw()
	for resource in resources:
		if is_instance_valid(resource): resource.queue_redraw()
	for post in trade_posts: post.queue_redraw()
	for relic in relics: relic.queue_redraw()

func _update_iso_depths() -> void:
	for building in buildings:
		if is_instance_valid(building): building.z_index = clampi(roundi((building.position.x + building.position.y) * 0.5), 0, 2800) if view_mode_25d else 0
	for resource in resources:
		if is_instance_valid(resource): resource.z_index = clampi(roundi((resource.position.x + resource.position.y) * 0.5), 0, 2800) if view_mode_25d else 0
	for post in trade_posts:
		if is_instance_valid(post): post.z_index = clampi(roundi((post.position.x + post.position.y) * 0.5), 0, 2800) if view_mode_25d else 0
	for relic in relics:
		if is_instance_valid(relic): relic.z_index = clampi(roundi((relic.position.x + relic.position.y) * 0.5), 0, 2800) if view_mode_25d else 0
	for unit in units:
		if is_instance_valid(unit):
			unit.z_index = clampi(roundi((unit.position.x + unit.position.y) * 0.5), 0, 2800) + (8 if is_instance_valid(unit.wall_host) else 0) if view_mode_25d else (3 if is_instance_valid(unit.wall_host) else 0)

func _adjust_zoom(factor: float, screen_anchor := Vector2.INF) -> void:
	var base_zoom := clampf(camera.zoom.x * factor, 0.7, 1.65)
	if is_equal_approx(base_zoom, camera.zoom.x): return
	if screen_anchor == Vector2.INF: screen_anchor = get_viewport_rect().size * 0.5
	camera.force_update_scroll()
	var anchor_world := get_viewport().get_canvas_transform().affine_inverse() * screen_anchor
	camera.zoom = Vector2(base_zoom, base_zoom * 0.5 if view_mode_25d else base_zoom)
	camera.force_update_scroll()
	var shifted_world := get_viewport().get_canvas_transform().affine_inverse() * screen_anchor
	camera.position += anchor_world - shifted_world
	_clamp_camera_position()
	# Projection geometry depends on zoom.x / zoom.y, which stays fixed here.
	# Camera2D scales the existing map, fog mesh and entity drawings itself.
	queue_redraw()

func _edge_pan_direction(screen_point: Vector2, viewport_size: Vector2) -> Vector2:
	if not edge_scroll_enabled: return Vector2.ZERO
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0: return Vector2.ZERO
	# Confined mouse coordinates can land exactly on the right or bottom edge.
	# Clamping also keeps edge scrolling continuous during a focus transition.
	var point := screen_point.clamp(Vector2.ZERO, (viewport_size - Vector2.ONE).max(Vector2.ZERO))
	var direction := Vector2.ZERO
	if point.x <= EDGE_SCROLL_MARGIN: direction.x -= 1
	if point.x >= viewport_size.x - EDGE_SCROLL_MARGIN: direction.x += 1
	if point.y <= EDGE_SCROLL_MARGIN: direction.y -= 1
	if point.y >= viewport_size.y - EDGE_SCROLL_MARGIN: direction.y += 1
	return direction

func _uses_native_selection_pointer() -> bool:
	return OS.get_name() == "macOS" and DisplayServer.get_name() != "headless"

func _gameplay_mouse_mode():
	if _uses_native_selection_pointer():
		return Input.MOUSE_MODE_HIDDEN
	return Input.MOUSE_MODE_CONFINED_HIDDEN

func _apply_gameplay_mouse_mode() -> void:
	Input.mouse_mode = _gameplay_mouse_mode()

func _selection_pointer_screen_position() -> Vector2:
	if not _uses_native_selection_pointer(): return get_viewport().get_mouse_position()
	var window_id := get_window().get_window_id()
	var window_position := DisplayServer.window_get_position(window_id)
	var window_size := DisplayServer.window_get_size(window_id)
	if window_size.x <= 0 or window_size.y <= 0: return get_viewport().get_mouse_position()
	var client_point := Vector2(DisplayServer.mouse_get_position() - window_position)
	return client_point * get_viewport_rect().size / Vector2(window_size)

func _selection_native_left_down() -> bool:
	return (DisplayServer.mouse_get_button_state() & MOUSE_BUTTON_MASK_LEFT) != 0

func _reset_selection_pointer() -> void:
	selection_drag_phase = SelectionDragPhase.IDLE
	selection_previous_left_down = _selection_native_left_down() if _uses_native_selection_pointer() else false

func _selection_point_over_hud(screen_point: Vector2) -> bool:
	if not Rect2(Vector2.ZERO, get_viewport_rect().size).has_point(screen_point): return true
	for control in [hud_top, hud_bottom, minimap, global_queue_panel, pause_overlay, settings_overlay, tech_tree_overlay, age_choice_overlay]:
		if control == null or not (control is Control) or not control.is_visible_in_tree(): continue
		var canvas_transform: Transform2D = control.get_global_transform_with_canvas()
		var screen_rect := Rect2(canvas_transform * Vector2.ZERO, canvas_transform * control.size - canvas_transform * Vector2.ZERO)
		if screen_rect.has_point(screen_point):
			if control == minimap and not minimap._inside_map(canvas_transform.affine_inverse() * screen_point): continue
			return true
	return false

func _can_begin_native_selection(screen_point: Vector2) -> bool:
	return get_window().has_focus() and started and not paused and not game_over and build_mode == "" and order_mode == "" and not wall_dragging and not _selection_point_over_hud(screen_point)

func _poll_selection_pointer() -> void:
	var screen_point := _selection_pointer_screen_position()
	var left_down := _selection_native_left_down()
	if left_down and not selection_previous_left_down:
		if selection_drag_phase == SelectionDragPhase.BLOCKED:
			pass
		elif dragging:
			if selection_drag_phase == SelectionDragPhase.IDLE: selection_drag_phase = SelectionDragPhase.CANDIDATE
		elif _can_begin_native_selection(screen_point):
			_begin_selection_candidate(screen_point)
		else:
			selection_drag_phase = SelectionDragPhase.BLOCKED
	elif left_down:
		if dragging and selection_drag_phase in [SelectionDragPhase.CANDIDATE, SelectionDragPhase.ACTIVE]:
			selection_drag_additive = Input.is_key_pressed(KEY_SHIFT)
			_update_selection_drag(screen_point)
	elif selection_previous_left_down:
		if dragging and selection_drag_phase in [SelectionDragPhase.CANDIDATE, SelectionDragPhase.ACTIVE]:
			# The pointer may already be at the next right-click target by this frame.
			_complete_selection_drag(drag_current_screen, selection_drag_additive)
		else:
			selection_drag_phase = SelectionDragPhase.IDLE
	selection_previous_left_down = left_down

func _begin_selection_candidate(screen_point: Vector2) -> void:
	dragging = true
	selection_drag_phase = SelectionDragPhase.CANDIDATE
	selection_drag_additive = Input.is_key_pressed(KEY_SHIFT)
	drag_start_screen = screen_point
	drag_current_screen = screen_point
	_begin_selection_drag(screen_point)
	if _uses_native_selection_pointer(): selection_previous_left_down = _selection_native_left_down()

func _selection_drag_active() -> bool:
	return dragging and selection_drag_phase == SelectionDragPhase.ACTIVE

func _selection_drag_visible() -> bool:
	return dragging and drag_start_screen.distance_to(drag_current_screen) > SELECTION_DRAG_VISUAL_THRESHOLD

func _begin_selection_drag(screen_point: Vector2) -> void:
	if selection_drag_overlay != null: selection_drag_overlay.begin(screen_point)

func _update_selection_drag(screen_point: Vector2) -> void:
	drag_current_screen = screen_point
	if selection_drag_phase == SelectionDragPhase.CANDIDATE and drag_start_screen.distance_to(screen_point) > SELECTION_DRAG_THRESHOLD:
		selection_drag_phase = SelectionDragPhase.ACTIVE
	var should_show := _selection_drag_visible()
	if selection_drag_overlay != null:
		selection_drag_overlay.update_drag(screen_point, should_show)

func _finish_selection_drag() -> void:
	if selection_drag_overlay != null: selection_drag_overlay.finish()

func _complete_selection_drag(screen_point: Vector2, additive: bool) -> void:
	if not dragging: return
	_update_selection_drag(screen_point)
	dragging = false
	selection_drag_phase = SelectionDragPhase.IDLE
	_finish_selection_drag()
	_select_screen_area(drag_start_screen, screen_point, additive)

func _cancel_selection_drag(block_until_release := false) -> void:
	dragging = false
	var left_down := _selection_native_left_down() if _uses_native_selection_pointer() else false
	selection_drag_phase = SelectionDragPhase.BLOCKED if block_until_release and left_down else SelectionDragPhase.IDLE
	if _uses_native_selection_pointer(): selection_previous_left_down = left_down
	_finish_selection_drag()

func _update_cursor() -> void:
	var screen_point := _selection_pointer_screen_position()
	cursor.position = screen_point
	if dragging:
		# Keep the current cursor for the click-sized candidate. The anchor is
		# sufficient feedback and avoids introducing a first-draw font cost.
		if _selection_drag_visible(): cursor.set_state("select")
		cursor.set_context("")
		return
	var over_ui := _selection_point_over_hud(screen_point)
	var world_point := get_viewport().get_canvas_transform().affine_inverse() * screen_point
	cursor.set_state(_cursor_state_at(world_point, over_ui))
	var resource := _resource_at(world_point) if not over_ui and build_mode == "" else null
	var context := ""
	if resource != null:
		context = GameData.RESOURCE_LABELS[resource.kind]
		context += " · %d" % resource.amount if not fog.active or fog.can_see(0, resource.position) else " · 未在视野内"
	cursor.set_context(context)

func _cursor_state_at(world_point: Vector2, over_ui := false) -> String:
	if over_ui: return "default"
	if order_mode in ["attack_move", "patrol", "focus", "attack_ground"]: return order_mode
	if order_mode in ["field_ram", "field_tower"]: return "build_valid" if world_map.is_walkable(world_point) else "build_invalid"
	if order_mode == "unload": return "unload" if world_map.is_walkable(world_point) else "build_invalid"
	if build_mode != "":
		var cost: Dictionary = RtsLandmarkCatalog.landmark(pending_landmark_id).get("cost", {}) if build_mode == "landmark" else RtsCivilizationRules.building_cost(civilizations[0], build_mode)
		return "build_valid" if can_place(build_mode, world_point, wall_vertical) and can_afford(0, cost) else "build_invalid"
	if _selection_drag_active(): return "drag"
	var entity := _entity_at(world_point)
	var resource := _resource_at(world_point)
	var post := _trade_post_at(world_point)
	var relic := _relic_at(world_point)
	var has_unit := false
	var has_worker := false
	var has_producer := false
	for subject in selected:
		if not is_instance_valid(subject): continue
		if subject is RtsUnit:
			has_unit = true
			if subject.kind == "villager": has_worker = true
		elif subject is RtsBuilding and subject.can_set_rally(0):
			has_producer = true
	if entity != null and is_enemy(0, entity.owner_id) and has_unit: return "attack"
	if resource != null and resource.appearance == "boar" and resource.wildlife_hp > 0.0 and has_unit: return "attack"
	if entity is RtsUnit and entity.kind in ["transport_ship", "battering_ram", "siege_tower"] and entity.owner_id == 0 and selected.any(func(subject: Node2D) -> bool: return subject is RtsUnit and not subject.stats.get("tags", []).has("naval") and not subject.stats.get("tags", []).has("siege")): return "board"
	if has_worker and entity is RtsBuilding and entity.owner_id == 0 and not entity.is_complete(): return "construct"
	if has_worker and entity != null and entity.owner_id == 0 and (entity is RtsBuilding or entity is RtsUnit and entity.stats.get("tags", []).has("siege")) and entity.hp < entity.max_hp: return "construct"
	if has_worker and (resource != null and resource.appearance != "fish" or entity is RtsBuilding and entity.kind == "farm"): return "gather"
	if resource != null and resource.appearance == "fish" and not selected.is_empty() and selected[0] is RtsUnit and selected[0].kind == "fishing_boat": return "gather"
	if post != null and not selected.is_empty() and selected[0] is RtsUnit and selected[0].kind == "trader": return "trade"
	if relic != null and not selected.is_empty() and selected[0] is RtsUnit and selected[0].kind == "monk": return "relic"
	if entity != null and (entity.owner_id == 0 or entity is RtsUnit and is_enemy(0, entity.owner_id) and not has_unit): return "select"
	if resource != null: return "select"
	if has_unit: return "move"
	if has_producer: return "rally"
	return "default"

func _player_center(owner_id: int) -> RtsBuilding:
	for building in buildings:
		if is_instance_valid(building) and building.owner_id == owner_id and building.kind == "town_center": return building
	return null

func _input(event: InputEvent) -> void:
	if age_choice_overlay != null:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			_close_age_choice()
			get_viewport().set_input_as_handled()
		return
	if unit_preview_page != null:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			menu_ui._close_unit_preview()
			get_viewport().set_input_as_handled()
		return
	if tech_tree_overlay != null:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			_close_tech_tree()
			get_viewport().set_input_as_handled()
		return
	if settings_overlay != null and settings_overlay.visible:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			_close_settings()
			get_viewport().set_input_as_handled()
		return
	if not started or game_over: return
	# Active drags receive motion before GUI controls can consume it.
	if event is InputEventMouseMotion:
		if dragging:
			_update_selection_drag(_selection_pointer_screen_position() if _uses_native_selection_pointer() else event.position)
		if wall_dragging:
			wall_end = get_global_mouse_position()
			queue_redraw()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if _finish_left_drag(event):
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and dragging:
		_cancel_selection_drag(true)
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_set_paused(not paused)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
		_toggle_global_queue()
		get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_V:
		_toggle_view_mode(true)
		get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R and (build_mode.ends_with("_wall") or build_mode.ends_with("_gate")):
		wall_vertical = not wall_vertical
		queue_redraw()
		get_viewport().set_input_as_handled()

func _finish_left_drag(event: InputEventMouseButton) -> bool:
	if wall_dragging:
		wall_dragging = false
		_confirm_wall_line(wall_start, get_global_mouse_position(), event.shift_pressed)
		return true
	if dragging:
		# Use the release event's position, not the pointer's later position.
		_complete_selection_drag(event.position, event.shift_pressed)
		if _uses_native_selection_pointer(): selection_previous_left_down = _selection_native_left_down()
		return true
	return false

func _unhandled_input(event: InputEvent) -> void:
	if not started or game_over or paused or age_choice_overlay != null: return
	if event is InputEventMagnifyGesture:
		if zoom_gesture_enabled:
			_adjust_zoom(event.factor, event.position)
			get_viewport().set_input_as_handled()
		return
	if event is InputEventPanGesture:
		_move_camera_screen_delta(event.delta * GESTURE_PAN_PIXELS)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		if event.pressed and (event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT): cursor.flash()
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_adjust_zoom(1.1, event.position)
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_adjust_zoom(1.0 / 1.1, event.position)
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if not event.pressed:
				_finish_left_drag(event)
				return
			if order_mode != "":
				_issue_mode_order(get_global_mouse_position(), event.shift_pressed)
				return
			if build_mode != "":
				if build_mode.ends_with("_wall"):
					wall_dragging = true
					wall_start = get_global_mouse_position()
					wall_end = wall_start
				else:
					_confirm_build(get_global_mouse_position(), event.shift_pressed)
				return
			if event.double_click:
				var clicked := _entity_at(get_viewport().get_canvas_transform().affine_inverse() * event.position)
				if clicked is RtsUnit and clicked.owner_id == 0:
					_cancel_selection_drag(true)
					_select_same_type_visible(clicked, event.shift_pressed)
					return
				if clicked is RtsBuilding and clicked.owner_id == 0:
					_cancel_selection_drag(true)
					_select_same_buildings_visible(clicked, event.shift_pressed)
					return
			if _uses_native_selection_pointer():
				if dragging and selection_drag_phase in [SelectionDragPhase.CANDIDATE, SelectionDragPhase.ACTIVE]: return
			_begin_selection_candidate(_selection_pointer_screen_position() if _uses_native_selection_pointer() else event.position)
			return
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if order_mode != "":
				order_mode = ""
				notify_player("已取消命令")
				return
			if build_mode != "":
				build_mode = ""
				wall_dragging = false
				pending_landmark_id = ""
				notify_player("已取消建造")
				return
			_issue_order(get_viewport().get_canvas_transform().affine_inverse() * event.position, event.shift_pressed)
			return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_PERIOD:
			_select_next_idle_villager()
			get_viewport().set_input_as_handled()
			return
		if event.keycode >= KEY_0 and event.keycode <= KEY_9 and (event.ctrl_pressed or control_groups.has(event.keycode)) and not event.alt_pressed:
			_handle_control_group(event)
			get_viewport().set_input_as_handled()
			return
		if hotkey_buttons.has(event.keycode):
			var button: RtsCommandButton = hotkey_buttons[event.keycode]
			if is_instance_valid(button) and not button.disabled:
				button.pressed.emit()
				get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_DELETE:
			for entity in selected.duplicate():
				if entity is RtsBuilding and entity.kind != "town_center": entity_destroyed(entity)

func _select_area(from: Vector2, to: Vector2, additive: bool) -> void:
	PlayerSelection.select_area(self, from, to, additive)

func _select_screen_area(from: Vector2, to: Vector2, additive: bool) -> void:
	PlayerSelection.select_screen_area(self, from, to, additive)

func _select_same_type_visible(clicked: RtsUnit, additive: bool) -> void:
	PlayerSelection.select_same_type_visible(self, clicked, additive)

func _select_same_buildings_visible(clicked: RtsBuilding, additive: bool) -> void:
	PlayerSelection.select_same_buildings_visible(self, clicked, additive)

func _handle_control_group(event: InputEventKey) -> void:
	PlayerSelection.handle_control_group(self, event)

func _entity_at(point: Vector2) -> Node2D:
	return PlayerSelection.entity_at(self, point)

func _resource_at(point: Vector2) -> RtsResource:
	return PlayerSelection.resource_at(self, point)

func _trade_post_at(point: Vector2) -> RtsTradePost:
	return PlayerSelection.trade_post_at(self, point)

func _relic_at(point: Vector2) -> RtsRelic:
	return PlayerSelection.relic_at(self, point)

func _issue_order(point: Vector2, append_order := false) -> void:
	PlayerOrders.issue_order(self, point, append_order)

func _issue_mode_order(point: Vector2, append_order := false) -> void:
	PlayerOrders.issue_mode_order(self, point, append_order)

func _issue_attack_move(point: Vector2, append_order := false) -> void:
	PlayerOrders.issue_attack_move(self, point, append_order)

func place_field_siege(kind: String, point: Vector2, append_order := false) -> bool:
	if players[0]["age"] < RtsTechTree.UNIT_AGE[kind] or not navigation.can_occupy(point, 20.0, null): return false
	var builders: Array[RtsUnit] = []
	for chosen in selected:
		if is_instance_valid(chosen) and chosen is RtsUnit and chosen.owner_id == 0 and chosen.stats.get("tags", []).has("infantry") and not chosen.stats.get("tags", []).has("siege"): builders.append(chosen)
	if builders.is_empty() or not spend(0, GameData.unit_cost(kind)):
		notify_player("需要步兵与足够资源")
		return false
	var site := spawn_unit(0, kind, point)
	site.field_build_total = 25.0
	site.field_build_remaining = site.field_build_total
	site.hp = maxf(1.0, site.max_hp * 0.3)
	for builder in builders: builder.issue_command("field_build", Vector2.INF, site, append_order)
	return true

func issue_group_order(movers: Array[RtsUnit], point: Vector2, attack_move := false, append_order := false) -> void:
	PlayerOrders.issue_group_order(self, movers, point, attack_move, append_order)

func _stop_selected_units() -> void:
	PlayerOrders.stop_selected_units(self)

func _retreat_selected() -> void:
	PlayerOrders.retreat_selected(self)

func _confirm_build(point: Vector2, append_order := false) -> void:
	var builders: Array[RtsUnit] = []
	for entity in selected:
		if is_instance_valid(entity) and entity is RtsUnit and entity.owner_id == 0 and entity.kind == "villager":
			builders.append(entity)
	if builders.is_empty():
		for unit in units:
			if is_instance_valid(unit) and unit.owner_id == 0 and unit.kind == "villager": builders.append(unit)
		builders.sort_custom(func(a: RtsUnit, b: RtsUnit) -> bool: return a.position.distance_squared_to(point) < b.position.distance_squared_to(point))
		if builders.size() > 2: builders.resize(2)
	if builders.is_empty():
		notify_player("需要村民建造")
		return
	var success := place_landmark(0, pending_landmark_id, point, builders, append_order) if build_mode == "landmark" else place_building(0, build_mode, point, builders, append_order, wall_vertical)
	if success and (not append_order or build_mode == "landmark"):
		build_mode = ""
		pending_landmark_id = ""
		_rebuild_actions()
	queue_redraw()

func _wall_positions(from: Vector2, to: Vector2, kind := "palisade_wall") -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var delta := to - from
	var vertical := absf(delta.y) > absf(delta.x) if delta.length() > 20.0 else wall_vertical
	var start := snap_build_point(kind, from, vertical)
	var end := snap_build_point(kind, to, vertical)
	var spacing := build_footprint_size(kind, vertical).y if vertical else build_footprint_size(kind, vertical).x
	var length := absf(end.y - start.y) if vertical else absf(end.x - start.x)
	var count := clampi(roundi(length / spacing) + 1, 1, 24)
	var sign_value := signf(delta.y if vertical else delta.x)
	if is_zero_approx(sign_value): sign_value = 1.0
	for index in count:
		positions.append(start + (Vector2.DOWN if vertical else Vector2.RIGHT) * sign_value * index * spacing)
	return positions

func _confirm_wall_line(from: Vector2, to: Vector2, append_order := false) -> void:
	var vertical := absf(to.y - from.y) > absf(to.x - from.x) if from.distance_to(to) > 20.0 else wall_vertical
	var positions := _wall_positions(from, to, build_mode)
	var builders: Array[RtsUnit] = []
	for entity in selected:
		if entity is RtsUnit and entity.owner_id == 0 and entity.kind == "villager": builders.append(entity)
	if builders.is_empty():
		notify_player("需要村民建墙")
		return
	var cost: Dictionary = GameData.BUILDINGS[build_mode]["cost"]
	for resource in cost:
		if players[0][resource] < cost[resource] * positions.size():
			notify_player("整段城墙所需资源不足")
			return
	for point in positions:
		if not can_place(build_mode, point, vertical):
			notify_player("城墙经过不可建造的位置")
			return
	for index in positions.size():
		place_building(0, build_mode, positions[index], builders, append_order or index > 0, vertical)
	if not append_order:
		build_mode = ""
		_rebuild_actions()
	queue_redraw()

func _update_hud() -> void:
	hud_ui._update_hud()

func _prune_hidden_enemy_selection() -> void:
	var changed := false
	for entity in selected.duplicate():
		var hidden := false
		if is_instance_valid(entity) and not entity.is_queued_for_deletion() and fog.active:
			if entity is RtsResource:
				hidden = not fog.can_show_resource(0, entity)
			elif entity is RtsUnit and is_enemy(0, entity.owner_id):
				hidden = not fog.can_detect_unit(0, entity)
			elif entity is RtsBuilding and is_enemy(0, entity.owner_id):
				hidden = not fog.can_see(0, entity.position)
		if not is_instance_valid(entity) or entity.is_queued_for_deletion() or hidden:
			selected.erase(entity)
			changed = true
	if changed:
		_rebuild_actions()
		_update_selection_hud()
		queue_redraw()

func _update_selection_hud() -> void:
	hud_ui._update_selection_hud()

func idle_villagers() -> Array[RtsUnit]:
	var result: Array[RtsUnit] = []
	for unit in units:
		if is_instance_valid(unit) and not unit.is_queued_for_deletion() and unit.owner_id == 0 and unit.kind == "villager" and unit.garrisoned_in == null and unit.order == "idle" and unit.command_queue.is_empty():
			result.append(unit)
	return result

func farm_worker(farm: RtsBuilding, excluded: RtsUnit = null) -> RtsUnit:
	for unit in units:
		if is_instance_valid(unit) and unit != excluded and unit.order == "gather" and unit.target == farm: return unit
	return null

func find_nearest_free_farm(owner_id: int, point: Vector2, max_distance: float, excluded: RtsUnit = null) -> RtsBuilding:
	var result: RtsBuilding
	var best := max_distance * max_distance
	for farm in buildings:
		if not is_instance_valid(farm) or farm.owner_id != owner_id or farm.kind != "farm" or not farm.is_complete() or farm_worker(farm, excluded) != null: continue
		var distance := point.distance_squared_to(farm.position)
		if distance < best:
			if excluded != null and navigation.path_to_range(point, farm.position, farm.size().x * 0.5 + excluded.radius() + 2.0, excluded).is_empty(): continue
			best = distance
			result = farm
	return result

func _select_next_idle_villager() -> void:
	if not started or paused or game_over: return
	var idle := idle_villagers()
	if idle.is_empty(): return
	var index := 0
	if selected.size() == 1 and selected[0] is RtsUnit:
		var previous := idle.find(selected[0])
		if previous >= 0: index = (previous + 1) % idle.size()
	selected.clear()
	selected.append(idle[index])
	camera.position = idle[index].position
	_clamp_camera_position()
	_rebuild_actions()
	_update_hud()
	queue_redraw()

func _toggle_global_queue() -> void:
	hud_ui._toggle_global_queue()

func _refresh_global_queue_panel() -> void:
	hud_ui._refresh_global_queue_panel()

func _refresh_action_buttons() -> void:
	hud_ui._refresh_action_buttons()

func _rebuild_actions() -> void:
	hud_ui._rebuild_actions()

func _activate_selected_ability(ability_id: String) -> void:
	for selection in selected:
		if is_instance_valid(selection) and selection is RtsUnit: selection.activate_ability(ability_id)
	_refresh_action_buttons()

func ring_town_bell(center: RtsBuilding) -> void:
	if not is_instance_valid(center) or center.kind != "town_center" or not center.is_complete(): return
	var ordered := center.garrisoned_units.size()
	for unit in units:
		if ordered >= center.garrison_capacity(): break
		if not is_instance_valid(unit) or unit.owner_id != center.owner_id or unit.kind != "villager" or unit.garrisoned_in != null or unit.position.distance_to(center.position) > 250.0: continue
		unit.issue_command("garrison", Vector2.INF, center)
		ordered += 1
	if center.owner_id == 0: notify_player("附近村民正在返回城镇中心")

func _set_selected_trade_resource(resource_kind: String) -> void:
	if resource_kind not in ["food", "wood", "gold"]: return
	for selection in selected:
		if is_instance_valid(selection) and selection is RtsUnit and selection.kind == "trader": selection.trade_resource_kind = resource_kind
	notify_player("商人将运回%s" % GameData.RESOURCE_LABELS[resource_kind])
	_update_hud()

func _show_age_choice() -> void:
	hud_ui._show_age_choice()

func _close_age_choice() -> void:
	hud_ui._close_age_choice()

func _select_landmark_for_placement(choice_id: String) -> void:
	var choice := RtsLandmarkCatalog.landmark(choice_id)
	if choice.is_empty(): return
	build_mode = "landmark"
	pending_landmark_id = choice_id
	notify_player("%s：%s。点击地图放置" % [choice["label"], choice["description"]])

func _add_action_spacer() -> void:
	hud_ui._add_action_spacer()

func _add_action(icon_kind: String, label_text: String, cost: Dictionary, keycode: int, action_type: String, callback: Callable) -> void:
	hud_ui._add_action(icon_kind, label_text, cost, keycode, action_type, callback)

func _draw() -> void:
	if not started:
		draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("638b5c"))
	for entity in selected:
		if not is_instance_valid(entity): continue
		var ground_lift := RtsIsoProjection.ground_lift(self, entity.position) if view_mode_25d else Vector2.ZERO
		if entity is RtsUnit:
			if selected.size() <= 6 and entity.owner_id == 0: _draw_selected_route(entity)
			draw_arc(entity.position + ground_lift, entity.radius() + 6, 0, TAU, 32, Color("f5e597"), 2)
		elif entity is RtsBuilding:
			draw_rect(Rect2(entity.position + ground_lift - entity.size() * 0.5 - Vector2(5, 5), entity.size() + Vector2(10, 10)), Color("f5e597"), false, 2)
			if entity.can_set_rally(0):
				var marker: Vector2 = entity.rally_point
				var marker_color := Color("f5e597")
				draw_line(entity.position, marker, Color(marker_color, 0.65), 2)
				draw_arc(marker, 9, 0, TAU, 24, marker_color, 2)
				draw_line(marker + Vector2(0, 12), marker + Vector2(0, -14), marker_color, 2)
				draw_colored_polygon(PackedVector2Array([marker + Vector2(0, -14), marker + Vector2(15, -9), marker + Vector2(0, -4)]), marker_color)
		elif entity is RtsResource:
			draw_arc(entity.position + ground_lift, entity.radius + 5.0, 0, TAU, 32, Color("f5e597"), 2)
	if build_mode != "":
		var mouse := get_global_mouse_position()
		var vertical := wall_vertical
		var preview_positions: Array[Vector2] = [mouse]
		if wall_dragging:
			preview_positions = _wall_positions(wall_start, wall_end, build_mode)
			vertical = absf(wall_end.y - wall_start.y) > absf(wall_end.x - wall_start.x) if wall_start.distance_to(wall_end) > 20.0 else wall_vertical
		for preview in preview_positions:
			var valid := can_place(build_mode, preview, vertical)
			var snapped := snap_build_point(build_mode, preview, vertical)
			var footprint := build_footprint_rect(build_mode, snapped, vertical)
			var color := Color(0.25, 0.9, 0.4, 0.35) if valid else Color(0.9, 0.2, 0.2, 0.35)
			draw_rect(footprint, color)
			draw_rect(footprint, color.darkened(0.25), false, 2.0)
			for x in range(1, roundi(footprint.size.x / BUILD_GRID_SIZE)):
				var grid_x := footprint.position.x + x * BUILD_GRID_SIZE
				draw_line(Vector2(grid_x, footprint.position.y), Vector2(grid_x, footprint.end.y), color.darkened(0.2), 1.0)
			for y in range(1, roundi(footprint.size.y / BUILD_GRID_SIZE)):
				var grid_y := footprint.position.y + y * BUILD_GRID_SIZE
				draw_line(Vector2(footprint.position.x, grid_y), Vector2(footprint.end.x, grid_y), color.darkened(0.2), 1.0)
	for line in hit_lines:
		if fog.active and line["owner"] != 0 and not fog.can_see(0, line["to"]): continue
		var progress := clampf(float(line["time"]) / 0.24, 0.0, 1.0)
		var origin: Vector2 = line["from"]
		var impact: Vector2 = line["to"]
		if view_mode_25d:
			origin += RtsIsoProjection.ground_lift(self, origin)
			impact += RtsIsoProjection.ground_lift(self, impact)
		var color := Color(player_color(line["owner"]).lightened(0.55), progress)
		draw_line(origin, impact, color, 2.5)
		draw_circle(impact, 3.0 + (1.0 - progress) * 5.0, Color("ffdf97", progress * 0.72))
		for ray in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			draw_line(impact + ray * 5.0, impact + ray * (8.0 + (1.0 - progress) * 7.0), Color("ffe9bc", progress), 1.6)
	for effect in world_effects:
		var effect_point: Vector2 = effect["point"]
		if effect["kind"] != "resource" and fog.active and not fog.can_see(0, effect_point): continue
		if view_mode_25d: effect_point += RtsIsoProjection.ground_lift(self, effect_point)
		var lifetime: float = 0.85 if effect["kind"] == "resource" else 0.9 if effect["kind"] in ["death", "collapse", "complete"] else 0.36 if effect["kind"] == "siege" else 0.24
		var progress := 1.0 - clampf(float(effect["time"]) / lifetime, 0.0, 1.0)
		var alpha := 1.0 - progress
		match effect["kind"]:
			"resource":
				var text_color := Color("e8ce76") if effect["resource"] == "gold" else Color("a7da80") if effect["resource"] == "food" else Color("d3ac77")
				var lift := RtsIsoProjection.world_delta(get_viewport().get_canvas_transform(), Vector2(0, -20.0 - progress * 26.0))
				draw_set_transform_matrix(RtsIsoProjection.upright(get_viewport().get_canvas_transform(), effect_point + lift))
				draw_string(ThemeDB.fallback_font, Vector2(-9, 0), "+%d" % effect["amount"], HORIZONTAL_ALIGNMENT_LEFT, -1, RtsUiTypography.screen_font_size(RtsUiTypography.CAPTION, text_scale), Color(text_color, alpha))
				draw_set_transform_matrix(Transform2D.IDENTITY)
			"death", "collapse":
				var radius := (10.0 if effect["kind"] == "death" else 25.0) * (0.8 + progress * 0.6)
				draw_circle(effect_point, radius, Color("775f48", alpha * 0.22))
				if effect["kind"] == "death":
					var body := PackedVector2Array([effect_point + Vector2(-10, -3), effect_point + Vector2(8, -2), effect_point + Vector2(11, 3), effect_point + Vector2(-8, 4)])
					draw_colored_polygon(body, Color(effect["color"], alpha * 0.65))
					draw_circle(effect_point + Vector2(11, 1), 3.5, Color("d9bf96", alpha * 0.7))
				for angle_index in 6:
					var direction := Vector2.from_angle(float(angle_index) * TAU / 6.0)
					draw_circle(effect_point + direction * radius * progress, 2.5 + progress * 2.0, Color("b8a481", alpha * 0.48))
			"complete":
				draw_arc(effect_point, 12.0 + progress * 28.0, 0.0, TAU, 32, Color("f2d587", alpha), 2.4)
			_:
				var size := 14.0 + progress * (26.0 if effect["kind"] == "siege" else 10.0)
				var color := Color("f3ba6c") if effect["kind"] == "siege" else Color("f3e2a5")
				draw_arc(effect_point, size, 0.0, TAU, 24, Color(color, alpha * 0.7), 2.0)
				for ray_index in 5:
					var direction := Vector2.from_angle(float(ray_index) * TAU / 5.0)
					draw_line(effect_point + direction * size * 0.5, effect_point + direction * size, Color(color, alpha), 1.7)
	for marker in order_markers:
		var alpha: float = clampf(marker["time"] / 0.82, 0.0, 1.0)
		var marker_point: Vector2 = marker["point"]
		draw_arc(marker_point, 9.0 + (1.0 - alpha) * 13.0, 0.0, TAU, 24, Color(marker["color"], alpha), 2.0)
		var symbol := "×" if marker["kind"] == "invalid" else "攻" if marker["kind"] == "attack" else "+" if marker["queued"] else "●"
		draw_set_transform_matrix(RtsIsoProjection.upright(get_viewport().get_canvas_transform(), marker_point))
		draw_string(ThemeDB.fallback_font, Vector2(-6, 5), symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(marker["color"], alpha))
		draw_set_transform_matrix(Transform2D.IDENTITY)

func _draw_selected_route(unit: RtsUnit) -> void:
	var points := PackedVector2Array()
	points.append(unit.position)
	if unit.order in ["move", "attack_move", "patrol", "unload"]:
		for index in range(unit.route_index, mini(unit.route.size(), unit.route_index + 24)):
			points.append(unit.route[index])
		if unit.destination != Vector2.INF: points.append(unit.destination)
	for command in unit.command_queue:
		var goal: Vector2 = command.get("point", Vector2.INF)
		if goal == Vector2.INF and is_instance_valid(command.get("target")): goal = command["target"].position
		if goal != Vector2.INF and Rect2(Vector2.ZERO, world_size).has_point(goal): points.append(goal)
	if points.size() < 2: return
	for index in points.size():
		if view_mode_25d: points[index] += RtsIsoProjection.ground_lift(self, points[index])
	for index in range(points.size() - 1):
		draw_dashed_line(points[index], points[index + 1], Color("e8d99e", 0.52), 1.4, 8.0)
	for index in range(1, points.size()):
		draw_arc(points[index], 3.5, 0.0, TAU, 14, Color("e8d99e", 0.72), 1.2)

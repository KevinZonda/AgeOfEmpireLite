extends Node2D
const SETTINGS_STORE = preload("res://scripts/ui/settings_store.gd")
const DISPLAY_SETTINGS = preload("res://scripts/ui/display_settings.gd")
const UI_STYLE = preload("res://scripts/ui/ui_style.gd")
var settings_store := SETTINGS_STORE.new()
var display_settings := DISPLAY_SETTINGS.new(self, settings_store)
const MatchSession = preload("res://scripts/match/match_session.gd")
var session := MatchSession.new(self)
const MatchSimulation = preload("res://scripts/match/match_simulation.gd")
var simulation := MatchSimulation.new(self)
const RtsUiTypography = preload("res://scripts/ui/typography.gd")

const WORLD_SIZE := Vector2(2400, 2400)
const START_CAMERA_POINT := Vector2(630, 820)
const WINDOW_RESOLUTIONS = DISPLAY_SETTINGS.WINDOW_RESOLUTIONS
const UI_SCALE_OPTIONS = SETTINGS_STORE.UI_SCALE_OPTIONS
const TEXT_SCALE_OPTIONS = SETTINGS_STORE.TEXT_SCALE_OPTIONS
static var base_tooltip_font_size := -1
const MINIMAP_SIZE_OPTIONS = SETTINGS_STORE.MINIMAP_SIZE_OPTIONS
const HEALTH_BAR_MODES = SETTINGS_STORE.HEALTH_BAR_MODES
const HEALTH_BAR_CHANGE_DURATION := 3.0
const MIN_UI_VIEWPORT_SIZE := Vector2(1280, 720)
const SETTINGS_PATH = SETTINGS_STORE.SETTINGS_PATH
const LEGACY_DISPLAY_SETTINGS_PATH = SETTINGS_STORE.LEGACY_DISPLAY_SETTINGS_PATH
const CAMERA_PAN_SPEED := 570.0
# At 720p, virtual 1x uses the previous maximum magnification.
const CAMERA_ZOOM_BASE := 1.65
const CAMERA_REFERENCE_HEIGHT := 720.0
# Partial resolution compensation: 720p = 1x, 900p = 1.1x, 1080p = 1.2x.
const CAMERA_RESOLUTION_COMPENSATION := 0.4
const DEFAULT_CAMERA_VIRTUAL_SCALE := 1.0
const MIN_CAMERA_VIRTUAL_SCALE := 0.5
const MAX_CAMERA_VIRTUAL_SCALE := 1.5
const GESTURE_PAN_PIXELS := 32.0
const EDGE_SCROLL_MARGIN := 28.0
const SELECTION_DRAG_THRESHOLD := 12.0
const SELECTION_DRAG_VISUAL_THRESHOLD := 1.0
const BUILD_GRID_SIZE := GameData.BUILD_GRID_SIZE
const MENU_UI := preload("res://scripts/ui/game_menu_ui.gd")
const HUD_UI := preload("res://scripts/ui/game_hud_ui.gd")
const PlayerSelection = preload("res://scripts/player/player_selection.gd")
const PlayerInput = preload("res://scripts/player/player_input.gd")
const PlatformPointer = preload("res://scripts/player/platform_pointer.gd")
const PlayerActions = preload("res://scripts/player/player_actions.gd")
var player_selection := PlayerSelection.new()
var player_input := PlayerInput.new(self)
var platform_pointer := PlatformPointer.new(self)
var player_actions := PlayerActions.new(self, Callable(player_input, "_gameplay_input_allowed"))
const ContextOrder = preload("res://scripts/player/context_order.gd")
const PlayerOrders = preload("res://scripts/player/player_orders.gd")
const MATCH_ECONOMY := preload("res://scripts/match/match_economy.gd")
const MATCH_PRODUCTION := preload("res://scripts/match/match_production.gd")
const MatchEntityQueries = preload("res://scripts/match/match_entity_queries.gd")
var match_entity_queries := MatchEntityQueries.new(session.entities)
var match_economy := MATCH_ECONOMY.new(session, match_entity_queries)
var match_production := MATCH_PRODUCTION.new(session, match_economy, match_entity_queries)
const FEEDBACK_AUDIO := preload("res://scripts/ui/feedback_audio.gd")
const UNIT_ABILITY_ACTIONS := [
	{"id": "palings", "label": "架设拒马", "kinds": ["longbow"]},
	{"id": "volley", "label": "万箭齐发", "kinds": ["longbow"]},
	{"id": "pavise", "label": "部署大盾", "kinds": ["arbaletrier"]},
	{"id": "helmsman", "label": "掌舵人", "kinds": ["warship"]},
	{"id": "convert", "label": "招降", "kinds": ["monk"]},
	{"id": "camp", "label": "预备营地", "kinds": ["scout", "man_at_arms"], "civilization": "English"},
	{"id": "artillery_shot", "label": "炮击齐射", "kinds": ["cannon"], "producer_landmark": "fr_college_of_artillery"},
]

const SelectionDragPhase = PlayerInput.SelectionDragPhase
const PLAYER_COLOR_NAMES := ["蓝色", "红色", "黄色", "绿色", "青色", "紫色", "橙色", "粉色"]
const PLAYER_COLORS := [
	Color("4e9bea"), Color("e65852"), Color("e5c44b"), Color("4ac57b"),
	Color("4ac5c5"), Color("a77bd8"), Color("e5ae4b"), Color("e58fba"),
]

var world_size: Vector2:
	get: return session.world_size
	set(value): session.world_size = value
var civilizations: Array:
	get: return session.civilizations
	set(value): session.civilizations = value
var teams: Array[int]:
	get: return session.teams
	set(value): session.teams = value
var match_mode: String:
	get: return session.match_mode
	set(value): session.match_mode = value
var defeated_players: Array[int]:
	get: return session.defeated_players
	set(value): session.defeated_players = value
var players: Array[Dictionary]:
	get: return session.players
	set(value): session.players = value
var units: Array[RtsUnit]:
	get: return session.entities.units
	set(value): session.entities.units = value
var buildings: Array[RtsBuilding]:
	get: return session.entities.buildings
	set(value): session.entities.buildings = value
var resources: Array[RtsResource]:
	get: return session.entities.resources
	set(value): session.entities.resources = value
var trade_posts: Array[RtsTradePost]:
	get: return session.entities.trade_posts
	set(value): session.entities.trade_posts = value
var relics: Array[RtsRelic]:
	get: return session.entities.relics
	set(value): session.entities.relics = value
var market_supply: Dictionary:
	get: return session.market_supply
	set(value): session.market_supply = value
var selected: Array[Node2D]:
	get: return player_selection.selected
	set(value): player_selection.selected = value
var control_groups: Dictionary:
	get: return player_selection.control_groups
	set(value): player_selection.control_groups = value
var last_group_key: int:
	get: return player_selection.last_group_key
	set(value): player_selection.last_group_key = value
var last_group_press_time: float:
	get: return player_selection.last_group_press_time
	set(value): player_selection.last_group_press_time = value
var camera: Camera2D
var camera_physical_scale := 1.0
var camera_virtual_scale := DEFAULT_CAMERA_VIRTUAL_SCALE
var world_map: RtsWorldMap
var navigation: RtsNavigation
var weather: RtsWeather
var fog: RtsFogOfWar
var objectives: RtsObjectiveManager
var map_seed: int:
	get: return session.map_seed
	set(value): session.map_seed = value
var map_style: String:
	get: return session.map_style
	set(value): session.map_style = value
var selected_map_size := WORLD_SIZE
var selected_map_style := "balanced"
var map_size_choice: OptionButton:
	get: return menu_ui.map_size_choice if menu_ui != null else null
	set(value): menu_ui.map_size_choice = value
var map_style_choice: OptionButton:
	get: return menu_ui.map_style_choice if menu_ui != null else null
	set(value): menu_ui.map_style_choice = value
var map_seed_input: LineEdit:
	get: return menu_ui.map_seed_input if menu_ui != null else null
	set(value): menu_ui.map_seed_input = value
var projection_choice: OptionButton:
	get: return menu_ui.projection_choice if menu_ui != null else null
	set(value): menu_ui.projection_choice = value
var initial_resources_choice: OptionButton:
	get: return menu_ui.initial_resources_choice if menu_ui != null else null
	set(value): menu_ui.initial_resources_choice = value
var fog_mode_choice: OptionButton:
	get: return menu_ui.fog_mode_choice if menu_ui != null else null
	set(value): menu_ui.fog_mode_choice = value
var player_list: VBoxContainer:
	get: return menu_ui.player_list if menu_ui != null else null
	set(value): menu_ui.player_list = value
var add_player_button: Button:
	get: return menu_ui.add_player_button if menu_ui != null else null
	set(value): menu_ui.add_player_button = value
var setup_start_button: Button:
	get: return menu_ui.setup_start_button if menu_ui != null else null
	set(value): menu_ui.setup_start_button = value
var setup_warning_label: Label:
	get: return menu_ui.setup_warning_label if menu_ui != null else null
	set(value): menu_ui.setup_warning_label = value
var lobby_players: Array[Dictionary] = [
	{"civilization": "English", "difficulty": "human", "team": 1, "color": 0},
	{"civilization": "French", "difficulty": "normal", "team": 2, "color": 1},
]
var use_lobby_setup := false
var selected_initial_resources := 1
var selected_fog_mode := "enabled"
var selected_view_mode_25d: bool:
	get: return settings_store.selected_view_mode_25d if settings_store != null else false
	set(value): settings_store.selected_view_mode_25d = value
var started: bool:
	get: return session.started
	set(value): session.started = value
var game_over: bool:
	get: return session.game_over
	set(value): session.game_over = value
var paused: bool:
	get: return session.paused
	set(value): session.paused = value
var view_mode_25d := false
var formation_mode := "balanced"
var formation_width := 5
var selected_civ := "English"
var selected_opponent_civ := "French"
var build_mode: String:
	get: return player_input.build_mode
	set(value): player_input.set_build_mode(value)
var pending_landmark_id: String:
	get: return player_input.pending_landmark_id
	set(value): player_input.pending_landmark_id = value
var build_page: int:
	get: return player_input.build_page
	set(value): player_input.build_page = value
var order_mode: String:
	get: return player_input.order_mode
	set(value): player_input.set_order_mode(value)
var dragging: bool:
	get: return player_input.dragging
	set(value): player_input.dragging = value
var wall_dragging: bool:
	get: return player_input.wall_dragging
	set(value): player_input.wall_dragging = value
var wall_vertical: bool:
	get: return player_input.wall_vertical
	set(value): player_input.wall_vertical = value
var wall_start: Vector2:
	get: return player_input.wall_start
	set(value): player_input.wall_start = value
var wall_end: Vector2:
	get: return player_input.wall_end
	set(value): player_input.wall_end = value
var drag_start_screen: Vector2:
	get: return player_input.drag_start_screen
	set(value): player_input.drag_start_screen = value
var drag_current_screen: Vector2:
	get: return player_input.drag_current_screen
	set(value): player_input.drag_current_screen = value
var selection_drag_phase: int:
	get: return player_input.selection_drag_phase
	set(value): player_input.selection_drag_phase = value
var selection_drag_additive: bool:
	get: return player_input.selection_drag_additive
	set(value): player_input.selection_drag_additive = value
var selection_previous_left_down: bool:
	get: return player_input.selection_previous_left_down
	set(value): player_input.selection_previous_left_down = value
var ai_think_timers: Dictionary = {}
var iso_sort_timer := 0.0
var ai: RtsAiController
var ai_controllers: Array[RtsAiController] = []
var hud_timer := 0.0
var notice_timer := 0.0
var _effects_redraw_timer := 0.0
var hit_lines: Array[Dictionary] = []
var order_markers: Array[Dictionary] = []
var world_effects: Array[Dictionary] = []
var feedback_audio: Node
var match_statistics := RtsMatchStatistics.new()

var top_label: Label:
	get: return hud_ui.top_label if hud_ui != null else null
	set(value): hud_ui.top_label = value
var fps_label: Label:
	get: return hud_ui.fps_label if hud_ui != null else null
	set(value): hud_ui.fps_label = value
var fps_update_timer: float:
	get: return hud_ui.fps_update_timer if hud_ui != null else 0.0
	set(value): hud_ui.fps_update_timer = value
var resource_readouts: Dictionary:
	get: return hud_ui.resource_readouts if hud_ui != null else {}
	set(value): hud_ui.resource_readouts = value
var population_label: Label:
	get: return hud_ui.population_label if hud_ui != null else null
	set(value): hud_ui.population_label = value
var hud_top: PanelContainer:
	get: return hud_ui.hud_top if hud_ui != null else null
	set(value): hud_ui.hud_top = value
var hud_bottom: PanelContainer:
	get: return hud_ui.hud_bottom if hud_ui != null else null
	set(value): hud_ui.hud_bottom = value
var menu_backdrop: Control:
	get: return menu_ui.menu_backdrop if menu_ui != null else null
	set(value): menu_ui.menu_backdrop = value
var idle_villager_button: Button:
	get: return hud_ui.idle_villager_button if hud_ui != null else null
	set(value): hud_ui.idle_villager_button = value
var info_label: Label:
	get: return hud_ui.info_label if hud_ui != null else null
	set(value): hud_ui.info_label = value
var detail_label: Label:
	get: return hud_ui.detail_label if hud_ui != null else null
	set(value): hud_ui.detail_label = value
var selection_portrait: Variant:
	get: return hud_ui.selection_portrait if hud_ui != null else null
	set(value): hud_ui.selection_portrait = value
var selection_health: ProgressBar:
	get: return hud_ui.selection_health if hud_ui != null else null
	set(value): hud_ui.selection_health = value
var selection_progress: ProgressBar:
	get: return hud_ui.selection_progress if hud_ui != null else null
	set(value): hud_ui.selection_progress = value
var queue_label: Label:
	get: return hud_ui.queue_label if hud_ui != null else null
	set(value): hud_ui.queue_label = value
var queue_controls: HBoxContainer:
	get: return hud_ui.queue_controls if hud_ui != null else null
	set(value): hud_ui.queue_controls = value
var global_queue_panel: PanelContainer:
	get: return hud_ui.global_queue_panel if hud_ui != null else null
	set(value): hud_ui.global_queue_panel = value
var global_queue_list: VBoxContainer:
	get: return hud_ui.global_queue_list if hud_ui != null else null
	set(value): hud_ui.global_queue_list = value
var view_button: Button:
	get: return hud_ui.view_button if hud_ui != null else null
	set(value): hud_ui.view_button = value
var command_title: Label:
	get: return hud_ui.command_title if hud_ui != null else null
	set(value): hud_ui.command_title = value
var notice_label: Label:
	get: return hud_ui.notice_label if hud_ui != null else null
	set(value): hud_ui.notice_label = value
var action_bar: GridContainer:
	get: return hud_ui.action_bar if hud_ui != null else null
	set(value): hud_ui.action_bar = value
var command_buttons: Array[RtsCommandButton]:
	get: return hud_ui.command_buttons if hud_ui != null else []
	set(value): hud_ui.command_buttons = value
var hotkey_buttons: Dictionary:
	get: return hud_ui.hotkey_buttons if hud_ui != null else {}
	set(value): hud_ui.hotkey_buttons = value
var minimap: RtsMinimap:
	get: return hud_ui.minimap if hud_ui != null else null
	set(value): hud_ui.minimap = value
var menu_ui: MENU_UI
var hud_ui: HUD_UI
var ui_root: Control:
	get: return hud_ui.ui_root if hud_ui != null else null
	set(value): hud_ui.ui_root = value
var ui_scale: float:
	get: return settings_store.ui_scale if settings_store != null else 0.0
	set(value): settings_store.ui_scale = value
var text_scale: float:
	get: return settings_store.text_scale if settings_store != null else 0.0
	set(value): settings_store.text_scale = value
var applied_world_text_scale := -1.0
var minimap_size: int:
	get: return settings_store.minimap_size if settings_store != null else 0
	set(value): settings_store.minimap_size = value
var show_building_icons: bool:
	get: return settings_store.show_building_icons if settings_store != null else false
	set(value): settings_store.show_building_icons = value
var show_building_names: bool:
	get: return settings_store.show_building_names if settings_store != null else false
	set(value): settings_store.show_building_names = value
var show_fps: bool:
	get: return settings_store.show_fps if settings_store != null else false
	set(value): settings_store.show_fps = value
var health_bar_mode: String:
	get: return settings_store.health_bar_mode if settings_store != null else ""
	set(value): settings_store.health_bar_mode = value
var building_icons_toggle: CheckButton:
	get: return menu_ui.building_icons_toggle if menu_ui != null else null
	set(value): menu_ui.building_icons_toggle = value
var building_names_toggle: CheckButton:
	get: return menu_ui.building_names_toggle if menu_ui != null else null
	set(value): menu_ui.building_names_toggle = value
var fps_toggle: CheckButton:
	get: return menu_ui.fps_toggle if menu_ui != null else null
	set(value): menu_ui.fps_toggle = value
var health_bar_choice: OptionButton:
	get: return menu_ui.health_bar_choice if menu_ui != null else null
	set(value): menu_ui.health_bar_choice = value
var ui_scale_choice: OptionButton:
	get: return menu_ui.ui_scale_choice if menu_ui != null else null
	set(value): menu_ui.ui_scale_choice = value
var text_scale_choice: OptionButton:
	get: return menu_ui.text_scale_choice if menu_ui != null else null
	set(value): menu_ui.text_scale_choice = value
var minimap_size_choice: OptionButton:
	get: return menu_ui.minimap_size_choice if menu_ui != null else null
	set(value): menu_ui.minimap_size_choice = value
var ui_scale_values: Array[float]:
	get: return menu_ui.ui_scale_values if menu_ui != null else []
	set(value): menu_ui.ui_scale_values = value
var ui_scale_update_pending: bool:
	get: return hud_ui.ui_scale_update_pending if hud_ui != null else false
	set(value): hud_ui.ui_scale_update_pending = value
var menu_panel: PanelContainer:
	get: return menu_ui.menu_panel if menu_ui != null else null
	set(value): menu_ui.menu_panel = value
var tech_tree_overlay: ColorRect:
	get: return menu_ui.tech_tree_overlay if menu_ui != null else null
	set(value): menu_ui.tech_tree_overlay = value
var tech_tree_civilization_choice: OptionButton:
	get: return menu_ui.tech_tree_civilization_choice if menu_ui != null else null
	set(value): menu_ui.tech_tree_civilization_choice = value
var tech_tree_page: Variant:
	get: return menu_ui.tech_tree_page if menu_ui != null else null
	set(value): menu_ui.tech_tree_page = value
var unit_preview_page: Variant:
	get: return menu_ui.unit_preview_page if menu_ui != null else null
	set(value): menu_ui.unit_preview_page = value
var age_choice_overlay: ColorRect:
	get: return hud_ui.age_choice_overlay if hud_ui != null else null
	set(value): hud_ui.age_choice_overlay = value
var result_panel: PanelContainer:
	get: return menu_ui.report_ui.panel if menu_ui != null else null
	set(value): menu_ui.report_ui.panel = value
var pause_overlay: ColorRect:
	get: return menu_ui.pause_overlay if menu_ui != null else null
	set(value): menu_ui.pause_overlay = value
var settings_overlay: ColorRect:
	get: return menu_ui.settings_overlay if menu_ui != null else null
	set(value): menu_ui.settings_overlay = value
var settings_tabs: TabContainer:
	get: return menu_ui.settings_tabs if menu_ui != null else null
	set(value): menu_ui.settings_tabs = value
var settings_tab_buttons: Array[Button]:
	get: return menu_ui.settings_tab_buttons if menu_ui != null else []
	set(value): menu_ui.settings_tab_buttons = value
var window_mode_choice: OptionButton:
	get: return menu_ui.window_mode_choice if menu_ui != null else null
	set(value): menu_ui.window_mode_choice = value
var resolution_choice: OptionButton:
	get: return menu_ui.resolution_choice if menu_ui != null else null
	set(value): menu_ui.resolution_choice = value
var resolution_values: Array[Vector2i]:
	get: return menu_ui.resolution_values if menu_ui != null else []
	set(value): menu_ui.resolution_values = value
var windowed_resolution: Vector2i:
	get: return settings_store.windowed_resolution if settings_store != null else Vector2i.ZERO
	set(value): settings_store.windowed_resolution = value
var adaptive_resolution_enabled: bool:
	get: return settings_store.adaptive_resolution_enabled if settings_store != null else false
	set(value): settings_store.adaptive_resolution_enabled = value
var adaptive_usable_rect: Rect2i:
	get: return display_settings.adaptive_usable_rect if display_settings != null else Rect2i()
	set(value): display_settings.adaptive_usable_rect = value
var adaptive_resolution_check_timer: float:
	get: return display_settings.adaptive_resolution_check_timer if display_settings != null else 0.0
	set(value): display_settings.adaptive_resolution_check_timer = value
var fullscreen_enabled: bool:
	get: return settings_store.fullscreen_enabled if settings_store != null else false
	set(value): settings_store.fullscreen_enabled = value
var edge_scroll_toggle: CheckButton:
	get: return menu_ui.edge_scroll_toggle if menu_ui != null else null
	set(value): menu_ui.edge_scroll_toggle = value
var edge_scroll_enabled: bool:
	get: return settings_store.edge_scroll_enabled if settings_store != null else false
	set(value): settings_store.edge_scroll_enabled = value
var zoom_gesture_toggle: CheckButton:
	get: return menu_ui.zoom_gesture_toggle if menu_ui != null else null
	set(value): menu_ui.zoom_gesture_toggle = value
var zoom_gesture_enabled: bool:
	get: return settings_store.zoom_gesture_enabled if settings_store != null else false
	set(value): settings_store.zoom_gesture_enabled = value
var settings_from_pause: bool:
	get: return menu_ui.settings_from_pause if menu_ui != null else false
	set(value): menu_ui.settings_from_pause = value
var cursor: GameCursor:
	get: return hud_ui.cursor if hud_ui != null else null
	set(value): hud_ui.cursor = value
var selection_drag_overlay: Variant:
	get: return hud_ui.selection_drag_overlay if hud_ui != null else null
	set(value): hud_ui.selection_drag_overlay = value

func _ready() -> void:
	child_entered_tree.connect(simulation.register)
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
	navigation.background_recovery_enabled = OS.get_environment("RTS_ASYNC_NAV") != "0"
	navigation.route_budget_enabled = OS.get_environment("RTS_ROUTE_BUDGET") == "1"
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
	_update_camera_physical_scale()
	_apply_camera_zoom()
	feedback_audio = FEEDBACK_AUDIO.new()
	add_child(feedback_audio)
	weather = RtsWeather.new()
	weather.z_index = RtsWeather.RAIN_Z_INDEX
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
	session.changes.feedback_requested.connect(_on_match_feedback)
	match_economy.resource_credited.connect(match_statistics.record_income)
	match_production.age_advanced.connect(func(owner_id: int, age: int) -> void: match_statistics.record_event(owner_id, "进入时代 %d" % age))
	match_production.unit_spawn_requested.connect(func(owner_id: int, kind: String, producer: Object) -> void: spawn_unit(owner_id, kind, find_spawn_position(producer)))
	_create_hud()
	get_viewport().size_changed.connect(_apply_ui_scales)
	get_viewport().size_changed.connect(_update_camera_physical_scale)
	get_tree().node_added.connect(_on_ui_node_added)
	_apply_ui_scales()
	_create_cursor()
	_show_menu()
	platform_pointer.setup_web_gestures()
	queue_redraw()

func _load_ui_font() -> void:
	UI_STYLE.load_font()

func _exit_tree() -> void:
	platform_pointer.release_web_gestures()
	player_actions.clear()
	if navigation != null: navigation.shutdown_jobs()
	if get_tree().node_added.is_connected(_on_ui_node_added): get_tree().node_added.disconnect(_on_ui_node_added)
	_cancel_selection_drag()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# Scene-free matches never enter the tree, so _exit_tree cannot release
		# catalog callbacks which capture their RefCounted owner.
		if player_actions != null: player_actions.clear()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_cancel_selection_drag()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN and started and not paused and not game_over:
		_apply_gameplay_mouse_mode()
		_reset_selection_pointer()

func _create_cursor() -> void:
	hud_ui._create_cursor()

func _create_hud() -> void:
	menu_ui = MENU_UI.new(self)
	menu_ui.match_requested.connect(_start_lobby_match)
	menu_ui.report_ui.return_requested.connect(_return_to_menu)
	menu_ui.pause_requested.connect(_set_paused)
	menu_ui.restart_requested.connect(func() -> void: start_game(selected_civ, -1, selected_opponent_civ))
	menu_ui.return_requested.connect(_return_to_menu)
	menu_ui.quit_requested.connect(func() -> void: get_tree().quit())
	hud_ui = HUD_UI.new(self)
	hud_ui.view_mode_requested.connect(func() -> void: _toggle_view_mode(true))
	hud_ui.idle_villager_requested.connect(_select_next_idle_villager)
	add_child(hud_ui)
	hud_ui._create_hud()

func _on_ui_node_added(node: Node) -> void:
	hud_ui._on_ui_node_added(node)

func _apply_ui_scales() -> void:
	hud_ui._apply_ui_scales()

func _hud_panel_style(color: Color, margin: float) -> StyleBoxFlat:
	return UI_STYLE._hud_panel_style(color, margin)

func _add_resource_readout(parent: HBoxContainer, kind: String) -> void:
	hud_ui._add_resource_readout(parent, kind)

func _button_style(fill: Color, border: Color) -> StyleBoxFlat:
	return UI_STYLE._button_style(fill, border)

func _parchment_style(fill: Color, margin: float) -> StyleBoxFlat:
	return UI_STYLE._parchment_style(fill, margin)

func _style_menu_button(button: BaseButton, selected := false) -> void:
	UI_STYLE._style_menu_button(button, selected)

func _style_button(button: BaseButton, primary := false) -> void:
	UI_STYLE._style_button(button, primary)

func _style_progress_bar(bar: ProgressBar, fill_color: Color) -> void:
	UI_STYLE._style_progress_bar(bar, fill_color)

func _add_pause_button(parent: Node, label_text: String, action: Callable) -> void:
	menu_ui._add_pause_button(parent, label_text, action)

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
	return DISPLAY_SETTINGS._fit_window_size_to_screen(usable_size)

func _adaptive_window_resolution() -> Vector2i:
	return display_settings._adaptive_window_resolution()

func _apply_window_resolution(resolution: Vector2i, save_setting := true) -> void:
	display_settings._apply_window_resolution(resolution, save_setting)

func _window_is_fullscreen() -> bool:
	return display_settings._window_is_fullscreen()

func _apply_window_mode(fullscreen: bool, save_setting := true) -> void:
	display_settings._apply_window_mode(fullscreen, save_setting)

func _save_settings() -> void:
	settings_store.save(display_settings._window_is_fullscreen())

func _load_settings() -> void:
	settings_store.load_preferences(display_settings)

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
	simulation.reset()
	paused = false
	pause_overlay.hide()
	selected_civ = civ
	selected_opponent_civ = opponent_civ
	var player_count := lobby_players.size() if use_lobby_setup else 2 if match_mode == "duel" else 3 if match_mode == "ffa3" else 4
	session.configure_players(civ, opponent_civ, match_mode, lobby_players if use_lobby_setup else [], selected_initial_resources)
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
	camera_virtual_scale = DEFAULT_CAMERA_VIRTUAL_SCALE
	_update_camera_physical_scale()
	_apply_camera_zoom()
	camera.position = _starting_camera_position()
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
	_stagger_ai_think_phases()
	ai = ai_controllers[0]
	if view_mode_25d != selected_view_mode_25d: _toggle_view_mode()
	# A new projected match must center home even if the previous match used 2.5D.
	if view_mode_25d: camera.position = spawn_point_for(0)
	_clamp_camera_position()
	camera.force_update_scroll()
	_update_hud()
	_rebuild_actions()
	queue_redraw()

func _clear_world() -> void:
	simulation.dispose_projectiles()
	if navigation != null: navigation.shutdown_jobs()
	_close_age_choice()
	_cancel_selection_drag()
	if world_map != null: world_map.hide()
	if weather != null: weather.hide()
	if fog != null: fog.clear()
	session.entities.clear()
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
	return session.is_enemy(a, b)

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
	# Gather the defended centers once; the unit pass then costs O(units x centers)
	# instead of O(units x buildings).
	var centers: Array[RtsBuilding] = []
	for building in buildings:
		if is_instance_valid(building) and building.kind == "town_center" and not is_enemy(owner_id, building.owner_id):
			centers.append(building)
	var threat: RtsUnit
	var threat_score := INF
	for unit in units:
		if not is_instance_valid(unit) or not is_enemy(owner_id, unit.owner_id) or not unit.stats.get("tags", []).has("military"): continue
		if fog.active and not fog.can_detect_unit(owner_id, unit): continue
		for center in centers:
			var distance := center.position.distance_squared_to(unit.position)
			if distance < 340.0 * 340.0 and distance < threat_score:
				threat = unit
				threat_score = distance
	if threat != null: return threat
	return nearest_enemy_center(owner_id)

func _spawn_neutral_sites() -> void:
	session.entities.spawn_neutral_sites()

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
	return session.entities.spawn_resource(kind, world_point, amount, appearance)

func spawn_unit(owner_id: int, kind: String, world_point: Vector2, rally := Vector2.INF, rally_target: Node2D = null, rally_resource_kind := "") -> RtsUnit:
	return session.entities.spawn_unit(owner_id, kind, world_point, rally, rally_target, rally_resource_kind)

func spawn_building(owner_id: int, kind: String, world_point: Vector2, under_construction := false, landmark_id := "", vertical := false) -> RtsBuilding:
	return session.entities.spawn_building(owner_id, kind, world_point, under_construction, landmark_id, vertical)

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
	session.entities.entity_destroyed(entity)

func _eliminate_player(owner_id: int) -> void:
	session.entities.eliminate_player(owner_id)

func _check_match_end() -> void:
	var surviving_teams: Dictionary = {}
	for owner_id in players.size():
		if not defeated_players.has(owner_id): surviving_teams[teams[owner_id]] = true
	if not surviving_teams.has(teams[0]):
		_finish_game(false, "landmarks")
	elif surviving_teams.size() == 1:
		_finish_game(true, "landmarks")

func _finish_game(won: bool, reason := "landmarks") -> void:
	simulation.dispose_projectiles()
	if game_over: return
	_cancel_selection_drag()
	match_statistics.record_event(0, "对局结束")
	match_statistics.sample()
	game_over = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	cursor.hide()
	menu_ui.report_ui.show_result(won, reason)

func _show_match_report(won: bool, result_reason: String) -> void:
	menu_ui.report_ui.show_report(won, result_reason)

func credit_resource(owner_id: int, kind: String, amount: int) -> void:
	match_economy.credit_resource(owner_id, kind, amount)

func market_quote(resource_kind: String, buy: bool, owner_id := 0) -> int:
	return match_economy.market_quote(resource_kind, buy, owner_id)

func exchange_resource(owner_id: int, resource_kind: String, buy: bool) -> bool:
	return match_economy.exchange_resource(owner_id, resource_kind, buy)

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
	return match_economy.can_afford(owner_id, cost)

func spend(owner_id: int, cost: Dictionary) -> bool:
	return match_economy.spend(owner_id, cost)

func population_used(owner_id: int) -> int:
	return match_economy.population_used(owner_id)

func population_cap(owner_id: int) -> int:
	return match_economy.population_cap(owner_id)

func train_unit(building: RtsBuilding, unit_kind: String) -> bool:
	return match_production.train_unit(building, unit_kind)

func queued_research(owner_id: int) -> Array[String]:
	return match_production.queued_research(owner_id)

func research_technology(building: RtsBuilding, tech_id: String) -> bool:
	return match_production.research_technology(building, tech_id)

func complete_research(owner_id: int, tech_id: String) -> void:
	match_production.complete_research(owner_id, tech_id)

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
	var status := RtsActionAvailability.construction(self, owner_id, "landmark", world_point, false, landmark_id)
	if not status["available"]:
		if owner_id == 0: notify_player(status["reason"])
		return false
	var builders: Array[RtsUnit] = []
	for worker in workers:
		if is_instance_valid(worker) and worker.owner_id == owner_id and worker.kind == "villager": builders.append(worker)
	if builders.is_empty(): return false
	var choice := RtsLandmarkCatalog.landmark(landmark_id)
	if not spend(owner_id, status["cost"]): return false
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
	match_production.complete_age(owner_id, target_age, landmark_id)

func cancel_production_job(building: RtsBuilding, index: int = 0) -> bool:
	return match_production.cancel_job(building, index)

func build_footprint_size(kind: String, vertical := false) -> Vector2:
	var definition: Dictionary = GameData.BUILDINGS[kind]
	if definition.has("footprint_tiles"):
		return Vector2(definition["footprint_tiles"]) * BUILD_GRID_SIZE
	var dimensions: Vector2 = definition["size"]
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
	var status := RtsActionAvailability.construction(self, owner_id, kind, world_point, vertical)
	if not status["available"]:
		if owner_id == 0: notify_player(status["reason"])
		return false
	var builders: Array[RtsUnit] = []
	for worker in workers:
		if is_instance_valid(worker) and worker.owner_id == owner_id and worker.kind == "villager":
			builders.append(worker)
	if builders.is_empty(): return false
	if not spend(owner_id, status["cost"]): return false
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

func _on_match_feedback(owner_id: int, message: String) -> void:
	if owner_id == 0: notify_player(message)

func notify_player(message: String) -> void:
	if notice_label != null: notice_label.text = message
	notice_timer = 3.5

func _process(delta: float) -> void:
	if hud_ui != null: hud_ui.tick_fps(delta)
	display_settings.tick(delta)
	if not started or game_over or paused:
		if navigation != null: navigation.tick_jobs(false)
		return
	_tick_presentation(delta)
	step(delta)

# The same explicit step is used by live matches and accelerated regressions.
# Delta stays caller-controlled; fixed-rate simulation is a separate behavior
# change and is not silently enabled by introducing this ownership boundary.
func step(delta: float) -> bool:
	return simulation.step(delta)

func _tick_match_logic(delta: float) -> void:
	match_statistics.tick(delta)
	for controller in ai_controllers:
		if defeated_players.has(controller.owner_id): continue
		var owner_id := controller.owner_id
		ai_think_timers[owner_id] = float(ai_think_timers.get(owner_id, 0.0)) - delta
		if ai_think_timers[owner_id] <= 0.0:
			controller.tick()
			ai_think_timers[owner_id] = controller.next_think_delay()

# AIs sharing a think interval spread their steady-state think times evenly
# across it, so several same-difficulty opponents never think on the same
# frame. The first think still happens at match start (timer 0); the phase is
# consumed by the first reschedule and the exact interval keeps the cadence.
func _stagger_ai_think_phases() -> void:
	var group_sizes := {}
	for controller in ai_controllers:
		var interval := controller.think_interval()
		group_sizes[interval] = int(group_sizes.get(interval, 0)) + 1
	var group_ranks := {}
	for controller in ai_controllers:
		var interval := controller.think_interval()
		var rank: int = int(group_ranks.get(interval, 0))
		group_ranks[interval] = rank + 1
		var group_size: int = group_sizes[interval]
		controller.think_phase = interval * float(rank) / float(group_size) if group_size > 1 else 0.0
		controller._think_phase_pending = controller.think_phase > 0.0

func _tick_presentation(delta: float) -> void:
	if _uses_native_selection_pointer():
		_poll_selection_pointer()
	elif dragging:
		_update_selection_drag(get_viewport().get_mouse_position())
	_prune_hidden_enemy_selection()
	if view_mode_25d:
		iso_sort_timer -= delta
		if iso_sort_timer <= 0.0:
			_update_iso_depths()
			iso_sort_timer = 0.1
	_pan_camera(delta)
	_update_cursor(delta)
	if notice_timer > 0.0:
		notice_timer -= delta
		if notice_timer <= 0.0: notice_label.text = ""
	hud_timer -= delta
	if hud_timer <= 0.0:
		_update_hud()
		hud_timer = 0.25
	_compact_timed_entries(hit_lines, delta)
	_compact_timed_entries(order_markers, delta)
	_compact_timed_entries(world_effects, delta)
	var selection_follows_unit := false
	for entity in selected:
		if is_instance_valid(entity) and entity is RtsUnit:
			selection_follows_unit = true
			break
	if build_mode != "" or selection_follows_unit:
		# Rings and route origins use world positions on this canvas, so redraw
		# every frame to follow unit translation, just like mouse previews.
		queue_redraw()
	else:
		var effects_active := not hit_lines.is_empty() or not order_markers.is_empty() or not world_effects.is_empty()
		if effects_active:
			_effects_redraw_timer -= delta
			if _effects_redraw_timer <= 0.0:
				queue_redraw()
				_effects_redraw_timer = 0.1
		else:
			_effects_redraw_timer = 0.0

static func _compact_timed_entries(entries: Array[Dictionary], delta: float) -> void:
	var write := 0
	for index in entries.size():
		var entry: Dictionary = entries[index]
		entry["time"] = float(entry["time"]) - delta
		if entry["time"] > 0.0:
			entries[write] = entry
			write += 1
	entries.resize(write)

func _pan_camera(delta: float) -> void:
	player_input._pan_camera(delta)

func _move_camera_screen_delta(screen_delta: Vector2) -> void:
	player_input._move_camera_screen_delta(screen_delta)

func _clamp_camera_position() -> void:
	player_input._clamp_camera_position()

func _starting_camera_position() -> Vector2:
	# Preserve the opening screen offset when the default magnification changes.
	return spawn_point_for(0) + _scaled_point(START_CAMERA_POINT - Vector2(330, 720)) / (CAMERA_ZOOM_BASE * camera_physical_scale * DEFAULT_CAMERA_VIRTUAL_SCALE)

func _toggle_view_mode(save_setting := false) -> void:
	var at_starting_camera := started and match_statistics.elapsed < 2.0 and camera.position.distance_to(_starting_camera_position()) < 2.0
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
	if fog.active: fog._update_entity_visibility()
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
	# Fog memories are display-only nodes outside the live building list.
	for memory in fog.remembered_buildings.values():
		var ghost: Node2D = memory["ghost"]
		if is_instance_valid(ghost): ghost.queue_redraw()
	for unit in units:
		if is_instance_valid(unit): unit.queue_redraw()
	for resource in resources:
		if is_instance_valid(resource): resource.queue_redraw()
	for post in trade_posts: post.queue_redraw()
	for relic in relics: relic.queue_redraw()

func should_show_health_bar(current_hp: float, maximum_hp: float, change_timer: float) -> bool:
	match health_bar_mode:
		"always": return true
		"changed": return change_timer > 0.0
		_: return current_hp < maximum_hp

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
	player_input._adjust_zoom(factor, screen_anchor)

func camera_zoom_ratio() -> float:
	return camera_virtual_scale

func _apply_camera_zoom() -> void:
	var zoom := CAMERA_ZOOM_BASE * camera_physical_scale * camera_virtual_scale
	camera.zoom = Vector2(zoom, zoom * 0.5 if view_mode_25d else zoom)

func _update_camera_physical_scale() -> void:
	# Use viewport height, not monitor DPI or width: wider windows reveal more map.
	var height_ratio := maxf(get_viewport_rect().size.y, 1.0) / CAMERA_REFERENCE_HEIGHT
	var physical_scale := lerpf(1.0, height_ratio, CAMERA_RESOLUTION_COMPENSATION)
	if is_equal_approx(physical_scale, camera_physical_scale): return
	camera_physical_scale = physical_scale
	_apply_camera_zoom()
	# Keep the world point at the screen center, except when constrained by map edges.
	if started: _clamp_camera_position()
	camera.force_update_scroll()
	# A uniform zoom preserves projection geometry; reuse terrain and fog meshes.
	queue_redraw()

func _edge_pan_direction(screen_point: Vector2, viewport_size: Vector2) -> Vector2:
	return player_input._edge_pan_direction(screen_point, viewport_size)

func _uses_native_selection_pointer() -> bool:
	return platform_pointer._uses_native_selection_pointer()

func _gameplay_mouse_mode():
	return platform_pointer._gameplay_mouse_mode()

func _apply_gameplay_mouse_mode() -> void:
	platform_pointer._apply_gameplay_mouse_mode()

func _selection_pointer_screen_position() -> Vector2:
	return platform_pointer._selection_pointer_screen_position()

func _selection_native_left_down() -> bool:
	return platform_pointer._selection_native_left_down()

func _reset_selection_pointer() -> void:
	player_input._reset_selection_pointer()

func _selection_point_over_hud(screen_point: Vector2) -> bool:
	return player_input._selection_point_over_hud(screen_point)

func _poll_selection_pointer() -> void:
	player_input._poll_selection_pointer()

func _advance_selection_pointer(screen_point: Vector2, left_down: bool) -> void:
	player_input._advance_selection_pointer(screen_point, left_down)

func _consume_placement_left_press() -> void:
	player_input._consume_placement_left_press()

func _begin_selection_candidate(screen_point: Vector2) -> void:
	player_input._begin_selection_candidate(screen_point)

func _selection_drag_active() -> bool:
	return player_input._selection_drag_active()

func _selection_drag_visible() -> bool:
	return player_input._selection_drag_visible()

func _begin_selection_drag(screen_point: Vector2) -> void:
	player_input._begin_selection_drag(screen_point)

func _update_selection_drag(screen_point: Vector2) -> void:
	player_input._update_selection_drag(screen_point)

func _finish_selection_drag() -> void:
	player_input._finish_selection_drag()

func _complete_selection_drag(screen_point: Vector2, additive: bool) -> void:
	player_input._complete_selection_drag(screen_point, additive)

func _cancel_selection_drag(block_until_release := false) -> void:
	player_input._cancel_selection_drag(block_until_release)

func _update_cursor(delta := 0.0) -> void:
	player_input._update_cursor(delta)

func _cursor_state_at(world_point: Vector2, over_ui := false) -> String:
	return player_input._cursor_state_at(world_point, over_ui)

func _player_center(owner_id: int) -> RtsBuilding:
	for building in buildings:
		if is_instance_valid(building) and building.owner_id == owner_id and building.kind == "town_center": return building
	return null

func _input(event: InputEvent) -> void:
	player_input._input(event)

func _finish_left_drag(event: InputEventMouseButton) -> bool:
	return player_input._finish_left_drag(event)

func _unhandled_input(event: InputEvent) -> void:
	player_input._unhandled_input(event)

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
	player_input._confirm_build(point, append_order)

func _wall_positions(from: Vector2, to: Vector2, kind := "palisade_wall") -> Array[Vector2]:
	return player_input._wall_positions(from, to, kind)

func _confirm_wall_line(from: Vector2, to: Vector2, append_order := false) -> void:
	player_input._confirm_wall_line(from, to, append_order)

func _update_hud() -> void:
	if hud_ui != null: hud_ui._update_hud()

func _prune_hidden_enemy_selection() -> void:
	PlayerSelection.prune_hidden_enemy_selection(self)

func _update_selection_hud() -> void:
	hud_ui._update_selection_hud()

func idle_villagers() -> Array[RtsUnit]:
	var result: Array[RtsUnit] = []
	for unit in units:
		if is_instance_valid(unit) and not unit.is_queued_for_deletion() and unit.owner_id == 0 and unit.kind == "villager" and unit.garrisoned_in == null and unit.order == "idle" and unit.command_queue.is_empty():
			result.append(unit)
	return result

# The HUD reads this every refresh; counting avoids the array allocation.
func idle_villager_count() -> int:
	var count := 0
	for unit in units:
		if is_instance_valid(unit) and not unit.is_queued_for_deletion() and unit.owner_id == 0 and unit.kind == "villager" and unit.garrisoned_in == null and unit.order == "idle" and unit.command_queue.is_empty():
			count += 1
	return count

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
	PlayerSelection.select_next_idle_villager(self)

func _toggle_global_queue() -> void:
	hud_ui._toggle_global_queue()

func _refresh_global_queue_panel() -> void:
	hud_ui._refresh_global_queue_panel()

func _refresh_action_buttons() -> void:
	if hud_ui != null: hud_ui._refresh_action_buttons()

func _rebuild_actions() -> void:
	player_actions.rebuild()

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

# Both HUD clicks and keyboard shortcuts execute registered gameplay actions.
func execute_player_action(action_id: String) -> bool:
	return player_actions.execute(action_id)

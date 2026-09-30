class_name RtsGameHudUi
extends CanvasLayer
const UnitStatText = preload("res://scripts/ui/unit_stat_text.gd")
const SelectionPortrait = preload("res://scripts/ui/selection_portrait.gd")
const SelectionDragOverlay = preload("res://scripts/ui/selection_drag_overlay.gd")
const UiStyle = preload("res://scripts/ui/ui_style.gd")
const IconCache = preload("res://scripts/ui/icon_cache.gd")
const RtsUiTypography = preload("res://scripts/ui/typography.gd")

signal view_mode_requested
signal idle_villager_requested

# Owns the HUD tree and renders command state from the game root.
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
const HUD_BOTTOM_HEIGHT := 241.0
var game: Node2D
var top_label: Label
var fps_label: Label
var fps_update_timer := 0.0
var resource_readouts: Dictionary = {}
var population_label: Label
var hud_top: PanelContainer
var hud_bottom: PanelContainer
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
var ui_root: Control
var ui_scale_update_pending := false
var age_choice_overlay: ColorRect
var cursor: GameCursor
var selection_drag_overlay: Variant
var top_column: VBoxContainer
var top_row: HBoxContainer
var top_tools: HBoxContainer
var command_side_buttons: Array[Button] = []
var current_build_pages: Array = []
var minimap_anchor: Control
var minimap_panel: PanelContainer
var minimap_panel_style_2d: StyleBoxFlat
var minimap_panel_style_25d: StyleBoxFlat
var minimap_slot: Control
var multi_selection_scroll: ScrollContainer
var multi_selection_grid: GridContainer
var multi_selection_ids: Array[int] = []
var selection_panel: PanelContainer
var selection_column: VBoxContainer
var selection_header: HBoxContainer
var command_panel: PanelContainer
var queue_scroll: ScrollContainer
var displayed_queue_jobs: Array[String] = []
var selection_summary: Label
var selection_details_button: Button
var selection_details_scroll: ScrollContainer
var selection_details_expanded := false
var command_page := 0
var command_selection_id := 0

func _init(game_ref: Node2D) -> void:
	game = game_ref

func _create_hud() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	root.size = game.get_viewport_rect().size
	# Rasterize glyphs at the final UI scale instead of enlarging their bitmaps.
	root.oversampling_with_scale = CanvasItem.OVERSAMPLING_WITH_SCALE_ENABLED
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	ui_root = root
	game.menu_ui.create_backdrop(root)
	var top := PanelContainer.new()
	hud_top = top
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 54
	top.add_theme_stylebox_override("panel", UiStyle._hud_panel_style(Color("251e17"), 8))
	root.add_child(top)
	top.minimum_size_changed.connect(func() -> void: call_deferred("_fit_top_hud"))
	top.resized.connect(_layout_top_overlays)
	top_column = VBoxContainer.new()
	top_column.add_theme_constant_override("separation", 4)
	top.add_child(top_column)
	top_row = HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 5)
	top_column.add_child(top_row)
	top_label = Label.new()
	top_label.custom_minimum_size.x = 230
	top_label.add_theme_font_size_override("font_size", RtsUiTypography.BODY)
	top_label.add_theme_color_override("font_color", Color("f4dfaa"))
	top_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top_row.add_child(top_label)
	for kind in ["food", "wood", "gold", "stone"]:
		_add_resource_readout(top_row, kind)
	var population_chip := PanelContainer.new()
	population_chip.add_theme_stylebox_override("panel", UiStyle._hud_panel_style(Color("352b1e"), 5))
	top_row.add_child(population_chip)
	var population_row := HBoxContainer.new()
	population_row.add_theme_constant_override("separation", 4)
	population_chip.add_child(population_row)
	var population_icon := TextureRect.new()
	population_icon.texture = IconCache.texture_at("res://assets/ui/resource_icons/population.png")
	population_icon.custom_minimum_size = Vector2(30, 28)
	population_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	population_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	population_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	population_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	population_row.add_child(population_icon)
	population_label = Label.new()
	population_label.custom_minimum_size.x = 64
	population_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	population_label.add_theme_font_size_override("font_size", RtsUiTypography.BODY)
	population_label.add_theme_color_override("font_color", Color("eee2c7"))
	population_row.add_child(population_label)
	top_tools = HBoxContainer.new()
	top_tools.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_tools.alignment = BoxContainer.ALIGNMENT_END
	top_tools.add_theme_constant_override("separation", 5)
	top_row.add_child(top_tools)
	var global_queue_button := Button.new()
	global_queue_button.text = "队列 [F]"
	UiStyle._style_button(global_queue_button)
	global_queue_button.pressed.connect(_toggle_global_queue)
	top_tools.add_child(global_queue_button)
	idle_villager_button = Button.new()
	idle_villager_button.text = "村民 0"
	UiStyle._style_button(idle_villager_button)
	idle_villager_button.tooltip_text = "选中下一个空闲村民（句号键）"
	idle_villager_button.pressed.connect(func() -> void: idle_villager_requested.emit())
	top_tools.add_child(idle_villager_button)
	view_button = Button.new()
	view_button.text = "2.5D 视角"
	UiStyle._style_button(view_button)
	view_button.pressed.connect(func() -> void: view_mode_requested.emit())
	top_tools.add_child(view_button)
	global_queue_panel = PanelContainer.new()
	global_queue_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	global_queue_panel.offset_left = -390
	global_queue_panel.offset_right = -8
	global_queue_panel.offset_top = 58
	global_queue_panel.offset_bottom = 415
	global_queue_panel.add_theme_stylebox_override("panel", UiStyle._hud_panel_style(Color("2c241b"), 12))
	root.add_child(global_queue_panel)
	fps_label = Label.new()
	fps_label.text = "FPS: --"
	fps_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	fps_label.offset_left = -100
	fps_label.offset_right = -12
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fps_label.add_theme_font_size_override("font_size", RtsUiTypography.CAPTION)
	fps_label.add_theme_color_override("font_color", Color("f4dfaa"))
	fps_label.add_theme_color_override("font_outline_color", Color("1b1814"))
	fps_label.add_theme_constant_override("outline_size", 3)
	fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fps_label.visible = game.show_fps
	root.add_child(fps_label)
	top.visibility_changed.connect(func() -> void: fps_label.visible = game.show_fps and top.visible)
	fps_label.visibility_changed.connect(_layout_top_overlays)
	call_deferred("_layout_top_overlays")
	var global_queue_scroll := ScrollContainer.new()
	global_queue_panel.add_child(global_queue_scroll)
	global_queue_list = VBoxContainer.new()
	global_queue_list.custom_minimum_size.x = 350
	global_queue_scroll.add_child(global_queue_list)
	global_queue_panel.hide()
	var bottom := PanelContainer.new()
	hud_bottom = bottom
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -HUD_BOTTOM_HEIGHT
	bottom.add_theme_stylebox_override("panel", UiStyle._hud_panel_style(Color("241d16"), 7))
	root.add_child(bottom)
	bottom.minimum_size_changed.connect(func() -> void: call_deferred("_fit_bottom_hud"))
	var dock := HBoxContainer.new()
	dock.add_theme_constant_override("separation", 9)
	bottom.add_child(dock)
	command_panel = PanelContainer.new()
	command_panel.custom_minimum_size.x = 308
	command_panel.add_theme_stylebox_override("panel", UiStyle._hud_panel_style(Color("30261b"), 7))
	dock.add_child(command_panel)
	var command_column := VBoxContainer.new()
	command_column.add_theme_constant_override("separation", 5)
	command_panel.add_child(command_column)
	command_title = Label.new()
	command_title.clip_text = true
	command_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	command_title.add_theme_font_size_override("font_size", RtsUiTypography.SUBSECTION_TITLE)
	command_title.add_theme_color_override("font_color", Color("e8cb85"))
	command_title.hide()
	command_column.add_child(command_title)
	var action_scroll := ScrollContainer.new()
	action_scroll.custom_minimum_size = Vector2(294, 170)
	action_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	action_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	action_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	command_column.add_child(action_scroll)
	action_bar = GridContainer.new()
	action_bar.columns = 5
	action_bar.add_theme_constant_override("h_separation", 6)
	action_bar.add_theme_constant_override("v_separation", 4)
	action_scroll.add_child(action_bar)
	selection_panel = PanelContainer.new()
	selection_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection_panel.add_theme_stylebox_override("panel", UiStyle._hud_panel_style(Color("30271c"), 8))
	dock.add_child(selection_panel)
	var selection_row := HBoxContainer.new()
	selection_row.add_theme_constant_override("separation", 10)
	selection_panel.add_child(selection_row)
	selection_portrait = SelectionPortrait.new()
	selection_portrait.custom_minimum_size = Vector2(100, 140)
	selection_row.add_child(selection_portrait)
	selection_column = VBoxContainer.new()
	selection_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection_column.add_theme_constant_override("separation", 4)
	selection_row.add_child(selection_column)
	selection_header = HBoxContainer.new()
	selection_header.add_theme_constant_override("separation", 4)
	selection_column.add_child(selection_header)
	info_label = Label.new()
	info_label.text = "未选择"
	info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_label.add_theme_font_size_override("font_size", RtsUiTypography.SECTION_TITLE)
	info_label.add_theme_color_override("font_color", Color("f0dfb6"))
	selection_header.add_child(info_label)
	selection_details_button = Button.new()
	selection_details_button.text = "详情 ▾"
	selection_details_button.tooltip_text = "展开完整属性、攻击数据和单位状态"
	selection_details_button.custom_minimum_size = Vector2(64, 26)
	UiStyle._style_button(selection_details_button)
	selection_details_button.pressed.connect(_toggle_selection_details)
	selection_header.add_child(selection_details_button)
	selection_summary = Label.new()
	selection_summary.add_theme_font_size_override("font_size", RtsUiTypography.CAPTION)
	selection_summary.add_theme_color_override("font_color", Color("d3c5a8"))
	selection_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	selection_summary.max_lines_visible = 2
	selection_summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	selection_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection_column.add_child(selection_summary)
	multi_selection_scroll = ScrollContainer.new()
	multi_selection_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	multi_selection_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	multi_selection_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	multi_selection_scroll.hide()
	selection_column.add_child(multi_selection_scroll)
	multi_selection_grid = GridContainer.new()
	multi_selection_grid.columns = 6
	multi_selection_grid.add_theme_constant_override("h_separation", 5)
	multi_selection_grid.add_theme_constant_override("v_separation", 5)
	multi_selection_scroll.add_child(multi_selection_grid)
	detail_label = Label.new()
	detail_label.text = "左键选择 · 右键下令"
	detail_label.add_theme_font_size_override("font_size", RtsUiTypography.CAPTION)
	detail_label.add_theme_color_override("font_color", Color("d3c5a8"))
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.custom_minimum_size.x = 420
	detail_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection_details_scroll = ScrollContainer.new()
	selection_details_scroll.custom_minimum_size.y = 76
	selection_details_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection_details_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	selection_details_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	selection_column.add_child(selection_details_scroll)
	selection_details_scroll.add_child(detail_label)
	selection_details_scroll.hide()
	selection_health = ProgressBar.new()
	selection_health.show_percentage = false
	selection_health.custom_minimum_size = Vector2(285, 11)
	selection_health.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiStyle._style_progress_bar(selection_health, Color("80ad68"))
	selection_health.hide()
	selection_column.add_child(selection_health)
	selection_progress = ProgressBar.new()
	selection_progress.show_percentage = false
	selection_progress.custom_minimum_size = Vector2(285, 9)
	selection_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiStyle._style_progress_bar(selection_progress, Color("d4af62"))
	selection_progress.hide()
	selection_column.add_child(selection_progress)
	queue_label = Label.new()
	queue_label.add_theme_font_size_override("font_size", RtsUiTypography.CAPTION)
	queue_label.add_theme_color_override("font_color", Color("e5d1a1"))
	selection_column.add_child(queue_label)
	queue_scroll = ScrollContainer.new()
	queue_scroll.custom_minimum_size.y = 65
	queue_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	queue_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	queue_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	queue_scroll.hide()
	selection_column.add_child(queue_scroll)
	queue_controls = HBoxContainer.new()
	queue_controls.add_theme_constant_override("separation", 4)
	queue_scroll.add_child(queue_controls)
	notice_label = Label.new()
	notice_label.add_theme_color_override("font_color", Color("f0d783"))
	notice_label.add_theme_font_size_override("font_size", RtsUiTypography.CAPTION)
	selection_column.add_child(notice_label)
	minimap_anchor = Control.new()
	minimap_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dock.add_child(minimap_anchor)
	minimap_panel = PanelContainer.new()
	minimap_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	minimap_panel_style_2d = UiStyle._hud_panel_style(Color("30261b"), 7)
	minimap_panel_style_25d = UiStyle._hud_panel_style(Color.TRANSPARENT, 7)
	minimap_panel_style_25d.border_color = Color.TRANSPARENT
	minimap_panel_style_25d.shadow_color = Color.TRANSPARENT
	minimap_panel.add_theme_stylebox_override("panel", minimap_panel_style_2d)
	minimap_anchor.add_child(minimap_panel)
	minimap_slot = Control.new()
	minimap_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap_panel.add_child(minimap_slot)
	minimap = RtsMinimap.new()
	minimap_slot.add_child(minimap)
	minimap.setup(game)
	minimap_anchor.resized.connect(_layout_minimap)
	minimap_slot.resized.connect(_layout_minimap)
	_apply_minimap_size()

	game.menu_ui.create_overlays(root)

func _apply_minimap_size() -> void:
	var panel_size: Vector2 = Vector2.ONE * (game.minimap_size + 14.0)
	minimap_anchor.custom_minimum_size = Vector2(panel_size.x, HUD_BOTTOM_HEIGHT - 14.0)
	minimap_slot.custom_minimum_size = Vector2.ONE * game.minimap_size
	minimap_panel.custom_minimum_size = panel_size
	minimap_panel.size = panel_size
	_layout_minimap()
	_fit_bottom_hud()

func _fit_bottom_hud() -> void:
	if hud_bottom == null: return
	var command_width := maxf(308.0, action_bar.get_combined_minimum_size().x + command_panel.get_theme_stylebox("panel").get_minimum_size().x)
	if not is_equal_approx(command_panel.custom_minimum_size.x, command_width):
		command_panel.custom_minimum_size.x = command_width
	var content_height: float = hud_bottom.get_combined_minimum_size().y
	var required_height := maxf(maxf(HUD_BOTTOM_HEIGHT, content_height), _production_hud_floor())
	if not is_equal_approx(hud_bottom.offset_top, -required_height):
		hud_bottom.offset_top = -required_height

func _production_hud_floor() -> float:
	if selection_header == null or queue_scroll == null: return HUD_BOTTOM_HEIGHT
	var header_height := maxf(maxf(selection_header.get_combined_minimum_size().y, selection_details_button.get_combined_minimum_size().y), info_label.get_combined_minimum_size().y)
	var summary_font: Font = selection_summary.get_theme_font("font")
	var summary_size := selection_summary.get_theme_font_size("font_size")
	var summary_height := summary_font.get_height(summary_size)
	# At narrow widths the town center's summary wraps onto a second line.
	var town_center_summary := "生命 1050/1050   已建成   右键设置集结点"
	if selection_column.size.x > 0.0 and summary_font.get_string_size(town_center_summary, HORIZONTAL_ALIGNMENT_LEFT, -1, summary_size).x > selection_column.size.x:
		summary_height = summary_height * 2.0 + selection_summary.get_theme_constant("line_spacing")
	var column_height := header_height + summary_height
	column_height += selection_health.get_combined_minimum_size().y + selection_progress.get_combined_minimum_size().y
	column_height += queue_label.get_combined_minimum_size().y + queue_scroll.get_combined_minimum_size().y + notice_label.get_combined_minimum_size().y
	column_height += selection_column.get_theme_constant("separation") * 6
	var content_height := maxf(selection_portrait.get_combined_minimum_size().y, column_height)
	return content_height + selection_panel.get_theme_stylebox("panel").get_minimum_size().y + hud_bottom.get_theme_stylebox("panel").get_minimum_size().y

func _fit_top_hud() -> void:
	if top_row == null or top_tools == null or ui_root == null: return
	var available_width: float = ui_root.size.x - hud_top.get_theme_stylebox("panel").get_minimum_size().x
	var single_row_width: float = top_row.get_combined_minimum_size().x
	if top_tools.get_parent() != top_row:
		single_row_width += top_tools.get_combined_minimum_size().x + 5.0
	if single_row_width > available_width and top_tools.get_parent() == top_row:
		top_tools.reparent(top_column)
	elif single_row_width <= available_width and top_tools.get_parent() != top_row:
		top_tools.reparent(top_row)
	_layout_top_overlays()

func _layout_top_overlays() -> void:
	if hud_top == null or fps_label == null or global_queue_panel == null: return
	var top_bottom: float = hud_top.position.y + hud_top.size.y
	fps_label.offset_top = top_bottom + 6.0
	fps_label.offset_bottom = top_bottom + 29.0
	global_queue_panel.offset_top = top_bottom + (35.0 if game.show_fps else 4.0)
	global_queue_panel.offset_bottom = global_queue_panel.offset_top + 357.0

func _layout_minimap() -> void:
	if minimap == null or minimap_slot == null: return
	var panel_style := minimap_panel_style_25d if game.view_mode_25d else minimap_panel_style_2d
	if minimap_panel.get_theme_stylebox("panel") != panel_style:
		minimap_panel.add_theme_stylebox_override("panel", panel_style)
	minimap_panel.position = Vector2(0, minimap_anchor.size.y - minimap_panel.size.y)
	# Both projections fit in the same frame; changing view never covers the battlefield.
	minimap.size = Vector2.ONE * game.minimap_size
	minimap.position = minimap_slot.size - minimap.size
	minimap.queue_redraw()

func _update_hud() -> void:
	if top_label == null or game.players.is_empty(): return
	game._prune_hidden_enemy_selection()
	if global_queue_panel.visible: _refresh_global_queue_panel()
	_update_population_hud()
	_refresh_action_buttons()
	_update_selection_hud()

func _update_population_hud() -> void:
	var bank: Dictionary = game.players[0]
	var dynasty_text := " · %s朝" % RtsLandmarkCatalog.DYNASTY_NAMES[bank["dynasty"]] if bank["dynasty"] != "" else ""
	var used: int = game.population_used(0)
	var capacity: int = game.population_cap(0)
	var age_names := ["", "黑暗时代", "封建时代", "城堡时代", "帝王时代"]
	top_label.text = "%s · %s %s%s" % [GameData.CIVILIZATIONS[game.civilizations[0]]["label"], age_names[clampi(bank["age"], 1, 4)], ["", "I", "II", "III", "IV"][clampi(bank["age"], 1, 4)], dynasty_text]
	for kind in ["food", "wood", "gold", "stone"]:
		resource_readouts[kind].text = str(bank[kind])
	population_label.text = "%d/%d" % [used, capacity]
	population_label.tooltip_text = "空余 %d" % maxi(0, capacity - used)
	var idle_count: int = game.idle_villagers().size()
	idle_villager_button.text = "村民 %d" % idle_count
	idle_villager_button.disabled = idle_count == 0
	call_deferred("_fit_top_hud")

func _update_selection_hud() -> void:
	var subject: Node2D
	if game.selected.size() == 1 and is_instance_valid(game.selected[0]): subject = game.selected[0]
	selection_health.visible = subject != null and not subject is RtsResource
	var has_progress := subject is RtsResource
	var selected_building: RtsBuilding = subject if subject is RtsBuilding else null
	var has_production_actions := selected_building != null and selected_building.owner_id == 0 and _has_production_actions(selected_building)
	if subject is RtsUnit:
		var unit: RtsUnit = subject
		has_progress = unit.field_build_remaining > 0.0
	elif subject is RtsBuilding:
		var building: RtsBuilding = subject
		has_progress = not building.is_complete() or building.kind == "farm" or has_production_actions or not building.production_queue.is_empty()
	selection_progress.visible = has_progress
	queue_label.text = ""
	queue_scroll.visible = selected_building != null and selected_building.owner_id == 0 and (has_production_actions or not selected_building.production_queue.is_empty())
	selection_portrait.show()
	multi_selection_scroll.hide()
	if game.selected.is_empty() or not is_instance_valid(game.selected[0]):
		_clear_multi_selection_icons()
		selection_portrait.show_subject(null)
		info_label.text = "未选择"
		detail_label.text = "左键选择 · 双击同型单位 · 右键下令 · Esc 暂停"
		_refresh_selection_summary()
		return
	var item: Node2D = game.selected[0]
	if game.selected.size() > 1:
		selection_portrait.hide()
		selection_summary.hide()
		selection_details_scroll.hide()
		selection_details_button.hide()
		info_label.text = "已选中 %d 个单位 · 点击图标单独选中" % game.selected.size()
		_refresh_multi_selection_icons()
		multi_selection_scroll.show()
		return
	_clear_multi_selection_icons()
	selection_portrait.show_subject(item, Color("b6a877") if item is RtsResource else game.player_color(item.owner_id))
	if item is RtsResource:
		info_label.text = _resource_label(item)
		detail_label.text = "资源类型  %s\n采集单位  %s\n当前状态  %s" % [GameData.RESOURCE_LABELS.get(item.kind, item.kind), "渔船" if item.appearance == "fish" else "村民", _resource_status(item)]
		selection_progress.max_value = maxi(1, item.initial_amount)
		selection_progress.value = item.amount
		selection_progress.show()
		queue_label.text = "剩余 %d / %d" % [item.amount, item.initial_amount]
		_refresh_selection_summary()
		return
	var name: String = GameData.UNITS[item.kind]["label"] if item is RtsUnit else item.display_label()
	info_label.text = "敌方 · %s" % name if game.is_enemy(0, item.owner_id) else name
	selection_health.max_value = item.max_hp
	selection_health.value = maxf(0.0, item.hp)
	selection_health.show()
	if item is RtsUnit:
		detail_label.text = _unit_stats_text(item)
		if item.field_build_remaining > 0.0:
			selection_progress.max_value = item.field_build_total
			selection_progress.value = item.field_build_total - item.field_build_remaining
			selection_progress.show()
			queue_label.text = "野外建造 %d%%" % roundi(100.0 * selection_progress.value / selection_progress.max_value)
		if item.kind in ["transport_ship", "battering_ram", "siege_tower"]: detail_label.text += "   乘员 %d/%d" % [item.passengers.size(), 10 if item.kind == "siege_tower" else 8]
		if item.kind == "trader": detail_label.text += "   右键贸易站往返交易"
		if item.kind == "monk": detail_label.text += "   携带圣物" if item.carried_relic != null else "   可占圣地、拾取圣物"
		if item.kind == "fishing_boat": detail_label.text += "   右键鱼群捕鱼"
	else:
		detail_label.text = "生命 %.0f/%.0f   %s" % [item.hp, item.max_hp, "建造中" if not item.is_complete() else "已建成"]
		if item.kind == "farm" and item.is_complete(): detail_label.text += "\n播种 %.1f 工作量 · 收获 %.1f 工作量" % [RtsBuilding.FARM_SOW_WORK, RtsBuilding.FARM_HARVEST_WORK]
		if item.kind == "monastery": detail_label.text += "   圣物 %d（每 4 秒每件 +12 黄金）" % item.relics.size()
		if not item.garrisoned_units.is_empty(): detail_label.text += "   驻军 %d/%d" % [item.garrisoned_units.size(), item.garrison_capacity()]
		if item.can_set_rally(0):
			detail_label.text += "   右键设置集结点"
		_update_building_progress(item)
		_refresh_queue_controls(item)
	_refresh_selection_summary()

func _toggle_selection_details() -> void:
	selection_details_expanded = not selection_details_expanded
	selection_details_button.text = "收起 ▴" if selection_details_expanded else "详情 ▾"
	_refresh_selection_summary()

func _refresh_selection_summary() -> void:
	selection_details_scroll.visible = selection_details_expanded
	selection_summary.visible = not selection_details_expanded
	selection_details_button.visible = not game.selected.is_empty()
	var lines: PackedStringArray = detail_label.text.split("\n")
	selection_summary.text = "\n".join(lines.slice(0, mini(2, lines.size())))

func _clear_multi_selection_icons() -> void:
	if multi_selection_ids.is_empty(): return
	multi_selection_ids.clear()
	for child in multi_selection_grid.get_children():
		multi_selection_grid.remove_child(child)
		child.queue_free()

func _refresh_multi_selection_icons() -> void:
	var ids: Array[int] = []
	for item in game.selected: ids.append(item.get_instance_id())
	if ids != multi_selection_ids:
		_clear_multi_selection_icons()
		multi_selection_ids = ids
		for index in game.selected.size():
			var item: Node2D = game.selected[index]
			var button := RtsCommandButton.new()
			button.configure(item.kind, "", "")
			button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			button.pressed.connect(_select_from_multi_selection.bind(item))
			multi_selection_grid.add_child(button)
	for index in game.selected.size():
		var item: Node2D = game.selected[index]
		var label_text: String = GameData.UNITS[item.kind]["label"] if item is RtsUnit else item.display_label()
		var button: RtsCommandButton = multi_selection_grid.get_child(index)
		button.tooltip_text = "%s %d · 生命 %.0f/%.0f\n点击单独选中" % [label_text, index + 1, item.hp, item.max_hp]

func _select_from_multi_selection(item: Node2D) -> void:
	if not is_instance_valid(item) or item.is_queued_for_deletion() or not game.selected.has(item): return
	game.selected.clear()
	game.selected.append(item)
	_rebuild_actions()
	_update_hud()
	game.play_feedback("select")
	game.queue_redraw()

func _resource_label(resource: RtsResource) -> String:
	return {"berry": "浆果", "deer": "鹿", "sheep": "绵羊", "boar": "野猪", "fish": "鱼群"}.get(resource.appearance, {"wood": "树木", "gold": "金矿", "stone": "石矿"}.get(resource.kind, GameData.RESOURCE_LABELS.get(resource.kind, resource.kind)))

func _resource_status(resource: RtsResource) -> String:
	if resource.appearance == "boar" and resource.wildlife_hp > 0.0: return "野猪存活 · 生命 %.0f/90" % resource.wildlife_hp
	if resource.appearance == "deer" and resource.wildlife_hp > 0.0: return "鹿存活 · 生命 %.0f/12" % resource.wildlife_hp
	if resource.appearance == "sheep":
		if resource.claimed_by < 0: return "尚未认领"
		return "我方已认领" if resource.claimed_by == 0 else "敌方已认领"
	return "可采集"

func _resource_guide(resource: RtsResource) -> String:
	match resource.appearance:
		"boar": return "先选中可攻击的单位，右键攻击野猪。击杀后选中村民，右键采集。"
		"sheep": return "选中村民，右键点击羊群采集；侦察兵可认领羊群并带回城镇中心。"
		"fish": return "选中渔船，右键点击鱼群捕鱼。"
		"deer": return "选中村民，右键点击鹿群；村民会先猎杀鹿，再采集鹿肉。"
	return "选中村民，右键点击%s采集%s。" % [_resource_label(resource), GameData.RESOURCE_LABELS.get(resource.kind, resource.kind)]

func _update_building_progress(building: RtsBuilding) -> void:
	if not building.is_complete():
		selection_progress.max_value = maxf(0.1, building.build_total)
		selection_progress.value = building.build_total - building.build_remaining
		selection_progress.show()
		queue_label.text = "施工 %d%% · 村民 %d · 选村民右键继续" % [int(100.0 * selection_progress.value / selection_progress.max_value), game.count_builders(building)]
	elif building.kind == "farm":
		selection_progress.max_value = building.farm_stage_work()
		selection_progress.value = building.farm_stage_progress
		selection_progress.show()
		var farmer: RtsUnit = game.farm_worker(building)
		var stage_label := "播种" if building.farm_stage == "sowing" else "收获"
		var remaining := (building.farm_stage_work() - building.farm_stage_progress) / farmer.farm_work_speed() if farmer != null else 0.0
		queue_label.text = "%s %d%% · 速度 %.2f 工作量/秒 · 剩余 %.1f 秒" % [stage_label, roundi(100.0 * building.farm_stage_progress / building.farm_stage_work()), farmer.farm_work_speed(), remaining] if farmer != null else "%s %d%% · 暂停，派村民耕作" % [stage_label, roundi(100.0 * building.farm_stage_progress / building.farm_stage_work())]
	elif not building.production_queue.is_empty():
		var job: Dictionary = building.current_job()
		selection_progress.max_value = job["time"]
		selection_progress.value = job["time"] - job["remaining"]
		selection_progress.show()
	elif _has_production_actions(building):
		selection_progress.max_value = 1.0
		selection_progress.value = 0.0
		selection_progress.show()

func _has_production_actions(building: RtsBuilding) -> bool:
	if building.owner_id != 0: return false
	var producer := building.producer_kind()
	return not RtsTechTree.all_train_units(game.civilizations[0], producer).is_empty() or not RtsTechTree.all_researches(game.civilizations[0], producer).is_empty()

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
	if unit.kind == "scout" and game.civilizations[unit.owner_id] == "Chinese" and game.players[unit.owner_id].get("dynasty", "") == "Tang": lines.append("唐朝斥候：视野 +70")
	if is_instance_valid(unit.wall_host): lines.append("正在石墙上驻守  ·  远程护甲 +2")
	var profiles := UnitStatText.active_profiles(stats)
	for profile_id in profiles:
		var profile: Dictionary = profiles[profile_id]
		var description := UnitStatText.attack_text(profile_id, profile, true)
		for bonus in profile.get("bonuses", []): description += "  ·  " + UnitStatText.bonus_text(bonus, true)
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
			var work_text := "采集%s  ·  工作速度 %.2f/秒" % [source_label, unit.gathering_per_second()]
			if unit.target is RtsBuilding and unit.target.kind == "farm":
				work_text += "  ·  %s %d%%  ·  耕作 %.2f 工作量/秒" % ["播种" if unit.target.farm_stage == "sowing" else "收获", roundi(100.0 * unit.target.farm_stage_progress / unit.target.farm_stage_work()), unit.farm_work_speed()]
			lines.insert(0, work_text)
		else:
			lines.insert(0, "未采集资源  ·  工作速度 0.00/秒")
	if unit.kind == "trader" and game.civilizations[unit.owner_id] == "French": lines.append("贸易运回：%s" % GameData.RESOURCE_LABELS[unit.trade_resource_kind])
	return "\n".join(lines)

func _job_label(job: Dictionary) -> String:
	match job["type"]:
		"train": return "训练：%s" % GameData.UNITS[job["kind"]]["label"]
		"research": return "研究：%s" % RtsTechTree.get_technology(job["kind"])["label"]
	return "未知任务"

func _refresh_queue_controls(building: RtsBuilding) -> void:
	if building.owner_id != 0 or not _has_production_actions(building) and building.production_queue.is_empty(): return
	var jobs: Array[String] = [str(building.get_instance_id())]
	for index in building.production_queue.size():
		var job: Dictionary = building.production_queue[index]
		jobs.append("%s:%s" % [job["type"], job["kind"]])
	if jobs == displayed_queue_jobs: return
	var previous_scroll := queue_scroll.scroll_horizontal if not displayed_queue_jobs.is_empty() and displayed_queue_jobs[0] == jobs[0] else 0
	displayed_queue_jobs = jobs
	for child in queue_controls.get_children():
		queue_controls.remove_child(child)
		child.queue_free()
	if building.production_queue.is_empty():
		var empty := Label.new()
		empty.text = "生产队列空"
		empty.add_theme_font_size_override("font_size", RtsUiTypography.CAPTION)
		empty.add_theme_color_override("font_color", Color("a99b7e"))
		queue_controls.add_child(empty)
	for index in building.production_queue.size():
		queue_controls.add_child(_queue_job_button(building, index, building.production_queue[index]))
	queue_scroll.scroll_horizontal = previous_scroll

func _queue_job_button(building: RtsBuilding, index: int, job: Dictionary) -> Button:
	var button := RtsCommandButton.new()
	button.configure(str(job["kind"]), "", "")
	button.tooltip_text = "%s\n点击取消并返还 %s" % [_job_label(job), GameData.cost_text(job["cost"])]
	var overlay := ColorRect.new()
	overlay.color = Color(0.13, 0.08, 0.04, 0.8)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var cross := Label.new()
	cross.text = "×"
	cross.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cross.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cross.add_theme_font_size_override("font_size", 30)
	cross.add_theme_color_override("font_color", Color("fff2d2"))
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(cross)
	cross.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.hide()
	button.mouse_entered.connect(func() -> void: overlay.show())
	button.mouse_exited.connect(func() -> void: overlay.hide())
	button.pressed.connect(func() -> void:
		if is_instance_valid(building): game.cancel_production_job(building, index)
	)
	return button

func _toggle_global_queue() -> void:
	global_queue_panel.visible = not global_queue_panel.visible
	if global_queue_panel.visible: _refresh_global_queue_panel()

func _refresh_global_queue_panel() -> void:
	for child in global_queue_list.get_children(): child.queue_free()
	var heading := Label.new()
	heading.text = "全局生产队列 · 点击定位建筑"
	global_queue_list.add_child(heading)
	var count := 0
	for building in game.buildings:
		if not is_instance_valid(building) or building.owner_id != 0 or building.production_queue.is_empty(): continue
		for index in building.production_queue.size():
			var job: Dictionary = building.production_queue[index]
			var row := HBoxContainer.new()
			global_queue_list.add_child(row)
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
		global_queue_list.add_child(empty)

func _refresh_action_buttons() -> void:
	if game.players.is_empty() or command_buttons.is_empty(): return
	var producer: RtsBuilding
	if not game.selected.is_empty() and is_instance_valid(game.selected[0]) and game.selected[0] is RtsBuilding:
		producer = game.selected[0]
	var context := RtsActionAvailability.context_for(game, 0, producer)
	for button in command_buttons:
		if not is_instance_valid(button) or button.is_queued_for_deletion(): continue
		var action_type: String = button.get_meta("action_type")
		var action_kind: String = button.get_meta("action_kind")
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
		button.set_availability(status["available"], status["reason"], status["cost"])

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

func _rebuild_actions() -> void:
	if action_bar == null: return
	for child in action_bar.get_children():
		action_bar.remove_child(child)
		child.queue_free()
	command_buttons.clear()
	hotkey_buttons.clear()
	command_title.hide()
	command_side_buttons.clear()
	current_build_pages.clear()
	if game.selected.is_empty() or not is_instance_valid(game.selected[0]):
		command_page = 0
		command_selection_id = 0
		return
	var item: Node2D = game.selected[0]
	var selection_id := item.get_instance_id()
	if selection_id != command_selection_id:
		command_page = 0
		command_selection_id = selection_id
	action_bar.columns = 5
	if item is RtsResource:
		command_title.text = "采集方式"
		command_title.show()
		action_bar.columns = 1
		var guide := Label.new()
		guide.text = _resource_guide(item)
		guide.custom_minimum_size.x = 270
		guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		guide.add_theme_font_size_override("font_size", RtsUiTypography.BODY)
		guide.add_theme_color_override("font_color", Color("e9dbbd"))
		action_bar.add_child(guide)
		return
	if item.owner_id != 0:
		command_title.text = "敌方建筑 · 情报" if item is RtsBuilding else "敌方单位 · 情报"
		command_title.show()
		return
	if item is RtsUnit: _build_unit_actions(item)
	elif item is RtsBuilding: _build_building_actions(item)
	_refresh_action_buttons()
	_layout_command_grid()

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
		current_build_pages = pages
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

# Keep twelve action slots in their original order, with a fixed control column.
func _layout_command_grid() -> void:
	var actions: Array[Node] = action_bar.get_children()
	var stop: Control
	for button in command_buttons:
		if button.icon_kind == "stop":
			stop = button
			actions.erase(button)
			break
	var is_build_page := not current_build_pages.is_empty()
	var page_count := current_build_pages.size() if is_build_page else maxi(1, ceili(float(actions.size()) / COMMANDS_PER_PAGE))
	command_page = clampi(command_page, 0, page_count - 1)
	var page_index: int = game.build_page if is_build_page else command_page
	var first := 0 if is_build_page else command_page * COMMANDS_PER_PAGE
	var visible_actions: Array[Control] = []
	for index in actions.size():
		actions[index].visible = index >= first and index < first + COMMANDS_PER_PAGE
		if actions[index].visible: visible_actions.append(actions[index])
	while visible_actions.size() < COMMANDS_PER_PAGE:
		_add_action_spacer()
		visible_actions.append(action_bar.get_child(action_bar.get_child_count() - 1))
	for direction in [-1, 1]:
		var next_index := posmod(page_index + direction, page_count)
		var tip := "上一页" if direction == -1 else "下一页"
		if is_build_page:
			tip += "：%s → %s" % [current_build_pages[page_index]["title"], current_build_pages[next_index]["title"]]
		else:
			tip += "（%d/%d）" % [page_index + 1, page_count]
		var arrow := _add_side_button("←" if direction == -1 else "→", tip, func() -> void:
			if is_build_page: game.build_page = next_index
			else: command_page = next_index
			_rebuild_actions()
		)
		arrow.disabled = page_count <= 1
	if stop == null and game.selected[0] is RtsUnit:
		stop = _add_side_button("■", "停止选中单位当前的命令", func() -> void: game._stop_selected_units())
	elif stop != null:
		stop.show()
		command_side_buttons.append(stop)
	else:
		_add_action_spacer()
		stop = action_bar.get_child(action_bar.get_child_count() - 1)
	var side_controls: Array[Control] = [command_side_buttons[0], command_side_buttons[1], stop]
	for row in 3:
		for column in 4:
			action_bar.move_child(visible_actions[row * 4 + column], row * 5 + column)
		action_bar.move_child(side_controls[row], row * 5 + 4)

func _add_side_button(symbol: String, description: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = symbol
	button.tooltip_text = description
	button.custom_minimum_size = Vector2(54, 54)
	button.focus_mode = Control.FOCUS_NONE
	UiStyle._style_button(button)
	button.pressed.connect(callback)
	action_bar.add_child(button)
	command_side_buttons.append(button)
	return button

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
	if not game.started or game.game_over or age_choice_overlay != null: return
	var current_age: int = game.players[0]["age"]
	if not RtsTechTree.can_advance(current_age): return
	var choices: Array[Dictionary] = []
	for choice in RtsLandmarkCatalog.choices_for(game.civilizations[0], current_age, game.players[0]["landmarks"]):
		if int(choice["age"]) == current_age + 1: choices.append(choice)
	if choices.is_empty(): return
	var target_age := current_age + 1
	age_choice_overlay = ColorRect.new()
	age_choice_overlay.color = Color("100f0d", 0.87)
	age_choice_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	age_choice_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	hud_bottom.get_parent().add_child(age_choice_overlay)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -310
	panel.offset_right = 310
	panel.offset_top = -190
	panel.offset_bottom = 190
	panel.add_theme_stylebox_override("panel", UiStyle._hud_panel_style(Color("30271c"), 18))
	age_choice_overlay.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var heading := Label.new()
	heading.text = "选择进入 %s 时代的地标" % ["", "I", "II", "III", "IV"][target_age]
	heading.add_theme_font_size_override("font_size", RtsUiTypography.SECTION_TITLE)
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
		UiStyle._style_button(button)
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
		icon.texture = IconCache.texture_at("res://assets/ui/command_icons/%s.png" % chosen_id)
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
		name_label.add_theme_font_size_override("font_size", RtsUiTypography.BODY)
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
	UiStyle._style_button(cancel)
	cancel.pressed.connect(_close_age_choice)
	column.add_child(cancel)

func _close_age_choice() -> void:
	if age_choice_overlay == null: return
	age_choice_overlay.queue_free()
	age_choice_overlay = null

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
	action_bar.add_child(spacer)

func _add_action(icon_kind: String, label_text: String, cost: Dictionary, keycode: int, action_type: String, callback: Callable) -> void:
	var button := RtsCommandButton.new()
	var key_text := OS.get_keycode_string(keycode) if keycode != KEY_NONE else ""
	button.configure(icon_kind, label_text, key_text)
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
	action_bar.add_child(button)
	command_buttons.append(button)
	if keycode != KEY_NONE: hotkey_buttons[keycode] = button

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

func _add_resource_readout(parent: HBoxContainer, kind: String) -> void:
	var chip := PanelContainer.new()
	chip.custom_minimum_size.x = 92
	chip.add_theme_stylebox_override("panel", UiStyle._hud_panel_style(Color("352b1e"), 5))
	parent.add_child(chip)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	chip.add_child(row)
	var icon := TextureRect.new()
	icon.texture = IconCache.texture_at("res://assets/ui/resource_icons/%s.png" % kind)
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


func _create_cursor() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	game.add_child(layer)
	selection_drag_overlay = SelectionDragOverlay.new()
	layer.add_child(selection_drag_overlay)
	cursor = GameCursor.new()
	cursor.text_scale = game.text_scale
	layer.add_child(cursor)
	cursor.hide()


func _on_ui_node_added(node: Node) -> void:
	if ui_root == null or not (node is Control or node is PopupMenu) or not ui_root.is_ancestor_of(node) or ui_scale_update_pending: return
	ui_scale_update_pending = true
	call_deferred("_apply_ui_scales")


func _apply_ui_scales() -> void:
	ui_scale_update_pending = false
	if ui_root == null or not is_instance_valid(ui_root): return
	var viewport_size := game.get_viewport_rect().size
	var max_scale := minf(viewport_size.x / game.MIN_UI_VIEWPORT_SIZE.x, viewport_size.y / game.MIN_UI_VIEWPORT_SIZE.y)
	var effective_scale := maxf(0.5, minf(game.ui_scale, max_scale))
	# CanvasItem font oversampling sees Control transforms, but not CanvasLayer transforms.
	ui_root.scale = Vector2.ONE * effective_scale
	ui_root.size = viewport_size / effective_scale
	RtsUiTypography.apply_tree(ui_root, game.text_scale, effective_scale, game.base_tooltip_font_size)
	call_deferred("_fit_top_hud")
	call_deferred("_fit_bottom_hud")
	if cursor != null:
		cursor.text_scale = game.text_scale
		cursor.queue_redraw()
	if not is_equal_approx(game.applied_world_text_scale, game.text_scale):
		game.applied_world_text_scale = game.text_scale
		game._redraw_projected_entities()
		if game.objectives != null: game.objectives.queue_redraw()
		game.queue_redraw()


func tick_fps(delta: float) -> void:
	if not game.show_fps or fps_label == null: return
	fps_update_timer -= delta
	if fps_update_timer <= 0.0:
		fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
		fps_update_timer = 0.5

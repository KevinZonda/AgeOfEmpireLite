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
signal match_view_refreshed

# Owns the HUD tree and renders command state from the game root.
# Arrow glyphs are drawn at a fixed size so text scaling cannot resize the slots.
class CommandPageButton extends Button:
	var direction := 1
	func _draw() -> void:
		var center := size * 0.5
		var color := get_theme_color("font_hover_color" if is_hovered() else "font_color")
		draw_line(center - Vector2(14, 0), center + Vector2(14, 0), color, 2.5, true)
		var tip := center + Vector2(14 * direction, 0)
		draw_line(tip, tip + Vector2(-10 * direction, -10), color, 2.5, true)
		draw_line(tip, tip + Vector2(-10 * direction, 10), color, 2.5, true)

const COMMAND_TILE_SIZE := Vector2(68, 68)
const HUD_BOTTOM_HEIGHT := 241.0
var command_tile_size := COMMAND_TILE_SIZE
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
var command_page_buttons: Array[Button] = []
var current_build_pages: Array:
	get: return game.player_actions.current_build_pages
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
var command_page: int:
	get: return game.player_actions.command_page
	set(value): game.player_actions.command_page = value
var command_selection_id: int:
	get: return game.player_actions.command_selection_id
	set(value): game.player_actions.command_selection_id = value

var _match_dirty := false
var _match_actions_dirty := false
var _match_refresh_queued := false
var _global_queue_signature: Array[String] = []
var _global_queue_locators: Array[Button] = []

func _init(game_ref: Node2D) -> void:
	game = game_ref
	game.player_actions.rebuilt.connect(_render_actions)
	game.player_actions.age_choice_requested.connect(_show_age_choice)
	game.player_actions.view_refresh_requested.connect(_update_hud)
	game.session.changes.changed.connect(_on_match_changed)

func _on_match_changed(owner_id: int, domains: Array[StringName]) -> void:
	# Enemy entities may be inspected, but their resource/queue changes are private.
	if owner_id != 0 and not domains.has(&"entities") and not domains.has(&"selection"): return
	_match_dirty = true
	_match_actions_dirty = _match_actions_dirty or domains.has(&"research") or domains.has(&"market") or domains.has(&"selection") or domains.has(&"age") or domains.has(&"landmarks") or domains.has(&"dynasty")
	if _match_refresh_queued: return
	_match_refresh_queued = true
	call_deferred("_flush_match_changes")

func _flush_match_changes() -> void:
	_match_refresh_queued = false
	if not _match_dirty or top_label == null: return
	_update_hud()
	match_view_refreshed.emit()

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
	global_queue_button.text = "队列 [Tab]"
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
	view_button.tooltip_text = "切换 2D / 2.5D 视角（F3）"
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
	command_panel.custom_minimum_size.x = 378
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
	# The grid determines its width and fills three rows of the default HUD.
	action_scroll.custom_minimum_size = Vector2(0, 170)
	action_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	action_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	action_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	command_column.add_child(action_scroll)
	action_bar = GridContainer.new()
	action_bar.columns = 5
	action_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
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
	_fit_command_tiles()
	var grid_width := command_tile_size.x * 5.0 + action_bar.get_theme_constant("h_separation") * 4.0
	var command_width := maxf(grid_width, action_bar.get_combined_minimum_size().x) + command_panel.get_theme_stylebox("panel").get_minimum_size().x
	if not is_equal_approx(command_panel.custom_minimum_size.x, command_width):
		command_panel.custom_minimum_size.x = command_width
	var content_height: float = hud_bottom.get_combined_minimum_size().y
	var required_height := maxf(maxf(HUD_BOTTOM_HEIGHT, content_height), _production_hud_floor())
	if not is_equal_approx(hud_bottom.offset_top, -required_height):
		hud_bottom.offset_top = -required_height

func _fit_command_tiles() -> void:
	# At very large text sizes, reserve enough width for the production summary
	# so larger command tiles do not force an extra row and a taller bottom HUD.
	var summary_font: Font = selection_summary.get_theme_font("font")
	var summary_size := selection_summary.get_theme_font_size("font_size")
	var summary_width := summary_font.get_string_size("生命 1050/1050   已建成   右键设置集结点", HORIZONTAL_ALIGNMENT_LEFT, -1, summary_size).x
	var dock := command_panel.get_parent() as HBoxContainer
	var selection_row := selection_column.get_parent() as HBoxContainer
	var reserved_width := hud_bottom.get_theme_stylebox("panel").get_minimum_size().x + dock.get_theme_constant("separation") * 2.0
	reserved_width += minimap_anchor.get_combined_minimum_size().x + selection_panel.get_theme_stylebox("panel").get_minimum_size().x
	reserved_width += selection_portrait.custom_minimum_size.x + selection_row.get_theme_constant("separation") + ceilf(summary_width)
	var grid_gaps := action_bar.get_theme_constant("h_separation") * 4.0 + command_panel.get_theme_stylebox("panel").get_minimum_size().x
	var tile_side := clampf(floorf((ui_root.size.x - reserved_width - grid_gaps) / 5.0), 54.0, COMMAND_TILE_SIZE.x)
	command_tile_size = Vector2.ONE * tile_side
	if action_bar.columns != 5 or command_title.visible: return
	for child in action_bar.get_children():
		if child.custom_minimum_size != command_tile_size:
			child.custom_minimum_size = command_tile_size

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
	# Production buildings show progress in the bar and queue icons; their
	# status label is empty. Do not reserve an extra line for an empty label.
	column_height += queue_scroll.get_combined_minimum_size().y + notice_label.get_combined_minimum_size().y
	column_height += selection_column.get_theme_constant("separation") * 5
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
	if _match_actions_dirty: _rebuild_actions()
	_match_dirty = false
	_match_actions_dirty = false
	if global_queue_panel.visible: _refresh_global_queue_panel()
	_update_population_hud()
	_refresh_action_buttons()
	_update_selection_hud()
	queue_label.visible = not queue_label.text.is_empty()

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
		detail_label.text = "资源类型  %s\n采集单位  %s" % [GameData.RESOURCE_LABELS.get(item.kind, item.kind), "渔船" if item.appearance == "fish" else "村民"]
		var status_line := "当前状态  %s" % _resource_status(item)
		if item.has_wildlife_health():
			# The compact summary shows only two lines. Keep wildlife health first.
			detail_label.text = status_line + "\n" + detail_label.text
			if item.wildlife_hp > 0.0:
				selection_health.max_value = item.wildlife_max_hp
				selection_health.value = item.wildlife_hp
				selection_health.show()
		else:
			detail_label.text += "\n" + status_line
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
	if resource.has_wildlife_health():
		if resource.wildlife_hp <= 0.0: return "已猎杀 · 可采集"
		var status := "%s存活 · 生命 %.0f/%.0f" % [_resource_label(resource), resource.wildlife_hp, resource.wildlife_max_hp]
		if resource.appearance == "sheep":
			status += " · " + ("尚未认领" if resource.claimed_by < 0 else "我方已认领" if resource.claimed_by == 0 else "敌方已认领")
		return status
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
		_cancel_queue_job(building, job)
	)
	return button

func _cancel_queue_job(building: RtsBuilding, job: Dictionary) -> bool:
	if not is_instance_valid(building) or building.is_queued_for_deletion(): return false
	# Rows can survive until the deferred redraw. Resolve the original task,
	# never a stale slot that another cancellation has shifted underneath it.
	for index in building.production_queue.size():
		if is_same(building.production_queue[index], job):
			return game.cancel_production_job(building, index)
	return false

func _toggle_global_queue() -> void:
	global_queue_panel.visible = not global_queue_panel.visible
	if global_queue_panel.visible: _refresh_global_queue_panel()

func _refresh_global_queue_panel() -> void:
	var jobs: Array[Dictionary] = []
	var signature: Array[String] = []
	for building in game.buildings:
		if not is_instance_valid(building) or building.owner_id != 0: continue
		for index in building.production_queue.size():
			var job: Dictionary = building.production_queue[index]
			jobs.append({"building": building, "index": index, "job": job})
			signature.append("%s:%s:%s" % [building.get_instance_id(), job["type"], job["kind"]])
	if signature != _global_queue_signature or global_queue_list.get_child_count() == 0:
		_global_queue_signature = signature
		_global_queue_locators.clear()
		for child in global_queue_list.get_children():
			global_queue_list.remove_child(child)
			child.queue_free()
		var heading := Label.new()
		heading.text = "全局生产队列 · 点击定位建筑"
		global_queue_list.add_child(heading)
		for entry in jobs:
			var building: RtsBuilding = entry["building"]
			var job: Dictionary = entry["job"]
			var row := HBoxContainer.new()
			global_queue_list.add_child(row)
			var locate := Button.new()
			locate.custom_minimum_size.x = 275
			locate.pressed.connect(func() -> void:
				if not is_instance_valid(building) or building.is_queued_for_deletion(): return
				game.selected.clear()
				game.selected.append(building)
				game.camera.position = building.position
				_rebuild_actions()
				_update_hud()
			)
			row.add_child(locate)
			_global_queue_locators.append(locate)
			var cancel := Button.new()
			cancel.text = "×"
			cancel.pressed.connect(func() -> void:
				_cancel_queue_job(building, job)
			)
			row.add_child(cancel)
		if jobs.is_empty():
			var empty := Label.new()
			empty.text = "当前没有训练、研究或升级任务"
			global_queue_list.add_child(empty)
	# Update countdown text in place; a timer tick must not replace a hovered row.
	for index in jobs.size():
		var entry: Dictionary = jobs[index]
		var building: RtsBuilding = entry["building"]
		_global_queue_locators[index].text = "%s · %s%s" % [building.display_label(), _job_label(entry["job"]), " %.0fs" % building.production_remaining if entry["index"] == 0 else ""]

func _refresh_action_buttons() -> void:
	if game.players.is_empty() or command_buttons.is_empty(): return
	var context := RtsActionAvailability.context_for(game, 0, game.selected[0] if not game.selected.is_empty() and game.selected[0] is RtsBuilding else null)
	for button in command_buttons:
		if not is_instance_valid(button) or button.is_queued_for_deletion(): continue
		var status: Dictionary = game.player_actions.availability(button.get_meta("action_type"), button.get_meta("action_kind"), context)
		button.set_availability(status["available"], status["reason"], status["cost"])

func _selected_ability_availability(ability_id: String) -> Dictionary:
	return game.player_actions._selected_ability_availability(ability_id)

func _rebuild_actions() -> void:
	game.player_actions.rebuild()

func _render_actions() -> void:
	if action_bar == null: return
	for child in action_bar.get_children():
		action_bar.remove_child(child)
		child.queue_free()
	command_buttons.clear()
	hotkey_buttons.clear()
	command_title.hide()
	command_side_buttons.clear()
	command_page_buttons.clear()
	if game.selected.is_empty() or not is_instance_valid(game.selected[0]): return
	var item: Node2D = game.selected[0]
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
	var rendered: Array[Dictionary] = []
	for descriptor in game.player_actions.descriptors:
		var control: Control = _render_command(descriptor)
		control.visible = descriptor["visible"]
		rendered.append({"control": control, "slot": descriptor["slot"]})
	rendered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["slot"] < b["slot"])
	for index in rendered.size(): action_bar.move_child(rendered[index]["control"], index)
	command_side_buttons.sort_custom(func(a: Button, b: Button) -> bool: return a.get_meta("side_order") < b.get_meta("side_order"))
	_refresh_action_buttons()

func _render_command(descriptor: Dictionary) -> Control:
	if descriptor["view"] == "spacer":
		var spacer := Control.new()
		spacer.custom_minimum_size = command_tile_size
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		action_bar.add_child(spacer)
		return spacer
	var action_id: String = descriptor["id"]
	if descriptor["view"] == "side":
		var button: Button
		if descriptor["direction"] != 0:
			button = CommandPageButton.new()
			button.direction = descriptor["direction"]
			command_page_buttons.append(button)
		else:
			button = Button.new()
			button.text = descriptor["symbol"]
		button.set_meta("side_order", descriptor["side_order"])
		var keycode: int = descriptor["keycode"]
		button.tooltip_text = "%s\n快捷键：%s" % [descriptor["description"], OS.get_keycode_string(keycode)]
		_add_shortcut_badge(button, keycode)
		hotkey_buttons[keycode] = button
		button.custom_minimum_size = command_tile_size
		button.focus_mode = Control.FOCUS_NONE
		UiStyle._style_button(button)
		button.pressed.connect(func() -> void: game.execute_player_action(action_id))
		action_bar.add_child(button)
		command_side_buttons.append(button)
		return button
	var button := RtsCommandButton.new()
	var keycode: int = descriptor["keycode"]
	button.configure(descriptor["kind"], descriptor["label"], OS.get_keycode_string(keycode) if keycode != KEY_NONE else "")
	button.custom_minimum_size = command_tile_size
	_add_shortcut_badge(button, keycode)
	button.set_description(descriptor["description"])
	button.set_meta("cost", descriptor["cost"])
	button.set_meta("action_type", descriptor["type"])
	button.set_meta("action_kind", descriptor["kind"])
	button.set_meta("action_id", action_id)
	button.pressed.connect(func() -> void: game.execute_player_action(action_id))
	action_bar.add_child(button)
	command_buttons.append(button)
	if descriptor["kind"] == "stop":
		button.set_meta("side_order", descriptor["side_order"])
		command_side_buttons.append(button)
	if keycode != KEY_NONE: hotkey_buttons[keycode] = button
	return button

func _add_shortcut_badge(button: Button, keycode: int) -> void:
	if keycode == KEY_NONE: return
	var badge := PanelContainer.new()
	badge.name = "ShortcutBadge"
	badge.position = Vector2(2, 2)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("211b14")
	style.content_margin_left = 3
	style.content_margin_right = 3
	badge.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = OS.get_keycode_string(keycode)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color("f1d99b"))
	badge.add_child(label)
	button.add_child(badge)

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

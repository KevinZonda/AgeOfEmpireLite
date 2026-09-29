extends RefCounted

# Base sizes at 100% text scale. All font scaling goes through apply_tree().
const HERO := 42
const PAGE_TITLE := 28
const FEATURE_TITLE := 24
const SECTION_TITLE := 20
const SUBSECTION_TITLE := 18
const BODY := 16
const CAPTION := 14

# UI controls inherit ui_scale from ui_root. Their local font size cancels that
# transform so the final on-screen size depends only on text_scale.
static func ui_font_size(base_size: int, text_scale: float, ui_scale: float) -> int:
	return maxi(1, roundi(base_size * text_scale / maxf(ui_scale, 0.01)))

# Tooltips and cursor/world annotations are rendered outside the scaled UI tree.
static func screen_font_size(base_size: int, text_scale: float) -> int:
	return maxi(1, roundi(base_size * text_scale))

static func apply_tree(root: Node, text_scale: float, ui_scale: float, tooltip_base_size: int) -> void:
	var tooltip_size := screen_font_size(tooltip_base_size, text_scale)
	var default_theme := ThemeDB.get_default_theme()
	if default_theme.get_font_size("font_size", "TooltipLabel") != tooltip_size:
		default_theme.set_font_size("font_size", "TooltipLabel", tooltip_size)
	_apply_node(root, text_scale, ui_scale, tooltip_base_size)

static func _apply_node(node: Node, text_scale: float, ui_scale: float, tooltip_base_size: int) -> void:
	if node is PopupMenu:
		var popup: PopupMenu = node
		if not popup.has_meta("base_ui_font_size"):
			popup.set_meta("base_ui_font_size", popup.get_theme_font_size("font_size"))
		var size := ui_font_size(int(popup.get_meta("base_ui_font_size")), text_scale, ui_scale)
		if popup.get_theme_font_size("font_size") != size:
			popup.add_theme_font_size_override("font_size", size)
	elif node is Label or node is BaseButton or node is LineEdit or node is TextEdit or node is RichTextLabel or node is TabContainer:
		var control: Control = node
		var font_key := "normal_font_size" if node is RichTextLabel else "font_size"
		var is_tooltip := control.theme_type_variation == "TooltipLabel"
		if is_tooltip:
			# A new TooltipLabel inherits the already scaled ThemeDB size.
			control.set_meta("base_ui_font_size", tooltip_base_size)
		elif not control.has_meta("base_ui_font_size"):
			control.set_meta("base_ui_font_size", control.get_theme_font_size(font_key))
		var base_size: int = control.get_meta("base_ui_font_size")
		var size := screen_font_size(base_size, text_scale) if is_tooltip else ui_font_size(base_size, text_scale, ui_scale)
		if control.get_theme_font_size(font_key) != size:
			control.add_theme_font_size_override(font_key, size)
	if node is RtsStatisticsChart:
		var chart: RtsStatisticsChart = node
		if not is_equal_approx(chart.text_scale, text_scale) or not is_equal_approx(chart.ui_scale, ui_scale):
			chart.text_scale = text_scale
			chart.ui_scale = ui_scale
			chart.queue_redraw()
	for child in node.get_children(true):
		_apply_node(child, text_scale, ui_scale, tooltip_base_size)

static func world_caption_size(game: Node) -> int:
	var configured: Variant = game.get("text_scale") if game != null else null
	return screen_font_size(CAPTION, float(configured) if configured != null else 1.0)

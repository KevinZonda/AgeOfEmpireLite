class_name RtsCommandButton
extends Button

var icon_kind := ""
var caption := ""
var shortcut_label := ""
var slot_index := -1
var availability_reason := ""
var action_cost: Dictionary = {}

func configure(kind: String, label_text: String, key_text: String, slot: int = -1) -> void:
	icon_kind = kind
	caption = label_text
	shortcut_label = key_text
	slot_index = slot
	custom_minimum_size = Vector2(108, 69)
	_refresh_tooltip()
	queue_redraw()

func set_availability(available: bool, reason: String = "", cost: Dictionary = {}) -> void:
	disabled = not available
	availability_reason = "" if available else reason
	action_cost = cost.duplicate(true)
	_refresh_tooltip()
	queue_redraw()

func _refresh_tooltip() -> void:
	var lines: Array[String] = [caption]
	if not action_cost.is_empty(): lines.append(GameData.cost_text(action_cost))
	if not availability_reason.is_empty(): lines.append(availability_reason)
	if not shortcut_label.is_empty(): lines.append("快捷键 %s" % shortcut_label)
	tooltip_text = "\n".join(lines)

func _draw() -> void:
	var color := Color("e9d69d") if not disabled else Color("8b9291")
	_draw_icon(Vector2(24, 29), color)
	var font := ThemeDB.fallback_font
	if font == null: return
	draw_string(font, Vector2(46, 26), caption, HORIZONTAL_ALIGNMENT_LEFT, 59, 11 if caption.length() > 4 else 14, color)
	if not shortcut_label.is_empty():
		draw_string(font, Vector2(46, 45), "[%s]" % shortcut_label, HORIZONTAL_ALIGNMENT_LEFT, 55, 11, color.darkened(0.15))
	if disabled and not availability_reason.is_empty():
		draw_string(font, Vector2(5, 63), availability_reason, HORIZONTAL_ALIGNMENT_LEFT, 98, 10, Color("d9a99a"))

func _draw_icon(center: Vector2, color: Color) -> void:
	match icon_kind:
		"house", "town_center", "barracks", "stable", "outpost", "keep", "siege_workshop", "wonder":
			draw_rect(Rect2(center + Vector2(-11, -4), Vector2(22, 17)), color, false, 2)
			draw_colored_polygon(PackedVector2Array([center + Vector2(-13, -5), center + Vector2(0, -15), center + Vector2(13, -5)]), color)
			if icon_kind == "barracks": draw_line(center + Vector2(-7, 2), center + Vector2(7, 2), color, 2)
			if icon_kind == "stable": draw_arc(center + Vector2(0, 6), 5, PI, TAU, 12, color, 2)
		"farm":
			draw_rect(Rect2(center + Vector2(-12, -11), Vector2(24, 23)), color, false, 2)
			for x in [-7, 0, 7]: draw_line(center + Vector2(x - 3, -8), center + Vector2(x + 2, 9), color, 2)
		"archery_range", "archer", "longbow":
			draw_arc(center, 12, -PI * 0.6, PI * 0.6, 20, color, 2)
			draw_line(center + Vector2(4, -12), center + Vector2(4, 12), color, 2)
			draw_line(center + Vector2(-6, 0), center + Vector2(14, 0), color, 2)
		"crossbowman", "arbaletrier", "zhuge_nu":
			draw_arc(center + Vector2(2, -5), 11, 0, PI, 16, color, 2)
			draw_line(center + Vector2(2, -9), center + Vector2(2, 13), color, 2)
			draw_line(center + Vector2(-11, -5), center + Vector2(13, -5), color, 2)
		"villager":
			draw_circle(center + Vector2(0, -8), 5, color)
			draw_line(center + Vector2(0, -2), center + Vector2(0, 12), color, 3)
			draw_line(center + Vector2(-8, 3), center + Vector2(8, 3), color, 2)
		"spearman":
			draw_line(center + Vector2(-8, 12), center + Vector2(8, -12), color, 3)
			draw_colored_polygon(PackedVector2Array([center + Vector2(8, -17), center + Vector2(3, -9), center + Vector2(11, -9)]), color)
		"man_at_arms", "palace_guard":
			draw_rect(Rect2(center + Vector2(-8, -10), Vector2(16, 21)), color, false, 2)
			draw_line(center + Vector2(8, 8), center + Vector2(15, -12), color, 3)
		"scout", "horseman", "knight", "royal_knight":
			draw_colored_polygon(PackedVector2Array([center + Vector2(-10, -8), center + Vector2(9, -8), center + Vector2(12, 4), center + Vector2(0, 13), center + Vector2(-12, 4)]), color)
			draw_line(center + Vector2(-5, 1), center + Vector2(5, 1), Color("273338"), 2)
		"forged_weapons", "iron_armor", "veteran_training", "elite_training":
			draw_rect(Rect2(center + Vector2(-10, -12), Vector2(20, 24)), color, false, 2)
			draw_line(center + Vector2(-5, -5), center + Vector2(5, -5), color, 2)
			draw_line(center + Vector2(-5, 1), center + Vector2(5, 1), color, 2)
		"age":
			draw_line(center + Vector2(0, 12), center + Vector2(0, -8), color, 4)
			draw_colored_polygon(PackedVector2Array([center + Vector2(-9, -5), center + Vector2(0, -16), center + Vector2(9, -5)]), color)
		"palisade_wall", "stone_wall":
			draw_rect(Rect2(center + Vector2(-13, -8), Vector2(26, 16)), color, false, 2)
			for x in [-6, 3]: draw_line(center + Vector2(x, -8), center + Vector2(x, 8), color, 2)
		"battering_ram", "trebuchet":
			draw_line(center + Vector2(-13, 8), center + Vector2(13, 8), color, 3)
			draw_circle(center + Vector2(-7, 11), 3, color)
			draw_circle(center + Vector2(8, 11), 3, color)
			draw_line(center + Vector2(-7, 4), center + Vector2(6, -12), color, 3)
		"next_page":
			draw_line(center + Vector2(-10, 0), center + Vector2(9, 0), color, 3)
			draw_colored_polygon(PackedVector2Array([center + Vector2(4, -7), center + Vector2(12, 0), center + Vector2(4, 7)]), color)
		_:
			draw_circle(center, 10, color)

class_name RtsCommandButton
extends Button

var icon_kind := ""
var caption := ""
var shortcut_label := ""

func configure(kind: String, label_text: String, key_text: String) -> void:
	icon_kind = kind
	caption = label_text
	shortcut_label = key_text
	custom_minimum_size = Vector2(108, 61)
	queue_redraw()

func _draw() -> void:
	var color := Color("e9d69d") if not disabled else Color("8b9291")
	_draw_icon(Vector2(24, 29), color)
	var font := ThemeDB.fallback_font
	if font == null: return
	draw_string(font, Vector2(46, 26), caption, HORIZONTAL_ALIGNMENT_LEFT, 55, 14, color)
	draw_string(font, Vector2(46, 46), "[%s]" % shortcut_label, HORIZONTAL_ALIGNMENT_LEFT, 55, 11, color.darkened(0.15))

func _draw_icon(center: Vector2, color: Color) -> void:
	match icon_kind:
		"house", "town_center", "barracks", "stable":
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
		"villager":
			draw_circle(center + Vector2(0, -8), 5, color)
			draw_line(center + Vector2(0, -2), center + Vector2(0, 12), color, 3)
			draw_line(center + Vector2(-8, 3), center + Vector2(8, 3), color, 2)
		"spearman":
			draw_line(center + Vector2(-8, 12), center + Vector2(8, -12), color, 3)
			draw_colored_polygon(PackedVector2Array([center + Vector2(8, -17), center + Vector2(3, -9), center + Vector2(11, -9)]), color)
		"horseman", "knight":
			draw_colored_polygon(PackedVector2Array([center + Vector2(-10, -8), center + Vector2(9, -8), center + Vector2(12, 4), center + Vector2(0, 13), center + Vector2(-12, 4)]), color)
			draw_line(center + Vector2(-5, 1), center + Vector2(5, 1), Color("273338"), 2)
		"age":
			draw_line(center + Vector2(0, 12), center + Vector2(0, -8), color, 4)
			draw_colored_polygon(PackedVector2Array([center + Vector2(-9, -5), center + Vector2(0, -16), center + Vector2(9, -5)]), color)
		_:
			draw_circle(center, 10, color)

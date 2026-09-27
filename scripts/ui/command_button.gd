class_name RtsCommandButton
extends Button

var icon_kind := ""
var caption := ""
var shortcut_label := ""
var slot_index := -1
var availability_reason := ""
var action_cost: Dictionary = {}
var description := ""

func configure(kind: String, label_text: String, key_text: String, slot: int = -1) -> void:
	icon_kind = kind
	caption = label_text
	shortcut_label = key_text
	slot_index = slot
	custom_minimum_size = Vector2(108, 69)
	add_theme_stylebox_override("normal", _tile_style(Color("473725"), Color("8d7549")))
	add_theme_stylebox_override("hover", _tile_style(Color("634a29"), Color("ebca7c")))
	add_theme_stylebox_override("pressed", _tile_style(Color("2f281c"), Color("f4d58a")))
	add_theme_stylebox_override("disabled", _tile_style(Color("2d2a24"), Color("5f594a")))
	focus_mode = Control.FOCUS_NONE
	_refresh_tooltip()
	queue_redraw()

func _tile_style(fill: Color, edge: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	return style

func set_availability(available: bool, reason: String = "", cost: Dictionary = {}) -> void:
	disabled = not available
	availability_reason = "" if available else reason
	action_cost = cost.duplicate(true)
	_refresh_tooltip()
	queue_redraw()

func set_description(value: String) -> void:
	description = value
	_refresh_tooltip()

func _refresh_tooltip() -> void:
	var lines: Array[String] = [caption]
	if not action_cost.is_empty(): lines.append(GameData.cost_text(action_cost))
	if not description.is_empty(): lines.append(description)
	if not availability_reason.is_empty(): lines.append(availability_reason)
	if not shortcut_label.is_empty(): lines.append("快捷键 %s" % shortcut_label)
	tooltip_text = "\n".join(lines)

func _draw() -> void:
	var color := Color("f1d99b") if not disabled else Color("8b8679")
	draw_rect(Rect2(5, 9, 34, 34), Color("211d16") if not disabled else Color("272722"))
	draw_rect(Rect2(5, 9, 34, 34), Color("a68b53") if not disabled else Color("59574d"), false, 1)
	_draw_icon(Vector2(22, 26), color)
	var font := ThemeDB.fallback_font
	if font == null: return
	draw_string(font, Vector2(45, 28), caption, HORIZONTAL_ALIGNMENT_LEFT, 60, 11 if caption.length() > 4 else 13, color)
	if not shortcut_label.is_empty():
		draw_rect(Rect2(5, 49, 22, 16), Color("211b14"))
		draw_rect(Rect2(5, 49, 22, 16), Color("a68b53"), false, 1)
		draw_string(font, Vector2(10, 61), shortcut_label, HORIZONTAL_ALIGNMENT_LEFT, 16, 11, color)
	if disabled and not availability_reason.is_empty():
		draw_string(font, Vector2(33, 60), availability_reason, HORIZONTAL_ALIGNMENT_LEFT, 70, 10, Color("d8a48d"))

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
		"battering_ram", "trebuchet", "siege_tower", "mangonel", "nest_of_bees", "springald", "bombard", "cannon":
			draw_line(center + Vector2(-13, 8), center + Vector2(13, 8), color, 3)
			draw_circle(center + Vector2(-7, 11), 3, color)
			draw_circle(center + Vector2(8, 11), 3, color)
			draw_line(center + Vector2(-7, 4), center + Vector2(6, -12), color, 3)
		"fishing_boat", "arrow_ship", "warship", "transport_ship":
			draw_colored_polygon(PackedVector2Array([center + Vector2(-14, 1), center + Vector2(14, 1), center + Vector2(9, 10), center + Vector2(-9, 10)]), color)
			draw_line(center + Vector2(0, 1), center + Vector2(0, -15), color, 2)
			if icon_kind == "transport_ship": draw_rect(Rect2(center + Vector2(-7, -5), Vector2(14, 6)), color.darkened(0.3))
		"patrol":
			draw_arc(center, 10, -PI * 0.8, PI * 0.85, 16, color, 2)
			draw_colored_polygon(PackedVector2Array([center + Vector2(-10, -7), center + Vector2(-14, 0), center + Vector2(-5, -1)]), color)
		"hold":
			draw_rect(Rect2(center + Vector2(-9, -9), Vector2(18, 18)), color, false, 2)
			draw_circle(center, 3, color)
		"focus":
			draw_arc(center, 10, 0, TAU, 18, color, 2)
			draw_line(center + Vector2(-15, 0), center + Vector2(15, 0), color, 2)
			draw_line(center + Vector2(0, -15), center + Vector2(0, 15), color, 2)
		"retreat":
			draw_line(center + Vector2(12, 0), center + Vector2(-10, 0), color, 3)
			draw_colored_polygon(PackedVector2Array([center + Vector2(-6, -8), center + Vector2(-15, 0), center + Vector2(-6, 8)]), color)
		"market_buy", "market_sell":
			draw_circle(center + Vector2(-4, 3), 7, color)
			draw_line(center + Vector2(5, 4), center + Vector2(12, 4), color, 2)
			draw_colored_polygon(PackedVector2Array([center + Vector2(9, 0), center + Vector2(15, 4), center + Vector2(9, 8)]), color)
		"unload":
			draw_line(center + Vector2(-12, 8), center + Vector2(11, 8), color, 3)
			draw_line(center + Vector2(0, -12), center + Vector2(0, 4), color, 3)
			draw_colored_polygon(PackedVector2Array([center + Vector2(-6, -2), center + Vector2(0, 6), center + Vector2(6, -2)]), color)
		"next_page":
			draw_line(center + Vector2(-10, 0), center + Vector2(9, 0), color, 3)
			draw_colored_polygon(PackedVector2Array([center + Vector2(4, -7), center + Vector2(12, 0), center + Vector2(4, 7)]), color)
		_:
			draw_circle(center, 10, color)

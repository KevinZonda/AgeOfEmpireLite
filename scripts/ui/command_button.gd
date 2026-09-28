class_name RtsCommandButton
extends Button

static var texture_cache: Dictionary = {}

var icon_kind := ""
var caption := ""
var shortcut_label := ""
var slot_index := -1
var availability_reason := ""
var action_cost: Dictionary = {}
var description := ""
var icon_texture: Texture2D
var rank_icon_fallback := false

func configure(kind: String, label_text: String, key_text: String, slot: int = -1) -> void:
	icon_kind = kind
	caption = label_text
	shortcut_label = key_text
	slot_index = slot
	icon_texture = _load_icon(kind)
	custom_minimum_size = Vector2(80, 80)
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
	if not description.is_empty(): lines.append(description)
	if not action_cost.is_empty(): lines.append("花费：%s" % GameData.cost_text(action_cost))
	if not availability_reason.is_empty(): lines.append("当前不可用：%s" % availability_reason)
	if not shortcut_label.is_empty(): lines.append("快捷键：%s" % shortcut_label)
	tooltip_text = "\n".join(lines)

func _draw() -> void:
	var color := Color("f1d99b") if not disabled else Color("8b8679")
	var icon_rect := Rect2((size - Vector2(68, 68)) * 0.5, Vector2(68, 68))
	if icon_texture != null:
		draw_texture_rect(icon_texture, icon_rect, false, Color(1, 1, 1, 0.38) if disabled else Color.WHITE)
	else:
		draw_rect(icon_rect, Color("211d16") if not disabled else Color("272722"))
		draw_rect(icon_rect, Color("a68b53") if not disabled else Color("59574d"), false, 1)
		draw_set_transform(icon_rect.get_center(), 0.0, Vector2(1.7, 1.7))
		_draw_icon(Vector2.ZERO, color)
		draw_set_transform(Vector2.ZERO)
	var font := ThemeDB.fallback_font
	if font == null: return
	if rank_icon_fallback:
		var rank_badge := Rect2(icon_rect.position + Vector2(0, 52), Vector2(22, 16))
		draw_rect(rank_badge, Color("211b14"))
		draw_rect(rank_badge, Color("a68b53"), false, 1)
		draw_string(font, rank_badge.position + Vector2(2, 12), "III" if icon_kind.ends_with("_3") else "IV", HORIZONTAL_ALIGNMENT_CENTER, 18, 10, color)

func _load_icon(kind: String) -> Texture2D:
	rank_icon_fallback = false
	var path := "res://assets/ui/command_icons/%s.png" % kind
	var texture := _texture_at(path)
	if texture == null and kind.begins_with("rank_"):
		var separator := kind.rfind("_")
		if separator > 5:
			path = "res://assets/ui/command_icons/%s.png" % kind.substr(5, separator - 5)
			texture = _texture_at(path)
			rank_icon_fallback = texture != null
	return texture

static func _texture_at(path: String) -> Texture2D:
	if texture_cache.has(path): return texture_cache[path]
	var texture: Texture2D
	# The local template_debug binary cannot read textures imported by the
	# official editor, but it can decode the source PNGs directly.
	if FileAccess.file_exists(path):
		var image := Image.new()
		if image.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) == OK:
			texture = ImageTexture.create_from_image(image)
	if texture == null and ResourceLoader.exists(path): texture = load(path) as Texture2D
	texture_cache[path] = texture
	return texture

func _draw_icon(center: Vector2, color: Color) -> void:
	match icon_kind:
		"house", "town_center", "barracks", "stable", "outpost", "keep", "siege_workshop":
			draw_rect(Rect2(center + Vector2(-11, -4), Vector2(22, 17)), color, false, 2)
			draw_colored_polygon(PackedVector2Array([center + Vector2(-13, -5), center + Vector2(0, -15), center + Vector2(13, -5)]), color)
			if icon_kind == "barracks": draw_line(center + Vector2(-7, 2), center + Vector2(7, 2), color, 2)
			if icon_kind == "stable": draw_arc(center + Vector2(0, 6), 5, PI, TAU, 12, color, 2)
		"wonder":
			draw_rect(Rect2(center + Vector2(-14, 10), Vector2(28, 3)), color)
			for x in [-9, 0, 9]: draw_rect(Rect2(center + Vector2(x - 2, -6), Vector2(4, 16)), color)
			draw_colored_polygon(PackedVector2Array([center + Vector2(-15, -7), center + Vector2(0, -14), center + Vector2(15, -7)]), color)
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
		"forged_weapons", "veteran_training", "archery_drill", "cavalry_husbandry", "siege_works":
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
		"stop":
			draw_rect(Rect2(center + Vector2(-9, -9), Vector2(18, 18)), color)
		"attack_move":
			draw_line(center + Vector2(-13, 9), center + Vector2(8, -8), color, 3)
			draw_colored_polygon(PackedVector2Array([center + Vector2(5, -14), center + Vector2(14, -12), center + Vector2(12, -3)]), color)
			draw_line(center + Vector2(-12, -9), center + Vector2(-5, -2), color, 2)
		"attack_ground":
			draw_arc(center + Vector2(0, 3), 9, 0, TAU, 18, color, 2)
			draw_line(center + Vector2(0, -15), center + Vector2(0, 12), color, 2)
			draw_line(center + Vector2(-13, 3), center + Vector2(13, 3), color, 2)
		"formation":
			for x in [-9, 0, 9]:
				draw_circle(center + Vector2(x, -7), 3, color)
				draw_circle(center + Vector2(x, 7), 3, color)
		"stance":
			draw_colored_polygon(PackedVector2Array([center + Vector2(0, -13), center + Vector2(11, -7), center + Vector2(8, 7), center + Vector2(0, 13), center + Vector2(-8, 7), center + Vector2(-11, -7)]), color)
			draw_line(center + Vector2(-5, 0), center + Vector2(5, 0), Color("473725"), 2)
		"ungarrison":
			draw_rect(Rect2(center + Vector2(-12, -11), Vector2(17, 22)), color, false, 2)
			draw_line(center + Vector2(-3, 0), center + Vector2(12, 0), color, 3)
			draw_colored_polygon(PackedVector2Array([center + Vector2(7, -6), center + Vector2(14, 0), center + Vector2(7, 6)]), color)
		"town_bell":
			draw_colored_polygon(PackedVector2Array([center + Vector2(-9, 7), center + Vector2(-6, -5), center + Vector2(0, -11), center + Vector2(6, -5), center + Vector2(9, 7)]), color)
			draw_line(center + Vector2(-11, 8), center + Vector2(11, 8), color, 3)
			draw_circle(center + Vector2(0, 11), 2, color)
		"return_work":
			draw_line(center + Vector2(7, -10), center + Vector2(-3, 9), color, 4)
			draw_line(center + Vector2(3, -12), center + Vector2(13, -8), color, 4)
			draw_line(center + Vector2(-9, -7), center + Vector2(-9, 7), color, 2)
			draw_colored_polygon(PackedVector2Array([center + Vector2(-13, -2), center + Vector2(-9, -9), center + Vector2(-5, -2)]), color)
		"field_ram", "field_tower":
			draw_rect(Rect2(center + Vector2(-10, -5), Vector2(20, 15)), color, false, 2)
			draw_circle(center + Vector2(-7, 11), 3, color)
			draw_circle(center + Vector2(7, 11), 3, color)
			if icon_kind == "field_tower": draw_colored_polygon(PackedVector2Array([center + Vector2(-12, -6), center + Vector2(0, -15), center + Vector2(12, -6)]), color)
			else: draw_line(center + Vector2(-12, 0), center + Vector2(13, 0), color, 4)
		"palings", "camp":
			for x in [-8, 0, 8]:
				draw_line(center + Vector2(x, 10), center + Vector2(x, -10), color, 3)
				draw_colored_polygon(PackedVector2Array([center + Vector2(x - 3, -8), center + Vector2(x, -15), center + Vector2(x + 3, -8)]), color)
		"volley", "artillery_shot":
			for x in [-8, 0, 8]:
				draw_line(center + Vector2(x - 3, 9), center + Vector2(x + 4, -9), color, 2)
				draw_colored_polygon(PackedVector2Array([center + Vector2(x + 2, -7), center + Vector2(x + 7, -15), center + Vector2(x + 7, -5)]), color)
		"pavise":
			draw_colored_polygon(PackedVector2Array([center + Vector2(-10, -12), center + Vector2(10, -12), center + Vector2(10, 5), center + Vector2(0, 13), center + Vector2(-10, 5)]), color)
		"helmsman":
			draw_arc(center, 10, 0, TAU, 18, color, 2)
			for x in [-1, 1]: draw_line(center + Vector2(-10 * x, 0), center + Vector2(10 * x, 0), color, 2)
			draw_circle(center, 3, color)
		"convert":
			draw_arc(center, 11, -PI * 0.7, PI * 0.7, 18, color, 2)
			draw_colored_polygon(PackedVector2Array([center + Vector2(5, -12), center + Vector2(13, -10), center + Vector2(9, -3)]), color)
			draw_circle(center, 3, color)
		"food":
			for x in [-6, 0, 6]:
				draw_line(center + Vector2(x, 12), center + Vector2(x, -9), color, 2)
				draw_colored_polygon(PackedVector2Array([center + Vector2(x - 3, -7), center + Vector2(x, -15), center + Vector2(x + 3, -7)]), color)
		"wood":
			draw_line(center + Vector2(-11, 10), center + Vector2(8, -9), color, 7)
			draw_circle(center + Vector2(9, -10), 5, color)
		"gold", "stone":
			draw_colored_polygon(PackedVector2Array([center + Vector2(-11, 8), center + Vector2(-7, -5), center + Vector2(1, -12), center + Vector2(12, -4), center + Vector2(11, 8)]), color)
			if icon_kind == "stone": draw_line(center + Vector2(-7, -4), center + Vector2(10, 3), Color("473725"), 2)
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
			draw_circle(center + Vector2(-5, 4), 6, color)
			var marker := Color("c6704b") if caption.contains("粮") else Color("7da76a") if caption.contains("木") else Color("b9b7ac")
			draw_circle(center + Vector2(5, -8), 4, marker)
			var direction := 1 if icon_kind == "market_buy" else -1
			draw_line(center + Vector2(-1 * direction, 5), center + Vector2(10 * direction, 5), color, 2)
			draw_colored_polygon(PackedVector2Array([center + Vector2(6 * direction, 1), center + Vector2(13 * direction, 5), center + Vector2(6 * direction, 9)]), color)
		"spy":
			draw_arc(center, 12, PI * 0.15, PI * 0.85, 16, color, 2)
			draw_circle(center, 5, color)
		"collect_stockpile":
			draw_rect(Rect2(center + Vector2(-11, -9), Vector2(22, 17)), color, false, 2)
			draw_line(center + Vector2(-6, -1), center + Vector2(6, -1), color, 2)
			draw_colored_polygon(PackedVector2Array([center + Vector2(-5, 8), center + Vector2(0, 15), center + Vector2(5, 8)]), color)
		"trade":
			draw_line(center + Vector2(-12, -5), center + Vector2(10, -5), color, 2)
			draw_colored_polygon(PackedVector2Array([center + Vector2(6, -10), center + Vector2(13, -5), center + Vector2(6, 0)]), color)
			draw_line(center + Vector2(12, 6), center + Vector2(-10, 6), color, 2)
			draw_colored_polygon(PackedVector2Array([center + Vector2(-6, 1), center + Vector2(-13, 6), center + Vector2(-6, 11)]), color)
		"unload":
			draw_line(center + Vector2(-12, 8), center + Vector2(11, 8), color, 3)
			draw_line(center + Vector2(0, -12), center + Vector2(0, 4), color, 3)
			draw_colored_polygon(PackedVector2Array([center + Vector2(-6, -2), center + Vector2(0, 6), center + Vector2(6, -2)]), color)
		"next_page":
			draw_line(center + Vector2(-10, 0), center + Vector2(9, 0), color, 3)
			draw_colored_polygon(PackedVector2Array([center + Vector2(4, -7), center + Vector2(12, 0), center + Vector2(4, 7)]), color)
		_:
			if icon_kind.begins_with("rank_"):
				draw_line(center + Vector2(-9, 10), center + Vector2(0, -11), color, 3)
				draw_line(center + Vector2(0, -11), center + Vector2(9, 10), color, 3)
			else: draw_circle(center, 10, color)

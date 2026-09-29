class_name GameCursor
extends Control

# Visual feedback only; this control never captures mouse input.
const LABELS := {
	"default": "",
	"select": "选择",
	"move": "移动",
	"rally": "集结",
	"gather": "采集",
	"trade": "贸易",
	"relic": "拾取圣物",
	"construct": "建造",
	"attack": "攻击",
	"attack_move": "攻击移动",
	"patrol": "巡逻",
	"focus": "集火",
	"unload": "登陆",
	"board": "登船",
	"drag": "框选",
	"build_valid": "放置",
	"build_invalid": "不可放置",
}

var state := "default"
var context_text := ""
var click_time := 0.0
var text_scale := 1.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(100, 52)
	z_index = 100

func set_state(value: String) -> void:
	if state == value: return
	state = value
	queue_redraw()

func set_context(value: String) -> void:
	if context_text == value: return
	context_text = value
	queue_redraw()

func flash() -> void:
	click_time = 0.2
	queue_redraw()

func _process(delta: float) -> void:
	if click_time > 0.0:
		click_time = maxf(0.0, click_time - delta)
		queue_redraw()

func _draw() -> void:
	var accent := Color("f1e5bd")
	match state:
		"select", "drag": accent = Color("f3d96e")
		"move", "rally", "patrol", "unload", "board": accent = Color("89c4f0")
		"gather", "trade", "relic", "construct", "build_valid": accent = Color("83da8b")
		"attack", "attack_move", "focus", "build_invalid": accent = Color("ef7772")
	var arrow := PackedVector2Array([Vector2(0, 0), Vector2(1, 23), Vector2(7, 17), Vector2(12, 29), Vector2(17, 26), Vector2(11, 15), Vector2(20, 14)])
	draw_colored_polygon(arrow, Color("1e2628"))
	draw_polyline(arrow, accent, 2, true)
	if state != "default":
		draw_circle(Vector2(23, 26), 11, Color("1e2628"))
		draw_arc(Vector2(23, 26), 10, 0, TAU, 24, accent, 2)
		match state:
			"select", "drag":
				draw_rect(Rect2(18, 21, 10, 10), accent, false, 2)
			"move", "rally", "patrol", "unload", "board":
				draw_line(Vector2(17, 26), Vector2(29, 26), accent, 2)
				draw_line(Vector2(23, 20), Vector2(23, 32), accent, 2)
			"gather", "trade", "relic":
				draw_line(Vector2(18, 31), Vector2(27, 21), accent, 2)
				draw_line(Vector2(23, 21), Vector2(29, 24), accent, 2)
			"attack", "attack_move", "focus":
				draw_line(Vector2(17, 32), Vector2(29, 20), accent, 3)
				draw_line(Vector2(18, 22), Vector2(27, 31), accent, 2)
			"construct", "build_valid":
				draw_line(Vector2(17, 26), Vector2(21, 30), accent, 2)
				draw_line(Vector2(21, 30), Vector2(29, 21), accent, 2)
			"build_invalid":
				draw_line(Vector2(18, 21), Vector2(28, 31), accent, 2)
				draw_line(Vector2(28, 21), Vector2(18, 31), accent, 2)
	var label: String = LABELS.get(state, "")
	if label != "":
		var font := ThemeDB.fallback_font
		if font != null:
			var label_size := maxi(1, roundi(14.0 * text_scale))
			draw_string(font, Vector2(38, 31), label, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size, Color("151d20"))
			draw_string(font, Vector2(37, 30), label, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size, accent)
	if context_text != "":
		var font := ThemeDB.fallback_font
		if font != null:
			var context_size := maxi(1, roundi(13.0 * text_scale))
			var width := font.get_string_size(context_text, HORIZONTAL_ALIGNMENT_LEFT, -1, context_size).x + 16.0
			var height := maxf(25.0, context_size + 12.0)
			draw_rect(Rect2(18, 43, width, height), Color("2c241b", 0.94))
			draw_rect(Rect2(18, 43, width, height), Color("b79759"), false, 1)
			draw_string(font, Vector2(26, 43 + height - 8), context_text, HORIZONTAL_ALIGNMENT_LEFT, -1, context_size, Color("f3dfb4"))
	if click_time > 0.0:
		var progress := 1.0 - click_time / 0.2
		draw_arc(Vector2.ZERO, 8.0 + progress * 12.0, 0, TAU, 28, Color(accent, 1.0 - progress), 2)

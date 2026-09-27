class_name RtsStatisticsChart
extends Control

var statistics: RtsMatchStatistics
var metric := "stock"
var player_colors: Array[Color] = []

func _ready() -> void:
	custom_minimum_size = Vector2(690, 260)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func show_metric(chosen: String) -> void:
	metric = chosen
	queue_redraw()

func _draw() -> void:
	var bounds := Rect2(Vector2(46, 10), size - Vector2(60, 40))
	draw_rect(bounds, Color("192b2a"), true)
	if statistics == null or statistics.samples.is_empty(): return
	var max_value := 1.0
	for sample in statistics.samples:
		for player in sample["players"]:
			max_value = maxf(max_value, float(player.get(metric, 0)))
	var duration := maxf(1.0, statistics.elapsed)
	for mark in 5:
		var y := bounds.end.y - float(mark) / 4.0 * bounds.size.y
		draw_line(Vector2(bounds.position.x, y), Vector2(bounds.end.x, y), Color("52706b", 0.45), 1.0)
		_draw_label(Vector2(0, y + 4), "%d" % roundi(float(mark) / 4.0 * max_value))
	for mark in 5:
		var x := bounds.position.x + float(mark) / 4.0 * bounds.size.x
		_draw_label(Vector2(x - 10, bounds.end.y + 20), "%d分" % roundi(float(mark) / 4.0 * duration / 60.0))
	for owner_id in player_colors.size():
		var previous := Vector2.INF
		for sample in statistics.samples:
			if owner_id >= sample["players"].size(): continue
			var player: Dictionary = sample["players"][owner_id]
			var point := Vector2(bounds.position.x + float(sample["time"]) / duration * bounds.size.x, bounds.end.y - float(player.get(metric, 0)) / max_value * bounds.size.y)
			if previous != Vector2.INF: draw_line(previous, point, player_colors[owner_id], 2.5, true)
			previous = point
	draw_rect(bounds, Color("90aaa2"), false, 1.0)

func _draw_label(at: Vector2, value: String) -> void:
	var font := ThemeDB.fallback_font
	if font != null: draw_string(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("d8e4d8"))

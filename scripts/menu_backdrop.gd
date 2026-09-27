class_name RtsMenuBackdrop
extends Control

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), Color("24180f"))
	var plank_width := w / 15.0
	for plank in 15:
		var left := float(plank) * plank_width
		var tone := Color("3d2818").lerp(Color("5a3922"), float((plank * 7) % 5) / 5.0)
		draw_rect(Rect2(left + 2, 0, plank_width - 3, h), tone)
		draw_line(Vector2(left, 0), Vector2(left, h), Color("1d130c"), 4)
		for grain in 8:
			var x := left + plank_width * (0.14 + float((grain * 3 + plank) % 7) / 10.0)
			var y := h * float(grain) / 8.0
			draw_line(Vector2(x, y), Vector2(x + sin(float(plank + grain)) * 7.0, y + h * 0.12), Color("24180f", 0.28), 1)
	for beam_y in [0.0, h - 45.0]:
		draw_rect(Rect2(0, beam_y, w, 45), Color("2a1b10"))
		draw_rect(Rect2(0, beam_y + 5, w, 2), Color("8c6335"))
		draw_rect(Rect2(0, beam_y + 38, w, 2), Color("8c6335"))
	for x in [25.0, w - 25.0]:
		for y in [22.0, h - 22.0]:
			draw_circle(Vector2(x, y), 8, Color("8f6b3b"))
			draw_circle(Vector2(x, y), 4, Color("302016"))

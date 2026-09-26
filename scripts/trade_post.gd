class_name RtsTradePost
extends Node2D

func contains(point: Vector2) -> bool:
	return position.distance_to(point) <= 26.0

func _draw() -> void:
	draw_rect(Rect2(-23, -22, 46, 44), Color("382d24"))
	draw_rect(Rect2(-19, -18, 38, 36), Color("bf9a62"))
	draw_colored_polygon(PackedVector2Array([Vector2(-27, -20), Vector2(0, -37), Vector2(27, -20)]), Color("79513c"))
	var font := ThemeDB.fallback_font
	if font != null: draw_string(font, Vector2(-28, 37), "贸易站", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)

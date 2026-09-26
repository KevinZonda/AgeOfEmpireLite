class_name RtsResource
extends Node2D

var kind: String
var amount: int
var radius := 22.0

func setup(resource_kind: String, quantity: int) -> void:
	kind = resource_kind
	amount = quantity
	queue_redraw()

func harvest(quantity: int) -> int:
	var taken: int = mini(quantity, amount)
	amount -= taken
	if amount <= 0:
		queue_free()
	else:
		queue_redraw()
	return taken

func _draw() -> void:
	var color := Color("82ba62")
	match kind:
		"wood": color = Color("397948")
		"gold": color = Color("e4c359")
		"stone": color = Color("9b9f9e")
	if kind == "wood":
		draw_circle(Vector2(0, 8), 9, Color("6d4a31"))
		draw_circle(Vector2(0, -4), 19, color)
		draw_circle(Vector2(-7, -9), 8, color.lightened(0.15))
	elif kind == "food":
		draw_circle(Vector2.ZERO, radius, Color("456d31"))
		for point in [Vector2(-10, -8), Vector2(8, -11), Vector2(4, 9), Vector2(-11, 8)]:
			draw_circle(point, 5, Color("d86b65"))
	else:
		var points := PackedVector2Array([Vector2(-22, 14), Vector2(-16, -10), Vector2(2, -20), Vector2(22, -8), Vector2(20, 17)])
		draw_colored_polygon(points, color)
		draw_line(Vector2(-16, -10), Vector2(2, -20), color.lightened(0.25), 2)
	var font := ThemeDB.fallback_font
	if font != null:
		draw_string(font, Vector2(-18, 36), str(amount), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)

class_name RtsSelectionPortrait
extends Control

var subject: Node2D
var owner_tint := Color("8a9a8e")

func _ready() -> void:
	custom_minimum_size = Vector2(102, 142)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func show_subject(value: Node2D, tint: Color = Color("8a9a8e")) -> void:
	subject = value
	owner_tint = tint
	queue_redraw()

func _draw() -> void:
	var frame := Rect2(Vector2.ZERO, size)
	draw_rect(frame, Color("1b1814"))
	draw_rect(Rect2(Vector2(5, 5), size - Vector2(10, 10)), Color("594328"))
	draw_rect(Rect2(Vector2(9, 9), size - Vector2(18, 18)), Color("b69a69"))
	draw_rect(Rect2(Vector2(12, 12), size - Vector2(24, 24)), Color("343d38"))
	draw_rect(frame, Color("b9995b"), false, 2)
	for x in [6.0, size.x - 6.0]:
		for y in [6.0, size.y - 6.0]:
			draw_circle(Vector2(x, y), 2.5, Color("e2c987"))
	if subject == null or not is_instance_valid(subject):
		_draw_empty()
	elif subject is RtsBuilding:
		_draw_building()
	elif subject is RtsResource:
		_draw_resource()
	else:
		_draw_unit()

func _draw_resource() -> void:
	var resource: RtsResource = subject
	var center := Vector2(size.x * 0.5, size.y * 0.5)
	var color := Color("79a64e")
	match resource.kind:
		"wood": color = Color("397948")
		"gold": color = Color("e4c359")
		"stone": color = Color("9b9f9e")
	if resource.appearance in ["deer", "boar", "sheep"]:
		color = {"deer": Color("a8794e"), "boar": Color("684d3a"), "sheep": Color("efead9")}[resource.appearance]
		draw_colored_polygon(PackedVector2Array([center + Vector2(-31, -9), center + Vector2(-20, -19), center + Vector2(17, -19), center + Vector2(31, -5), center + Vector2(25, 13), center + Vector2(-22, 17)]), color)
		draw_circle(center + Vector2(24, -14), 12, color.lightened(0.1))
		for x in [-18.0, 18.0]: draw_line(center + Vector2(x, 10), center + Vector2(x, 35), color.darkened(0.35), 4)
	elif resource.appearance == "fish":
		draw_colored_polygon(PackedVector2Array([center + Vector2(-30, 0), center + Vector2(5, -18), center + Vector2(31, 0), center + Vector2(5, 18)]), Color("c5d9cf"))
	else:
		draw_circle(center, 28, color)
		if resource.appearance == "berry":
			for offset in [Vector2(-12, -9), Vector2(10, -13), Vector2(9, 12), Vector2(-14, 11)]: draw_circle(center + offset, 6, Color("d86b65"))

func _draw_empty() -> void:
	var center := Vector2(size.x * 0.5, size.y * 0.48)
	draw_colored_polygon(PackedVector2Array([center + Vector2(-23, -22), center + Vector2(23, -22), center + Vector2(19, 23), center + Vector2(0, 35), center + Vector2(-19, 23)]), Color("766a50"))
	draw_line(center + Vector2(-15, -14), center + Vector2(15, 23), Color("c9b580"), 3)
	draw_line(center + Vector2(15, -14), center + Vector2(-15, 23), Color("c9b580"), 3)

func _draw_building() -> void:
	var center := Vector2(size.x * 0.5, size.y * 0.5)
	var building: RtsBuilding = subject
	draw_colored_polygon(PackedVector2Array([Vector2(14, 105), Vector2(88, 105), Vector2(78, 119), Vector2(24, 119)]), Color("202622", 0.65))
	draw_rect(Rect2(center + Vector2(-29, -20), Vector2(58, 47)), Color("a99570"))
	draw_rect(Rect2(center + Vector2(-34, -32), Vector2(68, 14)), owner_tint.darkened(0.23))
	draw_colored_polygon(PackedVector2Array([center + Vector2(-39, -32), center + Vector2(0, -57), center + Vector2(39, -32)]), Color("7a4d37"))
	draw_line(center + Vector2(-31, -31), center + Vector2(31, -31), Color("dbc795"), 2)
	draw_rect(Rect2(center + Vector2(-9, 1), Vector2(18, 26)), Color("42352a"))
	for x in [-22.0, 17.0]:
		draw_rect(Rect2(center + Vector2(x, -13), Vector2(6, 11)), Color("394a4a"))
	if building.kind == "town_center" or building.kind == "keep":
		for x in [-29.0, 18.0]:
			draw_rect(Rect2(center + Vector2(x, -40), Vector2(11, 13)), Color("b9a77d"))

func _draw_unit() -> void:
	var center := Vector2(size.x * 0.5, size.y * 0.5)
	var unit: RtsUnit = subject
	var cavalry: bool = unit.stats.get("tags", []).has("cavalry")
	var naval: bool = unit.stats.get("tags", []).has("naval")
	draw_colored_polygon(PackedVector2Array([center + Vector2(-32, 39), center + Vector2(-23, 33), center + Vector2(23, 33), center + Vector2(32, 39), center + Vector2(23, 45), center + Vector2(-23, 45)]), Color("1c2524", 0.65))
	if naval:
		draw_colored_polygon(PackedVector2Array([center + Vector2(-32, 18), center + Vector2(32, 18), center + Vector2(21, 36), center + Vector2(-21, 36)]), Color("8e6640"))
		draw_line(center + Vector2(0, 17), center + Vector2(0, -40), Color("d3c393"), 3)
		draw_colored_polygon(PackedVector2Array([center + Vector2(2, -36), center + Vector2(25, -7), center + Vector2(2, -7)]), Color("eee2bc"))
		return
	if cavalry:
		draw_colored_polygon(PackedVector2Array([center + Vector2(-34, 9), center + Vector2(22, 9), center + Vector2(30, 24), center + Vector2(-22, 26)]), Color("886b4e"))
		draw_circle(center + Vector2(24, 5), 9, Color("9d7a51"))
	for x in [-18.0, 18.0]:
		draw_line(center + Vector2(x * 0.45, 17), center + Vector2(x * 0.55, 35), Color("35302b"), 5)
	draw_colored_polygon(PackedVector2Array([center + Vector2(-22, -9), center + Vector2(22, -9), center + Vector2(18, 17), center + Vector2(-18, 17)]), owner_tint.darkened(0.15))
	draw_circle(center + Vector2(0, -23), 13, Color("ddc39b"))
	if unit.kind == "villager":
		draw_colored_polygon(PackedVector2Array([center + Vector2(-15, -26), center + Vector2(15, -26), center + Vector2(8, -39), center + Vector2(-8, -39)]), Color("99784a"))
		draw_line(center + Vector2(20, -16), center + Vector2(26, 21), Color("aa8353"), 3)
	else:
		draw_colored_polygon(PackedVector2Array([center + Vector2(-14, -30), center + Vector2(14, -30), center + Vector2(8, -44), center + Vector2(-8, -44)]), Color("acaaa0"))
		draw_line(center + Vector2(-11, -25), center + Vector2(11, -25), Color("615d54"), 2)
		if unit.kind in ["archer", "longbow", "crossbowman", "arbaletrier", "zhuge_nu"]:
			draw_arc(center + Vector2(24, -6), 19, -PI * 0.6, PI * 0.6, 18, Color("d1ba86"), 3)
		else:
			draw_line(center + Vector2(26, 23), center + Vector2(27, -48), Color("c9c8b5"), 3)
			draw_colored_polygon(PackedVector2Array([center + Vector2(27, -51), center + Vector2(21, -38), center + Vector2(33, -38)]), Color("d8d6c0"))

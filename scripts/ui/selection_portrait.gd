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
	var siege: bool = unit.stats.get("tags", []).has("siege")
	draw_colored_polygon(PackedVector2Array([center + Vector2(-32, 39), center + Vector2(-23, 33), center + Vector2(23, 33), center + Vector2(32, 39), center + Vector2(23, 45), center + Vector2(-23, 45)]), Color("1c2524", 0.65))
	if siege:
		_draw_siege(unit.kind, center)
		return
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

func _draw_siege(kind: String, center: Vector2) -> void:
	var timber := Color("9d7449")
	var timber_light := Color("c29b65")
	var iron := Color("383f40")
	var iron_light := Color("78817e")
	var banner := owner_tint.lightened(0.12)
	match kind:
		"battering_ram":
			# A roofed ram with a projecting iron-capped log.
			draw_rect(Rect2(center + Vector2(-27, -3), Vector2(51, 32)), timber)
			for x in [-20.0, 9.0]:
				draw_line(center + Vector2(x, -2), center + Vector2(x, 28), timber_light, 4)
			draw_colored_polygon(PackedVector2Array([center + Vector2(-32, -4), center + Vector2(-23, -23), center + Vector2(18, -23), center + Vector2(29, -4)]), banner.darkened(0.33))
			draw_line(center + Vector2(-24, -13), center + Vector2(20, -13), timber_light, 3)
			draw_line(center + Vector2(-21, 13), center + Vector2(33, 13), timber.darkened(0.25), 11)
			draw_colored_polygon(PackedVector2Array([center + Vector2(29, 5), center + Vector2(37, 7), center + Vector2(37, 19), center + Vector2(29, 21)]), iron_light)
			_draw_siege_wheel(center + Vector2(-19, 31), 7)
			_draw_siege_wheel(center + Vector2(18, 31), 7)
		"trebuchet":
			# Tall A-frame, pivoting arm, hanging counterweight, and sling stone.
			draw_line(center + Vector2(-30, 29), center + Vector2(2, -31), timber_light, 6)
			draw_line(center + Vector2(29, 29), center + Vector2(2, -31), timber_light, 6)
			draw_line(center + Vector2(-27, 28), center + Vector2(30, 28), timber, 7)
			draw_line(center + Vector2(-19, -7), center + Vector2(30, -47), timber.darkened(0.16), 7)
			draw_circle(center + Vector2(2, -22), 5, iron)
			draw_line(center + Vector2(-17, -9), center + Vector2(-17, 2), iron_light, 2)
			draw_rect(Rect2(center + Vector2(-27, 1), Vector2(20, 20)), iron)
			draw_rect(Rect2(center + Vector2(-24, 4), Vector2(14, 4)), banner)
			draw_line(center + Vector2(30, -47), center + Vector2(34, -31), Color("d6c298"), 2)
			draw_circle(center + Vector2(34, -26), 6, Color("858680"))
			_draw_siege_wheel(center + Vector2(-23, 32), 6)
			_draw_siege_wheel(center + Vector2(23, 32), 6)
		"mangonel":
			# A low torsion frame with a short raised throwing spoon.
			draw_colored_polygon(PackedVector2Array([center + Vector2(-31, 5), center + Vector2(22, 5), center + Vector2(29, 27), center + Vector2(-26, 27)]), timber)
			draw_line(center + Vector2(-24, 8), center + Vector2(16, 26), timber_light, 4)
			draw_line(center + Vector2(17, 8), center + Vector2(-16, 26), timber_light, 4)
			draw_circle(center + Vector2(-4, 9), 10, iron)
			draw_line(center + Vector2(-4, 7), center + Vector2(17, -32), timber_light, 7)
			draw_arc(center + Vector2(19, -34), 8, 0.1, PI, 12, iron_light, 4)
			draw_circle(center + Vector2(19, -35), 6, Color("91948d"))
			draw_rect(Rect2(center + Vector2(-26, 0), Vector2(15, 5)), banner)
			_draw_siege_wheel(center + Vector2(-20, 31), 7)
			_draw_siege_wheel(center + Vector2(22, 31), 7)
		"springald":
			# A giant crossbow, seen from above its wheeled firing bed.
			draw_line(center + Vector2(-25, 28), center + Vector2(24, 28), timber, 8)
			draw_colored_polygon(PackedVector2Array([center + Vector2(-8, -12), center + Vector2(8, -12), center + Vector2(13, 24), center + Vector2(-13, 24)]), timber_light)
			draw_line(center + Vector2(-33, -14), center + Vector2(-23, -27), timber, 5)
			draw_line(center + Vector2(-23, -27), center + Vector2(0, -12), timber, 5)
			draw_line(center + Vector2(0, -12), center + Vector2(23, -27), timber, 5)
			draw_line(center + Vector2(23, -27), center + Vector2(33, -14), timber, 5)
			draw_line(center + Vector2(-33, -14), center + Vector2(0, 3), Color("e4d4a4"), 2)
			draw_line(center + Vector2(33, -14), center + Vector2(0, 3), Color("e4d4a4"), 2)
			draw_line(center + Vector2(0, 13), center + Vector2(0, -37), iron, 4)
			draw_colored_polygon(PackedVector2Array([center + Vector2(0, -44), center + Vector2(-6, -32), center + Vector2(6, -32)]), iron_light)
			draw_rect(Rect2(center + Vector2(-8, 17), Vector2(16, 5)), banner)
			_draw_siege_wheel(center + Vector2(-22, 30), 7)
			_draw_siege_wheel(center + Vector2(22, 30), 7)
		"bombard":
			# A compact, heavy, upturned bombarding tube on a handcart.
			draw_line(center + Vector2(-30, 28), center + Vector2(25, 28), timber, 8)
			draw_line(center + Vector2(-20, 25), center + Vector2(14, -5), timber_light, 6)
			draw_line(center + Vector2(-9, 17), center + Vector2(24, -30), iron, 20)
			draw_line(center + Vector2(20, -34), center + Vector2(29, -22), iron_light, 8)
			draw_line(center + Vector2(-2, 7), center + Vector2(9, -8), Color("b89251"), 4)
			draw_rect(Rect2(center + Vector2(-27, 20), Vector2(12, 5)), banner)
			_draw_siege_wheel(center + Vector2(-21, 31), 8)
			_draw_siege_wheel(center + Vector2(19, 31), 8)
		"cannon":
			# A long level bronze gun with a wide muzzle and spoked field wheels.
			draw_colored_polygon(PackedVector2Array([center + Vector2(-23, 2), center + Vector2(16, 5), center + Vector2(12, 28), center + Vector2(-28, 28)]), timber.darkened(0.1))
			draw_line(center + Vector2(-26, -7), center + Vector2(27, -22), Color("8d744a"), 13)
			draw_line(center + Vector2(29, -27), center + Vector2(32, -16), Color("c7a96d"), 7)
			for x in [-15.0, 5.0]:
				draw_line(center + Vector2(x, -11), center + Vector2(x + 3, 0), iron, 3)
			draw_line(center + Vector2(-31, 27), center + Vector2(-37, 36), timber_light, 4)
			draw_rect(Rect2(center + Vector2(-23, 21), Vector2(13, 5)), banner)
			_draw_siege_wheel(center + Vector2(-18, 28), 10)
			_draw_siege_wheel(center + Vector2(17, 28), 10)
		"nest_of_bees":
			# A clustered rocket rack, its many launch mouths defining the silhouette.
			draw_line(center + Vector2(-23, 29), center + Vector2(21, 29), timber, 8)
			draw_line(center + Vector2(-16, 25), center + Vector2(12, -13), timber_light, 5)
			draw_colored_polygon(PackedVector2Array([center + Vector2(-26, -16), center + Vector2(17, -34), center + Vector2(29, -5), center + Vector2(-15, 12)]), timber.darkened(0.16))
			for row in range(3):
				for column in range(4):
					var mouth := center + Vector2(-11 + column * 8 + row * 4, -17 + row * 9)
					draw_circle(mouth, 3.1, iron)
					draw_circle(mouth, 1.3, Color("cc8153"))
			draw_line(center + Vector2(-24, -15), center + Vector2(17, -33), banner, 3)
			_draw_siege_wheel(center + Vector2(-19, 31), 7)
			_draw_siege_wheel(center + Vector2(19, 31), 7)
		"siege_tower":
			# A tall armored tower with a front gate and folding assault bridge.
			draw_rect(Rect2(center + Vector2(-25, -35), Vector2(50, 66)), timber)
			for x in [-21.0, -9.0, 3.0, 15.0]:
				draw_line(center + Vector2(x, -34), center + Vector2(x, 29), timber_light.darkened(0.1), 2)
			draw_rect(Rect2(center + Vector2(-29, -43), Vector2(58, 10)), timber.darkened(0.27))
			for x in [-24.0, -7.0, 10.0, 23.0]:
				draw_rect(Rect2(center + Vector2(x, -49), Vector2(8, 9)), timber_light)
			draw_rect(Rect2(center + Vector2(-13, -26), Vector2(26, 17)), iron)
			draw_line(center + Vector2(-25, -5), center + Vector2(25, -5), banner, 6)
			draw_rect(Rect2(center + Vector2(-11, 4), Vector2(22, 26)), timber.darkened(0.38))
			draw_line(center + Vector2(0, 5), center + Vector2(0, 29), iron_light, 2)
			_draw_siege_wheel(center + Vector2(-20, 32), 7)
			_draw_siege_wheel(center + Vector2(20, 32), 7)

func _draw_siege_wheel(position: Vector2, radius: float) -> void:
	draw_circle(position, radius, Color("2f302c"))
	draw_circle(position, radius - 2.0, Color("80613e"))
	for direction in [Vector2.LEFT, Vector2.UP, Vector2.RIGHT, Vector2.DOWN]:
		draw_line(position, position + direction * (radius - 2.0), Color("c4a773"), 1.5)
	draw_circle(position, 2.2, Color("d0b886"))

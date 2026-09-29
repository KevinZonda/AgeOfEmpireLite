extends RefCounted
const FilledPolygon = preload("res://scripts/entities/visuals/filled_polygon.gd")

# Drawn inside RtsUnit._draw_isometric() after its upright transform is set.
# Coordinates are screen-facing pixels with the unit's ground point at (0, 0).
# The caller owns the draw transform and restores it for status overlays.
static func draw(unit: Node2D, kind: String, radius: float, owner_color: Color, swing: float = 0.0) -> void:
	match kind:
		"battering_ram": _draw_ram(unit, radius, owner_color, swing)
		"trebuchet": _draw_trebuchet(unit, radius, owner_color, swing)
		"mangonel": _draw_mangonel(unit, radius, owner_color, swing)
		"springald": _draw_springald(unit, radius, owner_color, swing)
		"bombard": _draw_bombard(unit, radius, owner_color, swing)
		"cannon": _draw_cannon(unit, radius, owner_color, swing)
		"nest_of_bees": _draw_nest_of_bees(unit, radius, owner_color, swing)
		"siege_tower": _draw_siege_tower(unit, radius, owner_color, swing)

static func overlay_y(kind: String) -> float:
	match kind:
		"siege_tower": return -77.0
		"trebuchet": return -58.0
		"nest_of_bees": return -47.0
		"springald", "mangonel": return -43.0
		_: return -38.0

static func _beam(unit: Node2D, start: Vector2, finish: Vector2, width: float, wood := Color("a3794f")) -> void:
	unit.draw_line(start, finish, Color("392b25"), width + 2.0, true)
	unit.draw_line(start, finish, wood, width, true)

static func _wheel(unit: Node2D, center: Vector2, size: float) -> void:
	unit.draw_circle(center, size + 1.0, Color("272826"))
	unit.draw_circle(center, size - 0.3, Color("765236"))
	unit.draw_arc(center, size - 0.5, 0.0, TAU, 16, Color("b58a5a"), 1.1, true)
	for spoke in 6:
		var angle := TAU * float(spoke) / 6.0
		unit.draw_line(center, center + Vector2(cos(angle), sin(angle)) * (size - 1.0), Color("d2aa74"), 0.9, true)
	unit.draw_circle(center, 1.7, Color("393631"))

static func _chassis(unit: Node2D, radius: float, owner_color: Color, wheel_size := 5.0) -> void:
	var half_width := radius * 0.78
	FilledPolygon.draw(unit, PackedVector2Array([
		Vector2(-half_width, -9), Vector2(half_width - 2.0, -9),
		Vector2(half_width + 2.0, -4), Vector2(-half_width + 2.0, -4)
	]), Color("49392a"))
	unit.draw_rect(Rect2(-half_width + 1.0, -10.0, half_width * 1.9, 3.0), Color("aa8255"))
	unit.draw_line(Vector2(-half_width + 3.0, -7.0), Vector2(half_width, -7.0), owner_color.darkened(0.24), 2.0)
	_wheel(unit, Vector2(-half_width + 2.5, -2.0), wheel_size)
	_wheel(unit, Vector2(half_width - 2.0, -2.0), wheel_size)

static func _draw_ram(unit: Node2D, radius: float, owner_color: Color, swing: float) -> void:
	# A low roof shields the crew; the iron-capped beam extends past it.
	_chassis(unit, radius, owner_color, 4.6)
	_beam(unit, Vector2(-14.0, -13.0), Vector2(22.0 + swing * 3.0, -13.0), 5.0, Color("916541"))
	FilledPolygon.draw(unit, PackedVector2Array([
		Vector2(21.0 + swing * 3.0, -17.0), Vector2(29.0 + swing * 3.0, -14.0),
		Vector2(27.0 + swing * 3.0, -10.0), Vector2(21.0 + swing * 3.0, -9.0)
	]), Color("657073"))
	FilledPolygon.draw(unit, PackedVector2Array([
		Vector2(-16.0, -17.0), Vector2(-6.0, -25.0), Vector2(12.0, -25.0),
		Vector2(17.0, -18.0), Vector2(15.0, -7.0), Vector2(-16.0, -7.0)
	]), Color("765638"))
	FilledPolygon.draw(unit, PackedVector2Array([
		Vector2(-18.0, -18.0), Vector2(-7.0, -28.0), Vector2(13.0, -28.0),
		Vector2(18.0, -19.0), Vector2(13.0, -22.0), Vector2(-7.0, -22.0)
	]), owner_color.darkened(0.27))
	for x in [-11.0, -3.0, 5.0, 13.0]:
		unit.draw_line(Vector2(x, -22.0), Vector2(x - 3.0, -10.0), Color("b18a5d"), 1.5)
	unit.draw_line(Vector2(-15.0, -18.0), Vector2(15.0, -18.0), Color("cfac79"), 1.5)
	_wheel(unit, Vector2(-11.0, -2.0), 4.5)
	_wheel(unit, Vector2(12.0, -2.0), 4.5)

static func _draw_trebuchet(unit: Node2D, radius: float, owner_color: Color, swing: float) -> void:
	# Tall A-frame, unequal throwing arm, hanging counterweight and sling.
	_chassis(unit, radius, owner_color, 4.3)
	_beam(unit, Vector2(-16.0, -8.0), Vector2(0.0, -33.0), 3.2)
	_beam(unit, Vector2(16.0, -8.0), Vector2(0.0, -33.0), 3.2)
	_beam(unit, Vector2(-13.0, -12.0), Vector2(11.0, -23.0), 2.1)
	_beam(unit, Vector2(12.0, -12.0), Vector2(-9.0, -23.0), 2.1)
	var tip := Vector2(18.0 - swing * 7.0, -48.0 + swing * 6.0)
	_beam(unit, Vector2(-8.0, -24.0), tip, 3.7, Color("bf9561"))
	unit.draw_circle(Vector2(0.0, -33.0), 2.6, Color("44413a"))
	unit.draw_line(Vector2(-8.0, -24.0), Vector2(-8.0, -35.0), Color("ded0a5"), 1.4)
	FilledPolygon.draw(unit, PackedVector2Array([
		Vector2(-13.0, -24.0), Vector2(-3.0, -24.0),
		Vector2(-5.0, -14.0), Vector2(-12.0, -14.0)
	]), owner_color.darkened(0.26))
	unit.draw_line(tip, tip + Vector2(2.0, 5.0), Color("d3bf93"), 1.4)
	unit.draw_circle(tip + Vector2(2.0, 6.0), 3.2, Color("77776d"))
	unit.draw_rect(Rect2(-5.0, -9.0, 10.0, 2.0), owner_color.darkened(0.15))

static func _draw_mangonel(unit: Node2D, radius: float, owner_color: Color, swing: float) -> void:
	# Compact torsion cart with a forward throwing spoon and visible stone.
	_chassis(unit, radius, owner_color, 5.0)
	_beam(unit, Vector2(-12.0, -9.0), Vector2(-4.0, -23.0), 3.0)
	_beam(unit, Vector2(13.0, -9.0), Vector2(-4.0, -23.0), 3.0)
	unit.draw_circle(Vector2(-4.0, -23.0), 4.1, Color("4d3c2c"))
	var cup := Vector2(9.0 - swing * 4.0, -32.0 + swing * 4.0)
	_beam(unit, Vector2(-4.0, -23.0), cup, 3.3, Color("c29c68"))
	unit.draw_arc(cup, 6.0, 0.2, PI - 0.15, 10, Color("c9a16b"), 2.8, true)
	unit.draw_circle(cup + Vector2(0.0, -1.0), 4.2, Color("77756a"))
	unit.draw_circle(cup + Vector2(-1.0, -2.0), 1.0, Color("b9b7a7"))
	unit.draw_line(Vector2(-12.0, -17.0), Vector2(11.0, -17.0), owner_color.darkened(0.25), 3.0)
	unit.draw_circle(Vector2(-4.0, -17.0), 3.0, Color("554331"))

static func _draw_springald(unit: Node2D, radius: float, owner_color: Color, swing: float) -> void:
	# The wide bow and central bolt make this read as a giant crossbow.
	_chassis(unit, radius, owner_color, 4.5)
	_beam(unit, Vector2(-4.0, -8.0), Vector2(0.0, -30.0), 4.0)
	_beam(unit, Vector2(-13.0, -8.0), Vector2(0.0, -21.0), 2.7)
	_beam(unit, Vector2(13.0, -8.0), Vector2(0.0, -21.0), 2.7)
	unit.draw_line(Vector2(-21.0, -26.0), Vector2(-13.0, -20.0), Color("a57b50"), 3.6, true)
	unit.draw_line(Vector2(-13.0, -20.0), Vector2(0.0, -22.0), Color("c6a071"), 3.6, true)
	unit.draw_line(Vector2(0.0, -22.0), Vector2(13.0, -20.0), Color("c6a071"), 3.6, true)
	unit.draw_line(Vector2(13.0, -20.0), Vector2(21.0, -26.0), Color("a57b50"), 3.6, true)
	unit.draw_line(Vector2(-21.0, -26.0), Vector2(0.0, -20.0 + swing * 4.0), Color("e2d3a9"), 1.4, true)
	unit.draw_line(Vector2(21.0, -26.0), Vector2(0.0, -20.0 + swing * 4.0), Color("e2d3a9"), 1.4, true)
	unit.draw_line(Vector2(0.0, -12.0), Vector2(0.0, -33.0), Color("676c65"), 2.2)
	FilledPolygon.draw(unit, PackedVector2Array([
		Vector2(-3.0, -29.0), Vector2(0.0, -35.0), Vector2(3.0, -29.0)
	]), Color("c6cac2"))
	unit.draw_rect(Rect2(-8.0, -13.0, 16.0, 3.5), owner_color.darkened(0.13))

static func _draw_bombard(unit: Node2D, radius: float, owner_color: Color, swing: float) -> void:
	# A short, heavy hand cannon rides a low push cart.
	_chassis(unit, radius, owner_color, 4.0)
	_beam(unit, Vector2(-19.0, -9.0), Vector2(-26.0, -15.0), 2.1)
	_beam(unit, Vector2(-15.0, -6.0), Vector2(-24.0, -9.0), 2.1)
	FilledPolygon.draw(unit, PackedVector2Array([
		Vector2(-11.0, -17.0), Vector2(11.0, -20.0),
		Vector2(16.0, -15.0), Vector2(-8.0, -12.0)
	]), Color("886b42"))
	FilledPolygon.draw(unit, PackedVector2Array([
		Vector2(-8.0, -23.0), Vector2(9.0, -24.0),
		Vector2(16.0 + swing * 2.0, -20.0), Vector2(16.0 + swing * 2.0, -14.0),
		Vector2(-7.0, -15.0)
	]), Color("927644"))
	unit.draw_line(Vector2(-5.0, -21.0), Vector2(12.0, -21.0), Color("c3a56f"), 1.5)
	unit.draw_circle(Vector2(16.0 + swing * 2.0, -17.0), 5.0, Color("5a5444"))
	unit.draw_circle(Vector2(16.0 + swing * 2.0, -17.0), 2.6, Color("252927"))
	unit.draw_line(Vector2(-9.0, -13.0), Vector2(8.0, -13.0), owner_color, 4.0)

static func _draw_cannon(unit: Node2D, radius: float, owner_color: Color, swing: float) -> void:
	# Long iron barrel, large spoked wheels and rear trail, unlike the bombard.
	_beam(unit, Vector2(-22.0, -3.0), Vector2(7.0, -12.0), 3.8)
	FilledPolygon.draw(unit, PackedVector2Array([
		Vector2(-14.0, -15.0), Vector2(12.0, -19.0),
		Vector2(17.0, -12.0), Vector2(-10.0, -9.0)
	]), Color("966e43"))
	unit.draw_line(Vector2(-13.0, -12.0), Vector2(12.0, -15.0), owner_color.darkened(0.22), 3.6)
	FilledPolygon.draw(unit, PackedVector2Array([
		Vector2(-10.0, -24.0), Vector2(20.0 + swing * 2.0, -28.0),
		Vector2(22.0 + swing * 2.0, -20.0), Vector2(-10.0, -16.0)
	]), Color("444a49"))
	unit.draw_line(Vector2(-8.0, -22.0), Vector2(18.0, -25.0), Color("818b85"), 1.4)
	unit.draw_line(Vector2(15.0 + swing * 2.0, -28.0), Vector2(19.0 + swing * 2.0, -20.0), Color("9fa9a0"), 2.8)
	unit.draw_circle(Vector2(-8.0, -20.0), 4.0, Color("333a39"))
	_wheel(unit, Vector2(-7.0, -2.0), 6.5)
	_wheel(unit, Vector2(10.0, -3.0), 6.5)

static func _draw_nest_of_bees(unit: Node2D, radius: float, owner_color: Color, swing: float) -> void:
	# Angled rack of many visible rocket tubes on a wheeled frame.
	_chassis(unit, radius, owner_color, 4.5)
	_beam(unit, Vector2(-11.0, -8.0), Vector2(-4.0, -21.0), 3.0)
	_beam(unit, Vector2(11.0, -8.0), Vector2(4.0, -21.0), 3.0)
	FilledPolygon.draw(unit, PackedVector2Array([
		Vector2(-12.0, -35.0), Vector2(11.0, -39.0),
		Vector2(14.0, -18.0), Vector2(-9.0, -15.0)
	]), Color("49382c"))
	FilledPolygon.draw(unit, PackedVector2Array([
		Vector2(-10.0, -33.0), Vector2(9.0, -36.0),
		Vector2(11.0, -20.0), Vector2(-7.0, -18.0)
	]), owner_color.darkened(0.35))
	for row in 3:
		for column in 4:
			var tube := Vector2(-6.6 + float(column) * 4.7, -31.0 + float(row) * 5.0 - float(column) * 0.55)
			unit.draw_circle(tube, 1.8, Color("c69b65"))
			unit.draw_circle(tube, 1.0, Color("322c26"))
	unit.draw_line(Vector2(-10.0, -34.0), Vector2(11.0, -38.0), Color("d0ad75"), 1.5)
	unit.draw_line(Vector2(-8.0, -17.0), Vector2(13.0, -20.0), Color("d0ad75"), 1.5)
	unit.draw_rect(Rect2(-7.0, -12.0, 14.0, 2.0), owner_color)

static func _draw_siege_tower(unit: Node2D, radius: float, owner_color: Color, swing: float) -> void:
	# A tall boarded tower with battlements, ladder and lowered assault ramp.
	var half_width := radius * 0.72
	FilledPolygon.draw(unit, PackedVector2Array([
		Vector2(-half_width, -52.0), Vector2(half_width - 2.0, -52.0),
		Vector2(half_width + 2.0, -9.0), Vector2(-half_width, -9.0)
	]), Color("765639"))
	FilledPolygon.draw(unit, PackedVector2Array([
		Vector2(half_width - 2.0, -52.0), Vector2(half_width + 4.0, -47.0),
		Vector2(half_width + 6.0, -8.0), Vector2(half_width + 2.0, -9.0)
	]), Color("4b3628"))
	for y in [-46.0, -37.0, -28.0, -19.0, -10.0]:
		unit.draw_line(Vector2(-half_width + 1.0, y), Vector2(half_width, y), Color("ae8556"), 1.4)
	for x in [-8.0, 0.0, 8.0]:
		unit.draw_line(Vector2(x, -49.0), Vector2(x, -11.0), Color("493827"), 1.0)
	unit.draw_rect(Rect2(-half_width - 1.0, -58.0, half_width * 2.0 + 2.0, 6.0), Color("4a3829"))
	for x in [-12.0, -3.0, 6.0]:
		unit.draw_rect(Rect2(x, -62.0, 6.0, 7.0), Color("6e5338"))
	FilledPolygon.draw(unit, PackedVector2Array([
		Vector2(half_width - 1.0, -44.0), Vector2(half_width + 16.0 + swing * 2.0, -38.0),
		Vector2(half_width + 17.0 + swing * 2.0, -34.0), Vector2(half_width, -39.0)
	]), Color("a77a4b"))
	_beam(unit, Vector2(-7.0, -10.0), Vector2(-7.0, -43.0), 1.2, Color("d4b27c"))
	_beam(unit, Vector2(5.0, -10.0), Vector2(5.0, -43.0), 1.2, Color("d4b27c"))
	for y in [-14.0, -20.0, -26.0, -32.0, -38.0]:
		unit.draw_line(Vector2(-7.0, y), Vector2(5.0, y), Color("d4b27c"), 1.6)
	unit.draw_rect(Rect2(-half_width + 2.0, -53.0, half_width * 1.35, 3.0), owner_color)
	unit.draw_line(Vector2(0.0, -61.0), Vector2(0.0, -69.0), Color("d9c79e"), 1.5)
	FilledPolygon.draw(unit, PackedVector2Array([
		Vector2(0.0, -69.0), Vector2(10.0, -66.0), Vector2(0.0, -63.0)
	]), owner_color)
	_wheel(unit, Vector2(-half_width + 3.0, -4.0), 4.7)
	_wheel(unit, Vector2(half_width - 2.0, -4.0), 4.7)

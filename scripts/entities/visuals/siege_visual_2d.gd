extends RefCounted
class_name RtsSiegeVisual2D

# Called from RtsUnit._draw() after its motion transform has been set. The
# machines face toward the top of the screen, matching the other 2D units.
const WOOD_DARK := Color("473227")
const WOOD := Color("79563a")
const WOOD_LIGHT := Color("b58b5b")
const IRON := Color("333d3d")
const IRON_LIGHT := Color("8d9790")
const ROPE := Color("dfc99b")

static func draw(unit: Node2D, kind: String, radius: float, team_color: Color, swing: float = 0.0) -> void:
	match kind:
		"battering_ram":
			_ram(unit, radius, team_color, swing)
		"trebuchet":
			_trebuchet(unit, radius, team_color, swing)
		"mangonel":
			_mangonel(unit, radius, team_color, swing)
		"springald":
			_springald(unit, radius, team_color, swing)
		"bombard":
			_bombard(unit, radius, team_color, swing)
		"cannon":
			_cannon(unit, radius, team_color, swing)
		"nest_of_bees":
			_nest_of_bees(unit, radius, team_color, swing)
		"siege_tower":
			_siege_tower(unit, radius, team_color)

static func _poly(unit: Node2D, points: Array, color: Color) -> void:
	unit.draw_colored_polygon(PackedVector2Array(points), color)

static func _wheel(unit: Node2D, center: Vector2, size: float = 4.0) -> void:
	unit.draw_circle(center, size + 0.8, WOOD_DARK)
	unit.draw_circle(center, size - 0.3, WOOD)
	unit.draw_line(center + Vector2(-size + 1.2, 0), center + Vector2(size - 1.2, 0), WOOD_LIGHT, 1.0)
	unit.draw_line(center + Vector2(0, -size + 1.2), center + Vector2(0, size - 1.2), WOOD_LIGHT, 1.0)
	unit.draw_circle(center, 1.5, IRON)

static func _base(unit: Node2D, radius: float, team_color: Color, narrow: bool = false) -> void:
	var side := radius - (9.0 if narrow else 6.0)
	_wheel(unit, Vector2(-radius + 4.0, 9.5), 3.6 if narrow else 4.2)
	_wheel(unit, Vector2(radius - 4.0, 9.5), 3.6 if narrow else 4.2)
	_poly(unit, [Vector2(-side, -9), Vector2(side, -9), Vector2(side + 1, 9), Vector2(-side - 1, 9)], WOOD_DARK)
	unit.draw_rect(Rect2(-side + 2, -7, side * 2 - 4, 13), WOOD)
	unit.draw_line(Vector2(-side + 1, 5), Vector2(side - 1, 5), WOOD_LIGHT, 1.5)
	unit.draw_rect(Rect2(-side + 1, 7, side * 2 - 2, 2), team_color.darkened(0.18))

static func _ram(unit: Node2D, radius: float, team_color: Color, swing: float) -> void:
	# Armored, pitched roof and a pointed iron ram protruding from its front.
	_base(unit, radius, team_color)
	var log_tip := -radius - 2.0 - swing * 3.0
	unit.draw_line(Vector2(0, 9), Vector2(0, log_tip + 3), WOOD_DARK, 6.5)
	unit.draw_line(Vector2(0, 8), Vector2(0, log_tip + 3), WOOD_LIGHT, 3.0)
	_poly(unit, [Vector2(-4, log_tip + 5), Vector2(4, log_tip + 5), Vector2(2.5, log_tip), Vector2(0, log_tip - 3), Vector2(-2.5, log_tip)], IRON)
	unit.draw_line(Vector2(-2.5, log_tip + 3), Vector2(0, log_tip - 2), IRON_LIGHT, 1.2)
	_poly(unit, [Vector2(-13, -14), Vector2(0, -19), Vector2(13, -14), Vector2(12, 7), Vector2(-12, 7)], WOOD_DARK)
	_poly(unit, [Vector2(-11, -12), Vector2(0, -17), Vector2(0, 5), Vector2(-11, 5)], WOOD)
	_poly(unit, [Vector2(0, -17), Vector2(11, -12), Vector2(11, 5), Vector2(0, 5)], WOOD_LIGHT)
	for y in [-10.0, -3.0, 4.0]:
		unit.draw_line(Vector2(-11, y), Vector2(11, y), WOOD_DARK, 1.2)
	unit.draw_line(Vector2(0, -16), Vector2(0, 4), team_color.darkened(0.2), 2.0)
	unit.draw_circle(Vector2(0, 4), 1.5, IRON)

static func _trebuchet(unit: Node2D, radius: float, team_color: Color, swing: float) -> void:
	# A tall A-frame, long throwing arm, sling stone and low counterweight.
	_base(unit, radius, team_color)
	unit.draw_line(Vector2(-11, 7), Vector2(0, -12), WOOD_DARK, 5.0)
	unit.draw_line(Vector2(11, 7), Vector2(0, -12), WOOD_DARK, 5.0)
	unit.draw_line(Vector2(-10, 6), Vector2(0, -10), WOOD_LIGHT, 2.2)
	unit.draw_line(Vector2(10, 6), Vector2(0, -10), WOOD_LIGHT, 2.2)
	unit.draw_line(Vector2(-8, 1), Vector2(8, 1), team_color.darkened(0.2), 2.5)
	var arm_end := Vector2(13 - swing * 3.0, -21 + swing * 3.0)
	unit.draw_line(Vector2(-8, 11), arm_end, WOOD_DARK, 5.0)
	unit.draw_line(Vector2(-7, 9), arm_end, WOOD_LIGHT, 2.2)
	_poly(unit, [Vector2(-13, 7), Vector2(-5, 6), Vector2(-4, 14), Vector2(-12, 15)], IRON)
	unit.draw_line(arm_end, arm_end + Vector2(2, 3), ROPE, 1.1)
	unit.draw_circle(arm_end + Vector2(2, 4), 3.1, Color("5c5f58"))
	unit.draw_circle(Vector2(0, -11), 2.5, IRON)

static func _mangonel(unit: Node2D, radius: float, team_color: Color, swing: float) -> void:
	# Compact catapult: short raised arm ending in a shallow stone cup.
	_base(unit, radius, team_color)
	unit.draw_line(Vector2(-10, 5), Vector2(-5, -11), WOOD_LIGHT, 3.5)
	unit.draw_line(Vector2(10, 5), Vector2(5, -11), WOOD_LIGHT, 3.5)
	unit.draw_line(Vector2(-7, -9), Vector2(7, -9), WOOD_DARK, 3.0)
	unit.draw_line(Vector2(0, 8), Vector2(5 + swing * 2.0, -14 - swing * 2.0), WOOD_DARK, 5.5)
	unit.draw_line(Vector2(0, 7), Vector2(5 + swing * 2.0, -14 - swing * 2.0), WOOD_LIGHT, 2.5)
	_poly(unit, [Vector2(-1 + swing * 2.0, -13 - swing * 2.0), Vector2(11 + swing * 2.0, -14 - swing * 2.0), Vector2(9 + swing * 2.0, -19 - swing * 2.0), Vector2(1 + swing * 2.0, -19 - swing * 2.0)], WOOD_DARK)
	unit.draw_circle(Vector2(5 + swing * 2.0, -16 - swing * 2.0), 3.4, Color("686a61"))
	unit.draw_line(Vector2(-9, -9), Vector2(9, -9), team_color, 1.5)

static func _springald(unit: Node2D, radius: float, team_color: Color, swing: float) -> void:
	# Oversized horizontal bow and one heavy central bolt.
	_base(unit, radius, team_color, true)
	unit.draw_line(Vector2(0, 9), Vector2(0, -13), WOOD_DARK, 5.5)
	unit.draw_line(Vector2(0, 7), Vector2(0, -13), WOOD_LIGHT, 2.4)
	_poly(unit, [Vector2(-radius + 1, -10), Vector2(-13, -17), Vector2(-7, -18), Vector2(0, -13), Vector2(7, -18), Vector2(13, -17), Vector2(radius - 1, -10), Vector2(12, -12), Vector2(0, -10), Vector2(-12, -12)], WOOD)
	unit.draw_line(Vector2(-radius + 1, -10), Vector2(0, -5 + swing * 2.0), ROPE, 1.4)
	unit.draw_line(Vector2(radius - 1, -10), Vector2(0, -5 + swing * 2.0), ROPE, 1.4)
	unit.draw_line(Vector2(0, 7), Vector2(0, -21), IRON_LIGHT, 2.1)
	_poly(unit, [Vector2(-3, -18), Vector2(0, -24), Vector2(3, -18)], IRON)
	unit.draw_circle(Vector2(0, -10), 2.3, team_color)

static func _bombard(unit: Node2D, radius: float, team_color: Color, swing: float) -> void:
	# Hand-pushed bombard: short bronze barrel, broad muzzle and rear handles.
	_base(unit, radius, team_color, true)
	unit.draw_line(Vector2(-8, 6), Vector2(-10, 17), WOOD_LIGHT, 2.5)
	unit.draw_line(Vector2(8, 6), Vector2(10, 17), WOOD_LIGHT, 2.5)
	unit.draw_line(Vector2(-14, 17), Vector2(-8, 17), WOOD_DARK, 2.3)
	unit.draw_line(Vector2(8, 17), Vector2(14, 17), WOOD_DARK, 2.3)
	_poly(unit, [Vector2(-5, 9), Vector2(5, 9), Vector2(8, -13 - swing * 1.5), Vector2(-8, -13 - swing * 1.5)], Color("806b48"))
	_poly(unit, [Vector2(-4, 7), Vector2(4, 7), Vector2(6, -12), Vector2(-6, -12)], Color("b79b61"))
	unit.draw_rect(Rect2(-9, -17 - swing * 1.5, 18, 5), Color("8f744e"))
	unit.draw_line(Vector2(-7, -16 - swing * 1.5), Vector2(7, -16 - swing * 1.5), Color("d2b576"), 1.4)
	unit.draw_circle(Vector2(0, -17 - swing * 1.5), 3.2, IRON)
	unit.draw_rect(Rect2(-5, 3, 10, 3), team_color.darkened(0.15))

static func _cannon(unit: Node2D, radius: float, team_color: Color, swing: float) -> void:
	# Long iron cannon on large spoked wheels and a tapered wooden trail.
	_wheel(unit, Vector2(-14, 2), 5.2)
	_wheel(unit, Vector2(14, 2), 5.2)
	_poly(unit, [Vector2(-9, 0), Vector2(9, 0), Vector2(5, 17), Vector2(-5, 17)], WOOD_DARK)
	unit.draw_line(Vector2(-7, 4), Vector2(-3, 15), WOOD_LIGHT, 2.0)
	unit.draw_line(Vector2(7, 4), Vector2(3, 15), WOOD_LIGHT, 2.0)
	_poly(unit, [Vector2(-5, 8), Vector2(5, 8), Vector2(4, -19 - swing * 2.0), Vector2(-4, -19 - swing * 2.0)], IRON)
	unit.draw_line(Vector2(-2, 5), Vector2(-2, -18), IRON_LIGHT, 1.3)
	unit.draw_rect(Rect2(-7, -21 - swing * 2.0, 14, 4), IRON)
	unit.draw_circle(Vector2(0, -21 - swing * 2.0), 3.0, Color("171d1d"))
	unit.draw_rect(Rect2(-6, 3, 12, 3), team_color)
	unit.draw_circle(Vector2(0, 11), 2.2, Color("171d1d"))

static func _nest_of_bees(unit: Node2D, radius: float, team_color: Color, swing: float) -> void:
	# A rack of parallel fire arrows; the red fletching reads at unit scale.
	_base(unit, radius, team_color)
	_poly(unit, [Vector2(-12, 4), Vector2(12, 4), Vector2(10, -18), Vector2(-10, -18)], WOOD_DARK)
	unit.draw_rect(Rect2(-9, -17, 18, 19), Color("69503a"))
	for x in [-6.0, -3.0, 0.0, 3.0, 6.0]:
		unit.draw_line(Vector2(x, 1), Vector2(x, -16 - swing * 2.0), ROPE, 1.1)
		_poly(unit, [Vector2(x - 1.3, -14 - swing * 2.0), Vector2(x, -20 - swing * 2.0), Vector2(x + 1.3, -14 - swing * 2.0)], Color("c64d37"))
		unit.draw_line(Vector2(x - 1.2, -1), Vector2(x + 1.2, 2), team_color.darkened(0.1), 1.0)
	unit.draw_line(Vector2(-12, 4), Vector2(-10, -18), WOOD_LIGHT, 2.0)
	unit.draw_line(Vector2(12, 4), Vector2(10, -18), WOOD_LIGHT, 2.0)

static func _siege_tower(unit: Node2D, radius: float, team_color: Color) -> void:
	# Stacked tower decks, side braces, ladder and forward assault bridge.
	_wheel(unit, Vector2(-radius + 4, 11), 4.1)
	_wheel(unit, Vector2(radius - 4, 11), 4.1)
	_poly(unit, [Vector2(-13, 13), Vector2(13, 13), Vector2(11, -17), Vector2(-11, -17)], WOOD_DARK)
	unit.draw_rect(Rect2(-10, -16, 20, 26), WOOD)
	unit.draw_line(Vector2(-10, -11), Vector2(10, -11), WOOD_LIGHT, 2.0)
	unit.draw_line(Vector2(-10, 1), Vector2(10, 1), WOOD_LIGHT, 2.0)
	unit.draw_line(Vector2(-11, 10), Vector2(11, -15), WOOD_DARK, 2.0)
	unit.draw_line(Vector2(11, 10), Vector2(-11, -15), WOOD_DARK, 2.0)
	unit.draw_line(Vector2(-4, 9), Vector2(-4, -10), IRON, 1.5)
	unit.draw_line(Vector2(4, 9), Vector2(4, -10), IRON, 1.5)
	for y in [-7.0, -3.0, 1.0, 5.0]:
		unit.draw_line(Vector2(-4, y), Vector2(4, y), ROPE, 1.1)
	unit.draw_rect(Rect2(-13, -20, 26, 5), team_color.darkened(0.15))
	for x in [-11.0, -3.0, 5.0]:
		unit.draw_rect(Rect2(x, -23, 6, 5), WOOD_LIGHT)
	_poly(unit, [Vector2(-8, -20), Vector2(8, -20), Vector2(12, -24), Vector2(-12, -24)], WOOD_DARK)
	unit.draw_line(Vector2(-9, -21), Vector2(9, -21), WOOD_LIGHT, 1.2)

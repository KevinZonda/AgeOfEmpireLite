class_name RtsCharacterVisual
extends RefCounted

# Small battlefield silhouettes. The 2D and 2.5D versions share the same
# equipment so a unit remains recognizable when the camera mode changes.
const OUTLINE := Color("202829")
const LEATHER := Color("654835")
const WOOD := Color("9a7148")
const SKIN := Color("dfbd91")
const STEEL := Color("aebfc0")
const STEEL_LIGHT := Color("e1e6dc")
const GOLD := Color("d8ae56")

static func handles(kind: String) -> bool:
	return kind in ["crossbowman", "arbaletrier", "trader", "imperial_official", "horseman", "scout", "knight", "royal_knight", "handcannoneer"]

static func draw_2d(unit: Node2D, kind: String, team: Color, gait: float, swing: float) -> void:
	if kind in ["horseman", "scout", "knight", "royal_knight"]:
		_cavalry_2d(unit, kind, team, swing)
	else:
		_infantry_2d(unit, kind, team, gait, swing)

static func draw_25d(unit: Node2D, kind: String, team: Color, gait: float, swing: float) -> void:
	if kind in ["horseman", "scout", "knight", "royal_knight"]:
		_cavalry_25d(unit, kind, team, swing)
	else:
		_infantry_25d(unit, kind, team, gait, swing)

static func _poly(unit: Node2D, points: Array, fill: Color, stroke: Color = OUTLINE, width: float = 1.5) -> void:
	var shape := PackedVector2Array(points)
	unit.draw_colored_polygon(shape, fill)
	if width > 0.0:
		unit.draw_polyline(shape + PackedVector2Array([shape[0]]), stroke, width)

static func _crossbow(unit: Node2D, center: Vector2, large: bool) -> void:
	var width := 15.0 if large else 12.0
	unit.draw_line(center + Vector2(0, 10), center + Vector2(0, -9), OUTLINE, 4.5)
	unit.draw_line(center + Vector2(0, 9), center + Vector2(0, -9), WOOD, 2.6)
	unit.draw_arc(center + Vector2(0, -7), width, PI * 0.12, PI * 0.88, 14, OUTLINE, 3.0)
	unit.draw_line(center + Vector2(-width * 0.9, -2), center + Vector2(width * 0.9, -2), Color("e1d5b5"), 1.2)
	unit.draw_line(center + Vector2(0, 5), center + Vector2(0, -15), STEEL_LIGHT, 1.3)
	unit.draw_circle(center + Vector2(0, 2), 2.0, LEATHER)

static func _pavise(unit: Node2D, center: Vector2, team: Color, tall: bool) -> void:
	var height := 20.0 if tall else 16.0
	_poly(unit, [center + Vector2(-7, -height * 0.5), center + Vector2(6, -height * 0.5), center + Vector2(7, height * 0.18), center + Vector2(0, height * 0.6), center + Vector2(-7, height * 0.18)], STEEL)
	_poly(unit, [center + Vector2(-4, -height * 0.35), center + Vector2(3, -height * 0.35), center + Vector2(4, height * 0.08), center + Vector2(0, height * 0.35), center + Vector2(-4, height * 0.08)], team.darkened(0.15), OUTLINE, 0.8)
	unit.draw_line(center + Vector2(-5, -height * 0.15), center + Vector2(5, -height * 0.15), GOLD, 1.1)

static func _sword(unit: Node2D, grip: Vector2, swing: float) -> void:
	var tip := grip + Vector2(12 + swing * 8, -19 + swing * 8)
	unit.draw_line(grip, tip, OUTLINE, 4.0)
	unit.draw_line(grip + Vector2(1, -2), tip, STEEL_LIGHT, 2.0)
	unit.draw_line(grip + Vector2(-3, -4), grip + Vector2(5, 0), GOLD, 2.4)
	unit.draw_circle(grip + Vector2(-1, 2), 1.7, LEATHER)

static func _cavalry_2d(unit: Node2D, kind: String, team: Color, swing: float) -> void:
	var heavy := kind in ["knight", "royal_knight"]
	var royal := kind == "royal_knight"
	# Horse, mane, tail and reins remain visible beneath the rider.
	_poly(unit, [Vector2(-20, -7), Vector2(8, -10), Vector2(18, -5), Vector2(18, 7), Vector2(-18, 9)], Color("8d6547"))
	_poly(unit, [Vector2(-18, -5), Vector2(6, -8), Vector2(16, -4), Vector2(16, 5), Vector2(-17, 6)], Color("b18962"), OUTLINE, 0.8)
	unit.draw_line(Vector2(-17, 5), Vector2(-26, 11), LEATHER, 3.0)
	unit.draw_line(Vector2(-12, 7), Vector2(-13, 14), OUTLINE, 3.0)
	unit.draw_line(Vector2(9, 6), Vector2(11, 14), OUTLINE, 3.0)
	unit.draw_circle(Vector2(16, -8), 6.0, OUTLINE)
	unit.draw_circle(Vector2(16, -8), 4.8, Color("b99269"))
	unit.draw_line(Vector2(15, -13), Vector2(11, -9), LEATHER, 2.0)
	unit.draw_circle(Vector2(20, -8), 1.0, OUTLINE)
	if heavy:
		_poly(unit, [Vector2(-18, -8), Vector2(1, -10), Vector2(5, 6), Vector2(-18, 7)], team.darkened(0.2))
		unit.draw_line(Vector2(-15, 4), Vector2(3, 4), GOLD, 1.5)
	# Saddle, rider and helm/cap.
	_poly(unit, [Vector2(-9, -9), Vector2(6, -10), Vector2(8, 4), Vector2(-8, 6)], STEEL if heavy else team.darkened(0.12))
	unit.draw_line(Vector2(-8, 2), Vector2(8, 2), LEATHER, 2.0)
	unit.draw_circle(Vector2(0, -8), 5.7, OUTLINE)
	unit.draw_circle(Vector2(0, -8), 4.3, SKIN)
	if heavy:
		_poly(unit, [Vector2(-6, -11), Vector2(5, -11), Vector2(4, -16), Vector2(-4, -17)], STEEL_LIGHT)
		unit.draw_line(Vector2(-5, -8), Vector2(5, -8), OUTLINE, 1.2)
		if royal: unit.draw_line(Vector2(0, -17), Vector2(1, -21), GOLD, 2.0)
	else:
		_poly(unit, [Vector2(-5, -10), Vector2(5, -10), Vector2(3, -14), Vector2(-3, -14)], team.darkened(0.3))
	if kind == "scout":
		# The scout carries a map case and a spyglass, with no blade.
		unit.draw_line(Vector2(7, -4), Vector2(18, -15), LEATHER, 3.0)
		unit.draw_line(Vector2(15, -13), Vector2(21, -18), GOLD, 2.2)
		unit.draw_circle(Vector2(-8, 3), 4.0, WOOD)
		unit.draw_line(Vector2(-11, 1), Vector2(-5, 5), Color("e4d3aa"), 1.3)
	else:
		_sword(unit, Vector2(8, 2), swing)
		if heavy: _pavise(unit, Vector2(-11, -1), team, false)

static func _cavalry_25d(unit: Node2D, kind: String, team: Color, swing: float) -> void:
	var heavy := kind in ["knight", "royal_knight"]
	var royal := kind == "royal_knight"
	# Side-on horse with separate neck, legs and barding.
	for x in [-13.0, 8.0]:
		unit.draw_line(Vector2(x, -5), Vector2(x - 2, 4), OUTLINE, 4.0)
		unit.draw_line(Vector2(x, -5), Vector2(x - 2, 3), LEATHER, 2.2)
	_poly(unit, [Vector2(-20, -13), Vector2(9, -15), Vector2(16, -11), Vector2(14, -3), Vector2(-19, -3)], Color("9a7452"))
	unit.draw_line(Vector2(-19, -7), Vector2(-28, 0), LEATHER, 3.4)
	_poly(unit, [Vector2(8, -14), Vector2(15, -24), Vector2(20, -23), Vector2(21, -13)], Color("a5805b"))
	_poly(unit, [Vector2(15, -23), Vector2(23, -22), Vector2(25, -17), Vector2(18, -16)], Color("b88d63"))
	unit.draw_circle(Vector2(21, -21), 1.0, OUTLINE)
	unit.draw_line(Vector2(16, -19), Vector2(24, -18), LEATHER, 1.4)
	if heavy:
		_poly(unit, [Vector2(-19, -16), Vector2(7, -17), Vector2(9, -5), Vector2(-18, -5)], team.darkened(0.18))
		unit.draw_line(Vector2(-17, -8), Vector2(8, -8), GOLD, 1.3)
	_poly(unit, [Vector2(-9, -25), Vector2(5, -25), Vector2(8, -12), Vector2(-8, -11)], STEEL if heavy else team.darkened(0.13))
	unit.draw_line(Vector2(-7, -14), Vector2(7, -14), LEATHER, 1.8)
	unit.draw_circle(Vector2(-1, -29), 5.5, OUTLINE)
	unit.draw_circle(Vector2(-1, -29), 4.1, SKIN)
	if heavy:
		_poly(unit, [Vector2(-6, -31), Vector2(5, -31), Vector2(3, -37), Vector2(-4, -37)], STEEL_LIGHT)
		unit.draw_line(Vector2(-5, -29), Vector2(4, -29), OUTLINE, 1.1)
		if royal: unit.draw_line(Vector2(-1, -37), Vector2(1, -42), GOLD, 2.3)
	else:
		_poly(unit, [Vector2(-6, -31), Vector2(5, -31), Vector2(3, -35), Vector2(-5, -35)], team.darkened(0.25))
	if kind == "scout":
		unit.draw_line(Vector2(7, -21), Vector2(17, -30), LEATHER, 3.0)
		unit.draw_line(Vector2(15, -29), Vector2(22, -35), GOLD, 2.0)
		unit.draw_circle(Vector2(-12, -13), 4.0, WOOD)
	else:
		_sword(unit, Vector2(8, -17), swing)
		if heavy: _pavise(unit, Vector2(-11, -20), team, true)

static func _infantry_2d(unit: Node2D, kind: String, team: Color, gait: float, swing: float) -> void:
	var armored := kind == "arbaletrier"
	var official := kind == "imperial_official"
	var trader := kind == "trader"
	var coat := Color("983e36") if official else Color("ad8552") if trader else Color("53636b") if kind == "handcannoneer" else team.darkened(0.14)
	unit.draw_line(Vector2(-5, 5), Vector2(-6 + gait, 15), OUTLINE, 5.0)
	unit.draw_line(Vector2(5, 5), Vector2(6 - gait, 15), OUTLINE, 5.0)
	unit.draw_line(Vector2(-5, 5), Vector2(-6 + gait, 14), LEATHER, 2.6)
	unit.draw_line(Vector2(5, 5), Vector2(6 - gait, 14), LEATHER, 2.6)
	if trader:
		_poly(unit, [Vector2(-14, -11), Vector2(12, -11), Vector2(14, 8), Vector2(-14, 8)], LEATHER)
		unit.draw_rect(Rect2(-12, -9, 8, 10), WOOD)
		unit.draw_rect(Rect2(4, -8, 8, 10), Color("c6a76d"))
	_poly(unit, [Vector2(-8, -8), Vector2(8, -8), Vector2(9, 7), Vector2(-9, 7)], coat)
	unit.draw_line(Vector2(-8, 1), Vector2(8, 1), GOLD if official else LEATHER, 1.7)
	if official:
		unit.draw_line(Vector2(0, -7), Vector2(0, 7), GOLD, 1.6)
		unit.draw_rect(Rect2(-5, 2, 10, 3), Color("c8a352"))
	unit.draw_circle(Vector2(0, -11), 6.5, OUTLINE)
	unit.draw_circle(Vector2(0, -11), 5.1, SKIN)
	if official:
		_poly(unit, [Vector2(-9, -15), Vector2(9, -15), Vector2(5, -20), Vector2(-5, -20)], Color("252b30"))
		unit.draw_line(Vector2(-9, -16), Vector2(9, -16), GOLD, 1.3)
		unit.draw_rect(Rect2(9, -3, 9, 13), Color("e0cfa5"))
		unit.draw_line(Vector2(12, -2), Vector2(12, 8), Color("bd6c41"), 1.4)
	elif trader:
		_poly(unit, [Vector2(-7, -13), Vector2(7, -13), Vector2(5, -18), Vector2(-5, -18)], Color("846344"))
		unit.draw_circle(Vector2(12, 6), 4.5, Color("d7b576"))
		unit.draw_circle(Vector2(12, 6), 2.0, GOLD)
		unit.draw_line(Vector2(14, 2), Vector2(16, -15), WOOD, 2.0)
	elif kind == "handcannoneer":
		_poly(unit, [Vector2(-6, -14), Vector2(6, -14), Vector2(5, -18), Vector2(-5, -18)], Color("4e5250"))
		unit.draw_line(Vector2(6, 5), Vector2(18 + swing * 4, -17), OUTLINE, 7.0)
		unit.draw_line(Vector2(7, 4), Vector2(18 + swing * 4, -17), Color("666e6d"), 4.5)
		unit.draw_circle(Vector2(18 + swing * 4, -17), 3.2, OUTLINE)
		unit.draw_circle(Vector2(18 + swing * 4, -17), 1.8, Color("cfd5ca"))
		unit.draw_line(Vector2(7, 2), Vector2(13, -8), WOOD, 2.4)
		unit.draw_circle(Vector2(-10, 4), 3.2, Color("bb803f"))
	else:
		_poly(unit, [Vector2(-7, -14), Vector2(7, -14), Vector2(5, -18), Vector2(-5, -18)], STEEL if armored else Color("746e5d"))
		_crossbow(unit, Vector2(12 + swing * 2, -1), armored)
		if armored: _pavise(unit, Vector2(-12, -2), team, true)

static func _infantry_25d(unit: Node2D, kind: String, team: Color, gait: float, swing: float) -> void:
	var armored := kind == "arbaletrier"
	var official := kind == "imperial_official"
	var trader := kind == "trader"
	var coat := Color("a4473d") if official else Color("ad8552") if trader else Color("52636a") if kind == "handcannoneer" else team.darkened(0.17)
	if trader:
		_poly(unit, [Vector2(-13, -20), Vector2(9, -20), Vector2(13, -5), Vector2(-14, -5)], LEATHER)
		unit.draw_rect(Rect2(-13, -18, 7, 10), WOOD)
		unit.draw_circle(Vector2(-10, -6), 4.3, Color("d1b279"))
	unit.draw_line(Vector2(-5, -4), Vector2(-6 + gait, 3), OUTLINE, 5.0)
	unit.draw_line(Vector2(5, -4), Vector2(6 - gait, 3), OUTLINE, 5.0)
	unit.draw_line(Vector2(-5, -4), Vector2(-6 + gait, 2), LEATHER, 2.5)
	unit.draw_line(Vector2(5, -4), Vector2(6 - gait, 2), LEATHER, 2.5)
	_poly(unit, [Vector2(-8, -20), Vector2(7, -20), Vector2(9, -5), Vector2(-9, -5)], coat)
	unit.draw_line(Vector2(-8, -9), Vector2(8, -9), GOLD if official else LEATHER, 1.6)
	if official:
		_poly(unit, [Vector2(-9, -10), Vector2(9, -10), Vector2(12, -3), Vector2(-12, -3)], coat.darkened(0.1))
		unit.draw_line(Vector2(0, -20), Vector2(0, -4), GOLD, 1.4)
	unit.draw_circle(Vector2(0, -25), 6.2, OUTLINE)
	unit.draw_circle(Vector2(0, -25), 4.8, SKIN)
	unit.draw_circle(Vector2(2, -25), 0.8, OUTLINE)
	if official:
		_poly(unit, [Vector2(-9, -29), Vector2(9, -29), Vector2(6, -34), Vector2(-6, -34)], Color("262a2b"))
		unit.draw_line(Vector2(-9, -29), Vector2(9, -29), GOLD, 1.3)
		unit.draw_rect(Rect2(10, -20, 8, 13), Color("e7d7b0"))
		unit.draw_line(Vector2(13, -18), Vector2(13, -8), Color("bd6840"), 1.2)
	elif trader:
		_poly(unit, [Vector2(-7, -29), Vector2(7, -29), Vector2(5, -33), Vector2(-5, -33)], Color("846344"))
		unit.draw_line(Vector2(13, -20), Vector2(16, 0), WOOD, 2.1)
		unit.draw_circle(Vector2(12, -8), 4.2, Color("d5b073"))
		unit.draw_circle(Vector2(12, -8), 1.8, GOLD)
	elif kind == "handcannoneer":
		_poly(unit, [Vector2(-6, -28), Vector2(6, -28), Vector2(4, -33), Vector2(-4, -33)], Color("525754"))
		unit.draw_line(Vector2(4, -15), Vector2(19 + swing * 4, -31), OUTLINE, 7.0)
		unit.draw_line(Vector2(5, -15), Vector2(19 + swing * 4, -31), Color("626d6d"), 4.4)
		unit.draw_circle(Vector2(19 + swing * 4, -31), 3.3, OUTLINE)
		unit.draw_circle(Vector2(19 + swing * 4, -31), 1.8, Color("d8d6c8"))
		unit.draw_line(Vector2(5, -13), Vector2(12, -21), WOOD, 2.2)
		unit.draw_circle(Vector2(-11, -7), 3.3, Color("b57a3d"))
	else:
		_poly(unit, [Vector2(-7, -29), Vector2(7, -29), Vector2(5, -33), Vector2(-5, -33)], STEEL if armored else Color("756e5d"))
		_crossbow(unit, Vector2(12 + swing * 2, -17), armored)
		if armored: _pavise(unit, Vector2(-12, -16), team, true)

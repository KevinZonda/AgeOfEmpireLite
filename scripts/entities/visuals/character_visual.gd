class_name RtsCharacterVisual
extends RefCounted
const FilledPolygon = preload("res://scripts/entities/visuals/filled_polygon.gd")

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

static func draw_2d(unit: CanvasItem, kind: String, team: Color, gait: float, swing: float) -> void:
	if kind in ["horseman", "scout", "knight", "royal_knight"]:
		_cavalry_2d(unit, kind, team, gait, swing)
	else:
		_infantry_2d(unit, kind, team, gait, swing)

static func draw_25d(unit: CanvasItem, kind: String, team: Color, gait: float, swing: float) -> void:
	if kind in ["horseman", "scout", "knight", "royal_knight"]:
		_cavalry_25d(unit, kind, team, gait, swing)
	else:
		_infantry_25d(unit, kind, team, gait, swing)

static func _poly(unit: CanvasItem, points: Array, fill: Color, stroke: Color = OUTLINE, width: float = 1.5) -> void:
	var shape := PackedVector2Array(points)
	FilledPolygon.draw(unit, shape, fill)
	if width > 0.0:
		unit.draw_polyline(shape + PackedVector2Array([shape[0]]), stroke, width)

static func _crossbow(unit: CanvasItem, center: Vector2, large: bool) -> void:
	var width := 15.0 if large else 12.0
	unit.draw_line(center + Vector2(0, 10), center + Vector2(0, -9), OUTLINE, 4.5)
	unit.draw_line(center + Vector2(0, 9), center + Vector2(0, -9), WOOD, 2.6)
	unit.draw_arc(center + Vector2(0, -7), width, PI * 0.12, PI * 0.88, 14, OUTLINE, 3.0)
	unit.draw_line(center + Vector2(-width * 0.9, -2), center + Vector2(width * 0.9, -2), Color("e1d5b5"), 1.2)
	unit.draw_line(center + Vector2(0, 5), center + Vector2(0, -15), STEEL_LIGHT, 1.3)
	unit.draw_circle(center + Vector2(0, 2), 2.0, LEATHER)

static func _pavise(unit: CanvasItem, center: Vector2, team: Color, tall: bool) -> void:
	var height := 20.0 if tall else 16.0
	_poly(unit, [center + Vector2(-7, -height * 0.5), center + Vector2(6, -height * 0.5), center + Vector2(7, height * 0.18), center + Vector2(0, height * 0.6), center + Vector2(-7, height * 0.18)], STEEL)
	_poly(unit, [center + Vector2(-4, -height * 0.35), center + Vector2(3, -height * 0.35), center + Vector2(4, height * 0.08), center + Vector2(0, height * 0.35), center + Vector2(-4, height * 0.08)], team.darkened(0.15), OUTLINE, 0.8)
	unit.draw_line(center + Vector2(-5, -height * 0.15), center + Vector2(5, -height * 0.15), GOLD, 1.1)

static func _sword(unit: CanvasItem, grip: Vector2, swing: float) -> void:
	var tip := grip + Vector2(12 + swing * 8, -19 + swing * 8)
	unit.draw_line(grip, tip, OUTLINE, 4.0)
	unit.draw_line(grip + Vector2(1, -2), tip, STEEL_LIGHT, 2.0)
	unit.draw_line(grip + Vector2(-3, -4), grip + Vector2(5, 0), GOLD, 2.4)
	unit.draw_circle(grip + Vector2(-1, 2), 1.7, LEATHER)

static func _spyglass(unit: CanvasItem, start: Vector2) -> void:
	var end := start + Vector2(13, -3)
	unit.draw_line(start, end, OUTLINE, 5.0)
	unit.draw_line(start + Vector2(1, 0), end - Vector2(1, 0), WOOD, 3.2)
	unit.draw_line(start + Vector2(5, -1), start + Vector2(5, 2), GOLD, 1.5)
	unit.draw_circle(end, 2.7, GOLD)
	unit.draw_circle(end + Vector2(0.5, 0), 1.4, Color("8db4bd"))

static func _hand_cannon(unit: CanvasItem, team: Color, lift: float, swing: float) -> void:
	var offset := Vector2(-swing * 2.5, lift + swing)
	# Both arms support the wooden stock; the short metal barrel has a clear muzzle.
	unit.draw_line(Vector2(-7, -3) + offset, Vector2(4, 2) + offset, OUTLINE, 5.0)
	unit.draw_line(Vector2(-7, -3) + offset, Vector2(4, 2) + offset, team.darkened(0.25), 3.0)
	unit.draw_line(Vector2(7, -4) + offset, Vector2(13, -3) + offset, OUTLINE, 5.0)
	unit.draw_line(Vector2(7, -4) + offset, Vector2(13, -3) + offset, team.darkened(0.25), 3.0)
	_poly(unit, [Vector2(-11, 3) + offset, Vector2(-6, 0) + offset, Vector2(9, -5) + offset, Vector2(12, 0) + offset, Vector2(-5, 7) + offset, Vector2(-12, 7) + offset], WOOD)
	unit.draw_line(Vector2(8, -4) + offset, Vector2(27, -10) + offset, OUTLINE, 8.0)
	unit.draw_line(Vector2(8, -4) + offset, Vector2(27, -10) + offset, Color("77898b"), 5.1)
	unit.draw_line(Vector2(11, -6) + offset, Vector2(24, -10) + offset, STEEL_LIGHT, 1.4)
	unit.draw_line(Vector2(10, -2) + offset, Vector2(12, -8) + offset, GOLD, 2.0)
	unit.draw_circle(Vector2(27, -10) + offset, 3.9, STEEL_LIGHT)
	unit.draw_circle(Vector2(27, -10) + offset, 2.2, OUTLINE)
	unit.draw_circle(Vector2(4, 2) + offset, 2.5, SKIN)
	unit.draw_circle(Vector2(13, -3) + offset, 2.5, SKIN)

static func _cavalry_2d(unit: CanvasItem, kind: String, team: Color, gait: float, swing: float) -> void:
	var heavy := kind in ["knight", "royal_knight"]
	var royal := kind == "royal_knight"
	# Four offset legs and a tapered body still read as a horse at map scale.
	for x in [-13.0, 10.0]:
		var stride := gait if x < 0.0 else -gait
		for side in [-1.0, 1.0]:
			var hip := Vector2(x, side * 6.0)
			var hoof := Vector2(x + stride, side * 13.0)
			unit.draw_line(hip, hoof, OUTLINE, 4.5)
			unit.draw_line(hip, hoof, Color("8d6547"), 2.7)
			unit.draw_line(hoof, hoof + Vector2(3, side), OUTLINE, 2.0)
	_poly(unit, [Vector2(-22, -5), Vector2(-17, -9), Vector2(4, -10), Vector2(15, -6), Vector2(17, 4), Vector2(6, 9), Vector2(-17, 8), Vector2(-23, 4)], Color("9a7452"))
	_poly(unit, [Vector2(-18, -7), Vector2(3, -8), Vector2(13, -5), Vector2(10, 2), Vector2(-1, 5), Vector2(-18, 4)], Color("b58a60"), OUTLINE, 0.8)
	_poly(unit, [Vector2(-17, 4), Vector2(3, 5), Vector2(14, 2), Vector2(7, 8), Vector2(-17, 7)], Color("76543e"), OUTLINE, 0.0)
	unit.draw_line(Vector2(-20, 2), Vector2(-28, 9 + gait * 0.5), OUTLINE, 3.2)
	unit.draw_line(Vector2(-21, 2), Vector2(-27, 8 + gait * 0.5), LEATHER, 1.8)
	_poly(unit, [Vector2(8, -7), Vector2(15, -13), Vector2(21, -12), Vector2(21, -5), Vector2(15, 0)], Color("a47b56"))
	_poly(unit, [Vector2(17, -14), Vector2(25, -14), Vector2(29, -9), Vector2(26, -5), Vector2(19, -6)], Color("bd9368"))
	_poly(unit, [Vector2(19, -13), Vector2(20, -18), Vector2(23, -14)], Color("8d6547"))
	unit.draw_circle(Vector2(24, -11), 1.1, OUTLINE)
	unit.draw_line(Vector2(22, -6), Vector2(27, -6), LEATHER, 1.4)
	unit.draw_line(Vector2(16, -12), Vector2(20, -5), LEATHER, 1.2)
	if heavy:
		_poly(unit, [Vector2(-19, -8), Vector2(1, -9), Vector2(7, -3), Vector2(4, 6), Vector2(-18, 6)], team.darkened(0.22))
		unit.draw_line(Vector2(-17, 4), Vector2(3, 4), GOLD, 1.5)
	# Saddle, rider and helm/cap.
	_poly(unit, [Vector2(-9, -9), Vector2(6, -10), Vector2(8, 4), Vector2(-8, 6)], STEEL if heavy else team.darkened(0.12))
	_poly(unit, [Vector2(-7, -8), Vector2(2, -9), Vector2(6, 3), Vector2(-3, 4)], STEEL_LIGHT if heavy else team.lightened(0.12), OUTLINE, 0.0)
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
		# The lens and brass rings distinguish the telescope from a blade.
		unit.draw_line(Vector2(5, -5), Vector2(11, -8), team.darkened(0.2), 3.5)
		_spyglass(unit, Vector2(8, -9))
		_poly(unit, [Vector2(-13, -1), Vector2(-6, -2), Vector2(-5, 4), Vector2(-12, 5)], WOOD)
		unit.draw_line(Vector2(-11, 0), Vector2(-7, 3), Color("e4d3aa"), 1.3)
	else:
		unit.draw_line(Vector2(5, -2), Vector2(9, 2), STEEL if heavy else team.darkened(0.18), 4.0)
		_sword(unit, Vector2(8, 2), swing)
		if heavy: _pavise(unit, Vector2(-11, -1), team, false)

static func _cavalry_25d(unit: CanvasItem, kind: String, team: Color, gait: float, swing: float) -> void:
	var heavy := kind in ["knight", "royal_knight"]
	var royal := kind == "royal_knight"
	# Near and far leg pairs move in opposite phases during a gallop.
	for x in [-14.0, -8.0, 7.0, 13.0]:
		var stride := gait * (1.0 if x < 0.0 else -1.0) * (0.75 if x == -8.0 or x == 7.0 else 1.0)
		var hoof := Vector2(x + stride, 4.0 + absf(stride) * 0.23)
		unit.draw_line(Vector2(x, -8), hoof, OUTLINE, 4.4)
		unit.draw_line(Vector2(x, -8), hoof + Vector2(-0.5, -1), Color("936b4b"), 2.7)
		unit.draw_line(hoof + Vector2(-2, 0), hoof + Vector2(2.5, 0), OUTLINE, 2.0)
	_poly(unit, [Vector2(-22, -10), Vector2(-18, -15), Vector2(-7, -17), Vector2(8, -17), Vector2(15, -12), Vector2(13, -6), Vector2(4, -3), Vector2(-17, -4), Vector2(-23, -7)], Color("98704f"))
	_poly(unit, [Vector2(-18, -14), Vector2(-7, -16), Vector2(7, -16), Vector2(12, -12), Vector2(5, -9), Vector2(-16, -9)], Color("bd9167"), OUTLINE, 0.0)
	_poly(unit, [Vector2(-17, -8), Vector2(4, -8), Vector2(12, -11), Vector2(11, -6), Vector2(3, -4), Vector2(-17, -5)], Color("78563f"), OUTLINE, 0.0)
	unit.draw_line(Vector2(-20, -10), Vector2(-27, -3 + gait * 0.5), OUTLINE, 3.8)
	unit.draw_line(Vector2(-21, -10), Vector2(-27, -3 + gait * 0.5), LEATHER, 2.0)
	_poly(unit, [Vector2(7, -16), Vector2(13, -25), Vector2(18, -29), Vector2(22, -25), Vector2(19, -14), Vector2(13, -9)], Color("a87d58"))
	_poly(unit, [Vector2(16, -28), Vector2(22, -28), Vector2(28, -23), Vector2(27, -19), Vector2(20, -18), Vector2(17, -21)], Color("c2986d"))
	_poly(unit, [Vector2(17, -28), Vector2(18, -34), Vector2(21, -29)], Color("8d6547"))
	_poly(unit, [Vector2(21, -28), Vector2(23, -33), Vector2(24, -27)], Color("8d6547"))
	unit.draw_circle(Vector2(23, -25), 1.1, OUTLINE)
	unit.draw_line(Vector2(21, -20), Vector2(27, -20), LEATHER, 1.5)
	unit.draw_line(Vector2(15, -26), Vector2(19, -18), LEATHER, 1.4)
	if heavy:
		_poly(unit, [Vector2(-19, -15), Vector2(6, -16), Vector2(11, -10), Vector2(7, -5), Vector2(-18, -6)], team.darkened(0.20))
		unit.draw_line(Vector2(-17, -8), Vector2(7, -8), GOLD, 1.3)
	_poly(unit, [Vector2(-9, -25), Vector2(5, -25), Vector2(8, -12), Vector2(-8, -11)], STEEL if heavy else team.darkened(0.13))
	_poly(unit, [Vector2(-7, -24), Vector2(1, -24), Vector2(5, -14), Vector2(-5, -13)], STEEL_LIGHT if heavy else team.lightened(0.12), OUTLINE, 0.0)
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
		unit.draw_line(Vector2(5, -25), Vector2(9, -28), team.darkened(0.2), 3.5)
		_spyglass(unit, Vector2(7, -29))
		_poly(unit, [Vector2(-16, -18), Vector2(-8, -19), Vector2(-7, -10), Vector2(-15, -10)], WOOD)
		unit.draw_line(Vector2(-14, -16), Vector2(-9, -13), Color("e4d3aa"), 1.3)
	else:
		unit.draw_line(Vector2(5, -20), Vector2(9, -17), STEEL if heavy else team.darkened(0.18), 4.0)
		_sword(unit, Vector2(8, -17), swing)
		if heavy: _pavise(unit, Vector2(-11, -20), team, true)

static func _infantry_2d(unit: CanvasItem, kind: String, team: Color, gait: float, swing: float) -> void:
	var armored := kind == "arbaletrier"
	var official := kind == "imperial_official"
	var trader := kind == "trader"
	var coat := team.darkened(0.2) if official else team.darkened(0.14)
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
		_poly(unit, [Vector2(-9, -5), Vector2(-5, -5), Vector2(5, 6), Vector2(2, 8)], Color("816043"), OUTLINE, 0.0)
		_poly(unit, [Vector2(-15, 0), Vector2(-9, -1), Vector2(-7, 7), Vector2(-14, 8)], Color("b57a3d"))
		unit.draw_line(Vector2(-13, 1), Vector2(-9, 1), GOLD, 1.1)
		_hand_cannon(unit, team, 0.0, swing)
	else:
		_poly(unit, [Vector2(-7, -14), Vector2(7, -14), Vector2(5, -18), Vector2(-5, -18)], STEEL if armored else Color("746e5d"))
		_crossbow(unit, Vector2(12 + swing * 2, -1), armored)
		if armored: _pavise(unit, Vector2(-12, -2), team, true)

static func _infantry_25d(unit: CanvasItem, kind: String, team: Color, gait: float, swing: float) -> void:
	var armored := kind == "arbaletrier"
	var official := kind == "imperial_official"
	var trader := kind == "trader"
	var coat := team.darkened(0.22) if official else team.darkened(0.17)
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
		_poly(unit, [Vector2(-9, -19), Vector2(-5, -19), Vector2(5, -8), Vector2(2, -6)], Color("816043"), OUTLINE, 0.0)
		_poly(unit, [Vector2(-15, -14), Vector2(-9, -15), Vector2(-7, -7), Vector2(-14, -6)], Color("b57a3d"))
		unit.draw_line(Vector2(-13, -13), Vector2(-9, -13), GOLD, 1.1)
		_hand_cannon(unit, team, -14.0, swing)
	else:
		_poly(unit, [Vector2(-7, -29), Vector2(7, -29), Vector2(5, -33), Vector2(-5, -33)], STEEL if armored else Color("756e5d"))
		_crossbow(unit, Vector2(12 + swing * 2, -17), armored)
		if armored: _pavise(unit, Vector2(-12, -16), team, true)

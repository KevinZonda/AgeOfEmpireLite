class_name RtsChineseVisual
extends RefCounted
const FilledPolygon = preload("res://scripts/entities/visuals/filled_polygon.gd")

# Distinct equipment silhouettes for the Chinese unique units. RtsUnit has
# already applied its idle/movement transform before calling these methods.
const OUTLINE := Color("202829")
const SKIN := Color("dfbd91")
const LEATHER := Color("664936")
const WOOD := Color("91653e")
const STEEL := Color("b5c0b9")
const GOLD := Color("d9ac55")
const POWDER := Color("37312c")
const FIRE := Color("fa9839")
const FIRE_LIGHT := Color("ffdd76")

static func handles(kind: String) -> bool:
	return kind in ["zhuge_nu", "grenadier", "fire_lancer"]

static func draw_2d(canvas: CanvasItem, kind: String, team: Color, gait: float, swing: float) -> void:
	if kind == "fire_lancer":
		_fire_lancer_2d(canvas, team, swing)
	else:
		_infantry(canvas, kind, team, gait, swing, false)

static func draw_25d(canvas: CanvasItem, kind: String, team: Color, gait: float, swing: float) -> void:
	if kind == "fire_lancer":
		_fire_lancer_25d(canvas, team, swing)
	else:
		_infantry(canvas, kind, team, gait, swing, true)

static func _poly(canvas: CanvasItem, points: Array, fill: Color, stroke: Color = OUTLINE, width: float = 1.4) -> void:
	var shape := PackedVector2Array(points)
	FilledPolygon.draw(canvas, shape, fill)
	if width > 0.0:
		canvas.draw_polyline(shape + PackedVector2Array([shape[0]]), stroke, width)

static func _infantry(canvas: CanvasItem, kind: String, team: Color, gait: float, swing: float, iso: bool) -> void:
	var y := -14.0 if iso else 0.0
	var coat := team.darkened(0.12) if kind == "zhuge_nu" else team.darkened(0.2)
	# Boots, short padded coat, belt, face and a low Chinese helmet.
	for side in [-1.0, 1.0]:
		var x: float = side * 5.0
		canvas.draw_line(Vector2(x, y + 5), Vector2(x + side * 1.2 + gait * side, y + 15), OUTLINE, 5.0)
		canvas.draw_line(Vector2(x, y + 5), Vector2(x + side * 1.2 + gait * side, y + 14), LEATHER, 2.8)
	_poly(canvas, [Vector2(-8, y - 8), Vector2(8, y - 8), Vector2(9, y + 7), Vector2(-9, y + 7)], coat)
	canvas.draw_line(Vector2(-8, y + 1), Vector2(8, y + 1), GOLD, 1.6)
	canvas.draw_line(Vector2(0, y - 7), Vector2(0, y + 6), team.lightened(0.28), 1.3)
	canvas.draw_circle(Vector2(0, y - 11), 6.4, OUTLINE)
	canvas.draw_circle(Vector2(0, y - 11), 5.0, SKIN)
	_poly(canvas, [Vector2(-7, y - 14), Vector2(7, y - 14), Vector2(4, y - 19), Vector2(-4, y - 19)], Color("536060"))
	canvas.draw_line(Vector2(-8, y - 14), Vector2(8, y - 14), GOLD, 1.2)
	if kind == "zhuge_nu":
		# Quiver lies behind the left shoulder; the top magazine makes this
		# visually different from an ordinary crossbow at battlefield zoom.
		_poly(canvas, [Vector2(-13, y - 7), Vector2(-9, y - 11), Vector2(-5, y + 3), Vector2(-10, y + 5)], LEATHER)
		for i in range(3):
			canvas.draw_line(Vector2(-12 + i * 2, y - 9), Vector2(-12 + i * 2, y - 14), STEEL, 1.0)
		_repeating_crossbow(canvas, Vector2(12 + swing * 2.0, y - 2))
	else:
		# Spare grenades and powder bag on the belt; the right hand throws the
		# lit ball upward during the unit's attack animation.
		_poly(canvas, [Vector2(-15, y - 4), Vector2(-8, y - 5), Vector2(-7, y + 7), Vector2(-15, y + 7)], LEATHER)
		canvas.draw_line(Vector2(-13, y - 3), Vector2(-10, y + 5), GOLD, 1.3)
		canvas.draw_circle(Vector2(-11, y + 7), 2.0, POWDER)
		canvas.draw_circle(Vector2(-5, y + 5), 2.5, POWDER)
		var hand := Vector2(14 + swing * 6.0, y - 8 - swing * 9.0)
		canvas.draw_line(Vector2(7, y - 4), hand, OUTLINE, 5.0)
		canvas.draw_line(Vector2(7, y - 4), hand, coat.lightened(0.12), 3.0)
		canvas.draw_circle(hand, 2.5, SKIN)
		_grenade(canvas, hand + Vector2(1, -6))

static func _repeating_crossbow(canvas: CanvasItem, center: Vector2) -> void:
	# The broad bow sits at the muzzle, in front of a raised repeating magazine.
	canvas.draw_line(center + Vector2(0, 10), center + Vector2(0, -14), OUTLINE, 5.0)
	canvas.draw_line(center + Vector2(0, 10), center + Vector2(0, -14), WOOD, 3.0)
	canvas.draw_arc(center + Vector2(0, -9), 13, PI * 0.12, PI * 0.88, 12, OUTLINE, 3.3)
	canvas.draw_line(center + Vector2(-12, -4), center + Vector2(12, -4), Color("e8d7aa"), 1.3)
	# Raised, banded bolt box, above the stock instead of a single loose bolt.
	_poly(canvas, [center + Vector2(-5, -14), center + Vector2(5, -14), center + Vector2(6, 1), center + Vector2(-5, 1)], Color("ad7946"))
	for offset in [-10.0, -5.0, 0.0]:
		canvas.draw_line(center + Vector2(-4, offset), center + Vector2(5, offset), Color("5d4636"), 1.1)
	canvas.draw_line(center + Vector2(0, -16), center + Vector2(0, -20), STEEL, 1.5)
	canvas.draw_line(center + Vector2(-3, 8), center + Vector2(3, 8), LEATHER, 2.0)

static func _grenade(canvas: CanvasItem, center: Vector2) -> void:
	canvas.draw_circle(center, 5.4, OUTLINE)
	canvas.draw_circle(center, 4.0, POWDER)
	canvas.draw_arc(center, 3.1, -PI * 0.7, PI * 0.25, 8, Color("837451"), 1.2)
	canvas.draw_line(center + Vector2(0, -5), center + Vector2(2, -9), Color("d4bd80"), 1.4)
	_poly(canvas, [center + Vector2(2, -11), center + Vector2(5, -15), center + Vector2(5, -10)], FIRE, Color.TRANSPARENT, 0.0)
	canvas.draw_circle(center + Vector2(4, -11), 1.3, FIRE_LIGHT)

static func _fire_lancer_2d(canvas: CanvasItem, team: Color, swing: float) -> void:
	# Top-down mount: pointed head, mane, four legs and a team-coloured saddle.
	_poly(canvas, [Vector2(-21, -7), Vector2(7, -10), Vector2(17, -5), Vector2(18, 7), Vector2(-18, 9)], Color("8e6648"))
	_poly(canvas, [Vector2(-17, -5), Vector2(8, -8), Vector2(16, -3), Vector2(16, 5), Vector2(-17, 6)], Color("b58a5d"), OUTLINE, 0.9)
	canvas.draw_line(Vector2(-17, 5), Vector2(-26, 11), LEATHER, 3.1)
	for x in [-12.0, 9.0]:
		canvas.draw_line(Vector2(x, 6), Vector2(x + 1, 14), OUTLINE, 3.5)
	canvas.draw_circle(Vector2(17, -8), 5.9, OUTLINE)
	canvas.draw_circle(Vector2(17, -8), 4.5, Color("c19a6c"))
	canvas.draw_circle(Vector2(20, -8), 1.0, OUTLINE)
	_poly(canvas, [Vector2(-9, -9), Vector2(6, -10), Vector2(8, 5), Vector2(-8, 6)], team.darkened(0.08))
	canvas.draw_line(Vector2(-7, 3), Vector2(7, 3), GOLD, 1.6)
	canvas.draw_circle(Vector2(-1, -9), 5.6, OUTLINE)
	canvas.draw_circle(Vector2(-1, -9), 4.3, SKIN)
	_poly(canvas, [Vector2(-6, -12), Vector2(5, -12), Vector2(3, -17), Vector2(-4, -17)], Color("505959"))
	canvas.draw_line(Vector2(-1, -17), Vector2(1, -21), Color("ba4e35"), 2.2)
	canvas.draw_line(Vector2(5, -4), Vector2(11, 1), Color("bc4438"), 3.0)
	var tip := Vector2(30 + swing * 3.0, -19 - swing * 4.0)
	_lance(canvas, Vector2(7, 0), tip, team)

static func _fire_lancer_25d(canvas: CanvasItem, team: Color, swing: float) -> void:
	for x in [-13.0, 8.0]:
		canvas.draw_line(Vector2(x, -5), Vector2(x - 2, 4), OUTLINE, 4.0)
		canvas.draw_line(Vector2(x, -5), Vector2(x - 2, 3), LEATHER, 2.1)
	_poly(canvas, [Vector2(-20, -13), Vector2(8, -15), Vector2(16, -10), Vector2(14, -3), Vector2(-19, -3)], Color("9d7551"))
	canvas.draw_line(Vector2(-19, -7), Vector2(-28, 0), LEATHER, 3.3)
	_poly(canvas, [Vector2(8, -14), Vector2(15, -24), Vector2(20, -23), Vector2(21, -13)], Color("b18a5c"))
	_poly(canvas, [Vector2(15, -23), Vector2(23, -22), Vector2(25, -17), Vector2(18, -16)], Color("c09b6a"))
	canvas.draw_circle(Vector2(21, -21), 1.0, OUTLINE)
	canvas.draw_line(Vector2(16, -19), Vector2(24, -18), LEATHER, 1.4)
	_poly(canvas, [Vector2(-9, -25), Vector2(5, -25), Vector2(8, -12), Vector2(-8, -11)], team.darkened(0.08))
	canvas.draw_line(Vector2(-8, -14), Vector2(7, -14), GOLD, 1.8)
	canvas.draw_circle(Vector2(-1, -29), 5.7, OUTLINE)
	canvas.draw_circle(Vector2(-1, -29), 4.3, SKIN)
	_poly(canvas, [Vector2(-7, -32), Vector2(5, -32), Vector2(3, -38), Vector2(-5, -38)], Color("535e5d"))
	canvas.draw_line(Vector2(-1, -38), Vector2(1, -42), Color("bb4839"), 2.2)
	canvas.draw_line(Vector2(5, -19), Vector2(11, -13), Color("bc4438"), 3.0)
	var tip := Vector2(30 + swing * 3.0, -39 - swing * 4.0)
	_lance(canvas, Vector2(7, -17), tip, team)

static func _lance(canvas: CanvasItem, grip: Vector2, tip: Vector2, team: Color) -> void:
	var direction := (tip - grip).normalized()
	var across := Vector2(-direction.y, direction.x)
	canvas.draw_line(grip, tip, OUTLINE, 5.2)
	canvas.draw_line(grip, tip, WOOD, 2.8)
	_poly(canvas, [tip - direction * 3 + across * 3, tip + direction * 6, tip - direction * 3 - across * 3], STEEL)
	var base := tip - direction * 8
	_poly(canvas, [base + across * 3, base - direction * 7 + across * 8, base - direction * 2 + across * 10, tip + direction * 4, base - direction * 1 - across * 9, base - direction * 7 - across * 7, base - across * 3], FIRE, Color.TRANSPARENT, 0.0)
	_poly(canvas, [base + across * 2, base - direction * 3 + across * 4, tip + direction * 3, base - direction * 3 - across * 4, base - across * 2], FIRE_LIGHT, Color.TRANSPARENT, 0.0)
	canvas.draw_line(grip + direction * 4, grip + direction * 4 + across * 7, team.lightened(0.23), 2.2)

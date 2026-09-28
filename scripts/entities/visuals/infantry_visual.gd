class_name RtsInfantryVisual
extends RefCounted

# Readable battlefield silhouettes at the same scale as RtsCharacterVisual.
const OUTLINE := Color("202829")
const SKIN := Color("dfbd91")
const LEATHER := Color("604536")
const WOOD := Color("9a7148")
const STEEL := Color("9eafb2")
const STEEL_LIGHT := Color("e1e8df")
const GOLD := Color("d8ae56")
const LACQUER := Color("8c3932")

static func handles(kind: String) -> bool:
	return kind in ["man_at_arms", "palace_guard", "archer", "longbow"]

static func draw_2d(canvas: CanvasItem, kind: String, team: Color, gait: float, swing: float, stakes_deployed: bool = false) -> void:
	if kind == "man_at_arms":
		_heavy_2d(canvas, team, gait, swing, false)
	elif kind == "palace_guard":
		_heavy_2d(canvas, team, gait, swing, true)
	else:
		_bowman_2d(canvas, team, gait, swing, kind == "longbow", stakes_deployed)

static func draw_25d(canvas: CanvasItem, kind: String, team: Color, gait: float, swing: float, stakes_deployed: bool = false) -> void:
	if kind == "man_at_arms":
		_heavy_25d(canvas, team, gait, swing, false)
	elif kind == "palace_guard":
		_heavy_25d(canvas, team, gait, swing, true)
	else:
		_bowman_25d(canvas, team, gait, swing, kind == "longbow", stakes_deployed)

static func _poly(canvas: CanvasItem, points: Array, fill: Color, stroke: Color = OUTLINE, width: float = 1.4) -> void:
	var shape := PackedVector2Array(points)
	canvas.draw_colored_polygon(shape, fill)
	if width > 0.0:
		canvas.draw_polyline(shape + PackedVector2Array([shape[0]]), stroke, width)

static func _legs_2d(canvas: CanvasItem, gait: float, plated: bool) -> void:
	for side in [-1.0, 1.0]:
		var x: float = side * 5.0
		var foot := Vector2(side * 6.0 - side * gait, 15)
		canvas.draw_line(Vector2(x, 5), foot, OUTLINE, 5.0)
		canvas.draw_line(Vector2(x, 5), foot + Vector2(0, -1), STEEL if plated else LEATHER, 2.7)

static func _legs_25d(canvas: CanvasItem, gait: float, plated: bool) -> void:
	for side in [-1.0, 1.0]:
		var x: float = side * 5.0
		var foot := Vector2(side * 6.0 - side * gait, 3)
		canvas.draw_line(Vector2(x, -5), foot, OUTLINE, 5.0)
		canvas.draw_line(Vector2(x, -5), foot + Vector2(0, -1), STEEL if plated else LEATHER, 2.7)

static func _heater_shield(canvas: CanvasItem, center: Vector2, team: Color, tall: bool) -> void:
	var h := 21.0 if tall else 19.0
	_poly(canvas, [center + Vector2(-8, -h * 0.53), center + Vector2(7, -h * 0.53), center + Vector2(8, h * 0.14), center + Vector2(0, h * 0.58), center + Vector2(-8, h * 0.14)], STEEL_LIGHT)
	_poly(canvas, [center + Vector2(-5, -h * 0.36), center + Vector2(4, -h * 0.36), center + Vector2(5, h * 0.07), center + Vector2(0, h * 0.35), center + Vector2(-5, h * 0.07)], team.darkened(0.18), OUTLINE, 0.8)
	canvas.draw_line(center + Vector2(0, -h * 0.31), center + Vector2(0, h * 0.31), GOLD, 1.1)
	canvas.draw_circle(center, 1.8, GOLD)

static func _straight_sword(canvas: CanvasItem, grip: Vector2, swing: float) -> void:
	var tip := grip + Vector2(7.0 + swing * 10.0, -24.0 + swing * 8.0)
	canvas.draw_line(grip, tip, OUTLINE, 5.0)
	canvas.draw_line(grip + Vector2(0, -2), tip, STEEL_LIGHT, 2.3)
	canvas.draw_line(grip + Vector2(-4, -5), grip + Vector2(5, -3), GOLD, 2.0)
	canvas.draw_circle(grip, 1.8, LEATHER)

static func _dao(canvas: CanvasItem, grip: Vector2, swing: float) -> void:
	# A broad, curved single-edged dao with a small red tassel.
	var heel := grip + Vector2(3, -5)
	var point := grip + Vector2(16 + swing * 8, -20 + swing * 7)
	_poly(canvas, [heel, heel + Vector2(4, -3), point + Vector2(4, 1), point + Vector2(2, -5), point + Vector2(-2, -5)], STEEL_LIGHT)
	canvas.draw_line(grip + Vector2(-3, -4), grip + Vector2(5, -1), GOLD, 2.2)
	canvas.draw_line(grip, grip + Vector2(-4, 5), LACQUER, 1.8)

static func _lamellar(canvas: CanvasItem, top: float, bottom: float, team: Color) -> void:
	var y := top + 3.0
	while y < bottom:
		canvas.draw_line(Vector2(-7, y), Vector2(7, y), GOLD, 1.2)
		for x in [-4.0, 0.0, 4.0]:
			canvas.draw_line(Vector2(x, y), Vector2(x + 1, y + 3), team.lightened(0.27), 0.9)
		y += 5.0

static func _heavy_2d(canvas: CanvasItem, team: Color, gait: float, swing: float, palace: bool) -> void:
	_legs_2d(canvas, gait, not palace)
	if palace:
		# Split skirt, lacquered lamellar and a crested Chinese helmet.
		_poly(canvas, [Vector2(-11, 1), Vector2(11, 1), Vector2(12, 10), Vector2(0, 7), Vector2(-12, 10)], LACQUER.darkened(0.14))
		_poly(canvas, [Vector2(-9, -8), Vector2(9, -8), Vector2(9, 6), Vector2(-9, 6)], team.darkened(0.30))
		_lamellar(canvas, -8, 5, team)
		canvas.draw_line(Vector2(-9, 1), Vector2(9, 1), GOLD, 1.5)
		canvas.draw_circle(Vector2(0, -12), 6.5, OUTLINE)
		canvas.draw_circle(Vector2(0, -12), 5.0, SKIN)
		_poly(canvas, [Vector2(-8, -13), Vector2(-6, -19), Vector2(5, -19), Vector2(8, -13)], LACQUER)
		canvas.draw_line(Vector2(-9, -14), Vector2(9, -14), GOLD, 1.5)
		canvas.draw_line(Vector2(0, -18), Vector2(0, -23), GOLD, 2.0)
		canvas.draw_line(Vector2(0, -23), Vector2(3, -26), LACQUER, 1.7)
		_dao(canvas, Vector2(10, 5), swing)
	else:
		# Plate cuirass and a full heater shield dominate this silhouette.
		_poly(canvas, [Vector2(-10, -8), Vector2(10, -8), Vector2(11, 7), Vector2(-11, 7)], STEEL)
		_poly(canvas, [Vector2(-8, -6), Vector2(8, -6), Vector2(6, 5), Vector2(-6, 5)], STEEL_LIGHT, OUTLINE, 0.8)
		canvas.draw_line(Vector2(0, -6), Vector2(0, 5), STEEL, 1.3)
		canvas.draw_line(Vector2(-8, 3), Vector2(8, 3), LEATHER, 2.0)
		canvas.draw_circle(Vector2(0, -12), 6.4, OUTLINE)
		canvas.draw_circle(Vector2(0, -12), 4.9, SKIN)
		_poly(canvas, [Vector2(-7, -12), Vector2(-6, -19), Vector2(5, -19), Vector2(7, -12)], STEEL_LIGHT)
		canvas.draw_line(Vector2(-6, -11), Vector2(6, -11), OUTLINE, 1.2)
		_straight_sword(canvas, Vector2(10, 7), swing)
		_heater_shield(canvas, Vector2(-12, -2), team, false)

static func _heavy_25d(canvas: CanvasItem, team: Color, gait: float, swing: float, palace: bool) -> void:
	_legs_25d(canvas, gait, not palace)
	if palace:
		_poly(canvas, [Vector2(-10, -10), Vector2(10, -10), Vector2(12, -2), Vector2(0, -5), Vector2(-12, -2)], LACQUER.darkened(0.16))
		_poly(canvas, [Vector2(-9, -21), Vector2(9, -21), Vector2(9, -8), Vector2(-9, -8)], team.darkened(0.30))
		_lamellar(canvas, -21, -8, team)
		canvas.draw_line(Vector2(-9, -9), Vector2(9, -9), GOLD, 1.5)
		canvas.draw_circle(Vector2(0, -27), 6.3, OUTLINE)
		canvas.draw_circle(Vector2(0, -27), 4.8, SKIN)
		_poly(canvas, [Vector2(-8, -29), Vector2(-6, -35), Vector2(5, -35), Vector2(8, -29)], LACQUER)
		canvas.draw_line(Vector2(-9, -29), Vector2(9, -29), GOLD, 1.5)
		canvas.draw_line(Vector2(0, -35), Vector2(0, -40), GOLD, 2.0)
		canvas.draw_line(Vector2(0, -40), Vector2(3, -43), LACQUER, 1.7)
		_dao(canvas, Vector2(10, -12), swing)
	else:
		_poly(canvas, [Vector2(-9, -21), Vector2(9, -21), Vector2(10, -7), Vector2(-10, -7)], STEEL)
		_poly(canvas, [Vector2(-7, -19), Vector2(7, -19), Vector2(6, -9), Vector2(-6, -9)], STEEL_LIGHT, OUTLINE, 0.8)
		canvas.draw_line(Vector2(0, -19), Vector2(0, -9), STEEL, 1.3)
		canvas.draw_line(Vector2(-8, -10), Vector2(8, -10), LEATHER, 2.0)
		canvas.draw_circle(Vector2(0, -27), 6.3, OUTLINE)
		canvas.draw_circle(Vector2(0, -27), 4.8, SKIN)
		_poly(canvas, [Vector2(-7, -27), Vector2(-5, -34), Vector2(5, -34), Vector2(7, -27)], STEEL_LIGHT)
		canvas.draw_line(Vector2(-6, -26), Vector2(6, -26), OUTLINE, 1.2)
		_straight_sword(canvas, Vector2(10, -10), swing)
		_heater_shield(canvas, Vector2(-12, -17), team, true)

static func _quiver(canvas: CanvasItem, center: Vector2) -> void:
	_poly(canvas, [center + Vector2(-4, -7), center + Vector2(4, -7), center + Vector2(3, 7), center + Vector2(-3, 7)], LEATHER)
	canvas.draw_line(center + Vector2(-3, 3), center + Vector2(3, 3), GOLD, 1.0)
	for x in [-2.0, 1.0, 3.0]:
		canvas.draw_line(center + Vector2(x, -6), center + Vector2(x, -11), WOOD, 1.0)
		canvas.draw_line(center + Vector2(x, -11), center + Vector2(x + 2, -13), STEEL_LIGHT, 1.0)

static func _bow(canvas: CanvasItem, center: Vector2, long_bow: bool, swing: float) -> void:
	var radius := 17.0 if long_bow else 10.5
	var bow_center := center + Vector2(swing * 2, 0)
	canvas.draw_arc(bow_center, radius, -PI * 0.57, PI * 0.57, 16, OUTLINE, 4.0)
	canvas.draw_arc(bow_center, radius - 1.1, -PI * 0.57, PI * 0.57, 16, WOOD, 2.3)
	var end_y := radius * 0.98
	canvas.draw_line(bow_center + Vector2(-3.5, -end_y), bow_center + Vector2(-3.5, end_y), STEEL_LIGHT, 1.15)
	canvas.draw_line(bow_center + Vector2(-10, 0), bow_center + Vector2(6, 0), WOOD, 1.5)
	_poly(canvas, [bow_center + Vector2(7, -2), bow_center + Vector2(11, 0), bow_center + Vector2(7, 2)], STEEL_LIGHT, OUTLINE, 0.7)

static func _stakes(canvas: CanvasItem, ground_y: float) -> void:
	# The longbowman's planted stakes remain low and behind the figure.
	for x in [-21.0, -15.0]:
		canvas.draw_line(Vector2(x - 2, ground_y + 5), Vector2(x + 3, ground_y - 9), OUTLINE, 3.5)
		canvas.draw_line(Vector2(x - 2, ground_y + 5), Vector2(x + 3, ground_y - 9), WOOD, 2.0)
		_poly(canvas, [Vector2(x + 1, ground_y - 7), Vector2(x + 3, ground_y - 12), Vector2(x + 5, ground_y - 8)], STEEL)

static func _bowman_2d(canvas: CanvasItem, team: Color, gait: float, swing: float, long_bow: bool, stakes_deployed: bool) -> void:
	if long_bow and stakes_deployed: _stakes(canvas, 1.0)
	_legs_2d(canvas, gait, false)
	_quiver(canvas, Vector2(-11, -3))
	_poly(canvas, [Vector2(-8, -8), Vector2(8, -8), Vector2(9, 7), Vector2(-9, 7)], team.darkened(0.11))
	canvas.draw_line(Vector2(-8, 2), Vector2(8, 2), LEATHER, 1.8)
	if long_bow:
		canvas.draw_line(Vector2(0, -7), Vector2(0, 7), GOLD, 1.2)
	canvas.draw_circle(Vector2(0, -12), 6.2, OUTLINE)
	canvas.draw_circle(Vector2(0, -12), 4.9, SKIN)
	_poly(canvas, [Vector2(-7, -14), Vector2(7, -14), Vector2(4, -18), Vector2(-4, -18)], Color("686647") if long_bow else LEATHER)
	_bow(canvas, Vector2(12, -1), long_bow, swing)

static func _bowman_25d(canvas: CanvasItem, team: Color, gait: float, swing: float, long_bow: bool, stakes_deployed: bool) -> void:
	if long_bow and stakes_deployed: _stakes(canvas, -11.0)
	_legs_25d(canvas, gait, false)
	_quiver(canvas, Vector2(-11, -16))
	_poly(canvas, [Vector2(-8, -21), Vector2(8, -21), Vector2(9, -6), Vector2(-9, -6)], team.darkened(0.13))
	canvas.draw_line(Vector2(-8, -10), Vector2(8, -10), LEATHER, 1.8)
	if long_bow:
		canvas.draw_line(Vector2(0, -20), Vector2(0, -7), GOLD, 1.2)
	canvas.draw_circle(Vector2(0, -27), 6.2, OUTLINE)
	canvas.draw_circle(Vector2(0, -27), 4.8, SKIN)
	_poly(canvas, [Vector2(-7, -29), Vector2(7, -29), Vector2(4, -33), Vector2(-4, -33)], Color("686647") if long_bow else LEATHER)
	_bow(canvas, Vector2(12, -17), long_bow, swing)

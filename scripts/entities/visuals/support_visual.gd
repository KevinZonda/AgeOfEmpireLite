class_name RtsSupportVisual
extends RefCounted

const EDGE := Color("222b2b")
const SKIN := Color("dfc49a")
const WOOD := Color("9b754c")
const IRON := Color("cad2cd")
const GOLD := Color("e2bd65")

static func handles(kind: String) -> bool:
	return kind in ["villager", "spearman", "monk"]

static func draw_2d(canvas: CanvasItem, kind: String, team: Color, gait: float, swing: float, gather_kind: String = "", has_relic: bool = false, braced: bool = false) -> void:
	_match_2d(canvas, kind, team, gait, swing, gather_kind, has_relic, braced)

static func draw_25d(canvas: CanvasItem, kind: String, team: Color, gait: float, swing: float, gather_kind: String = "", has_relic: bool = false, braced: bool = false) -> void:
	_match_25d(canvas, kind, team, gait, swing, gather_kind, has_relic, braced)

static func _poly(canvas: CanvasItem, points: Array, fill: Color) -> void:
	var shape := PackedVector2Array(points)
	canvas.draw_colored_polygon(shape, fill)
	canvas.draw_polyline(shape + PackedVector2Array([shape[0]]), EDGE, 1.5)

static func _boots(canvas: CanvasItem, left: Vector2, right: Vector2, gait: float) -> void:
	canvas.draw_line(left, left + Vector2(-1 + gait, 9), EDGE, 4.8)
	canvas.draw_line(right, right + Vector2(1 - gait, 9), EDGE, 4.8)
	canvas.draw_line(left, left + Vector2(-1 + gait, 8), Color("5c4838"), 2.5)
	canvas.draw_line(right, right + Vector2(1 - gait, 8), Color("5c4838"), 2.5)

static func _tool(canvas: CanvasItem, base: Vector2, gather_kind: String, swing: float) -> void:
	var end := base + Vector2(5 - swing * 6, -22 - swing * 4)
	canvas.draw_line(base, end, EDGE, 4.0)
	canvas.draw_line(base, end, WOOD, 2.2)
	if gather_kind in ["stone", "gold"]:
		canvas.draw_line(end + Vector2(-7, -2), end + Vector2(7, 2), EDGE, 4.0)
		canvas.draw_line(end + Vector2(-7, -2), end + Vector2(7, 2), IRON, 2.2)
		canvas.draw_line(end + Vector2(-7, -2), end + Vector2(-9, 2), IRON, 1.5)
		canvas.draw_line(end + Vector2(7, 2), end + Vector2(9, 5), IRON, 1.5)
	elif gather_kind in ["food", "berry", "fish"]:
		canvas.draw_line(end + Vector2(-5, 0), end + Vector2(5, 0), EDGE, 3.0)
		canvas.draw_line(end + Vector2(-4, 0), end + Vector2(4, 0), IRON, 1.5)
	else:
		_poly(canvas, [end + Vector2(-2, -4), end + Vector2(6, -3), end + Vector2(6, 2), end + Vector2(-2, 1)], IRON)

static func _spear(canvas: CanvasItem, base: Vector2, braced: bool) -> void:
	var tip := base + (Vector2(24, -15) if braced else Vector2(1, -36))
	canvas.draw_line(base, tip, EDGE, 5.0)
	canvas.draw_line(base, tip, WOOD, 2.6)
	var direction := (tip - base).normalized()
	var side := direction.orthogonal() * 3.5
	_poly(canvas, [tip - direction * 2 + side, tip + direction * 10, tip - direction * 2 - side], IRON)
	canvas.draw_line(tip - direction * 3, tip - direction * 9, GOLD, 1.4)

static func _staff(canvas: CanvasItem, base: Vector2, has_relic: bool, swing: float) -> void:
	var top := base + Vector2(2 + swing * 2, -29 - swing * 3)
	canvas.draw_line(base, top, EDGE, 4.5)
	canvas.draw_line(base, top, WOOD, 2.3)
	canvas.draw_line(top + Vector2(-5, 5), top + Vector2(5, 5), GOLD, 2.4)
	canvas.draw_circle(top, 2.0, GOLD)
	if has_relic:
		var held := base + Vector2(6, -10)
		_poly(canvas, [held + Vector2(-5, 3), held + Vector2(-5, -3), held + Vector2(0, -7), held + Vector2(5, -3), held + Vector2(5, 3)], GOLD)
		canvas.draw_rect(Rect2(held + Vector2(-3, -2), Vector2(6, 4)), Color("f7e7b3"))
		canvas.draw_circle(held, 1.6, Color("5f8f8a"))
		canvas.draw_line(held + Vector2(-5, 4), held + Vector2(5, 4), Color("fff1bd"), 1.5)

static func _match_2d(canvas: CanvasItem, kind: String, team: Color, gait: float, swing: float, gather_kind: String, has_relic: bool, braced: bool) -> void:
	_boots(canvas, Vector2(-5, 6), Vector2(5, 6), gait)
	var cloth := team.darkened(0.27) if kind == "monk" else team.darkened(0.18)
	_poly(canvas, [Vector2(-8, -7), Vector2(8, -7), Vector2(9, 8), Vector2(-9, 8)], cloth)
	canvas.draw_line(Vector2(-8, 3), Vector2(8, 3), Color("d4b06a") if kind == "monk" else Color("634733"), 1.7)
	canvas.draw_circle(Vector2(0, -11), 6.7, EDGE)
	canvas.draw_circle(Vector2(0, -11), 5.2, SKIN)
	match kind:
		"villager":
			_poly(canvas, [Vector2(-10, -15), Vector2(10, -15), Vector2(6, -19), Vector2(-6, -19)], Color("aa8c55"))
			canvas.draw_line(Vector2(-8, -15), Vector2(8, -15), Color("e0c584"), 1.5)
			canvas.draw_circle(Vector2(-10, 4), 3.4, Color("bd945b"))
			_tool(canvas, Vector2(10, 6), gather_kind, swing)
		"spearman":
			_poly(canvas, [Vector2(-7, -15), Vector2(7, -15), Vector2(5, -19), Vector2(-5, -19)], Color("a5a9a4"))
			_poly(canvas, [Vector2(-13, -4), Vector2(-6, -7), Vector2(-3, 3), Vector2(-9, 8)], team.darkened(0.25))
			_spear(canvas, Vector2(11, 6), braced)
		"monk":
			canvas.draw_arc(Vector2(0, -11), 6.3, PI, TAU, 12, cloth.darkened(0.35), 3.0)
			canvas.draw_circle(Vector2(-2, -1), 2.3, GOLD)
			_staff(canvas, Vector2(11, 8), has_relic, swing)

static func _match_25d(canvas: CanvasItem, kind: String, team: Color, gait: float, swing: float, gather_kind: String, has_relic: bool, braced: bool) -> void:
	_boots(canvas, Vector2(-5, -4), Vector2(5, -4), gait)
	var cloth := team.darkened(0.27) if kind == "monk" else team.darkened(0.18)
	_poly(canvas, [Vector2(-8, -20), Vector2(8, -20), Vector2(9, -4), Vector2(-9, -4)], cloth)
	if kind == "monk": _poly(canvas, [Vector2(-8, -11), Vector2(8, -11), Vector2(12, -2), Vector2(-12, -2)], cloth.darkened(0.09))
	canvas.draw_line(Vector2(-8, -10), Vector2(8, -10), GOLD if kind == "monk" else Color("684b35"), 1.5)
	canvas.draw_circle(Vector2(0, -25), 6.5, EDGE)
	canvas.draw_circle(Vector2(0, -25), 5.0, SKIN)
	canvas.draw_circle(Vector2(2, -25), 0.9, EDGE)
	match kind:
		"villager":
			_poly(canvas, [Vector2(-11, -28), Vector2(11, -28), Vector2(6, -34), Vector2(-6, -34)], Color("ac8d55"))
			canvas.draw_line(Vector2(-9, -28), Vector2(9, -28), Color("dfc589"), 1.5)
			canvas.draw_circle(Vector2(-10, -8), 3.5, Color("bc985f"))
			_tool(canvas, Vector2(10, -5), gather_kind, swing)
		"spearman":
			_poly(canvas, [Vector2(-6, -29), Vector2(6, -29), Vector2(4, -35), Vector2(-4, -35)], Color("a8b0aa"))
			_poly(canvas, [Vector2(-13, -17), Vector2(-5, -19), Vector2(-4, -7), Vector2(-12, -6)], team.darkened(0.2))
			_spear(canvas, Vector2(10, -4), braced)
		"monk":
			canvas.draw_arc(Vector2(0, -25), 6.5, PI, TAU, 12, cloth.darkened(0.35), 3.2)
			canvas.draw_circle(Vector2(-2, -13), 2.1, GOLD)
			_staff(canvas, Vector2(11, -2), has_relic, swing)

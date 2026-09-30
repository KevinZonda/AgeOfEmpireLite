class_name RtsSupportVisual
extends RefCounted
const FilledPolygon = preload("res://scripts/entities/visuals/filled_polygon.gd")

const EDGE := Color("222b2b")
const SKIN := Color("dfc49a")
const WOOD := Color("9b754c")
const GOLD := Color("e2bd65")

static func handles(kind: String) -> bool:
	return kind == "monk"

static func draw_2d(canvas: CanvasItem, team: Color, gait: float, swing: float, has_relic: bool = false) -> void:
	_match_2d(canvas, team, gait, swing, has_relic)

static func draw_25d(canvas: CanvasItem, team: Color, gait: float, swing: float, has_relic: bool = false) -> void:
	_match_25d(canvas, team, gait, swing, has_relic)

static func _poly(canvas: CanvasItem, points: Array, fill: Color) -> void:
	var shape := PackedVector2Array(points)
	FilledPolygon.draw(canvas, shape, fill)
	canvas.draw_polyline(shape + PackedVector2Array([shape[0]]), EDGE, 1.5)

static func _boots(canvas: CanvasItem, left: Vector2, right: Vector2, gait: float) -> void:
	canvas.draw_line(left, left + Vector2(-1 + gait, 9), EDGE, 4.8)
	canvas.draw_line(right, right + Vector2(1 - gait, 9), EDGE, 4.8)
	canvas.draw_line(left, left + Vector2(-1 + gait, 8), Color("5c4838"), 2.5)
	canvas.draw_line(right, right + Vector2(1 - gait, 8), Color("5c4838"), 2.5)

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

static func _match_2d(canvas: CanvasItem, team: Color, gait: float, swing: float, has_relic: bool) -> void:
	_boots(canvas, Vector2(-5, 6), Vector2(5, 6), gait)
	var cloth := team.darkened(0.27)
	_poly(canvas, [Vector2(-8, -7), Vector2(8, -7), Vector2(9, 8), Vector2(-9, 8)], cloth)
	canvas.draw_line(Vector2(-8, 3), Vector2(8, 3), Color("d4b06a"), 1.7)
	canvas.draw_circle(Vector2(0, -11), 6.7, EDGE)
	canvas.draw_circle(Vector2(0, -11), 5.2, SKIN)
	canvas.draw_arc(Vector2(0, -11), 6.3, PI, TAU, 12, cloth.darkened(0.35), 3.0)
	canvas.draw_circle(Vector2(-2, -1), 2.3, GOLD)
	_staff(canvas, Vector2(11, 8), has_relic, swing)

static func _match_25d(canvas: CanvasItem, team: Color, gait: float, swing: float, has_relic: bool) -> void:
	_boots(canvas, Vector2(-5, -4), Vector2(5, -4), gait)
	var cloth := team.darkened(0.27)
	_poly(canvas, [Vector2(-8, -20), Vector2(8, -20), Vector2(9, -4), Vector2(-9, -4)], cloth)
	_poly(canvas, [Vector2(-8, -11), Vector2(8, -11), Vector2(12, -2), Vector2(-12, -2)], cloth.darkened(0.09))
	canvas.draw_line(Vector2(-8, -10), Vector2(8, -10), GOLD, 1.5)
	canvas.draw_circle(Vector2(0, -25), 6.5, EDGE)
	canvas.draw_circle(Vector2(0, -25), 5.0, SKIN)
	canvas.draw_circle(Vector2(2, -25), 0.9, EDGE)
	canvas.draw_arc(Vector2(0, -25), 6.5, PI, TAU, 12, cloth.darkened(0.35), 3.2)
	canvas.draw_circle(Vector2(-2, -13), 2.1, GOLD)
	_staff(canvas, Vector2(11, -2), has_relic, swing)

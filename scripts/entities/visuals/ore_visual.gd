class_name RtsOreVisual
extends RefCounted
const FilledPolygon = preload("res://scripts/entities/visuals/filled_polygon.gd")

const EDGE := Color("26302f")
const GOLD_ROCK := Color("66513d")
const GOLD_ROCK_DARK := Color("40372f")
const GOLD_ROCK_LIGHT := Color("8d7558")
const GOLD_ORE := Color("e4b84b")
const GOLD_LIGHT := Color("ffe69a")
const STONE_DARK := Color("555f62")
const STONE := Color("929da0")
const STONE_LIGHT := Color("c4ccca")

static func draw_2d(canvas: CanvasItem, kind: String, fraction: float = 1.0) -> void:
	if kind == "gold": _gold_2d(canvas, fraction)
	elif kind == "stone": _stone_2d(canvas, fraction)

static func draw_25d(canvas: CanvasItem, kind: String, fraction: float = 1.0) -> void:
	if kind == "gold": _gold_25d(canvas, fraction)
	elif kind == "stone": _stone_25d(canvas, fraction)

static func _poly(canvas: CanvasItem, points: Array, fill: Color, border: bool = false) -> void:
	var shape := PackedVector2Array(points)
	FilledPolygon.draw(canvas, shape, fill)
	if border: canvas.draw_polyline(shape + PackedVector2Array([shape[0]]), EDGE, 1.6)

static func _gold_2d(canvas: CanvasItem, fraction: float) -> void:
	# Ochre host rock surrounds an exposed, branching seam of yellow ore.
	_poly(canvas, [Vector2(-24, 9), Vector2(-21, -6), Vector2(-10, -16), Vector2(0, -12), Vector2(11, -19), Vector2(22, -7), Vector2(24, 9), Vector2(11, 18), Vector2(-12, 17)], GOLD_ROCK_DARK, true)
	_poly(canvas, [Vector2(-20, 5), Vector2(-19, -6), Vector2(-10, -13), Vector2(-1, -9), Vector2(-5, 3), Vector2(-13, 11)], GOLD_ROCK)
	_poly(canvas, [Vector2(-1, -9), Vector2(11, -16), Vector2(20, -6), Vector2(18, 8), Vector2(8, 13), Vector2(-5, 3)], GOLD_ROCK_LIGHT)
	_poly(canvas, [Vector2(-20, 6), Vector2(-12, 11), Vector2(-5, 3), Vector2(8, 13), Vector2(20, 7), Vector2(11, 17), Vector2(-12, 16)], GOLD_ROCK)
	_poly(canvas, [Vector2(-16, -6), Vector2(-10, -9), Vector2(-4, -3), Vector2(2, -6), Vector2(8, -1), Vector2(14, -4), Vector2(18, 1), Vector2(12, 5), Vector2(7, 3), Vector2(1, 0), Vector2(-5, 4), Vector2(-11, 0)], GOLD_ORE)
	_poly(canvas, [Vector2(-15, -6), Vector2(-10, -8), Vector2(-4, -2), Vector2(2, -5), Vector2(7, -1), Vector2(3, 0), Vector2(-4, 0), Vector2(-9, -2)], GOLD_LIGHT)
	canvas.draw_line(Vector2(7, 3), Vector2(13, 11), GOLD_ORE, 2.3)
	canvas.draw_line(Vector2(-9, 0), Vector2(-13, 8), GOLD_ORE, 2.0)
	if fraction > 0.28:
		_gold_chip(canvas, Vector2(-10, 12), 3.7)
		_gold_chip(canvas, Vector2(11, 12), 3.1)
	if fraction > 0.65: _gold_chip(canvas, Vector2(1, 11), 2.6)
	canvas.draw_line(Vector2(-18, -8), Vector2(-10, -14), GOLD_ROCK_LIGHT, 1.1)
	canvas.draw_line(Vector2(11, -16), Vector2(19, -6), GOLD_ROCK_LIGHT, 1.1)

static func _gold_25d(canvas: CanvasItem, fraction: float) -> void:
	# A broken cliff face with a bright seam through its front-facing facet.
	_poly(canvas, [Vector2(-24, 0), Vector2(-21, -18), Vector2(-12, -31), Vector2(-2, -26), Vector2(8, -36), Vector2(19, -22), Vector2(24, -5), Vector2(17, 4), Vector2(-17, 5)], GOLD_ROCK_DARK, true)
	_poly(canvas, [Vector2(-21, -17), Vector2(-12, -29), Vector2(-2, -25), Vector2(-5, -10), Vector2(-20, -5)], GOLD_ROCK_LIGHT)
	_poly(canvas, [Vector2(-4, -24), Vector2(8, -33), Vector2(19, -21), Vector2(17, -7), Vector2(4, -11)], GOLD_ROCK)
	_poly(canvas, [Vector2(-20, -5), Vector2(-5, -10), Vector2(4, -11), Vector2(17, -7), Vector2(22, -2), Vector2(16, 3), Vector2(-17, 4)], GOLD_ROCK)
	_poly(canvas, [Vector2(-14, -23), Vector2(-9, -27), Vector2(-5, -17), Vector2(1, -19), Vector2(7, -12), Vector2(13, -15), Vector2(17, -9), Vector2(10, -5), Vector2(4, -9), Vector2(-1, -11), Vector2(-8, -8), Vector2(-12, -12)], GOLD_ORE)
	_poly(canvas, [Vector2(-13, -22), Vector2(-9, -25), Vector2(-4, -15), Vector2(1, -17), Vector2(6, -11), Vector2(1, -12), Vector2(-5, -12), Vector2(-9, -13)], GOLD_LIGHT)
	canvas.draw_line(Vector2(8, -9), Vector2(12, -1), GOLD_ORE, 2.3)
	if fraction > 0.28:
		_gold_chip(canvas, Vector2(-13, 0), 3.8)
		_gold_chip(canvas, Vector2(14, 0), 3.4)
	if fraction > 0.65: _gold_chip(canvas, Vector2(0, 0), 2.6)

static func _gold_chip(canvas: CanvasItem, center: Vector2, size: float) -> void:
	_poly(canvas, [center + Vector2(-size, 0), center + Vector2(-size * 0.25, -size), center + Vector2(size, -size * 0.2), center + Vector2(size * 0.3, size)], GOLD_ORE, true)
	canvas.draw_line(center + Vector2(-size * 0.3, -size * 0.5), center + Vector2(size * 0.4, -size * 0.3), GOLD_LIGHT, 1.1)

static func _stone_2d(canvas: CanvasItem, fraction: float) -> void:
	# Broad, layered gray blocks instead of a recolored gold deposit.
	_poly(canvas, [Vector2(-25, 8), Vector2(-20, -6), Vector2(-12, -15), Vector2(-2, -14), Vector2(5, -20), Vector2(16, -16), Vector2(24, -5), Vector2(24, 10), Vector2(11, 18), Vector2(-13, 16)], STONE_DARK, true)
	_poly(canvas, [Vector2(-23, 7), Vector2(-20, -5), Vector2(-12, -12), Vector2(-3, -12), Vector2(1, -4), Vector2(-5, 8), Vector2(-15, 12)], STONE)
	_poly(canvas, [Vector2(-17, -7), Vector2(-11, -12), Vector2(-3, -10), Vector2(0, -4), Vector2(-7, 3), Vector2(-17, 2)], STONE_LIGHT)
	_poly(canvas, [Vector2(0, -4), Vector2(5, -18), Vector2(15, -14), Vector2(22, -5), Vector2(19, 8), Vector2(7, 11), Vector2(-5, 8)], STONE)
	_poly(canvas, [Vector2(6, -14), Vector2(14, -13), Vector2(20, -5), Vector2(14, 0), Vector2(4, -2)], STONE_LIGHT)
	_poly(canvas, [Vector2(-16, 12), Vector2(-5, 8), Vector2(7, 11), Vector2(19, 8), Vector2(11, 17), Vector2(-13, 15)], Color("737f81"))
	canvas.draw_line(Vector2(-15, 5), Vector2(-7, 3), STONE_DARK, 1.4)
	canvas.draw_line(Vector2(7, 1), Vector2(12, 7), STONE_DARK, 1.4)
	canvas.draw_line(Vector2(13, 7), Vector2(19, 8), STONE_DARK, 1.1)
	if fraction > 0.35: _stone_chip(canvas, Vector2(-18, 13), 4.5)
	if fraction > 0.7: _stone_chip(canvas, Vector2(18, 13), 3.6)

static func _stone_25d(canvas: CanvasItem, fraction: float) -> void:
	_poly(canvas, [Vector2(-25, 1), Vector2(-22, -16), Vector2(-14, -27), Vector2(-4, -25), Vector2(4, -32), Vector2(14, -27), Vector2(23, -14), Vector2(25, 2), Vector2(14, 6), Vector2(-15, 5)], STONE_DARK, true)
	_poly(canvas, [Vector2(-22, -15), Vector2(-14, -25), Vector2(-4, -23), Vector2(0, -14), Vector2(-7, -4), Vector2(-22, -3)], STONE)
	_poly(canvas, [Vector2(-17, -19), Vector2(-13, -24), Vector2(-5, -22), Vector2(-2, -14), Vector2(-10, -11), Vector2(-19, -11)], STONE_LIGHT)
	_poly(canvas, [Vector2(0, -14), Vector2(5, -30), Vector2(14, -25), Vector2(22, -13), Vector2(20, -3), Vector2(8, 0), Vector2(-7, -4)], STONE)
	_poly(canvas, [Vector2(5, -27), Vector2(13, -24), Vector2(19, -14), Vector2(13, -9), Vector2(2, -12)], STONE_LIGHT)
	_poly(canvas, [Vector2(-22, -3), Vector2(-7, -4), Vector2(8, 0), Vector2(20, -3), Vector2(23, 2), Vector2(13, 5), Vector2(-15, 4)], Color("6e7a7d"))
	canvas.draw_line(Vector2(-13, -5), Vector2(-7, -4), STONE_DARK, 1.5)
	canvas.draw_line(Vector2(4, -10), Vector2(10, -3), STONE_DARK, 1.5)
	canvas.draw_line(Vector2(10, -3), Vector2(17, -6), STONE_DARK, 1.1)
	if fraction > 0.35: _stone_chip(canvas, Vector2(-17, 3), 4.8)
	if fraction > 0.7: _stone_chip(canvas, Vector2(16, 3), 3.7)

static func _stone_chip(canvas: CanvasItem, center: Vector2, size: float) -> void:
	_poly(canvas, [center + Vector2(-size, size * 0.45), center + Vector2(-size * 0.5, -size * 0.7), center + Vector2(size * 0.6, -size), center + Vector2(size, size * 0.5)], STONE, true)
	canvas.draw_line(center + Vector2(-size * 0.4, -size * 0.4), center + Vector2(size * 0.5, -size * 0.7), STONE_LIGHT, 1.1)

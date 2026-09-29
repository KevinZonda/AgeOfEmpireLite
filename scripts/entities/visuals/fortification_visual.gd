class_name RtsFortificationVisual
extends RefCounted

# The narrow footprint is a single wall section. The long edge changes with
# wall_vertical, while the gate opening always cuts through its middle.
static func draw_topdown(c: CanvasItem, kind: String, bounds: Rect2, palette: Dictionary, accent: Color, _civ: String, wall_vertical: bool) -> void:
	var stone := kind.begins_with("stone")
	var gate := kind.ends_with("_gate")
	var face: Color = palette["wall"] if stone else palette["timber"]
	var light: Color = palette["trim"] if stone else Color("ad8658")
	var dark: Color = face.darkened(0.38)
	var n0 := 0.27 if stone else 0.34
	var n1 := 0.73 if stone else 0.66
	c.draw_rect(bounds.grow(-3.0), dark)
	_top_quad(c, bounds, 0.0, 1.0, n0, n1, face, wall_vertical)
	if stone:
		_top_quad(c, bounds, 0.02, 0.98, 0.39, 0.61, light.darkened(0.09), wall_vertical)
		for i in 9:
			var t := (float(i) + 0.5) / 9.0
			if gate and t > 0.32 and t < 0.68: continue
			_top_quad(c, bounds, t - 0.03, t + 0.03, n0 - 0.09, n0 + 0.07, light, wall_vertical)
			_top_quad(c, bounds, t - 0.03, t + 0.03, n1 - 0.07, n1 + 0.09, light.darkened(0.12), wall_vertical)
	else:
		# Pointed timber is represented by visible round log tops and two rails.
		for n in [0.38, 0.62]:
			c.draw_line(_top_point(bounds, 0.02, n, wall_vertical), _top_point(bounds, 0.98, n, wall_vertical), light.darkened(0.20), 2.0)
		for i in 13:
			var t := (float(i) + 0.5) / 13.0
			if gate and t > 0.32 and t < 0.68: continue
			c.draw_circle(_top_point(bounds, t, 0.5, wall_vertical), 2.4, light)
			c.draw_circle(_top_point(bounds, t, 0.5, wall_vertical), 1.15, dark)
	if gate:
		# A dark road through the wall remains distinct from the closed leaves.
		_top_quad(c, bounds, 0.32, 0.68, 0.03, 0.97, Color("374039"), wall_vertical)
		_top_quad(c, bounds, 0.345, 0.655, 0.33, 0.67, Color("76553b") if not stone else Color("554d43"), wall_vertical)
		c.draw_line(_top_point(bounds, 0.5, 0.33, wall_vertical), _top_point(bounds, 0.5, 0.67, wall_vertical), light, 1.3)
		for t in [0.26, 0.74]:
			_top_quad(c, bounds, t - 0.075, t + 0.075, n0 - 0.12, n1 + 0.12, face.lightened(0.08), wall_vertical)
			_top_quad(c, bounds, t - 0.047, t + 0.047, 0.37, 0.63, dark, wall_vertical)
		for t in [0.2, 0.72]:
			c.draw_line(_top_point(bounds, t, 0.5, wall_vertical), _top_point(bounds, t + 0.08, 0.5, wall_vertical), accent.darkened(0.18), 1.8)

static func draw_iso(c: CanvasItem, kind: String, nw: Vector2, ne: Vector2, se: Vector2, sw: Vector2, lift: Vector2, palette: Dictionary, accent: Color, _civ: String, wall_vertical: bool, canvas: Transform2D, zoom: float) -> void:
	var far_a := nw
	var far_b := sw if wall_vertical else ne
	var near_a := ne if wall_vertical else sw
	var near_b := se
	# A wall occupies a narrow strip within the 25-unit collision footprint.
	# This keeps the apparent masonry or timber thickness close to AoE4 walls.
	var back_a := far_a.lerp(near_a, 0.34)
	var back_b := far_b.lerp(near_b, 0.34)
	var front_a := far_a.lerp(near_a, 0.71)
	var front_b := far_b.lerp(near_b, 0.71)
	_poly(c, [back_a, back_b, front_b, front_a], Color("252b24", 0.30))
	if kind.begins_with("stone"):
		_stone_iso(c, back_a, back_b, front_a, front_b, lift, palette, accent, kind.ends_with("_gate"))
	else:
		_palisade_iso(c, back_a, back_b, front_a, front_b, lift, palette, accent, kind.ends_with("_gate"), canvas, zoom)

static func _stone_iso(c: CanvasItem, back_a: Vector2, back_b: Vector2, front_a: Vector2, front_b: Vector2, lift: Vector2, palette: Dictionary, accent: Color, gate: bool) -> void:
	var stone: Color = palette["wall"]
	var trim: Color = palette["trim"]
	var shade := stone.darkened(0.29)
	var mortar := shade.darkened(0.17)
	var top := lift
	# The full top walkway and two stone faces replace the generic low plinth.
	_poly(c, [back_a + top, back_b + top, front_b + top, front_a + top], trim.darkened(0.17))
	if gate:
		for section in [[0.0, 0.32], [0.68, 1.0]]:
			_face(c, front_a, front_b, top, float(section[0]), float(section[1]), stone)
			_course_lines(c, front_a, front_b, top, float(section[0]), float(section[1]), mortar)
		# A deep recess behind the stone arch reads as a passage, even at icon scale.
		var a := front_a.lerp(front_b, 0.32)
		var b := front_a.lerp(front_b, 0.68)
		_poly(c, [a, b, b + top * 0.67, front_a.lerp(front_b, 0.60) + top * 0.82, front_a.lerp(front_b, 0.40) + top * 0.82, a + top * 0.67], Color("30332f"))
		var door := Color("705238")
		_poly(c, [a.lerp(b, 0.08), a.lerp(b, 0.49), a.lerp(b, 0.49) + top * 0.55, a.lerp(b, 0.08) + top * 0.55], door)
		_poly(c, [a.lerp(b, 0.51), a.lerp(b, 0.92), a.lerp(b, 0.92) + top * 0.55, a.lerp(b, 0.51) + top * 0.55], door.darkened(0.13))
		c.draw_line(a.lerp(b, 0.5), a.lerp(b, 0.5) + top * 0.57, Color("2f2f2b"), 1.1)
		c.draw_line(a + top * 0.69, front_a.lerp(front_b, 0.40) + top * 0.83, trim, 2.0)
		c.draw_line(front_a.lerp(front_b, 0.40) + top * 0.83, front_a.lerp(front_b, 0.60) + top * 0.83, trim, 2.0)
		c.draw_line(front_a.lerp(front_b, 0.60) + top * 0.83, b + top * 0.69, trim.darkened(0.13), 2.0)
		# Gatehouse lintel carries a narrow parapet and small flanking towers.
		_face(c, front_a, front_b, top * 0.33, 0.32, 0.68, stone.darkened(0.06), top * 0.67)
		for t in [0.22, 0.78]:
			var center := front_a.lerp(front_b, t)
			c.draw_line(center, center + top * 1.18, shade, 6.0)
			c.draw_line(center + top * 0.78, center + top * 1.18, trim, 4.0)
	else:
		_face(c, front_a, front_b, top, 0.0, 1.0, stone)
		_course_lines(c, front_a, front_b, top, 0.0, 1.0, mortar)
	# Merlons alternate with clear gaps rather than forming a solid rail.
	for i in 10:
		var t := (float(i) + 0.5) / 10.0
		if gate and t > 0.34 and t < 0.66: continue
		var at := front_a.lerp(front_b, t) + top
		c.draw_line(at, at + top * 0.34, shade, 5.0)
		c.draw_line(at + top * 0.07, at + top * 0.34, trim, 3.2)
	# A restrained owner stripe sits below the parapet.
	if gate:
		c.draw_line(front_a.lerp(front_b, 0.40) + top * 1.05, front_a.lerp(front_b, 0.60) + top * 1.05, accent.darkened(0.14), 2.0)
	else:
		c.draw_line(front_a.lerp(front_b, 0.07) + top * 0.82, front_a.lerp(front_b, 0.93) + top * 0.82, accent.darkened(0.23), 1.8)

static func _palisade_iso(c: CanvasItem, back_a: Vector2, back_b: Vector2, front_a: Vector2, front_b: Vector2, lift: Vector2, palette: Dictionary, accent: Color, gate: bool, canvas: Transform2D, zoom: float) -> void:
	var timber: Color = palette["timber"]
	var pale := Color("aa8153")
	var dark := timber.darkened(0.24)
	# The back row and shadow give the fence real thickness at both rotations.
	_poly(c, [back_a + lift * 0.85, back_b + lift * 0.85, front_b + lift * 0.85, front_a + lift * 0.85], dark)
	for i in 14:
		var t := (float(i) + 0.5) / 14.0
		if gate and t > 0.30 and t < 0.70: continue
		var foot := front_a.lerp(front_b, t)
		var side := (front_b - front_a) * 0.031
		_poly(c, [foot - side, foot + side, foot + side + lift * 0.91, foot + lift * 1.20, foot - side + lift * 0.91], timber.darkened(0.09 if i % 2 == 0 else 0.18))
		c.draw_line(foot - side * 0.45 + lift * 0.07, foot - side * 0.45 + lift * 0.89, pale.darkened(0.06), 1.0)
	for h in [0.35, 0.68]:
		if gate:
			for section in [[0.01, 0.31], [0.69, 0.99]]:
				c.draw_line(front_a.lerp(front_b, float(section[0])) + lift * h, front_a.lerp(front_b, float(section[1])) + lift * h, dark, 2.6)
		else:
			c.draw_line(front_a.lerp(front_b, 0.01) + lift * h, front_a.lerp(front_b, 0.99) + lift * h, dark, 2.6)
	if gate:
		var left := front_a.lerp(front_b, 0.32)
		var right := front_a.lerp(front_b, 0.68)
		_poly(c, [left, right, right + lift * 0.91, left + lift * 0.91], Color("272c29"))
		# Two wooden gate leaves and diagonal bracing, framed by taller posts.
		var middle := left.lerp(right, 0.5)
		_poly(c, [left + (right - left) * 0.04, middle, middle + lift * 0.69, left + (right - left) * 0.04 + lift * 0.69], Color("8a633f"))
		_poly(c, [middle, right - (right - left) * 0.04, right - (right - left) * 0.04 + lift * 0.69, middle + lift * 0.69], Color("765238"))
		for t in [0.33, 0.43, 0.57, 0.67]:
			var plank := front_a.lerp(front_b, t)
			c.draw_line(plank, plank + lift * 0.68, dark, 1.0)
		c.draw_line(left + lift * 0.12, middle + lift * 0.61, dark, 1.8)
		c.draw_line(middle + lift * 0.61, right + lift * 0.12, dark, 1.8)
		for t in [0.29, 0.71]:
			var post := front_a.lerp(front_b, t)
			c.draw_line(post, post + lift * 1.27, dark, 6.5)
			c.draw_line(post + lift * 0.12, post + lift * 1.18, pale, 3.8)
			var roof_up := RtsIsoProjection.world_delta(canvas, Vector2(0, -3.5 * zoom))
			_poly(c, [post - (right - left) * 0.13 + lift * 1.18, post + roof_up + lift * 1.29, post + (right - left) * 0.13 + lift * 1.18], dark)
		c.draw_line(left + lift * 0.95, right + lift * 0.95, dark, 5.0)
		c.draw_line(left + lift * 0.99, right + lift * 0.99, pale, 2.8)
		c.draw_line(front_a.lerp(front_b, 0.42) + lift * 1.05, front_a.lerp(front_b, 0.58) + lift * 1.05, accent.darkened(0.2), 2.0)
	else:
		c.draw_line(front_a.lerp(front_b, 0.07) + lift * 0.73, front_a.lerp(front_b, 0.93) + lift * 0.73, accent.darkened(0.24), 1.8)

static func _course_lines(c: CanvasItem, a: Vector2, b: Vector2, lift: Vector2, t0: float, t1: float, mortar: Color) -> void:
	for h in [0.34, 0.67]:
		c.draw_line(a.lerp(b, t0) + lift * h, a.lerp(b, t1) + lift * h, mortar, 1.0)
	for i in 8:
		var t := (float(i) + 0.5) / 8.0
		if t <= t0 or t >= t1: continue
		var at := a.lerp(b, t)
		var start := 0.0 if i % 2 == 0 else 0.34
		c.draw_line(at + lift * start, at + lift * (start + 0.33), mortar, 0.9)

static func _face(c: CanvasItem, a: Vector2, b: Vector2, lift: Vector2, t0: float, t1: float, color: Color, base: Vector2 = Vector2.ZERO) -> void:
	var p := a.lerp(b, t0) + base
	var q := a.lerp(b, t1) + base
	_poly(c, [p, q, q + lift, p + lift], color)

static func _top_point(bounds: Rect2, t: float, n: float, vertical: bool) -> Vector2:
	return bounds.position + bounds.size * (Vector2(n, t) if vertical else Vector2(t, n))

static func _top_quad(c: CanvasItem, bounds: Rect2, t0: float, t1: float, n0: float, n1: float, color: Color, vertical: bool) -> void:
	_poly(c, [_top_point(bounds, t0, n0, vertical), _top_point(bounds, t1, n0, vertical), _top_point(bounds, t1, n1, vertical), _top_point(bounds, t0, n1, vertical)], color)

static func _poly(c: CanvasItem, points: Array, color: Color) -> void:
	c.draw_colored_polygon(PackedVector2Array(points), color)

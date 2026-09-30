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
		_gate_topdown(c, bounds, face, light, accent, stone, wall_vertical)

static func draw_iso(c: CanvasItem, kind: String, nw: Vector2, ne: Vector2, se: Vector2, sw: Vector2, lift: Vector2, palette: Dictionary, accent: Color, _civ: String, wall_vertical: bool, _canvas: Transform2D, _zoom: float) -> void:
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
		_palisade_iso(c, back_a, back_b, front_a, front_b, lift, palette, accent, kind.ends_with("_gate"))

static func _stone_iso(c: CanvasItem, back_a: Vector2, back_b: Vector2, front_a: Vector2, front_b: Vector2, lift: Vector2, palette: Dictionary, accent: Color, gate: bool) -> void:
	if gate:
		_stone_gate_iso(c, back_a, back_b, front_a, front_b, lift, palette, accent)
		return
	var stone: Color = palette["wall"]
	var trim: Color = palette["trim"]
	var shade := stone.darkened(0.29)
	var mortar := shade.darkened(0.17)
	var top := lift
	# The full top walkway and two stone faces replace the generic low plinth.
	_poly(c, [back_a + top, back_b + top, front_b + top, front_a + top], trim.darkened(0.17))
	# The far end of the wall is exposed to the isometric camera. Keep its
	# thickness visible below the walkway, including on gate segments.
	_poly(c, [back_b, front_b, front_b + top, back_b + top], shade)
	c.draw_line(back_b + top, front_b + top, trim.darkened(0.2), 1.6)
	_face(c, front_a, front_b, top, 0.0, 1.0, stone)
	_course_lines(c, front_a, front_b, top, 0.0, 1.0, mortar)
	# Merlons alternate with clear gaps rather than forming a solid rail.
	for i in 10:
		var t := (float(i) + 0.5) / 10.0
		var at := front_a.lerp(front_b, t) + top
		c.draw_line(at, at + top * 0.34, shade, 5.0)
		c.draw_line(at + top * 0.07, at + top * 0.34, trim, 3.2)
	# A restrained owner stripe sits below the parapet.
	c.draw_line(front_a.lerp(front_b, 0.07) + top * 0.82, front_a.lerp(front_b, 0.93) + top * 0.82, accent.darkened(0.23), 1.8)

static func _palisade_iso(c: CanvasItem, back_a: Vector2, back_b: Vector2, front_a: Vector2, front_b: Vector2, lift: Vector2, palette: Dictionary, accent: Color, gate: bool) -> void:
	if gate:
		_timber_gate_iso(c, back_a, back_b, front_a, front_b, lift, palette, accent)
		return
	var timber: Color = palette["timber"]
	var pale := Color("aa8153")
	var dark := timber.darkened(0.24)
	# The back row and shadow give the fence real thickness at both rotations.
	_poly(c, [back_a + lift * 0.85, back_b + lift * 0.85, front_b + lift * 0.85, front_a + lift * 0.85], dark)
	_poly(c, [back_b, front_b, front_b + lift * 0.91, back_b + lift * 0.91], timber.darkened(0.34))
	for h in [0.35, 0.68]:
		c.draw_line(back_b + lift * h, front_b + lift * h, pale.darkened(0.16), 1.5)
	for i in 14:
		var t := (float(i) + 0.5) / 14.0
		var foot := front_a.lerp(front_b, t)
		var side := (front_b - front_a) * 0.031
		_poly(c, [foot - side, foot + side, foot + side + lift * 0.91, foot + lift * 1.20, foot - side + lift * 0.91], timber.darkened(0.09 if i % 2 == 0 else 0.18))
		c.draw_line(foot - side * 0.45 + lift * 0.07, foot - side * 0.45 + lift * 0.89, pale.darkened(0.06), 1.0)
	for h in [0.35, 0.68]:
		c.draw_line(front_a.lerp(front_b, 0.01) + lift * h, front_a.lerp(front_b, 0.99) + lift * h, dark, 2.6)
	c.draw_line(front_a.lerp(front_b, 0.07) + lift * 0.73, front_a.lerp(front_b, 0.93) + lift * 0.73, accent.darkened(0.24), 1.8)

# Gatehouse geometry uses the same along-wall/depth basis at both rotations.
# Heights are multiples of the existing 11-unit wall height; collision stays unchanged.
static func _gate_topdown(c: CanvasItem, bounds: Rect2, stone: Color, trim: Color, accent: Color, masonry: bool, vertical: bool) -> void:
	_top_quad(c, bounds, 0.33, 0.67, 0.0, 1.0, Color("6d705b"), vertical)
	for i in 5:
		var n := float(i) / 5.0
		_top_quad(c, bounds, 0.365, 0.635, n + 0.015, n + 0.17, Color("a49c7c").darkened(0.06 if i % 2 else 0.0), vertical)
	_top_quad(c, bounds, 0.32, 0.68, 0.24, 0.76, Color("34392f"), vertical)
	_top_quad(c, bounds, 0.35, 0.65, 0.42, 0.58, Color("735239"), vertical)
	for t in [0.38, 0.44, 0.50, 0.56, 0.62]:
		c.draw_line(_top_point(bounds, t, 0.43, vertical), _top_point(bounds, t, 0.57, vertical), Color("ad8959"), 0.9)
	for t in [0.265, 0.735]:
		_top_quad(c, bounds, t - 0.11, t + 0.11, 0.035, 1.0, Color("29332a", 0.27), vertical)
		_top_quad(c, bounds, t - 0.09, t + 0.09, 0.06, 0.94, stone.darkened(0.29), vertical)
		_top_quad(c, bounds, t - 0.077, t + 0.077, 0.10, 0.87, trim if masonry else Color("936640"), vertical)
		_top_quad(c, bounds, t - 0.045, t + 0.045, 0.26, 0.71, stone.darkened(0.38), vertical)
		if masonry:
			for at in [t - 0.062, t + 0.062]:
				for n in [0.18, 0.48, 0.78]:
					_top_quad(c, bounds, at - 0.02, at + 0.02, n - 0.07, n + 0.07, trim.lightened(0.11), vertical)
			for n in [0.15, 0.80]:
				_top_quad(c, bounds, t - 0.025, t + 0.025, n - 0.05, n + 0.05, trim, vertical)
		else:
			_top_quad(c, bounds, t - 0.087, t + 0.087, 0.11, 0.88, Color("70503b"), vertical)
			_top_quad(c, bounds, t - 0.087, t, 0.11, 0.88, Color("9c7350"), vertical)
			c.draw_line(_top_point(bounds, t, 0.10, vertical), _top_point(bounds, t, 0.88, vertical), Color("b9986f"), 1.2)
			for n in [0.27, 0.44, 0.61, 0.77]:
				c.draw_line(_top_point(bounds, t - 0.085, n, vertical), _top_point(bounds, t + 0.085, n, vertical), Color("3b3028", 0.45), 0.8)
		_top_quad(c, bounds, t - 0.033, t + 0.033, 0.81, 0.89, accent.darkened(0.12), vertical)
	# A roofed timber gallery or stone fighting platform spans the gate.
	_top_quad(c, bounds, 0.35, 0.65, 0.25, 0.38, trim.darkened(0.15), vertical)
	_top_quad(c, bounds, 0.35, 0.65, 0.63, 0.75, trim.darkened(0.30), vertical)
	if masonry:
		for t in [0.39, 0.50, 0.61]:
			_top_quad(c, bounds, t - 0.02, t + 0.02, 0.25, 0.34, trim.lightened(0.07), vertical)
	else:
		_top_quad(c, bounds, 0.35, 0.65, 0.30, 0.50, Color("9c7350"), vertical)
		_top_quad(c, bounds, 0.35, 0.65, 0.50, 0.70, Color("70503b"), vertical)
		c.draw_line(_top_point(bounds, 0.35, 0.50, vertical), _top_point(bounds, 0.65, 0.50, vertical), Color("b9986f"), 1.2)

static func _stone_gate_iso(c: CanvasItem, ba: Vector2, bb: Vector2, fa: Vector2, fb: Vector2, lift: Vector2, palette: Dictionary, accent: Color) -> void:
	var stone: Color = palette["wall"]
	var trim: Color = palette["trim"]
	var shade := stone.darkened(0.27)
	# Wall shoulders end against the wider gatehouse, rather than running
	# a solid wall behind the opening.
	for span in [[0.0, 0.18], [0.82, 1.0]]:
		var t0: float = span[0]
		var t1: float = span[1]
		_poly(c, [ba.lerp(bb, t0) + lift, ba.lerp(bb, t1) + lift, fa.lerp(fb, t1) + lift, fa.lerp(fb, t0) + lift], trim.darkened(0.16))
		_face(c, fa, fb, lift, t0, t1, stone)
		_course_lines(c, fa, fb, lift, t0, t1, shade)
		for t in [t0 + 0.035, t0 + 0.105, t0 + 0.17]:
			if t > t1: continue
			_face(c, fa, fb, lift * 0.28, t - 0.023, t + 0.023, trim, lift)
	_poly(c, [bb, fb, fb + lift, bb + lift], shade)
	var gb := ba.lerp(fa, -0.45)
	var ge := bb.lerp(fb, -0.45)
	var gf := ba.lerp(fa, 1.30)
	var gh := bb.lerp(fb, 1.30)
	# Approach paving and the deep, darker rear of the passage.
	_poly(c, [gb.lerp(ge, 0.33), gb.lerp(ge, 0.67), gf.lerp(gh, 0.67), gf.lerp(gh, 0.33)], Color("a49c7c"))
	_stone_gate_tower(c, gb, ge, gf, gh, lift, 0.17, 0.35, stone, trim, accent)
	var a := gf.lerp(gh, 0.35)
	var b := gf.lerp(gh, 0.65)
	var arch: Array = [a, b, b + lift * 1.35, a.lerp(b, 0.87) + lift * 1.73, a.lerp(b, 0.68) + lift * 1.92, a.lerp(b, 0.5) + lift * 1.98, a.lerp(b, 0.32) + lift * 1.92, a.lerp(b, 0.13) + lift * 1.73, a + lift * 1.35]
	_poly(c, arch, Color("272e28"))
	# Two arched doors sit behind the dressed-stone reveal.
	_poly(c, [a.lerp(b, 0.07), a.lerp(b, 0.49), a.lerp(b, 0.49) + lift * 1.76, a.lerp(b, 0.28) + lift * 1.67, a.lerp(b, 0.07) + lift * 1.28], Color("805936"))
	_poly(c, [a.lerp(b, 0.51), a.lerp(b, 0.93), a.lerp(b, 0.93) + lift * 1.28, a.lerp(b, 0.72) + lift * 1.67, a.lerp(b, 0.51) + lift * 1.76], Color("68482f"))
	for i in 7:
		var t := 0.10 + float(i) * 0.13
		var plank := a.lerp(b, t)
		var h := 1.30 + 0.43 * (1.0 - absf(t - 0.5) * 2.0)
		c.draw_line(plank + lift * 0.07, plank + lift * h, Color("342b24", 0.75), 0.8)
	for h in [0.35, 0.97]:
		c.draw_line(a.lerp(b, 0.08) + lift * h, a.lerp(b, 0.46) + lift * h, Color("343b36"), 1.8)
		c.draw_line(a.lerp(b, 0.54) + lift * h, a.lerp(b, 0.92) + lift * h, Color("343b36"), 1.8)
	c.draw_line(a.lerp(b, 0.5), a.lerp(b, 0.5) + lift * 1.75, Color("272923"), 1.2)
	# The bridge face has an actual arched lower boundary, so the masonry
	# never fills in the doorway after it has been drawn.
	_poly(c, [a + lift * 1.35, a.lerp(b, 0.13) + lift * 1.73, a.lerp(b, 0.32) + lift * 1.92, a.lerp(b, 0.5) + lift * 1.98, a.lerp(b, 0.68) + lift * 1.92, a.lerp(b, 0.87) + lift * 1.73, b + lift * 1.35, b + lift * 2.32, a + lift * 2.32], stone)
	var inner: Array[Vector2] = [Vector2(0.0, 1.35), Vector2(0.13, 1.73), Vector2(0.32, 1.92), Vector2(0.5, 1.98), Vector2(0.68, 1.92), Vector2(0.87, 1.73), Vector2(1.0, 1.35)]
	var outer: Array[Vector2] = [Vector2(-0.055, 1.38), Vector2(0.08, 1.89), Vector2(0.29, 2.10), Vector2(0.5, 2.16), Vector2(0.71, 2.10), Vector2(0.92, 1.89), Vector2(1.055, 1.38)]
	for i in 6:
		_poly(c, [a.lerp(b, inner[i].x) + lift * inner[i].y, a.lerp(b, inner[i+1].x) + lift * inner[i+1].y, a.lerp(b, outer[i+1].x) + lift * outer[i+1].y, a.lerp(b, outer[i].x) + lift * outer[i].y], trim.darkened(0.08 if i % 2 else 0.0))
		c.draw_line(a.lerp(b, inner[i].x) + lift * inner[i].y, a.lerp(b, outer[i].x) + lift * outer[i].y, shade, 0.65)
	_poly(c, [gb.lerp(ge, 0.35) + lift * 2.32, gb.lerp(ge, 0.65) + lift * 2.32, b + lift * 2.32, a + lift * 2.32], trim.darkened(0.19))
	c.draw_line(a + lift * 2.30, b + lift * 2.30, trim, 1.4)
	for t in [0.39, 0.5, 0.61]:
		_face(c, gf, gh, lift * 0.29, t - 0.022, t + 0.022, trim, lift * 2.32)
	_stone_gate_tower(c, gb, ge, gf, gh, lift, 0.65, 0.83, stone, trim, accent)

static func _stone_gate_tower(c: CanvasItem, ba: Vector2, bb: Vector2, fa: Vector2, fb: Vector2, lift: Vector2, t0: float, t1: float, stone: Color, trim: Color, accent: Color) -> void:
	var a := ba.lerp(bb, t0)
	var b := ba.lerp(bb, t1)
	var d := fa.lerp(fb, t0)
	var e := fa.lerp(fb, t1)
	var up := lift * 2.55
	var shade := stone.darkened(0.26)
	_poly(c, [b, e, e + up, b + up], shade)
	_poly(c, [d, e, e + up, d + up], stone)
	# Splayed stone footing and two simple courses give each pier weight.
	_poly(c, [d, e, e + lift * 0.18, d + lift * 0.18], trim.darkened(0.15))
	for h in [0.48, 1.0, 1.5, 2.02]:
		c.draw_line(d + lift * h, e + lift * h, Color(shade, 0.62), 0.75)
		c.draw_line(e + lift * h, b + lift * h, shade.darkened(0.12), 0.75)
	var slit := d.lerp(e, 0.50) + lift * 1.32
	c.draw_line(slit, slit + lift * 0.48, trim, 2.7)
	c.draw_line(slit + lift * 0.04, slit + lift * 0.44, Color("333b30"), 1.2)
	var side_slit := b.lerp(e, 0.55) + lift * 1.28
	c.draw_line(side_slit, side_slit + lift * 0.42, Color("343a30"), 1.2)
	# A projecting cornice supports an open crenellated fighting platform.
	_poly(c, [a + up, b + up, e + up, d + up], trim.darkened(0.38))
	c.draw_line(d + up, e + up, trim, 2.5)
	c.draw_line(b + up, e + up, trim.darkened(0.16), 2.5)
	for t in [0.08, 0.5, 0.92]:
		var p := d.lerp(e, t)
		var width := (e - d) * 0.10
		_poly(c, [p - width + up, p + width + up, p + width + up + lift * 0.31, p - width + up + lift * 0.31], trim)
	for n in [0.08, 0.5, 0.92]:
		var p := b.lerp(e, n)
		var width := (e - b) * 0.10
		_poly(c, [p - width + up, p + width + up, p + width + up + lift * 0.31, p - width + up + lift * 0.31], trim.darkened(0.20))
	# A short hanging owner pennant leaves most masonry unpainted.
	var mid := d.lerp(e, 0.50)
	var w := (e - d) * 0.13
	_poly(c, [mid - w + lift * 2.21, mid + w + lift * 2.21, mid + w + lift * 1.82, mid + lift * 1.73, mid - w + lift * 1.82], accent.darkened(0.10))

static func _timber_gate_iso(c: CanvasItem, ba: Vector2, bb: Vector2, fa: Vector2, fb: Vector2, lift: Vector2, palette: Dictionary, accent: Color) -> void:
	var timber: Color = palette["timber"]
	var pale := Color("ad8658")
	var dark := timber.darkened(0.26)
	for span in [[0.0, 0.20], [0.80, 1.0]]:
		for i in 4:
			var t: float = float(span[0]) + 0.025 + float(i) * 0.051
			var foot := fa.lerp(fb, t)
			var side := (fb - fa) * 0.025
			_poly(c, [foot - side, foot + side, foot + side + lift * 0.88, foot + lift * 1.2, foot - side + lift * 0.88], timber.darkened(0.06 if i % 2 == 0 else 0.17))
			c.draw_line(foot + lift * 0.08, foot + lift * 0.87, pale, 0.8)
		for h in [0.32, 0.65]:
			c.draw_line(fa.lerp(fb, float(span[0])) + lift * h, fa.lerp(fb, float(span[1])) + lift * h, dark, 2.2)
	_poly(c, [bb, fb, fb + lift * 0.88, bb + lift * 0.88], dark)
	for h in [0.32, 0.65]:
		c.draw_line(bb + lift * h, fb + lift * h, pale.darkened(0.18), 1.3)
	var gb := ba.lerp(fa, -0.35)
	var ge := bb.lerp(fb, -0.35)
	var gf := ba.lerp(fa, 1.20)
	var gh := bb.lerp(fb, 1.20)
	_poly(c, [gb.lerp(ge, 0.34), gb.lerp(ge, 0.66), gf.lerp(gh, 0.66), gf.lerp(gh, 0.34)], Color("82745a"))
	_timber_gate_tower(c, gb, ge, gf, gh, lift, 0.20, 0.34, timber, pale)
	var a := gf.lerp(gh, 0.34)
	var b := gf.lerp(gh, 0.66)
	_poly(c, [a, b, b + lift * 1.74, a + lift * 1.74], Color("2f3328"))
	_face(c, a, b, lift * 1.42, 0.04, 0.49, Color("986c43"))
	_face(c, a, b, lift * 1.42, 0.51, 0.96, Color("805735"))
	for t in [0.12, 0.24, 0.36, 0.64, 0.76, 0.88]:
		c.draw_line(a.lerp(b, t), a.lerp(b, t) + lift * 1.40, dark, 0.8)
	for h in [0.17, 1.21]:
		c.draw_line(a.lerp(b, 0.06) + lift * h, a.lerp(b, 0.46) + lift * h, dark, 1.8)
		c.draw_line(a.lerp(b, 0.54) + lift * h, a.lerp(b, 0.94) + lift * h, dark, 1.8)
	c.draw_line(a.lerp(b, 0.08) + lift * 0.21, a.lerp(b, 0.46) + lift * 1.19, pale.darkened(0.18), 1.4)
	c.draw_line(a.lerp(b, 0.54) + lift * 1.19, a.lerp(b, 0.92) + lift * 0.21, pale.darkened(0.18), 1.4)
	# Covered gallery above the two doors, with exposed structural braces.
	_face(c, gf, gh, lift * 0.22, 0.32, 0.68, dark, lift * 1.60)
	c.draw_line(a + lift * 1.65, b + lift * 1.65, pale, 1.5)
	var ra := gb.lerp(ge, 0.30) + lift * 1.88
	var rb := gb.lerp(ge, 0.70) + lift * 1.88
	var rc := gf.lerp(gh, 0.70) + lift * 1.88
	var rd := gf.lerp(gh, 0.30) + lift * 1.88
	var ridge_a := ra.lerp(rd, 0.5) + lift * 0.39
	var ridge_b := rb.lerp(rc, 0.5) + lift * 0.39
	_poly(c, [ra, rb, ridge_b, ridge_a], Color("916848"))
	_poly(c, [ridge_a, ridge_b, rc, rd], Color("634a36"))
	c.draw_line(ridge_a, ridge_b, pale, 1.2)
	c.draw_line(rd, rc, Color("342d25"), 1.6)
	var mid := a.lerp(b, 0.5)
	var w := (b - a) * 0.10
	_poly(c, [mid - w + lift * 1.70, mid + w + lift * 1.70, mid + w + lift * 1.43, mid + lift * 1.37, mid - w + lift * 1.43], accent.darkened(0.12))
	_timber_gate_tower(c, gb, ge, gf, gh, lift, 0.66, 0.80, timber, pale)

static func _timber_gate_tower(c: CanvasItem, ba: Vector2, bb: Vector2, fa: Vector2, fb: Vector2, lift: Vector2, t0: float, t1: float, timber: Color, pale: Color) -> void:
	var a := ba.lerp(bb, t0)
	var b := ba.lerp(bb, t1)
	var d := fa.lerp(fb, t0)
	var e := fa.lerp(fb, t1)
	var dark := timber.darkened(0.32)
	_poly(c, [b, e, e + lift * 1.87, b + lift * 1.87], dark)
	_poly(c, [d, e, e + lift * 1.87, d + lift * 1.87], timber)
	for t in [0.0, 0.5, 1.0]:
		c.draw_line(d.lerp(e, t), d.lerp(e, t) + lift * 1.86, pale.darkened(0.13), 1.6)
	for h in [0.2, 0.78, 1.26, 1.76]:
		c.draw_line(d + lift * h, e + lift * h, dark, 1.3)
	c.draw_line(d + lift * 0.26, e + lift * 1.19, pale.darkened(0.18), 1.3)
	var slit := d.lerp(e, 0.5) + lift * 1.40
	c.draw_line(slit, slit + lift * 0.28, Color("293126"), 1.5)
	var up := lift * 1.93
	var over := (e - d) * 0.12
	var depth := (d - a) * 0.10
	var ra := a - over - depth + up
	var rb := b + over - depth + up
	var rc := e + over + depth + up
	var rd := d - over + depth + up
	var ridge_a := ra.lerp(rd, 0.5) + lift * 0.42
	var ridge_b := rb.lerp(rc, 0.5) + lift * 0.42
	_poly(c, [ra, rb, ridge_b, ridge_a], Color("986c49"))
	_poly(c, [ridge_a, ridge_b, rc, rd], Color("674c35"))
	_poly(c, [rb, rc, ridge_b], Color("503d2c"))
	c.draw_line(rd, rc, Color("342d25"), 1.4)
	c.draw_line(ridge_a, ridge_b, pale, 1.2)

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

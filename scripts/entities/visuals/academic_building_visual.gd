extends RefCounted

# Six small civic/religious complexes. Every visible structure contributes local
# 3D faces to the owning renderer so roofs, galleries and towers share its BSP.
static func handles(kind: String) -> bool:
	return kind in ["university", "monastery"]

static func _layout(kind: String, civilization: String) -> Array:
	if kind == "university":
		match civilization:
			"Chinese": return [[0.5, 0.25, 0.72, 0.27, 18, "temple"], [0.17, 0.55, 0.17, 0.34, 9, "temple"], [0.83, 0.55, 0.17, 0.34, 9, "temple"], [0.5, 0.84, 0.32, 0.15, 11, "temple"], [0.78, 0.25, 0.16, 0.17, 27, "temple"]]
			"French": return [[0.5, 0.26, 0.74, 0.25, 23, "hip"], [0.17, 0.56, 0.17, 0.34, 14, "hip"], [0.83, 0.56, 0.17, 0.34, 14, "hip"], [0.5, 0.83, 0.24, 0.16, 16, "hip"], [0.8, 0.25, 0.16, 0.18, 34, "hip"]]
		return [[0.5, 0.26, 0.74, 0.24, 21, "gable"], [0.17, 0.56, 0.17, 0.34, 13, "timber"], [0.83, 0.56, 0.17, 0.34, 13, "timber"], [0.5, 0.83, 0.23, 0.16, 17, "timber"], [0.5, 0.26, 0.17, 0.18, 31, "spire"]]
	match civilization:
		"Chinese": return [[0.5, 0.25, 0.7, 0.29, 22, "temple"], [0.16, 0.56, 0.17, 0.3, 9, "temple"], [0.84, 0.5, 0.17, 0.25, 9, "temple"], [0.48, 0.8, 0.38, 0.2, 17, "double_temple"], [0.82, 0.77, 0.17, 0.19, 29, "temple"]]
		"French": return [[0.5, 0.26, 0.74, 0.25, 24, "gable"], [0.17, 0.56, 0.17, 0.34, 13, "gable"], [0.83, 0.56, 0.17, 0.34, 13, "gable"], [0.5, 0.83, 0.27, 0.17, 18, "gable"], [0.2, 0.25, 0.17, 0.2, 35, "spire"]]
	return [[0.43, 0.46, 0.31, 0.65, 23, "church"], [0.65, 0.48, 0.16, 0.51, 11, "gable"], [0.75, 0.25, 0.17, 0.21, 36, "spire"], [0.14, 0.53, 0.15, 0.4, 10, "timber"]]

static func _colors(civilization: String) -> Dictionary:
	if civilization == "Chinese":
		return {"wall": Color("d8c6a0"), "trim": Color("dec58e"), "roof": Color("53645c"), "roof_dark": Color("303f39"), "timber": Color("824536")}
	if civilization == "French":
		return {"wall": Color("d3c7ad"), "trim": Color("e5dac1"), "roof": Color("52677a"), "roof_dark": Color("344756"), "timber": Color("75604a")}
	return {"wall": Color("beb59e"), "trim": Color("dbcfb0"), "roof": Color("635f55"), "roof_dark": Color("423f39"), "timber": Color("64503c")}

static func populate(g, kind: String, civilization: String, player: Color) -> void:
	if not handles(kind): return
	g.palette = _colors(civilization)
	if civilization == "Chinese" and kind == "university":
		g.palette["roof"] = Color("68716b")
		g.palette["roof_dark"] = Color("414c45")
	elif civilization == "Chinese":
		g.palette["roof"] = Color("8c7053")
		g.palette["roof_dark"] = Color("594837")
	g.box(Vector2.ZERO, g.dimensions * 0.95, g.base_z, 0.7, Color("a99e86"))
	# Low paving and a wide empty center make both courts legible at game zoom.
	for row in [0.5, 0.66, 0.79, 0.93]:
		var a := _p(g, 0.1, row, 0.76)
		var b := _p(g, 0.9, row, 0.76)
		g.face([a, b, b + Vector3(0, 0.3, 0), a + Vector3(0, 0.3, 0)], Color("8e8975"))
	for form in _layout(kind, civilization): _hall(g, form, civilization)
	if civilization == "Chinese":
		# A paired finial on the main ridge, distinct from a pagoda pyramid.
		for u in [0.34, 0.66]:
			g.box(_xy(g, u, 0.25), Vector2(1.0, 1.0), g.base_z + (33.5 if kind == "monastery" else 29.5), 2.1, g.palette["trim"])
		var gate_v := 0.8 if kind == "monastery" else 0.84
		_banner(g, 0.5, gate_v + (0.13 if kind == "monastery" else 0.09), 9.0 if kind == "university" else 9.5, player)
		# A low altar/reading desk is visible in the courtyard.
		g.box(_xy(g, 0.5, 0.61), Vector2(7, 5), g.base_z + 0.8, 2.7, Color("756752"))
		if kind == "monastery":
			_roof(g, 0.82, 0.77, 0.24, 0.26, 20.5, "temple", 6.0)
			g.box(_xy(g, 0.5, 0.61), Vector2(4, 3), g.base_z + 3.5, 1.7, Color("a99565"))
	else:
		var tower := Vector2(0.5, 0.26) if kind == "university" and civilization == "English" else Vector2(0.8, 0.25) if kind == "university" else Vector2(0.2, 0.25) if civilization == "French" else Vector2(0.75, 0.25)
		var tower_h := 31.0 if kind == "university" and civilization == "English" else 34.0 if kind == "university" else 35.0 if civilization == "French" else 36.0
		if kind == "university":
			_clock(g, tower.x, tower.y + 0.1, tower_h * 0.72)
		else:
			_cross(g, tower.x, tower.y, tower_h + 13.0)
			if civilization == "English":
				var rose := _p(g, 0.43, 0.787, 27.0)
				g.disc(rose, 2.2, g.palette["trim"])
				g.disc(rose + Vector3(0, 0.02, 0), 1.45, Color("52635f"))
				for v in [0.22, 0.42, 0.63]:
					g.box(_xy(g, 0.60, v), Vector2(2.0, 4.0), g.base_z, 15.0, g.palette["wall"].darkened(0.1))
			else:
				# Two open gallery runs frame the central garden.
				for u in [0.3, 0.5, 0.7]:
					g.box(_xy(g, u, 0.43), Vector2(1.7, 1.7), g.base_z + 0.8, 8.0, g.palette["trim"])
				_roof(g, 0.5, 0.41, 0.53, 0.12, 9, "gable", 3.5)
				g.box(_xy(g, 0.5, 0.61), Vector2(12, 9), g.base_z + 0.8, 0.3, Color("6d7954"))
		_banner(g, 0.64 if kind == "university" else 0.49, 0.384 if kind == "university" else 0.788 if civilization == "English" else 0.923, 17 if kind == "university" else 12, player)
		if kind == "university":
			g.box(_xy(g, 0.5, 0.61), Vector2(8, 5), g.base_z + 0.8, 3, Color("837861"))
			for u in [0.42, 0.58]: g.box(_xy(g, u, 0.62), Vector2(3, 5), g.base_z + 0.8, 1.5, g.palette["timber"])
	# Shallow entry steps sit on the paving rather than a tall display plinth.
	var entry := 0.825 if civilization == "English" and kind == "monastery" else 0.945
	for index in 3:
		g.box(_xy(g, 0.43 if entry < 0.9 else 0.5, entry + index * 0.018), Vector2(g.dimensions.x * 0.19, 2.2), g.base_z, 1.7 - index * 0.45, g.palette["trim"].darkened(0.16))

static func _xy(g, u: float, v: float) -> Vector2:
	return Vector2(u - 0.5, v - 0.5) * g.dimensions

static func _p(g, u: float, v: float, z: float) -> Vector3:
	var xy := _xy(g, u, v)
	return Vector3(xy.x, xy.y, g.base_z + z)

static func _ribbon(g, a: Vector3, b: Vector3, width: float, color: Color, side := false) -> void:
	var across := Vector3(0, width * 0.5, 0) if side else Vector3(width * 0.5, 0, 0)
	if absf(a.z - b.z) < 0.01: across = Vector3(0, 0, width * 0.5)
	g.face([a - across, b - across, b + across, a + across], color)

static func _arch(g, u: float, v: float, z: float, width: float, height: float, side := false) -> void:
	# Both polygons run around the contour in order; no bow-tie/self crossing.
	var center := _p(g, u, v, z)
	var horizontal := Vector3(0, 1, 0) if side else Vector3(1, 0, 0)
	for inset in [0, 1]:
		var half := maxf(0.7, width * 0.5 - inset * 0.7)
		var base := center + Vector3(0, 0, inset * 0.8) + (Vector3(0.02 * inset, 0, 0) if side else Vector3(0, 0.02 * inset, 0))
		var h: float = height - inset * 1.2
		g.face([base - horizontal * half, base + horizontal * half, base + horizontal * half + Vector3(0, 0, h * 0.67), base + horizontal * half * 0.67 + Vector3(0, 0, h * 0.91), base + Vector3(0, 0, h), base - horizontal * half * 0.67 + Vector3(0, 0, h * 0.91), base - horizontal * half + Vector3(0, 0, h * 0.67)], g.palette["trim"] if inset == 0 else Color("354544"))

static func _hall(g, form: Array, civilization: String) -> void:
	var u: float = form[0]
	var v: float = form[1]
	var w: float = form[2]
	var d: float = form[3]
	var h: float = form[4]
	var style: String = form[5]
	var center := _xy(g, u, v)
	var extent: Vector2 = Vector2(w, d) * g.dimensions
	var stone: Color = g.palette["wall"]
	if style in ["temple", "double_temple"]:
		g.box(center, extent + Vector2.ONE * 1.0, g.base_z + 0.7, 1.8, stone.darkened(0.12))
		g.box(center - Vector2(0, extent.y * 0.09), extent * Vector2(0.88, 0.65), g.base_z + 2.5, h - 2.5, stone)
		var front := v + d * 0.48
		for fraction in [0.12, 0.37, 0.63, 0.88]:
			g.box(_xy(g, u + (fraction - 0.5) * w, front), Vector2(1.7, 1.7), g.base_z + 2.5, h - 2.5, g.palette["timber"])
		var screen_y := v + d * 0.24 + 0.001
		for fraction in [0.24, 0.5, 0.76]:
			var a := _p(g, u + (fraction - 0.5) * w - 0.024, screen_y, 3.0)
			var b := _p(g, u + (fraction - 0.5) * w + 0.024, screen_y, h - 3.0)
			g.face([a, Vector3(b.x, a.y, a.z), b, Vector3(a.x, b.y, b.z)], g.palette["timber"].darkened(0.14))
		_roof(g, u, v, w + 0.065, d + 0.065, h, "temple", 11.5 if w > 0.5 else 7.5 if h > 24 else 5.0)
		if style == "double_temple": _roof(g, u, v, w + 0.1, d + 0.1, h - 6.0, "temple", 4.5)
		return
	g.box(center, extent, g.base_z + 0.7, h - 0.7, stone)
	g.box(center, extent + Vector2.ONE * 1.0, g.base_z + 0.7, 2.0, stone.darkened(0.18))
	var front_v := v + d * 0.5 + 0.001
	for fraction in ([0.17, 0.39, 0.61, 0.83] if w > 0.5 else [0.5]):
		_arch(g, u + (fraction - 0.5) * w, front_v, h * 0.45, 3.1, h * 0.24)
	_arch(g, u + w * 0.5 + 0.001, v, h * 0.45, 3.0, h * 0.24, true)
	if w > 0.2:
		_arch(g, u, front_v + 0.03, 0.8, 5.2, minf(13.0, h * 0.6))
	if style == "timber":
		for fraction in [0.12, 0.5, 0.88]:
			var a := _p(g, u + (fraction - 0.5) * w, front_v + 0.04, 3.0)
			_ribbon(g, a, a + Vector3(0, 0, h - 3.0), 1.4, g.palette["timber"])
		_ribbon(g, _p(g, u - w * 0.5, front_v + 0.04, h * 0.36), _p(g, u + w * 0.5, front_v + 0.04, h * 0.36), 1.2, g.palette["timber"])
	else:
		for fraction in [0.25, 0.67]:
			_ribbon(g, _p(g, u - w * 0.5, front_v + 0.005, h * fraction), _p(g, u + w * 0.5, front_v + 0.005, h * fraction), 0.35, stone.darkened(0.15))
	_roof(g, u, v, w + 0.035, d + 0.035, h, style, 13.0 if style in ["church", "spire"] else 10.0 if civilization == "French" else 7.0)

static func _roof(g, u: float, v: float, w: float, d: float, z: float, style: String, rise: float) -> void:
	var roof: Color = g.palette["roof"]
	var dark: Color = g.palette["roof_dark"]
	var center := _xy(g, u, v)
	var extent: Vector2 = Vector2(w, d) * g.dimensions
	# Closed dark fascia gives the eaves measurable thickness.
	g.box(center, extent, g.base_z + z - 0.8, 0.8, dark)
	var a := _p(g, u - w * 0.5, v - d * 0.5, z)
	var b := _p(g, u + w * 0.5, v - d * 0.5, z)
	var c := _p(g, u + w * 0.5, v + d * 0.5, z)
	var e := _p(g, u - w * 0.5, v + d * 0.5, z)
	if style == "spire":
		g.pyramid(a, b, c, e, rise, roof)
		return
	var along_x := w >= d
	var first := (a + e) * 0.5 if along_x else (a + b) * 0.5
	var last := (b + c) * 0.5 if along_x else (e + c) * 0.5
	var inset := 0.18 if style in ["hip", "temple"] else 0.0
	var left := first.lerp(last, inset) + Vector3(0, 0, rise)
	var right := last.lerp(first, inset) + Vector3(0, 0, rise)
	if style == "temple":
		# Three connected roof bands bow upward toward the eave. Hip end bands
		# join each strip to a corresponding ridge cap; no stacked pyramids.
		var edge_a := a if along_x else b
		var edge_b := b if along_x else c
		var edge_c := e if along_x else a
		var edge_d := c if along_x else e
		for back in [true, false]:
			var outer_a := edge_a if back else edge_c
			var outer_b := edge_b if back else edge_d
			var previous_a := outer_a + Vector3(0, 0, 1.2)
			var previous_b := outer_b + Vector3(0, 0, 1.2)
			g.face([outer_a, outer_b, previous_b, previous_a], dark)
			for fraction in [0.32, 0.68, 1.0]:
				var h := rise * pow(fraction, 1.35)
				var next_a := outer_a.lerp(left, fraction)
				var next_b := outer_b.lerp(right, fraction)
				next_a.z = g.base_z + z + h
				next_b.z = g.base_z + z + h
				g.face([previous_a, previous_b, next_b, next_a], roof.lightened(0.10) if back else roof.darkened(0.07))
				previous_a = next_a
				previous_b = next_b
		# Hip closures fill the ends and thick turned-up eaves mark the corners.
		g.face([a, e, left], roof.lightened(0.03))
		g.face([b, c, right], roof.darkened(0.12))
		for corner in [a, b, c, e]:
			var hub := (a + c) * 0.5
			var raised: Vector3 = hub + (corner - hub) * 1.04 + Vector3(0, 0, 2.2)
			g.face([corner, raised, raised + Vector3(0, 0, -1), corner + Vector3(0, 0, -0.7)], dark)
	elif along_x:
		g.face([a, b, right, left], roof.lightened(0.13))
		g.face([left, right, c, e], roof.darkened(0.08))
		g.face([a, e, left], roof.lightened(0.04) if inset else g.palette["wall"])
		g.face([b, c, right], roof.darkened(0.18) if inset else g.palette["wall"])
	else:
		g.face([a, left, right, e], roof.lightened(0.13))
		g.face([left, b, c, right], roof.darkened(0.08))
		g.face([a, b, left], roof.lightened(0.04) if inset else g.palette["wall"])
		g.face([e, c, right], roof.darkened(0.18) if inset else g.palette["wall"])
	_ribbon(g, left + Vector3(0, 0, 0.08), right + Vector3(0, 0, 0.08), 0.9, g.palette["trim"].darkened(0.19))

static func _clock(g, u: float, v: float, z: float) -> void:
	var center := _p(g, u, v + 0.003, z)
	g.disc(center, 3.0, g.palette["trim"])
	g.disc(center + Vector3(0, 0.02, 0), 2.25, Color("394746"))
	_ribbon(g, center + Vector3(0, 0.04, 0), center + Vector3(1.5, 0.04, 0.8), 0.45, g.palette["trim"])
	_ribbon(g, center + Vector3(0, 0.04, 0), center + Vector3(0, 0.04, 1.9), 0.45, g.palette["trim"])

static func _cross(g, u: float, v: float, z: float) -> void:
	g.box(_xy(g, u, v), Vector2(0.9, 0.9), g.base_z + z, 4.0, g.palette["trim"])
	g.box(_xy(g, u, v), Vector2(4.0, 0.9), g.base_z + z + 2.3, 0.8, g.palette["trim"])

static func _banner(g, u: float, v: float, z: float, player: Color) -> void:
	var p := _p(g, u, v, z)
	g.face([p, p + Vector3(4, 0, 0), p + Vector3(4, 0, -5), p + Vector3(2, 0, -6), p + Vector3(0, 0, -5)], player)

static func draw_topdown(c: CanvasItem, bounds: Rect2, kind: String, civilization: String, _palette: Dictionary, player: Color) -> void:
	if not handles(kind): return
	var palette := _colors(civilization)
	if civilization == "Chinese" and kind == "university":
		palette["roof"] = Color("68716b")
		palette["roof_dark"] = Color("414c45")
	elif civilization == "Chinese":
		palette["roof"] = Color("8c7053")
		palette["roof_dark"] = Color("594837")
	var area := bounds.grow(-3)
	c.draw_rect(area, Color("a99e86"))
	for row in [0.5, 0.66, 0.79, 0.93]:
		var y: float = area.position.y + area.size.y * row
		c.draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), Color("8e8975"), 0.65)
	var forms := _layout(kind, civilization)
	for form in forms:
		var center: Vector2 = area.position + area.size * Vector2(form[0], form[1])
		var extent: Vector2 = area.size * Vector2(form[2], form[3])
		var roof := Rect2(center - extent * 0.5, extent).grow(1.6 if civilization == "Chinese" else 0.8)
		if form[5] == "double_temple":
			c.draw_rect(roof.grow(1.7), palette["roof_dark"])
			c.draw_rect(roof.grow(1.7), palette["trim"].darkened(0.3), false, 0.6)
		c.draw_rect(Rect2(roof.position + Vector2(2, 3), roof.size), Color("3d4538", 0.3))
		var a := roof.position
		var b := Vector2(roof.end.x, roof.position.y)
		var d := Vector2(roof.position.x, roof.end.y)
		var f := roof.end
		var along_x := extent.x >= extent.y
		var left := (a + d) * 0.5 if along_x else (a + b) * 0.5
		var right := (b + f) * 0.5 if along_x else (d + f) * 0.5
		if form[5] == "spire":
			for face in [[a,b], [b,f], [f,d], [d,a]]:
				c.draw_colored_polygon(PackedVector2Array([face[0],face[1],center]), palette["roof"] if face[0] in [a,d] else palette["roof_dark"])
		else:
			var inset := 0.18 if form[5] in ["hip", "temple", "double_temple"] else 0.0
			var ridge_a := left.lerp(right, inset)
			var ridge_b := right.lerp(left, inset)
			if along_x:
				c.draw_colored_polygon(PackedVector2Array([a,b,ridge_b,ridge_a]), palette["roof"].lightened(0.12))
				c.draw_colored_polygon(PackedVector2Array([d,f,ridge_b,ridge_a]), palette["roof_dark"])
			else:
				c.draw_colored_polygon(PackedVector2Array([a,d,ridge_b,ridge_a]), palette["roof"].lightened(0.12))
				c.draw_colored_polygon(PackedVector2Array([b,f,ridge_b,ridge_a]), palette["roof_dark"])
			if inset > 0:
				for face in ([[a,d,ridge_a], [b,f,ridge_b]] if along_x else [[a,b,ridge_a], [d,f,ridge_b]]):
					c.draw_colored_polygon(PackedVector2Array(face), palette["roof"])
			c.draw_line(ridge_a, ridge_b, palette["trim"].darkened(0.2), 1.0)
		c.draw_rect(roof, palette["roof_dark"], false, 0.8)
		if civilization == "Chinese":
			for corner in [a,b,d,f]: c.draw_line(corner, corner + (corner - center).normalized() * 1.4, palette["trim"].darkened(0.1), 1.0)
	var court := area.position + area.size * Vector2(0.5, 0.61)
	if kind == "university" or civilization == "Chinese":
		c.draw_rect(Rect2(court - Vector2(3.5,2.5),Vector2(7,5)), Color("81745a"))
	elif civilization == "French":
		c.draw_rect(Rect2(court - Vector2(6,4.5),Vector2(12,9)), Color("6d7954"))
	var entry := area.position + area.size * Vector2(0.43 if kind == "monastery" and civilization == "English" else 0.5, 0.81 if kind == "monastery" and civilization == "English" else 0.93)
	c.draw_line(entry - Vector2(area.size.x * 0.09,0), entry + Vector2(area.size.x * 0.09,0), palette["trim"], 1.8)
	c.draw_rect(Rect2(entry + Vector2(2,-8),Vector2(4,5)),player)

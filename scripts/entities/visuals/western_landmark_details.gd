extends RefCounted

# Shared masonry, roofs and facade details for western landmarks.
const FilledPolygon = preload("res://scripts/entities/visuals/filled_polygon.gd")

static func _p(g, u: float, v: float, z: float) -> Vector3:
	var xy: Vector2 = (Vector2(u, v) - Vector2.ONE * 0.5) * g.dimensions
	return Vector3(xy.x, xy.y, g.base_z + z)

static func _hall(g, form: Array, player: Color) -> void:
	var u: float = form[0]
	var v: float = form[1]
	var w: float = form[2]
	var d: float = form[3]
	var h: float = form[4]
	var style: String = form[5]
	var center: Vector2 = Vector2(u - 0.5, v - 0.5) * g.dimensions
	var extent: Vector2 = Vector2(w, d) * g.dimensions
	var stone: Color = g.palette["wall"]
	if style == "awning":
		g.box(center, extent, 0.5, 9, Color("776349"))
		_roof(g, u, v, w + 0.03, d + 0.03, 10, "hip", player.lightened(0.10), 3.0)
		for across in [-0.3, 0.0, 0.3]:
			var a := _p(g, u + w * across, v - d * 0.5, 10)
			var b := _p(g, u + w * across, v + d * 0.5, 10)
			_ribbon(g, a, b, 1.8, Color("ded0ad"))
		return
	g.box(center, extent, g.base_z, h, stone)
	g.box(center, extent + Vector2.ONE * 0.9, g.base_z, 2.8, stone.darkened(0.19))
	g.box(center, extent + Vector2.ONE * 1.0, g.base_z + h - 2, 1.7, g.palette["trim"].darkened(0.08))
	# Restrained stone courses and corner quoins provide scale without outlines.
	for level in [h * 0.32, h * 0.66]:
		var a := _p(g, u - w * 0.5, v + d * 0.5 + 0.001, level)
		var b := _p(g, u + w * 0.5, v + d * 0.5 + 0.001, level)
		_ribbon(g, a, b, 0.40, stone.darkened(0.15))
	for corner in [-1.0, 1.0]:
		for level in 4:
			var at := _p(g, u + corner * (w * 0.5 - 0.015), v + d * 0.5 + 0.002, h * (0.10 + level * 0.21))
			_ribbon(g, at, at + Vector3(0, 0, h * 0.13), 1.8, stone.lightened(0.12))
	for level in ([0.31] if style == "clock_spire" else [0.31, 0.66] if h > 35.0 else [0.51]):
		for across in ([0.22, 0.50, 0.78] if w > 0.3 else [0.50]):
			_arch(g, u + (across - 0.5) * w, v + d * 0.5 + 0.003, h * level, minf(3.0, w * g.dimensions.x * 0.20), h * 0.18, false)
		_arch(g, u + w * 0.5 + 0.003, v, h * 0.59, 2.0, h * 0.19, true)
	if style == "flat" or style == "chimney":
		g.box(center, extent - Vector2.ONE * 1.0, g.base_z + h, 0.4, Color("77756a"))
		g.battlements(center, extent, g.base_z + h, g.palette["trim"])
	elif style == "dome":
		g.block(u, v, w * 0.92, d * 0.92, h, "dome")
	else:
		_roof(g, u, v, w + 0.035, d + 0.035, h, style, g.palette["roof"], 18.0 if style in ["spire", "clock_spire"] else 10.0)
	if w > 0.3 and style != "chimney":
		_arch(g, u, v + d * 0.5 + 0.006, 0, 4.0, minf(14.0, h * 0.55), false)

static func _roof(g, u: float, v: float, w: float, d: float, z: float, style: String, color: Color, rise: float) -> void:
	var a := _p(g, u - w * 0.5, v - d * 0.5, z)
	var b := _p(g, u + w * 0.5, v - d * 0.5, z)
	var c := _p(g, u + w * 0.5, v + d * 0.5, z)
	var e := _p(g, u - w * 0.5, v + d * 0.5, z)
	g.box(Vector2(u - 0.5, v - 0.5) * g.dimensions, Vector2(w, d) * g.dimensions, g.base_z + z - 0.8, 0.8, g.palette["roof_dark"])
	if style in ["spire", "clock_spire"]:
		g.pyramid(a, b, c, e, rise, color)
		return
	var along_x := w >= d
	var first := (a + e) * 0.5 if along_x else (a + b) * 0.5
	var last := (b + c) * 0.5 if along_x else (e + c) * 0.5
	var inset := 0.18 if style == "hip" else 0.0
	var left := first.lerp(last, inset) + Vector3(0, 0, rise)
	var right := last.lerp(first, inset) + Vector3(0, 0, rise)
	if along_x:
		g.face([a, b, right, left], color.lightened(0.14))
		g.face([left, right, c, e], color.darkened(0.07))
		g.face([a, left, e], color if style == "hip" else g.palette["wall"].darkened(0.15))
		g.face([b, c, right], color.darkened(0.19) if style == "hip" else g.palette["wall"].darkened(0.22))
	else:
		g.face([a, left, right, e], color.lightened(0.15))
		g.face([left, b, c, right], color.darkened(0.12))
		g.face([a, b, left], color if style == "hip" else g.palette["wall"].darkened(0.20))
		g.face([e, right, c], color.darkened(0.09) if style == "hip" else g.palette["wall"])
	# Tile seams follow the roof plane; narrow ribbons also participate in BSP.
	for t in [0.25, 0.50, 0.75]:
		var near: Vector3 = e.lerp(c, t) if along_x else a.lerp(e, t)
		var peak: Vector3 = left.lerp(right, t)
		var shift := Vector3(0, 0, 0.025)
		var across := Vector3(0.35, 0, 0) if along_x else Vector3(0, 0.35, 0)
		g.face([near - across + shift, peak - across + shift, peak + across + shift, near + across + shift], color.lightened(0.13))
	g.box(Vector2((left.x + right.x) * 0.5, (left.y + right.y) * 0.5), Vector2(absf(right.x - left.x) + 1.2, absf(right.y - left.y) + 1.2), left.z, 0.8, g.palette["trim"].darkened(0.15))

static func _ribbon(g, a: Vector3, b: Vector3, width: float, color: Color) -> void:
	var across := Vector3(-(b.z - a.z), 0, b.x - a.x).normalized() * width * 0.5
	if across.is_zero_approx(): across = Vector3(width * 0.5, 0, 0)
	g.face([a - across, b - across, b + across, a + across], color)

static func _arch(g, u: float, v: float, z: float, half_width: float, height: float, side: bool) -> void:
	half_width = minf(half_width, height * 0.45)
	var hub := _p(g, u, v, z)
	var across := Vector3(0, 1, 0) if side else Vector3(1, 0, 0)
	var outward := Vector3(0.022, 0, 0) if side else Vector3(0, 0.022, 0)
	for inset in [0.0, 0.9]:
		var width := maxf(0.6, half_width - inset)
		var h: float = height - inset * 1.4
		var bottom: Vector3 = hub + outward * (1.0 + inset) + Vector3(0, 0, inset)
		var points: Array = [bottom - across * width, bottom + across * width]
		for i in 7:
			var angle := i * PI / 6.0
			points.append(bottom + across * (cos(angle) * width) + Vector3(0, 0, h - width + sin(angle) * width))
		g.face(points, g.palette["trim"].darkened(0.07) if inset == 0 else Color("39494b"))
	if height > 8.0:
		_ribbon(g, hub + outward * 4 + Vector3(0, 0, 1), hub + outward * 4 + Vector3(0, 0, height - half_width), 0.65, g.palette["trim"].darkened(0.20))

static func _buttress(g, u: float, v: float, height: float) -> void:
	var xy := _p(g, u, v, 0)
	g.box(Vector2(xy.x, xy.y), Vector2(3, 5), g.base_z, height, g.palette["wall"].darkened(0.13))
	g.box(Vector2(xy.x, xy.y), Vector2(4, 6), g.base_z + height, 1, g.palette["trim"])

static func _column(g, u: float, v: float, height: float) -> void:
	var xy := _p(g, u, v, 0)
	g.box(Vector2(xy.x, xy.y), Vector2(2.3, 2.3), g.base_z, height, g.palette["trim"])
	g.box(Vector2(xy.x, xy.y), Vector2(3.3, 3.3), g.base_z + height - 2, 1.5, g.palette["trim"])

static func _steps(g, u: float, v: float, width: float) -> void:
	for i in 3:
		var at := _p(g, u, v + i * 0.018, 0)
		g.box(Vector2(at.x, at.y), Vector2(width * g.dimensions.x, 3.2), g.base_z, 3.0 - i * 0.8, g.palette["trim"].darkened(i * 0.07))

static func _banner(g, u: float, v: float, z: float, color: Color) -> void:
	var a := _p(g, u, v, z)
	g.face([a, a + Vector3(3.8, 0, 0), a + Vector3(3.8, 0, -8), a + Vector3(0, 0, -6.5)], color)

static func _cross(g, u: float, v: float, z: float) -> void:
	var center := _p(g, u, v, z)
	g.box(Vector2(center.x, center.y), Vector2(1.3, 1.3), center.z, 6, g.palette["trim"])
	g.box(Vector2(center.x, center.y), Vector2(4.0, 1.3), center.z + 3, 1.3, g.palette["trim"])

static func _curtains(g, player: Color) -> void:
	var stone: Color = g.palette["wall"]
	for u in [0.14, 0.86]:
		var center: Vector2 = Vector2(u - 0.5, 0) * g.dimensions
		var extent: Vector2 = Vector2(0.055, 0.70) * g.dimensions
		g.box(center, extent, g.base_z, 18, stone)
		g.battlements(center, extent + Vector2.ONE, g.base_z + 18, g.palette["trim"])
	for u in [0.30, 0.70]:
		var center: Vector2 = Vector2(u - 0.5, 0.30) * g.dimensions
		var extent: Vector2 = Vector2(0.22, 0.07) * g.dimensions
		g.box(center, extent, g.base_z, 19, stone)
		g.battlements(center, extent, g.base_z + 19, g.palette["trim"])
	_arch(g, 0.50, 0.837, 0, 5.0, 14, false)
	var lintel := _p(g, 0.50, 0.80, 14)
	g.box(Vector2(lintel.x, lintel.y), Vector2(0.18, 0.07) * g.dimensions, g.base_z + 14, 6, stone)
	_banner(g, 0.61, 0.839, 16, player)

static func _cargo(g, u: float, v: float) -> void:
	var center := _p(g, u, v, 0)
	g.box(Vector2(center.x, center.y), Vector2(6, 5), g.base_z, 4, Color("8b6c49"))
	g.box(Vector2(center.x + 5, center.y + 2), Vector2(4, 4), g.base_z, 3, Color("a68a5b"))

static func draw_layout_topdown(c: CanvasItem, bounds: Rect2, forms: Array, id: String, palette: Dictionary, player: Color) -> void:
	var roof := Color("57636b") if id.begins_with("eng_") else Color("556e80")
	if id == "fr_red_palace": roof = Color("8f5145")
	c.draw_rect(bounds.grow(-2), Color("a69d85"))
	for row in [0.68, 0.80, 0.90]:
		var y: float = bounds.position.y + bounds.size.y * row
		c.draw_line(Vector2(bounds.position.x + 4, y), Vector2(bounds.end.x - 4, y), Color("938b76"), 0.65)
	for form in forms:
		var extent := bounds.size * Vector2(form[2], form[3])
		var center := bounds.position + bounds.size * Vector2(form[0], form[1])
		var box := Rect2(center - extent * 0.5, extent)
		var style: String = form[5]
		c.draw_rect(Rect2(box.position + Vector2(2, 3), box.size + Vector2.ONE * 2), Color("3a3c34", 0.25))
		c.draw_rect(box.grow(1.5), palette["wall"].darkened(0.13))
		if style in ["flat", "chimney"]:
			c.draw_rect(box, palette["trim"])
			c.draw_rect(box.grow(-2.3), Color("77776a"))
			for t in [0.10, 0.35, 0.60, 0.85]:
				for y in [box.position.y, box.end.y - 2]: c.draw_rect(Rect2(box.position.x + box.size.x * t - 1, y, 2, 2), palette["trim"].lightened(0.15))
		elif style == "dome":
			c.draw_rect(box, roof)
			c.draw_circle(center + Vector2(1, 1), minf(extent.x, extent.y) * 0.43, roof.darkened(0.25))
			c.draw_circle(center, minf(extent.x, extent.y) * 0.40, roof.lightened(0.21))
		else:
			var color := player.lightened(0.1) if style == "awning" else roof
			var corners := [box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)]
			var along_x := extent.x >= extent.y
			var inset := 0.0 if style == "gable" else 0.18
			var first := Vector2(box.position.x + extent.x * inset, center.y) if along_x else Vector2(center.x, box.position.y + extent.y * inset)
			var last := Vector2(box.end.x - extent.x * inset, center.y) if along_x else Vector2(center.x, box.end.y - extent.y * inset)
			if style in ["spire", "clock_spire"]:
				for i in 4:
					FilledPolygon.draw(c, PackedVector2Array([corners[i], corners[(i + 1) % 4], center]), color.lightened(0.12) if i in [0, 3] else color.darkened(0.15))
			else:
				var light_face := [corners[0], corners[1], last, first] if along_x else [corners[0], first, last, corners[3]]
				var dark_face := [first, last, corners[2], corners[3]] if along_x else [first, corners[1], corners[2], last]
				FilledPolygon.draw(c, PackedVector2Array(light_face), color.lightened(0.13))
				FilledPolygon.draw(c, PackedVector2Array(dark_face), color.darkened(0.09))
				if inset > 0.0:
					FilledPolygon.draw(c, PackedVector2Array([corners[0], first, corners[3]] if along_x else [corners[0], corners[1], first]), color.lightened(0.03))
					FilledPolygon.draw(c, PackedVector2Array([corners[1], corners[2], last] if along_x else [corners[3], last, corners[2]]), color.darkened(0.19))
				c.draw_line(first, last, palette["trim"].darkened(0.2), 0.9)
				for t in [0.3, 0.6]:
					var a: Vector2 = corners[3].lerp(corners[2], t) if along_x else corners[0].lerp(corners[3], t)
					c.draw_line(a, first.lerp(last, t), color.lightened(0.23), 0.55)
			c.draw_line(corners[3], corners[2], color.darkened(0.37), 1.1)

class_name RtsKeepMonasteryVisual
extends RefCounted

const Geometry = preload("res://scripts/entities/visuals/building_geometry.gd")

# Finished regular buildings; the owning node provides the low foundation.
static func draw_topdown(c: CanvasItem, kind: String, bounds: Rect2, palette: Dictionary, accent: Color, civ: String) -> void:
	match kind:
		"keep": _keep_2d(c, bounds, palette, accent)
		"outpost": _outpost_2d(c, bounds, palette, accent)
		"monastery": _monastery_2d(c, bounds, palette, accent, civ)


static func draw_iso(c: CanvasItem, kind: String, nw: Vector2, ne: Vector2, se: Vector2, sw: Vector2, lift: Vector2, palette: Dictionary, accent: Color, civ: String, canvas: Transform2D, zoom: float) -> void:
	match kind:
		"keep": _keep_iso(c, nw, ne, sw, lift, palette, accent, canvas, zoom)
		"outpost": _outpost_iso(c, nw, ne, sw, lift, palette, accent, canvas, zoom)
		"monastery": _monastery_iso(c, nw, ne, sw, lift, palette, accent, civ, canvas, zoom)


# A visual-only hull, relative to the foundation plane. Gameplay footprint is unchanged.
static func selection_hull(snapshot, canvas: Transform2D) -> PackedVector2Array:
	var bounds := Rect2(-snapshot.dimensions * 0.5, snapshot.dimensions)
	var nw := bounds.position
	var ne := Vector2(bounds.end.x, bounds.position.y)
	var sw := Vector2(bounds.position.x, bounds.end.y)
	var floor := Geometry.up(canvas, snapshot.zoom, snapshot.isometric_height() * 0.18)
	var points := PackedVector2Array([nw, ne, bounds.end, sw])
	if snapshot.kind == "keep":
		for uv in [Vector2(0.3, 0.23), Vector2(0.7, 0.23), Vector2(0.7, 0.58), Vector2(0.3, 0.58)]:
			points.append(Geometry.point(nw, ne, sw, uv.x, uv.y) + floor + Geometry.up(canvas, snapshot.zoom, 52.0))
		for u in [0.13, 0.87]:
			for v in [0.13, 0.87]:
				for offset in [Vector2(-0.105, -0.105), Vector2(0.105, -0.105), Vector2(0.105, 0.105), Vector2(-0.105, 0.105)]:
					points.append(Geometry.point(nw, ne, sw, u + offset.x, v + offset.y) + floor + Geometry.up(canvas, snapshot.zoom, 33.1))
	elif snapshot.kind == "outpost":
		for uv in [Vector2(0.0882, 0.1015), Vector2(0.9118, 0.1015), Vector2(0.9118, 0.8985), Vector2(0.0882, 0.8985)]:
			points.append(Geometry.point(nw, ne, sw, uv.x, uv.y) + floor + Geometry.up(canvas, snapshot.zoom, 36.0))
		points.append(Geometry.point(nw, ne, sw, 0.5, 0.5) + floor + Geometry.up(canvas, snapshot.zoom, 42.0))
	return Geometry2D.convex_hull(points)


static func _block(c: CanvasItem, nw: Vector2, ne: Vector2, sw: Vector2, floor: Vector2, up: Vector2, u: float, v: float, width: float, depth: float, wall: Color, trim: Color) -> Array[Vector2]:
	var a := Geometry.point(nw, ne, sw, u, v) + floor
	var b := Geometry.point(nw, ne, sw, u + width, v) + floor
	var f := Geometry.point(nw, ne, sw, u + width, v + depth) + floor
	var d := Geometry.point(nw, ne, sw, u, v + depth) + floor
	c.draw_colored_polygon(PackedVector2Array([b + up, f + up, f, b]), wall.darkened(0.18))
	c.draw_colored_polygon(PackedVector2Array([d + up, f + up, f, d]), wall)
	c.draw_line(d + up, f + up, trim, 1.4)
	return [a + up, b + up, f + up, d + up]


static func _gable(c: CanvasItem, corners: Array[Vector2], rise: Vector2, palette: Dictionary, civ: String) -> void:
	var a: Vector2 = corners[0]
	var b: Vector2 = corners[1]
	var f: Vector2 = corners[2]
	var d: Vector2 = corners[3]
	var rear_peak := (a + b) * 0.5 + rise
	var front_peak := (d + f) * 0.5 + rise
	var roof: Color = palette["roof"]
	var dark: Color = palette["roof_dark"]
	var trim: Color = palette["trim"]
	c.draw_colored_polygon(PackedVector2Array([a, rear_peak, front_peak, d]), roof.lightened(0.1))
	c.draw_colored_polygon(PackedVector2Array([rear_peak, b, f, front_peak]), roof)
	c.draw_colored_polygon(PackedVector2Array([d, front_peak, f]), palette["wall"])
	c.draw_line(rear_peak, front_peak, trim, 1.5)
	c.draw_polyline(PackedVector2Array([d, front_peak, f]), dark, 1.5)
	for fraction in [0.28, 0.56, 0.84]:
		c.draw_line(a.lerp(d, fraction), rear_peak.lerp(front_peak, fraction), Color(dark, 0.38), 0.9)
		c.draw_line(rear_peak.lerp(front_peak, fraction), b.lerp(f, fraction), Color(dark, 0.3), 0.9)
	if civ == "Chinese":
		for corner in [a, b, f, d]: c.draw_line(corner, corner + rise * 0.28, trim, 1.5)


# Fortifications use actual wall thickness, inset tops and a battered foot.
# Masonry stays low contrast so openings and the silhouette read at game zoom.
static func _stone_face(c: CanvasItem, a: Vector2, b: Vector2, up: Vector2, color: Color, trim: Color, rows: int = 5) -> void:
	c.draw_colored_polygon(PackedVector2Array([a, b, b + up, a + up]), color)
	c.draw_line(a + up * 0.1, b + up * 0.1, color.lightened(0.12), 2.0)
	for row in range(1, rows):
		var fraction := float(row) / float(rows)
		var line_up := up * fraction
		c.draw_line(a + line_up, b + line_up, Color(color.darkened(0.2), 0.42), 0.6)
		for joint in range(1, 5):
			var x := (float(joint) - (0.5 if row % 2 else 0.0)) / 5.0
			c.draw_line(a.lerp(b, x) + line_up, a.lerp(b, x) + up * (fraction + 1.0 / float(rows)), Color(color.darkened(0.22), 0.35), 0.6)
	# Alternating end quoins frame the corners without heavy black outlines.
	for row in rows:
		var low := up * (float(row) / float(rows))
		var high := up * (float(row + 1) / float(rows))
		var extent := 0.075 if row % 2 else 0.12
		for edge in [0, 1]:
			var x := a if edge == 0 else b
			var y := a.lerp(b, extent if edge == 0 else 1.0 - extent)
			c.draw_colored_polygon(PackedVector2Array([x + low, y + low, y + high, x + high]), Color(trim.darkened(0.08), 0.5))


static func _slit(c: CanvasItem, bottom: Vector2, up: Vector2, trim: Color) -> void:
	c.draw_line(bottom - up * 0.04, bottom + up, trim.darkened(0.18), 3.4)
	c.draw_line(bottom, bottom + up * 0.88, Color("313a38"), 1.6)


static func _crenels(c: CanvasItem, a: Vector2, b: Vector2, up: Vector2, trim: Color, count: int, inset: Vector2 = Vector2.ZERO) -> void:
	c.draw_line(a, b, trim.darkened(0.25), 2.8)
	for index in count:
		var left := a.lerp(b, (float(index) + 0.12) / float(count))
		var right := a.lerp(b, (float(index) + 0.7) / float(count))
		c.draw_colored_polygon(PackedVector2Array([left, right, right + up, left + up]), trim.darkened(0.08))
		if inset != Vector2.ZERO:
			c.draw_colored_polygon(PackedVector2Array([left + up, right + up, right + up + inset, left + up + inset]), trim.lightened(0.1))
		c.draw_line(left + up, right + up, trim.lightened(0.15), 0.8)


static func _curtain(c: CanvasItem, a: Vector2, b: Vector2, up: Vector2, thickness: Vector2, wall: Color, trim: Color, teeth: int = 6) -> void:
	_stone_face(c, a, b, up, wall, trim, 3)
	c.draw_colored_polygon(PackedVector2Array([a + up, b + up, b + up + thickness, a + up + thickness]), trim.darkened(0.12))
	_crenels(c, a + up, b + up, up * 0.2, trim, teeth, thickness * 0.45)
	for fraction in [0.27, 0.72]:
		_slit(c, a.lerp(b, fraction) + up * 0.39, up * 0.22, trim)


static func _arch(c: CanvasItem, bottom: Vector2, half: Vector2, rise: Vector2, stone: Color, timber: Color) -> void:
	var outline := PackedVector2Array([bottom - half, bottom - half + rise * 0.64, bottom - half * 0.72 + rise * 0.87, bottom + rise, bottom + half * 0.72 + rise * 0.87, bottom + half + rise * 0.64, bottom + half])
	c.draw_polyline(outline, stone.lightened(0.09), 5.0)
	c.draw_colored_polygon(outline, Color("303632"))
	for offset in [-0.6, -0.2, 0.2, 0.6]:
		var bar: Vector2 = bottom + half * offset
		c.draw_line(bar, bar + rise * (0.77 if absf(offset) > 0.5 else 0.88), timber.darkened(0.35), 1.1)
	c.draw_line(bottom - half + rise * 0.35, bottom + half + rise * 0.35, timber, 1.4)
	for fraction in [0.23, 0.52, 0.78]:
		var index := clampi(int(fraction * 6.0), 1, 5)
		var p := outline[index]
		c.draw_line(p, p + (p - bottom).normalized() * 2.0, stone.darkened(0.3), 0.8)


static func _keep_iso(c: CanvasItem, nw: Vector2, ne: Vector2, sw: Vector2, lift: Vector2, palette: Dictionary, accent: Color, canvas: Transform2D, zoom: float) -> void:
	var wall: Color = palette["wall"]
	var trim: Color = palette["trim"]
	var ground := lift * 0.18
	var court := PackedVector2Array()
	for uv in [Vector2(0.08, 0.08), Vector2(0.92, 0.08), Vector2(0.92, 0.92), Vector2(0.08, 0.92)]: court.append(Geometry.point(nw, ne, sw, uv.x, uv.y) + ground)
	c.draw_colored_polygon(court, Color("9a937a"))
	for fraction in [0.22, 0.38, 0.54, 0.7, 0.86]:
		c.draw_line(Geometry.point(nw, ne, sw, 0.1, fraction) + ground, Geometry.point(nw, ne, sw, 0.9, fraction) + ground, Color("6e725e", 0.4), 0.65)
	var up := Geometry.up(canvas, zoom, 20.0)
	_curtain(c, Geometry.point(nw, ne, sw, 0.12, 0.13) + ground, Geometry.point(nw, ne, sw, 0.88, 0.13) + ground, up, (sw - nw) * 0.055, wall.darkened(0.2), trim)
	_curtain(c, Geometry.point(nw, ne, sw, 0.88, 0.13) + ground, Geometry.point(nw, ne, sw, 0.88, 0.88) + ground, up, (nw - ne) * 0.055, wall.darkened(0.18), trim)
	_turret(c, nw, ne, sw, ground, 0.13, 0.13, palette, canvas, zoom)
	_turret(c, nw, ne, sw, ground, 0.87, 0.13, palette, canvas, zoom)
	# A tall rear donjon leaves the paved forecourt and central entry visible.
	var donjon_up := Geometry.up(canvas, zoom, 47.0)
	var a := Geometry.point(nw, ne, sw, 0.3, 0.23) + ground
	var b := Geometry.point(nw, ne, sw, 0.7, 0.23) + ground
	var f := Geometry.point(nw, ne, sw, 0.7, 0.58) + ground
	var d := Geometry.point(nw, ne, sw, 0.3, 0.58) + ground
	_stone_face(c, b, f, donjon_up, wall.darkened(0.22), trim, 7)
	_stone_face(c, d, f, donjon_up, wall, trim, 7)
	for fraction in [0.33, 0.68]:
		_slit(c, d.lerp(f, fraction) + donjon_up * 0.67, donjon_up * 0.16, trim)
		_slit(c, b.lerp(f, fraction) + donjon_up * 0.69, donjon_up * 0.13, trim)
	# Projecting machicolation ledge and dark brackets under the parapet.
	for edge in [[d, f], [b, f]]:
		var first: Vector2 = edge[0]
		var last: Vector2 = edge[1]
		c.draw_line(first + donjon_up * 0.9, last + donjon_up * 0.9, trim, 3.0)
		for fraction in [0.12, 0.36, 0.6, 0.84]:
			c.draw_line(first.lerp(last, fraction) + donjon_up * 0.82, first.lerp(last, fraction) + donjon_up * 0.91, trim.darkened(0.33), 2.4)
	c.draw_colored_polygon(PackedVector2Array([a + donjon_up, b + donjon_up, f + donjon_up, d + donjon_up]), palette["roof_dark"].darkened(0.12))
	var merlon := Geometry.up(canvas, zoom, 5.0)
	for edge in [[a, b], [b, f], [d, f], [a, d]]:
		_crenels(c, edge[0] + donjon_up, edge[1] + donjon_up, merlon, trim, 4)
	_arch(c, d.lerp(f, 0.5), (f - d) * 0.14, donjon_up * 0.32, trim, palette["timber"])
	var banner := d.lerp(f, 0.82) + donjon_up * 0.62
	c.draw_colored_polygon(PackedVector2Array([banner, banner + (f - d) * 0.12, banner + (f - d) * 0.12 - donjon_up * 0.24, banner + (f - d) * 0.06 - donjon_up * 0.3, banner - donjon_up * 0.24]), accent)
	# Near curtains are low enough to expose the main tower and court.
	_curtain(c, Geometry.point(nw, ne, sw, 0.13, 0.13) + ground, Geometry.point(nw, ne, sw, 0.13, 0.88) + ground, up, (ne - nw) * 0.055, wall.darkened(0.06), trim)
	_curtain(c, Geometry.point(nw, ne, sw, 0.13, 0.88) + ground, Geometry.point(nw, ne, sw, 0.87, 0.88) + ground, up, (nw - sw) * 0.055, wall, trim)
	var entrance := Geometry.point(nw, ne, sw, 0.5, 0.883) + ground
	_arch(c, entrance, (ne - nw) * 0.076, up * 0.87, trim, palette["timber"])
	for fraction in [0.0, 0.035, 0.07]:
		c.draw_line(Geometry.point(nw, ne, sw, 0.42, 0.9 + fraction) + ground * (1.0 - fraction * 8.0), Geometry.point(nw, ne, sw, 0.58, 0.9 + fraction) + ground * (1.0 - fraction * 8.0), trim.darkened(0.2), 1.8)
	_turret(c, nw, ne, sw, ground, 0.13, 0.87, palette, canvas, zoom)
	_turret(c, nw, ne, sw, ground, 0.87, 0.87, palette, canvas, zoom)


static func _turret(c: CanvasItem, nw: Vector2, ne: Vector2, sw: Vector2, floor: Vector2, u: float, v: float, palette: Dictionary, canvas: Transform2D, zoom: float) -> void:
	var center := Geometry.point(nw, ne, sw, u, v) + floor
	var corners: Array[Vector2] = []
	for offset in [Vector2(-0.65, -1), Vector2(0.65, -1), Vector2(1, -0.55), Vector2(1, 0.55), Vector2(0.65, 1), Vector2(-0.65, 1), Vector2(-1, 0.55), Vector2(-1, -0.55)]:
		corners.append(Geometry.point(nw, ne, sw, u + offset.x * 0.105, v + offset.y * 0.105) + floor)
	var up := Geometry.up(canvas, zoom, 29.0)
	var wall: Color = palette["wall"]
	var trim: Color = palette["trim"]
	for index in [2, 3, 4, 5, 6]:
		var next: int = (index + 1) % 8
		var a := corners[index]
		var b := corners[next]
		var foot_a := center + (a - center) * 1.12
		var foot_b := center + (b - center) * 1.12
		c.draw_colored_polygon(PackedVector2Array([foot_a, foot_b, b + up * 0.13, a + up * 0.13]), trim.darkened(0.18))
		_stone_face(c, a + up * 0.13, b + up * 0.13, up * 0.87, wall.darkened(0.07 + (0.2 if index < 4 else 0.0)), trim, 4)
	var top := PackedVector2Array()
	for corner in corners: top.append(corner + up)
	c.draw_colored_polygon(top, wall.darkened(0.38))
	# Inset dark well and broad stone merlons give the turrets a defensive top.
	for index in 8:
		var next: int = (index + 1) % 8
		_crenels(c, top[index], top[next], up * 0.14, trim, 1, (center + up - top[index]) * 0.22)
	for index in [3, 5]:
		_slit(c, corners[index].lerp(corners[index + 1], 0.5) + up * 0.45, up * 0.2, trim)


static func _keep_2d(c: CanvasItem, bounds: Rect2, palette: Dictionary, accent: Color) -> void:
	var area := bounds.grow(-5.0)
	var wall: Color = palette["wall"]
	var trim: Color = palette["trim"]
	c.draw_rect(area, wall.darkened(0.08))
	var court := area.grow(-area.size.x * 0.1)
	c.draw_rect(court, Color("9a937a"))
	for fraction in [0.25, 0.4, 0.55, 0.7, 0.85]:
		c.draw_line(Geometry.point_rect(court, 0, fraction), Geometry.point_rect(court, 1, fraction), Color("666b58", 0.38), 0.7)
	c.draw_rect(area, trim, false, 1.4)
	c.draw_rect(court, wall.darkened(0.28), false, 1.8)
	for side in [0, 1]:
		for fraction in [0.23, 0.37, 0.63, 0.77]:
			for vertical in [true, false]:
				var p := Geometry.point_rect(area, float(side) if vertical else fraction, fraction if vertical else float(side))
				c.draw_rect(Rect2(p - Vector2.ONE * 2.2, Vector2.ONE * 4.4), trim)
	var donjon := Geometry.rect(area, 0.3, 0.23, 0.4, 0.35)
	c.draw_rect(Rect2(donjon.position + Vector2(3, 4), donjon.size), Color("343d34", 0.42))
	c.draw_rect(donjon, trim)
	c.draw_rect(donjon.grow(-3.8), palette["roof_dark"])
	for fraction in [0.1, 0.35, 0.6, 0.85]:
		for side in [0, 1]:
			for vertical in [true, false]:
				var p := Geometry.point_rect(donjon, float(side) if vertical else fraction, fraction if vertical else float(side))
				c.draw_rect(Rect2(p - Vector2.ONE * 1.7, Vector2.ONE * 3.4), trim.lightened(0.13))
	for u in [0.13, 0.87]:
		for v in [0.13, 0.87]:
			var center := Geometry.point_rect(area, u, v)
			var radius := minf(area.size.x, area.size.y) * 0.115
			var rim := PackedVector2Array()
			for i in 8: rim.append(center + Vector2(cos(TAU * i / 8.0), sin(TAU * i / 8.0)) * radius)
			c.draw_colored_polygon(rim, trim)
			c.draw_circle(center, radius * 0.6, wall.darkened(0.4))
			for i in 8:
				var p := center + Vector2(cos(TAU * i / 8.0), sin(TAU * i / 8.0)) * radius * 0.88
				c.draw_rect(Rect2(p - Vector2.ONE * 1.5, Vector2.ONE * 3), trim.lightened(0.12))
	var gate := Geometry.rect(area, 0.425, 0.88, 0.15, 0.15)
	c.draw_rect(gate, palette["timber"].darkened(0.38))
	c.draw_line(gate.position, Vector2(gate.end.x, gate.position.y), trim, 2.0)
	for fraction in [0.22, 0.5, 0.78]:
		c.draw_line(Geometry.point_rect(gate, fraction, 0), Geometry.point_rect(gate, fraction, 1), palette["timber"], 0.7)
	c.draw_rect(Geometry.rect(area, 0.61, 0.54, 0.065, 0.12), accent)


static func _outpost_iso(c: CanvasItem, nw: Vector2, ne: Vector2, sw: Vector2, lift: Vector2, palette: Dictionary, accent: Color, canvas: Transform2D, zoom: float) -> void:
	var floor := lift * 0.18
	var wall: Color = palette["wall"]
	var trim: Color = palette["trim"]
	var timber: Color = palette["timber"].darkened(0.25)
	var up := Geometry.up(canvas, zoom, 27.0)
	var a := Geometry.point(nw, ne, sw, 0.19, 0.2) + floor
	var b := Geometry.point(nw, ne, sw, 0.81, 0.2) + floor
	var f := Geometry.point(nw, ne, sw, 0.81, 0.8) + floor
	var d := Geometry.point(nw, ne, sw, 0.19, 0.8) + floor
	var center := (a + b + f + d) * 0.25
	# A flared plinth carries the compact stone shaft.
	for edge in [[b, f], [d, f]]:
		var first: Vector2 = edge[0]
		var last: Vector2 = edge[1]
		c.draw_colored_polygon(PackedVector2Array([center + (first - center) * 1.18, center + (last - center) * 1.18, last + up * 0.18, first + up * 0.18]), wall.darkened(0.15))
	_stone_face(c, b + up * 0.18, f + up * 0.18, up * 0.82, wall.darkened(0.24), trim, 4)
	_stone_face(c, d + up * 0.18, f + up * 0.18, up * 0.82, wall, trim, 4)
	_slit(c, b.lerp(f, 0.5) + up * 0.49, up * 0.23, trim)
	_arch(c, d.lerp(f, 0.5), (f - d) * 0.18, up * 0.42, trim, timber)
	# Open timber gallery sits on cantilever brackets, with a separate hip roof.
	var gallery: Array[Vector2] = []
	for corner in [a, b, f, d]: gallery.append(center + (corner - center) * 1.23 + up)
	c.draw_colored_polygon(PackedVector2Array(gallery), timber)
	for edge in [[gallery[1], gallery[2]], [gallery[3], gallery[2]]]:
		c.draw_line(edge[0], edge[1], timber.lightened(0.2), 3.0)
		for fraction in [0.16, 0.5, 0.84]:
			var bracket: Vector2 = edge[0].lerp(edge[1], fraction)
			c.draw_line(bracket - up * 0.15, bracket, timber, 2.0)
	var gallery_up := Geometry.up(canvas, zoom, 9.0)
	for corner in gallery: c.draw_line(corner, corner + gallery_up, timber, 2.5)
	for edge in [[gallery[1], gallery[2]], [gallery[3], gallery[2]]]:
		c.draw_line(edge[0] + gallery_up * 0.38, edge[1] + gallery_up * 0.38, timber.lightened(0.25), 1.5)
		for fraction in [0.25, 0.5, 0.75]:
			var rail: Vector2 = edge[0].lerp(edge[1], fraction)
			c.draw_line(rail, rail + gallery_up * 0.38, timber, 1.0)
	var roof := PackedVector2Array()
	for corner in gallery: roof.append(center + (corner - up - center) * 1.08 + up + gallery_up)
	var peak := center + up + gallery_up + Geometry.up(canvas, zoom, 6.0)
	for index in 4:
		c.draw_colored_polygon(PackedVector2Array([roof[index], roof[(index + 1) % 4], peak]), palette["roof"].lightened(0.1) if index in [0, 3] else palette["roof_dark"])
	c.draw_polyline(PackedVector2Array([roof[1], roof[2], roof[3]]), palette["roof_dark"].darkened(0.25), 1.5)
	var banner := gallery[2] + gallery_up * 0.88
	c.draw_colored_polygon(PackedVector2Array([banner, banner - (ne - nw) * 0.13, banner - (ne - nw) * 0.13 - gallery_up * 0.8, banner - gallery_up * 0.68]), accent)


static func _outpost_2d(c: CanvasItem, bounds: Rect2, palette: Dictionary, accent: Color) -> void:
	var area := bounds.grow(-4.0)
	c.draw_rect(area, palette["wall"].darkened(0.17))
	var roof := Geometry.rect(area, 0.05, 0.06, 0.9, 0.88)
	c.draw_rect(Rect2(roof.position + Vector2(2.5, 3.0), roof.size), Color("2e382c", 0.42))
	var center := roof.get_center()
	var a := roof.position
	var b := Vector2(roof.end.x, roof.position.y)
	var f := roof.end
	var d := Vector2(roof.position.x, roof.end.y)
	for face in [[a, b], [b, f], [f, d], [d, a]]:
		c.draw_colored_polygon(PackedVector2Array([face[0], face[1], center]), palette["roof"] if face[0] in [a, d] else palette["roof_dark"])
		c.draw_line(face[0], center, Color(palette["roof_dark"], 0.55), 0.8)
	c.draw_rect(roof, palette["timber"].darkened(0.3), false, 1.8)
	c.draw_line(Geometry.point_rect(area, 0.22, 0.94), Geometry.point_rect(area, 0.78, 0.94), palette["trim"], 1.5)
	c.draw_rect(Geometry.rect(area, 0.42, 0.85, 0.16, 0.13), palette["timber"].darkened(0.4))
	c.draw_rect(Geometry.rect(roof, 0.77, 0.67, 0.18, 0.24), accent)


static func _monastery_iso(c: CanvasItem, nw: Vector2, ne: Vector2, sw: Vector2, lift: Vector2, palette: Dictionary, accent: Color, civ: String, canvas: Transform2D, zoom: float) -> void:
	if civ == "Chinese":
		_temple_iso(c, nw, ne, sw, lift, palette, accent, canvas, zoom)
		return
	var floor := lift * 0.18
	var wall: Color = palette["wall"]
	var trim: Color = palette["trim"]
	var roof: Color = palette["roof"]
	var dark: Color = palette["roof_dark"]
	# The nave is the visible central mass; detached aisle roofs overlap its
	# projected gable at this camera angle and leave stray roof slivers.
	var nave_up := Geometry.up(canvas, zoom, 27.0)
	var nave := _block(c, nw, ne, sw, floor, nave_up, 0.31, 0.1, 0.43, 0.76, wall, trim)
	_gable(c, nave, Geometry.up(canvas, zoom, 15.0), palette, civ)
	for v in [0.34, 0.53, 0.71]:
		var window := Geometry.point(nw, ne, sw, 0.74, v) + floor + nave_up * 0.62
		c.draw_line(window, window + nave_up * 0.2, trim, 5.0)
		c.draw_line(window + nave_up * 0.02, window + nave_up * 0.17, Color("34454a"), 2.9)
	var front := Geometry.point(nw, ne, sw, 0.525, 0.86) + floor
	var door_up := Geometry.up(canvas, zoom, 16.0)
	var half := (ne - nw) * 0.065
	c.draw_colored_polygon(PackedVector2Array([front - half + door_up * 0.75, front + half + door_up * 0.75, front + half, front - half]), Color("3d3932"))
	c.draw_line(front - half + door_up * 0.75, front + half + door_up * 0.75, trim, 1.6)
	# Offset bell tower keeps the roof ridge and the entrance visible.
	var tower_up := Geometry.up(canvas, zoom, 43.0)
	var tower := _block(c, nw, ne, sw, floor, tower_up, 0.73, 0.12, 0.2, 0.23, wall, trim)
	# One window on each visible face, inset from the edges and below the eave.
	for face in [Vector2(0.83, 0.35), Vector2(0.93, 0.235)]:
		var opening := Geometry.point(nw, ne, sw, face.x, face.y) + floor + tower_up * 0.59
		c.draw_line(opening, opening + tower_up * 0.15, trim, 5.0)
		c.draw_line(opening + tower_up * 0.02, opening + tower_up * 0.13, Color("34454a"), 2.9)
	var peak := (tower[0] + tower[1] + tower[2] + tower[3]) * 0.25 + Geometry.up(canvas, zoom, 21.0)
	c.draw_colored_polygon(PackedVector2Array([tower[0], tower[3], peak]), roof.lightened(0.09))
	c.draw_colored_polygon(PackedVector2Array([tower[1], tower[2], peak]), roof)
	c.draw_colored_polygon(PackedVector2Array([tower[3], tower[2], peak]), dark)
	if civ == "Chinese":
		c.draw_line(tower[3], tower[2], trim, 2.1)
	else:
		c.draw_line(peak, peak + Geometry.up(canvas, zoom, 9.0), trim, 1.6)
		c.draw_line(peak + Geometry.up(canvas, zoom, 5.0) - (ne - nw) * 0.035, peak + Geometry.up(canvas, zoom, 5.0) + (ne - nw) * 0.035, trim, 1.6)
	c.draw_line(Geometry.point(nw, ne, sw, 0.31, 0.85) + floor, Geometry.point(nw, ne, sw, 0.74, 0.85) + floor, accent, 1.8)


static func _temple_iso(c: CanvasItem, nw: Vector2, ne: Vector2, sw: Vector2, lift: Vector2, palette: Dictionary, accent: Color, canvas: Transform2D, zoom: float) -> void:
	var floor := lift * 0.18
	var wall: Color = palette["wall"]
	var timber: Color = palette["timber"]
	var trim: Color = palette["trim"]
	var hall_up := Geometry.up(canvas, zoom, 24.0)
	var hall := _block(c, nw, ne, sw, floor, hall_up, 0.1, 0.18, 0.8, 0.58, wall, trim)
	_gable(c, hall, Geometry.up(canvas, zoom, 13.0), palette, "Chinese")
	for u in [0.2, 0.39, 0.61, 0.8]:
		var post := Geometry.point(nw, ne, sw, u, 0.76) + floor
		c.draw_line(post, post + hall_up * 0.82, timber, 2.8)
	var doorway := Geometry.point(nw, ne, sw, 0.5, 0.76) + floor
	c.draw_line(doorway, doorway + hall_up * 0.52, palette["roof_dark"], 7.0)
	# The rear pagoda rises over the hall's roof, with two projecting eaves.
	var tower_up := Geometry.up(canvas, zoom, 39.0)
	var tower := _block(c, nw, ne, sw, floor, tower_up, 0.39, 0.08, 0.22, 0.22, wall, trim)
	var cap := PackedVector2Array([tower[0], tower[1], tower[2], tower[3]])
	c.draw_colored_polygon(cap, palette["roof_dark"])
	c.draw_polyline(PackedVector2Array([tower[0], tower[1], tower[2], tower[3], tower[0]]), trim, 2.2)
	var tier := Geometry.up(canvas, zoom, 10.0)
	c.draw_colored_polygon(PackedVector2Array([tower[1] + tier, tower[2] + tier, tower[2], tower[1]]), wall.darkened(0.16))
	c.draw_colored_polygon(PackedVector2Array([tower[3] + tier, tower[2] + tier, tower[2], tower[3]]), wall)
	var tier_top: Array[Vector2] = [tower[0] + tier, tower[1] + tier, tower[2] + tier, tower[3] + tier]
	_gable(c, tier_top, Geometry.up(canvas, zoom, 8.0), palette, "Chinese")
	var incense := Geometry.point(nw, ne, sw, 0.5, 0.9) + floor
	c.draw_circle(incense, 3.5, Color("756246"))
	c.draw_line(incense, incense + Geometry.up(canvas, zoom, 7.0), trim, 1.3)
	c.draw_line(Geometry.point(nw, ne, sw, 0.21, 0.9) + floor, Geometry.point(nw, ne, sw, 0.79, 0.9) + floor, accent, 1.8)


static func _monastery_2d(c: CanvasItem, bounds: Rect2, palette: Dictionary, accent: Color, civ: String) -> void:
	var area := bounds.grow(-5.0)
	if civ == "Chinese":
		c.draw_rect(area, palette["wall"].darkened(0.16))
		var hall := Geometry.rect(area, 0.1, 0.18, 0.8, 0.59)
		c.draw_rect(hall, palette["roof"])
		c.draw_rect(hall, palette["roof_dark"], false, 1.7)
		c.draw_line(Vector2(hall.position.x, hall.get_center().y), Vector2(hall.end.x, hall.get_center().y), palette["trim"], 2.2)
		var tower := Geometry.rect(area, 0.39, 0.08, 0.22, 0.22)
		c.draw_rect(tower, palette["roof_dark"])
		c.draw_rect(tower, palette["trim"], false, 1.6)
		c.draw_circle(area.position + area.size * Vector2(0.5, 0.9), 3.5, palette["trim"])
		c.draw_line(Vector2(hall.position.x, hall.end.y + 2), Vector2(hall.end.x, hall.end.y + 2), accent, 2.2)
		return
	c.draw_rect(area, palette["wall"].darkened(0.16))
	for side in [Geometry.rect(area, 0.07, 0.29, 0.28, 0.5), Geometry.rect(area, 0.7, 0.29, 0.24, 0.5)]:
		c.draw_rect(side, palette["roof"])
		c.draw_line(Vector2(side.get_center().x, side.position.y), Vector2(side.get_center().x, side.end.y), palette["trim"], 1.6)
	var nave := Geometry.rect(area, 0.31, 0.1, 0.43, 0.77)
	c.draw_rect(nave, palette["roof"])
	c.draw_rect(nave, palette["roof_dark"], false, 1.5)
	c.draw_line(Vector2(nave.get_center().x, nave.position.y), Vector2(nave.get_center().x, nave.end.y), palette["trim"], 2.0)
	var tower := Geometry.rect(area, 0.73, 0.12, 0.2, 0.23)
	c.draw_rect(tower, palette["wall"])
	c.draw_rect(tower.grow(-2.0), palette["roof_dark"])
	c.draw_rect(tower, palette["trim"], false, 1.5)
	if civ != "Chinese":
		var cross := tower.get_center()
		c.draw_line(cross + Vector2(0, -4), cross + Vector2(0, 4), palette["trim"], 1.4)
		c.draw_line(cross + Vector2(-3, -1), cross + Vector2(3, -1), palette["trim"], 1.4)
	c.draw_line(Vector2(nave.position.x, nave.end.y + 2), Vector2(nave.end.x, nave.end.y + 2), accent, 2.2)

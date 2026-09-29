class_name RtsKeepMonasteryVisual
extends RefCounted

const Geometry = preload("res://scripts/entities/visuals/building_geometry.gd")

# Finished regular buildings; the owning node provides the low foundation.
static func draw_topdown(c: CanvasItem, kind: String, bounds: Rect2, palette: Dictionary, accent: Color, civ: String) -> void:
	match kind:
		"keep": _keep_2d(c, bounds, palette, accent)
		"monastery": _monastery_2d(c, bounds, palette, accent, civ)


static func draw_iso(c: CanvasItem, kind: String, nw: Vector2, ne: Vector2, se: Vector2, sw: Vector2, lift: Vector2, palette: Dictionary, accent: Color, civ: String, canvas: Transform2D, zoom: float) -> void:
	match kind:
		"keep": _keep_iso(c, nw, ne, sw, lift, palette, accent, canvas, zoom)
		"monastery": _monastery_iso(c, nw, ne, sw, lift, palette, accent, civ, canvas, zoom)


static func _wall(c: CanvasItem, a: Vector2, b: Vector2, up: Vector2, face: Color, coping: Color) -> void:
	c.draw_colored_polygon(PackedVector2Array([a + up, b + up, b, a]), face)
	c.draw_line(a + up, b + up, coping, 3.0)
	for fraction in [0.09, 0.27, 0.45, 0.63, 0.81]:
		var tooth := a.lerp(b, fraction) + up
		c.draw_line(tooth, tooth + up * 0.19, coping, 4.0)


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


static func _keep_iso(c: CanvasItem, nw: Vector2, ne: Vector2, sw: Vector2, lift: Vector2, palette: Dictionary, accent: Color, canvas: Transform2D, zoom: float) -> void:
	var wall: Color = palette["wall"]
	var trim: Color = palette["trim"]
	var dark: Color = palette["roof_dark"]
	var ground := lift * 0.18
	var court := PackedVector2Array([
		Geometry.point(nw, ne, sw, 0.09, 0.09) + ground,
		Geometry.point(nw, ne, sw, 0.91, 0.09) + ground,
		Geometry.point(nw, ne, sw, 0.91, 0.91) + ground,
		Geometry.point(nw, ne, sw, 0.09, 0.91) + ground,
	])
	c.draw_colored_polygon(court, wall.darkened(0.27))
	var curtain_up := Geometry.up(canvas, zoom, 22.0)
	_wall(c, Geometry.point(nw, ne, sw, 0.1, 0.1) + ground, Geometry.point(nw, ne, sw, 0.9, 0.1) + ground, curtain_up, wall.darkened(0.23), trim)
	_wall(c, Geometry.point(nw, ne, sw, 0.9, 0.1) + ground, Geometry.point(nw, ne, sw, 0.9, 0.9) + ground, curtain_up, wall.darkened(0.17), trim)
	# The near curtains sit below the donjon roof in screen space. Draw them
	# first so their tall polygons cannot erase the upper tower and battlements.
	_wall(c, Geometry.point(nw, ne, sw, 0.1, 0.1) + ground, Geometry.point(nw, ne, sw, 0.1, 0.9) + ground, curtain_up, wall.darkened(0.07), trim)
	_wall(c, Geometry.point(nw, ne, sw, 0.1, 0.9) + ground, Geometry.point(nw, ne, sw, 0.9, 0.9) + ground, curtain_up, wall, trim)
	_turret(c, nw, ne, sw, ground, 0.12, 0.12, palette, canvas, zoom, false)
	_turret(c, nw, ne, sw, ground, 0.88, 0.12, palette, canvas, zoom, false)
	# The taller square donjon gives the keep a distinct center above the walls.
	var donjon_up := Geometry.up(canvas, zoom, 51.0)
	var top := _block(c, nw, ne, sw, ground, donjon_up, 0.3, 0.18, 0.4, 0.44, wall, trim)
	c.draw_colored_polygon(PackedVector2Array(top), dark)
	for i in 4:
		_wall_top(c, top[i], top[(i + 1) % 4], Geometry.up(canvas, zoom, 4.0), trim, 3)
	c.draw_line(Geometry.point(nw, ne, sw, 0.3, 0.62) + ground + donjon_up * 0.86, Geometry.point(nw, ne, sw, 0.7, 0.62) + ground + donjon_up * 0.86, trim.darkened(0.12), 1.8)
	for u in [0.39, 0.61]:
		var slit := Geometry.point(nw, ne, sw, u, 0.62) + ground + donjon_up * 0.69
		c.draw_line(slit, slit + donjon_up * 0.17, trim, 4.4)
		c.draw_line(slit + donjon_up * 0.025, slit + donjon_up * 0.15, Color("394342"), 2.5)
	for v in [0.31, 0.5]:
		var slit := Geometry.point(nw, ne, sw, 0.7, v) + ground + donjon_up * 0.72
		c.draw_line(slit, slit + donjon_up * 0.15, trim, 4.0)
		c.draw_line(slit + donjon_up * 0.025, slit + donjon_up * 0.13, Color("394342"), 2.4)
	# Front turrets and gate frame the completed central tower.
	var entrance := Geometry.point(nw, ne, sw, 0.5, 0.9) + ground
	var gate_up := Geometry.up(canvas, zoom, 14.0)
	var gate_half := (ne - nw) * 0.095
	c.draw_colored_polygon(PackedVector2Array([entrance - gate_half + gate_up * 0.7, entrance + gate_half + gate_up * 0.7, entrance + gate_half, entrance - gate_half]), Color("2f3331"))
	c.draw_line(entrance - gate_half + gate_up * 0.7, entrance + gate_half + gate_up * 0.7, trim.darkened(0.28), 1.8)
	for fraction in [-0.45, 0.0, 0.45]:
		var bar: Vector2 = entrance + gate_half * fraction
		c.draw_line(bar, bar + gate_up * 0.66, palette["timber"], 0.9)
	_turret(c, nw, ne, sw, ground, 0.12, 0.88, palette, canvas, zoom, true)
	_turret(c, nw, ne, sw, ground, 0.88, 0.88, palette, canvas, zoom, true)
	var banner := Geometry.point(nw, ne, sw, 0.72, 0.65) + ground + curtain_up * 0.72
	c.draw_colored_polygon(PackedVector2Array([banner, banner + (ne - nw) * 0.1, banner + (ne - nw) * 0.1 - curtain_up * 0.24, banner - curtain_up * 0.2]), accent)


static func _wall_top(c: CanvasItem, a: Vector2, b: Vector2, rise: Vector2, color: Color, teeth: int) -> void:
	c.draw_line(a, b, color, 2.0)
	for index in teeth:
		c.draw_line(a.lerp(b, (float(index) + 0.5) / float(teeth)), a.lerp(b, (float(index) + 0.5) / float(teeth)) + rise, color, 3.2)


static func _turret(c: CanvasItem, nw: Vector2, ne: Vector2, sw: Vector2, floor: Vector2, u: float, v: float, palette: Dictionary, canvas: Transform2D, zoom: float, foreground: bool) -> void:
	var radius := 0.105
	var corners: Array[Vector2] = []
	for offset in [Vector2(-0.65, -1), Vector2(0.65, -1), Vector2(1, -0.55), Vector2(1, 0.55), Vector2(0.65, 1), Vector2(-0.65, 1), Vector2(-1, 0.55), Vector2(-1, -0.55)]:
		corners.append(Geometry.point(nw, ne, sw, u + offset.x * radius, v + offset.y * radius) + floor)
	var height := Geometry.up(canvas, zoom, 34.0 if foreground else 31.0)
	var wall: Color = palette["wall"]
	for index in [2, 3, 4, 5, 6]:
		var next: int = (index + 1) % 8
		c.draw_colored_polygon(PackedVector2Array([corners[index] + height, corners[next] + height, corners[next], corners[index]]), wall.darkened(0.05 + float(index - 2) * 0.035))
	var top := PackedVector2Array()
	for corner in corners: top.append(corner + height)
	var peak := Geometry.point(nw, ne, sw, u, v) + floor + height + Geometry.up(canvas, zoom, 8.0)
	for index in 8:
		c.draw_colored_polygon(PackedVector2Array([top[index], top[(index + 1) % 8], peak]), palette["roof"].lightened(0.07) if index in [0, 1, 6, 7] else palette["roof_dark"])
	c.draw_polyline(PackedVector2Array([corners[2] + height, corners[3] + height, corners[4] + height, corners[5] + height, corners[6] + height]), palette["trim"], 1.7)
	var slit := Geometry.point(nw, ne, sw, u, v + radius * 0.9) + floor + height * 0.59
	c.draw_line(slit, slit + height * 0.16, Color("394342"), 1.9)


static func _keep_2d(c: CanvasItem, bounds: Rect2, palette: Dictionary, accent: Color) -> void:
	var outer := bounds.grow(-5.0)
	var court := outer.grow(-8.0)
	c.draw_rect(outer, palette["wall"])
	c.draw_rect(court, palette["wall"].darkened(0.26))
	c.draw_rect(outer, palette["trim"], false, 2.5)
	var donjon := Geometry.rect(outer, 0.31, 0.28, 0.38, 0.38)
	c.draw_rect(donjon, palette["roof_dark"])
	c.draw_rect(donjon, palette["trim"], false, 2.0)
	for u in [0.12, 0.88]:
		for v in [0.12, 0.88]:
			var center := outer.position + outer.size * Vector2(u, v)
			c.draw_circle(center, minf(outer.size.x, outer.size.y) * 0.1, palette["wall"])
			c.draw_circle(center, minf(outer.size.x, outer.size.y) * 0.065, palette["roof_dark"])
			c.draw_arc(center, minf(outer.size.x, outer.size.y) * 0.1, 0, TAU, 16, palette["trim"], 1.7)
	var gate := Rect2(outer.get_center().x - 7.0, outer.end.y - 8.0, 14.0, 10.0)
	c.draw_rect(gate, Color("303430"))
	c.draw_line(Vector2(gate.position.x, gate.position.y), Vector2(gate.end.x, gate.position.y), accent, 2.0)


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

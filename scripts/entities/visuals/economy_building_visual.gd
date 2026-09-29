extends RefCounted

# The surrounding building node draws the foundation and construction state.
# These finished details stay inside its existing footprint and use its palette.

static func draw_topdown(c: CanvasItem, kind: String, bounds: Rect2, palette: Dictionary, accent: Color, civ: String) -> void:
	match kind:
		"town_center": _town_center_2d(c, bounds, palette, accent, civ)
		"mill": _mill_2d(c, bounds, palette, accent)
		"lumber_camp": _lumber_2d(c, bounds, palette, accent)


static func draw_iso(c: CanvasItem, kind: String, nw: Vector2, ne: Vector2, se: Vector2, sw: Vector2, lift: Vector2, palette: Dictionary, accent: Color, civ: String, canvas: Transform2D, zoom: float) -> void:
	match kind:
		"town_center": _town_center_iso(c, nw, ne, sw, lift, palette, accent, civ, canvas, zoom)
		"mill": _mill_iso(c, nw, ne, sw, lift, palette, accent, civ, canvas, zoom)
		"lumber_camp": _lumber_iso(c, nw, ne, sw, lift, palette, accent, canvas, zoom)


static func _pt(nw: Vector2, ne: Vector2, sw: Vector2, u: float, v: float) -> Vector2:
	return nw + (ne - nw) * u + (sw - nw) * v


static func _up(canvas: Transform2D, zoom: float, pixels: float) -> Vector2:
	return RtsIsoProjection.world_delta(canvas, Vector2(0.0, -pixels * zoom))


static func _box(c: CanvasItem, nw: Vector2, ne: Vector2, sw: Vector2, base: Vector2, up: Vector2, u: float, v: float, width: float, depth: float, wall: Color, trim: Color) -> Array[Vector2]:
	var a := _pt(nw, ne, sw, u, v) + base
	var b := _pt(nw, ne, sw, u + width, v) + base
	var d := _pt(nw, ne, sw, u, v + depth) + base
	var f := _pt(nw, ne, sw, u + width, v + depth) + base
	c.draw_colored_polygon(PackedVector2Array([b + up, f + up, f, b]), wall.darkened(0.2))
	c.draw_colored_polygon(PackedVector2Array([d + up, f + up, f, d]), wall)
	c.draw_line(d + up, f + up, trim, 1.3)
	return [a + up, b + up, f + up, d + up]


static func _gable(c: CanvasItem, corners: Array[Vector2], rise: Vector2, palette: Dictionary, civ: String) -> void:
	var a: Vector2 = corners[0]
	var b: Vector2 = corners[1]
	var f: Vector2 = corners[2]
	var d: Vector2 = corners[3]
	var back := (a + b) * 0.5 + rise
	var front := (d + f) * 0.5 + rise
	var roof: Color = palette["roof"]
	var dark: Color = palette["roof_dark"]
	var wall: Color = palette["wall"]
	var trim: Color = palette["trim"]
	c.draw_colored_polygon(PackedVector2Array([a, b, back]), wall.darkened(0.08))
	c.draw_colored_polygon(PackedVector2Array([d, f, front]), wall)
	c.draw_colored_polygon(PackedVector2Array([a, back, front, d]), roof.lightened(0.1))
	c.draw_colored_polygon(PackedVector2Array([back, b, f, front]), roof)
	c.draw_polyline(PackedVector2Array([d, front, f]), dark, 1.5)
	c.draw_line(back, front, trim, 1.4)
	for fraction in [0.24, 0.5, 0.76]:
		c.draw_line(a.lerp(d, fraction), back.lerp(front, fraction), Color(dark, 0.43), 0.85)
		c.draw_line(back.lerp(front, fraction), b.lerp(f, fraction), Color(dark, 0.36), 0.85)
	if civ == "Chinese":
		# A few lifted tips read as a tiled, East Asian roof at game scale.
		for corner in [a, b, f, d]:
			c.draw_line(corner, corner + rise * 0.3, trim, 1.6)


static func _town_center_iso(c: CanvasItem, nw: Vector2, ne: Vector2, sw: Vector2, lift: Vector2, palette: Dictionary, accent: Color, civ: String, canvas: Transform2D, zoom: float) -> void:
	var wall: Color = palette["wall"]
	var timber: Color = palette["timber"]
	var trim: Color = palette["trim"]
	var dark: Color = palette["roof_dark"]
	var floor := lift * 0.18
	# The front third is a paved working court. The main hall occupies the back.
	var court := PackedVector2Array([
		_pt(nw, ne, sw, 0.11, 0.50) + floor,
		_pt(nw, ne, sw, 0.89, 0.50) + floor,
		_pt(nw, ne, sw, 0.89, 0.90) + floor,
		_pt(nw, ne, sw, 0.11, 0.90) + floor,
	])
	c.draw_colored_polygon(court, Color("a79b7e"))
	for fraction in [0.59, 0.69, 0.79]:
		c.draw_line(_pt(nw, ne, sw, 0.13, fraction) + floor, _pt(nw, ne, sw, 0.87, fraction) + floor, Color("716e5f", 0.45), 0.8)
	var hall_up := _up(canvas, zoom, 27.0)
	var hall := _box(c, nw, ne, sw, floor, hall_up, 0.10, 0.07, 0.80, 0.34, wall, trim)
	_gable(c, hall, _up(canvas, zoom, 9.0), palette, civ)
	for fraction in [0.12, 0.38, 0.62, 0.88]:
		var post := _pt(nw, ne, sw, fraction, 0.41) + floor
		c.draw_line(post, post + hall_up * 0.95, timber, 2.0)
	c.draw_line(_pt(nw, ne, sw, 0.1, 0.41) + floor + hall_up * 0.45, _pt(nw, ne, sw, 0.9, 0.41) + floor + hall_up * 0.45, timber, 1.8)
	for fraction in [0.27, 0.73]:
		var window := _pt(nw, ne, sw, fraction, 0.41) + floor + hall_up * 0.65
		c.draw_line(window, window + hall_up * 0.18, dark, 4.0)
		c.draw_line(window + hall_up * 0.83, window + hall_up * 0.83 + (ne - nw) * 0.05, trim, 1.1)
	# Low parapets on the sides frame the open court rather than enclosing it in one roof.
	for u in [0.08, 0.92]:
		var rear := _pt(nw, ne, sw, u, 0.40) + floor
		var near := _pt(nw, ne, sw, u, 0.86) + floor
		var parapet := _up(canvas, zoom, 6.0)
		c.draw_line(rear, rear + parapet, wall.darkened(0.1), 3.0)
		c.draw_line(near, near + parapet, wall, 3.0)
		c.draw_line(rear + parapet, near + parapet, trim, 3.0)
		for fraction in [0.1, 0.42, 0.74]:
			var crenel := rear.lerp(near, fraction) + parapet
			c.draw_line(crenel, crenel + _up(canvas, zoom, 2.0), wall, 3.4)
	# The front remains open. A large bronze bell hangs in its own timber frame.
	var bell_left := _pt(nw, ne, sw, 0.29, 0.70) + floor
	var bell_right := _pt(nw, ne, sw, 0.71, 0.70) + floor
	var frame_up := _up(canvas, zoom, 25.0)
	c.draw_line(bell_left, bell_left + frame_up, timber.darkened(0.12), 3.2)
	c.draw_line(bell_right, bell_right + frame_up, timber.darkened(0.12), 3.2)
	c.draw_line(bell_left + frame_up, bell_right + frame_up, timber, 3.8)
	var brace_left := bell_left.lerp(bell_right, 0.18) + frame_up
	var brace_right := bell_left.lerp(bell_right, 0.82) + frame_up
	c.draw_line(bell_left + frame_up * 0.72, brace_left, timber, 1.7)
	c.draw_line(bell_right + frame_up * 0.72, brace_right, timber, 1.7)
	var bell_top := (bell_left + bell_right) * 0.5 + frame_up + _up(canvas, zoom, -5.0)
	c.draw_line((bell_left + bell_right) * 0.5 + frame_up, bell_top, Color("5c4b31"), 1.6)
	_draw_bell_iso(c, bell_top, canvas, zoom)
	c.draw_line(_pt(nw, ne, sw, 0.11, 0.97) + floor, _pt(nw, ne, sw, 0.36, 0.97) + floor, accent, 2.0)
	c.draw_line(_pt(nw, ne, sw, 0.64, 0.97) + floor, _pt(nw, ne, sw, 0.89, 0.97) + floor, accent, 2.0)


static func _draw_bell_iso(c: CanvasItem, top: Vector2, canvas: Transform2D, zoom: float) -> void:
	var right := RtsIsoProjection.world_delta(canvas, Vector2(9.5 * zoom, 0.0))
	var down := _up(canvas, zoom, -13.0)
	var bronze := Color("c99748")
	var shadow := Color("604526")
	var highlight := Color("f5d985")
	var outline := PackedVector2Array([
		top - right * 0.22, top + right * 0.22,
		top + right * 0.48 + down * 0.22,
		top + right * 0.64 + down * 0.69,
		top + right + down, top - right + down,
		top - right * 0.64 + down * 0.69,
		top - right * 0.48 + down * 0.22,
	])
	c.draw_colored_polygon(outline, shadow)
	c.draw_circle(top, 2.0, shadow)
	c.draw_colored_polygon(PackedVector2Array([
		top - right * 0.2 + down * 0.05, top + right * 0.18 + down * 0.05,
		top + right * 0.43 + down * 0.28,
		top + right * 0.58 + down * 0.72,
		top + right * 0.88 + down * 0.91,
		top - right * 0.88 + down * 0.91,
		top - right * 0.58 + down * 0.72,
		top - right * 0.43 + down * 0.28,
	]), bronze)
	c.draw_line(top - right + down, top + right + down, highlight, 2.8)
	c.draw_line(top - right * 0.8 + down * 0.9, top + right * 0.8 + down * 0.9, shadow, 1.0)
	c.draw_line(top - right * 0.33 + down * 0.2, top - right * 0.55 + down * 0.75, highlight, 1.6)
	c.draw_circle(top + down * 1.16, 2.6, shadow)


static func _town_center_2d(c: CanvasItem, bounds: Rect2, palette: Dictionary, accent: Color, civ: String) -> void:
	var inner := bounds.grow(-5.0)
	var roof: Color = palette["roof"]
	var trim: Color = palette["trim"]
	var dark: Color = palette["roof_dark"]
	c.draw_rect(inner, palette["wall"])
	var hall := Rect2(inner.position + inner.size * Vector2(0.1, 0.07), inner.size * Vector2(0.8, 0.45))
	c.draw_rect(hall, roof)
	c.draw_line(Vector2(hall.position.x, hall.get_center().y), Vector2(hall.end.x, hall.get_center().y), trim, 2.0)
	for fraction in [0.22, 0.5, 0.78]:
		var x := lerpf(hall.position.x, hall.end.x, fraction)
		c.draw_line(Vector2(x, hall.position.y), Vector2(x, hall.end.y), Color(dark, 0.5), 1.0)
	var court := Rect2(inner.position + inner.size * Vector2(0.13, 0.54), inner.size * Vector2(0.74, 0.38))
	c.draw_rect(court, Color("a79b7e"))
	for fraction in [0.14, 0.44, 0.74]:
		var y := lerpf(court.position.y, court.end.y, fraction)
		c.draw_line(Vector2(court.position.x, y), Vector2(court.end.x, y), Color("716e5f", 0.4), 1.0)
	var bell_center := inner.position + inner.size * Vector2(0.5, 0.73)
	var frame_left := bell_center + Vector2(-12, -9)
	var frame_right := bell_center + Vector2(12, -9)
	c.draw_line(frame_left, frame_left + Vector2(0, 19), palette["timber"], 3.0)
	c.draw_line(frame_right, frame_right + Vector2(0, 19), palette["timber"], 3.0)
	c.draw_line(frame_left, frame_right, palette["timber"], 3.4)
	var bell_outline := PackedVector2Array([
		bell_center + Vector2(-2, -6), bell_center + Vector2(2, -6),
		bell_center + Vector2(5, -2), bell_center + Vector2(6, 2),
		bell_center + Vector2(9, 7), bell_center + Vector2(-9, 7),
		bell_center + Vector2(-6, 2), bell_center + Vector2(-5, -2),
	])
	c.draw_colored_polygon(bell_outline, Color("654923"))
	c.draw_colored_polygon(PackedVector2Array([
		bell_center + Vector2(-2, -5), bell_center + Vector2(2, -5),
		bell_center + Vector2(4, -1), bell_center + Vector2(5, 2),
		bell_center + Vector2(8, 6), bell_center + Vector2(-8, 6),
		bell_center + Vector2(-5, 2), bell_center + Vector2(-4, -1),
	]), Color("c99748"))
	c.draw_circle(bell_center + Vector2(0, -6), 2.2, Color("775329"))
	c.draw_line(bell_center + Vector2(-9, 7), bell_center + Vector2(9, 7), Color("f5d985"), 2.3)
	c.draw_circle(bell_center + Vector2(0, 10), 2.3, Color("604526"))
	c.draw_line(Vector2(inner.position.x + inner.size.x * 0.13, inner.end.y - 2), Vector2(inner.position.x + inner.size.x * 0.38, inner.end.y - 2), accent, 2.5)
	c.draw_line(Vector2(inner.position.x + inner.size.x * 0.62, inner.end.y - 2), Vector2(inner.position.x + inner.size.x * 0.87, inner.end.y - 2), accent, 2.5)


static func _mill_iso(c: CanvasItem, nw: Vector2, ne: Vector2, sw: Vector2, lift: Vector2, palette: Dictionary, accent: Color, civ: String, canvas: Transform2D, zoom: float) -> void:
	var timber: Color = palette["timber"]
	var trim: Color = palette["trim"]
	var wall: Color = palette["wall"]
	var dark: Color = palette["roof_dark"]
	var floor := lift * 0.18
	var wall_up := _up(canvas, zoom, 27.0)
	# The mill is a narrow, tall gabled house; the surrounding low base is its yard.
	_box(c, nw, ne, sw, floor, wall_up, 0.22, 0.14, 0.56, 0.65, wall, trim)
	var eave := floor + wall_up
	var roof_corners: Array[Vector2] = [
		_pt(nw, ne, sw, 0.18, 0.10) + eave,
		_pt(nw, ne, sw, 0.82, 0.10) + eave,
		_pt(nw, ne, sw, 0.82, 0.84) + eave,
		_pt(nw, ne, sw, 0.18, 0.84) + eave,
	]
	_gable(c, roof_corners, _up(canvas, zoom, 13.0), palette, civ)
	for fraction in [0.24, 0.76]:
		var post := _pt(nw, ne, sw, fraction, 0.79) + floor
		c.draw_line(post, post + wall_up * 0.94, timber, 2.2)
	c.draw_line(_pt(nw, ne, sw, 0.22, 0.79) + floor + wall_up * 0.47, _pt(nw, ne, sw, 0.78, 0.79) + floor + wall_up * 0.47, timber, 1.7)
	var door_left := _pt(nw, ne, sw, 0.43, 0.79) + floor
	var door_right := _pt(nw, ne, sw, 0.57, 0.79) + floor
	c.draw_colored_polygon(PackedVector2Array([door_left + wall_up * 0.38, door_right + wall_up * 0.38, door_right, door_left]), Color("514433"))
	c.draw_line(door_left + wall_up * 0.38, door_right + wall_up * 0.38, trim, 1.3)
	# Mount the four sails in front of the facade, after the roof has been drawn.
	var hub := _pt(nw, ne, sw, 0.5, 0.8) + floor + wall_up * 0.7
	var right := RtsIsoProjection.world_delta(canvas, Vector2(15.0 * zoom, 0.0))
	var upward := _up(canvas, zoom, 15.0)
	_draw_sails(c, hub, right, upward, timber, trim, canvas)
	for u in [0.14, 0.27, 0.76, 0.89]:
		var bag := _pt(nw, ne, sw, u, 0.89) + floor
		c.draw_circle(bag, 3.1, Color("d5bc88"))
		c.draw_line(bag + Vector2(-2, -1), bag + Vector2(2, -1), Color("79684c"), 0.9)
	c.draw_line(_pt(nw, ne, sw, 0.22, 0.87) + floor, _pt(nw, ne, sw, 0.78, 0.87) + floor, accent, 2.0)


static func _draw_sails(c: CanvasItem, hub: Vector2, right: Vector2, up: Vector2, timber: Color, trim: Color, canvas: Transform2D) -> void:
	for direction in [right + up, -right + up, -right - up, right - up]:
		var endpoint: Vector2 = hub + direction
		var screen_dir := canvas.basis_xform(direction)
		var screen_side := Vector2(-screen_dir.y, screen_dir.x).normalized() * screen_dir.length() * 0.4
		var side := RtsIsoProjection.world_delta(canvas, screen_side)
		c.draw_colored_polygon(PackedVector2Array([hub + direction * 0.27, hub + direction * 0.96, hub + direction * 0.96 + side, hub + direction * 0.27 + side * 0.65]), Color("f2e0b1"))
		c.draw_line(hub + direction * 0.27 + side * 0.65, hub + direction * 0.96 + side, Color("796443"), 1.2)
		c.draw_line(hub, endpoint, timber.darkened(0.22), 2.8)
	c.draw_circle(hub, 3.8, trim)
	c.draw_circle(hub, 1.6, timber.darkened(0.25))


static func _mill_2d(c: CanvasItem, bounds: Rect2, palette: Dictionary, accent: Color) -> void:
	var yard := bounds.grow(-5.0)
	c.draw_rect(yard, Color("a89a77"))
	var roof := Rect2(yard.position + yard.size * Vector2(0.17, 0.08), yard.size * Vector2(0.66, 0.78))
	c.draw_rect(roof, palette["roof"])
	c.draw_colored_polygon(PackedVector2Array([roof.position, Vector2(roof.get_center().x, roof.position.y), Vector2(roof.get_center().x, roof.end.y), Vector2(roof.position.x, roof.end.y)]), palette["roof"].lightened(0.13))
	c.draw_line(Vector2(roof.get_center().x, roof.position.y), Vector2(roof.get_center().x, roof.end.y), palette["trim"], 2.2)
	for fraction in [0.19, 0.4, 0.64, 0.84]:
		var y := lerpf(roof.position.y, roof.end.y, fraction)
		c.draw_line(Vector2(roof.position.x + 2, y), Vector2(roof.end.x - 2, y), Color(palette["roof_dark"], 0.45), 1.0)
	var hub := roof.get_center() + Vector2(1, 2)
	_draw_sails(c, hub, Vector2(11, 0), Vector2(0, -11), palette["timber"], palette["trim"], Transform2D.IDENTITY)
	for x in [yard.position.x + 5, yard.end.x - 5]:
		for y in [yard.position.y + 9, yard.end.y - 7]:
			c.draw_circle(Vector2(x, y), 3.0, Color("d5bc88"))
	c.draw_line(Vector2(roof.position.x + 3, roof.end.y - 2), Vector2(roof.end.x - 3, roof.end.y - 2), accent, 2.5)


static func _lumber_iso(c: CanvasItem, nw: Vector2, ne: Vector2, sw: Vector2, lift: Vector2, palette: Dictionary, accent: Color, canvas: Transform2D, zoom: float) -> void:
	var floor := lift * 0.18
	var timber: Color = palette["timber"]
	var trim: Color = palette["trim"]
	var floor_poly := PackedVector2Array([
		_pt(nw, ne, sw, 0.07, 0.08) + floor,
		_pt(nw, ne, sw, 0.93, 0.08) + floor,
		_pt(nw, ne, sw, 0.93, 0.92) + floor,
		_pt(nw, ne, sw, 0.07, 0.92) + floor,
	])
	c.draw_colored_polygon(floor_poly, Color("9a855e"))
	for fraction in [0.22, 0.42, 0.62, 0.82]:
		c.draw_line(_pt(nw, ne, sw, 0.08, fraction) + floor, _pt(nw, ne, sw, 0.92, fraction) + floor, Color("6d5b42", 0.65), 1.0)
	# A horizontal timber drum dominates the open camp, with extra cut logs below.
	var rack_left := _pt(nw, ne, sw, 0.14, 0.18) + floor
	var rack_right := _pt(nw, ne, sw, 0.86, 0.18) + floor
	var rack_front_left := _pt(nw, ne, sw, 0.14, 0.70) + floor
	var rack_front_right := _pt(nw, ne, sw, 0.86, 0.70) + floor
	var rack_up := _up(canvas, zoom, 9.0)
	for post in [rack_left, rack_right, rack_front_left, rack_front_right]:
		c.draw_line(post, post + rack_up, timber.darkened(0.12), 3.0)
	c.draw_line(rack_left + rack_up, rack_right + rack_up, timber, 2.8)
	c.draw_line(rack_front_left + rack_up, rack_front_right + rack_up, timber, 2.8)
	var drum_start := _pt(nw, ne, sw, 0.22, 0.42) + floor + _up(canvas, zoom, 9.0)
	var drum_end := _pt(nw, ne, sw, 0.78, 0.42) + floor + _up(canvas, zoom, 9.0)
	c.draw_line(drum_start, drum_end, Color("65432d"), 15.0)
	c.draw_line(drum_start + _up(canvas, zoom, 3.0), drum_end + _up(canvas, zoom, 3.0), Color("a57647"), 8.0)
	c.draw_circle(drum_end, 7.2, Color("bd925d"))
	c.draw_arc(drum_end, 5.4, 0.0, TAU, 20, Color("765133"), 1.5)
	c.draw_circle(drum_end, 2.1, Color("765133"))
	for fraction in [0.28, 0.48, 0.68]:
		var start := _pt(nw, ne, sw, 0.19, fraction + 0.14) + floor + _up(canvas, zoom, 2.0)
		var finish := _pt(nw, ne, sw, 0.8, fraction + 0.14) + floor + _up(canvas, zoom, 2.0)
		c.draw_line(start, finish, Color("805333"), 6.5)
		c.draw_circle(finish, 3.4, Color("c49a67"))
		c.draw_circle(finish, 1.2, Color("7d5737"))
	# Three beams form the simple lifting trestle visible at the front of the camp.
	var hoist_left := _pt(nw, ne, sw, 0.18, 0.85) + floor
	var hoist_right := _pt(nw, ne, sw, 0.82, 0.85) + floor
	var hoist_peak := (hoist_left + hoist_right) * 0.5 + _up(canvas, zoom, 20.0)
	c.draw_line(hoist_left, hoist_peak, timber, 3.7)
	c.draw_line(hoist_peak, hoist_right, timber, 3.7)
	c.draw_line(hoist_left + _up(canvas, zoom, 4.0), hoist_right + _up(canvas, zoom, 4.0), trim, 2.2)
	c.draw_line(hoist_peak, hoist_peak + _up(canvas, zoom, -10.0), Color("3f392e"), 1.5)
	c.draw_circle(hoist_peak + _up(canvas, zoom, -10.0), 2.1, trim)
	c.draw_line(_pt(nw, ne, sw, 0.12, 0.89) + floor, _pt(nw, ne, sw, 0.88, 0.89) + floor, accent, 1.8)


static func _lumber_2d(c: CanvasItem, bounds: Rect2, palette: Dictionary, accent: Color) -> void:
	var deck := bounds.grow(-5.0)
	c.draw_rect(deck, Color("9a855e"))
	for fraction in [0.17, 0.35, 0.53, 0.71, 0.89]:
		var y := lerpf(deck.position.y, deck.end.y, fraction)
		c.draw_line(Vector2(deck.position.x + 2, y), Vector2(deck.end.x - 2, y), Color("654d35", 0.6), 1.0)
	var rack := Rect2(deck.position + deck.size * Vector2(0.1, 0.12), deck.size * Vector2(0.8, 0.58))
	c.draw_rect(rack, palette["timber"], false, 3.4)
	var drum := Rect2(rack.position + rack.size * Vector2(0.12, 0.16), rack.size * Vector2(0.72, 0.58))
	c.draw_rect(drum, Color("805535"))
	for fraction in [0.18, 0.48, 0.78]:
		var x := lerpf(drum.position.x, drum.end.x, fraction)
		c.draw_line(Vector2(x, drum.position.y), Vector2(x, drum.end.y), Color("b18450"), 2.0)
	c.draw_circle(Vector2(drum.end.x, drum.get_center().y), drum.size.y * 0.48, Color("c69c65"))
	c.draw_circle(Vector2(drum.end.x, drum.get_center().y), drum.size.y * 0.17, palette["timber"])
	var peak := Vector2(rack.get_center().x, deck.end.y - 3)
	c.draw_line(Vector2(peak.x - 16, rack.end.y), peak, palette["timber"], 3.2)
	c.draw_line(peak, Vector2(peak.x + 16, rack.end.y), palette["timber"], 3.2)
	c.draw_line(Vector2(deck.position.x + 6, deck.end.y - 3), Vector2(deck.end.x - 6, deck.end.y - 3), accent, 2.3)

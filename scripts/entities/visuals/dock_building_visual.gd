extends RefCounted

const Geometry = preload("res://scripts/entities/visuals/building_geometry.gd")

# A broad timber quay with a storehouse and a small lookout, adapted from the
# recognizable silhouette of Age of Empires IV docks to this game's tile size.

static func draw_topdown(c: CanvasItem, bounds: Rect2, palette: Dictionary, accent: Color, _civ: String) -> void:
	var deck := Rect2(bounds.position + bounds.size * Vector2(0.04, 0.04), bounds.size * 0.92)
	var timber: Color = palette["timber"]
	var trim: Color = palette["trim"]
	var roof: Color = palette["roof"]
	var dark: Color = palette["roof_dark"]
	c.draw_rect(deck, Color("a98559"))
	for fraction in [0.13, 0.25, 0.37, 0.49, 0.61, 0.73, 0.85]:
		var y := lerpf(deck.position.y, deck.end.y, fraction)
		c.draw_line(Vector2(deck.position.x, y), Vector2(deck.end.x, y), Color(timber.darkened(0.33), 0.5), 1.0)
	c.draw_rect(deck, timber.darkened(0.2), false, 1.8)
	# The two projecting fingers leave a boat berth between them.
	for x_fraction in [0.13, 0.72]:
		var finger := Rect2(deck.position + deck.size * Vector2(x_fraction, 0.68), deck.size * Vector2(0.15, 0.28))
		c.draw_rect(finger, Color("81603d"))
		c.draw_rect(finger, trim, false, 1.1)
	var store := Rect2(deck.position + deck.size * Vector2(0.08, 0.10), deck.size * Vector2(0.52, 0.40))
	c.draw_rect(store, roof)
	c.draw_line(Vector2(store.position.x, store.get_center().y), Vector2(store.end.x, store.get_center().y), trim, 2.0)
	for fraction in [0.24, 0.48, 0.72]:
		var x := lerpf(store.position.x, store.end.x, fraction)
		c.draw_line(Vector2(x, store.position.y + 1), Vector2(x, store.end.y - 1), Color(dark, 0.4), 1.0)
	c.draw_rect(store, timber.darkened(0.2), false, 1.6)
	var tower := Rect2(deck.position + deck.size * Vector2(0.69, 0.12), deck.size * Vector2(0.20, 0.25))
	c.draw_rect(tower, palette["wall"])
	c.draw_rect(tower.grow(-2.0), dark)
	c.draw_rect(tower, trim, false, 1.4)
	for spot in [Vector2(0.07, 0.55), Vector2(0.48, 0.55), Vector2(0.90, 0.55), Vector2(0.07, 0.93), Vector2(0.90, 0.93)]:
		var post: Vector2 = deck.position + deck.size * spot
		c.draw_circle(post, 2.6, timber.darkened(0.28))
		c.draw_circle(post + Vector2(-0.5, -0.5), 1.3, trim)
	var boom_base := deck.position + deck.size * Vector2(0.65, 0.66)
	c.draw_line(boom_base, boom_base + deck.size * Vector2(0.22, -0.16), timber.darkened(0.25), 2.2)
	c.draw_circle(boom_base, 2.5, trim)
	c.draw_line(Vector2(deck.position.x + 3.0, deck.end.y - 2.0), Vector2(deck.end.x - 3.0, deck.end.y - 2.0), accent, 2.0)


static func draw_iso(c: CanvasItem, nw: Vector2, ne: Vector2, _se: Vector2, sw: Vector2, lift: Vector2, palette: Dictionary, accent: Color, _civ: String, canvas: Transform2D, zoom: float) -> void:
	var timber: Color = palette["timber"]
	var trim: Color = palette["trim"]
	var roof: Color = palette["roof"]
	var dark: Color = palette["roof_dark"]
	var wall: Color = palette["wall"]
	var floor := lift * 0.18
	var deck_a := Geometry.point(nw, ne, sw, 0.04, 0.04) + floor
	var deck_b := Geometry.point(nw, ne, sw, 0.96, 0.04) + floor
	var deck_c := Geometry.point(nw, ne, sw, 0.96, 0.96) + floor
	var deck_d := Geometry.point(nw, ne, sw, 0.04, 0.96) + floor
	c.draw_colored_polygon(PackedVector2Array([deck_a, deck_b, deck_c, deck_d]), Color("a98559"))
	c.draw_colored_polygon(PackedVector2Array([deck_d, deck_c, deck_c - lift * 0.14, deck_d - lift * 0.14]), Color("745536"))
	for fraction in [0.13, 0.25, 0.37, 0.49, 0.61, 0.73, 0.85]:
		c.draw_line(Geometry.point(nw, ne, sw, 0.05, fraction) + floor, Geometry.point(nw, ne, sw, 0.95, fraction) + floor, Color(timber.darkened(0.37), 0.62), 1.0)
	for u in [0.05, 0.30, 0.70, 0.95]:
		var front := Geometry.point(nw, ne, sw, u, 0.96) + floor
		c.draw_line(front - lift * 0.21, front + Geometry.up(canvas, zoom, 9.0), timber.darkened(0.25), 3.0)
		c.draw_circle(front + Geometry.up(canvas, zoom, 9.0), 1.5, trim)
	for v in [0.14, 0.54, 0.91]:
		var edge := Geometry.point(nw, ne, sw, 0.96, v) + floor
		c.draw_line(edge - lift * 0.17, edge + Geometry.up(canvas, zoom, 7.0), timber.darkened(0.25), 2.5)
	# Low timber storehouse: dark entry below a single pitched roof.
	var a := Geometry.point(nw, ne, sw, 0.09, 0.10) + floor
	var b := Geometry.point(nw, ne, sw, 0.58, 0.10) + floor
	var f := Geometry.point(nw, ne, sw, 0.58, 0.48) + floor
	var d := Geometry.point(nw, ne, sw, 0.09, 0.48) + floor
	var up := Geometry.up(canvas, zoom, 18.0)
	var rise := Geometry.up(canvas, zoom, 7.0)
	c.draw_colored_polygon(PackedVector2Array([b + up, f + up, f, b]), wall.darkened(0.24))
	c.draw_colored_polygon(PackedVector2Array([d + up, f + up, f, d]), wall.darkened(0.08))
	var ridge_back := (a + d) * 0.5 + up + rise
	var ridge_front := (b + f) * 0.5 + up + rise
	c.draw_colored_polygon(PackedVector2Array([b + up, f + up, ridge_front]), wall.darkened(0.16))
	c.draw_colored_polygon(PackedVector2Array([a + up, b + up, ridge_front, ridge_back]), roof.darkened(0.16))
	c.draw_colored_polygon(PackedVector2Array([ridge_back, ridge_front, f + up, d + up]), roof)
	c.draw_line(ridge_back, ridge_front, trim, 1.5)
	var door := d.lerp(f, 0.56)
	c.draw_line(door, door + up * 0.58, Color("3b332b"), 6.0)
	c.draw_line(door + up * 0.61, door + up * 0.66, trim, 7.0)
	for fraction in [0.15, 0.45, 0.77]:
		c.draw_line(d.lerp(f, fraction), d.lerp(f, fraction) + up * 0.91, timber.darkened(0.16), 1.7)
	# Open watch shelter: posts and railing keep the deck visible beneath it.
	var tower_a := Geometry.point(nw, ne, sw, 0.69, 0.16) + floor
	var tower_u := (ne - nw) * 0.21
	var tower_v := (sw - nw) * 0.20
	var tower_b := tower_a + tower_u
	var tower_d := tower_a + tower_v
	var tower_f := tower_b + tower_v
	var tower_up := Geometry.up(canvas, zoom, 21.0)
	for post in [tower_a, tower_b, tower_d, tower_f]:
		c.draw_line(post, post + tower_up, timber.darkened(0.27), 2.6)
	var rail_height := tower_up * 0.42
	c.draw_line(tower_d + rail_height, tower_f + rail_height, timber.darkened(0.18), 2.0)
	c.draw_line(tower_b + rail_height, tower_f + rail_height, timber.darkened(0.18), 1.7)
	var roof_a := tower_a + tower_up
	var roof_b := tower_b + tower_up
	var roof_d := tower_d + tower_up
	var roof_f := tower_f + tower_up
	var peak := (roof_a + roof_b + roof_d + roof_f) * 0.25 + Geometry.up(canvas, zoom, 6.0)
	c.draw_colored_polygon(PackedVector2Array([roof_a, roof_b, peak]), roof.darkened(0.2))
	c.draw_colored_polygon(PackedVector2Array([roof_b, roof_f, peak]), dark)
	c.draw_colored_polygon(PackedVector2Array([roof_d, roof_f, peak]), roof)
	c.draw_colored_polygon(PackedVector2Array([roof_a, roof_d, peak]), roof.darkened(0.08))
	c.draw_line(roof_d, roof_f, trim, 1.2)
	# A short loading boom and hook finish the silhouette without filling the berth.
	var mast := Geometry.point(nw, ne, sw, 0.71, 0.72) + floor
	var mast_top := mast + Geometry.up(canvas, zoom, 19.0)
	var boom_end := mast_top + (ne - nw) * 0.18 + (sw - nw) * 0.04
	c.draw_line(mast, mast_top, timber.darkened(0.21), 2.2)
	c.draw_line(mast_top, boom_end, timber, 2.0)
	c.draw_line(boom_end, boom_end - Geometry.up(canvas, zoom, 8.0), dark, 1.0)
	c.draw_line(Geometry.point(nw, ne, sw, 0.08, 0.97) + floor, Geometry.point(nw, ne, sw, 0.92, 0.97) + floor, accent, 2.0)

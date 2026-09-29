class_name RtsIndustryBuildingVisual
extends RefCounted

const Geometry = preload("res://scripts/entities/visuals/building_geometry.gd")

# CanvasItem primitives keep the three workshops in the same projected space as
# RtsBuilding. All layout coordinates are fractions of the existing footprint.
static func draw_topdown(c: CanvasItem, kind: String, bounds: Rect2, palette: Dictionary, accent: Color, civ: String) -> void:
	match kind:
		"mining_camp": _mining_topdown(c, bounds, palette, accent)
		"blacksmith": _blacksmith_topdown(c, bounds, palette, accent, civ)
		"siege_workshop": _siege_topdown(c, bounds, palette, accent, civ)

static func draw_iso(c: CanvasItem, kind: String, nw: Vector2, ne: Vector2, se: Vector2, sw: Vector2, lift: Vector2, palette: Dictionary, accent: Color, civ: String, canvas: Transform2D, zoom: float) -> void:
	match kind:
		"mining_camp": _mining_iso(c, nw, ne, sw, lift, palette, accent, canvas, zoom)
		"blacksmith": _blacksmith_iso(c, nw, ne, sw, lift, palette, accent, civ, canvas, zoom)
		"siege_workshop": _siege_iso(c, nw, ne, sw, lift, palette, accent, civ, canvas, zoom)

static func _quad(c: CanvasItem, a: Vector2, b: Vector2, d: Vector2, e: Vector2, color: Color) -> void:
	c.draw_colored_polygon(PackedVector2Array([a, b, d, e]), color)

static func _upright_wheel(c: CanvasItem, center: Vector2, radius: float, canvas: Transform2D, zoom: float) -> void:
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for step in 16:
		var angle := TAU * float(step) / 16.0
		outer.append(center + Geometry.screen_delta(canvas, zoom, cos(angle) * radius, sin(angle) * radius))
		inner.append(center + Geometry.screen_delta(canvas, zoom, cos(angle) * (radius - 1.8), sin(angle) * (radius - 1.8)))
	c.draw_colored_polygon(outer, Color("2f302c"))
	c.draw_colored_polygon(inner, Color("a8814c"))
	for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
		c.draw_line(center, center + Geometry.screen_delta(canvas, zoom, cos(angle) * (radius - 0.8), sin(angle) * (radius - 0.8)), Color("514334"), 1.4)
	c.draw_circle(center, 1.8, Color("d6bd80"))

static func _mining_topdown(c: CanvasItem, bounds: Rect2, palette: Dictionary, accent: Color) -> void:
	var deck := bounds.grow(-5.0)
	var timber: Color = palette["timber"]
	var roof: Color = palette["roof"]
	var trim: Color = palette["trim"]
	c.draw_rect(deck, Color("9a8e70"))
	# Parallel iron rails and timber sleepers continue out of the mine shed.
	for v in [0.36, 0.49, 0.62, 0.75, 0.88]:
		c.draw_line(Geometry.point_rect(deck, 0.22, v), Geometry.point_rect(deck, 0.70, v), timber.darkened(0.06), 2.0)
	for u in [0.31, 0.62]: c.draw_line(Geometry.point_rect(deck, u, 0.30), Geometry.point_rect(deck, u, 0.94), Color("555954"), 2.2)
	var shelter := Geometry.rect(deck, 0.04, 0.05, 0.64, 0.41)
	c.draw_rect(shelter, roof)
	c.draw_rect(shelter, timber.darkened(0.2), false, 2.2)
	c.draw_line(Vector2(shelter.position.x + 2, shelter.get_center().y), Vector2(shelter.end.x - 2, shelter.get_center().y), trim, 1.6)
	# The ore car sits on the rails, with two visible wheel hubs and a full load.
	var cart := Geometry.rect(deck, 0.29, 0.57, 0.35, 0.25)
	c.draw_rect(cart.grow(1.4), Color("443c30"))
	c.draw_rect(cart, Color("987449"))
	c.draw_rect(cart.grow(-2.4), Color("554b3c"))
	for u in [0.14, 0.86]:
		var wheel := Geometry.point_rect(cart, u, 1.03)
		c.draw_circle(wheel, 3.1, Color("303633"))
		c.draw_circle(wheel, 1.2, trim)
	for offset in [Vector2(-3, 1), Vector2(2, -1), Vector2(4, 3)]:
		c.draw_circle(cart.get_center() + offset, 2.9, Color("cfad67"))
	# Two unmistakable piles of stone and gold sit outside the receiving shed.
	for pile in [[0.10, 0.72, Color("85877b")], [0.80, 0.77, Color("cfac5d")]]:
		var at := Geometry.point_rect(deck, pile[0], pile[1])
		c.draw_colored_polygon(PackedVector2Array([at + Vector2(-6, 5), at + Vector2(0, -6), at + Vector2(7, 5)]), pile[2])
		c.draw_line(at + Vector2(-3, 1), at + Vector2(0, -4), trim, 1.0)
	# The crane's upper winch, diagonal arm and hook meet over the gold pile.
	var winch := Geometry.point_rect(deck, 0.78, 0.19)
	c.draw_circle(winch, 5.0, timber.darkened(0.2))
	c.draw_circle(winch, 2.2, trim)
	c.draw_line(Geometry.point_rect(deck, 0.87, 0.81), winch, timber, 3.4)
	c.draw_line(winch, Geometry.point_rect(deck, 0.96, 0.36), timber, 3.2)
	c.draw_line(Geometry.point_rect(deck, 0.96, 0.36), Geometry.point_rect(deck, 0.96, 0.64), Color("615a49"), 1.5)
	c.draw_line(Geometry.point_rect(deck, 0.08, 0.49), Geometry.point_rect(deck, 0.66, 0.49), accent, 2.7)

static func _blacksmith_topdown(c: CanvasItem, bounds: Rect2, palette: Dictionary, accent: Color, civ: String) -> void:
	var yard := bounds.grow(-5.0)
	var timber: Color = palette["timber"]
	var trim: Color = palette["trim"]
	var roof: Color = palette["roof"]
	var dark: Color = palette["roof_dark"]
	c.draw_rect(yard, Color("8d846d"))
	# The long roof and exposed working bay give a different footprint from a house.
	var main := Geometry.rect(yard, 0.04, 0.04, 0.70, 0.55)
	c.draw_rect(main, roof)
	c.draw_rect(main, dark, false, 2.2)
	c.draw_line(Vector2(main.position.x + 3, main.get_center().y), Vector2(main.end.x - 3, main.get_center().y), trim, 2.0)
	for u in [0.27, 0.51, 0.73]:
		var x := lerpf(main.position.x, main.end.x, u)
		c.draw_line(Vector2(x, main.position.y + 1), Vector2(x, main.get_center().y - 2), Color(dark, 0.4), 1.0)
	var chimney := Geometry.rect(yard, 0.55, 0.12, 0.15, 0.18)
	c.draw_rect(chimney, Color("68554a"))
	c.draw_rect(chimney.grow(-2.0), Color("252623"))
	c.draw_rect(chimney, trim, false, 1.5)
	var forge := Geometry.rect(yard, 0.09, 0.65, 0.34, 0.21)
	c.draw_rect(forge, Color("3a3830"))
	c.draw_rect(forge.grow(-3.0), Color("d36e30"))
	c.draw_rect(forge.grow(-6.0), Color("f1bf65"))
	# Anvil and trough remain visible when the building is viewed from above.
	var anvil := Geometry.point_rect(yard, 0.69, 0.76)
	c.draw_colored_polygon(PackedVector2Array([anvil + Vector2(-7, -3), anvil + Vector2(6, -3), anvil + Vector2(3, 1), anvil + Vector2(-3, 2)]), Color("454c4b"))
	c.draw_rect(Rect2(anvil + Vector2(-2, 1), Vector2(5, 5)), Color("333b3a"))
	var trough := Geometry.rect(yard, 0.80, 0.55, 0.12, 0.28)
	c.draw_rect(trough, timber)
	c.draw_rect(trough.grow(-2.0), Color("4d7272"))
	c.draw_line(Geometry.point_rect(yard, 0.08, 0.61), Geometry.point_rect(yard, 0.43, 0.61), accent, 2.6)
	if civ == "Chinese": c.draw_line(Geometry.point_rect(main, 0.05, 0.09), Geometry.point_rect(main, 0.93, 0.09), trim, 1.6)

static func _siege_topdown(c: CanvasItem, bounds: Rect2, palette: Dictionary, accent: Color, civ: String) -> void:
	var yard := bounds.grow(-5.0)
	var timber: Color = palette["timber"]
	var roof: Color = palette["roof"]
	var dark: Color = palette["roof_dark"]
	var trim: Color = palette["trim"]
	c.draw_rect(yard, Color("8b826b"))
	# Two roofed workshops frame a broad, exposed siege assembly yard.
	var left := Geometry.rect(yard, 0.05, 0.05, 0.39, 0.43)
	var right := Geometry.rect(yard, 0.56, 0.05, 0.39, 0.43)
	for roof_part in [left, right]:
		c.draw_rect(roof_part, roof)
		c.draw_rect(roof_part, dark, false, 2.0)
		c.draw_line(Geometry.point_rect(roof_part, 0.5, 0.05), Geometry.point_rect(roof_part, 0.5, 0.95), trim, 2.0)
	var bay := Geometry.rect(yard, 0.14, 0.51, 0.72, 0.39)
	c.draw_rect(bay, Color("a99b78"))
	for v in [0.16, 0.78]: c.draw_line(Geometry.point_rect(bay, 0.06, v), Geometry.point_rect(bay, 0.94, v), timber.darkened(0.1), 1.8)
	# A single substantial catapult chassis replaces loose black dots.
	var chassis := Geometry.rect(bay, 0.22, 0.17, 0.58, 0.65)
	c.draw_rect(chassis, Color("7b5538"))
	c.draw_rect(chassis.grow(-2.0), Color("ab8653"))
	for u in [0.21, 0.79]: c.draw_line(Geometry.point_rect(chassis, u, 0.09), Geometry.point_rect(chassis, u, 0.91), Color("544331"), 2.1)
	c.draw_line(Geometry.point_rect(chassis, 0.15, 0.76), Geometry.point_rect(chassis, 0.86, 0.76), trim.darkened(0.1), 2.5)
	for u in [0.08, 0.92]:
		var wheel := Geometry.point_rect(chassis, u, 0.70)
		c.draw_circle(wheel, 4.1, Color("313733"))
		c.draw_circle(wheel, 2.7, Color("b18a54"))
		c.draw_line(wheel + Vector2(-2.0, 0), wheel + Vector2(2.0, 0), Color("544332"), 1.1)
		c.draw_line(wheel + Vector2(0, -2.0), wheel + Vector2(0, 2.0), Color("544332"), 1.1)
	var pivot := Geometry.point_rect(chassis, 0.50, 0.58)
	var arm_tip := Geometry.point_rect(chassis, 0.70, -0.28)
	c.draw_line(pivot, arm_tip, Color("5d402b"), 5.0)
	c.draw_line(pivot, arm_tip, trim.darkened(0.18), 2.4)
	c.draw_circle(arm_tip, 3.4, Color("474942"))
	c.draw_circle(arm_tip + Vector2(-0.8, -0.7), 1.5, Color("a9aaa0"))
	c.draw_line(Geometry.point_rect(yard, 0.29, 0.90), Geometry.point_rect(yard, 0.71, 0.90), accent, 3.3)
	if civ == "Chinese":
		for roof_part in [left, right]: c.draw_line(Geometry.point_rect(roof_part, 0.08, 0.12), Geometry.point_rect(roof_part, 0.92, 0.12), trim, 1.7)

static func _mining_iso(c: CanvasItem, nw: Vector2, ne: Vector2, sw: Vector2, lift: Vector2, palette: Dictionary, accent: Color, canvas: Transform2D, zoom: float) -> void:
	var floor_lift := lift * 0.16
	var timber: Color = palette["timber"]
	var trim: Color = palette["trim"]
	var roof: Color = palette["roof"]
	_iso_deck(c, nw, ne, sw, floor_lift, Color("9c8d6e"), timber)
	# Rails run from the dark mine receiving bay into the front loading yard.
	for v in [0.48, 0.62, 0.76, 0.90]:
		c.draw_line(Geometry.point(nw, ne, sw, 0.30, v) + floor_lift, Geometry.point(nw, ne, sw, 0.66, v) + floor_lift, timber.darkened(0.12), 2.4)
	for u in [0.34, 0.62]:
		c.draw_line(Geometry.point(nw, ne, sw, u, 0.39) + floor_lift, Geometry.point(nw, ne, sw, u, 0.97) + floor_lift, Color("4a514e"), 2.5)
	var a := Geometry.point(nw, ne, sw, 0.06, 0.05)
	var b := Geometry.point(nw, ne, sw, 0.70, 0.05)
	var d := Geometry.point(nw, ne, sw, 0.06, 0.55)
	var e := Geometry.point(nw, ne, sw, 0.70, 0.55)
	var eave := lift * 0.93
	var ridge := Geometry.up(canvas, zoom, 8.0)
	var portal_left := Geometry.point(nw, ne, sw, 0.25, 0.55)
	var portal_right := Geometry.point(nw, ne, sw, 0.57, 0.55)
	_quad(c, b + eave, e + eave, e + floor_lift, b + floor_lift, palette["wall"].darkened(0.2))
	_quad(c, d + eave, e + eave, e + floor_lift, d + floor_lift, palette["wall"])
	_quad(c, portal_left + eave * 0.78, portal_right + eave * 0.78, portal_right + floor_lift, portal_left + floor_lift, Color("343b34"))
	c.draw_line(portal_left + floor_lift, portal_left + eave * 0.83, timber, 3.4)
	c.draw_line(portal_right + floor_lift, portal_right + eave * 0.83, timber, 3.4)
	for post in [a, b, d, e]: c.draw_line(post + floor_lift, post + eave, timber, 3.1)
	var back_peak := (a + b) * 0.5 + eave + ridge
	var front_peak := (d + e) * 0.5 + eave + ridge
	c.draw_colored_polygon(PackedVector2Array([d + eave, front_peak, e + eave]), palette["wall"].darkened(0.1))
	_quad(c, a + eave, back_peak, front_peak, d + eave, roof.lightened(0.08))
	_quad(c, back_peak, b + eave, e + eave, front_peak, roof)
	c.draw_line(back_peak, front_peak, trim, 2.0)
	c.draw_line(d + eave, e + eave, accent, 2.7)
	# Distinct gray stone and yellow gold heaps dwarf the incidental woodwork.
	_ore_heap_iso(c, Geometry.point(nw, ne, sw, 0.14, 0.80) + floor_lift, Color("7c817d"), canvas, zoom)
	_ore_heap_iso(c, Geometry.point(nw, ne, sw, 0.85, 0.79) + floor_lift, Color("d0a956"), canvas, zoom)
	# Raised ore box, bright cargo, two upright wheels on the mine rails.
	var cart_a := Geometry.point(nw, ne, sw, 0.34, 0.66) + floor_lift
	var cart_b := Geometry.point(nw, ne, sw, 0.62, 0.66) + floor_lift
	var cart_d := Geometry.point(nw, ne, sw, 0.34, 0.85) + floor_lift
	var cart_e := Geometry.point(nw, ne, sw, 0.62, 0.85) + floor_lift
	var cart_up := Geometry.up(canvas, zoom, 7.0)
	_quad(c, cart_d + cart_up, cart_e + cart_up, cart_e, cart_d, Color("7a5436"))
	_quad(c, cart_b + cart_up, cart_e + cart_up, cart_e, cart_b, Color("5b4434"))
	_quad(c, cart_a + cart_up, cart_b + cart_up, cart_e + cart_up, cart_d + cart_up, Color("403e34"))
	for spot in [0.22, 0.52, 0.80]:
		var ore := cart_d.lerp(cart_e, spot) + cart_up + Geometry.up(canvas, zoom, 2.5)
		c.draw_circle(ore, 3.0, Color("e1b861"))
	for axle in [cart_d, cart_e]: _upright_wheel(c, axle, 4.4, canvas, zoom)
	# Compact derrick at the side: mast, arm, rope, visible suspended rock.
	var crane_foot := Geometry.point(nw, ne, sw, 0.88, 0.55) + floor_lift
	var crane_top := crane_foot + Geometry.up(canvas, zoom, 15.0)
	var crane_tip := crane_top + Geometry.screen_delta(canvas, zoom, 9.0, -4.0)
	c.draw_line(crane_foot, crane_top, timber, 3.7)
	c.draw_line(crane_top, crane_tip, timber.lightened(0.1), 3.3)
	c.draw_line(crane_tip, crane_tip + Geometry.screen_delta(canvas, zoom, 0.0, 8.0), trim.darkened(0.3), 1.5)
	var load := crane_tip + Geometry.screen_delta(canvas, zoom, 0.0, 13.0)
	c.draw_colored_polygon(PackedVector2Array([load + Geometry.screen_delta(canvas, zoom, -5.0, 0.0), load + Geometry.screen_delta(canvas, zoom, -1.0, -5.0), load + Geometry.screen_delta(canvas, zoom, 5.0, -2.0), load + Geometry.screen_delta(canvas, zoom, 4.0, 4.0), load + Geometry.screen_delta(canvas, zoom, -2.0, 5.0)]), Color("bc9955"))
	c.draw_line(load + Geometry.screen_delta(canvas, zoom, -3.0, 0.0), load + Geometry.screen_delta(canvas, zoom, 0.0, -3.0), Color("f0d58a"), 1.3)

static func _ore_heap_iso(c: CanvasItem, at: Vector2, color: Color, canvas: Transform2D, zoom: float) -> void:
	c.draw_colored_polygon(PackedVector2Array([at + Geometry.screen_delta(canvas, zoom, -9.0, 2.0), at + Geometry.screen_delta(canvas, zoom, -3.0, -5.0), at + Geometry.screen_delta(canvas, zoom, 1.0, -8.0), at + Geometry.screen_delta(canvas, zoom, 8.0, -2.0), at + Geometry.screen_delta(canvas, zoom, 10.0, 3.0)]), color.darkened(0.23))
	c.draw_colored_polygon(PackedVector2Array([at + Geometry.screen_delta(canvas, zoom, -7.0, 0.0), at + Geometry.screen_delta(canvas, zoom, 1.0, -8.0), at + Geometry.screen_delta(canvas, zoom, 7.0, 1.0)]), color.lightened(0.13))
	for offset in [Vector2(-6, 4), Vector2(0, 5), Vector2(8, 4)]:
		c.draw_circle(at + Geometry.screen_delta(canvas, zoom, offset.x, offset.y), 2.7, color)

static func _iso_deck(c: CanvasItem, nw: Vector2, ne: Vector2, sw: Vector2, lift: Vector2, color: Color, timber: Color) -> void:
	var se := ne + sw - nw
	_quad(c, nw + lift, ne + lift, se + lift, sw + lift, color)
	for v in [0.19, 0.4, 0.61, 0.82]:
		c.draw_line(Geometry.point(nw, ne, sw, 0.06, v) + lift, Geometry.point(nw, ne, sw, 0.94, v) + lift, Color(timber, 0.31), 1.0)

static func _iso_hall(c: CanvasItem, nw: Vector2, ne: Vector2, sw: Vector2, lift: Vector2, palette: Dictionary, accent: Color, canvas: Transform2D, zoom: float, u0: float, v0: float, u1: float, v1: float, height: float, roof_rise: float, door_width: float) -> void:
	var floor_lift := lift * 0.15
	var eave := lift * height
	var a := Geometry.point(nw, ne, sw, u0, v0)
	var b := Geometry.point(nw, ne, sw, u1, v0)
	var d := Geometry.point(nw, ne, sw, u0, v1)
	var e := Geometry.point(nw, ne, sw, u1, v1)
	var wall: Color = palette["wall"]
	var timber: Color = palette["timber"]
	var trim: Color = palette["trim"]
	var roof: Color = palette["roof"]
	var rise := Geometry.up(canvas, zoom, roof_rise)
	var ridge_back := (a + b) * 0.5 + eave + rise
	var ridge_front := (d + e) * 0.5 + eave + rise
	_quad(c, b + eave, e + eave, e + floor_lift, b + floor_lift, wall.darkened(0.23))
	_quad(c, d + eave, e + eave, e + floor_lift, d + floor_lift, wall)
	c.draw_colored_polygon(PackedVector2Array([d + eave, ridge_front, e + eave]), wall.darkened(0.08))
	# The dark tall door goes on the visible front gable, not on the roof.
	var doorway := (d + e) * 0.5
	var half_door := (e - d) * door_width * 0.5
	_quad(c, doorway - half_door + eave * 0.79, doorway + half_door + eave * 0.79, doorway + half_door + floor_lift, doorway - half_door + floor_lift, Color("343832"))
	_quad(c, a + eave, ridge_back, ridge_front, d + eave, roof.lightened(0.10))
	_quad(c, ridge_back, b + eave, e + eave, ridge_front, roof)
	c.draw_line(ridge_back, ridge_front, trim, 2.3)
	c.draw_line(d + eave, e + eave, palette["roof_dark"], 2.0)
	for corner in [d, e]: c.draw_line(corner + floor_lift, corner + eave, timber, 2.7)
	c.draw_line(d + eave * 0.84, e + eave * 0.84, accent, 2.5)

static func _blacksmith_iso(c: CanvasItem, nw: Vector2, ne: Vector2, sw: Vector2, lift: Vector2, palette: Dictionary, accent: Color, civ: String, canvas: Transform2D, zoom: float) -> void:
	var timber: Color = palette["timber"]
	var trim: Color = palette["trim"]
	_iso_deck(c, nw, ne, sw, lift * 0.15, Color("8e8268"), timber)
	# The roof covers the lower flue, leaving a short brick shaft above it.
	_blacksmith_chimney_iso(c, nw, ne, sw, lift, canvas, zoom)
	_iso_hall(c, nw, ne, sw, lift, palette, accent, canvas, zoom, 0.05, 0.04, 0.70, 0.69, 0.93, 14.0, 0.34)
	# Side forge shed on exposed posts, lower than the steep main roof.
	var shed_a := Geometry.point(nw, ne, sw, 0.70, 0.22)
	var shed_b := Geometry.point(nw, ne, sw, 0.95, 0.22)
	var shed_d := Geometry.point(nw, ne, sw, 0.70, 0.74)
	var shed_e := Geometry.point(nw, ne, sw, 0.95, 0.74)
	var shed_high := lift * 0.73
	var shed_low := lift * 0.58
	for post in [shed_b, shed_e]: c.draw_line(post + lift * 0.15, post + shed_low, timber, 3.0)
	_quad(c, shed_a + shed_high, shed_b + shed_low, shed_e + shed_low, shed_d + shed_high, palette["roof_dark"])
	c.draw_line(shed_d + shed_high, shed_e + shed_low, trim, 2.3)
	# The front work area breaks the solid-house silhouette.
	var forge := Geometry.point(nw, ne, sw, 0.26, 0.91) + lift * 0.17
	c.draw_line(forge, forge + lift * 0.42, Color("39362e"), 10.5)
	c.draw_circle(forge + lift * 0.36, 5.4, Color("bc5726"))
	c.draw_circle(forge + lift * 0.39, 3.1, Color("f9c16b"))
	var anvil := Geometry.point(nw, ne, sw, 0.77, 0.87) + lift * 0.16
	c.draw_line(anvil, anvil + lift * 0.26, Color("414949"), 6.3)
	c.draw_line(anvil + lift * 0.26 - (ne - nw) * 0.07, anvil + lift * 0.26 + (ne - nw) * 0.08, Color("676f6c"), 5.0)
	if civ == "Chinese": c.draw_line(shed_a + shed_high, shed_d + shed_high, trim, 2.4)

static func _blacksmith_chimney_iso(c: CanvasItem, nw: Vector2, ne: Vector2, sw: Vector2, lift: Vector2, canvas: Transform2D, zoom: float) -> void:
	var base := lift * 0.93
	var a := Geometry.point(nw, ne, sw, 0.10, 0.39) + base
	var b := Geometry.point(nw, ne, sw, 0.19, 0.39) + base
	var d := Geometry.point(nw, ne, sw, 0.10, 0.48) + base
	var e := Geometry.point(nw, ne, sw, 0.19, 0.48) + base
	var top := Geometry.up(canvas, zoom, 17.0)
	var brick := Color("9b8b79")
	_quad(c, b + top, e + top, e, b, brick.darkened(0.24))
	_quad(c, d + top, e + top, e, d, brick)
	for level in [0.28, 0.54, 0.8]:
		c.draw_line(d + top * level, e + top * level, Color("665f55", 0.7), 0.8)
	c.draw_colored_polygon(PackedVector2Array([a + top, b + top, e + top, d + top]), Color("d1bca0"))
	var center := (a + b + d + e) * 0.25 + top
	c.draw_colored_polygon(PackedVector2Array([
		center.lerp(a + top, 0.58), center.lerp(b + top, 0.58),
		center.lerp(e + top, 0.58), center.lerp(d + top, 0.58),
	]), Color("30302d"))
	c.draw_line(d + top, e + top, Color("e0c9a6"), 1.5)

static func _siege_iso(c: CanvasItem, nw: Vector2, ne: Vector2, sw: Vector2, lift: Vector2, palette: Dictionary, accent: Color, civ: String, canvas: Transform2D, zoom: float) -> void:
	var timber: Color = palette["timber"]
	var trim: Color = palette["trim"]
	_iso_deck(c, nw, ne, sw, lift * 0.15, Color("95896b"), timber)
	# Two separate rear halls leave the entire front half open for assembly.
	_iso_hall(c, nw, ne, sw, lift, palette, accent, canvas, zoom, 0.05, 0.06, 0.44, 0.52, 0.94, 13.0, 0.50)
	_iso_hall(c, nw, ne, sw, lift, palette, accent, canvas, zoom, 0.56, 0.06, 0.95, 0.52, 0.94, 13.0, 0.50)
	var yard_left := Geometry.point(nw, ne, sw, 0.08, 0.93) + lift * 0.18
	var yard_right := Geometry.point(nw, ne, sw, 0.92, 0.93) + lift * 0.18
	for u in [0.08, 0.92]:
		var front_post := Geometry.point(nw, ne, sw, u, 0.93) + lift * 0.18
		var back_post := Geometry.point(nw, ne, sw, u, 0.55) + lift * 0.18
		c.draw_line(front_post, front_post + lift * 0.46, timber, 2.8)
		c.draw_line(back_post, back_post + lift * 0.46, timber, 2.8)
		c.draw_line(front_post + lift * 0.37, back_post + lift * 0.37, timber, 2.4)
	c.draw_line(yard_left, yard_right, accent, 2.7)
	# A half-built catapult fills the yard: paired timber rails, one axle,
	# two upright spoked wheels, triangular pivot and a raised throwing arm.
	var floor_lift := lift * 0.18
	for u in [0.36, 0.64]:
		var rear := Geometry.point(nw, ne, sw, u, 0.56) + floor_lift
		var front := Geometry.point(nw, ne, sw, u, 0.90) + floor_lift
		c.draw_line(rear, front, Color("65462f"), 5.2)
		c.draw_line(rear + Geometry.up(canvas, zoom, 2.0), front + Geometry.up(canvas, zoom, 2.0), timber.lightened(0.28), 2.3)
	for v in [0.63, 0.82]:
		c.draw_line(Geometry.point(nw, ne, sw, 0.32, v) + floor_lift, Geometry.point(nw, ne, sw, 0.68, v) + floor_lift, timber, 4.1)
	var axle_left := Geometry.point(nw, ne, sw, 0.26, 0.79) + floor_lift
	var axle_right := Geometry.point(nw, ne, sw, 0.74, 0.79) + floor_lift
	c.draw_line(axle_left, axle_right, Color("64472e"), 4.6)
	_upright_wheel(c, axle_left, 6.2, canvas, zoom)
	_upright_wheel(c, axle_right, 6.2, canvas, zoom)
	var pivot_base := Geometry.point(nw, ne, sw, 0.50, 0.70) + floor_lift
	var pivot_top := pivot_base + Geometry.up(canvas, zoom, 10.0)
	c.draw_line(Geometry.point(nw, ne, sw, 0.37, 0.77) + floor_lift, pivot_top, timber, 3.4)
	c.draw_line(Geometry.point(nw, ne, sw, 0.63, 0.77) + floor_lift, pivot_top, timber, 3.4)
	c.draw_circle(pivot_top, 3.1, trim)
	var arm_tip := pivot_top + Geometry.screen_delta(canvas, zoom, 18.0, -12.0)
	c.draw_line(pivot_top, arm_tip, Color("49372b"), 10.0)
	c.draw_line(pivot_top, arm_tip, Color("c59b62"), 5.8)
	c.draw_line(pivot_top + Geometry.screen_delta(canvas, zoom, 0.0, 2.5), arm_tip + Geometry.screen_delta(canvas, zoom, 0.0, 2.5), timber, 1.8)
	var counterweight := pivot_top + Geometry.screen_delta(canvas, zoom, -4.0, 8.0)
	c.draw_line(pivot_top, counterweight, Color("4a3d31"), 2.2)
	c.draw_colored_polygon(PackedVector2Array([counterweight + Geometry.screen_delta(canvas, zoom, -4.0, 0.0), counterweight + Geometry.screen_delta(canvas, zoom, 4.0, 0.0), counterweight + Geometry.screen_delta(canvas, zoom, 4.0, 7.0), counterweight + Geometry.screen_delta(canvas, zoom, -4.0, 7.0)]), Color("6c5940"))
	var spoon := arm_tip + Geometry.screen_delta(canvas, zoom, 0.0, -1.5)
	c.draw_colored_polygon(PackedVector2Array([spoon + Geometry.screen_delta(canvas, zoom, -6.0, 0.0), spoon + Geometry.screen_delta(canvas, zoom, -4.0, 4.0), spoon + Geometry.screen_delta(canvas, zoom, 5.0, 4.0), spoon + Geometry.screen_delta(canvas, zoom, 7.0, -1.0), spoon + Geometry.screen_delta(canvas, zoom, 4.0, -3.0)]), Color("9b7545"))
	c.draw_colored_polygon(PackedVector2Array([spoon + Geometry.screen_delta(canvas, zoom, -4.0, -2.0), spoon + Geometry.screen_delta(canvas, zoom, -1.0, -5.0), spoon + Geometry.screen_delta(canvas, zoom, 4.0, -4.0), spoon + Geometry.screen_delta(canvas, zoom, 6.0, 0.0), spoon + Geometry.screen_delta(canvas, zoom, 1.0, 2.0)]), Color("c5c4b7"))
	c.draw_line(spoon + Geometry.screen_delta(canvas, zoom, -2.0, -3.0), spoon + Geometry.screen_delta(canvas, zoom, 1.0, -4.0), Color("f2eee0"), 1.4)
	if civ == "Chinese": c.draw_line(pivot_base, pivot_top, trim, 1.7)

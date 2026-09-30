extends RefCounted

const DockGeometry = preload("res://scripts/entities/visuals/dock_geometry.gd")
const Geometry = preload("res://scripts/entities/visuals/building_geometry.gd")
const FilledPolygon = preload("res://scripts/entities/visuals/filled_polygon.gd")
static var geometry_cache: Dictionary = {}

# One cached mesh supplies the map, memory, selection and portrait projections.
static func geometry(dimensions: Vector2, palette: Dictionary, civ: String, accent: Color):
	var key := str([dimensions, palette, civ, accent])
	if not geometry_cache.has(key):
		if geometry_cache.size() >= 16: geometry_cache.clear()
		geometry_cache[key] = DockGeometry.new(dimensions, palette, civ, accent)
	return geometry_cache[key]

static func draw_iso(c: CanvasItem, nw: Vector2, ne: Vector2, _se: Vector2, sw: Vector2, _lift: Vector2, palette: Dictionary, accent: Color, civ: String, canvas: Transform2D, zoom: float) -> void:
	var dimensions := Vector2((ne - nw).length(), (sw - nw).length())
	for polygon in geometry(dimensions, palette, civ, accent).projected_faces(canvas, zoom, Vector2.ZERO):
		FilledPolygon.draw(c, polygon["points"], polygon["color"])

static func selection_hull(state, canvas: Transform2D) -> PackedVector2Array:
	var palette := {"wall": Color("c9bd9e"), "trim": Color("ddcca6"), "roof": Color("58666b"), "roof_dark": Color("38464c"), "timber": Color("795938")}
	var model = geometry(state.dimensions, palette, state.civilization, state.player_color)
	var points := PackedVector2Array()
	var terrain := RtsIsoProjection.world_delta(canvas, Vector2(0, -state.foundation_height * state.zoom))
	for polygon in model.projected_faces(canvas, state.zoom, terrain):
		points.append_array(polygon["points"])
	return Geometry2D.convex_hull(points)

static func draw_topdown(c: CanvasItem, bounds: Rect2, palette: Dictionary, accent: Color, civ: String) -> void:
	var roof := Color("58666b") if civ == "English" else Color("59768a") if civ == "French" else Color("496763")
	# Separate bridge fingers leave the actual map terrain visible in the berth.
	for form in [Rect2(0.025, 0.045, 0.95, 0.62), Rect2(0.09, 0.64, 0.20, 0.48), Rect2(0.71, 0.64, 0.22, 0.48)]:
		var deck := Geometry.rect(bounds, form.position.x, form.position.y, form.size.x, form.size.y)
		c.draw_rect(Rect2(deck.position + Vector2(1.3, 2), deck.size), Color("24322b", 0.24))
		c.draw_rect(deck, Color("8a6b46"))
		c.draw_rect(deck.grow(-0.5), Color("a08257"))
		var rows := maxi(2, ceili(deck.size.y / 4.0))
		for row in rows:
			var y := deck.position.y + row * deck.size.y / rows
			c.draw_line(Vector2(deck.position.x + 0.7, y), Vector2(deck.end.x - 0.7, y), Color("624b32", 0.52), 0.65)
		c.draw_line(Vector2(deck.position.x, deck.end.y), deck.end, Color("695137"), 1.3)
	var ramp := Geometry.rect(bounds, 0.36, -0.025, 0.23, 0.13)
	c.draw_rect(ramp, Color("a08257"))
	for t in [0.28, 0.52, 0.77]: c.draw_line(ramp.position + Vector2(0, ramp.size.y * t), ramp.position + Vector2(ramp.size.x, ramp.size.y * t), Color("725638"), 0.7)
	_roof_top(c, bounds, Rect2(0.045, 0.075, 0.58, 0.42), roof, palette["trim"], civ)
	_roof_top(c, bounds, Rect2(0.665, 0.125, 0.27, 0.28), roof, palette["trim"], civ)
	# Loading mouth below the eave, with the open shutters on either side.
	c.draw_rect(Geometry.rect(bounds, 0.22, 0.485, 0.23, 0.05), Color("30392f"))
	for u in [0.185, 0.46]: c.draw_rect(Geometry.rect(bounds, u, 0.48, 0.025, 0.10), Color("735336"))
	for at in [Vector2(0.105, 0.55), Vector2(0.185, 0.585), Vector2(0.29, 0.53)]:
		var box := Rect2(Geometry.point_rect(bounds, at.x, at.y), Vector2(4, 4))
		c.draw_rect(box, Color("a88250"))
		c.draw_rect(box, Color("695031"), false, 0.8)
		c.draw_line(box.position, box.end, Color("695031"), 0.6)
	for at in [Vector2(0.5, 0.55), Vector2(0.57, 0.59)]:
		var center := Geometry.point_rect(bounds, at.x, at.y)
		c.draw_circle(center, 2.1, Color("62513b"))
		c.draw_circle(center + Vector2(-0.3, -0.4), 1.5, Color("9d7b50"))
	for at in [Vector2(0.43, 0.55), Vector2(0.45, 0.61)]:
		c.draw_circle(Geometry.point_rect(bounds, at.x, at.y), 2.0, Color("bca97d"))
	for at in [Vector2(0.045, 0.66), Vector2(0.33, 0.66), Vector2(0.66, 0.66), Vector2(0.97, 0.66), Vector2(0.115, 1.08), Vector2(0.265, 1.08), Vector2(0.735, 1.08), Vector2(0.90, 1.08)]:
		var center := Geometry.point_rect(bounds, at.x, at.y)
		c.draw_rect(Rect2(center - Vector2(1.5, 1.1), Vector2(3, 2.2)), Color("685036"))
		c.draw_line(center - Vector2(1.7, 0.5), center + Vector2(1.7, -0.5), Color("b09669"), 0.8)
	for span in [[Vector2(0.33, 0.67), Vector2(0.66, 0.67)], [Vector2(0.11, 0.72), Vector2(0.11, 1.07)], [Vector2(0.90, 0.72), Vector2(0.90, 1.07)]]:
		c.draw_line(Geometry.point_rect(bounds, span[0].x, span[0].y), Geometry.point_rect(bounds, span[1].x, span[1].y), Color("c7b285"), 0.8)
	for at in [Vector2(0.24, 0.84), Vector2(0.79, 1.0)]: c.draw_arc(Geometry.point_rect(bounds, at.x, at.y), 1.7, 0, TAU, 12, Color("ccb587"), 0.8)
	var base := Geometry.point_rect(bounds, 0.80, 0.62)
	var tip := Geometry.point_rect(bounds, 1.00, 0.69)
	c.draw_line(base + Vector2(1.2, 1.3), tip + Vector2(1.2, 1.3), Color("28342c", 0.32), 2.8)
	c.draw_line(base, tip, Color("715134"), 2.1)
	c.draw_circle(base, 2.5, Color("a18154"))
	c.draw_rect(Geometry.rect(bounds, 0.32, 0.495, 0.055, 0.025), accent.darkened(0.10))

static func _roof_top(c: CanvasItem, bounds: Rect2, form: Rect2, roof: Color, trim: Color, civ: String) -> void:
	var r := Geometry.rect(bounds, form.position.x, form.position.y, form.size.x, form.size.y)
	c.draw_rect(Rect2(r.position + Vector2(1.4, 2.0), r.size + Vector2(0.8, 0.8)), Color("27342c", 0.28))
	c.draw_rect(r.grow(0.6), roof.darkened(0.32))
	var a := r.position
	var b := Vector2(r.end.x, r.position.y)
	var e := Vector2(r.position.x, r.end.y)
	var d := r.end
	var inset := 0.0 if civ == "English" else 0.18
	var left := Vector2(lerpf(a.x, b.x, inset), r.get_center().y)
	var right := Vector2(lerpf(b.x, a.x, inset), r.get_center().y)
	FilledPolygon.draw(c, PackedVector2Array([a, b, right, left]), roof.lightened(0.17))
	FilledPolygon.draw(c, PackedVector2Array([left, right, d, e]), roof.darkened(0.07))
	if inset > 0.0:
		FilledPolygon.draw(c, PackedVector2Array([a, left, e]), roof.lightened(0.04))
		FilledPolygon.draw(c, PackedVector2Array([b, d, right]), roof.darkened(0.20))
	for t in [0.22, 0.43, 0.64, 0.85]:
		c.draw_line(e.lerp(d, t), left.lerp(right, t), roof.lightened(0.25), 0.55)
	c.draw_line(left, right, trim.darkened(0.19), 0.85)
	if civ == "Chinese":
		for corner in [a, b, d, e]: c.draw_circle(corner, 0.9, trim)

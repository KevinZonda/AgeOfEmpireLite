extends "res://scripts/entities/visuals/landmark_visual.gd"

const MilitaryTraining = preload("res://scripts/entities/visuals/military_training_geometry.gd")
const StableCamp = preload("res://scripts/entities/visuals/stable_camp_geometry.gd")

# Reuse the landmark BSP for intersecting roofs, beams and workshop furniture.
# Cache canonical projections too, so portraits share the exact map geometry.
var flat_faces: Array[Dictionary] = []
var portrait_faces: Array[Dictionary] = []
var portrait_bounds := Rect2()
var civilization := "English"
var accent := Color.WHITE
var variant := 0

static func handles(kind: String) -> bool:
	return kind in ["house", "blacksmith", "market", "barracks", "archery_range", "stable", "scout_camp"]

func _init(kind: String, size: Vector2, civ: String, player: Color, variation: int, colors: Dictionary) -> void:
	dimensions = size
	civilization = civ
	accent = player
	variant = variation
	palette = colors.duplicate()
	if kind == "market" and civ == "English": palette["roof"] = Color("59656a")
	base_z = 2.0
	box(Vector2.ZERO, dimensions * 0.96, 0, 2, Color("9c9680"))
	match kind:
		"house": _house()
		"blacksmith": _smith()
		"market": _market()
		"barracks", "archery_range": MilitaryTraining.populate(self, kind)
		"stable", "scout_camp": StableCamp.populate(self, kind)
	prepare()
	_cache_projections()

func p(u: float, v: float, z: float) -> Vector3:
	var ground := (Vector2(u, v) - Vector2.ONE * 0.5) * dimensions
	return Vector3(ground.x, ground.y, z)

func cube(u: float, v: float, w: float, d: float, z: float, h: float, color: Color) -> void:
	box((Vector2(u + w * 0.5, v + d * 0.5) - Vector2.ONE * 0.5) * dimensions, Vector2(w, d) * dimensions, z, h, color)

func beam(a: Vector3, b: Vector3, width: float, color: Color) -> void:
	# Facade ribbons sit just in front of the wall, and take part in BSP order.
	var normal := Vector3(-(b.z - a.z), 0, b.x - a.x).normalized() * width * 0.5
	face([a - normal, b - normal, b + normal, a + normal], color)

func window(u: float, v: float, z: float, w: float, h: float, side := false) -> void:
	var origin := p(u, v, z)
	var horizontal := Vector3(0, w, 0) if side else Vector3(w, 0, 0)
	var toward := Vector3(0.04, 0, 0) if side else Vector3(0, 0.04, 0)
	origin += toward
	face([origin, origin + horizontal, origin + horizontal + Vector3(0, 0, h), origin + Vector3(0, 0, h)], palette["trim"])
	var inset := horizontal.normalized() * 0.8 + Vector3(0, 0, 0.8)
	var a := origin + inset + toward
	var b := origin + horizontal - horizontal.normalized() * 0.8 + Vector3(0, 0, h - 0.8) + toward
	face([a, Vector3(b.x, b.y, a.z), b, Vector3(a.x, a.y, b.z)], Color("3a5555"))
	var center := origin + horizontal * 0.5 + toward * 3
	face([center - horizontal.normalized() * 0.35, center + horizontal.normalized() * 0.35, center + horizontal.normalized() * 0.35 + Vector3(0, 0, h), center - horizontal.normalized() * 0.35 + Vector3(0, 0, h)], palette["timber"])

func door(u: float, v: float, w: float, h: float) -> void:
	cube(u - 0.015, v, w + 0.03, 0.025, base_z, h + 1, palette["timber"])
	face([p(u, v + 0.026, base_z), p(u + w, v + 0.026, base_z), p(u + w, v + 0.026, h + base_z), p(u, v + 0.026, h + base_z)], Color("514333"))
	for offset in [0.25, 0.5, 0.75]:
		beam(p(u + w * offset, v + 0.028, base_z + 1), p(u + w * offset, v + 0.028, base_z + h - 1), 0.45, Color("8c704e"))
	cube(u + w * 0.75, v + 0.029, 0.018, 0.018, base_z + h * 0.45, 1.0, Color("d3b46c"))

func hall(u: float, v: float, w: float, d: float, h: float, rise: float) -> void:
	cube(u, v, w, d, base_z, h, palette["wall"])
	_roof(u - 0.035, v - 0.025, w + 0.07, d + 0.05, base_z + h, rise)
	for x in [u, u + w - 0.025]:
		cube(x, v + d, 0.025, 0.025, base_z, h, palette["timber"])
	cube(u, v + d, w, 0.02, base_z + h - 2, 1.6, palette["timber"])
	cube(u, v + d, w, 0.02, base_z + 1, 1.3, palette["timber"])

func _roof(u: float, v: float, w: float, d: float, z: float, rise: float) -> void:
	var a := p(u, v, z)
	var b := p(u + w, v, z)
	var c := p(u + w, v + d, z)
	var e := p(u, v + d, z)
	var rear := p(u + w * 0.5, v, z + rise)
	var front := p(u + w * 0.5, v + d, z + rise)
	var roof: Color = palette["roof"]
	var edge: Color = palette["roof_dark"]
	# The eaves are actual shallow prisms, not a drawn black outline.
	box(Vector2((a.x + c.x) * 0.5, (a.y + c.y) * 0.5), Vector2(c.x - a.x, c.y - a.y), z - 1.2, 1.2, edge)
	if civilization == "French":
		rear.y += d * dimensions.y * 0.20
		front.y -= d * dimensions.y * 0.20
		face([a, b, rear], roof.lightened(0.05))
		face([e, front, c], roof.darkened(0.09))
	else:
		face([a, b, rear], palette["wall"].darkened(0.18))
		face([e, c, front], palette["wall"])
	if civilization == "Chinese":
		# Broad curved slopes with lifted outer edges and a long tiled ridge.
		var left_rear := a.lerp(rear, 0.26) - Vector3(0, 0, 2)
		var left_front := e.lerp(front, 0.26) - Vector3(0, 0, 2)
		var right_rear := b.lerp(rear, 0.26) - Vector3(0, 0, 2)
		var right_front := c.lerp(front, 0.26) - Vector3(0, 0, 2)
		face([a + Vector3(0, 0, 2), left_rear, left_front, e + Vector3(0, 0, 2)], roof.lightened(0.13))
		face([left_rear, rear, front, left_front], roof.lightened(0.08))
		face([rear, right_rear, right_front, front], roof)
		face([right_rear, b + Vector3(0, 0, 2), c + Vector3(0, 0, 2), right_front], roof.darkened(0.12))
		for tip in [rear, front]: box(Vector2(tip.x, tip.y), Vector2(2.5, 4), tip.z, 2, palette["trim"])
	else:
		face([a, rear, front, e], roof.lightened(0.14))
		face([rear, b, c, front], roof)
	# The far slope is almost edge-on in the fixed camera. Its tile ribbons
	# collapse to raster speckles after BSP splitting; detail the broad slope.
	for t in [0.28, 0.56, 0.82]:
		var right := b.lerp(c, t)
		var ridge := rear.lerp(front, t)
		if civilization != "Chinese":
			face([ridge + Vector3(0, 0.15, 0.30), right + Vector3(0, 0.15, 0.30), right + Vector3(0, -0.50, 0.30), ridge + Vector3(0, -0.50, 0.30)], edge.lightened(0.1))
	box(Vector2(rear.x, (rear.y + front.y) * 0.5), Vector2(1.3, absf(front.y - rear.y) + 1), rear.z, 0.6, palette["trim"])

func _house() -> void:
	var timber: Color = palette["timber"]
	var h := 21.0 + variant
	var width := 0.72 if variant == 2 else 0.78
	var depth := 0.60 if civilization == "Chinese" else 0.71
	hall(0.10, 0.09, width, depth, h, 9 if civilization == "Chinese" else 12)
	door(0.40, 0.09 + depth, 0.16, 15)
	cube(0.39, 0.09 + depth + 0.05, 0.18, 0.018, 18, 1.6, accent)
	cube(0.36, 0.12 + depth, 0.24, 0.065, 1, 1.8, Color("b4a991"))
	window(0.19, 0.09 + depth + 0.03, 11, 5, 6)
	window(0.67, 0.09 + depth + 0.03, 11, 5, 6)
	window(0.10 + width + 0.001, 0.28, 11, 6, 6, true)
	window(0.10 + width + 0.001, 0.56, 11, 6, 6, true)
	if civilization == "English":
		for u in [0.34, 0.62]: cube(u, 0.09 + depth + 0.025, 0.025, 0.02, base_z, h, timber)
		beam(p(0.12, 0.09 + depth + 0.06, h - 1), p(0.31, 0.09 + depth + 0.06, 12), 1.3, timber)
		beam(p(0.68, 0.09 + depth + 0.06, 12), p(0.87, 0.09 + depth + 0.06, h - 1), 1.3, timber)
	elif civilization == "French":
		for z in [6.0, 12.0, 18.0]:
			cube(0.10 + width, 0.10, 0.02, depth - 0.02, z, 0.45, Color("aaa18d"))
		cube(0.10, 0.09 + depth + 0.02, width, 0.015, 7, 0.45, Color("aaa18d"))
	else:
		# A low courtyard wall and red posts change the silhouette, not just tint.
		for u in [0.07, 0.88]: cube(u, 0.70, 0.04, 0.22, 2, 5, palette["wall"].darkened(0.12))
		for u in [0.07, 0.58]: cube(u, 0.91, 0.34, 0.035, 2, 5, palette["wall"])
		for u in [0.13, 0.85]: cube(u, 0.09 + depth, 0.03, 0.045, 2, h, timber)
	if civilization != "Chinese":
		var u := 0.19 if variant != 1 else 0.66
		cube(u, 0.23, 0.10, 0.11, 22, 16, Color("9a8973"))
		cube(u - 0.015, 0.215, 0.13, 0.14, 38, 1.7, Color("bdad95"))
		cube(u + 0.015, 0.25, 0.07, 0.06, 39.7, 0.15, Color("3c3a32"))
	if variant == 1:
		cube(0.31, 0.81, 0.35, 0.13, 2, 1.8, Color("a59375"))
		cube(0.32, 0.92, 0.025, 0.025, 2, 13, timber)
		cube(0.63, 0.92, 0.025, 0.025, 2, 13, timber)
		face([p(0.30, 0.09 + depth, 18), p(0.67, 0.09 + depth, 18), p(0.67, 0.96, 15), p(0.30, 0.96, 15)], palette["roof"])
	elif variant == 2:
		cube(0.78, 0.62, 0.16, 0.27, 2, 10, palette["wall"].darkened(0.08))
		face([p(0.76, 0.59, 15), p(0.95, 0.59, 12), p(0.95, 0.92, 12), p(0.76, 0.92, 15)], palette["roof"])

func _smith() -> void:
	var timber: Color = palette["timber"]
	hall(0.07, 0.07, 0.58, 0.56, 25, 13)
	door(0.26, 0.64, 0.17, 18)
	window(0.65, 0.22, 13, 6, 7, true)
	# Hollow-looking chimney cap and brick courses above the roof.
	cube(0.14, 0.22, 0.10, 0.10, 22, 24, Color("8f7965"))
	cube(0.125, 0.205, 0.13, 0.13, 46, 1.8, Color("bfaa8b"))
	cube(0.15, 0.23, 0.08, 0.08, 47.8, 0.2, Color("34342f"))
	for z in [38.0, 41.0, 44.0]: cube(0.14, 0.321, 0.10, 0.004, z, 0.5, Color("c4b094"))
	# Covered open bay with braces and a lower tiled lean-to roof.
	for v in [0.22, 0.69]: cube(0.93, v, 0.025, 0.025, 2, 17, timber)
	face([p(0.65, 0.20, 24), p(0.97, 0.20, 19), p(0.97, 0.74, 19), p(0.65, 0.74, 24)], palette["roof_dark"])
	# Masonry forge: a front opening shows the fire, rather than a glowing drum.
	cube(0.09, 0.75, 0.25, 0.20, 2, 13, Color("827463"))
	cube(0.075, 0.735, 0.28, 0.23, 15, 1.5, Color("aa9780"))
	face([p(0.13, 0.951, 4), p(0.30, 0.951, 4), p(0.30, 0.951, 12), p(0.13, 0.951, 12)], Color("34332d"))
	face([p(0.15, 0.952, 5), p(0.28, 0.952, 5), p(0.27, 0.952, 8), p(0.24, 0.952, 7), p(0.21, 0.952, 10), p(0.18, 0.952, 7)], Color("d57332"))
	face([p(0.18, 0.953, 5), p(0.25, 0.953, 5), p(0.22, 0.953, 8)], Color("ffc66d"))
	# Stump-mounted anvil with a narrow waist and a projecting horn.
	cube(0.68, 0.86, 0.15, 0.11, 2, 5, Color("8b603d"))
	cube(0.72, 0.88, 0.06, 0.07, 7, 4, Color("4d5958"))
	var profile := [Vector2(-6, 11), Vector2(4, 11), Vector2(10, 13), Vector2(6, 15), Vector2(-7, 15)]
	var front: Array = []
	var back: Array = []
	for vertex in profile:
		var at := p(0.755, 0.965, vertex.y)
		front.append(at + Vector3(vertex.x, 0, 0))
		back.append(at + Vector3(vertex.x, -4, 0))
	face(front, Color("687574"))
	for i in profile.size(): face([front[i], front[(i + 1) % profile.size()], back[(i + 1) % profile.size()], back[i]], Color("909b95") if i == 2 else Color("465150"))
	# Rack: three long tools hang on the front wall, beside the doorway.
	cube(0.45, 0.642, 0.17, 0.024, 20, 1.5, timber)
	for u in [0.48, 0.54, 0.60]:
		cube(u, 0.666, 0.013, 0.017, 12, 8, Color("aa895d"))
		cube(u - 0.018, 0.666, 0.05, 0.02, 18, 2, Color("626c67"))
	cube(0.43, 0.82, 0.15, 0.10, 2, 4, Color("3d4038"))
	cube(0.86, 0.80, 0.10, 0.16, 2, 5, timber)
	cube(0.875, 0.815, 0.07, 0.13, 7.1, 0.15, Color("557974"))
	cube(0.08, 0.641, 0.15, 0.025, 23, 1.4, accent)

func _market() -> void:
	hall(0.07, 0.07, 0.51, 0.34, 27, 11)
	door(0.25, 0.42, 0.13, 17)
	for u in [0.13, 0.43]: window(u, 0.425, 19, 5, 6)
	for u in [0.19, 0.41]: cube(u, 0.425, 0.023, 0.025, 2, 25, palette["timber"])
	cube(0.07, 0.427, 0.51, 0.025, 16, 1.4, palette["timber"])
	_stall(0.07, 0.58, 0.36, 0.25, Color("b97952"))
	_stall(0.63, 0.54, 0.30, 0.25, Color("70855c"))
	cube(0.79, 0.17, 0.13, 0.13, 2, 3, palette["wall"].darkened(0.1))
	cube(0.835, 0.215, 0.035, 0.035, 5, 18, palette["trim"])
	cube(0.82, 0.20, 0.065, 0.065, 23, 1.5, palette["wall"])
	_crate(0.71, 0.85, 0.12, 0.11, 2, 8)
	_crate(0.72, 0.86, 0.09, 0.08, 10, 5)
	_sack(0.50, 0.86, 4, Color("c4b383"))
	_sack(0.58, 0.91, 3, Color("a7966e"))

func _stall(u: float, v: float, w: float, d: float, goods: Color) -> void:
	var timber: Color = palette["timber"]
	for x in [u, u + w - 0.025]:
		for y in [v, v + d]: cube(x, y, 0.025, 0.025, 2, 15 if y == v else 11, timber)
	cube(u + 0.02, v + d - 0.04, w - 0.02, 0.11, 2, 6, Color("a57e50"))
	for i in 3:
		var x := u + 0.03 + (w - 0.06) * i / 3.0
		cube(x, v + d - 0.01, (w - 0.07) / 3, 0.06, 8.1, 1.3, goods.lightened(i * 0.10))
	for i in 5:
		var x := u + w * i / 5.0
		var next := x + w / 5.0
		var tint: Color = accent.lerp(Color("a8ae91"), 0.35) if i % 2 == 0 else palette["trim"]
		face([p(x - 0.01, v - 0.02, 18), p(next, v - 0.02, 18), p(next, v + d + 0.03, 13), p(x - 0.01, v + d + 0.03, 13)], tint)
		face([p(x - 0.01, v + d + 0.03, 13), p(next, v + d + 0.03, 13), p(next - 0.012, v + d + 0.03, 10.5), p(x, v + d + 0.03, 10.5)], tint.darkened(0.13))

func _crate(u: float, v: float, w: float, d: float, z: float, h: float) -> void:
	cube(u, v, w, d, z, h, Color("b18e5b"))
	beam(p(u + 0.01, v + d + 0.01, z + 1), p(u + w - 0.01, v + d + 0.01, z + h - 1), 0.8, palette["timber"])
	beam(p(u + 0.01, v + d + 0.02, z + h - 1), p(u + w - 0.01, v + d + 0.02, z + 1), 0.8, palette["timber"])

func _sack(u: float, v: float, radius: float, color: Color) -> void:
	var center := p(u, v, 2)
	var top: Array = []
	for i in 8:
		var a := i * TAU / 8.0
		var b := (i + 1) * TAU / 8.0
		var first := center + Vector3(cos(a), sin(a), 0) * radius
		var second := center + Vector3(cos(b), sin(b), 0) * radius
		var upper := center + Vector3(cos(a) * radius * 0.6, sin(a) * radius * 0.6, radius * 1.4)
		var upper_next := center + Vector3(cos(b) * radius * 0.6, sin(b) * radius * 0.6, radius * 1.4)
		if cos((a + b) * 0.5) + sin((a + b) * 0.5) > 0: face([first, second, upper_next, upper], color.darkened(0.10 * i / 8))
		top.append(upper)
	face(top, color.lightened(0.10))
	cube(u - 0.015, v - 0.015, 0.03, 0.03, 2 + radius * 1.4, 1.3, palette["timber"])

func _cache_projections() -> void:
	var by_height := faces.duplicate()
	by_height.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _average_z(a) < _average_z(b))
	for polygon in by_height:
		var points := PackedVector2Array()
		for at in polygon["points"]: points.append(Vector2(at.x, at.y))
		if not Geometry2D.triangulate_polygon(points).is_empty(): flat_faces.append({"points": points, "color": polygon["color"]})
	var first := true
	for polygon in ordered_faces:
		var points := PackedVector2Array()
		for at in polygon["points"]:
			var projected := Vector2((at.x - at.y) * 0.70710678, (at.x + at.y) * 0.35355339 - at.z)
			points.append(projected)
			portrait_bounds = Rect2(projected, Vector2.ZERO) if first else portrait_bounds.expand(projected)
			first = false
		portrait_faces.append({"points": points, "color": polygon["color"]})

func _average_z(polygon: Dictionary) -> float:
	var z := 0.0
	for point in polygon["points"]: z += point.z
	return z / polygon["points"].size()

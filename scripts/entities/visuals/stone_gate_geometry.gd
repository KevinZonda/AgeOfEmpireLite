extends "res://scripts/entities/visuals/landmark_visual.gd"

# The gatehouse, arch tunnel and wall returns share one depth-sorted mesh.
# No face is drawn as a screen-space patch over a neighboring pier.
static var cache: Dictionary = {}
var flat_faces: Array[Dictionary] = []

static func geometry(size: Vector2, colors: Dictionary, accent: Color, vertical: bool):
	var key := str([size, colors, accent, vertical])
	if not cache.has(key):
		if cache.size() >= 32: cache.clear()
		cache[key] = new(size, colors, accent, vertical)
	return cache[key]

func _init(size: Vector2, colors: Dictionary, accent: Color, vertical: bool) -> void:
	dimensions = Vector2(size.y, size.x) if vertical else size
	palette = colors.duplicate()
	_populate_gate(accent)
	if vertical:
		for polygon in faces:
			var points: PackedVector3Array = polygon["points"]
			for i in points.size(): points[i] = Vector3(points[i].y, points[i].x, points[i].z)
	dimensions = size
	prepare()
	var surfaces := faces.duplicate()
	surfaces.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _height(a) < _height(b))
	for polygon in surfaces:
		var points := PackedVector2Array()
		for p in polygon["points"]: points.append(Vector2(p.x, p.y))
		if not Geometry2D.triangulate_polygon(points).is_empty(): flat_faces.append({"points": points, "color": polygon["color"]})

func _height(polygon: Dictionary) -> float:
	var result := 0.0
	for p in polygon["points"]: result += p.z
	return result / polygon["points"].size()

func _populate_gate(accent: Color) -> void:
	var length := dimensions.x
	var depth := dimensions.y
	var stone: Color = palette["wall"]
	var trim: Color = palette["trim"]
	var tower_width := length * 0.18
	var tower_depth := depth * 0.65
	var opening := length * 0.30
	var outer := opening * 0.5 + tower_width
	var return_length := length * 0.5 - outer
	# Full-volume returns meet the piers at exactly the same joint.
	for side in [-1.0, 1.0]:
		var x: float = side * (outer + return_length * 0.5)
		box(Vector2(x, 0), Vector2(return_length, depth * 0.37), 0, 11, stone)
		box(Vector2(x, 0), Vector2(return_length, depth * 0.43), 0, 1.7, stone.darkened(0.12))
		for t in [0.25, 0.75]:
			box(Vector2(x + (t - 0.5) * return_length, depth * 0.13), Vector2(3.0, 2.3), 11, 3.0, trim)
		_tower(side * (opening * 0.5 + tower_width * 0.5), tower_width, tower_depth, accent)
	box(Vector2.ZERO, Vector2(opening, depth * 0.95), 0, 0.5, Color("a49c7c"))
	var front := tower_depth * 0.5
	var back := -front
	var half := opening * 0.5
	var spring := 14.5
	var arc_rise := 7.0
	var crown := 25.5
	# Each arch strip is convex; the soffit closes the tunnel in depth.
	for i in 8:
		var t0 := PI * float(i) / 8.0
		var t1 := PI * float(i + 1) / 8.0
		var a := Vector2(cos(t0) * half, spring + sin(t0) * arc_rise)
		var b := Vector2(cos(t1) * half, spring + sin(t1) * arc_rise)
		face([Vector3(a.x, front, a.y), Vector3(b.x, front, b.y), Vector3(b.x, front, crown), Vector3(a.x, front, crown)], stone)
		face([Vector3(a.x, back, a.y), Vector3(b.x, back, b.y), Vector3(b.x, back, crown), Vector3(a.x, back, crown)], stone.darkened(0.18))
		face([Vector3(a.x, front, a.y), Vector3(b.x, front, b.y), Vector3(b.x, back, b.y), Vector3(a.x, back, a.y)], stone.darkened(0.36))
		var outer_a := Vector2(cos(t0) * (half + 1.3), spring + sin(t0) * (arc_rise + 1.3))
		var outer_b := Vector2(cos(t1) * (half + 1.3), spring + sin(t1) * (arc_rise + 1.3))
		face([Vector3(a.x, front + 0.045, a.y), Vector3(b.x, front + 0.045, b.y), Vector3(outer_b.x, front + 0.045, outer_b.y), Vector3(outer_a.x, front + 0.045, outer_a.y)], trim.darkened(0.10 if i % 2 else 0.03))
	# Vertical reveal stones frame the jambs all the way to the paving.
	for side in [-1.0, 1.0]:
		for row in 5:
			var x0: float = side * half
			var x1: float = side * (half + 1.3)
			var z0 := float(row) * spring / 5.0
			var z1 := float(row + 1) * spring / 5.0 - 0.16
			face([Vector3(x0, front + 0.04, z0), Vector3(x1, front + 0.04, z0), Vector3(x1, front + 0.04, z1), Vector3(x0, front + 0.04, z1)], trim.darkened(0.06))
	box(Vector2.ZERO, Vector2(opening + 0.15, tower_depth), crown, 0.6, trim.darkened(0.15))
	for x in [-opening * 0.32, 0.0, opening * 0.32]:
		box(Vector2(x, front - 1.0), Vector2(3.0, 2.0), crown + 0.6, 3.0, trim)
	# Recessed doors have continuous planks, then two opaque iron straps.
	var door_y := front - 3.4
	for i in 10:
		var x0 := lerpf(-half + 0.3, half - 0.3, float(i) / 10.0)
		var x1 := lerpf(-half + 0.3, half - 0.3, float(i + 1) / 10.0) - 0.12
		var top0 := spring + arc_rise * sqrt(maxf(0, 1.0 - pow(x0 / half, 2))) - 0.35
		var top1 := spring + arc_rise * sqrt(maxf(0, 1.0 - pow(x1 / half, 2))) - 0.35
		face([Vector3(x0, door_y, 0.5), Vector3(x1, door_y, 0.5), Vector3(x1, door_y, top1), Vector3(x0, door_y, top0)], Color("765436").darkened(0.07 if i % 2 else 0.0))
	for z in [4.0, 10.5]:
		for side in [-1.0, 1.0]:
			var a: float = 0.2 * side
			var b: float = (half - 0.5) * side
			face([Vector3(a, door_y + 0.025, z), Vector3(b, door_y + 0.025, z), Vector3(b, door_y + 0.025, z + 0.65), Vector3(a, door_y + 0.025, z + 0.65)], Color("353c35"))

func _tower(x: float, width: float, depth: float, accent: Color) -> void:
	var stone: Color = palette["wall"]
	var trim: Color = palette["trim"]
	var center := Vector2(x, 0)
	box(center, Vector2(width, depth), 0, 28.05, stone)
	box(center, Vector2(width + 0.8, depth + 0.8), 0, 1.8, stone.darkened(0.11))
	box(center, Vector2(width + 0.6, depth + 0.6), 26.8, 1.25, trim.darkened(0.12))
	box(center, Vector2(width - 1.3, depth - 1.3), 28.05, 0.15, stone.darkened(0.37))
	battlements(center, Vector2(width, depth), 28.05, trim)
	for z in [7.0, 13.5, 20.0]:
		face([Vector3(x - width * 0.5, depth * 0.5 + 0.02, z), Vector3(x + width * 0.5, depth * 0.5 + 0.02, z), Vector3(x + width * 0.5, depth * 0.5 + 0.02, z + 0.22), Vector3(x - width * 0.5, depth * 0.5 + 0.02, z + 0.22)], stone.darkened(0.13))
	_window(Vector3(x, depth * 0.5 + 0.04, 14.8), Vector3.RIGHT, Vector3(0, 0.022, 0))
	_window(Vector3(x + width * 0.5 + 0.04, 0, 14.8), Vector3(0, 1, 0), Vector3(0.022, 0, 0))
	var p := Vector3(x + width * 0.18, depth * 0.5 + 0.08, 25.0)
	face([p, p + Vector3(2.3, 0, 0), p + Vector3(2.3, 0, -5), p + Vector3(1.15, 0, -6), p + Vector3(0, 0, -5)], accent)

func _window(p: Vector3, across: Vector3, outward: Vector3) -> void:
	var trim: Color = palette["trim"]
	var up := Vector3(0, 0, 4.8)
	face([p - across * 1.1, p + across * 1.1, p + across * 1.1 + up, p - across * 1.1 + up], trim.darkened(0.18))
	face([p - across * 0.55 + outward, p + across * 0.55 + outward, p + across * 0.55 + outward + up * 0.92, p - across * 0.55 + outward + up * 0.92], Color("333c37"))

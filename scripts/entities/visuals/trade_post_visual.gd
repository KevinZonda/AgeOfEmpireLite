extends RefCounted

# A neutral roadside trading house. Cache both camera projections once;
# rendering and pointer targeting use the same visible surfaces.
const FilledPolygon = preload("res://scripts/entities/visuals/filled_polygon.gd")
const TIMBER := Color("624631")
const TIMBER_LIGHT := Color("a77c50")
const WALL := Color("c8b58c")
const WALL_SIDE := Color("9c8b66")
const ROOF := Color("97674b")
const ROOF_LIGHT := Color("bb865b")
const CLOTH := Color("bfad78")
const CLOTH_STRIPE := Color("677e75")
var flat: Array[Dictionary] = []
var iso: Array[Dictionary] = []
var shapes: Array[Dictionary]
var isometric := false

func _init() -> void:
	for projection in [false, true]:
		isometric = projection
		shapes = iso if projection else flat
		_build()

func draw(canvas: CanvasItem, projected: bool) -> void:
	for shape in (iso if projected else flat):
		if shape.has("line"):
			canvas.draw_polyline(shape["points"], shape["color"], shape["line"], true)
		else:
			FilledPolygon.draw(canvas, shape["points"], shape["color"])

func contains(point: Vector2, projected: bool) -> bool:
	for shape in (iso if projected else flat):
		if shape.has("line") or shape.get("shadow", false): continue
		if Geometry2D.is_point_in_polygon(point, shape["points"]): return true
	return false

func bounds(projected: bool) -> Rect2:
	var result := Rect2(Vector2.ZERO, Vector2.ZERO)
	for shape in (iso if projected else flat):
		if shape.get("shadow", false): continue
		for point in shape["points"]: result = result.expand(point)
	return result

func _p(point: Vector3) -> Vector2:
	return Vector2((point.x - point.y) * 0.70710678, (point.x + point.y) * 0.35355339 - point.z) if isometric else Vector2(point.x, point.y)

func _face(points: Array, color: Color, shadow := false) -> void:
	var polygon := PackedVector2Array()
	for point in points: polygon.append(_p(point))
	# Vertical faces collapse to lines in the overhead camera.
	if Geometry2D.triangulate_polygon(polygon).is_empty(): return
	shapes.append({"points": polygon, "color": color, "shadow": shadow})

func _line(points: Array, color: Color, width := 1.0) -> void:
	var path := PackedVector2Array()
	for point in points: path.append(_p(point))
	if path[0].distance_squared_to(path[path.size() - 1]) > 0.01:
		shapes.append({"points": path, "color": color, "line": width})

func _box(origin: Vector3, size: Vector3, front: Color, side: Color, top: Color) -> void:
	var a := origin
	var b := origin + Vector3(size.x, 0, 0)
	var c := origin + Vector3(size.x, size.y, 0)
	var d := origin + Vector3(0, size.y, 0)
	var up := Vector3(0, 0, size.z)
	_face([b, c, c + up, b + up], side)
	_face([d, c, c + up, d + up], front)
	_face([a + up, b + up, c + up, d + up], top)

func _build() -> void:
	# A broad, low platform separates the shop from surrounding grass.
	_face([Vector3(-33, -24, 0), Vector3(37, -24, 0), Vector3(44, 35, 0), Vector3(30, 43, 0), Vector3(-30, 41, 0)], Color("26372d", 0.24), true)
	_box(Vector3(-29, -23, 0), Vector3(65, 62, 2), Color("777460"), Color("696956"), Color("aaa18a"))
	_face([Vector3(-24, 15, 2.1), Vector3(14, 15, 2.1), Vector3(14, 38, 2.1), Vector3(-24, 38, 2.1)], Color("736451", 0.55), true)
	for x in [-23.0, -7.0, 9.0, 25.0]:
		_line([Vector3(x, 36, 2.2), Vector3(x + 8, 36, 2.2)], Color("c5baa0"), 0.7)
	_box(Vector3(-24, -20, 2), Vector3(36, 32, 30), WALL, WALL_SIDE, TIMBER)
	# Corner posts, a continuous sill and the front beam expose construction.
	for corner in [Vector2(-24, 12), Vector2(10, 12), Vector2(10, -20)]:
		_box(Vector3(corner.x, corner.y, 2), Vector3(2, 2, 31), TIMBER, TIMBER.darkened(0.12), TIMBER_LIGHT)
	_box(Vector3(-24, 12, 2), Vector3(36, 1.5, 3), TIMBER, TIMBER, TIMBER_LIGHT)
	_box(Vector3(-24, 12, 26), Vector3(36, 1.5, 3), TIMBER, TIMBER, TIMBER_LIGHT)
	# Recessed door and shuttered side window, visible under the porch.
	_face([Vector3(-17, 13.6, 4), Vector3(-8, 13.6, 4), Vector3(-8, 13.6, 23), Vector3(-17, 13.6, 23)], Color("4c4131"))
	for x in [-15.0, -12.0, -9.0]:
		_line([Vector3(x, 13.7, 5), Vector3(x, 13.7, 22)], Color("786043"), 0.75)
	_line([Vector3(-10, 13.8, 13), Vector3(-9, 13.8, 13)], Color("e0ba65"), 1.5)
	_face([Vector3(12.1, -12, 15), Vector3(12.1, -3, 15), Vector3(12.1, -3, 24), Vector3(12.1, -12, 24)], TIMBER)
	_face([Vector3(12.2, -11, 16), Vector3(12.2, -4, 16), Vector3(12.2, -4, 23), Vector3(12.2, -11, 23)], Color("3e544e"))
	_line([Vector3(12.3, -7.5, 16), Vector3(12.3, -7.5, 23)], TIMBER_LIGHT, 1.1)
	_line([Vector3(12.3, -11, 19.5), Vector3(12.3, -4, 19.5)], TIMBER_LIGHT, 1.0)
	# Pitched roof: two differently lit slopes, front gable and thick eaves.
	_face([Vector3(-25, 13, 32), Vector3(14, 13, 32), Vector3(-5.5, 13, 45)], WALL)
	_line([Vector3(-25, 13.1, 32), Vector3(-5.5, 13.1, 45), Vector3(14, 13.1, 32)], TIMBER, 1.8)
	_face([Vector3(-28, -23, 32), Vector3(-5.5, -23, 47), Vector3(-5.5, 16, 47), Vector3(-28, 16, 32)], ROOF_LIGHT)
	_face([Vector3(-5.5, -23, 47), Vector3(16, -23, 32), Vector3(16, 16, 32), Vector3(-5.5, 16, 47)], ROOF)
	for y in [-14.0, -4.0, 6.0]:
		_line([Vector3(-27, y, 32.7), Vector3(-5.5, y, 47.1), Vector3(15, y, 32.7)], Color("76513d"), 0.7)
	_line([Vector3(-5.5, -23, 47.2), Vector3(-5.5, 16, 47.2)], Color("d6a676"), 1.6)
	_line([Vector3(-28, 16, 31), Vector3(-5.5, 16, 46), Vector3(16, 16, 31)], TIMBER, 2.3)
	# Back cargo is drawn before the porch and its supports.
	_barrel(Vector2(24, -12), 5, 12)
	_crate(Vector3(19, 1, 2), Vector3(12, 11, 10))
	_crate(Vector3(20, 2, 12), Vector3(9, 8, 7))
	# The cloth canopy falls toward the customer-facing edge.
	for x in [-23.0, 11.0]:
		_box(Vector3(x, 34, 2), Vector3(1.8, 1.8, 18), TIMBER, TIMBER.darkened(0.15), TIMBER_LIGHT)
		_line([Vector3(x, 35, 8), Vector3(x + 5, 29, 18)], TIMBER_LIGHT, 1.0)
	for strip in 6:
		var x := -26.0 + strip * 7.0
		var color := CLOTH if strip % 2 == 0 else CLOTH_STRIPE
		_face([Vector3(x, 13, 26), Vector3(x + 7, 13, 26), Vector3(x + 7, 37, 19), Vector3(x, 37, 19)], color)
		_face([Vector3(x, 37, 19), Vector3(x + 7, 37, 19), Vector3(x + 6, 37, 16), Vector3(x + 1, 37, 16)], color.darkened(0.18))
	_line([Vector3(-26, 37, 19), Vector3(16, 37, 19)], Color("ded0a0"), 1.0)
	# Goods laid out in front make the trading purpose visible at map zoom.
	_box(Vector3(-20, 30, 2), Vector3(25, 10, 8), TIMBER_LIGHT, TIMBER, Color("c09762"))
	for x in [-16.0, -8.0, 0.0]:
		_face([Vector3(x - 2.5, 32, 10.1), Vector3(x + 2.5, 32, 10.1), Vector3(x + 2.5, 37, 10.1), Vector3(x - 2.5, 37, 10.1)], Color("a65540") if x == -16 else Color("b8a36d") if x == -8 else Color("66897a"))
		_line([Vector3(x - 2, 34, 10.2), Vector3(x + 2, 34, 10.2)], Color("e1c397"), 0.9)
	_sack(Vector2(24, 31), 5, Color("c0ac7c"))
	_sack(Vector2(32, 28), 4, Color("a79162"))
	# Hanging coin sign, with no player tint: this is a neutral destination.
	_box(Vector3(18, 23, 2), Vector3(1.8, 1.8, 33), TIMBER, TIMBER, TIMBER_LIGHT)
	_line([Vector3(18, 24, 34), Vector3(32, 24, 34)], TIMBER, 2.0)
	for x in [24.0, 30.0]:
		_line([Vector3(x, 24, 34), Vector3(x, 24, 31)], Color("bca573"), 0.8)
	_face([Vector3(22, 24, 22), Vector3(32, 24, 22), Vector3(32, 24, 31), Vector3(22, 24, 31)], TIMBER)
	_face([Vector3(23, 24.1, 23), Vector3(31, 24.1, 23), Vector3(31, 24.1, 30), Vector3(23, 24.1, 30)], Color("3d625c"))
	var coin: Array = []
	for i in 12:
		var angle := i * TAU / 12.0
		coin.append(Vector3(27 + cos(angle) * 2.5, 24.2, 26.5 + sin(angle) * 2.5))
	_face(coin, Color("e2bd63"))
	_line([Vector3(27, 24.3, 25), Vector3(27, 24.3, 28)], Color("8f6537"), 0.8)

func _crate(origin: Vector3, size: Vector3) -> void:
	_box(origin, size, Color("b38b55"), Color("85633e"), Color("d0a970"))
	var y := origin.y + size.y + 0.1
	_line([Vector3(origin.x + 1, y, origin.z + 1), Vector3(origin.x + size.x - 1, y, origin.z + size.z - 1)], TIMBER, 1.0)
	_line([Vector3(origin.x + 1, y, origin.z + size.z - 1), Vector3(origin.x + size.x - 1, y, origin.z + 1)], TIMBER, 1.0)
	for offset in [size.x * 0.25, size.x * 0.75]:
		_line([origin + Vector3(offset, 0, size.z + 0.1), origin + Vector3(offset, size.y, size.z + 0.1)], TIMBER_LIGHT, 0.8)

func _barrel(center: Vector2, radius: float, height: float) -> void:
	var top: Array = []
	for i in 8:
		var a := i * TAU / 8.0
		var b := (i + 1) * TAU / 8.0
		var first := Vector3(center.x + cos(a) * radius, center.y + sin(a) * radius, 2)
		var second := Vector3(center.x + cos(b) * radius, center.y + sin(b) * radius, 2)
		var up := Vector3(0, 0, height)
		if cos((a + b) * 0.5) + sin((a + b) * 0.5) > 0:
			_face([first, second, second + up, first + up], TIMBER_LIGHT.darkened(i * 0.03))
			for z in [height * 0.25, height * 0.75]:
				_line([first + Vector3(0, 0, z), second + Vector3(0, 0, z)], Color("595e54"), 1.0)
		top.append(first + up)
	_face(top, Color("ba9464"))
	_line([Vector3(center.x - 3, center.y, height + 2.1), Vector3(center.x + 3, center.y, height + 2.1)], TIMBER, 0.8)

func _sack(center: Vector2, radius: float, color: Color) -> void:
	# An upright, low faceted bag with a gathered neck.
	var base := _p(Vector3(center.x, center.y, 3))
	var extent := Vector2(radius, radius * 1.3 if isometric else radius)
	var silhouette := PackedVector2Array([base + Vector2(-extent.x, 0), base + Vector2(-extent.x * 0.85, -extent.y), base + Vector2(-1, -extent.y * 1.5), base + Vector2(2, -extent.y * 1.5), base + Vector2(extent.x * 0.85, -extent.y), base + Vector2(extent.x, 0), base + Vector2(0, extent.y * 0.3)])
	shapes.append({"points": silhouette, "color": color})
	shapes.append({"points": PackedVector2Array([base + Vector2(-extent.x, 0), base + Vector2(-extent.x * 0.85, -extent.y), base + Vector2(-1, -extent.y * 1.3), base + Vector2(-1, 0)]), "color": color.lightened(0.12)})
	shapes.append({"points": PackedVector2Array([base + Vector2(-2, -extent.y * 1.3), base + Vector2(2, -extent.y * 1.3)]), "color": TIMBER, "line": 1.0})

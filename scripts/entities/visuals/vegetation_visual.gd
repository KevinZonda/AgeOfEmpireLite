extends RefCounted

# Geometry is generated once per resource with a private, position-seeded RNG.
# Both projections and portraits share the same plant, independent of map RNG.
const FilledPolygon = preload("res://scripts/entities/visuals/filled_polygon.gd")
const BARK_DARK := Color("493b2c")
const BARK := Color("806044")
const BARK_LIGHT := Color("ac8558")
var tree_2d: Array[Dictionary] = []
var tree_25d: Array[Dictionary] = []
var bush_2d: Array[Dictionary] = []
var bush_25d: Array[Dictionary] = []
var fruit_2d: Array[Dictionary] = []
var fruit_25d: Array[Dictionary] = []
var width := 1.0
var height := 1.0
var lean := 0.0
var crown_shape := 0
var rng := RandomNumberGenerator.new()

func _init(point: Vector2, is_tree := true) -> void:
	rng.seed = hash(point)
	width = rng.randf_range(0.90, 1.12)
	height = rng.randf_range(0.89, 1.13)
	lean = rng.randf_range(-4.0, 4.0)
	crown_shape = rng.randi_range(0, 2)
	var leaf := [Color("477744"), Color("3c7351"), Color("527a43")][rng.randi_range(0, 2)] as Color
	if is_tree:
		_build_tree(tree_2d, false, leaf)
		_build_tree(tree_25d, true, leaf)
	else:
		_build_bush(bush_2d, fruit_2d, false)
		_build_bush(bush_25d, fruit_25d, true)

func draw_ground(canvas: CanvasItem, is_tree: bool) -> void:
	var extent := Vector2(27 * width, 15) if is_tree else Vector2(23 * width, 13)
	var points := PackedVector2Array()
	for i in 16:
		points.append(Vector2(5, 3) + Vector2(cos(i * TAU / 16.0), sin(i * TAU / 16.0)) * extent)
	FilledPolygon.draw(canvas, points, Color("203127", 0.27))
	canvas.draw_circle(Vector2.ZERO, 7.0 if is_tree else 12.0, Color("203127", 0.18))

func draw(canvas: CanvasItem, is_tree: bool, isometric: bool, fraction := 1.0) -> void:
	var shapes := (tree_25d if isometric else tree_2d) if is_tree else (bush_25d if isometric else bush_2d)
	for shape in shapes:
		FilledPolygon.draw(canvas, shape["points"], shape["color"])
	if not is_tree:
		for fruit in (fruit_25d if isometric else fruit_2d):
			if fraction < fruit["threshold"]: continue
			var point: Vector2 = fruit["point"]
			var radius: float = fruit["radius"]
			canvas.draw_circle(point + Vector2(0.3, 0.7), radius + 0.35, Color("683d33"))
			canvas.draw_circle(point, radius, Color("bd5144"))
			canvas.draw_circle(point + Vector2(-radius * 0.28, -radius * 0.3), radius * 0.4, Color("ec9870"))
	elif isometric and fraction < 0.7:
		# A pale cut on the exposed trunk keeps harvesting legible at game zoom.
		canvas.draw_line(Vector2(-2, -11), Vector2(2, -13), Color("dab47c"), 2.0)
		canvas.draw_line(Vector2(9, 1), Vector2(12, 0), BARK_LIGHT, 1.5)
		canvas.draw_line(Vector2(-10, 3), Vector2(-8, 4), BARK_LIGHT, 1.5)

func _shape(target: Array[Dictionary], points: Array, color: Color) -> void:
	target.append({"points": PackedVector2Array(points), "color": color})

func _build_tree(target: Array[Dictionary], iso: bool, leaf: Color) -> void:
	var trunk_top := Vector2(lean, -37 * height) if iso else Vector2(lean * 0.5, -7)
	# Flared roots, a tapering trunk, and two forks behind the canopy.
	_shape(target, [Vector2(-10, 3), Vector2(-4, -4), trunk_top + Vector2(-3, 0), trunk_top + Vector2(3, 0), Vector2(4, -3), Vector2(10, 3), Vector2(1, 2), Vector2(-2, 5)], BARK_DARK)
	_shape(target, [Vector2(-3, 1), Vector2(-4, -5), trunk_top + Vector2(-2, 0), trunk_top + Vector2(1, 0), Vector2(1, 1)], BARK)
	_shape(target, [Vector2(-3, -2), trunk_top + Vector2(-2, 1), trunk_top, Vector2(-1, -3)], BARK_LIGHT)
	for side in [-1.0, 1.0]:
		var fork := trunk_top + Vector2(side * 12, -6)
		_branch(target, trunk_top + Vector2(0, 10), fork, 3.0, 1.5)
	var center := Vector2(lean, -44 * height) if iso else Vector2(0, -5)
	var vertical := 1.0 if iso else 0.78
	var spread: float = [1.0, 0.86, 1.12][crown_shape]
	var rise: float = [1.0, 1.16, 0.87][crown_shape]
	# Back-to-front leaf masses merge into an asymmetric crown, with gaps
	# around the lower branches rather than a circular outline.
	var lobes := [Vector3(-9, -11, 13), Vector3(7, -14, 14), Vector3(17, -3, 12), Vector3(-18, 1, 12), Vector3(0, -1, 17), Vector3(11, 10, 12), Vector3(-9, 11, 13)]
	for i in lobes.size():
		var lobe: Vector3 = lobes[i]
		var point := center + Vector2((lobe.x + rng.randf_range(-3, 3)) * width * spread, (lobe.y + rng.randf_range(-2, 2)) * vertical * rise)
		var tint := leaf.darkened(0.17) if i < 3 else leaf
		if i == 5: tint = leaf.darkened(0.08)
		_lobe(target, point, Vector2(lobe.z * width * spread, lobe.z * vertical * rise) * rng.randf_range(0.91, 1.07), tint)

func _build_bush(target: Array[Dictionary], fruits: Array[Dictionary], iso: bool) -> void:
	var center := Vector2(lean * 0.4, -12) if iso else Vector2.ZERO
	var vertical := 0.8 if iso else 0.95
	if iso:
		for side in [-1.0, 1.0]:
			_branch(target, Vector2(0, 1), Vector2(side * 12, -14), 2.0, 1.0)
	var leaf := Color("5c7d3c")
	var lobes := [Vector3(-8, -5, 11), Vector3(6, -9, 12), Vector3(14, 2, 10), Vector3(-14, 4, 11), Vector3(0, 3, 13), Vector3(7, 10, 9)]
	for i in lobes.size():
		var lobe: Vector3 = lobes[i]
		var point := center + Vector2(lobe.x * width, lobe.y * vertical)
		_lobe(target, point, Vector2(lobe.z * width, lobe.z * vertical), leaf.darkened(0.1) if i < 3 else leaf)
	# Small irregular bunches, distributed across the visible leaf masses.
	for i in 7:
		var point := center + Vector2([-13, -5, 7, 14, -12, 1, 9][i] * width, [-4, -10, -7, 1, 7, 5, 11][i] * vertical)
		point += Vector2(rng.randf_range(-1.5, 1.5), rng.randf_range(-1.0, 1.0))
		for j in (3 if i % 3 == 0 else 2):
			fruits.append({"point": point + Vector2(j * 2.5 - 1, (j % 2) * 2.2), "radius": rng.randf_range(1.6, 2.2), "threshold": float(i) * 0.12})

func _branch(target: Array[Dictionary], start: Vector2, end: Vector2, base_width: float, tip_width: float) -> void:
	var normal := (end - start).normalized().orthogonal()
	_shape(target, [start - normal * base_width, end - normal * tip_width, end + normal * tip_width, start + normal * base_width], BARK)

func _lobe(target: Array[Dictionary], center: Vector2, extent: Vector2, leaf: Color) -> void:
	var rim: Array[Vector2] = []
	for i in 12:
		var angle := i * TAU / 12.0
		var roughness := rng.randf_range(0.88, 1.08)
		rim.append(center + Vector2(cos(angle), sin(angle)) * extent * roughness)
	_shape(target, rim, leaf.darkened(0.18))
	# The lower/right rim remains dark; broad upper/left facets give volume.
	var middle: Array[Vector2] = []
	for point in rim: middle.append(center + (point - center) * 0.94 + Vector2(-0.4, -0.7))
	_shape(target, middle, leaf)
	_shape(target, [middle[6], middle[7], middle[8], middle[9], middle[10], center + Vector2(extent.x * 0.23, -extent.y * 0.1), center + Vector2(-extent.x * 0.43, extent.y * 0.04)], leaf.lightened(0.16))
	# Two restrained leaf facets, still visible without noisy individual leaves.
	_shape(target, [center + Vector2(-4, -3), center + Vector2(-1, -5), center + Vector2(2, -3), center + Vector2(-1, -2)], leaf.lightened(0.24))
	_shape(target, [center + Vector2(3, 3), center + Vector2(5, 1), center + Vector2(7, 2), center + Vector2(5, 4)], leaf.darkened(0.09))

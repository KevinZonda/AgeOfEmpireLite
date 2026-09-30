extends RefCounted

# Local 3D faces, rendered through the existing 2D isometric canvas. BSP splits
# intersecting faces, so overlapping wings cannot override one another merely
# because their draw calls happened later. Geometry is cached by the building.
const WesternLandmark = preload("res://scripts/entities/visuals/western_landmark_visual.gd")
const ChineseLandmark = preload("res://scripts/entities/visuals/chinese_landmark_visual.gd")
const EPSILON := 0.001
var faces: Array[Dictionary] = []
var ordered_faces: Array[Dictionary] = []
var dimensions := Vector2.ZERO
var palette: Dictionary
var base_z := 0.0
var height_above_origin := 0.0
var projected_cache: Array[Dictionary] = []
var projected_cache_up := Vector2.INF
var projected_cache_lift := Vector2.INF

func face(points: Array, color: Color) -> void:
	faces.append({"points": PackedVector3Array(points), "color": color})

func box(center: Vector2, extent: Vector2, bottom: float, height: float, color: Color) -> void:
	var a := Vector3(center.x - extent.x * 0.5, center.y - extent.y * 0.5, bottom)
	var b := a + Vector3(extent.x, 0, 0)
	var c := b + Vector3(0, extent.y, 0)
	var d := a + Vector3(0, extent.y, 0)
	var up := Vector3(0, 0, height)
	face([b, c, c + up, b + up], color.darkened(0.22))
	face([d, c, c + up, d + up], color)
	face([a + up, b + up, c + up, d + up], color.lightened(0.08))

func battlements(center: Vector2, extent: Vector2, bottom: float, color: Color) -> void:
	# Inset complete merlons onto all four edges. Each corner is emitted once,
	# so adjacent edges do not create overlapping teeth or solid corner clumps.
	var tooth := 3.0
	var half := (extent - Vector2.ONE * tooth) * 0.5
	var across := maxi(2, ceili((extent.x - tooth) / 7.0))
	var along := maxi(2, ceili((extent.y - tooth) / 7.0))
	for i in range(across + 1):
		var x := lerpf(-half.x, half.x, float(i) / across)
		for y in [-half.y, half.y]:
			var offset := Vector2(x, y)
			box(center + offset, Vector2.ONE * tooth, bottom, 4, battlement_color(offset, color))
	for i in range(1, along):
		var y := lerpf(-half.y, half.y, float(i) / along)
		for x in [-half.x, half.x]:
			var offset := Vector2(x, y)
			box(center + offset, Vector2.ONE * tooth, bottom, 4, battlement_color(offset, color))

static func battlement_color(offset: Vector2, color: Color) -> Color:
	# Ground-plane depth: the two rear edges receive a darker stone tone.
	var depth := offset.x + offset.y
	return color.darkened(0.22 if depth < -0.001 else 0.08 if absf(depth) <= 0.001 else 0.0)

func block(u: float, v: float, width: float, depth: float, height: float, style: String, tint := Color.TRANSPARENT) -> void:
	var center := (Vector2(u, v) - Vector2.ONE * 0.5) * dimensions
	var extent := Vector2(width, depth) * dimensions
	var a := Vector3(center.x - extent.x * 0.5, center.y - extent.y * 0.5, base_z + height)
	var b := a + Vector3(extent.x, 0, 0)
	var c := b + Vector3(0, extent.y, 0)
	var d := a + Vector3(0, extent.y, 0)
	var wall: Color = palette["wall"]
	var roof: Color = palette["roof"] if tint.a == 0.0 else tint
	var trim: Color = palette["trim"]
	box(center, extent, base_z, height, wall)
	match style:
		"flat", "clock":
			face([a, b, c, d], palette["roof_dark"])
			battlements(center, extent, base_z + height, trim)
		"gable":
			var back := (a + b) * 0.5 + Vector3(0, 0, 9)
			var front := (d + c) * 0.5 + Vector3(0, 0, 9)
			# Closed gable ends; the former renderer left these triangles empty.
			face([a, b, back], wall.darkened(0.22))
			face([d, c, front], wall)
			face([a, back, front, d], roof.lightened(0.12))
			face([back, b, c, front], roof)
		"dome":
			# A hemisphere, not a screen-space circle on top of a pyramid.
			var hub := (a + c) * 0.5
			var radius := minf(extent.x, extent.y) * 0.5
			for ring in 5:
				var first := float(ring) * PI * 0.5 / 5.0
				var last := float(ring + 1) * PI * 0.5 / 5.0
				for segment in 16:
					var angle := float(segment) * TAU / 16.0
					var next := float(segment + 1) * TAU / 16.0
					var p := hub + Vector3(cos(angle) * cos(first), sin(angle) * cos(first), sin(first)) * radius
					var q := hub + Vector3(cos(next) * cos(first), sin(next) * cos(first), sin(first)) * radius
					var r := hub + Vector3(cos(next) * cos(last), sin(next) * cos(last), sin(last)) * radius
					var s := hub + Vector3(cos(angle) * cos(last), sin(angle) * cos(last), sin(last)) * radius
					var color := roof.lightened(0.16 + 0.13 * cos(angle + PI * 0.25))
					face([p, q, r] if ring == 4 else [p, q, r, s], color)
		_:
			var rise := 26.6 if style == "spire" else 14.0 if style == "pagoda" else 9.0
			pyramid(a, b, c, d, rise, roof)
			if style == "pagoda":
				var hub := (a + c) * 0.5 + Vector3(0, 0, 11.48)
				pyramid(hub + (a - (a + c) * 0.5) * 0.65, hub + (b - (a + c) * 0.5) * 0.65, hub + (c - (a + c) * 0.5) * 0.65, hub + (d - (a + c) * 0.5) * 0.65, 16.8, roof.lightened(0.08))
	# Windows lie on the front facade and participate in the same occlusion.
	for fraction in [0.25, 0.75]:
		var p := d.lerp(c, fraction)
		p.z = base_z + height * 0.62
		p.y += 0.02
		face([p + Vector3(-1.4, 0, 0), p + Vector3(1.4, 0, 0), p + Vector3(1.4, 0, height * 0.18), p + Vector3(-1.4, 0, height * 0.18)], Color("36474a"))
	if style == "clock":
		var hub := (c + d) * 0.5
		hub.z = base_z + height * 0.55
		hub.y += 0.04
		disc(hub, 6, trim)
		disc(hub + Vector3(0, 0.01, 0), 4.5, palette["roof_dark"])
		face([hub + Vector3(-0.5, 0.02, -0.5), hub + Vector3(2.8, 0.02, -0.5), hub + Vector3(2.8, 0.02, 0.5), hub + Vector3(-0.5, 0.02, 0.5)], trim)
		face([hub + Vector3(-0.5, 0.02, 0), hub + Vector3(0.5, 0.02, 0), hub + Vector3(0.5, 0.02, 3.5), hub + Vector3(-0.5, 0.02, 3.5)], trim)

func pyramid(a: Vector3, b: Vector3, c: Vector3, d: Vector3, rise: float, roof: Color) -> void:
	var peak := (a + c) * 0.5 + Vector3(0, 0, rise)
	face([a, b, peak], roof.lightened(0.13))
	face([b, c, peak], roof)
	face([c, d, peak], roof.darkened(0.22))
	face([d, a, peak], roof.lightened(0.08))

func disc(center: Vector3, radius: float, color: Color) -> void:
	var points: Array = []
	for i in 16:
		var angle := float(i) * TAU / 16.0
		points.append(center + Vector3(cos(angle), 0, sin(angle)) * radius)
	face(points, color)

func column(u: float, v: float, height: float) -> void:
	box((Vector2(u, v) - Vector2.ONE * 0.5) * dimensions, Vector2(3, 3), base_z, height, palette["trim"])

func _insert(tree: Dictionary, polygon: Dictionary) -> Dictionary:
	var points: PackedVector3Array = polygon["points"]
	if tree.is_empty():
		var normal := Vector3.ZERO
		for i in range(2, points.size()):
			normal = (points[i - 1] - points[0]).cross(points[i] - points[0]).normalized()
			if not normal.is_zero_approx(): break
		if normal.is_zero_approx(): return tree
		return {"normal": normal, "distance": normal.dot(points[0]), "same": [polygon], "front": {}, "back": {}}
	var front: Array = []
	var back: Array = []
	var positive := false
	var negative := false
	for p in points:
		var distance: float = tree["normal"].dot(p) - tree["distance"]
		positive = positive or distance > EPSILON
		negative = negative or distance < -EPSILON
	if not positive and not negative:
		tree["same"].append(polygon)
		return tree
	if not negative:
		tree["front"] = _insert(tree["front"], polygon)
		return tree
	if not positive:
		tree["back"] = _insert(tree["back"], polygon)
		return tree
	for i in points.size():
		var p := points[i]
		var q := points[(i + 1) % points.size()]
		var dp: float = tree["normal"].dot(p) - tree["distance"]
		var dq: float = tree["normal"].dot(q) - tree["distance"]
		if dp >= -EPSILON: front.append(p)
		if dp <= EPSILON: back.append(p)
		if (dp > EPSILON and dq < -EPSILON) or (dp < -EPSILON and dq > EPSILON):
			var crossing := p.lerp(q, dp / (dp - dq))
			front.append(crossing)
			back.append(crossing)
	if front.size() >= 3: tree["front"] = _insert(tree["front"], {"points": PackedVector3Array(front), "color": polygon["color"]})
	if back.size() >= 3: tree["back"] = _insert(tree["back"], {"points": PackedVector3Array(back), "color": polygon["color"]})
	return tree

func _traverse(tree: Dictionary, toward_camera: Vector3) -> void:
	if tree.is_empty(): return
	var front_first: bool = tree["normal"].dot(toward_camera) < 0.0
	_traverse(tree["front"] if front_first else tree["back"], toward_camera)
	ordered_faces.append_array(tree["same"])
	_traverse(tree["back"] if front_first else tree["front"], toward_camera)

func prepare() -> void:
	projected_cache.clear()
	projected_cache_up = Vector2.INF
	projected_cache_lift = Vector2.INF
	height_above_origin = 0.0
	for polygon in faces:
		for p in polygon["points"]:
			height_above_origin = maxf(height_above_origin, p.z - (p.x + p.y) * sqrt(0.125))
	var tree: Dictionary = {}
	for polygon in faces: tree = _insert(tree, polygon)
	ordered_faces.clear()
	# Matches the game's fixed 2:1 projection: x/y move down equally, z up.
	_traverse(tree, Vector3(1, 1, sqrt(0.5)))

func projected_faces(canvas: Transform2D, zoom: float, lift: Vector2) -> Array[Dictionary]:
	var up := RtsIsoProjection.world_delta(canvas, Vector2(0, -zoom))
	if up.is_equal_approx(projected_cache_up) and lift.is_equal_approx(projected_cache_lift): return projected_cache
	var result: Array[Dictionary] = []
	for polygon in ordered_faces:
		var points := PackedVector2Array()
		for p in polygon["points"]: points.append(Vector2(p.x, p.y) + up * p.z + lift)
		# BSP intersections can leave subpixel slivers. Discard zero-area
		# projections before they reach polygon triangulation or hit testing.
		var twice_area := 0.0
		for i in range(1, points.size() - 1):
			twice_area += (points[i] - points[0]).cross(points[i + 1] - points[0])
		if absf(twice_area) < 0.001: continue
		result.append({"points": points, "color": polygon["color"]})
	projected_cache = result
	projected_cache_up = up
	projected_cache_lift = lift
	return result

func populate(kind: String, landmark_id: String, player: Color) -> void:
	if kind == "landmark":
		if ChineseLandmark.populate(self, landmark_id, player): return
		if WesternLandmark.populate(self, landmark_id, player): return
	if kind == "wonder":
		# Broad plinth, colonnade, cupola and four corner pinnacles.
		block(0.5, 0.5, 1.04, 1.04, 12, "flat")
		base_z = 12.0
		for u in [0.1, 0.9]:
			for v in [0.1, 0.9]: block(u, v, 0.17, 0.17, 35, "spire")
		block(0.5, 0.5, 0.62, 0.62, 48, "dome", Color("bda36b"))
		for u in [0.27, 0.42, 0.58, 0.73]: column(u, 0.94, 20.0)
		return
	match landmark_id:
		"eng_council_hall":
			block(0.5, 0.49, 0.78, 0.48, 21, "gable")
			for u in [0.27, 0.5, 0.73]: column(u, 0.83, 16.8)
		"eng_kings_mill":
			for u in [0.24, 0.76]: block(u, 0.5, 0.21, 0.28, 39, "spire")
			block(0.5, 0.52, 0.43, 0.59, 18, "gable")
		"eng_white_tower":
			block(0.5, 0.48, 0.48, 0.55, 57, "flat")
		"eng_abbey":
			block(0.5, 0.43, 0.39, 0.7, 21, "gable")
			for u in [0.25, 0.75]: block(u, 0.69, 0.18, 0.19, 34, "spire")
		"eng_berkshire_fortress":
			for u in [0.15, 0.85]:
				for v in [0.16, 0.84]: block(u, v, 0.21, 0.21, 37, "flat")
			block(0.5, 0.5, 0.37, 0.38, 27, "flat")
		"eng_wynguard_palace":
			block(0.5, 0.48, 0.49, 0.55, 32, "hip")
			for u in [0.15, 0.85]: block(u, 0.55, 0.21, 0.33, 24, "spire")
		"fr_school_of_cavalry":
			for u in [0.19, 0.81]: block(u, 0.48, 0.25, 0.7, 20, "gable")
			block(0.5, 0.18, 0.37, 0.23, 31, "hip")
		"fr_chamber_of_commerce":
			for u in [0.19, 0.5, 0.81]: block(u, 0.32, 0.28, 0.42, 19, "gable", player.darkened(0.12))
			block(0.5, 0.73, 0.3, 0.24, 22, "hip")
		"fr_royal_institute":
			for u in [0.2, 0.8]: block(u, 0.58, 0.3, 0.41, 23, "gable")
			block(0.5, 0.43, 0.38, 0.48, 35, "dome")
		"fr_guild_hall":
			for u in [0.22, 0.78]: block(u, 0.61, 0.27, 0.4, 20, "gable")
			block(0.5, 0.42, 0.37, 0.37, 52, "spire")
		"fr_red_palace":
			var red := Color("a45e4e")
			for u in [0.17, 0.83]:
				for v in [0.19, 0.81]: block(u, v, 0.23, 0.23, 35, "spire", red)
			block(0.5, 0.49, 0.4, 0.4, 29, "flat", red)
		"fr_college_of_artillery":
			block(0.5, 0.47, 0.65, 0.55, 22, "gable")
			for u in [0.23, 0.77]: block(u, 0.24, 0.15, 0.16, 45, "flat", Color("7a7166"))
			box(Vector2(0, dimensions.y * 0.32), Vector2(5, 18), 2.0, 5.0, Color("3c4548"))
		"zh_imperial_academy":
			for u in [0.17, 0.83]: block(u, 0.5, 0.24, 0.47, 25, "pagoda")
			block(0.5, 0.24, 0.43, 0.29, 24, "gable")
		"zh_barbican":
			for u in [0.2, 0.8]: block(u, 0.65, 0.24, 0.33, 37, "pagoda")
			block(0.5, 0.34, 0.4, 0.29, 26, "flat")
		"zh_clocktower":
			block(0.5, 0.49, 0.4, 0.42, 58, "clock")
			for u in [0.17, 0.83]: block(u, 0.64, 0.18, 0.3, 17, "gable")
		"zh_imperial_palace":
			block(0.5, 0.28, 0.7, 0.32, 25, "pagoda")
			block(0.5, 0.61, 0.56, 0.32, 32, "pagoda")
		"zh_gatehouse":
			for u in [0.14, 0.86]: block(u, 0.52, 0.23, 0.37, 42, "flat")
			block(0.5, 0.45, 0.47, 0.39, 43, "pagoda")
		"zh_spirit_way":
			for u in [0.2, 0.8]: block(u, 0.62, 0.16, 0.25, 30, "flat")
			block(0.5, 0.37, 0.59, 0.31, 29, "pagoda")


extends "res://scripts/entities/visuals/landmark_visual.gd"

# A bounded set of crop states keeps working farms from rebuilding every frame.
# Crop geometry follows the actual sow/harvest cycle and lives in fog snapshots.
const CROP_STEPS := 12
static var geometry_cache: Dictionary = {}
var flat_faces: Array[Dictionary] = []

static func geometry(size: Vector2, civilization: String, fraction: float, stage: String):
	var step := clampi(roundi(fraction * CROP_STEPS), 0, CROP_STEPS)
	# English and French share the wheat field; the paddy has its own mesh.
	var key := str([size, civilization == "Chinese", step, stage])
	if not geometry_cache.has(key):
		if geometry_cache.size() >= 64: geometry_cache.clear()
		geometry_cache[key] = new(size, civilization, float(step) / CROP_STEPS, stage, 0)
	return geometry_cache[key]

func _init(size: Vector2, civilization: String, fraction: float, stage: String, variation: int) -> void:
	set_world_dimensions(size)
	var rice := civilization == "Chinese"
	var amount := clampf(fraction, 0.0, 1.0)
	var soil := Color("756044") if rice else Color("785538")
	box(Vector2.ZERO, dimensions * 0.96, 0.0, 1.1, soil.darkened(0.12))
	# Low earth ridges leave clear access around the crop; no square picture frame.
	for side in [-1.0, 1.0]:
		box(Vector2(0, side * dimensions.y * 0.46), Vector2(dimensions.x * 0.94, 2.2), 1.1, 0.9, soil.lightened(0.22))
		box(Vector2(side * dimensions.x * 0.46, 0), Vector2(2.0, dimensions.y * 0.88), 1.1, 0.7, soil.lightened(0.12))
	for row in 6:
		var y := (float(row) / 5.0 - 0.5) * dimensions.y * 0.73
		var ridge := Vector2(dimensions.x * 0.82, 2.6)
		box(Vector2(0, y), ridge, 1.15, 0.65, soil.lightened(0.08))
		# Irrigation glints in the narrow channels of the Chinese paddy.
		box(Vector2(0, y + 2.0), Vector2(dimensions.x * 0.8, 1.35), 1.18, 0.02, Color("6e9281") if rice else soil.darkened(0.27))
		for column in 8:
			var index := row * 8 + column
			var jitter := float((index * 17 + variation * 7) % 11 - 5) * 0.11
			var x := (float(column) / 7.0 - 0.5) * dimensions.x * 0.75 + jitter
			var position := Vector3(x, y + jitter, 1.85)
			var planted := clampf(amount * 6.0 - row, 0.0, 1.0)
			if stage == "harvesting":
				planted = 1.0 if float(index) / 48.0 < amount else 0.0
			if planted <= 0.01:
				if stage == "harvesting": _stubble(position, rice)
				continue
			var maturity := 1.0 if stage == "harvesting" else clampf(amount * 1.5 - row * 0.07, 0.0, 1.0)
			var height := lerpf(2.6, 7.4 if rice else 8.6, maturity) * (0.6 + planted * 0.4)
			var green := Color("728e48") if rice else Color("879651")
			var ripe := Color("bfac58") if rice else Color("d0b463")
			var foliage := green.lerp(ripe, smoothstep(0.42, 1.0, maturity))
			var leaf_span := 1.75 if rice else 1.4
			_stalk(position, height, leaf_span, foliage, maturity, index)
	prepare()
	for polygon in ordered_faces:
		var points := PackedVector2Array()
		for p in polygon["points"]: points.append(Vector2(p.x, p.y))
		if not Geometry2D.triangulate_polygon(points).is_empty(): flat_faces.append({"points": points, "color": polygon["color"]})

func _stalk(p: Vector3, height: float, span: float, color: Color, maturity: float, index: int) -> void:
	var lean := 0.45 if index % 2 == 0 else -0.35
	var top := p + Vector3(lean, 0, height)
	face([p + Vector3(-0.3, 0, 0), p + Vector3(0.3, 0, 0), top + Vector3(0.25, 0, 0), top - Vector3(0.25, 0, 0)], color.darkened(0.14))
	for side in [-1.0, 1.0]:
		var root := p + Vector3(0, 0.015, height * (0.35 if side < 0 else 0.56))
		face([root, root + Vector3(side * span, 0, height * 0.2), root + Vector3(side * span * 0.8, 0.9, height * 0.12)], color.lightened(0.09 if side < 0 else 0.0))
	if maturity > 0.4:
		var grain := color.lightened(0.15)
		face([top + Vector3(-0.8, 0.025, -1.5), top + Vector3(0, 0.025, -2.1), top + Vector3(0.85, 0.025, -0.6), top + Vector3(0.2, 0.025, 0.4)], grain)
		# The small angled crown also reads as grain from above.
		face([top + Vector3(-0.85, 0, -0.7), top + Vector3(0, -0.7, 0), top + Vector3(0.85, 0, -0.7), top + Vector3(0, 0.7, -1.2)], grain.darkened(0.06))

func _stubble(p: Vector3, rice: bool) -> void:
	var straw := Color("ac9e61") if rice else Color("b19a61")
	face([p + Vector3(-0.5, 0, 0), p + Vector3(0.5, 0, 0), p + Vector3(0.3, 0, 1.4), p + Vector3(-0.3, 0, 1.6)], straw)
	face([p + Vector3(-1.1, -0.45, 0.1), p + Vector3(0.9, -0.45, 0.1), p + Vector3(1.3, 0.45, 0.1), p + Vector3(-0.7, 0.45, 0.1)], straw.darkened(0.15))

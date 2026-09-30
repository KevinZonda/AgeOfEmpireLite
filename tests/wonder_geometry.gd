extends SceneTree

const Geometry = preload("res://scripts/entities/visuals/landmark_visual.gd")
const Wonder = preload("res://scripts/entities/visuals/wonder_visual.gd")
const VIEW := Vector3(1, 1, sqrt(0.5))
var failures := 0
var checked := 0

func _project(p: Vector3) -> Vector2:
	return Vector2((p.x - p.y) * sqrt(0.5), (p.x + p.y) * sqrt(0.125) - p.z)

func _triangles(faces: Array) -> Array:
	var result: Array = []
	for polygon in faces:
		var points: PackedVector3Array = polygon["points"]
		for i in range(1, points.size() - 1):
			var a := _project(points[0])
			var b := _project(points[i])
			var c := _project(points[i + 1])
			var denominator := (b - a).cross(c - a)
			if absf(denominator) < 0.00001: continue
			result.append([a, b, c, denominator, points[0].dot(VIEW), points[i].dot(VIEW), points[i + 1].dot(VIEW), polygon["color"]])
	return result

func _visible(point: Vector2, triangles: Array, depth_test: bool) -> Color:
	var color := Color.TRANSPARENT
	var best := -INF
	for t in triangles:
		var relative: Vector2 = point - t[0]
		var u: float = relative.cross(t[2] - t[0]) / t[3]
		var v: float = (t[1] - t[0]).cross(relative) / t[3]
		if u < 0.0001 or v < 0.0001 or u + v > 0.9999: continue
		var depth: float = (1.0 - u - v) * t[4] + u * t[5] + v * t[6]
		if not depth_test or depth >= best - 0.00001:
			best = depth
			color = t[7]
	return color

func _initialize() -> void:
	for civilization in ["English", "French", "Chinese"]:
		var g = Geometry.new()
		g.dimensions = Vector2(118, 118)
		assert(Wonder.populate(g, civilization, Color.CORNFLOWER_BLUE))
		var started := Time.get_ticks_usec()
		g.prepare()
		var prepare_us := Time.get_ticks_usec() - started
		var source := _triangles(g.faces)
		var ordered := _triangles(g.ordered_faces)
		var rng := RandomNumberGenerator.new()
		rng.seed = 20260930
		var mismatches := 0
		for i in 650:
			var point := Vector2(rng.randf_range(-110, 110), rng.randf_range(-150, 70))
			var expected := _visible(point, source, true)
			var actual := _visible(point, ordered, false)
			if expected.a == 0 and actual.a == 0: continue
			checked += 1
			if not expected.is_equal_approx(actual): mismatches += 1
		if mismatches > 0: failures += 1
		print("WONDER_%s %s wrong_pixels=%d faces=%d fragments=%d prepare_us=%d" % ["PASS" if mismatches == 0 else "FAIL", civilization, mismatches, g.faces.size(), g.ordered_faces.size(), prepare_us])
	print("WONDER_GEOMETRY_%s visible_samples=%d" % ["OK" if failures == 0 else "FAILED", checked])
	quit(1 if failures else 0)

extends SceneTree

const Visual = preload("res://scripts/entities/visuals/landmark_visual.gd")
const PALETTE = {"wall": Color("cbbd99"), "roof": Color("75564a"), "roof_dark": Color("503b37"), "trim": Color("e3d0a0")}
const VIEW := Vector3(1, 1, 0.70710678)
var failures := 0
var samples_checked := 0
var preparation_us := 0

func project(p: Vector3) -> Vector2:
	return Vector2((p.x - p.y) * sqrt(0.5), (p.x + p.y) * sqrt(0.125) - p.z)

func triangles(faces: Array) -> Array:
	var result: Array = []
	for face in faces:
		var points: PackedVector3Array = face["points"]
		for i in range(1, points.size() - 1):
			var a := project(points[0])
			var b := project(points[i])
			var c := project(points[i + 1])
			var denominator := (b - a).cross(c - a)
			if absf(denominator) < 0.00001: continue
			result.append([a, b, c, denominator, points[0].dot(VIEW), points[i].dot(VIEW), points[i + 1].dot(VIEW), face["color"]])
	return result

func visible_at(point: Vector2, surfaces: Array, use_depth: bool) -> Color:
	var color := Color.TRANSPARENT
	var best := -INF
	for triangle in surfaces:
		var relative: Vector2 = point - triangle[0]
		var u: float = relative.cross(triangle[2] - triangle[0]) / triangle[3]
		var v: float = (triangle[1] - triangle[0]).cross(relative) / triangle[3]
		if u < 0.00001 or v < 0.00001 or u + v > 0.99999: continue
		var depth: float = (1.0 - u - v) * triangle[4] + u * triangle[5] + v * triangle[6]
		if not use_depth or depth >= best - 0.00001:
			best = depth
			color = triangle[7]
	return color

func verify(mesh, label: String, sample_scale := 1.0) -> void:
	var source := triangles(mesh.faces)
	var painted := triangles(mesh.ordered_faces)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260929
	var errors := 0
	for i in 700:
		# Preserve coverage of the entire model after its dimensions change.
		var point := Vector2(rng.randf_range(-110, 110), rng.randf_range(-150, 70)) * sample_scale
		var expected := visible_at(point, source, true)
		var actual := visible_at(point, painted, false)
		if expected.a == 0.0 and actual.a == 0.0: continue
		samples_checked += 1
		if not expected.is_equal_approx(actual): errors += 1
	if errors > 0: failures += 1
	print("POC_%s %s wrong_pixels=%d faces=%d fragments=%d" % ["PASS" if errors == 0 else "FAIL", label, errors, mesh.faces.size(), mesh.ordered_faces.size()])

func verify_battlement_ring(style: String) -> void:
	var mesh = Visual.new()
	mesh.dimensions = Vector2(40, 32)
	mesh.palette = PALETTE
	mesh.block(0.5, 0.5, 1.0, 1.0, 24.0, style)
	var sides := [0, 0, 0, 0]
	var tops: Array[Rect2] = []
	for face in mesh.faces:
		var points: PackedVector3Array = face["points"]
		if not points.size() == 4: continue
		if not points[0].z == 28.0 or not points[1].z == 28.0 or not points[2].z == 28.0 or not points[3].z == 28.0: continue
		var bounds := Rect2(Vector2(points[0].x, points[0].y), Vector2.ZERO)
		for p in points: bounds = bounds.expand(Vector2(p.x, p.y))
		tops.append(bounds)
		var center := bounds.get_center()
		if center.x < -16: sides[0] += 1
		if center.x > 16: sides[1] += 1
		if center.y < -12: sides[2] += 1
		if center.y > 12: sides[3] += 1
	var complete: bool = sides.all(func(count: int) -> bool: return count >= 3)
	for i in tops.size():
		for j in range(i + 1, tops.size()):
			if tops[i].intersects(tops[j]): complete = false
	if not complete: failures += 1
	print("POC_%s %s_four_sided_battlements sides=%s" % ["PASS" if complete else "FAIL", style, sides])

func _initialize() -> void:
	var started := Time.get_ticks_usec()
	verify_battlement_ring("flat")
	verify_battlement_ring("clock")
	for id in RtsLandmarkCatalog.LANDMARKS:
		var mesh = Visual.new()
		mesh.set_world_dimensions(RtsLandmarkCatalog.LANDMARK_SIZE)
		mesh.palette = PALETTE
		mesh.populate("landmark", id, Color.BLUE)
		var preparation_start := Time.get_ticks_usec()
		mesh.prepare()
		preparation_us += Time.get_ticks_usec() - preparation_start
		verify(mesh, id, GameData.BUILDING_SCALE)
	var wonder = Visual.new()
	wonder.set_world_dimensions(GameData.BUILDINGS["wonder"]["size"])
	wonder.palette = PALETTE
	wonder.populate("wonder", "", Color.BLUE)
	var preparation_start := Time.get_ticks_usec()
	wonder.prepare()
	preparation_us += Time.get_ticks_usec() - preparation_start
	verify(wonder, "wonder", GameData.BUILDING_SCALE)
	# An intersection where sorting whole objects by their center cannot work.
	var crossed = Visual.new()
	crossed.box(Vector2.ZERO, Vector2(90, 20), 0, 40, Color.RED)
	crossed.box(Vector2.ZERO, Vector2(20, 90), 0, 30, Color.BLUE)
	crossed.prepare()
	verify(crossed, "crossed_wings")
	crossed.faces.reverse()
	crossed.prepare()
	verify(crossed, "crossed_wings_reversed_submission")
	print("LANDMARK_OCCLUSION samples=%d failures=%d elapsed_ms=%.1f" % [samples_checked, failures, (Time.get_ticks_usec() - started) / 1000.0])
	print("LANDMARK_PREPARATION total_ms=%.2f models=19" % (preparation_us / 1000.0))
	quit(1 if failures else 0)

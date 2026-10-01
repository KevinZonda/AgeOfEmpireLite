extends "res://tests/landmark_occlusion.gd"

const Refined = preload("res://scripts/entities/visuals/refined_building_geometry.gd")
const COLORS = {"wall": Color("cbbd99"), "timber": Color("674c39"), "roof": Color("75564a"), "roof_dark": Color("503b37"), "trim": Color("e3d0a0")}

# BSP regards these depths as coplanar; floating-point interpolation of a
# source triangle versus its split fragments can otherwise differ by 4e-5.
# Keep exact color comparisons and the painter's later-submitted tie policy.
func visible_at(point: Vector2, surfaces: Array, use_depth: bool) -> Color:
	var color := Color.TRANSPARENT
	var best := -INF
	for triangle in surfaces:
		var relative: Vector2 = point - triangle[0]
		var u: float = relative.cross(triangle[2] - triangle[0]) / triangle[3]
		var v: float = (triangle[1] - triangle[0]).cross(relative) / triangle[3]
		if u < 0.00001 or v < 0.00001 or u + v > 0.99999: continue
		var depth: float = (1.0 - u - v) * triangle[4] + u * triangle[5] + v * triangle[6]
		if not use_depth or depth >= best - Refined.EPSILON * GameData.BUILDING_SCALE:
			best = depth
			color = triangle[7]
	return color

func verify_coplanar_beam(mesh) -> void:
	# Preserve the old unscaled sample that exposed the depth-tie ambiguity.
	var point := Vector2(15.39806, -28.71364)
	var expected := visible_at(point, triangles(mesh.faces), true)
	var actual := visible_at(point, triangles(mesh.ordered_faces), false)
	assert(expected.is_equal_approx(COLORS["timber"]), "the later coplanar timber face wins the depth tie")
	assert(actual.is_equal_approx(expected), "BSP fragments preserve coplanar submission order")

func verify_target_faces(mesh) -> void:
	var source := triangles(mesh.faces)
	var painted := triangles(mesh.ordered_faces)
	for target in [[0.80, 0.34, 15.0, 6.0], [0.80, 0.61, 15.0, 6.0], [0.80, 0.88, 15.0, 6.0]]:
		# Refined geometry lowers the authored model by two units, then
		# scales every axis. mesh.dimensions already contains the final scale.
		var center: Vector3 = mesh.p(target[0], target[1], (target[2] - 2.0) * GameData.BUILDING_SCALE)
		var radius: float = target[3] * GameData.BUILDING_SCALE
		# Samples include the lower rings formerly covered by the wooden stem.
		for sample in [
			[Vector2(0.07, -0.04), mesh.accent.darkened(0.12)],
			[Vector2(0.22, -0.23), Color("d7c996")],
			[Vector2(0.13, -0.83), Color("ccbb86")],
		]:
			var at: Vector3 = center + Vector3(1, -1, 0).normalized() * sample[0].x * radius + Vector3(0, 0, sample[0].y * radius)
			assert(visible_at(project(at), source, true).is_equal_approx(sample[1]), "target rings must remain visible in front of their supports")
			assert(visible_at(project(at), painted, false).is_equal_approx(sample[1]), "painted target must show a complete disk and bullseye")

func _initialize() -> void:
	var polygons := 0
	for civilization in ["English", "French", "Chinese"]:
		for kind in ["barracks", "archery_range", "stable", "scout_camp"]:
			for variant in 1:
				var mesh := Refined.new(kind, GameData.BUILDINGS[kind]["size"], civilization, Color("4e9bea"), variant, COLORS)
				for polygon in mesh.portrait_faces:
					assert(not Geometry2D.triangulate_polygon(polygon["points"]).is_empty(), "BSP fragment must remain drawable")
					polygons += 1
				verify(mesh, "%s_%s_%d" % [civilization, kind, variant], GameData.BUILDING_SCALE)
				if kind == "barracks": verify_coplanar_beam(mesh)
				if kind == "archery_range": verify_target_faces(mesh)
	print("MILITARY_BUILDING_OCCLUSION polygons=%d visible_samples=%d failures=%d" % [polygons, samples_checked, failures])
	quit(1 if failures else 0)

extends SceneTree

const Visual = preload("res://scripts/entities/visuals/landmark_visual.gd")
const State = preload("res://scripts/entities/visuals/building_visual_state.gd")

func _initialize() -> void:
	var polygon_count := 0
	var meshes: Array = []
	var palette := {"wall": Color("cbbd99"), "roof": Color("75564a"), "roof_dark": Color("503b37"), "trim": Color("e3d0a0")}
	var canvas := Transform2D(Vector2(0.70710678, 0.35355339) * 1.65, Vector2(-0.70710678, 0.35355339) * 1.65, Vector2.ZERO)
	for id in RtsLandmarkCatalog.LANDMARKS:
		var mesh = Visual.new()
		mesh.set_world_dimensions(RtsLandmarkCatalog.LANDMARK_SIZE)
		mesh.palette = palette.duplicate()
		mesh.populate("landmark", id, Color.BLUE)
		mesh.prepare()
		assert(mesh.faces.size() >= 60, "landmarks need their own architecture")
		for other in meshes: assert(mesh.faces != other, "landmarks must have distinct models")
		meshes.append(mesh.faces)
		for face in mesh.projected_faces(canvas, 1.65, Vector2.ZERO):
			assert(not Geometry2D.triangulate_polygon(face["points"]).is_empty(), "invalid rendered face in %s: %s" % [id, face["points"]])
			polygon_count += 1
	# Ensure small windows still form convex arches, and high features clear badges.
	var state := State.new()
	state.kind = "landmark"
	assert(state.isometric_height() <= 6.0, "the generic pedestal must remain low")
	state.kind = "stone_gate"
	assert(state.isometric_height() + state.visual_feature_height() >= 31.4)
	state.kind = "palisade_gate"
	assert(state.isometric_height() + state.visual_feature_height() >= 25.8)
	state.kind = "outpost"
	assert(state.isometric_height() + state.visual_feature_height() >= 49.7)
	print("ARCHITECTURE_REDRAW_GEOMETRY_OK: 18 distinct landmarks, ", polygon_count, " valid projected polygons")
	quit()

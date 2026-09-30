extends "res://tests/landmark_occlusion.gd"

const SacredGeometry = preload("res://scripts/entities/visuals/sacred_site_geometry.gd")
const Preview = preload("res://tools/sacred_site_preview.gd")
const Manager = preload("res://scripts/match/objective_manager.gd")

class FogStub extends Node2D:
	var active := true
	var point_visible := false
	func can_see(_owner_id: int, _point: Vector2) -> bool: return point_visible

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var polygons := 0
	var projected := 0
	for variation in 3:
		for color in [Color("d4c69e"), Color("4e9bea"), Color("d66557")]:
			var model := SacredGeometry.new(color, variation)
			assert(model.faces.size() > 24, "the sacred site needs stepped masonry, ruins and a flag")
			assert(not model.flat_faces.is_empty(), "topdown view must use the same ruin model")
			for polygon in model.faces:
				var points: PackedVector3Array = polygon["points"]
				var normal := (points[1] - points[0]).cross(points[2] - points[0]).normalized()
				for point in points: assert(absf(normal.dot(point - points[0])) < 0.0001, "stone, cloth and column source faces must be planar")
			for zoom in [0.7, 1.0, 1.65]:
				var canvas := Transform2D(Vector2(0.70710678, 0.35355339) * zoom, Vector2(-0.70710678, 0.35355339) * zoom, Vector2.ZERO)
				for height in [0.0, 21.0]:
					var lift := RtsIsoProjection.world_delta(canvas, Vector2(0, -height * zoom))
					var faces: Array = model.projected_faces(canvas, zoom, lift)
					assert(is_same(faces, model.projected_faces(canvas, zoom, lift)), "repeated projection must return the same cached geometry")
					for polygon in faces:
						assert(not Geometry2D.triangulate_polygon(polygon["points"]).is_empty(), "projected ruin fragment must remain drawable")
						projected += 1
			polygons += model.ordered_faces.size()
			verify(model, "sacred_ruin_%d_%s" % [variation, color.to_html()])
	var lifecycle := _verify_lifecycle()
	print("SACRED_SITE_GEOMETRY polygons=%d projected_checks=%d visible_samples=%d failures=%d lifecycle_checks=%d" % [polygons, projected, samples_checked, failures, lifecycle])
	quit(1 if failures else 0)

func _verify_lifecycle() -> int:
	var context := Preview.Context.new()
	root.add_child(context)
	context.world_map = Preview.MapStub.new()
	context.add_child(context.world_map)
	context.add_child(context.camera)
	context.camera.enabled = false
	var manager = Manager.new()
	context.add_child(manager)
	manager.set_process(false)
	var checked := 0
	for round in 4:
		var previous: Array = manager.site_visuals.duplicate()
		manager.setup(context)
		assert(manager.site_visuals.size() == 3 and manager.get_child_count() == 3, "repeated setup must not accumulate site display nodes")
		for old in previous: assert(not is_instance_valid(old), "replaced site displays must be released")
		for index in 3:
			var visual = manager.site_visuals[index]
			var state: Dictionary = manager.sacred_sites[index]
			assert(visual.site == state and visual.site_index == index and visual.position == state["position"], "display must follow its actual objective record")
			visual.sync_visual()
			var neutral: Color = visual.flag_color
			var neutral_geometry = visual.geometry
			state["capture_owner"] = 0
			for progress in [1.0, 4.0, 7.0]:
				state["capture_progress"] = progress
				visual.sync_visual()
				assert(visual.flag_color == neutral and visual.geometry == neutral_geometry, "capture progress must retain the current owner flag and model")
				checked += 1
			state["owner_id"] = 0
			visual.sync_visual()
			assert(visual.flag_color == context.player_color(0), "finished capture must use the capturing player flag color")
			var blue_geometry = visual.geometry
			state["contested"] = true
			visual.sync_visual()
			assert(visual.flag_color == context.player_color(0) and visual.geometry == blue_geometry, "contested overlay must not recolor the owner flag or rebuild geometry")
			for isometric in [false, true]:
				context.view_mode_25d = isometric
				for zoom in [0.7, 1.0, 1.65]:
					context.camera.zoom = Vector2(zoom, zoom * 0.5 if isometric else zoom)
					context.world_map.ground_height = 21.0
					visual.sync_visual()
					assert(visual.geometry == blue_geometry, "view, terrain height and zoom changes must reuse the model")
					checked += 1
			state["owner_id"] = 1
			visual.sync_visual()
			assert(visual.flag_color == context.player_color(1), "owner change must replace flag color")
			checked += 4
		var reset_ids: Array = manager.site_visuals.map(func(visual): return visual.get_instance_id())
		manager.reset()
		assert(manager.site_visuals.map(func(visual): return visual.get_instance_id()) == reset_ids, "match reset should preserve display nodes")
		for visual in manager.site_visuals:
			assert(visual.site["owner_id"] == -1 and visual.site["capture_owner"] == -1 and visual.site["capture_progress"] == 0.0 and not visual.site["contested"])
			assert(visual.flag_color != context.player_color(0) and visual.flag_color != context.player_color(1), "reset must restore neutral ownership and flag")
			checked += 1
	var fog := FogStub.new()
	context.fog = fog
	context.add_child(fog)
	var site_visual = manager.site_visuals[0]
	site_visual.sync_visual()
	assert(site_visual.visible and site_visual.modulate.r < 1.0, "known objective ruins should stay visible but dim in unseen fog")
	fog.point_visible = true
	site_visual.sync_visual()
	assert(site_visual.modulate == Color.WHITE, "visible site must clear its fog dimming")
	checked += 2
	context.free()
	return checked

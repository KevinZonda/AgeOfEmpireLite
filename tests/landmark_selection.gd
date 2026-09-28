extends SceneTree

const Preview = preload("res://tests/landmark_rendering.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var context := Preview.PreviewContext.new()
	root.add_child(context)
	context.camera.enabled = false
	context.add_child(context.camera)
	var ids: Array = RtsLandmarkCatalog.LANDMARKS.keys()
	ids.append_array(["wonder_English", "wonder_French", "wonder_Chinese"])
	var checked := 0
	for id in ids:
		var wonder: bool = id.begins_with("wonder_")
		context.civilizations[0] = id.trim_prefix("wonder_") if wonder else RtsLandmarkCatalog.LANDMARKS[id]["civilization"]
		var building := RtsBuilding.new()
		context.add_child(building)
		building.setup(context, 0, "wonder" if wonder else "landmark", false, "" if wonder else id)
		for zoom in [0.7, 1.0, 1.65]:
			context.camera.zoom = Vector2(zoom, zoom * 0.5)
			var canvas := Transform2D(Vector2(0.70710678, 0.35355339) * zoom, Vector2(-0.70710678, 0.35355339) * zoom, Vector2.ZERO)
			root.canvas_transform = canvas
			for completed in [0.75, 1.0]:
				building.build_remaining = building.build_total * (1.0 - completed)
				var lift := RtsIsoProjection.world_delta(canvas, Vector2(0, -building.isometric_height() * (0.25 + 0.75 * completed) * zoom))
				var geometry = building._landmark_geometry()
				var faces: Array = geometry.projected_faces(canvas, zoom, lift)
				for face in faces:
					var center := Vector2.ZERO
					for p in face["points"]: center += p
					center /= face["points"].size()
					assert(building.contains_isometric_visual(building.position + center, canvas), "%s: displayed face must remain clickable" % id)
					checked += 1
				assert(building._landmark_geometry() == geometry, "drawing and hit testing must reuse prepared geometry")
				var icon_height: float = building.isometric_height() * (0.25 + 0.75 * completed) + building._landmark_extra_height()
				var icon_point := building.position + RtsIsoProjection.world_delta(canvas, Vector2(0, -icon_height * zoom - building.icon_size() * 0.5 - 9.0))
				assert(building.contains_icon_visual(icon_point, canvas))
				context.show_building_icons = false
				assert(not building.contains_icon_visual(icon_point, canvas), "hidden badges must not intercept clicks")
				context.show_building_icons = true
		context.view_mode_25d = false
		var topdown_icon := building.position + Vector2(0, -building.size().y * 0.5 - building.icon_size() * 0.5 - 8.0)
		assert(building.contains_icon_visual(topdown_icon, Transform2D.IDENTITY))
		context.show_building_icons = false
		assert(not building.contains_icon_visual(topdown_icon, Transform2D.IDENTITY))
		context.show_building_icons = true
		context.view_mode_25d = true
		building.free()
	context.free()
	print("LANDMARK_SELECTION_OK face_centers=%d across 21 appearances, 3 zooms, 2 construction stages" % checked)
	quit()

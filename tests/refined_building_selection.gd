extends SceneTree

const Preview = preload("res://tools/building_refinement_preview.gd")
const Renderer = preload("res://scripts/entities/visuals/building_visual.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var context := Preview.Context.new()
	root.add_child(context)
	context.add_child(context.camera)
	context.camera.enabled = false
	var checked := 0
	for civ in ["English", "French", "Chinese"]:
		context.civilizations[0] = civ
		for kind in ["house", "blacksmith", "market"]:
			for variant in (3 if kind == "house" else 1):
				var building := RtsBuilding.new()
				for i in 100:
					var point := Vector2(i * 43 + 7, i * 19 + 11)
					if absi(hash(point)) % 3 == variant:
						building.position = point
						break
				context.add_child(building)
				building.setup(context, 0, kind)
				building.set_process(false)
				building.hide()
				var snapshot = building.visual_snapshot()
				building.building_visual.state = snapshot
				var geometry = building.building_visual._refined_geometry()
				# Remembered buildings recreate the same fixed house variant.
				var remembered := Renderer.new()
				remembered.state = snapshot
				assert(remembered._refined_geometry().portrait_faces == geometry.portrait_faces)
				for zoom in [0.7, 1.0, 1.65]:
					context.camera.zoom = Vector2(zoom, zoom * 0.5)
					var canvas := Transform2D(Vector2(0.70710678, 0.35355339) * zoom, Vector2(-0.70710678, 0.35355339) * zoom, Vector2.ZERO)
					root.canvas_transform = canvas
					for completed in [0.75, 1.0]:
						building.build_remaining = building.build_total * (1.0 - completed)
						for polygon in geometry.projected_faces(canvas, zoom, Vector2.ZERO):
							var center := Vector2.ZERO
							for point in polygon["points"]: center += point
							center /= polygon["points"].size()
							assert(building.contains_isometric_visual(building.position + center, canvas), "displayed chimney, roof and furniture must remain selectable")
							checked += 1
						assert(building.building_visual._refined_geometry() == geometry, "camera and construction progress must reuse the cached mesh")
				building.free()
	context.free()
	print("REFINED_BUILDING_SELECTION_OK: ", checked, " face centers, 15 appearances")
	quit()

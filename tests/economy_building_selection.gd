extends SceneTree

const Preview = preload("res://tools/economy_building_refinement_preview.gd")
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
		for kind in Preview.KINDS:
			var building := RtsBuilding.new()
			context.add_child(building)
			building.setup(context, 0, kind)
			building.set_process(false)
			building.hide()
			var snapshot = building.visual_snapshot()
			building.building_visual.state = snapshot
			var geometry = building.building_visual._refined_geometry()
			var frame := Rect2(Vector2(17, 20), Vector2(96, 130))
			var bounds: Rect2 = geometry.portrait_bounds
			assert(bounds.has_area(), "economy portraits must contain visible geometry")
			var fit := minf(frame.size.x / bounds.size.x, frame.size.y / bounds.size.y)
			var origin := frame.get_center() - bounds.get_center() * fit
			for polygon in geometry.portrait_faces:
				for point in polygon["points"]:
					assert(frame.grow(0.001).has_point(point * fit + origin), "portrait roofs and machinery must fit without clipping")
			# Fog memory retains the same civilization and production equipment geometry.
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
						assert(building.contains_isometric_visual(building.position + center, canvas), "displayed roof, stores and machinery must remain selectable")
						checked += 1
					assert(building.building_visual._refined_geometry() == geometry, "camera and construction progress must reuse the cached mesh")
					# Test the highest model face, not a generic wall-height estimate.
					var raised = building.visual_snapshot()
					raised.foundation_height = 21.0
					raised.show_building_icons = true
					var side: float = raised.icon_size()
					var icon_screen := Vector2(0, -(geometry.height_above_origin + raised.foundation_height) * zoom - side * 0.5 - 9.0)
					var icon_world := building.position + RtsIsoProjection.world_delta(canvas, icon_screen)
					assert(building.building_visual.contains_icon_visual(raised, icon_world, canvas), "raised-ground icon must remain selectable at the true model top")
					assert(not building.building_visual.contains_icon_visual(raised, icon_world + RtsIsoProjection.world_delta(canvas, Vector2(side, 0)), canvas), "icon hit rectangle must reject adjacent empty space")
					var terrain := RtsIsoProjection.world_delta(canvas, Vector2(0, -raised.foundation_height * zoom))
					for polygon in geometry.projected_faces(canvas, zoom, terrain):
						var center := Vector2.ZERO
						for point in polygon["points"]: center += point
						center /= polygon["points"].size()
						assert(building.building_visual.contains_isometric_visual(raised, building.position + center, canvas), "raised-ground faces must remain selectable")
						checked += 1
			building.free()
	context.free()
	print("ECONOMY_BUILDING_SELECTION_OK: ", checked, " face centers, 15 appearances")
	quit()

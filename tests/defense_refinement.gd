extends SceneTree

const State = preload("res://scripts/entities/visuals/building_visual_state.gd")
const Visual = preload("res://scripts/entities/visuals/building_visual.gd")
const Defense = preload("res://scripts/entities/visuals/keep_monastery_visual.gd")

func _initialize() -> void:
	var probes := 0
	var portrait_count := 0
	for civ in ["English", "French", "Chinese"]:
		for kind in ["keep", "outpost", "stone_wall", "stone_gate", "palisade_wall", "palisade_gate"]:
			for vertical in [false, true]:
				var state = State.new()
				state.kind = kind
				state.dimensions = GameData.BUILDINGS[kind]["size"]
				if vertical and (kind.ends_with("_wall") or kind.ends_with("_gate")): state.dimensions = Vector2(state.dimensions.y, state.dimensions.x)
				state.wall_vertical = vertical
				state.civilization = civ
				state.world_position = Vector2(120, 160)
				state.view_mode_25d = true
				state.show_building_icons = true
				var visual = Visual.new()
				var portrait: Rect2 = visual.defense_portrait_bounds(state)
				assert(portrait.size.x > 0 and portrait.size.y > 0)
				for zoom in [0.6, 1.0, 2.0]:
					state.zoom = zoom
					assert(visual.defense_portrait_bounds(state).is_equal_approx(portrait), "HUD portrait must not change with camera zoom")
					var canvas := Transform2D(Vector2(0.70710678, 0.35355339) * zoom, Vector2(-0.70710678, 0.35355339) * zoom, Vector2.ZERO)
					for elevation in [0.0, 19.0]:
						state.foundation_height = elevation
						var terrain := RtsIsoProjection.world_delta(canvas, Vector2(0, -elevation * zoom))
						visual.state = state
						var badge_height: float = visual._visible_height(1.0)
						var badge: Vector2 = state.world_position + terrain + RtsIsoProjection.world_delta(canvas, Vector2(0, -badge_height * zoom - state.icon_size() * 0.5 - 9.0))
						assert(visual.contains_icon_visual(state, badge, canvas), "badge missed after foundation/roof refinement")
						if kind in ["keep", "outpost"]:
							var badge_bottom: float = -badge_height * zoom - 9.0
							for point in Defense.selection_hull(state, canvas):
								assert(canvas.basis_xform(point).y - badge_bottom >= 8.99, "HUD badge overlaps defense roof")
						assert(not visual.contains_isometric_visual(state, state.world_position + terrain + RtsIsoProjection.world_delta(canvas, Vector2(0, -160.0 * zoom)), canvas))
						if civ == "Chinese" and kind in ["keep", "outpost"]:
							for face in Defense.chinese_roof_faces(state, canvas):
								var points: PackedVector2Array = face["points"]
								assert(not Geometry2D.triangulate_polygon(points).is_empty(), "curved roof must triangulate at every zoom")
								var center := (points[0] + points[1] + points[2]) / 3
								assert(visual.contains_isometric_visual(state, state.world_position + terrain + center, canvas), "roof overhang must be selectable on slopes")
								for point in points:
									assert(portrait.has_point(canvas.basis_xform(point) / zoom), "curved roof clipped in HUD")
								probes += 1
						if civ != "Chinese" and kind == "outpost":
							for face in Defense.outpost_roof_faces(state, canvas):
								var points: PackedVector2Array = face["points"]
								assert(not Geometry2D.triangulate_polygon(points).is_empty(), "hip roof must triangulate")
								var center := (points[0] + points[1] + points[2]) / 3
								assert(visual.contains_isometric_visual(state, state.world_position + terrain + center, canvas), "taller hip roof must be selectable")
								for point in points: assert(portrait.has_point(canvas.basis_xform(point) / zoom), "taller hip roof clipped in HUD")
								probes += 1
						if kind.ends_with("_wall"):
							var footprint := Rect2(-state.dimensions * 0.5, state.dimensions)
							var depth := Vector2(state.dimensions.x, 0) if vertical else Vector2(0, state.dimensions.y)
							var along := Vector2(0, state.dimensions.y) if vertical else Vector2(state.dimensions.x, 0)
							for t in [0.15, 0.55, 0.85]:
								var point: Vector2 = footprint.position + along * t + depth * 0.71 + RtsIsoProjection.world_delta(canvas, Vector2(0, -13.0 * zoom))
								assert(visual.contains_isometric_visual(state, state.world_position + terrain + point, canvas), "raised wall top missed")
								probes += 1
				portrait_count += 1
	# All eighteen detailed landmark models now feed the actual HUD frame.
	for id in RtsLandmarkCatalog.LANDMARKS:
		var state = State.new()
		state.kind = "landmark"
		state.landmark_id = id
		state.civilization = RtsLandmarkCatalog.LANDMARKS[id]["civilization"]
		state.dimensions = RtsLandmarkCatalog.LANDMARK_SIZE
		var visual = Visual.new()
		visual._cache_civic_portrait(state)
		var frame := Rect2(Vector2(17, 20), Vector2(96, 130))
		var bounds: Rect2 = visual.civic_portrait_bounds
		assert(visual.civic_portrait_faces.size() > 40, "landmark portrait must use its detailed model")
		var fit := minf(frame.size.x / bounds.size.x, frame.size.y / bounds.size.y)
		var origin := frame.get_center() - bounds.get_center() * fit
		for face in visual.civic_portrait_faces:
			for point in face["points"]: assert(frame.grow(0.001).has_point(point * fit + origin), "landmark portrait is cropped")
		portrait_count += 1
	print("DEFENSE_REFINEMENT_OK roof/wall probes=%d portraits=%d across civilizations, rotations, zooms and elevations" % [probes, portrait_count])
	quit()

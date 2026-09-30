extends SceneTree
const State = preload("res://scripts/entities/visuals/building_visual_state.gd")
const Visual = preload("res://scripts/entities/visuals/building_visual.gd")
func _initialize() -> void:
	var count := 0
	for kind in ["stone_gate", "palisade_gate"]:
		for vertical in [false, true]:
			for zoom in [0.6, 1.0, 2.0]:
				for elevation in [0.0, 9.0]:
					var state = State.new()
					state.kind = kind
					state.dimensions = Vector2(25, 75) if vertical else Vector2(75, 25)
					state.wall_vertical = vertical
					state.world_position = Vector2(120, 160)
					state.view_mode_25d = true
					state.zoom = zoom
					state.foundation_height = elevation
					var canvas := Transform2D(Vector2(0.70710678, 0.35355339) * zoom, Vector2(-0.70710678, 0.35355339) * zoom, Vector2.ZERO)
					var up := RtsIsoProjection.world_delta(canvas, Vector2(0, -11.0 * zoom))
					var terrain := RtsIsoProjection.world_delta(canvas, Vector2(0, -elevation * zoom))
					var bounds := Rect2(-state.dimensions * 0.5, state.dimensions)
					var nw := bounds.position
					var ne := Vector2(bounds.end.x, bounds.position.y)
					var sw := Vector2(bounds.position.x, bounds.end.y)
					var along := sw - nw if vertical else ne - nw
					var depth := ne - nw if vertical else sw - nw
					var visual = Visual.new()
					for t in [0.26, 0.74]:
						var h := 2.72 if kind == "stone_gate" else 2.25
						var top_point: Vector2 = state.world_position + nw + along * t + depth * 0.65 + up * h + terrain
						assert(visual.contains_isometric_visual(state, top_point, canvas), "%s gate top missed: v=%s zoom=%s elevation=%s" % [kind, vertical, zoom, elevation])
						count += 1
					var outside: Vector2 = state.world_position + terrain + RtsIsoProjection.world_delta(canvas, Vector2(0, -150.0 * zoom))
					assert(not visual.contains_isometric_visual(state, outside, canvas), "far above gate should miss")
	# Tower roofs and early landmark scaffolds must remain selectable on slopes.
	for kind in ["keep", "outpost", "landmark"]:
		for zoom in [0.7, 1.0, 2.0]:
			for elevation in [0.0, 12.0]:
				var state = State.new()
				state.kind = kind
				state.landmark_id = "zh_clocktower" if kind == "landmark" else ""
				state.dimensions = RtsLandmarkCatalog.LANDMARK_SIZE if kind == "landmark" else GameData.BUILDINGS[kind]["size"]
				state.zoom = zoom
				state.foundation_height = elevation
				state.show_building_icons = true
				state.view_mode_25d = true
				var canvas := Transform2D(Vector2(0.70710678, 0.35355339) * zoom, Vector2(-0.70710678, 0.35355339) * zoom, Vector2.ZERO)
				var visual = Visual.new()
				visual.state = state
				if kind == "landmark":
					state.build_total = 100.0
					state.build_remaining = 60.0
					var height: float = visual._visible_height(0.4)
					assert(height > 15.0, "early scaffolds must describe the future building")
					var point := RtsIsoProjection.world_delta(canvas, Vector2(0, -(height + elevation) * zoom))
					assert(visual.contains_isometric_visual(state, point, canvas), "elevated scaffold must be clickable")
					var badge := point + RtsIsoProjection.world_delta(canvas, Vector2(0, -state.icon_size() * 0.5 - 9.0))
					assert(visual.contains_icon_visual(state, badge, canvas), "scaffold badge must match its drawn position")
				else:
					var height := 59.56 if kind == "keep" else 49.74
					var point := RtsIsoProjection.world_delta(canvas, Vector2(0, -(height + elevation - 2.0) * zoom))
					assert(visual.contains_isometric_visual(state, point, canvas), "tower roof must be clickable")
				count += 1
	print("DEFENSE_VISUAL_SELECTION_OK probes=%d, gates/towers/scaffolds across zooms and elevations" % count)
	quit()

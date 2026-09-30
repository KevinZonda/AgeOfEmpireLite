extends SceneTree

const VisualState = preload("res://scripts/entities/visuals/building_visual_state.gd")
const BuildingVisual = preload("res://scripts/entities/visuals/building_visual.gd")
const DockVisual = preload("res://scripts/entities/visuals/dock_building_visual.gd")
const FilledPolygon = preload("res://scripts/entities/visuals/filled_polygon.gd")

func _initialize() -> void:
	var probes := 0
	var polygons := 0
	for civ in ["English", "French", "Chinese"]:
		for zoom in [0.6, 1.0, 2.0]:
			for elevation in [0.0, 9.0]:
				var state = VisualState.new()
				state.kind = "dock"
				state.civilization = civ
				state.dimensions = GameData.BUILDINGS["dock"]["size"]
				state.world_position = Vector2(120, 160)
				state.view_mode_25d = true
				state.zoom = zoom
				state.foundation_height = elevation
				var visual = BuildingVisual.new()
				visual.state = state
				var colors: Dictionary = visual._architecture_palette()
				var model = DockVisual.geometry(state.dimensions, colors, civ, state.player_color)
				assert(model == DockVisual.geometry(state.dimensions, colors, civ, state.player_color), "dock meshes must be shared with selection and portraits")
				assert(not model.portrait_faces.is_empty() and not model.flat_faces.is_empty())
				var canvas := Transform2D(Vector2(0.70710678, 0.35355339) * zoom, Vector2(-0.70710678, 0.35355339) * zoom, Vector2.ZERO)
				var lift := RtsIsoProjection.world_delta(canvas, Vector2(0, -zoom))
				var terrain: Vector2 = lift * elevation
				for polygon in model.projected_faces(canvas, zoom, terrain):
					var points: PackedVector2Array = polygon["points"]
					assert(FilledPolygon._is_primitive(points) or not Geometry2D.triangulate_polygon(points).is_empty(), "dock render face cannot triangulate: %s" % civ)
					polygons += 1
				# Both visible finger tips extend outside the simulation footprint.
				for u in [0.19, 0.81]:
					var point: Vector2 = state.world_position + Vector2((u - 0.5) * state.dimensions.x, 0.595 * state.dimensions.y) + lift * 4.18 + terrain
					assert(visual.contains_isometric_visual(state, point, canvas), "visible pier tip must be selectable")
					probes += 1
					var flat_point: Vector2 = state.world_position + Vector2((u - 0.5) * state.dimensions.x, 0.595 * state.dimensions.y)
					assert(visual.contains_topdown_visual(state, flat_point), "visible topdown finger must be selectable outside footprint")
					probes += 1
				var water_gap: Vector2 = state.world_position + Vector2(0, 0.59 * state.dimensions.y)
				assert(not visual.contains_topdown_visual(state, water_gap), "open water between outer finger tips must not acquire deck selection")
				# The roof ridge is also outside the ground rectangle in world-space
				# projection, so this checks mesh selection rather than footprint hit.
				var top: Vector2 = state.world_position + Vector2(-0.16 * state.dimensions.x, -0.21 * state.dimensions.y) + lift * 29.0 + terrain
				assert(visual.contains_isometric_visual(state, top, canvas), "visible warehouse roof must be selectable")
				probes += 1
				assert(not visual.contains_isometric_visual(state, state.world_position + Vector2(300, 300), canvas))
	print("DOCK_VISUAL_OK polygons=%d selection_probes=%d civilizations=3 zooms=3 elevations=2" % [polygons, probes])
	quit()

extends "res://tests/landmark_occlusion.gd"

const Gate = preload("res://scripts/entities/visuals/stone_gate_geometry.gd")
const State = preload("res://scripts/entities/visuals/building_visual_state.gd")
const BuildingVisual = preload("res://scripts/entities/visuals/building_visual.gd")
var hit_probes := 0

func _initialize() -> void:
	for civ in ["English", "French", "Chinese"]:
		for vertical in [false, true]:
			var state = State.new()
			state.kind = "stone_gate"
			state.dimensions = Vector2(25, 75) if vertical else Vector2(75, 25)
			state.wall_vertical = vertical
			state.civilization = civ
			state.player_color = Color("4e9bea")
			state.world_position = Vector2(120, 160)
			state.view_mode_25d = true
			var visual = BuildingVisual.new()
			visual.state = state
			var mesh = Gate.geometry(state.dimensions, visual._architecture_palette(), state.player_color, vertical)
			assert(mesh == Gate.geometry(state.dimensions, visual._architecture_palette(), state.player_color, vertical), "gate mesh must be shared")
			for polygon in mesh.faces: assert(is_equal_approx(polygon["color"].a, 1.0), "masonry, doors and windows must be opaque")
			verify(mesh, "%s_%s_gate" % [civ, "vertical" if vertical else "horizontal"])
			for zoom in [0.6, 1.0, 2.0]:
				state.zoom = zoom
				var canvas := Transform2D(Vector2(0.70710678, 0.35355339) * zoom, Vector2(-0.70710678, 0.35355339) * zoom, Vector2.ZERO)
				for elevation in [0.0, 19.0]:
					state.foundation_height = elevation
					var terrain := RtsIsoProjection.world_delta(canvas, Vector2(0, -elevation * zoom))
					for polygon in mesh.projected_faces(canvas, zoom, terrain):
						var points: PackedVector2Array = polygon["points"]
						assert(not Geometry2D.triangulate_polygon(points).is_empty(), "arch or wall-return fragment cannot triangulate")
						var point := Vector2.ZERO
						for p in points: point += p / points.size()
						assert(visual.contains_isometric_visual(state, state.world_position + point, canvas), "visible gate face must be selectable on slopes")
						hit_probes += 1
			visual._cache_civic_portrait(state)
			assert(visual.portrait_mesh == mesh, "HUD must use the same opaque gate geometry")
			var frame := Rect2(Vector2(17, 20), Vector2(96, 130))
			var bounds: Rect2 = visual.civic_portrait_bounds
			var fit := minf(frame.size.x / bounds.size.x, frame.size.y / bounds.size.y)
			for polygon in visual.civic_portrait_faces:
				for p in polygon["points"]:
					assert(frame.grow(0.001).has_point(frame.get_center() + (p - bounds.get_center()) * fit), "gate portrait clipped")
	print("STONE_GATE_GEOMETRY_OK depth_samples=%d failures=%d hit_probes=%d" % [samples_checked, failures, hit_probes])
	quit(1 if failures else 0)

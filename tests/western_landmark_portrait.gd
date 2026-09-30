extends SceneTree

const State = preload("res://scripts/entities/visuals/building_visual_state.gd")
const Visual = preload("res://scripts/entities/visuals/building_visual.gd")
const IDS = ["eng_council_hall", "eng_wynguard_palace", "fr_chamber_of_commerce", "fr_college_of_artillery"]

func _initialize() -> void:
	var checked := 0
	for id in IDS:
		var state = State.new()
		state.kind = "landmark"
		state.landmark_id = id
		state.civilization = RtsLandmarkCatalog.LANDMARKS[id]["civilization"]
		state.dimensions = RtsLandmarkCatalog.LANDMARK_SIZE
		state.player_color = Color("4e9bea")
		var visual = Visual.new()
		visual._cache_civic_portrait(state)
		var model = visual.portrait_mesh
		assert(model == visual._landmark_geometry(), "HUD must use the actual landmark model")
		assert(visual.civic_portrait_faces.size() > 40, "HUD must not fall back to a generic house")
		var bounds: Rect2 = visual.civic_portrait_bounds
		for zoom in [0.7, 1.0, 1.65]:
			state.zoom = zoom
			state.foundation_height = 21.0
			visual._cache_civic_portrait(state)
			assert(visual.portrait_mesh == model, "camera and terrain must not rebuild the HUD model")
			assert(visual.civic_portrait_bounds.is_equal_approx(bounds), "HUD framing must be independent of map projection")
		for frame_size in [Vector2(96, 130), Vector2(68, 102)]:
			var frame := Rect2(Vector2(17, 20), frame_size)
			var fit := minf(frame.size.x / bounds.size.x, frame.size.y / bounds.size.y)
			var origin := frame.get_center() - bounds.get_center() * fit
			for face in visual.civic_portrait_faces:
				for point in face["points"]:
					assert(frame.grow(0.001).has_point(point * fit + origin), "landmark portrait clipped")
					checked += 1
		state.player_color = Color("e86643")
		visual._cache_civic_portrait(state)
		assert(visual.portrait_mesh != model, "owner color change must refresh portrait geometry")
		assert(visual.civic_portrait_faces.any(func(face: Dictionary) -> bool: return face["color"].is_equal_approx(state.player_color)), "HUD must retain the new player's banner color")
	print("WESTERN_LANDMARK_PORTRAIT_OK vertices=", checked, " models=4")
	quit()

extends SceneTree

const State = preload("res://scripts/entities/visuals/building_visual_state.gd")
const Visual = preload("res://scripts/entities/visuals/building_visual.gd")
var samples := 0
var polygons := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var wonder_meshes: Array = []
	for civilization in ["English", "French", "Chinese"]:
		for kind in ["wonder", "university", "monastery", "dock", "farm"]:
			var state = State.new()
			state.kind = kind
			state.civilization = civilization
			state.dimensions = GameData.BUILDINGS[kind]["size"]
			state.player_color = Color.CORNFLOWER_BLUE
			state.world_position = Vector2(300, 250)
			state.crop_fraction = 1.0
			state.view_mode_25d = true
			state.build_total = 100.0
			var visual = Visual.new()
			visual.state = state
			var mesh = visual._civic_display_geometry()
			assert(mesh.faces.size() > 50, "model needs distinct architecture or crops")
			assert(visual._civic_display_geometry() == mesh, "unchanged snapshots must reuse their mesh")
			if kind == "wonder":
				for other in wonder_meshes: assert(mesh.faces != other, "wonders must have independent models")
				wonder_meshes.append(mesh.faces)
			for zoom in [0.7, 1.0, 1.8]:
				state.zoom = zoom
				var canvas := Transform2D(Vector2(0.70710678, 0.35355339) * zoom, Vector2(-0.70710678, 0.35355339) * zoom, Vector2.ZERO)
				for elevation in [0.0, 21.0]:
					state.foundation_height = elevation
					var terrain := RtsIsoProjection.world_delta(canvas, Vector2(0, -elevation * zoom))
					for ratio in [0.75, 1.0]:
						state.build_remaining = 100.0 * (1.0 - ratio)
						for polygon in mesh.projected_faces(canvas, zoom, terrain):
							assert(not Geometry2D.triangulate_polygon(polygon["points"]).is_empty(), "projected model must triangulate")
							polygons += 1
							var center := Vector2.ZERO
							for p in polygon["points"]: center += p
							center /= polygon["points"].size()
							assert(visual.contains_isometric_visual(state, state.world_position + center, canvas), "%s %s: visible surface must be selectable" % [civilization, kind])
							samples += 1
						var height: float = visual._visible_height(ratio)
						assert(is_equal_approx(height, mesh.height_above_origin), "finished badge must use exact mesh height")
						var badge := terrain + RtsIsoProjection.world_delta(canvas, Vector2(0, -height * zoom - state.icon_size() * 0.5 - 9.0))
						assert(visual.contains_icon_visual(state, state.world_position + badge, canvas))
					state.build_remaining = 60.0
					if kind != "farm":
						var top := terrain + RtsIsoProjection.world_delta(canvas, Vector2(0, -visual._visible_height(0.4) * zoom))
						assert(visual.contains_isometric_visual(state, state.world_position + top, canvas), "scaffold top must remain selectable")
			state.build_remaining = 0.0
			visual._cache_civic_portrait(state)
			assert(visual.civic_portrait_bounds.size.x > 0 and visual.civic_portrait_bounds.size.y > 0)
			for polygon in visual.civic_portrait_faces:
				for p in polygon["points"]: assert(visual.civic_portrait_bounds.grow(0.01).has_point(p), "portrait vertices must fit their frame")
			if kind == "dock":
				var tip: Vector2 = state.world_position + Vector2(-state.dimensions.x * 0.3, state.dimensions.y * 0.58)
				assert(visual.contains_topdown_visual(state, tip), "extended bridge head must be selectable in 2D")
				var empty: Vector2 = state.world_position + Vector2(0, state.dimensions.y * 0.58)
				assert(not visual.contains_topdown_visual(state, empty), "water between outer fingers must not select")
			if kind == "farm":
				var neighbor = Visual.new()
				neighbor.state = state
				assert(neighbor._farm_geometry() == mesh, "many farms at the same crop stage must share prepared geometry")
				state.crop_fraction = 0.5
				state.farm_stage = "sowing"
				var half = visual._farm_geometry()
				assert(half.faces != mesh.faces, "sowing changes crop coverage")
				state.crop_fraction += 0.00001
				assert(visual._farm_geometry() == half, "small work increments must reuse crop geometry")
				state.farm_stage = "harvesting"
				assert(visual._farm_geometry().faces != half.faces, "harvested stubble must differ from new shoots")
	# Capture the real farm cycle, then prove hidden simulation changes stay frozen.
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game("English", 12345)
	var farm: RtsBuilding = game.spawn_building(0, "farm", Vector2(400, 400))
	farm.farm_stage = "harvesting"
	farm.farm_stage_progress = farm.FARM_HARVEST_WORK * 0.5
	var memory = State.capture(farm)
	var remembered = Visual.new()
	remembered.state = memory
	var frozen_faces = remembered._farm_geometry().faces.duplicate(true)
	farm.farm_stage = "sowing"
	farm.farm_stage_progress = 0.0
	assert(memory.farm_stage == "harvesting" and memory.crop_fraction == 0.5)
	assert(remembered._farm_geometry().faces == frozen_faces, "fog crop appearance must not follow hidden work")
	game.paused = true
	game.view_mode_25d = false
	var dock: RtsBuilding = game.spawn_building(0, "dock", Vector2(900, 950))
	var tip := dock.position + Vector2(-dock.size().x * 0.3, dock.size().y * 0.58)
	assert(not dock.contains(tip), "bridge tip lies beyond the original footprint")
	assert(dock.contains_visual(tip, Transform2D.IDENTITY))
	assert(game._entity_at(tip) == dock, "the actual 2D selection path must select the bridge head")
	game.free()
	print("CIVIC_BUILDING_SELECTION_OK samples=%d triangulated_faces=%d, 15 models, zoom/elevation/construction/portraits/farm memory" % [samples, polygons])
	quit()

extends "res://tests/landmark_occlusion.gd"

const State = preload("res://scripts/entities/visuals/building_visual_state.gd")
const Renderer = preload("res://scripts/entities/visuals/building_visual.gd")

func _initialize() -> void:
	for civilization in ["English", "French", "Chinese"]:
		for kind in ["university", "monastery", "dock", "farm"]:
			var state = State.new()
			state.kind = kind
			state.civilization = civilization
			state.dimensions = GameData.BUILDINGS[kind]["size"]
			state.player_color = Color.CORNFLOWER_BLUE
			state.crop_fraction = 0.75
			var renderer = Renderer.new()
			renderer.state = state
			verify(renderer._civic_display_geometry(), "%s_%s" % [civilization, kind])
	print("CIVIC_BUILDING_OCCLUSION samples=%d failures=%d" % [samples_checked, failures])
	quit(1 if failures else 0)

extends "res://tests/landmark_occlusion.gd"

const Refined = preload("res://scripts/entities/visuals/refined_building_geometry.gd")
const COLORS = {"wall": Color("cbbd99"), "timber": Color("674c39"), "roof": Color("75564a"), "roof_dark": Color("503b37"), "trim": Color("e3d0a0")}

func _initialize() -> void:
	var polygons := 0
	for civilization in ["English", "French", "Chinese"]:
		for kind in ["house", "blacksmith", "market"]:
			for variant in (3 if kind == "house" else 1):
				var mesh := Refined.new(kind, GameData.BUILDINGS[kind]["size"], civilization, Color("4e9bea"), variant, COLORS)
				for polygon in mesh.portrait_faces:
					assert(not Geometry2D.triangulate_polygon(polygon["points"]).is_empty(), "BSP fragment must remain drawable")
					polygons += 1
				verify(mesh, "%s_%s_%d" % [civilization, kind, variant])
	print("REFINED_BUILDING_OCCLUSION polygons=%d visible_samples=%d failures=%d" % [polygons, samples_checked, failures])
	quit(1 if failures else 0)

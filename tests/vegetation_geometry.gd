extends SceneTree

const Visual = preload("res://scripts/entities/visuals/vegetation_visual.gd")

func _initialize() -> void:
	# The randomized concave crowns must triangulate for every projection.
	# This catches self-intersecting shapes that only fail at certain map seeds.
	var checked := 0
	for tree in [true, false]:
		for i in 512:
			var point := Vector2(i * 43.17 - 2000, i * 19.31 - 700)
			var visual := Visual.new(point, tree)
			var repeated := Visual.new(point, tree)
			for key in (["tree_2d", "tree_25d"] if tree else ["bush_2d", "bush_25d"]):
				var shapes: Array = visual.get(key)
				assert(shapes == repeated.get(key), "redrawing/recreating a plant must preserve its appearance")
				for shape in shapes:
					assert(not Geometry2D.triangulate_polygon(shape["points"]).is_empty(), "invalid vegetation polygon at %s / %s" % [point, key])
					checked += 1
	print("VEGETATION_GEOMETRY_OK: ", checked, " polygons, 1024 plants")
	quit()

extends SceneTree

const Visual = preload("res://scripts/entities/visuals/ore_visual.gd")

func _initialize() -> void:
	var checked := 0
	for kind in ["stone", "gold"]:
		for i in 256:
			var point := Vector2(i * 43.17 - 2000, i * 19.31 - 700)
			var visual := Visual.new(point, kind)
			var repeated := Visual.new(point, kind)
			assert(visual.ground == repeated.ground)
			assert(not Geometry2D.triangulate_polygon(visual.ground).is_empty())
			for key in ["shapes_2d", "shapes_25d"]:
				var shapes: Array = visual.get(key)
				assert(shapes.filter(func(shape: Dictionary) -> bool: return shape["threshold"] <= 0.14).size() < shapes.size(), "harvesting should reduce visible ore or rubble")
				assert(shapes == repeated.get(key), "a deposit must keep its appearance across recreations")
				for shape in shapes:
					if shape.get("line", false): continue
					assert(not Geometry2D.triangulate_polygon(shape["points"]).is_empty(), "invalid ore polygon at %s / %s" % [point, key])
					checked += 1
	# Variations must not consume global RNG or change collection/collision data.
	seed(9721)
	var expected := randf()
	seed(9721)
	var first := RtsResource.new()
	first.position = Vector2(3, 8)
	first.setup("gold", 580, "ore")
	assert(randf() == expected, "ore geometry must use a private RNG")
	var other := RtsResource.new()
	other.position = Vector2(74, 45)
	other.setup("gold", 580, "ore")
	assert(first.ore_visual.shapes_25d != other.ore_visual.shapes_25d, "nearby deposits should vary")
	assert(first.amount == 580 and first.initial_amount == 580 and first.radius == 22.0)
	var geometry: Array = first.ore_visual.shapes_25d.duplicate(true)
	first.amount = 81
	assert(first.ore_visual.shapes_25d == geometry, "harvesting must not rebuild the rock geometry")
	first.setup("stone", 560, "ore")
	assert(first.ore_visual != null and not first.ore_visual.is_gold)
	first.setup("food", 420, "berry")
	assert(first.ore_visual == null, "resetting a resource must clear its ore visual")
	first.free()
	other.free()
	print("ORE_GEOMETRY_OK: ", checked, " polygons, 512 deposits")
	quit()

extends SceneTree

const Gate = preload("res://scripts/entities/visuals/stone_gate_geometry.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var palette := {"wall": Color.GRAY, "trim": Color.WHITE, "roof": Color.GRAY, "roof_dark": Color.DARK_GRAY, "timber": Color.BROWN}
	var size: Vector2 = GameData.BUILDINGS["stone_gate"]["size"]
	var horizontal = Gate.new(size, palette, Color.BLUE, false)
	var vertical = Gate.new(Vector2(size.y, size.x), palette, Color.BLUE, true)
	assert(horizontal.faces.size() == vertical.faces.size())
	for i in horizontal.faces.size():
		var a: PackedVector3Array = horizontal.faces[i]["points"]
		var b: PackedVector3Array = vertical.faces[i]["points"]
		for j in a.size():
			assert(b[j].is_equal_approx(Vector3(a[j].y, a[j].x, a[j].z)), "gate geometry must follow its rotated footprint")
	var original: Array = vertical.faces.duplicate(true)
	vertical.prepare()
	assert(vertical.faces == original, "rebuilding BSP must not scale the model twice")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	var probes := 0
	for civ in ["English", "French", "Chinese"]:
		game.start_game(civ, 12345)
		game.paused = true
		for unit in game.units:
			for building in game.buildings:
				var occupied := Rect2(building.position - building.size() * 0.5, building.size()).grow(unit.radius() - 0.01)
				assert(not occupied.has_point(unit.position), "starting units must clear the enlarged town center")
			assert(game.navigation.can_occupy(unit.position, unit.radius(), unit, false, false), "starting units need a navigable spawn")
			probes += 1
	var wall_a: RtsBuilding = game.spawn_building(0, "stone_wall", Vector2(1300, 1100))
	var wall_b: RtsBuilding = game.spawn_building(0, "stone_wall", wall_a.position + Vector2(GameData.BUILD_GRID_SIZE * 3.0, 0))
	assert(RtsSiegeRules.walls_connected(wall_a, wall_b), "adjacent enlarged walls must remain connected")
	wall_b.position += Vector2(GameData.BUILD_GRID_SIZE * 3.0, 0)
	assert(not RtsSiegeRules.walls_connected(wall_a, wall_b), "a missing wall section must break the connection")
	game.free()
	print("BUILDING_SCALE_OK rotated gate, stable cache, wall connectivity and spawn clearance probes=", probes)
	quit()

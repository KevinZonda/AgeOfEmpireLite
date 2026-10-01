extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game("English", 4242)
	var grid: float = game.BUILD_GRID_SIZE
	var reference: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://docs/aoe4-building-footprints.json"))
	assert(reference is Dictionary, "the footprint reference must be readable")
	assert(reference["buildings"].size() == GameData.BUILDINGS.size(), "the footprint reference must cover every current building")
	for entry in reference["buildings"]:
		var kind: String = str(entry["project_id"])
		assert(GameData.BUILDINGS.has(kind), "the footprint reference must cover a current building")
		if entry["width_tiles"] == null:
			assert(not GameData.BUILDINGS[kind].has("footprint_tiles"), "%s has no verified tile count" % kind)
			continue
		var expected := Vector2i(int(entry["width_tiles"]), int(entry["height_tiles"]))
		assert(GameData.BUILDINGS[kind].get("footprint_tiles", Vector2i.ZERO) == expected, "%s tile count differs from the reference" % kind)
		var footprint: Vector2 = game.build_footprint_size(kind)
		assert(footprint == Vector2(expected) * grid, "%s preview uses the wrong footprint" % kind)
		var body: Vector2 = RtsLandmarkCatalog.LANDMARK_SIZE if kind == "landmark" else GameData.BUILDINGS[kind]["size"]
		assert(body.x <= footprint.x and body.y <= footprint.y, "%s body extends beyond its placement footprint" % kind)
	var point := Vector2.INF
	for y in range(300, 1000, 25):
		for x in range(350, 1100, 25):
			var candidate := Vector2(x + 4, y + 7)
			if game.can_place("house", candidate):
				point = candidate
				break
		if point != Vector2.INF: break
	assert(point != Vector2.INF, "test map needs a buildable house location")
	var snapped: Vector2 = game.snap_build_point("house", point)
	assert(snapped == game.snap_build_point("house", point + Vector2(2, -2)))
	var footprint: Rect2 = game.build_footprint_rect("house", snapped)
	assert(fposmod(footprint.position.x, grid) == 0.0 and fposmod(footprint.position.y, grid) == 0.0)
	assert(fposmod(footprint.size.x, grid) == 0.0 and fposmod(footprint.size.y, grid) == 0.0)
	var worker: RtsUnit = game.units[0]
	var workers: Array[RtsUnit] = [worker]
	assert(game.place_building(0, "house", point, workers))
	var house: RtsBuilding = game.buildings.back()
	assert(house.position == snapped, "placed building must use the preview anchor")
	assert(not game.can_place("house", point + Vector2(2, -2)), "occupied grid cells must reject another building")
	var wall_span: float = game.build_footprint_size("palisade_wall").x * 2.0
	var wall_points: Array[Vector2] = game._wall_positions(Vector2(600, 650), Vector2(600 + wall_span, 650))
	assert(wall_points.size() == 3)
	for i in range(1, wall_points.size()):
		var previous: Rect2 = game.build_footprint_rect("palisade_wall", wall_points[i - 1])
		var current: Rect2 = game.build_footprint_rect("palisade_wall", wall_points[i])
		assert(previous.end.x == current.position.x and previous.position.y == current.position.y, "wall sections must meet without a gap")
	var vertical_points: Array[Vector2] = game._wall_positions(Vector2(600, 650), Vector2(600, 650 + wall_span))
	assert(vertical_points.size() == 3)
	for i in range(1, vertical_points.size()):
		var previous: Rect2 = game.build_footprint_rect("palisade_wall", vertical_points[i - 1], true)
		var current: Rect2 = game.build_footprint_rect("palisade_wall", vertical_points[i], true)
		assert(previous.end.y == current.position.y and previous.position.x == current.position.x, "vertical wall sections must meet without a gap")
	print("BUILD_GRID_OK")
	quit()

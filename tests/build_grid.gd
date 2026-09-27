extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game("English", 4242)
	var grid: float = game.BUILD_GRID_SIZE
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
	var wall_points: Array[Vector2] = game._wall_positions(Vector2(600, 650), Vector2(750, 650))
	assert(wall_points.size() == 3)
	for i in range(1, wall_points.size()):
		var previous: Rect2 = game.build_footprint_rect("palisade_wall", wall_points[i - 1])
		var current: Rect2 = game.build_footprint_rect("palisade_wall", wall_points[i])
		assert(previous.end.x == current.position.x and previous.position.y == current.position.y, "wall sections must meet without a gap")
	var vertical_points: Array[Vector2] = game._wall_positions(Vector2(600, 650), Vector2(600, 800))
	assert(vertical_points.size() == 3)
	for i in range(1, vertical_points.size()):
		var previous: Rect2 = game.build_footprint_rect("palisade_wall", vertical_points[i - 1], true)
		var current: Rect2 = game.build_footprint_rect("palisade_wall", vertical_points[i], true)
		assert(previous.end.y == current.position.y and previous.position.x == current.position.x, "vertical wall sections must meet without a gap")
	print("BUILD_GRID_OK")
	quit()

extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://scenes/main.tscn")
	var game: Variant = scene.instantiate()
	root.add_child(game)
	await process_frame
	game.start_game("English", 4242)
	var center: RtsBuilding = game._player_center(0)
	var worker: RtsUnit = game.units[0]
	assert(not game.navigation.can_occupy(center.position, worker.radius(), worker), "Town Center should block movement")
	var destination := Vector2(330, 610)
	var route: PackedVector2Array = game.navigation.path_between(worker.position, destination)
	assert(not route.is_empty(), "the map should offer a route around the Town Center")
	for waypoint in route:
		assert(not Rect2(center.position - center.size() * 0.5, center.size()).has_point(waypoint), "route should avoid buildings")
	worker.order_move(destination)
	for i in 240:
		worker._process(0.05)
		assert(not Rect2(center.position - center.size() * 0.5, center.size()).has_point(worker.position), "worker should not enter building")
	assert(worker.position.distance_to(destination) < 12.0, "worker should reach its destination around the building")
	var occupied_goal: Vector2 = game.units[1].position
	var open_goal: Vector2 = game.navigation.nearest_walkable_point(occupied_goal, worker.radius(), worker)
	assert(game.navigation.can_occupy(open_goal, worker.radius(), worker), "move orders should choose a free destination")
	var movable_resource: RtsResource = game.spawn_resource("stone", Vector2(1200, 750), 100)
	game.navigation.refresh()
	var old_cell: Vector2i = game.world_map.cell_at(movable_resource.position)
	assert(game.navigation.pathfinder.is_point_solid(old_cell))
	movable_resource.position = Vector2(1450, 750)
	game.navigation.path_between(worker.position, movable_resource.position)
	assert(not game.navigation.pathfinder.is_point_solid(old_cell), "moved resources should release old path cells")
	assert(game.navigation.pathfinder.is_point_solid(game.world_map.cell_at(movable_resource.position)), "moved resources should block their new path cells")
	print("NAVIGATION_OK")
	quit()

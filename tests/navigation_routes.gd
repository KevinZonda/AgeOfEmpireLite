extends SceneTree

class TestGame extends Node2D:
	var players := [{}, {}]
	var units: Array[RtsUnit] = []
	var resources: Array[RtsResource] = []
	var buildings: Array[RtsBuilding] = []

	func is_enemy(first: int, second: int) -> bool:
		return first != second

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := TestGame.new()
	root.add_child(game)
	var world := RtsWorldMap.new()
	world.world_size = Vector2(1000, 1000)
	world.grid_size = Vector2i(20, 20)
	world.cells.resize(400)
	world.cells.fill(RtsWorldMap.Terrain.GRASS)
	game.add_child(world)
	var unit := RtsUnit.new()
	unit.stats = {"radius": 12.0}
	unit.position = Vector2(125, 125)
	game.units.append(unit)
	var navigation := RtsNavigation.new(game, world)
	navigation.refresh()

	var destination := Vector2(825, 125)
	var straight := navigation.path_between(unit.position, destination, unit)
	assert(straight.size() == 2 and straight[0] == unit.position and straight[1] == destination, "clear ground should produce one straight segment")

	world.cells[2 * world.grid_size.x + 9] = RtsWorldMap.Terrain.MOUNTAIN
	navigation.refresh()
	var raw := navigation.pathfinder.get_point_path(world.cell_at(unit.position), world.cell_at(destination))
	var detour := navigation.path_between(unit.position, destination, unit)
	assert(detour.size() > 2 and detour.size() < raw.size(), "the route should bend around terrain with fewer waypoints")
	assert(navigation._path_length(detour) < navigation._path_length(raw), "the smoothed route should be shorter")
	for i in range(1, detour.size()):
		assert(navigation._static_segment_clear(detour[i - 1], detour[i], unit.radius(), unit), "each shortcut must clear the unit's full radius")

	# The nearest approach sits in a pocket whose entrance is on the far side.
	world.cells.fill(RtsWorldMap.Terrain.GRASS)
	for blocked in [Vector2i(9, 11), Vector2i(9, 12), Vector2i(9, 13), Vector2i(10, 11), Vector2i(10, 13)]:
		world.cells[blocked.y * world.grid_size.x + blocked.x] = RtsWorldMap.Terrain.MOUNTAIN
	unit.position = Vector2(225, 625)
	navigation.refresh()
	var target := Vector2(625, 625)
	var reach := 100.0
	var first_approach := target + (unit.position - target).normalized() * (reach - 0.25)
	var first_route := navigation.pathfinder.get_point_path(world.cell_at(unit.position), world.cell_at(first_approach))
	assert(not first_route.is_empty(), "the pocket approach should still be reachable")
	first_route.append(first_approach)
	var best_route := navigation.path_to_range(unit.position, target, reach, unit)
	assert(not best_route.is_empty(), "an approach route should exist")
	assert(navigation._path_length(best_route) + 1.0 < navigation._path_length(first_route), "choose the shorter approach instead of the first reachable angle")
	unit.free()
	print("NAVIGATION_ROUTES_OK")
	quit()

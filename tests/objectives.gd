extends SceneTree


class MapStub extends Node2D:
	var world_size := Vector2(2400, 1500)

	func nearest_walkable_point(point: Vector2) -> Vector2:
		return point


class GameStub extends Node2D:
	var world_map: MapStub
	var started := true
	var paused := false
	var game_over := false
	var civilizations := ["English", "French"]
	var units: Array[Node2D] = []
	var buildings: Array[Node2D] = []


class UnitStub extends Node2D:
	var owner_id := 0
	var hp := 10.0
	var stats := {"tags": ["military"]}


class BuildingStub extends Node2D:
	var owner_id := 0
	var kind := "wonder"
	var complete := true

	func is_complete() -> bool:
		return complete


func _initialize() -> void:
	var game := GameStub.new()
	root.add_child(game)
	game.world_map = MapStub.new()
	game.add_child(game.world_map)
	var objectives := RtsObjectiveManager.new()
	game.add_child(objectives)
	objectives.setup(game)
	assert(objectives.sacred_sites.size() == 3)
	var victories: Array[Dictionary] = []
	var captures: Array[Dictionary] = []
	objectives.victory.connect(func(owner_id: int, reason: String) -> void: victories.append({"owner": owner_id, "reason": reason}))
	objectives.site_captured.connect(func(index: int, owner_id: int) -> void: captures.append({"index": index, "owner": owner_id}))
	var blue := UnitStub.new()
	var red := UnitStub.new()
	red.owner_id = 1
	game.add_child(blue)
	game.add_child(red)
	game.units.append_array([blue, red])
	for index in 3:
		blue.position = objectives.sacred_sites[index]["position"]
		red.position = blue.position if index == 0 else Vector2.ZERO
		objectives._process(9.0)
		if index == 0:
			assert(objectives.sacred_sites[0]["owner_id"] == -1)
			red.position = Vector2.ZERO
			objectives._process(8.0)
		assert(objectives.sacred_sites[index]["owner_id"] == 0)
	assert(captures.size() == 3)
	assert(objectives.status_for(0)["sacred_owned"] == 3)
	assert(objectives.sacred_holder == 0)
	var held_time := objectives.sacred_remaining
	red.position = objectives.sacred_sites[2]["position"]
	objectives._process(30.0)
	assert(objectives.sacred_remaining == held_time)
	assert(victories.is_empty())
	red.position = Vector2.ZERO
	objectives._process(90.0)
	assert(victories.size() == 1 and victories[0] == {"owner": 0, "reason": "sacred"})
	objectives._process(200.0)
	assert(victories.size() == 1)
	objectives.reset()
	assert(objectives.status_for(0)["sacred_owned"] == 0)
	var wonder := BuildingStub.new()
	game.add_child(wonder)
	game.buildings.append(wonder)
	objectives._process(30.0)
	assert(objectives.status_for(0)["wonder_active"])
	assert(objectives.wonder_remaining[0] == 90.0)
	objectives.on_building_destroyed(wonder)
	game.buildings.erase(wonder)
	wonder.queue_free()
	objectives._process(1.0)
	assert(objectives.wonder_remaining[0] == RtsObjectiveManager.WONDER_VICTORY_TIME)
	var replacement := BuildingStub.new()
	game.add_child(replacement)
	game.buildings.append(replacement)
	objectives._process(120.0)
	assert(victories.size() == 2 and victories[1] == {"owner": 0, "reason": "wonder"})
	game.free()
	print("OBJECTIVES_OK")
	quit()

extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var map := RtsWorldMap.new()
	var matching_map := RtsWorldMap.new()
	for seed_value in range(1, 21):
		map.generate(seed_value * 173, Vector2(2400, 1500))
		assert(map.cells.has(RtsWorldMap.Terrain.WATER))
		assert(map.cells.has(RtsWorldMap.Terrain.MOUNTAIN))
		assert(map.plants.size() > 100)
		assert(not map.path_between(Vector2(330, 720), Vector2(2070, 720)).is_empty())
		var west_starters := {"wood": 0, "food": 0, "gold": 0, "stone": 0}
		var east_starters := {"wood": 0, "food": 0, "gold": 0, "stone": 0}
		for index in 15:
			west_starters[map.resource_specs[index]["kind"]] += 1
			east_starters[map.resource_specs[index + 15]["kind"]] += 1
		assert(west_starters == east_starters and west_starters == {"wood": 5, "food": 4, "gold": 3, "stone": 3})
		var deer_count := 0
		for spec in map.resource_specs:
			if spec["appearance"] == "deer": deer_count += 1
			if spec["appearance"] == "fish":
				assert(map.is_navigable(spec["position"]))
			else:
				assert(map.is_walkable(spec["position"]))
				assert(not map.path_between(Vector2(1200, 750), spec["position"]).is_empty())
		assert(deer_count >= 12)
	matching_map.generate(map.map_seed, Vector2(2400, 1500))
	assert(matching_map.cells == map.cells)
	assert(matching_map.resource_specs == map.resource_specs)
	map.free()
	matching_map.free()
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game("English", 12345)
	assert(game.map_seed == 12345 and game.resources.size() == game.world_map.resource_specs.size())
	assert(not game.can_place("house", Vector2(800, 1220)))
	var worker: RtsUnit = game.units[0]
	worker.order_move(Vector2(800, 1220))
	assert(game.world_map.is_walkable(worker.destination))
	assert(game.weather.rain_active)
	game.weather.weather_remaining = 0.01
	game.weather._process(0.02)
	assert(not game.weather.rain_active)
	print("MAP_GENERATOR_OK")
	quit()

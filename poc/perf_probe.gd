extends SceneTree

# Headless probe: measures the worst-case one-frame costs suspected of causing
# intermittent mid-game hitches (nav world-grid rebuild, fog tick, stats sample).
func _initialize() -> void:
	call_deferred("_run")

func _report(label: String, start_us: int) -> void:
	print("%-42s %8.1f ms" % [label, (Time.get_ticks_usec() - start_us) / 1000.0])

func _run() -> void:
	seed(4242)
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game("English", 4242, "French")
	await process_frame

	# Simulate a late-game population: 300 extra units spread across players.
	for i in 300:
		var unit := RtsUnit.new()
		unit.position = Vector2(300 + (i % 30) * 45.0, 400 + (i / 30) * 45.0)
		game.add_child(unit)
		unit.setup(game, i % game.players.size(), "spearman")
		game.units.append(unit)
	print("players=%d units=%d buildings=%d resources=%d" % [game.players.size(), game.units.size(), game.buildings.size(), game.resources.size()])
	print("map grid=%s world=%s" % [game.world_map.grid_size, game.world_map.world_size])

	var nav = game.navigation
	var probe_unit: RtsUnit = game.units[0]
	var start: int

	# 1. Cache invalidation itself (building placed/destroyed).
	start = Time.get_ticks_usec()
	nav.refresh()
	_report("nav.refresh() [cache wipe]", start)

	# 2. The lazy rebuild that lands on the next failing path query:
	#    world-size fine grid rasterization (GDScript, whole map).
	start = Time.get_ticks_usec()
	var world_grid: AStarGrid2D = nav._fine_grid_for(probe_unit)
	_report("nav._fine_grid_for() [world grid build]", start)
	print("   world fine grid cells: %s = %d" % [world_grid.region.size, world_grid.region.size.x * world_grid.region.size.y])

	# 3. Full-map connected-component flood fill on that grid (on failed A*).
	start = Time.get_ticks_usec()
	nav._components_for(world_grid)
	_report("nav._components_for() [BFS flood]", start)

	# 4. A realistic failing fine path query after fresh invalidation
	#    (stuck unit whose target became unreachable).
	nav.refresh()
	var from := probe_unit.position
	var to := Vector2(game.world_map.world_size.x - from.x, game.world_map.world_size.y - from.y)
	start = Time.get_ticks_usec()
	var path: PackedVector2Array = nav._fine_static_path(from, to, probe_unit)
	_report("nav._fine_static_path() [cold, cross-map]", start)
	print("   path points: %d" % path.size())

	# 5. Fog-of-war full visibility recompute (runs every 0.15 s).
	start = Time.get_ticks_usec()
	game.fog.update_visibility()
	_report("fog.update_visibility() [0.15s tick]", start)

	# 6. Match statistics sample (runs every 5 s, retained forever).
	start = Time.get_ticks_usec()
	game.match_statistics.sample()
	_report("match_statistics.sample() [5s tick]", start)

	quit()

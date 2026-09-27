extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var map := RtsWorldMap.new()
	for style in ["balanced", "lakes", "highlands", "islands"]:
		for participants in [2, 4]:
			for map_size in [Vector2(2400, 2400), Vector2(3000, 3000)]:
				for seed_value in [17, 431, 9021]:
					map.generate(seed_value, map_size, style, participants)
					var report := map.fairness_report()
					assert(report["fair"], "%s %d %s %d: %s" % [style, participants, map_size, seed_value, report])
					for base in map.spawn_positions():
						assert(map.is_walkable(base))
	map.free()
	print("MAP_FAIRNESS_OK")
	quit()

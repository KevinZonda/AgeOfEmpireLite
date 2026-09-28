extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var map := RtsWorldMap.new()
	for style in ["balanced", "lakes", "highlands", "islands"]:
		var first_cells := PackedByteArray()
		var first_sites: Array[Vector2] = []
		for seed_value in [17, 431, 9021]:
			map.generate(seed_value, Vector2(2400, 2400), style, 2)
			assert(map.fairness_report()["fair"], "starter resources must stay fair")
			var bases := map.spawn_positions()
			var sites := map.sacred_site_positions()
			var posts := map.trade_post_positions()
			assert(sites.size() == 3 and posts.size() == 2)
			for site in sites:
				assert(map.is_walkable(site), "every sacred site needs solid ground")
				if style != "islands":
					for base in bases: assert(not map.path_between(base, site).is_empty(), "land sites must be reachable from either base")
			if style == "islands":
				assert(map.path_between(bases[0], bases[1]).is_empty(), "islands must require sea transport")
				assert(not map.path_between(bases[0], posts[0]).is_empty() and not map.path_between(bases[1], posts[1]).is_empty(), "each home island needs a reachable trade post")
			else:
				assert(not map.path_between(bases[0], bases[1]).is_empty(), "land maps must connect both players")
				for post in posts:
					for base in bases: assert(not map.path_between(base, post).is_empty(), "land trade routes must be reachable")
			var contested := {"gold": 0, "stone": 0, "food": 0}
			for spec in map.resource_specs:
				if not contested.has(spec["kind"]) or spec["appearance"] in ["sheep", "boar", "fish"]: continue
				var far_from_home := true
				for base in bases:
					if base.distance_to(spec["position"]) < 430.0: far_from_home = false
				if not far_from_home: continue
				for site in sites:
					if site.distance_to(spec["position"]) < 620.0:
						contested[spec["kind"]] += 1
						break
			assert(contested["gold"] >= 2 and contested["food"] >= 2, "central objectives need contested economy")
			if style != "islands": assert(contested["stone"] >= 2, "land objectives need contested stone")
			if style in ["lakes", "highlands"]:
				for index in 2:
					var y: float = (map.crossing_references[index] + map.crossing_references[index + 1]) * 0.5
					var barrier: Vector2 = map._world_point(Vector2(map._barrier_center(y), y))
					assert(map.terrain_at(barrier) == (RtsWorldMap.Terrain.WATER if style == "lakes" else RtsWorldMap.Terrain.MOUNTAIN), "crossings must be separated by impassable terrain")
			if seed_value == 17:
				first_cells = map.cells.duplicate()
				first_sites = sites.duplicate()
			else:
				assert(map.cells != first_cells and sites != first_sites, "the seed must change macro layout and objectives")
		map.generate(431, Vector2(3000, 3000), style, 4)
		assert(map.fairness_report()["fair"], "four-player starts must stay fair")
		if style != "islands":
			for base in map.spawn_positions():
				for site in map.sacred_site_positions(): assert(not map.path_between(base, site).is_empty(), "four-player land sites must be reachable")
	map.free()
	assert(RtsLandmarkCatalog.preferred_landmark("English", 2, "highlands") == "eng_white_tower")
	assert(RtsLandmarkCatalog.preferred_landmark("French", 1, "balanced") == "fr_school_of_cavalry")
	assert(RtsLandmarkCatalog.preferred_landmark("French", 1, "lakes") == "fr_chamber_of_commerce")
	assert(RtsLandmarkCatalog.preferred_landmark("French", 3, "islands") == "fr_red_palace")
	assert(RtsLandmarkCatalog.preferred_landmark("Chinese", 1, "highlands") == "zh_barbican")
	assert(RtsLandmarkCatalog.dynasty_for([]) == "Tang")
	print("MAP_STRATEGY_OK")
	quit()

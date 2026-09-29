extends "res://tests/navigation_battle_goal_poc.gd"

func _run() -> void:
	var game := fixture()
	var nav := CountedNavigation.new(game, game.world_map)
	game.navigation = nav
	var unit := game.spawn_unit(Vector2(725, 525))
	var blocker := game.spawn_unit(unit.position + Vector2(50, 0))
	blocker.owner_id = 1
	blocker.order = "hold"
	var target := unit.position + Vector2(180, 0)
	var started := Time.get_ticks_usec()
	for attempt in 10:
		var path := nav._local_unit_path(unit, target, 2, 96)
		check(path.size() > 2 and safe_route(game, unit, path), "native_search_returns_safe_detour")
	print("NATIVE_POC requests=10 elapsed_ms=%.3f flood_cells=%d" % [(Time.get_ticks_usec() - started) / 1000.0, nav.flood_cells])
	check(nav.flood_cells == 0, "reachable_exit_does_not_need_script_flood")
	# A failed native probe must still use the component filter, rather than
	# repeating an exhaustive native search for every disconnected exit.
	nav.flood_cells = 0
	for i in 8:
		var guard := game.spawn_unit(unit.position + Vector2.from_angle(i * TAU / 8.0) * 25.0)
		guard.order = "hold"
	check(nav._local_unit_path(unit, target, 2, 96).is_empty(), "sealed_mover_cannot_cross_units")
	check(nav.flood_cells > 0 and nav.flood_cells < 100, "failed_probe_filters_small_connected_pocket")
	game.free()
	print("NAVIGATION_BATTLE_NATIVE_POC checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)

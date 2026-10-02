extends "res://poc/exploration-2026-10-02/explore.gd"

func _run() -> void:
	setup_case()
	var center: RtsBuilding = game._player_center(0)
	var worker := soldier("villager", 0, center.position + Vector2(0, 95))
	game.selected.assign([worker])
	game._rebuild_actions()
	assert(not game.command_buttons.is_empty())
	worker.issue_command("garrison", Vector2.INF, center)
	tick_units([worker], 50)
	assert(worker.garrisoned_in == center and not game.selected.has(worker))
	game._update_hud()
	assert(game.command_buttons.is_empty())
	var site := free_site("house")
	var workers: Array[RtsUnit] = [worker]
	var before: int = game.players[0]["wood"]
	var buildings_before: int = game.buildings.size()
	assert(not game.place_building(0, "house", site, workers))
	assert(game.players[0]["wood"] == before and game.buildings.size() == buildings_before)
	# A stale build mode with every villager inside must not select hidden builders.
	for unit in game.units:
		if unit.kind == "villager" and unit.owner_id == 0 and unit.garrisoned_in == null: center.garrison_unit(unit)
	game.build_mode = "house"
	game._confirm_build(site)
	assert(game.players[0]["wood"] == before and game.buildings.size() == buildings_before)
	center.ungarrison_all()
	assert(worker.garrisoned_in == null)
	assert(game.place_building(0, "house", site, workers))
	assert(game.count_builders(game.buildings.back()) == 1)
	var second := soldier("villager", 0, center.position + Vector2(170, 0))
	game.selected.assign([worker, second])
	assert(center.garrison_unit(worker))
	assert(game.selected.size() == 1 and game.selected[0] == second)
	workers.assign([worker, second])
	assert(game.place_building(0, "house", free_site("house"), workers))
	assert(game.count_builders(game.buildings.back()) == 1 and second.order == "build")
	game.navigation.shutdown_jobs()
	game.queue_free()
	await process_frame
	print("EXPLORATION_B08_OK")
	quit()

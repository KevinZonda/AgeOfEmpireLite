extends SceneTree

# Fast-forward a passive match to catch population, resource, and construction
# deadlocks that only appear after nearby deposits run out.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	seed(4242)
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game("English", 4242)
	var easy := RtsAiController.new(game, 1, "easy")
	var hard := RtsAiController.new(game, 1, "hard")
	assert(hard.worker_goal() > easy.worker_goal() and hard.attack_threshold() < easy.attack_threshold())
	var peak_cap := 0
	var peak_army := 0
	for step in 6000:
		if game.game_over: break
		game._process(0.1)
		for building in game.buildings.duplicate():
			if is_instance_valid(building) and not building.is_queued_for_deletion(): building._process(0.1)
		for unit in game.units.duplicate():
			if is_instance_valid(unit) and not unit.is_queued_for_deletion(): unit._process(0.1)
		game.objectives._process(0.1)
		peak_cap = maxi(peak_cap, game.population_cap(1))
		var military := 0
		for unit in game.units:
			if is_instance_valid(unit) and unit.owner_id == 1 and unit.stats.get("tags", []).has("military"): military += 1
		peak_army = maxi(peak_army, military)
	if peak_cap < 40 or peak_army < 20 or game.players[1]["age"] < 3 and not game.game_over:
		push_error("AI long match stalled: age=%d cap=%d army=%d bank=%s" % [game.players[1]["age"], peak_cap, peak_army, str(game.players[1])])
		quit(1)
		return
	print("AI_LONG_MATCH_OK age=%d peak_cap=%d peak_army=%d" % [game.players[1]["age"], peak_cap, peak_army])
	quit()

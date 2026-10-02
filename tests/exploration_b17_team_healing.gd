extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.match_mode = "team2"
	game.start_game("English", 431, "French")
	game.ai_controllers.clear()
	var point: Vector2 = game.spawn_point_for(0) + Vector2(160, 0)
	var monk: RtsUnit = game.spawn_unit(0, "monk", point)
	var ally: RtsUnit = game.spawn_unit(2, "spearman", point + Vector2(35, 0))
	var own: RtsUnit = game.spawn_unit(0, "spearman", point + Vector2(40, 0))
	var enemy: RtsUnit = game.spawn_unit(1, "spearman", point + Vector2(30, 0))
	monk.position = point
	ally.position = point + Vector2(35, 0)
	own.position = point + Vector2(40, 0)
	enemy.position = point + Vector2(30, 0)
	ally.hp = ally.max_hp - 20.0
	own.hp = own.max_hp - 10.0
	enemy.hp = enemy.max_hp - 50.0
	monk.hp = monk.max_hp - 40.0
	monk._heal_ally(0.01)
	assert(ally.hp == ally.max_hp - 13.0 and own.hp == own.max_hp - 10.0, "the allied unit with most missing HP heals first")
	monk._heal_ally(0.5)
	assert(ally.hp == ally.max_hp - 13.0, "the one-second healing cooldown remains enforced")
	monk._heal_ally(0.5)
	assert(ally.hp == ally.max_hp - 6.0)
	monk._heal_ally(1.0)
	assert(own.hp == own.max_hp - 3.0, "own units still participate in missing-HP priority")
	assert(enemy.hp == enemy.max_hp - 50.0 and monk.hp == monk.max_hp - 40.0, "enemies and the healer itself cannot be healed")
	own.hp = own.max_hp
	ally.hp = ally.max_hp - 20.0
	ally.position = point + Vector2(101, 0)
	monk._heal_ally(1.0)
	assert(ally.hp == ally.max_hp - 20.0, "allied healing does not extend the original radius")
	ally.position = point + Vector2(100, 0)
	monk._heal_ally(1.0)
	assert(ally.hp == ally.max_hp - 13.0, "the healing radius is inclusive")
	ally.garrisoned_in = game._player_center(2)
	monk._heal_ally(1.0)
	assert(ally.hp == ally.max_hp - 13.0, "garrisoned allies remain ineligible")
	ally.garrisoned_in = null
	ally.hp = 0.0
	monk._heal_ally(1.0)
	assert(ally.hp == 0.0, "healing cannot resurrect a dead ally")
	ally.hp = ally.max_hp - 2.0
	monk._heal_ally(1.0)
	assert(ally.hp == ally.max_hp, "healing is capped at maximum HP")
	ally.hp -= 20.0
	ally.queue_free()
	monk._heal_ally(1.0)
	assert(ally.hp == ally.max_hp - 20.0, "a pending-deletion ally cannot take a heal")
	game.free()
	print("EXPLORATION_B17_TEAM_HEALING_OK")
	quit()

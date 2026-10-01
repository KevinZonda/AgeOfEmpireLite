extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _match(mode: String) -> Node2D:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.match_mode = mode
	game.start_game("English", 431, "French")
	game.ai_controllers.clear()
	game.fog.active = false
	return game

func _run() -> void:
	var ffa: Node2D = await _match("ffa3")
	var victories: Array = []
	ffa.objectives.victory.connect(func(owner: int, reason: String): victories.append([owner, reason]))
	for site in ffa.objectives.sacred_sites: site["owner_id"] = 1
	ffa.objectives._process(0.1)
	ffa.objectives._process(30.0)
	assert(ffa.objectives.sacred_remaining == 60.0)
	ffa.entity_destroyed(ffa._player_center(1))
	assert(ffa.defeated_players.has(1) and not ffa.game_over)
	ffa.objectives._process(91.0)
	assert(not ffa.game_over and victories.is_empty(), "an eliminated FFA team cannot win with retained sites")
	assert(ffa.objectives.sacred_holder == -1 and ffa.objectives.sacred_remaining == 90.0)
	ffa.objectives._emit_victory(1, "sacred")
	assert(victories.is_empty(), "victory dispatch also rejects defeated teams")
	# The abandoned sites remain capturable and normal objective victories work.
	for site in ffa.objectives.sacred_sites: site["owner_id"] = 0
	ffa.objectives._process(0.1)
	ffa.objectives._process(90.0)
	assert(victories == [[0, "sacred"]] and ffa.game_over)
	ffa.free()
	await process_frame

	var team: Node2D = await _match("team2")
	victories.clear()
	team.objectives.victory.connect(func(owner: int, reason: String): victories.append([owner, reason]))
	for index in team.objectives.sacred_sites.size():
		team.objectives.sacred_sites[index]["owner_id"] = 2 if index != 1 else 0
	team.objectives._process(0.1)
	team.objectives._process(30.0)
	team.entity_destroyed(team._player_center(2))
	assert(team.defeated_players.has(2) and not team.game_over)
	assert(team.objectives.status_for(0)["sacred_owned"] == 3, "a surviving ally retains shared sacred ownership")
	team.objectives._process(60.0)
	assert(victories == [[0, "sacred"]] and team.game_over, "shared countdown continues and victory names a living ally")
	team.free()
	print("EXPLORATION_B03_OBJECTIVE_DEFEAT_OK")
	quit()

extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game("English", 4242)
	game.ai_controllers.clear()
	var boar: RtsResource = game.spawn_resource("food", Vector2(1050, 650), 420, "boar")
	var villager: RtsUnit = game.spawn_unit(0, "villager", boar.position + Vector2(50, 0))
	assert(not game.navigation.can_occupy(boar.position + Vector2(20, 0), villager.radius(), villager), "units should not enter a boar's collision area")
	var initial_hp: float = villager.hp
	for step in 6:
		boar._process_boar(0.25)
		if villager.hp < initial_hp: break
	assert(villager.hp < initial_hp, "boar should attack the nearby villager")
	assert(villager.position.distance_to(boar.position) < villager.radius() + boar.radius, "the attack should leave the villager overlapping the boar")
	var start: Vector2 = villager.position
	villager.issue_command("move", start + Vector2(160, 0))
	for step in 12:
		villager._process(0.1)
		boar._process_boar(0.1)
	assert(villager.position.distance_to(start) > 35.0, "villager should escape after a move order while the boar attacks")
	for voice in game.feedback_audio.voices:
		voice.stop()
		voice.stream = null
	await process_frame
	game.free()
	print("VILLAGER_BOAR_ESCAPE_OK")
	quit()

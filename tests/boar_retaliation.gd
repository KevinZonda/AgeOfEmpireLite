extends "res://tests/navigation_poc.gd"

func _run() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game("English", 4242)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.fog.active = false
	game.navigation.route_budget_enabled = false
	for entity in game.units + game.resources + game.buildings: entity.free()
	game.units.clear()
	game.resources.clear()
	game.buildings.clear()
	game.selected.clear()
	game.world_map.cells.fill(RtsWorldMap.Terrain.GRASS)
	game.navigation.refresh()

	var boar: RtsResource = game.spawn_resource("food", Vector2(725, 525), 420, "boar")
	var soldier: RtsUnit = game.spawn_unit(0, "spearman", boar.position + Vector2(25, 0))
	soldier.position = boar.position + Vector2(25, 0)
	boar._process_boar(0.01)
	check(boar.boar_target == null, "boar_leaves_unprovoking_soldier_alone")
	soldier.order_attack(boar)
	soldier._process_attack_order(0.01)
	check(boar.wildlife_hp < boar.wildlife_max_hp, "military_melee_hits_boar")
	var hp_before := soldier.hp
	boar._process_boar(0.25)
	check(soldier.hp == hp_before - 11.0 and boar.boar_target == soldier, "boar_retaliates_against_melee_attacker")

	# A ranged hit must provoke pursuit even beyond the passive villager radius.
	soldier.hp = 0.0
	boar.setup("food", 420, "boar")
	var archer: RtsUnit = game.spawn_unit(0, "archer", boar.position + Vector2(130, 0))
	archer.order_attack(boar)
	archer._process_attack_order(0.01)
	var arrows := game.get_children().filter(func(node: Node) -> bool: return node is RtsProjectile and not node.is_queued_for_deletion())
	check(arrows.size() == 1 and boar.wildlife_hp == 90.0 and boar.boar_target == null, "ranged_launch_does_not_provoke_before_impact")
	if arrows.size() == 1:
		arrows[0]._process(1.0)
		check(boar.wildlife_hp < 90.0, "military_projectile_hits_boar")
	var villager: RtsUnit = game.spawn_unit(0, "villager", boar.position - Vector2(25, 0))
	hp_before = archer.hp
	var villager_hp := villager.hp
	var origin := boar.position
	for step in 16: boar._process_boar(0.25)
	check(boar.position.distance_to(origin) >= 99.0 and archer.hp < hp_before, "boar_pursues_and_hits_distant_ranged_attacker")
	check(boar.boar_target == archer and villager.hp == villager_hp, "retaliation_survives_scans_and_prioritizes_attacker")

	# An invalid attacker must release retaliation so normal scanning can resume.
	archer.hp = 0.0
	boar._process_boar(0.01)
	check(boar.boar_target == null, "boar_drops_dead_military_attacker")
	villager.position = boar.position + Vector2(25, 0)
	game.navigation.invalidate_spatial_index()
	boar.wildlife_attack = 0.0
	boar._process_boar(0.25)
	check(boar.boar_target == villager and villager.hp == villager_hp - 11.0, "boar_resumes_passive_villager_aggression")

	# Killing the animal during combat must prevent a final retaliatory strike.
	boar.take_damage(100.0)
	hp_before = villager.hp
	boar._process_boar(1.5)
	check(boar.boar_target == null and villager.hp == hp_before and boar.harvest(10) == 10, "dead_boar_stops_attacking_and_remains_harvestable")
	for voice in game.feedback_audio.voices:
		voice.stop()
		voice.stream = null
	game.free()
	print("BOAR_RETALIATION checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)

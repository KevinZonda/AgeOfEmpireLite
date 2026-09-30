extends SceneTree

const State = preload("res://scripts/entities/visuals/unit_visual_state.gd")

func _initialize() -> void: call_deferred("_run")

func _arrows(game: Node2D) -> Array:
	return game.get_children().filter(func(node: Node) -> bool: return node is RtsProjectile and not node.is_queued_for_deletion())

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.feedback_audio.free()
	game.feedback_audio = null
	game.start_game("English", 4242)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.navigation.route_budget_enabled = false
	var defender: RtsUnit = game.spawn_unit(1, "spearman", game.units[0].position)
	for kind in ["spearman", "archer", "longbow"]:
		var attacker: RtsUnit = game.spawn_unit(0, kind, defender.position + Vector2(30, 0))
		attacker.order_attack(defender)
		attacker.attack_timer = 0.15
		defender.hp = defender.max_hp
		var initial_hp := defender.hp
		var profile := RtsStatResolver.attack_profile(attacker.stats, defender.stats)
		var expected_damage := RtsCombatRules.volley_damage(attacker.stats, defender.stats, profile)
		attacker._process_attack_order(0.01)
		var prepared = State.capture(attacker)
		assert(prepared.visual_action == "attack" and not prepared.action_released, "windup must hold the weapon before the real attack")
		assert(defender.hp == initial_hp and _arrows(game).is_empty(), "the new pose must not add an early hit")
		attacker._tick_visual(0.16)
		attacker._tick_status(0.16)
		attacker._process_attack_order(0.01)
		assert(State.capture(attacker).action_released and not prepared.action_released, "release must match the real attack and preserve earlier snapshots")
		assert(attacker.attack_timer > 0.0)
		if kind == "spearman":
			assert(_arrows(game).is_empty() and is_equal_approx(defender.hp, initial_hp - expected_damage), "spear thrust must retain the original melee damage")
		else:
			assert(_arrows(game).size() == 1 and defender.hp == initial_hp, "bow release must create one arrow without immediate damage")
			var arrow: RtsProjectile = _arrows(game)[0]
			assert(is_equal_approx(arrow.impact_damage, expected_damage))
			arrow._process(1.0)
			assert(is_equal_approx(defender.hp, initial_hp - expected_damage), "arrow impact must retain the original ranged damage")
		attacker._tick_visual(1.0)
		assert(attacker.visual_action == "" and not State.capture(attacker).action_released, "recovery must clear the release pose")
		attacker.order_stop()
	for arrow in game.get_children():
		if arrow is RtsProjectile: arrow.free()
	game.free()
	print("HUMANOID_ACTIONS_OK")
	quit()

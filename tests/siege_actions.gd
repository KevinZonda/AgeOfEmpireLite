extends SceneTree

const State = preload("res://scripts/entities/visuals/unit_visual_state.gd")
const Siege = preload("res://scripts/entities/visuals/siege_visual.gd")

func _initialize() -> void: call_deferred("_run")

func _projectiles(game: Node2D) -> Array:
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
	var target: RtsBuilding = game.spawn_building(1, "house", game.units[0].position + Vector2(200, 0))
	target.max_hp = 10000.0
	var count := 0
	for kind in Siege.KINDS:
		if kind == "siege_tower": continue
		var unit: RtsUnit = game.spawn_unit(0, kind, target.position + Vector2(220, 0))
		unit.position = target.position + Vector2(50 if kind == "battering_ram" else 220, 0)
		unit.order_attack(target)
		unit.attack_timer = 0.15
		target.hp = target.max_hp
		unit._process_attack_order(0.01)
		var prepared = State.capture(unit)
		assert(prepared.visual_action == "attack" and not prepared.action_released)
		assert(_projectiles(game).is_empty() and target.hp == target.max_hp, "windup must not inflict damage")
		unit._tick_visual(0.16)
		unit._tick_status(0.16)
		unit._process_attack_order(0.01)
		var released = State.capture(unit)
		assert(released.action_released and released.release_elapsed == 0.0)
		assert(not prepared.action_released, "render snapshots must retain their original pose")
		if kind == "battering_ram":
			assert(_projectiles(game).is_empty() and target.hp < target.max_hp)
		else:
			assert(_projectiles(game).size() == 1 and target.hp == target.max_hp, "one launch, no extra visual damage")
			_projectiles(game)[0].free()
		unit._tick_visual(0.1)
		assert(is_equal_approx(State.capture(unit).release_elapsed, 0.1))
		unit._tick_visual(1.0)
		assert(not State.capture(unit).action_released)
		unit.order_stop()
		game.units.erase(unit)
		unit.free()
		count += 1
	for kind in ["trebuchet", "mangonel", "bombard", "cannon", "nest_of_bees"]:
		var unit: RtsUnit = game.spawn_unit(0, kind, target.position + Vector2(200, 0))
		var point := unit.position + Vector2(160, 0)
		unit.issue_command("attack_ground", point)
		assert(unit.order == "attack_ground")
		unit.attack_timer = 0.15
		unit._process_attack_ground(0.01)
		assert(not State.capture(unit).action_released and _projectiles(game).is_empty())
		unit._tick_visual(0.16)
		unit._tick_status(0.16)
		unit._process_attack_ground(0.01)
		assert(State.capture(unit).action_released and State.capture(unit).release_elapsed == 0.0, "ground fire needs the same actual launch signal")
		assert(_projectiles(game).size() == 1)
		_projectiles(game)[0].free()
		unit.order_stop()
		game.units.erase(unit)
		unit.free()
		count += 1
	var tower: RtsUnit = game.spawn_unit(0, "siege_tower", target.position + Vector2(45, 0))
	tower.position = target.position + Vector2(45, 0)
	tower.order = "siege_tower_docked"
	tower.target = target
	tower._tick_visual(0.01)
	var deployed = State.capture(tower)
	assert(deployed.siege_deployed and deployed.facing_direction.x < 0.0)
	tower.order_stop()
	assert(not State.capture(tower).siege_deployed and deployed.siege_deployed)
	game.free()
	print("SIEGE_ACTIONS_OK attacks=%d deployment=1" % count)
	quit()

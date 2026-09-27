extends SceneTree

# Headless CPU benchmark for a live 200 versus 200 melee fight. Spawn and
# command setup are excluded from the measured simulation steps.
const UNITS_PER_SIDE := 200
const STEPS := 90
const STEP_SECONDS := 1.0 / 30.0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game("English", 4242)
	game.ai_controllers.clear()
	game.fog.active = false
	game.fog.hide()

	var center: Vector2 = game.world_size * 0.5
	var attackers: Array[RtsUnit] = []
	var defenders: Array[RtsUnit] = []
	var combatants: Array[RtsUnit] = []
	for index in UNITS_PER_SIDE:
		var column := index % 20
		var row := index / 20
		var pair_center := center + Vector2((column - 9.5) * 70.0, (row - 4.5) * 60.0)
		var attacker: RtsUnit = game.spawn_unit(0, "spearman", pair_center + Vector2(-15.0, 0.0))
		var defender: RtsUnit = game.spawn_unit(1, "spearman", pair_center + Vector2(15.0, 0.0))
		attacker.order_stop()
		defender.order_stop()
		attackers.append(attacker)
		defenders.append(defender)
		combatants.append(attacker)
		combatants.append(defender)
	game.navigation.invalidate_spatial_index()
	for index in UNITS_PER_SIDE:
		attackers[index].order_attack(defenders[index])
		defenders[index].order_attack(attackers[index])

	var initial_hp := _total_hp(combatants)
	var total_us := 0
	var peak_us := 0
	var attacks := 0
	for step in STEPS:
		var started := Time.get_ticks_usec()
		for unit in combatants:
			if not is_instance_valid(unit) or unit.is_queued_for_deletion(): continue
			var previous_attack_timer: float = unit.attack_timer
			unit._process(STEP_SECONDS)
			if unit.attack_timer > previous_attack_timer + STEP_SECONDS * 0.5: attacks += 1
		var elapsed_us := Time.get_ticks_usec() - started
		total_us += elapsed_us
		peak_us = maxi(peak_us, elapsed_us)

	var hp_lost := initial_hp - _total_hp(combatants)
	var survivors := 0
	for unit in combatants:
		if is_instance_valid(unit) and not unit.is_queued_for_deletion() and unit.hp > 0.0: survivors += 1
	print("PERFORMANCE_COMBAT units=%d steps=%d step_avg_ms=%.2f step_peak_ms=%.2f attacks=%d hp_lost=%.1f survivors=%d" % [combatants.size(), STEPS, total_us / (STEPS * 1000.0), peak_us / 1000.0, attacks, hp_lost, survivors])
	if attacks == 0 or hp_lost <= 0.0:
		push_error("Combat benchmark did not exercise attacks and damage")
		quit(1)
		return
	quit()

func _total_hp(units: Array[RtsUnit]) -> float:
	var total := 0.0
	for unit in units:
		if is_instance_valid(unit): total += maxf(0.0, unit.hp)
	return total

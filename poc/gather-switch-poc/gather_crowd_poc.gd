extends "res://poc/gather-switch-poc/gather_switch_poc.gd"

# Observe each actor's actual credits, including mixed crowds with miners.
# This subclass only records; every work callback delegates to production code.
class WitnessVillager extends RtsUnit:
	var earned := {"wood": 0, "gold": 0, "stone": 0}
	func _process_gather_order(delta: float) -> void:
		var before := {}
		for kind_name in earned: before[kind_name] = game.players[owner_id][kind_name]
		super._process_gather_order(delta)
		for kind_name in earned: earned[kind_name] += game.players[owner_id][kind_name] - before[kind_name]

func witness(point: Vector2) -> WitnessVillager:
	var unit := WitnessVillager.new()
	unit.position = game.world_map.nearest_walkable_point(point)
	game.add_child(unit)
	unit.setup(game, 0, "villager")
	unit.position = game.navigation.nearest_walkable_point(unit.position, unit.radius(), unit)
	game.session.entities.register(unit)
	return unit

func crowd_case(count: int, variant: String, queued_control := false) -> void:
	reset_sandbox()
	var trees: Array[RtsResource] = []
	var replacements: Array[RtsResource] = []
	var ore: Array[RtsResource] = []
	var passage := variant == "mixed_passage"
	var forest_x := 1170.0 if passage else 850.0
	for i in 8:
		trees.append(resource("wood", Vector2(forest_x + (i % 4) * 80, 800 + (i / 4) * 85), 70 if variant != "shared_live" else 100000))
	if variant == "shared_depleted":
		for i in 4: replacements.append(resource("wood", Vector2(forest_x + i * 80, 960), 70))
	# Both types are adjacent to the forest / busy passage, never a hidden choice.
	for i in 8:
		ore.append(resource("gold" if i % 2 == 0 else "stone", Vector2(forest_x - 65 + (i % 4) * 80, 1060 + (i / 4) * 80), 100000))
	if passage:
		# Wall with a 150px passage forces resource and military traffic together.
		for row in game.world_map.grid_size.y:
			if row < 13 or row > 15: game.world_map.cells[row * game.world_map.grid_size.x + 20] = RtsWorldMap.Terrain.MOUNTAIN
		game.navigation.invalidate_obstacles()
	var workers: Array[WitnessVillager] = []
	var authorized: Array[int] = []
	var background_miners: Array[WitnessVillager] = []
	for i in count:
		# The front row is nearest the forest; 22px spacing keeps starting bodies
		# separate while the shared targets force genuine later congestion.
		var start := Vector2((520.0 if passage else 710.0) + (i % 20) * 22, 735 - (i / 20) * 22)
		var unit := witness(start)
		workers.append(unit)
		unit.issue_command("gather", Vector2.INF, trees[i % trees.size()])
		if queued_control and i < 8:
			unit.issue_command("gather", Vector2.INF, ore[i], true)
			authorized.append(i)
	check(workers.all(func(u: WitnessVillager) -> bool: return u.order == "gather" and u.gather_kind == "wood"), "crowd fixture: all lumberjacks start on wood")
	check(workers.all(func(u: WitnessVillager) -> bool: return u.command_queue.is_empty()) if not queued_control else authorized.size() == 8, "crowd fixture: initial queue condition")
	if passage:
		for i in mini(100, count / 2):
			var miner := witness(ore[i % 8].position + Vector2(0, 32 + (i / 8) * 22))
			miner.issue_command("gather", Vector2.INF, ore[i % 8])
			background_miners.append(miner)
		for i in mini(100, count / 2):
			var soldier: RtsUnit = game.spawn_unit(0, "spearman", Vector2(1150 + (i % 10) * 24, 420 + (i / 10) * 24))
			soldier.issue_command("move", Vector2(700 + (i % 10) * 24, 920 + (i / 10) * 24))
	var total_units: int = game.units.size()
	var steps := 600
	var accepted_steps := 0
	var unexpected: Dictionary = {}
	var permitted: Dictionary = {}
	var queue_anomalies: Dictionary = {}
	var transitioned: Dictionary = {}
	var initial_target_ids: Array[int] = []
	for unit in workers: initial_target_ids.append(unit.target.get_instance_id())
	var history: Array[Dictionary] = []
	var started := Time.get_ticks_usec()
	print("CROWD_BEGIN count=%d variant=%s queued=%s total_units=%d" % [count, variant, queued_control, total_units])
	for tick in steps:
		if game.step(DT): accepted_steps += 1
		for i in workers.size():
			var unit := workers[i]
			var mining_target: bool = unit.order == "gather" and is_instance_valid(unit.target) and unit.target is RtsResource and unit.target.kind in ["gold", "stone"]
			if mining_target:
				if authorized.has(i):
					if not permitted.has(i): permitted[i] = snappedf((tick + 1) * DT, 0.001)
				elif not unexpected.has(i): unexpected[i] = {"t": snappedf((tick + 1) * DT, 0.001), "state": state(unit)}
			if not authorized.has(i) and (not unit.command_queue.is_empty() or unit.gather_kind != "wood"):
				if not queue_anomalies.has(i): queue_anomalies[i] = state(unit)
			if is_instance_valid(unit.target) and unit.target.get_instance_id() != initial_target_ids[i]: transitioned[i] = true
		if tick % 100 == 99:
			var orders := {}
			var worked := 0
			var earned_wood := 0
			for unit in workers:
				orders[unit.order] = int(orders.get(unit.order, 0)) + 1
				if unit.earned.wood > 0: worked += 1
				earned_wood += int(unit.earned.wood)
			history.append({"t": (tick + 1) * DT, "orders": orders, "wood_earners": worked, "wood_earned": earned_wood, "unexpected_miners": unexpected.size(), "authorized_miners": permitted.size()})
		if tick % 10 == 9: await process_frame
	var wood_earned := 0
	var wood_earners := 0
	var unexpected_income := 0
	var authorized_income := 0
	for i in workers.size():
		var earned: Dictionary = workers[i].earned
		wood_earned += int(earned.wood)
		if earned.wood > 0: wood_earners += 1
		if authorized.has(i): authorized_income += int(earned.gold) + int(earned.stone)
		else: unexpected_income += int(earned.gold) + int(earned.stone)
	var background_income := 0
	for unit in background_miners: background_income += int(unit.earned.gold) + int(unit.earned.stone)
	var old_depleted := 0
	for tree in trees:
		if not is_instance_valid(tree) or tree.is_queued_for_deletion() or tree.amount <= 0: old_depleted += 1
	var result := {"case": "crowd/%d/%s%s" % [count, variant, "/queued_control" if queued_control else ""],
		"lumberjacks": count, "total_units": total_units, "seconds": steps * DT,
		"steps": accepted_steps, "wall_seconds": (Time.get_ticks_usec() - started) / 1000000.0,
		"unexpected_mining_workers": unexpected, "queue_or_kind_anomalies": queue_anomalies,
		"unexpected_mining_income": unexpected_income, "authorized_mining_workers": permitted,
		"authorized_mining_income": authorized_income, "background_mining_income": background_income,
		"wood_earned": wood_earned, "wood_earners": wood_earners, "original_trees_depleted": old_depleted,
		"target_changed_workers": transitioned.size(), "history": history}
	cases.append(result)
	print("CASE ", JSON.stringify(result))
	check(accepted_steps == steps, result.case + ": all simulation steps ran")
	check(unexpected.is_empty() and queue_anomalies.is_empty(), result.case + ": no spontaneous target/kind/queue switch")
	check(unexpected_income == 0, result.case + ": every unqueued lumberjack earned zero gold/stone")
	check(wood_earned > 0 and wood_earners > 0, result.case + ": real wood harvesting occurred")
	if variant == "shared_depleted":
		check(old_depleted > 0 and not transitioned.is_empty(), result.case + ": depletion and follow-up actually occurred")
	if passage: check(background_income > 0, result.case + ": background miners actually mined")
	if queued_control: check(not permitted.is_empty() and authorized_income > 0, result.case + ": queued mining works amid crowding")

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.start_game("English", 4242)
	await process_frame
	var counts := [50, 100, 200, 400]
	var filter_count := OS.get_environment("RTS_GATHER_CROWD_COUNT")
	if filter_count != "": counts = [int(filter_count)]
	for count in counts:
		for variant in ["shared_live", "shared_depleted", "mixed_passage"]: await crowd_case(count, variant)
	for count in ([100, 400] if filter_count == "" else counts): await crowd_case(count, "shared_depleted", true)
	var output := OS.get_environment("RTS_GATHER_POC_OUTPUT")
	if output != "":
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file == null: check(false, "cannot write crowd JSON report")
		else: file.store_string(JSON.stringify({"engine": Engine.get_version_info(), "checks": checks, "failures": failures, "cases": cases}, "\t") + "\n")
	for voice in game.feedback_audio.voices:
		voice.stop()
		voice.stream = null
	game.free()
	print("GATHER_SWITCH_POC crowd_cases=%d checks=%d failures=%d" % [cases.size(), checks, failures])
	quit(1 if failures else 0)

extends SceneTree

# Run production game.step(): includes navigation jobs, AI, actors and fog.
# Only scenario setup issues commands. Observe every subsequent simulation tick.
const DT := 0.05
var game: Node2D
var checks := 0
var failures := 0
var cases: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("CHECK_%s %s" % ["OK" if ok else "FAIL", label])

func state(unit: RtsUnit) -> Dictionary:
	var resource := ""
	var remaining := -1
	var target_id := 0
	if is_instance_valid(unit.target):
		target_id = unit.target.get_instance_id()
		if unit.target is RtsResource:
			resource = unit.target.kind
			remaining = unit.target.amount
		elif unit.target is RtsBuilding: resource = unit.target.kind
	return {"order": unit.order, "target_kind": resource, "target_id": target_id,
		"remaining": remaining, "gather_kind": unit.gather_kind,
		"queue_size": unit.command_queue.size(), "owner": unit.owner_id}

func observe(label: String, unit: RtsUnit, seconds: float, expected_mining := false) -> Dictionary:
	var before := {"wood": game.players[unit.owner_id]["wood"],
		"gold": game.players[unit.owner_id]["gold"], "stone": game.players[unit.owner_id]["stone"]}
	var timeline: Array[Dictionary] = []
	var previous := ""
	var mining_ticks := 0
	var queue_nonempty_ticks := 0
	var accepted_steps := 0
	for tick in int(round(seconds / DT)):
		if game.step(DT): accepted_steps += 1
		var snapshot := state(unit)
		if snapshot.order == "gather" and snapshot.target_kind in ["gold", "stone"]: mining_ticks += 1
		if snapshot.queue_size > 0: queue_nonempty_ticks += 1
		# Log changes of order/target/queue; resource quantities remain in endpoints.
		var key := "%s/%s/%d/%d" % [snapshot.order, snapshot.target_kind, snapshot.target_id, snapshot.queue_size]
		if key != previous:
			snapshot["t"] = snappedf((tick + 1) * DT, 0.001)
			timeline.append(snapshot)
			previous = key
		# Godot's real event loop frees depleted resources and reaps native jobs.
		if tick % 20 == 19: await process_frame
	var gains := {}
	for kind in before: gains[kind] = game.players[unit.owner_id][kind] - before[kind]
	var result := {"case": label, "seconds": seconds, "steps": accepted_steps,
		"expected_mining": expected_mining, "mining_ticks": mining_ticks,
		"queue_nonempty_ticks": queue_nonempty_ticks, "gains": gains,
		"timeline": timeline, "final": state(unit)}
	cases.append(result)
	print("CASE ", JSON.stringify(result))
	check(accepted_steps == int(round(seconds / DT)), label + ": all simulation steps ran")
	check((mining_ticks > 0) == expected_mining, label + ": mining expectation")
	return result

func reset_sandbox() -> void:
	game.ai_controllers.clear()
	for collection in [game.units, game.buildings, game.resources, game.trade_posts, game.relics]:
		for entity in collection.duplicate():
			if is_instance_valid(entity): entity.free()
		collection.clear()
	game.selected.clear()
	game.world_map.cells.fill(RtsWorldMap.Terrain.GRASS)
	game.simulation.reset()
	game.match_statistics.reset(game)
	game.game_over = false
	game.paused = false
	game.fog.active = false
	# Keep both players alive so full match logic never terminates the experiment.
	game.spawn_building(0, "town_center", Vector2(250, 250))
	game.spawn_building(1, "town_center", Vector2(1800, 1200))
	for owner in game.players.size():
		game.players[owner]["age"] = 1
		for kind in ["wood", "food", "gold", "stone"]: game.players[owner][kind] = 0
	game.navigation.refresh()

func resource(kind: String, point: Vector2, amount := 10000) -> RtsResource:
	return game.spawn_resource(kind, point, amount, "tree" if kind == "wood" else "")

func sandbox_case(civ: String, variant: String, ore_kind: String) -> void:
	reset_sandbox()
	var old := resource("wood", Vector2(900, 600), 10000 if variant == "live" else 25)
	var ore := resource(ore_kind, Vector2(855, 655))
	var next: RtsResource
	if variant in ["neighbor", "deleted", "freed", "fog", "blocked"]:
		next = resource("wood", Vector2(970, 600))
	elif variant == "outside_radius":
		next = resource("wood", Vector2(1085, 600))
	var unit: RtsUnit = game.spawn_unit(0, "villager", Vector2(865, 600))
	unit.issue_command("gather", Vector2.INF, old)
	check(unit.order == "gather" and unit.target == old and unit.command_queue.is_empty(), civ + "/" + variant + ": initial wood order and empty queue")
	if variant == "fog":
		game.fog.reset("enabled")
		# Only ore is explored; fog cannot reveal the replacement tree during run.
		game.simulation.set_actor_enabled(game.fog, false)
		var explored: PackedByteArray = game.fog.explored_cells[0]
		explored.fill(0)
		var ore_cell: Vector2i = game.world_map.cell_at(ore.position)
		explored[ore_cell.y * game.world_map.grid_size.x + ore_cell.x] = 1
		game.fog.explored_cells[0] = explored
		check(not game.fog.can_show_resource(0, next) and game.fog.can_show_resource(0, ore), "fog fixture: replacement hidden, ore explored")
	elif variant == "blocked":
		# After the last harvest, separate the replacement tree with a terrain wall.
		for row in game.world_map.grid_size.y:
			game.world_map.cells[row * game.world_map.grid_size.x + 18] = RtsWorldMap.Terrain.MOUNTAIN
		game.navigation.invalidate_obstacles()
	elif variant == "deleted":
		old.queue_free()
	elif variant == "freed":
		old.free()
	var result: Dictionary = await observe("%s/%s/%s" % [civ, variant, ore_kind], unit, 30.0)
	check(result.queue_nonempty_ticks == 0, result.case + ": no queued commands appeared")
	check(result.gains.gold == 0 and result.gains.stone == 0 and ore.amount == 10000, result.case + ": ore untouched and no mining income")
	if variant in ["live", "neighbor", "deleted", "freed"]:
		check(unit.order == "gather" and unit.gather_kind == "wood" and result.gains.wood > 0, result.case + ": actually gathered wood")
	else:
		check(unit.order == "idle", result.case + ": idle when no eligible replacement")
	game.simulation.set_actor_enabled(game.fog, true)

func queued_controls() -> void:
	for ore_kind in ["gold", "stone"]:
		reset_sandbox()
		var old := resource("wood", Vector2(900, 600), 100)
		resource("wood", Vector2(970, 600)) # Queue has priority over nearby wood.
		var ore := resource(ore_kind, Vector2(855, 655))
		var unit: RtsUnit = game.spawn_unit(0, "villager", Vector2(865, 600))
		unit.issue_command("gather", Vector2.INF, old)
		unit.issue_command("gather", Vector2.INF, ore, true)
		check(unit.command_queue.size() == 1, "queued control: mining intent queued at setup")
		var result: Dictionary = await observe("control/queued_" + ore_kind, unit, 40.0, true)
		check(result.timeline[0].target_kind == "wood" and result.gains.wood == 100 and result.gains[ore_kind] > 0, result.case + ": wood depleted before queued mining")
	# A newly issued non-appended wood command must clear an older mining queue.
	reset_sandbox()
	var old := resource("wood", Vector2(900, 600), 25)
	var ore := resource("gold", Vector2(855, 655))
	var unit: RtsUnit = game.spawn_unit(0, "villager", Vector2(865, 600))
	unit.issue_command("gather", Vector2.INF, old)
	unit.issue_command("gather", Vector2.INF, ore, true)
	unit.issue_command("gather", Vector2.INF, old)
	check(unit.command_queue.is_empty(), "new non-appended wood command clears old mining queue")
	await observe("control/reissued_wood_clears_queue", unit, 30.0)
	# Low-level order_gather() differs: it starts an order but preserves its queue.
	reset_sandbox()
	old = resource("wood", Vector2(900, 600), 25)
	ore = resource("gold", Vector2(855, 655))
	unit = game.spawn_unit(0, "villager", Vector2(865, 600))
	unit.issue_command("move", Vector2(850, 600))
	unit.issue_command("gather", Vector2.INF, ore, true)
	unit.order_gather(old)
	check(unit.command_queue.size() == 1, "low-level order_gather preserves old queue")
	await observe("control/low_level_preserves_old_queue", unit, 30.0, true)

func construction_control() -> void:
	reset_sandbox()
	var old := resource("wood", Vector2(900, 600), 25)
	resource("wood", Vector2(970, 600))
	var ore := resource("gold", Vector2(830, 710))
	var camp: RtsBuilding = game.spawn_building(0, "mining_camp", Vector2(780, 650), true)
	var unit: RtsUnit = game.spawn_unit(0, "villager", Vector2(865, 600))
	unit.issue_command("gather", Vector2.INF, old)
	unit.issue_command("build", Vector2.INF, camp, true)
	var result: Dictionary = await observe("control/queued_mining_camp_then_auto_gold", unit, 80.0, true)
	check(camp.is_complete() and ore.amount < 10000 and result.gains.gold > 0, "queued camp completes and automatically assigns nearby gold")

func ai_control() -> void:
	reset_sandbox()
	var old := resource("wood", Vector2(900, 600), 25)
	var ore := resource("gold", Vector2(855, 655))
	var unit: RtsUnit = game.spawn_unit(1, "villager", Vector2(865, 600))
	unit.issue_command("gather", Vector2.INF, old)
	game.ai_controllers.append(RtsAiController.new(game, 1, "normal"))
	game.ai_think_timers[1] = 0.0
	var result: Dictionary = await observe("control/opponent_ai_depleted_wood_to_gold", unit, 40.0, true)
	check(result.gains.wood == 25 and ore.amount < 10000, "opponent AI changes resource after wood exhaustion")

func natural_matches() -> void:
	for seed_value in [4242, 44127]:
		game.start_game("English", seed_value, "French")
		await process_frame
		var workers: Array[RtsUnit] = []
		for unit in game.units:
			if unit.owner_id == 0 and unit.kind == "villager" and unit.gather_kind == "wood": workers.append(unit)
		check(workers.size() == 2 and game.ai_controllers.all(func(ai: RtsAiController) -> bool: return ai.owner_id != 0), "natural match: two lumberjacks; no player AI")
		var mining_ticks := 0
		var stopped := 0
		var wood_before: int = game.players[0]["wood"]
		for tick in 2400:
			if not game.step(DT): stopped += 1
			for worker in workers:
				if worker.order == "gather" and is_instance_valid(worker.target) and worker.target is RtsResource and worker.target.kind in ["gold", "stone"]: mining_ticks += 1
			if tick % 20 == 19: await process_frame
		var result := {"case": "natural_match/seed_%d" % seed_value, "seconds": 120,
			"mining_ticks": mining_ticks, "rejected_steps": stopped, "wood_gain": game.players[0]["wood"] - wood_before,
			"final": workers.map(func(u: RtsUnit) -> Dictionary: return state(u))}
		cases.append(result)
		print("CASE ", JSON.stringify(result))
		check(mining_ticks == 0 and stopped == 0 and result.wood_gain > 0, result.case + ": lumberjacks stay off ore in full match")

func player_order_controls() -> void:
	# Exercise the same context-order dispatcher as a right click, with explicit
	# append flags. No synthetic mouse event or command is sent during observation.
	for append_mining in [false, true]:
		reset_sandbox()
		var old := resource("wood", Vector2(900, 600), 100)
		var ore := resource("gold", Vector2(855, 655))
		var unit: RtsUnit = game.spawn_unit(0, "villager", Vector2(865, 600))
		game.selected.assign([unit])
		var ore_point: Vector2 = ore.position + (RtsIsoProjection.ground_lift(game, ore.position) if game.view_mode_25d else Vector2.ZERO)
		var wood_point: Vector2 = old.position + (RtsIsoProjection.ground_lift(game, old.position) if game.view_mode_25d else Vector2.ZERO)
		game._issue_order(wood_point)
		game._issue_order(ore_point, true)
		if not append_mining: game._issue_order(wood_point)
		check(unit.order == "gather" and unit.target == old and unit.command_queue.size() == (1 if append_mining else 0), "player dispatcher fixture: wood target and expected queue")
		var label := "control/player_dispatcher_" + ("queued_gold" if append_mining else "wood_clears_gold_queue")
		var result: Dictionary = await observe(label, unit, 40.0, append_mining)
		check((result.gains.gold > 0) == append_mining, label + ": gold income follows append intent")

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	for civ in GameData.CIVILIZATIONS:
		game.start_game(civ, 4242)
		await process_frame
		for variant in ["live", "neighbor", "no_tree", "outside_radius", "deleted", "freed", "fog", "blocked"]:
			for ore_kind in ["gold", "stone"]: await sandbox_case(civ, variant, ore_kind)
	await queued_controls()
	await player_order_controls()
	await construction_control()
	await ai_control()
	await natural_matches()
	var report := {"engine": Engine.get_version_info(), "checks": checks,
		"failures": failures, "cases": cases}
	var output := OS.get_environment("RTS_GATHER_POC_OUTPUT")
	if output != "":
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file == null:
			check(false, "cannot write JSON report")
		else: file.store_string(JSON.stringify(report, "\t") + "\n")
	for voice in game.feedback_audio.voices:
		voice.stop()
		voice.stream = null
	game.free()
	print("GATHER_SWITCH_POC cases=%d checks=%d failures=%d" % [cases.size(), checks, failures])
	quit(1 if failures else 0)

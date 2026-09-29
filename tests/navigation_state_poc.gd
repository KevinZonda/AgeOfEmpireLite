extends "res://tests/navigation_construction_poc.gd"

# Real command/state transitions, separate from the geometric corner suite.
func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game("English", 4242)
	game.ai_controllers.clear()
	game.set_process(false)
	game.fog.active = false
	var section := OS.get_environment("RTS_STATE_SECTION")
	if section in ["", "gather"]: _test_gather_transitions()
	if section in ["", "farm_queue"]: _test_busy_farm_queue()
	if section in ["", "unload"]: _test_unload_spacing()
	if section in ["", "boarding"]: _test_boarding_barrier()
	if section in ["", "retreat"]: _test_siege_retreat()
	if section in ["", "landing"]: _test_blocked_landing()
	if section in ["", "landing_route"]: _test_landing_route()
	if section in ["", "spawn"]: _test_spawn_spacing()
	if section in ["", "production"]: _test_production_spacing()
	if section in ["", "targets"]: await _test_changed_targets()
	for voice in game.feedback_audio.voices:
		voice.stop()
		voice.stream = null
	game.free()
	print("NAVIGATION_STATE_POC checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)

func actor(kind: String, point: Vector2, owner := 0) -> RtsUnit:
	var unit: RtsUnit = game.spawn_unit(owner, kind, point)
	unit.set_process(false)
	unit.engagement = "passive"
	return unit

func structure(kind: String, point: Vector2) -> RtsBuilding:
	var target: RtsBuilding = game.spawn_building(0, kind, point)
	target.set_process(false)
	return target

func tree(point: Vector2, amount := 1000) -> RtsResource:
	var node: RtsResource = game.spawn_resource("wood", point, amount, "tree")
	node.set_process(false)
	return node

func set_coast(x_cell: int) -> void:
	for y in game.world_map.grid_size.y:
		for x in range(x_cell, game.world_map.grid_size.x):
			game.world_map.cells[y * game.world_map.grid_size.x + x] = RtsWorldMap.Terrain.WATER
	game.navigation.refresh()

func overlap_count(units: Array[RtsUnit]) -> int:
	var count := 0
	for i in units.size():
		for j in range(i + 1, units.size()):
			if units[i].position.distance_to(units[j].position) < units[i].radius() + units[j].radius() - 0.001: count += 1
	return count

func _test_gather_transitions() -> void:
	for separation in [24.0, 30.0, 40.0, 48.0, 64.0]:
		for angle in 4:
			reset()
			var direction := Vector2.from_angle(angle * PI / 2)
			var old := tree(Vector2(900, 600), 1)
			var next := tree(old.position + direction * separation)
			var unit := worker(old.position - direction * 34)
			unit.issue_command("gather", Vector2.INF, old)
			tick([unit], 160)
			check(next.amount < 1000 and unit.order == "gather", "auto_gather_sep%d_angle%d" % [separation, angle], "remaining=%d order=%s" % [next.amount, unit.order])
	for with_neighbor in [false, true]:
		reset()
		var old := tree(Vector2(900, 600), 1)
		if with_neighbor: tree(Vector2(948, 600), 1000)
		var unit := worker(Vector2(866, 600))
		unit.issue_command("gather", Vector2.INF, old)
		unit.issue_command("move", Vector2(650, 600), null, true)
		tick([unit], 200)
		check(unit.order == "idle" and unit.command_queue.is_empty() and unit.position.distance_to(Vector2(650, 600)) < 7, "depleted_gather_follows_explicit_queue_neighbor%s" % with_neighbor, "order=%s queue=%d pos=%s" % [unit.order, unit.command_queue.size(), unit.position])

func _test_busy_farm_queue() -> void:
	for occupied in [false, true]:
		for extra_farm in [false, true]:
			reset()
			var farm := structure("farm", Vector2(900, 600))
			if extra_farm: structure("farm", Vector2(800, 700))
			if occupied:
				var farmer := worker(farm.position + Vector2(0, -40))
				farmer.issue_command("gather", Vector2.INF, farm)
			var unit := worker(Vector2(650, 600))
			unit.issue_command("move", Vector2(750, 600))
			unit.issue_command("gather", Vector2.INF, farm, true)
			unit.issue_command("move", Vector2(650, 450), null, true)
			tick([unit], 100)
			if occupied and not extra_farm:
				check(not unit.command_queue.is_empty() or unit.position.distance_to(Vector2(650, 450)) < 7, "busy_farm_preserves_followup_move", "order=%s queue=%d pos=%s" % [unit.order, unit.command_queue.size(), unit.position])
			else:
				check(unit.order == "gather" and unit.command_queue.size() == 1, "farm_queue_control_occupied%s_extra%s" % [occupied, extra_farm], "order=%s queue=%d" % [unit.order, unit.command_queue.size()])

	# Failed queued commands are drained iteratively, even for long task lists.
	reset()
	var farm := structure("farm", Vector2(900, 600))
	var farmer := worker(farm.position + Vector2(0, -40))
	farmer.issue_command("gather", Vector2.INF, farm)
	var unit := worker(Vector2(650, 600))
	unit.issue_command("move", Vector2(750, 600))
	for i in 2048: unit.issue_command("gather", Vector2.INF, farm, true)
	unit.issue_command("move", Vector2(650, 450), null, true)
	tick([unit], 200)
	check(unit.order == "idle" and unit.command_queue.is_empty() and unit.position.distance_to(Vector2(650, 450)) < 7, "busy_farm_long_queue_drains_iteratively")

func _test_unload_spacing() -> void:
	for carrier_kind in ["town_center", "battering_ram", "transport_ship"]:
		for passenger_kind in ["villager", "knight"]:
			for variant in 6:
				var count: int = [2, 4, 8][variant % 3]
				var serial := variant >= 3
				reset()
				var carrier: Node2D
				if carrier_kind == "town_center": carrier = structure(carrier_kind, Vector2(800, 600))
				else:
					if carrier_kind == "transport_ship": set_coast(16)
					carrier = actor(carrier_kind, Vector2(825, 525) if carrier_kind == "transport_ship" else Vector2(800, 600))
				var passengers: Array[RtsUnit] = []
				var boarded := 0
				for i in count:
					var unit := actor(passenger_kind, Vector2(750, 525) if carrier_kind == "transport_ship" else carrier.position + Vector2(-70, 0))
					passengers.append(unit)
					if carrier.garrison_unit(unit): boarded += 1
				var label := "unload_%s_%s_%d_serial%s" % [carrier_kind, passenger_kind, count, serial]
				check(boarded == count, label + "_setup", "%d boarded" % boarded)
				if serial:
					# Public unload calls for one passenger at a time invalidate the
					# spatial index between exits. The same bodies/shore remain.
					for unit in passengers:
						if carrier is RtsBuilding: carrier.garrisoned_units.assign([unit])
						else: carrier.passengers.assign([unit])
						carrier.ungarrison_all()
				else: carrier.ungarrison_all()
				check(passengers.all(func(u: RtsUnit) -> bool: return u.garrisoned_in == null), label + "_exits")
				check(overlap_count(passengers) == 0, label + "_no_overlap", "%d pairs %s" % [overlap_count(passengers), passengers.map(func(u: RtsUnit) -> Variant: return u.position)])

func _test_boarding_barrier() -> void:
	for kind in ["battering_ram", "siege_tower"]:
		for sealed in [false, true]:
			reset()
			# Four legally placeable wall pieces close a 300px mountain pass.
			if sealed:
				for x in game.world_map.grid_size.x:
					if x < 15 or x >= 21: game.world_map.cells[12 * game.world_map.grid_size.x + x] = RtsWorldMap.Terrain.MOUNTAIN
				for i in 4:
					var point := Vector2(787.5 + i * 75, 612.5)
					check(game.can_place("palisade_wall", point), "boarding_%s_wall%d_placeable" % [kind, i])
					structure("palisade_wall", point)
				game.navigation.refresh()
			var carrier := actor(kind, Vector2(900, 650))
			var unit := actor("spearman", Vector2(900, 575))
			var route: PackedVector2Array = game.navigation.path_between(unit.position, carrier.position + Vector2(50, 0), unit)
			check(route.is_empty() == sealed, "boarding_%s_sealed%s_route_control" % [kind, sealed])
			unit.issue_command("board_transport", Vector2.INF, carrier)
			tick([unit], 120)
			check((unit.garrisoned_in == null) if sealed else unit.garrisoned_in == carrier, "boarding_%s_sealed%s_respects_barrier" % [kind, sealed], "boarded=%s pos=%s" % [unit.garrisoned_in == carrier, unit.position])

func _test_siege_retreat() -> void:
	for kind in ["mangonel", "trebuchet", "bombard"]:
		for obstructed in [false, true]:
			reset()
			var unit := actor(kind, Vector2(900, 600))
			var enemy := actor("spearman", Vector2(955, 600), 1)
			var profile: Dictionary = RtsStatResolver.attack_profile(unit.stats, enemy.stats)
			var minimum: float = profile.get("min_range", unit.stats.get("min_range", 0.0)) + enemy.radius()
			var retreat_x: float = enemy.position.x - minimum - 10
			if obstructed:
				# A normal vertical palisade blocks retreat, without covering the
				# attacker's body. A perpendicular escape remains fully open.
				var wall: RtsBuilding = game.spawn_building(0, "palisade_wall", Vector2(retreat_x - 12, 600), false, "", true)
				wall.set_process(false)
				game.navigation.refresh()
			var witness := unit.position + Vector2(0, -minimum - 25)
			check(not game.navigation.path_between(unit.position, witness, unit).is_empty() and witness.distance_to(enemy.position) > minimum, "retreat_%s_obstructed%s_witness" % [kind, obstructed])
			unit.issue_command("attack", Vector2.INF, enemy)
			var fired := false
			for step in 600:
				unit._process(0.05)
				if unit.attack_timer > 0:
					fired = true
					break
			check(fired, "retreat_%s_obstructed%s_can_fire" % [kind, obstructed], "minimum=%.1f pos=%s goal=%s" % [minimum, unit.position, unit.route_goal])

func _test_blocked_landing() -> void:
	for variant in 3:
		var blocked := variant > 0
		reset()
		set_coast(16)
		var boat := actor("transport_ship", Vector2(825, 525))
		var unit := actor("spearman", Vector2(750, 525))
		check(boat.garrison_unit(unit), "landing_variant%d_setup" % variant)
		if blocked:
			# Both farms stay on land and outside the boat body.
			structure("farm", Vector2(725 if variant == 1 else 750, 525))
		check(game.navigation.can_occupy(boat.position, boat.radius(), boat, false, false), "landing_variant%d_boat_start_valid" % variant)
		var pair: Dictionary = game.find_landing_pair(boat, Vector2(775, 525))
		check(not pair.is_empty(), "landing_variant%d_pair_exists" % variant)
		if not pair.is_empty():
			check(game.navigation.can_occupy(pair["land"], unit.radius(), unit, false, false), "landing_variant%d_land_is_free" % variant, str(pair))
		boat.issue_command("unload", Vector2(775, 525))
		tick([boat], 300)
		check(unit.garrisoned_in == null and game.navigation.can_occupy(unit.position, unit.radius(), unit, false, false), "landing_variant%d_finishes_safely" % variant, str(unit.position))

func _test_landing_route() -> void:
	for spacing in [80, 100, 125]:
		reset()
		for y in game.world_map.grid_size.y:
			for x in range(8, 20): game.world_map.cells[y * game.world_map.grid_size.x + x] = RtsWorldMap.Terrain.WATER
		game.navigation.refresh()
		var boat := actor("transport_ship", Vector2(425, 525))
		var unit := actor("spearman", Vector2(375, 525))
		check(boat.garrison_unit(unit), "landing_route_spacing%d_boarded" % spacing)
		for i in ceili(game.world_size.y / spacing):
			var fish: RtsResource = game.spawn_resource("food", Vector2(700, 25 + i * spacing), 420, "fish")
			fish.set_process(false)
		var pair: Dictionary = game.find_landing_pair(boat, Vector2(1025, 525))
		check(not pair.is_empty(), "landing_route_spacing%d_pair_exists" % spacing)
		if not pair.is_empty():
			var path: PackedVector2Array = game.navigation.path_between(boat.position, pair["water"], boat)
			check(not path.is_empty(), "landing_route_spacing%d_water_reachable" % spacing, "pair=%s points=%d" % [pair, path.size()])
		# The left shore is always a reachable fallback within the 750px range.
		check(not game.navigation.path_between(boat.position, Vector2(425, 625), boat).is_empty(), "landing_route_spacing%d_fallback_witness" % spacing)
		boat.issue_command("unload", Vector2(1025, 525))
		tick([boat], 800)
		check(unit.garrisoned_in == null, "landing_route_spacing%d_unloads" % spacing, "order=%s pos=%s" % [boat.order, boat.position])

func _test_spawn_spacing() -> void:
	for kind in ["villager", "knight", "battering_ram"]:
		for count in [2, 4, 8]:
			reset()
			var units: Array[RtsUnit] = []
			for i in count:
				var unit := actor(kind, Vector2(800, 600))
				unit.order_hold()
				units.append(unit)
			check(overlap_count(units) == 0, "spawn_%s_%d_no_overlap" % [kind, count], "%d pairs %s" % [overlap_count(units), units.map(func(u: RtsUnit) -> Variant: return u.position)])

func _test_production_spacing() -> void:
	for kind in ["spearman", "knight"]:
		reset()
		seed(2026092903)
		structure("town_center", Vector2(450, 400))
		var producer := structure("barracks" if kind == "spearman" else "stable", Vector2(900, 600))
		var units: Array[RtsUnit] = []
		var trained := 0
		for i in 8:
			if not game.train_unit(producer, kind): break
			var previous: int = game.units.size()
			producer._process(100)
			if game.units.size() == previous + 1:
				trained += 1
				var unit: RtsUnit = game.units.back()
				unit.set_process(false)
				unit.engagement = "passive"
				unit.order_hold()
				units.append(unit)
		check(trained == 8, "production_%s_setup" % kind, "%d trained" % trained)
		check(overlap_count(units) == 0, "production_%s_no_overlap" % kind, "%d pairs %s" % [overlap_count(units), units.map(func(u: RtsUnit) -> Variant: return u.position)])

func _test_changed_targets() -> void:
	for kind in ["spearman", "archer"]:
		for transition in ["visible", "deleted", "garrisoned", "embarked", "converted"]:
			reset()
			var enemy := actor("spearman", Vector2(1050, 600), 1)
			var attacker := actor(kind, Vector2(700, 600))
			attacker.issue_command("attack", Vector2.INF, enemy)
			attacker.issue_command("move", Vector2(600, 400), null, true)
			if transition == "deleted":
				game.entity_destroyed(enemy)
				await process_frame
			elif transition == "garrisoned":
				var center: RtsBuilding = game.spawn_building(1, "town_center", Vector2(1150, 600))
				center.set_process(false)
				enemy.issue_command("garrison", Vector2.INF, center)
				tick([enemy], 200)
				check(enemy.garrisoned_in == center, "target_%s_%s_setup" % [kind, transition])
			elif transition == "embarked":
				var ram := actor("battering_ram", Vector2(1120, 600), 1)
				enemy.issue_command("board_transport", Vector2.INF, ram)
				tick([enemy], 200)
				check(enemy.garrisoned_in == ram, "target_%s_%s_setup" % [kind, transition])
			elif transition == "converted":
				var monk := actor("monk", Vector2(1100, 700))
				var relic := RtsRelic.new()
				relic.game = game
				game.add_child(relic)
				relic.set_process(false)
				game.relics.append(relic)
				monk.carried_relic = relic
				relic.carried_by = monk
				monk._finish_conversion()
				check(enemy.owner_id == attacker.owner_id, "target_%s_converted_setup" % kind)
			var fired := false
			for step in 600:
				attacker._process(0.05)
				if attacker.attack_timer > 0:
					fired = true
					break # Stop before damage/death can mask the target-validity bug.
			var label := "target_%s_%s" % [kind, transition]
			if transition == "visible":
				check(fired, label + "_attack_control")
				continue
			check(not fired, label + "_not_attacked_after_transition")
			check(attacker.order == "idle" and attacker.command_queue.is_empty() and attacker.position.distance_to(Vector2(600, 400)) < 7, label + "_queue_resumes", "order=%s queue=%d pos=%s" % [attacker.order, attacker.command_queue.size(), attacker.position])

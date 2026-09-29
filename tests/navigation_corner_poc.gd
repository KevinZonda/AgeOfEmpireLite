extends "res://tests/navigation_dense_poc.gd"

# Independent geometry deliberately does not call navigation collision code.
# This catches errors shared by path validation, smoothing and movement itself.
func oracle_point(game: Fixture, point: Vector2, radius: float, unit: RtsUnit) -> bool:
	if point.x < radius or point.y < radius or point.x > game.world_size.x - radius or point.y > game.world_size.y - radius: return false
	var naval: bool = unit.stats.get("tags", []).has("naval")
	for obstacle in game.buildings:
		if obstacle.kind.ends_with("_gate") and obstacle.is_complete() and not game.is_enemy(unit.owner_id, obstacle.owner_id): continue
		if Rect2(obstacle.position - obstacle.size() / 2, obstacle.size()).grow(radius).has_point(point): return false
	for obstacle in game.resources:
		if point.distance_squared_to(obstacle.position) < pow(radius + obstacle.radius, 2) - 0.0001: return false
	for y in range(maxi(0, floori((point.y - radius) / 50)), mini(game.world_map.grid_size.y, floori((point.y + radius) / 50) + 1)):
		for x in range(maxi(0, floori((point.x - radius) / 50)), mini(game.world_map.grid_size.x, floori((point.x + radius) / 50) + 1)):
			var terrain: int = game.world_map.cells[y * game.world_map.grid_size.x + x]
			if (terrain == RtsWorldMap.Terrain.WATER) == naval and terrain != RtsWorldMap.Terrain.MOUNTAIN: continue
			var closest := point.clamp(Vector2(x, y) * 50, Vector2(x + 1, y + 1) * 50)
			if point.distance_squared_to(closest) < radius * radius - 0.0001: return false
	return true

func oracle_segment(game: Fixture, from: Vector2, to: Vector2, unit: RtsUnit) -> bool:
	if not oracle_point(game, from, unit.radius(), unit) or not oracle_point(game, to, unit.radius(), unit): return false
	for obstacle in game.resources:
		var closest := Geometry2D.get_closest_point_to_segment(obstacle.position, from, to)
		if closest.distance_squared_to(obstacle.position) < pow(unit.radius() + obstacle.radius, 2) - 0.0001: return false
	for obstacle in game.buildings:
		if obstacle.kind.ends_with("_gate") and obstacle.is_complete() and not game.is_enemy(unit.owner_id, obstacle.owner_id): continue
		var bounds := Rect2(obstacle.position - obstacle.size() / 2, obstacle.size()).grow(unit.radius() - 0.0001)
		if segment_rect_distance_squared(from, to, bounds) == 0: return false
	var naval: bool = unit.stats.get("tags", []).has("naval")
	var region := Rect2(from, Vector2.ZERO).expand(to).grow(unit.radius())
	for y in range(maxi(0, floori(region.position.y / 50)), mini(game.world_map.grid_size.y, floori(region.end.y / 50) + 1)):
		for x in range(maxi(0, floori(region.position.x / 50)), mini(game.world_map.grid_size.x, floori(region.end.x / 50) + 1)):
			var terrain: int = game.world_map.cells[y * game.world_map.grid_size.x + x]
			if (terrain == RtsWorldMap.Terrain.WATER) == naval and terrain != RtsWorldMap.Terrain.MOUNTAIN: continue
			if segment_rect_distance_squared(from, to, Rect2(Vector2(x, y) * 50, Vector2(50, 50))) < unit.radius() * unit.radius() - 0.0001: return false
	return true

func segment_rect_distance_squared(from: Vector2, to: Vector2, bounds: Rect2) -> float:
	if bounds.has_point(from) or bounds.has_point(to): return 0.0
	var points := [bounds.position, Vector2(bounds.end.x, bounds.position.y), bounds.end, Vector2(bounds.position.x, bounds.end.y)]
	var distance := minf(from.distance_squared_to(from.clamp(bounds.position, bounds.end)), to.distance_squared_to(to.clamp(bounds.position, bounds.end)))
	for i in 4:
		if Geometry2D.segment_intersects_segment(from, to, points[i], points[(i + 1) % 4]) != null: return 0.0
		distance = minf(distance, points[i].distance_squared_to(Geometry2D.get_closest_point_to_segment(points[i], from, to)))
	return distance

func oracle_path(game: Fixture, unit: RtsUnit, path: PackedVector2Array) -> bool:
	if path.is_empty(): return false
	var previous := unit.position
	for point in path:
		if not oracle_segment(game, previous, point, unit): return false
		previous = point
	return true

func _run() -> void:
	var section := OS.get_environment("RTS_CORNER_SECTION")
	if section in ["", "sweeps"]: _test_grazing_sweeps()
	if section in ["", "slots"]: _test_mixed_slots()
	if section in ["", "slits"]: _test_resource_slits()
	if section in ["", "moving"]: await _test_small_resource_moves()
	if section in ["", "groups"]: _test_disconnected_groups()
	if section in ["", "slots_wall"]: _test_wall_slots()
	if section in ["", "queue"]: _test_group_queue()
	if section in ["", "transitions"]: _test_gate_transitions()
	if section in ["", "fuzz"]: _test_seeded_routes()
	print("NAVIGATION_CORNER_POC checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)

func _test_grazing_sweeps() -> void:
	for kind in ["terrain", "resource", "building", "unit"]:
		for radius in [10.0, 12.0, 18.0, 24.0, 28.0]:
			for corner in 4:
				var game := fixture()
				var obstacle_center := Vector2(625, 525)
				var normal := Vector2.from_angle(PI / 4 + corner * PI / 2)
				var tangent := normal.orthogonal()
				var length: float = radius * 0.5
				var midpoint: Vector2
				if kind == "terrain":
					block(game, 12, 10)
					midpoint = obstacle_center + normal.sign() * 25 + normal * (radius - 0.02)
				elif kind == "resource":
					resource(game, obstacle_center, 22)
					midpoint = obstacle_center + normal * (radius + 22 - 0.02)
				elif kind == "building":
					building(game, obstacle_center, Vector2(50, 50))
					midpoint = obstacle_center + normal.sign() * (25 + radius - radius * 0.1)
				else:
					var guard := game.spawn_unit(obstacle_center)
					guard.owner_id = 1
					guard.order = "hold"
					guard.stance = "hold"
					midpoint = obstacle_center + normal * (radius + guard.radius() - 0.02)
				var unit := game.spawn_unit(midpoint - tangent * length / 2)
				unit.stats["radius"] = radius
				var goal: Vector2 = midpoint + tangent * length / 2
				game.navigation.refresh()
				var label := "%s_r%d_corner%d" % [kind, radius, corner]
				var endpoints_clear := oracle_point(game, unit.position, radius, unit) and oracle_point(game, goal, radius, unit)
				if kind == "unit": endpoints_clear = endpoints_clear and unit.position.distance_to(obstacle_center) >= radius + 12 and goal.distance_to(obstacle_center) >= radius + 12
				check(endpoints_clear, label + "_endpoints")
				if kind != "unit":
					var path := game.navigation.path_between(unit.position, goal, unit)
					check(oracle_path(game, unit, path), label + "_safe_path", str(path))
				var next := game.navigation.move_step(unit, goal)
				var safe := oracle_segment(game, unit.position, next, unit)
				if kind == "unit":
					var nearest := Geometry2D.get_closest_point_to_segment(obstacle_center, unit.position, next)
					safe = nearest.distance_to(obstacle_center) >= radius + 12 - 0.0001
				check(safe, label + "_safe_motion", "%s -> %s" % [unit.position, next])
				game.free()

func _test_mixed_slots() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026092901
	for sample in 160:
		var game := fixture()
		var target := Vector2(925, 525)
		# Legal, separated farm footprints; no overlapping buildings.
		for attempt in 30:
			if game.buildings.size() == 3: break
			var point := target + Vector2(rng.randi_range(-5, 5), rng.randi_range(-5, 5)) * 25
			if game.buildings.any(func(b: RtsBuilding) -> bool: return absf(b.position.x - point.x) < 75 and absf(b.position.y - point.y) < 75): continue
			var farm := building(game, point, GameData.BUILDINGS["farm"]["size"])
			farm.kind = "farm"
		var units: Array[RtsUnit] = []
		var kinds := ["scout", "knight", "horseman"] if sample < 80 else ["battering_ram", "bombard", "trebuchet"]
		for i in 6:
			var unit := game.spawn_unit(Vector2(225 + (i % 2) * 80, 250 + (i / 2) * 85))
			unit.kind = kinds[i % 3]
			unit.stats = GameData.UNITS[unit.kind].duplicate(true)
			unit.engagement = "passive"
			units.append(unit)
		var group := group_for(game, units, target)
		var invalid: Array = []
		for unit in units:
			if not oracle_point(game, group.destination_for(unit), unit.radius(), unit):
				invalid.append([unit.kind, unit.radius(), group.destination_for(unit)])
		check(invalid.is_empty(), "mixed_slots_seed2026092901_sample%d" % sample, "%s buildings=%s" % [invalid, game.buildings.map(func(b: RtsBuilding) -> Variant: return b.position)])
		if sample in [0, 1, 8, 69, 77, 82, 85, 108, 115, 134, 140, 146, 158]:
			tick_group(group, 3000)
			var idle := units.filter(func(u: RtsUnit) -> bool: return u.order == "idle").size()
			check(idle == units.size(), "mixed_slots_sample%d_eventual_completion" % sample, "%d/6 %s" % [idle, units.map(func(u: RtsUnit) -> Variant: return [u.kind, u.position, u.destination, u.order])])
			if sample in [82, 85, 108, 134]: _check_isolated_recovery(game, units, "mixed_%d" % sample)
		game.free()

func _test_resource_slits() -> void:
	for radius in [10.0, 12.0, 18.0]:
		for margin in [0.5, 1.0, 2.0, 4.0, 8.0]:
			for mirrored in [false, true]:
				var game := fixture()
				for y in 20:
					if y != 10: block(game, 12, y)
				# The resource closes all but a known positive-clearance strip.
				var center_y: float = 500 + radius * 2 + 8 + margin
				if mirrored: center_y = 1050 - center_y
				resource(game, Vector2(625, center_y), 8)
				var crossing_y: float = 500 + radius + margin / 2
				if mirrored: crossing_y = 1050 - crossing_y
				var unit := game.spawn_unit(Vector2(225, 425))
				unit.stats["radius"] = radius
				unit.stats["speed"] = 180.0
				var goal := Vector2(1025, 625)
				var witness := PackedVector2Array([unit.position, Vector2(550, crossing_y), Vector2(700, crossing_y), goal])
				var label := "resource_slit_r%d_margin%s_mirror%s" % [radius, margin, mirrored]
				check(oracle_path(game, unit, witness), label + "_witness")
				var path := game.navigation.path_between(unit.position, goal, unit)
				check(oracle_path(game, unit, path), label + "_route", str(path))
				game.free()

func _test_small_resource_moves() -> void:
	for offset in [-4.0, -3.5, -3.0, -2.5, -2.0, 0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0]:
		var game := fixture()
		for y in 20:
			if y != 10: block(game, 12, y)
		var animal := resource(game, Vector2(625, 540 + offset), 8)
		var unit := game.spawn_unit(Vector2(225, 425))
		var goal := Vector2(1025, 625)
		var cold := game.navigation.path_between(unit.position, goal, unit)
		var previous := animal.position
		animal.position.y += 1.0
		game.navigation.resource_moved(animal, previous)
		await process_frame
		var warm := game.navigation.path_between(unit.position, goal, unit)
		game.navigation.refresh()
		var fresh := game.navigation.path_between(unit.position, goal, unit)
		check(warm.is_empty() == fresh.is_empty(), "resource_motion_cache_offset%s" % offset, "cold=%d warm=%d fresh=%d" % [cold.size(), warm.size(), fresh.size()])
		check(warm.is_empty() or oracle_path(game, unit, warm), "resource_motion_safe_offset%s" % offset)
		game.free()

func _test_disconnected_groups() -> void:
	for radius in [12.0, 28.0]:
		for reversed in [false, true]:
			var game := fixture()
			for y in 20: block(game, 12, y)
			game.navigation.refresh()
			var units: Array[RtsUnit] = []
			for i in 4:
				var unit := game.spawn_unit(Vector2(525 if i < 2 else 725, 450 + (i % 2) * 65))
				unit.stats["radius"] = radius
				unit.stats["speed"] = 180.0
				units.append(unit)
			if reversed: units.reverse()
			var group := group_for(game, units, Vector2(1100, 600))
			var reachable: Array[RtsUnit] = []
			for unit in units:
				if unit.position.x > 650: reachable.append(unit)
			tick_group(group, 800)
			var idle := units.filter(func(u: RtsUnit) -> bool: return u.order == "idle").size()
			check(idle == units.size(), "disconnected_group_r%d_reverse%s" % [radius, reversed], "%d/4 %s" % [idle, units.map(func(u: RtsUnit) -> Variant: return [u.position, u.destination, u.order])])
			check(reachable.all(func(u: RtsUnit) -> bool: return u.position.distance_to(Vector2(1100, 600)) < 180), "disconnected_group_reachable_members_r%d_reverse%s" % [radius, reversed])
			game.free()

func _test_wall_slots() -> void:
	for formation in ["balanced", "line", "compact", "column"]:
		for near in [false, true]:
			var game := fixture()
			for x in 30: block(game, x, 10)
			game.navigation.refresh()
			var units: Array[RtsUnit] = []
			for i in 6:
				var unit := game.spawn_unit(Vector2((800 if near else 200) + (i % 2) * 35, 350 + (i / 2) * 35))
				unit.stats["speed"] = 180.0
				units.append(unit)
			var group := group_for(game, units, Vector2(1000, 475), formation)
			var inaccessible := 0
			for unit in units:
				if game.navigation.path_between(unit.position, group.destination_for(unit), unit).is_empty(): inaccessible += 1
			check(inaccessible == 0, "wall_slots_%s_near%s_reachable" % [formation, near], "%d/6 inaccessible" % inaccessible)
			tick_group(group, 3000)
			check(units.all(func(u: RtsUnit) -> bool: return u.order == "idle"), "wall_slots_%s_near%s_finish" % [formation, near], str(units.map(func(u: RtsUnit) -> Variant: return [u.position, u.destination, u.order])))
			if not near and formation in ["compact", "column"]: _check_isolated_recovery(game, units, "wall_" + formation)
			game.free()

func _check_isolated_recovery(original: Fixture, units: Array[RtsUnit], label: String) -> void:
	# Controls distinguish a static route failure from congestion among allies.
	var alone_succeed := true
	var stalled := 0
	for source in units:
		if source.order == "idle": continue
		stalled += 1
		var waypoint := source.route[mini(source.route_index, source.route.size() - 1)] if not source.route.is_empty() else source.destination
		var local := original.navigation.path_around_units(source, waypoint)
		print("POC_DIAG %s kind=%s fixed_blocker=%s local_points=%d retries=%d" % [label, source.kind, original.navigation.has_fixed_unit_blocker(source, waypoint), local.size(), source.route_failures])
		var game := fixture()
		game.world_map.cells = original.world_map.cells.duplicate()
		for obstacle in original.buildings: building(game, obstacle.position, obstacle.size())
		var unit := game.spawn_unit(source.position)
		unit.stats = source.stats.duplicate(true)
		unit.destination = source.destination
		game.navigation.refresh()
		var path := game.navigation.path_between(unit.position, source.destination, unit)
		if not oracle_path(game, unit, path) or not arrive(unit, source.destination, 6, 3000): alone_succeed = false
		game.free()
	check(alone_succeed, label + "_isolated_recovery_control", "stalled=%d" % stalled)

func _test_group_queue() -> void:
	var game := fixture()
	for x in 30: block(game, x, 10)
	game.navigation.refresh()
	var units: Array[RtsUnit] = []
	for i in 6:
		var unit := game.spawn_unit(Vector2(200 + (i % 2) * 35, 350 + (i / 2) * 35))
		unit.stats["speed"] = 180.0
		units.append(unit)
	var group := group_for(game, units, Vector2(1000, 475), "line")
	for i in units.size(): units[i].issue_command("move", Vector2(200 + (i % 2) * 35, 250 + (i / 2) * 35), null, true)
	tick_group(group, 3000)
	var finished := units.filter(func(u: RtsUnit) -> bool: return u.order == "idle" and u.command_queue.is_empty() and u.position.x < 300).size()
	check(finished == 6, "wall_group_followup_queue_finishes", "%d/6 %s" % [finished, units.map(func(u: RtsUnit) -> Variant: return [u.position, u.order, u.command_queue.size()])])
	game.free()

func _test_gate_transitions() -> void:
	for radius in [10.0, 18.0]:
		var game := fixture()
		for y in 20:
			if y != 10: block(game, 12, y)
		var gate := building(game, Vector2(625, 525), Vector2(40, 40))
		gate.kind = "palisade_gate"
		gate.build_remaining = 10
		var unit := game.spawn_unit(Vector2(225, 525))
		unit.stats["radius"] = radius
		var goal := Vector2(1025, 525)
		for state in ["construction", "completed", "captured", "recaptured", "deleted"]:
			if state == "completed": gate.build_remaining = 0
			if state == "captured": gate.owner_id = 1
			if state == "recaptured": gate.owner_id = 0
			if state == "deleted":
				game.buildings.erase(gate)
				gate.free()
			game.navigation.invalidate_obstacles()
			var path := game.navigation.path_between(unit.position, goal, unit)
			var open: bool = state in ["completed", "recaptured", "deleted"]
			check(oracle_path(game, unit, path) if open else path.is_empty(), "gate_r%d_%s" % [radius, state])
		game.free()

func _test_seeded_routes() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026092902
	for sample in 100:
		var game := fixture()
		# Keep a certified clear border route even when the middle is dense.
		for i in 18:
			block(game, rng.randi_range(7, 23), rng.randi_range(4, 15))
		for i in 12:
			resource(game, Vector2(rng.randf_range(400, 1100), rng.randf_range(260, 740)), rng.randf_range(8, 30))
		for i in 8:
			building(game, Vector2(rng.randf_range(450, 1050), rng.randf_range(280, 720)), Vector2(55, 55))
		var unit := game.spawn_unit(Vector2(175, rng.randf_range(150, 850)))
		unit.stats["radius"] = [10.0, 12.0, 18.0, 24.0, 28.0][sample % 5]
		unit.stats["speed"] = 180.0
		var goal := Vector2(1325, rng.randf_range(150, 850))
		var witness := PackedVector2Array([unit.position, Vector2(175, 100), Vector2(1325, 100), goal])
		check(oracle_path(game, unit, witness), "fuzz_%d_witness" % sample)
		var path := game.navigation.path_between(unit.position, goal, unit)
		check(oracle_path(game, unit, path) and not path.is_empty() and path[path.size() - 1].distance_to(goal) < 1, "fuzz_%d_safe_route" % sample, str(path))
		var motion_safe := true
		var arrived := false
		for step in 900:
			var previous := unit.position
			arrived = unit._move_toward(goal, 0.05, 6)
			if not oracle_segment(game, previous, unit.position, unit): motion_safe = false
			if arrived: break
		check(motion_safe and arrived, "fuzz_%d_safe_arrival" % sample, "safe=%s arrived=%s position=%s" % [motion_safe, arrived, unit.position])
		game.free()

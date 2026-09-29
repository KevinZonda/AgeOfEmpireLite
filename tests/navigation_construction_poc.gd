extends SceneTree

# Exercise real placement, construction, and queued orders on deterministic terrain.
var game: Node2D
var failures := 0
var checks := 0
var max_step := 0.0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String, detail := "") -> void:
	checks += 1
	if not ok: failures += 1
	print("POC_%s %s %s" % ["PASS" if ok else "FAIL", label, detail])

func reset() -> void:
	for collection in [game.units, game.buildings, game.resources, game.trade_posts, game.relics]:
		for entity in collection:
			if is_instance_valid(entity): entity.free()
		collection.clear()
	game.selected.clear()
	game.world_map.cells.fill(RtsWorldMap.Terrain.GRASS)
	game.navigation.refresh()
	game.players[0]["age"] = 3
	for resource in ["food", "wood", "gold", "stone"]: game.players[0][resource] = 10000
	max_step = 0.0

func worker(point: Vector2) -> RtsUnit:
	var unit: RtsUnit = game.spawn_unit(0, "villager", point)
	unit.set_process(false)
	unit.engagement = "passive"
	return unit

func tick(units: Array[RtsUnit], steps: int) -> void:
	for step in steps:
		for unit in units:
			var previous := unit.position
			unit._process(0.05)
			max_step = maxf(max_step, previous.distance_to(unit.position))

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game("English", 4242)
	game.ai_controllers.clear()
	game.set_process(false)
	for kind in ["house", "farm", "palisade_wall"]:
		for vertical in ([false, true] if kind == "palisade_wall" else [false]):
			for edge in [false, true]: test_covered_builder(kind, vertical, edge)
	test_queued_buildings()
	test_bystander()
	test_finished_by_other()
	test_escape_obstacles()
	test_wall_joint()
	test_sealed_then_opened()
	test_escape_terrain_and_resources()
	test_farm_queue()
	for voice in game.feedback_audio.voices:
		voice.stop()
		voice.stream = null
	game.free()
	print("NAVIGATION_CONSTRUCTION_POC checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)

func test_covered_builder(kind: String, vertical: bool, edge: bool) -> void:
	reset()
	var site: Vector2 = game.snap_build_point(kind, Vector2(700, 500), vertical)
	var dimensions: Vector2 = GameData.BUILDINGS[kind]["size"]
	if vertical: dimensions = Vector2(dimensions.y, dimensions.x)
	var unit := worker(site + (Vector2(dimensions.x * 0.5 + 4, 0) if edge else Vector2.ZERO))
	var units: Array[RtsUnit] = [unit]
	var label := "%s_vertical%s_edge%s" % [kind, vertical, edge]
	check(game.place_building(0, kind, site, units, false, vertical), label + "_placement")
	var building: RtsBuilding = game.buildings.back()
	var goal := site + Vector2(230, 150)
	unit.issue_command("move", goal, null, true)
	tick(units, 700)
	check(building.is_complete(), label + "_completes", "remaining=%.2f" % building.build_remaining)
	check(unit.order == "idle" and unit.position.distance_to(goal) < 12.0, label + "_leaves_after_build", "position=%s order=%s" % [unit.position, unit.order])
	check(game.navigation.can_occupy(unit.position, unit.radius(), unit, false), label + "_outside_footprint")
	check(max_step <= unit.effective_speed() * 0.05 + 0.01, label + "_no_teleport", "max_step=%.3f" % max_step)

func test_queued_buildings() -> void:
	reset()
	var first: Vector2 = game.snap_build_point("house", Vector2(700, 500))
	var units: Array[RtsUnit] = [worker(first), worker(first + Vector2(0, 26)), worker(first + Vector2(26, 0))]
	check(game.place_building(0, "house", first, units), "multi_builder_first_placement")
	check(game.place_building(0, "house", first + Vector2(100, 0), units, true), "multi_builder_queued_placement")
	for i in units.size(): units[i].issue_command("move", first + Vector2(200, 130 + i * 30), null, true)
	tick(units, 1000)
	check(game.buildings.all(func(b: RtsBuilding) -> bool: return b.is_complete()), "queued_buildings_complete")
	check(units.all(func(u: RtsUnit) -> bool: return u.order == "idle" and u.position.distance_to(u.destination) < 12.0), "all_builders_leave", str(units.map(func(u: RtsUnit) -> Variant: return [u.position, u.order])))

func test_bystander() -> void:
	reset()
	var site: Vector2 = game.snap_build_point("house", Vector2(700, 500))
	var idle := worker(site)
	var builder := worker(site + Vector2(-100, 0))
	var units: Array[RtsUnit] = [builder]
	game.place_building(0, "house", site, units)
	units.append(idle)
	tick(units, 400)
	check(game.navigation.can_occupy(idle.position, idle.radius(), idle, false), "idle_bystander_clears_foundation", str(idle.position))
	idle.issue_command("move", site + Vector2(200, 0))
	tick(units, 300)
	check(idle.order == "idle" and idle.position.distance_to(idle.destination) < 12.0, "bystander_can_move_after_completion")

func test_finished_by_other() -> void:
	reset()
	var building: RtsBuilding = game.spawn_building(0, "house", Vector2(700, 500), true)
	var unit := worker(Vector2(400, 500))
	unit.issue_command("build", Vector2.INF, building)
	unit.issue_command("move", Vector2(300, 500), null, true)
	# Another worker finishes while this builder is on the other side of a barrier.
	for y in game.world_map.grid_size.y:
		game.world_map.cells[y * game.world_map.grid_size.x + 11] = RtsWorldMap.Terrain.MOUNTAIN
	game.navigation.invalidate_obstacles()
	building.advance_construction(building.build_remaining)
	tick([unit], 120)
	check(unit.order == "idle" and unit.position.distance_to(Vector2(300, 500)) < 12.0, "completed_target_releases_remote_builder", "position=%s order=%s" % [unit.position, unit.order])

func test_escape_obstacles() -> void:
	reset()
	var site: Vector2 = game.snap_build_point("house", Vector2(700, 500))
	var unit := worker(site)
	# The closest northern exit is blocked, but the other sides remain open.
	var obstacle: RtsBuilding = game.spawn_building(0, "house", site + Vector2(0, -75))
	var builders: Array[RtsUnit] = [unit]
	game.place_building(0, "house", site, builders)
	var crossed := false
	for step in 400:
		tick([unit], 1)
		if Rect2(obstacle.position - obstacle.size() * 0.5, obstacle.size()).grow(unit.radius()).has_point(unit.position): crossed = true
	check(not crossed, "escape_does_not_cross_neighbor")
	check(game.buildings.back().is_complete() and game.navigation.can_occupy(unit.position, unit.radius(), unit, false), "escape_uses_open_side", str(unit.position))

func test_wall_joint() -> void:
	reset()
	var site: Vector2 = game.snap_build_point("palisade_wall", Vector2(700, 500))
	var unit := worker(site + Vector2(37.5, 0))
	var builders: Array[RtsUnit] = [unit]
	game.place_building(0, "palisade_wall", site, builders)
	game.place_building(0, "palisade_wall", site + Vector2(75, 0), builders, true)
	unit.issue_command("move", site + Vector2(0, 150), null, true)
	tick(builders, 800)
	check(game.buildings.all(func(b: RtsBuilding) -> bool: return b.is_complete()), "overlapping_wall_joint_completes")
	check(unit.order == "idle" and unit.position.distance_to(unit.destination) < 12.0, "wall_joint_builder_leaves")

func test_sealed_then_opened() -> void:
	reset()
	var site: Vector2 = game.snap_build_point("farm", Vector2(700, 500))
	var unit := worker(site)
	var blockers: Array[RtsBuilding] = []
	for offset in [Vector2(-75, 0), Vector2(75, 0), Vector2(0, -75), Vector2(0, 75)]:
		blockers.append(game.spawn_building(0, "farm", site + offset))
	# Larger collision radius closes the gaps between the surrounding farms.
	unit.stats["radius"] = 16.0
	var builders: Array[RtsUnit] = [unit]
	game.place_building(0, "farm", site, builders)
	var foundation: RtsBuilding = game.buildings.back()
	tick(builders, 80)
	check(unit.position == site and not foundation.is_complete(), "sealed_builder_waits_without_crossing_buildings")
	game.buildings.erase(blockers[0])
	blockers[0].free()
	game.navigation.invalidate_obstacles()
	tick(builders, 400)
	check(foundation.is_complete() and game.navigation.can_occupy(unit.position, unit.radius(), unit, false), "sealed_builder_resumes_when_exit_opens")

func test_escape_terrain_and_resources() -> void:
	reset()
	var site: Vector2 = game.snap_build_point("house", Vector2(700, 500))
	var unit := worker(site)
	var resource: RtsResource = game.spawn_resource("wood", site + Vector2(0, -60), 1000, "tree")
	var blocked_cell: Vector2i = game.world_map.cell_at(site + Vector2(-75, 0))
	game.world_map.cells[blocked_cell.y * game.world_map.grid_size.x + blocked_cell.x] = RtsWorldMap.Terrain.WATER
	# Spawn directly to simulate an already existing overlap beside terrain.
	var building: RtsBuilding = game.spawn_building(0, "house", site)
	var units: Array[RtsUnit] = [unit]
	var safe := true
	for step in 160:
		tick(units, 1)
		var cell_rect := Rect2(Vector2(blocked_cell) * RtsWorldMap.CELL_SIZE, Vector2.ONE * RtsWorldMap.CELL_SIZE)
		var closest := unit.position.clamp(cell_rect.position, cell_rect.end)
		if unit.position.distance_to(closest) < unit.radius() or unit.position.distance_to(resource.position) < unit.radius() + resource.radius: safe = false
	check(safe and game.navigation.can_occupy(unit.position, unit.radius(), unit, false), "escape_respects_water_and_resource", str(unit.position))
	check(not game.navigation.can_occupy(building.position, unit.radius(), unit, false), "ordinary_collision_still_blocks_building_interior")

func test_farm_queue() -> void:
	reset()
	var site: Vector2 = game.snap_build_point("farm", Vector2(700, 500))
	var unit := worker(site)
	var builders: Array[RtsUnit] = [unit]
	game.place_building(0, "farm", site, builders)
	var farm: RtsBuilding = game.buildings.back()
	unit.issue_command("gather", Vector2.INF, farm, true)
	var food_before: int = game.players[0]["food"]
	tick(builders, 600)
	check(farm.is_complete() and unit.order == "gather" and game.players[0]["food"] > food_before, "builder_continues_queued_farm_work")

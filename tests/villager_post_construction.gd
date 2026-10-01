extends SceneTree

const Fixture = preload("res://tests/helpers/navigation_fixture.gd")

class FogStub extends RefCounted:
	var active := false
	var hidden: Array[RtsResource] = []
	func can_show_resource(_owner: int, resource: RtsResource) -> bool: return not hidden.has(resource)

class WorkFixture extends Fixture:
	const HEALTH_BAR_CHANGE_DURATION := 3.0
	var civilizations := ["English", "French"]
	var fog := FogStub.new()
	var completions := 0
	func building_completed(_building: RtsBuilding) -> void: completions += 1
	func farm_worker(farm: RtsBuilding, except: RtsUnit = null) -> RtsUnit:
		for unit in units:
			if unit != except and unit.order == "gather" and unit.target == farm: return unit
		return null
	func find_nearest_free_farm(owner: int, point: Vector2, reach: float, except: RtsUnit) -> RtsBuilding:
		var result: RtsBuilding
		var best := reach * reach
		for farm in buildings:
			if farm.is_queued_for_deletion() or farm.kind != "farm" or farm.owner_id != owner or not farm.is_complete() or farm_worker(farm, except) != null: continue
			var distance := point.distance_squared_to(farm.position)
			if distance >= best or navigation.path_to_range(point, farm.position, farm.size().x * 0.5 + except.radius() + 2.0, except).is_empty(): continue
			best = distance
			result = farm
		return result

var checks := 0
var failures := 0
var game: WorkFixture
var worker: RtsUnit
var completed: RtsBuilding

func _initialize() -> void: call_deferred("_run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL ", label)

func building(kind: String, point: Vector2, unfinished := true, owner := 0) -> RtsBuilding:
	var site := RtsBuilding.new()
	site.game = game
	site.kind = kind
	site.owner_id = owner
	site.stats = GameData.BUILDINGS[kind].duplicate(true)
	site.max_hp = 100.0
	site.build_total = 1.0
	site.build_remaining = 0.1 if unfinished else 0.0
	site.position = point
	game.buildings.append(site)
	game.add_child(site)
	site.hide()
	site.set_process(false)
	return site

func resource(kind: String, offset: Vector2, appearance := "") -> RtsResource:
	var node := RtsResource.new()
	node.game = game
	node.position = worker.position + offset
	node.setup(kind, 100, appearance)
	game.resources.append(node)
	game.add_child(node)
	node.hide()
	node.set_process(false)
	return node

func start_case(kind: String) -> void:
	if game != null:
		game.navigation.background_jobs.shutdown()
		game.free()
	game = WorkFixture.new()
	root.add_child(game)
	game.players = [{"age": 4, "researched": [], "landmarks": []}, {"age": 4, "researched": [], "landmarks": []}]
	game.initialize(Vector2(1800, 1800))
	worker = game.spawn_unit(Vector2(600, 600))
	worker.kind = "villager"
	worker.refresh_stats(false)
	var half_width: float = GameData.BUILDINGS[kind]["size"].x * 0.5
	completed = building(kind, worker.position - Vector2(half_width + worker.radius() + 3.0, 0))
	check(game.navigation.can_occupy(worker.position, worker.radius(), worker, false), "completion_fixture_starts_outside_" + kind)
	worker.issue_command("build", Vector2.INF, completed)

func finish() -> void:
	game.navigation.refresh()
	worker.orders.tick(worker, 0.2)
	check(completed.is_complete() and game.completions == 1, "tick_completes_" + completed.kind)

func _run() -> void:
	start_case("farm")
	var free_farm := building("farm", worker.position - Vector2(0, 110), false)
	finish()
	check(worker.order == "gather" and worker.target == completed, "farmer_uses_own_completed_farm_before_closer_free_farm")
	var helper := game.spawn_unit(worker.position + Vector2(0, 25))
	helper.kind = "villager"
	helper.refresh_stats(false)
	helper.order = "build"
	helper.target = completed
	helper.orders.tick(helper, 0.1)
	check(helper.order == "gather" and helper.target == free_farm, "other_builder_uses_free_nearby_farm")
	var third := game.spawn_unit(worker.position + Vector2(0, 55))
	third.kind = "villager"
	third.refresh_stats(false)
	third.order = "build"
	third.target = completed
	var next_site := building("house", worker.position + Vector2(100, 90))
	game.navigation.refresh()
	third.orders.tick(third, 0.1)
	check(third.order == "build" and third.target == next_site, "full_farms_send_surplus_builder_to_construction")

	for pair in [["mill", "food", "sheep"], ["mill", "food", "berries"], ["lumber_camp", "wood", ""], ["mining_camp", "gold", ""], ["mining_camp", "stone", ""]]:
		start_case(pair[0])
		var target := resource(pair[1], Vector2(80, 0), pair[2])
		next_site = building("house", worker.position + Vector2(0, 120))
		finish()
		check(worker.order == "gather" and worker.target == target, "matching_resource_precedes_construction_" + pair[0] + "_" + pair[1] + "_" + pair[2])

	start_case("mining_camp")
	resource("gold", Vector2(160, 0))
	var stone := resource("stone", Vector2(70, 0))
	finish()
	check(worker.order == "gather" and worker.target == stone, "mine_uses_nearest_of_gold_and_stone")

	for kind in ["house", "mill", "lumber_camp", "mining_camp"]:
		start_case(kind)
		resource("food", Vector2(40, 0), "fish")
		resource("wood", Vector2(250, 0))
		var depleted := resource("gold", Vector2(50, 0))
		depleted.amount = 0
		next_site = building("house", worker.position + Vector2(0, 120))
		building("house", worker.position + Vector2(0, -80), true, 1)
		building("house", worker.position + Vector2(80, 0), false)
		finish()
		check(worker.order == "build" and worker.target == next_site, "no_usable_resource_resumes_owned_unfinished_building_" + kind)
		# Finishing the follow-up runs the same rule, then stops when no work remains.
		worker.position = next_site.position + Vector2(next_site.size().x * 0.5 + worker.radius() + 3.0, 0)
		worker.orders.tick(worker, 0.2)
		check(worker.order == "idle", "construction_chain_ends_idle_" + kind)

	start_case("lumber_camp")
	game.fog.active = true
	var hidden := resource("wood", Vector2(55, 0))
	game.fog.hidden.append(hidden)
	var visible := resource("wood", Vector2(100, 0))
	finish()
	check(worker.order == "gather" and worker.target == visible, "hidden_resources_are_skipped")

	start_case("lumber_camp")
	var unreachable := resource("wood", Vector2(90, 0))
	# Water ring leaves the resource visible but unreachable on foot.
	for y in range(10, 15):
		for x in range(13, 16):
			game.world_map.cells[y * game.world_map.grid_size.x + x] = RtsWorldMap.Terrain.WATER
	var reachable := resource("wood", Vector2(0, -100))
	game.navigation.refresh()
	check(game.navigation.path_to_range(worker.position, unreachable.position, unreachable.radius + worker.radius() + 2.0, worker).is_empty(), "blocked_resource_fixture_is_unreachable")
	finish()
	check(worker.order == "gather" and worker.target == reachable, "unreachable_resource_is_skipped")

	start_case("house")
	var blocked_site := building("house", worker.position + Vector2(130, 0))
	for y in range(10, 15):
		for x in range(13, 17):
			game.world_map.cells[y * game.world_map.grid_size.x + x] = RtsWorldMap.Terrain.WATER
	next_site = building("house", worker.position + Vector2(0, 150))
	game.navigation.refresh()
	check(game.navigation.path_to_range(worker.position, blocked_site.position, blocked_site.size().x * 0.6 + worker.radius(), worker).is_empty(), "blocked_building_fixture_is_unreachable")
	finish()
	check(worker.order == "build" and worker.target == next_site, "unreachable_construction_is_skipped")

	for kind in ["farm", "mill", "house"]:
		start_case(kind)
		resource("food", Vector2(80, 0), "sheep")
		next_site = building("house", worker.position + Vector2(0, 120))
		var destination := Vector2(900, 600)
		worker.issue_command("move", destination, null, true)
		finish()
		check(worker.order == "move" and worker.destination == destination, "explicit_queue_precedes_automatic_work_" + kind)

	for command in ["build", "gather"]:
		start_case("farm")
		next_site = building("house", worker.position + Vector2(0, 120))
		var food := resource("food", Vector2(80, 0), "sheep")
		var queued_target: Node2D = next_site if command == "build" else food
		worker.issue_command(command, Vector2.INF, queued_target, true)
		finish()
		check(worker.order == command and worker.target == queued_target, "explicit_" + command + "_precedes_automatic_farming")

	start_case("house")
	building("house", worker.position + Vector2(0, 220))
	finish()
	check(worker.order == "idle", "distant_construction_does_not_pull_worker_away")
	worker.order_stop()
	worker.orders.tick(worker, 0.1)
	check(worker.order == "idle", "idle_tick_does_not_assign_work_after_stop")

	start_case("mill")
	resource("food", Vector2(70, 0), "sheep")
	completed.queue_free()
	worker.orders.tick(worker, 0.2)
	check(worker.order == "idle", "destroyed_site_does_not_trigger_completion_followup")

	game.navigation.background_jobs.shutdown()
	game.free()
	print("VILLAGER_POST_CONSTRUCTION checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)

extends SceneTree

const Fixture = preload("res://tests/helpers/navigation_fixture.gd")

class FogStub extends RefCounted:
	var active := false
	func update_unit_display(_unit: RtsUnit) -> void: pass

class OrderFixture extends Fixture:
	const HEALTH_BAR_CHANGE_DURATION := 1.5
	var civilizations := ["English", "French"]
	var fog := FogStub.new()
	var visible_enemy: RtsUnit
	var destroyed := 0
	func nearest_enemy(_unit: RtsUnit, _reach: float) -> Node2D: return visible_enemy
	func entity_destroyed(unit: RtsUnit) -> void:
		destroyed += 1
		unit.queue_free()
	func farm_worker(farm: RtsBuilding, except: RtsUnit = null) -> RtsUnit:
		for unit in units:
			if unit != except and unit.order == "gather" and unit.target == farm: return unit
		return null
	func find_nearest_free_farm(owner: int, point: Vector2, reach: float, except: RtsUnit) -> RtsBuilding:
		for building in buildings:
			if building.kind == "farm" and building.owner_id == owner and building.position.distance_to(point) <= reach and farm_worker(building, except) == null: return building
		return null

var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("_run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("POC_FAIL ", label)

func make_unit(game: OrderFixture, kind: String, point: Vector2, owner := 0) -> RtsUnit:
	var unit := game.spawn_unit(point)
	unit.kind = kind
	unit.owner_id = owner
	unit.refresh_stats(false)
	unit.order_stop()
	return unit

func make_building(game: OrderFixture, kind: String, point: Vector2) -> RtsBuilding:
	var building := RtsBuilding.new()
	building.game = game
	building.kind = kind
	building.stats = GameData.BUILDINGS[kind].duplicate(true)
	building.position = point
	game.buildings.append(building)
	game.add_child(building)
	building.hide()
	building.set_process(false)
	return building

func request_route(unit: RtsUnit) -> int:
	unit.route_goal = unit.destination
	unit.route = PackedVector2Array([unit.position, unit.destination])
	unit.game.navigation.background_jobs.request(unit, unit.destination, Vector2.INF)
	return unit.route_generation

func _run() -> void:
	var game := OrderFixture.new()
	root.add_child(game)
	game.players = [{"age": 4, "researched": []}, {"age": 4, "researched": []}]
	game.initialize(Vector2(1800, 1800))
	var soldier := make_unit(game, "spearman", Vector2(300, 300))
	var friend := make_unit(game, "spearman", Vector2(1000, 300))
	var enemy := make_unit(game, "spearman", Vector2(1000, 500), 1)
	var goal := Vector2(700, 300)
	soldier.issue_command("move", goal)
	soldier.issue_command("move", Vector2(900, 300), null, true)
	var generation := request_route(soldier)
	var invalid_target := RefCounted.new()
	check(not soldier._start_command({"type": "attack", "target": invalid_target}), "non_scene_attack_target_rejected")
	check(not soldier._start_command({"type": "build", "target": invalid_target}), "non_scene_work_target_rejected")
	soldier.conversion_timer = 2.0
	for command in ["unknown", "build", "gather", "repair", "board_transport", "supervise", "relic", "garrison"]:
		soldier.issue_command(command, Vector2.INF, friend)
		check(soldier.order == "move" and soldier.destination == goal and soldier.command_queue.size() == 1, "invalid_replacement_preserves_orders_" + command)
		check(soldier.route_generation == generation and game.navigation.background_jobs.has_request(soldier) and soldier.route.size() == 2 and soldier.conversion_timer == 2.0, "invalid_replacement_preserves_inflight_state_" + command)
	soldier.issue_command("move", Vector2.INF)
	soldier.issue_command("attack", Vector2.INF, friend)
	soldier.issue_command("unknown", Vector2.INF, null, true)
	check(soldier.order == "move" and soldier.command_queue.size() == 1 and soldier.route_generation == generation, "invalid_point_friendly_attack_and_append_preserve_state")
	var arbitrary := Node2D.new()
	check(not soldier._start_command({"type": "group_move", "group": arbitrary}), "invalid_group_type_rejected")
	arbitrary.free()
	# Admission copies the caller's command; queue activation validates current state.
	soldier.issue_command("attack", Vector2.INF, enemy, true)
	soldier.issue_command("move", Vector2(1100, 300), null, true)
	soldier._advance_command()
	enemy.queue_free()
	soldier._advance_command()
	check(soldier.order == "move" and soldier.destination == Vector2(1100, 300) and soldier.command_queue.is_empty(), "queued_deleted_target_skipped_without_discarding_following_move")
	check(not game.navigation.background_jobs.has_request(soldier) and soldier.route.is_empty(), "accepted_transition_cancels_previous_generation")
	var worker := make_unit(game, "villager", Vector2(500, 900))
	arbitrary = Node2D.new()
	worker.issue_command("move", Vector2(700, 900))
	check(not worker._start_command({"type": "repair", "target": arbitrary}) and worker.order == "move", "invalid_repair_target_type_rejected")
	arbitrary.free()
	var house := make_building(game, "house", Vector2(1100, 900))
	house.build_remaining = 10.0
	worker.issue_command("move", Vector2(700, 900))
	worker.issue_command("build", Vector2.INF, house, true)
	worker.issue_command("move", Vector2(900, 900), null, true)
	house.build_remaining = 0.0
	worker._advance_command()
	check(worker.order == "move" and worker.destination == Vector2(900, 900), "queued_completed_build_skipped")
	var farm := make_building(game, "farm", Vector2(550, 1000))
	var farmer := make_unit(game, "villager", Vector2(600, 1000))
	farmer.order_gather(farm)
	worker.issue_command("move", Vector2(700, 900), null, true)
	generation = request_route(worker)
	worker.issue_command("gather", Vector2.INF, farm)
	worker.order_gather(farm)
	check(worker.order == "move" and worker.command_queue.size() == 1 and worker.route_generation == generation and game.navigation.background_jobs.has_request(worker), "farm_contention_rejection_is_transactional_for_all_entry_points")
	var free_farm := make_building(game, "farm", Vector2(520, 1000))
	worker.issue_command("gather", Vector2.INF, farm, true)
	farmer.order_stop()
	worker._advance_command()
	worker._advance_command()
	check(worker.order == "gather" and worker.target == farm, "queued_farm_assignment_resolved_at_activation")
	free_farm.queue_free()
	# Actual tick-driven engagements preserve explicit queue through target loss,
	# and central resume cancels combat movement and clears all transient state.
	enemy = make_unit(game, "spearman", Vector2(850, 500), 1)
	game.visible_enemy = enemy
	for interrupted in ["attack_move", "patrol", "hold"]:
		soldier.position = Vector2(300, 300)
		soldier.issue_command(interrupted, goal)
		soldier.issue_command("move", Vector2(900, 300), null, true)
		soldier.awareness_timer = 0.0
		soldier._process(0.01)
		check(soldier.order == "attack" and soldier.resume_order == interrupted and soldier.command_queue.size() == 1, "automatic_engagement_suspends_" + interrupted)
		generation = request_route(soldier)
		enemy.hp = 0.0
		soldier._process(0.01)
		check(soldier.order == interrupted and soldier.command_queue.size() == 1 and soldier.target == null and not soldier.auto_engaged and soldier.resume_order == "" and soldier.resume_destination == Vector2.INF, "target_loss_restores_" + interrupted)
		check(soldier.route_generation > generation and not game.navigation.background_jobs.has_request(soldier), "resume_cancels_combat_route_" + interrupted)
		enemy.hp = enemy.max_hp
	game.visible_enemy = null
	for interrupted in ["attack_move", "patrol", "hold"]:
		soldier.position = Vector2(300, 300)
		soldier.issue_command(interrupted, goal)
		soldier.orders.engage(soldier, enemy)
		soldier.engagement = "defensive"
		soldier.position += Vector2(190, 0)
		generation = request_route(soldier)
		soldier._process(0.01)
		check(soldier.order == interrupted and soldier.target == null and not soldier.auto_engaged and soldier.resume_order == "" and soldier.route_generation > generation and not game.navigation.background_jobs.has_request(soldier), "defensive_leash_uses_complete_resume_lifecycle_" + interrupted)
	soldier.engagement = "aggressive"
	soldier.order_attack_move(goal)
	soldier.orders.engage(soldier, enemy)
	soldier.issue_command("move", Vector2(900, 300), null, true)
	request_route(soldier)
	soldier.order_stop()
	enemy.hp = 0.0
	soldier._process(0.01)
	check(soldier.order == "idle" and soldier.command_queue.is_empty() and soldier.resume_order == "" and not game.navigation.background_jobs.has_request(soldier), "stop_prevents_later_combat_resumption")
	# A stationing boundary preserves saved work and removes every live command.
	var center := make_building(game, "town_center", Vector2(600, 900))
	worker.issue_command("garrison", Vector2.INF, center)
	worker.issue_command("move", Vector2(900, 900), null, true)
	generation = request_route(worker)
	check(center.garrison_unit(worker), "building_garrison_succeeds")
	check(worker.garrisoned_in == center and worker.order == "idle" and worker.command_queue.is_empty() and worker.target == null and worker.route_generation > generation and not game.navigation.background_jobs.has_request(worker), "building_garrison_cancels_full_lifecycle")
	check(worker.saved_work.get("target") == farm, "garrison_preserves_saved_worker_job")
	worker.issue_command("move", Vector2(900, 900))
	check(worker.order == "idle" and worker.command_queue.is_empty(), "stationed_units_reject_new_world_orders")
	center.ungarrison_all(true)
	check(worker.order == "gather" and worker.target == farm and worker.saved_work.is_empty(), "ungarrison_resumes_valid_saved_job")
	worker.order_stop()
	var ram := make_unit(game, "battering_ram", worker.position + Vector2(40, 0))
	worker.issue_command("move", Vector2(900, 900))
	worker.issue_command("move", Vector2(1000, 900), null, true)
	request_route(worker)
	check(ram.garrison_unit(worker) and worker.command_queue.is_empty() and worker.target == null and not game.navigation.background_jobs.has_request(worker), "transport_garrison_uses_same_cancellation_boundary")
	var wall := make_building(game, "stone_wall", Vector2(1500, 900))
	wall.owner_id = 1
	var tower := make_unit(game, "siege_tower", Vector2(1435, 900))
	tower.position = wall.position - Vector2(wall.size().x * 0.5 + tower.radius() + 3.0, 0)
	check(game.navigation.can_occupy(tower.position, tower.radius(), tower, false), "siege_docking_fixture_starts_outside_wall")
	tower.issue_command("assault_wall", Vector2.INF, wall)
	generation = request_route(tower)
	tower._process(0.01)
	check(tower.order == "siege_tower_docked" and tower.target == wall and tower.route_generation > generation and not game.navigation.background_jobs.has_request(tower), "siege_docking_cancels_active_movement")
	# Lethal damage must cancel immediately, before deferred destruction executes.
	var doomed := make_unit(game, "spearman", Vector2(1300, 1300))
	doomed.issue_command("move", Vector2(1400, 1300))
	doomed.issue_command("move", Vector2(1500, 1300), null, true)
	request_route(doomed)
	doomed.take_damage(doomed.hp + 1.0)
	check(game.destroyed == 1 and doomed.command_queue.is_empty() and not game.navigation.background_jobs.has_request(doomed), "lethal_damage_cancels_before_deferred_free")
	game.navigation.background_jobs.shutdown()
	game.free()
	print("UNIT_ORDERS_REGRESSION checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)

extends SceneTree

const Fixture = preload("res://tests/helpers/navigation_fixture.gd")

class FogStub extends RefCounted:
	var updates := 0
	func update_visibility() -> void: updates += 1

class ComponentFixture extends Fixture:
	const HEALTH_BAR_CHANGE_DURATION := 1.5
	var civilizations := ["English", "French"]
	var fog := FogStub.new()
	var camp_space := true
	func can_afford(owner: int, cost: Dictionary) -> bool:
		for resource in cost:
			if players[owner].get(resource, 0) < cost[resource]: return false
		return true
	func spend(owner: int, cost: Dictionary) -> bool:
		if not can_afford(owner, cost): return false
		for resource in cost: players[owner][resource] -= cost[resource]
		return true
	func can_place(_kind: String, _point: Vector2) -> bool: return camp_space
	func spawn_building(owner: int, kind: String, point: Vector2) -> RtsBuilding:
		var building := RtsBuilding.new()
		building.owner_id = owner
		building.kind = kind
		building.position = point
		buildings.append(building)
		add_child(building)
		building.hide()
		building.set_process(false)
		return building

var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("_run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("POC_FAIL ", label)

func make_unit(game: ComponentFixture, kind: String, point: Vector2, owner := 0) -> RtsUnit:
	var unit := game.spawn_unit(point)
	unit.kind = kind
	unit.owner_id = owner
	unit.refresh_stats(false)
	unit.order_stop()
	return unit

func _run() -> void:
	var game := ComponentFixture.new()
	root.add_child(game)
	game.players = [{"age": 4, "researched": [], "wood": 500}, {"age": 4, "researched": [], "wood": 500}]
	game.initialize(Vector2(1600, 1600))
	var soldier := make_unit(game, "spearman", Vector2(300, 300))
	var other := make_unit(game, "spearman", Vector2(1000, 1000), 1)
	# Public properties remain writable, with one component-owned state object.
	soldier.route = PackedVector2Array([Vector2(300, 300)])
	soldier.route.append(Vector2(350, 300))
	check(soldier.movement.route.size() == 2 and other.movement.route.is_empty(), "route_proxy_mutations_are_owned_and_isolated")
	soldier.route_goal = Vector2(600, 300)
	game.navigation.background_jobs.request(soldier, soldier.route_goal, Vector2.INF)
	var generation := soldier.route_generation
	check(not soldier._start_command({"type": "build", "target": other}), "invalid_command_rejected")
	check(soldier.route_generation == generation and game.navigation.background_jobs.has_request(soldier), "rejected_command_preserves_current_movement")
	soldier.resume_order = "patrol"
	soldier.resume_destination = Vector2(800, 300)
	soldier.charging = true
	soldier.conversion_timer = 2.0
	soldier.order_stop()
	check(soldier.route.is_empty() and soldier.route_generation > generation and not game.navigation.background_jobs.has_request(soldier), "stop_cancels_async_recovery_and_route")
	check(soldier.resume_order == "" and soldier.resume_destination == Vector2.INF and not soldier.charging and soldier.conversion_timer == 0.0, "stop_clears_transient_command_state")
	# Queued hold/patrol commands must not discard commands following them.
	soldier.issue_command("move", Vector2(500, 300))
	soldier.issue_command("patrol", Vector2(600, 300), null, true)
	soldier.issue_command("move", Vector2(700, 300), null, true)
	soldier._advance_command()
	check(soldier.order == "patrol" and soldier.command_queue.size() == 1, "queued_patrol_preserves_following_command")
	soldier.order_stop()
	soldier.issue_command("move", Vector2(500, 300))
	soldier.issue_command("hold", Vector2.INF, null, true)
	soldier.issue_command("move", Vector2(700, 300), null, true)
	soldier._advance_command()
	check(soldier.order == "hold" and soldier.command_queue.size() == 1, "queued_hold_preserves_following_command")
	# Automatic attacks retain their caller's explicit resume information.
	soldier.order_attack_move(Vector2(700, 300))
	soldier.order_attack(other, true)
	soldier.resume_order = "attack_move"
	soldier.resume_destination = Vector2(700, 300)
	other.hp = 0.0
	soldier._process(0.01)
	check(soldier.order == "attack_move" and soldier.destination == Vector2(700, 300), "automatic_engagement_resumes_attack_move")
	var before := soldier.position
	soldier._move_toward(soldier.destination, 0.1, 6.0)
	check(soldier.position.distance_to(before) > 0.0 and soldier.position.distance_to(before) <= soldier.effective_speed() * 0.1 + 0.001, "movement_component_preserves_speed_limit")
	var ram := make_unit(game, "battering_ram", soldier.position + Vector2(40, 0))
	soldier.route_goal = Vector2(700, 300)
	game.navigation.background_jobs.request(soldier, soldier.route_goal, Vector2.INF)
	check(ram.garrison_unit(soldier) and not game.navigation.background_jobs.has_request(soldier) and soldier.route.is_empty(), "transport_garrison_cancels_inflight_movement")
	soldier.garrisoned_in = null
	ram.passengers.clear()
	soldier.position -= Vector2(40, 0)
	game.navigation.invalidate_spatial_index()
	var worker := make_unit(game, "villager", Vector2(600, 600))
	var resource := RtsResource.new()
	resource.kind = "wood"
	resource.position = Vector2(640, 600)
	worker.order_gather(resource)
	worker.remember_work()
	worker.order_stop()
	worker.resume_work()
	check(worker.order == "gather" and worker.target == resource and worker.saved_work.is_empty(), "worker_saved_job_resumes_after_stop")
	var bow := make_unit(game, "longbow", Vector2(800, 300))
	check(bow.ability_availability("palings").available and bow.activate_ability("palings"), "ability_readiness_matches_execution")
	check(not bow.ability_availability("palings").available and not bow.activate_ability("palings"), "ability_cooldown_rejects_execution")
	bow.order_move(Vector2(900, 300))
	check(bow.paling_timer == 0.0 and bow.paling_cooldown == 30.0, "moving_cancels_palings_without_resetting_cooldown")
	check(bow.activate_ability("volley"), "volley_starts")
	bow._tick_status(5.0)
	check(bow.volley_timer == 0.0 and bow.volley_cooldown == 40.0, "owned_ability_timers_tick_once")
	bow._tick_status(40.0)
	check(bow.ability_availability("volley").available and bow.activate_ability("volley"), "ability_becomes_ready_when_cooldown_expires")
	var shield := make_unit(game, "arbaletrier", Vector2(900, 800), 1)
	var base_range := shield.attack_range()
	var base_armor: float = shield.stats.armor.ranged
	shield.activate_ability("pavise")
	for refresh in 3: shield.refresh_stats()
	check(shield.attack_range() == base_range + 30.0 and shield.stats.armor.ranged == base_armor + 5.0, "pavise_refresh_applies_buff_once")
	check(shield.stats.range == shield.attack_range(), "legacy_stats_project_final_profile")
	shield.stats.range = 9999.0
	check(shield.attack_range() == base_range + 30.0, "simulation_ignores_stale_flat_combat_stats")
	shield.order_move(Vector2(1100, 800))
	shield._move_toward(shield.destination, 0.1, 6.0)
	check(shield.shield_timer == 0.0 and shield.attack_range() == base_range and shield.stats.armor.ranged == base_armor, "movement_removes_pavise_from_profiles_and_projection")
	shield.activate_ability("pavise")
	var squad: Array[RtsUnit] = [shield]
	var group := RtsMovementGroup.new(game, squad, Vector2(1200, 800))
	shield.issue_command("group_move", Vector2(1200, 800), null, false, group)
	shield._move_with_group(0.1)
	check(shield.shield_timer == 0.0 and shield.attack_range() == base_range, "formation_movement_also_interrupts_pavise")
	var ship := make_unit(game, "warship", Vector2(1300, 1000))
	var base_speed := ship.effective_speed()
	check(ship.ability_availability("helmsman").available and ship.activate_ability("helmsman") and is_equal_approx(ship.effective_speed(), base_speed * 1.4), "helmsman_speed_buff_applies_once")
	ship._tick_status(3.0)
	check(ship.helm_timer == 7.0 and ship.helm_cooldown == 27.0, "helmsman_timer_and_cooldown_tick_once")
	ship.order_attack(shield)
	check(ship.helm_timer == 0.0 and ship.helm_cooldown == 27.0 and ship.effective_speed() == base_speed, "attacking_interrupts_helmsman_without_resetting_cooldown")
	var monk := make_unit(game, "monk", Vector2(1200, 300))
	check(not monk.ability_availability("convert").available and not monk.activate_ability("convert"), "conversion_requires_relic")
	var relic := RtsRelic.new()
	monk.carried_relic = relic
	check(monk.ability_availability("convert").available and monk.activate_ability("convert"), "conversion_with_relic_starts")
	monk.issue_command("move", Vector2(1300, 300))
	check(monk.conversion_timer == 0.0 and monk.conversion_cooldown == 120.0, "new_command_interrupts_conversion_only")
	var convert_target := make_unit(game, "spearman", Vector2(1250, 300), 1)
	monk.conversion_cooldown = 0.0
	monk.activate_ability("convert")
	monk._tick_status(3.0)
	check(convert_target.owner_id == 0 and monk.conversion_timer == 0.0 and monk.conversion_cooldown == 117.0, "conversion_channel_completes_once")
	var cannon := make_unit(game, "cannon", Vector2(1200, 900), 1)
	check(not cannon.ability_availability("artillery_shot").available and not cannon.activate_ability("artillery_shot"), "artillery_requires_producer_landmark")
	cannon.producer_landmark_id = "fr_college_of_artillery"
	check(cannon.ability_availability("artillery_shot").available and cannon.activate_ability("artillery_shot") and cannon.artillery_shot_ready, "producer_landmark_unlocks_artillery")
	var scout := make_unit(game, "scout", Vector2(200, 1200))
	game.camp_space = false
	check(not scout.ability_availability("camp").available and not scout.activate_ability("camp"), "camp_placement_failure_matches_availability")
	game.camp_space = true
	game.players[0].wood = 0
	check(not scout.ability_availability("camp").available and not scout.activate_ability("camp"), "camp_affordability_matches_availability")
	game.players[0].wood = 500
	check(scout.ability_availability("camp").available and scout.activate_ability("camp") and game.players[0].wood == 475, "camp_spends_once")
	for camp in 4: game.spawn_building(0, "scout_camp", Vector2(100, 100))
	check(not scout.ability_availability("camp").available and not scout.activate_ability("camp"), "camp_limit_matches_availability")
	var once := RtsStatResolver.unit("English", "spearman", 4, ["forged_weapons"])
	var twice := RtsStatResolver.unit("English", "spearman", 4, ["forged_weapons", "forged_weapons"])
	check(once.profiles == twice.profiles, "research_effects_resolve_once")
	for kind in GameData.UNITS:
		var stats := RtsStatResolver.unit("French", kind, 4)
		check(stats.damage == RtsStatResolver.primary_damage(stats) and stats.range == RtsStatResolver.primary_range(stats) and stats.cooldown == RtsStatResolver.primary_cooldown(stats), "all_units_project_primary_" + kind)
	resource.free()
	relic.free()
	game.navigation.background_jobs.shutdown()
	game.free()
	print("UNIT_COMPONENTS_REGRESSION checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)

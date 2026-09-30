extends SceneTree

const ContextOrder = preload("res://scripts/player/context_order.gd")
const Snapshot = preload("res://scripts/ai/ai_snapshot.gd")
const EconomyPlan = preload("res://scripts/ai/economy_plan.gd")

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> bool:
	if condition: return true
	push_error(message)
	quit(1)
	return false

func _run() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	if not _check(game.navigation.route_budget_enabled == (OS.get_environment("RTS_ROUTE_BUDGET") == "1"), "live navigation must enable ordinary route budgeting only through explicit opt-in"): return
	await process_frame
	game.start_game("Chinese", 12345)
	game.paused = true
	var paused_unit: RtsUnit = game.units[0]
	var route_budget_was_enabled: bool = game.navigation.route_budget_enabled
	var recovery_was_enabled: bool = game.navigation.background_recovery_enabled
	game.navigation.route_budget_enabled = true
	game.navigation.background_recovery_enabled = true
	game.navigation.request_route(paused_unit, paused_unit.position + Vector2(100, 0), 6.0, false)
	game.navigation.background_jobs.request(paused_unit, paused_unit.position + Vector2(100, 0), Vector2.INF)
	game._process(0.25)
	if not _check(game.navigation.route_jobs.pending.size() == 1 and game.navigation.route_jobs.completed.is_empty() and game.navigation.background_jobs.pending.size() == 1 and game.navigation.background_jobs.active.is_empty(), "paused live game must not dispatch ordinary routes or recovery snapshots"): return
	game.navigation.route_budget_enabled = route_budget_was_enabled
	game.navigation.background_recovery_enabled = recovery_was_enabled
	for resource in GameData.RESOURCE_NAMES: game.players[0][resource] = 10000
	var state = game.session.player(0)
	if not _check(is_same(state.bank, game.players[0]), "compatibility bank must be the player state's actual bank"): return
	var old_food: int = game.players[0]["food"]
	state.spend({"food": 11})
	if not _check(game.players[0]["food"] == old_food - 11, "state spending must update the compatibility view"): return
	game.players[0]["food"] += 19
	if not _check(state.bank["food"] == old_food + 8, "compatibility writes must not leave a second bank stale"): return
	var center: RtsBuilding = game._player_center(0)
	game.spawn_building(0, "house", center.position + Vector2(-150, 0))
	var official_count := 0
	for unit in game.units:
		if unit.owner_id == 0 and unit.kind == "imperial_official": official_count += 1
	for index in 4 - official_count:
		if not _check(game.train_unit(center, "imperial_official"), "official should queue before its limit"): return
	var locked := RtsActionAvailability.production(game, center, "train", "imperial_official")
	if not _check(not locked["available"] and "4" in locked["reason"] and not game.train_unit(center, "imperial_official"), "description and transaction must agree about queued officials"): return
	game.cancel_production_job(center)
	if not _check(RtsActionAvailability.production(game, center, "train", "imperial_official")["available"], "cancel must release the limit for validation"): return
	var villager: RtsUnit = game.units.filter(func(unit: RtsUnit) -> bool: return unit.owner_id == 0 and unit.kind == "villager")[0]
	var worker_context := {"entity": center, "resource": null, "post": null, "relic": null, "ground_point": center.position}
	center.hp -= 5
	game.selected.assign([villager])
	if not _check(ContextOrder.for_unit(game, villager, worker_context)["type"] == "repair" and ContextOrder.cursor_for(game, worker_context) == "construct", "cursor and right-click must use the same repair priority"): return
	var snap := Snapshot.new(game, 0)
	if not _check(snap.unit_count("imperial_official") == 3, "AI counts must include current officials and queues"): return
	snap.add_unit("imperial_official")
	if not _check(snap.unit_count("imperial_official") == 4, "same-think training must reserve a slot in the snapshot"): return
	var plan := EconomyPlan.new(3, "balanced", 0, false)
	if not _check(plan.wants_siege and not plan.allows_research(), "strategic siege reservation must gate research"): return
	plan.update_age_saving(3, false, 400.0, 150.0, 3)
	if not _check(not plan.allows_production("stable", 400.0) and plan.allows_production("siege_workshop", 400.0), "age saving must preserve producer-specific policy"): return
	var old_units: Array = game.units.duplicate()
	game.start_game("English", 4242)
	if not _check(game.navigation.route_jobs.pending.is_empty() and game.navigation.route_jobs.current.is_empty() and game.navigation.route_jobs.completed.is_empty() and game.navigation.background_jobs.pending.is_empty() and game.navigation.background_jobs.current.is_empty() and game.navigation.background_jobs.completed.is_empty() and game.navigation.background_jobs.active.is_empty(), "restart must clear both navigation services before replacing the live registry"): return
	if not _check(game.session.entities.units.size() == 12 and is_same(game.units, game.session.entities.units), "restart must replace the live world through its registry"): return
	for unit in old_units:
		if not _check(not game.units.has(unit) and unit.is_queued_for_deletion(), "restart must retire every previous unit"): return
	var temporary_resource: RtsResource = game.spawn_resource("wood", Vector2(400, 400), 10)
	var resource_count: int = game.resources.size()
	temporary_resource.free()
	if not _check(game.resources.size() == resource_count - 1, "direct resource removal must unregister its live reference"): return
	var removed: RtsUnit = game.spawn_unit(0, "spearman", Vector2(700, 700))
	removed.issue_command("move", Vector2(800, 700))
	game.navigation.request_route(removed, removed.destination, 6.0, false)
	game.navigation.background_jobs.request(removed, removed.destination, Vector2.INF)
	game.entity_destroyed(removed)
	if not _check(not game.navigation.route_jobs.has_request(removed) and not game.navigation.background_jobs.has_request(removed), "registry destruction must cancel orders before deferred free"): return
	var enemy_unit: RtsUnit = game.units.filter(func(unit: RtsUnit) -> bool: return unit.owner_id == 1)[0]
	enemy_unit.issue_command("move", Vector2(1000, 1000))
	game.navigation.request_route(enemy_unit, enemy_unit.destination, 6.0, false)
	game.navigation.background_jobs.request(enemy_unit, enemy_unit.destination, Vector2.INF)
	var enemy_center: RtsBuilding = game._player_center(1)
	game.entity_destroyed(enemy_center)
	if not _check(not game.navigation.route_jobs.has_request(enemy_unit) and not game.navigation.background_jobs.has_request(enemy_unit), "defeat must cancel every eliminated unit before deferred free"): return
	if not _check(game.defeated_players.has(1) and game.units.all(func(unit: RtsUnit) -> bool: return unit.owner_id != 1) and game.buildings.all(func(building: RtsBuilding) -> bool: return building.owner_id != 1), "defeat must remove the whole owner's live world"): return
	game.free()
	print("SESSION_RULES_REGRESSION_OK")
	quit()

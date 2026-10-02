extends RefCounted

const HUNT_WINDUP := 0.4
const HUNT_ACTION_LENGTH := 0.65
const TRADE_POST_DISTANCE := 46.0

static func trade_home_distance(home_size: Vector2, trader_radius: float) -> float:
	return home_size.x * 0.5 + trader_radius + 4.0

# Economic and worker behavior. The unit retains order state and exposes the
# existing methods; these helpers operate on that state without owning it.
static func gathering_amount(unit) -> int:
	if unit.order != "gather" or not is_instance_valid(unit.target): return 0
	if unit.target is RtsBuilding and unit.target.kind == "farm": return farm_yield(unit)
	var resource_kind: String = "food" if unit.target is RtsBuilding else unit.target.kind
	var amount := 12 if unit.kind == "fishing_boat" else GameData.gathered_amount(unit.game.civilizations[unit.owner_id], resource_kind, unit.target is RtsBuilding)
	amount = maxi(1, roundi(amount * RtsLandmarkCatalog.gather_multiplier(unit.game.civilizations[unit.owner_id], unit.game.players[unit.owner_id].get("landmarks", []), resource_kind, unit.target is RtsBuilding) * RtsCivilizationRules.economic_gather_multiplier(unit.game, unit.owner_id, resource_kind) * RtsCivilizationRules.economic_site_multiplier(unit.game, unit.owner_id, resource_kind, unit.target)))
	if unit.kind == "villager" and unit.target is RtsResource and unit.target.appearance == "deer":
		for building in unit.game.buildings:
			if is_instance_valid(building) and building.owner_id == unit.owner_id and building.kind == "scout_camp" and building.position.distance_to(unit.position) <= 180.0:
				amount = maxi(1, roundi(amount * 1.1))
				break
	return amount

static func farm_work_speed(unit) -> float:
	return RtsLandmarkCatalog.gather_multiplier(unit.game.civilizations[unit.owner_id], unit.game.players[unit.owner_id].get("landmarks", []), "food", true) * RtsCivilizationRules.economic_gather_multiplier(unit.game, unit.owner_id, "food") * RtsCivilizationRules.economic_site_multiplier(unit.game, unit.owner_id, "food", unit.target)

static func farm_yield(unit) -> int:
	return GameData.gathered_amount(unit.game.civilizations[unit.owner_id], "food", true) * 6

static func remember_work(unit) -> void:
	if unit.order in ["gather", "build", "trade", "supervise"]:
		unit.saved_work = {"type": unit.order, "target": unit.trade_post if unit.order == "trade" else unit.target}
	else:
		unit.saved_work.clear()

static func resume_work(unit) -> void:
	if unit.saved_work.is_empty(): return
	var previous: Dictionary = unit.saved_work.duplicate()
	unit.saved_work.clear()
	if is_instance_valid(previous.get("target")) and not previous["target"].is_queued_for_deletion():
		unit.issue_command(previous["type"], Vector2.INF, previous["target"])

static func continue_gather(unit) -> void:
	# A completed resource must not postpone an explicit queued command.
	if not unit.command_queue.is_empty():
		unit._advance_command()
		return
	var next_resource: RtsResource
	if unit.gather_kind != "":
		next_resource = unit.game.find_nearest_resource(unit.gather_location, unit.gather_kind, unit.AUTO_GATHER_RADIUS, unit.owner_id, unit.kind == "fishing_boat", unit)
	if next_resource != null:
		unit.order_gather(next_resource)
	else:
		unit._advance_command()

static func finish_construction(unit: RtsUnit, completed: RtsBuilding) -> void:
	# Player commands take priority over every automatic follow-up.
	unit._advance_command()
	if unit.order != "idle" or not unit.command_queue.is_empty(): return
	if completed.kind == "farm":
		if unit.game.farm_worker(completed, unit) == null and not unit.game.navigation.path_to_range(unit.position, completed.position, completed.size().x * 0.5 + unit.radius() + 2.0, unit).is_empty():
			if unit._try_order_gather(completed): return
		var farm: RtsBuilding = unit.game.find_nearest_free_farm(unit.owner_id, unit.position, unit.AUTO_GATHER_RADIUS, unit)
		if is_instance_valid(farm) and unit._try_order_gather(farm): return
	var resource_kinds: Array[String] = []
	match completed.kind:
		"mill": resource_kinds.assign(["food"])
		"lumber_camp": resource_kinds.assign(["wood"])
		"mining_camp": resource_kinds.assign(["gold", "stone"])
	if not resource_kinds.is_empty():
		var resource := _nearby_construction_resource(unit, resource_kinds)
		if resource != null and unit._try_order_gather(resource): return
	var site := _nearby_construction_site(unit)
	if site != null: unit.issue_command("build", Vector2.INF, site)

static func _nearby_construction_resource(unit: RtsUnit, kinds: Array[String]) -> RtsResource:
	var result: RtsResource
	var best := unit.AUTO_GATHER_RADIUS * unit.AUTO_GATHER_RADIUS
	for resource in unit.game.resources:
		if not is_instance_valid(resource) or resource.is_queued_for_deletion() or resource.amount <= 0 or not kinds.has(resource.kind) or resource.appearance == "fish": continue
		if unit.game.fog.active and not unit.game.fog.can_show_resource(unit.owner_id, resource): continue
		var distance := unit.position.distance_squared_to(resource.position)
		if distance > best: continue
		if unit.game.navigation.path_to_range(unit.position, resource.position, resource.radius + unit.radius() + 2.0, unit).is_empty(): continue
		best = distance
		result = resource
	return result

static func _nearby_construction_site(unit: RtsUnit) -> RtsBuilding:
	var result: RtsBuilding
	var best := unit.AUTO_GATHER_RADIUS * unit.AUTO_GATHER_RADIUS
	for site in unit.game.buildings:
		if not is_instance_valid(site) or site.is_queued_for_deletion() or site.owner_id != unit.owner_id or site.is_complete(): continue
		var distance := unit.position.distance_squared_to(site.position)
		if distance > best: continue
		if unit.game.navigation.path_to_range(unit.position, site.position, site.size().x * 0.6 + unit.radius(), unit).is_empty(): continue
		best = distance
		result = site
	return result

static func process_repair_order(unit, delta: float) -> void:
	if unit.target.hp >= unit.target.max_hp:
		unit._advance_command()
		return
	var stop_distance: float = float(unit.target.size().x) * 0.5 + unit.radius() if unit.target is RtsBuilding else unit.target.radius() + unit.radius()
	if not unit._move_toward(unit.target.position, delta, stop_distance): return
	if unit.work_timer > 0.0: return
	var resource_kind := "wood"
	if unit.target is RtsBuilding:
		var cost: Dictionary = unit.target.definition().get("cost", {})
		if cost.has("stone") and not cost.has("wood"): resource_kind = "stone"
	if not unit.game.spend(unit.owner_id, {resource_kind: 1}):
		unit._advance_command()
		return
	unit.target.hp = minf(unit.target.max_hp, unit.target.hp + (5.0 if unit.target is RtsUnit else 8.0))
	unit.target.queue_redraw()
	unit.work_timer = 0.4
	unit._start_visual_action("build", 0.4)

static func process_trade_order(unit, delta: float) -> void:
	if not is_instance_valid(unit.trade_post) or unit.trade_post.is_queued_for_deletion() or not is_instance_valid(unit.trade_home) or unit.trade_home.is_queued_for_deletion() or unit.trade_home.owner_id != unit.owner_id:
		unit._advance_command()
		return
	var goal: Vector2 = unit.trade_home.position if unit.trade_returning else unit.trade_post.position
	# The market center is inside its collision footprint. Use a reachable
	# interaction distance for the return leg, including the trader's radius.
	var stop_distance: float = trade_home_distance(unit.trade_home.size(), unit.radius()) if unit.trade_returning else TRADE_POST_DISTANCE
	if unit._move_toward(goal, delta, stop_distance):
		var cargo := maxi(6, roundi(unit.trade_home.position.distance_to(unit.trade_post.position) / 36.0))
		cargo = roundi(cargo * RtsLandmarkCatalog.trade_multiplier(unit.game.civilizations[unit.owner_id], unit.game.players[unit.owner_id].get("landmarks", [])))
		if unit.game.civilizations[unit.owner_id] == "French": cargo = roundi(cargo * 1.15)
		unit.game.credit_resource(unit.owner_id, unit.trade_resource_kind if unit.game.civilizations[unit.owner_id] == "French" else "gold", cargo)
		unit.trade_returning = not unit.trade_returning
		unit._reset_route()

static func process_gather_order(unit, delta: float) -> void:
	if unit.target is RtsResource and unit.target.appearance == "boar" and unit.target.wildlife_hp > 0.0:
		unit.UnitCombat.process_attack_order(unit, delta)
		return
	if unit.target is RtsResource and unit.target.appearance == "deer" and unit.target.wildlife_hp > 0.0:
		process_hunt_order(unit, delta)
		return
	unit.hunt_windup = -1.0
	# Let the release finish before switching back to the gathering tool.
	if unit.visual_action == "hunt" and unit.visual_action_timer > 0.0: return
	var gathering_distance: float = unit.target.radius + unit.radius() + 2.0 if unit.target is RtsResource else unit.target.size().x * 0.5 + unit.radius() + 2.0
	if not unit._move_toward(unit.target.position, delta, gathering_distance): return
	if unit.target is RtsBuilding and unit.target.kind == "farm":
		if not unit.target.is_complete(): return
		if unit.game.civilizations[unit.owner_id] == "English" and unit.game.players[unit.owner_id]["researched"].has("enclosures"):
			unit.enclosure_timer -= delta
			while unit.enclosure_timer <= 0.0:
				unit.game.credit_resource(unit.owner_id, "gold", 2)
				unit.enclosure_timer += 5.0
		else:
			unit.enclosure_timer = 5.0
		var food: int = unit.target.work_farm(delta, farm_work_speed(unit), farm_yield(unit))
		if food > 0:
			unit.game.credit_resource(unit.owner_id, "food", food)
			unit.farm_gain_display_amount += food
		if unit.work_timer <= 0.0:
			if unit.farm_gain_display_amount > 0 and unit.owner_id == 0 and unit.game.has_method("show_resource_gain"):
				unit.game.show_resource_gain(unit.position, "food", unit.farm_gain_display_amount)
			unit.farm_gain_display_amount = 0
			unit._start_visual_action("gather", 0.42)
			unit.work_timer = 1.1
		return
	unit.enclosure_timer = 5.0
	if unit.work_timer <= 0.0:
		var resource_kind: String = "food" if unit.target is RtsBuilding else unit.target.kind
		var amount := gathering_amount(unit)
		if unit.target is RtsResource: amount = unit.target.harvest(amount)
		if amount > 0:
			unit.game.credit_resource(unit.owner_id, resource_kind, amount)
			if unit.owner_id == 0 and unit.game.has_method("show_resource_gain"): unit.game.show_resource_gain(unit.position, resource_kind, amount)
		unit._start_visual_action("gather", 0.42)
		unit.work_timer = 1.1
		if unit.target is RtsResource and unit.target.amount <= 0: continue_gather(unit)

static func cancel_hunt(unit) -> void:
	unit.hunt_windup = -1.0
	if unit.visual_action == "hunt":
		unit.visual_action = ""
		unit.visual_action_timer = 0.0
		unit.visual_action_released = false
		unit.visual_release_elapsed = -1.0
		unit.visual_charge_impact = false
		unit.queue_redraw()

static func process_hunt_order(unit, delta: float, profile: Dictionary = {}) -> void:
	if profile.is_empty(): profile = unit.stats.get("profiles", {}).get("hunt_ranged", {})
	var reach: float = float(profile.get("range", 86.4)) + unit.target.radius
	if not unit._move_toward(unit.target.position, delta, reach):
		cancel_hunt(unit)
		return
	unit._face_direction(unit.target.position - unit.position)
	if unit.hunt_windup < 0.0:
		if unit.attack_timer > 0.0: return
		unit.hunt_windup = HUNT_WINDUP
		unit._start_visual_action("hunt", HUNT_ACTION_LENGTH)
		return
	unit.hunt_windup = maxf(0.0, unit.hunt_windup - delta)
	if unit.hunt_windup > 0.0: return
	var arrow := RtsProjectile.new()
	arrow.setup(unit.game, unit.owner_id, unit.global_position, unit.target, float(profile.get("damage", 3.0)), float(unit.stats.get("projectile_speed", 350.0)), 0.0, unit.stats, profile)
	arrow.source_unit = unit
	arrow.attack_profile["hunting"] = true
	unit.game.add_child(arrow)
	unit._mark_visual_impact()
	unit.hunt_windup = -1.0
	unit.attack_timer = float(profile.get("cooldown", 1.584))
	unit.queue_redraw()

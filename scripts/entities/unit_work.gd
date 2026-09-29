extends RefCounted

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
	if not is_instance_valid(unit.trade_post) or not is_instance_valid(unit.trade_home) or unit.trade_home.is_queued_for_deletion():
		unit._advance_command()
		return
	var goal: Vector2 = unit.trade_home.position if unit.trade_returning else unit.trade_post.position
	if unit._move_toward(goal, delta, 46.0):
		var cargo := maxi(6, roundi(unit.trade_home.position.distance_to(unit.trade_post.position) / 36.0))
		cargo = roundi(cargo * RtsLandmarkCatalog.trade_multiplier(unit.game.civilizations[unit.owner_id], unit.game.players[unit.owner_id].get("landmarks", [])))
		if unit.game.civilizations[unit.owner_id] == "French": cargo = roundi(cargo * 1.15)
		unit.game.credit_resource(unit.owner_id, unit.trade_resource_kind if unit.game.civilizations[unit.owner_id] == "French" else "gold", cargo)
		unit.trade_returning = not unit.trade_returning
		unit._reset_route()

static func process_gather_order(unit, delta: float) -> void:
	var gathering_distance: float = unit.target.radius + unit.radius() + 2.0 if unit.target is RtsResource else unit.target.size().x * 0.5 + unit.radius() + 2.0
	if not unit._move_toward(unit.target.position, delta, gathering_distance): return
	if unit.target is RtsResource and unit.target.appearance == "deer" and unit.target.wildlife_hp > 0.0:
		if unit.attack_timer > 0.0: return
		var hunt_profile: Dictionary = unit.stats.get("profiles", {}).get("hunt_melee", {})
		unit.target.take_damage(float(hunt_profile.get("damage", unit.stats.get("damage", 1.0))))
		unit.attack_timer = float(hunt_profile.get("cooldown", unit.stats.get("cooldown", 1.0)))
		unit._start_visual_action("attack", 0.30)
		return
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

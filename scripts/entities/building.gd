class_name RtsBuilding
extends Node2D

const BuildingVisual = preload("res://scripts/entities/visuals/building_visual.gd")
const BuildingVisualState = preload("res://scripts/entities/visuals/building_visual_state.gd")
const IconCache = preload("res://scripts/ui/icon_cache.gd")

const FARM_SOW_WORK := 2.2
const FARM_HARVEST_WORK := 4.4
var building_visual = BuildingVisual.new()
var building_visual_state = BuildingVisualState.new()

var game: Node2D
var owner_id := 0
var kind: String
var landmark_id := ""
var stats: Dictionary = {}
var hp := 1.0:
	set(value):
		if health_bar_initialized and not is_equal_approx(hp, value):
			health_bar_timer = game.HEALTH_BAR_CHANGE_DURATION
			if is_inside_tree(): queue_redraw()
		hp = value
var max_hp := 1.0
var health_bar_timer := 0.0
var health_bar_initialized := false
var build_remaining := 0.0
var build_total := 0.0
var farm_stage := "sowing"
var farm_stage_progress := 0.0
var farm_food_buffer := 0.0
# A building works on one job at a time. All queue queries derive from these jobs.
var production_queue: Array[Dictionary] = []
var production_remaining := 0.0
var rally_point := Vector2.ZERO
var rally_target: Node2D
var rally_resource_kind := ""
var garrisoned_units: Array[RtsUnit] = []
var defense_timer := 0.0
var wall_vertical := false
var relics: Array[RtsRelic] = []
var relic_income_timer := 4.0
var landmark_tick_timer := 4.0
var landmark_stockpile := {"food": 0, "wood": 0, "gold": 0, "stone": 0}
var landmark_ability_cooldown := 0.0
var tax_stockpile := 0
var tax_timer := 4.0
var damage_flash_timer := 0.0
var building_icon: Texture2D

func setup(game_ref: Node2D, player_id: int, building_kind: String, under_construction := false, chosen_landmark := "") -> void:
	game = game_ref
	owner_id = player_id
	kind = building_kind
	landmark_id = chosen_landmark
	var icon_kind := landmark_id if kind == "landmark" else "scout" if kind == "scout_camp" else kind
	building_icon = IconCache.texture_at("res://assets/ui/command_icons/%s.png" % icon_kind)
	var definition := definition()
	stats = definition.duplicate(true)
	stats["armor"] = definition.get("armor", {"melee": 0.0, "ranged": 0.0}).duplicate(true)
	refresh_stats(false)
	hp = max_hp if not under_construction else max_hp * 0.3
	build_total = definition["time"]
	build_remaining = build_total if under_construction else 0.0
	rally_point = position + Vector2(95 if game.spawn_point_for(owner_id).x < game.world_size.x * 0.5 else -95, 0)
	health_bar_initialized = true
	queue_redraw()

func definition() -> Dictionary:
	if kind != "landmark": return GameData.BUILDINGS[kind]
	var result: Dictionary = GameData.BUILDINGS[kind].duplicate(true)
	var choice := RtsLandmarkCatalog.landmark(landmark_id)
	if not choice.is_empty():
		result["label"] = choice["label"]
		result["hp"] = choice["hp"]
		result["size"] = choice["size"]
		result["time"] = choice["time"]
		result["pop"] = choice.get("population", 0)
		result["defense"] = choice.get("defense", {})
		result["garrison_capacity"] = choice.get("garrison_capacity", 0)
	return result

func producer_kind() -> String:
	return RtsLandmarkCatalog.producer(landmark_id) if kind == "landmark" else kind

func can_set_rally(player_id: int) -> bool:
	return owner_id == player_id and is_complete() and not RtsTechTree.all_train_units(game.civilizations[owner_id], producer_kind()).is_empty()

func garrison_capacity() -> int:
	return int(stats.get("garrison_capacity", 0))

func display_label() -> String:
	return definition()["label"]

func refresh_stats(preserve_damage := true) -> void:
	var missing_hp := maxf(0.0, max_hp - hp) if preserve_damage else 0.0
	stats = definition().duplicate(true)
	stats["armor"] = stats.get("armor", {"melee": 0.0, "ranged": 0.0}).duplicate(true)
	var bonus := RtsLandmarkCatalog.building_bonus(game.civilizations[owner_id], game.players[owner_id].get("landmarks", []), kind)
	for stat in bonus:
		if str(stat).begins_with("armor_"):
			var armor_kind: String = str(stat).trim_prefix("armor_")
			stats["armor"][armor_kind] = float(stats["armor"].get(armor_kind, 0.0)) + float(bonus[stat])
		else:
			stats[stat] = float(stats.get(stat, 0.0)) + float(bonus[stat])
	max_hp = float(stats["hp"])
	hp = maxf(1.0, max_hp - missing_hp)
	queue_redraw()

func size() -> Vector2:
	var dimensions: Vector2 = stats.get("size", GameData.BUILDINGS[kind]["size"])
	return Vector2(dimensions.y, dimensions.x) if wall_vertical and (kind.ends_with("_wall") or kind.ends_with("_gate")) else dimensions

func contains(world_point: Vector2) -> bool:
	return Rect2(position - size() * 0.5, size()).has_point(world_point)

func visual_snapshot():
	return BuildingVisualState.capture(self)

func _current_visual_state(include_terrain := true):
	return BuildingVisualState.capture(self, building_visual_state, include_terrain)

func icon_size() -> float:
	return _current_visual_state(false).icon_size()

func contains_icon_visual(world_point: Vector2, canvas: Transform2D) -> bool:
	return building_visual.contains_icon_visual(_current_visual_state(), world_point, canvas)

func isometric_height() -> float:
	return _current_visual_state(false).isometric_height()

func visual_feature_height() -> float:
	return _current_visual_state(false).visual_feature_height()

func _landmark_extra_height() -> float:
	return building_visual.landmark_extra_height(_current_visual_state(false))

func foundation_height() -> float:
	return _current_visual_state().foundation_height

func contains_isometric_visual(world_point: Vector2, canvas: Transform2D) -> bool:
	return building_visual.contains_isometric_visual(_current_visual_state(), world_point, canvas)

func contains_visual(world_point: Vector2, canvas: Transform2D) -> bool:
	var snapshot = _current_visual_state()
	return building_visual.contains_isometric_visual(snapshot, world_point, canvas) if snapshot.view_mode_25d else building_visual.contains_topdown_visual(snapshot, world_point)

func _landmark_geometry():
	building_visual.state = _current_visual_state(false)
	return building_visual._landmark_geometry()

func is_complete() -> bool:
	return build_remaining <= 0.0

func farm_stage_work() -> float:
	return FARM_SOW_WORK if farm_stage == "sowing" else FARM_HARVEST_WORK

func farm_crop_fraction() -> float:
	return clampf(farm_stage_progress / FARM_SOW_WORK, 0.0, 1.0) if farm_stage == "sowing" else clampf(1.0 - farm_stage_progress / FARM_HARVEST_WORK, 0.0, 1.0)

func work_farm(delta: float, speed: float, harvest_yield: int) -> int:
	if kind != "farm" or not is_complete() or delta <= 0.0 or speed <= 0.0: return 0
	var remaining_work := delta * speed
	while remaining_work > 0.000001:
		var work := minf(remaining_work, farm_stage_work() - farm_stage_progress)
		if farm_stage == "harvesting": farm_food_buffer += float(harvest_yield) * work / FARM_HARVEST_WORK
		farm_stage_progress += work
		remaining_work -= work
		if farm_stage_progress >= farm_stage_work() - 0.000001:
			farm_stage = "harvesting" if farm_stage == "sowing" else "sowing"
			farm_stage_progress = 0.0
	queue_redraw()
	var food := floori(farm_food_buffer + 0.00001)
	farm_food_buffer = maxf(0.0, farm_food_buffer - food)
	return food

func advance_construction(delta: float) -> void:
	if is_complete(): return
	build_remaining = maxf(0.0, build_remaining - delta)
	hp = max_hp * (1.0 - 0.7 * build_remaining / maxf(0.1, build_total))
	queue_redraw()
	if is_complete():
		game.building_completed(self)

func enqueue(unit_kind: String, paid_cost: Dictionary = {}) -> void:
	var cost: Dictionary = paid_cost if not paid_cost.is_empty() else GameData.unit_cost(unit_kind)
	production_queue.append({"type": "train", "kind": unit_kind, "time": _training_time(unit_kind), "cost": cost.duplicate(true)})
	if production_queue.size() == 1: _begin_next_job()
	queue_redraw()

func enqueue_research(tech_kind: String, duration: float, paid_cost: Dictionary) -> void:
	production_queue.append({"type": "research", "kind": tech_kind, "time": maxf(0.01, duration), "cost": paid_cost.duplicate(true)})
	if production_queue.size() == 1: _begin_next_job()
	queue_redraw()

func current_job() -> Dictionary:
	if production_queue.is_empty(): return {}
	var job := production_queue[0].duplicate(true)
	job["remaining"] = production_remaining
	return job

func queued_unit_count(unit_kind: String = "") -> int:
	var count := 0
	for job in production_queue:
		if job["type"] == "train" and (unit_kind.is_empty() or job["kind"] == unit_kind): count += 1
	return count

func queued_population_cost() -> int:
	var population := 0
	for job in production_queue:
		if job["type"] == "train": population += RtsBalanceData.population_cost(job["kind"])
	return population

func queued_research_ids() -> Array[String]:
	var result: Array[String] = []
	for job in production_queue:
		if job["type"] == "research": result.append(job["kind"])
	return result

func cancel_queue_entry(index: int = 0) -> Dictionary:
	if index < 0 or index >= production_queue.size(): return {}
	var job: Dictionary = production_queue[index]
	production_queue.remove_at(index)
	if index == 0: _begin_next_job()
	queue_redraw()
	return job.duplicate(true)

func _begin_next_job() -> void:
	production_remaining = 0.0
	if production_queue.is_empty(): return
	production_remaining = production_queue[0]["time"]

func _training_time(unit_kind: String) -> float:
	var producer := producer_kind()
	var academy := 0.75 if game.players[owner_id].get("researched", []).has("military_academy") and GameData.UNITS[unit_kind]["tags"].has("military") else 1.0
	return GameData.training_time(game.civilizations[owner_id], producer, unit_kind, game.players[owner_id]["age"]) * RtsLandmarkCatalog.training_multiplier(game.civilizations[owner_id], game.players[owner_id].get("landmarks", []), producer, unit_kind) * RtsLandmarkCatalog.dynasty_training_multiplier(game.civilizations[owner_id], game.players[owner_id].get("dynasty", ""), producer, unit_kind) * RtsLandmarkCatalog.training_rate(landmark_id) * academy

func set_rally(world_point: Vector2, target_ref: Node2D = null) -> void:
	rally_point = world_point
	rally_target = target_ref
	rally_resource_kind = target_ref.kind if target_ref is RtsResource else "food" if target_ref is RtsBuilding and target_ref.kind == "farm" else ""
	queue_redraw()

func garrison_unit(unit: RtsUnit) -> bool:
	if not is_complete() or unit.owner_id != owner_id or garrisoned_units.size() >= garrison_capacity(): return false
	if not (RtsSiegeRules.can_garrison(unit.stats, kind) or kind == "landmark" and garrison_capacity() > 0 and not unit.stats.get("tags", []).has("siege")): return false
	if garrisoned_units.has(unit): return true
	garrisoned_units.append(unit)
	unit.enter_garrison(self)
	game.navigation.invalidate_spatial_index()
	queue_redraw()
	return true

func ungarrison_all(resume_previous_work := false) -> void:
	for index in garrisoned_units.size():
		var unit: RtsUnit = garrisoned_units[index]
		if not is_instance_valid(unit): continue
		unit.garrisoned_in = null
		unit.position = game.navigation.nearest_walkable_point(position + Vector2((index % 3 - 1) * 24, size().y * 0.5 + 30 + (index / 3) * 22), unit.radius(), unit)
		game.navigation.invalidate_spatial_index()
		game.fog.update_unit_display(unit)
		unit.order_stop()
		if resume_previous_work: unit.resume_work()
	garrisoned_units.clear()
	game.navigation.invalidate_spatial_index()
	queue_redraw()

func _process_defense(delta: float) -> void:
	defense_timer = maxf(0.0, defense_timer - delta)
	if defense_timer > 0.0: return
	var attack: Dictionary = RtsSiegeRules.defense_stats(kind, garrisoned_units.size()) if kind != "landmark" else stats.get("defense", {}).duplicate(true)
	if attack.is_empty(): return
	if kind == "landmark":
		attack["damage"] = float(attack.get("damage", 0.0)) + garrisoned_units.size() * float(attack.get("garrison_bonus", 0.0))
		attack["attack_type"] = "ranged"
		attack["tags"] = ["building", "structure", "fortification"]
	var enemy: RtsUnit
	var best := INF
	var reach: float = float(attack.get("range", 0.0))
	for unit in game.navigation.nearby_units(position, reach):
		if not is_instance_valid(unit) or unit.is_queued_for_deletion() or not game.is_enemy(owner_id, unit.owner_id) or unit.garrisoned_in != null: continue
		if game.fog.active and not game.fog.can_detect_unit(owner_id, unit): continue
		var distance := position.distance_squared_to(unit.position)
		if distance < best and distance <= reach * reach:
			best = distance
			enemy = unit
	if enemy == null: return
	var damage := RtsCombatRules.damage(attack, enemy.stats)
	for _shot in maxi(1, int(attack.get("salvo", 1))):
		var projectile := RtsProjectile.new()
		var profile := {"damage": float(attack.get("damage", 0.0)), "damage_kind": "ranged", "hits": 1}
		projectile.setup(game, owner_id, global_position, enemy, damage, float(attack.get("projectile_speed", 400.0)), float(attack.get("splash_radius", 0.0)), attack, profile)
		game.add_child(projectile)
	defense_timer = float(attack.get("cooldown", 1.5))

func _process_landmark(delta: float) -> void:
	landmark_tick_timer -= delta
	if landmark_tick_timer > 0.0: return
	landmark_tick_timer += 4.0
	if landmark_id == "eng_kings_mill":
		for unit in game.units:
			if is_instance_valid(unit) and unit.owner_id == owner_id and unit.order != "attack" and unit.position.distance_to(position) <= 160.0:
				unit.hp = minf(unit.max_hp, unit.hp + 4.0)
				unit.queue_redraw()
	elif landmark_id == "fr_guild_hall":
		for resource in landmark_stockpile:
			landmark_stockpile[resource] = mini(400, int(landmark_stockpile[resource]) + 12)

func collect_stockpile() -> bool:
	if landmark_id != "fr_guild_hall" or not is_complete(): return false
	for resource in landmark_stockpile:
		if int(landmark_stockpile[resource]) > 0:
			game.credit_resource(owner_id, resource, landmark_stockpile[resource])
			landmark_stockpile[resource] = 0
	return true

func activate_landmark_ability() -> bool:
	if landmark_id != "zh_imperial_palace" or not is_complete() or landmark_ability_cooldown > 0.0: return false
	game.fog.reveal_enemy_villagers(owner_id, 10.0)
	landmark_ability_cooldown = 60.0
	return true

func _process(delta: float) -> void:
	if not game.started or game.paused or game.game_over: return
	if health_bar_timer > 0.0:
		health_bar_timer = maxf(0.0, health_bar_timer - delta)
		if health_bar_timer == 0.0: queue_redraw()
	if damage_flash_timer > 0.0:
		damage_flash_timer = maxf(0.0, damage_flash_timer - delta)
		queue_redraw()
	if game.civilizations[owner_id] == "Chinese" and is_complete() and kind in ["town_center", "market", "barracks", "archery_range", "stable", "siege_workshop", "blacksmith", "farm"]:
		tax_timer -= delta
		if tax_timer <= 0.0:
			var tax := 2
			for landmark in game.buildings:
				if is_instance_valid(landmark) and landmark.owner_id == owner_id and landmark.landmark_id == "zh_imperial_academy" and landmark.is_complete() and landmark.position.distance_to(position) <= 180.0:
					tax *= 2
					break
			tax_stockpile = mini(80, tax_stockpile + tax)
			tax_timer += 4.0
	landmark_ability_cooldown = maxf(0.0, landmark_ability_cooldown - delta)
	if kind == "landmark" and is_complete(): _process_landmark(delta)
	if kind == "monastery" and is_complete() and not relics.is_empty():
		relic_income_timer -= delta
		if relic_income_timer <= 0.0:
			game.credit_resource(owner_id, "gold", relics.size() * 12)
			relic_income_timer += 4.0
	if is_complete(): _process_defense(delta)
	if not is_complete() or production_queue.is_empty(): return
	var work_rate := 1.0
	for unit in game.units:
		if is_instance_valid(unit) and unit.owner_id == owner_id and unit.kind == "imperial_official" and unit.order == "supervise" and unit.target == self and unit.position.distance_to(position) <= 70.0:
			work_rate = 1.5
			break
	production_remaining = maxf(0.0, production_remaining - delta * work_rate)
	if production_remaining > 0.0: return
	game.session.changes.begin_transaction()
	var job: Dictionary = production_queue.pop_front()
	if job["type"] == "train":
		var trained: RtsUnit = game.spawn_unit(owner_id, job["kind"], game.find_spawn_position(self), rally_point, rally_target, rally_resource_kind)
		if owner_id == 0 and game.has_method("play_feedback"):
			game.play_feedback("complete")
			game.world_effects.append({"point": trained.position, "kind": "complete", "time": 0.9})
		if kind == "landmark" and (RtsLandmarkCatalog.produced_siege_hp(landmark_id) > 1.0 or RtsLandmarkCatalog.produced_siege_damage(landmark_id) > 1.0) and trained.stats.get("tags", []).has("siege"):
			trained.producer_landmark_id = landmark_id
			trained.refresh_stats()
		if landmark_id == "eng_wynguard_palace" and job["kind"] == "longbow" and game.population_used(owner_id) + 2 <= game.population_cap(owner_id):
			for offset in [Vector2(-20, 30), Vector2(20, 30)]:
				game.spawn_unit(owner_id, "spearman", game.find_spawn_position(self) + offset, rally_point, rally_target, rally_resource_kind)
	elif job["type"] == "research":
		game.complete_research(owner_id, job["kind"])
	_begin_next_job()
	game.session.changes.mark(owner_id, &"production")
	game.session.changes.end_transaction()
	queue_redraw()

func take_damage(damage: float) -> void:
	hp -= damage
	damage_flash_timer = 0.22
	if owner_id == 0 and game.has_method("play_feedback"): game.play_feedback("alert")
	queue_redraw()
	if hp <= 0.0:
		game.entity_destroyed(self)

func _draw() -> void:
	building_visual.draw(self, _current_visual_state())

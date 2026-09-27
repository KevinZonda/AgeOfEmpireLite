class_name RtsBuilding
extends Node2D

var game: Node2D
var owner_id := 0
var kind: String
var landmark_id := ""
var stats: Dictionary = {}
var hp := 1.0
var max_hp := 1.0
var build_remaining := 0.0
var build_total := 0.0
var training_queue: Array[String] = []
var training_remaining := 0.0
var research_queue: Array[String] = []
var research_remaining := 0.0
var age_remaining := 0.0
# A building works on one job at a time. The two typed queues above remain useful
# for population accounting and the existing selection UI.
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

func setup(game_ref: Node2D, player_id: int, building_kind: String, under_construction := false, chosen_landmark := "") -> void:
	game = game_ref
	owner_id = player_id
	kind = building_kind
	landmark_id = chosen_landmark
	var definition := definition()
	stats = definition.duplicate(true)
	stats["armor"] = definition.get("armor", {"melee": 0.0, "ranged": 0.0}).duplicate(true)
	refresh_stats(false)
	hp = max_hp if not under_construction else max_hp * 0.3
	build_total = definition["time"]
	build_remaining = build_total if under_construction else 0.0
	rally_point = position + Vector2(95 if game.spawn_point_for(owner_id).x < game.world_size.x * 0.5 else -95, 0)
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

func is_complete() -> bool:
	return build_remaining <= 0.0

func advance_construction(delta: float) -> void:
	if is_complete(): return
	build_remaining = maxf(0.0, build_remaining - delta)
	hp = max_hp * (1.0 - 0.7 * build_remaining / maxf(0.1, build_total))
	queue_redraw()
	if is_complete():
		game.building_completed(self)

func enqueue(unit_kind: String, paid_cost: Dictionary = {}) -> void:
	training_queue.append(unit_kind)
	var cost: Dictionary = paid_cost if not paid_cost.is_empty() else GameData.unit_cost(unit_kind)
	production_queue.append({"type": "train", "kind": unit_kind, "time": _training_time(unit_kind), "cost": cost.duplicate(true)})
	if production_queue.size() == 1: _begin_next_job()
	queue_redraw()

func enqueue_research(tech_kind: String, duration: float, paid_cost: Dictionary) -> void:
	research_queue.append(tech_kind)
	production_queue.append({"type": "research", "kind": tech_kind, "time": maxf(0.01, duration), "cost": paid_cost.duplicate(true)})
	if production_queue.size() == 1: _begin_next_job()
	queue_redraw()

func enqueue_age(target_age: int, duration: float, paid_cost: Dictionary) -> void:
	production_queue.append({"type": "age", "kind": "age_%d" % target_age, "target_age": target_age, "time": maxf(0.01, duration), "cost": paid_cost.duplicate(true)})
	if production_queue.size() == 1: _begin_next_job()
	queue_redraw()

func has_queued_age() -> bool:
	for job in production_queue:
		if job["type"] == "age": return true
	return false

func current_job() -> Dictionary:
	if production_queue.is_empty(): return {}
	var job := production_queue[0].duplicate(true)
	job["remaining"] = production_remaining
	return job

func has_queued_research(tech_kind: String) -> bool:
	return research_queue.has(tech_kind)

func cancel_queue_entry(index: int = 0) -> Dictionary:
	if index < 0 or index >= production_queue.size(): return {}
	var job: Dictionary = production_queue[index]
	production_queue.remove_at(index)
	if job["type"] == "train":
		training_queue.erase(job["kind"])
	elif job["type"] == "research":
		research_queue.erase(job["kind"])
	if index == 0: _begin_next_job()
	queue_redraw()
	return job.duplicate(true)

func drain_queue() -> Array[Dictionary]:
	var jobs: Array[Dictionary] = []
	while not production_queue.is_empty():
		jobs.append(cancel_queue_entry(0))
	return jobs

func _begin_next_job() -> void:
	production_remaining = 0.0
	training_remaining = 0.0
	research_remaining = 0.0
	age_remaining = 0.0
	if production_queue.is_empty(): return
	production_remaining = production_queue[0]["time"]
	_sync_remaining()

func _sync_remaining() -> void:
	training_remaining = production_remaining if not production_queue.is_empty() and production_queue[0]["type"] == "train" else 0.0
	research_remaining = production_remaining if not production_queue.is_empty() and production_queue[0]["type"] == "research" else 0.0
	age_remaining = production_remaining if not production_queue.is_empty() and production_queue[0]["type"] == "age" else 0.0

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
	unit.garrisoned_in = self
	unit.order = "idle"
	unit.position = position
	unit.hide()
	game.navigation.invalidate_spatial_index()
	queue_redraw()
	return true

func ungarrison_all(resume_previous_work := false) -> void:
	for index in garrisoned_units.size():
		var unit: RtsUnit = garrisoned_units[index]
		if not is_instance_valid(unit): continue
		unit.garrisoned_in = null
		unit.position = game.navigation.nearest_walkable_point(position + Vector2((index % 3 - 1) * 24, size().y * 0.5 + 30 + (index / 3) * 22), unit.radius(), unit)
		unit.show()
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
	_sync_remaining()
	if production_remaining > 0.0: return
	var job: Dictionary = production_queue.pop_front()
	if job["type"] == "train":
		training_queue.pop_front()
		var trained: RtsUnit = game.spawn_unit(owner_id, job["kind"], game.find_spawn_position(self), rally_point, rally_target, rally_resource_kind)
		if kind == "landmark" and (RtsLandmarkCatalog.produced_siege_hp(landmark_id) > 1.0 or RtsLandmarkCatalog.produced_siege_damage(landmark_id) > 1.0) and trained.stats.get("tags", []).has("siege"):
			trained.producer_landmark_id = landmark_id
			trained.refresh_stats()
		if landmark_id == "eng_wynguard_palace" and job["kind"] == "longbow" and game.population_used(owner_id) + 2 <= game.population_cap(owner_id):
			for offset in [Vector2(-20, 30), Vector2(20, 30)]:
				game.spawn_unit(owner_id, "spearman", game.find_spawn_position(self) + offset, rally_point, rally_target, rally_resource_kind)
	elif job["type"] == "research":
		research_queue.pop_front()
		game.complete_research(owner_id, job["kind"])
	else:
		game.complete_age(owner_id, job["target_age"])
	_begin_next_job()
	queue_redraw()

func take_damage(damage: float) -> void:
	hp -= damage
	queue_redraw()
	if hp <= 0.0:
		game.entity_destroyed(self)

func _draw() -> void:
	var bounds := Rect2(-size() * 0.5, size())
	var color: Color = game.player_color(owner_id)
	if not is_complete(): color = color.darkened(0.45)
	if game.view_mode_25d and not kind in ["farm", "palisade_wall", "stone_wall", "palisade_gate", "stone_gate"]:
		var depth := 18.0 if kind == "town_center" or kind == "landmark" or kind == "keep" else 12.0
		draw_rect(Rect2(bounds.position + Vector2(0, depth), bounds.size), color.darkened(0.55))
		draw_colored_polygon(PackedVector2Array([bounds.position + Vector2(0, bounds.size.y), bounds.position + bounds.size, bounds.position + bounds.size + Vector2(0, depth), bounds.position + Vector2(0, bounds.size.y + depth)]), color.darkened(0.4))
	draw_rect(bounds, Color("272d2a"))
	draw_rect(bounds.grow(-4), color)
	if kind.ends_with("_gate"):
		var opening := Rect2(-size() * 0.22, size() * 0.44)
		draw_rect(opening, Color("314638"))
		draw_line(opening.position, opening.end, Color("d8c88e"), 2)
	elif kind.ends_with("_wall"):
		draw_line(Vector2(-size().x * 0.4, 0), Vector2(size().x * 0.4, 0), Color("d5d0b3"), 3)
	elif kind == "farm":
		for x in range(-17, 25, 11):
			draw_line(Vector2(x, -22), Vector2(x - 7, 22), Color("d4bd73"), 3)
	elif kind == "town_center":
		draw_rect(Rect2(-15, -19, 30, 28), Color("e5d3a7"))
		draw_colored_polygon(PackedVector2Array([Vector2(-26, -19), Vector2(0, -35), Vector2(26, -19)]), Color("513c36"))
	else:
		draw_colored_polygon(PackedVector2Array([Vector2(-size().x * 0.4, -size().y * 0.4), Vector2(0, -size().y * 0.65), Vector2(size().x * 0.4, -size().y * 0.4)]), Color("513c36"))
	var font := ThemeDB.fallback_font
	if font != null:
		draw_string(font, Vector2(-size().x * 0.5, size().y * 0.5 + 15), display_label(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
	draw_rect(Rect2(-size().x * 0.5, -size().y * 0.5 - 10, size().x, 5), Color("432e2b"))
	draw_rect(Rect2(-size().x * 0.5, -size().y * 0.5 - 10, size().x * clampf(hp / max_hp, 0.0, 1.0), 5), Color("7fd47a"))
	if not is_complete():
		draw_arc(Vector2.ZERO, 14, 0, TAU * (1.0 - build_remaining / maxf(build_total, 0.1)), 20, Color.WHITE, 3)
	if not production_queue.is_empty():
		draw_circle(Vector2(size().x * 0.5 - 4, -size().y * 0.5 + 4), 8, Color("e5c45d"))

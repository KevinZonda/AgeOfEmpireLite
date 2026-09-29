class_name RtsBuilding
extends Node2D
const RtsUiTypography = preload("res://scripts/ui/typography.gd")

const LandmarkVisual = preload("res://scripts/entities/visuals/landmark_visual.gd")
const EconomyBuildingVisual = preload("res://scripts/entities/visuals/economy_building_visual.gd")
const IndustryBuildingVisual = preload("res://scripts/entities/visuals/industry_building_visual.gd")
const FARM_SOW_WORK := 2.2
const FARM_HARVEST_WORK := 4.4
var landmark_geometry
var landmark_geometry_key := ""

var game: Node2D
var owner_id := 0
var kind: String
var landmark_id := ""
var stats: Dictionary = {}
var hp := 1.0
var max_hp := 1.0
var build_remaining := 0.0
var build_total := 0.0
var farm_stage := "sowing"
var farm_stage_progress := 0.0
var farm_food_buffer := 0.0
var training_queue: Array[String] = []
var research_queue: Array[String] = []
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
var damage_flash_timer := 0.0
var building_icon: Texture2D

func setup(game_ref: Node2D, player_id: int, building_kind: String, under_construction := false, chosen_landmark := "") -> void:
	game = game_ref
	owner_id = player_id
	kind = building_kind
	landmark_id = chosen_landmark
	var icon_kind := landmark_id if kind == "landmark" else "scout" if kind == "scout_camp" else kind
	building_icon = RtsCommandButton._texture_at("res://assets/ui/command_icons/%s.png" % icon_kind)
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

func icon_size() -> float:
	return 24.0 if kind.ends_with("_wall") or kind.ends_with("_gate") or kind == "scout_camp" else 30.0

func contains_icon_visual(world_point: Vector2, canvas: Transform2D) -> bool:
	if game.get("show_building_icons") == false: return false
	var side := icon_size()
	if not game.view_mode_25d:
		var center := Vector2(0, -size().y * 0.5 - side * 0.5 - 8.0)
		return Rect2(center - Vector2.ONE * side * 0.5, Vector2.ONE * side).has_point(world_point - position)
	var construction_ratio := 1.0 - build_remaining / maxf(build_total, 0.1)
	var height := isometric_height() * (0.25 + 0.75 * construction_ratio) + (visual_feature_height() + _landmark_extra_height() if construction_ratio >= 0.65 else 0.0)
	var terrain_lift := RtsIsoProjection.world_delta(canvas, Vector2(0, -foundation_height() * game.camera.zoom.x))
	var screen_point := canvas.basis_xform(world_point - position - terrain_lift)
	var center := Vector2(0, -height * game.camera.zoom.x - side * 0.5 - 9.0)
	return Rect2(center - Vector2.ONE * side * 0.5, Vector2.ONE * side).has_point(screen_point)

func isometric_height() -> float:
	var art_kind := _visual_kind()
	if art_kind == "farm": return 0.0
	if art_kind.ends_with("_wall") or art_kind.ends_with("_gate"): return 11.0
	if art_kind == "outpost": return 43.0
	if art_kind == "wonder": return 58.0
	if art_kind in ["town_center", "keep", "palace"]: return 42.0
	if art_kind in ["monastery", "university"]: return 34.0
	if art_kind == "mill": return 35.0
	if art_kind in ["lumber_camp", "mining_camp", "scout_camp", "dock"]: return 17.0
	if art_kind == "house": return 23.0
	return 26.0

func visual_feature_height() -> float:
	match kind:
		"town_center": return 22.0
		"lumber_camp": return 10.0
		"mining_camp": return 17.0
		"mill": return 12.0
		"blacksmith": return 18.0
		"siege_workshop": return 15.0
		"market": return 10.0
		"university": return 18.0
	return 0.0

func _landmark_extra_height() -> float:
	if kind not in ["landmark", "wonder"]: return 0.0
	return _landmark_geometry().height_above_origin

func _visual_kind() -> String:
	if kind != "landmark": return kind
	match landmark_id:
		"eng_white_tower", "eng_berkshire_fortress", "fr_red_palace", "zh_barbican", "zh_gatehouse": return "keep"
		"eng_kings_mill", "eng_abbey", "zh_spirit_way": return "monastery"
		"eng_wynguard_palace", "zh_imperial_palace": return "palace"
		"fr_school_of_cavalry": return "stable"
		"fr_chamber_of_commerce", "fr_guild_hall": return "market"
		"fr_royal_institute", "zh_imperial_academy": return "university"
		"fr_college_of_artillery", "zh_clocktower": return "siege_workshop"
		_: return "town_center"

func foundation_height() -> float:
	if game == null or game.world_map == null: return 0.0
	var half := size() * 0.5
	var height: float = game.world_map.elevation_at(position)
	for corner in [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)]:
		height = maxf(height, game.world_map.elevation_at(position + corner))
	return height

func contains_isometric_visual(world_point: Vector2, canvas: Transform2D) -> bool:
	if contains(world_point): return true
	var bounds := Rect2(-size() * 0.5, size())
	var nw := bounds.position
	var ne := Vector2(bounds.end.x, bounds.position.y)
	var se := bounds.end
	var sw := Vector2(bounds.position.x, bounds.end.y)
	var terrain_lift := RtsIsoProjection.world_delta(canvas, Vector2(0, -foundation_height() * game.camera.zoom.x))
	var construction_ratio := 1.0 - build_remaining / maxf(build_total, 0.1)
	var height := isometric_height() * (0.25 + 0.75 * construction_ratio)
	var lift := terrain_lift + RtsIsoProjection.world_delta(canvas, Vector2(0, -height * game.camera.zoom.x))
	var local_point := world_point - position
	if not kind in ["landmark", "wonder", "farm", "barracks", "archery_range", "stable", "palisade_wall", "stone_wall", "palisade_gate", "stone_gate"]:
		var center := (nw + ne + se + sw) * 0.25
		var overhang := 1.1 if game.civilizations[owner_id] == "Chinese" else 1.06
		var a := center + (nw - center) * overhang + lift
		var b := center + (ne - center) * overhang + lift
		var c := center + (se - center) * overhang + lift
		var d := center + (sw - center) * overhang + lift
		var roof_rise := 15.0 if kind in ["town_center", "landmark", "keep", "wonder"] else 9.0
		var rise := RtsIsoProjection.world_delta(canvas, Vector2(0, -roof_rise * game.camera.zoom.x))
		var ridge_back := (a + b) * 0.5 + rise
		var ridge_front := (d + c) * 0.5 + rise
		for facet in [PackedVector2Array([a, ridge_back, ridge_front, d]), PackedVector2Array([ridge_back, b, c, ridge_front])]:
			if Geometry2D.is_point_in_polygon(local_point, facet): return true
	for polygon in [
		PackedVector2Array([nw + lift, ne + lift, se + lift, sw + lift]),
		PackedVector2Array([ne + lift, se + lift, se + terrain_lift, ne + terrain_lift]),
		PackedVector2Array([sw + lift, se + lift, se + terrain_lift, sw + terrain_lift]),
	]:
		if Geometry2D.is_point_in_polygon(local_point, polygon): return true
	if kind in ["barracks", "archery_range"] and construction_ratio >= 0.65:
		var floor_lift := terrain_lift + (lift - terrain_lift) * 0.18
		var towers: Array = [[0.14, 0.75, 0.15, 0.17, 32.0], [0.72, 0.75, 0.15, 0.17, 32.0]] if kind == "barracks" else [[0.76, 0.09, 0.18, 0.24, 38.0]]
		for tower in towers:
			var u: float = tower[0]
			var v: float = tower[1]
			var width: float = tower[2]
			var depth: float = tower[3]
			var up := RtsIsoProjection.world_delta(canvas, Vector2(0, -float(tower[4]) * game.camera.zoom.x))
			var corners := PackedVector2Array([
				_military_point(nw, ne, sw, u, v) + floor_lift,
				_military_point(nw, ne, sw, u + width, v) + floor_lift,
				_military_point(nw, ne, sw, u + width, v + depth) + floor_lift,
				_military_point(nw, ne, sw, u, v + depth) + floor_lift,
			])
			var hull_points := PackedVector2Array(corners)
			for corner in corners: hull_points.append(corner + up)
			hull_points.append(_military_point(nw, ne, sw, u + width * 0.5, v + depth * 0.5) + floor_lift + up + RtsIsoProjection.world_delta(canvas, Vector2(0, -16.0 * game.camera.zoom.x)))
			if Geometry2D.is_point_in_polygon(local_point, Geometry2D.convex_hull(hull_points)): return true
	if kind in ["landmark", "wonder"] and construction_ratio >= 0.65:
		for polygon in _landmark_geometry().projected_faces(canvas, game.camera.zoom.x, lift):
			if Geometry2D.is_point_in_polygon(local_point, polygon["points"]): return true
	return false

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
		game.navigation.invalidate_spatial_index()
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
	var job: Dictionary = production_queue.pop_front()
	if job["type"] == "train":
		training_queue.pop_front()
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
		research_queue.pop_front()
		game.complete_research(owner_id, job["kind"])
	_begin_next_job()
	queue_redraw()

func take_damage(damage: float) -> void:
	hp -= damage
	damage_flash_timer = 0.22
	if owner_id == 0 and game.has_method("play_feedback"): game.play_feedback("alert")
	queue_redraw()
	if hp <= 0.0:
		game.entity_destroyed(self)

func _draw() -> void:
	if game.view_mode_25d:
		_draw_isometric()
		return
	var bounds := Rect2(-size() * 0.5, size())
	var palette := _architecture_palette()
	var wall_color: Color = palette["wall"]
	var construction_ratio := 1.0 - build_remaining / maxf(build_total, 0.1)
	draw_rect(bounds, Color("272d2a"))
	draw_rect(bounds.grow(-4), wall_color.darkened(0.28) if not is_complete() else wall_color)
	if damage_flash_timer > 0.0: draw_rect(bounds.grow(-2), Color("f8ca91", damage_flash_timer * 1.4), false, 3.0)
	if not is_complete():
		var timber := Color("b99b6e")
		for side in [-1.0, 1.0]:
			var post_x: float = side * (size().x * 0.5 - 7.0)
			draw_line(Vector2(post_x, size().y * 0.43), Vector2(post_x, -size().y * 0.43 * construction_ratio), timber, 3.0)
			draw_line(Vector2(post_x, size().y * 0.2), Vector2(-post_x, -size().y * 0.28 * construction_ratio), Color(timber, 0.72), 2.0)
		if construction_ratio < 0.65:
			draw_rect(Rect2(-size().x * 0.42, -size().y * 0.35, size().x * 0.84, 5), Color("6d5a41"))
	if construction_ratio >= 0.65:
		_draw_topdown_architecture(bounds, palette)
		if kind == "landmark" or kind == "wonder": _draw_topdown_landmark(bounds, palette)
	var side := icon_size()
	_draw_building_icon(Vector2(0, -size().y * 0.5 - side * 0.5 - 8.0), side)
	var font := ThemeDB.fallback_font
	if font != null and game.get("show_building_names") != false:
		var font_size: int = RtsUiTypography.world_caption_size(game)
		var canvas := get_viewport().get_canvas_transform()
		var label_anchor := canvas.basis_xform(Vector2(-size().x * 0.5, size().y * 0.5))
		draw_set_transform_matrix(RtsIsoProjection.upright(canvas, Vector2.ZERO))
		draw_string(font, label_anchor + Vector2(0, font_size + 2), display_label(), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
		draw_set_transform_matrix(Transform2D.IDENTITY)
	var bar_y := -size().y * 0.5 - side - 18.0
	draw_rect(Rect2(-size().x * 0.5, bar_y, size().x, 5), Color("432e2b"))
	draw_rect(Rect2(-size().x * 0.5, bar_y, size().x * clampf(hp / max_hp, 0.0, 1.0), 5), Color("7fd47a"))
	if not is_complete():
		draw_arc(Vector2.ZERO, 14, 0, TAU * (1.0 - build_remaining / maxf(build_total, 0.1)), 20, Color.WHITE, 3)
	if not production_queue.is_empty():
		draw_circle(Vector2(size().x * 0.5 - 4, -size().y * 0.5 + 4), 8, Color("e5c45d"))

func _draw_isometric() -> void:
	var bounds := Rect2(-size() * 0.5, size())
	var art_kind := _visual_kind()
	var body_bounds := bounds
	if art_kind == "monastery" and kind != "landmark":
		body_bounds = Rect2(Vector2(-size().x * 0.34, -size().y * 0.5), Vector2(size().x * 0.68, size().y))
	var open_yard := kind != "landmark" and art_kind in ["town_center", "barracks", "archery_range", "stable", "market", "university", "dock", "lumber_camp", "mining_camp", "mill", "scout_camp", "blacksmith", "siege_workshop"]
	var palette := _architecture_palette()
	var color: Color = palette["wall"]
	var construction_ratio := 1.0 - build_remaining / maxf(build_total, 0.1)
	if not is_complete(): color = color.darkened(0.32)
	var nw := body_bounds.position
	var ne := Vector2(body_bounds.end.x, body_bounds.position.y)
	var se := body_bounds.end
	var sw := Vector2(body_bounds.position.x, body_bounds.end.y)
	var height := isometric_height() * (0.25 + 0.75 * construction_ratio)
	var canvas := get_viewport().get_canvas_transform()
	var lift := RtsIsoProjection.world_delta(canvas, Vector2(0, -height * game.camera.zoom.x))
	var wall_lift := lift * 0.18 if open_yard else lift
	var terrain_lift := RtsIsoProjection.world_delta(canvas, Vector2(0, -foundation_height() * game.camera.zoom.x))
	var ne_ground := RtsIsoProjection.ground_lift(game, position + ne) - terrain_lift
	var se_ground := RtsIsoProjection.ground_lift(game, position + se) - terrain_lift
	var sw_ground := RtsIsoProjection.ground_lift(game, position + sw) - terrain_lift
	draw_set_transform_matrix(Transform2D(0.0, terrain_lift))
	if ne_ground.length() + se_ground.length() + sw_ground.length() > 0.5:
		draw_colored_polygon(PackedVector2Array([ne, se, se + se_ground, ne + ne_ground]), Color("625d4e"))
		draw_colored_polygon(PackedVector2Array([sw, se, se + se_ground, sw + sw_ground]), Color("817866"))
		draw_line(sw + sw_ground, se + se_ground, Color("3a3c32", 0.75), 1.4)
	draw_colored_polygon(PackedVector2Array([nw, ne, se, sw]), Color("273a30", 0.65))
	if height > 0.0:
		draw_colored_polygon(PackedVector2Array([ne + wall_lift, se + wall_lift, se, ne]), color.darkened(0.26))
		draw_colored_polygon(PackedVector2Array([sw + wall_lift, se + wall_lift, se, sw]), color)
		draw_polyline(PackedVector2Array([ne + wall_lift, se + wall_lift, se, ne, ne + wall_lift]), Color("1c2829"), 2.0)
		draw_polyline(PackedVector2Array([sw + wall_lift, se + wall_lift, se, sw, sw + wall_lift]), Color("1c2829"), 2.0)
	var roof_color: Color = palette["roof"]
	if art_kind == "farm": roof_color = Color("735035")
	if art_kind.ends_with("_wall") or art_kind.ends_with("_gate"): roof_color = color.lightened(0.08)
	if construction_ratio >= 0.65:
		draw_colored_polygon(PackedVector2Array([nw + wall_lift, ne + wall_lift, se + wall_lift, sw + wall_lift]), roof_color if not open_yard else palette["timber"])
		draw_polyline(PackedVector2Array([nw + wall_lift, ne + wall_lift, se + wall_lift, sw + wall_lift, nw + wall_lift]), Color("1f2929"), 2.0)
		_draw_iso_architecture(art_kind, nw, ne, se, sw, lift, palette, canvas)
		if kind == "landmark" or kind == "wonder": _draw_iso_landmark_architecture(lift, canvas)
	else:
		var scaffold := Color("c5a878")
		for corner in [nw, ne, sw, se]:
			draw_line(corner, corner + lift * maxf(0.2, construction_ratio), scaffold, 2.2)
		draw_line(nw + lift * 0.38, se + lift * 0.38, Color(scaffold, 0.82), 2.0)
		draw_line(ne + lift * 0.38, sw + lift * 0.38, Color(scaffold, 0.82), 2.0)
	if damage_flash_timer > 0.0:
		draw_polyline(PackedVector2Array([nw + lift, ne + lift, se + lift, sw + lift, nw + lift]), Color("f7d091", damage_flash_timer * 3.4), 3.0)
	# Labels and status bars are drawn in screen space so they stay legible.
	draw_set_transform_matrix(RtsIsoProjection.upright(canvas, terrain_lift))
	var side := icon_size()
	var icon_height := height + (visual_feature_height() + _landmark_extra_height() if construction_ratio >= 0.65 else 0.0)
	_draw_building_icon(Vector2(0, -icon_height * game.camera.zoom.x - side * 0.5 - 9.0), side)
	var font := ThemeDB.fallback_font
	if font != null and game.get("show_building_names") != false:
		var label := display_label()
		var font_size: int = RtsUiTypography.world_caption_size(game)
		var label_width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(font, Vector2(-label_width * 0.5, canvas.basis_xform(se).y + font_size + 5.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
	var bar_width := minf(72.0, size().x * 0.8)
	var bar_y: float = minf(-icon_height * game.camera.zoom.x - size().y * 0.25 - 16.0, -icon_height * game.camera.zoom.x - side - 20.0)
	draw_rect(Rect2(-bar_width * 0.5, bar_y, bar_width, 5), Color("422f2d"))
	draw_rect(Rect2(-bar_width * 0.5, bar_y, bar_width * clampf(hp / max_hp, 0.0, 1.0), 5), Color("7fd47a"))
	if not is_complete(): draw_arc(Vector2.ZERO, 14, 0, TAU * (1.0 - build_remaining / maxf(build_total, 0.1)), 20, Color.WHITE, 3)
	if not production_queue.is_empty(): draw_circle(Vector2(bar_width * 0.5 + 5, bar_y + 2), 6, Color("e5c45d"))
	draw_set_transform_matrix(Transform2D.IDENTITY)

func _architecture_palette() -> Dictionary:
	match game.civilizations[owner_id]:
		"French":
			return {"wall": Color("d1c4a4"), "timber": Color("706451"), "roof": Color("647989"), "roof_dark": Color("405463"), "trim": Color("e1d6b4")}
		"Chinese":
			return {"wall": Color("d8c8a3"), "timber": Color("924d3b"), "roof": Color("53645d"), "roof_dark": Color("344740"), "trim": Color("e2ba75")}
		_:
			var palette := {"wall": Color("cbbd99"), "timber": Color("674c39"), "roof": Color("75564a"), "roof_dark": Color("503b37"), "trim": Color("e3d0a0")}
			if kind in ["town_center", "lumber_camp", "mining_camp", "mill", "blacksmith", "siege_workshop"]:
				palette["roof"] = Color("59636a")
				palette["roof_dark"] = Color("3b454b")
			return palette

func _draw_topdown_architecture(bounds: Rect2, palette: Dictionary) -> void:
	var art_kind := _visual_kind()
	if kind not in ["landmark", "wonder"] and art_kind in ["town_center", "mill", "lumber_camp"]:
		EconomyBuildingVisual.draw_topdown(self, art_kind, bounds, palette, game.player_color(owner_id), game.civilizations[owner_id])
		return
	if kind not in ["landmark", "wonder"] and art_kind in ["mining_camp", "blacksmith", "siege_workshop"]:
		IndustryBuildingVisual.draw_topdown(self, art_kind, bounds, palette, game.player_color(owner_id), game.civilizations[owner_id])
		return
	var roof_bounds := bounds.grow(-6.0)
	var roof: Color = palette["roof"]
	var dark: Color = palette["roof_dark"]
	var trim: Color = palette["trim"]
	var wall: Color = palette["wall"]
	if art_kind == "farm":
		draw_rect(roof_bounds, Color("735035"))
		for portion in [0.1, 0.3, 0.5, 0.7, 0.9]:
			var y := lerpf(roof_bounds.position.y, roof_bounds.end.y, portion)
			draw_line(Vector2(roof_bounds.position.x + 3, y), Vector2(roof_bounds.end.x - 3, y), Color("a2784a"), 2.2)
			if is_complete() and farm_crop_fraction() >= portion:
				for x_portion in [0.2, 0.4, 0.6, 0.8]:
					var x := lerpf(roof_bounds.position.x, roof_bounds.end.x, x_portion)
					draw_line(Vector2(x, y + 2), Vector2(x, y - 5), Color("a9c468"), 2.0)
					draw_circle(Vector2(x + 2, y - 5), 2.0, Color("d9c875"))
		return
	if art_kind.ends_with("_wall") or art_kind.ends_with("_gate"):
		draw_rect(roof_bounds, trim if art_kind.begins_with("stone") else palette["timber"])
		for portion in [0.1, 0.3, 0.5, 0.7, 0.9]:
			var x := lerpf(roof_bounds.position.x, roof_bounds.end.x, portion)
			draw_rect(Rect2(x - 3, roof_bounds.position.y - 2, 6, 5), dark)
		if art_kind.ends_with("_gate"):
			var gap := Rect2(-size().x * 0.14, roof_bounds.position.y, size().x * 0.28, roof_bounds.size.y)
			draw_rect(gap, Color("304136"))
		return
	if art_kind in ["keep", "outpost"]:
		draw_rect(roof_bounds, wall.darkened(0.33))
		draw_rect(roof_bounds, trim, false, 3.0)
		for portion in [0.12, 0.36, 0.6, 0.84]:
			var x := lerpf(roof_bounds.position.x, roof_bounds.end.x, portion)
			draw_rect(Rect2(x - 3, roof_bounds.position.y - 2, 6, 5), trim)
			draw_rect(Rect2(x - 3, roof_bounds.end.y - 3, 6, 5), trim)
		draw_rect(Rect2(-5, -5, 10, 10), dark)
		return
	if art_kind in ["barracks", "archery_range", "stable"]:
		_draw_topdown_military_structure(art_kind, roof_bounds, palette)
		return
	if kind != "landmark" and art_kind == "university":
		_draw_topdown_university(roof_bounds, palette)
		return
	if art_kind in ["market", "dock", "scout_camp"]:
		_draw_topdown_open_structure(art_kind, roof_bounds, palette)
		return
	var top_left := roof_bounds.position
	var top_right := Vector2(roof_bounds.end.x, roof_bounds.position.y)
	var bottom_left := Vector2(roof_bounds.position.x, roof_bounds.end.y)
	var bottom_right := roof_bounds.end
	var ridge_left := Vector2(roof_bounds.position.x + 5, roof_bounds.get_center().y)
	var ridge_right := Vector2(roof_bounds.end.x - 5, roof_bounds.get_center().y)
	draw_colored_polygon(PackedVector2Array([top_left, top_right, ridge_right, ridge_left]), roof.lightened(0.11))
	draw_colored_polygon(PackedVector2Array([ridge_left, ridge_right, bottom_right, bottom_left]), roof)
	draw_line(ridge_left, ridge_right, trim, 2.0)
	draw_polyline(PackedVector2Array([top_left, top_right, bottom_right, bottom_left, top_left]), dark, 1.7)
	for portion in [0.28, 0.55, 0.8]:
		var x := lerpf(roof_bounds.position.x, roof_bounds.end.x, portion)
		draw_line(Vector2(x, roof_bounds.position.y + 2), Vector2(x, roof_bounds.get_center().y - 2), Color(dark, 0.46), 1.0)
		draw_line(Vector2(x, roof_bounds.get_center().y + 2), Vector2(x, roof_bounds.end.y - 2), Color(dark, 0.36), 1.0)
	draw_line(Vector2(roof_bounds.position.x, roof_bounds.end.y + 2), Vector2(roof_bounds.end.x, roof_bounds.end.y + 2), game.player_color(owner_id), 3.0)
	match art_kind:
		"town_center", "palace", "wonder", "university", "monastery":
			var tower := Rect2(Vector2(-7, -8), Vector2(14, 16))
			draw_rect(tower, palette["wall"])
			draw_rect(tower.grow(-2), dark)
			draw_rect(tower, trim, false, 1.3)
			if art_kind in ["wonder", "palace"]:
				draw_rect(tower.grow(4), trim, false, 2.0)
		"house", "siege_workshop":
			draw_rect(Rect2(roof_bounds.position + Vector2(9, 8), Vector2(7, 8)), palette["timber"])
	if art_kind == "siege_workshop":
		draw_rect(Rect2(roof_bounds.position.x + 7, roof_bounds.end.y - 17, roof_bounds.size.x - 14, 11), dark)
	elif art_kind == "monastery":
		draw_line(Vector2(0, -14), Vector2(0, 14), trim, 3.0)
		draw_line(Vector2(-9, 0), Vector2(9, 0), trim, 3.0)

func _draw_topdown_open_structure(art_kind: String, roof_bounds: Rect2, palette: Dictionary) -> void:
	if art_kind == "market":
		_draw_topdown_market(roof_bounds, palette)
		return
	var timber: Color = palette["timber"]
	var trim: Color = palette["trim"]
	draw_rect(roof_bounds, Color("ab9b74") if art_kind != "dock" else Color("a77c50"))
	for portion in [0.17, 0.38, 0.59, 0.8]:
		var y := lerpf(roof_bounds.position.y, roof_bounds.end.y, portion)
		draw_line(Vector2(roof_bounds.position.x, y), Vector2(roof_bounds.end.x, y), Color(timber, 0.35), 1.0)
	match art_kind:
		"dock":
			for portion in [0.1, 0.4, 0.7, 0.9]:
				var x := lerpf(roof_bounds.position.x, roof_bounds.end.x, portion)
				draw_circle(Vector2(x, roof_bounds.position.y), 2.8, timber)
				draw_circle(Vector2(x, roof_bounds.end.y), 2.8, timber)
		"scout_camp":
			var center := roof_bounds.get_center()
			draw_colored_polygon(PackedVector2Array([center + Vector2(-13, 7), center + Vector2(0, -12), center + Vector2(13, 7)]), Color("a98458"))
			draw_circle(center + Vector2(0, 14), 3.0, Color("d88a47"))

func _draw_topdown_market(bounds: Rect2, palette: Dictionary) -> void:
	draw_rect(bounds, Color("a99b77"))
	var hall := _military_rect(bounds, 0.06, 0.08, 0.55, 0.34)
	var hall_palette := palette.duplicate()
	if game.civilizations[owner_id] == "English":
		hall_palette["roof"] = Color("59656a")
		hall_palette["roof_dark"] = Color("404b51")
	_draw_topdown_military_roof(hall, hall_palette)
	for box in [_military_rect(bounds, 0.06, 0.58, 0.35, 0.22), _military_rect(bounds, 0.66, 0.53, 0.28, 0.27)]:
		draw_rect(box, palette["trim"])
		for stripe in [0.2, 0.55, 0.9]:
			var x := lerpf(box.position.x, box.end.x, stripe)
			draw_line(Vector2(x, box.position.y), Vector2(x, box.end.y), game.player_color(owner_id), box.size.x * 0.16)
		draw_rect(box, palette["timber"], false, 1.5)
	var cross := bounds.position + bounds.size * Vector2(0.87, 0.37)
	draw_rect(Rect2(cross - Vector2(5, 4), Vector2(10, 8)), palette["wall"].darkened(0.18))
	draw_rect(Rect2(cross - Vector2(2, 7), Vector2(4, 7)), palette["trim"])
	for spot in [Vector2(0.83, 0.86), Vector2(0.2, 0.88)]:
		draw_circle(bounds.position + bounds.size * spot, 2.8, Color("9b6b3d"))

func _university_palette(palette: Dictionary) -> Dictionary:
	var college := palette.duplicate()
	if game.civilizations[owner_id] == "English":
		college["wall"] = Color("b8ae96")
		college["timber"] = Color("6b5849")
		college["roof"] = Color("586168")
		college["roof_dark"] = Color("414a51")
		college["trim"] = Color("d8c9ab")
	return college

func _draw_topdown_university(bounds: Rect2, palette: Dictionary) -> void:
	var college := _university_palette(palette)
	draw_rect(bounds, Color("9b9b83"))
	var court := _military_rect(bounds, 0.3, 0.37, 0.4, 0.52)
	draw_rect(court, Color("b6ad96"))
	for box in [
		_military_rect(bounds, 0.07, 0.07, 0.86, 0.3),
		_military_rect(bounds, 0.07, 0.34, 0.23, 0.5),
		_military_rect(bounds, 0.7, 0.34, 0.23, 0.5),
	]:
		draw_rect(box.grow(2), college["wall"])
		_draw_topdown_military_roof(box, college)
	var tower := _military_rect(bounds, 0.41, 0.18, 0.18, 0.22)
	draw_rect(tower, college["wall"].darkened(0.28))
	draw_rect(tower.grow(-2), college["roof_dark"])
	draw_rect(tower, palette["trim"], false, 1.5)
	var monument := bounds.position + bounds.size * Vector2(0.5, 0.68)
	draw_rect(Rect2(monument - Vector2(4, 3), Vector2(8, 6)), palette["wall"])
	draw_circle(monument, 2.0, palette["trim"])
	for u in [0.34, 0.66]:
		var y := bounds.position.y + bounds.size.y * 0.8
		draw_line(Vector2(bounds.position.x + bounds.size.x * u, y), Vector2(bounds.position.x + bounds.size.x * u, bounds.end.y - 2), Color("687957"), 3.0)

func _military_rect(bounds: Rect2, u: float, v: float, width: float, depth: float) -> Rect2:
	return Rect2(bounds.position + bounds.size * Vector2(u, v), bounds.size * Vector2(width, depth))

func _draw_topdown_military_roof(box: Rect2, palette: Dictionary, ridge_along_width := true) -> void:
	var roof: Color = palette["roof"]
	var dark: Color = palette["roof_dark"]
	var trim: Color = palette["trim"]
	draw_rect(box, roof)
	draw_rect(box, dark, false, 1.6)
	if ridge_along_width:
		draw_line(Vector2(box.position.x + 2, box.get_center().y), Vector2(box.end.x - 2, box.get_center().y), trim, 2.0)
	else:
		draw_line(Vector2(box.get_center().x, box.position.y + 2), Vector2(box.get_center().x, box.end.y - 2), trim, 2.0)

func _draw_topdown_military_structure(art_kind: String, bounds: Rect2, palette: Dictionary) -> void:
	var timber: Color = palette["timber"]
	var trim: Color = palette["trim"]
	var wall: Color = palette["wall"]
	draw_rect(bounds, Color("a99b77"))
	for portion in [0.16, 0.37, 0.58, 0.79]:
		var y := lerpf(bounds.position.y, bounds.end.y, portion)
		draw_line(Vector2(bounds.position.x, y), Vector2(bounds.end.x, y), Color(timber, 0.28), 1.0)
	match art_kind:
		"barracks":
			_draw_topdown_military_roof(_military_rect(bounds, 0.08, 0.07, 0.84, 0.27), palette)
			_draw_topdown_military_roof(_military_rect(bounds, 0.08, 0.28, 0.23, 0.46), palette, false)
			_draw_topdown_military_roof(_military_rect(bounds, 0.69, 0.28, 0.23, 0.46), palette, false)
			for u in [0.22, 0.78]:
				var tower := _military_rect(bounds, u - 0.1, 0.72, 0.2, 0.2)
				draw_rect(tower, palette["roof_dark"])
				draw_rect(tower, trim, false, 2.0)
			var yard := _military_rect(bounds, 0.35, 0.42, 0.3, 0.39)
			for u in [0.42, 0.58]:
				var target := bounds.position + bounds.size * Vector2(u, 0.53)
				draw_line(target, target + Vector2(0, 11), timber, 2.0)
				draw_line(target + Vector2(-4, 5), target + Vector2(4, 5), timber, 1.6)
				draw_circle(target, 2.5, wall)
			draw_line(yard.position + Vector2(0, yard.size.y), yard.end, trim, 2.0)
		"archery_range":
			_draw_topdown_military_roof(_military_rect(bounds, 0.06, 0.07, 0.7, 0.27), palette)
			_draw_topdown_military_roof(_military_rect(bounds, 0.06, 0.29, 0.22, 0.45), palette, false)
			var tower := _military_rect(bounds, 0.72, 0.1, 0.22, 0.24)
			draw_rect(tower, palette["roof_dark"])
			draw_rect(tower, trim, false, 2.0)
			for u in [0.4, 0.59, 0.78]:
				var target := bounds.position + bounds.size * Vector2(u, 0.57)
				draw_line(target + Vector2(0, 5), target + Vector2(0, 13), timber, 1.6)
				draw_circle(target, 5.2, wall)
				draw_circle(target, 3.3, Color("ad654a"))
				draw_circle(target, 1.4, trim)
				draw_line(target + Vector2(0, 14), target + Vector2(0, 20), trim, 1.2)
		"stable":
			_draw_topdown_military_roof(_military_rect(bounds, 0.06, 0.06, 0.88, 0.3), palette)
			_draw_topdown_military_roof(_military_rect(bounds, 0.06, 0.32, 0.24, 0.38), palette, false)
			var paddock := _military_rect(bounds, 0.34, 0.43, 0.55, 0.43)
			draw_rect(paddock, timber, false, 2.0)
			for u in [0.46, 0.74]:
				var stall := bounds.position + bounds.size * Vector2(u, 0.47)
				draw_line(stall, stall + Vector2(0, 11), timber, 1.5)
			var horse := bounds.position + bounds.size * Vector2(0.59, 0.66)
			draw_colored_polygon(PackedVector2Array([horse + Vector2(-7, -3), horse + Vector2(5, -3), horse + Vector2(8, 1), horse + Vector2(-5, 4)]), Color("765039"))
			draw_circle(horse + Vector2(9, 0), 2.5, Color("765039"))

func _draw_topdown_landmark(bounds: Rect2, palette: Dictionary) -> void:
	var forms: Array = []
	if kind == "wonder":
		forms = [[0.5, 0.5, 0.65, 0.65, "dome"], [0.16, 0.16, 0.17, 0.17, "spire"], [0.84, 0.16, 0.17, 0.17, "spire"], [0.16, 0.84, 0.17, 0.17, "spire"], [0.84, 0.84, 0.17, 0.17, "spire"]]
	else:
		match landmark_id:
			"eng_council_hall": forms = [[0.5, 0.44, 0.73, 0.42, "gable"], [0.5, 0.8, 0.57, 0.13, "portico"]]
			"eng_kings_mill": forms = [[0.5, 0.52, 0.37, 0.67, "gable"], [0.22, 0.46, 0.19, 0.24, "spire"], [0.78, 0.46, 0.19, 0.24, "spire"]]
			"eng_white_tower": forms = [[0.5, 0.5, 0.52, 0.58, "flat"]]
			"eng_abbey": forms = [[0.5, 0.43, 0.34, 0.71, "gable"], [0.23, 0.75, 0.2, 0.19, "spire"], [0.77, 0.75, 0.2, 0.19, "spire"]]
			"eng_berkshire_fortress": forms = [[0.5, 0.5, 0.35, 0.35, "flat"], [0.15, 0.15, 0.22, 0.22, "flat"], [0.85, 0.15, 0.22, 0.22, "flat"], [0.15, 0.85, 0.22, 0.22, "flat"], [0.85, 0.85, 0.22, 0.22, "flat"]]
			"eng_wynguard_palace": forms = [[0.5, 0.46, 0.47, 0.55, "hip"], [0.17, 0.55, 0.2, 0.32, "spire"], [0.83, 0.55, 0.2, 0.32, "spire"]]
			"fr_school_of_cavalry": forms = [[0.19, 0.5, 0.23, 0.73, "gable"], [0.81, 0.5, 0.23, 0.73, "gable"], [0.5, 0.17, 0.38, 0.22, "hip"]]
			"fr_chamber_of_commerce": forms = [[0.18, 0.34, 0.28, 0.42, "awning"], [0.5, 0.34, 0.28, 0.42, "awning"], [0.82, 0.34, 0.28, 0.42, "awning"], [0.5, 0.75, 0.3, 0.22, "hip"]]
			"fr_royal_institute": forms = [[0.2, 0.6, 0.29, 0.4, "gable"], [0.8, 0.6, 0.29, 0.4, "gable"], [0.5, 0.4, 0.39, 0.42, "dome"]]
			"fr_guild_hall": forms = [[0.2, 0.62, 0.27, 0.37, "gable"], [0.8, 0.62, 0.27, 0.37, "gable"], [0.5, 0.38, 0.35, 0.38, "spire"]]
			"fr_red_palace": forms = [[0.5, 0.5, 0.38, 0.38, "red"], [0.16, 0.17, 0.2, 0.2, "red"], [0.84, 0.17, 0.2, 0.2, "red"], [0.16, 0.83, 0.2, 0.2, "red"], [0.84, 0.83, 0.2, 0.2, "red"]]
			"fr_college_of_artillery": forms = [[0.5, 0.49, 0.64, 0.51, "gable"], [0.22, 0.2, 0.14, 0.16, "chimney"], [0.78, 0.2, 0.14, 0.16, "chimney"]]
			"zh_imperial_academy": forms = [[0.5, 0.24, 0.44, 0.29, "gable"], [0.17, 0.53, 0.24, 0.44, "pagoda"], [0.83, 0.53, 0.24, 0.44, "pagoda"]]
			"zh_barbican": forms = [[0.5, 0.34, 0.39, 0.3, "flat"], [0.2, 0.67, 0.23, 0.32, "pagoda"], [0.8, 0.67, 0.23, 0.32, "pagoda"]]
			"zh_clocktower": forms = [[0.5, 0.49, 0.38, 0.43, "clock"], [0.16, 0.65, 0.18, 0.29, "gable"], [0.84, 0.65, 0.18, 0.29, "gable"]]
			"zh_imperial_palace": forms = [[0.5, 0.28, 0.7, 0.31, "pagoda"], [0.5, 0.67, 0.56, 0.31, "pagoda"]]
			"zh_gatehouse": forms = [[0.5, 0.45, 0.48, 0.4, "pagoda"], [0.14, 0.53, 0.22, 0.36, "flat"], [0.86, 0.53, 0.22, 0.36, "flat"]]
			"zh_spirit_way": forms = [[0.5, 0.36, 0.59, 0.31, "pagoda"], [0.2, 0.65, 0.16, 0.26, "flat"], [0.8, 0.65, 0.16, 0.26, "flat"]]
	var roof: Color = palette["roof"]
	var trim: Color = palette["trim"]
	var dark: Color = palette["roof_dark"]
	for form in forms:
		var p := bounds.position + bounds.size * Vector2(float(form[0]), float(form[1]))
		var dimensions := bounds.size * Vector2(float(form[2]), float(form[3]))
		var box := Rect2(p - dimensions * 0.5, dimensions)
		var style: String = form[4]
		var fill: Color = Color("a45e4e") if style == "red" else Color("78736b") if style == "chimney" else game.player_color(owner_id).darkened(0.13) if style == "awning" else roof
		draw_rect(box, fill)
		draw_rect(box, trim, false, 2.0)
		if style in ["gable", "hip", "pagoda", "spire"]:
			draw_line(Vector2(box.position.x + 3, box.get_center().y), Vector2(box.end.x - 3, box.get_center().y), trim, 2.0)
		if style in ["spire", "pagoda"]: draw_rect(box.grow(-5), dark, false, 1.6)
		if style == "dome":
			draw_circle(p, minf(dimensions.x, dimensions.y) * 0.32, trim)
			draw_circle(p, minf(dimensions.x, dimensions.y) * 0.22, roof.lightened(0.28))
		if style == "clock":
			draw_circle(p, 9.0, trim)
			draw_circle(p, 6.0, dark)
		if style == "flat" or style == "red":
			for x in [box.position.x + 4, box.end.x - 4]:
				for y in [box.position.y + 4, box.end.y - 4]: draw_rect(Rect2(x - 2, y - 2, 4, 4), trim)

func _draw_iso_architecture(art_kind: String, nw: Vector2, ne: Vector2, se: Vector2, sw: Vector2, lift: Vector2, palette: Dictionary, canvas: Transform2D) -> void:
	if kind not in ["landmark", "wonder"] and art_kind in ["town_center", "mill", "lumber_camp"]:
		EconomyBuildingVisual.draw_iso(self, art_kind, nw, ne, se, sw, lift, palette, game.player_color(owner_id), game.civilizations[owner_id], canvas, game.camera.zoom.x)
		return
	if kind not in ["landmark", "wonder"] and art_kind in ["mining_camp", "blacksmith", "siege_workshop"]:
		IndustryBuildingVisual.draw_iso(self, art_kind, nw, ne, se, sw, lift, palette, game.player_color(owner_id), game.civilizations[owner_id], canvas, game.camera.zoom.x)
		return
	if art_kind == "farm":
		_draw_iso_farm(nw, ne, se, sw, lift)
		return
	if art_kind.ends_with("_wall") or art_kind.ends_with("_gate"):
		_draw_iso_fortification(nw, ne, se, sw, lift, palette)
		return
	if kind != "landmark" and art_kind in ["barracks", "archery_range", "stable"]:
		_draw_iso_military_structure(art_kind, nw, ne, sw, lift, palette, canvas)
		return
	if kind != "landmark" and art_kind == "university":
		_draw_iso_university(nw, ne, sw, lift, palette, canvas)
		return
	if kind != "landmark" and art_kind in ["market", "dock", "scout_camp"]:
		_draw_iso_open_structure(art_kind, nw, ne, se, sw, lift, palette, canvas)
		return
	var timber: Color = palette["timber"]
	var trim: Color = palette["trim"]
	var front_mid := (sw + se) * 0.5
	var door_half := (se - sw) * (0.11 if art_kind in ["house", "outpost"] else 0.16)
	var door_top := front_mid + lift * 0.72
	var door := PackedVector2Array([door_top - door_half, door_top + door_half, front_mid + door_half, front_mid - door_half])
	draw_colored_polygon(door, Color("322f2a"))
	draw_polyline(PackedVector2Array([door_top - door_half, door_top + door_half, front_mid + door_half]), trim, 1.5)
	draw_line(front_mid + lift * 0.3, front_mid + lift * 0.57, timber.lightened(0.24), 1.5)
	for portion in [0.08, 0.92]:
		var front_post := sw.lerp(se, portion)
		var side_post := ne.lerp(se, portion)
		draw_line(front_post, front_post + lift, timber, 2.5)
		draw_line(side_post, side_post + lift, timber.darkened(0.16), 2.0)
	for portion in [0.23, 0.77]:
		var window_base := sw.lerp(se, portion) + lift * 0.38
		var window_top := window_base + lift * 0.24
		var half_width := (se - sw) * 0.045
		draw_colored_polygon(PackedVector2Array([window_top - half_width, window_top + half_width, window_base + half_width, window_base - half_width]), Color("3c4e4c"))
		draw_line(window_base - half_width, window_base + half_width, trim, 1.6)
	# The faction color is an accent; the wall and roof retain their material colors.
	draw_line(sw.lerp(se, 0.08) + lift * 0.88, sw.lerp(se, 0.92) + lift * 0.88, game.player_color(owner_id), 3.0)
	# Landmark wings share a flat terrace; no generic pitched roof or tower
	# may intersect the bespoke geometry drawn above it.
	if kind in ["landmark", "wonder"]: return
	_draw_iso_roof(art_kind, nw, ne, se, sw, lift, palette, canvas)
	_draw_iso_building_feature(art_kind, nw, ne, se, sw, lift, palette, canvas)

func _draw_iso_open_structure(art_kind: String, nw: Vector2, ne: Vector2, se: Vector2, sw: Vector2, lift: Vector2, palette: Dictionary, canvas: Transform2D) -> void:
	if art_kind == "market":
		_draw_iso_market(nw, ne, sw, lift, palette, canvas)
		return
	var floor_lift := lift * 0.18
	var timber: Color = palette["timber"]
	var trim: Color = palette["trim"]
	var deck := Color("aa8558") if art_kind == "dock" else Color("a69a74")
	draw_colored_polygon(PackedVector2Array([nw + floor_lift, ne + floor_lift, se + floor_lift, sw + floor_lift]), deck)
	for portion in [0.16, 0.34, 0.52, 0.7, 0.88]:
		draw_line(nw.lerp(sw, portion) + floor_lift, ne.lerp(se, portion) + floor_lift, Color(timber, 0.32), 1.0)
	if art_kind == "dock":
		for corner in [nw, ne, sw, se]:
			draw_line(corner + floor_lift, corner + floor_lift - lift * 0.75, timber.darkened(0.18), 4.0)
		var mast := (nw + ne) * 0.5 + floor_lift
		var mast_top := mast + RtsIsoProjection.world_delta(canvas, Vector2(0, -19.0 * game.camera.zoom.x))
		draw_line(mast, mast_top, timber, 2.2)
		draw_line(mast_top, mast_top + (se - sw) * 0.38, timber, 2.0)
		draw_line(mast_top + (se - sw) * 0.38, mast_top + (se - sw) * 0.38 + lift * 0.3, Color("463e35"), 1.4)
		return
	if art_kind == "scout_camp":
		var base_left := nw.lerp(sw, 0.36).lerp(ne.lerp(se, 0.36), 0.25) + floor_lift
		var base_right := nw.lerp(sw, 0.75).lerp(ne.lerp(se, 0.75), 0.76) + floor_lift
		var peak := (base_left + base_right) * 0.5 + RtsIsoProjection.world_delta(canvas, Vector2(0, -15.0 * game.camera.zoom.x))
		draw_colored_polygon(PackedVector2Array([base_left, peak, base_right]), Color("a98458"))
		draw_line(base_left, peak, trim, 1.4)
		draw_line(peak, base_right, timber, 1.4)
		draw_circle(sw.lerp(se, 0.22) + floor_lift, 3.2, Color("dd9251"))
		return

func _draw_iso_market(nw: Vector2, ne: Vector2, sw: Vector2, lift: Vector2, palette: Dictionary, canvas: Transform2D) -> void:
	var floor_lift := lift * 0.18
	var up := RtsIsoProjection.world_delta(canvas, Vector2(0, -23.0 * game.camera.zoom.x))
	var rise := RtsIsoProjection.world_delta(canvas, Vector2(0, -7.0 * game.camera.zoom.x))
	var timber: Color = palette["timber"]
	var wall: Color = palette["wall"]
	var deck_a := _military_point(nw, ne, sw, 0.03, 0.03) + floor_lift
	var deck_b := _military_point(nw, ne, sw, 0.97, 0.03) + floor_lift
	var deck_c := _military_point(nw, ne, sw, 0.97, 0.97) + floor_lift
	var deck_d := _military_point(nw, ne, sw, 0.03, 0.97) + floor_lift
	draw_colored_polygon(PackedVector2Array([deck_a, deck_b, deck_c, deck_d]), Color("a99b7c"))
	var a := _military_point(nw, ne, sw, 0.06, 0.07) + floor_lift
	var b := _military_point(nw, ne, sw, 0.59, 0.07) + floor_lift
	var c := _military_point(nw, ne, sw, 0.59, 0.42) + floor_lift
	var d := _military_point(nw, ne, sw, 0.06, 0.42) + floor_lift
	draw_colored_polygon(PackedVector2Array([b + up, c + up, c, b]), wall.darkened(0.19))
	draw_colored_polygon(PackedVector2Array([d + up, c + up, c, d]), wall.lightened(0.04))
	var ridge_left := (a + d) * 0.5 + up + rise
	var ridge_right := (b + c) * 0.5 + up + rise
	var hall_roof: Color = Color("59656a") if game.civilizations[owner_id] == "English" else palette["roof"]
	draw_colored_polygon(PackedVector2Array([a + up, b + up, ridge_right, ridge_left]), hall_roof.darkened(0.2))
	draw_colored_polygon(PackedVector2Array([ridge_left, ridge_right, c + up, d + up]), hall_roof)
	draw_line(ridge_left, ridge_right, palette["trim"], 1.8)
	for u in [0.13, 0.32, 0.51]:
		var foot := _military_point(nw, ne, sw, u, 0.42) + floor_lift
		draw_line(foot, foot + up * 0.88, timber, 2.2)
		var window := foot + up * 0.58
		draw_line(window, window + up * 0.18, Color("343d3b"), 3.2)
		draw_line(window + up * 0.2, window + up * 0.23, palette["trim"], 3.6)
	draw_line(d + up * 0.47, c + up * 0.47, timber, 2.0)
	draw_line(d + up * 0.08, c + up * 0.08, timber, 2.2)
	for spot in [Vector2(0.86, 0.83), Vector2(0.24, 0.91)]:
		var goods := _military_point(nw, ne, sw, spot.x, spot.y) + floor_lift
		draw_circle(goods, 3.8, Color("7a5437"))
		draw_circle(goods + Vector2(0, -1), 2.5, Color("c69f64"))
	_draw_iso_market_stall(nw, ne, sw, floor_lift, canvas, palette, 0.07, 0.62, 0.36, 0.24)
	_draw_iso_market_stall(nw, ne, sw, floor_lift, canvas, palette, 0.69, 0.52, 0.25, 0.25)
	var cross := _military_point(nw, ne, sw, 0.87, 0.37) + floor_lift
	var cross_u := (ne - nw) * 0.075
	var cross_v := (sw - nw) * 0.075
	draw_colored_polygon(PackedVector2Array([cross - cross_u - cross_v, cross + cross_u - cross_v, cross + cross_u + cross_v, cross - cross_u + cross_v]), wall.darkened(0.2))
	var cross_top := cross + RtsIsoProjection.world_delta(canvas, Vector2(0, -19.0 * game.camera.zoom.x))
	draw_line(cross, cross_top, wall.lightened(0.1), 4.0)
	draw_circle(cross_top, 2.4, palette["trim"])

func _draw_iso_market_stall(nw: Vector2, ne: Vector2, sw: Vector2, floor_lift: Vector2, canvas: Transform2D, palette: Dictionary, u: float, v: float, width: float, depth: float) -> void:
	var a := _military_point(nw, ne, sw, u, v) + floor_lift
	var b := _military_point(nw, ne, sw, u + width, v) + floor_lift
	var c := _military_point(nw, ne, sw, u + width, v + depth) + floor_lift
	var d := _military_point(nw, ne, sw, u, v + depth) + floor_lift
	var high := RtsIsoProjection.world_delta(canvas, Vector2(0, -14.0 * game.camera.zoom.x))
	var low := high * 0.76
	for corner in [a, b]:
		draw_line(corner, corner + high, palette["timber"], 2.0)
	for stripe in 5:
		var left := float(stripe) / 5.0
		var right := float(stripe + 1) / 5.0
		draw_colored_polygon(PackedVector2Array([a.lerp(b, left) + high, a.lerp(b, right) + high, d.lerp(c, right) + low, d.lerp(c, left) + low]), game.player_color(owner_id) if stripe % 2 == 0 else palette["trim"])
	draw_line(d + low, c + low, palette["timber"], 1.4)
	for corner in [d, c]:
		draw_line(corner, corner + low, palette["timber"], 2.0)

func _draw_iso_university(nw: Vector2, ne: Vector2, sw: Vector2, lift: Vector2, palette: Dictionary, canvas: Transform2D) -> void:
	var floor_lift := lift * 0.18
	var college := _university_palette(palette)
	var deck_a := _military_point(nw, ne, sw, 0.04, 0.04) + floor_lift
	var deck_b := _military_point(nw, ne, sw, 0.96, 0.04) + floor_lift
	var deck_c := _military_point(nw, ne, sw, 0.96, 0.95) + floor_lift
	var deck_d := _military_point(nw, ne, sw, 0.04, 0.95) + floor_lift
	draw_colored_polygon(PackedVector2Array([deck_a, deck_b, deck_c, deck_d]), Color("a49b85"))
	var court_a := _military_point(nw, ne, sw, 0.3, 0.37) + floor_lift
	var court_b := _military_point(nw, ne, sw, 0.7, 0.37) + floor_lift
	var court_c := _military_point(nw, ne, sw, 0.7, 0.91) + floor_lift
	var court_d := _military_point(nw, ne, sw, 0.3, 0.91) + floor_lift
	draw_colored_polygon(PackedVector2Array([court_a, court_b, court_c, court_d]), Color("b9ae94"))
	_draw_iso_military_block(nw, ne, sw, floor_lift, canvas, college, 0.07, 0.07, 0.86, 0.3, 27.0, "gable_u")
	_draw_iso_military_block(nw, ne, sw, floor_lift, canvas, college, 0.07, 0.32, 0.23, 0.51, 26.0, "gable_v")
	_draw_iso_military_block(nw, ne, sw, floor_lift, canvas, college, 0.7, 0.32, 0.23, 0.51, 26.0, "gable_v")
	var window_up := RtsIsoProjection.world_delta(canvas, Vector2(0, -26.0 * game.camera.zoom.x))
	for u in [0.3, 0.7, 0.93]:
		var wall_start := _military_point(nw, ne, sw, u, 0.36) + floor_lift
		var wall_end := _military_point(nw, ne, sw, u, 0.8) + floor_lift
		draw_line(wall_start + window_up * 0.47, wall_end + window_up * 0.47, college["trim"], 1.5)
		for v in [0.46, 0.65]:
			var foot := _military_point(nw, ne, sw, u, v) + floor_lift
			var bottom := foot + window_up * 0.48
			var top := foot + window_up * 0.77
			draw_line(bottom, top, college["trim"], 5.2)
			draw_line(bottom + window_up * 0.04, top - window_up * 0.04, Color("303b40"), 3.0)
			draw_line((bottom + top) * 0.5 + Vector2(-2, 0), (bottom + top) * 0.5 + Vector2(2, 0), college["trim"], 1.0)
	for v in [0.33, 0.82]:
		var pier := _military_point(nw, ne, sw, 0.93, v) + floor_lift
		draw_line(pier, pier + window_up * 0.92, college["trim"], 1.4)
	for u in [0.17, 0.83]:
		var front := _military_point(nw, ne, sw, u, 0.83) + floor_lift
		var gable := front + window_up + RtsIsoProjection.world_delta(canvas, Vector2(0, -8.0 * game.camera.zoom.x))
		draw_colored_polygon(PackedVector2Array([front + window_up - (ne - nw) * 0.08, gable, front + window_up + (ne - nw) * 0.08]), college["wall"].lightened(0.09))
		draw_line(front + window_up - (ne - nw) * 0.08, gable, college["trim"], 1.4)
		draw_line(gable, front + window_up + (ne - nw) * 0.08, college["trim"], 1.4)
	_draw_iso_university_tower(nw, ne, sw, floor_lift, canvas, college)
	var monument := _military_point(nw, ne, sw, 0.5, 0.68) + floor_lift
	var monument_top := monument + RtsIsoProjection.world_delta(canvas, Vector2(0, -13.0 * game.camera.zoom.x))
	draw_circle(monument, 5.2, college["wall"].darkened(0.28))
	draw_line(monument, monument_top, college["trim"], 3.2)
	draw_circle(monument_top, 2.3, college["trim"])
	for u in [0.34, 0.66]:
		var hedge_start := _military_point(nw, ne, sw, u, 0.78) + floor_lift
		var hedge_end := _military_point(nw, ne, sw, u, 0.92) + floor_lift
		draw_line(hedge_start, hedge_end, Color("627355"), 3.2)

func _draw_iso_university_tower(nw: Vector2, ne: Vector2, sw: Vector2, floor_lift: Vector2, canvas: Transform2D, palette: Dictionary) -> void:
	var a := _military_point(nw, ne, sw, 0.41, 0.16) + floor_lift
	var b := _military_point(nw, ne, sw, 0.59, 0.16) + floor_lift
	var c := _military_point(nw, ne, sw, 0.59, 0.38) + floor_lift
	var d := _military_point(nw, ne, sw, 0.41, 0.38) + floor_lift
	var up := RtsIsoProjection.world_delta(canvas, Vector2(0, -44.0 * game.camera.zoom.x))
	var rise := RtsIsoProjection.world_delta(canvas, Vector2(0, -7.0 * game.camera.zoom.x))
	draw_colored_polygon(PackedVector2Array([b + up, c + up, c, b]), palette["wall"].darkened(0.18))
	draw_colored_polygon(PackedVector2Array([d + up, c + up, c, d]), palette["wall"])
	var peak := (a + b + c + d) * 0.25 + up + rise
	draw_colored_polygon(PackedVector2Array([a + up, b + up, peak, d + up]), palette["roof_dark"])
	draw_colored_polygon(PackedVector2Array([b + up, c + up, peak]), palette["roof"])
	draw_colored_polygon(PackedVector2Array([d + up, c + up, peak]), palette["roof"])
	var doorway := (d + c) * 0.5
	draw_line(doorway, doorway + up * 0.46, Color("303333"), 5.0)
	draw_circle(doorway + up * 0.46, 2.5, Color("303333"))
	draw_line(d + up * 0.75, c + up * 0.75, palette["trim"], 1.6)
	draw_line(doorway + up * 0.65, doorway + up * 0.87, Color("37403e"), 2.7)

func _military_point(nw: Vector2, ne: Vector2, sw: Vector2, u: float, v: float) -> Vector2:
	return nw + (ne - nw) * u + (sw - nw) * v

func _draw_iso_upright_disc(center: Vector2, radius: float, color: Color, canvas: Transform2D) -> void:
	var screen_radius: float = radius * game.camera.zoom.x
	var horizontal := RtsIsoProjection.world_delta(canvas, Vector2(screen_radius, 0))
	var vertical := RtsIsoProjection.world_delta(canvas, Vector2(0, screen_radius))
	var outline := PackedVector2Array()
	for step in 24:
		var angle := TAU * float(step) / 24.0
		outline.append(center + horizontal * cos(angle) + vertical * sin(angle))
	draw_colored_polygon(outline, color)

func _draw_iso_military_block(nw: Vector2, ne: Vector2, sw: Vector2, floor_lift: Vector2, canvas: Transform2D, palette: Dictionary, u: float, v: float, width: float, depth: float, height: float, style: String) -> void:
	var a := _military_point(nw, ne, sw, u, v) + floor_lift
	var b := _military_point(nw, ne, sw, u + width, v) + floor_lift
	var c := _military_point(nw, ne, sw, u + width, v + depth) + floor_lift
	var d := _military_point(nw, ne, sw, u, v + depth) + floor_lift
	var up := RtsIsoProjection.world_delta(canvas, Vector2(0, -height * game.camera.zoom.x))
	var rise := RtsIsoProjection.world_delta(canvas, Vector2(0, -8.0 * game.camera.zoom.x))
	var wall: Color = palette["wall"]
	var roof: Color = palette["roof"]
	var dark: Color = palette["roof_dark"]
	var trim: Color = palette["trim"]
	draw_colored_polygon(PackedVector2Array([a + up, b + up, b, a]), wall.darkened(0.1))
	draw_colored_polygon(PackedVector2Array([a + up, d + up, d, a]), wall.darkened(0.12))
	draw_colored_polygon(PackedVector2Array([b + up, c + up, c, b]), wall.darkened(0.2))
	draw_colored_polygon(PackedVector2Array([d + up, c + up, c, d]), wall)
	draw_colored_polygon(PackedVector2Array([a + up, b + up, c + up, d + up]), dark)
	draw_line(d + up, c + up, trim.darkened(0.18), 2.0)
	if style == "tower":
		match game.civilizations[owner_id]:
			"English":
				draw_colored_polygon(PackedVector2Array([a + up, b + up, c + up, d + up]), dark)
				for p in [a + up, b + up, c + up, d + up]: draw_line(p, p + up * 0.16, trim, 3.5)
			"Chinese":
				var peak := (a + c) * 0.5 + up + rise * 1.3
				draw_colored_polygon(PackedVector2Array([a + up, b + up, peak]), roof.lightened(0.12))
				draw_colored_polygon(PackedVector2Array([b + up, c + up, peak]), roof)
				draw_colored_polygon(PackedVector2Array([c + up, d + up, peak]), dark)
				draw_line(d + up, c + up, trim, 2.6)
				var upper := (a + c) * 0.5 + up + rise * 0.85
				draw_line(upper - (b - a) * 0.3, upper + (b - a) * 0.3, trim, 2.0)
			_:
				var peak := (a + c) * 0.5 + up + rise * 1.8
				draw_colored_polygon(PackedVector2Array([a + up, b + up, peak]), roof.lightened(0.1))
				draw_colored_polygon(PackedVector2Array([b + up, c + up, peak]), roof)
				draw_colored_polygon(PackedVector2Array([c + up, d + up, peak]), dark)
		var slit := (d + c) * 0.5 + up * 0.6
		draw_line(slit, slit + up * 0.16, Color("344343"), 3.0)
	else:
		if style == "gable_v":
			var ridge_back := (a + b) * 0.5 + up + rise
			var ridge_front := (d + c) * 0.5 + up + rise
			draw_colored_polygon(PackedVector2Array([a + up, b + up, ridge_back]), wall.darkened(0.1))
			draw_colored_polygon(PackedVector2Array([d + up, c + up, ridge_front]), wall)
			draw_colored_polygon(PackedVector2Array([a + up, ridge_back, ridge_front, d + up]), roof.lightened(0.13))
			draw_colored_polygon(PackedVector2Array([ridge_back, b + up, c + up, ridge_front]), roof)
			draw_line(ridge_back, ridge_front, trim, 2.0)
		else:
			var ridge_left := (a + d) * 0.5 + up + rise
			var ridge_right := (b + c) * 0.5 + up + rise
			draw_colored_polygon(PackedVector2Array([a + up, d + up, ridge_left]), wall.darkened(0.12))
			draw_colored_polygon(PackedVector2Array([b + up, c + up, ridge_right]), wall.darkened(0.2))
			draw_colored_polygon(PackedVector2Array([a + up, b + up, ridge_right, ridge_left]), roof.lightened(0.13))
			draw_colored_polygon(PackedVector2Array([ridge_left, ridge_right, c + up, d + up]), roof)
			draw_line(ridge_left, ridge_right, trim, 2.0)
		if game.civilizations[owner_id] == "Chinese":
			for corner in [a + up, b + up, c + up, d + up]: draw_circle(corner + rise * 0.2, 2.2, trim)
		for portion in [0.22, 0.51, 0.8]:
			var post := d.lerp(c, portion)
			draw_line(post, post + up * 0.82, palette["timber"], 1.8)
		var doorway := (d + c) * 0.5
		draw_line(doorway, doorway + up * 0.56, Color("39433d"), 5.0)

func _draw_iso_military_structure(art_kind: String, nw: Vector2, ne: Vector2, sw: Vector2, lift: Vector2, palette: Dictionary, canvas: Transform2D) -> void:
	var floor_lift := lift * 0.18
	var timber: Color = palette["timber"]
	var trim: Color = palette["trim"]
	var deck := PackedVector2Array([nw + floor_lift, ne + floor_lift, ne + sw - nw + floor_lift, sw + floor_lift])
	draw_colored_polygon(deck, Color("a69a74"))
	for portion in [0.17, 0.37, 0.57, 0.77]:
		draw_line(_military_point(nw, ne, sw, 0.05, portion) + floor_lift, _military_point(nw, ne, sw, 0.95, portion) + floor_lift, Color(timber, 0.32), 1.0)
	match art_kind:
		"barracks":
			_draw_iso_military_block(nw, ne, sw, floor_lift, canvas, palette, 0.07, 0.07, 0.86, 0.28, 21, "gable_u")
			_draw_iso_military_block(nw, ne, sw, floor_lift, canvas, palette, 0.07, 0.33, 0.22, 0.39, 17, "gable_v")
			_draw_iso_military_block(nw, ne, sw, floor_lift, canvas, palette, 0.71, 0.33, 0.22, 0.39, 17, "gable_v")
			for u in [0.42, 0.58]:
				var dummy := _military_point(nw, ne, sw, u, 0.58) + floor_lift
				var head := dummy + lift * 0.46
				draw_line(dummy, head, timber, 2.5)
				draw_line(dummy + lift * 0.27 - (ne - nw) * 0.05, dummy + lift * 0.27 + (ne - nw) * 0.05, timber, 2.1)
				draw_circle(head, 3.3, palette["wall"])
			for u in [0.14, 0.72]: _draw_iso_military_block(nw, ne, sw, floor_lift, canvas, palette, u, 0.75, 0.15, 0.17, 32, "tower")
		"archery_range":
			_draw_iso_military_block(nw, ne, sw, floor_lift, canvas, palette, 0.06, 0.06, 0.7, 0.28, 21, "gable_u")
			_draw_iso_military_block(nw, ne, sw, floor_lift, canvas, palette, 0.06, 0.33, 0.2, 0.42, 16, "gable_v")
			_draw_iso_military_block(nw, ne, sw, floor_lift, canvas, palette, 0.76, 0.09, 0.18, 0.24, 38, "tower")
			for u in [0.36, 0.61, 0.86]:
				var foot := _military_point(nw, ne, sw, u, 0.57) + floor_lift
				var board := foot + RtsIsoProjection.world_delta(canvas, Vector2(0, -12.0 * game.camera.zoom.x))
				var brace := RtsIsoProjection.world_delta(canvas, Vector2(5.0 * game.camera.zoom.x, -2.0 * game.camera.zoom.x))
				draw_line(foot - brace * 0.75, board, timber, 2.0)
				draw_line(foot + brace * 0.75, board, timber, 2.0)
				_draw_iso_upright_disc(board, 6.0, timber.darkened(0.18), canvas)
				_draw_iso_upright_disc(board, 5.0, trim, canvas)
				_draw_iso_upright_disc(board, 3.3, Color("ad654a"), canvas)
				_draw_iso_upright_disc(board, 1.5, trim, canvas)
				var lane := _military_point(nw, ne, sw, u, 0.87) + floor_lift
				draw_line(lane, foot, Color("d4bd86"), 1.5)
		"stable":
			_draw_iso_military_block(nw, ne, sw, floor_lift, canvas, palette, 0.06, 0.06, 0.88, 0.3, 22, "gable_u")
			_draw_iso_military_block(nw, ne, sw, floor_lift, canvas, palette, 0.06, 0.34, 0.24, 0.36, 16, "gable_v")
			for u in [0.46, 0.69]:
				var stall := _military_point(nw, ne, sw, u, 0.39) + floor_lift
				draw_line(stall, stall + lift * 0.38, timber.darkened(0.14), 2.0)
			var horse := _military_point(nw, ne, sw, 0.55, 0.64) + floor_lift
			var horse_up := RtsIsoProjection.world_delta(canvas, Vector2(0, -10.0 * game.camera.zoom.x))
			var horse_right := RtsIsoProjection.world_delta(canvas, Vector2(8.0 * game.camera.zoom.x, 0))
			var horse_body := horse + horse_up
			draw_colored_polygon(PackedVector2Array([horse_body - horse_right - horse_up * 0.35, horse_body + horse_right - horse_up * 0.35, horse_body + horse_right + horse_up * 0.35, horse_body - horse_right + horse_up * 0.35]), Color("765039"))
			for side in [-1.0, 1.0]: draw_line(horse_body + horse_right * side - horse_up * 0.3, horse + horse_right * side * 0.82, Color("66432f"), 2.0)
			draw_line(horse_body + horse_right * 0.8, horse_body + horse_right * 1.35 + horse_up * 0.45, Color("765039"), 3.4)
			draw_circle(horse_body + horse_right * 1.48 + horse_up * 0.45, 3.8, Color("765039"))
			for u in [0.34, 0.54, 0.74, 0.92]:
				var post := _military_point(nw, ne, sw, u, 0.9) + floor_lift
				draw_line(post, post + lift * 0.28, timber, 2.5)
			var fence_left := _military_point(nw, ne, sw, 0.34, 0.9) + floor_lift + lift * 0.24
			var fence_right := _military_point(nw, ne, sw, 0.92, 0.9) + floor_lift + lift * 0.24
			draw_line(fence_left, fence_right, timber, 2.8)
			var fence_back := _military_point(nw, ne, sw, 0.92, 0.41) + floor_lift + lift * 0.24
			draw_line(fence_right, fence_back, timber, 2.8)

func _draw_iso_roof(art_kind: String, nw: Vector2, ne: Vector2, se: Vector2, sw: Vector2, lift: Vector2, palette: Dictionary, canvas: Transform2D) -> void:
	var center := (nw + ne + se + sw) * 0.25
	if art_kind in ["keep", "outpost"]:
		var parapet: Color = palette["wall"]
		var masonry: Color = palette["trim"]
		draw_colored_polygon(PackedVector2Array([nw + lift, ne + lift, se + lift, sw + lift]), parapet.darkened(0.32))
		for edge in [[nw, ne], [ne, se], [se, sw], [sw, nw]]:
			var start: Vector2 = edge[0] + lift
			var finish: Vector2 = edge[1] + lift
			draw_line(start, finish, masonry, 3.2)
		_draw_iso_battlements([nw + lift, ne + lift, se + lift, sw + lift], lift * 0.13, masonry, 4.5)
		return
	var overhang := 1.1 if game.civilizations[owner_id] == "Chinese" else 1.06
	var a := center + (nw - center) * overhang + lift
	var b := center + (ne - center) * overhang + lift
	var c := center + (se - center) * overhang + lift
	var d := center + (sw - center) * overhang + lift
	var roof_height := 23.0 if art_kind == "monastery" else 15.0 if art_kind == "university" else 9.0
	var rise := RtsIsoProjection.world_delta(canvas, Vector2(0, -roof_height * game.camera.zoom.x))
	var ridge_back := (a + b) * 0.5 + rise
	var ridge_front := (d + c) * 0.5 + rise
	var roof: Color = palette["roof"]
	var dark: Color = palette["roof_dark"]
	if game.civilizations[owner_id] == "Chinese":
		var upturn := RtsIsoProjection.world_delta(canvas, Vector2(0, -3.5 * game.camera.zoom.x))
		a += upturn
		b += upturn
		c += upturn
		d += upturn
	draw_colored_polygon(PackedVector2Array([a, b, c, d]), dark)
	draw_colored_polygon(PackedVector2Array([a, b, ridge_back]), palette["wall"].darkened(0.1))
	draw_colored_polygon(PackedVector2Array([d, c, ridge_front]), palette["wall"])
	draw_colored_polygon(PackedVector2Array([a, ridge_back, ridge_front, d]), roof.lightened(0.09))
	draw_colored_polygon(PackedVector2Array([ridge_back, b, c, ridge_front]), roof)
	draw_polyline(PackedVector2Array([a, ridge_back, b]), dark, 2.0)
	draw_polyline(PackedVector2Array([d, ridge_front, c]), dark, 2.0)
	draw_line(ridge_back, ridge_front, palette["trim"], 2.0)
	for portion in [0.28, 0.58, 0.84]:
		draw_line(a.lerp(d, portion), ridge_back.lerp(ridge_front, portion), Color(dark, 0.45), 1.0)
		draw_line(ridge_back.lerp(ridge_front, portion), b.lerp(c, portion), Color(dark, 0.37), 1.0)
	if game.civilizations[owner_id] == "Chinese":
		for corner in [a, b, c, d]:
			draw_circle(corner, 1.8, palette["trim"])

func _draw_iso_building_feature(art_kind: String, nw: Vector2, ne: Vector2, se: Vector2, sw: Vector2, lift: Vector2, palette: Dictionary, canvas: Transform2D) -> void:
	var roof_middle := (nw + ne + se + sw) * 0.25 + lift
	var timber: Color = palette["timber"]
	var trim: Color = palette["trim"]
	match art_kind:
		"keep", "university", "monastery":
			_draw_iso_tower(art_kind, nw, ne, se, sw, lift, palette, canvas)
		"house":
			var chimney := roof_middle + (nw - roof_middle) * 0.28
			var chimney_top := chimney + RtsIsoProjection.world_delta(canvas, Vector2(0, -10.0 * game.camera.zoom.x))
			draw_line(chimney, chimney_top, timber, 7.0)
			draw_line(chimney_top + Vector2(-4, 0), chimney_top + Vector2(4, 0), trim, 3.0)
	if art_kind == "outpost":
		var mast := roof_middle + RtsIsoProjection.world_delta(canvas, Vector2(0, -16.0 * game.camera.zoom.x))
		draw_line(roof_middle, mast, timber, 2.0)
		draw_colored_polygon(PackedVector2Array([mast, mast + Vector2(9, 3), mast + Vector2(0, 6)]), game.player_color(owner_id))

func _draw_iso_tower(art_kind: String, nw: Vector2, ne: Vector2, se: Vector2, sw: Vector2, lift: Vector2, palette: Dictionary, canvas: Transform2D) -> void:
	var center := (nw + ne + se + sw) * 0.25 + lift
	var tower_scale := 0.4 if art_kind in ["palace", "wonder"] else 0.34 if art_kind in ["keep", "town_center"] else 0.26
	var a := center + (nw - center + lift) * tower_scale
	var b := center + (ne - center + lift) * tower_scale
	var c := center + (se - center + lift) * tower_scale
	var d := center + (sw - center + lift) * tower_scale
	var rise := RtsIsoProjection.world_delta(canvas, Vector2(0, -(26.0 if art_kind in ["palace", "wonder", "monastery"] else 19.0) * game.camera.zoom.x))
	var wall: Color = palette["wall"]
	draw_colored_polygon(PackedVector2Array([b + rise, c + rise, c, b]), wall.darkened(0.25))
	draw_colored_polygon(PackedVector2Array([d + rise, c + rise, c, d]), wall)
	draw_colored_polygon(PackedVector2Array([a + rise, b + rise, c + rise, d + rise]), palette["roof_dark"])
	draw_polyline(PackedVector2Array([a + rise, b + rise, c + rise, d + rise, a + rise]), palette["trim"], 1.6)
	if art_kind == "keep":
		_draw_iso_battlements([a + rise, b + rise, c + rise, d + rise], rise * 0.2, palette["trim"], 3.0)
	elif art_kind in ["palace", "wonder"]:
		var upper_center := (a + b + c + d) * 0.25 + rise
		var upper_a := upper_center + (a + rise - upper_center) * 0.64
		var upper_b := upper_center + (b + rise - upper_center) * 0.64
		var upper_c := upper_center + (c + rise - upper_center) * 0.64
		var upper_d := upper_center + (d + rise - upper_center) * 0.64
		var upper_rise := RtsIsoProjection.world_delta(canvas, Vector2(0, -(17.0 if art_kind == "wonder" else 12.0) * game.camera.zoom.x))
		draw_colored_polygon(PackedVector2Array([upper_b + upper_rise, upper_c + upper_rise, upper_c, upper_b]), wall.darkened(0.25))
		draw_colored_polygon(PackedVector2Array([upper_d + upper_rise, upper_c + upper_rise, upper_c, upper_d]), wall)
		var cap_rise := RtsIsoProjection.world_delta(canvas, Vector2(0, -8.0 * game.camera.zoom.x))
		var peak := (upper_a + upper_b + upper_c + upper_d) * 0.25 + upper_rise + cap_rise
		draw_colored_polygon(PackedVector2Array([upper_a + upper_rise, peak, upper_d + upper_rise]), palette["roof"])
		draw_colored_polygon(PackedVector2Array([upper_b + upper_rise, upper_c + upper_rise, peak]), palette["roof_dark"])
		draw_line(upper_d + upper_rise, upper_c + upper_rise, palette["trim"], 2.0)
		_draw_iso_landmark_crown(peak, palette, canvas)
	elif art_kind == "monastery":
		var bell_top := (a + b + c + d) * 0.25 + rise
		draw_circle(bell_top, 3.0, palette["trim"])
		draw_line(bell_top, bell_top + RtsIsoProjection.world_delta(canvas, Vector2(0, -13.0 * game.camera.zoom.x)), palette["trim"], 2.0)
		draw_line(bell_top + Vector2(-5, -7), bell_top + Vector2(5, -7), palette["trim"], 2.0)
	else:
		_draw_iso_landmark_crown((a + b + c + d) * 0.25 + rise, palette, canvas)

func _draw_iso_landmark_crown(base: Vector2, palette: Dictionary, canvas: Transform2D) -> void:
	var mast_height := 28.0 if kind == "wonder" else 13.0
	var top := base + RtsIsoProjection.world_delta(canvas, Vector2(0, -mast_height * game.camera.zoom.x))
	draw_line(base, top, palette["timber"], 1.7)
	if kind == "wonder":
		draw_circle(top, 4.0, palette["trim"])
		draw_line(top + Vector2(-6, 5), top + Vector2(6, 5), palette["trim"], 2.0)
	elif landmark_id == "zh_clocktower":
		draw_circle(top, 5.0, palette["trim"])
		draw_circle(top, 2.2, palette["roof_dark"])
	elif landmark_id in ["eng_kings_mill", "eng_abbey", "zh_spirit_way"]:
		draw_line(top + Vector2(-5, 4), top + Vector2(5, 4), palette["trim"], 2.2)
	else:
		var accent: Color = Color("c99657") if kind == "landmark" else game.player_color(owner_id)
		draw_colored_polygon(PackedVector2Array([top, top + Vector2(10, 3), top + Vector2(0, 7)]), accent)

func _landmark_geometry():
	var key := str([kind, landmark_id, size(), game.civilizations[owner_id], game.player_color(owner_id)])
	if landmark_geometry == null or landmark_geometry_key != key:
		landmark_geometry = LandmarkVisual.new()
		landmark_geometry.dimensions = size()
		landmark_geometry.palette = _architecture_palette()
		landmark_geometry.populate(kind, landmark_id, game.player_color(owner_id))
		landmark_geometry.prepare()
		landmark_geometry_key = key
	return landmark_geometry

func _draw_iso_landmark_architecture(lift: Vector2, canvas: Transform2D) -> void:
	for polygon in _landmark_geometry().projected_faces(canvas, game.camera.zoom.x, lift):
		draw_colored_polygon(polygon["points"], polygon["color"])

func _draw_iso_battlements(corners: Array, rise: Vector2, color: Color, width: float) -> void:
	var teeth: Array[Vector2] = []
	for edge in corners.size():
		var start: Vector2 = corners[edge]
		var finish: Vector2 = corners[(edge + 1) % corners.size()]
		var count := maxi(2, ceili(start.distance_to(finish) / 9.0))
		# Half-open intervals include every corner exactly once.
		for i in count: teeth.append(start.lerp(finish, float(i) / count))
	var canvas := get_viewport().get_canvas_transform()
	teeth.sort_custom(func(a: Vector2, b: Vector2) -> bool: return canvas.basis_xform(a).y < canvas.basis_xform(b).y)
	var center := Vector2.ZERO
	for corner in corners: center += corner
	center /= corners.size()
	for tooth in teeth:
		draw_line(tooth, tooth + rise, LandmarkVisual.battlement_color(tooth - center, color), width)

func _draw_iso_fortification(nw: Vector2, ne: Vector2, se: Vector2, sw: Vector2, lift: Vector2, palette: Dictionary) -> void:
	var material: Color = palette["trim"] if kind.begins_with("stone") else palette["timber"]
	_draw_iso_battlements([nw + lift, ne + lift, se + lift, sw + lift], lift * 0.25, material, 4.0)
	if kind.ends_with("_gate"):
		var mid := (sw + se) * 0.5
		var half_width := (se - sw) * 0.19
		draw_colored_polygon(PackedVector2Array([mid - half_width + lift * 0.86, mid + half_width + lift * 0.86, mid + half_width, mid - half_width]), Color("2c2a26"))
		draw_line(mid - half_width + lift * 0.84, mid + half_width + lift * 0.84, material, 2.0)

func _draw_iso_farm(nw: Vector2, ne: Vector2, se: Vector2, sw: Vector2, lift: Vector2) -> void:
	for portion in [0.1, 0.3, 0.5, 0.7, 0.9]:
		var start := nw.lerp(sw, portion) + lift
		var finish := ne.lerp(se, portion) + lift
		draw_line(start, finish, Color("6f5838"), 3.0)
		draw_line(start + (se - ne) * 0.045, finish + (se - ne) * 0.045, Color("a9814e"), 2.2)
		if not is_complete() or farm_crop_fraction() < portion: continue
		for across in [0.2, 0.4, 0.6, 0.8]:
			var crop := start.lerp(finish, across)
			draw_line(crop, crop + Vector2(0, -7), Color("91ae5a"), 2.0)
			draw_circle(crop + Vector2(2, -7), 2.0, Color("d9c875"))

func _draw_building_icon(center: Vector2, icon_size: float) -> void:
	if game.get("show_building_icons") == false: return
	var badge := Rect2(center - Vector2.ONE * icon_size * 0.5, Vector2.ONE * icon_size)
	if building_icon != null:
		draw_texture_rect(building_icon, badge, false, Color(1, 1, 1, 0.55) if not is_complete() else Color.WHITE)
	else:
		draw_rect(badge, Color("24313a"))
		# Wonders have no command icon asset yet; a small column marks them on the map.
		draw_colored_polygon(PackedVector2Array([center + Vector2(-9, -5), center + Vector2(0, -11), center + Vector2(9, -5)]), Color("e8d5a1"))
		for offset in [-6.0, 0.0, 6.0]:
			draw_rect(Rect2(center + Vector2(offset - 1.5, -4), Vector2(3, 11)), Color("e8d5a1"))
		draw_rect(Rect2(center + Vector2(-10, 7), Vector2(20, 3)), Color("e8d5a1"))
	draw_rect(badge, Color("e4c785"), false, 1.0)

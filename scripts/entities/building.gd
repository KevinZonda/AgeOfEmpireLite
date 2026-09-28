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
	var side := icon_size()
	if not game.view_mode_25d:
		var center := Vector2(0, -size().y * 0.5 - side * 0.5 - 8.0)
		return Rect2(center - Vector2.ONE * side * 0.5, Vector2.ONE * side).has_point(world_point - position)
	var construction_ratio := 1.0 - build_remaining / maxf(build_total, 0.1)
	var height := isometric_height() * (0.25 + 0.75 * construction_ratio)
	var terrain_lift := RtsIsoProjection.world_delta(canvas, Vector2(0, -foundation_height() * game.camera.zoom.x))
	var screen_point := canvas.basis_xform(world_point - position - terrain_lift)
	var center := Vector2(0, -height * game.camera.zoom.x - side * 0.5 + 1.0)
	return Rect2(center - Vector2.ONE * side * 0.5, Vector2.ONE * side).has_point(screen_point)

func isometric_height() -> float:
	if kind == "farm": return 0.0
	if kind.ends_with("_wall") or kind.ends_with("_gate"): return 11.0
	if kind == "outpost": return 43.0
	if kind in ["town_center", "landmark", "keep", "wonder"]: return 42.0
	if kind == "monastery": return 34.0
	if kind in ["mill", "lumber_camp", "mining_camp", "scout_camp", "dock"]: return 17.0
	if kind == "house": return 23.0
	return 26.0

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
	var lift := terrain_lift + RtsIsoProjection.world_delta(canvas, Vector2(0, -isometric_height() * game.camera.zoom.x))
	var local_point := world_point - position
	if not kind in ["farm", "palisade_wall", "stone_wall", "palisade_gate", "stone_gate"]:
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
	return false

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
	_sync_remaining()
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
	else:
		game.complete_age(owner_id, job["target_age"])
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
	if construction_ratio >= 0.65: _draw_topdown_architecture(bounds, palette)
	var side := icon_size()
	_draw_building_icon(Vector2(0, -size().y * 0.5 - side * 0.5 - 8.0), side)
	var font := ThemeDB.fallback_font
	if font != null:
		draw_string(font, Vector2(-size().x * 0.5, size().y * 0.5 + 15), display_label(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
	var bar_y := -size().y * 0.5 - side - 18.0
	draw_rect(Rect2(-size().x * 0.5, bar_y, size().x, 5), Color("432e2b"))
	draw_rect(Rect2(-size().x * 0.5, bar_y, size().x * clampf(hp / max_hp, 0.0, 1.0), 5), Color("7fd47a"))
	if not is_complete():
		draw_arc(Vector2.ZERO, 14, 0, TAU * (1.0 - build_remaining / maxf(build_total, 0.1)), 20, Color.WHITE, 3)
	if not production_queue.is_empty():
		draw_circle(Vector2(size().x * 0.5 - 4, -size().y * 0.5 + 4), 8, Color("e5c45d"))

func _draw_isometric() -> void:
	var bounds := Rect2(-size() * 0.5, size())
	var palette := _architecture_palette()
	var color: Color = palette["wall"]
	var construction_ratio := 1.0 - build_remaining / maxf(build_total, 0.1)
	if not is_complete(): color = color.darkened(0.32)
	var nw := bounds.position
	var ne := Vector2(bounds.end.x, bounds.position.y)
	var se := bounds.end
	var sw := Vector2(bounds.position.x, bounds.end.y)
	var height := isometric_height() * (0.25 + 0.75 * construction_ratio)
	var canvas := get_viewport().get_canvas_transform()
	var lift := RtsIsoProjection.world_delta(canvas, Vector2(0, -height * game.camera.zoom.x))
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
		draw_colored_polygon(PackedVector2Array([ne + lift, se + lift, se, ne]), color.darkened(0.26))
		draw_colored_polygon(PackedVector2Array([sw + lift, se + lift, se, sw]), color)
		draw_polyline(PackedVector2Array([ne + lift, se + lift, se, ne, ne + lift]), Color("1c2829"), 2.0)
		draw_polyline(PackedVector2Array([sw + lift, se + lift, se, sw, sw + lift]), Color("1c2829"), 2.0)
	var roof_color: Color = palette["roof"]
	if kind == "farm": roof_color = Color("9d874e")
	if kind.ends_with("_wall") or kind.ends_with("_gate"): roof_color = color.lightened(0.08)
	if construction_ratio >= 0.65:
		draw_colored_polygon(PackedVector2Array([nw + lift, ne + lift, se + lift, sw + lift]), roof_color)
		draw_polyline(PackedVector2Array([nw + lift, ne + lift, se + lift, sw + lift, nw + lift]), Color("1f2929"), 2.0)
		_draw_iso_architecture(nw, ne, se, sw, lift, palette, canvas)
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
	_draw_building_icon(Vector2(0, -height * game.camera.zoom.x - side * 0.5 + 1.0), side)
	var font := ThemeDB.fallback_font
	if font != null:
		var label := display_label()
		var label_width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_string(font, Vector2(-label_width * 0.5, size().y * 0.28 + 22.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
	var bar_width := minf(72.0, size().x * 0.8)
	var bar_y: float = minf(-height * game.camera.zoom.x - size().y * 0.25 - 16.0, -height * game.camera.zoom.x - side - 8.0)
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
			return {"wall": Color("cbbd99"), "timber": Color("674c39"), "roof": Color("75564a"), "roof_dark": Color("503b37"), "trim": Color("e3d0a0")}

func _draw_topdown_architecture(bounds: Rect2, palette: Dictionary) -> void:
	var roof_bounds := bounds.grow(-6.0)
	var roof: Color = palette["roof"]
	var dark: Color = palette["roof_dark"]
	var trim: Color = palette["trim"]
	var wall: Color = palette["wall"]
	if kind == "farm":
		draw_rect(roof_bounds, Color("8f7747"))
		for portion in [0.17, 0.38, 0.59, 0.8]:
			var y := lerpf(roof_bounds.position.y, roof_bounds.end.y, portion)
			draw_line(Vector2(roof_bounds.position.x + 3, y), Vector2(roof_bounds.end.x - 3, y), Color("c9aa60"), 2.2)
		return
	if kind.ends_with("_wall") or kind.ends_with("_gate"):
		draw_rect(roof_bounds, trim if kind.begins_with("stone") else palette["timber"])
		for portion in [0.1, 0.3, 0.5, 0.7, 0.9]:
			var x := lerpf(roof_bounds.position.x, roof_bounds.end.x, portion)
			draw_rect(Rect2(x - 3, roof_bounds.position.y - 2, 6, 5), dark)
		if kind.ends_with("_gate"):
			var gap := Rect2(-size().x * 0.14, roof_bounds.position.y, size().x * 0.28, roof_bounds.size.y)
			draw_rect(gap, Color("304136"))
		return
	if kind in ["keep", "outpost"]:
		draw_rect(roof_bounds, wall.darkened(0.33))
		draw_rect(roof_bounds, trim, false, 3.0)
		for portion in [0.12, 0.36, 0.6, 0.84]:
			var x := lerpf(roof_bounds.position.x, roof_bounds.end.x, portion)
			draw_rect(Rect2(x - 3, roof_bounds.position.y - 2, 6, 5), trim)
			draw_rect(Rect2(x - 3, roof_bounds.end.y - 3, 6, 5), trim)
		draw_rect(Rect2(-5, -5, 10, 10), dark)
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
	match kind:
		"town_center", "landmark", "wonder":
			var tower := Rect2(Vector2(-7, -8), Vector2(14, 16))
			draw_rect(tower, palette["wall"])
			draw_rect(tower.grow(-2), dark)
			draw_rect(tower, trim, false, 1.3)
		"house", "blacksmith", "siege_workshop":
			draw_rect(Rect2(roof_bounds.position + Vector2(9, 8), Vector2(7, 8)), palette["timber"])
		"market":
			var awning := Rect2(roof_bounds.position.x + 5, roof_bounds.end.y - 12, roof_bounds.size.x - 10, 10)
			draw_rect(awning, game.player_color(owner_id))
			for portion in [0.25, 0.5, 0.75]:
				var x := lerpf(awning.position.x, awning.end.x, portion)
				draw_line(Vector2(x, awning.position.y), Vector2(x, awning.end.y), trim, 2.0)
		"barracks":
			for offset in [-6.0, 0.0, 6.0]:
				draw_line(Vector2(offset, roof_bounds.end.y - 11), Vector2(offset + 5, roof_bounds.end.y - 3), trim, 1.4)
		"stable":
			draw_rect(Rect2(roof_bounds.position.x + 3, roof_bounds.end.y - 13, roof_bounds.size.x - 6, 9), palette["timber"], false, 2.0)
		"archery_range":
			var target := Vector2(roof_bounds.end.x - 11, roof_bounds.end.y - 11)
			draw_circle(target, 6.0, trim)
			draw_circle(target, 3.5, game.player_color(owner_id))
		"mill":
			draw_circle(Vector2.ZERO, 5.0, trim)
			for direction in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				draw_line(Vector2.ZERO, direction * 15.0, palette["timber"], 2.5)
		"monastery":
			draw_line(Vector2(0, -11), Vector2(0, 11), trim, 3.0)
			draw_line(Vector2(-8, 0), Vector2(8, 0), trim, 3.0)

func _draw_iso_architecture(nw: Vector2, ne: Vector2, se: Vector2, sw: Vector2, lift: Vector2, palette: Dictionary, canvas: Transform2D) -> void:
	if kind == "farm":
		_draw_iso_farm(nw, ne, se, sw, lift)
		return
	if kind.ends_with("_wall") or kind.ends_with("_gate"):
		_draw_iso_fortification(nw, ne, se, sw, lift, palette)
		return
	var timber: Color = palette["timber"]
	var trim: Color = palette["trim"]
	var front_mid := (sw + se) * 0.5
	var door_half := (se - sw) * (0.11 if kind in ["house", "outpost"] else 0.16)
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
	_draw_iso_roof(nw, ne, se, sw, lift, palette, canvas)
	_draw_iso_building_feature(nw, ne, se, sw, lift, palette, canvas)

func _draw_iso_roof(nw: Vector2, ne: Vector2, se: Vector2, sw: Vector2, lift: Vector2, palette: Dictionary, canvas: Transform2D) -> void:
	var center := (nw + ne + se + sw) * 0.25
	if kind in ["keep", "outpost"]:
		var parapet: Color = palette["wall"]
		var masonry: Color = palette["trim"]
		draw_colored_polygon(PackedVector2Array([nw + lift, ne + lift, se + lift, sw + lift]), parapet.darkened(0.32))
		for edge in [[nw, ne], [ne, se], [se, sw], [sw, nw]]:
			var start: Vector2 = edge[0] + lift
			var finish: Vector2 = edge[1] + lift
			draw_line(start, finish, masonry, 3.2)
			for portion in [0.12, 0.38, 0.64, 0.9]:
				var tooth := start.lerp(finish, portion)
				draw_line(tooth, tooth + lift * 0.13, masonry, 4.5)
		return
	var overhang := 1.1 if game.civilizations[owner_id] == "Chinese" else 1.06
	var a := center + (nw - center) * overhang + lift
	var b := center + (ne - center) * overhang + lift
	var c := center + (se - center) * overhang + lift
	var d := center + (sw - center) * overhang + lift
	var rise := RtsIsoProjection.world_delta(canvas, Vector2(0, -(15.0 if kind in ["town_center", "landmark", "keep", "wonder"] else 9.0) * game.camera.zoom.x))
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

func _draw_iso_building_feature(nw: Vector2, ne: Vector2, se: Vector2, sw: Vector2, lift: Vector2, palette: Dictionary, canvas: Transform2D) -> void:
	var front := (sw + se) * 0.5
	var roof_middle := (nw + ne + se + sw) * 0.25 + lift
	var timber: Color = palette["timber"]
	var trim: Color = palette["trim"]
	match kind:
		"town_center", "keep", "landmark", "wonder":
			_draw_iso_tower(nw, ne, se, sw, lift, palette, canvas)
		"house", "blacksmith", "siege_workshop":
			var chimney := roof_middle + (nw - roof_middle) * 0.28
			var chimney_top := chimney + RtsIsoProjection.world_delta(canvas, Vector2(0, -12.0 * game.camera.zoom.x))
			draw_line(chimney, chimney_top, timber, 7.0)
			draw_line(chimney_top + Vector2(-4, 0), chimney_top + Vector2(4, 0), trim, 3.0)
	if kind == "market":
		var left := sw.lerp(se, 0.18) + lift * 0.74
		var right := sw.lerp(se, 0.82) + lift * 0.74
		draw_colored_polygon(PackedVector2Array([left, right, right - lift * 0.25, left - lift * 0.25]), game.player_color(owner_id).darkened(0.12))
		for portion in [0.32, 0.5, 0.68]:
			var stripe := left.lerp(right, portion)
			draw_line(stripe, stripe - lift * 0.25, trim, 2.0)
	elif kind == "barracks":
		for portion in [0.18, 0.27, 0.36]:
			var spear := sw.lerp(se, portion)
			draw_line(spear + lift * 0.15, spear + lift * 0.8, timber.darkened(0.35), 1.4)
			draw_circle(spear + lift * 0.85, 1.8, trim)
	elif kind == "stable":
		draw_line(sw.lerp(se, 0.64) + lift * 0.24, sw.lerp(se, 0.9) + lift * 0.24, timber, 3.0)
		draw_line(sw.lerp(se, 0.64) + lift * 0.24, sw.lerp(se, 0.64) + lift * 0.58, timber, 2.0)
		draw_line(sw.lerp(se, 0.9) + lift * 0.24, sw.lerp(se, 0.9) + lift * 0.58, timber, 2.0)
	elif kind == "archery_range":
		var target := ne.lerp(se, 0.58) + lift * 0.56
		draw_circle(target, 5.0, trim)
		draw_circle(target, 3.3, game.player_color(owner_id))
		draw_circle(target, 1.5, Color("f3e8c5"))
	elif kind == "mill":
		var hub := front + lift * 0.6
		draw_circle(hub, 4.0, trim)
		for direction in [Vector2(0, -13), Vector2(0, 13), Vector2(-13, 0), Vector2(13, 0)]:
			var blade := RtsIsoProjection.world_delta(canvas, direction * game.camera.zoom.x)
			draw_line(hub, hub + blade, timber, 3.0)
	elif kind == "lumber_camp":
		for portion in [0.18, 0.27, 0.36]:
			var log_base := sw.lerp(se, portion)
			draw_line(log_base, log_base + lift * 0.3, Color("9a7048"), 4.0)
	elif kind == "mining_camp":
		for portion in [0.7, 0.8]:
			var ore := sw.lerp(se, portion)
			draw_circle(ore + lift * 0.12, 3.5, Color("85837a"))
	elif kind == "monastery":
		draw_line(roof_middle + Vector2(0, -4), roof_middle + Vector2(0, -15), trim, 2.4)
		draw_line(roof_middle + Vector2(-5, -11), roof_middle + Vector2(5, -11), trim, 2.4)
	elif kind == "outpost":
		var mast := roof_middle + RtsIsoProjection.world_delta(canvas, Vector2(0, -16.0 * game.camera.zoom.x))
		draw_line(roof_middle, mast, timber, 2.0)
		draw_colored_polygon(PackedVector2Array([mast, mast + Vector2(9, 3), mast + Vector2(0, 6)]), game.player_color(owner_id))

func _draw_iso_tower(nw: Vector2, ne: Vector2, se: Vector2, sw: Vector2, lift: Vector2, palette: Dictionary, canvas: Transform2D) -> void:
	var center := (nw + ne + se + sw) * 0.25 + lift
	var tower_scale := 0.2 if kind == "outpost" else 0.25
	var a := center + (nw - center + lift) * tower_scale
	var b := center + (ne - center + lift) * tower_scale
	var c := center + (se - center + lift) * tower_scale
	var d := center + (sw - center + lift) * tower_scale
	var rise := RtsIsoProjection.world_delta(canvas, Vector2(0, -(14.0 if kind == "outpost" else 19.0) * game.camera.zoom.x))
	var wall: Color = palette["wall"]
	draw_colored_polygon(PackedVector2Array([b + rise, c + rise, c, b]), wall.darkened(0.25))
	draw_colored_polygon(PackedVector2Array([d + rise, c + rise, c, d]), wall)
	draw_colored_polygon(PackedVector2Array([a + rise, b + rise, c + rise, d + rise]), palette["roof_dark"])
	draw_polyline(PackedVector2Array([a + rise, b + rise, c + rise, d + rise, a + rise]), palette["trim"], 1.6)
	if kind in ["keep", "outpost"]:
		for portion in [0.1, 0.4, 0.7]:
			var battlement := (d + rise).lerp(c + rise, portion)
			draw_line(battlement, battlement + rise * 0.2, palette["trim"], 3.0)
	else:
		var flag_base := (a + b + c + d) * 0.25 + rise
		var flag_top := flag_base + RtsIsoProjection.world_delta(canvas, Vector2(0, -14 * game.camera.zoom.x))
		draw_line(flag_base, flag_top, palette["timber"], 1.7)
		draw_colored_polygon(PackedVector2Array([flag_top, flag_top + Vector2(9, 3), flag_top + Vector2(0, 6)]), game.player_color(owner_id))

func _draw_iso_fortification(nw: Vector2, ne: Vector2, se: Vector2, sw: Vector2, lift: Vector2, palette: Dictionary) -> void:
	var top_left := sw + lift
	var top_right := se + lift
	var material: Color = palette["trim"] if kind.begins_with("stone") else palette["timber"]
	for portion in [0.07, 0.25, 0.43, 0.61, 0.79, 0.95]:
		var tooth := top_left.lerp(top_right, portion)
		draw_line(tooth, tooth + lift * 0.25, material, 4.0)
	if kind.ends_with("_gate"):
		var mid := (sw + se) * 0.5
		var half_width := (se - sw) * 0.19
		draw_colored_polygon(PackedVector2Array([mid - half_width + lift * 0.86, mid + half_width + lift * 0.86, mid + half_width, mid - half_width]), Color("2c2a26"))
		draw_line(mid - half_width + lift * 0.84, mid + half_width + lift * 0.84, material, 2.0)

func _draw_iso_farm(nw: Vector2, ne: Vector2, se: Vector2, sw: Vector2, lift: Vector2) -> void:
	for portion in [0.12, 0.32, 0.52, 0.72, 0.9]:
		var start := nw.lerp(sw, portion) + lift
		var finish := ne.lerp(se, portion) + lift
		draw_line(start, finish, Color("6f5838"), 3.0)
		draw_line(start + (se - ne) * 0.045, finish + (se - ne) * 0.045, Color("d8bf70"), 2.2)
	for portion in [0.2, 0.48, 0.76]:
		var crop := nw.lerp(sw, portion).lerp(ne.lerp(se, portion), 0.5) + lift
		draw_line(crop, crop + Vector2(0, -4), Color("91a760"), 1.5)

func _draw_building_icon(center: Vector2, icon_size: float) -> void:
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

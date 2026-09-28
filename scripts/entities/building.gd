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
	return 20.0 if kind.ends_with("_wall") or kind.ends_with("_gate") or kind == "scout_camp" else 26.0

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
	if kind in ["town_center", "landmark", "keep", "wonder"]: return 42.0
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
	var color: Color = game.player_color(owner_id)
	var construction_ratio := 1.0 - build_remaining / maxf(build_total, 0.1)
	if not is_complete(): color = color.darkened(0.45)
	if game.view_mode_25d and not kind in ["farm", "palisade_wall", "stone_wall", "palisade_gate", "stone_gate"]:
		var depth := 18.0 if kind == "town_center" or kind == "landmark" or kind == "keep" else 12.0
		draw_rect(Rect2(bounds.position + Vector2(0, depth), bounds.size), color.darkened(0.55))
		draw_colored_polygon(PackedVector2Array([bounds.position + Vector2(0, bounds.size.y), bounds.position + bounds.size, bounds.position + bounds.size + Vector2(0, depth), bounds.position + Vector2(0, bounds.size.y + depth)]), color.darkened(0.4))
	draw_rect(bounds, Color("272d2a"))
	draw_rect(bounds.grow(-4), color)
	if damage_flash_timer > 0.0: draw_rect(bounds.grow(-2), Color("f8ca91", damage_flash_timer * 1.4), false, 3.0)
	if not is_complete():
		var timber := Color("b99b6e")
		for side in [-1.0, 1.0]:
			var post_x: float = side * (size().x * 0.5 - 7.0)
			draw_line(Vector2(post_x, size().y * 0.43), Vector2(post_x, -size().y * 0.43 * construction_ratio), timber, 3.0)
			draw_line(Vector2(post_x, size().y * 0.2), Vector2(-post_x, -size().y * 0.28 * construction_ratio), Color(timber, 0.72), 2.0)
		if construction_ratio < 0.65:
			draw_rect(Rect2(-size().x * 0.42, -size().y * 0.35, size().x * 0.84, 5), Color("6d5a41"))
	if kind.ends_with("_gate"):
		var opening := Rect2(-size() * 0.22, size() * 0.44)
		draw_rect(opening, Color("314638"))
		draw_line(opening.position, opening.end, Color("d8c88e"), 2)
	elif kind.ends_with("_wall"):
		draw_line(Vector2(-size().x * 0.4, 0), Vector2(size().x * 0.4, 0), Color("d5d0b3"), 3)
	elif kind == "farm":
		for x in range(-17, 25, 11):
			draw_line(Vector2(x, -22), Vector2(x - 7, 22), Color("d4bd73"), 3)
	elif kind == "town_center" and construction_ratio >= 0.65:
		draw_rect(Rect2(-15, -19, 30, 28), Color("e5d3a7"))
		draw_colored_polygon(PackedVector2Array([Vector2(-26, -19), Vector2(0, -35), Vector2(26, -19)]), Color("513c36"))
	elif construction_ratio >= 0.65:
		draw_colored_polygon(PackedVector2Array([Vector2(-size().x * 0.4, -size().y * 0.4), Vector2(0, -size().y * 0.65), Vector2(size().x * 0.4, -size().y * 0.4)]), Color("513c36"))
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
	var color: Color = game.player_color(owner_id)
	var construction_ratio := 1.0 - build_remaining / maxf(build_total, 0.1)
	if not is_complete(): color = color.darkened(0.45)
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
		draw_colored_polygon(PackedVector2Array([ne + lift, se + lift, se, ne]), color.darkened(0.5))
		draw_colored_polygon(PackedVector2Array([sw + lift, se + lift, se, sw]), color.darkened(0.35))
		if kind.ends_with("_gate"):
			var gate_mid := (sw + se) * 0.5
			draw_line(gate_mid + lift * 0.2, gate_mid + lift * 0.78, Color("202a29"), 7.0)
	var roof_color := Color("6b4b3d") if kind in ["town_center", "landmark", "keep", "wonder"] else color.darkened(0.18)
	if kind == "farm": roof_color = Color("957d48")
	if kind.ends_with("_wall") or kind.ends_with("_gate"): roof_color = color.lightened(0.13)
	if construction_ratio >= 0.65:
		draw_colored_polygon(PackedVector2Array([nw + lift, ne + lift, se + lift, sw + lift]), roof_color)
		draw_polyline(PackedVector2Array([nw + lift, ne + lift, se + lift, sw + lift, nw + lift]), Color("1f2929"), 2.0)
	else:
		var scaffold := Color("c5a878")
		for corner in [nw, ne, sw, se]:
			draw_line(corner, corner + lift * maxf(0.2, construction_ratio), scaffold, 2.2)
		draw_line(nw + lift * 0.38, se + lift * 0.38, Color(scaffold, 0.82), 2.0)
		draw_line(ne + lift * 0.38, sw + lift * 0.38, Color(scaffold, 0.82), 2.0)
	if kind == "farm":
		for portion in [0.25, 0.5, 0.75]:
			draw_line(nw.lerp(sw, portion), ne.lerp(se, portion), Color("c3a763"), 2.0)
	elif construction_ratio >= 0.65 and not kind.ends_with("_wall") and not kind.ends_with("_gate"):
		var roof_middle := (nw + ne + se + sw) * 0.25 + lift
		draw_line(nw + lift, se + lift, roof_color.lightened(0.25), 2.0)
		draw_circle(roof_middle, 4.0, Color("d8bd80"))
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
	var bar_y: float = -height * game.camera.zoom.x - size().y * 0.25 - 16.0
	draw_rect(Rect2(-bar_width * 0.5, bar_y, bar_width, 5), Color("422f2d"))
	draw_rect(Rect2(-bar_width * 0.5, bar_y, bar_width * clampf(hp / max_hp, 0.0, 1.0), 5), Color("7fd47a"))
	if not is_complete(): draw_arc(Vector2.ZERO, 14, 0, TAU * (1.0 - build_remaining / maxf(build_total, 0.1)), 20, Color.WHITE, 3)
	if not production_queue.is_empty(): draw_circle(Vector2(bar_width * 0.5 + 5, bar_y + 2), 6, Color("e5c45d"))
	draw_set_transform_matrix(Transform2D.IDENTITY)

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

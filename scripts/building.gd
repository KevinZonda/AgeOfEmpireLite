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
	rally_point = position + Vector2(95 if owner_id == 0 else -95, 0)
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
	return result

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
	return stats.get("size", GameData.BUILDINGS[kind]["size"])

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
	var cost: Dictionary = paid_cost if not paid_cost.is_empty() else GameData.UNITS[unit_kind]["cost"]
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
	return GameData.training_time(game.civilizations[owner_id], kind, unit_kind) * RtsLandmarkCatalog.training_multiplier(game.civilizations[owner_id], game.players[owner_id].get("landmarks", []), kind, unit_kind) * RtsLandmarkCatalog.dynasty_training_multiplier(game.civilizations[owner_id], game.players[owner_id].get("dynasty", ""), kind, unit_kind)

func set_rally(world_point: Vector2, target_ref: Node2D = null) -> void:
	rally_point = world_point
	rally_target = target_ref
	rally_resource_kind = target_ref.kind if target_ref is RtsResource else "food" if target_ref is RtsBuilding and target_ref.kind == "farm" else ""
	queue_redraw()

func garrison_unit(unit: RtsUnit) -> bool:
	if not is_complete() or unit.owner_id != owner_id or garrisoned_units.size() >= RtsSiegeRules.garrison_capacity(kind): return false
	if not RtsSiegeRules.can_garrison(unit.stats, kind): return false
	if garrisoned_units.has(unit): return true
	garrisoned_units.append(unit)
	unit.garrisoned_in = self
	unit.order = "idle"
	unit.position = position
	unit.hide()
	game.navigation.invalidate_spatial_index()
	queue_redraw()
	return true

func ungarrison_all() -> void:
	for index in garrisoned_units.size():
		var unit: RtsUnit = garrisoned_units[index]
		if not is_instance_valid(unit): continue
		unit.garrisoned_in = null
		unit.position = game.navigation.nearest_walkable_point(position + Vector2((index % 3 - 1) * 24, size().y * 0.5 + 30 + (index / 3) * 22), unit.radius(), unit)
		unit.show()
		unit.order_stop()
	garrisoned_units.clear()
	game.navigation.invalidate_spatial_index()
	queue_redraw()

func _process_defense(delta: float) -> void:
	defense_timer = maxf(0.0, defense_timer - delta)
	if defense_timer > 0.0: return
	var attack := RtsSiegeRules.defense_stats(kind, garrisoned_units.size())
	if attack.is_empty(): return
	var enemy: RtsUnit
	var best := INF
	var reach: float = RtsSiegeRules.defense_range(kind)
	for unit in game.units:
		if not is_instance_valid(unit) or unit.is_queued_for_deletion() or unit.owner_id == owner_id or unit.garrisoned_in != null: continue
		if game.fog.active and not game.fog.can_see(owner_id, unit.position): continue
		var distance := position.distance_squared_to(unit.position)
		if distance < best and distance <= reach * reach:
			best = distance
			enemy = unit
	if enemy == null: return
	var damage := RtsCombatRules.damage(attack, enemy.stats)
	var projectile := RtsProjectile.new()
	projectile.setup(game, owner_id, global_position, enemy, damage, RtsSiegeRules.defense_projectile_speed(kind))
	game.add_child(projectile)
	defense_timer = RtsSiegeRules.defense_cooldown(kind)

func _process(delta: float) -> void:
	if not game.started or game.paused or game.game_over: return
	if is_complete(): _process_defense(delta)
	if not is_complete() or production_queue.is_empty(): return
	production_remaining = maxf(0.0, production_remaining - delta)
	_sync_remaining()
	if production_remaining > 0.0: return
	var job: Dictionary = production_queue.pop_front()
	if job["type"] == "train":
		training_queue.pop_front()
		game.spawn_unit(owner_id, job["kind"], game.find_spawn_position(self), rally_point, rally_target, rally_resource_kind)
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
	var color: Color = GameData.CIVILIZATIONS[game.civilizations[owner_id]]["color"]
	if not is_complete(): color = color.darkened(0.45)
	draw_rect(bounds, Color("272d2a"))
	draw_rect(bounds.grow(-4), color)
	if kind == "farm":
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

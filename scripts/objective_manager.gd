class_name RtsObjectiveManager
extends Node2D

signal victory(owner_id: int, reason: String)
signal site_captured(index: int, owner_id: int)

const SITE_RADIUS := 95.0
const CAPTURE_TIME := 8.0
const SACRED_VICTORY_TIME := 90.0
const WONDER_VICTORY_TIME := 120.0
const SITE_FRACTIONS := [Vector2(0.5, 0.23), Vector2(0.5, 0.5), Vector2(0.5, 0.77)]

var game: Node2D
var sacred_sites: Array[Dictionary] = []
var sacred_holder := -1
var sacred_remaining := SACRED_VICTORY_TIME
var wonder_remaining := {0: WONDER_VICTORY_TIME, 1: WONDER_VICTORY_TIME}
var wonder_instance_ids := {0: 0, 1: 0}
var _victory_emitted := false


func setup(game_ref: Node2D) -> void:
	game = game_ref
	sacred_sites.clear()
	var size: Vector2 = game.world_map.world_size
	for fraction in SITE_FRACTIONS:
		var desired: Vector2 = Vector2(size.x * fraction.x, size.y * fraction.y)
		var position: Vector2 = game.world_map.nearest_walkable_point(desired)
		sacred_sites.append({"position": position, "owner_id": -1, "capture_owner": -1, "capture_progress": 0.0, "contested": false})
	reset()


func reset() -> void:
	for site in sacred_sites:
		site["owner_id"] = -1
		site["capture_owner"] = -1
		site["capture_progress"] = 0.0
		site["contested"] = false
	sacred_holder = -1
	sacred_remaining = SACRED_VICTORY_TIME
	wonder_remaining = {0: WONDER_VICTORY_TIME, 1: WONDER_VICTORY_TIME}
	wonder_instance_ids = {0: 0, 1: 0}
	_victory_emitted = false
	queue_redraw()


func _process(delta: float) -> void:
	if game == null or not game.started or game.paused or game.game_over or _victory_emitted: return
	var changed := false
	for index in sacred_sites.size():
		changed = _tick_site(index, delta) or changed
	_tick_sacred_victory(delta)
	_tick_wonder_victory(delta)
	if changed: queue_redraw()


func _tick_site(index: int, delta: float) -> bool:
	var site: Dictionary = sacred_sites[index]
	var presence := [false, false]
	for unit in game.units:
		if not is_instance_valid(unit) or unit.is_queued_for_deletion() or unit.hp <= 0.0: continue
		if unit is RtsUnit and unit.garrisoned_in != null: continue
		if unit.owner_id < 0 or unit.owner_id > 1: continue
		if not unit.stats.get("tags", []).has("military"): continue
		if unit.position.distance_squared_to(site["position"]) <= SITE_RADIUS * SITE_RADIUS:
			presence[unit.owner_id] = true
	var contested: bool = presence[0] and presence[1]
	var changed: bool = site["contested"] != contested
	site["contested"] = contested
	if contested: return changed
	var alone_owner := 0 if presence[0] else 1 if presence[1] else -1
	if alone_owner < 0:
		if site["capture_owner"] != -1 or site["capture_progress"] > 0.0:
			site["capture_owner"] = -1
			site["capture_progress"] = 0.0
			return true
		return changed
	if alone_owner == site["owner_id"]:
		if site["capture_owner"] != -1 or site["capture_progress"] > 0.0:
			site["capture_owner"] = -1
			site["capture_progress"] = 0.0
			return true
		return changed
	if site["capture_owner"] != alone_owner:
		site["capture_owner"] = alone_owner
		site["capture_progress"] = 0.0
	site["capture_progress"] = minf(CAPTURE_TIME, float(site["capture_progress"]) + delta)
	if site["capture_progress"] >= CAPTURE_TIME:
		site["owner_id"] = alone_owner
		site["capture_owner"] = -1
		site["capture_progress"] = 0.0
		site_captured.emit(index, alone_owner)
	return true


func _tick_sacred_victory(delta: float) -> void:
	if sacred_sites.size() != 3: return
	var owner: int = sacred_sites[0]["owner_id"]
	for site in sacred_sites:
		if owner < 0 or site["owner_id"] != owner:
			sacred_holder = -1
			sacred_remaining = SACRED_VICTORY_TIME
			return
	if sacred_holder != owner:
		sacred_holder = owner
		sacred_remaining = SACRED_VICTORY_TIME
		return
	for site in sacred_sites:
		if site["contested"]: return
	sacred_remaining = maxf(0.0, sacred_remaining - delta)
	if sacred_remaining <= 0.0: _emit_victory(owner, "sacred")


func _tick_wonder_victory(delta: float) -> void:
	var present := {0: 0, 1: 0}
	for building in game.buildings:
		if not is_instance_valid(building) or building.is_queued_for_deletion(): continue
		if building.kind != "wonder" or not building.is_complete(): continue
		if building.owner_id < 0 or building.owner_id > 1: continue
		if present[building.owner_id] == 0: present[building.owner_id] = building.get_instance_id()
	for owner_id in [0, 1]:
		if present[owner_id] == 0:
			wonder_instance_ids[owner_id] = 0
			wonder_remaining[owner_id] = WONDER_VICTORY_TIME
			continue
		if wonder_instance_ids[owner_id] != present[owner_id]:
			wonder_instance_ids[owner_id] = present[owner_id]
			wonder_remaining[owner_id] = WONDER_VICTORY_TIME
		wonder_remaining[owner_id] = maxf(0.0, float(wonder_remaining[owner_id]) - delta)
		if wonder_remaining[owner_id] <= 0.0: _emit_victory(owner_id, "wonder")


func on_building_destroyed(building: Node2D) -> void:
	if building.kind != "wonder" or building.owner_id < 0 or building.owner_id > 1: return
	if wonder_instance_ids[building.owner_id] == building.get_instance_id():
		wonder_instance_ids[building.owner_id] = 0
		wonder_remaining[building.owner_id] = WONDER_VICTORY_TIME


func status_for(owner_id: int) -> Dictionary:
	var owned := 0
	for site in sacred_sites:
		if site["owner_id"] == owner_id: owned += 1
	return {
		"sacred_owned": owned,
		"sacred_holder": sacred_holder,
		"sacred_remaining": sacred_remaining if sacred_holder == owner_id else SACRED_VICTORY_TIME,
		"wonder_active": wonder_instance_ids.get(owner_id, 0) != 0,
		"wonder_remaining": wonder_remaining.get(owner_id, WONDER_VICTORY_TIME),
	}


func status_text(owner_id: int) -> String:
	var status := status_for(owner_id)
	var parts: Array[String] = ["圣地 %d/3" % status["sacred_owned"]]
	if status["sacred_holder"] == owner_id: parts.append("圣地胜利 %ds" % ceili(status["sacred_remaining"]))
	if status["wonder_active"]: parts.append("奇观胜利 %ds" % ceili(status["wonder_remaining"]))
	return "  ·  ".join(parts)


func _emit_victory(owner_id: int, reason: String) -> void:
	if _victory_emitted: return
	_victory_emitted = true
	victory.emit(owner_id, reason)


func _draw() -> void:
	var font := ThemeDB.fallback_font
	for index in sacred_sites.size():
		var site: Dictionary = sacred_sites[index]
		var center: Vector2 = site["position"]
		var color := Color("b7b0a0")
		if site["owner_id"] >= 0 and game != null:
			color = GameData.CIVILIZATIONS[game.civilizations[site["owner_id"]]]["color"]
		if site["contested"]: color = Color("ead667")
		draw_circle(center, 28.0, Color(color, 0.2))
		draw_arc(center, 31.0, 0.0, TAU, 36, color, 4.0)
		draw_arc(center, SITE_RADIUS, 0.0, TAU, 48, Color(color, 0.32), 2.0)
		if site["capture_owner"] >= 0 and site["capture_progress"] > 0.0:
			draw_arc(center, 37.0, -PI * 0.5, -PI * 0.5 + TAU * float(site["capture_progress"]) / CAPTURE_TIME, 24, Color("f3e8b1"), 4.0)
		if font != null: draw_string(font, center + Vector2(-8, 7), ["I", "II", "III"][index], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)

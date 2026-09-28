class_name RtsUnit
extends Node2D

const AUTO_GATHER_RADIUS := 180.0
const ROUTE_STALL_SECONDS := 0.9
const ROUTE_RETRY_BASE := 0.7
const ROUTE_RETRY_MAX := 4.0
const UnitWork = preload("res://scripts/entities/unit_work.gd")
const UnitCombat = preload("res://scripts/entities/unit_combat.gd")
const SiegeVisual2D = preload("res://scripts/entities/visuals/siege_visual_2d.gd")
const SiegeVisual25D = preload("res://scripts/entities/visuals/siege_visual_25d.gd")

var game: Node2D
var owner_id := 0
var kind: String
var stats: Dictionary = {}
var hp := 1.0
var max_hp := 1.0
var order := "idle"
var destination := Vector2.ZERO
var target: Node2D
var attack_timer := 0.0
var hit_flash_timer := 0.0
var work_timer := 0.0
var enclosure_timer := 5.0
var charging := false
var charge_distance := 0.0
var charge_cooldown := 0.0
var charge_elapsed := 0.0
var stun_timer := 0.0
var momentum_timer := 0.0
var resume_destination := Vector2.INF
var resume_order := ""
var patrol_origin := Vector2.ZERO
var patrol_destination := Vector2.ZERO
var hold_position := Vector2.ZERO
var stance := "aggressive"
var engagement := "aggressive"
var auto_engaged := false
var awareness_timer := 0.0
var engagement_origin := Vector2.ZERO
var gather_kind := ""
var gather_location := Vector2.ZERO
var route := PackedVector2Array()
var route_index := 0
var route_goal := Vector2.INF
var route_retry := 0.0
var route_failures := 0
var route_stop_distance := -1.0
var route_obstacle_revision := -1
var route_check_pending := false
var route_blocked := false
var route_best_distance := INF
var route_recovery_distance := INF
var route_stalled_time := 0.0
var movement_group: RtsMovementGroup
var group_stuck_time := 0.0
var group_progress_target := Vector2.INF
var group_best_distance := INF
var avoidance_cooldown := 0.0
var yield_timer := 0.0
var yield_request_cooldown := 0.0
var command_queue: Array[Dictionary] = []
var garrisoned_in: Node2D
var wall_host: RtsBuilding
var wall_entry_point: Node2D
var passengers: Array[RtsUnit] = []
var field_build_remaining := 0.0
var field_build_total := 0.0
var landing_position := Vector2.INF
var trade_post: RtsTradePost
var trade_home: RtsBuilding
var trade_returning := false
var trade_resource_kind := "gold"
var saved_work: Dictionary = {}
var carried_relic: RtsRelic
var producer_landmark_id := ""
var paling_timer := 0.0
var paling_cooldown := 0.0
var volley_timer := 0.0
var volley_cooldown := 0.0
var shield_timer := 0.0
var heal_timer := 0.0
var helm_timer := 0.0
var helm_cooldown := 0.0
var conversion_timer := 0.0
var conversion_cooldown := 0.0
var spirit_buff_timer := 0.0
var revealed_timer := 0.0
var artillery_shot_ready := false
var artillery_shot_cooldown := 0.0
var facing_right := true
var facing_back := false
var visual_phase := 0.0
var visual_moving := false
var visual_last_position := Vector2.INF
var visual_action := ""
var visual_action_timer := 0.0
var visual_action_length := 0.0
var visual_idle_timer := 0.0
var visual_redraw_timer := 0.0

func setup(game_ref: Node2D, player_id: int, unit_kind: String) -> void:
	game = game_ref
	owner_id = player_id
	kind = unit_kind
	awareness_timer = float(get_instance_id() % 7) * 0.035
	refresh_stats(false)
	queue_redraw()

func refresh_stats(preserve_damage := true) -> void:
	var missing_hp := maxf(0.0, max_hp - hp) if preserve_damage else 0.0
	stats = RtsUnitCatalog.unit_definition(game.civilizations[owner_id], kind, game.players[owner_id].get("researched", []), game.players[owner_id].get("age", 1), game.players[owner_id].get("landmarks", []), game.players[owner_id].get("dynasty", ""), producer_landmark_id)
	if shield_timer > 0.0:
		stats["armor"]["ranged"] = float(stats["armor"].get("ranged", 0.0)) + 5.0
		for profile_id in stats.get("profiles", {}): stats["profiles"][profile_id]["range"] = float(stats["profiles"][profile_id].get("range", 0.0)) + 30.0
		stats["range"] = float(stats.get("range", 0.0)) + 30.0
	if is_instance_valid(wall_host): stats["armor"]["ranged"] = float(stats["armor"].get("ranged", 0.0)) + 2.0
	max_hp = float(stats["hp"])
	hp = maxf(1.0, max_hp - missing_hp)
	queue_redraw()

func radius() -> float:
	return float(stats["radius"])

func effective_speed() -> float:
	return float(stats["speed"]) * (1.4 if helm_timer > 0.0 else 1.0)

func gathering_amount() -> int:
	return UnitWork.gathering_amount(self)

func gathering_per_second() -> float:
	return float(gathering_amount()) / 1.1

func order_move(world_point: Vector2) -> void:
	if is_instance_valid(wall_host): leave_wall()
	if stance == "hold": stance = "aggressive"
	resume_order = ""
	conversion_timer = 0.0
	if paling_timer > 0.0: paling_timer = 0.0
	movement_group = null
	order = "move"
	destination = game.navigation.nearest_walkable_point(world_point, radius(), self, true)
	target = null
	charging = false
	resume_destination = Vector2.INF
	_reset_route()

func order_attack(enemy: Node2D, automatic := false) -> void:
	if is_instance_valid(wall_host) and position.distance_to(enemy.position) > float(stats.get("range", 0.0)) + 35.0: leave_wall()
	resume_order = ""
	conversion_timer = 0.0
	if float(stats.get("damage", 0.0)) <= 0.0: return
	if kind == "battering_ram" and enemy is RtsUnit: return
	if helm_timer > 0.0: helm_timer = 0.0
	movement_group = null
	order = "attack"
	auto_engaged = automatic
	engagement_origin = position
	target = enemy
	charging = enemy is RtsUnit and (stats.get("profiles", {}).has("charge") or float(stats.get("charge_bonus", 0.0)) > 0.0) and charge_cooldown <= 0.0 and position.distance_to(enemy.position) >= 110.0 and position.distance_to(enemy.position) <= 180.0
	charge_distance = 0.0
	charge_elapsed = 0.0
	resume_destination = Vector2.INF
	_reset_route()

func order_attack_move(world_point: Vector2) -> void:
	if is_instance_valid(wall_host): leave_wall()
	if stance == "hold": stance = "aggressive"
	resume_order = ""
	conversion_timer = 0.0
	if paling_timer > 0.0: paling_timer = 0.0
	movement_group = null
	order = "attack_move"
	destination = game.navigation.nearest_walkable_point(world_point, radius(), self, true)
	target = null
	charging = false
	resume_destination = Vector2.INF
	_reset_route()

func order_stop() -> void:
	if stance == "hold": stance = "aggressive"
	resume_order = ""
	conversion_timer = 0.0
	command_queue.clear()
	movement_group = null
	order = "wall" if is_instance_valid(wall_host) else "idle"
	target = null
	charging = false
	resume_destination = Vector2.INF
	_reset_route()

func order_hold() -> void:
	order_stop()
	stance = "hold"
	hold_position = position
	order = "hold"

func order_patrol(world_point: Vector2) -> void:
	order_stop()
	stance = "aggressive"
	patrol_origin = position
	patrol_destination = game.navigation.nearest_walkable_point(world_point, radius(), self, true)
	destination = patrol_destination
	order = "patrol"

func garrison_unit(unit: RtsUnit) -> bool:
	if kind not in ["transport_ship", "battering_ram", "siege_tower"] or field_build_remaining > 0.0 or not is_instance_valid(unit) or unit.owner_id != owner_id or passengers.size() >= (10 if kind == "siege_tower" else 8) or unit.stats.get("tags", []).has("naval") or unit.stats.get("tags", []).has("siege") or unit.garrisoned_in != null: return false
	if unit.position.distance_to(position) > 100.0: return false
	passengers.append(unit)
	unit.garrisoned_in = self
	unit.order = "idle"
	unit.command_queue.clear()
	unit.position = position
	unit.hide()
	game.navigation.invalidate_spatial_index()
	queue_redraw()
	return true

func ungarrison_all() -> void:
	if kind not in ["transport_ship", "battering_ram", "siege_tower"] or passengers.is_empty(): return
	var shore := position + Vector2(0, 40) if kind != "transport_ship" else landing_position
	if kind == "transport_ship" and shore == Vector2.INF:
		var pair: Dictionary = game.find_landing_pair(self, position)
		if pair.is_empty() or position.distance_to(pair["water"]) > 80.0: return
		shore = pair["land"]
	for index in passengers.size():
		var passenger: RtsUnit = passengers[index]
		if not is_instance_valid(passenger): continue
		passenger.garrisoned_in = null
		passenger.position = game.navigation.nearest_walkable_point(shore + Vector2((index % 3 - 1) * 23, (index / 3) * 23), passenger.radius(), passenger)
		passenger.show()
		passenger.order_stop()
	passengers.clear()
	landing_position = Vector2.INF
	game.navigation.invalidate_spatial_index()
	queue_redraw()

func issue_command(command_type: String, world_point := Vector2.INF, target_ref: Node2D = null, append := false, group: RtsMovementGroup = null) -> void:
	var command := {"type": command_type, "point": world_point, "target": target_ref, "group": group}
	if not append:
		command_queue.clear()
		_start_command(command)
	elif order == "idle" and command_queue.is_empty():
		_start_command(command)
	else:
		command_queue.append(command)
	queue_redraw()

func _start_command(command: Dictionary) -> bool:
	movement_group = null
	match command["type"]:
		"assault_wall":
			if kind != "siege_tower" or not command["target"] is RtsBuilding or command["target"].kind != "stone_wall" or not game.is_enemy(owner_id, command["target"].owner_id): return false
			target = command["target"]
			order = "assault_wall"
			_reset_route()
		"board_wall":
			if not command["target"] is RtsBuilding: return false
			var entrance := RtsSiegeRules.wall_entry(game, self, command["target"])
			if entrance == null: return false
			wall_entry_point = entrance
			target = command["target"]
			order = "board_wall"
			_reset_route()
		"group_move", "group_attack_move":
			if command["type"] == "group_attack_move" and not stats.get("tags", []).has("military"): return false
			if is_instance_valid(wall_host): leave_wall()
			movement_group = command.get("group")
			if movement_group == null: return false
			movement_group.activate()

			order = "attack_move" if command["type"] == "group_attack_move" else "move"
			destination = movement_group.destination_for(self)
			target = null
			charging = false
			resume_destination = Vector2.INF
			group_stuck_time = 0.0
			group_progress_target = Vector2.INF
			group_best_distance = INF
			_reset_route()
		"move": order_move(command["point"])
		"patrol":
			if not stats.get("tags", []).has("military"): return false
			order_patrol(command["point"])
		"hold": order_hold()
		"attack_move":
			if not stats.get("tags", []).has("military"): return false
			order_attack_move(command["point"])
		"attack_ground":
			if kind not in ["mangonel", "nest_of_bees", "trebuchet", "bombard", "cannon"]: return false
			order = "attack_ground"
			destination = command["point"]
			target = null
			_reset_route()
		"attack":
			if not is_instance_valid(command["target"]) or command["target"].is_queued_for_deletion(): return false
			if float(stats.get("damage", 0.0)) <= 0.0: return false
			if kind == "battering_ram" and command["target"] is RtsUnit: return false
			order_attack(command["target"])
		"gather":
			if not ["villager", "fishing_boat"].has(kind) or not is_instance_valid(command["target"]) or command["target"].is_queued_for_deletion(): return false
			if command["target"] is RtsResource and command["target"].appearance == "sheep" and command["target"].claimed_by != owner_id: return false
			if kind == "fishing_boat" and (not command["target"] is RtsResource or command["target"].appearance != "fish"): return false
			if kind == "villager" and command["target"] is RtsResource and command["target"].appearance == "fish": return false
			order_gather(command["target"])
		"trade":
			if kind != "trader" or not command["target"] is RtsTradePost: return false
			if not is_instance_valid(trade_home) or trade_home.is_queued_for_deletion(): trade_home = game.find_nearest_owned_building(owner_id, "market", position)
			if trade_home == null: return false
			trade_post = command["target"]
			trade_returning = false
			order = "trade"
			_reset_route()
		"supervise", "collect_tax":
			if kind != "imperial_official" or not command["target"] is RtsBuilding or command["target"].owner_id != owner_id or not command["target"].is_complete(): return false
			order = command["type"]
			target = command["target"]
			_reset_route()
		"relic":
			if kind != "monk" or carried_relic != null or not command["target"] is RtsRelic or not command["target"].available(): return false
			order = "relic"
			target = command["target"]
			_reset_route()
		"deposit_relic":
			if kind != "monk" or carried_relic == null or not command["target"] is RtsBuilding or command["target"].kind != "monastery" or command["target"].owner_id != owner_id: return false
			order = "deposit_relic"
			target = command["target"]
			_reset_route()
		"build":
			if kind != "villager" or not is_instance_valid(command["target"]) or command["target"].is_queued_for_deletion() or command["target"].is_complete(): return false
			order_build(command["target"])
		"field_build":
			if not stats.get("tags", []).has("infantry") or not command["target"] is RtsUnit or command["target"].field_build_remaining <= 0.0 or command["target"].owner_id != owner_id: return false
			order = "field_build"
			target = command["target"]
			_reset_route()
		"repair":
			if kind != "villager" or not is_instance_valid(command["target"]) or command["target"].owner_id != owner_id or not (command["target"] is RtsBuilding or command["target"] is RtsUnit and command["target"].stats.get("tags", []).has("siege")): return false
			if command["target"].hp >= command["target"].max_hp: return false
			order = "repair"
			target = command["target"]
			_reset_route()
		"garrison":
			if not is_instance_valid(command["target"]) or command["target"].is_queued_for_deletion() or not (RtsSiegeRules.can_garrison(stats, command["target"].kind) or command["target"].kind == "landmark" and command["target"].garrison_capacity() > 0 and not stats.get("tags", []).has("siege")): return false
			remember_work()
			order = "garrison"
			target = command["target"]
			_reset_route()
		"board_transport":
			if not command["target"] is RtsUnit or command["target"].kind not in ["transport_ship", "battering_ram", "siege_tower"] or command["target"].owner_id != owner_id or stats.get("tags", []).has("naval") or stats.get("tags", []).has("siege"): return false
			order = "board_transport"
			target = command["target"]
			_reset_route()
		"unload":
			if kind != "transport_ship" or passengers.is_empty(): return false
			var pair: Dictionary = game.find_landing_pair(self, command["point"])
			if pair.is_empty(): return false
			order = "unload"
			destination = pair["water"]
			landing_position = pair["land"]
			target = null
			_reset_route()
		_: return false
	return true

func _advance_command() -> void:
	order = "wall" if is_instance_valid(wall_host) else "idle"
	movement_group = null
	target = null
	resume_destination = Vector2.INF
	while not command_queue.is_empty():
		var command: Dictionary = command_queue.pop_front()
		if _start_command(command): break

func leave_wall() -> void:
	if not is_instance_valid(wall_host): return
	var exit_point := wall_host.position + Vector2(0, 55)
	if is_instance_valid(wall_entry_point): exit_point = wall_entry_point.position + Vector2(0, 55)
	wall_host = null
	wall_entry_point = null
	z_index = 0
	position = game.navigation.nearest_walkable_point(exit_point, radius(), self)
	refresh_stats()
	game.navigation.invalidate_spatial_index()

func is_braced() -> bool:
	if kind == "longbow" and paling_timer > 0.0: return true
	if float(stats.get("brace_bonus", 0.0)) <= 0.0: return false
	if order == "idle": return true
	if order == "attack" and is_instance_valid(target):
		return position.distance_to(target.position) <= float(stats["range"]) + radius() + 8.0
	return false

func activate_ability(ability_id: String) -> bool:
	match ability_id:
		"palings":
			if kind != "longbow" or paling_cooldown > 0.0: return false
			paling_timer = 99999.0
			paling_cooldown = 30.0
			order_stop()
			return true
		"volley":
			if kind != "longbow" or volley_cooldown > 0.0: return false
			volley_timer = 5.0
			volley_cooldown = 45.0
			return true
		"pavise":
			if kind != "arbaletrier": return false
			shield_timer = 99999.0 if shield_timer <= 0.0 else 0.0
			refresh_stats()
			return true
		"helmsman":
			if kind != "warship" or helm_cooldown > 0.0: return false
			helm_timer = 10.0
			helm_cooldown = 30.0
			return true
		"artillery_shot":
			if kind != "cannon" or producer_landmark_id != "fr_college_of_artillery" or artillery_shot_cooldown > 0.0: return false
			artillery_shot_ready = true
			return true
		"convert":
			if kind != "monk" or carried_relic == null or conversion_cooldown > 0.0: return false
			order_stop()
			conversion_timer = 3.0
			conversion_cooldown = 120.0
			return true
		"camp":
			if game.civilizations[owner_id] != "English" or kind not in ["scout", "man_at_arms"]: return false
			var camp_count := 0
			for building in game.buildings:
				if is_instance_valid(building) and building.owner_id == owner_id and building.kind == "scout_camp": camp_count += 1
			if camp_count >= 5 or not game.can_afford(owner_id, {"wood": 25}): return false
			for offset in [Vector2(46, 0), Vector2(-46, 0), Vector2(0, 46), Vector2(0, -46)]:
				var site: Vector2 = position + offset
				if not game.can_place("scout_camp", site): continue
				if not game.spend(owner_id, {"wood": 25}): return false
				game.spawn_building(owner_id, "scout_camp", site)
				game.fog.update_visibility()
				return true
			return false
	return false

func order_gather(resource: Node2D) -> void:
	if resource is RtsResource and resource.appearance == "sheep" and resource.claimed_by != owner_id: return
	if not ["villager", "fishing_boat"].has(kind): return
	if resource is RtsBuilding and resource.kind == "farm" and game.farm_worker(resource, self) != null:
		resource = game.find_nearest_free_farm(owner_id, position, 190.0, self)
		if resource == null:
			order_stop()
			return
	order = "gather"
	target = resource
	resume_destination = Vector2.INF
	charging = false
	gather_kind = resource.kind if resource is RtsResource else ""
	gather_location = resource.position
	_reset_route()

func remember_work() -> void:
	UnitWork.remember_work(self)

func resume_work() -> void:
	UnitWork.resume_work(self)

func _continue_gather() -> void:
	UnitWork.continue_gather(self)

func order_build(building: Node2D) -> void:
	if kind != "villager": return
	order = "build"
	target = building
	resume_destination = Vector2.INF
	charging = false
	_reset_route()

func _reset_route() -> void:
	yield_timer = 0.0
	route.clear()
	route_index = 0
	route_goal = Vector2.INF
	route_retry = 0.0
	route_failures = 0
	route_stop_distance = -1.0
	route_obstacle_revision = -1
	route_check_pending = false
	route_blocked = false
	route_best_distance = INF
	route_recovery_distance = INF
	route_stalled_time = 0.0

func _process(delta: float) -> void:
	if not game.started or game.paused or game.game_over or garrisoned_in != null: return
	_tick_visual(delta)
	if hit_flash_timer > 0.0:
		hit_flash_timer = maxf(0.0, hit_flash_timer - delta)
		queue_redraw()
	if field_build_remaining > 0.0: return
	if _tick_status(delta): return
	if order == "hold":
		if position.distance_to(hold_position) > 6.0:
			_move_toward(hold_position, delta, 4.0)
			return
		var held_enemy: Node2D = game.nearest_enemy(self, float(stats.get("range", 0.0)) + 22.0) if engagement != "passive" else null
		if held_enemy != null and float(stats.get("damage", 0.0)) > 0.0:
			order_attack(held_enemy, true)
			resume_order = "hold"
		return
	if order == "wall":
		if not is_instance_valid(wall_host):
			order = "idle"
			return
		var wall_enemy: Node2D = game.nearest_enemy(self, float(stats.get("range", 0.0)) + 20.0) if engagement != "passive" else null
		if wall_enemy != null and float(stats.get("damage", 0.0)) > 0.0: order_attack(wall_enemy, true)
		return
	if order == "board_wall":
		if not is_instance_valid(target) or not target is RtsBuilding or not target.is_complete() or not is_instance_valid(wall_entry_point):
			_advance_command()
			return
		if not is_instance_valid(wall_host) and not _move_toward(wall_entry_point.position, delta, 35.0): return
		wall_host = target
		position = target.position + Vector2(float(get_instance_id() % 3 - 1) * 17.0, -9.0)
		z_index = 3
		refresh_stats()
		game.navigation.invalidate_spatial_index()
		_advance_command()
		return
	if order == "assault_wall":
		if not is_instance_valid(target) or target.is_queued_for_deletion():
			_advance_command()
			return
		if _move_toward(target.position, delta, 65.0):
			order = "siege_tower_docked"
			for passenger in passengers.duplicate():
				if not is_instance_valid(passenger): continue
				passenger.garrisoned_in = null
				passenger.show()
				passenger.wall_host = target
				passenger.wall_entry_point = self
				passenger.position = target.position + Vector2(float(passenger.get_instance_id() % 3 - 1) * 17.0, -9.0)
				passenger.order_stop()
				passenger.refresh_stats()
			passengers.clear()
			game.navigation.invalidate_spatial_index()
		return
	if order == "siege_tower_docked": return
	if order == "idle":
		_process_idle_order()
		return
	if order == "attack_move":
		var nearby_enemy: Node2D
		if awareness_timer <= 0.0 and engagement != "passive":
			nearby_enemy = game.nearest_enemy(self, 110.0 if engagement == "defensive" else 155.0)
			awareness_timer = 0.24
		if nearby_enemy != null:
			var resume_point := destination
			order_attack(nearby_enemy, true)
			resume_destination = resume_point
			resume_order = "attack_move"
			return
		if movement_group != null: _move_with_group(delta)
		else: _move_toward(destination, delta, 6.0)
		if position.distance_to(destination) < 7.0: _advance_command()
		return
	if order == "patrol":
		var patrol_enemy: Node2D
		if awareness_timer <= 0.0 and engagement != "passive":
			patrol_enemy = game.nearest_enemy(self, 110.0 if engagement == "defensive" else 155.0)
			awareness_timer = 0.24
		if patrol_enemy != null:
			var resume_point := destination
			order_attack(patrol_enemy, true)
			resume_destination = resume_point
			resume_order = "patrol"
			return
		_move_toward(destination, delta, 6.0)
		if position.distance_to(destination) < 8.0:
			destination = patrol_origin if destination == patrol_destination else patrol_destination
			_reset_route()
		return
	if order == "move":
		if movement_group != null: _move_with_group(delta)
		else: _move_toward(destination, delta, 6.0)
		if position.distance_to(destination) < 7.0: _advance_command()
		return
	if order == "unload":
		if _move_toward(destination, delta, 16.0):
			ungarrison_all()
			_advance_command()
		return
	if order == "trade":
		_process_trade_order(delta)
		return
	if order == "attack_ground":
		_process_attack_ground(delta)
		return
	if order in ["supervise", "collect_tax"]:
		if not is_instance_valid(target) or target.is_queued_for_deletion() or not target is RtsBuilding or not target.is_complete():
			_advance_command()
			return
		if not _move_toward(target.position, delta, target.size().x * 0.5 + radius() + 4.0): return
		if order == "collect_tax":
			if target.tax_stockpile > 0:
				game.credit_resource(owner_id, "gold", target.tax_stockpile)
				target.tax_stockpile = 0
			_advance_command()
		return
	if order == "relic":
		if not is_instance_valid(target) or not target is RtsRelic or not target.available():
			_advance_command()
			return
		if _move_toward(target.position, delta, 18.0):
			carried_relic = target
			carried_relic.carried_by = self
			var monastery: RtsBuilding = game.find_nearest_owned_building(owner_id, "monastery", position)
			if monastery != null: issue_command("deposit_relic", Vector2.INF, monastery)
			else: _advance_command()
		return
	if order == "deposit_relic":
		if carried_relic == null or not is_instance_valid(target) or target.is_queued_for_deletion() or not target.is_complete():
			_advance_command()
			return
		if _move_toward(target.position, delta, target.size().x * 0.5 + radius() + 4.0):
			carried_relic.carried_by = null
			carried_relic.stored_in = target
			target.relics.append(carried_relic)
			carried_relic = null
			_advance_command()
		return
	if order == "gather":
		if not is_instance_valid(target):
			_continue_gather()
		elif target is RtsResource and (target.is_queued_for_deletion() or target.amount <= 0):
			_continue_gather()
		if order != "gather": return
	if not is_instance_valid(target):
		if resume_destination != Vector2.INF:
			var resume_point := resume_destination
			var next_order := resume_order
			resume_destination = Vector2.INF
			resume_order = ""
			if next_order == "patrol":
				order = "patrol"
				destination = resume_point
				_reset_route()
			else: order_attack_move(resume_point)
			return
		if resume_order == "hold":
			resume_order = ""
			order = "hold"
			return
		_advance_command()
		return
	if order == "idle": return
	if order == "garrison":
		if not target is RtsBuilding or not target.is_complete():
			_advance_command()
			return
		if not _move_toward(target.position, delta, target.size().x * 0.5 + radius() + 5.0): return
		if not target.garrison_unit(self): _advance_command()
		return
	if order == "board_transport":
		if not target is RtsUnit or not is_instance_valid(target):
			_advance_command()
			return
		if _move_toward(target.position, delta, 78.0) and not target.garrison_unit(self): _advance_command()
		return
	if order == "gather":
		_process_gather_order(delta)
		return
	if order == "build":
		if not _move_toward(target.position, delta, target.size().x * 0.6 + radius()): return
		if visual_action_timer <= 0.0: _start_visual_action("build", 0.45)
		target.advance_construction(delta * GameData.construction_multiplier(game.civilizations[owner_id]))
		if target.is_complete(): _advance_command()
		return
	if order == "field_build":
		if not target is RtsUnit or target.field_build_remaining <= 0.0:
			_advance_command()
			return
		if _move_toward(target.position, delta, target.radius() + radius() + 7.0):
			target.field_build_remaining = maxf(0.0, target.field_build_remaining - delta)
			target.queue_redraw()
			if target.field_build_remaining <= 0.0:
				target.hp = minf(target.max_hp, target.hp + target.max_hp * 0.7)
				_advance_command()
		return
	if order == "repair":
		_process_repair_order(delta)
		return
	if order == "attack": _process_attack_order(delta)

func _process_repair_order(delta: float) -> void:
	UnitWork.process_repair_order(self, delta)

func _process_attack_ground(delta: float) -> void:
	UnitCombat.process_attack_ground(self, delta)
func _tick_status(delta: float) -> bool:
	attack_timer = maxf(0.0, attack_timer - delta)
	awareness_timer = maxf(0.0, awareness_timer - delta)
	work_timer = maxf(0.0, work_timer - delta)
	charge_cooldown = maxf(0.0, charge_cooldown - delta)
	stun_timer = maxf(0.0, stun_timer - delta)
	momentum_timer = maxf(0.0, momentum_timer - delta)
	paling_timer = maxf(0.0, paling_timer - delta)
	paling_cooldown = maxf(0.0, paling_cooldown - delta)
	volley_timer = maxf(0.0, volley_timer - delta)
	volley_cooldown = maxf(0.0, volley_cooldown - delta)
	helm_timer = maxf(0.0, helm_timer - delta)
	helm_cooldown = maxf(0.0, helm_cooldown - delta)
	conversion_cooldown = maxf(0.0, conversion_cooldown - delta)
	artillery_shot_cooldown = maxf(0.0, artillery_shot_cooldown - delta)
	revealed_timer = maxf(0.0, revealed_timer - delta)
	if spirit_buff_timer > 0.0:
		spirit_buff_timer = maxf(0.0, spirit_buff_timer - delta)
		hp = minf(max_hp, hp + 2.0 * delta)
	if conversion_timer > 0.0:
		conversion_timer = maxf(0.0, conversion_timer - delta)
		if conversion_timer <= 0.0: _finish_conversion()
		return true
	if kind == "monk": _heal_ally(delta)
	if charging:
		charge_elapsed += delta
		if charge_elapsed >= 7.0: charging = false
	return stun_timer > 0.0

func _process_idle_order() -> void:
	if kind == "imperial_official":
		var taxable: RtsBuilding
		var nearest := INF
		for building in game.buildings:
			if not is_instance_valid(building) or building.owner_id != owner_id or building.tax_stockpile < 4: continue
			var distance := position.distance_squared_to(building.position)
			if distance < nearest:
				nearest = distance
				taxable = building
		if taxable != null: issue_command("collect_tax", Vector2.INF, taxable)
		return
	if engagement == "passive" or awareness_timer > 0.0: return
	awareness_timer = 0.3
	var sight := maxf(115.0, float(stats.get("range", 0.0)) + 45.0)
	if engagement == "defensive": sight = minf(sight, 110.0)
	var enemy: Node2D = game.nearest_enemy(self, sight)
	if enemy != null and stats.get("tags", []).has("military"): order_attack(enemy, true)

func _process_trade_order(delta: float) -> void:
	UnitWork.process_trade_order(self, delta)

func _process_gather_order(delta: float) -> void:
	UnitWork.process_gather_order(self, delta)

func _process_attack_order(delta: float) -> void:
	UnitCombat.process_attack_order(self, delta)

func _heal_ally(delta: float) -> void:
	UnitCombat.heal_ally(self, delta)

func _finish_conversion() -> void:
	UnitCombat.finish_conversion(self)
func _move_toward(point: Vector2, delta: float, stop_distance: float) -> bool:
	yield_request_cooldown = maxf(0.0, yield_request_cooldown - delta)
	if yield_timer > 0.0:
		yield_timer = maxf(0.0, yield_timer - delta)
		return false
	var distance := position.distance_to(point)
	if distance <= stop_distance + 0.5: return true
	if paling_timer > 0.0: paling_timer = 0.0
	if shield_timer > 0.0:
		shield_timer = 0.0
		refresh_stats()
	route_retry = maxf(0.0, route_retry - delta)
	game.navigation._ensure_current()
	if route_obstacle_revision != game.navigation.obstacle_revision:
		route_obstacle_revision = game.navigation.obstacle_revision
		route_check_pending = true
		# A newly opened route should wake up an unreachable unit immediately.
		if route.is_empty(): route_retry = 0.0
	while route_index < route.size() - 1 and position.distance_to(route[route_index]) < 2.0:
		route_index += 1
		route_best_distance = INF
		route_stalled_time = 0.0
		route_check_pending = true
	if route_check_pending and not route.is_empty():
		# Validate only the next segment. Later segments are checked as we enter
		# them, so a remote building change does not force another A* search.
		route_blocked = not game.navigation._static_segment_clear(position, route[route_index], radius(), self)
		route_check_pending = false
	var target_changed := route_goal == Vector2.INF or route_goal.distance_to(point) > RtsWorldMap.CELL_SIZE * 0.5 or not is_equal_approx(route_stop_distance, stop_distance)
	var stagger := float(get_instance_id() % 11) * 0.017
	if target_changed and route_failures > 0:
		# Backoff belongs to the failed target, not a new position it moves to.
		route_retry = minf(route_retry, 0.15 + stagger)
	var exhausted := not route.is_empty() and route_index == route.size() - 1 and position.distance_to(route[route_index]) < 0.5
	var stalled := route_stalled_time >= ROUTE_STALL_SECONDS
	var needs_route := target_changed or route.is_empty() or route_blocked or exhausted or stalled
	if needs_route and route_retry <= 0.0:
		if (stalled or exhausted or route_failures > 0) and order in ["move", "attack_move"] and point == destination and not game.navigation.can_occupy(point, radius(), self):
			# A slot can become occupied after the order was issued. Finish at
			# the nearest reachable free point instead of retrying it forever.
			point = game.navigation.nearest_walkable_point(point, radius(), self, true)
			destination = point
			distance = position.distance_to(point)
			if distance <= stop_distance + 0.5: return true
		if target_changed:
			route_failures = 0
		elif stalled or exhausted:
			route_failures += 1
		if ["gather", "build", "field_build", "repair", "attack", "garrison", "board_transport", "trade", "deposit_relic", "relic", "supervise", "collect_tax", "board_wall", "assault_wall"].has(order):
			route = game.navigation.path_to_range(position, point, stop_distance, self)
		else:
			route = game.navigation.path_between(position, point, self)
		if stalled and not route.is_empty() and game.navigation.has_fixed_unit_blocker(self, route[mini(1, route.size() - 1)]):
			var escape: PackedVector2Array = game.navigation.path_around_units(self, route[mini(1, route.size() - 1)])
			if not escape.is_empty(): route = escape
		route_index = 1 if route.size() > 1 and position.distance_to(route[0]) < 8.0 else 0
		route_goal = point
		route_stop_distance = stop_distance
		route_best_distance = position.distance_to(route[route_index]) if not route.is_empty() else INF
		route_recovery_distance = route_best_distance
		route_stalled_time = 0.0
		route_check_pending = false
		route_blocked = false
		if route.is_empty(): route_failures += 1
		# Spread retries without consuming the match RNG. Successful movement
		# resets failures; simply finding the same blocked route does not.
		route_retry = 0.15 + stagger
		if route_failures > 0:
			route_retry = minf(ROUTE_RETRY_MAX, ROUTE_RETRY_BASE * pow(2.0, mini(route_failures - 1, 3))) + stagger
	if route.is_empty(): return false
	var waypoint: Vector2 = route[route_index]
	var remaining := position.distance_to(waypoint)
	if remaining < route_best_distance - minf(2.0, maxf(0.1, effective_speed() * 0.2)):
		route_best_distance = remaining
		route_stalled_time = 0.0
		if remaining < route_recovery_distance - radius(): route_failures = 0
	else:
		route_stalled_time += delta
	var speed: float = effective_speed()
	var step := speed * delta
	if route_index == route.size() - 1: step = minf(step, maxf(0.0, distance - stop_distance))
	var old_position := position
	position = game.navigation.move_step(self, position.move_toward(waypoint, step))
	game.navigation.unit_moved(self, old_position)
	_update_facing(old_position)
	if charging: charge_distance += old_position.distance_to(position)
	position = position.clamp(Vector2(24, 24), game.world_size - Vector2(24, 24))
	_refresh_slope_visual(old_position)
	return position.distance_to(point) <= stop_distance + 0.5

func _move_with_group(delta: float) -> void:
	yield_request_cooldown = maxf(0.0, yield_request_cooldown - delta)
	if yield_timer > 0.0:
		yield_timer = maxf(0.0, yield_timer - delta)
		return
	var point := movement_group.target_for(self)
	avoidance_cooldown = maxf(0.0, avoidance_cooldown - delta)
	# Direct local steering shares the squad path. Only a genuinely stuck member
	# pays for its own A* route around a corner or a crowded gate.
	var old_position := position
	var step := effective_speed() * delta
	position = game.navigation.move_step(self, position.move_toward(point, step))
	game.navigation.unit_moved(self, old_position)
	_update_facing(old_position)
	position = position.clamp(Vector2(24, 24), game.world_size - Vector2(24, 24))
	_refresh_slope_visual(old_position)
	var remaining := position.distance_to(point)
	if group_progress_target.distance_squared_to(point) > 16.0:
		group_progress_target = point
		group_best_distance = remaining
		group_stuck_time = 0.0
	elif remaining < group_best_distance - 2.0:
		group_best_distance = remaining
		group_stuck_time = 0.0
	else:
		# Sideways jitter is not progress. Also recover when sitting on an
		# intermediate waypoint while the actual destination is still far away.
		group_stuck_time += delta

	if group_stuck_time > 1.1:
		# A member that cannot follow the shared route computes its own escape
		# path to its assigned slot. It leaves the formation until the order ends.
		movement_group = null
		_reset_route()
		_move_toward(destination, delta, 8.0)

func _refresh_slope_visual(previous_position: Vector2) -> void:
	if not game.view_mode_25d or position == previous_position: return
	if absf(game.world_map.elevation_at(position) - game.world_map.elevation_at(previous_position)) > 0.01:
		queue_redraw()

func _update_facing(previous_position: Vector2) -> void:
	if not game.view_mode_25d or previous_position.distance_squared_to(position) < 0.25: return
	var screen_move := get_viewport().get_canvas_transform().basis_xform(position - previous_position)
	var next_right := facing_right if absf(screen_move.x) < 0.5 else screen_move.x > 0.0
	var next_back := facing_back if absf(screen_move.y) < 0.5 else screen_move.y < 0.0
	if next_right != facing_right or next_back != facing_back:
		facing_right = next_right
		facing_back = next_back
		queue_redraw()

func _tick_visual(delta: float) -> void:
	visual_moving = visual_last_position != Vector2.INF and position.distance_squared_to(visual_last_position) > 0.16
	visual_last_position = position
	if visual_moving: visual_phase += delta * (11.0 if stats.get("tags", []).has("cavalry") else 8.0)
	if visual_action_timer > 0.0: visual_action_timer = maxf(0.0, visual_action_timer - delta)
	visual_redraw_timer -= delta
	if visual_moving or visual_action_timer > 0.0:
		if visual_redraw_timer <= 0.0:
			visual_redraw_timer = (0.22 if game.units.size() > 160 else 0.085) if visual_moving else 0.055
			queue_redraw()
	elif visual_action != "":
		visual_action = ""
		queue_redraw()
	elif game.selected.size() <= 12 and game.selected.has(self):
		visual_phase += delta * 1.8
		visual_idle_timer += delta
		if visual_idle_timer >= 0.14:
			visual_idle_timer = 0.0
			queue_redraw()

func _start_visual_action(action: String, duration: float) -> void:
	visual_action = action
	visual_action_length = duration
	visual_action_timer = duration
	queue_redraw()
	if owner_id == 0 and game.has_method("play_feedback"):
		game.play_feedback("attack" if action == "attack" else "gather" if action == "gather" else "build")

func _action_swing() -> float:
	if visual_action_timer <= 0.0 or visual_action_length <= 0.0: return 0.0
	return sin((1.0 - visual_action_timer / visual_action_length) * PI)

func take_damage(damage: float) -> void:
	UnitCombat.take_damage(self, damage)
func _draw() -> void:
	if game.view_mode_25d:
		_draw_isometric()
		return
	var color: Color = game.player_color(owner_id)
	var r := radius()
	var gait := sin(visual_phase) * 3.5 if visual_moving else 0.0
	var idle_bob := sin(visual_phase) * 0.7 if not visual_moving else 0.0
	var swing := _action_swing()
	draw_circle(Vector2(2, 5), r + 2.0, Color("172322", 0.53))
	draw_set_transform_matrix(Transform2D(0.0, Vector2(0, idle_bob - absf(gait) * 0.35 - swing * 1.5)))
	if stats.get("tags", []).has("naval"):
		draw_colored_polygon(PackedVector2Array([Vector2(0, -r - 5), Vector2(r - 2, -4), Vector2(r - 4, 9), Vector2(0, r + 3), Vector2(-r + 4, 9), Vector2(-r + 2, -4)]), Color("715239"))
		draw_colored_polygon(PackedVector2Array([Vector2(0, -r), Vector2(r - 6, -3), Vector2(r - 8, 6), Vector2(-r + 8, 6), Vector2(-r + 6, -3)]), color.darkened(0.18))
		draw_line(Vector2(0, -7), Vector2(0, 10), Color("e8d8aa"), 2.0)
		draw_colored_polygon(PackedVector2Array([Vector2(1, -5), Vector2(10, 2), Vector2(1, 3)]), Color("eee7cf"))
		if kind == "transport_ship": draw_string(ThemeDB.fallback_font, Vector2(-5, 8), str(passengers.size()), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
	elif stats.get("tags", []).has("siege"):
		SiegeVisual2D.draw(self, kind, r, color, swing)
	elif stats.get("tags", []).has("cavalry"):
		draw_colored_polygon(PackedVector2Array([Vector2(-r + 2, -5), Vector2(r - 5, -8), Vector2(r + 3, -2), Vector2(r - 3, 8), Vector2(-r + 1, 7)]), Color("95734e"))
		draw_circle(Vector2(r - 1, -7), 5.0, Color("a28058"))
		draw_colored_polygon(PackedVector2Array([Vector2(-8, -7), Vector2(5, -9), Vector2(8, 4), Vector2(-5, 6)]), color.darkened(0.08))
		draw_circle(Vector2(0, -3), 4.5, Color("d9bf96"))
		draw_line(Vector2(-r + 3, 3), Vector2(-r - 5, 8), Color("594233"), 2.0)
	else:
		draw_line(Vector2(-4, 5), Vector2(-5 + gait, r + 2), Color("3e342c"), 3.0)
		draw_line(Vector2(4, 5), Vector2(5 - gait, r + 2), Color("3e342c"), 3.0)
		draw_colored_polygon(PackedVector2Array([Vector2(-8, -7), Vector2(8, -7), Vector2(9, 8), Vector2(-9, 8)]), color.darkened(0.10))
		draw_circle(Vector2(0, -10), 5.5, Color("ddc59f"))
		if kind == "villager" or kind == "imperial_official":
			draw_colored_polygon(PackedVector2Array([Vector2(-7, -13), Vector2(7, -13), Vector2(4, -19), Vector2(-4, -19)]), Color("95744b"))
			draw_line(Vector2(10, 5), Vector2(14 - swing * 6, -13 - swing * 6), Color("c8a777"), 2.5)
		elif kind == "monk":
			draw_circle(Vector2(0, -11), 6.5, color.darkened(0.27))
			draw_line(Vector2(12, 7), Vector2(12, -18), Color("e2d09c"), 2.0)
			draw_line(Vector2(8, -12), Vector2(16, -12), Color("e2d09c"), 2.0)
		elif stats.get("tags", []).has("ranged"):
			draw_arc(Vector2(10, -2), 9, -PI * 0.55, PI * 0.55, 12, Color("e1d3a9"), 2.0)
			draw_line(Vector2(7, -13), Vector2(7, 9), Color("d8c9a3"), 1.5)
		else:
			draw_line(Vector2(11, 8), Vector2(12 + swing * 12, -20 + swing * 13), Color("d6d5bd"), 2.5)
			if stats.get("tags", []).has("heavy"):
				draw_colored_polygon(PackedVector2Array([Vector2(-11, -4), Vector2(-5, -8), Vector2(0, -4), Vector2(-1, 8), Vector2(-8, 9)]), Color("bbc0b8"))
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if hit_flash_timer > 0.0:
		draw_arc(Vector2.ZERO, r + 4.0, 0.0, TAU, 24, Color("ffe5ac", hit_flash_timer / 0.18), 2.0)
	if hp < max_hp:
		draw_rect(Rect2(-r, -r - 8, r * 2.0, 3), Color("422f2d"))
		draw_rect(Rect2(-r, -r - 8, r * 2.0 * clampf(hp / max_hp, 0.0, 1.0), 3), Color("82dd8b"))

func _draw_isometric() -> void:
	var color: Color = game.player_color(owner_id)
	var canvas := get_viewport().get_canvas_transform()
	var ground_lift := RtsIsoProjection.ground_lift(game, position)
	var gait := sin(visual_phase) * 3.0 if visual_moving else 0.0
	var idle_bob := sin(visual_phase) * 0.7 if not visual_moving else 0.0
	var swing := _action_swing()
	# The footprint follows the ground projection; the figure faces the screen.
	draw_set_transform_matrix(Transform2D(0.0, ground_lift))
	draw_circle(Vector2.ZERO, radius() + 3.0, Color("1c2928", 0.62))
	draw_set_transform_matrix(RtsIsoProjection.upright(canvas, ground_lift + RtsIsoProjection.world_delta(canvas, Vector2(0, idle_bob - absf(gait) * 0.35 - swing * 1.5)), game.camera.zoom.x))
	if stats.get("tags", []).has("naval"):
		draw_colored_polygon(PackedVector2Array([Vector2(-radius(), -7), Vector2(radius(), -7), Vector2(radius() * 0.65, 3), Vector2(-radius() * 0.65, 3)]), Color("765839"))
		draw_colored_polygon(PackedVector2Array([Vector2(-radius() * 0.7, -10), Vector2(radius() * 0.7, -10), Vector2(radius() * 0.45, -6), Vector2(-radius() * 0.45, -6)]), color)
		draw_line(Vector2(0, -9), Vector2(0, -26), Color("e6d3a5"), 2.0)
		draw_colored_polygon(PackedVector2Array([Vector2(1, -25), Vector2(11, -15), Vector2(1, -14)]), Color("eee4cc"))
		if kind == "transport_ship": draw_string(ThemeDB.fallback_font, Vector2(-5, -2), str(passengers.size()), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	elif stats.get("tags", []).has("siege"):
		SiegeVisual25D.draw(self, kind, radius(), color, swing)
	else:
		var body_half := 7.0 if stats.get("tags", []).has("cavalry") else 5.5
		var body_bottom := -3.0
		var body_top := -17.0 if stats.get("tags", []).has("cavalry") else -15.0
		draw_colored_polygon(PackedVector2Array([Vector2(-body_half, body_top), Vector2(body_half, body_top), Vector2(body_half + 2, body_bottom), Vector2(-body_half - 2, body_bottom)]), color.darkened(0.18))
		draw_line(Vector2(-4, body_bottom), Vector2(-5 + gait, 2), Color("302f2a"), 2.5)
		draw_line(Vector2(4, body_bottom), Vector2(5 - gait, 2), Color("302f2a"), 2.5)
		draw_circle(Vector2(0, body_top - 5), 5.0, color.darkened(0.32) if facing_back else Color("e7d1ac"))
		if not facing_back: draw_circle(Vector2(2.0 if facing_right else -2.0, body_top - 5), 1.25, Color("443a32"))
		if kind == "monk":
			draw_line(Vector2(9, -24), Vector2(9, 0), Color("e9dca6"), 2.0)
			draw_line(Vector2(5, -19), Vector2(13, -19), Color("e9dca6"), 2.0)
		elif kind == "archer" or kind == "longbow":
			draw_arc(Vector2(9 + swing * 4, -12), 8, -PI * 0.6, PI * 0.6, 12, Color("eee6c9"), 2.0)
		elif stats.get("tags", []).has("cavalry"):
			draw_colored_polygon(PackedVector2Array([Vector2(-13, -5), Vector2(12, -5), Vector2(15, 0), Vector2(-12, 0)]), Color("a1835c"))
		elif kind == "villager":
			draw_line(Vector2(8, -7), Vector2(13 - swing * 6, -19 - swing * 5), Color("d5bb8d"), 2.5)
			draw_rect(Rect2(7, -11, 6, 6), Color("b6a07a"))
		elif visual_action == "attack" and swing > 0.0:
			draw_line(Vector2(6, -8), Vector2(14 + swing * 12, -23 + swing * 12), Color("e2e0ca"), 2.4)
	draw_set_transform_matrix(RtsIsoProjection.upright(canvas, ground_lift))
	if hit_flash_timer > 0.0:
		draw_arc(Vector2(0, -16), radius() + 7.0, 0.0, TAU, 24, Color("ffe5ac", hit_flash_timer / 0.18), 2.0)
	if hp < max_hp:
		var bar_width := maxf(18.0, radius() * 2.0)
		var bar_y := SiegeVisual25D.overlay_y(kind) if stats.get("tags", []).has("siege") else -38.0
		draw_rect(Rect2(-bar_width * 0.5, bar_y, bar_width, 4), Color("422f2d"))
		draw_rect(Rect2(-bar_width * 0.5, bar_y, bar_width * clampf(hp / max_hp, 0.0, 1.0), 4), Color("82dd8b"))
	draw_set_transform_matrix(Transform2D.IDENTITY)

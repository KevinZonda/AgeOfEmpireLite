class_name RtsUnit
extends Node2D

const AUTO_GATHER_RADIUS := 180.0
const ROUTE_STALL_SECONDS := 0.9
const ROUTE_RETRY_BASE := 0.7
const ROUTE_RETRY_MAX := 4.0
const UnitVisual = preload("res://scripts/entities/visuals/unit_visual.gd")
const UnitVisualState = preload("res://scripts/entities/visuals/unit_visual_state.gd")
const UnitWork = preload("res://scripts/entities/unit_work.gd")
const UnitMovement = preload("res://scripts/entities/unit_movement.gd")
const UnitAbilities = preload("res://scripts/entities/unit_abilities.gd")
const UnitStats = preload("res://scripts/entities/unit_stats.gd")
const UnitCombat = preload("res://scripts/entities/unit_combat.gd")

var unit_visual = UnitVisual.new()
var unit_visual_state = UnitVisualState.new()
var movement = UnitMovement.new()
var abilities = UnitAbilities.new()

var game: Node2D
var owner_id := 0
var kind: String
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
var order := "idle"
var destination: Vector2:
	get: return movement.destination
	set(value): movement.destination = value
var target: Node2D
var attack_timer := 0.0
var hit_flash_timer := 0.0
var work_timer := 0.0
var farm_gain_display_amount := 0
var enclosure_timer := 5.0
var charging: bool:
	get: return movement.charging
	set(value): movement.charging = value
var charge_distance: float:
	get: return movement.charge_distance
	set(value): movement.charge_distance = value
var charge_cooldown: float:
	get: return abilities.charge_cooldown
	set(value): abilities.charge_cooldown = value
var charge_elapsed: float:
	get: return movement.charge_elapsed
	set(value): movement.charge_elapsed = value
var stun_timer: float:
	get: return abilities.stun_timer
	set(value): abilities.stun_timer = value
var momentum_timer: float:
	get: return abilities.momentum_timer
	set(value): abilities.momentum_timer = value
var resume_destination: Vector2:
	get: return movement.resume_destination
	set(value): movement.resume_destination = value
var resume_order := ""
var patrol_origin: Vector2:
	get: return movement.patrol_origin
	set(value): movement.patrol_origin = value
var patrol_destination: Vector2:
	get: return movement.patrol_destination
	set(value): movement.patrol_destination = value
var hold_position: Vector2:
	get: return movement.hold_position
	set(value): movement.hold_position = value
var stance := "aggressive"
var engagement := "aggressive"
var auto_engaged := false
var awareness_timer := 0.0
var engagement_origin := Vector2.ZERO
var gather_kind := ""
var gather_location := Vector2.ZERO
var route: PackedVector2Array:
	get: return movement.route
	set(value): movement.route = value
var route_index: int:
	get: return movement.route_index
	set(value): movement.route_index = value
var route_goal: Vector2:
	get: return movement.route_goal
	set(value): movement.route_goal = value
var route_generation: int:
	get: return movement.route_generation
	set(value): movement.route_generation = value
var route_retry: float:
	get: return movement.route_retry
	set(value): movement.route_retry = value
var route_failures: int:
	get: return movement.route_failures
	set(value): movement.route_failures = value
var route_stop_distance: float:
	get: return movement.route_stop_distance
	set(value): movement.route_stop_distance = value
var route_obstacle_revision: int:
	get: return movement.route_obstacle_revision
	set(value): movement.route_obstacle_revision = value
var route_retry_obstacle_revision: int:
	get: return movement.route_retry_obstacle_revision
	set(value): movement.route_retry_obstacle_revision = value
var route_check_pending: bool:
	get: return movement.route_check_pending
	set(value): movement.route_check_pending = value
var route_blocked: bool:
	get: return movement.route_blocked
	set(value): movement.route_blocked = value
var route_best_distance: float:
	get: return movement.route_best_distance
	set(value): movement.route_best_distance = value
var route_recovery_distance: float:
	get: return movement.route_recovery_distance
	set(value): movement.route_recovery_distance = value
var route_stalled_time: float:
	get: return movement.route_stalled_time
	set(value): movement.route_stalled_time = value
var movement_group: RtsMovementGroup:
	get: return movement.movement_group
	set(value): movement.movement_group = value
var group_stuck_time: float:
	get: return movement.group_stuck_time
	set(value): movement.group_stuck_time = value
var group_progress_target: Vector2:
	get: return movement.group_progress_target
	set(value): movement.group_progress_target = value
var group_best_distance: float:
	get: return movement.group_best_distance
	set(value): movement.group_best_distance = value
var avoidance_cooldown: float:
	get: return movement.avoidance_cooldown
	set(value): movement.avoidance_cooldown = value
var yield_timer: float:
	get: return movement.yield_timer
	set(value): movement.yield_timer = value
var yield_request_cooldown: float:
	get: return movement.yield_request_cooldown
	set(value): movement.yield_request_cooldown = value
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
var paling_timer: float:
	get: return abilities.paling_timer
	set(value): abilities.paling_timer = value
var paling_cooldown: float:
	get: return abilities.paling_cooldown
	set(value): abilities.paling_cooldown = value
var volley_timer: float:
	get: return abilities.volley_timer
	set(value): abilities.volley_timer = value
var volley_cooldown: float:
	get: return abilities.volley_cooldown
	set(value): abilities.volley_cooldown = value
var shield_timer: float:
	get: return abilities.shield_timer
	set(value): abilities.shield_timer = value
var heal_timer: float:
	get: return abilities.heal_timer
	set(value): abilities.heal_timer = value
var helm_timer: float:
	get: return abilities.helm_timer
	set(value): abilities.helm_timer = value
var helm_cooldown: float:
	get: return abilities.helm_cooldown
	set(value): abilities.helm_cooldown = value
var conversion_timer: float:
	get: return abilities.conversion_timer
	set(value): abilities.conversion_timer = value
var conversion_cooldown: float:
	get: return abilities.conversion_cooldown
	set(value): abilities.conversion_cooldown = value
var spirit_buff_timer: float:
	get: return abilities.spirit_buff_timer
	set(value): abilities.spirit_buff_timer = value
var revealed_timer: float:
	get: return abilities.revealed_timer
	set(value): abilities.revealed_timer = value
var artillery_shot_ready: bool:
	get: return abilities.artillery_shot_ready
	set(value): abilities.artillery_shot_ready = value
var artillery_shot_cooldown: float:
	get: return abilities.artillery_shot_cooldown
	set(value): abilities.artillery_shot_cooldown = value
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
	health_bar_initialized = true
	queue_redraw()

func refresh_stats(preserve_damage := true) -> void:
	UnitStats.refresh(self, preserve_damage)

func attack_damage() -> float:
	return RtsStatResolver.primary_damage(stats)

func attack_range() -> float:
	return RtsStatResolver.primary_range(stats)

func attack_cooldown() -> float:
	return RtsStatResolver.primary_cooldown(stats)

func radius() -> float:
	return float(stats["radius"])

func effective_speed() -> float:
	return float(stats["speed"]) * (1.4 if helm_timer > 0.0 else 1.0)

func gathering_amount() -> int:
	return UnitWork.gathering_amount(self)

func farm_work_speed() -> float:
	return UnitWork.farm_work_speed(self)

func gathering_per_second() -> float:
	if order == "gather" and target is RtsBuilding and target.kind == "farm":
		return float(gathering_amount()) * farm_work_speed() / (RtsBuilding.FARM_SOW_WORK + RtsBuilding.FARM_HARVEST_WORK)
	return float(gathering_amount()) / 1.1

func order_move(world_point: Vector2) -> void:
	_order_move_to(world_point, "move")

func order_attack_move(world_point: Vector2) -> void:
	_order_move_to(world_point, "attack_move")

func _prepare_command() -> void:
	resume_order = ""
	auto_engaged = false
	abilities.interrupt_command()
	movement.begin_command()

func _order_move_to(world_point: Vector2, move_order: String) -> void:
	if is_instance_valid(wall_host): leave_wall()
	if stance == "hold": stance = "aggressive"
	_prepare_command()
	abilities.paling_timer = 0.0
	order = move_order
	destination = game.navigation.nearest_walkable_point(world_point, radius(), self, true)
	target = null
	_reset_route()

func order_attack(enemy: Node2D, automatic := false) -> void:
	if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or attack_damage() <= 0.0: return
	if kind == "battering_ram" and enemy is RtsUnit: return
	if is_instance_valid(wall_host) and position.distance_to(enemy.position) > attack_range() + 35.0: leave_wall()
	_prepare_command()
	abilities.helm_timer = 0.0
	order = "attack"
	auto_engaged = automatic
	engagement_origin = position
	target = enemy
	charging = enemy is RtsUnit and (stats.get("profiles", {}).has("charge") or float(stats.get("charge_bonus", 0.0)) > 0.0) and charge_cooldown <= 0.0 and position.distance_to(enemy.position) >= 110.0 and position.distance_to(enemy.position) <= 180.0
	charge_distance = 0.0
	charge_elapsed = 0.0
	_reset_route()

func order_stop(clear_queue := true) -> void:
	if stance == "hold": stance = "aggressive"
	_prepare_command()
	if clear_queue: command_queue.clear()
	order = "wall" if is_instance_valid(wall_host) else "idle"
	target = null
	_reset_route()

func order_hold(clear_queue := true) -> void:
	order_stop(clear_queue)
	stance = "hold"
	hold_position = position
	order = "hold"

func order_patrol(world_point: Vector2, clear_queue := true) -> void:
	order_stop(clear_queue)
	stance = "aggressive"
	patrol_origin = position
	patrol_destination = game.navigation.nearest_walkable_point(world_point, radius(), self, true)
	destination = patrol_destination
	order = "patrol"

func garrison_unit(unit: RtsUnit) -> bool:
	if kind not in ["transport_ship", "battering_ram", "siege_tower"] or field_build_remaining > 0.0 or not is_instance_valid(unit) or unit.owner_id != owner_id or passengers.size() >= (10 if kind == "siege_tower" else 8) or unit.stats.get("tags", []).has("naval") or unit.stats.get("tags", []).has("siege") or unit.garrisoned_in != null: return false
	if unit.position.distance_to(position) > 100.0 or not game.navigation.boarding_clear(unit.position, position, unit): return false
	passengers.append(unit)
	unit._prepare_command()
	unit._reset_route()
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
		game.navigation.invalidate_spatial_index()
		game.fog.update_unit_display(passenger)
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
	match command["type"]:
		"assault_wall":
			if kind != "siege_tower" or not command["target"] is RtsBuilding or command["target"].kind != "stone_wall" or not game.is_enemy(owner_id, command["target"].owner_id): return false
			_prepare_command()
			target = command["target"]
			order = "assault_wall"
			_reset_route()
		"board_wall":
			if not command["target"] is RtsBuilding: return false
			var entrance := RtsSiegeRules.wall_entry(game, self, command["target"])
			if entrance == null: return false
			wall_entry_point = entrance
			_prepare_command()
			target = command["target"]
			order = "board_wall"
			_reset_route()
		"group_move", "group_attack_move":
			if command["type"] == "group_attack_move" and not stats.get("tags", []).has("military"): return false
			var group: RtsMovementGroup = command.get("group")
			if group == null: return false
			if is_instance_valid(wall_host): leave_wall()
			_prepare_command()
			movement_group = group
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
			order_patrol(command["point"], false)
		"hold": order_hold(false)
		"attack_move":
			if not stats.get("tags", []).has("military"): return false
			order_attack_move(command["point"])
		"attack_ground":
			if kind not in ["mangonel", "nest_of_bees", "trebuchet", "bombard", "cannon"]: return false
			_prepare_command()
			order = "attack_ground"
			destination = command["point"]
			target = null
			_reset_route()
		"attack":
			if not is_instance_valid(command["target"]) or command["target"].is_queued_for_deletion(): return false
			if attack_damage() <= 0.0: return false
			if kind == "battering_ram" and command["target"] is RtsUnit: return false
			order_attack(command["target"])
		"gather":
			if not ["villager", "fishing_boat"].has(kind) or not is_instance_valid(command["target"]) or command["target"].is_queued_for_deletion(): return false
			if kind == "fishing_boat" and (not command["target"] is RtsResource or command["target"].appearance != "fish"): return false
			if kind == "villager" and command["target"] is RtsResource and command["target"].appearance == "fish": return false
			return _try_order_gather(command["target"])
		"trade":
			if kind != "trader" or not command["target"] is RtsTradePost: return false
			if not is_instance_valid(trade_home) or trade_home.is_queued_for_deletion(): trade_home = game.find_nearest_owned_building(owner_id, "market", position)
			if trade_home == null: return false
			trade_post = command["target"]
			trade_returning = false
			_prepare_command()
			order = "trade"
			_reset_route()
		"supervise", "collect_tax":
			if kind != "imperial_official" or not command["target"] is RtsBuilding or command["target"].owner_id != owner_id or not command["target"].is_complete(): return false
			_prepare_command()
			order = command["type"]
			target = command["target"]
			_reset_route()
		"relic":
			if kind != "monk" or carried_relic != null or not command["target"] is RtsRelic or not command["target"].available(): return false
			_prepare_command()
			order = "relic"
			target = command["target"]
			_reset_route()
		"deposit_relic":
			if kind != "monk" or carried_relic == null or not command["target"] is RtsBuilding or command["target"].kind != "monastery" or command["target"].owner_id != owner_id: return false
			_prepare_command()
			order = "deposit_relic"
			target = command["target"]
			_reset_route()
		"build":
			if kind != "villager" or not is_instance_valid(command["target"]) or command["target"].is_queued_for_deletion() or command["target"].is_complete(): return false
			order_build(command["target"])
		"field_build":
			if not stats.get("tags", []).has("infantry") or not command["target"] is RtsUnit or command["target"].field_build_remaining <= 0.0 or command["target"].owner_id != owner_id: return false
			_prepare_command()
			order = "field_build"
			target = command["target"]
			_reset_route()
		"repair":
			if kind != "villager" or not is_instance_valid(command["target"]) or command["target"].owner_id != owner_id or not (command["target"] is RtsBuilding or command["target"] is RtsUnit and command["target"].stats.get("tags", []).has("siege")): return false
			if command["target"].hp >= command["target"].max_hp: return false
			_prepare_command()
			order = "repair"
			target = command["target"]
			_reset_route()
		"garrison":
			if not is_instance_valid(command["target"]) or command["target"].is_queued_for_deletion() or not (RtsSiegeRules.can_garrison(stats, command["target"].kind) or command["target"].kind == "landmark" and command["target"].garrison_capacity() > 0 and not stats.get("tags", []).has("siege")): return false
			remember_work()
			_prepare_command()
			order = "garrison"
			target = command["target"]
			_reset_route()
		"board_transport":
			if not command["target"] is RtsUnit or command["target"].kind not in ["transport_ship", "battering_ram", "siege_tower"] or command["target"].owner_id != owner_id or stats.get("tags", []).has("naval") or stats.get("tags", []).has("siege"): return false
			_prepare_command()
			order = "board_transport"
			target = command["target"]
			_reset_route()
		"unload":
			if kind != "transport_ship" or passengers.is_empty(): return false
			var pair: Dictionary = game.find_landing_pair(self, command["point"])
			if pair.is_empty(): return false
			_prepare_command()
			order = "unload"
			destination = pair["water"]
			landing_position = pair["land"]
			target = null
			_reset_route()
		_: return false
	return true

func _advance_command() -> void:
	_prepare_command()
	order = "wall" if is_instance_valid(wall_host) else "idle"
	target = null
	_reset_route()
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
		return position.distance_to(target.position) <= attack_range() + radius() + 8.0
	return false

func ability_availability(ability_id: String) -> Dictionary:
	return abilities.availability(self, ability_id)

func activate_ability(ability_id: String) -> bool:
	return abilities.activate(self, ability_id)

func order_gather(resource: Node2D) -> void:
	if not ["villager", "fishing_boat"].has(kind): return
	if not _try_order_gather(resource): _advance_command()

func _try_order_gather(resource: Node2D) -> bool:
	if not is_instance_valid(resource) or resource.is_queued_for_deletion(): return false
	if not ["villager", "fishing_boat"].has(kind): return false
	if resource is RtsBuilding and resource.kind == "farm" and game.farm_worker(resource, self) != null:
		resource = game.find_nearest_free_farm(owner_id, position, 190.0, self)
		if resource == null:
			order = "idle"
			target = null
			_reset_route()
			return false
	_prepare_command()
	order = "gather"
	target = resource
	farm_gain_display_amount = 0
	resume_destination = Vector2.INF
	charging = false
	gather_kind = resource.kind if resource is RtsResource else ""
	gather_location = resource.position
	_reset_route()
	return true

func remember_work() -> void:
	UnitWork.remember_work(self)

func resume_work() -> void:
	UnitWork.resume_work(self)

func _continue_gather() -> void:
	UnitWork.continue_gather(self)

func order_build(building: Node2D) -> void:
	if kind != "villager": return
	_prepare_command()
	order = "build"
	target = building
	resume_destination = Vector2.INF
	charging = false
	_reset_route()

func _reset_route() -> void:
	movement.reset_route(self)

func _process(delta: float) -> void:
	if not game.started or game.paused or game.game_over: return
	if health_bar_timer > 0.0:
		health_bar_timer = maxf(0.0, health_bar_timer - delta)
		if health_bar_timer == 0.0: queue_redraw()
	if garrisoned_in != null: return
	_tick_visual(delta)
	if hit_flash_timer > 0.0:
		hit_flash_timer = maxf(0.0, hit_flash_timer - delta)
		queue_redraw()
	if field_build_remaining > 0.0: return
	if _tick_status(delta): return
	# Garrison entry and units stationed on walls intentionally use the building
	# footprint. Other ground units must clear newly placed foundations first.
	var entering_garrison: bool = order == "garrison" and is_instance_valid(target) and target is RtsBuilding and target.is_complete() and position.distance_to(target.position) <= target.size().x * 0.5 + radius() + 5.5
	if not is_instance_valid(wall_host) and not entering_garrison and order != "siege_tower_docked" and game.navigation.recover_building_overlap(self, delta): return
	if order == "hold":
		if position.distance_to(hold_position) > 6.0:
			_move_toward(hold_position, delta, 4.0)
			return
		var held_enemy: Node2D = game.nearest_enemy(self, attack_range() + 22.0) if engagement != "passive" else null
		if held_enemy != null and attack_damage() > 0.0:
			order_attack(held_enemy, true)
			resume_order = "hold"
		return
	if order == "wall":
		if not is_instance_valid(wall_host):
			order = "idle"
			return
		var wall_enemy: Node2D = game.nearest_enemy(self, attack_range() + 20.0) if engagement != "passive" else null
		if wall_enemy != null and attack_damage() > 0.0: order_attack(wall_enemy, true)
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
				passenger.wall_host = target
				passenger.wall_entry_point = self
				passenger.position = target.position + Vector2(float(passenger.get_instance_id() % 3 - 1) * 17.0, -9.0)
				game.fog.update_unit_display(passenger)
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
	if order == "attack" and not UnitCombat.valid_attack_target(self, target): target = null
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
		if target.is_queued_for_deletion() or target.is_complete():
			_advance_command()
			return
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
	return abilities.tick(self, delta)

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
	var sight := maxf(115.0, attack_range() + 45.0)
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
	return movement.move_to(self, point, delta, stop_distance)

func _move_with_group(delta: float) -> void:
	movement.move_with_group(self, delta)

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
	unit_visual.draw(self, UnitVisualState.capture(self, unit_visual_state))

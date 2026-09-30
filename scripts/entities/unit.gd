class_name RtsUnit
extends Node2D

const AUTO_GATHER_RADIUS := 180.0
const UnitVisual = preload("res://scripts/entities/visuals/unit_visual.gd")
const UnitVisualState = preload("res://scripts/entities/visuals/unit_visual_state.gd")
const UnitWork = preload("res://scripts/entities/unit_work.gd")
const UnitMovement = preload("res://scripts/entities/unit_movement.gd")
const ROUTE_STALL_SECONDS := UnitMovement.ROUTE_STALL_SECONDS
const ROUTE_RETRY_BASE := UnitMovement.ROUTE_RETRY_BASE
const ROUTE_RETRY_MAX := UnitMovement.ROUTE_RETRY_MAX
const UnitAbilities = preload("res://scripts/entities/unit_abilities.gd")
const UnitStats = preload("res://scripts/entities/unit_stats.gd")
const UnitCombat = preload("res://scripts/entities/unit_combat.gd")
const UnitOrders = preload("res://scripts/entities/unit_orders.gd")

var unit_visual: UnitVisual = UnitVisual.new()
var unit_visual_state: UnitVisualState = UnitVisualState.new()
var movement: UnitMovement = UnitMovement.new()
var abilities: UnitAbilities = UnitAbilities.new()
var orders: UnitOrders = UnitOrders.new()

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
var order: String:
	get: return orders.order
	set(value): orders.order = value
var destination: Vector2:
	get: return movement.destination
	set(value): movement.destination = value
var target: Node2D:
	get: return orders.target
	set(value): orders.target = value
var attack_timer := 0.0
var hunt_windup := -1.0
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
var resume_order: String:
	get: return orders.resume_order
	set(value): orders.resume_order = value
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
var auto_engaged: bool:
	get: return orders.auto_engaged
	set(value): orders.auto_engaged = value
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
var command_queue: Array[Dictionary]:
	get: return orders.command_queue
	set(value): orders.command_queue = value
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
var visual_facing_world := Vector2.ZERO
var visual_phase := 0.0
var visual_moving := false
var visual_last_position := Vector2.INF
var visual_action := ""
var visual_action_timer := 0.0
var visual_action_length := 0.0
var visual_action_released := false
var visual_release_elapsed := -1.0
var visual_charge_impact := false
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
	orders.start(self, {"type": "move", "point": world_point})

func order_attack_move(world_point: Vector2) -> void:
	orders.start(self, {"type": "attack_move", "point": world_point})

func _prepare_command() -> void:
	orders.exit(self)

func _order_move_to(world_point: Vector2, move_order: String) -> void:
	if not world_point.is_finite(): return
	if is_instance_valid(wall_host): leave_wall()
	if stance == "hold": stance = "aggressive"
	_prepare_command()
	abilities.paling_timer = 0.0
	order = move_order
	destination = game.navigation.nearest_walkable_point(world_point, radius(), self, true)
	target = null

func order_attack(enemy: Node2D, automatic := false) -> void:
	if automatic: orders.engage(self, enemy)
	else: orders.start(self, {"type": "attack", "target": enemy})

func _enter_attack(enemy: Node2D, automatic: bool) -> void:
	if not UnitCombat.valid_attack_target(self, enemy) or attack_damage() <= 0.0: return
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

func order_stop(clear_queue := true) -> void:
	if stance == "hold": stance = "aggressive"
	orders.stop(self, clear_queue)

func order_hold(clear_queue := true) -> void:
	if clear_queue: orders.issue(self, {"type": "hold"}, false)
	else: orders.start(self, {"type": "hold"})

func _enter_hold() -> void:
	order_stop(false)
	stance = "hold"
	hold_position = position
	order = "hold"

func order_patrol(world_point: Vector2, clear_queue := true) -> void:
	if clear_queue: orders.issue(self, {"type": "patrol", "point": world_point}, false)
	else: orders.start(self, {"type": "patrol", "point": world_point})

func _enter_patrol(world_point: Vector2) -> void:
	order_stop(false)
	stance = "aggressive"
	patrol_origin = position
	patrol_destination = game.navigation.nearest_walkable_point(world_point, radius(), self, true)
	destination = patrol_destination
	order = "patrol"

func garrison_unit(unit: RtsUnit) -> bool:
	if kind not in ["transport_ship", "battering_ram", "siege_tower"] or field_build_remaining > 0.0 or not is_instance_valid(unit) or unit.owner_id != owner_id or passengers.size() >= (10 if kind == "siege_tower" else 8) or unit.stats.get("tags", []).has("naval") or unit.stats.get("tags", []).has("siege") or unit.garrisoned_in != null: return false
	if unit.position.distance_to(position) > 100.0 or not game.navigation.boarding_clear(unit.position, position, unit): return false
	passengers.append(unit)
	unit.enter_garrison(self)
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
	orders.issue(self, {"type": command_type, "point": world_point, "target": target_ref, "group": group}, append)

func _start_command(command: Dictionary) -> bool:
	return orders.start(self, command)

func _advance_command() -> void:
	orders.finish(self)

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
	_try_order_gather(resource)

func _try_order_gather(resource: Node2D) -> bool:
	return orders.start(self, {"type": "gather", "target": resource})

func remember_work() -> void:
	UnitWork.remember_work(self)

func resume_work() -> void:
	UnitWork.resume_work(self)

func _continue_gather() -> void:
	UnitWork.continue_gather(self)

func order_build(building: Node2D) -> void:
	orders.start(self, {"type": "build", "target": building})

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
		# Tint instead of repainting the whole figure every frame of the flash.
		if hit_flash_timer > 0.0:
			var flash := hit_flash_timer / 0.18
			self_modulate = Color(1.0 + 0.9 * flash, 1.0 + 0.75 * flash, 1.0 + 0.4 * flash)
		else:
			self_modulate = Color.WHITE
	if field_build_remaining > 0.0: return
	if _tick_status(delta): return
	# Garrison entry and units stationed on walls intentionally use the building
	# footprint. Other ground units must clear newly placed foundations first.
	var entering_garrison: bool = order == "garrison" and is_instance_valid(target) and target is RtsBuilding and target.is_complete() and position.distance_to(target.position) <= target.size().x * 0.5 + radius() + 5.5
	if not is_instance_valid(wall_host) and not entering_garrison and order != "siege_tower_docked" and game.navigation.recover_building_overlap(self, delta): return
	orders.tick(self, delta)

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
	if enemy != null and stats.get("tags", []).has("military"): orders.engage(self, enemy)

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
	_face_direction(position - previous_position)

func _face_direction(world_direction: Vector2) -> void:
	if world_direction.length_squared() < 0.25: return
	var screen_move := get_viewport().get_canvas_transform().basis_xform(world_direction)
	var previous_screen := get_viewport().get_canvas_transform().basis_xform(visual_facing_world)
	var heading_changed := roundi(screen_move.angle() / (PI / 4.0)) != roundi(previous_screen.angle() / (PI / 4.0)) or visual_facing_world.is_zero_approx()
	visual_facing_world = world_direction.normalized()
	var next_right := facing_right if absf(screen_move.x) < 0.5 else screen_move.x > 0.0
	var next_back := facing_back if absf(screen_move.y) < 0.5 else screen_move.y < 0.0
	if next_right != facing_right or next_back != facing_back or heading_changed:
		facing_right = next_right
		facing_back = next_back
		queue_redraw()

func _tick_visual(delta: float) -> void:
	visual_moving = visual_last_position != Vector2.INF and position.distance_squared_to(visual_last_position) > 0.16
	visual_last_position = position
	if not visual_moving and visual_action_timer > 0.0 and order in ["attack", "gather", "build", "repair"] and is_instance_valid(target) and not target.is_queued_for_deletion():
		_face_direction(target.position - position)
	if kind == "siege_tower" and order == "siege_tower_docked" and is_instance_valid(target):
		_face_direction(target.position - position)
	var support_active := kind == "monk" and conversion_timer > 0.0 or kind == "imperial_official" and (order in ["supervise", "collect_tax"] or visual_action == "tax") and not visual_moving
	if support_active and is_instance_valid(target): _face_direction(target.position - position)
	if visual_moving: visual_phase += delta * (11.0 if stats.get("tags", []).has("cavalry") else 8.0)
	elif support_active: visual_phase += delta * 4.0
	elif kind == "fishing_boat" and visible: visual_phase += delta * 1.8
	if visual_action_released: visual_release_elapsed += delta
	if visual_action_timer > 0.0: visual_action_timer = maxf(0.0, visual_action_timer - delta)
	if visual_action_timer <= 0.0 and visual_action != "":
		visual_action = ""
		visual_action_released = false
		visual_release_elapsed = -1.0
		visual_charge_impact = false
		queue_redraw()
	visual_redraw_timer -= delta
	if visual_moving or visual_action_timer > 0.0 or support_active:
		if visual_redraw_timer <= 0.0:
			visual_redraw_timer = (0.22 if game.units.size() > 160 else 0.085) if visual_moving else 0.055
			queue_redraw()
	elif (kind == "fishing_boat" and visible) or (game.selected.size() <= 12 and game.selected.has(self)):
		if kind != "fishing_boat" or not visible: visual_phase += delta * 1.8
		visual_idle_timer += delta
		var idle_interval := 0.085 if kind == "fishing_boat" and order == "gather" else 0.14
		if visual_idle_timer >= idle_interval:
			visual_idle_timer = 0.0
			queue_redraw()

func _start_visual_action(action: String, duration: float) -> void:
	if is_instance_valid(target) and not target.is_queued_for_deletion():
		_face_direction(target.position - position)
	elif action == "attack" and order == "attack_ground":
		_face_direction(destination - position)
	visual_action = action
	visual_action_length = duration
	visual_action_timer = duration
	visual_action_released = false
	visual_release_elapsed = -1.0
	visual_charge_impact = false
	queue_redraw()
	if action in ["attack", "hunt", "gather", "build", "repair"] and owner_id == 0 and game.has_method("play_feedback"):
		game.play_feedback("attack" if action in ["attack", "hunt"] else "gather" if action == "gather" else "build")

func _mark_visual_impact(charged := false) -> void:
	visual_action_released = true
	visual_release_elapsed = 0.0
	visual_charge_impact = charged
	queue_redraw()

func _action_swing() -> float:
	if visual_action_timer <= 0.0 or visual_action_length <= 0.0: return 0.0
	return sin((1.0 - visual_action_timer / visual_action_length) * PI)

func take_damage(damage: float) -> void:
	UnitCombat.take_damage(self, damage)

func _draw() -> void:
	unit_visual.draw(self, UnitVisualState.capture(self, unit_visual_state))

func enter_garrison(host: Node2D) -> void:
	orders.enter_garrison(self, host)

func cancel_orders() -> void:
	orders.stop(self)

func _exit_tree() -> void:
	orders.exit(self)
	command_queue.clear()

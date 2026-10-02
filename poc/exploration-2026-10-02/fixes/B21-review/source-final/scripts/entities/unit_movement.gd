extends RefCounted

# Owns movement state. Methods receive the unit without retaining a scene reference.
const ROUTE_STALL_SECONDS := 0.9
const ROUTE_RETRY_BASE := 0.7
const ROUTE_RETRY_MAX := 4.0
# Inline searches (route budget queue disabled) share a cost cap so a mass
# order spreads pathfinding across simulation steps. The cap refills with
# simulated time (SYNC_ROUTE_BUDGET_US per step's worth of delta), which also
# covers headless drivers that never advance the navigation frame. A unit
# denied by the cap retries shortly; after a few denials it searches anyway so
# nothing can starve.
const SYNC_ROUTE_BUDGET_US := 8000
const SYNC_ROUTE_STEP_SECONDS := 1.0 / 30.0
const ROUTE_DENIAL_MIN := 3
const ROUTE_DENIAL_STAGGER := 8

static var _sync_route_nav: RtsNavigation
static var _sync_route_clock := 0.0
static var _sync_route_spent_us := 0

var destination := Vector2.ZERO
var charging := false
var charge_distance := 0.0
var charge_elapsed := 0.0
var resume_destination := Vector2.INF
var patrol_origin := Vector2.ZERO
var patrol_destination := Vector2.ZERO
var hold_position := Vector2.ZERO
var route := PackedVector2Array()
var route_index := 0
var route_goal := Vector2.INF
var route_generation := 0
var route_retry := 0.0
var route_failures := 0
var route_stop_distance := -1.0
var route_obstacle_revision := -1
var route_retry_obstacle_revision := -1
var route_check_pending := false
var route_blocked := false
var route_best_distance := INF
var route_recovery_distance := INF
var route_stalled_time := 0.0
# Physical travel progress survives route retries and background path results.
var travel_stalled_time := 0.0
var travel_progress_position := Vector2.INF
var travel_progress_goal := Vector2.INF
var travel_progress_stop_distance := -1.0
var route_denials := 0
var route_clock := 0.0
var group_stuck_time := 0.0
var group_progress_target := Vector2.INF
var group_best_distance := INF
var movement_group: RtsMovementGroup
var avoidance_cooldown := 0.0
var yield_timer := 0.0
var yield_request_cooldown := 0.0

func reset_route(unit: RtsUnit) -> void:
	route_generation += 1
	if unit.game != null and unit.game.navigation != null:
		unit.game.navigation.background_jobs.cancel(unit)
		unit.game.navigation.cancel_route_request(unit)
	yield_timer = 0.0
	route.clear()
	route_index = 0
	route_goal = Vector2.INF
	route_retry = 0.0
	route_failures = 0
	route_stop_distance = -1.0
	route_obstacle_revision = -1
	route_retry_obstacle_revision = -1
	route_check_pending = false
	route_blocked = false
	route_best_distance = INF
	route_recovery_distance = INF
	route_stalled_time = 0.0
	travel_stalled_time = 0.0
	travel_progress_position = Vector2.INF
	travel_progress_goal = Vector2.INF
	travel_progress_stop_distance = -1.0

# This call does not yield. Publish displacements before spatial/visual callbacks.
func move_to(unit: RtsUnit, point: Vector2, delta: float, stop_distance: float) -> bool:
	var navigation: RtsNavigation = unit.game.navigation
	var position: Vector2 = unit.position
	var radius := unit.radius()
	route_clock += delta
	if navigation != _sync_route_nav:
		_sync_route_nav = navigation
		_sync_route_clock = route_clock
		_sync_route_spent_us = 0
	elif route_clock > _sync_route_clock:
		# Simulated time passed: refill the inline search budget.
		_sync_route_spent_us = maxi(0, _sync_route_spent_us - int((route_clock - _sync_route_clock) / SYNC_ROUTE_STEP_SECONDS * SYNC_ROUTE_BUDGET_US))
		_sync_route_clock = route_clock
	# Measure physical progress independently of replanning. Route creation can
	# clear route_stalled_time while a blocked worker remains at the same point.
	var arrived := position.distance_to(point) <= stop_distance + 0.5
	if arrived or travel_progress_goal == Vector2.INF or travel_progress_goal.distance_to(point) > RtsWorldMap.CELL_SIZE * 0.5 or not is_equal_approx(travel_progress_stop_distance, stop_distance) or position.distance_to(travel_progress_position) > 2.0:
		travel_stalled_time = 0.0
		travel_progress_position = position
		travel_progress_goal = point
		travel_progress_stop_distance = stop_distance
	else:
		travel_stalled_time += delta
	yield_request_cooldown = maxf(0.0, yield_request_cooldown - delta)
	if yield_timer > 0.0:
		yield_timer = maxf(0.0, yield_timer - delta)
		return false
	var distance := position.distance_to(point)
	if distance <= stop_distance + 0.5 and (unit.order != "board_transport" or navigation.boarding_clear(position, point, unit)):
		if navigation.route_budget_enabled and navigation.route_jobs.has_request(unit): navigation.cancel_route_request(unit)
		return true
	unit.abilities.interrupt_movement(unit)
	var speed: float = unit.effective_speed()
	route_retry = maxf(0.0, route_retry - delta)
	navigation._ensure_current()
	if route_obstacle_revision != navigation.geometry_cache.obstacle_revision:
		route_obstacle_revision = navigation.geometry_cache.obstacle_revision
		route_check_pending = true
		# Structural changes wake unreachable units immediately. Moving wildlife
		# still invalidates collision checks, but preserves failure backoff.
		if route.is_empty() and route_retry_obstacle_revision != navigation.geometry_cache.retry_obstacle_revision: route_retry = 0.0
		route_retry_obstacle_revision = navigation.geometry_cache.retry_obstacle_revision
	while route_index < route.size() - 1 and position.distance_to(route[route_index]) < 2.0:
		# A subpixel fine-grid connector can be a necessary corner turn. In
		# budgeted routes, only skip it when the advancing shortcut is safe.
		if navigation.route_budget_enabled and not navigation._static_segment_clear(position, route[route_index + 1], radius, unit): break
		route_index += 1
		route_best_distance = INF
		route_stalled_time = 0.0
		route_check_pending = true
	if route_check_pending and not route.is_empty():
		# Validate only the next segment. Later segments are checked as we enter
		# them, so a remote building change does not force another A* search.
		route_blocked = not navigation._static_segment_clear(position, route[route_index], radius, unit)
		route_check_pending = false
	var target_changed := route_goal == Vector2.INF or route_goal.distance_to(point) > RtsWorldMap.CELL_SIZE * 0.5 or not is_equal_approx(route_stop_distance, stop_distance)
	var stagger := float(unit.get_instance_id() % 11) * 0.017
	if target_changed and route_failures > 0:
		# Backoff belongs to the failed target, not a new position it moves to.
		route_retry = minf(route_retry, 0.15 + stagger)
	var exhausted := not route.is_empty() and route_index == route.size() - 1 and position.distance_to(route[route_index]) < 0.5
	var stalled := route_stalled_time >= ROUTE_STALL_SECONDS
	if navigation.background_recovery_enabled:
		if target_changed: navigation.background_jobs.cancel(unit)
		var recovery: Dictionary = navigation.background_jobs.take(unit, point, navigation)
		if not recovery.is_empty():
			var escape: PackedVector2Array = recovery.path
			if escape.size() > 1:
				route = escape
				route_index = 1
				route_best_distance = position.distance_to(route[route_index])
				route_recovery_distance = route_best_distance
				route_stalled_time = 0.0
				route_check_pending = true
				route_blocked = false
				stalled = false
				exhausted = false
			elif route_failures >= 3:
				navigation.request_passage(unit, recovery.target)
	var needs_route := target_changed or route.is_empty() or route_blocked or exhausted or stalled
	if needs_route and route_retry <= 0.0 and not (navigation.background_recovery_enabled and navigation.background_jobs.has_request(unit)):
		var budgeted := not navigation.route_budget_enabled
		var search_started := 0
		if budgeted:
			if _sync_route_spent_us >= SYNC_ROUTE_BUDGET_US and route_denials < ROUTE_DENIAL_MIN + unit.get_instance_id() % ROUTE_DENIAL_STAGGER:
				# Defer to a later step without growing failure backoff.
				route_denials += 1
				route_retry = 0.05 + stagger
				return false
			search_started = Time.get_ticks_usec()
		if (stalled or exhausted or route_failures > 0) and unit.order in ["move", "attack_move"] and point == destination and not navigation.can_occupy(point, radius, unit):
			# A slot can become occupied after the order was issued. Finish at
			# the nearest reachable free point instead of retrying it forever.
			point = navigation.nearest_walkable_point(point, radius, unit, true)
			destination = point
			distance = position.distance_to(point)
			if distance <= stop_distance + 0.5 and (unit.order != "board_transport" or navigation.boarding_clear(position, point, unit)):
				if navigation.route_budget_enabled and navigation.route_jobs.has_request(unit): navigation.cancel_route_request(unit)
				if budgeted:
					_charge_sync_route(navigation, search_started)
					route_denials = 0
				return true
		var use_range := ["gather", "build", "field_build", "repair", "attack", "attack_ground", "garrison", "board_transport", "trade", "deposit_relic", "relic", "supervise", "collect_tax", "board_wall", "assault_wall"].has(unit.order)
		var output: Dictionary = {}
		if navigation.route_budget_enabled:
			output = navigation.take_route(unit, point, stop_distance, use_range)
			if output.is_empty():
				navigation.request_route(unit, point, stop_distance, use_range)
				# Queue admission is not a failed route. Wait in place without
				# increasing failures/backoff or following a superseded route.
				return false
		if target_changed:
			route_failures = 0
		elif stalled or exhausted:
			route_failures += 1
		if navigation.route_budget_enabled:
			route = output.path
		elif use_range:
			route = navigation.path_to_range(position, point, stop_distance, unit)
		else:
			route = navigation.path_between(position, point, unit)
		var recovery_target := Vector2.INF
		var recovery_fallback := Vector2.INF
		if stalled and not route.is_empty() and navigation.has_fixed_unit_blocker(unit, route[mini(1, route.size() - 1)]):
			if navigation.background_recovery_enabled:
				recovery_target = route[mini(1, route.size() - 1)]
				if route_failures >= 3 and route.size() > 2: recovery_fallback = point
			else:
				var escape: PackedVector2Array = navigation.path_around_units(unit, route[mini(1, route.size() - 1)])
				if escape.is_empty() and route_failures >= 3 and route.size() > 2: escape = navigation.path_around_units(unit, point)
				if not escape.is_empty(): route = escape
				elif route_failures >= 3: navigation.request_passage(unit, route[mini(1, route.size() - 1)])
		route_index = 1 if route.size() > 1 and position.distance_to(route[0]) < 8.0 else 0
		route_goal = point
		route_stop_distance = stop_distance
		if recovery_target != Vector2.INF: navigation.background_jobs.request(unit, recovery_target, recovery_fallback)
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
		if budgeted:
			_charge_sync_route(navigation, search_started)
			route_denials = 0
	if route.is_empty(): return false
	var waypoint: Vector2 = route[route_index]
	var remaining := position.distance_to(waypoint)
	if remaining < route_best_distance - minf(2.0, maxf(0.1, speed * 0.2)):
		route_best_distance = remaining
		route_stalled_time = 0.0
		if remaining < route_recovery_distance - radius: route_failures = 0
	else:
		route_stalled_time += delta
	var step := speed * delta
	if route_index == route.size() - 1: step = minf(step, remaining)
	var old_position := position
	position = navigation.move_step(unit, position.move_toward(waypoint, step))
	unit.position = position
	navigation.unit_moved(unit, old_position)
	unit._update_facing(old_position)
	if charging: charge_distance += old_position.distance_to(position)
	position = position.clamp(Vector2.ONE * radius, unit.game.world_size - Vector2.ONE * radius)
	unit.position = position
	unit._refresh_slope_visual(old_position)
	return position.distance_to(point) <= stop_distance + 0.5 and (unit.order != "board_transport" or navigation.boarding_clear(position, point, unit))

func move_with_group(unit: RtsUnit, delta: float) -> void:
	var navigation: RtsNavigation = unit.game.navigation
	var position: Vector2 = unit.position
	var radius := unit.radius()
	yield_request_cooldown = maxf(0.0, yield_request_cooldown - delta)
	if yield_timer > 0.0:
		yield_timer = maxf(0.0, yield_timer - delta)
		return
	if movement_group.independent_members.has(unit.get_instance_id()):
		movement_group = null
		reset_route(unit)
		move_to(unit, destination, delta, 6.0)
		return
	var point := movement_group.target_for(unit)
	if position.distance_to(point) > 0.5: unit.abilities.interrupt_movement(unit)
	avoidance_cooldown = maxf(0.0, avoidance_cooldown - delta)
	# Direct local steering shares the squad path. Only a genuinely stuck member
	# pays for its own A* route around a corner or a crowded gate.
	var old_position := position
	var step := unit.effective_speed() * delta
	position = navigation.move_step(unit, position.move_toward(point, step))
	unit.position = position
	navigation.unit_moved(unit, old_position)
	unit._update_facing(old_position)
	position = position.clamp(Vector2.ONE * radius, unit.game.world_size - Vector2.ONE * radius)
	unit.position = position
	unit._refresh_slope_visual(old_position)
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
		reset_route(unit)
		move_to(unit, destination, delta, 8.0)


func tick_charge(delta: float) -> void:
	if charging:
		charge_elapsed += delta
		if charge_elapsed >= 7.0: charging = false

func begin_command() -> void:
	movement_group = null
	charging = false
	resume_destination = Vector2.INF

static func _charge_sync_route(navigation: RtsNavigation, started: int) -> void:
	if navigation != _sync_route_nav:
		_sync_route_nav = navigation
		_sync_route_clock = 0.0
		_sync_route_spent_us = 0
	_sync_route_spent_us += Time.get_ticks_usec() - started

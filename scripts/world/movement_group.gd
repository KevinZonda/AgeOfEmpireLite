class_name RtsMovementGroup
extends RefCounted

# One route per nearby squad. Units retain their slot until this order finishes.
const SPACING := 34.0
const CLUSTER_DISTANCE := 240.0
const MAX_MEMBERS := 12

var game: Node2D
var members: Array[RtsUnit] = []
var goal: Vector2
var route := PackedVector2Array()
var route_index := 0
var slots: Dictionary = {}
var final_destinations: Dictionary = {}
var member_route_index: Dictionary = {}
var active := false
var last_frame := -1
var last_obstacle_revision := -1
var heading := Vector2.RIGHT
var formation := "balanced"
var formation_width := 5
var corridor_cache: Dictionary = {}
var member_segments: Dictionary = {}
var requested_goal: Vector2
var member_goals: Dictionary = {}
var independent_members: Dictionary = {}
var slot_reachability: Dictionary = {}

func _init(game_ref: Node2D, squad: Array[RtsUnit], world_goal: Vector2, chosen_formation := "balanced", chosen_width := 5) -> void:
	game = game_ref
	members = squad.duplicate()
	goal = world_goal
	requested_goal = world_goal
	formation = chosen_formation if chosen_formation in ["balanced", "line", "compact", "column"] else "balanced"
	formation_width = clampi(chosen_width, 2, 8)

static func split_squads(units: Array[RtsUnit]) -> Array[Array]:
	var buckets: Dictionary = {}
	for unit in units:
		if not is_instance_valid(unit) or unit.is_queued_for_deletion(): continue
		var cell := Vector2i(floori(unit.position.x / CLUSTER_DISTANCE), floori(unit.position.y / CLUSTER_DISTANCE))
		if not buckets.has(cell): buckets[cell] = []
		buckets[cell].append(unit)
	var visited: Dictionary = {}
	var squads: Array[Array] = []
	for first in units:
		if not is_instance_valid(first) or visited.has(first.get_instance_id()): continue
		var squad: Array[RtsUnit] = [first]
		visited[first.get_instance_id()] = true
		var index := 0
		while index < squad.size():
			var seed := squad[index]
			var seed_cell := Vector2i(floori(seed.position.x / CLUSTER_DISTANCE), floori(seed.position.y / CLUSTER_DISTANCE))
			for y in range(seed_cell.y - 1, seed_cell.y + 2):
				for x in range(seed_cell.x - 1, seed_cell.x + 2):
					for candidate in buckets.get(Vector2i(x, y), []):
						if visited.has(candidate.get_instance_id()): continue
						if candidate.owner_id == seed.owner_id and candidate.stats.get("tags", []).has("naval") == seed.stats.get("tags", []).has("naval") and seed.position.distance_squared_to(candidate.position) <= CLUSTER_DISTANCE * CLUSTER_DISTANCE:
							squad.append(candidate)
							visited[candidate.get_instance_id()] = true
			index += 1
		# Keep a long army as several nearby platoons. A column of hundreds
		# would extend beyond the map and prevent its front from progressing.
		squad.sort_custom(func(a: RtsUnit, b: RtsUnit) -> bool:
			if absf(a.position.x - b.position.x) > 40.0: return a.position.x < b.position.x
			return a.position.y < b.position.y
		)
		for start_index in range(0, squad.size(), MAX_MEMBERS): squads.append(squad.slice(start_index, mini(start_index + MAX_MEMBERS, squad.size())))
	return squads

func activate() -> void:
	if active: return
	active = true
	_replan()

func _replan() -> void:
	var previous_goal := goal
	var survivors: Array[RtsUnit] = []
	for member in members:
		if is_instance_valid(member) and not member.is_queued_for_deletion(): survivors.append(member)
	members = survivors
	var center := _center(not slots.is_empty())
	if members.is_empty(): return
	var leader := members[0]
	for member in members:
		if game.navigation.can_occupy(member.position, member.radius(), member, false, false):
			leader = member
			break
	goal = game.navigation.nearest_walkable_point(requested_goal, leader.radius(), leader, false, false)
	route = game.navigation.path_between(leader.position, goal, leader, false)
	if route.is_empty() and game.navigation.can_occupy(leader.position, leader.radius(), leader, false):
		goal = game.navigation.nearest_walkable_point(goal, leader.radius(), leader, true, false)
		route = game.navigation.path_between(leader.position, goal, leader, false)
	slot_reachability.clear()
	member_goals.clear()
	independent_members.clear()
	for member in members:
		var id := member.get_instance_id()
		member_goals[id] = goal
		# Nearby bodies that fit the leader's verified route only need a
		# clear attachment to it, not another search across the entire map.
		var shares_route: bool = not route.is_empty() and member.owner_id == leader.owner_id and member.stats.get("tags", []).has("naval") == leader.stats.get("tags", []).has("naval") and member.radius() <= leader.radius() and game.navigation._static_segment_clear(member.position, leader.position, member.radius(), member, false)
		if not shares_route and game.navigation.can_occupy(member.position, member.radius(), member, false, false) and game.navigation.path_between(member.position, goal, member).is_empty():
			# Spatially close members may be across an impassable wall. They
			# retain their own reachable interpretation of the player's click.
			member_goals[id] = game.navigation.nearest_walkable_point(requested_goal, member.radius(), member, true, false)
			independent_members[id] = true
	route_index = 1 if route.size() > 1 else 0
	member_route_index.clear()
	for unit in members:
		var closest := 0
		var best := INF
		for i in route.size():
			var distance := unit.position.distance_squared_to(route[i])
			if distance < best:
				best = distance
				closest = i
		member_route_index[unit.get_instance_id()] = mini(closest + 1, maxi(0, route.size() - 1))
	last_obstacle_revision = game.navigation.obstacle_revision
	corridor_cache.clear()
	member_segments.clear()
	heading = (goal - center).normalized()
	if heading.is_zero_approx(): heading = Vector2.RIGHT
	if slots.is_empty(): _assign_slots(center)
	else:
		for unit in members:
			if unit.movement.movement_group != self: continue
			var id := unit.get_instance_id()
			if previous_goal.distance_squared_to(goal) > 1.0 or game.navigation.path_between(unit.position, final_destinations[id], unit).is_empty():
				final_destinations[id] = _free_slot(unit, member_goals[id] + slots[id])
			unit.movement.destination = final_destinations[id]

func _role_rank(unit: RtsUnit) -> int:
	var tags: Array = unit.stats.get("tags", [])
	if tags.has("cavalry"): return 0
	if tags.has("siege"): return 3
	if RtsStatResolver.primary_attack_type(unit.stats) == "ranged": return 2
	return 1

func _assign_slots(center: Vector2) -> void:
	var started := Time.get_ticks_usec() if game.navigation.profiling_enabled else 0
	var lateral := Vector2(-heading.y, heading.x)
	var ordered := members.duplicate()
	ordered.sort_custom(func(a: RtsUnit, b: RtsUnit) -> bool:
		var ar := _role_rank(a)
		var br := _role_rank(b)
		if ar != br: return ar < br
		var side_a := (a.position - center).dot(lateral)
		var side_b := (b.position - center).dot(lateral)
		if absf(side_a - side_b) > 0.1: return side_a < side_b
		return a.get_instance_id() < b.get_instance_id()
	)
	var columns := mini(formation_width, maxi(1, ceili(sqrt(float(ordered.size())))))
	var spacing := SPACING
	match formation:
		"line": columns = mini(formation_width, ordered.size())
		"compact": spacing = 26.0
		"column": columns = 2
	for unit in ordered: spacing = maxf(spacing, unit.radius() * 2.0 + 8.0)
	for i in ordered.size():
		var col := i % columns
		var row := i / columns
		slots[ordered[i].get_instance_id()] = lateral * (float(col) - float(columns - 1) * 0.5) * spacing - heading * row * spacing
	# A nearby click translates the current shape without assembling first.
	if formation == "balanced" and center.distance_to(goal) < 170.0:
		for unit in ordered:
			slots[unit.get_instance_id()] = unit.position - center
	final_destinations.clear()
	for unit in ordered:
		var id: int = unit.get_instance_id()
		final_destinations[id] = _free_slot(unit, member_goals[id] + slots[id])
	_match_slots(ordered)
	if game.navigation.profiling_enabled: game.navigation._record_profile(&"group_slots", started)

func _match_slots(ordered: Array) -> void:
	# Minimum total travel assignment prevents rear units being sent through
	# front units that have already parked. Keep the existing role bands.
	var count := ordered.size()
	var potentials: Array[float] = []
	var slot_potentials: Array[float] = []
	var occupants: Array[int] = []
	var previous: Array[int] = []
	potentials.resize(count + 1)
	slot_potentials.resize(count + 1)
	occupants.resize(count + 1)
	previous.resize(count + 1)
	var points: Array[Vector2] = []
	var offsets: Array[Vector2] = []
	for unit in ordered:
		points.append(final_destinations[unit.get_instance_id()])
		offsets.append(slots[unit.get_instance_id()])
	var compatible: Array[Array] = []
	for unit in ordered:
		var source_valid: bool = game.navigation.can_occupy(unit.position, unit.radius(), unit, false, false)
		var row: Array[bool] = []
		for j in count:
			row.append(is_equal_approx(unit.radius(), ordered[j].radius()) and (not source_valid or _slot_reachable(unit, points[j])))
		compatible.append(row)
	for i in range(1, count + 1):
		occupants[0] = i
		var column := 0
		var minimum: Array[float] = []
		minimum.resize(count + 1)
		minimum.fill(INF)
		var used: Array[bool] = []
		used.resize(count + 1)
		while true:
			used[column] = true
			var row := occupants[column]
			var delta := INF
			var next := 0
			for j in range(1, count + 1):
				if used[j]: continue
				var cost: float = ordered[row - 1].position.distance_to(points[j - 1])
				if not compatible[row - 1][j - 1]: cost += 1.0e12
				if _role_rank(ordered[row - 1]) != _role_rank(ordered[j - 1]): cost += 10000.0
				cost -= potentials[row] + slot_potentials[j]
				if cost < minimum[j]:
					minimum[j] = cost
					previous[j] = column
				if minimum[j] < delta:
					delta = minimum[j]
					next = j
			for j in range(count + 1):
				if used[j]:
					potentials[occupants[j]] += delta
					slot_potentials[j] -= delta
				else: minimum[j] -= delta
			column = next
			if occupants[column] == 0: break
		while column != 0:
			var next := previous[column]
			occupants[column] = occupants[next]
			column = next
	for j in range(1, count + 1):
		var id: int = ordered[occupants[j] - 1].get_instance_id()
		final_destinations[id] = points[j - 1]
		slots[id] = offsets[j - 1]

func _free_slot(unit: RtsUnit, desired: Vector2) -> Vector2:
	# A new foundation may cover a member. Its dedicated overlap recovery
	# runs before group movement; there is no legal starting path yet.
	var source_valid: bool = game.navigation.can_occupy(unit.position, unit.radius(), unit, false, false)
	var candidate: Vector2 = game.navigation.nearest_walkable_point(desired, unit.radius(), unit, false, false)
	if source_valid and not _slot_reachable(unit, candidate):
		candidate = member_goals[unit.get_instance_id()]
	for ring in range(25):
		for i in (1 if ring == 0 else 16):
			var point := candidate + Vector2.from_angle(TAU * i / 16.0) * ring * 12.0
			var free := true
			for other in members:
				if other == unit or not final_destinations.has(other.get_instance_id()): continue
				if point.distance_to(final_destinations[other.get_instance_id()]) < unit.radius() + other.radius() + 8.0:
					free = false
					break
			if free and game.navigation.can_occupy(point, unit.radius(), unit, false, false) and (not source_valid or _slot_reachable(unit, point)): return point
	return candidate

func _slot_reachable(unit: RtsUnit, point: Vector2) -> bool:
	# _replan already proved the member can reach this anchor with its body.
	# Reuse that route certificate for nearby slots instead of running A* for
	# every cell of the assignment matrix (up to 144 searches per platoon).
	var anchor: Vector2 = member_goals.get(unit.get_instance_id(), goal)
	var key := [unit.owner_id, unit.radius(), unit.stats.get("tags", []).has("naval"), anchor, point]
	if slot_reachability.has(key): return slot_reachability[key]
	# If the coarse route cannot certify an offset, _free_slot tries another
	# nearby point. Only the actual player goal needs the full fine fallback.
	var reachable: bool = game.navigation._static_segment_clear(anchor, point, unit.radius(), unit, false) or not game.navigation._path_between(anchor, point, unit, true, false).is_empty()
	slot_reachability[key] = reachable
	return reachable

func _center(active_only := true) -> Vector2:
	var sum := Vector2.ZERO
	var count := 0
	for unit in members:
		if is_instance_valid(unit) and not unit.is_queued_for_deletion() and unit.hp > 0 and (not active_only or unit.movement.movement_group == self):
			sum += unit.position
			count += 1
	return sum / count if count > 0 else goal

func _corridor_is_narrow(point: Vector2) -> bool:
	var point_cell: Vector2i = game.world_map.cell_at(point)
	var heading_sector := posmod(roundi(heading.angle() / (PI / 4.0)), 8)
	var cache_key := Vector3i(point_cell.x, point_cell.y, heading_sector)
	if corridor_cache.has(cache_key): return corridor_cache[cache_key]
	var representative: RtsUnit
	for member in members:
		if is_instance_valid(member) and member.movement.movement_group == self:
			representative = member
			break
	if representative == null: return false
	var grid: AStarGrid2D = game.navigation._grid_for(representative)
	var lateral := Vector2(-heading.y, heading.x)
	var open_width := 0
	for side in [-1, 1]:
		for step in range(1, 5):
			var cell: Vector2i = game.world_map.cell_at(point + lateral * side * step * RtsWorldMap.CELL_SIZE)
			if grid.is_point_solid(cell): break
			open_width += 1
	var result := open_width < 3
	corridor_cache[cache_key] = result
	return result

func _tick() -> void:
	var frame := Engine.get_process_frames()
	if frame == last_frame: return
	last_frame = frame
	if not active: activate()
	if members.is_empty(): return
	game.navigation._ensure_current()
	if game.navigation.obstacle_revision != last_obstacle_revision:
		# Wildlife anywhere on the map can change the navigation revision.
		# Invalidate geometric caches, but retain an unaffected shared route
		# and its slots instead of making every squad search again.
		corridor_cache.clear()
		member_segments.clear()
		last_obstacle_revision = game.navigation.obstacle_revision
		if not _remaining_route_clear(): _replan()
	if route.is_empty(): return
	var center := _center()
	for i in range(route_index, route.size() - 1):
		if center.distance_to(route[i]) < 65.0: route_index = i + 1
	var waypoint: Vector2 = route[route_index] if route_index < route.size() else goal
	var next_heading := (waypoint - center).normalized()
	if not next_heading.is_zero_approx(): heading = next_heading

func _remaining_route_clear() -> bool:
	if route.is_empty(): return false
	var representative: RtsUnit
	var first := route.size() - 1
	for unit in members:
		if not is_instance_valid(unit) or unit.is_queued_for_deletion() or unit.movement.movement_group != self: continue
		if representative == null: representative = unit
		first = mini(first, maxi(0, int(member_route_index.get(unit.get_instance_id(), 0)) - 1))
		if not game.navigation.can_occupy(destination_for(unit), unit.radius(), unit, false): return false
	if representative == null: return true
	# Revisit adjusted goals: a blocked or disconnected click may now be
	# reachable. Clamping an off-map click alone does not require a search.
	var clamped_goal := requested_goal.clamp(Vector2.ONE * representative.radius(), game.world_size - Vector2.ONE * representative.radius())
	if goal.distance_squared_to(clamped_goal) > 1.0: return false
	for index in range(first, route.size() - 1):
		if not game.navigation._static_segment_clear(route[index], route[index + 1], representative.radius(), representative, false): return false
	return true

func target_for(unit: RtsUnit) -> Vector2:
	_tick()
	if route.is_empty(): return destination_for(unit)
	var id := unit.get_instance_id()
	var final_point := destination_for(unit)
	# A clear final approach avoids steering a rear rank through already parked
	# front ranks, and does not cut corners just because the goal is nearby.
	if (route.size() <= 2 or unit.position.distance_to(final_point) < 200.0) and _segment_clear_for(unit, final_point): return final_point
	var index: int = clampi(member_route_index.get(id, 0), 0, route.size() - 1)
	var offset: Vector2 = slots.get(id, Vector2.ZERO)
	var formation_center := unit.position - offset
	for i in range(index, mini(route.size() - 1, index + 5)):
		if formation_center.distance_to(route[i]) < 55.0 or unit.position.distance_to(route[i]) < 35.0: index = i + 1
	member_route_index[id] = index
	var target_point := route[index]
	# Advance only onto segments the full unit can traverse. Look ahead through
	# bends instead of repeatedly backing up to an offset beside a wall.
	for next_index in range(mini(route.size() - 1, index + 4), maxi(-1, index - 3), -1):
		if next_index < route.size() - 1 and not _corridor_is_narrow(route[next_index]) and _segment_clear_for(unit, route[next_index] + offset):
			target_point = route[next_index] + offset
			break
		if _segment_clear_for(unit, route[next_index]):
			target_point = route[next_index]
			break
	return target_point

func _segment_clear_for(unit: RtsUnit, point: Vector2) -> bool:
	var id := unit.get_instance_id()
	if member_segments.has(id):
		var cached: Dictionary = member_segments[id]
		if cached["to"] == point and unit.position.distance_squared_to(Geometry2D.get_closest_point_to_segment(unit.position, cached["from"], point)) < 0.0625:
			return true
	if not game.navigation._static_segment_clear(unit.position, point, unit.radius(), unit): return false
	member_segments[id] = {"from": unit.position, "to": point}
	return true

func destination_for(unit: RtsUnit) -> Vector2:
	return final_destinations.get(unit.get_instance_id(), goal)

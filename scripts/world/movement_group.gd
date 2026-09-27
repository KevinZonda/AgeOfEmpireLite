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
var last_obstacle_signature := -1
var heading := Vector2.RIGHT
var narrow := false
var final_approach := false
var formation := "balanced"
var formation_width := 5
var corridor_cache: Dictionary = {}

func _init(game_ref: Node2D, squad: Array[RtsUnit], world_goal: Vector2, chosen_formation := "balanced", chosen_width := 5) -> void:
	game = game_ref
	members = squad.duplicate()
	goal = world_goal
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
	var survivors: Array[RtsUnit] = []
	for member in members:
		if is_instance_valid(member) and not member.is_queued_for_deletion(): survivors.append(member)
	members = survivors
	var center := _center(not slots.is_empty())
	if members.is_empty(): return
	var leader := members[0]
	for member in members:
		if member.movement_group == self:
			leader = member
			break
	goal = game.navigation.nearest_walkable_point(goal, leader.radius(), leader, false)
	route = game.navigation.path_between(center, goal, leader)
	if route.is_empty():
		goal = game.navigation.nearest_walkable_point(goal, leader.radius(), leader, true)
		route = game.navigation.path_between(center, goal, leader)
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
	last_obstacle_signature = game.navigation.obstacle_signature
	corridor_cache.clear()
	heading = (goal - center).normalized()
	if heading.is_zero_approx(): heading = Vector2.RIGHT
	_assign_slots(center)

func _role_rank(unit: RtsUnit) -> int:
	var tags: Array = unit.stats.get("tags", [])
	if tags.has("cavalry"): return 0
	if tags.has("siege"): return 3
	if unit.stats.get("attack_type", "melee") == "ranged": return 2
	return 1

func _assign_slots(center: Vector2) -> void:
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
		final_destinations[id] = game.navigation.nearest_walkable_point(goal + slots[id], unit.radius(), unit, false)

func _center(active_only := true) -> Vector2:
	var sum := Vector2.ZERO
	var count := 0
	for unit in members:
		if is_instance_valid(unit) and not unit.is_queued_for_deletion() and unit.hp > 0 and (not active_only or unit.movement_group == self):
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
		if is_instance_valid(member) and member.movement_group == self:
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

func _grid_line_clear(unit: RtsUnit, from: Vector2, to: Vector2) -> bool:
	var grid: AStarGrid2D = game.navigation._grid_for(unit)
	var samples := maxi(1, ceili(from.distance_to(to) / 20.0))
	for sample in range(1, samples + 1):
		if grid.is_point_solid(game.world_map.cell_at(from.lerp(to, float(sample) / samples))): return false
	return true

func _tick() -> void:
	var frame := Engine.get_process_frames()
	if frame == last_frame: return
	last_frame = frame
	if not active: activate()
	if members.is_empty() or route.is_empty(): return
	game.navigation._ensure_current()
	if game.navigation.obstacle_signature != last_obstacle_signature: _replan()
	if route.is_empty(): return
	var center := _center()
	while route_index < route.size() - 1 and center.distance_to(route[route_index]) < 65.0:
		route_index += 1
	var waypoint: Vector2 = route[route_index] if route_index < route.size() else goal
	final_approach = route_index >= route.size() - 1 and center.distance_to(goal) < 115.0
	var next_heading := (waypoint - center).normalized()
	if not next_heading.is_zero_approx(): heading = next_heading
	narrow = not final_approach and (_corridor_is_narrow(waypoint) or _corridor_is_narrow(center))

func target_for(unit: RtsUnit) -> Vector2:
	_tick()
	if route.is_empty(): return goal
	var id := unit.get_instance_id()
	var index: int = member_route_index.get(id, 0)
	var waypoint: Vector2 = route[index]
	var direction := (waypoint - unit.position).normalized()
	if direction.is_zero_approx(): direction = heading
	var compressed := narrow or _corridor_is_narrow(waypoint) or _corridor_is_narrow(unit.position)
	var offset: Vector2 = Vector2.ZERO if compressed else slots.get(id, Vector2.ZERO)
	var target_point: Vector2 = waypoint + offset
	if not _grid_line_clear(unit, unit.position, target_point):
		for earlier in range(index, -1, -1):
			var candidate: Vector2 = route[earlier]
			if _grid_line_clear(unit, unit.position, candidate):
				index = earlier
				target_point = candidate
				compressed = true
				break
	while index < route.size() - 1 and unit.position.distance_to(target_point) < 48.0:
		var next_index := index + 1
		waypoint = route[next_index]
		direction = (waypoint - unit.position).normalized()
		if direction.is_zero_approx(): direction = heading
		compressed = narrow or _corridor_is_narrow(waypoint) or _corridor_is_narrow(unit.position)
		offset = Vector2.ZERO if compressed else slots.get(id, Vector2.ZERO)
		var next_target: Vector2 = waypoint + offset
		if not _grid_line_clear(unit, unit.position, next_target):
			# The offset can sit beside a gate even when the path center is
			# traversable. Follow the centerline until the formation fits again.
			if _grid_line_clear(unit, unit.position, waypoint):
				index = next_index
				target_point = waypoint
			else:
				for earlier in range(index, -1, -1):
					var centerline: Vector2 = route[earlier]
					if _grid_line_clear(unit, unit.position, centerline) and unit.position.distance_to(centerline) > 12.0:
						index = earlier
						target_point = centerline
						break
			break
		index = next_index
		target_point = next_target
	member_route_index[id] = index
	if index >= route.size() - 1 and unit.position.distance_to(goal) < 115.0: return destination_for(unit)
	return target_point

func destination_for(unit: RtsUnit) -> Vector2:
	return final_destinations.get(unit.get_instance_id(), goal)

class_name RtsNavigation
extends RefCounted

# Terrain is owned by RtsWorldMap. This layer adds changing entity footprints.
const CLEARANCE := 16.0
const SPATIAL_CELL_SIZE := 64.0

var game: Node2D
var world_map: RtsWorldMap
var pathfinder := AStarGrid2D.new()
var enemy_pathfinder := AStarGrid2D.new()
var water_pathfinder := AStarGrid2D.new()
var owner_pathfinders: Array[AStarGrid2D] = []
var obstacle_signature := -1
var spatial_frame := -1
var indexed_unit_count := -1
var indexed_resource_count := -1
var max_dynamic_radius := 0.0
var units_by_cell: Dictionary = {}
var resources_by_cell: Dictionary = {}

func _init(game_ref: Node2D, map_ref: RtsWorldMap) -> void:
	game = game_ref
	world_map = map_ref

func refresh() -> void:
	obstacle_signature = _obstacle_signature()
	invalidate_spatial_index()
	owner_pathfinders.clear()
	for owner_id in game.players.size(): owner_pathfinders.append(AStarGrid2D.new())
	pathfinder = owner_pathfinders[0]
	enemy_pathfinder = owner_pathfinders[1]
	var grids: Array[AStarGrid2D] = owner_pathfinders.duplicate()
	grids.append(water_pathfinder)
	for grid in grids:
		grid.clear()
		grid.region = Rect2i(Vector2i.ZERO, world_map.grid_size)
		grid.cell_size = Vector2(RtsWorldMap.CELL_SIZE, RtsWorldMap.CELL_SIZE)
		grid.offset = Vector2.ONE * RtsWorldMap.CELL_SIZE * 0.5
		grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		grid.update()
	for y in world_map.grid_size.y:
		for x in world_map.grid_size.x:
			var cell := Vector2i(x, y)
			var center := world_map.cell_center(cell)
			if not world_map.is_walkable(center):
				for grid in owner_pathfinders: grid.set_point_solid(cell)
			if not world_map.is_navigable(center): water_pathfinder.set_point_solid(cell)
	for building in game.buildings:
		if not is_instance_valid(building) or building.is_queued_for_deletion(): continue
		var footprint := Rect2(building.position - building.size() * 0.5, building.size()).grow(CLEARANCE)
		if building.kind.ends_with("_gate") and building.is_complete():
			for owner_id in owner_pathfinders.size():
				if game.is_enemy(owner_id, building.owner_id): _mark_rect(footprint, owner_pathfinders[owner_id])
		else:
			for grid in owner_pathfinders: _mark_rect(footprint, grid)
		_mark_rect(footprint, water_pathfinder)
	for resource in game.resources:
		if not is_instance_valid(resource) or resource.is_queued_for_deletion(): continue
		for grid in grids:
			_mark_circle(resource.position, resource.radius + CLEARANCE, grid)
	for building in game.buildings:
		if not is_instance_valid(building) or building.is_queued_for_deletion() or not building.is_complete() or not building.kind.ends_with("_gate"): continue
		var first := world_map.cell_at(building.position - Vector2.ONE * RtsWorldMap.CELL_SIZE)
		var last := world_map.cell_at(building.position + Vector2.ONE * RtsWorldMap.CELL_SIZE)
		for y in range(first.y, last.y + 1):
			for x in range(first.x, last.x + 1):
				var cell := Vector2i(x, y)
				var delta: Vector2 = world_map.cell_center(cell) - building.position
				var along := absf(delta.y) if building.wall_vertical else absf(delta.x)
				var across := absf(delta.x) if building.wall_vertical else absf(delta.y)
				if along <= RtsWorldMap.CELL_SIZE * 0.55 and across <= RtsWorldMap.CELL_SIZE * 1.1 and world_map.is_walkable(world_map.cell_center(cell)):
					for owner_id in owner_pathfinders.size():
						if not game.is_enemy(owner_id, building.owner_id): owner_pathfinders[owner_id].set_point_solid(cell, false)

func _obstacle_signature() -> int:
	var signature := 0
	for building in game.buildings:
		if is_instance_valid(building) and not building.is_queued_for_deletion():
			signature = hash([signature, building.get_instance_id(), world_map.cell_at(building.position), building.is_complete()])
	for resource in game.resources:
		if is_instance_valid(resource) and not resource.is_queued_for_deletion():
			signature = hash([signature, resource.get_instance_id(), world_map.cell_at(resource.position)])
	return signature

func _ensure_current() -> void:
	if obstacle_signature != _obstacle_signature(): refresh()

func invalidate_spatial_index() -> void:
	spatial_frame = -1

func _spatial_cell(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / SPATIAL_CELL_SIZE), floori(point.y / SPATIAL_CELL_SIZE))

func _ensure_spatial_index() -> void:
	var frame := Engine.get_process_frames()
	if spatial_frame == frame and indexed_unit_count == game.units.size() and indexed_resource_count == game.resources.size(): return
	units_by_cell.clear()
	resources_by_cell.clear()
	max_dynamic_radius = 0.0
	for unit in game.units:
		if not is_instance_valid(unit) or unit.is_queued_for_deletion() or unit.garrisoned_in != null: continue
		max_dynamic_radius = maxf(max_dynamic_radius, unit.radius())
		var cell := _spatial_cell(unit.position)
		if not units_by_cell.has(cell): units_by_cell[cell] = []
		units_by_cell[cell].append(unit)
	for resource in game.resources:
		if not is_instance_valid(resource) or resource.is_queued_for_deletion(): continue
		max_dynamic_radius = maxf(max_dynamic_radius, resource.radius)
		var cell := _spatial_cell(resource.position)
		if not resources_by_cell.has(cell): resources_by_cell[cell] = []
		resources_by_cell[cell].append(resource)
	spatial_frame = frame
	indexed_unit_count = game.units.size()
	indexed_resource_count = game.resources.size()

func unit_moved(unit: RtsUnit, previous_position: Vector2) -> void:
	if spatial_frame != Engine.get_process_frames(): return
	_move_in_index(units_by_cell, unit, previous_position)

func resource_moved(resource: RtsResource, previous_position: Vector2) -> void:
	if spatial_frame != Engine.get_process_frames(): return
	_move_in_index(resources_by_cell, resource, previous_position)

func _move_in_index(index: Dictionary, entity: Node2D, previous_position: Vector2) -> void:
	var old_cell := _spatial_cell(previous_position)
	var new_cell := _spatial_cell(entity.position)
	if old_cell == new_cell: return
	if index.has(old_cell): index[old_cell].erase(entity)
	if not index.has(new_cell): index[new_cell] = []
	index[new_cell].append(entity)

func _mark_rect(area: Rect2, grid: AStarGrid2D) -> void:
	var first := world_map.cell_at(area.position)
	var last := world_map.cell_at(area.end)
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			var cell := Vector2i(x, y)
			var center := world_map.cell_center(cell)
			if area.has_point(center): grid.set_point_solid(cell)

func _mark_circle(center: Vector2, radius: float, grid: AStarGrid2D) -> void:
	var first := world_map.cell_at(center - Vector2.ONE * radius)
	var last := world_map.cell_at(center + Vector2.ONE * radius)
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			var cell := Vector2i(x, y)
			if center.distance_to(world_map.cell_center(cell)) < radius:
				grid.set_point_solid(cell)

func _grid_for(unit: RtsUnit) -> AStarGrid2D:
	if unit != null and unit.stats.get("tags", []).has("naval"): return water_pathfinder
	if unit != null and unit.owner_id >= 0 and unit.owner_id < owner_pathfinders.size(): return owner_pathfinders[unit.owner_id]
	return pathfinder

func nearest_open_cell(point: Vector2, grid: AStarGrid2D = null) -> Vector2i:
	if grid == null: grid = pathfinder
	var origin := world_map.cell_at(point)
	if not grid.is_point_solid(origin): return origin
	var best := Vector2i(-1, -1)
	var best_distance := INF
	for radius in range(1, maxi(world_map.grid_size.x, world_map.grid_size.y)):
		for y in range(maxi(0, origin.y - radius), mini(world_map.grid_size.y - 1, origin.y + radius) + 1):
			for x in range(maxi(0, origin.x - radius), mini(world_map.grid_size.x - 1, origin.x + radius) + 1):
				if absi(x - origin.x) != radius and absi(y - origin.y) != radius: continue
				var cell := Vector2i(x, y)
				if grid.is_point_solid(cell): continue
				var distance := point.distance_squared_to(world_map.cell_center(cell))
				if distance < best_distance:
					best = cell
					best_distance = distance
		if best.x >= 0: return best
	return origin

func path_between(from: Vector2, to: Vector2, unit: RtsUnit = null) -> PackedVector2Array:
	_ensure_current()
	var grid := _grid_for(unit)
	var start := nearest_open_cell(from, grid)
	var end := nearest_open_cell(to, grid)
	if grid.is_point_solid(start) or grid.is_point_solid(end): return PackedVector2Array()
	return grid.get_point_path(start, end)

func path_to_range(from: Vector2, target: Vector2, reach: float, unit: RtsUnit) -> PackedVector2Array:
	_ensure_current()
	var grid := _grid_for(unit)
	var start := nearest_open_cell(from, grid)
	if grid.is_point_solid(start): return PackedVector2Array()
	var direction := (from - target).normalized()
	if direction.is_zero_approx(): direction = Vector2.RIGHT
	for offset in [0.0, PI / 4.0, -PI / 4.0, PI / 2.0, -PI / 2.0, 3.0 * PI / 4.0, -3.0 * PI / 4.0, PI]:
		var approach := target + direction.rotated(offset) * maxf(0.0, reach - 0.25)
		if not can_occupy(approach, unit.radius(), unit): continue
		var end := nearest_open_cell(approach, grid)
		if grid.is_point_solid(end) or not _segment_clear(world_map.cell_center(end), approach, unit.radius(), unit): continue
		var candidate := grid.get_point_path(start, end)
		if candidate.is_empty(): continue
		candidate.append(approach)
		return candidate
	return PackedVector2Array()

func nearest_walkable_point(point: Vector2, radius := CLEARANCE, self_unit: RtsUnit = null, require_path := false) -> Vector2:
	_ensure_current()
	var grid := _grid_for(self_unit)
	var clamped := point.clamp(Vector2(24, 24), world_map.world_size - Vector2(24, 24))
	var start := nearest_open_cell(self_unit.position, grid) if require_path and self_unit != null else Vector2i(-1, -1)
	if _valid_destination(clamped, radius, self_unit, start, grid): return clamped
	for ring in range(1, 17):
		for i in 16:
			var candidate := clamped + Vector2.from_angle(TAU * i / 16.0) * ring * maxf(radius, 12.0)
			if _valid_destination(candidate, radius, self_unit, start, grid): return candidate
	if start.x >= 0:
		var best := Vector2.INF
		var best_distance := INF
		for y in world_map.grid_size.y:
			for x in world_map.grid_size.x:
				var cell := Vector2i(x, y)
				if grid.is_point_solid(cell): continue
				var candidate := world_map.cell_center(cell)
				var distance := candidate.distance_squared_to(clamped)
				if distance >= best_distance or not can_occupy(candidate, radius, self_unit): continue
				if grid.get_id_path(start, cell).is_empty(): continue
				best = candidate
				best_distance = distance
		if best != Vector2.INF: return best
	return world_map.cell_center(nearest_open_cell(clamped, grid))

func _valid_destination(point: Vector2, radius: float, self_unit: RtsUnit, start: Vector2i, grid: AStarGrid2D) -> bool:
	if not can_occupy(point, radius, self_unit): return false
	if start.x < 0: return true
	var end := world_map.cell_at(point)
	if grid.is_point_solid(end) or grid.get_id_path(start, end).is_empty(): return false
	return _segment_clear(world_map.cell_center(end), point, radius, self_unit)

func _segment_clear(from: Vector2, to: Vector2, radius: float, self_unit: RtsUnit) -> bool:
	var samples := maxi(1, ceili(from.distance_to(to) / maxf(1.0, radius * 0.5)))
	for i in range(samples + 1):
		if not can_occupy(from.lerp(to, float(i) / samples), radius, self_unit): return false
	return true

func move_step(unit: RtsUnit, desired_position: Vector2) -> Vector2:
	var movement := desired_position - unit.position
	if movement.is_zero_approx(): return unit.position
	var direction := movement.normalized()
	var distance := movement.length()
	var side := 1.0 if unit.get_instance_id() % 2 == 0 else -1.0
	var candidates := [direction, direction.rotated(side * PI / 4.0), direction.rotated(-side * PI / 4.0), direction.rotated(side * PI / 2.0), direction.rotated(-side * PI / 2.0), direction.rotated(side * PI * 0.75), direction.rotated(-side * PI * 0.75)]
	for candidate_direction in candidates:
		var candidate: Vector2 = unit.position + candidate_direction * distance
		if _motion_clear(unit, candidate): return candidate
	return unit.position

func _motion_clear(unit: RtsUnit, destination: Vector2) -> bool:
	var samples := maxi(1, ceili(unit.position.distance_to(destination) / maxf(1.0, unit.radius() * 0.5)))
	for i in range(1, samples + 1):
		var fraction := float(i) / samples
		if not can_occupy(unit.position.lerp(destination, fraction), unit.radius(), unit): return false
	return true

func can_occupy(point: Vector2, radius: float, self_unit: RtsUnit) -> bool:
	_ensure_spatial_index()
	if point.x < radius or point.y < radius or point.x > world_map.world_size.x - radius or point.y > world_map.world_size.y - radius: return false
	for sample in 9:
		var offset := Vector2.ZERO if sample == 0 else Vector2.from_angle(TAU * (sample - 1) / 8.0) * radius
		if self_unit != null and self_unit.stats.get("tags", []).has("naval"):
			if not world_map.is_navigable(point + offset): return false
		elif not world_map.is_walkable(point + offset): return false
	for building in game.buildings:
		if not is_instance_valid(building) or building.is_queued_for_deletion(): continue
		if self_unit != null and not game.is_enemy(self_unit.owner_id, building.owner_id) and building.kind.ends_with("_gate") and building.is_complete(): continue
		if Rect2(building.position - building.size() * 0.5, building.size()).grow(radius).has_point(point): return false
	var center_cell := _spatial_cell(point)
	var search_radius := ceili((radius + max_dynamic_radius) / SPATIAL_CELL_SIZE)
	for y in range(center_cell.y - search_radius, center_cell.y + search_radius + 1):
		for x in range(center_cell.x - search_radius, center_cell.x + search_radius + 1):
			var cell := Vector2i(x, y)
			for resource in resources_by_cell.get(cell, []):
				if not is_instance_valid(resource) or resource.is_queued_for_deletion(): continue
				if point.distance_squared_to(resource.position) < pow(radius + resource.radius, 2): return false
			for other in units_by_cell.get(cell, []):
				if not is_instance_valid(other) or other.is_queued_for_deletion() or other == self_unit: continue
				var personal_space: float = radius + other.radius()
				if self_unit != null and self_unit.owner_id == other.owner_id and self_unit.movement_group != null and other.movement_group != null:
					personal_space *= 0.8
				if point.distance_squared_to(other.position) < personal_space * personal_space:
					if self_unit == null or point.distance_squared_to(other.position) <= self_unit.position.distance_squared_to(other.position): return false
	return true

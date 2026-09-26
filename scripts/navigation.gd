class_name RtsNavigation
extends RefCounted

# Terrain is owned by RtsWorldMap. This layer adds changing entity footprints.
const CLEARANCE := 16.0
const SPATIAL_CELL_SIZE := 64.0

var game: Node2D
var world_map: RtsWorldMap
var pathfinder := AStarGrid2D.new()
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
	pathfinder.clear()
	pathfinder.region = Rect2i(Vector2i.ZERO, world_map.grid_size)
	pathfinder.cell_size = Vector2(RtsWorldMap.CELL_SIZE, RtsWorldMap.CELL_SIZE)
	pathfinder.offset = Vector2.ONE * RtsWorldMap.CELL_SIZE * 0.5
	pathfinder.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	pathfinder.update()
	for y in world_map.grid_size.y:
		for x in world_map.grid_size.x:
			var cell := Vector2i(x, y)
			if not world_map.is_walkable(world_map.cell_center(cell)):
				pathfinder.set_point_solid(cell)
	for building in game.buildings:
		if not is_instance_valid(building) or building.is_queued_for_deletion(): continue
		var footprint := Rect2(building.position - building.size() * 0.5, building.size()).grow(CLEARANCE)
		_mark_rect(footprint)
	for resource in game.resources:
		if not is_instance_valid(resource) or resource.is_queued_for_deletion(): continue
		_mark_circle(resource.position, resource.radius + CLEARANCE)

func _obstacle_signature() -> int:
	var signature := 0
	for building in game.buildings:
		if is_instance_valid(building) and not building.is_queued_for_deletion():
			signature = hash([signature, building.get_instance_id(), world_map.cell_at(building.position)])
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
		if not is_instance_valid(unit) or unit.is_queued_for_deletion(): continue
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

func _mark_rect(area: Rect2) -> void:
	var first := world_map.cell_at(area.position)
	var last := world_map.cell_at(area.end)
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			var cell := Vector2i(x, y)
			var center := world_map.cell_center(cell)
			var tile := Rect2(center - Vector2.ONE * RtsWorldMap.CELL_SIZE * 0.5, Vector2.ONE * RtsWorldMap.CELL_SIZE)
			if tile.intersects(area): pathfinder.set_point_solid(cell)

func _mark_circle(center: Vector2, radius: float) -> void:
	var first := world_map.cell_at(center - Vector2.ONE * radius)
	var last := world_map.cell_at(center + Vector2.ONE * radius)
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			var cell := Vector2i(x, y)
			var tile := Rect2(Vector2(cell) * RtsWorldMap.CELL_SIZE, Vector2.ONE * RtsWorldMap.CELL_SIZE)
			if center.distance_to(center.clamp(tile.position, tile.end)) < radius:
				pathfinder.set_point_solid(cell)

func nearest_open_cell(point: Vector2) -> Vector2i:
	var origin := world_map.cell_at(point)
	if not pathfinder.is_point_solid(origin): return origin
	var best := Vector2i(-1, -1)
	var best_distance := INF
	for radius in range(1, maxi(world_map.grid_size.x, world_map.grid_size.y)):
		for y in range(maxi(0, origin.y - radius), mini(world_map.grid_size.y - 1, origin.y + radius) + 1):
			for x in range(maxi(0, origin.x - radius), mini(world_map.grid_size.x - 1, origin.x + radius) + 1):
				if absi(x - origin.x) != radius and absi(y - origin.y) != radius: continue
				var cell := Vector2i(x, y)
				if pathfinder.is_point_solid(cell): continue
				var distance := point.distance_squared_to(world_map.cell_center(cell))
				if distance < best_distance:
					best = cell
					best_distance = distance
		if best.x >= 0: return best
	return origin

func path_between(from: Vector2, to: Vector2) -> PackedVector2Array:
	_ensure_current()
	var start := nearest_open_cell(from)
	var end := nearest_open_cell(to)
	if pathfinder.is_point_solid(start) or pathfinder.is_point_solid(end): return PackedVector2Array()
	return pathfinder.get_point_path(start, end)

func nearest_walkable_point(point: Vector2, radius := CLEARANCE, self_unit: RtsUnit = null) -> Vector2:
	_ensure_current()
	var clamped := point.clamp(Vector2(24, 24), world_map.world_size - Vector2(24, 24))
	if can_occupy(clamped, radius, self_unit): return clamped
	for ring in range(1, 9):
		for i in 16:
			var candidate := clamped + Vector2.from_angle(TAU * i / 16.0) * ring * radius * 2.0
			if can_occupy(candidate, radius, self_unit): return candidate
	return world_map.cell_center(nearest_open_cell(clamped))

func move_step(unit: RtsUnit, desired_position: Vector2) -> Vector2:
	var movement := desired_position - unit.position
	if movement.is_zero_approx(): return unit.position
	var direction := movement.normalized()
	var distance := movement.length()
	var candidates := [direction, direction.rotated(PI / 4.0), direction.rotated(-PI / 4.0), direction.rotated(PI / 2.0), direction.rotated(-PI / 2.0)]
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
		if not world_map.is_walkable(point + offset): return false
	for building in game.buildings:
		if not is_instance_valid(building) or building.is_queued_for_deletion(): continue
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
				if point.distance_squared_to(other.position) < pow(radius + other.radius(), 2):
					if self_unit == null or point.distance_squared_to(other.position) <= self_unit.position.distance_squared_to(other.position): return false
	return true

extends RefCounted

# Live collision broad phase. Geometry invalidation and movement notifications
# only invalidate/update this index; they never mutate cached search grids.
# Buckets persist within a simulation step: structural changes (register,
# unregister, garrison transitions) invalidate, movement migrates single
# buckets via unit_moved/resource_moved. A step boundary triggers one cheap
# reconcile pass per entity instead of clearing and re-bucketing everything,
# so positions changed without a movement callback still refresh next step.
const CELL_SIZE := 64.0
var spatial_frame := -1
var indexed_unit_count := -1
var indexed_resource_count := -1
var indexed_building_count := -1
var max_dynamic_radius := 0.0
var units_by_cell: Dictionary = {}
var resources_by_cell: Dictionary = {}
var buildings_by_cell: Dictionary = {}
# Last indexed bucket per entity, so step-boundary reconcile only touches
# entities whose cell actually changed. Keyed by the entity itself.
var _unit_cells: Dictionary = {}
var _resource_cells: Dictionary = {}

func invalidate() -> void:
	spatial_frame = -1

func is_current(entities: Object, frame: int) -> bool:
	# Counts are a safety net for callers that bypass invalidate(); movement
	# alone never changes them, so a reconciled index survives within a frame.
	return spatial_frame == frame and indexed_unit_count == entities.units.size() and indexed_resource_count == entities.resources.size() and indexed_building_count == entities.buildings.size()

func cell_at(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / CELL_SIZE), floori(point.y / CELL_SIZE))

func ensure_current(entities: Object, frame := -1) -> void:
	if frame == -1: frame = Engine.get_process_frames()
	if is_current(entities, frame): return
	if spatial_frame == -1 or indexed_unit_count != entities.units.size() or indexed_resource_count != entities.resources.size() or indexed_building_count != entities.buildings.size():
		rebuild(entities, frame)
	else:
		reconcile(entities, frame)

func rebuild(entities: Object, frame := -1) -> void:
	if frame == -1: frame = Engine.get_process_frames()
	units_by_cell.clear()
	resources_by_cell.clear()
	buildings_by_cell.clear()
	_unit_cells.clear()
	_resource_cells.clear()
	max_dynamic_radius = 0.0
	for unit in entities.units:
		if not is_instance_valid(unit) or unit.is_queued_for_deletion() or unit.garrisoned_in != null: continue
		max_dynamic_radius = maxf(max_dynamic_radius, unit.radius())
		var cell := cell_at(unit.position)
		if not units_by_cell.has(cell): units_by_cell[cell] = []
		units_by_cell[cell].append(unit)
		_unit_cells[unit] = cell
	for resource in entities.resources:
		if not is_instance_valid(resource) or resource.is_queued_for_deletion(): continue
		max_dynamic_radius = maxf(max_dynamic_radius, resource.radius)
		var cell := cell_at(resource.position)
		if not resources_by_cell.has(cell): resources_by_cell[cell] = []
		resources_by_cell[cell].append(resource)
		_resource_cells[resource] = cell
	for building in entities.buildings:
		if not is_instance_valid(building) or building.is_queued_for_deletion(): continue
		var bounds := Rect2(building.position - building.size() * 0.5, building.size()).grow(48.0)
		var first := cell_at(bounds.position)
		var last := cell_at(bounds.end)
		for y in range(first.y, last.y + 1):
			for x in range(first.x, last.x + 1):
				var cell := Vector2i(x, y)
				if not buildings_by_cell.has(cell): buildings_by_cell[cell] = []
				buildings_by_cell[cell].append(building)
	spatial_frame = frame
	indexed_unit_count = entities.units.size()
	indexed_resource_count = entities.resources.size()
	indexed_building_count = entities.buildings.size()

# A new frame may carry positions that changed without a movement callback.
# Reconcile migrates only those entities; everything else keeps its bucket.
func reconcile(entities: Object, frame: int) -> void:
	if _reconcile_point_index(entities.units, units_by_cell, _unit_cells, true) or _reconcile_point_index(entities.resources, resources_by_cell, _resource_cells, false):
		# A freed entity still listed by its owner cannot serve as a key anymore.
		rebuild(entities, frame)
		return
	spatial_frame = frame

func _reconcile_point_index(list: Array, buckets: Dictionary, cells: Dictionary, skip_garrisoned: bool) -> bool:
	for entity in list:
		if not is_instance_valid(entity): return true
		var indexed: bool = cells.has(entity)
		if entity.is_queued_for_deletion() or (skip_garrisoned and entity.garrisoned_in != null):
			if indexed: _remove_from_bucket(buckets, cells, entity)
			continue
		var cell := cell_at(entity.position)
		if indexed:
			var old: Vector2i = cells[entity]
			if old == cell: continue
			if buckets.has(old): buckets[old].erase(entity)
		if not buckets.has(cell): buckets[cell] = []
		# A stale previous_position must not duplicate an indexed entity.
		if not buckets[cell].has(entity): buckets[cell].append(entity)
		cells[entity] = cell
	return false

func _remove_from_bucket(buckets: Dictionary, cells: Dictionary, entity: Node2D) -> void:
	var old: Vector2i = cells[entity]
	if buckets.has(old): buckets[old].erase(entity)
	cells.erase(entity)

func _move_entity(index: Dictionary, cells: Dictionary, entity: Node2D, previous_position: Vector2) -> void:
	var old_cell := cell_at(previous_position)
	var new_cell := cell_at(entity.position)
	if old_cell == new_cell: return
	if index.has(old_cell): index[old_cell].erase(entity)
	if not index.has(new_cell): index[new_cell] = []
	# A stale previous_position after an intervening rebuild must not duplicate
	# the entity into a cell that already indexes it.
	if not index[new_cell].has(entity): index[new_cell].append(entity)
	cells[entity] = new_cell

func unit_moved(unit: RtsUnit, previous_position: Vector2, _frame := -1) -> void:
	if spatial_frame == -1: return
	# Radii only grow between rebuilds; an overestimate merely widens queries.
	max_dynamic_radius = maxf(max_dynamic_radius, unit.radius())
	_move_entity(units_by_cell, _unit_cells, unit, previous_position)

func resource_moved(resource: RtsResource, previous_position: Vector2, _frame := -1) -> void:
	if spatial_frame == -1: return
	max_dynamic_radius = maxf(max_dynamic_radius, resource.radius)
	_move_entity(resources_by_cell, _resource_cells, resource, previous_position)

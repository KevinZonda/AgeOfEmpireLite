extends RefCounted

# Live collision broad phase. Geometry invalidation and movement notifications
# only invalidate/update this index; they never mutate cached search grids.
const CELL_SIZE := 64.0
var spatial_frame := -1
var indexed_unit_count := -1
var indexed_resource_count := -1
var indexed_building_count := -1
var max_dynamic_radius := 0.0
var units_by_cell: Dictionary = {}
var resources_by_cell: Dictionary = {}
var buildings_by_cell: Dictionary = {}

func invalidate() -> void:
	spatial_frame = -1

func cell_at(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / CELL_SIZE), floori(point.y / CELL_SIZE))

func ensure_current(entities: Object, frame := -1) -> void:
	if frame == -1: frame = Engine.get_process_frames()
	if spatial_frame == frame and indexed_unit_count == entities.units.size() and indexed_resource_count == entities.resources.size() and indexed_building_count == entities.buildings.size(): return
	units_by_cell.clear()
	resources_by_cell.clear()
	buildings_by_cell.clear()
	max_dynamic_radius = 0.0
	for unit in entities.units:
		if not is_instance_valid(unit) or unit.is_queued_for_deletion() or unit.garrisoned_in != null: continue
		max_dynamic_radius = maxf(max_dynamic_radius, unit.radius())
		var cell := cell_at(unit.position)
		if not units_by_cell.has(cell): units_by_cell[cell] = []
		units_by_cell[cell].append(unit)
	for resource in entities.resources:
		if not is_instance_valid(resource) or resource.is_queued_for_deletion(): continue
		max_dynamic_radius = maxf(max_dynamic_radius, resource.radius)
		var cell := cell_at(resource.position)
		if not resources_by_cell.has(cell): resources_by_cell[cell] = []
		resources_by_cell[cell].append(resource)
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

func move_entity(index: Dictionary, entity: Node2D, previous_position: Vector2) -> void:
	var old_cell := cell_at(previous_position)
	var new_cell := cell_at(entity.position)
	if old_cell == new_cell: return
	if index.has(old_cell): index[old_cell].erase(entity)
	if not index.has(new_cell): index[new_cell] = []
	index[new_cell].append(entity)

func unit_moved(unit: RtsUnit, previous_position: Vector2, frame := -1) -> void:
	if frame == -1: frame = Engine.get_process_frames()
	if spatial_frame == frame: move_entity(units_by_cell, unit, previous_position)

func resource_moved(resource: RtsResource, previous_position: Vector2, frame := -1) -> void:
	if frame == -1: frame = Engine.get_process_frames()
	if spatial_frame == frame: move_entity(resources_by_cell, resource, previous_position)

extends RefCounted

const SegmentGeometry = preload("res://scripts/world/navigation_recovery.gd")

# Geometry cache lifetime has one owner. A geometry revision invalidates every
# derived grid/graph/component together; the structural revision alone wakes
# failed routes. Unit traffic and living wildlife positions never wake retries.
var _default_grid: AStarGrid2D
var clearance_grids: Dictionary = {}
var fine_grids: Dictionary = {}
var local_fine_grids: Array[Dictionary] = []
var grid_components: Dictionary = {}
var grid_component_sizes: Dictionary = {}
var corner_graphs: Dictionary = {}
var corner_endpoint_validity: Dictionary = {}
var corner_endpoint_bounds: Dictionary = {}
var obstacle_signature := -1
var obstacle_revision := 0
var retry_obstacle_revision := 0
var retry_obstacle_signature := -1
var obstacle_check_frame := -1

func invalidate(wake_failed_routes: bool) -> void:
	if wake_failed_routes: retry_obstacle_signature = -1
	obstacle_signature = -1
	obstacle_check_frame = -1

func rebuild(entities: Object) -> void:
	clearance_grids.clear()
	fine_grids.clear()
	local_fine_grids.clear()
	grid_components.clear()
	grid_component_sizes.clear()
	invalidate_corner_visibility()
	_default_grid = null
	obstacle_revision += 1
	obstacle_signature = signature(entities)
	var structural_signature := signature(entities, true)
	if structural_signature != retry_obstacle_signature:
		retry_obstacle_signature = structural_signature
		retry_obstacle_revision += 1
	obstacle_check_frame = Engine.get_process_frames()

func invalidate_corner_visibility() -> void:
	corner_graphs.clear()
	corner_endpoint_validity.clear()
	corner_endpoint_bounds.clear()

func wildlife_moved(previous: Vector2, position: Vector2, animal_radius: float) -> void:
	# Geometry-derived corner candidates remain stable. Only strict visibility
	# whose segment can meet either animal footprint is stale. Invalidate BOTH
	# positive and negative checks so vacating a corridor restores connectivity.
	var swept := Rect2(previous, Vector2.ZERO).expand(position)
	for key in corner_endpoint_validity:
		var area := swept.grow(animal_radius + key.y + 0.001)
		if not area.intersects(corner_endpoint_bounds[key], true): continue
		var endpoints: Dictionary = corner_endpoint_validity[key]
		for point in endpoints.keys():
			if area.has_point(point): endpoints.erase(point)
	for key in corner_graphs:
		var graph: Dictionary = corner_graphs[key]
		if not graph.has("visibility_bounds"): continue # No cached queries yet.
		var area := swept.grow(animal_radius + key.y + 0.001)
		if not area.intersects(graph.visibility_bounds, true): continue
		var points: PackedVector2Array = graph.points
		for edge in graph.edges.keys():
			if SegmentGeometry._segment_hits_rect(points[edge.x - 2], points[edge.y - 2], area): graph.edges.erase(edge)
		for anchor in graph.attachments:
			var attachment: Dictionary = graph.attachments[anchor]
			for corner in attachment.keys():
				if SegmentGeometry._segment_hits_rect(anchor, points[corner - 2], area): attachment.erase(corner)

func signature(entities: Object, ignore_resource_positions := false) -> int:
	var signature := 0
	for building in entities.buildings:
		if is_instance_valid(building) and not building.is_queued_for_deletion():
			signature = hash([signature, building.get_instance_id(), building.position, building.size(), building.owner_id, building.kind, building.is_complete()])
	for resource in entities.resources:
		if is_instance_valid(resource) and not resource.is_queued_for_deletion():
			# Living wildlife wanders every frame; animals are dynamic obstacles
			# tracked by the spatial index, not cached geometry.
			var mobile := is_mobile_wildlife(resource)
			signature = hash([signature, resource.get_instance_id(), Vector2.ZERO if ignore_resource_positions or mobile else resource.position, resource.radius, mobile])
	return signature

static func is_mobile_wildlife(resource: RtsResource) -> bool:
	return resource.appearance in ["deer", "boar", "sheep"] and resource.wildlife_hp > 0.0

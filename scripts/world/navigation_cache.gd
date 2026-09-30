extends RefCounted

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
	corner_graphs.clear()
	_default_grid = null
	obstacle_revision += 1
	obstacle_signature = signature(entities)
	var structural_signature := signature(entities, true)
	if structural_signature != retry_obstacle_signature:
		retry_obstacle_signature = structural_signature
		retry_obstacle_revision += 1
	obstacle_check_frame = Engine.get_process_frames()

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

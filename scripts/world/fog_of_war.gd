class_name RtsFogOfWar
extends Node2D

const RememberedBuildingVisual = preload("res://scripts/entities/visuals/remembered_building_visual.gd")

const UPDATE_INTERVAL := 0.15
const UNEXPLORED_COLOR := Color(0.035, 0.055, 0.065, 1.0)
const EXPLORED_COLOR := Color(0.035, 0.055, 0.065, 0.68)

var game: Node2D
var grid_size := Vector2i.ZERO
var visible_cells: Array[PackedByteArray] = []
var explored_cells: Array[PackedByteArray] = []
var mask_texture: ImageTexture
var mask_image: Image
var relief_mesh: MeshInstance2D
var update_timer := 0.0
var active := false
var mode := "enabled"
var spy_timers: Dictionary = {}
var remembered_buildings: Dictionary = {}

func setup(game_ref: Node2D) -> void:
	game = game_ref
	# Apply the final unit positions after the units have processed this frame.
	process_priority = 100
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	relief_mesh = MeshInstance2D.new()
	relief_mesh.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(relief_mesh)
	relief_mesh.hide()

func reset(new_mode := "enabled") -> void:
	_clear_building_memory()
	mode = new_mode
	spy_timers.clear()
	grid_size = game.world_map.grid_size
	var cell_count := grid_size.x * grid_size.y
	visible_cells.clear()
	explored_cells.clear()
	for owner_id in game.players.size():
		var visible := PackedByteArray()
		visible.resize(cell_count)
		visible.fill(0)
		visible_cells.append(visible)
		var explored := PackedByteArray()
		explored.resize(cell_count)
		explored.fill(1 if mode == "terrain" else 0)
		explored_cells.append(explored)
	mask_texture = null
	mask_image = null
	relief_mesh.mesh = null
	active = mode != "disabled"
	if not active:
		game.world_map.set_occlusion_fog(null)
		_update_entity_visibility()
		hide()
		if game.minimap != null: game.minimap.queue_redraw()
		return
	update_timer = UPDATE_INTERVAL
	update_visibility()
	show()

func clear() -> void:
	game.world_map.set_occlusion_fog(null)
	_clear_building_memory()
	spy_timers.clear()
	active = false
	hide()
	mask_texture = null
	mask_image = null
	visible_cells.clear()
	explored_cells.clear()

func _process(delta: float) -> void:
	if not active or not game.started or game.paused or game.game_over: return
	for owner_id in spy_timers.keys(): spy_timers[owner_id] = maxf(0.0, float(spy_timers[owner_id]) - delta)
	update_timer -= delta
	if update_timer <= 0.0:
		update_timer = UPDATE_INTERVAL
		update_visibility()
	else:
		_update_enemy_unit_display()

func _index(cell: Vector2i) -> int:
	return cell.y * grid_size.x + cell.x

func can_see(owner_id: int, point: Vector2) -> bool:
	if owner_id < 0 or owner_id >= game.players.size(): return false
	if not active: return true
	return visible_cells[owner_id][_index(game.world_map.cell_at(point))] != 0

func can_detect_unit(owner_id: int, enemy: RtsUnit) -> bool:
	if not active: return true
	if not can_see(owner_id, enemy.position): return false
	if enemy.owner_id == owner_id or enemy.revealed_timer > 0.0: return true
	var patch_index: int = game.world_map.forest_patch_at(enemy.position)
	if patch_index < 0: return true
	for observer in game.navigation.nearby_units(enemy.position, 210.0):
		if not is_instance_valid(observer) or observer.owner_id != owner_id or observer.garrisoned_in != null: continue
		if observer.position.distance_to(enemy.position) <= (145.0 if observer.kind == "scout" else 85.0): return true
		if game.world_map.forest_patch_at(observer.position) == patch_index: return true
	return false

func can_show_unit(owner_id: int, unit: RtsUnit) -> bool:
	if not can_detect_unit(owner_id, unit): return false
	if not active or unit.owner_id == owner_id: return true
	# Units render above the fog plane. Hide the figure until its drawn bounds,
	# rather than only its ground anchor, are inside current vision.
	var reach := unit.radius() + 16.0
	var top := maxf(40.0, unit.radius() + 18.0)
	var offsets := [Vector2(-reach, -top), Vector2(0, -top), Vector2(reach, -top), Vector2(-reach, 0), Vector2(reach, 0), Vector2(0, reach)]
	var origin := unit.position
	var canvas := get_viewport().get_canvas_transform()
	if game.view_mode_25d: origin += RtsIsoProjection.ground_lift(game, unit.position)
	for offset in offsets:
		var point: Vector2 = origin + (RtsIsoProjection.world_delta(canvas, offset * game.camera.zoom.x) if game.view_mode_25d else offset)
		if not can_see(owner_id, point): return false
	return true

func update_unit_display(unit: RtsUnit) -> void:
	unit.visible = unit.garrisoned_in == null and (unit.owner_id == 0 or can_show_unit(0, unit))

func update_building_display(building: RtsBuilding) -> void:
	building.visible = building.owner_id == 0 or can_see(0, building.position)

func _update_enemy_unit_display() -> void:
	var selection_may_change := false
	for unit in game.units:
		if not is_instance_valid(unit) or unit.is_queued_for_deletion() or unit.owner_id == 0: continue
		var was_visible: bool = unit.visible
		update_unit_display(unit)
		if was_visible and not unit.visible and game.selected.has(unit): selection_may_change = true
	if selection_may_change: game._prune_hidden_enemy_selection()

func is_explored(owner_id: int, point: Vector2) -> bool:
	if owner_id < 0 or owner_id >= game.players.size(): return false
	if not active: return true
	return explored_cells[owner_id][_index(game.world_map.cell_at(point))] != 0

func can_show_resource(owner_id: int, resource: RtsResource) -> bool:
	if resource.appearance in ["deer", "sheep"]: return can_see(owner_id, resource.position)
	return is_explored(owner_id, resource.position)

func reveal_enemy_villagers(owner_id: int, duration: float) -> void:
	spy_timers[owner_id] = maxf(float(spy_timers.get(owner_id, 0.0)), duration)
	update_visibility()

func update_visibility() -> void:
	if not active: return
	game.navigation.invalidate_spatial_index()
	for owner_id in game.players.size():
		var visible: PackedByteArray = visible_cells[owner_id]
		visible.fill(0)
		for unit in game.units:
			if not is_instance_valid(unit) or unit.is_queued_for_deletion() or unit.owner_id != owner_id or unit.garrisoned_in != null: continue
			var radius := 360.0 if unit.kind == "scout" else 185.0 if unit.kind == "villager" else 250.0
			if unit.kind == "scout" and game.civilizations[owner_id] == "Chinese" and game.players[owner_id].get("dynasty", "") == "Tang": radius += 70.0
			if game.world_map.is_high_ground(unit.position): radius += 65.0
			for camp in game.buildings:
				if is_instance_valid(camp) and camp.owner_id == owner_id and camp.kind == "scout_camp" and camp.position.distance_to(unit.position) <= 180.0:
					radius *= 1.3
					break
			_reveal_circle(visible, unit.position, radius)
		for building in game.buildings:
			if not is_instance_valid(building) or building.is_queued_for_deletion() or building.owner_id != owner_id: continue
			var radius := 310.0 if building.kind == "town_center" else 225.0
			if not building.is_complete(): radius *= 0.55
			_reveal_circle(visible, building.position, radius)
		if float(spy_timers.get(owner_id, 0.0)) > 0.0:
			for enemy in game.units:
				if is_instance_valid(enemy) and enemy.kind == "villager" and game.is_enemy(owner_id, enemy.owner_id): _reveal_circle(visible, enemy.position, 42.0)
		visible_cells[owner_id] = visible
	# Teams share current vision, while each player's explored map persists.
	var own_visibility := visible_cells.duplicate(true)
	for owner_id in game.players.size():
		var visible: PackedByteArray = visible_cells[owner_id]
		for ally_id in game.players.size():
			if ally_id == owner_id or game.is_enemy(owner_id, ally_id): continue
			var ally_visible: PackedByteArray = own_visibility[ally_id]
			for index in visible.size():
				if ally_visible[index] != 0: visible[index] = 1
		visible_cells[owner_id] = visible
	for owner_id in game.players.size():
		var visible: PackedByteArray = visible_cells[owner_id]
		var explored: PackedByteArray = explored_cells[owner_id]
		for index in visible.size():
			if visible[index] != 0: explored[index] = 1
		explored_cells[owner_id] = explored
	_update_building_memory()
	_update_entity_visibility()
	_update_mask()
	game._prune_hidden_enemy_selection()
	queue_redraw()
	if game.minimap != null: game.minimap.queue_redraw()

func _reveal_circle(visible: PackedByteArray, origin: Vector2, radius: float) -> void:
	var terrain_map: RtsWorldMap = game.world_map
	var first := terrain_map.cell_at(origin - Vector2.ONE * radius)
	var last := terrain_map.cell_at(origin + Vector2.ONE * radius)
	var source_cell := terrain_map.cell_at(origin)
	var limit := radius + RtsWorldMap.CELL_SIZE * 0.45
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			var cell := Vector2i(x, y)
			if visible[_index(cell)] != 0: continue
			if origin.distance_squared_to(terrain_map.cell_center(cell)) > limit * limit: continue
			if _line_of_sight(source_cell, cell): visible[_index(cell)] = 1

func _line_of_sight(from: Vector2i, to: Vector2i) -> bool:
	var x := from.x
	var y := from.y
	var dx := absi(to.x - x)
	var dy := absi(to.y - y)
	var step_x := 1 if x < to.x else -1
	var step_y := 1 if y < to.y else -1
	var error := dx - dy
	while x != to.x or y != to.y:
		var doubled := error * 2
		if doubled > -dy:
			error -= dy
			x += step_x
		if doubled < dx:
			error += dx
			y += step_y
		if x == to.x and y == to.y: return true
		if game.world_map.cells[_index(Vector2i(x, y))] == RtsWorldMap.Terrain.MOUNTAIN: return false
	return true

func _update_building_memory() -> void:
	var live_ids := {}
	for building in game.buildings:
		if not is_instance_valid(building) or building.is_queued_for_deletion() or not game.is_enemy(0, building.owner_id): continue
		var building_id: int = building.get_instance_id()
		live_ids[building_id] = true
		if can_see(0, building.position): _remember_building(building, building_id)
	for building_id in remembered_buildings.keys():
		var memory: Dictionary = remembered_buildings[building_id]
		var ghost: RememberedBuildingVisual = memory["ghost"]
		if can_see(0, memory["position"]):
			ghost.hide()
			if not live_ids.has(building_id):
				ghost.queue_free()
				remembered_buildings.erase(building_id)
		else:
			ghost.show()

func _remember_building(building: RtsBuilding, building_id: int) -> void:
	var ghost: RememberedBuildingVisual
	if remembered_buildings.has(building_id):
		ghost = remembered_buildings[building_id]["ghost"]
	else:
		ghost = RememberedBuildingVisual.new()
		ghost.name = "RememberedBuilding"
		ghost.game = game
		ghost.process_mode = Node.PROCESS_MODE_DISABLED
		ghost.hide()
		ghost.modulate = Color(0.62, 0.66, 0.69, 0.85)
		game.add_child(ghost)
	ghost.state = building.visual_snapshot()
	# Transient hit flashes and change timers never animated on the old memory node.
	ghost.state.damage_flash_timer = 0.0
	ghost.state.health_bar_timer = 0.0
	ghost.position = ghost.state.world_position
	ghost.z_index = building.z_index
	remembered_buildings[building_id] = {"ghost": ghost, "position": building.position, "owner_id": building.owner_id}
	ghost.queue_redraw()

func _clear_building_memory() -> void:
	for memory in remembered_buildings.values():
		var ghost: RememberedBuildingVisual = memory["ghost"]
		if is_instance_valid(ghost):
			ghost.hide()
			ghost.queue_free()
	remembered_buildings.clear()

func _update_entity_visibility() -> void:
	for unit in game.units:
		if not is_instance_valid(unit) or unit.is_queued_for_deletion(): continue
		update_unit_display(unit)
	for building in game.buildings:
		if not is_instance_valid(building) or building.is_queued_for_deletion(): continue
		update_building_display(building)
	for resource in game.resources:
		if not is_instance_valid(resource) or resource.is_queued_for_deletion(): continue
		resource.visible = can_show_resource(0, resource)
		resource.modulate = Color.WHITE if can_see(0, resource.position) else Color(0.42, 0.46, 0.48)
	for post in game.trade_posts:
		if is_instance_valid(post):
			post.visible = is_explored(0, post.position)
			post.modulate = Color.WHITE if can_see(0, post.position) else Color(0.42, 0.46, 0.48)
	for relic in game.relics:
		if is_instance_valid(relic): relic.visible = relic.available() and can_see(0, relic.position)

func _update_mask() -> void:
	var image := Image.create(grid_size.x, grid_size.y, false, Image.FORMAT_RGBA8)
	var visible: PackedByteArray = visible_cells[0]
	var explored: PackedByteArray = explored_cells[0]
	for y in grid_size.y:
		for x in grid_size.x:
			var index := _index(Vector2i(x, y))
			var color := Color.TRANSPARENT if visible[index] != 0 or mode == "terrain" else EXPLORED_COLOR if explored[index] != 0 else UNEXPLORED_COLOR
			image.set_pixel(x, y, color)
	if mask_texture == null:
		mask_texture = ImageTexture.create_from_image(image)
	else:
		mask_texture.update(image)
	mask_image = image
	game.world_map.set_occlusion_fog(mask_texture)
	relief_mesh.texture = mask_texture
	if game.view_mode_25d and relief_mesh.mesh == null: update_projection()
	else: queue_redraw()

func update_projection() -> void:
	if relief_mesh == null: return
	for memory in remembered_buildings.values():
		var ghost: RememberedBuildingVisual = memory["ghost"]
		ghost.z_index = clampi(roundi((ghost.position.x + ghost.position.y) * 0.5), 0, 2800) if game.view_mode_25d else 0
		ghost.queue_redraw()
	if not active or not game.view_mode_25d:
		relief_mesh.hide()
		queue_redraw()
		return
	var terrain_map: RtsWorldMap = game.world_map
	var lift := RtsIsoProjection.world_delta(get_viewport().get_canvas_transform(), Vector2(0, -game.camera.zoom.x))
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	# Fog stops at the playable boundary; the black exterior never shares vision.
	var width := grid_size.x + 1
	for y in grid_size.y + 1:
		for x in grid_size.x + 1:
			var point := Vector2(x, y) * RtsWorldMap.CELL_SIZE + lift * terrain_map._visual_vertex_height(x, y)
			vertices.append(Vector3(point.x, point.y, 0.0))
			uvs.append(Vector2(float(x) / grid_size.x, float(y) / grid_size.y))
	for y in grid_size.y:
		for x in grid_size.x:
			var nw := y * width + x
			var ne := nw + 1
			var sw := nw + width
			var se := sw + 1
			indices.append_array(PackedInt32Array([nw, ne, se, nw, se, sw]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	relief_mesh.mesh = mesh
	relief_mesh.show()
	queue_redraw()

func _draw() -> void:
	if not active or mask_texture == null: return
	if not game.view_mode_25d: draw_texture_rect(mask_texture, Rect2(Vector2.ZERO, game.world_size), false)

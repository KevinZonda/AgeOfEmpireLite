class_name RtsFogOfWar
extends Node2D

const UPDATE_INTERVAL := 0.15
const PLAYER_COUNT := 2
const UNEXPLORED_COLOR := Color(0.035, 0.055, 0.065, 1.0)
const EXPLORED_COLOR := Color(0.035, 0.055, 0.065, 0.68)

var game: Node2D
var grid_size := Vector2i.ZERO
var visible_cells: Array[PackedByteArray] = []
var explored_cells: Array[PackedByteArray] = []
var mask_texture: ImageTexture
var mask_image: Image
var update_timer := 0.0
var active := false

func setup(game_ref: Node2D) -> void:
	game = game_ref
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func reset() -> void:
	grid_size = game.world_map.grid_size
	var cell_count := grid_size.x * grid_size.y
	visible_cells.clear()
	explored_cells.clear()
	for owner_id in PLAYER_COUNT:
		var visible := PackedByteArray()
		visible.resize(cell_count)
		visible.fill(0)
		visible_cells.append(visible)
		var explored := PackedByteArray()
		explored.resize(cell_count)
		explored.fill(0)
		explored_cells.append(explored)
	mask_texture = null
	mask_image = null
	active = true
	update_timer = UPDATE_INTERVAL
	update_visibility()
	show()

func clear() -> void:
	active = false
	hide()
	mask_texture = null
	mask_image = null
	visible_cells.clear()
	explored_cells.clear()

func _process(delta: float) -> void:
	if not active or not game.started or game.paused or game.game_over: return
	update_timer -= delta
	if update_timer <= 0.0:
		update_timer = UPDATE_INTERVAL
		update_visibility()

func _index(cell: Vector2i) -> int:
	return cell.y * grid_size.x + cell.x

func can_see(owner_id: int, point: Vector2) -> bool:
	if not active or owner_id < 0 or owner_id >= PLAYER_COUNT: return false
	return visible_cells[owner_id][_index(game.world_map.cell_at(point))] != 0

func is_explored(owner_id: int, point: Vector2) -> bool:
	if not active or owner_id < 0 or owner_id >= PLAYER_COUNT: return false
	return explored_cells[owner_id][_index(game.world_map.cell_at(point))] != 0

func can_show_resource(owner_id: int, resource: RtsResource) -> bool:
	if resource.appearance == "deer": return can_see(owner_id, resource.position)
	return is_explored(owner_id, resource.position)

func update_visibility() -> void:
	if not active: return
	for owner_id in PLAYER_COUNT:
		var visible: PackedByteArray = visible_cells[owner_id]
		visible.fill(0)
		for unit in game.units:
			if not is_instance_valid(unit) or unit.is_queued_for_deletion() or unit.owner_id != owner_id or unit.garrisoned_in != null: continue
			var radius := 360.0 if unit.kind == "scout" else 185.0 if unit.kind == "villager" else 250.0
			_reveal_circle(visible, unit.position, radius)
		for building in game.buildings:
			if not is_instance_valid(building) or building.is_queued_for_deletion() or building.owner_id != owner_id: continue
			var radius := 310.0 if building.kind == "town_center" else 225.0
			if not building.is_complete(): radius *= 0.55
			_reveal_circle(visible, building.position, radius)
		visible_cells[owner_id] = visible
		var explored: PackedByteArray = explored_cells[owner_id]
		for index in visible.size():
			if visible[index] != 0: explored[index] = 1
		explored_cells[owner_id] = explored
	_update_entity_visibility()
	_update_mask()
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

func _update_entity_visibility() -> void:
	for unit in game.units:
		if not is_instance_valid(unit) or unit.is_queued_for_deletion(): continue
		unit.visible = unit.garrisoned_in == null and (unit.owner_id == 0 or can_see(0, unit.position))
	for building in game.buildings:
		if not is_instance_valid(building) or building.is_queued_for_deletion(): continue
		building.visible = building.owner_id == 0 or can_see(0, building.position)
	for resource in game.resources:
		if not is_instance_valid(resource) or resource.is_queued_for_deletion(): continue
		resource.visible = can_show_resource(0, resource)

func _update_mask() -> void:
	var image := Image.create(grid_size.x, grid_size.y, false, Image.FORMAT_RGBA8)
	var visible: PackedByteArray = visible_cells[0]
	var explored: PackedByteArray = explored_cells[0]
	for y in grid_size.y:
		for x in grid_size.x:
			var index := _index(Vector2i(x, y))
			var color := Color.TRANSPARENT if visible[index] != 0 else EXPLORED_COLOR if explored[index] != 0 else UNEXPLORED_COLOR
			image.set_pixel(x, y, color)
	if mask_texture == null:
		mask_texture = ImageTexture.create_from_image(image)
	else:
		mask_texture.update(image)
	mask_image = image

func _draw() -> void:
	if active and mask_texture != null:
		draw_texture_rect(mask_texture, Rect2(Vector2.ZERO, game.world_size), false)

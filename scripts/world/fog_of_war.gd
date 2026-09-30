class_name RtsFogOfWar
extends Node2D

const RememberedBuildingVisual = preload("res://scripts/entities/visuals/remembered_building_visual.gd")

const UPDATE_INTERVAL := 0.15
const UNEXPLORED_COLOR := Color(0.035, 0.055, 0.065, 1.0)
const EXPLORED_COLOR := Color(0.035, 0.055, 0.065, 0.68)
const SHOW_SAMPLE_OFFSETS := [Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(0, 1)]

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
# Tick-level results, recomputed by update_visibility and read every frame.
var unit_display_cache: Dictionary = {}
var _ally_snapshot: Array[PackedByteArray] = []
var _scout_camps: Dictionary = {}
var _no_camps: Array[Vector2] = []
var _mountain_prefix := PackedInt32Array()
var _mask_data := PackedByteArray()
var _unit_tick_positions: Dictionary = {}
var _unit_tick_positions_next: Dictionary = {}
var _transparent_quad := PackedByteArray([0, 0, 0, 0])
var _explored_quad := PackedByteArray([EXPLORED_COLOR.r8, EXPLORED_COLOR.g8, EXPLORED_COLOR.b8, EXPLORED_COLOR.a8])
var _unexplored_quad := PackedByteArray([UNEXPLORED_COLOR.r8, UNEXPLORED_COLOR.g8, UNEXPLORED_COLOR.b8, UNEXPLORED_COLOR.a8])

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
	_ally_snapshot.clear()
	for owner_id in game.players.size():
		var snapshot := PackedByteArray()
		snapshot.resize(cell_count)
		_ally_snapshot.append(snapshot)
	unit_display_cache.clear()
	_scout_camps.clear()
	_unit_tick_positions.clear()
	_unit_tick_positions_next.clear()
	_build_mountain_prefix()
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
	unit_display_cache.clear()
	_scout_camps.clear()
	_unit_tick_positions.clear()
	_unit_tick_positions_next.clear()
	_mountain_prefix = PackedInt32Array()

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
	var unit_radius := unit.radius()
	var reach := unit_radius + 16.0
	var top := maxf(40.0, unit_radius + 18.0)
	var origin := unit.position
	var iso: bool = game.view_mode_25d
	var canvas: Transform2D
	if iso:
		origin += RtsIsoProjection.ground_lift(game, unit.position)
		canvas = get_viewport().get_canvas_transform()
	# Inline of can_see's cell lookup; can_detect_unit above guarantees
	# owner_id is valid and the fog is active here.
	var vis: PackedByteArray = visible_cells[owner_id]
	var cell_size := float(RtsWorldMap.CELL_SIZE)
	var gw := grid_size.x
	var gh := grid_size.y
	for sample in SHOW_SAMPLE_OFFSETS:
		var offset := Vector2(sample.x * reach, sample.y * (top if sample.y < 0.0 else reach))
		var point: Vector2 = origin + (RtsIsoProjection.world_delta(canvas, offset * game.camera.zoom.x) if iso else offset)
		var cx := clampi(floori(point.x / cell_size), 0, gw - 1)
		var cy := clampi(floori(point.y / cell_size), 0, gh - 1)
		if vis[cy * gw + cx] == 0: return false
	return true

func update_unit_display(unit: RtsUnit) -> void:
	var shown := unit.owner_id == 0 or can_show_unit(0, unit)
	if unit.owner_id != 0: unit_display_cache[unit.get_instance_id()] = shown
	unit.visible = unit.garrisoned_in == null and shown

func update_building_display(building: RtsBuilding) -> void:
	building.visible = building.owner_id == 0 or can_see(0, building.position)

# Runs every frame between ticks; reuses the tick-level visibility results
# instead of recomputing sight checks for every enemy unit. Units first seen
# after the last tick (fresh spawns) are computed once and cached.
func _update_enemy_unit_display() -> void:
	var selection_may_change := false
	for unit in game.units:
		if not is_instance_valid(unit) or unit.is_queued_for_deletion() or unit.owner_id == 0: continue
		var key: int = unit.get_instance_id()
		var shown: bool
		if unit_display_cache.has(key):
			shown = unit_display_cache[key]
		else:
			shown = can_show_unit(0, unit)
			unit_display_cache[key] = shown
		var should_show := unit.garrisoned_in == null and shown
		if unit.visible == should_show: continue
		if unit.visible and game.selected.has(unit): selection_may_change = true
		unit.visible = should_show
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
	_heal_moved_unit_buckets()
	_collect_scout_camps()
	var player_count: int = game.players.size()
	for owner_id in player_count:
		var visible: PackedByteArray = visible_cells[owner_id]
		visible.fill(0)
		var camps: Array[Vector2] = _scout_camps.get(owner_id, _no_camps)
		for unit in game.units:
			if not is_instance_valid(unit) or unit.is_queued_for_deletion() or unit.owner_id != owner_id or unit.garrisoned_in != null: continue
			var radius := 360.0 if unit.kind == "scout" else 185.0 if unit.kind == "villager" else 250.0
			if unit.kind == "scout" and game.civilizations[owner_id] == "Chinese" and game.players[owner_id].get("dynasty", "") == "Tang": radius += 70.0
			if game.world_map.is_high_ground(unit.position): radius += 65.0
			for camp_position in camps:
				if camp_position.distance_squared_to(unit.position) <= 32400.0:
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
	# Teams share current vision, while each player's explored map persists.
	var shares_vision := false
	for owner_id in player_count:
		for ally_id in player_count:
			if ally_id != owner_id and not game.is_enemy(owner_id, ally_id): shares_vision = true
	if shares_vision:
		if _ally_snapshot.size() != player_count:
			_ally_snapshot.clear()
			for owner_id in player_count:
				var snapshot := PackedByteArray()
				snapshot.resize(grid_size.x * grid_size.y)
				_ally_snapshot.append(snapshot)
		for owner_id in player_count:
			var source: PackedByteArray = visible_cells[owner_id]
			var snapshot: PackedByteArray = _ally_snapshot[owner_id]
			for index in source.size(): snapshot[index] = source[index]
	for owner_id in player_count:
		var visible: PackedByteArray = visible_cells[owner_id]
		if shares_vision:
			for ally_id in player_count:
				if ally_id == owner_id or game.is_enemy(owner_id, ally_id): continue
				var ally_visible: PackedByteArray = _ally_snapshot[ally_id]
				for index in visible.size():
					if ally_visible[index] != 0: visible[index] = 1
		var explored: PackedByteArray = explored_cells[owner_id]
		for index in visible.size():
			if visible[index] != 0: explored[index] = 1
	_update_building_memory()
	_update_entity_visibility()
	_update_mask()
	game._prune_hidden_enemy_selection()
	queue_redraw()
	if game.minimap != null: game.minimap.queue_redraw()

func _collect_scout_camps() -> void:
	for positions in _scout_camps.values(): positions.clear()
	for building in game.buildings:
		if not is_instance_valid(building) or building.is_queued_for_deletion() or building.kind != "scout_camp": continue
		if not _scout_camps.has(building.owner_id): _scout_camps[building.owner_id] = [] as Array[Vector2]
		_scout_camps[building.owner_id].append(building.position)

# Position writes that bypass navigation.unit_moved (teleports, garrison code,
# tests) leave the spatial index stale; click picking and stealth detection read
# it right after a tick. Detect such moves against the last tick's snapshot and
# invalidate only then, so quiet ticks never pay for a full index rebuild.
func _heal_moved_unit_buckets() -> void:
	var moved := false
	_unit_tick_positions_next.clear()
	for unit in game.units:
		if not is_instance_valid(unit) or unit.is_queued_for_deletion(): continue
		var id: int = unit.get_instance_id()
		_unit_tick_positions_next[id] = unit.position
		if _unit_tick_positions.get(id, unit.position) != unit.position: moved = true
	var swap := _unit_tick_positions
	_unit_tick_positions = _unit_tick_positions_next
	_unit_tick_positions_next = swap
	if moved: game.navigation.invalidate_spatial_index()

# Stamps the cells inside the reveal circle. The exact distance test gates
# every cell; line of sight only runs when a mountain lies inside the circle's
# bounding square (an O(1) prefix-sum query), keeping mountain occlusion
# identical while open terrain stamps each row's contiguous run directly.
func _reveal_circle(visible: PackedByteArray, origin: Vector2, radius: float) -> void:
	var cell_size := float(RtsWorldMap.CELL_SIZE)
	var limit := radius + cell_size * 0.45
	var limit_sq := limit * limit
	var band := ceili(limit / cell_size)
	var width := grid_size.x
	var height := grid_size.y
	var source: Vector2i = game.world_map.cell_at(origin)
	var sx := source.x
	var sy := source.y
	var ox := origin.x
	var oy := origin.y
	var with_los := _mountains_within(sx, sy, band)
	# The cells passing the exact distance test in one row form a single
	# contiguous run. Solve the run bounds per row with one square root (plus a
	# one-cell margin refined by the same exact test) instead of probing every
	# cell of the bounding square.
	var half := cell_size * 0.5
	var y0 := maxi(0, sy - band)
	var y1 := mini(height - 1, sy + band)
	for y in range(y0, y1 + 1):
		var dy_world := oy - (y * cell_size + half)
		var remaining := limit_sq - dy_world * dy_world
		if remaining < 0.0: continue
		var dx_max := sqrt(remaining)
		var row_base := y * width
		var x0 := maxi(0, ceili((ox - dx_max - half) / cell_size) - 1)
		var x1 := mini(width - 1, floori((ox + dx_max - half) / cell_size) + 1)
		while x0 <= x1:
			var dx_world := ox - (x0 * cell_size + half)
			if dx_world * dx_world <= remaining: break
			x0 += 1
		while x1 >= x0:
			var dx_world := ox - (x1 * cell_size + half)
			if dx_world * dx_world <= remaining: break
			x1 -= 1
		if with_los:
			# Mountain occlusion can break the run, so gate each cell on sight.
			# The Bresenham walk is inlined (identical steps to _line_of_sight);
			# at thousands of calls per tick the function-call overhead hurts.
			var cells: PackedByteArray = game.world_map.cells
			var ldy := absi(y - sy)
			var row_step := width if y > sy else -width
			for x in range(x0, x1 + 1):
				var index := row_base + x
				if visible[index] != 0: continue
				var ldx := absi(x - sx)
				if ldx <= 1 and ldy <= 1:
					# One Bresenham step reaches any neighbor, so no intermediate
					# cell exists that could block the sight line.
					visible[index] = 1
					continue
				var blocked := false
				var lx := sx
				var ly := sy
				var step_x := 1 if lx < x else -1
				var step_y := 1 if ly < y else -1
				var error := ldx - ldy
				var li := sy * width + sx
				while true:
					var doubled := error * 2
					if doubled > -ldy:
						error -= ldy
						lx += step_x
						li += step_x
					if doubled < ldx:
						error += ldx
						ly += step_y
						li += row_step
					if lx == x and ly == y: break
					if cells[li] == RtsWorldMap.Terrain.MOUNTAIN:
						blocked = true
						break
				if not blocked: visible[index] = 1
		else:
			for x in range(x0, x1 + 1):
				visible[row_base + x] = 1

func _build_mountain_prefix() -> void:
	var width := grid_size.x
	var height := grid_size.y
	var stride := width + 1
	_mountain_prefix.resize(stride * (height + 1))
	_mountain_prefix.fill(0)
	var cells: PackedByteArray = game.world_map.cells
	for y in range(1, height + 1):
		var row_total := 0
		var row := y * stride
		var above := row - stride
		var cells_row := (y - 1) * width
		for x in range(1, width + 1):
			if cells[cells_row + x - 1] == RtsWorldMap.Terrain.MOUNTAIN: row_total += 1
			_mountain_prefix[row + x] = _mountain_prefix[above + x] + row_total

func _mountains_within(cx: int, cy: int, extent: int) -> bool:
	var x0 := maxi(0, cx - extent)
	var y0 := maxi(0, cy - extent)
	var x1 := mini(grid_size.x - 1, cx + extent)
	var y1 := mini(grid_size.y - 1, cy + extent)
	var stride := grid_size.x + 1
	return _mountain_prefix[(y1 + 1) * stride + x1 + 1] - _mountain_prefix[y0 * stride + x1 + 1] - _mountain_prefix[(y1 + 1) * stride + x0] + _mountain_prefix[y0 * stride + x0] > 0

func _line_of_sight(from: Vector2i, to: Vector2i) -> bool:
	var cells: PackedByteArray = game.world_map.cells
	var width := grid_size.x
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
		if cells[y * width + x] == RtsWorldMap.Terrain.MOUNTAIN: return false
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
	unit_display_cache.clear()
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
	var width := grid_size.x
	var height := grid_size.y
	var count := width * height
	if _mask_data.size() != count * 4:
		_mask_data.resize(count * 4)
		mask_image = null
	var data := _mask_data
	if mode == "terrain":
		data.fill(0)
	else:
		var visible: PackedByteArray = visible_cells[0]
		var explored: PackedByteArray = explored_cells[0]
		for index in count:
			var base := index * 4
			var quad := _transparent_quad if visible[index] != 0 else _explored_quad if explored[index] != 0 else _unexplored_quad
			data[base] = quad[0]
			data[base + 1] = quad[1]
			data[base + 2] = quad[2]
			data[base + 3] = quad[3]
	if mask_image == null:
		mask_image = Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, data)
	else:
		mask_image.set_data(width, height, false, Image.FORMAT_RGBA8, data)
	if mask_texture == null:
		mask_texture = ImageTexture.create_from_image(mask_image)
	else:
		mask_texture.update(mask_image)
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

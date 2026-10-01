class_name RtsMinimap
extends Control
const Contours = preload("res://scripts/world/terrain_contours.gd")

var game: Node2D
var update_timer := 0.0
var terrain_texture: Texture2D
var cached_seed := -1
var cached_size := Vector2i.ZERO

func setup(game_ref: Node2D) -> void:
	game = game_ref
	clip_contents = false
	mouse_filter = Control.MOUSE_FILTER_PASS
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	queue_redraw()

func _process(delta: float) -> void:
	if game == null or not game.started: return
	update_timer -= delta
	if update_timer <= 0.0:
		queue_redraw()
		update_timer = 0.15

func world_to_map(world_point: Vector2) -> Vector2:
	var uv := Vector2(world_point.x / game.world_size.x, world_point.y / game.world_size.y)
	if not game.view_mode_25d: return uv * size
	var radius := minf(size.x, size.y) * 0.5
	return size * 0.5 + Vector2(uv.x - uv.y, uv.x + uv.y - 1.0) * radius

func map_to_world(map_point: Vector2) -> Vector2:
	if not game.view_mode_25d:
		return Vector2(map_point.x / size.x * game.world_size.x, map_point.y / size.y * game.world_size.y).clamp(Vector2.ZERO, game.world_size)
	var delta := (map_point - size * 0.5) / maxf(minf(size.x, size.y) * 0.5, 1.0)
	var uv := Vector2((delta.x + delta.y + 1.0) * 0.5, (delta.y - delta.x + 1.0) * 0.5)
	return (uv * game.world_size).clamp(Vector2.ZERO, game.world_size)

func _inside_map(map_point: Vector2) -> bool:
	if not game.view_mode_25d: return Rect2(Vector2.ZERO, size).has_point(map_point)
	var delta := map_point - size * 0.5
	return absf(delta.x) + absf(delta.y) <= minf(size.x, size.y) * 0.5

func _gui_input(event: InputEvent) -> void:
	if game == null or not game.started or game.paused or game.game_over: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not _inside_map(event.position): return
		game.camera.position = map_to_world(event.position)
		accept_event()
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if not _inside_map(event.position): return
		game.camera.position = map_to_world(event.position)
		accept_event()

func _draw() -> void:
	var diamond: bool = game != null and game.view_mode_25d
	if diamond:
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.5
		draw_colored_polygon(PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0), center + Vector2(0, radius), center + Vector2(-radius, 0)]), Color("334934"))
	else:
		draw_rect(Rect2(Vector2.ZERO, size), Color("334934"))
	if game == null or not game.started: return
	var terrain_map: RtsWorldMap = game.world_map
	if cached_seed != terrain_map.map_seed or cached_size != terrain_map.grid_size or terrain_texture == null:
		_build_terrain_texture(terrain_map)
	var texture_rect := Rect2(Vector2.ZERO, size)
	if diamond:
		var side := minf(size.x, size.y) / sqrt(2.0)
		draw_set_transform(size * 0.5, PI / 4.0)
		texture_rect = Rect2(Vector2.ONE * -side * 0.5, Vector2.ONE * side)
	draw_texture_rect(terrain_texture, texture_rect, false)
	if game.fog.active and game.fog.mask_texture != null:
		draw_texture_rect(game.fog.mask_texture, texture_rect, false)
	if diamond: draw_set_transform(Vector2.ZERO)
	if game.objectives != null:
		for site in game.objectives.sacred_sites:
			var site_color := Color("f1dfa0")
			if site["owner_id"] >= 0: site_color = game.player_color(site["owner_id"]).lightened(0.35)
			draw_circle(world_to_map(site["position"]), 3.0, site_color)
	for post in game.trade_posts:
		if is_instance_valid(post) and (not game.fog.active or game.fog.is_explored(0, post.position)):
			draw_rect(Rect2(world_to_map(post.position) - Vector2(2, 2), Vector2(4, 4)), Color("d4af71"))
	for relic in game.relics:
		if is_instance_valid(relic) and relic.available() and (not game.fog.active or game.fog.can_see(0, relic.position)):
			draw_circle(world_to_map(relic.position), 2.0, Color("f4e8ae"))
	for resource in game.resources:
		if not is_instance_valid(resource) or resource.is_queued_for_deletion(): continue
		if game.fog.active and not game.fog.can_show_resource(0, resource): continue
		var resource_color := Color("72b16b")
		if resource.kind == "gold": resource_color = Color("d7bc5d")
		if resource.kind == "stone": resource_color = Color("a2aaa8")
		draw_circle(world_to_map(resource.position), 1.5, resource_color)
	if game.fog.active:
		for memory in game.fog.remembered_buildings.values():
			var ghost: Node2D = memory["ghost"]
			if not ghost.visible: continue
			var old_color: Color = game.player_color(int(memory["owner_id"])).lerp(Color.GRAY, 0.55)
			draw_rect(Rect2(world_to_map(memory["position"]) - Vector2(3, 3), Vector2(6, 6)), old_color)
	for building in game.buildings:
		if not is_instance_valid(building): continue
		if building.owner_id != 0 and game.fog.active and not game.fog.can_see(0, building.position): continue
		var color: Color = game.player_color(building.owner_id)
		draw_rect(Rect2(world_to_map(building.position) - Vector2(3, 3), Vector2(6, 6)), color)
	for unit in game.units:
		if not is_instance_valid(unit) or unit.garrisoned_in != null: continue
		if unit.owner_id != 0 and game.fog.active:
			if game.is_enemy(0, unit.owner_id) and not game.fog.can_show_unit(0, unit): continue
			if not game.is_enemy(0, unit.owner_id) and not game.fog.can_see(0, unit.position): continue
		var color: Color = Color.WHITE if game.selected.has(unit) else game.player_color(unit.owner_id).lightened(0.28)
		draw_circle(world_to_map(unit.position), 1.8, color)
	var inverse: Transform2D = get_viewport().get_canvas_transform().affine_inverse()
	var viewport_size: Vector2 = get_viewport_rect().size
	var corners := PackedVector2Array([
		world_to_map(inverse * Vector2.ZERO),
		world_to_map(inverse * Vector2(viewport_size.x, 0)),
		world_to_map(inverse * viewport_size),
		world_to_map(inverse * Vector2(0, viewport_size.y)),
	])
	if diamond:
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.5
		var bounds := PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0), center + Vector2(0, radius), center + Vector2(-radius, 0)])
		for clipped in Geometry2D.intersect_polygons(corners, bounds):
			if clipped.size() < 2: continue
			var outline := clipped.duplicate()
			outline.append(clipped[0])
			draw_polyline(outline, Color("f4dd89"), 1.5)
	else:
		for index in corners.size():
			draw_line(corners[index], corners[(index + 1) % corners.size()], Color("f4dd89"), 1.5)
	if diamond:
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.5
		draw_polyline(PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0), center + Vector2(0, radius), center + Vector2(-radius, 0), center + Vector2(0, -radius)]), Color("c8b987"), 2.0)
	else:
		draw_rect(Rect2(Vector2.ZERO, size), Color("c8b987"), false, 2)

func _build_terrain_texture(terrain_map: RtsWorldMap) -> void:
	var image := Contours.overview_image(terrain_map)
	terrain_texture = ImageTexture.create_from_image(image)
	cached_seed = terrain_map.map_seed
	cached_size = terrain_map.grid_size

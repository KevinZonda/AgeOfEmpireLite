class_name RtsMinimap
extends Control

var game: Node2D
var update_timer := 0.0

func setup(game_ref: Node2D) -> void:
	game = game_ref
	custom_minimum_size = Vector2(208, 130)
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()

func _process(delta: float) -> void:
	if game == null or not game.started: return
	update_timer -= delta
	if update_timer <= 0.0:
		queue_redraw()
		update_timer = 0.15

func world_to_map(world_point: Vector2) -> Vector2:
	return Vector2(world_point.x / game.world_size.x * size.x, world_point.y / game.world_size.y * size.y)

func map_to_world(map_point: Vector2) -> Vector2:
	return Vector2(map_point.x / size.x * game.world_size.x, map_point.y / size.y * game.world_size.y).clamp(Vector2.ZERO, game.world_size)

func _gui_input(event: InputEvent) -> void:
	if game == null or not game.started or game.paused or game.game_over: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		game.camera.position = map_to_world(event.position)
		accept_event()
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		game.camera.position = map_to_world(event.position)
		accept_event()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("334934"))
	for x in range(0, int(size.x), 26): draw_line(Vector2(x, 0), Vector2(x, size.y), Color(1, 1, 1, 0.07))
	for y in range(0, int(size.y), 26): draw_line(Vector2(0, y), Vector2(size.x, y), Color(1, 1, 1, 0.07))
	if game == null or not game.started: return
	for resource in game.resources:
		if not is_instance_valid(resource) or resource.is_queued_for_deletion(): continue
		var resource_color := Color("72b16b")
		if resource.kind == "gold": resource_color = Color("d7bc5d")
		if resource.kind == "stone": resource_color = Color("a2aaa8")
		draw_circle(world_to_map(resource.position), 1.5, resource_color)
	for building in game.buildings:
		if not is_instance_valid(building): continue
		var color: Color = GameData.CIVILIZATIONS[game.civilizations[building.owner_id]]["color"]
		draw_rect(Rect2(world_to_map(building.position) - Vector2(3, 3), Vector2(6, 6)), color)
	for unit in game.units:
		if not is_instance_valid(unit): continue
		var color: Color = GameData.CIVILIZATIONS[game.civilizations[unit.owner_id]]["color"].lightened(0.28)
		draw_circle(world_to_map(unit.position), 1.8, color)
	var visible_size: Vector2 = get_viewport_rect().size / game.camera.zoom
	var viewport_center: Vector2 = game.camera.get_screen_center_position()
	var top_left := world_to_map(viewport_center - visible_size * 0.5)
	var bottom_right := world_to_map(viewport_center + visible_size * 0.5)
	draw_rect(Rect2(top_left, bottom_right - top_left), Color("f4dd89"), false, 1.5)
	draw_rect(Rect2(Vector2.ZERO, size), Color("c8b987"), false, 2)

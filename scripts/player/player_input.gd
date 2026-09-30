extends RefCounted

# Owns gameplay input modes, drag lifecycle, routing and camera controls.
# The game delegates entry points to preserve scene and test adapters.
var game: Node2D
enum Mode { SELECT, BUILD, TARGET }
enum SelectionDragPhase { IDLE, BLOCKED, CANDIDATE, ACTIVE }

var build_mode := ""
var pending_landmark_id := ""
var build_page := 0
var order_mode := ""
var dragging := false
var wall_dragging := false
var wall_vertical := false
var wall_start := Vector2.ZERO
var wall_end := Vector2.ZERO
var drag_start_screen := Vector2.ZERO
var drag_current_screen := Vector2.ZERO
var selection_drag_phase := SelectionDragPhase.IDLE
var selection_drag_additive := false
var selection_previous_left_down := false

var mode: Mode:
	get:
		if not build_mode.is_empty(): return Mode.BUILD
		if not order_mode.is_empty(): return Mode.TARGET
		return Mode.SELECT

func _init(game_ref: Node2D) -> void:
	game = game_ref

func set_build_mode(value: String) -> void:
	build_mode = value
	if not value.is_empty():
		order_mode = ""
		game._cancel_selection_drag(true)

func set_order_mode(value: String) -> void:
	order_mode = value
	if not value.is_empty():
		build_mode = ""
		pending_landmark_id = ""
		wall_dragging = false
		game._cancel_selection_drag(true)

func _pan_camera(delta: float) -> void:
	var direction := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): direction.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): direction.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): direction.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): direction.y += 1
	# A pointer resting at the screen edge must not cancel or skew WASD movement.
	if direction == Vector2.ZERO and game.get_window().has_focus():
		direction = game._edge_pan_direction(game._selection_pointer_screen_position(), game.get_viewport_rect().size)
	if direction != Vector2.ZERO:
		game._move_camera_screen_delta(direction.normalized() * game.CAMERA_PAN_SPEED * delta)

func _move_camera_screen_delta(screen_delta: Vector2) -> void:
	var world_delta := Vector2(screen_delta.x / game.camera.zoom.x, screen_delta.y / game.camera.zoom.y).rotated(game.camera.rotation)
	game.camera.position += world_delta
	game._clamp_camera_position()

func _clamp_camera_position() -> void:
	var half_view: Vector2 = game.get_viewport_rect().size * 0.5 / game.camera.zoom
	var angle: float = game.camera.rotation
	var extents := Vector2(absf(cos(angle)) * half_view.x + absf(sin(angle)) * half_view.y, absf(sin(angle)) * half_view.x + absf(cos(angle)) * half_view.y)
	# A diamond-shaped projected view cannot fit inside the standard map.
	# Keep its center navigable and allow some background at the corners.
	var margin := extents.min(game.world_size * (0.12 if game.view_mode_25d else 0.5))
	game.camera.position = game.camera.position.clamp(margin, game.world_size - margin)

func _adjust_zoom(factor: float, screen_anchor := Vector2.INF) -> void:
	var base_zoom := clampf(game.camera.zoom.x * factor, 0.7, 1.65)
	if is_equal_approx(base_zoom, game.camera.zoom.x): return
	if screen_anchor == Vector2.INF: screen_anchor = game.get_viewport_rect().size * 0.5
	game.camera.force_update_scroll()
	var anchor_world := game.get_viewport().get_canvas_transform().affine_inverse() * screen_anchor
	game.camera.zoom = Vector2(base_zoom, base_zoom * 0.5 if game.view_mode_25d else base_zoom)
	game.camera.force_update_scroll()
	var shifted_world := game.get_viewport().get_canvas_transform().affine_inverse() * screen_anchor
	game.camera.position += anchor_world - shifted_world
	game._clamp_camera_position()
	# Projection geometry depends on zoom.x / zoom.y, which stays fixed here.
	# Camera2D scales the existing map, fog mesh and entity drawings itself.
	game.queue_redraw()

func _edge_pan_direction(screen_point: Vector2, viewport_size: Vector2) -> Vector2:
	if not game.edge_scroll_enabled: return Vector2.ZERO
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0: return Vector2.ZERO
	# Confined mouse coordinates can land exactly on the right or bottom edge.
	# Clamping also keeps edge scrolling continuous during a focus transition.
	var point := screen_point.clamp(Vector2.ZERO, (viewport_size - Vector2.ONE).max(Vector2.ZERO))
	# Command buttons and the minimap can overlap the edge-scroll strip.
	# Hovering the HUD must not move the battlefield while clicking a command.
	if game.hud_top != null and game.hud_top.visible and game.hud_top.get_global_rect().has_point(point): return Vector2.ZERO
	if game.hud_bottom != null and game.hud_bottom.visible and game.hud_bottom.get_global_rect().has_point(point): return Vector2.ZERO
	if game.global_queue_panel != null and game.global_queue_panel.visible and game.global_queue_panel.get_global_rect().has_point(point): return Vector2.ZERO
	if game.hud_ui != null and game.hud_ui.minimap_panel != null and game.hud_ui.minimap_panel.visible and game.hud_ui.minimap_panel.get_global_rect().has_point(point): return Vector2.ZERO
	var direction := Vector2.ZERO
	if point.x <= game.EDGE_SCROLL_MARGIN: direction.x -= 1
	if point.x >= viewport_size.x - game.EDGE_SCROLL_MARGIN: direction.x += 1
	if point.y <= game.EDGE_SCROLL_MARGIN: direction.y -= 1
	if point.y >= viewport_size.y - game.EDGE_SCROLL_MARGIN: direction.y += 1
	return direction

func _reset_selection_pointer() -> void:
	game.selection_drag_phase = game.SelectionDragPhase.IDLE
	game.selection_previous_left_down = game._selection_native_left_down() if game._uses_native_selection_pointer() else false

func _selection_point_over_hud(screen_point: Vector2) -> bool:
	if not Rect2(Vector2.ZERO, game.get_viewport_rect().size).has_point(screen_point): return true
	for control in [game.hud_top, game.hud_bottom, game.minimap, game.global_queue_panel, game.pause_overlay, game.settings_overlay, game.tech_tree_overlay, game.age_choice_overlay]:
		if control == null or not (control is Control) or not control.is_visible_in_tree(): continue
		var canvas_transform: Transform2D = control.get_global_transform_with_canvas()
		var screen_rect := Rect2(canvas_transform * Vector2.ZERO, canvas_transform * control.size - canvas_transform * Vector2.ZERO)
		if screen_rect.has_point(screen_point):
			if control == game.minimap and not game.minimap._inside_map(canvas_transform.affine_inverse() * screen_point): continue
			return true
	return false

func _poll_selection_pointer() -> void:
	game._advance_selection_pointer(game._selection_pointer_screen_position(), game._selection_native_left_down())

func _advance_selection_pointer(screen_point: Vector2, left_down: bool) -> void:
	if left_down and not game.selection_previous_left_down:
		if game.selection_drag_phase == game.SelectionDragPhase.BLOCKED:
			pass
		elif game.dragging:
			if game.selection_drag_phase == game.SelectionDragPhase.IDLE: game.selection_drag_phase = game.SelectionDragPhase.CANDIDATE
		else:
			# Native LEFT can belong to a logical RIGHT (for example Ctrl-click).
			# Only an unhandled LEFT event may start a selection; polling keeps
			# an existing drag responsive and detects its release.
			game.selection_drag_phase = game.SelectionDragPhase.BLOCKED
	elif left_down:
		if game.dragging and game.selection_drag_phase in [game.SelectionDragPhase.CANDIDATE, game.SelectionDragPhase.ACTIVE]:
			game.selection_drag_additive = Input.is_key_pressed(KEY_SHIFT)
			game._update_selection_drag(screen_point)
	elif game.selection_previous_left_down:
		if game.dragging and game.selection_drag_phase in [game.SelectionDragPhase.CANDIDATE, game.SelectionDragPhase.ACTIVE]:
			# The pointer may already be at the next right-click target by this frame.
			game._complete_selection_drag(game.drag_current_screen, game.selection_drag_additive)
		else:
			game.selection_drag_phase = game.SelectionDragPhase.IDLE
	game.selection_previous_left_down = left_down

func _consume_placement_left_press() -> void:
	# Placing may clear build_mode before macOS polls the still-held button.
	# Keep this press blocked until release so it cannot select the new building.
	game._cancel_selection_drag()
	game.selection_drag_phase = game.SelectionDragPhase.BLOCKED
	game.selection_previous_left_down = true

func _begin_selection_candidate(screen_point: Vector2) -> void:
	game.dragging = true
	game.selection_drag_phase = game.SelectionDragPhase.CANDIDATE
	game.selection_drag_additive = Input.is_key_pressed(KEY_SHIFT)
	game.drag_start_screen = screen_point
	game.drag_current_screen = screen_point
	game._begin_selection_drag(screen_point)
	if game._uses_native_selection_pointer(): game.selection_previous_left_down = game._selection_native_left_down()

func _selection_drag_active() -> bool:
	return game.dragging and game.selection_drag_phase == game.SelectionDragPhase.ACTIVE

func _selection_drag_visible() -> bool:
	return game.dragging and game.drag_start_screen.distance_to(game.drag_current_screen) > game.SELECTION_DRAG_VISUAL_THRESHOLD

func _begin_selection_drag(screen_point: Vector2) -> void:
	if game.selection_drag_overlay != null: game.selection_drag_overlay.begin(screen_point)

func _update_selection_drag(screen_point: Vector2) -> void:
	game.drag_current_screen = screen_point
	if game.selection_drag_phase == game.SelectionDragPhase.CANDIDATE and game.drag_start_screen.distance_to(screen_point) > game.SELECTION_DRAG_THRESHOLD:
		game.selection_drag_phase = game.SelectionDragPhase.ACTIVE
	var should_show: bool = game._selection_drag_visible()
	if game.selection_drag_overlay != null:
		game.selection_drag_overlay.update_drag(screen_point, should_show)

func _finish_selection_drag() -> void:
	if game.selection_drag_overlay != null: game.selection_drag_overlay.finish()

func _complete_selection_drag(screen_point: Vector2, additive: bool) -> void:
	if not game.dragging: return
	game._update_selection_drag(screen_point)
	game.dragging = false
	game.selection_drag_phase = game.SelectionDragPhase.IDLE
	game._finish_selection_drag()
	game._select_screen_area(game.drag_start_screen, screen_point, additive)

func _cancel_selection_drag(block_until_release := false) -> void:
	game.dragging = false
	var left_down: bool = game._selection_native_left_down() if game._uses_native_selection_pointer() else false
	game.selection_drag_phase = game.SelectionDragPhase.BLOCKED if block_until_release and left_down else game.SelectionDragPhase.IDLE
	if game._uses_native_selection_pointer(): game.selection_previous_left_down = left_down
	game._finish_selection_drag()

func _input(event: InputEvent) -> void:
	if game.age_choice_overlay != null:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			game._close_age_choice()
			game.get_viewport().set_input_as_handled()
		return
	if game.unit_preview_page != null:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			game.menu_ui._close_unit_preview()
			game.get_viewport().set_input_as_handled()
		return
	if game.tech_tree_overlay != null:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			game._close_tech_tree()
			game.get_viewport().set_input_as_handled()
		return
	if game.settings_overlay != null and game.settings_overlay.visible:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			game._close_settings()
			game.get_viewport().set_input_as_handled()
		return
	if not game.started:
		if game.menu_ui.setup_menu_active and game.menu_panel.visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			game.menu_ui._show_home_menu()
			game.get_viewport().set_input_as_handled()
		return
	if game.game_over: return
	# Active drags receive motion before GUI controls can consume it.
	if event is InputEventMouseMotion:
		if game.dragging:
			game._update_selection_drag(game._selection_pointer_screen_position() if game._uses_native_selection_pointer() else event.position)
		if game.wall_dragging:
			game.wall_end = game.get_global_mouse_position()
			game.queue_redraw()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if game._finish_left_drag(event):
			game.get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and game.dragging:
		game._cancel_selection_drag(true)
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		game._set_paused(not game.paused)
		game.get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
		game._toggle_global_queue()
		game.get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_V:
		game._toggle_view_mode(true)
		game.get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R and (game.build_mode.ends_with("_wall") or game.build_mode.ends_with("_gate")):
		game.wall_vertical = not game.wall_vertical
		game.queue_redraw()
		game.get_viewport().set_input_as_handled()

func _finish_left_drag(event: InputEventMouseButton) -> bool:
	if game.wall_dragging:
		game.wall_dragging = false
		game._confirm_wall_line(game.wall_start, game.get_global_mouse_position(), event.shift_pressed)
		return true
	if game.dragging:
		# Use the release event's position, not the pointer's later position.
		game._complete_selection_drag(event.position, event.shift_pressed)
		if game._uses_native_selection_pointer(): game.selection_previous_left_down = game._selection_native_left_down()
		return true
	return false

func _unhandled_input(event: InputEvent) -> void:
	if not _gameplay_input_allowed(): return
	if event is InputEventMagnifyGesture:
		if game.zoom_gesture_enabled:
			game._adjust_zoom(event.factor, event.position)
			game.get_viewport().set_input_as_handled()
		return
	if event is InputEventPanGesture:
		game._move_camera_screen_delta(event.delta * game.GESTURE_PAN_PIXELS)
		game.get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		if event.pressed and (event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT): game.cursor.flash()
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			game._adjust_zoom(1.1, event.position)
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			game._adjust_zoom(1.0 / 1.1, event.position)
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if not event.pressed:
				game._finish_left_drag(event)
				return
			if game.order_mode != "":
				game._issue_mode_order(game.get_global_mouse_position(), event.shift_pressed)
				return
			if game.build_mode != "":
				game._consume_placement_left_press()
				if game.build_mode.ends_with("_wall"):
					game.wall_dragging = true
					game.wall_start = game.get_global_mouse_position()
					game.wall_end = game.wall_start
				else:
					game._confirm_build(game.get_global_mouse_position(), event.shift_pressed)
				return
			if event.double_click:
				var clicked: Node2D = game._entity_at(game.get_viewport().get_canvas_transform().affine_inverse() * event.position)
				if clicked is RtsUnit and clicked.owner_id == 0:
					game._cancel_selection_drag(true)
					game._select_same_type_visible(clicked, event.shift_pressed)
					return
				if clicked is RtsBuilding and clicked.owner_id == 0:
					game._cancel_selection_drag(true)
					game._select_same_buildings_visible(clicked, event.shift_pressed)
					return
			if game._uses_native_selection_pointer():
				if game.dragging and game.selection_drag_phase in [game.SelectionDragPhase.CANDIDATE, game.SelectionDragPhase.ACTIVE]: return
			game._begin_selection_candidate(game._selection_pointer_screen_position() if game._uses_native_selection_pointer() else event.position)
			return
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if game.order_mode != "":
				game.order_mode = ""
				game.notify_player("已取消命令")
				return
			if game.build_mode != "":
				game.build_mode = ""
				game.wall_dragging = false
				game.pending_landmark_id = ""
				game.notify_player("已取消建造")
				return
			game._issue_order(game.get_viewport().get_canvas_transform().affine_inverse() * event.position, event.shift_pressed)
			return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_PERIOD:
			game._select_next_idle_villager()
			game.get_viewport().set_input_as_handled()
			return
		if event.keycode >= KEY_0 and event.keycode <= KEY_9 and (event.ctrl_pressed or game.control_groups.has(event.keycode)) and not event.alt_pressed:
			game._handle_control_group(event)
			game.get_viewport().set_input_as_handled()
			return
		if game.player_actions.has_hotkey(event.keycode):
			if game.player_actions.execute_hotkey(event.keycode):
				game.get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_DELETE:
			for entity in game.selected.duplicate():
				if entity is RtsBuilding and entity.kind != "town_center": game.entity_destroyed(entity)


func _gameplay_input_allowed() -> bool:
	return game.started and not game.game_over and not game.paused and game.age_choice_overlay == null and game.unit_preview_page == null and game.tech_tree_overlay == null and (game.settings_overlay == null or not game.settings_overlay.visible)

func _update_cursor() -> void:
	var screen_point: Vector2 = game._selection_pointer_screen_position()
	game.cursor.position = screen_point
	if game.dragging:
		# Keep the current cursor for the click-sized candidate. The anchor is
		# sufficient feedback and avoids introducing a first-draw font cost.
		if game._selection_drag_visible(): game.cursor.set_state("select")
		game.cursor.set_context("")
		return
	var over_ui: bool = game._selection_point_over_hud(screen_point)
	var world_point := game.get_viewport().get_canvas_transform().affine_inverse() * screen_point
	game.cursor.set_state(game._cursor_state_at(world_point, over_ui))
	var resource: RtsResource = game._resource_at(world_point) if not over_ui and game.build_mode == "" else null
	var context := ""
	if resource != null:
		context = GameData.RESOURCE_LABELS[resource.kind]
		context += " · %d" % resource.amount if not game.fog.active or game.fog.can_see(0, resource.position) else " · 未在视野内"
	game.cursor.set_context(context)

func _cursor_state_at(world_point: Vector2, over_ui := false) -> String:
	if over_ui: return "default"
	if game.order_mode in ["attack_move", "patrol", "focus", "attack_ground"]: return game.order_mode
	if game.order_mode in ["field_ram", "field_tower"]: return "build_valid" if game.world_map.is_walkable(world_point) else "build_invalid"
	if game.order_mode == "unload": return "unload" if game.world_map.is_walkable(world_point) else "build_invalid"
	if game.build_mode != "":
		return "build_valid" if RtsActionAvailability.construction(game, 0, game.build_mode, world_point, game.wall_vertical, game.pending_landmark_id)["available"] else "build_invalid"
	if game._selection_drag_active(): return "drag"
	return game.ContextOrder.cursor_for(game, game.ContextOrder.targets(game, world_point))

func _confirm_build(point: Vector2, append_order := false) -> void:
	var builders: Array[RtsUnit] = []
	for entity in game.selected:
		if is_instance_valid(entity) and entity is RtsUnit and entity.owner_id == 0 and entity.kind == "villager":
			builders.append(entity)
	if builders.is_empty():
		for unit in game.units:
			if is_instance_valid(unit) and unit.owner_id == 0 and unit.kind == "villager": builders.append(unit)
		builders.sort_custom(func(a: RtsUnit, b: RtsUnit) -> bool: return a.position.distance_squared_to(point) < b.position.distance_squared_to(point))
		if builders.size() > 2: builders.resize(2)
	if builders.is_empty():
		game.notify_player("需要村民建造")
		return
	var success: bool = game.place_landmark(0, game.pending_landmark_id, point, builders, append_order) if game.build_mode == "landmark" else game.place_building(0, game.build_mode, point, builders, append_order, game.wall_vertical)
	if success and (not append_order or game.build_mode == "landmark"):
		game.build_mode = ""
		game.pending_landmark_id = ""
		game._rebuild_actions()
	game.queue_redraw()

func _wall_positions(from: Vector2, to: Vector2, kind := "palisade_wall") -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var delta := to - from
	var vertical: bool = absf(delta.y) > absf(delta.x) if delta.length() > 20.0 else game.wall_vertical
	var start: Vector2 = game.snap_build_point(kind, from, vertical)
	var end: Vector2 = game.snap_build_point(kind, to, vertical)
	var spacing: float = game.build_footprint_size(kind, vertical).y if vertical else game.build_footprint_size(kind, vertical).x
	var length := absf(end.y - start.y) if vertical else absf(end.x - start.x)
	var count := clampi(roundi(length / spacing) + 1, 1, 24)
	var sign_value := signf(delta.y if vertical else delta.x)
	if is_zero_approx(sign_value): sign_value = 1.0
	for index in count:
		positions.append(start + (Vector2.DOWN if vertical else Vector2.RIGHT) * sign_value * index * spacing)
	return positions

func _confirm_wall_line(from: Vector2, to: Vector2, append_order := false) -> void:
	var vertical: bool = absf(to.y - from.y) > absf(to.x - from.x) if from.distance_to(to) > 20.0 else game.wall_vertical
	var positions: Array[Vector2] = game._wall_positions(from, to, game.build_mode)
	var builders: Array[RtsUnit] = []
	for entity in game.selected:
		if entity is RtsUnit and entity.owner_id == 0 and entity.kind == "villager": builders.append(entity)
	if builders.is_empty():
		game.notify_player("需要村民建墙")
		return
	var cost: Dictionary = GameData.BUILDINGS[game.build_mode]["cost"]
	for resource in cost:
		if game.players[0][resource] < cost[resource] * positions.size():
			game.notify_player("整段城墙所需资源不足")
			return
	for point in positions:
		if not game.can_place(game.build_mode, point, vertical):
			game.notify_player("城墙经过不可建造的位置")
			return
	for index in positions.size():
		game.place_building(0, game.build_mode, positions[index], builders, append_order or index > 0, vertical)
	if not append_order:
		game.build_mode = ""
		game._rebuild_actions()
	game.queue_redraw()


extends SceneTree

class PointerGame extends "res://scripts/game.gd":
	var native_left := false
	var pointer := Vector2.ZERO
	func _uses_native_selection_pointer() -> bool:
		return true
	func _selection_native_left_down() -> bool:
		return native_left
	func _selection_pointer_screen_position() -> Vector2:
		return pointer

var game: PointerGame
var scout: RtsUnit
var empty_point := Vector2.ZERO

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	Input.use_accumulated_input = false
	game = PointerGame.new()
	root.add_child(game)
	await process_frame
	game.start_game("English", 12345)
	game.set_process(false)
	game.fog.active = false
	game.ai_controllers.clear()
	game.camera.force_update_scroll()
	var spawn_screen := _empty_screen()
	scout = game.spawn_unit(0, "scout", root.get_canvas_transform().affine_inverse() * spawn_screen)
	empty_point = _empty_screen()
	assert(empty_point != spawn_screen)
	for entity in game.units + game.resources + game.buildings: entity.set_process(false)

	# A session-state pulse by itself cannot stand in for a LEFT event.
	_reset()
	game.native_left = true
	game._poll_selection_pointer()
	assert(not game.dragging and game.selected == [scout])
	game.native_left = false
	game._poll_selection_pointer()
	assert(game.selected == [scout])

	# RIGHT followed by a late native LEFT pulse: previous bug.
	_reset()
	_button(MOUSE_BUTTON_RIGHT, true)
	assert(scout.order == "move")
	game.native_left = true
	for frame in 5: game._poll_selection_pointer()
	assert(not game.dragging, "RIGHT must not acquire a selection from native LEFT")
	game.native_left = false
	_button(MOUSE_BUTTON_RIGHT, false)
	game._poll_selection_pointer()
	assert(game.selected == [scout], "native LEFT release after RIGHT must preserve selection")

	# Control+left is delivered as RIGHT by the macOS backend while LEFT is held.
	_reset()
	game.native_left = true
	_button(MOUSE_BUTTON_RIGHT, true, true)
	game._poll_selection_pointer()
	game.native_left = false
	_button(MOUSE_BUTTON_RIGHT, false, true)
	game._poll_selection_pointer()
	assert(scout.order == "move" and game.selected == [scout] and not game.dragging)

	# RIGHT cancels an actual pending LEFT; later pulses/releases cannot revive it.
	_reset()
	game.native_left = true
	_button(MOUSE_BUTTON_LEFT, true)
	assert(game.dragging)
	_button(MOUSE_BUTTON_RIGHT, true)
	assert(not game.dragging)
	game._poll_selection_pointer()
	game.native_left = false
	game._poll_selection_pointer()
	game.native_left = true
	game._poll_selection_pointer()
	game.native_left = false
	_button(MOUSE_BUTTON_LEFT, false)
	_button(MOUSE_BUTTON_RIGHT, false)
	game._poll_selection_pointer()
	assert(game.selected == [scout] and scout.order == "move")

	# A genuine instantaneous tap works even when native polling misses both edges.
	_reset()
	_button(MOUSE_BUTTON_LEFT, true)
	assert(game.dragging)
	_button(MOUSE_BUTTON_LEFT, false)
	assert(game.selected.is_empty() and not game.dragging)

	# Shift-tapping empty ground keeps the existing selection.
	_reset()
	_shift(true)
	_button(MOUSE_BUTTON_LEFT, true, false, true)
	_button(MOUSE_BUTTON_LEFT, false, false, true)
	_shift(false)
	assert(game.selected == [scout], "Shift selection must remain additive")

	# Double-click selection cannot be followed by a poll-created rectangle.
	_reset()
	game.pointer = root.get_canvas_transform() * (scout.position + (RtsIsoProjection.ground_lift(game, scout.position) if game.view_mode_25d else Vector2.ZERO))
	game.native_left = true
	_button(MOUSE_BUTTON_LEFT, true, false, false, true)
	assert(game.selected.has(scout) and not game.dragging)
	game._poll_selection_pointer()
	game.native_left = false
	_button(MOUSE_BUTTON_LEFT, false)
	game._poll_selection_pointer()
	assert(game.selected.has(scout) and not game.dragging)

	# Native position and native release still drive an event-started rectangle.
	_reset()
	var center := root.get_canvas_transform() * (scout.position + (RtsIsoProjection.ground_lift(game, scout.position) if game.view_mode_25d else Vector2.ZERO))
	game.pointer = center - Vector2(40, 40)
	game.native_left = true
	_button(MOUSE_BUTTON_LEFT, true)
	game.pointer = center + Vector2(40, 40)
	game._poll_selection_pointer()
	assert(game.drag_current_screen == game.pointer and game._selection_drag_active(), "polling must still update a real drag")
	game.native_left = false
	game._poll_selection_pointer()
	assert(not game.dragging and game.selected.has(scout), "native release must complete an event-started drag")
	var selected_after_poll := game.selected.duplicate()
	_button(MOUSE_BUTTON_LEFT, false)
	assert(game.selected == selected_after_poll, "late LEFT release must not select twice")

	# Losing focus cancels the event-started selection and prevents poll-only restart.
	_reset()
	game.native_left = true
	_button(MOUSE_BUTTON_LEFT, true)
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	game._poll_selection_pointer()
	assert(not game.dragging and game.selected == [scout])
	game.native_left = false
	_button(MOUSE_BUTTON_LEFT, false)

	print("RIGHT_CLICK_SELECTION_OK")
	game.queue_free()
	await process_frame
	quit()

func _empty_screen() -> Vector2:
	for y in range(180, 360, 40):
		for x in range(260, 1000, 40):
			var point := Vector2(x, y)
			var world := root.get_canvas_transform().affine_inverse() * point
			if game.world_map.is_walkable(world) and game._entity_at(world) == null and game._resource_at(world) == null and not game._selection_point_over_hud(point): return point
	assert(false, "fixture needs empty visible ground")
	return Vector2.ZERO

func _reset() -> void:
	game.native_left = false
	game.pointer = empty_point
	_button(MOUSE_BUTTON_LEFT, false)
	_button(MOUSE_BUTTON_RIGHT, false)
	game._cancel_selection_drag()
	game._reset_selection_pointer()
	game.selected.assign([scout])
	scout.order_stop()

func _button(index: int, pressed: bool, ctrl := false, shift := false, double_click := false) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = index
	event.pressed = pressed
	event.position = game.pointer
	event.global_position = game.pointer
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if game.native_left else 0
	event.ctrl_pressed = ctrl
	event.shift_pressed = shift
	event.double_click = double_click
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _shift(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_SHIFT
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

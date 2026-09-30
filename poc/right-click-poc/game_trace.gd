extends "res://scripts/game.gd"

var _trace_source := "other"

func _selection_ids() -> Array:
	var ids := []
	for entity in selected:
		if is_instance_valid(entity): ids.append(entity.get_instance_id())
	return ids

func _trace_state(action: String, extra: Dictionary = {}) -> void:
	var sink := get_tree().root.get_node_or_null("InputTrace")
	if sink == null: return
	var row := {"layer": "selection", "action": action, "dragging": dragging,
		"phase": selection_drag_phase, "start_x": drag_start_screen.x, "start_y": drag_start_screen.y,
		"x": drag_current_screen.x, "y": drag_current_screen.y,
		"native_buttons": 0 if DisplayServer.get_name() == "headless" else DisplayServer.mouse_get_button_state(), "input_buttons": Input.get_mouse_button_mask(),
		"source": _trace_source, "selected_ids": _selection_ids(), "previous_left": selection_previous_left_down,
		"build_mode": build_mode, "order_mode": order_mode,
		"cursor_visible": cursor.visible if cursor else false, "focused": get_window().has_focus()}
	row.merge(extra)
	sink.log_row(row)

func _input(event: InputEvent) -> void:
	_trace_source = "input"
	if event is InputEventMouseButton:
		_trace_state("input_button", {"button": event.button_index, "pressed": event.pressed, "mask": event.button_mask, "ctrl": event.ctrl_pressed, "event_x": event.position.x, "event_y": event.position.y})
	super(event)
	_trace_source = "other"

func _unhandled_input(event: InputEvent) -> void:
	_trace_source = "unhandled_input"
	if event is InputEventMouseButton:
		_trace_state("unhandled_button", {"button": event.button_index, "pressed": event.pressed, "mask": event.button_mask, "ctrl": event.ctrl_pressed})
	super(event)
	_trace_source = "other"

func _advance_selection_pointer(screen_point: Vector2, left_down: bool) -> void:
	_trace_source = "native_poll"
	var changed := left_down != selection_previous_left_down
	if changed: _trace_state("poll_edge_before", {"left_down": left_down, "pointer_x": screen_point.x, "pointer_y": screen_point.y})
	super(screen_point, left_down)
	if changed: _trace_state("poll_edge_after", {"left_down": left_down})
	_trace_source = "other"

func _issue_order(point: Vector2, append_order := false) -> void:
	_trace_state("right_order_before", {"world_x": point.x, "world_y": point.y})
	super(point, append_order)
	_trace_state("right_order_after")

func _begin_selection_candidate(screen_point: Vector2) -> void:
	_trace_state("begin_before", {"requested_x": screen_point.x, "requested_y": screen_point.y})
	super(screen_point)
	_trace_state("begin_after")

func _complete_selection_drag(screen_point: Vector2, additive: bool) -> void:
	_trace_state("complete_before")
	super(screen_point, additive)
	_trace_state("complete_after")

func _cancel_selection_drag(block_until_release := false) -> void:
	_trace_state("cancel")
	super(block_until_release)

func _update_selection_drag(screen_point: Vector2) -> void:
	var previous_phase := selection_drag_phase
	super(screen_point)
	if previous_phase != selection_drag_phase: _trace_state("phase_change")

extends "res://scripts/game.gd"

func _trace_state(action: String, extra: Dictionary = {}) -> void:
	var sink := get_tree().root.get_node_or_null("InputTrace")
	if sink == null: return
	var row := {"layer": "selection", "action": action, "dragging": dragging,
		"phase": selection_drag_phase, "start_x": drag_start_screen.x, "start_y": drag_start_screen.y,
		"x": drag_current_screen.x, "y": drag_current_screen.y,
		"native_buttons": DisplayServer.mouse_get_button_state(), "input_buttons": Input.get_mouse_button_mask(),
		"cursor_visible": cursor.visible if cursor else false, "focused": get_window().has_focus()}
	row.merge(extra)
	sink.log_row(row)

func _begin_selection_candidate_poc(screen_point: Vector2, from_native := false) -> void:
	_trace_state("begin_before", {"from_native": from_native, "requested_x": screen_point.x, "requested_y": screen_point.y})
	super(screen_point, from_native)
	_trace_state("begin_after")

func _complete_selection_drag_poc(screen_point: Vector2, additive: bool) -> void:
	_trace_state("complete_before")
	super(screen_point, additive)
	_trace_state("complete_after")

func _cancel_selection_drag_poc(block_until_release := false) -> void:
	_trace_state("cancel")
	super(block_until_release)

func _update_selection_drag_poc(screen_point: Vector2) -> void:
	var previous_phase := selection_drag_phase
	super(screen_point)
	if previous_phase != selection_drag_phase: _trace_state("phase_change")

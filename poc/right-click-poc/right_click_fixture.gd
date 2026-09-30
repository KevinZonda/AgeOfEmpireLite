extends "res://poc/right-click-poc/game_trace.gd"

# Replay only: supply session state independently of Godot button events.
var replay_left := false
var replay_point := Vector2.ZERO
var replay_native_mask := 0
var event_owned_poll := false
var owned_left := false
var begin_count := 0
var complete_count := 0
var order_count := 0

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT: owned_left = event.pressed
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed: owned_left = false
	super(event)

func _advance_selection_pointer(screen_point: Vector2, left_down: bool) -> void:
	# Experimental variant only: require a delivered LEFT press to own polling.
	super(screen_point, left_down and owned_left if event_owned_poll else left_down)

func _begin_selection_candidate(screen_point: Vector2) -> void:
	begin_count += 1
	super(screen_point)

func _complete_selection_drag(screen_point: Vector2, additive: bool) -> void:
	if dragging: complete_count += 1
	super(screen_point, additive)

func _issue_order(point: Vector2, append_order := false) -> void:
	order_count += 1
	super(point, append_order)

func _uses_native_selection_pointer() -> bool:
	return true

func _selection_native_left_down() -> bool:
	return replay_left

func _selection_pointer_screen_position() -> Vector2:
	return replay_point

func _can_begin_native_selection(screen_point: Vector2) -> bool:
	# Headless windows cannot have focus. Keep the other production gates.
	return started and not paused and not game_over and build_mode == "" and order_mode == "" and not wall_dragging and not _selection_point_over_hud(screen_point)

extends RefCounted

# Platform polling is isolated from drag state and logical mouse events.
var game: Node2D

func _init(game_ref: Node2D) -> void:
	game = game_ref

func _uses_native_selection_pointer() -> bool:
	return OS.get_name() == "macOS" and DisplayServer.get_name() != "headless"

func _gameplay_mouse_mode():
	# Browsers support hiding the cursor, but cannot confine it to the canvas.
	if OS.has_feature("web") or game._uses_native_selection_pointer():
		return Input.MOUSE_MODE_HIDDEN
	return Input.MOUSE_MODE_CONFINED_HIDDEN

func _apply_gameplay_mouse_mode() -> void:
	Input.mouse_mode = game._gameplay_mouse_mode()

func _selection_pointer_screen_position() -> Vector2:
	if not game._uses_native_selection_pointer(): return game.get_viewport().get_mouse_position()
	var window_id := game.get_window().get_window_id()
	var window_position := DisplayServer.window_get_position(window_id)
	var window_size := DisplayServer.window_get_size(window_id)
	if window_size.x <= 0 or window_size.y <= 0: return game.get_viewport().get_mouse_position()
	var client_point := Vector2(DisplayServer.mouse_get_position() - window_position)
	return client_point * game.get_viewport_rect().size / Vector2(window_size)

func _selection_native_left_down() -> bool:
	return (DisplayServer.mouse_get_button_state() & MOUSE_BUTTON_MASK_LEFT) != 0

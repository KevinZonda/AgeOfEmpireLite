extends RefCounted

# Platform polling and browser wheel translation stay outside gameplay routing.
var game: Node2D
var _web_wheel_callback: Variant
var _web_wheel_listener: Variant

func _init(game_ref: Node2D) -> void:
	game = game_ref

func setup_web_gestures() -> void:
	if not OS.has_feature("web"): return
	JavaScriptBridge.eval(FileAccess.get_file_as_string("res://scripts/player/web_gestures.js"), true)
	# Keep the callback alive until the DOM listener is removed.
	_web_wheel_callback = JavaScriptBridge.create_callback(_on_web_gesture)
	_web_wheel_listener = JavaScriptBridge.get_interface("AoeWebGestures").install(_web_wheel_callback)

func release_web_gestures() -> void:
	if _web_wheel_listener != null: _web_wheel_listener.dispose()
	_web_wheel_listener = null
	_web_wheel_callback = null

func _on_web_gesture(args: Array) -> void:
	if args.size() != 5: return
	var event: InputEventGesture
	if args[0] == "pan":
		var pan := InputEventPanGesture.new()
		# Browser deltas are canvas pixels; native pan uses logical gesture units.
		pan.delta = Vector2(float(args[1]), float(args[2])) / game.GESTURE_PAN_PIXELS
		event = pan
	elif args[0] == "magnify":
		var magnify := InputEventMagnifyGesture.new()
		magnify.factor = float(args[1])
		event = magnify
	else:
		return
	event.position = Vector2(float(args[3]), float(args[4]))
	# Use the regular GUI/unhandled route so menus, pause and settings keep priority.
	Input.parse_input_event(event)

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

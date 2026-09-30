extends Node2D

var trace: FileAccess
var down := false
var anchor := Vector2.ZERO
var point := Vector2.ZERO
var previous_frame := 0
var minimal := false
var vsync := true
var label: Label
var headless := false
var last_button := "none"

func _ready() -> void:
	headless = DisplayServer.get_name() == "headless"
	trace = FileAccess.open(OS.get_environment("AOE_ENGINE_TRACE"), FileAccess.WRITE)
	minimal = not "--game" in OS.get_cmdline_user_args()
	if minimal:
		label = Label.new()
		label.position = Vector2(20, 20)
		add_child(label)
	RenderingServer.frame_post_draw.connect(func(): log_row({"layer": "post_draw", "down": down}))
	log_row({"layer": "start", "version": Engine.get_version_info(), "minimal": minimal})

func log_row(row: Dictionary) -> void:
	if trace == null: return
	row["t"] = Time.get_unix_time_from_system()
	trace.store_line(JSON.stringify(row))
	if row["layer"] not in ["frame", "post_draw"] and row.get("type", "") != "InputEventMouseMotion": trace.flush()

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	log_row({"layer": "frame", "gap_ms": (now - previous_frame) / 1000.0 if previous_frame else 0.0,
		"buttons": 0 if headless else DisplayServer.mouse_get_button_state(), "input_buttons": Input.get_mouse_button_mask(),
		"x": 0 if headless else DisplayServer.mouse_get_position().x, "y": 0 if headless else DisplayServer.mouse_get_position().y})
	previous_frame = now
	if minimal:
		label.text = "RIGHT-CLICK POC | mode %d | VSync %s\n1 visible / 2 hidden / 3 confined. V toggle VSync. Esc quit.\nLast Godot button: %s | native mask: %d | Input mask: %d\nF7: next gesture intended RIGHT. F8: mark failed RIGHT.\nMasks: 1 LEFT / 2 RIGHT / 3 BOTH. Click away from this text." % [Input.mouse_mode, vsync, last_button, 0 if headless else DisplayServer.mouse_get_button_state(), Input.get_mouse_button_mask()]
		queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		var row := {"layer": "godot", "type": event.get_class(), "x": event.position.x, "y": event.position.y, "mask": event.button_mask}
		if event is InputEventMouseButton:
			row["pressed"] = event.pressed
			row["button"] = event.button_index
			row["ctrl"] = event.ctrl_pressed
			row["shift"] = event.shift_pressed
			row["double_click"] = event.double_click
			row["native_buttons"] = 0 if headless else DisplayServer.mouse_get_button_state()
			row["input_buttons"] = Input.get_mouse_button_mask()
			last_button = "%d %s" % [event.button_index, "DOWN" if event.pressed else "UP"]
			if event.button_index == MOUSE_BUTTON_LEFT:
				down = event.pressed
				if down: anchor = event.position
		point = event.position
		log_row(row)
	if event is InputEventKey and event.pressed and not event.echo:
		log_row({"layer": "key", "key": event.keycode})
		if event.keycode in [KEY_F7, KEY_F8]:
			log_row({"layer": "marker", "action": "failed_right_click" if event.keycode == KEY_F8 else "next_intended_right_click"})
			get_viewport().set_input_as_handled()
		if minimal:
			match event.keycode:
				KEY_1: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				KEY_2: Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
				KEY_3: Input.mouse_mode = Input.MOUSE_MODE_CONFINED_HIDDEN
				KEY_V:
					vsync = not vsync
					DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
					Engine.max_fps = 0 if vsync else 120
				KEY_ESCAPE: get_tree().quit()
		log_row({"layer": "mode", "mode": Input.mouse_mode, "vsync": vsync})

func _draw() -> void:
	if not minimal: return
	draw_circle(point, 6, Color.CYAN)
	if down: draw_rect(Rect2(anchor, point-anchor).abs(), Color.YELLOW, false, 2)

func _exit_tree() -> void:
	if trace: trace.close()

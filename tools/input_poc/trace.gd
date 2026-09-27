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

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	log_row({"layer": "frame", "gap_ms": (now - previous_frame) / 1000.0 if previous_frame else 0.0,
		"buttons": 0 if headless else DisplayServer.mouse_get_button_state(), "input_buttons": Input.get_mouse_button_mask(),
		"x": 0 if headless else DisplayServer.mouse_get_position().x, "y": 0 if headless else DisplayServer.mouse_get_position().y})
	previous_frame = now
	if minimal:
		label.text = "MINIMAL POC | mode %d | VSync %s\nDrag anywhere. 1 visible / 2 hidden / 3 confined. V toggle VSync. Esc quit.\nContinuous frame clock: %.3f" % [Input.mouse_mode, vsync, now / 1000000.0]
		queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		var row := {"layer": "godot", "type": event.get_class(), "x": event.position.x, "y": event.position.y, "mask": event.button_mask}
		if event is InputEventMouseButton:
			row["pressed"] = event.pressed
			row["button"] = event.button_index
			if event.button_index == MOUSE_BUTTON_LEFT:
				down = event.pressed
				if down: anchor = event.position
		point = event.position
		log_row(row)
	if event is InputEventKey and event.pressed and not event.echo:
		log_row({"layer": "key", "key": event.keycode})
		if event.keycode in [KEY_F6, KEY_B] and "--engine-wait-gate" in OS.get_cmdline_user_args():
			var original := OS.get_environment("AOE_POC_SKIP_WAIT_GATE") != "1"
			OS.set_environment("AOE_POC_SKIP_WAIT_GATE", "1" if original else "0")
			get_window().title = "Input POC - %s (B toggles)" % ("ORIGINAL scheduler" if original else "PATCHED scheduler")
			log_row({"layer": "scheduler_mode", "original": original})
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

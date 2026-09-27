extends SceneTree

var game: Node
var probe: Node2D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	probe = load("res://tools/input_poc/trace.gd").new()
	probe.name = "InputTrace"
	root.add_child(probe)
	if "--game" in OS.get_cmdline_user_args():
		game = load("res://tools/input_poc/game_trace.gd").new()
		root.add_child(game)
		await process_frame
		game.start_game("English", 12345)
	else:
		root.title = "Input POC - minimal (1 visible / 2 hidden / 3 confined, V vsync, Esc quit)"
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

	if "--responsive-wait" in OS.get_cmdline_user_args() or "--engine-wait-gate" in OS.get_cmdline_user_args():
		Engine.max_fps = 120
		root.title = "Input POC - responsive frame wait (120 fps cap, VSync unchanged)"
	if "--engine-wait-gate" in OS.get_cmdline_user_args():
		var original := "--original-scheduler" in OS.get_cmdline_user_args()
		OS.set_environment("AOE_POC_SKIP_WAIT_GATE", "1" if original else "0")
		root.title = "Input POC - %s (B toggles original/patched)" % ("ORIGINAL scheduler" if original else "PATCHED scheduler")
		probe.log_row({"layer": "scheduler_mode", "original": original})
	probe.log_row({"layer": "configuration", "max_fps": Engine.max_fps,
		"vsync_mode": DisplayServer.window_get_vsync_mode(), "mouse_mode": Input.mouse_mode,
		"screen_hz": DisplayServer.screen_get_refresh_rate()})

extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var probe := load("res://poc/right-click-poc/trace.gd").new()
	probe.name = "InputTrace"
	root.add_child(probe)
	if "--game" in OS.get_cmdline_user_args():
		var game := load("res://poc/right-click-poc/game_trace.gd").new()
		root.add_child(game)
		await process_frame
		game.start_game("English", 12345)
	else:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	root.title = "Right-click POC | F7 next intended RIGHT | F8 mark failed RIGHT"
	probe.log_row({"layer": "configuration", "max_fps": Engine.max_fps,
		"vsync_mode": DisplayServer.window_get_vsync_mode(), "mouse_mode": Input.mouse_mode,
		"screen_hz": 0 if DisplayServer.get_name() == "headless" else DisplayServer.screen_get_refresh_rate()})

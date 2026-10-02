extends "res://tests/exploration_b21_work_yield.gd"
func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game("English",4242)
	game.ai_controllers.clear()
	game.set_process(false)
	_test_narrow_yield()
	game.navigation.shutdown_jobs()
	for voice in game.feedback_audio.voices: voice.stop(); voice.stream = null
	game.free()
	print("B21_PAIRED_GEOMETRY checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)

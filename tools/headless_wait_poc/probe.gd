extends SceneTree

var started_usec: int
var iterations := 0
var draw_signals := 0
var duration_seconds := 3.0

func _initialize() -> void:
	Engine.max_fps = int(OS.get_environment("AOE_WAIT_POC_FPS"))
	duration_seconds = float(OS.get_environment("AOE_WAIT_POC_SECONDS"))
	RenderingServer.frame_post_draw.connect(func(): draw_signals += 1)
	started_usec = Time.get_ticks_usec()

func _process(_delta: float) -> bool:
	iterations += 1
	var elapsed := (Time.get_ticks_usec() - started_usec) / 1000000.0
	if elapsed < duration_seconds:
		return false
	print("HEADLESS_WAIT_RESULT ", JSON.stringify({
		"elapsed_seconds": elapsed,
		"iterations": iterations,
		"iterations_per_second": iterations / elapsed,
		"max_fps": Engine.max_fps,
		"draw_signals": draw_signals,
		"display": DisplayServer.get_name(),
	}))
	return true

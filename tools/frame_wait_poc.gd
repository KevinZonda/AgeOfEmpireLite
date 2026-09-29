extends SceneTree

# A known amount of main-thread work isolates frame pacing from game/render cost.
# Run windowed with Magnet active to exercise macOS's asynchronous wait branch.
var work_us := 25000
var frames := 0
var last_end := 0
var started := 0
var gaps: Array[float] = []
var intervals: Array[float] = []
var finished := false

func _initialize() -> void:
	if OS.has_environment("RTS_WAIT_WORK_US"): work_us = int(OS.get_environment("RTS_WAIT_WORK_US"))
	Engine.max_fps = 120
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	process_frame.connect(_work)
	RenderingServer.frame_post_draw.connect(_end)

func _work() -> void:
	started = Time.get_ticks_usec()
	while Time.get_ticks_usec() - started < work_us:
		pass

func _end() -> void:
	if finished: return
	var now := Time.get_ticks_usec()
	frames += 1
	if frames > 20:
		gaps.append((started - last_end) / 1000.0)
		intervals.append((now - last_end) / 1000.0)
	last_end = now
	if gaps.size() < 100: return
	finished = true
	print("FRAME_WAIT_POC ", JSON.stringify({"work_us": work_us, "max_fps": Engine.max_fps, "gap_ms": _summary(gaps), "frame_ms": _summary(intervals)}))
	quit()

func _summary(values: Array[float]) -> Dictionary:
	values.sort()
	return {"mean": values.reduce(func(a, b): return a + b, 0.0) / values.size(), "p50": values[values.size() / 2], "p95": values[94]}

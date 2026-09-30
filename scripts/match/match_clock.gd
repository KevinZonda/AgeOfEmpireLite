extends RefCounted

# Simulation time advances only through accepted match steps, independently of
# SceneTree/render frames. Reset is explicit when a new match replaces the world.
var tick_id := 0
var elapsed := 0.0
var delta := 0.0

func advance(step_delta: float) -> void:
	assert(is_finite(step_delta) and step_delta > 0.0)
	tick_id += 1
	delta = step_delta
	elapsed += step_delta

func reset() -> void:
	tick_id = 0
	elapsed = 0.0
	delta = 0.0

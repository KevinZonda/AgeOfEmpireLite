extends RefCounted

# Screen-space joints, reused by all sample infantry and both projections.
var direction := Vector2.DOWN
var aim := Vector2.RIGHT
var across := Vector2.RIGHT
var back := false
var profile := 0.0
var width := 6.0
var chest := Vector2.ZERO
var pelvis := Vector2.ZERO
var head := Vector2.ZERO
var far_shoulder := Vector2.ZERO
var near_shoulder := Vector2.ZERO
var far_hip := Vector2.ZERO
var near_hip := Vector2.ZERO
var far_knee := Vector2.ZERO
var near_knee := Vector2.ZERO
var far_foot := Vector2.ZERO
var near_foot := Vector2.ZERO
var far_hand := Vector2.ZERO
var near_hand := Vector2.ZERO

func update(state) -> void:
	direction = state.facing_direction.normalized()
	if direction.is_zero_approx(): direction = Vector2.DOWN
	back = direction.y < -0.35
	profile = absf(direction.x)
	aim = Vector2(direction.x, direction.y * 0.5).normalized()
	width = lerpf(6.1, 4.2, profile)
	var side := -1.0 if direction.x < -0.1 else 1.0
	across = Vector2(width * side, direction.x * 1.5)
	var stride := sin(state.visual_phase) if state.visual_moving else 0.0
	var weight := cos(state.visual_phase * 2.0) * 0.45 if state.visual_moving else 0.0
	pelvis = Vector2(stride * direction.x * 0.45, -11.0 + weight)
	chest = pelvis + Vector2(-stride * direction.x * 0.6, -10.5)
	head = chest + Vector2(direction.x * 1.2, -9.3)
	far_shoulder = chest - across
	near_shoulder = chest + across
	far_hip = pelvis - across * 0.48
	near_hip = pelvis + across * 0.48
	var ground_step := Vector2(direction.x, direction.y * 0.45)
	for near_side in [false, true]:
		var phase: float = state.visual_phase + (0.0 if near_side else PI)
		var step := sin(phase) * 4.3 if state.visual_moving else 0.0
		var lift := maxf(0.0, cos(phase)) * 2.8 if state.visual_moving else 0.0
		var hip := near_hip if near_side else far_hip
		var foot := Vector2(hip.x, 0.0) + ground_step * step - Vector2(0, lift)
		var knee := hip.lerp(foot, 0.52) + ground_step * (1.0 + lift * 0.6)
		var shoulder := near_shoulder if near_side else far_shoulder
		var hand := shoulder + Vector2(0, 11.5) - ground_step * step * 0.7
		if near_side:
			near_foot = foot
			near_knee = knee
			near_hand = hand
		else:
			far_foot = foot
			far_knee = knee
			far_hand = hand

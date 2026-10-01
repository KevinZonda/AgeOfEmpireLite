extends RefCounted

# Reusable screen-space horse and rider joints. Camera projection stays in caller.
var direction := Vector2.DOWN
var aim := Vector2.DOWN
var across := Vector2.RIGHT
var back := false
var profile := 0.0
var body := Vector2.ZERO
var fore := Vector2.ZERO
var rear := Vector2.ZERO
var horse_head := Vector2.ZERO
var saddle := Vector2.ZERO
var chest := Vector2.ZERO
var head := Vector2.ZERO
var near_shoulder := Vector2.ZERO
var far_shoulder := Vector2.ZERO
var near_hand := Vector2.ZERO
var far_hand := Vector2.ZERO
var hips := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var knees := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var hooves := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])

func update(state) -> void:
	direction = state.facing_direction.normalized()
	if direction.is_zero_approx(): direction = Vector2.DOWN
	back = direction.y < -0.35
	profile = absf(direction.x)
	aim = Vector2(direction.x, direction.y * 0.48).normalized()
	across = Vector2(direction.y * 6.2, -direction.x * 2.8)
	if across.y < -0.01 or (absf(across.y) < 0.01 and across.x < 0.0): across = -across
	var moving: bool = state.visual_moving
	var gallop: bool = moving and (state.charging or state.movement_speed_factor > 1.15)
	var phase: float = state.visual_phase * (1.25 if gallop else 1.0)
	var bob := cos(phase * 2.0) * (1.15 if gallop else 0.55) if moving else 0.0
	body = Vector2(0, -17 + bob)
	var length_axis := Vector2(direction.x * 17.0, direction.y * 6.5)
	fore = body + length_axis * 0.68
	rear = body - length_axis * 0.78
	horse_head = fore + length_axis * 0.6 + Vector2(0, -14.0)
	if moving: horse_head += Vector2(aim.x * sin(phase) * 0.5, bob * 0.35)
	saddle = body - length_axis * 0.1 + Vector2(0, -6.0)
	var lean_amount := 3.2 if state.charging else 0.0
	if state.charge_impact and state.visual_action == "attack": lean_amount = maxf(lean_amount, 3.2 * (1.0 - state.action_progress))
	var lean := aim * lean_amount
	chest = saddle + Vector2(-aim.x * bob * 0.45, -13.0 - bob * 0.45) + lean
	head = chest + Vector2(direction.x, -8.0)
	var rider_width := lerpf(5.5, 3.8, profile)
	var rider_across := Vector2(rider_width * (-1.0 if direction.x < -0.1 else 1.0), direction.x * 1.2)
	near_shoulder = chest + rider_across
	far_shoulder = chest - rider_across
	near_hand = chest + Vector2(rider_across.x * 0.7, 8)
	far_hand = chest + aim * 7.0 + Vector2(-rider_across.x * 0.5, 5)
	# Diagonal pairs trot; charge uses a gathered hind pair and reaching fore pair.
	for index in 4:
		var front := index >= 2
		var near_side := index % 2 == 1
		var origin := fore if front else rear
		var lateral := across * (1.0 if near_side else -1.0)
		hips[index] = origin + lateral * 0.75 + Vector2(0, 3)
		var offset := (0.0 if near_side == front else PI)
		if gallop: offset = (0.0 if front else PI * 0.75) + (0.45 if near_side else 0.0)
		var leg_phase := phase + offset
		var stride := sin(leg_phase) * (7.2 if gallop else 4.4) if moving else 0.0
		var lift := maxf(0.0, cos(leg_phase)) * (5.0 if gallop else 3.0) if moving else 0.0
		hooves[index] = Vector2(origin.x, origin.y - body.y) + lateral + aim * stride - Vector2(0, lift)
		knees[index] = hips[index].lerp(hooves[index], 0.55) + aim * (lift * (0.7 if front else -0.55) + (1.0 if front else -1.0))

extends SceneTree

const Pose = preload("res://scripts/entities/visuals/cavalry_pose.gd")
const Visual = preload("res://scripts/entities/visuals/cavalry_visual.gd")

func _initialize() -> void:
	var state := {"facing_direction": Vector2.DOWN, "visual_phase": 0.0, "visual_moving": false, "charging": false, "charge_impact": false, "visual_action": "", "action_progress": 0.0, "movement_speed_factor": 1.0}
	var pose = Pose.new()
	for kind in ["scout", "horseman", "knight", "royal_knight", "fire_lancer"]:
		assert(Visual.handles(kind))
	assert(not Visual.handles("spearman"))
	for heading in 8:
		state.facing_direction = Vector2.RIGHT.rotated(heading * PI / 4)
		pose.update(state)
		var idle_feet: PackedVector2Array = pose.hooves.duplicate()
		var idle_head: Vector2 = pose.head
		state.visual_phase = 1.1
		pose.update(state)
		assert(idle_feet == pose.hooves and idle_head == pose.head, "idle joints should stay planted")
		state.visual_moving = true
		pose.update(state)
		assert(idle_feet != pose.hooves, "every heading must have a walking gait")
		for index in 4:
			assert(pose.hips[index].is_finite() and pose.knees[index].is_finite() and pose.hooves[index].is_finite())
			assert(pose.hooves[index].distance_to(pose.hips[index]) < 32, "jointed legs must remain attached")
		var walk_chest: Vector2 = pose.chest
		state.charging = true
		pose.update(state)
		assert(walk_chest.distance_to(pose.chest) > 2, "charge must lean rider toward travel heading")
		state.charging = false
		state.visual_moving = false
		pose.update(state)
		var resting_chest: Vector2 = pose.chest
		state.charge_impact = true
		state.visual_action = "attack"
		state.action_progress = 0.2
		pose.update(state)
		assert(pose.chest.distance_to(resting_chest) > 2, "charge impact must keep the rider leaning after charging clears")
		state.action_progress = 1.0
		pose.update(state)
		assert(pose.chest.is_equal_approx(resting_chest), "charge recovery must restore upright riding")
		state.charge_impact = false
		state.visual_action = ""
		state.action_progress = 0.0
	state.facing_direction = Vector2.RIGHT
	pose.update(state)
	var side_span: float = absf(pose.fore.x - pose.rear.x)
	state.facing_direction = Vector2.DOWN
	pose.update(state)
	assert(absf(pose.fore.x - pose.rear.x) < side_span * 0.3, "front and side horse bodies must differ")
	assert(not pose.back)
	state.facing_direction = Vector2.UP
	pose.update(state)
	assert(pose.back)
	print("CAVALRY_POSE_OK")
	quit()

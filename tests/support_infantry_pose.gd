extends SceneTree
const Visual = preload("res://scripts/entities/visuals/support_infantry_visual.gd")
const State = preload("res://scripts/entities/visuals/unit_visual_state.gd")
const Pose = preload("res://scripts/entities/visuals/humanoid_pose.gd")
func _initialize() -> void:
	for kind in ["man_at_arms", "palace_guard"]:
		for heading in 8:
			var state = State.new()
			state.kind = kind
			state.visual_action = "attack"
			state.facing_direction = Vector2.RIGHT.rotated(heading * PI / 4)
			var pose = Pose.new()
			pose.update(state)
			state.action_progress = 0.0
			state.action_released = true
			state.release_elapsed = 0.0
			var blade: Vector2 = Visual._melee_pose(state, pose, true)
			var contact_hand: Vector2 = pose.near_hand
			assert(contact_hand.is_equal_approx(pose.chest + pose.aim * 16 + Vector2(0, 5)), "First hit must already be extended")
			var contact_blade: Vector2 = Vector2(pose.aim.x, 0.4 + pose.aim.y).normalized()
			assert(blade.is_equal_approx(contact_blade))
			state.action_progress = 0.72
			pose.update(state)
			Visual._melee_pose(state, pose, true)
			assert(pose.near_hand.is_equal_approx(contact_hand), "Preparation history must not change actual hit pose")
			state.release_elapsed = 0.10
			pose.update(state)
			Visual._melee_pose(state, pose, true)
			var rest: Vector2 = pose.near_shoulder + Vector2(0, 10)
			assert(pose.near_hand.distance_to(rest) < contact_hand.distance_to(rest))
			assert(not pose.near_hand.is_equal_approx(rest), "Recovery must be continuous")
			state.release_elapsed = 0.17
			pose.update(state)
			Visual._melee_pose(state, pose, true)
			assert(pose.near_hand.is_equal_approx(rest))
			state.action_released = false
			state.action_progress = 0.47
			pose.update(state)
			Visual._melee_pose(state, pose, true)
			assert(pose.near_hand.is_equal_approx(pose.chest - pose.aim * 5 + Vector2(0, -7)), "Windup remains raised")
	print("SUPPORT_INFANTRY_POSE_OK")
	quit()

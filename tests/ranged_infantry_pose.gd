extends SceneTree

const Ranged = preload("res://scripts/entities/visuals/ranged_infantry_visual.gd")
const Pose = preload("res://scripts/entities/visuals/humanoid_pose.gd")
const State = preload("res://scripts/entities/visuals/unit_visual_state.gd")

func _initialize() -> void:
	for kind in ["crossbowman", "arbaletrier", "zhuge_nu", "handcannoneer", "grenadier"]:
		assert(Ranged.handles(kind))
		for heading in 8:
			var state = State.preview(kind, GameData.UNITS[kind], Color("4e9bea"))
			state.facing_direction = Vector2.RIGHT.rotated(heading * PI / 4.0)
			state.visual_action = "attack"
			state.action_progress = 0.4
			var pose := Pose.new()
			pose.update(state)
			if kind == "grenadier":
				Ranged._grenade_pose(state, pose)
				assert(pose.near_hand.y < pose.head.y - 3.0, "prepare must raise the grenade")
				state.action_released = true
				state.release_elapsed = 0.0
				Ranged._grenade_pose(state, pose)
				assert((pose.near_hand - pose.chest).dot(pose.aim) > 16.0, "actual launch extends the throwing hand")
				state.release_elapsed = 0.3
				Ranged._grenade_pose(state, pose)
				assert(pose.near_hand.is_equal_approx(pose.near_shoulder + Vector2(0, 11)), "throw must recover")
			else:
				var aim := Ranged._weapon_pose(state, pose)
				assert(aim.dot(pose.aim) > 0.999, "raised stock must aim with the character in all eight headings")
				assert((pose.far_hand - pose.near_hand).dot(aim) > 9.9, "support hand must hold the forward stock")
				state.action_released = true
				state.release_elapsed = 0.0
				Ranged._weapon_pose(state, pose)
				var impact_hand := pose.near_hand
				state.release_elapsed = 0.16
				Ranged._weapon_pose(state, pose)
				assert((pose.near_hand - impact_hand).dot(pose.aim) > 2.7, "recoil must settle from actual launch age")
				state.action_progress = 0.95
				Ranged._weapon_pose(state, pose)
				assert(pose.far_hand.distance_to(pose.near_hand) < 5.0, "reload must bring the loading hand back to the breech")
				if kind == "handcannoneer":
					state.visual_action = ""
					pose.update(state)
					var carrying := Ranged._weapon_pose(state, pose)
					assert((pose.near_hand + carrying * 23.0).y < 0.0, "carried muzzle must remain above the ground")
	assert(not Ranged.handles("archer"))
	assert(not Ranged.handles("knight"))
	print("RANGED_INFANTRY_POSE_OK")
	quit()

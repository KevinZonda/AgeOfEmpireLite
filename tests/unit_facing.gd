extends SceneTree

const VisualState = preload("res://scripts/entities/visuals/unit_visual_state.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.feedback_audio.free()
	game.feedback_audio = null
	game.start_game("English", 4242)
	game.paused = true
	var unit: RtsUnit = game.units[0]
	var origin := unit.position
	var target := Node2D.new()
	game.add_child(target)
	for isometric in [false, true]:
		if game.view_mode_25d != isometric: game._toggle_view_mode()
		game.camera.force_update_scroll()
		var canvas: Transform2D = root.get_canvas_transform()
		for heading in 8:
			var screen_direction := Vector2.RIGHT.rotated(heading * PI / 4.0)
			unit.position = origin + canvas.affine_inverse().basis_xform(screen_direction * 20.0)
			unit._update_facing(origin)
			assert(VisualState.capture(unit).facing_direction.is_equal_approx(screen_direction), "all eight headings must follow screen movement in either projection")
			var retained: Vector2 = unit.visual_facing_world
			unit._face_direction(Vector2(-0.1, 0))
			assert(unit.visual_facing_world == retained, "collision jitter must not change the retained heading")
		for direction in [Vector2.LEFT, Vector2.RIGHT]:
			unit.position = origin + canvas.affine_inverse().basis_xform(direction * 20.0)
			unit._update_facing(origin)
			assert(unit.facing_right == (direction == Vector2.RIGHT), "movement must follow screen left/right in both camera modes")
			for vertical in [Vector2.UP, Vector2.DOWN, Vector2.ZERO]:
				unit.position = origin + canvas.affine_inverse().basis_xform(vertical * 20.0)
				unit._update_facing(origin)
				assert(unit.facing_right == (direction == Vector2.RIGHT), "vertical movement and stopping must preserve horizontal facing")
		unit.position = origin
		unit.facing_right = true
		unit.position += Vector2(-0.1, 0)
		unit._update_facing(origin)
		assert(unit.facing_right, "tiny collision corrections must not flip the figure")
		unit.position = origin
		unit.target = target
		for action in ["attack", "gather", "build"]:
			for direction in [Vector2.LEFT, Vector2.RIGHT]:
				unit.facing_right = direction != Vector2.RIGHT
				target.position = origin + canvas.affine_inverse().basis_xform(direction * 40.0)
				unit._start_visual_action(action, 0.4)
				assert(unit.facing_right == (direction == Vector2.RIGHT), "actions must face their target before the first animation frame")
		unit.order = "attack"
		unit.visual_last_position = unit.position
		target.position = origin + canvas.affine_inverse().basis_xform(Vector2.LEFT * 40.0)
		unit._tick_visual(0.01)
		assert(not unit.facing_right, "a stationary attack must follow a target that crosses to the other side")
		unit.target = null
		unit.order = "attack_ground"
		unit.destination = origin + canvas.affine_inverse().basis_xform(Vector2.RIGHT * 40.0)
		unit._start_visual_action("attack", 0.4)
		assert(unit.facing_right, "attacking a ground point must face the firing direction")
		unit.order = "idle"
		unit.visual_action_timer = 0.0
		unit.visual_last_position = unit.position
		unit._tick_visual(0.1)
		assert(unit.facing_right, "ending an animation must preserve its last facing")
	# Switching camera modes reprojects the retained world heading even when idle.
	unit._face_direction(Vector2.RIGHT * 20.0)
	var world_heading := unit.visual_facing_world
	var old_heading: Vector2 = VisualState.capture(unit).facing_direction
	game._toggle_view_mode()
	game.camera.force_update_scroll()
	var projected := root.get_canvas_transform().basis_xform(world_heading)
	var expected := Vector2.RIGHT.rotated(round(projected.angle() / (PI / 4.0)) * PI / 4.0)
	assert(unit.visual_facing_world == world_heading and VisualState.capture(unit).facing_direction.is_equal_approx(expected))
	assert(not old_heading.is_equal_approx(expected), "projection changes must update the visible heading without a movement command")
	target.free()
	game.queue_free()
	for frame in 2: await process_frame
	print("UNIT_FACING_OK")
	quit()

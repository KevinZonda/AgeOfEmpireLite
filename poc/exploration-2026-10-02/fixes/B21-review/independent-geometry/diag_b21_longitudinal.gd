extends "res://tests/navigation_construction_poc.gd"
func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game("English",4242)
	game.ai_controllers.clear()
	game.set_process(false)
	reset()
	var legal := true
	var site: RtsBuilding
	for lane in 12:
		for col in 8:
			var at := Vector2(550+col*100,200+lane*90)
			legal = legal and game.can_place("house",at)
			var b: RtsBuilding = game.spawn_building(0,"house",at,lane==3 and col>=1)
			b.set_process(false)
			if lane==3 and col==1:site=b
	var mover := worker(Vector2(709.8823,375.0638))
	mover.position=Vector2(709.8823,375.0638)
	var builder := worker(Vector2(690.2985,368.711))
	builder.position=Vector2(690.2985,368.711)
	builder.issue_command("build",Vector2.INF,site)
	builder.movement.route_stalled_time=1.0
	builder.movement.route_goal=site.position
	builder.movement.route_stop_distance=site.size().x*0.6+builder.radius()

	var third := worker(Vector2(704.4349,351.0641))
	third.position=Vector2(704.4349,351.0641)
	third.issue_command("build",Vector2.INF,site)
	third.movement.route_stalled_time=1.0
	third.movement.route_goal=site.position
	third.movement.route_stop_distance=site.size().x*0.6+third.radius()
	game.navigation.invalidate_spatial_index()
	var step_distance := mover.effective_speed()*0.05
	print("GEOMETRY actual_step=",step_distance)
	var destination := mover.position.move_toward(Vector2(707.1428,350.0),step_distance)
	var forward := (destination-mover.position).normalized()
	var lateral := Vector2(-forward.y,forward.x)
	if (builder.position-mover.position).dot(lateral)<0:lateral=-lateral
	var old_angles_clear := false
	for angle in [0.0,PI/4,-PI/4,PI,3*PI/4,-3*PI/4]:
		var point := builder.position+lateral.rotated(angle)*step_distance
		var clear: bool=game.navigation._motion_clear(builder,point)
		print("GEOMETRY angle=",angle," point=",point," clear=",clear)
		old_angles_clear=old_angles_clear or clear
	var longitudinal: Vector2=builder.position+lateral.rotated(PI/2)*step_distance
	if not game.navigation._motion_clear(builder,longitudinal):longitudinal=builder.position+lateral.rotated(-PI/2)*step_distance
	var clear_longitudinal: bool=game.navigation._motion_clear(builder,longitudinal)
	print("GEOMETRY legal_sites=",legal," initial_legal=",game.navigation.can_occupy(builder.position,builder.radius(),builder,true,false)," blocked_caller=",not game.navigation._motion_clear(mover,destination)," six_angles_clear=",old_angles_clear," longitudinal=",longitudinal," longitudinal_clear=",clear_longitudinal)
	var before:=builder.position
	var result: bool=game.navigation._yield_allies(mover,destination)
	print("GEOMETRY yield_result=",result," builder_displacement=",builder.position.distance_to(before)," caller_clear=",game.navigation._motion_clear(mover,destination)," pos=",builder.position," third=",third.position)
	game.navigation.shutdown_jobs()
	for voice in game.feedback_audio.voices: voice.stop(); voice.stream=null
	game.free()
	quit()

extends "res://tests/navigation_construction_poc.gd"

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game("English", 4242)
	game.ai_controllers.clear()
	game.set_process(false)
	_test_legal_deadlock()
	if not OS.get_cmdline_user_args().has("--legal-only"):
		_test_narrow_yield()
		_test_physical_stall()
		for kind in ["build", "repair", "gather"]:
			_test_yield(kind, "travelling", true)
			_test_yield(kind, "working", false)
			_test_yield(kind, "not_stalled", false)
			_test_yield(kind, "hold", false)
			_test_yield(kind, "enemy", false)
			_test_yield(kind, "lower_priority", false)
			_test_yield(kind, "invalid_goal", false)
			_test_yield(kind, "invalid_target", false)
			_test_yield(kind, "moving_target", false)
			_test_yield(kind, "stale_group", false)
	game.navigation.shutdown_jobs()
	for voice in game.feedback_audio.voices:
		voice.stop()
		voice.stream = null
	game.free()
	print("EXPLORATION_B21_WORK_YIELD checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)

func _test_legal_deadlock() -> void:
	reset()
	var sites: Array[RtsBuilding] = []
	var legal := true
	for lane in 12:
		for col in 8:
			var point := Vector2(550 + col * 100, 200 + lane * 90)
			legal = legal and game.can_place("house", point)
			var site: RtsBuilding = game.spawn_building(0, "house", point, lane == 3 and col >= 1)
			site.set_process(false)
			sites.append(site)
	check(legal, "b21_all_96_sites_are_legal")
	# These seven legal positions reconstruct the dense48 stalled traffic.
	# Keep the original narrow snapped layout and the original 2600-tick limit.
	var points := [Vector2(709.8823,375.0638),Vector2(690.2985,368.711),Vector2(689.9805,668.058),Vector2(709.593,661.3858),Vector2(699.26,641.5241),Vector2(704.4349,351.0641),Vector2(705.8054,681.6865)]
	var movers := {0:Vector2(1526.0,379.859),3:Vector2(1590.0,560.0),4:Vector2(1590.0,650.0)}
	var actors: Array[RtsUnit] = []
	for point in points:
		var unit := worker(point)
		unit.position = point
		actors.append(unit)
	game.navigation.invalidate_spatial_index()
	check(actors.all(func(u: RtsUnit) -> bool: return game.navigation.can_occupy(u.position, u.radius(), u, true, false)), "b21_all_seven_initial_positions_are_clear")
	for i in actors.size():
		if movers.has(i): actors[i].issue_command("move", movers[i])
		else:
			for col in range(1,8): actors[i].issue_command("build", Vector2.INF, sites[3 * 8 + col], col > 1)
			actors[i].issue_command("move", Vector2(1550,470), null, true)
	var safe := true
	for step in 2600:
		tick(actors, 1)
		for i in actors.size():
			for j in range(i + 1, actors.size()):
				if actors[i].position.distance_to(actors[j].position) < actors[i].radius() + actors[j].radius() - 0.01: safe = false
	print("B21_END completed=",sites.filter(func(b:RtsBuilding)->bool:return b.is_complete()).size()," states=",actors.map(func(u:RtsUnit)->Variant:return {"id":u.get_instance_id(),"pos":u.position,"order":u.order,"queue":u.command_queue.size(),"stalled":u.movement.route_stalled_time,"travel_stalled":u.movement.get("travel_stalled_time"),"goal":u.route_goal,"stop":u.movement.route_stop_distance,"target":u.target.position if is_instance_valid(u.target) else Vector2.INF,"route":u.route,"yield":u.movement.yield_timer}))
	check(sites.all(func(b: RtsBuilding) -> bool: return b.is_complete()), "b21_all_96_sites_complete_at_original_deadline")
	check(actors.all(func(u: RtsUnit) -> bool: return u.order == "idle" and u.command_queue.is_empty() and u.position.x > 1450), "b21_all_seven_finish_queues_at_original_deadline")
	check(max_step <= actors[0].effective_speed() * 0.05 + 0.01, "b21_no_teleport")
	check(safe, "b21_never_overlaps_allies")

func _test_yield(kind: String, control: String, expected: bool) -> void:
	reset()
	var building_kind := "farm" if kind == "gather" else "house"
	var site: RtsBuilding = game.spawn_building(0, building_kind, Vector2(600,520), kind == "build")
	site.set_process(false)
	if kind == "repair": site.hp -= 24.0
	var stop_distance: float = site.size().x * (0.6 if kind == "build" else 0.5) + GameData.UNITS["villager"].get("radius",10.0) + (2.0 if kind == "gather" else 0.0)
	var blocker_point := site.position - Vector2(stop_distance + 0.4 if control == "working" else 90.0, 0)
	var caller: RtsUnit
	var blocker: RtsUnit
	if control == "lower_priority":
		blocker = worker(blocker_point)
		caller = worker(blocker_point - Vector2(22,0))
	else:
		caller = worker(blocker_point - Vector2(22,0))
		blocker = worker(blocker_point)
	blocker.issue_command(kind, Vector2.INF, site)
	blocker.issue_command("move", Vector2(400,800), null, true)
	blocker.movement.route_goal = site.position
	blocker.movement.route_stop_distance = stop_distance
	blocker.movement.route_stalled_time = 100.0 if control == "working" else 0.0 if control == "not_stalled" else 1.0
	if blocker.movement.get_property_list().any(func(p: Dictionary) -> bool: return p.name == "travel_stalled_time"):
		blocker.movement.set("travel_stalled_time", 100.0 if control == "working" else 0.0 if control in ["not_stalled", "stale_group"] else 1.0)
	if control == "stale_group": blocker.movement.group_stuck_time = 100.0
	if control == "hold": blocker.stance = "hold"
	if control == "enemy": blocker.owner_id = 1
	if control == "invalid_goal": blocker.movement.route_goal = Vector2.INF
	if control == "invalid_target": blocker.target = null
	var mobile_target: Node2D
	if control == "moving_target":
		# Isolate the live target position from cached route and static footprint.
		mobile_target = Node2D.new()
		game.add_child(mobile_target)
		mobile_target.position = blocker.position + Vector2(stop_distance + 0.4,0)
		blocker.target = mobile_target
	game.navigation.invalidate_spatial_index()
	var before := blocker.position
	var target_before := blocker.target
	var queue_before := blocker.command_queue.duplicate(true)
	var changed: bool = game.navigation._yield_allies(caller, caller.position + Vector2(2.4,0))
	var label := "b21_%s_%s" % [kind, control]
	check(changed == expected and ((blocker.position != before) == expected), label + "_yield_policy")
	check(blocker.order == kind and blocker.target == target_before and blocker.command_queue == queue_before, label + "_preserves_job")
	check(blocker.position.distance_to(before) <= 2.4 + 0.01 and game.navigation._segment_clear(before, blocker.position, blocker.radius(), blocker), label + "_safe_bounded_motion")
	if is_instance_valid(mobile_target): mobile_target.free()

func _test_physical_stall() -> void:
	reset()
	var subject := worker(Vector2(300,300))
	var site: RtsBuilding = game.spawn_building(0, "house", Vector2(600,520), true)
	site.set_process(false)
	var blockers: Array[RtsUnit] = []
	for i in 6:
		var blocker := worker(subject.position + Vector2.from_angle(TAU * i / 6.0) * 21.0)
		blocker.stance = "hold"
		blockers.append(blocker)
	game.navigation.invalidate_spatial_index()
	subject.issue_command("build", Vector2.INF, site)
	var initial := subject.position
	tick([subject], 100)
	check(subject.position == initial, "b21_physical_stall_fixture_cannot_move")
	check(subject.route_failures > 0, "b21_blocked_worker_really_replans")
	var timer: Variant = subject.movement.get("travel_stalled_time")
	check(timer != null and float(timer) >= 4.9, "b21_replanning_does_not_erase_physical_stall")
	if timer == null: return
	subject.issue_command("move", Vector2(900,300))
	check(subject.movement.get("travel_stalled_time") == 0.0, "b21_new_order_clears_physical_stall")
	tick([subject], 30)
	check(float(subject.movement.get("travel_stalled_time")) >= 1.4, "b21_physical_stall_restarts_for_new_order")
	for blocker in blockers:
		game.units.erase(blocker)
		blocker.free()
	game.navigation.invalidate_spatial_index()
	for step in 30:
		subject.movement.move_to(subject, Vector2(900,300),0.05,6.0)
	check(subject.position.distance_to(initial) > 2.0 and float(subject.movement.get("travel_stalled_time")) < RtsUnit.ROUTE_STALL_SECONDS, "b21_real_displacement_clears_physical_stall")
	# Deliver a completed recovery result at a controlled time. Exercise the
	# production take/apply path without depending on a worker scheduling race.
	subject.movement.travel_stalled_time = 2.0
	subject.movement.travel_progress_position = subject.position
	var jobs = game.navigation.background_jobs
	jobs.cancel(subject)
	game.navigation._ensure_current()
	jobs.request(subject, subject.position + Vector2(0,5), Vector2.INF)
	var job: Dictionary = jobs.pending.pop_back()
	var snapshot = game.navigation.RecoveryKernel.capture(game.navigation,subject)
	snapshot.result = PackedVector2Array([subject.position,subject.position + Vector2(0,5)])
	job.snapshot = snapshot
	job.revision = game.navigation.retry_obstacle_revision
	jobs.completed[subject.get_instance_id()] = job
	var accepted: int = jobs.metrics.accepted
	subject.movement.move_to(subject,Vector2(900,300),0.05,6.0)
	check(jobs.metrics.accepted == accepted + 1 and float(subject.movement.get("travel_stalled_time")) >= 2.0, "b21_accepting_recovery_does_not_erase_physical_stall")
	subject.movement.move_to(subject,Vector2(900,300),0.05,6.0)
	check(subject.movement.get("travel_stalled_time") == 0.0, "b21_recovery_displacement_clears_physical_stall")
	subject.movement.travel_stalled_time = 10.0
	subject.movement.move_to(subject, Vector2(1000,300),0.05,6.0)
	check(subject.movement.get("travel_stalled_time") == 0.0, "b21_new_goal_clears_physical_stall")
	subject.movement.travel_stalled_time = 10.0
	subject.movement.move_to(subject,subject.position,0.05,6.0)
	check(subject.movement.get("travel_stalled_time") == 0.0, "b21_arrival_clears_physical_stall")

func _test_narrow_yield() -> void:
	reset()
	var legal := true
	var site: RtsBuilding
	for lane in 12:
		for col in 8:
			var at := Vector2(550 + col * 100,200 + lane * 90)
			legal = legal and game.can_place("house",at)
			var building: RtsBuilding = game.spawn_building(0,"house",at,lane == 3 and col >= 1)
			building.set_process(false)
			if lane == 3 and col == 1: site = building
	var caller := worker(Vector2(709.8823,375.0638))
	var builder := worker(Vector2(690.2985,368.711))
	var third := worker(Vector2(704.4349,351.0641))
	var actors: Array[RtsUnit] = [caller,builder,third]
	var points := [Vector2(709.8823,375.0638),Vector2(690.2985,368.711),Vector2(704.4349,351.0641)]
	for i in actors.size(): actors[i].position = points[i]
	for worker_unit in [builder,third]:
		worker_unit.issue_command("build",Vector2.INF,site)
		worker_unit.issue_command("move",Vector2(1550,470),null,true)
		worker_unit.movement.route_goal = site.position
		worker_unit.movement.route_stop_distance = site.size().x * 0.6 + worker_unit.radius()
		worker_unit.movement.route_stalled_time = 1.0
		if worker_unit.movement.get_property_list().any(func(p: Dictionary) -> bool: return p.name == "travel_stalled_time"):
			worker_unit.movement.set("travel_stalled_time",1.0)
	game.navigation.invalidate_spatial_index()
	check(legal and actors.all(func(u: RtsUnit) -> bool: return game.navigation.can_occupy(u.position,u.radius(),u,true,false)), "b21_narrow_three_actor_fixture_is_legal")
	# Use the actual villager displacement at the original 0.05s timestep.
	var step_distance := caller.effective_speed() * 0.05
	var desired := caller.position.move_toward(Vector2(707.1428,350),step_distance)
	check(not game.navigation._motion_clear(caller,desired), "b21_narrow_caller_really_is_blocked")
	var lateral := Vector2(-(desired-caller.position).normalized().y,(desired-caller.position).normalized().x)
	if (builder.position-caller.position).dot(lateral) < 0.0: lateral = -lateral
	var six_clear := false
	for angle in [0.0,PI/4,-PI/4,PI,3*PI/4,-3*PI/4]:
		six_clear = six_clear or game.navigation._motion_clear(builder,builder.position + lateral.rotated(angle)*step_distance)
	check(not six_clear, "b21_original_six_sidestep_directions_are_blocked")
	var changed: bool = game.navigation._yield_allies(caller,desired)
	check(changed and game.navigation._motion_clear(caller,desired) and builder.position != points[1], "b21_longitudinal_yield_opens_legal_narrow_passage")
	check(builder.order == "build" and third.order == "build" and builder.target == site and third.target == site and builder.command_queue.size() == 1 and third.command_queue.size() == 1, "b21_narrow_yield_preserves_jobs_and_queues")
	check(builder.position.distance_to(points[1]) <= step_distance + 0.01 and third.position.distance_to(points[2]) <= step_distance + 0.01, "b21_narrow_yield_respects_original_speed_bound")
	check(game.navigation._segment_clear(points[1],builder.position,builder.radius(),builder) and game.navigation._segment_clear(points[2],third.position,third.radius(),third) and game.navigation._motion_clear(caller,desired), "b21_narrow_yield_collision_safe")

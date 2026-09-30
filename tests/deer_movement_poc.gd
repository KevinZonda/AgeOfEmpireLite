extends "res://tests/navigation_dense_poc.gd"

func deer_at(game: Fixture, point: Vector2) -> RtsResource:
	var deer := resource(game, point, 8.0)
	deer.game = game
	deer.setup("food", 160, "deer")
	return deer

func _run() -> void:
	for delta in [1.0 / 120.0, 1.0 / 60.0, 1.0 / 30.0, 0.2]:
		var game := fixture()
		var deer := deer_at(game, Vector2(725, 525))
		var threat := game.spawn_unit(deer.position - Vector2(40, 0))
		threat.kind = "spearman"
		var largest := 0.0
		var reversals := 0
		for step in ceili(2.0 / delta):
			var previous := deer.position
			deer._process(delta)
			largest = maxf(largest, previous.distance_to(deer.position))
			if step < ceili(0.3 / delta) and deer.position.x < previous.x - 0.001: reversals += 1
		print("DEER_MOVEMENT_POC delta=%.5f max_step=%.3f allowed=%.3f early_reversals=%d" % [delta, largest, 80.0 * delta, reversals])
		check(largest <= 80.0 * delta + 0.001, "deer_movement_is_speed_bounded")
		check(reversals == 0, "escape_persists_between_threat_scans")
		check(deer.position.distance_to(threat.position) > 75.0, "deer_escapes_threat")
		deer.take_damage(100.0)
		var death_position := deer.position
		deer._process(1.0)
		check(deer.position == death_position, "dead_deer_stays_still")
		game.free()
	_test_wandering()
	_test_shore()
	_test_grazing_cycle()
	_test_escape_transition()
	_test_pause_and_death_pose()
	print("DEER_MOVEMENT_POC checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)

func _test_wandering() -> void:
	var game := fixture()
	var deer := deer_at(game, Vector2(725, 525))
	var villager := game.spawn_unit(deer.position - Vector2(10, 0))
	villager.kind = "villager"
	var largest := 0.0
	for step in 120:
		var previous := deer.position
		deer._process(1.0 / 60.0)
		largest = maxf(largest, previous.distance_to(deer.position))
	check(largest <= 18.0 / 60.0 + 0.001, "wander_starts_without_snapping")
	check(deer.position.distance_to(Vector2(725, 525)) < 20.0, "villager_does_not_frighten_deer")
	game.free()

func _test_shore() -> void:
	var game := fixture()
	for y in game.world_map.grid_size.y:
		game.world_map.cells[y * game.world_map.grid_size.x + 12] = RtsWorldMap.Terrain.WATER
	var deer := deer_at(game, Vector2(598, 525))
	var threat := game.spawn_unit(Vector2(558, 525))
	threat.kind = "spearman"
	deer._process(1.0)
	check(deer.position.x < 600.0, "long_frame_cannot_jump_across_water")
	game.free()

func _test_grazing_cycle() -> void:
	var game := fixture()
	var origin := Vector2(725, 525)
	var deer := deer_at(game, origin)
	var other := deer_at(game, origin + Vector2(40, 30))
	check(not is_equal_approx(deer.deer_pause, other.deer_pause), "herd_grazing_is_not_synchronized")
	for step in 60: deer._process(1.0 / 60.0)
	check(deer.position == origin and deer.deer_graze > 0.99, "grazing_is_stationary_with_lowered_head")
	var moving_frames := 0
	var idle_frames := 0
	var stopped_after_walk := false
	var stays_local := true
	var largest := 0.0
	var pauses_without_stepping := true
	for step in 1800:
		var previous := deer.position
		var phase := deer.deer_phase
		deer._process(1.0 / 60.0)
		var distance := previous.distance_to(deer.position)
		largest = maxf(largest, distance)
		stays_local = stays_local and deer.position.distance_to(origin) <= RtsResource.DEER_WANDER_RADIUS + 0.001
		if distance > 0.00001:
			moving_frames += 1
		else:
			idle_frames += 1
			pauses_without_stepping = pauses_without_stepping and deer.deer_phase == phase
			if moving_frames > 0 and deer.deer_gait == 0.0 and deer.deer_graze > 0.99: stopped_after_walk = true
	check(moving_frames > 120 and idle_frames > 120 and stopped_after_walk, "deer_alternates_short_walks_and_grazing")
	check(stays_local and largest <= RtsResource.DEER_WALK_SPEED / 60.0 + 0.001, "wandering_stays_local_and_speed_bounded")
	check(pauses_without_stepping, "standing_deer_does_not_tread_in_place")
	game.free()

func _test_escape_transition() -> void:
	var game := fixture()
	var deer := deer_at(game, Vector2(725, 525))
	deer._process(0.5)
	var threat := game.spawn_unit(deer.position + Vector2(40, 0))
	threat.kind = "spearman"
	deer.wildlife_scan = 0.0
	var previous := deer.position
	deer._process(1.0 / 60.0)
	check(deer.position.x < previous.x and deer.deer_direction.x < -0.99, "grazing_deer_turns_away_from_threat")
	check(deer.deer_speed > 0.0 and deer.deer_speed < RtsResource.DEER_FLEE_SPEED, "escape_accelerates_from_rest")
	check(deer.deer_graze < 1.0 and deer.deer_gait > 0.0, "escape_raises_head_and_starts_stride")
	for step in 100: deer._process(1.0 / 60.0)
	var new_home := deer.home_position
	check(new_home.x < 690.0 and deer.deer_flee_target == Vector2.INF, "escape_settles_at_new_grazing_area")
	var phase := deer.deer_phase
	var settled := deer.position
	for step in 30: deer._process(1.0 / 60.0)
	check(deer.position == settled and deer.deer_phase == phase and deer.deer_gait == 0.0, "escape_finishes_without_sliding_back")
	game.free()

func _test_pause_and_death_pose() -> void:
	var game := fixture()
	var deer := deer_at(game, Vector2(725, 525))
	deer.deer_walk_target = deer.position + Vector2(20, 0)
	deer._process(0.2)
	var position_before := deer.position
	var phase := deer.deer_phase
	var graze := deer.deer_graze
	game.paused = true
	deer._process(2.0)
	check(deer.position == position_before and deer.deer_phase == phase and deer.deer_graze == graze, "pause_freezes_deer_movement_and_animation")
	game.paused = false
	deer.take_damage(100.0)
	deer._process(2.0)
	check(deer.position == position_before and deer.deer_phase == phase, "dead_deer_does_not_animate")
	game.free()

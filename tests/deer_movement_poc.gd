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

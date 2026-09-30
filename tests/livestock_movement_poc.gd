extends "res://tests/navigation_poc.gd"

class AnimalWorld extends "res://tests/helpers/navigation_fixture.gd":
	func find_nearest_owned_building(owner: int, building_kind: String, _point: Vector2) -> RtsBuilding:
		for node in buildings:
			if node.owner_id == owner and node.kind == building_kind: return node
		return null

class TestUnit extends RtsUnit:
	func take_damage(damage: float) -> void:
		hp = maxf(0.0, hp - damage)

func fixture() -> Fixture:
	var game := AnimalWorld.new()
	root.add_child(game)
	game.initialize(Vector2(1500, 1000))
	return game

func animal(game: Fixture, point: Vector2, species: String) -> RtsResource:
	var node := resource(game, point, 22.0)
	node.game = game
	node.setup("food", 200, species)
	return node

func actor(game: Fixture, point: Vector2, kind: String) -> TestUnit:
	var unit := TestUnit.new()
	unit.game = game
	unit.kind = kind
	unit.hp = 100.0
	unit.max_hp = 100.0
	unit.stats = {"radius": 12.0, "speed": 80.0}
	unit.position = point
	game.add_child(unit)
	unit.set_process(false)
	unit.hide()
	game.units.append(unit)
	game.navigation.invalidate_spatial_index()
	return unit

func _run() -> void:
	_test_boar_continuity()
	_test_boar_attack()
	_test_sheep_follow()
	_test_sheep_delivery()
	_test_shores()
	_test_freezing()
	print("LIVESTOCK_MOVEMENT_POC checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)

func _test_boar_continuity() -> void:
	for delta in [1.0 / 120.0, 1.0 / 60.0, 1.0 / 30.0]:
		var game := fixture()
		var boar := animal(game, Vector2(725, 525), "boar")
		actor(game, boar.position + Vector2(100, 0), "villager")
		var largest := 0.0
		var stationary := 0
		for step in roundi(0.5 / delta):
			var previous := boar.position
			boar._process(delta)
			var distance := boar.position.distance_to(previous)
			largest = maxf(largest, distance)
			if distance < 0.00001: stationary += 1
		print("BOAR_MOVEMENT fps=%d max_step=%.3f stationary=%d" % [roundi(1.0 / delta), largest, stationary])
		check(largest <= 44.0 * delta + 0.001 and stationary == 0, "boar_pursues_continuously_between_scans")
		check(absf(boar.position.x - 747.0) < 0.01, "boar_speed_is_frame_rate_independent")
		check(boar.animal_phase > 0.0 and boar.animal_gait > 0.99 and boar.animal_direction.x > 0.99, "boar_stride_and_facing_follow_motion")
		game.free()

func _test_boar_attack() -> void:
	var game := fixture()
	var boar := animal(game, Vector2(725, 525), "boar")
	var victim := actor(game, boar.position - Vector2(25, 0), "villager")
	var origin := boar.position
	boar._process(0.01)
	check(victim.hp == 89.0 and boar.boar_attack_pose > 0.0 and boar.animal_direction.x < -0.99, "boar_hit_has_facing_and_attack_pose")
	for step in 60: boar._process(1.0 / 60.0)
	check(victim.hp == 89.0 and boar.position == origin and boar.animal_gait == 0.0 and boar.boar_attack_pose == 0.0, "boar_attack_cooldown_and_anchor_stay_stable")
	for step in 15: boar._process(1.0 / 60.0)
	check(victim.hp == 78.0, "boar_next_hit_respects_original_cooldown")
	victim.hp = 0.0
	boar._process(0.1)
	check(boar.boar_target == null, "boar_drops_dead_target_between_scans")
	victim.hp = 100.0
	victim.position = boar.position + Vector2(100, 0)
	game.navigation.invalidate_spatial_index()
	boar.wildlife_scan = 0.0
	boar._process(0.01)
	victim.position += Vector2(150, 0)
	var before := boar.position
	boar._process(0.01)
	check(boar.position == before and boar.boar_target == null, "boar_drops_out_of_range_target")
	game.free()

func _test_sheep_follow() -> void:
	var game := fixture()
	var sheep := animal(game, Vector2(725, 525), "sheep")
	var origin := sheep.position
	sheep._process(0.5)
	check(sheep.position == origin and sheep.animal_graze == 1.0, "unclaimed_sheep_grazes_without_wandering")
	var scout := actor(game, sheep.position - Vector2(65, 0), "scout")
	scout.owner_id = 1
	sheep.claim_timer = 0.0
	sheep._process(1.0 / 60.0)
	check(sheep.claimed_by == 1 and sheep.shepherd == scout, "sheep_claims_and_follows_scout")
	check(sheep.position.x < origin.x and sheep.animal_direction.x < -0.99 and sheep.animal_phase > 0.0, "sheep_turns_and_steps_toward_scout")
	check(sheep.animal_speed < 67.0 and sheep.animal_graze < 1.0, "sheep_raises_head_and_accelerates")
	for step in 120: sheep._process(1.0 / 60.0)
	var settled := sheep.position
	var phase := sheep.animal_phase
	for step in 60: sheep._process(1.0 / 60.0)
	check(sheep.position == settled and sheep.animal_phase == phase and sheep.animal_gait == 0.0 and sheep.animal_graze == 1.0, "sheep_stops_stepping_and_grazes_at_follow_distance")
	scout.position -= Vector2(120, 0)
	var largest := 0.0
	for step in 120:
		var before := sheep.position
		sheep._process(1.0 / 60.0)
		largest = maxf(largest, sheep.position.distance_to(before))
	check(sheep.position.x < settled.x - 50.0 and largest <= 67.0 / 60.0 + 0.001, "claimed_sheep_resumes_speed_bounded_following")
	var food := sheep.harvest(10)
	var carcass := sheep.position
	phase = sheep.animal_phase
	sheep._process(1.0)
	check(food == 10 and sheep.amount == 190 and sheep.wildlife_hp == 0.0 and sheep.shepherd == null and sheep.position == carcass and sheep.animal_phase == phase, "gathered_sheep_becomes_stationary_meat")
	game.free()

func _test_sheep_delivery() -> void:
	var game := fixture()
	var sheep := animal(game, Vector2(725, 525), "sheep")
	actor(game, sheep.position + Vector2(65, 0), "scout")
	var center := RtsBuilding.new()
	center.owner_id = 0
	center.kind = "town_center"
	center.position = sheep.position
	game.add_child(center)
	center.set_process(false)
	center.hide()
	game.buildings.append(center)
	var original := sheep.position
	sheep._process(0.5)
	check(sheep.claimed_by == 0 and sheep.shepherd == null and sheep.position == original and sheep.animal_graze == 1.0, "delivered_sheep_stays_at_town_center")
	game.free()

func _test_shores() -> void:
	for species in ["sheep", "boar"]:
		var game := fixture()
		var node := animal(game, Vector2(575, 525), species)
		actor(game, Vector2(675, 525), "scout" if species == "sheep" else "villager")
		if species == "sheep": node.shepherd = game.units[0]
		for y in game.world_map.grid_size.y:
			game.world_map.cells[y * game.world_map.grid_size.x + 12] = RtsWorldMap.Terrain.WATER
		node._process(3.0)
		check(node.position.x < 600.0, "%s_long_frame_cannot_cross_water" % species)
		game.free()

func _test_freezing() -> void:
	for species in ["sheep", "boar"]:
		var game := fixture()
		var node := animal(game, Vector2(725, 525), species)
		actor(game, node.position + Vector2(65, 0), "scout" if species == "sheep" else "villager")
		node._process(0.1)
		var point := node.position
		var phase := node.animal_phase
		game.paused = true
		node._process(1.0)
		check(node.position == point and node.animal_phase == phase, "%s_pause_freezes_motion_and_pose" % species)
		game.paused = false
		if species == "sheep": node.harvest(1)
		else: node.take_damage(100.0)
		node._process(1.0)
		check(node.position == point and node.animal_phase == phase and node.animal_gait == 0.0, "%s_death_freezes_motion_and_stride" % species)
		game.free()

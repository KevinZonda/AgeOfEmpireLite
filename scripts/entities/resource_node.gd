class_name RtsResource
extends Node2D

const OreVisual = preload("res://scripts/entities/visuals/ore_visual.gd")
const DeerVisual = preload("res://scripts/entities/visuals/deer_visual.gd")
const LivestockVisual = preload("res://scripts/entities/visuals/livestock_visual.gd")
const VegetationVisual = preload("res://scripts/entities/visuals/vegetation_visual.gd")
const FishVisual = preload("res://scripts/entities/visuals/fish_visual.gd")
const FISH_REDRAW_INTERVAL := 1.0 / 12.0
const FISH_VISUAL_RADIUS := 38.0
const ANIMAL_REDRAW_INTERVAL := 0.15
const DEER_WALK_SPEED := 18.0
const DEER_FLEE_SPEED := 80.0
const DEER_THREAT_RADIUS := 75.0
const DEER_WANDER_RADIUS := 32.0
const HEALTH_BAR_CHANGE_DURATION := 3.0
const BOAR_SPEED := 44.0
const SHEEP_SPEED := 67.0
const BOAR_ATTACK_POSE_DURATION := 0.36

var game: Node2D
var kind: String
var amount: int
var initial_amount: int
var radius := 22.0
var appearance := ""
var vegetation_visual: RefCounted
var ore_visual: RefCounted
var home_position := Vector2.ZERO
var wander_time := 0.0
var claimed_by := -1
var shepherd: RtsUnit
var claim_timer := 0.0
var wildlife_hp := 0.0
var wildlife_max_hp := 1.0
var health_bar_timer := 0.0
var wildlife_scan := 0.0
var wildlife_attack := 0.0
var deer_flee_target := Vector2.INF
var deer_walk_target := Vector2.INF
var deer_pause := 0.0
var deer_speed := 0.0
var deer_direction := Vector2.RIGHT
var deer_phase := 0.0
var deer_gait := 0.0
var deer_graze := 0.0
var deer_rng := RandomNumberGenerator.new()
var animal_direction := Vector2.RIGHT
var animal_phase := 0.0
var animal_gait := 0.0
var animal_graze := 0.0
var animal_speed := 0.0
var boar_target: RtsUnit
var boar_attacker: RtsUnit
var boar_attack_pose := 0.0
var fish_time := 0.0
var fish_redraw_timer := 0.0
var fish_visual_seed := 0
var animal_redraw_timer := 0.0

func setup(resource_kind: String, quantity: int, visual_kind := "") -> void:
	kind = resource_kind
	amount = quantity
	initial_amount = quantity
	appearance = visual_kind
	fish_time = 0.0
	fish_redraw_timer = 0.0
	fish_visual_seed = hash(position)
	vegetation_visual = VegetationVisual.new(position, kind == "wood") if kind == "wood" or (kind == "food" and appearance not in ["deer", "boar", "sheep", "fish"]) else null
	ore_visual = OreVisual.new(position, kind) if kind in ["gold", "stone"] else null
	wildlife_max_hp = 90.0 if appearance == "boar" else 12.0 if appearance == "deer" else 1.0
	wildlife_hp = wildlife_max_hp
	health_bar_timer = 0.0
	home_position = position
	deer_flee_target = Vector2.INF
	deer_walk_target = Vector2.INF
	deer_rng.seed = hash(position)
	deer_pause = deer_rng.randf_range(1.5, 3.5)
	deer_speed = 0.0
	deer_direction = Vector2.from_angle(deer_rng.randf_range(0.0, TAU))
	deer_phase = 0.0
	deer_gait = 0.0
	deer_graze = 0.0
	wildlife_scan = 0.0
	animal_direction = deer_direction
	animal_phase = 0.0
	animal_gait = 0.0
	animal_graze = 0.0
	animal_speed = 0.0
	boar_target = null
	boar_attacker = null
	boar_attack_pose = 0.0
	wildlife_attack = 0.0
	claim_timer = 0.0
	# Desynchronize repaint ticks so herds do not redraw on the same frame.
	animal_redraw_timer = deer_rng.randf_range(0.0, ANIMAL_REDRAW_INTERVAL)
	wander_time = position.x * 0.013 + position.y * 0.019
	queue_redraw()

func _process(delta: float) -> void:
	if game == null or not game.started or game.paused or game.game_over: return
	if appearance == "fish":
		_process_fish(delta)
		return
	if health_bar_timer > 0.0:
		health_bar_timer = maxf(0.0, health_bar_timer - delta)
		if health_bar_timer == 0.0: queue_redraw()
	if appearance == "sheep":
		_process_sheep(delta)
		return
	if appearance == "boar":
		_process_boar(delta)
		return
	if appearance != "deer" or wildlife_hp <= 0.0: return
	_process_deer(delta)

func _process_fish(delta: float) -> void:
	# MatchSimulation owns callbacks, so is_processing() is deliberately not a
	# condition here. Hidden or offscreen schools keep their last cosmetic pose.
	if not is_inside_tree() or not is_visible_in_tree() or is_queued_for_deletion() or amount <= 0: return
	if get_tree().paused or not is_finite(delta) or delta <= 0.0: return
	var extent := Vector2.ONE * maxf(radius, FISH_VISUAL_RADIUS)
	var bounds: Rect2 = get_global_transform_with_canvas() * Rect2(-extent, extent * 2.0)
	if not get_viewport_rect().intersects(bounds): return
	fish_time += delta
	fish_redraw_timer += delta
	if fish_redraw_timer >= FISH_REDRAW_INTERVAL:
		fish_redraw_timer = fmod(fish_redraw_timer, FISH_REDRAW_INTERVAL)
		queue_redraw()

func _process_deer(delta: float) -> void:
	wander_time += delta
	wildlife_scan -= delta
	if wildlife_scan <= 0.0:
		wildlife_scan = 0.35
		var threat: RtsUnit
		var nearest := DEER_THREAT_RADIUS * DEER_THREAT_RADIUS
		for unit in game.navigation.nearby_units(position, DEER_THREAT_RADIUS):
			if unit.garrisoned_in != null or unit.kind == "villager": continue
			var distance := position.distance_squared_to(unit.position)
			if distance <= nearest:
				nearest = distance
				threat = unit
		if threat != null:
			var away := (position - threat.position).normalized()
			if away.is_zero_approx(): away = Vector2.RIGHT
			deer_flee_target = position + away * 55.0
			deer_walk_target = Vector2.INF
	# Idle deer graze in place, then choose a short, persistent walk. Each deer
	# has its own seeded RNG so a herd neither moves in sync nor affects map RNG.
	var fleeing := deer_flee_target != Vector2.INF
	if not fleeing and deer_walk_target == Vector2.INF:
		deer_pause -= delta
		if deer_pause <= 0.0: _choose_deer_walk()
	var desired := deer_flee_target if fleeing else deer_walk_target
	if desired == Vector2.INF:
		deer_speed = 0.0
		_update_deer_pose(delta, Vector2.ZERO)
		return
	desired = desired.clamp(Vector2.ONE * radius, game.world_size - Vector2.ONE * radius)
	var previous := position
	var acceleration := 240.0 if fleeing else 45.0
	var top_speed := DEER_FLEE_SPEED if fleeing else DEER_WALK_SPEED
	# Brake before the end of a walk instead of sliding into an abrupt stop.
	var target_speed := minf(top_speed, sqrt(2.0 * acceleration * position.distance_to(desired)))
	var previous_speed := deer_speed
	deer_speed = move_toward(deer_speed, target_speed, acceleration * delta)
	var next := position.move_toward(desired, (previous_speed + deer_speed) * 0.5 * delta)
	# Check the whole movement, including long frames; a walkable endpoint
	# across a lake must not let wildlife jump over the intervening water.
	var blocked := _move_wildlife(next)
	if blocked or position.distance_squared_to(desired) < 0.0625:
		if fleeing:
			# The new grazing area follows the escape, never the old threat.
			home_position = position
			deer_flee_target = Vector2.INF
		deer_walk_target = Vector2.INF
		deer_pause = deer_rng.randf_range(2.0, 5.0)
		deer_speed = 0.0
	_update_deer_pose(delta, position - previous)

func _move_wildlife(next: Vector2) -> bool:
	# Sample the entire segment for every species, including long frames.
	var previous := position
	next = next.clamp(Vector2.ONE * radius, game.world_size - Vector2.ONE * radius)
	var samples := maxi(1, ceili(previous.distance_to(next) / (RtsWorldMap.CELL_SIZE * 0.25)))
	var blocked := false
	for index in range(1, samples + 1):
		var point := previous.lerp(next, float(index) / samples)
		if not game.world_map.is_walkable(point):
			blocked = true
			break
		position = point
	if position != previous: game.navigation.resource_moved(self, previous)
	return blocked

func _choose_deer_walk() -> void:
	for attempt in 8:
		var candidate := position + Vector2.from_angle(deer_rng.randf_range(0.0, TAU)) * deer_rng.randf_range(12.0, 26.0)
		candidate = home_position + (candidate - home_position).limit_length(DEER_WANDER_RADIUS)
		candidate = candidate.clamp(Vector2.ONE * radius, game.world_size - Vector2.ONE * radius)
		if position.distance_to(candidate) >= 10.0 and game.world_map.is_walkable(candidate):
			deer_walk_target = candidate
			return
	deer_pause = deer_rng.randf_range(2.0, 5.0)

func _update_deer_pose(delta: float, movement: Vector2) -> void:
	var moving := movement.length_squared() > 0.000001
	if moving:
		deer_direction = movement.normalized()
		var stride_length := lerpf(24.0, 44.0, clampf(deer_speed / DEER_FLEE_SPEED, 0.0, 1.0))
		deer_phase = fmod(deer_phase + movement.length() * TAU / stride_length, TAU)
	deer_gait = move_toward(deer_gait, minf(1.0, movement.length() / maxf(delta * DEER_WALK_SPEED, 0.001)), delta * 8.0)
	var grazing := not moving and deer_flee_target == Vector2.INF and deer_walk_target == Vector2.INF
	deer_graze = move_toward(deer_graze, 1.0 if grazing else 0.0, delta * 2.5)
	# Repaint on a throttled tick; grazing head motion still updates, just slower.
	# A fully static pose (no gait, no graze) needs no repaint at all.
	_throttle_animal_redraw(delta, moving or deer_gait > 0.001 or deer_graze > 0.001)

func _process_boar(delta: float) -> void:
	if wildlife_hp <= 0.0: return
	wander_time += delta
	wildlife_scan -= delta
	wildlife_attack = maxf(0.0, wildlife_attack - delta)
	boar_attack_pose = maxf(0.0, boar_attack_pose - delta)
	# Damage sources take priority over passive villager scans, including
	# ranged attackers outside the passive warning radius.
	if not _valid_boar_target(boar_attacker): boar_attacker = null
	if boar_attacker != null:
		boar_target = boar_attacker
	# Scan infrequently, but continue pursuing the retained target every frame.
	elif wildlife_scan <= 0.0:
		wildlife_scan = 0.25
		boar_target = null
		var best := 110.0 * 110.0
		for unit in game.navigation.nearby_units(position, 110.0):
			if unit.kind != "villager" or not _valid_boar_target(unit): continue
			var distance := position.distance_squared_to(unit.position)
			if distance < best:
				best = distance
				boar_target = unit
	if not _valid_boar_target(boar_target): boar_target = null
	if boar_target != null and boar_attacker == null and position.distance_squared_to(boar_target.position) >= 110.0 * 110.0: boar_target = null
	var previous := position
	if boar_target != null:
		var offset := boar_target.position - position
		if not offset.is_zero_approx(): animal_direction = offset.normalized()
		if offset.length_squared() <= 30.0 * 30.0:
			animal_speed = 0.0
			if wildlife_attack <= 0.0:
				boar_target.take_damage(11.0)
				wildlife_attack = 1.2
				boar_attack_pose = BOAR_ATTACK_POSE_DURATION
		else:
			animal_speed = BOAR_SPEED
			_move_wildlife(position.move_toward(boar_target.position, minf(BOAR_SPEED * delta, offset.length() - 30.0)))
	else:
		animal_speed = 0.0
	_update_animal_pose(delta, position - previous, boar_target == null)

func _valid_boar_target(unit) -> bool:
	return is_instance_valid(unit) and not unit.is_queued_for_deletion() and unit.hp > 0.0 and unit.garrisoned_in == null and not is_instance_valid(unit.wall_host) and not unit.stats.get("tags", []).has("naval")

func _update_animal_pose(delta: float, movement: Vector2, grazing: bool) -> void:
	var moving := movement.length_squared() > 0.000001
	if moving:
		animal_direction = movement.normalized()
		animal_phase = fmod(animal_phase + movement.length() * TAU / (32.0 if appearance == "sheep" else 28.0), TAU)
	animal_gait = move_toward(animal_gait, 1.0 if moving else 0.0, delta * 8.0)
	animal_graze = move_toward(animal_graze, 1.0 if grazing and not moving else 0.0, delta * 2.5)
	_throttle_animal_redraw(delta, moving or animal_gait > 0.001 or animal_graze > 0.001 or boar_attack_pose > 0.0)

func _throttle_animal_redraw(delta: float, animated: bool) -> void:
	if not animated:
		animal_redraw_timer = 0.0
		return
	animal_redraw_timer += delta
	if animal_redraw_timer >= ANIMAL_REDRAW_INTERVAL:
		animal_redraw_timer = fmod(animal_redraw_timer, ANIMAL_REDRAW_INTERVAL)
		queue_redraw()

func has_wildlife_health() -> bool:
	return appearance in ["deer", "boar", "sheep"]

func take_damage(damage: float, attacker: RtsUnit = null) -> void:
	if not has_wildlife_health() or wildlife_hp <= 0.0: return
	var previous_hp := wildlife_hp
	wildlife_hp = maxf(0.0, wildlife_hp - damage)
	if wildlife_hp <= 0.0:
		shepherd = null
		boar_target = null
		boar_attacker = null
		boar_attack_pose = 0.0
		animal_gait = 0.0
		animal_speed = 0.0
	elif appearance == "boar" and wildlife_hp < previous_hp and _valid_boar_target(attacker):
		boar_attacker = attacker
		boar_target = attacker
	if not is_equal_approx(wildlife_hp, previous_hp): health_bar_timer = HEALTH_BAR_CHANGE_DURATION
	queue_redraw()

func should_show_health_bar() -> bool:
	return has_wildlife_health() and wildlife_hp > 0.0 and game != null and game.has_method("should_show_health_bar") and game.should_show_health_bar(wildlife_hp, wildlife_max_hp, health_bar_timer)

func _process_sheep(delta: float) -> void:
	if wildlife_hp <= 0.0: return
	wander_time += delta
	claim_timer -= delta
	if claim_timer <= 0.0:
		claim_timer = 0.3
		var closest := 75.0 * 75.0
		for unit in game.navigation.nearby_units(position, 75.0):
			if unit.hp <= 0.0 or unit.kind != "scout": continue
			var distance := position.distance_squared_to(unit.position)
			if distance < closest:
				closest = distance
				claimed_by = unit.owner_id
				shepherd = unit
				queue_redraw()
	if not is_instance_valid(shepherd) or shepherd.is_queued_for_deletion(): shepherd = null
	if shepherd != null and (shepherd.hp <= 0.0 or shepherd.garrisoned_in != null): shepherd = null
	var previous := position
	var following := false
	if shepherd != null:
		var center: RtsBuilding = game.find_nearest_owned_building(claimed_by, "town_center", position)
		if center != null and position.distance_to(center.position) < 100.0:
			shepherd = null
		else:
			var goal := shepherd.position - (shepherd.position - position).normalized() * 28.0
			var remaining := maxf(0.0, position.distance_to(goal) - 18.0)
			if remaining > 0.01:
				following = true
				var desired_speed := minf(SHEEP_SPEED, sqrt(2.0 * 180.0 * remaining))
				var old_speed := animal_speed
				animal_speed = move_toward(animal_speed, desired_speed, 180.0 * delta)
				_move_wildlife(position.move_toward(goal, minf((old_speed + animal_speed) * 0.5 * delta, remaining)))
	if not following: animal_speed = 0.0
	_update_animal_pose(delta, position - previous, not following)

func harvest(quantity: int) -> int:
	if appearance in ["boar", "deer"] and wildlife_hp > 0.0: return 0
	var taken: int = mini(quantity, amount)
	if appearance == "sheep" and taken > 0 and wildlife_hp > 0.0:
		# The first gathering action slaughters sheep; meat must stay put.
		take_damage(wildlife_hp)
		if game != null: game.navigation.invalidate_obstacles()
	amount -= taken
	if amount <= 0:
		if game != null: game.navigation.invalidate_obstacles()
		queue_free()
	else:
		queue_redraw()
	return taken

func _draw() -> void:
	var isometric: bool = game != null and game.view_mode_25d
	var canvas := get_viewport().get_canvas_transform()
	if isometric and appearance != "fish":
		var ground_lift := RtsIsoProjection.ground_lift(game, position)
		draw_set_transform_matrix(Transform2D(0.0, ground_lift))
		if vegetation_visual != null: vegetation_visual.draw_ground(self, kind == "wood")
		elif ore_visual != null: ore_visual.draw_ground(self)
		else: draw_circle(Vector2.ZERO, radius * 0.75, Color("1f302a", 0.45))
		draw_set_transform_matrix(RtsIsoProjection.upright(canvas, ground_lift, game.camera.zoom.x))
	elif vegetation_visual != null:
		vegetation_visual.draw_ground(self, kind == "wood")
	elif ore_visual != null:
		ore_visual.draw_ground(self)
	var color := Color("82ba62")
	match kind:
		"wood": color = Color("397948")
		"gold": color = Color("e4c359")
		"stone": color = Color("9b9f9e")
	var outline := Color("26352d")
	if appearance == "fish":
		# Fish share the projected water plane instead of an upright land sprite.
		FishVisual.draw(self, Transform2D.IDENTITY, fish_time, fish_visual_seed, float(amount) / maxf(initial_amount, 1), isometric)
	elif appearance == "deer":
		if wildlife_hp > 0.0:
			var figure := Transform2D.IDENTITY
			if isometric:
				figure = RtsIsoProjection.upright(canvas, RtsIsoProjection.ground_lift(game, position), game.camera.zoom.x)
			else:
				draw_set_transform_matrix(Transform2D(0.0, Vector2(1, 0.35), 0.0, Vector2.ZERO))
				draw_circle(Vector2.ZERO, radius * 0.75, Color("1f302a", 0.35))
			DeerVisual.draw(self, figure, canvas.basis_xform(deer_direction).normalized(), deer_phase, deer_gait, deer_graze, wander_time, deer_speed / DEER_FLEE_SPEED)
			draw_set_transform_matrix(figure)
		else:
			var figure := RtsIsoProjection.upright(canvas, RtsIsoProjection.ground_lift(game, position), game.camera.zoom.x) if isometric else Transform2D.IDENTITY
			DeerVisual.draw_carcass(self, figure)
	elif appearance in ["boar", "sheep"]:
		var figure := RtsIsoProjection.upright(canvas, RtsIsoProjection.ground_lift(game, position), game.camera.zoom.x) if isometric else Transform2D.IDENTITY
		if not isometric:
			draw_set_transform_matrix(Transform2D(0.0, Vector2(1, 0.35), 0.0, Vector2.ZERO))
			draw_circle(Vector2.ZERO, radius * 0.75, Color("1f302a", 0.35))
		var wool: Color = Color("efead9") if claimed_by < 0 else game.player_color(claimed_by).lightened(0.35)
		LivestockVisual.draw(self, figure, appearance, canvas.basis_xform(animal_direction).normalized(), animal_phase, animal_gait, animal_graze, wander_time, boar_attack_pose, wildlife_hp > 0.0, wool)
	elif kind == "wood":
		if vegetation_visual != null: vegetation_visual.draw(self, true, isometric, float(amount) / maxf(initial_amount, 1))
	elif kind == "food":
		if vegetation_visual != null: vegetation_visual.draw(self, false, isometric, float(amount) / maxf(initial_amount, 1))
	elif kind == "gold" or kind == "stone":
		var fraction := clampf(float(amount) / maxf(float(initial_amount), 1.0), 0.0, 1.0)
		if ore_visual != null: ore_visual.draw(self, isometric, fraction)
	else:
		var points := PackedVector2Array([Vector2(-22, 14), Vector2(-16, -10), Vector2(2, -20), Vector2(22, -8), Vector2(20, 17)])
		draw_colored_polygon(points, color)
		draw_polyline(points + PackedVector2Array([points[0]]), outline, 2.0)
		draw_line(Vector2(-16, -10), Vector2(2, -20), color.lightened(0.25), 2)
	if should_show_health_bar():
		var bar_transform := RtsIsoProjection.upright(canvas, RtsIsoProjection.ground_lift(game, position), game.camera.zoom.x) if isometric else Transform2D.IDENTITY
		draw_set_transform_matrix(bar_transform)
		var bar_y := -58.0 if appearance == "deer" else -42.0 if appearance == "sheep" else -32.0
		draw_rect(Rect2(-16, bar_y, 32, 4), Color("422f2d"))
		draw_rect(Rect2(-16, bar_y, 32 * clampf(wildlife_hp / wildlife_max_hp, 0.0, 1.0), 4), Color("82dd8b"))
	draw_set_transform_matrix(Transform2D.IDENTITY)

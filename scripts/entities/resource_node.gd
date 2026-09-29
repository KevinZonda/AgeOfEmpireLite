class_name RtsResource
extends Node2D

const OreVisual = preload("res://scripts/entities/visuals/ore_visual.gd")
const DEER_WALK_SPEED := 18.0
const DEER_FLEE_SPEED := 80.0
const DEER_THREAT_RADIUS := 75.0

var game: Node2D
var kind: String
var amount: int
var initial_amount: int
var radius := 22.0
var appearance := ""
var home_position := Vector2.ZERO
var wander_time := 0.0
var claimed_by := -1
var shepherd: RtsUnit
var claim_timer := 0.0
var wildlife_hp := 0.0
var wildlife_scan := 0.0
var wildlife_attack := 0.0
var deer_flee_target := Vector2.INF

func setup(resource_kind: String, quantity: int, visual_kind := "") -> void:
	kind = resource_kind
	amount = quantity
	initial_amount = quantity
	appearance = visual_kind
	wildlife_hp = 90.0 if appearance == "boar" else 12.0 if appearance == "deer" else 1.0
	home_position = position
	deer_flee_target = Vector2.INF
	wander_time = position.x * 0.013 + position.y * 0.019
	queue_redraw()

func _process(delta: float) -> void:
	if game == null or not game.started or game.paused or game.game_over: return
	if appearance == "sheep":
		_process_sheep(delta)
		return
	if appearance == "boar":
		_process_boar(delta)
		return
	if appearance != "deer" or wildlife_hp <= 0.0: return
	_process_deer(delta)

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
	# Keep the escape between scans instead of jumping back to the home orbit
	# on the very next frame. Both wandering and fleeing obey a speed limit.
	var fleeing := deer_flee_target != Vector2.INF
	var desired := deer_flee_target if fleeing else home_position + Vector2(sin(wander_time * 0.75) * 14.0, cos(wander_time * 0.52) * 10.0)
	desired = desired.clamp(Vector2.ONE * radius, game.world_size - Vector2.ONE * radius)
	var previous := position
	var next := position.move_toward(desired, (DEER_FLEE_SPEED if fleeing else DEER_WALK_SPEED) * delta)
	# Check the whole movement, including long frames; a walkable endpoint
	# across a lake must not let wildlife jump over the intervening water.
	var samples := maxi(1, ceili(previous.distance_to(next) / (RtsWorldMap.CELL_SIZE * 0.25)))
	var blocked := false
	for index in range(1, samples + 1):
		var point := previous.lerp(next, float(index) / samples)
		if not game.world_map.is_walkable(point):
			blocked = true
			break
		position = point
	if fleeing and (blocked or position.distance_squared_to(desired) < 0.01):
		# Settle where the escape ended rather than orbiting the old threat.
		home_position = position
		deer_flee_target = Vector2.INF
	if position != previous:
		game.navigation.resource_moved(self, previous)
		queue_redraw()

func _process_boar(delta: float) -> void:
	if wildlife_hp <= 0.0: return
	wildlife_scan -= delta
	wildlife_attack = maxf(0.0, wildlife_attack - delta)
	if wildlife_scan > 0.0: return
	wildlife_scan = 0.25
	var victim: RtsUnit
	var best := 110.0 * 110.0
	for unit in game.navigation.nearby_units(position, 110.0):
		if unit.kind != "villager" or unit.garrisoned_in != null: continue
		var distance := position.distance_squared_to(unit.position)
		if distance < best:
			best = distance
			victim = unit
	if victim == null: return
	if best <= 30.0 * 30.0:
		if wildlife_attack <= 0.0:
			victim.take_damage(11.0)
			wildlife_attack = 1.2
		return
	var next := position.move_toward(victim.position, 44.0 * 0.25)
	if game.world_map.is_walkable(next):
		var previous := position
		position = next
		game.navigation.resource_moved(self, previous)
		queue_redraw()

func take_damage(damage: float) -> void:
	if appearance not in ["boar", "deer"] or wildlife_hp <= 0.0: return
	wildlife_hp = maxf(0.0, wildlife_hp - damage)
	queue_redraw()

func _process_sheep(delta: float) -> void:
	claim_timer -= delta
	if claim_timer <= 0.0:
		claim_timer = 0.3
		var closest := 75.0 * 75.0
		for unit in game.units:
			if not is_instance_valid(unit) or unit.kind != "scout" or unit.garrisoned_in != null: continue
			var distance := position.distance_squared_to(unit.position)
			if distance < closest:
				closest = distance
				claimed_by = unit.owner_id
				shepherd = unit
				queue_redraw()
	if not is_instance_valid(shepherd): shepherd = null
	if shepherd == null: return
	var center: RtsBuilding = game.find_nearest_owned_building(claimed_by, "town_center", position)
	if center != null and position.distance_to(center.position) < 100.0:
		shepherd = null
		return
	var goal := shepherd.position - (shepherd.position - position).normalized() * 28.0
	if position.distance_to(goal) <= 18.0: return
	var next := position.move_toward(goal, 67.0 * delta)
	if game.world_map.is_walkable(next):
		var previous := position
		position = next
		game.navigation.resource_moved(self, previous)
		queue_redraw()

func harvest(quantity: int) -> int:
	if appearance in ["boar", "deer"] and wildlife_hp > 0.0: return 0
	var taken: int = mini(quantity, amount)
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
		draw_circle(Vector2.ZERO, radius * 0.75, Color("1f302a", 0.45))
		draw_set_transform_matrix(RtsIsoProjection.upright(canvas, ground_lift, game.camera.zoom.x))
	var color := Color("82ba62")
	match kind:
		"wood": color = Color("397948")
		"gold": color = Color("e4c359")
		"stone": color = Color("9b9f9e")
	var outline := Color("26352d")
	if appearance == "fish":
		var body := PackedVector2Array([Vector2(-16, 0), Vector2(4, -7), Vector2(16, 0), Vector2(4, 7)])
		draw_colored_polygon(body, Color("c5d9cf"))
		draw_polyline(body + PackedVector2Array([body[0]]), outline, 2.0)
		draw_colored_polygon(PackedVector2Array([Vector2(-16, 0), Vector2(-24, -7), Vector2(-24, 7)]), Color("9fc9cc"))
		draw_circle(Vector2(9, -2), 1.5, Color("253947"))
	elif appearance == "deer":
		if wildlife_hp > 0.0:
			draw_ellipse_shape()
		else:
			var carcass := PackedVector2Array([Vector2(-20, 2), Vector2(-14, -5), Vector2(13, -5), Vector2(21, 2), Vector2(14, 9), Vector2(-14, 9)])
			draw_colored_polygon(carcass, Color("886448"))
			draw_polyline(carcass + PackedVector2Array([carcass[0]]), outline, 2.0)
			draw_line(Vector2(14, -1), Vector2(24, -8), Color("674b37"), 2.0)
	elif appearance == "boar":
		var body := PackedVector2Array([Vector2(-20, -9), Vector2(8, -13), Vector2(22, -3), Vector2(18, 12), Vector2(-18, 11)])
		draw_colored_polygon(body, Color("684d3a") if wildlife_hp > 0.0 else Color("886b54"))
		draw_polyline(body + PackedVector2Array([body[0]]), outline, 2.0)
		draw_circle(Vector2(17, -5), 6, Color("795640"))
		draw_arc(Vector2(17, -5), 6, 0, TAU, 16, outline, 1.5)
	elif appearance == "sheep":
		draw_circle(Vector2.ZERO, 16, Color("efead9") if claimed_by < 0 else game.player_color(claimed_by).lightened(0.35))
		draw_arc(Vector2.ZERO, 16, 0, TAU, 24, outline, 2.0)
		draw_circle(Vector2(11, -8), 7, Color("d8ccb2"))
		draw_circle(Vector2(13, -10), 1.5, Color("252b27"))
		draw_line(Vector2(-8, 9), Vector2(-8, 19), Color("8d8574"), 2)
		draw_line(Vector2(5, 9), Vector2(5, 19), Color("8d8574"), 2)
	elif kind == "wood":
		draw_circle(Vector2(0, 8), 9, Color("6d4a31"))
		draw_circle(Vector2(0, -4), 19, color)
		draw_arc(Vector2(0, -4), 19, 0, TAU, 28, outline, 2.0)
		draw_circle(Vector2(-7, -9), 8, color.lightened(0.15))
	elif kind == "food":
		draw_circle(Vector2.ZERO, radius, Color("456d31"))
		draw_arc(Vector2.ZERO, radius, 0, TAU, 28, outline, 2.0)
		for point in [Vector2(-10, -8), Vector2(8, -11), Vector2(4, 9), Vector2(-11, 8)]:
			draw_circle(point, 5, Color("d86b65"))
	elif kind == "gold" or kind == "stone":
		var fraction := clampf(float(amount) / maxf(float(initial_amount), 1.0), 0.0, 1.0)
		if isometric: OreVisual.draw_25d(self, kind, fraction)
		else: OreVisual.draw_2d(self, kind, fraction)
	else:
		var points := PackedVector2Array([Vector2(-22, 14), Vector2(-16, -10), Vector2(2, -20), Vector2(22, -8), Vector2(20, 17)])
		draw_colored_polygon(points, color)
		draw_polyline(points + PackedVector2Array([points[0]]), outline, 2.0)
		draw_line(Vector2(-16, -10), Vector2(2, -20), color.lightened(0.25), 2)
	if isometric: draw_set_transform_matrix(Transform2D.IDENTITY)

func draw_ellipse_shape() -> void:
	var body := PackedVector2Array([Vector2(-18, -4), Vector2(12, -8), Vector2(21, 1), Vector2(5, 9), Vector2(-15, 8)])
	draw_colored_polygon(body, Color("a8794e"))
	draw_polyline(body + PackedVector2Array([body[0]]), Color("26352d"), 2.0)
	draw_circle(Vector2(17, -9), 8, Color("b98b59"))
	draw_arc(Vector2(17, -9), 8, 0, TAU, 16, Color("26352d"), 1.5)
	draw_circle(Vector2(20, -11), 1.5, Color("24251f"))
	draw_line(Vector2(-11, 6), Vector2(-13, 19), Color("543f31"), 3)
	draw_line(Vector2(6, 6), Vector2(10, 19), Color("543f31"), 3)
	draw_line(Vector2(16, -15), Vector2(10, -27), Color("674b37"), 2)
	draw_line(Vector2(10, -27), Vector2(5, -29), Color("674b37"), 2)
	draw_line(Vector2(10, -27), Vector2(13, -31), Color("674b37"), 2)
	draw_line(Vector2(20, -15), Vector2(23, -25), Color("674b37"), 2)

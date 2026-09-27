class_name RtsProjectile
extends Node2D

var game: Node2D
var owner_id := 0
var target: Node2D
var impact_damage := 0.0
var speed := 350.0
var remaining_life := 4.0
var splash_radius := 0.0
var source_stats: Dictionary = {}
var attack_profile: Dictionary = {}
var last_destination := Vector2.ZERO
var launch_position := Vector2.ZERO
var previous_position := Vector2.ZERO
var fixed_target := false


func setup(game_ref: Node2D, player_id: int, origin: Vector2, enemy: Node2D, damage_amount: float, flight_speed: float = 350.0, area_radius: float = 0.0, attacker: Dictionary = {}, profile: Dictionary = {}) -> void:
	game = game_ref
	owner_id = player_id
	position = origin
	launch_position = origin
	previous_position = origin
	target = enemy
	impact_damage = damage_amount
	speed = maxf(1.0, flight_speed)
	splash_radius = maxf(0.0, area_radius)
	source_stats = attacker.duplicate(true)
	attack_profile = profile.duplicate(true)
	last_destination = enemy.global_position
	visible = owner_id == 0 or not game.fog.active or game.fog.can_see(0, position)
	queue_redraw()

func setup_point(game_ref: Node2D, player_id: int, origin: Vector2, point: Vector2, damage_amount: float, flight_speed: float, area_radius: float, attacker: Dictionary, profile: Dictionary) -> void:
	game = game_ref
	owner_id = player_id
	position = origin
	launch_position = origin
	previous_position = origin
	target = null
	fixed_target = true
	last_destination = point
	impact_damage = damage_amount
	speed = maxf(1.0, flight_speed)
	splash_radius = maxf(1.0, area_radius)
	source_stats = attacker.duplicate(true)
	attack_profile = profile.duplicate(true)
	visible = owner_id == 0 or not game.fog.active or game.fog.can_see(0, position)
	queue_redraw()


func _process(delta: float) -> void:
	if not is_instance_valid(game) or game.game_over:
		queue_free()
		return
	if game.paused or not game.started: return
	visible = owner_id == 0 or not game.fog.active or game.fog.can_see(0, position)
	if (not is_instance_valid(target) or target.is_queued_for_deletion()) and splash_radius <= 0.0:
		queue_free()
		return
	remaining_life -= delta
	if remaining_life <= 0.0:
		queue_free()
		return

	var destination := target.global_position if not fixed_target and is_instance_valid(target) and not target.is_queued_for_deletion() else last_destination
	last_destination = destination
	var travel := speed * delta
	if global_position.distance_to(destination) <= travel + 3.0:
		var impact_point := destination
		if is_instance_valid(target) and not target.is_queued_for_deletion(): target.take_damage(impact_damage)
		if float(attack_profile.get("pierce_length", 0.0)) > 0.0 and game.has_method("nearest_enemy"):
			var direction := (destination - launch_position).normalized()
			var end := destination + direction * float(attack_profile["pierce_length"])
			for entity in game.units:
				if not is_instance_valid(entity) or entity == target or entity.is_queued_for_deletion() or not game.is_enemy(owner_id, entity.owner_id) or entity.garrisoned_in != null: continue
				var closest := Geometry2D.get_closest_point_to_segment(entity.global_position, launch_position, end)
				if entity.global_position.distance_to(closest) <= entity.radius() + float(attack_profile.get("pierce_width", 0.0)):
					entity.take_damage(RtsCombatRules.volley_damage(source_stats, entity.stats, attack_profile))
		if splash_radius > 0.0 and game.has_method("nearest_enemy"):
			for entity in game.units + game.buildings:
				if not is_instance_valid(entity) or entity.is_queued_for_deletion() or entity == target or not game.is_enemy(owner_id, entity.owner_id): continue
				if entity is RtsUnit and entity.garrisoned_in != null: continue
				if entity.global_position.distance_to(destination) > splash_radius + (entity.radius() if entity is RtsUnit else entity.size().x * 0.5): continue
				var amount := RtsCombatRules.volley_damage(source_stats, entity.stats, attack_profile) * (1.0 if fixed_target else 0.5)
				entity.take_damage(amount)
		game.show_hit(global_position, impact_point, owner_id, "siege" if splash_radius > 0.0 else "ranged")
		queue_free()
		return
	previous_position = global_position
	global_position = global_position.move_toward(destination, travel)
	queue_redraw()


func _draw() -> void:
	if game == null: return
	var canvas := get_viewport().get_canvas_transform()
	var flight_length := maxf(1.0, launch_position.distance_to(last_destination))
	var progress := clampf(launch_position.distance_to(global_position) / flight_length, 0.0, 1.0)
	var arc_height := sin(progress * PI) * minf(38.0, flight_length * 0.16)
	var screen_travel := canvas.basis_xform(global_position - previous_position).normalized()
	if screen_travel == Vector2.ZERO: screen_travel = Vector2.RIGHT
	var screen_lift := Vector2(0, -arc_height)
	if game.view_mode_25d:
		screen_lift += canvas.basis_xform(RtsIsoProjection.ground_lift(game, global_position))
		draw_set_transform_matrix(RtsIsoProjection.upright(canvas, RtsIsoProjection.world_delta(canvas, screen_lift)))
	else:
		draw_set_transform_matrix(Transform2D(0.0, screen_lift))
	var size := 4.2 if splash_radius > 0.0 else 2.8
	draw_line(-screen_travel * (size + 7.0), -screen_travel * size, Color("ffe4a0", 0.68), 2.0)
	draw_circle(Vector2.ZERO, size + 1.6, Color("2f2921", 0.86))
	draw_circle(Vector2.ZERO, size, Color("ffdc82"))
	draw_set_transform_matrix(Transform2D.IDENTITY)

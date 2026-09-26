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


func setup(game_ref: Node2D, player_id: int, origin: Vector2, enemy: Node2D, damage_amount: float, flight_speed: float = 350.0, area_radius: float = 0.0, attacker: Dictionary = {}, profile: Dictionary = {}) -> void:
	game = game_ref
	owner_id = player_id
	position = origin
	target = enemy
	impact_damage = damage_amount
	speed = maxf(1.0, flight_speed)
	splash_radius = maxf(0.0, area_radius)
	source_stats = attacker.duplicate(true)
	attack_profile = profile.duplicate(true)
	last_destination = enemy.global_position
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

	var destination := target.global_position if is_instance_valid(target) and not target.is_queued_for_deletion() else last_destination
	last_destination = destination
	var travel := speed * delta
	if global_position.distance_to(destination) <= travel + 3.0:
		var impact_point := destination
		if is_instance_valid(target) and not target.is_queued_for_deletion(): target.take_damage(impact_damage)
		if splash_radius > 0.0 and game.has_method("nearest_enemy"):
			for entity in game.units + game.buildings:
				if not is_instance_valid(entity) or entity.is_queued_for_deletion() or entity == target or not game.is_enemy(owner_id, entity.owner_id): continue
				if entity is RtsUnit and entity.garrisoned_in != null: continue
				if entity.global_position.distance_to(destination) > splash_radius + (entity.radius() if entity is RtsUnit else entity.size().x * 0.5): continue
				var amount := RtsCombatRules.volley_damage(source_stats, entity.stats, attack_profile) * 0.5
				entity.take_damage(amount)
		game.show_hit(global_position, impact_point, owner_id)
		queue_free()
		return
	global_position = global_position.move_toward(destination, travel)


func _draw() -> void:
	draw_circle(Vector2.ZERO, 4.0, Color("25221c"))
	draw_circle(Vector2.ZERO, 2.5, Color("eed899"))

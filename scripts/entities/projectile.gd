class_name RtsProjectile
extends Node2D

# The bolt shape never changes in flight; only the transform does. A child
# node draws it once, and movement updates the child's position/rotation/scale
# instead of replaying the draw commands every frame.
class BoltVisual extends Node2D:
	func _draw() -> void:
		var bolt := get_parent() as RtsProjectile
		if bolt == null: return
		if bolt.attack_profile.get("hunting", false):
			var tail := Vector2(-18.0, 0.0)
			var side := Vector2(0.0, 3.0)
			var forward := Vector2(4.0, 0.0)
			var back := Vector2(-3.0, 0.0)
			draw_line(tail, Vector2.ZERO, Color("302820"), 3.5)
			draw_line(tail, Vector2.ZERO, Color("e4c894"), 1.8)
			draw_colored_polygon(PackedVector2Array([forward, back + side, back - side]), Color("e1e6dc"))
			draw_line(tail + forward, tail + side, Color("efe2bf"), 1.7)
			draw_line(tail + forward, tail - side, Color("efe2bf"), 1.7)
			return
		var size := 4.2 if bolt.splash_radius > 0.0 else 2.8
		draw_line(Vector2(-(size + 7.0), 0.0), Vector2(-size, 0.0), Color("ffe4a0", 0.68), 2.0)
		draw_circle(Vector2.ZERO, size + 1.6, Color("2f2921", 0.86))
		draw_circle(Vector2.ZERO, size, Color("ffdc82"))

var game: Node2D
var owner_id := 0
var target: Node2D
var source_unit: RtsUnit
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
var _visual: BoltVisual


func setup(game_ref: Node2D, player_id: int, origin: Vector2, enemy: Node2D, damage_amount: float, flight_speed: float = 350.0, area_radius: float = 0.0, attacker: Dictionary = {}, profile: Dictionary = {}) -> void:
	_initialize(game_ref, player_id, origin, damage_amount, flight_speed, maxf(0.0, area_radius), attacker, profile)
	target = enemy
	fixed_target = false
	last_destination = enemy.global_position

func setup_point(game_ref: Node2D, player_id: int, origin: Vector2, point: Vector2, damage_amount: float, flight_speed: float, area_radius: float, attacker: Dictionary, profile: Dictionary) -> void:
	_initialize(game_ref, player_id, origin, damage_amount, flight_speed, maxf(1.0, area_radius), attacker, profile)
	target = null
	fixed_target = true
	last_destination = point

func _initialize(game_ref: Node2D, player_id: int, origin: Vector2, damage_amount: float, flight_speed: float, area_radius: float, attacker: Dictionary, profile: Dictionary) -> void:
	game = game_ref
	owner_id = player_id
	position = origin
	launch_position = origin
	previous_position = origin
	impact_damage = damage_amount
	speed = maxf(1.0, flight_speed)
	splash_radius = area_radius
	# Shallow copies: the projectile only reads these, but callers may replace
	# top-level entries after setup (the hunt arrow flags its own profile).
	source_stats = attacker.duplicate()
	attack_profile = profile.duplicate()
	visible = owner_id == 0 or not game.fog.active or game.fog.can_see(0, position)
	if _visual == null:
		_visual = BoltVisual.new()
		add_child(_visual)
	_visual.queue_redraw()

func _ready() -> void:
	_update_visual_transform()

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
		if is_instance_valid(target) and not target.is_queued_for_deletion():
			# Ownership can change while the projectile is in flight. Wildlife
			# remains huntable; unit/building impacts follow current diplomacy.
			if not (target is RtsUnit or target is RtsBuilding) or game.is_enemy(owner_id, target.owner_id):
				if target is RtsResource:
					target.take_damage(impact_damage, source_unit if is_instance_valid(source_unit) else null)
				else:
					target.take_damage(impact_damage)
		if float(attack_profile.get("pierce_length", 0.0)) > 0.0 and game.has_method("nearest_enemy"):
			var direction := (destination - launch_position).normalized()
			var end := destination + direction * float(attack_profile["pierce_length"])
			var pierce_width := float(attack_profile.get("pierce_width", 0.0))
			var segment_center := (launch_position + end) * 0.5
			var query_radius: float = launch_position.distance_to(end) * 0.5 + pierce_width + game.navigation.max_dynamic_radius
			for entity in game.navigation.nearby_units(segment_center, query_radius):
				if entity == target or not game.is_enemy(owner_id, entity.owner_id): continue
				var closest := Geometry2D.get_closest_point_to_segment(entity.global_position, launch_position, end)
				if entity.global_position.distance_to(closest) <= entity.radius() + pierce_width:
					entity.take_damage(RtsCombatRules.volley_damage(source_stats, entity.stats, attack_profile))
		if splash_radius > 0.0 and game.has_method("nearest_enemy"):
			var splash_damage := 1.0 if fixed_target else 0.5
			for entity in game.navigation.nearby_units(destination, splash_radius + game.navigation.max_dynamic_radius):
				if entity == target or not game.is_enemy(owner_id, entity.owner_id): continue
				if entity.global_position.distance_to(destination) > splash_radius + entity.radius(): continue
				entity.take_damage(RtsCombatRules.volley_damage(source_stats, entity.stats, attack_profile) * splash_damage)
			for entity in game.navigation.nearby_buildings(destination, splash_radius):
				if entity == target or not game.is_enemy(owner_id, entity.owner_id): continue
				if entity.global_position.distance_to(destination) > splash_radius + entity.size().x * 0.5: continue
				entity.take_damage(RtsCombatRules.volley_damage(source_stats, entity.stats, attack_profile) * splash_damage)
		game.show_hit(global_position, impact_point, owner_id, "siege" if splash_radius > 0.0 else "ranged")
		queue_free()
		return
	previous_position = global_position
	global_position = global_position.move_toward(destination, travel)
	_update_visual_transform()


func _update_visual_transform() -> void:
	if _visual == null or game == null or not is_inside_tree(): return
	var canvas := get_viewport().get_canvas_transform()
	var flight_length := maxf(1.0, launch_position.distance_to(last_destination))
	var progress := clampf(launch_position.distance_to(global_position) / flight_length, 0.0, 1.0)
	var arc_height := sin(progress * PI) * minf(38.0, flight_length * 0.16)
	var screen_travel := canvas.basis_xform(global_position - previous_position).normalized()
	if screen_travel == Vector2.ZERO: screen_travel = Vector2.RIGHT
	var screen_lift := Vector2(0, -arc_height)
	if attack_profile.get("hunting", false): screen_lift.y -= 12.0
	var lift := RtsIsoProjection.world_delta(canvas, screen_lift)
	if game.view_mode_25d:
		lift += RtsIsoProjection.ground_lift(game, global_position)
		_visual.scale = Vector2.ONE / maxf(0.001, canvas.get_scale().x)
	else:
		_visual.scale = Vector2.ONE
	_visual.position = lift
	_visual.rotation = RtsIsoProjection.world_delta(canvas, screen_travel).angle()

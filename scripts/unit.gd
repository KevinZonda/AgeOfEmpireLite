class_name RtsUnit
extends Node2D

const AUTO_GATHER_RADIUS := 180.0

var game: Node2D
var owner_id := 0
var kind: String
var stats: Dictionary = {}
var hp := 1.0
var max_hp := 1.0
var order := "idle"
var destination := Vector2.ZERO
var target: Node2D
var attack_timer := 0.0
var work_timer := 0.0
var charging := false
var charge_distance := 0.0
var resume_destination := Vector2.INF
var gather_kind := ""
var gather_location := Vector2.ZERO
var route := PackedVector2Array()
var route_index := 0
var route_goal := Vector2.INF
var route_retry := 0.0

func setup(game_ref: Node2D, player_id: int, unit_kind: String) -> void:
	game = game_ref
	owner_id = player_id
	kind = unit_kind
	refresh_stats(false)
	queue_redraw()

func refresh_stats(preserve_damage := true) -> void:
	var missing_hp := maxf(0.0, max_hp - hp) if preserve_damage else 0.0
	stats = RtsUnitCatalog.unit_definition(game.civilizations[owner_id], kind, game.players[owner_id].get("researched", []))
	max_hp = float(stats["hp"])
	hp = maxf(1.0, max_hp - missing_hp)
	queue_redraw()

func radius() -> float:
	return float(stats["radius"])

func order_move(world_point: Vector2) -> void:
	order = "move"
	destination = game.navigation.nearest_walkable_point(world_point, radius(), self)
	target = null
	charging = false
	resume_destination = Vector2.INF
	_reset_route()

func order_attack(enemy: Node2D) -> void:
	order = "attack"
	target = enemy
	charging = float(stats.get("charge_bonus", 0.0)) > 0.0
	charge_distance = 0.0
	resume_destination = Vector2.INF
	_reset_route()

func order_attack_move(world_point: Vector2) -> void:
	order = "attack_move"
	destination = game.navigation.nearest_walkable_point(world_point, radius(), self)
	target = null
	charging = false
	resume_destination = Vector2.INF
	_reset_route()

func order_stop() -> void:
	order = "idle"
	target = null
	charging = false
	resume_destination = Vector2.INF
	_reset_route()

func is_braced() -> bool:
	if float(stats.get("brace_bonus", 0.0)) <= 0.0: return false
	if order == "idle": return true
	if order == "attack" and is_instance_valid(target):
		return position.distance_to(target.position) <= float(stats["range"]) + radius() + 8.0
	return false

func order_gather(resource: Node2D) -> void:
	if kind != "villager": return
	order = "gather"
	target = resource
	resume_destination = Vector2.INF
	charging = false
	gather_kind = resource.kind if resource is RtsResource else ""
	gather_location = resource.position
	_reset_route()

func _continue_gather() -> void:
	var next_resource: RtsResource
	if gather_kind != "":
		next_resource = game.find_nearest_resource(gather_location, gather_kind, AUTO_GATHER_RADIUS)
	if next_resource != null:
		order_gather(next_resource)
	else:
		order = "idle"
		target = null

func order_build(building: Node2D) -> void:
	if kind != "villager": return
	order = "build"
	target = building
	resume_destination = Vector2.INF
	charging = false
	_reset_route()

func _reset_route() -> void:
	route.clear()
	route_index = 0
	route_goal = Vector2.INF
	route_retry = 0.0

func _process(delta: float) -> void:
	if not game.started or game.paused or game.game_over: return
	attack_timer = maxf(0.0, attack_timer - delta)
	work_timer = maxf(0.0, work_timer - delta)
	if order == "idle":
		var enemy: Node2D = game.nearest_enemy(self, 115.0)
		if enemy != null and kind != "villager": order_attack(enemy)
		return
	if order == "attack_move":
		var nearby_enemy: Node2D = game.nearest_enemy(self, 155.0)
		if nearby_enemy != null:
			var resume_point := destination
			order_attack(nearby_enemy)
			resume_destination = resume_point
			return
		_move_toward(destination, delta, 6.0)
		if position.distance_to(destination) < 7.0: order = "idle"
		return
	if order == "move":
		_move_toward(destination, delta, 6.0)
		if position.distance_to(destination) < 7.0: order = "idle"
		return
	if order == "gather":
		if not is_instance_valid(target):
			_continue_gather()
		elif target is RtsResource and (target.is_queued_for_deletion() or target.amount <= 0):
			_continue_gather()
	if not is_instance_valid(target):
		if resume_destination != Vector2.INF:
			var resume_point := resume_destination
			order_attack_move(resume_point)
			return
		order = "idle"
		target = null
		return
	if order == "idle": return
	if order == "gather":
		var gathering_distance: float = target.radius + radius() + 2.0 if target is RtsResource else target.size().x * 0.5 + radius() + 2.0
		if not _move_toward(target.position, delta, gathering_distance): return
		if work_timer <= 0.0:
			var resource_kind: String = "food" if target is RtsBuilding else target.kind
			var amount := GameData.gathered_amount(game.civilizations[owner_id], resource_kind, target is RtsBuilding)
			if target is RtsResource: amount = target.harvest(amount)
			if amount > 0: game.credit_resource(owner_id, resource_kind, amount)
			work_timer = 1.1
			if target is RtsResource and target.amount <= 0: _continue_gather()
		return
	if order == "build":
		if not _move_toward(target.position, delta, target.size().x * 0.6 + radius()): return
		target.advance_construction(delta)
		if target.is_complete(): order = "idle"
		return
	if order == "attack":
		var target_radius := 18.0
		if target is RtsUnit: target_radius = target.radius()
		if target is RtsBuilding: target_radius = target.size().x * 0.4
		var reach: float = float(stats["range"]) + target_radius
		if not _move_toward(target.position, delta, reach): return
		if attack_timer > 0.0: return
		var defender_stats: Dictionary = target.stats if target is RtsUnit else RtsUnitCatalog.building_definition(target.kind)
		var charged := charging and charge_distance >= 60.0
		var modifiers := {"charging": charged, "braced": is_braced(), "defender_braced": target.is_braced() if target is RtsUnit else false}
		var damage: float = RtsCombatRules.damage(stats, defender_stats, modifiers)
		charging = false
		if stats.get("attack_type", "melee") == "ranged":
			var projectile := RtsProjectile.new()
			projectile.setup(game, owner_id, global_position, target, damage, float(stats.get("projectile_speed", 350.0)))
			game.add_child(projectile)
		else:
			var impact_point: Vector2 = target.position
			target.take_damage(damage)
			game.show_hit(position, impact_point, owner_id)
		attack_timer = float(stats["cooldown"])

func _move_toward(point: Vector2, delta: float, stop_distance: float) -> bool:
	var distance := position.distance_to(point)
	if distance <= stop_distance: return true
	route_retry = maxf(0.0, route_retry - delta)
	if route_goal == Vector2.INF or route_goal.distance_to(point) > RtsWorldMap.CELL_SIZE * 0.5 or route_retry <= 0.0:
		route = game.navigation.path_between(position, point)
		route_index = 1 if route.size() > 1 else route.size()
		route_goal = point
		route_retry = 0.7
	if route.is_empty(): return false
	while route_index < route.size() and position.distance_to(route[route_index]) < 8.0:
		route_index += 1
	var waypoint: Vector2 = route[route_index] if route_index < route.size() else point
	var speed: float = float(stats["speed"])
	var step := speed * delta
	if route_index >= route.size(): step = minf(step, distance - stop_distance)
	var old_position := position
	position = game.navigation.move_step(self, position.move_toward(waypoint, step))
	if charging: charge_distance += old_position.distance_to(position)
	position = position.clamp(Vector2(24, 24), game.world_size - Vector2(24, 24))
	queue_redraw()
	return position.distance_to(point) <= stop_distance

func take_damage(damage: float) -> void:
	hp -= damage
	queue_redraw()
	if hp <= 0.0: game.entity_destroyed(self)

func _draw() -> void:
	var color: Color = GameData.CIVILIZATIONS[game.civilizations[owner_id]]["color"]
	draw_circle(Vector2(1, 3), radius() + 2, Color("20292a"))
	draw_circle(Vector2.ZERO, radius(), color)
	if kind == "villager":
		draw_circle(Vector2(0, -2), 4, Color("e8cfab"))
	elif stats.get("tags", []).has("cavalry"):
		draw_rect(Rect2(-5, -3, 10, 6), Color("f1e6c6"))
	elif kind == "archer" or kind == "longbow":
		draw_arc(Vector2(1, 0), 7, -PI * 0.6, PI * 0.6, 12, Color("eee6c9"), 2)
	elif kind == "crossbowman" or kind == "arbaletrier":
		draw_line(Vector2(-7, -3), Vector2(7, -3), Color("eee6c9"), 2)
		draw_line(Vector2(0, -3), Vector2(0, 8), Color("eee6c9"), 2)
	elif kind == "man_at_arms":
		draw_rect(Rect2(-5, -6, 10, 12), Color("eee6c9"), false, 2)
	else:
		draw_line(Vector2(0, -8), Vector2(0, 8), Color("eee6c9"), 2)
	draw_rect(Rect2(-radius(), -radius() - 7, radius() * 2, 3), Color("422f2d"))
	draw_rect(Rect2(-radius(), -radius() - 7, radius() * 2 * clampf(hp / max_hp, 0.0, 1.0), 3), Color("82dd8b"))

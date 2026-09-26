class_name RtsUnit
extends Node2D

var game: Node2D
var owner_id := 0
var kind: String
var hp := 1.0
var max_hp := 1.0
var order := "idle"
var destination := Vector2.ZERO
var target: Node2D
var attack_timer := 0.0
var work_timer := 0.0
var charging := false

func setup(game_ref: Node2D, player_id: int, unit_kind: String) -> void:
	game = game_ref
	owner_id = player_id
	kind = unit_kind
	max_hp = GameData.UNITS[kind]["hp"]
	hp = max_hp
	queue_redraw()

func radius() -> float:
	return GameData.UNITS[kind]["radius"]

func order_move(world_point: Vector2) -> void:
	order = "move"
	destination = world_point
	target = null
	charging = false

func order_attack(enemy: Node2D) -> void:
	order = "attack"
	target = enemy
	charging = kind == "knight"

func order_gather(resource: Node2D) -> void:
	if kind != "villager": return
	order = "gather"
	target = resource

func order_build(building: Node2D) -> void:
	if kind != "villager": return
	order = "build"
	target = building

func _process(delta: float) -> void:
	if not game.started or game.paused or game.game_over: return
	attack_timer = maxf(0.0, attack_timer - delta)
	work_timer = maxf(0.0, work_timer - delta)
	if order == "idle":
		var enemy: Node2D = game.nearest_enemy(self, 115.0)
		if enemy != null and kind != "villager": order_attack(enemy)
		return
	if order == "move":
		_move_toward(destination, delta, 6.0)
		if position.distance_to(destination) < 7.0: order = "idle"
		return
	if not is_instance_valid(target):
		order = "idle"
		target = null
		return
	if order == "gather":
		var gathering_distance: float = target.radius + radius() + 2.0 if target is RtsResource else target.size().x * 0.5 + radius() + 2.0
		if not _move_toward(target.position, delta, gathering_distance): return
		if work_timer <= 0.0:
			var resource_kind: String = "food" if target is RtsBuilding else target.kind
			var amount := GameData.gathered_amount(game.civilizations[owner_id], resource_kind, target is RtsBuilding)
			if target is RtsResource: amount = target.harvest(amount)
			game.credit_resource(owner_id, resource_kind, amount)
			work_timer = 1.1
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
		var reach: float = GameData.UNITS[kind]["range"] + target_radius
		if not _move_toward(target.position, delta, reach): return
		if attack_timer > 0.0: return
		var damage: float = GameData.UNITS[kind]["damage"]
		damage += GameData.first_strike_bonus(game.civilizations[owner_id], kind, charging)
		charging = false
		target.take_damage(damage)
		attack_timer = GameData.UNITS[kind]["cooldown"]
		game.show_hit(position, target.position, owner_id)

func _move_toward(point: Vector2, delta: float, stop_distance: float) -> bool:
	var distance := position.distance_to(point)
	if distance <= stop_distance: return true
	var speed: float = GameData.UNITS[kind]["speed"]
	position = position.move_toward(point, minf(speed * delta, distance - stop_distance))
	position = position.clamp(Vector2(24, 24), game.world_size - Vector2(24, 24))
	queue_redraw()
	return false

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
	elif kind == "knight" or kind == "horseman":
		draw_rect(Rect2(-5, -3, 10, 6), Color("f1e6c6"))
	elif kind == "archer" or kind == "longbow":
		draw_arc(Vector2(1, 0), 7, -PI * 0.6, PI * 0.6, 12, Color("eee6c9"), 2)
	else:
		draw_line(Vector2(0, -8), Vector2(0, 8), Color("eee6c9"), 2)
	draw_rect(Rect2(-radius(), -radius() - 7, radius() * 2, 3), Color("422f2d"))
	draw_rect(Rect2(-radius(), -radius() - 7, radius() * 2 * clampf(hp / max_hp, 0.0, 1.0), 3), Color("82dd8b"))

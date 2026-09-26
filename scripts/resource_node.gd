class_name RtsResource
extends Node2D

var game: Node2D
var kind: String
var amount: int
var radius := 22.0
var appearance := ""
var home_position := Vector2.ZERO
var wander_time := 0.0
var claimed_by := -1
var shepherd: RtsUnit
var claim_timer := 0.0

func setup(resource_kind: String, quantity: int, visual_kind := "") -> void:
	kind = resource_kind
	amount = quantity
	appearance = visual_kind
	home_position = position
	wander_time = position.x * 0.013 + position.y * 0.019
	queue_redraw()

func _process(delta: float) -> void:
	if game == null or not game.started or game.paused or game.game_over: return
	if appearance == "sheep":
		_process_sheep(delta)
		return
	if appearance != "deer": return
	wander_time += delta
	var desired := home_position + Vector2(sin(wander_time * 0.75) * 14.0, cos(wander_time * 0.52) * 10.0)
	if game.world_map.is_walkable(desired):
		var previous_position := position
		position = desired
		game.navigation.resource_moved(self, previous_position)
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
	var taken: int = mini(quantity, amount)
	amount -= taken
	if amount <= 0:
		queue_free()
	else:
		queue_redraw()
	return taken

func _draw() -> void:
	var color := Color("82ba62")
	match kind:
		"wood": color = Color("397948")
		"gold": color = Color("e4c359")
		"stone": color = Color("9b9f9e")
	if appearance == "fish":
		draw_colored_polygon(PackedVector2Array([Vector2(-16, 0), Vector2(4, -7), Vector2(16, 0), Vector2(4, 7)]), Color("c5d9cf"))
		draw_colored_polygon(PackedVector2Array([Vector2(-16, 0), Vector2(-24, -7), Vector2(-24, 7)]), Color("9fc9cc"))
		draw_circle(Vector2(9, -2), 1.5, Color("253947"))
	elif appearance == "deer":
		draw_ellipse_shape()
	elif appearance == "sheep":
		draw_circle(Vector2.ZERO, 16, Color("efead9") if claimed_by < 0 else game.player_color(claimed_by).lightened(0.35))
		draw_circle(Vector2(11, -8), 7, Color("d8ccb2"))
		draw_circle(Vector2(13, -10), 1.5, Color("252b27"))
		draw_line(Vector2(-8, 9), Vector2(-8, 19), Color("8d8574"), 2)
		draw_line(Vector2(5, 9), Vector2(5, 19), Color("8d8574"), 2)
	elif kind == "wood":
		draw_circle(Vector2(0, 8), 9, Color("6d4a31"))
		draw_circle(Vector2(0, -4), 19, color)
		draw_circle(Vector2(-7, -9), 8, color.lightened(0.15))
	elif kind == "food":
		draw_circle(Vector2.ZERO, radius, Color("456d31"))
		for point in [Vector2(-10, -8), Vector2(8, -11), Vector2(4, 9), Vector2(-11, 8)]:
			draw_circle(point, 5, Color("d86b65"))
	else:
		var points := PackedVector2Array([Vector2(-22, 14), Vector2(-16, -10), Vector2(2, -20), Vector2(22, -8), Vector2(20, 17)])
		draw_colored_polygon(points, color)
		draw_line(Vector2(-16, -10), Vector2(2, -20), color.lightened(0.25), 2)
	var font := ThemeDB.fallback_font
	if font != null:
		draw_string(font, Vector2(-18, 36), str(amount), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)

func draw_ellipse_shape() -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(-18, -4), Vector2(12, -8), Vector2(21, 1), Vector2(5, 9), Vector2(-15, 8)]), Color("a8794e"))
	draw_circle(Vector2(17, -9), 8, Color("b98b59"))
	draw_circle(Vector2(20, -11), 1.5, Color("24251f"))
	draw_line(Vector2(-11, 6), Vector2(-13, 19), Color("543f31"), 3)
	draw_line(Vector2(6, 6), Vector2(10, 19), Color("543f31"), 3)
	draw_line(Vector2(16, -15), Vector2(10, -27), Color("674b37"), 2)
	draw_line(Vector2(10, -27), Vector2(5, -29), Color("674b37"), 2)
	draw_line(Vector2(10, -27), Vector2(13, -31), Color("674b37"), 2)
	draw_line(Vector2(20, -15), Vector2(23, -25), Color("674b37"), 2)

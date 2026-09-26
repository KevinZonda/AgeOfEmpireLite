class_name RtsBuilding
extends Node2D

var game: Node2D
var owner_id := 0
var kind: String
var hp := 1.0
var max_hp := 1.0
var build_remaining := 0.0
var build_total := 0.0
var training_queue: Array[String] = []
var training_remaining := 0.0
var rally_point := Vector2.ZERO

func setup(game_ref: Node2D, player_id: int, building_kind: String, under_construction := false) -> void:
	game = game_ref
	owner_id = player_id
	kind = building_kind
	var definition: Dictionary = GameData.BUILDINGS[kind]
	max_hp = definition["hp"]
	hp = max_hp if not under_construction else max_hp * 0.3
	build_total = definition["time"]
	build_remaining = build_total if under_construction else 0.0
	rally_point = position + Vector2(95 if owner_id == 0 else -95, 0)
	queue_redraw()

func size() -> Vector2:
	return GameData.BUILDINGS[kind]["size"]

func contains(world_point: Vector2) -> bool:
	return Rect2(position - size() * 0.5, size()).has_point(world_point)

func is_complete() -> bool:
	return build_remaining <= 0.0

func advance_construction(delta: float) -> void:
	if is_complete(): return
	build_remaining = maxf(0.0, build_remaining - delta)
	hp = max_hp * (1.0 - 0.7 * build_remaining / maxf(0.1, build_total))
	queue_redraw()
	if is_complete():
		game.building_completed(self)

func enqueue(unit_kind: String) -> void:
	training_queue.append(unit_kind)
	if training_queue.size() == 1:
		training_remaining = _training_time(unit_kind)
	queue_redraw()

func _training_time(unit_kind: String) -> float:
	return GameData.training_time(game.civilizations[owner_id], kind, unit_kind)

func _process(delta: float) -> void:
	if not game.started or game.paused or game.game_over: return
	if not is_complete() or training_queue.is_empty(): return
	training_remaining -= delta
	if training_remaining > 0.0: return
	var unit_kind: String = training_queue.pop_front()
	game.spawn_unit(owner_id, unit_kind, game.find_spawn_position(self), rally_point)
	if not training_queue.is_empty():
		training_remaining = _training_time(training_queue[0])
	queue_redraw()

func take_damage(damage: float) -> void:
	hp -= damage
	queue_redraw()
	if hp <= 0.0:
		game.entity_destroyed(self)

func _draw() -> void:
	var bounds := Rect2(-size() * 0.5, size())
	var color: Color = GameData.CIVILIZATIONS[game.civilizations[owner_id]]["color"]
	if not is_complete(): color = color.darkened(0.45)
	draw_rect(bounds, Color("272d2a"))
	draw_rect(bounds.grow(-4), color)
	if kind == "farm":
		for x in range(-17, 25, 11):
			draw_line(Vector2(x, -22), Vector2(x - 7, 22), Color("d4bd73"), 3)
	elif kind == "town_center":
		draw_rect(Rect2(-15, -19, 30, 28), Color("e5d3a7"))
		draw_colored_polygon(PackedVector2Array([Vector2(-26, -19), Vector2(0, -35), Vector2(26, -19)]), Color("513c36"))
	else:
		draw_colored_polygon(PackedVector2Array([Vector2(-size().x * 0.4, -size().y * 0.4), Vector2(0, -size().y * 0.65), Vector2(size().x * 0.4, -size().y * 0.4)]), Color("513c36"))
	var font := ThemeDB.fallback_font
	if font != null:
		draw_string(font, Vector2(-size().x * 0.5, size().y * 0.5 + 15), GameData.BUILDINGS[kind]["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
	draw_rect(Rect2(-size().x * 0.5, -size().y * 0.5 - 10, size().x, 5), Color("432e2b"))
	draw_rect(Rect2(-size().x * 0.5, -size().y * 0.5 - 10, size().x * clampf(hp / max_hp, 0.0, 1.0), 5), Color("7fd47a"))
	if not is_complete():
		draw_arc(Vector2.ZERO, 14, 0, TAU * (1.0 - build_remaining / maxf(build_total, 0.1)), 20, Color.WHITE, 3)
	if not training_queue.is_empty():
		draw_circle(Vector2(size().x * 0.5 - 4, -size().y * 0.5 + 4), 8, Color("e5c45d"))

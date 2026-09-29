class_name RtsRelic
extends Node2D

var carried_by: RtsUnit
var stored_in: RtsBuilding
var game: Node2D

func available() -> bool:
	return carried_by == null and stored_in == null

func _process(_delta: float) -> void:
	if carried_by != null and is_instance_valid(carried_by): position = carried_by.position
	if not available():
		visible = false
	elif game != null and game.fog.active:
		visible = game.fog.can_see(0, position)
	else:
		visible = true

func _draw() -> void:
	if game != null and game.view_mode_25d:
		_draw_25d()
	else:
		_draw_topdown()

func _draw_topdown() -> void:
	draw_circle(Vector2.ZERO, 16.0, Color("e9c75c", 0.16))
	draw_circle(Vector2.ZERO, 11.0, Color("f8e5a5", 0.17))
	draw_rect(Rect2(-11, -9, 22, 18), Color("544c38"))
	draw_rect(Rect2(-9, -8, 18, 15), Color("b8a476"))
	draw_rect(Rect2(-7, -6, 14, 11), Color("77562d"))
	draw_rect(Rect2(-6, -5, 12, 9), Color("ebc65e"), false, 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(-4, -3), Vector2(4, -3), Vector2(2, 3), Vector2(-2, 3)]), Color("f5e2a1"))
	draw_circle(Vector2.ZERO, 2.2, Color("578982"))
	for corner in [Vector2(-8, -7), Vector2(8, -7), Vector2(-8, 6), Vector2(8, 6)]:
		draw_circle(corner, 1.4, Color("f7dfa0"))

func _draw_25d() -> void:
	var canvas := get_viewport().get_canvas_transform()
	var zoom: float = game.camera.zoom.x
	var ground := RtsIsoProjection.ground_lift(game, position)
	var rise := RtsIsoProjection.world_delta(canvas, Vector2(0, -4.0 * zoom))
	var nw := Vector2(-9, -7)
	var ne := Vector2(9, -7)
	var se := Vector2(9, 7)
	var sw := Vector2(-9, 7)
	draw_set_transform_matrix(Transform2D(0.0, ground))
	draw_circle(Vector2.ZERO, 15.0, Color("f0cd60", 0.16))
	draw_colored_polygon(PackedVector2Array([sw, se, se + rise, sw + rise]), Color("665943"))
	draw_colored_polygon(PackedVector2Array([ne, se, se + rise, ne + rise]), Color("847456"))
	draw_colored_polygon(PackedVector2Array([nw + rise, ne + rise, se + rise, sw + rise]), Color("c7b384"))
	draw_set_transform_matrix(RtsIsoProjection.upright(canvas, ground, zoom))
	# A small gilded reliquary sits on a stone plinth; the thin beam marks it at map scale.
	draw_polyline(PackedVector2Array([Vector2(0, -25), Vector2(1.5, -33), Vector2(-0.5, -43), Vector2(1, -53)]), Color("f2ca4b", 0.20), 2.8)
	draw_polyline(PackedVector2Array([Vector2(0, -25), Vector2(1.5, -33), Vector2(-0.5, -43), Vector2(1, -53)]), Color("fbe37e", 0.88), 1.0)
	draw_circle(Vector2(1, -53), 2.2, Color("f8df79", 0.7))
	draw_rect(Rect2(-9, -5, 18, 4), Color("4e4532"))
	draw_rect(Rect2(-7, -8, 14, 4), Color("d9b65d"))
	draw_colored_polygon(PackedVector2Array([Vector2(-8, -8), Vector2(-8, -18), Vector2(-5, -22), Vector2(0, -25), Vector2(5, -22), Vector2(8, -18), Vector2(8, -8)]), Color("d9ad4b"))
	draw_colored_polygon(PackedVector2Array([Vector2(-5, -10), Vector2(-5, -17), Vector2(0, -22), Vector2(5, -17), Vector2(5, -10)]), Color("554a35"))
	draw_colored_polygon(PackedVector2Array([Vector2(-3, -11), Vector2(-3, -16), Vector2(0, -19), Vector2(3, -16), Vector2(3, -11)]), Color("f3e5b8"))
	draw_line(Vector2(0, -19), Vector2(0, -11), Color("d3aa50"), 1.2)
	draw_line(Vector2(-3, -15), Vector2(3, -15), Color("d3aa50"), 1.2)
	for x in [-7.0, 7.0]:
		draw_circle(Vector2(x, -9), 1.3, Color("fff0bb"))
	draw_set_transform_matrix(Transform2D.IDENTITY)

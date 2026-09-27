class_name RtsRelic
extends Node2D

var carried_by: RtsUnit
var stored_in: RtsBuilding
var game: Node2D

func available() -> bool:
	return carried_by == null and stored_in == null

func _process(_delta: float) -> void:
	if carried_by != null and is_instance_valid(carried_by): position = carried_by.position + Vector2(0, -20)
	if stored_in != null:
		visible = false
	elif game != null and game.fog.active:
		visible = game.fog.can_see(0, position)

func _draw() -> void:
	if game != null and game.view_mode_25d:
		draw_set_transform_matrix(RtsIsoProjection.upright(get_viewport().get_canvas_transform(), Vector2.ZERO, game.camera.zoom.x))
	draw_circle(Vector2.ZERO, 14, Color("e6d28d", 0.25))
	draw_rect(Rect2(-5, -11, 10, 21), Color("d6bc65"))
	draw_rect(Rect2(-11, -4, 22, 8), Color("eee2a5"))
	draw_arc(Vector2.ZERO, 18, 0, TAU, 24, Color("f0e4aa"), 2)
	if game != null and game.view_mode_25d: draw_set_transform_matrix(Transform2D.IDENTITY)

extends RefCounted

const VisualState = preload("res://scripts/entities/visuals/unit_visual_state.gd")
const Figure = preload("res://scripts/entities/visuals/unit_figure_visual.gd")
const SiegeVisual2D = preload("res://scripts/entities/visuals/siege_visual_2d.gd")
const SiegeVisual25D = preload("res://scripts/entities/visuals/siege_visual_25d.gd")
const NavalVisual = preload("res://scripts/entities/visuals/naval_visual.gd")

var canvas_item: CanvasItem
var state: VisualState
var figure_renderer := Figure.new()

func draw(item: CanvasItem, snapshot: VisualState) -> void:
	canvas_item = item
	state = snapshot
	if Figure.handles(state.kind): _draw_figure()
	elif state.view_mode_25d: _draw_vehicle_isometric()
	else: _draw_vehicle_2d()

func _draw_figure() -> void:
	var canvas := canvas_item.get_viewport().get_canvas_transform()
	var ground_lift := RtsIsoProjection.world_delta(canvas, Vector2(0, -state.ground_height * state.zoom)) if state.view_mode_25d else Vector2.ZERO
	canvas_item.draw_set_transform_matrix(Transform2D(0.0, Vector2(1, 0.4), 0.0, ground_lift))
	Figure.draw_shadow(canvas_item, state)
	var figure := RtsIsoProjection.upright(canvas, ground_lift, state.zoom) if state.view_mode_25d else Transform2D.IDENTITY
	canvas_item.draw_set_transform_matrix(figure)
	figure_renderer.draw(canvas_item, state)
	if state.hit_flash_timer > 0.0:
		canvas_item.draw_arc(Vector2(0, -24 if state.tags.has("cavalry") else -19), 24.0 if state.tags.has("cavalry") else 18.0, 0.0, TAU, 24, Color("ffe5ac", state.hit_flash_timer / 0.18), 2.0)
	if state.show_health_bar: _health_bar(Figure.health_bar_y(state), 28.0 if state.tags.has("cavalry") else 24.0, 3.0)
	canvas_item.draw_set_transform_matrix(Transform2D.IDENTITY)

func _draw_vehicle_2d() -> void:
	var gait := sin(state.visual_phase) * 3.5 if state.visual_moving else 0.0
	var bob := sin(state.visual_phase) * 0.7 if not state.visual_moving else 0.0
	canvas_item.draw_circle(Vector2(2, 5), state.radius + 2.0, Color("172322", 0.53))
	canvas_item.draw_set_transform_matrix(Transform2D(0.0, Vector2(0, bob - absf(gait) * 0.35 - state.swing * 1.5)))
	if NavalVisual.handles(state.kind): NavalVisual.draw_2d(canvas_item, state.kind, state.radius, state.player_color, state.passenger_count)
	elif state.tags.has("siege"): SiegeVisual2D.draw(canvas_item, state.kind, state.radius, state.player_color, state.swing)
	else: push_error("Missing unit figure: " + state.kind)
	canvas_item.draw_set_transform_matrix(Transform2D.IDENTITY)
	if state.hit_flash_timer > 0.0:
		canvas_item.draw_arc(Vector2.ZERO, state.radius + 4.0, 0.0, TAU, 24, Color("ffe5ac", state.hit_flash_timer / 0.18), 2.0)
	if state.show_health_bar: _health_bar(-state.radius - 8, state.radius * 2.0, 3.0)

func _draw_vehicle_isometric() -> void:
	var canvas := canvas_item.get_viewport().get_canvas_transform()
	var ground_lift := RtsIsoProjection.world_delta(canvas, Vector2(0, -state.ground_height * state.zoom))
	var gait := sin(state.visual_phase) * 3.0 if state.visual_moving else 0.0
	var bob := sin(state.visual_phase) * 0.7 if not state.visual_moving else 0.0
	canvas_item.draw_set_transform_matrix(Transform2D(0.0, ground_lift))
	canvas_item.draw_circle(Vector2.ZERO, state.radius + 3.0, Color("1c2928", 0.62))
	canvas_item.draw_set_transform_matrix(RtsIsoProjection.upright(canvas, ground_lift + RtsIsoProjection.world_delta(canvas, Vector2(0, bob - absf(gait) * 0.35 - state.swing * 1.5)), state.zoom))
	if NavalVisual.handles(state.kind): NavalVisual.draw_25d(canvas_item, state.kind, state.radius, state.player_color, state.passenger_count)
	elif state.tags.has("siege"): SiegeVisual25D.draw(canvas_item, state.kind, state.radius, state.player_color, state.swing)
	else: push_error("Missing unit figure: " + state.kind)
	canvas_item.draw_set_transform_matrix(RtsIsoProjection.upright(canvas, ground_lift))
	if state.hit_flash_timer > 0.0:
		canvas_item.draw_arc(Vector2(0, -16), state.radius + 7.0, 0.0, TAU, 24, Color("ffe5ac", state.hit_flash_timer / 0.18), 2.0)
	if state.show_health_bar:
		_health_bar(SiegeVisual25D.overlay_y(state.kind) if state.tags.has("siege") else -38.0, maxf(18.0, state.radius * 2.0), 4.0)
	canvas_item.draw_set_transform_matrix(Transform2D.IDENTITY)

func _health_bar(y: float, width: float, height: float) -> void:
	canvas_item.draw_rect(Rect2(-width * 0.5, y, width, height), Color("422f2d"))
	canvas_item.draw_rect(Rect2(-width * 0.5, y, width * clampf(state.hp / state.max_hp, 0.0, 1.0), height), Color("82dd8b"))

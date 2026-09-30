extends RefCounted

const VisualState = preload("res://scripts/entities/visuals/unit_visual_state.gd")
const FilledPolygon = preload("res://scripts/entities/visuals/filled_polygon.gd")
const SiegeVisual2D = preload("res://scripts/entities/visuals/siege_visual_2d.gd")
const SiegeVisual25D = preload("res://scripts/entities/visuals/siege_visual_25d.gd")
const CharacterVisual = preload("res://scripts/entities/visuals/character_visual.gd")
const NavalVisual = preload("res://scripts/entities/visuals/naval_visual.gd")
const ChineseVisual = preload("res://scripts/entities/visuals/chinese_visual.gd")
const InfantryVisual = preload("res://scripts/entities/visuals/infantry_visual.gd")
const SupportVisual = preload("res://scripts/entities/visuals/support_visual.gd")
const HumanoidVisual = preload("res://scripts/entities/visuals/humanoid_visual.gd")
const HumanoidPose = preload("res://scripts/entities/visuals/humanoid_pose.gd")

var canvas_item: CanvasItem
var state: VisualState
var humanoid_pose := HumanoidPose.new()

func draw(item: CanvasItem, snapshot: VisualState) -> void:
	canvas_item = item
	state = snapshot
	if HumanoidVisual.handles(state.kind):
		_draw_humanoid()
		return
	if state.view_mode_25d:
		_draw_isometric()
		return
	var color: Color = state.player_color
	var r := state.radius
	var gait := sin(state.visual_phase) * 3.5 if state.visual_moving else 0.0
	var idle_bob := sin(state.visual_phase) * 0.7 if not state.visual_moving else 0.0
	var swing := state.swing
	var outline := Color("1b2928")
	canvas_item.draw_circle(Vector2(2, 5), r + 2.0, Color("172322", 0.53))
	canvas_item.draw_set_transform_matrix(_figure_transform(Transform2D(0.0, Vector2(0, idle_bob - absf(gait) * 0.35 - swing * 1.5))))
	if NavalVisual.handles(state.kind):
		NavalVisual.draw_2d(canvas_item, state.kind, r, color, state.passenger_count)
	elif state.tags.has("siege"):
		SiegeVisual2D.draw(canvas_item, state.kind, r, color, swing)
	elif CharacterVisual.handles(state.kind):
		CharacterVisual.draw_2d(canvas_item, state.kind, color, gait, swing)
	elif ChineseVisual.handles(state.kind):
		ChineseVisual.draw_2d(canvas_item, state.kind, color, gait, swing)
	elif InfantryVisual.handles(state.kind):
		InfantryVisual.draw_2d(canvas_item, state.kind, color, gait, swing)
	elif SupportVisual.handles(state.kind):
		SupportVisual.draw_2d(canvas_item, color, gait, swing, state.carries_relic)
	elif state.tags.has("cavalry"):
		var horse := PackedVector2Array([Vector2(-r + 2, -5), Vector2(r - 5, -8), Vector2(r + 3, -2), Vector2(r - 3, 8), Vector2(-r + 1, 7)])
		FilledPolygon.draw(canvas_item, horse, Color("95734e"))
		canvas_item.draw_polyline(horse + PackedVector2Array([horse[0]]), outline, 2.0)
		canvas_item.draw_circle(Vector2(r - 1, -7), 6.5, outline)
		canvas_item.draw_circle(Vector2(r - 1, -7), 5.0, Color("a28058"))
		var rider := PackedVector2Array([Vector2(-8, -7), Vector2(5, -9), Vector2(8, 4), Vector2(-5, 6)])
		FilledPolygon.draw(canvas_item, rider, color.darkened(0.08))
		canvas_item.draw_polyline(rider + PackedVector2Array([rider[0]]), outline, 1.8)
		canvas_item.draw_circle(Vector2(0, -3), 4.5, Color("d9bf96"))
		canvas_item.draw_line(Vector2(-r + 3, 3), Vector2(-r - 5, 8), Color("594233"), 2.0)
		if state.kind in ["knight", "royal_knight", "fire_lancer"]:
			canvas_item.draw_line(Vector2(6, -2), Vector2(r + 12, -16), outline, 4.0)
			canvas_item.draw_line(Vector2(6, -2), Vector2(r + 12, -16), Color("eadbb8"), 2.0)
	else:
		canvas_item.draw_line(Vector2(-4, 5), Vector2(-5 + gait, r + 2), outline, 5.0)
		canvas_item.draw_line(Vector2(4, 5), Vector2(5 - gait, r + 2), outline, 5.0)
		canvas_item.draw_line(Vector2(-4, 5), Vector2(-5 + gait, r + 2), Color("3e342c"), 3.0)
		canvas_item.draw_line(Vector2(4, 5), Vector2(5 - gait, r + 2), Color("3e342c"), 3.0)
		var body := PackedVector2Array([Vector2(-8, -7), Vector2(8, -7), Vector2(9, 8), Vector2(-9, 8)])
		FilledPolygon.draw(canvas_item, body, color.darkened(0.10))
		canvas_item.draw_polyline(body + PackedVector2Array([body[0]]), outline, 2.0)
		canvas_item.draw_circle(Vector2(0, -10), 7.0, outline)
		canvas_item.draw_circle(Vector2(0, -10), 5.5, Color("ddc59f"))
		if state.kind == "villager" or state.kind == "imperial_official":
			FilledPolygon.draw(canvas_item, PackedVector2Array([Vector2(-7, -13), Vector2(7, -13), Vector2(4, -19), Vector2(-4, -19)]), Color("95744b"))
			canvas_item.draw_line(Vector2(10, 5), Vector2(14 - swing * 6, -13 - swing * 6), Color("c8a777"), 2.5)
		elif state.kind == "monk":
			canvas_item.draw_circle(Vector2(0, -11), 6.5, color.darkened(0.27))
			canvas_item.draw_line(Vector2(12, 7), Vector2(12, -18), Color("e2d09c"), 2.0)
			canvas_item.draw_line(Vector2(8, -12), Vector2(16, -12), Color("e2d09c"), 2.0)
		elif state.tags.has("ranged"):
			canvas_item.draw_arc(Vector2(10, -2), 10.5, -PI * 0.55, PI * 0.55, 12, outline, 4.0)
			canvas_item.draw_arc(Vector2(10, -2), 9, -PI * 0.55, PI * 0.55, 12, Color("e1d3a9"), 2.0)
			canvas_item.draw_line(Vector2(7, -13), Vector2(7, 9), Color("d8c9a3"), 1.5)
		elif state.kind == "spearman":
			canvas_item.draw_line(Vector2(11, 8), Vector2(12, -25), outline, 4.5)
			canvas_item.draw_line(Vector2(11, 8), Vector2(12, -25), Color("d6c59e"), 2.0)
			FilledPolygon.draw(canvas_item, PackedVector2Array([Vector2(9, -24), Vector2(12, -33), Vector2(15, -24)]), Color("c9d1ce"))
		else:
			canvas_item.draw_line(Vector2(11, 8), Vector2(12 + swing * 12, -20 + swing * 13), Color("d6d5bd"), 2.5)
			if state.tags.has("heavy"):
				FilledPolygon.draw(canvas_item, PackedVector2Array([Vector2(-11, -4), Vector2(-5, -8), Vector2(0, -4), Vector2(-1, 8), Vector2(-8, 9)]), Color("bbc0b8"))
	canvas_item.draw_set_transform_matrix(Transform2D.IDENTITY)
	if state.hit_flash_timer > 0.0:
		canvas_item.draw_arc(Vector2.ZERO, r + 4.0, 0.0, TAU, 24, Color("ffe5ac", state.hit_flash_timer / 0.18), 2.0)
	if state.show_health_bar:
		canvas_item.draw_rect(Rect2(-r, -r - 8, r * 2.0, 3), Color("422f2d"))
		canvas_item.draw_rect(Rect2(-r, -r - 8, r * 2.0 * clampf(state.hp / state.max_hp, 0.0, 1.0), 3), Color("82dd8b"))

func _draw_isometric() -> void:
	var color: Color = state.player_color
	var outline := Color("1b2928")
	var canvas := canvas_item.get_viewport().get_canvas_transform()
	var ground_lift := RtsIsoProjection.world_delta(canvas, Vector2(0, -state.ground_height * state.zoom))
	var gait := sin(state.visual_phase) * 3.0 if state.visual_moving else 0.0
	var idle_bob := sin(state.visual_phase) * 0.7 if not state.visual_moving else 0.0
	var swing := state.swing
	# The footprint follows the ground projection; the figure faces the screen.
	canvas_item.draw_set_transform_matrix(Transform2D(0.0, ground_lift))
	canvas_item.draw_circle(Vector2.ZERO, state.radius + 3.0, Color("1c2928", 0.62))
	canvas_item.draw_set_transform_matrix(_figure_transform(RtsIsoProjection.upright(canvas, ground_lift + RtsIsoProjection.world_delta(canvas, Vector2(0, idle_bob - absf(gait) * 0.35 - swing * 1.5)), state.zoom)))
	if NavalVisual.handles(state.kind):
		NavalVisual.draw_25d(canvas_item, state.kind, state.radius, color, state.passenger_count)
	elif state.tags.has("siege"):
		SiegeVisual25D.draw(canvas_item, state.kind, state.radius, color, swing)
	elif CharacterVisual.handles(state.kind):
		CharacterVisual.draw_25d(canvas_item, state.kind, color, gait, swing)
	elif ChineseVisual.handles(state.kind):
		ChineseVisual.draw_25d(canvas_item, state.kind, color, gait, swing)
	elif InfantryVisual.handles(state.kind):
		InfantryVisual.draw_25d(canvas_item, state.kind, color, gait, swing)
	elif SupportVisual.handles(state.kind):
		SupportVisual.draw_25d(canvas_item, color, gait, swing, state.carries_relic)
	else:
		var cavalry: bool = state.tags.has("cavalry")
		if cavalry:
			var horse := PackedVector2Array([Vector2(-16, -7), Vector2(11, -8), Vector2(17, -15), Vector2(19, -12), Vector2(16, -3), Vector2(-14, -2)])
			FilledPolygon.draw(canvas_item, horse, Color("a1835c"))
			canvas_item.draw_polyline(horse + PackedVector2Array([horse[0]]), outline, 2.0)
		var body_half := 7.0 if cavalry else 5.5
		var body_bottom := -3.0
		var body_top := -17.0 if cavalry else -15.0
		var body := PackedVector2Array([Vector2(-body_half, body_top), Vector2(body_half, body_top), Vector2(body_half + 2, body_bottom), Vector2(-body_half - 2, body_bottom)])
		FilledPolygon.draw(canvas_item, body, color.darkened(0.18))
		canvas_item.draw_polyline(body + PackedVector2Array([body[0]]), outline, 2.0)
		canvas_item.draw_line(Vector2(-4, body_bottom), Vector2(-5 + gait, 2), outline, 4.5)
		canvas_item.draw_line(Vector2(4, body_bottom), Vector2(5 - gait, 2), outline, 4.5)
		canvas_item.draw_line(Vector2(-4, body_bottom), Vector2(-5 + gait, 2), Color("302f2a"), 2.5)
		canvas_item.draw_line(Vector2(4, body_bottom), Vector2(5 - gait, 2), Color("302f2a"), 2.5)
		canvas_item.draw_circle(Vector2(0, body_top - 5), 6.5, outline)
		canvas_item.draw_circle(Vector2(0, body_top - 5), 5.0, color.darkened(0.32) if state.facing_back else Color("e7d1ac"))
		if not state.facing_back: canvas_item.draw_circle(Vector2(2.0, body_top - 5), 1.25, Color("443a32"))
		if state.kind == "monk":
			canvas_item.draw_line(Vector2(9, -24), Vector2(9, 0), Color("e9dca6"), 2.0)
			canvas_item.draw_line(Vector2(5, -19), Vector2(13, -19), Color("e9dca6"), 2.0)
		elif state.kind == "archer" or state.kind == "longbow":
			canvas_item.draw_arc(Vector2(9 + swing * 4, -12), 9.5, -PI * 0.6, PI * 0.6, 12, outline, 4.0)
			canvas_item.draw_arc(Vector2(9 + swing * 4, -12), 8, -PI * 0.6, PI * 0.6, 12, Color("eee6c9"), 2.0)
		elif cavalry and state.kind in ["knight", "royal_knight", "fire_lancer"]:
			canvas_item.draw_line(Vector2(7, -13), Vector2(17, -31), outline, 4.5)
			canvas_item.draw_line(Vector2(7, -13), Vector2(17, -31), Color("e8d8b5"), 2.0)
		elif state.kind == "villager":
			canvas_item.draw_line(Vector2(8, -7), Vector2(13 - swing * 6, -19 - swing * 5), Color("d5bb8d"), 2.5)
			canvas_item.draw_rect(Rect2(7, -11, 6, 6), Color("b6a07a"))
		elif state.kind == "spearman":
			canvas_item.draw_line(Vector2(9, -1), Vector2(9, -31), outline, 4.5)
			canvas_item.draw_line(Vector2(9, -1), Vector2(9, -31), Color("d6c59e"), 2.0)
			FilledPolygon.draw(canvas_item, PackedVector2Array([Vector2(6, -30), Vector2(9, -38), Vector2(12, -30)]), Color("c9d1ce"))
		elif state.visual_action == "attack" and swing > 0.0:
			canvas_item.draw_line(Vector2(6, -8), Vector2(14 + swing * 12, -23 + swing * 12), Color("e2e0ca"), 2.4)
		if state.tags.has("heavy") and not cavalry:
			FilledPolygon.draw(canvas_item, PackedVector2Array([Vector2(-11, -16), Vector2(-4, -19), Vector2(-2, -6), Vector2(-10, -5)]), Color("9eaaa9"))
			canvas_item.draw_polyline(PackedVector2Array([Vector2(-11, -16), Vector2(-4, -19), Vector2(-2, -6), Vector2(-10, -5), Vector2(-11, -16)]), outline, 1.8)
	canvas_item.draw_set_transform_matrix(RtsIsoProjection.upright(canvas, ground_lift))
	if state.hit_flash_timer > 0.0:
		canvas_item.draw_arc(Vector2(0, -16), state.radius + 7.0, 0.0, TAU, 24, Color("ffe5ac", state.hit_flash_timer / 0.18), 2.0)
	if state.show_health_bar:
		var bar_width := maxf(18.0, state.radius * 2.0)
		var bar_y := SiegeVisual25D.overlay_y(state.kind) if state.tags.has("siege") else -38.0
		canvas_item.draw_rect(Rect2(-bar_width * 0.5, bar_y, bar_width, 4), Color("422f2d"))
		canvas_item.draw_rect(Rect2(-bar_width * 0.5, bar_y, bar_width * clampf(state.hp / state.max_hp, 0.0, 1.0), 4), Color("82dd8b"))
	canvas_item.draw_set_transform_matrix(Transform2D.IDENTITY)

func _draw_humanoid() -> void:
	var canvas := canvas_item.get_viewport().get_canvas_transform()
	var ground_lift := RtsIsoProjection.world_delta(canvas, Vector2(0, -state.ground_height * state.zoom)) if state.view_mode_25d else Vector2.ZERO
	# A shallow footprint sits beneath planted feet; the joint pose supplies bob.
	canvas_item.draw_set_transform_matrix(Transform2D(0.0, Vector2(1, 0.4), 0.0, ground_lift))
	HumanoidVisual.draw_shadow(canvas_item)
	var figure := RtsIsoProjection.upright(canvas, ground_lift, state.zoom) if state.view_mode_25d else Transform2D.IDENTITY
	canvas_item.draw_set_transform_matrix(figure)
	HumanoidVisual.draw(canvas_item, state, humanoid_pose)
	if state.hit_flash_timer > 0.0:
		canvas_item.draw_arc(Vector2(0, -19), 18.0, 0.0, TAU, 24, Color("ffe5ac", state.hit_flash_timer / 0.18), 2.0)
	if state.show_health_bar:
		var bar_y := -74.0 if state.kind == "spearman" else -52.0 if state.kind == "villager" else -45.0
		canvas_item.draw_rect(Rect2(-12, bar_y, 24, 3), Color("422f2d"))
		canvas_item.draw_rect(Rect2(-12, bar_y, 24 * clampf(state.hp / state.max_hp, 0.0, 1.0), 3), Color("82dd8b"))
	canvas_item.draw_set_transform_matrix(Transform2D.IDENTITY)

func _figure_transform(transform: Transform2D) -> Transform2D:
	# Flip the figure in its upright screen space. Ground shadows and overlays
	# are drawn outside this transform; ships and siege engines keep their poses.
	if not state.facing_right and not NavalVisual.handles(state.kind) and not state.tags.has("siege"):
		transform.x = -transform.x
	return transform

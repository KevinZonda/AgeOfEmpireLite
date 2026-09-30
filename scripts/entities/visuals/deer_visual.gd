extends RefCounted

const OUTLINE := Color("26352d")
const Quadruped = preload("res://scripts/entities/visuals/quadruped_visual.gd")

static func draw_carcass(item: CanvasItem, base: Transform2D) -> void:
	item.draw_set_transform_matrix(base)
	var body := PackedVector2Array([Vector2(-20, 2), Vector2(-14, -5), Vector2(13, -5), Vector2(21, 2), Vector2(14, 9), Vector2(-14, 9)])
	item.draw_colored_polygon(body, Color("886448"))
	item.draw_polyline(body + PackedVector2Array([body[0]]), OUTLINE, 2.0)
	item.draw_line(Vector2(14, -1), Vector2(24, -8), Color("674b37"), 2.0)

# Direction is projected into screen space by the caller. Keep the animal
# upright in both camera modes, with a narrower silhouette toward/away.
static func draw(item: CanvasItem, base: Transform2D, direction: Vector2, phase: float, gait: float, graze: float, time: float, running: float) -> void:
	var figure := Quadruped.figure_transform(base, direction)
	item.draw_set_transform_matrix(figure)
	# Opposite diagonal pairs step together. Hooves lift on the forward swing;
	# gait is driven by distance travelled, so standing deer never tread in place.
	Quadruped.draw_legs(item, phase, gait, -12.0, 7.0, 4.0, 19.0, lerpf(3.0, 6.0, running), 3.0, Color("543f31"), Color("73513a"))
	# One rise per diagonal step pair. Doubling phase here and then taking abs
	# caused four body jolts per stride, especially visible during escape.
	var bob := -absf(sin(phase)) * lerpf(0.35, 0.8, running) * gait
	var torso := figure * Transform2D(0.0, Vector2(0, bob))
	item.draw_set_transform_matrix(torso)
	var body := PackedVector2Array([Vector2(-18, -4), Vector2(-8, -7), Vector2(11, -7), Vector2(16, 0), Vector2(8, 7), Vector2(-15, 7)])
	item.draw_colored_polygon(body, Color("a8794e"))
	item.draw_polyline(body + PackedVector2Array([body[0]]), OUTLINE, 1.5)
	item.draw_line(Vector2(-17, 0), Vector2(-23, -3), Color("e0c09a"), 3.0)
	item.draw_line(Vector2(-11, 5), Vector2(8, 5), Color("ceaa7c"), 2.0)
	# Tilt neck, head and antlers as one piece; the muzzle reaches grass height.
	var nibble := sin(time * 3.0) * 0.04 * graze
	var neck := torso * Transform2D(graze * 1.35 + nibble, Vector2(9, -3))
	if direction.y < -0.55:
		# Hide the far eye when facing away; head sits further behind the torso.
		neck.origin += torso.basis_xform(Vector2(-3, -3))
	item.draw_set_transform_matrix(neck)
	item.draw_line(Vector2.ZERO, Vector2(8, -10), OUTLINE, 8.5)
	item.draw_line(Vector2.ZERO, Vector2(8, -10), Color("a8794e"), 6.0)
	item.draw_circle(Vector2(9, -11), 6.0, Color("b98b59"))
	item.draw_arc(Vector2(9, -11), 6.0, 0, TAU, 16, OUTLINE, 1.3)
	item.draw_line(Vector2(12, -9), Vector2(17, -8), Color("b98b59"), 4.0)
	item.draw_circle(Vector2(17, -8), 1.6, Color("543f31"))
	item.draw_line(Vector2(5, -15), Vector2(1, -20), Color("b98b59"), 3.0)
	if direction.y >= -0.55: item.draw_circle(Vector2(12, -12), 1.2, Color("24251f"))
	item.draw_polyline(PackedVector2Array([Vector2(6, -16), Vector2(1, -26), Vector2(-3, -28)]), Color("674b37"), 1.8)
	item.draw_line(Vector2(1, -26), Vector2(4, -29), Color("674b37"), 1.8)
	item.draw_polyline(PackedVector2Array([Vector2(11, -16), Vector2(14, -25), Vector2(18, -27)]), Color("674b37"), 1.8)

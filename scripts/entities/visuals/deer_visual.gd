extends RefCounted

const OUTLINE := Color("26352d")

# Direction is projected into screen space by the caller. Keep the animal
# upright in both camera modes, with a narrower silhouette toward/away.
static func draw(item: CanvasItem, base: Transform2D, direction: Vector2, phase: float, gait: float, graze: float, time: float, running: float) -> void:
	# Near-vertical projected directions can contain tiny +/- X rounding noise.
	# Give them a stable silhouette instead of flipping on that noise.
	var facing := -1.0 if direction.x < -0.15 else 1.0
	var width := lerpf(0.65, 1.0, absf(direction.x))
	var figure := base * Transform2D(0.0, Vector2(facing * width, 1.0), 0.0, Vector2(0, -18))
	item.draw_set_transform_matrix(figure)
	# Opposite diagonal pairs step together. Hooves lift on the forward swing;
	# gait is driven by distance travelled, so standing deer never tread in place.
	for far_side in [true, false]:
		for front in [false, true]:
			var x := 7.0 if front else -12.0
			var leg_phase := phase + (PI if front != far_side else 0.0)
			var stride := sin(leg_phase) * lerpf(3.0, 6.0, running) * gait
			var lift := maxf(0.0, cos(leg_phase)) * 3.0 * gait
			var hip := Vector2(x + (3.0 if far_side else 0.0), 4)
			var knee := hip + Vector2(stride * 0.4, 7.0 - lift * 0.4)
			var hoof := Vector2(hip.x + stride, 19.0 - lift - (1.0 if far_side else 0.0))
			var color := Color("73513a") if far_side else Color("543f31")
			item.draw_polyline(PackedVector2Array([hip, knee, hoof]), color, 2.5)
			item.draw_line(hoof + Vector2(-1.5, 0), hoof + Vector2(2, 0), OUTLINE, 2.0)
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

extends RefCounted

static func figure_transform(base: Transform2D, direction: Vector2, ground_offset := 18.0) -> Transform2D:
	# Vertical projection can introduce tiny +/- X values: keep it facing one
	# stable way rather than letting rounding noise mirror the whole animal.
	var facing := -1.0 if direction.x < -0.15 else 1.0
	var width := lerpf(0.65, 1.0, absf(direction.x))
	return base * Transform2D(0.0, Vector2(facing * width, 1.0), 0.0, Vector2(0, -ground_offset))

static func draw_legs(item: CanvasItem, phase: float, gait: float, rear_x: float, front_x: float, hip_y: float, hoof_y: float, stride_size: float, lift_size: float, near_color: Color, far_color: Color) -> void:
	for far_side in [true, false]:
		for front in [false, true]:
			var leg_phase := phase + (PI if front != far_side else 0.0)
			var stride := sin(leg_phase) * stride_size * gait
			var lift := maxf(0.0, cos(leg_phase)) * lift_size * gait
			var hip := Vector2((front_x if front else rear_x) + (3.0 if far_side else 0.0), hip_y)
			var knee := hip + Vector2(stride * 0.4, (hoof_y - hip_y) * 0.47 - lift * 0.4)
			var hoof := Vector2(hip.x + stride, hoof_y - lift - (1.0 if far_side else 0.0))
			item.draw_polyline(PackedVector2Array([hip, knee, hoof]), far_color if far_side else near_color, 2.5)
			item.draw_line(hoof + Vector2(-1.5, 0), hoof + Vector2(2, 0), Color("26352d"), 2.0)

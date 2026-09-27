class_name RtsIsoProjection
extends RefCounted

# The camera projects the ground plane. These transforms keep sprites and
# annotations upright while their anchors remain in world coordinates.
static func upright(canvas: Transform2D, origin: Vector2, pixel_scale := 1.0) -> Transform2D:
	var inverse := canvas.affine_inverse()
	return Transform2D(
		inverse.basis_xform(Vector2(pixel_scale, 0)),
		inverse.basis_xform(Vector2(0, pixel_scale)),
		origin
	)

static func world_delta(canvas: Transform2D, screen_delta: Vector2) -> Vector2:
	return canvas.affine_inverse().basis_xform(screen_delta)

static func ground_lift(game: Node2D, point: Vector2) -> Vector2:
	if game == null or game.world_map == null: return Vector2.ZERO
	var height: float = game.world_map.elevation_at(point)
	if height <= 0.0: return Vector2.ZERO
	return world_delta(game.get_viewport().get_canvas_transform(), Vector2(0, -height * game.camera.zoom.x))

static func ground_point(game: Node2D, visual_world_point: Vector2) -> Vector2:
	if game == null or not game.view_mode_25d: return visual_world_point
	var lift_per_height := world_delta(game.get_viewport().get_canvas_transform(), Vector2(0, -game.camera.zoom.x))
	var high: float = game.world_map.maximum_elevation + 1.0
	var step_count := maxi(1, ceili(high / 4.0))
	for step in step_count:
		var low := maxf(0.0, high - 4.0)
		var candidate := visual_world_point - lift_per_height * low
		if game.world_map.elevation_at(candidate) >= low:
			for refinement in 12:
				var middle := (low + high) * 0.5
				if game.world_map.elevation_at(visual_world_point - lift_per_height * middle) >= middle:
					low = middle
				else:
					high = middle
			return visual_world_point - lift_per_height * ((low + high) * 0.5)
		high = low
	return visual_world_point

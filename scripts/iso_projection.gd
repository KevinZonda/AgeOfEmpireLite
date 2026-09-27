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

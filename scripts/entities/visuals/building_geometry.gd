extends RefCounted

# Shared layout math for building details. Coordinates are footprint fractions;
# screen offsets are converted back to world space through the canvas transform.
static func point(nw: Vector2, ne: Vector2, sw: Vector2, u: float, v: float) -> Vector2:
	return nw + (ne - nw) * u + (sw - nw) * v


static func point_rect(bounds: Rect2, u: float, v: float) -> Vector2:
	return bounds.position + bounds.size * Vector2(u, v)


static func rect(bounds: Rect2, u: float, v: float, width: float, height: float) -> Rect2:
	return Rect2(point_rect(bounds, u, v), bounds.size * Vector2(width, height))


static func up(canvas: Transform2D, zoom: float, pixels: float, model_scale := GameData.BUILDING_SCALE) -> Vector2:
	return RtsIsoProjection.world_delta(canvas, Vector2(0.0, -pixels * zoom * model_scale))


static func screen_delta(canvas: Transform2D, zoom: float, x: float, y: float) -> Vector2:
	return RtsIsoProjection.world_delta(canvas, Vector2(x, y) * zoom * GameData.BUILDING_SCALE)

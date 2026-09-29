extends RefCounted

# Small convex fills can use GLES3's batched primitive stream instead of one
# dedicated polygon buffer/draw call each. Keep general triangulation for all
# concave or larger shapes. The override is used by the rendered A/B PoC only.
static var force_legacy := false

static func draw(canvas: CanvasItem, points: PackedVector2Array, color: Color) -> void:
	if not force_legacy and _is_primitive(points):
		canvas.draw_primitive(points, PackedColorArray([color]), PackedVector2Array())
	else:
		canvas.draw_colored_polygon(points, color)

static func _is_primitive(points: PackedVector2Array) -> bool:
	if points.size() == 3: return true
	if points.size() != 4: return false
	var direction := 0.0
	for i in 4:
		var cross := (points[(i + 1) % 4] - points[i]).cross(points[(i + 2) % 4] - points[(i + 1) % 4])
		if is_zero_approx(cross): return false
		if i == 0: direction = cross
		elif cross * direction <= 0.0: return false
	return true

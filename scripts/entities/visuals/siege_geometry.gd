extends RefCounted

# One local solid model feeds both projections. X is the axle, -Y is forward.
# Surfaces are culled and sorted along the camera ray before issuing 2D fills.
const WOOD := Color("89603c")
const WOOD_DARK := Color("4e3426")
const WOOD_LIGHT := Color("c49b65")
const IRON := Color("394344")
const IRON_LIGHT := Color("88928e")
const ROPE := Color("d5c399")

var team_color := Color.WHITE
var isometric := true
var forward := Vector2.DOWN
var lateral := Vector2.RIGHT
var surfaces: Array[Dictionary] = []
var batches: Array = []
var bounds := Rect2()
var has_bounds := false
var group_depth := NAN
var group_sequence := 0

# Coplanar decorations must composite with their supporting panel. Sorting a
# large backing by its center against each tiny inset can erase half the insets.
func begin_surface_group(center: Vector3) -> void:
	group_depth = depth(center)
	group_sequence = 0

func end_surface_group() -> void:
	group_depth = NAN

func _surface_depth(value: float) -> float:
	if is_nan(group_depth): return value
	group_sequence += 1
	return group_depth + group_sequence * 0.00001

func configure(state) -> void:
	team_color = state.player_color
	isometric = state.view_mode_25d
	var heading: Vector2 = state.facing_direction.normalized()
	if heading.is_zero_approx(): heading = Vector2(1, 1).normalized()
	forward = Vector2(heading.x, heading.y / ground_scale()).normalized()
	lateral = Vector2(-forward.y, forward.x)

func ground_scale() -> float: return 0.55 if isometric else 1.0
func height_scale() -> float: return 1.0 if isometric else 0.32

func world(point: Vector3) -> Vector3:
	var ground := lateral * point.x - forward * point.y
	return Vector3(ground.x, ground.y, point.z)

func project(point: Vector3) -> Vector2:
	var rotated := world(point)
	return Vector2(rotated.x, rotated.y * ground_scale() - rotated.z * height_scale())

func depth(point: Vector3) -> float:
	var rotated := world(point)
	return rotated.y * height_scale() + rotated.z * ground_scale()

func face(points: Array, color: Color, cull := false) -> void:
	if points.size() < 3: return
	var normal: Vector3 = (points[1] - points[0]).cross(points[2] - points[0]).normalized()
	var rotated_normal := world(normal)
	if cull and rotated_normal.y * height_scale() + rotated_normal.z * ground_scale() <= 0.001: return
	var shade := clampf(0.82 + rotated_normal.dot(Vector3(-0.4, -0.3, 0.85).normalized()) * 0.22, 0.58, 1.08)
	var projected := PackedVector2Array()
	var average := 0.0
	for point in points:
		var pixel := project(point)
		projected.append(pixel)
		average += depth(point)
		if not has_bounds:
			bounds = Rect2(pixel, Vector2.ZERO)
			has_bounds = true
		else: bounds = bounds.expand(pixel)
	surfaces.append({"points": projected, "color": Color(color.r * shade, color.g * shade, color.b * shade, color.a), "depth": _surface_depth(average / points.size()), "width": 0.0})

func line(a: Vector3, b: Vector3, color: Color, width := 1.0) -> void:
	var pixels := PackedVector2Array([project(a), project(b)])
	for pixel in pixels:
		if not has_bounds:
			bounds = Rect2(pixel, Vector2.ZERO)
			has_bounds = true
		else: bounds = bounds.expand(pixel)
	surfaces.append({"points": pixels, "color": color, "depth": _surface_depth((depth(a) + depth(b)) * 0.5 + 0.02), "width": width})

func box(low: Vector3, high: Vector3, color: Color) -> void:
	var p := [Vector3(low.x, low.y, low.z), Vector3(high.x, low.y, low.z), Vector3(high.x, high.y, low.z), Vector3(low.x, high.y, low.z), Vector3(low.x, low.y, high.z), Vector3(high.x, low.y, high.z), Vector3(high.x, high.y, high.z), Vector3(low.x, high.y, high.z)]
	for indices in [[0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7]]:
		face([p[indices[0]], p[indices[1]], p[indices[2]], p[indices[3]]], color, true)

func beam(a: Vector3, b: Vector3, width: float, color: Color) -> void:
	var axis := (b - a).normalized()
	if axis.is_zero_approx(): return
	var side := axis.cross(Vector3.UP if absf(axis.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT).normalized() * width * 0.5
	var up := axis.cross(side).normalized() * width * 0.5
	var corners: Array = [side + up, -side + up, -side - up, side - up]
	face([a + corners[3], a + corners[2], a + corners[1], a + corners[0]], color, true)
	face([b + corners[0], b + corners[1], b + corners[2], b + corners[3]], color, true)
	for i in 4:
		var j := (i + 1) % 4
		face([a + corners[i], a + corners[j], b + corners[j], b + corners[i]], color, true)

func cylinder(a: Vector3, b: Vector3, radius: float, color: Color, segments := 12) -> void:
	var axis := (b - a).normalized()
	if axis.is_zero_approx(): return
	var side := axis.cross(Vector3.UP if absf(axis.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT).normalized()
	var up := axis.cross(side).normalized()
	var ring_a: Array[Vector3] = []
	var ring_b: Array[Vector3] = []
	for i in segments:
		var angle := TAU * i / segments
		var offset := (side * cos(angle) + up * sin(angle)) * radius
		ring_a.append(a + offset)
		ring_b.append(b + offset)
	var reverse_a := ring_a.duplicate()
	reverse_a.reverse()
	face(reverse_a, color, true)
	face(ring_b, color, true)
	for i in segments:
		var j := (i + 1) % segments
		face([ring_a[i], ring_a[j], ring_b[j], ring_b[i]], color, true)

func disc(center: Vector3, radius: float, color: Color) -> void:
	var points: Array[Vector3] = []
	for i in 12:
		var angle := TAU * i / 12.0
		points.append(center + Vector3(cos(angle), 0, sin(angle)) * radius)
	face(points, color)

func wheel(center: Vector3, radius: float, thickness := 3.0) -> void:
	var axle := Vector3(thickness * 0.5, 0, 0)
	cylinder(center - axle, center + axle, radius, IRON, 12)
	var near_sign := 1.0 if world(Vector3.RIGHT).y >= 0 else -1.0
	var outer := center + axle * near_sign + Vector3(near_sign * 0.08, 0, 0)
	cylinder(outer - Vector3(0.03, 0, 0), outer + Vector3(0.03, 0, 0), radius * 0.77, WOOD, 12)
	# Wheel bodies are immutable; only six spoke lines depend on rolling phase.
	# Keep them as a small draw command instead of rebuilding every solid face.
	surfaces.append({"center": outer, "radius": radius * 0.73, "depth": depth(outer) + 0.02, "spokes": true})
	cylinder(outer - Vector3(0.2, 0, 0), outer + Vector3(0.2, 0, 0), 1.5, IRON_LIGHT, 8)

static func attack_motion(state) -> float:
	if state.visual_action != "attack": return 0.0
	if state.action_released:
		return maxf(0.0, 1.0 - maxf(0.0, state.release_elapsed) / 0.24)
	return -sin(clampf(state.action_progress * 2.0, 0.0, 1.0) * PI * 0.5) * 0.22

func finish() -> void:
	surfaces.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.depth < b.depth)
	# Preserve painter order while batching hundreds of immutable faces into
	# a handful of mesh draws. Spokes form the only moving subcommands.
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for surface in surfaces:
		if surface.has("spokes"):
			_append_mesh(vertices, colors, indices)
			vertices = PackedVector2Array()
			colors = PackedColorArray()
			indices = PackedInt32Array()
			batches.append(surface)
			continue
		var points: PackedVector2Array = surface.points
		if surface.width > 0.0:
			var side: Vector2 = (points[1] - points[0]).orthogonal().normalized() * surface.width * 0.5
			points = PackedVector2Array([points[0] - side, points[1] - side, points[1] + side, points[0] + side])
		var triangles := Geometry2D.triangulate_polygon(points)
		if triangles.is_empty(): continue
		var offset := vertices.size()
		vertices.append_array(points)
		for point in points: colors.append(surface.color)
		for index in triangles: indices.append(offset + index)
	_append_mesh(vertices, colors, indices)

func _append_mesh(vertices: PackedVector2Array, colors: PackedColorArray, indices: PackedInt32Array) -> void:
	if indices.is_empty(): return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	batches.append(mesh)

func draw(canvas: CanvasItem, rolling_phase := 0.0) -> void:
	for batch in batches:
		if batch is Dictionary:
			var center: Vector3 = batch.center
			var pixel := project(center)
			for spoke in 6:
				var angle := TAU * spoke / 6.0 + rolling_phase
				canvas.draw_line(pixel, project(center + Vector3(0, cos(angle), sin(angle)) * batch.radius), WOOD_LIGHT, 1.0, true)
		else: canvas.draw_mesh(batch, null)

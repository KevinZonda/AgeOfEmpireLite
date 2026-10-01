extends "res://scripts/entities/visuals/western_landmark_details.gd"

# The civic hall and royal palace use separate silhouettes, while retaining the
# same local 3D/BSP renderer and normalized simulation footprint.
static func handles(id: String) -> bool:
	return id in ["eng_council_hall", "eng_wynguard_palace"]

static func layout(id: String) -> Array:
	if id == "eng_council_hall":
		return [[0.50, 0.35, 0.80, 0.38, 24, "gable"], [0.25, 0.605, 0.28, 0.13, 11, "gallery"], [0.75, 0.605, 0.28, 0.13, 11, "gallery"], [0.50, 0.655, 0.23, 0.29, 16, "gable"], [0.50, 0.35, 0.085, 0.085, 46, "spire"]]
	if id == "eng_wynguard_palace":
		return [[0.50, 0.33, 0.48, 0.38, 33, "hip"], [0.18, 0.42, 0.22, 0.56, 38, "gable"], [0.82, 0.42, 0.22, 0.56, 38, "gable"], [0.50, 0.615, 0.34, 0.22, 20, "gable"]]
	return []

static func populate(g, id: String, player: Color) -> bool:
	if not handles(id): return false
	g.palette = g.palette.duplicate()
	g.palette["wall"] = Color("bfb69f")
	g.palette["trim"] = Color("ded3b7")
	g.palette["roof"] = Color("57636b")
	g.palette["roof_dark"] = Color("38464c")
	if id == "eng_council_hall":
		_council(g, player)
	else:
		_palace(g, player)
	return true

static func _solid(g, u: float, v: float, w: float, d: float, z: float, h: float, color: Color) -> void:
	var at := _p(g, u, v, z)
	g.box(Vector2(at.x, at.y), Vector2(w, d) * g.dimensions, at.z, h, color)

static func _council(g, player: Color) -> void:
	var wood := Color("6c5845")
	_solid(g, 0.50, 0.35, 0.80, 0.38, 0.5, 12, g.palette["wall"])
	_solid(g, 0.50, 0.35, 0.80, 0.38, 12.5, 11.5, Color("d0c6ac"))
	_solid(g, 0.50, 0.35, 0.82, 0.40, 0.5, 2, g.palette["wall"].darkened(0.17))
	_roof(g, 0.50, 0.35, 0.845, 0.425, 24, "gable", g.palette["roof"], 16)
	# The pale upper storey and broad timber rhythm read at game zoom.
	for z in [12.8, 23.2]:
		_ribbon(g, _p(g, 0.105, 0.542, z), _p(g, 0.895, 0.542, z), 1.4, wood)
	for u in [0.13, 0.25, 0.37, 0.63, 0.75, 0.87]:
		_ribbon(g, _p(g, u, 0.543, 12.7), _p(g, u, 0.543, 23.5), 1.25, wood)
	for u in [0.19, 0.31, 0.69, 0.81]:
		_arch(g, u, 0.547, 15, 2.0, 6.5, false)
	for u in [0.105, 0.895]:
		_buttress(g, u, 0.54, 12)
	# Two genuinely open galleries flank the projecting entrance porch.
	for u in [0.25, 0.75]:
		_gallery(g, u, wood)
	_hall(g, [0.50, 0.655, 0.23, 0.29, 16, "gable"], player)
	_arch(g, 0.50, 0.806, 1.5, 4.2, 11.8, false)
	_steps(g, 0.50, 0.825, 0.23)
	# Visible timber gable on the porch: no oversized dark contour.
	var eave_left := _p(g, 0.385, 0.802, 16)
	var eave_right := _p(g, 0.615, 0.802, 16)
	var peak := _p(g, 0.50, 0.802, 26)
	_ribbon(g, eave_left, peak, 1, wood)
	_ribbon(g, eave_right, peak, 1, wood)
	_ribbon(g, _p(g, 0.50, 0.803, 16), peak, 1.1, wood)
	_banner(g, 0.57, 0.808, 15, player)
	# Small louvered bell turret gives the long roof a civic landmark accent.
	_solid(g, 0.50, 0.35, 0.085, 0.085, 39, 7, g.palette["trim"])
	for u in [0.482, 0.518]:
		_arch(g, u, 0.395, 40, 0.9, 4.3, false)
	_roof(g, 0.50, 0.35, 0.105, 0.105, 46, "spire", g.palette["roof"], 8)
	_solid(g, 0.81, 0.32, 0.038, 0.050, 34, 9, g.palette["wall"].darkened(0.1))
	_solid(g, 0.81, 0.32, 0.050, 0.063, 42, 1.5, g.palette["trim"])
	for u in [0.20, 0.80]:
		_longbow_rack(g, u, 0.83)

static func _gallery(g, u: float, wood: Color) -> void:
	for x in [u - 0.13, u, u + 0.13]:
		_solid(g, x, 0.672, 0.025, 0.025, 0.5, 10.5, wood)
	_solid(g, u, 0.668, 0.30, 0.027, 10.1, 1.6, wood)
	var a := _p(g, u - 0.155, 0.54, 15.0)
	var b := _p(g, u + 0.155, 0.54, 15.0)
	var c := _p(g, u + 0.155, 0.69, 11.8)
	var d := _p(g, u - 0.155, 0.69, 11.8)
	g.face([a, b, c, d], g.palette["roof"].lightened(0.04))
	_ribbon(g, d, c, 1.1, g.palette["roof_dark"])

static func _longbow_rack(g, u: float, v: float) -> void:
	var wood := Color("795a3b")
	for x in [u - 0.045, u + 0.045]:
		_solid(g, x, v, 0.018, 0.045, 0.5, 7, wood)
	_ribbon(g, _p(g, u - 0.06, v + 0.026, 6), _p(g, u + 0.06, v + 0.026, 6), 1.3, wood)
	for x in [u - 0.033, u, u + 0.033]:
		var bottom := _p(g, x, v + 0.030, 1.0)
		var middle := _p(g, x - 0.018, v + 0.030, 5.0)
		var top := _p(g, x, v + 0.030, 9.0)
		_ribbon(g, bottom, middle, 0.85, Color("be9b64"))
		_ribbon(g, middle, top, 0.85, Color("be9b64"))
		_ribbon(g, bottom, top, 0.35, Color("dad1b3"))

static func _palace(g, player: Color) -> void:
	_palace_mass(g, 0.50, 0.33, 0.48, 0.38, 33)
	# A steep great-hall roof, rather than the low generic hip roof.
	_roof(g, 0.50, 0.33, 0.525, 0.425, 33, "hip", g.palette["roof"], 18)
	for u in [0.18, 0.82]:
		_palace_mass(g, u, 0.42, 0.22, 0.56, 38)
		_roof(g, u, 0.42, 0.26, 0.60, 38, "gable", g.palette["roof"], 18)
		for v in [0.23, 0.45, 0.64]:
			_buttress(g, u + 0.115, v, 28)
		_arch(g, u, 0.703, 21, 3.1, 10, false)
		_banner(g, u - 0.065, 0.707, 24, player)
		# Side-facing dormers emerge from the actual steep roof plane.
		_side_dormer(g, u + 0.09, 0.50, 43)
	for u in [0.36, 0.64]:
		_dormer(g, u, 0.495, 35)
		_banner(g, u - 0.04, 0.527, 29, player)
	_arch(g, 0.50, 0.526, 0.5, 5.0, 15.5, false)
	# Freestanding columns preserve a real dark recess behind the portico.
	for u in [0.355, 0.445, 0.555, 0.645]:
		_column(g, u, 0.713, 18)
	for u in [0.355, 0.645]:
		_column(g, u, 0.545, 18)
	_solid(g, 0.50, 0.712, 0.34, 0.035, 17.0, 3.0, g.palette["trim"])
	_roof(g, 0.50, 0.615, 0.36, 0.245, 20, "gable", g.palette["roof"], 10)
	_steps(g, 0.50, 0.765, 0.34)
	for u in [0.30, 0.70]:
		_solid(g, u, 0.855, 0.12, 0.10, 0.5, 2, g.palette["trim"].darkened(0.10))
		_solid(g, u, 0.855, 0.105, 0.085, 2.5, 2.8, Color("677454"))
	for u in [0.405, 0.595]:
		_column(g, u, 0.86, 5)
		_solid(g, u, 0.86, 0.030, 0.030, 5, 1, g.palette["trim"])
	for u in [0.435, 0.565]:
		var a := _p(g, u, 0.795, 0.56)
		var b := _p(g, u, 0.94, 0.56)
		g.face([a, b, b + Vector3(0.6, 0, 0), a + Vector3(0.6, 0, 0)], Color("d0c6ab"))

static func _palace_mass(g, u: float, v: float, w: float, d: float, h: float) -> void:
	_solid(g, u, v, w, d, 0.5, h - 0.5, g.palette["wall"])
	_solid(g, u, v, w + 0.015, d + 0.015, 0.5, 2.5, g.palette["wall"].darkened(0.15))
	_solid(g, u, v, w + 0.015, d + 0.015, h - 2, 1.5, g.palette["trim"])
	for level in [h * 0.25, h * 0.59]:
		for x in ([-0.32, 0.0, 0.32] if w > 0.3 else [0.0]):
			_arch(g, u + x * w, v + d * 0.5 + 0.003, level, 2.4, h * 0.22, false)
	for y in [-0.26, 0.0, 0.26]:
		_arch(g, u + w * 0.5 + 0.004, v + d * y, h * 0.58, 2.0, h * 0.22, true)
	for level in [h * 0.30, h * 0.65]:
		_ribbon(g, _p(g, u - w * 0.5, v + d * 0.5 + 0.005, level), _p(g, u + w * 0.5, v + d * 0.5 + 0.005, level), 0.5, g.palette["trim"].darkened(0.1))

static func _side_dormer(g, u: float, v: float, z: float) -> void:
	_solid(g, u, v, 0.070, 0.075, z, 5.5, g.palette["wall"])
	# A ridge across x presents the small gable to the right roof slope.
	_roof(g, u, v, 0.095, 0.085, z + 5.5, "gable", g.palette["roof"], 4)
	_arch(g, u + 0.038, v, z + 0.7, 1.5, 4.0, true)

static func _dormer(g, u: float, v: float, z: float) -> void:
	_solid(g, u, v, 0.065, 0.075, z, 5.5, g.palette["wall"])
	_roof(g, u, v, 0.085, 0.095, z + 5.5, "gable", g.palette["roof"], 4)
	_arch(g, u, v + 0.039, z + 0.7, 1.6, 4.0, false)

static func draw_topdown(c: CanvasItem, bounds: Rect2, id: String, palette: Dictionary, player: Color) -> bool:
	if not handles(id): return false
	var stone := palette.duplicate()
	stone["wall"] = Color("bfb69f")
	stone["trim"] = Color("ded3b7")
	draw_layout_topdown(c, bounds, layout(id), id, stone, player)
	if id == "eng_council_hall":
		for u in [0.25, 0.75]:
			var size := bounds.size * Vector2(0.31, 0.15)
			var at := bounds.position + bounds.size * Vector2(u, 0.615)
			c.draw_rect(Rect2(at - size * 0.5, size), Color("57636b").lightened(0.04))
			c.draw_line(at + Vector2(-size.x * 0.5, size.y * 0.5), at + size * 0.5, Color("38464c"), 1.0)
		for u in [0.20, 0.80]:
			var at := bounds.position + bounds.size * Vector2(u, 0.83)
			c.draw_rect(Rect2(at - Vector2(5.0, 2.4), Vector2(10, 4.8)), Color("795a3b"))
			for x in [-3.0, 0.0, 3.0]:
				c.draw_line(at + Vector2(x, -3), at + Vector2(x - 1, 3), Color("be9b64"), 0.8)
		var chimney := bounds.position + bounds.size * Vector2(0.81, 0.32)
		c.draw_rect(Rect2(chimney - Vector2(2, 2.6), Vector2(4, 5.2)), stone["trim"])
		c.draw_rect(Rect2(chimney - Vector2(1, 1.5), Vector2(2, 3)), Color("4a4942"))
	else:
		for u in [0.30, 0.70]:
			var at := bounds.position + bounds.size * Vector2(u, 0.855)
			var size := bounds.size * Vector2(0.12, 0.10)
			c.draw_rect(Rect2(at - size * 0.5, size), stone["trim"])
			c.draw_rect(Rect2(at - size * 0.5, size).grow(-1), Color("677454"))
		for u in [0.405, 0.595]:
			c.draw_circle(bounds.position + bounds.size * Vector2(u, 0.86), 1.8, stone["trim"])
		for u in [0.435, 0.565]:
			c.draw_line(bounds.position + bounds.size * Vector2(u, 0.79), bounds.position + bounds.size * Vector2(u, 0.94), Color("d0c6ab"), 0.7)
		for uv in [Vector2(0.36, 0.495), Vector2(0.64, 0.495), Vector2(0.27, 0.50), Vector2(0.91, 0.50)]:
			var at: Vector2 = bounds.position + bounds.size * uv
			c.draw_rect(Rect2(at - Vector2(3, 2.5), Vector2(6, 5)), stone["trim"].darkened(0.16))
			c.draw_line(at + Vector2(-3, -1), at + Vector2(3, -1), Color("57636b"), 2)
	var steps := bounds.position + bounds.size * Vector2(0.50, 0.835 if id == "eng_council_hall" else 0.78)
	var width: float = bounds.size.x * (0.23 if id == "eng_council_hall" else 0.34)
	for row in 3:
		c.draw_line(steps + Vector2(-width * 0.5, row * 1.3), steps + Vector2(width * 0.5, row * 1.3), stone["trim"].darkened(row * 0.07), 1.0)
	return true

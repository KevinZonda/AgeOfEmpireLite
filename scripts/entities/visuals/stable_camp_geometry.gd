extends RefCounted

# These details live in world space: horses, roof posts and tent flaps participate
# in the same occlusion, portraits and selection geometry as the main building.
static func populate(mesh, kind: String) -> void:
	match kind:
		"stable": _stable(mesh)
		"scout_camp": _camp(mesh)

static func _stable(m) -> void:
	var timber: Color = m.palette["timber"]
	var wall: Color = m.palette["wall"]
	# A shallow store room backs onto two genuinely open stable bays.
	m.cube(0.08, 0.08, 0.81, 0.17, 2, 23, wall)
	m.cube(0.08, 0.25, 0.035, 0.32, 2, 22, wall)
	m.cube(0.855, 0.25, 0.035, 0.32, 2, 22, wall)
	m._roof(0.045, 0.045, 0.89, 0.55, 25, 10 if m.civilization == "Chinese" else 13)
	for u in [0.11, 0.48, 0.85]:
		m.cube(u, 0.54, 0.03, 0.035, 2, 23, timber)
		m.beam(m.p(u + 0.015, 0.577, 16), m.p(u + 0.085, 0.577, 24), 1.1, timber)
	m.cube(0.10, 0.555, 0.79, 0.027, 22, 2.8, timber)
	# Low bay dividers reveal the shadowed interior and let the horse project out.
	m.cube(0.47, 0.27, 0.03, 0.27, 2, 8, timber.lightened(0.13))
	m.cube(0.115, 0.505, 0.31, 0.027, 2, 6, timber.lightened(0.15))
	for u in [0.13, 0.25, 0.37]:
		m.cube(u, 0.505, 0.018, 0.03, 2, 9, timber)
	# Reinforce the store-room facade, without filling the open entrances.
	m.window(0.27, 0.252, 13, 7, 6)
	m.window(0.66, 0.252, 13, 7, 6)
	if m.civilization == "English":
		m.cube(0.08, 0.252, 0.81, 0.013, 10, 1.2, timber)
	elif m.civilization == "French":
		for z in [7.0, 14.0]: m.cube(0.89, 0.09, 0.013, 0.47, z, 0.5, Color("aaa08b"))
	# An actual horse with four legs, neck, head, ears, mane and saddle cloth.
	_horse(m, 0.61, 0.76, 1.0, Color("9b6b43"))
	_horse(m, 0.29, 0.42, 0.78, Color("bca78a"))
	_fence(m, 0.08, 0.68, 0.28, false)
	_fence(m, 0.89, 0.61, 0.32, false)
	_fence(m, 0.09, 0.93, 0.27, true)
	# Feed trough is visibly hollow, with a separate hay surface inside.
	m.cube(0.12, 0.71, 0.23, 0.12, 2, 3, timber)
	m.cube(0.13, 0.72, 0.21, 0.10, 5.1, 0.15, Color("63573b"))
	for u in [0.12, 0.335]: m.cube(u, 0.71, 0.015, 0.12, 5, 2, timber.lightened(0.15))
	for v in [0.71, 0.815]: m.cube(0.12, v, 0.23, 0.015, 5, 2, timber.lightened(0.15))
	m.cube(0.15, 0.74, 0.15, 0.055, 5.4, 1.5, Color("c9b067"))
	_hay(m, 0.75, 0.64, 0.10, 0.12, 6)
	_hay(m, 0.75, 0.81, 0.11, 0.11, 5)
	# Hanging tack and a compact, team-colored stall sign.
	m.cube(0.865, 0.37, 0.025, 0.13, 16, 1.1, timber)
	m.cube(0.882, 0.39, 0.028, 0.07, 11, 5, Color("534734"))
	m.cube(0.883, 0.415, 0.03, 0.016, 7, 5, Color("b0a383"))
	m.cube(0.49, 0.585, 0.18, 0.025, 23, 3, m.accent)

static func _fence(m, u: float, v: float, length: float, across: bool) -> void:
	var color: Color = m.palette["timber"].lightened(0.10)
	for fraction in [0.0, 0.5, 1.0]:
		m.cube(u + length * fraction if across else u, v if across else v + length * fraction, 0.025, 0.025, 2, 8, color)
	for z in [5.0, 8.0]:
		m.cube(u, v, length + 0.025 if across else 0.023, 0.023 if across else length + 0.025, z, 1.1, color)

static func _horse(m, u: float, v: float, scale: float, color: Color) -> void:
	var center: Vector3 = m.p(u, v, 2)
	# Concave outline is split into convex torso, neck and head prisms.
	_profile(m, center, [Vector2(-7, 7), Vector2(5, 7), Vector2(7, 12), Vector2(4, 15), Vector2(-6, 15), Vector2(-9, 12)], 5, scale, color)
	_profile(m, center, [Vector2(2, 13), Vector2(7, 12), Vector2(11, 21), Vector2(7, 22)], 3.8, scale, color.lightened(0.06))
	_profile(m, center, [Vector2(7, 19), Vector2(12, 18), Vector2(15, 20), Vector2(14, 23), Vector2(8, 23)], 3.5, scale, color)
	for x in [-5.0, 4.0]:
		for y in [-1.8, 1.8]:
			m.box(Vector2(center.x + x * scale, center.y + y * scale), Vector2.ONE * 1.35 * scale, 2, 8 * scale, color.darkened(0.2))
			m.box(Vector2(center.x + x * scale, center.y + y * scale), Vector2.ONE * 1.6 * scale, 2, 1.3 * scale, Color("443e34"))
	# Two solid triangular ears and the mane edge preserve the horse silhouette.
	_profile(m, center, [Vector2(8, 22), Vector2(8.5, 26), Vector2(10, 23)], 0.7, scale, color)
	_profile(m, center + Vector3(0, -2 * scale, 0), [Vector2(10, 22), Vector2(11, 25), Vector2(12, 22)], 0.7, scale, color.darkened(0.1))
	_profile(m, center, [Vector2(1.8, 14), Vector2(6.5, 22), Vector2(7.8, 22), Vector2(3.5, 13)], 4.0, scale, Color("423b30"))
	_profile(m, center, [Vector2(-8, 13), Vector2(-11, 11), Vector2(-10, 3), Vector2(-8.8, 4)], 1.5, scale, Color("4b3d2e"))
	m.box(Vector2(center.x - 0.6 * scale, center.y), Vector2(7, 5.4) * scale, 2 + 15 * scale, 0.45 * scale, m.accent.darkened(0.1))
	m.box(Vector2(center.x - 0.5 * scale, center.y), Vector2(4.5, 3.4) * scale, 2 + 15.45 * scale, 1.2 * scale, Color("534131"))
	# Eye and bridle lie on the visible head side.
	m.box(Vector2(center.x + 11 * scale, center.y + 1.82 * scale), Vector2.ONE * 0.65 * scale, 2 + 21.5 * scale, 0.65 * scale, Color("2b302c"))

static func _profile(m, origin: Vector3, points: Array, depth: float, scale: float, color: Color) -> void:
	var front: Array = []
	var rear: Array = []
	for point in points:
		front.append(origin + Vector3(point.x, depth * 0.5, point.y) * scale)
		rear.append(origin + Vector3(point.x, -depth * 0.5, point.y) * scale)
	m.face(front, color)
	m.face(rear, color.darkened(0.18))
	for i in points.size():
		var j: int = (i + 1) % points.size()
		m.face([front[i], front[j], rear[j], rear[i]], color.lightened(0.1) if points[j].y >= points[i].y else color.darkened(0.1))

static func _hay(m, u: float, v: float, w: float, d: float, h: float) -> void:
	m.cube(u, v, w, d, 2, h, Color("c6ab64"))
	for fraction in [0.22, 0.73]: m.cube(u + w * fraction, v - 0.002, 0.012, d + 0.004, 2, h + 0.3, Color("8e7746"))

static func _camp(m) -> void:
	var canvas := Color("cec299")
	if m.civilization == "French": canvas = Color("d7d0b5")
	elif m.civilization == "Chinese": canvas = Color("bdab8d")
	var timber: Color = m.palette["timber"]
	var z := 2.4
	var ridge := 21.0
	# Low canvas eaves have vertical skirts; the rear triangle closes the tent.
	var a: Vector3 = m.p(0.10, 0.08, 6)
	var b: Vector3 = m.p(0.76, 0.08, 6)
	var c: Vector3 = m.p(0.76, 0.66, 6)
	var d: Vector3 = m.p(0.10, 0.66, 6)
	var rear: Vector3 = m.p(0.43, 0.08, ridge)
	var front: Vector3 = m.p(0.43, 0.66, ridge)
	m.face([a, b, rear], canvas.darkened(0.15))
	m.face([a, rear, front, d], canvas.lightened(0.08))
	m.face([rear, b, c, front], canvas.darkened(0.12))
	m.face([m.p(0.10, 0.08, z), a, d, m.p(0.10, 0.66, z)], canvas.darkened(0.15))
	m.face([m.p(0.76, 0.08, z), b, c, m.p(0.76, 0.66, z)], canvas.darkened(0.25))
	# The opening shows real depth, with parted flaps at different planes.
	m.face([m.p(0.15, 0.53, z), m.p(0.70, 0.53, z), m.p(0.43, 0.53, 19)], Color("4a4537"))
	m.face([m.p(0.10, 0.662, z), d + Vector3(0, 0.04, 0), front + Vector3(0, 0.04, 0)], canvas.lightened(0.03))
	m.face([m.p(0.10, 0.662, z), front + Vector3(0, 0.04, 0), m.p(0.29, 0.72, z)], canvas.lightened(0.03))
	m.face([front + Vector3(0, 0.05, 0), c + Vector3(0, 0.05, 0), m.p(0.76, 0.663, z)], canvas.darkened(0.07))
	m.face([front + Vector3(0, 0.05, 0), m.p(0.76, 0.663, z), m.p(0.59, 0.71, z)], canvas.darkened(0.07))
	m.cube(0.415, 0.665, 0.025, 0.025, 2, 20, timber)
	# A broad team-colored ridge stripe reads well even at the normal zoom.
	m.face([m.p(0.43, 0.075, ridge + 0.08), m.p(0.49, 0.075, ridge - 2.65), m.p(0.49, 0.668, ridge - 2.65), m.p(0.43, 0.668, ridge + 0.08)], m.accent)
	for pair in [[Vector2(0.10, 0.10), Vector2(0.03, 0.025)], [Vector2(0.76, 0.10), Vector2(0.88, 0.04)], [Vector2(0.10, 0.63), Vector2(0.025, 0.81)], [Vector2(0.76, 0.62), Vector2(0.91, 0.72)]]:
		_rope(m, m.p(pair[0].x, pair[0].y, 7), m.p(pair[1].x, pair[1].y, 3))
		m.cube(pair[1].x - 0.012, pair[1].y - 0.012, 0.024, 0.024, 2, 3.5, timber)
	# Compact fire ring in the open foreground, rather than a flat red decal.
	var center: Vector3 = m.p(0.57, 0.86, 2)
	for i in 6:
		var angle := float(i) * TAU / 6
		m.box(Vector2(center.x, center.y) + Vector2(cos(angle), sin(angle)) * 3.5, Vector2.ONE * 1.8, 2, 1.6, Color("8a8775"))
	m.box(Vector2(center.x, center.y), Vector2(6, 1.2), 2.2, 1.1, Color("514737"))
	m.box(Vector2(center.x, center.y), Vector2(1.2, 5), 2.2, 1.1, Color("514737"))
	m.pyramid(center + Vector3(-2, -1.6, 1), center + Vector3(2, -1.6, 1), center + Vector3(2, 1.6, 1), center + Vector3(-2, 1.6, 1), 5, Color("d9843d"))
	m.face([center + Vector3(-0.9, 1.65, 1.1), center + Vector3(0.9, 1.65, 1.1), center + Vector3(0.15, 1.65, 4.5)], Color("ffd37a"))
	# Bedroll, supply chest and a grounded barrel give the camp an inhabited scale.
	m.cube(0.12, 0.79, 0.23, 0.11, 2, 3.5, Color("6d8064"))
	for u in [0.16, 0.28]: m.cube(u, 0.79, 0.02, 0.11, 2, 3.8, Color("a39471"))
	m._crate(0.80, 0.37, 0.13, 0.15, 2, 5)
	m._sack(0.83, 0.24, 2.5, Color("b7a574"))
	# Short scout pennant is secondary to the tent silhouette.
	m.cube(0.91, 0.17, 0.022, 0.022, 2, 21, timber)
	m.face([m.p(0.93, 0.18, 23), m.p(0.93, 0.39, 21), m.p(0.93, 0.18, 18)], m.accent)

static func _rope(m, a: Vector3, b: Vector3) -> void:
	var width := Vector3(0.19, 0.19, 0)
	m.face([a - width, a + width, b + width, b - width], Color("a29169"))

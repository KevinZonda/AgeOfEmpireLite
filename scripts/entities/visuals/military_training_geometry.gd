extends RefCounted

# Training props occupy the open foreground rather than hiding under the roof.
# All boards, shafts and supports participate in the shared 3D face ordering.
static func populate(mesh, kind: String) -> void:
	if kind == "barracks":
		_barracks(mesh)
	elif kind == "archery_range":
		_archery_range(mesh)

static func _barracks(mesh) -> void:
	mesh.hall(0.07, 0.07, 0.67, 0.44, 25, 12)
	mesh.door(0.33, 0.515, 0.17, 18)
	mesh.window(0.13, 0.542, 12, 6, 7)
	mesh.window(0.59, 0.542, 12, 6, 7)
	mesh.window(0.741, 0.21, 12, 7, 7, true)
	_facade(mesh, 0.07, 0.535, 0.67, 25)
	# A broad team-colored lintel and crossed blades identify the main entrance.
	mesh.cube(0.29, 0.545, 0.25, 0.022, 22, 2.5, mesh.accent)
	_shield(mesh, 0.43, 0.55, 29, 3.0, mesh.accent)
	_banner(mesh, 0.80, 0.17, 29)
	mesh.cube(0.39, 0.59, 0.53, 0.32, 2.02, 0.15, Color("a89772"))
	# Open weapons rack, with three clearly separated spearheads.
	var timber: Color = mesh.palette["timber"]
	for u in [0.10, 0.35]: mesh.cube(u, 0.73, 0.026, 0.04, 2, 14, timber)
	mesh.cube(0.09, 0.755, 0.29, 0.035, 13, 1.8, timber)
	mesh.cube(0.09, 0.755, 0.29, 0.035, 6, 1.2, timber)
	for u in [0.14, 0.22, 0.30]:
		mesh.cube(u, 0.80, 0.014, 0.015, 3, 18, Color("b99a6c"))
		mesh.face([mesh.p(u - 0.023, 0.816, 20), mesh.p(u + 0.037, 0.816, 20), mesh.p(u + 0.007, 0.816, 25)], Color("a3aaa3"))
	_shield(mesh, 0.13, 0.817, 10, 3.6, mesh.accent.darkened(0.08))
	_shield(mesh, 0.29, 0.817, 10, 3.6, Color("ac704e"))
	# Stump-mounted training dummy: head, shoulder bar and straw-filled torso.
	mesh.cube(0.70, 0.77, 0.17, 0.12, 2, 2, Color("807053"))
	mesh.cube(0.775, 0.815, 0.024, 0.027, 4, 17, timber)
	mesh.cube(0.665, 0.805, 0.24, 0.032, 15, 2.0, Color("a98d60"))
	_round_body(mesh, 0.787, 0.832, 8, 8, 3.0, Color("b6a16a"))
	mesh.cube(0.75, 0.795, 0.075, 0.075, 19, 4, Color("c4b477"))
	mesh.cube(0.742, 0.787, 0.09, 0.09, 23, 0.8, Color("876c45"))
	# A small supply chest balances the courtyard without obscuring its equipment.
	mesh.cube(0.85, 0.51, 0.10, 0.14, 2, 5, Color("a48253"))
	mesh.cube(0.846, 0.505, 0.11, 0.15, 7, 1, timber)

static func _archery_range(mesh) -> void:
	mesh.hall(0.07, 0.07, 0.44, 0.45, 21, 10)
	mesh.door(0.21, 0.525, 0.15, 16)
	mesh.window(0.511, 0.18, 10, 6, 7, true)
	_facade(mesh, 0.07, 0.542, 0.44, 21)
	mesh.cube(0.08, 0.552, 0.43, 0.021, 19, 1.7, mesh.accent)
	_banner(mesh, 0.59, 0.16, 26)
	mesh.cube(0.55, 0.30, 0.39, 0.60, 2.02, 0.15, Color("ad9f76"))
	# Upright targets have thick rims, real rear braces and foot beams.
	for v in [0.34, 0.61, 0.88]:
		_target(mesh, 0.80, v, 15, 6.0)
	# Covered stores use an open rack, so bow silhouettes stay visible at 1x.
	var timber: Color = mesh.palette["timber"]
	for u in [0.10, 0.40]: mesh.cube(u, 0.81, 0.027, 0.04, 2, 14, timber)
	mesh.cube(0.09, 0.822, 0.34, 0.025, 14, 1.5, timber)
	mesh.cube(0.09, 0.822, 0.34, 0.025, 5, 1.2, timber)
	_bow(mesh, 0.18, 0.86, 4, 11)
	_bow(mesh, 0.32, 0.86, 4, 11)
	# A short open arrow bin; the bundle rises above its dark opening.
	mesh.cube(0.43, 0.70, 0.09, 0.13, 2, 5, Color("9d7b4b"))
	mesh.cube(0.44, 0.71, 0.07, 0.11, 7.03, 0.12, Color("433d30"))
	for i in 3:
		var u := 0.446 + i * 0.025
		mesh.cube(u, 0.765, 0.010, 0.01, 6, 8 + i, Color("ccb383"))
		mesh.face([mesh.p(u - 0.012, 0.777, 13 + i), mesh.p(u + 0.022, 0.777, 13 + i), mesh.p(u + 0.005, 0.777, 16 + i)], Color("d6d4b4"))

static func _facade(mesh, u: float, v: float, w: float, height: float) -> void:
	var timber: Color = mesh.palette["timber"]
	if mesh.civilization == "English":
		for x in [u + 0.02, u + w - 0.035]:
			mesh.cube(x, v, 0.025, 0.025, 2, height - 1, timber)
		mesh.beam(mesh.p(u + 0.035, v + 0.027, height), mesh.p(u + w * 0.23, v + 0.027, 16), 1.3, timber)
		mesh.beam(mesh.p(u + w * 0.77, v + 0.027, 16), mesh.p(u + w - 0.035, v + 0.027, height), 1.3, timber)
	elif mesh.civilization == "French":
		for z in [5.0, 11.0, 17.0]:
			for x in [u, u + w - 0.052]: mesh.cube(x, v, 0.052, 0.023, z, 2.3, mesh.palette["trim"])
	else:
		for x in [u + 0.03, u + w - 0.055]: mesh.cube(x, v, 0.027, 0.032, 2, height, timber)
		mesh.cube(u, v, w, 0.03, height - 3, 2, timber)

static func _banner(mesh, u: float, v: float, height: float) -> void:
	mesh.cube(u, v, 0.018, 0.018, 2, height, mesh.palette["timber"])
	mesh.face([mesh.p(u + 0.018, v + 0.019, height), mesh.p(u + 0.15, v + 0.019, height), mesh.p(u + 0.15, v + 0.019, height - 7), mesh.p(u + 0.018, v + 0.019, height - 6)], mesh.accent)
	mesh.cube(u - 0.025, v - 0.025, 0.07, 0.07, 2, 1.7, mesh.palette["trim"])

static func _shield(mesh, u: float, v: float, z: float, radius: float, color: Color) -> void:
	var center: Vector3 = mesh.p(u, v, z)
	var outline := [Vector2(-radius, radius), Vector2(radius, radius), Vector2(radius * 0.85, -radius * 0.35), Vector2(0, -radius * 1.1), Vector2(-radius * 0.85, -radius * 0.35)]
	var outer: Array = []
	var inner: Array = []
	for point in outline:
		outer.append(center + Vector3(point.x, 0, point.y))
		inner.append(center + Vector3(point.x * 0.76, 0.035, point.y * 0.76))
	mesh.face(outer, mesh.palette["trim"])
	mesh.face(inner, color)
	mesh.face([center + Vector3(-0.45, 0.07, -radius * 0.8), center + Vector3(0.45, 0.07, -radius * 0.8), center + Vector3(0.45, 0.07, radius * 0.8), center + Vector3(-0.45, 0.07, radius * 0.8)], mesh.palette["trim"])

static func _round_body(mesh, u: float, v: float, z: float, height: float, radius: float, color: Color) -> void:
	var center: Vector3 = mesh.p(u, v, z)
	var top: Array = []
	for i in 6:
		var a := TAU * i / 6.0
		var b := TAU * (i + 1) / 6.0
		var p := center + Vector3(cos(a) * radius, sin(a) * radius, 0)
		var q := center + Vector3(cos(b) * radius, sin(b) * radius, 0)
		if cos((a + b) * 0.5) + sin((a + b) * 0.5) > 0:
			mesh.face([p, q, q + Vector3(0, 0, height), p + Vector3(0, 0, height)], color.darkened(0.09 * i))
		top.append(p + Vector3(0, 0, height))
	mesh.face(top, color.lightened(0.10))

static func _target(mesh, u: float, v: float, z: float, radius: float) -> void:
	var timber: Color = mesh.palette["timber"]
	var center: Vector3 = mesh.p(u, v, z)
	# Face the training yard's fixed camera, preserving a round target profile.
	var across := Vector3(1, -1, 0).normalized()
	var forward := Vector3(1, 1, 0).normalized()
	var rear := center - forward * 2.6
	# The stem and brace sit behind the entire disk, including its lower rings.
	mesh.box(Vector2(rear.x, rear.y), Vector2.ONE * 1.8, 2, z - radius * 0.6 - 2, timber)
	mesh.box(Vector2(rear.x, rear.y), Vector2(8, 5), 2, 1.4, timber)
	var brace_foot := rear - forward * 7
	brace_foot.z = 3
	_strut(mesh, brace_foot, rear - Vector3(0, 0, radius * 0.4), 1.1, timber)
	var board: Array = []
	for i in 12:
		var a := TAU * i / 12.0
		var b := TAU * (i + 1) / 12.0
		var first := center + across * cos(a) * radius + Vector3(0, 0, sin(a) * radius)
		var next := center + across * cos(b) * radius + Vector3(0, 0, sin(b) * radius)
		board.append(first)
		if sin((a + b) * 0.5) > 0:
			mesh.face([first, next, next - forward * 1.4, first - forward * 1.4], Color("917348"))
	mesh.face(board, Color("ccbb86"))
	for ring in 3:
		var disc: Array = []
		var ring_radius: float = radius * [0.72, 0.44, 0.17][ring]
		for i in 12:
			var angle := TAU * i / 12.0
			disc.append(center + across * cos(angle) * ring_radius + forward * 0.035 * (ring + 1) + Vector3(0, 0, sin(angle) * ring_radius))
		mesh.face(disc, [Color("8d5640"), Color("d7c996"), mesh.accent.darkened(0.12)][ring])

static func _strut(mesh, a: Vector3, b: Vector3, width: float, color: Color) -> void:
	var cross := Vector3(1, 0, 0) * width * 0.5
	var side := (b - a).cross(Vector3.RIGHT).normalized() * width * 0.5
	mesh.face([a - cross + side, a + cross + side, b + cross + side, b - cross + side], color)
	mesh.face([a + cross - side, a + cross + side, b + cross + side, b + cross - side], color.darkened(0.2))
	mesh.face([b - cross - side, b + cross - side, b + cross + side, b - cross + side], color.lightened(0.1))

static func _bow(mesh, u: float, v: float, z: float, height: float) -> void:
	# Each wooden arc uses four convex ribbons; its taut string is separate.
	var curve := [Vector2(0, 0), Vector2(1.8, height * 0.20), Vector2(2.7, height * 0.50), Vector2(1.8, height * 0.80), Vector2(0, height)]
	var center: Vector3 = mesh.p(u, v, z)
	for i in 4:
		mesh.beam(center + Vector3(curve[i].x, 0, curve[i].y), center + Vector3(curve[i + 1].x, 0, curve[i + 1].y), 1.0, Color("b9945e"))
	mesh.beam(center + Vector3(0, 0.03, 0), center + Vector3(0, 0.03, height), 0.35, Color("ddd1aa"))

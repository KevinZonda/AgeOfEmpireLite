extends RefCounted

# Work yards use solid props in the same world coordinates as the buildings,
# so roof posts, wheels, crane ropes and cut logs share their occlusion order.
static func populate(mesh, kind: String) -> void:
	match kind:
		"lumber_camp": _lumber(mesh)
		"mining_camp": _mining(mesh)
		"siege_workshop": _siege(mesh)

static func _lumber(m) -> void:
	var wood: Color = m.palette["timber"]
	# Small store room leaves most of the footprint open for actual timber.
	m.hall(0.06, 0.06, 0.37, 0.30, 17, 8)
	m.door(0.17, 0.365, 0.14, 13)
	m.cube(0.08, 0.388, 0.31, 0.02, 16, 1.8, m.accent)
	# Triangular stack: the foreground cut ends are round, with sapwood rims.
	for position in [Vector3(0.59, 0.34, 4.4), Vector3(0.72, 0.34, 4.4), Vector3(0.85, 0.34, 4.4), Vector3(0.655, 0.34, 8.2), Vector3(0.785, 0.34, 8.2)]:
		_log(m, m.p(position.x, position.y, position.z), Vector3(0, 13, 0), 2.25)
	# A timber gantry suspends one log beside the cutting station.
	for u in [0.08, 0.40]:
		m.cube(u, 0.69, 0.035, 0.045, 2, 21, wood)
		m.beam(m.p(u + 0.017, 0.74, 15), m.p(u + 0.075 if u == 0.08 else u - 0.06, 0.74, 22), 1.3, wood)
	m.cube(0.075, 0.685, 0.37, 0.06, 23, 2.2, wood)
	_rope(m, m.p(0.25, 0.72, 23), m.p(0.25, 0.72, 11))
	_log(m, m.p(0.25, 0.54, 9), Vector3(0, 15, 0), 2.2)
	# A broad saw blade and two sawhorses remain legible at normal zoom.
	for v in [0.69, 0.89]:
		m.cube(0.56, v, 0.027, 0.025, 2, 7, wood)
		m.cube(0.77, v, 0.027, 0.025, 2, 7, wood)
		m.cube(0.54, v, 0.27, 0.035, 9, 1.3, wood.lightened(0.12))
	_log(m, m.p(0.665, 0.64, 12), Vector3(0, 14, 0), 1.8)
	m.face([m.p(0.59, 0.80, 12), m.p(0.75, 0.80, 16), m.p(0.75, 0.80, 17.2), m.p(0.59, 0.80, 13.2)], Color("99a49a"))
	m.cube(0.745, 0.79, 0.025, 0.027, 15, 4, Color("b08a57"))
	# Stacked planks and an axe in its chopping block.
	for z in [2.0, 3.5, 5.0]: m.cube(0.07, 0.87, 0.34, 0.055, z, 1.2, Color("bc9b68"))
	_log(m, m.p(0.91, 0.79, 2), Vector3(0, 0, 5), 3)
	m.cube(0.905, 0.795, 0.014, 0.015, 6, 7, Color("b59a6e"))
	m.cube(0.875, 0.793, 0.07, 0.019, 11, 2.5, Color("6b7875"))

static func _mining(m) -> void:
	var wood: Color = m.palette["timber"]
	var rock := Color("847f6d")
	# The dark tunnel is recessed behind thick side masonry and real supports.
	m.cube(0.06, 0.08, 0.10, 0.34, 2, 18, rock)
	m.cube(0.54, 0.08, 0.10, 0.34, 2, 18, rock)
	m.cube(0.16, 0.08, 0.38, 0.04, 2, 19, Color("343b32"))
	m.cube(0.13, 0.36, 0.045, 0.05, 2, 18, wood)
	m.cube(0.525, 0.36, 0.045, 0.05, 2, 18, wood)
	m.cube(0.12, 0.36, 0.46, 0.06, 20, 2.5, wood)
	# Lean roof has a strong low silhouette, rather than an enclosed cottage.
	m.face([m.p(0.035, 0.06, 24), m.p(0.665, 0.06, 24), m.p(0.665, 0.45, 21), m.p(0.035, 0.45, 21)], m.palette["roof"])
	m.face([m.p(0.035, 0.45, 21), m.p(0.665, 0.45, 21), m.p(0.665, 0.45, 19.5), m.p(0.035, 0.45, 19.5)], m.palette["roof_dark"])
	m.cube(0.23, 0.422, 0.24, 0.02, 20, 2, m.accent)
	# Hand tools hang from a low rack in the open working yard.
	for u in [0.08, 0.49]: m.cube(u, 0.62, 0.025, 0.03, 2, 12, wood)
	m.cube(0.075, 0.62, 0.445, 0.03, 14, 1.6, wood)
	m.cube(0.18, 0.655, 0.015, 0.018, 3, 10, Color("b49a6b"))
	m.face([m.p(0.105, 0.677, 12), m.p(0.18, 0.677, 14), m.p(0.18, 0.677, 12.9)], Color("65716a"))
	m.face([m.p(0.18, 0.677, 14), m.p(0.27, 0.677, 12), m.p(0.18, 0.677, 12.9)], Color("65716a"))
	m.cube(0.36, 0.655, 0.015, 0.018, 6, 8, Color("b49a6b"))
	m.face([m.p(0.32, 0.678, 7), m.p(0.41, 0.678, 7), m.p(0.40, 0.678, 3), m.p(0.365, 0.678, 2.5), m.p(0.33, 0.678, 3)], Color("788078"))
	_basket(m, m.p(0.25, 0.84, 2), 3.0)
	_basket(m, m.p(0.47, 0.79, 2), 2.6)
	_ore(m, m.p(0.25, 0.84, 6.8), 1.7, 2.4, Color("a39d86"))
	# A simple hand winch lifts a bucket beside the entrance.
	for u in [0.72, 0.90]: m.cube(u, 0.25, 0.027, 0.035, 2, 17, wood)
	m.cube(0.71, 0.25, 0.24, 0.04, 19, 2, wood)
	_cylinder(m, m.p(0.79, 0.265, 13), Vector3(5, 0, 0), 2, Color("a48c61"), 8)
	_rope(m, m.p(0.83, 0.28, 20), m.p(0.83, 0.28, 6))
	m.cube(0.79, 0.245, 0.08, 0.08, 2, 5, Color("9f8860"))
	# Broad broken stones form a two-layer stockpile in the open foreground.
	_stone(m, m.p(0.69, 0.67, 2), Vector2(7.6, 6.0), 4.2, Color("92988d"))
	_stone(m, m.p(0.85, 0.65, 2), Vector2(7.4, 6.0), 3.8, Color("a4a79b"))
	_stone(m, m.p(0.89, 0.82, 2), Vector2(7.0, 6.5), 4.0, Color("858f89"))
	_stone(m, m.p(0.70, 0.84, 2), Vector2(7.6, 6.5), 4.3, Color("a1a499"))
	_stone(m, m.p(0.78, 0.72, 5.6), Vector2(7.2, 6.2), 4.2, Color("aeb2a8"))
	_stone(m, m.p(0.81, 0.83, 5.7), Vector2(6.4, 5.4), 3.5, Color("929d96"))
	_stone(m, m.p(0.60, 0.90, 2), Vector2(3.1, 2.7), 2.0, Color("879289"))
	m.cube(0.84, 0.84, 0.014, 0.017, 3, 11, Color("ad9161"))
	m.cube(0.805, 0.835, 0.085, 0.02, 12, 1.8, Color("5e6d69"))

static func _stone(m, center: Vector3, extent: Vector2, height: float, color: Color) -> void:
	# An irregular, flat-topped broken block. Triangular sides keep every face
	# planar despite the tilted top and unequal cuts around the footprint.
	var outline := [Vector2(-0.95, -0.35), Vector2(-0.38, -0.85), Vector2(0.56, -0.73), Vector2(1.0, 0.02), Vector2(0.55, 0.74), Vector2(-0.56, 0.79)]
	var lower: Array = []
	var upper: Array = []
	for point in outline:
		var ground: Vector2 = point * extent * 0.5
		var cap := ground * 0.74 + extent * Vector2(0.04, -0.03)
		lower.append(center + Vector3(ground.x, ground.y, 0))
		upper.append(center + Vector3(cap.x, cap.y, height + cap.x * 0.13 - cap.y * 0.10))
	m.face(upper, color.lightened(0.13))
	for i in outline.size():
		var j := (i + 1) % outline.size()
		var tint := color.darkened(0.16 if i < 3 else 0.04)
		m.face([lower[i], lower[j], upper[j]], tint)
		m.face([lower[i], upper[j], upper[i]], tint)

static func _basket(m, center: Vector3, radius: float) -> void:
	var wicker := Color("ae9464")
	for i in 8:
		var a := float(i) * TAU / 8
		var b := float(i + 1) * TAU / 8
		var first := Vector3(cos(a), sin(a), 0)
		var second := Vector3(cos(b), sin(b), 0)
		m.face([center + first * radius * 0.72, center + second * radius * 0.72, center + second * radius + Vector3(0, 0, 5), center + first * radius + Vector3(0, 0, 5)], wicker.lightened(0.10 * cos(a)))
		m.face([center + first * radius * 0.90 + Vector3(0, 0, 3), center + second * radius * 0.90 + Vector3(0, 0, 3), center + second * radius * 0.93 + Vector3(0, 0, 3.6), center + first * radius * 0.93 + Vector3(0, 0, 3.6)], wicker.darkened(0.19))
	_disc(m, center + Vector3(0, 0, 5), Vector3(0, 0, 1), radius, wicker.lightened(0.12), 8)
	_disc(m, center + Vector3(0, 0, 5.05), Vector3(0, 0, 1), radius * 0.79, Color("625b42"), 8)
	# A broad arch handle distinguishes the hand basket from a barrel.
	var front := center + Vector3(0, radius * 0.12, 0)
	m.beam(front + Vector3(-radius * 0.9, 0, 5), front + Vector3(-radius * 0.6, 0, 8.5), 0.65, wicker)
	m.beam(front + Vector3(-radius * 0.6, 0, 8.5), front + Vector3(radius * 0.6, 0, 8.5), 0.65, wicker)
	m.beam(front + Vector3(radius * 0.6, 0, 8.5), front + Vector3(radius * 0.9, 0, 5), 0.65, wicker)

static func _siege(m) -> void:
	var wood: Color = m.palette["timber"]
	# Two connected rear workshops frame an exposed central assembly yard.
	m.hall(0.055, 0.055, 0.39, 0.34, 24, 12)
	m.hall(0.555, 0.055, 0.39, 0.34, 24, 12)
	m.cube(0.44, 0.09, 0.12, 0.15, 2, 19, m.palette["wall"].darkened(0.12))
	m.door(0.18, 0.40, 0.13, 19)
	m.door(0.67, 0.40, 0.13, 19)
	m.window(0.945, 0.16, 13, 8, 7, true)
	for u in [0.095, 0.815]: m.window(u, 0.405, 13, 5, 7)
	for u in [0.065, 0.565]: m.cube(u, 0.43, 0.36, 0.018, 22, 2, m.accent)
	# The recognizable two-wheel catapult is now a proper frame and throwing arm.
	_catapult(m)
	# Spare wheel, planks, and a braced upright assembly scaffold.
	_cylinder(m, m.p(0.88, 0.66, 7), Vector3(0, 1.6, 0), 5, Color("97794e"), 10)
	_cylinder(m, m.p(0.88, 0.695, 7), Vector3(0, 0.3, 0), 1.1, Color("655743"), 8)
	for z in [2.0, 4.0]: m.cube(0.74, 0.80, 0.22, 0.10, z, 1.5, Color("b39a6c"))
	for v in [0.58, 0.86]: m.cube(0.065, v, 0.033, 0.033, 2, 19, wood)
	m.cube(0.06, 0.575, 0.04, 0.32, 21, 2, wood)
	_rod(m, m.p(0.085, 0.61, 3), m.p(0.085, 0.85, 20), 1.4, wood)
	_rope(m, m.p(0.085, 0.70, 22), m.p(0.085, 0.70, 9))
	m._crate(0.12, 0.80, 0.13, 0.13, 2, 6)

static func _catapult(m) -> void:
	var wood := Color("97784e")
	var dark := Color("5b5140")
	# Longitudinal chassis rails join a single substantial axle and two wheels.
	for v in [0.64, 0.79]: m.cube(0.30, v, 0.39, 0.03, 7, 2, wood)
	m.cube(0.47, 0.58, 0.035, 0.29, 6, 1.7, dark)
	for v in [0.58, 0.85]:
		_cylinder(m, m.p(0.49, v, 7), Vector3(0, 1.8, 0), 5, wood, 10)
		_cylinder(m, m.p(0.49, v + 0.029, 7), Vector3(0, 0.2, 0), 1.0, dark, 8)
	# A pair of triangular uprights and crossbar cradle the arm.
	for v in [0.65, 0.79]:
		_rod(m, m.p(0.37, v, 8), m.p(0.48, v, 20), 1.4, wood)
		_rod(m, m.p(0.59, v, 8), m.p(0.48, v, 20), 1.4, wood)
	m.cube(0.462, 0.62, 0.037, 0.21, 19, 1.8, dark)
	_rod(m, m.p(0.32, 0.72, 8), m.p(0.61, 0.72, 30), 1.8, Color("b29a6d"))
	# Broad cup at the raised tip and compact rear winding drum.
	m.cube(0.586, 0.683, 0.09, 0.075, 30, 1.2, dark)
	for v in [0.679, 0.751]: m.cube(0.58, v, 0.10, 0.01, 31, 1.8, wood)
	m.cube(0.58, 0.679, 0.01, 0.08, 31, 1.8, wood)
	_cylinder(m, m.p(0.33, 0.64, 10), Vector3(0, 11, 0), 1.6, dark, 8)
	_rope(m, m.p(0.34, 0.72, 10), m.p(0.54, 0.72, 25))

static func _log(m, origin: Vector3, direction: Vector3, radius: float) -> void:
	_cylinder(m, origin, direction, radius, Color("80603e"), 8)
	# Cut grain sits in front of the cylinder cap, so it cannot become a label.
	var normal := direction.normalized()
	_disc(m, origin + direction + normal * 0.05, normal, radius * 0.84, Color("d0af78"), 8)
	_disc(m, origin + direction + normal * 0.10, normal, radius * 0.34, Color("b58d58"), 8)

static func _cylinder(m, origin: Vector3, direction: Vector3, radius: float, color: Color, sides: int) -> void:
	var normal := direction.normalized()
	var basis_u := normal.cross(Vector3(0, 0, 1)).normalized() if absf(normal.z) < 0.9 else Vector3.RIGHT
	var basis_v := normal.cross(basis_u).normalized()
	var first: Array = []
	var second: Array = []
	for i in sides:
		var angle := float(i) * TAU / sides
		var offset := (basis_u * cos(angle) + basis_v * sin(angle)) * radius
		first.append(origin + offset)
		second.append(origin + direction + offset)
	m.face(first, color.darkened(0.18))
	m.face(second, color.lightened(0.14))
	for i in sides:
		var j := (i + 1) % sides
		m.face([first[i], first[j], second[j], second[i]], color.lightened(0.09 * cos(float(i) * TAU / sides)))

static func _disc(m, origin: Vector3, normal: Vector3, radius: float, color: Color, sides: int) -> void:
	var basis_u := normal.cross(Vector3(0, 0, 1)).normalized() if absf(normal.z) < 0.9 else Vector3.RIGHT
	var basis_v := normal.cross(basis_u).normalized()
	var points: Array = []
	for i in sides:
		var angle := float(i) * TAU / sides
		points.append(origin + (basis_u * cos(angle) + basis_v * sin(angle)) * radius)
	m.face(points, color)

static func _rod(m, a: Vector3, b: Vector3, width: float, color: Color) -> void:
	var normal := (b - a).normalized()
	var u := normal.cross(Vector3(0, 0, 1)).normalized() * width * 0.5 if absf(normal.z) < 0.9 else Vector3.RIGHT * width * 0.5
	var v := normal.cross(u).normalized() * width * 0.5
	var first := [a - u - v, a + u - v, a + u + v, a - u + v]
	var second := [b - u - v, b + u - v, b + u + v, b - u + v]
	m.face(first, color.darkened(0.12))
	m.face(second, color.lightened(0.12))
	for i in 4:
		var j := (i + 1) % 4
		m.face([first[i], first[j], second[j], second[i]], color.lightened(0.06 * i))

static func _rope(m, a: Vector3, b: Vector3) -> void:
	var u := Vector3(0.16, 0.16, 0)
	m.face([a - u, a + u, b + u, b - u], Color("c1ae81"))

static func _ore(m, center: Vector3, radius: float, height: float, color: Color) -> void:
	var top := center + Vector3(radius * 0.1, -radius * 0.12, height)
	for i in 6:
		var a := float(i) * TAU / 6
		var b := float(i + 1) * TAU / 6
		m.face([center + Vector3(cos(a), sin(a), 0) * radius, center + Vector3(cos(b), sin(b), 0) * radius, top], color.lightened(0.11 * cos(a)))

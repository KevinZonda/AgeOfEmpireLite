extends RefCounted

# Local machine coordinates: x is the axle, negative y is the muzzle, z is height.
# The shared geometry renderer owns facing, projection, lighting and depth sorting.
static func build(g, state) -> void:
	match state.kind:
		"bombard": _bombard(g, state)
		"cannon": _cannon(g, state)
		"nest_of_bees": _nest_of_bees(g, state)

static func _bombard(g, state) -> void:
	# A compact bronze bombard on a four-wheel push cart. The handles and broad
	# barrel distinguish its silhouette from the long iron cannon and its trail.
	var recoil: float = maxf(0.0, float(g.attack_motion(state))) * 3.4
	var bronze := Color("987344")
	var bronze_light := Color("c1a06a")
	var bronze_dark := Color("695132")
	g.box(Vector3(-11, -14, 5), Vector3(11, 14, 8), g.WOOD_DARK)
	for x in [-9.0, 9.0]:
		g.box(Vector3(x - 1.7, -16, 7), Vector3(x + 1.7, 16, 10), g.WOOD)
		g.beam(Vector3(x, 11, 8), Vector3(x, 25, 13), 2.4, g.WOOD_LIGHT)
		g.beam(Vector3(x, 25, 13), Vector3(x, 29, 13), 2.1, g.WOOD_DARK)
	for y in [-10.0, 10.0]:
		g.beam(Vector3(-15, y, 4.5), Vector3(15, y, 4.5), 2.4, g.IRON)
		for x in [-13.5, 13.5]:
			g.wheel(Vector3(x, y, 4.5), 4.5, 2.8)
	for y in [-11.0, -4.0, 4.0, 11.0]:
		g.box(Vector3(-9, y - 1.9, 8), Vector3(9, y + 1.9, 9), g.WOOD_LIGHT)
	# Raised cheeks carry a horizontal trunnion; the barrel slides within them.
	for x in [-8.0, 8.0]:
		g.box(Vector3(x - 1.6, -6, 9), Vector3(x + 1.6, 7, 16), g.WOOD)
		g.box(Vector3(x - 1.8, -3, 15), Vector3(x + 1.8, 1, 17), g.IRON)
	g.cylinder(Vector3(-10, -1 + recoil, 17), Vector3(10, -1 + recoil, 17), 1.9, g.IRON)
	g.cylinder(Vector3(0, 9 + recoil, 17), Vector3(0, -9 + recoil, 18.5), 5.3, bronze)
	g.cylinder(Vector3(0, -9 + recoil, 18.5), Vector3(0, -18 + recoil, 19.2), 4.7, bronze)
	g.cylinder(Vector3(0, 8 + recoil, 17), Vector3(0, 10 + recoil, 17), 5.8, bronze_dark)
	g.cylinder(Vector3(0, -5 + recoil, 18.2), Vector3(0, -7 + recoil, 18.3), 5.7, bronze_light)
	g.cylinder(Vector3(0, -16 + recoil, 19.1), Vector3(0, -19 + recoil, 19.3), 5.5, bronze_light)
	_muzzle(g, Vector3(0, -19.2 + recoil, 19.3), 5.5, 3.5, bronze_light)
	g.cylinder(Vector3(0, 10 + recoil, 17), Vector3(0, 13 + recoil, 17), 1.6, bronze_dark)
	g.box(Vector3(-5, 10, 10), Vector3(5, 12, 11.5), g.team_color)
	g.beam(Vector3(-10, 14, 9), Vector3(10, 14, 9), 1.2, g.IRON)
	_fire(g, state, Vector3(0, -20 + recoil, 19.3), 6.5)

static func _cannon(g, state) -> void:
	var recoil: float = maxf(0.0, float(g.attack_motion(state))) * 4.2
	# Two large wheels and a long splayed rear trail carry a narrow iron barrel.
	for x in [-7.0, 7.0]:
		g.beam(Vector3(x, -7, 10), Vector3(x * 0.48, 23, 2.6), 3.8, g.WOOD)
		g.beam(Vector3(x, -8, 10), Vector3(x, 5, 13), 3.4, g.WOOD_LIGHT)
		g.box(Vector3(x - 1.7, -8, 10), Vector3(x + 1.7, 5, 16), g.WOOD)
		g.box(Vector3(x - 1.9, -5, 15), Vector3(x + 1.9, -1, 17), g.IRON)
	g.beam(Vector3(-4, 23, 2.4), Vector3(4, 23, 2.4), 2.8, g.IRON)
	g.beam(Vector3(-15, -5, 8), Vector3(15, -5, 8), 2.8, g.IRON)
	for x in [-13.0, 13.0]:
		g.wheel(Vector3(x, -5, 8), 8.0, 3.4)
	g.beam(Vector3(-8, 7, 10), Vector3(8, 7, 10), 2.4, g.WOOD_DARK)
	g.box(Vector3(-4, 8, 7), Vector3(4, 13, 10), g.WOOD_LIGHT)
	g.box(Vector3(-4, 8.5, 10), Vector3(4, 10.2, 11), g.team_color)
	g.cylinder(Vector3(-9, -3 + recoil, 17), Vector3(9, -3 + recoil, 17), 1.7, g.IRON_LIGHT)
	# The stepped barrel has a heavy breech, tapered chase and thick muzzle lip.
	g.cylinder(Vector3(0, 8 + recoil, 17), Vector3(0, -5 + recoil, 18), 4.5, g.IRON)
	g.cylinder(Vector3(0, -5 + recoil, 18), Vector3(0, -17 + recoil, 19), 3.8, g.IRON)
	g.cylinder(Vector3(0, -17 + recoil, 19), Vector3(0, -28 + recoil, 20), 3.2, g.IRON)
	g.cylinder(Vector3(0, 7 + recoil, 17), Vector3(0, 9 + recoil, 17), 4.9, g.IRON_LIGHT)
	g.cylinder(Vector3(0, -3 + recoil, 17.8), Vector3(0, -5 + recoil, 18), 4.6, g.IRON_LIGHT)
	g.cylinder(Vector3(0, -25 + recoil, 19.7), Vector3(0, -29 + recoil, 20.1), 4.0, g.IRON_LIGHT)
	_muzzle(g, Vector3(0, -29.2 + recoil, 20.1), 4.0, 2.45, g.IRON_LIGHT)
	g.cylinder(Vector3(0, 9 + recoil, 17), Vector3(0, 12 + recoil, 17), 1.5, g.IRON)
	g.line(Vector3(-1.3, 5 + recoil, 21.6), Vector3(-1.3, -24 + recoil, 23), Color("88918c"), 0.7)
	_fire(g, state, Vector3(0, -30 + recoil, 20.1), 7.3)

static func _muzzle(g, center: Vector3, outside: float, inside: float, metal: Color) -> void:
	# A real annular face retains the metal lip at side and oblique facings.
	var dark := Color("1d2424")
	var hollow: Array[Vector3] = []
	for i in 12:
		var a: float = TAU * float(i) / 12.0
		var b: float = TAU * float(i + 1) / 12.0
		var va := Vector3(cos(a), 0, sin(a))
		var vb := Vector3(cos(b), 0, sin(b))
		g.face([center + va * outside, center + vb * outside, center + vb * inside, center + va * inside], metal)
		hollow.append(center + va * inside + Vector3(0, 0.12, 0))
	g.face(hollow, dark)

static func _nest_of_bees(g, state) -> void:
	# The launcher is a deep, upward-tilted wooden rack, not a flat perforated
	# panel. Twelve tube mouths survive at normal zoom without visual noise.
	g.box(Vector3(-11, -13, 5), Vector3(11, 15, 8), g.WOOD_DARK)
	for x in [-9.0, 9.0]:
		g.box(Vector3(x - 1.6, -15, 7), Vector3(x + 1.6, 16, 10), g.WOOD)
	for y in [-10.0, 11.0]:
		g.beam(Vector3(-15, y, 5), Vector3(15, y, 5), 2.2, g.IRON)
		for x in [-13.0, 13.0]:
			g.wheel(Vector3(x, y, 5), 5.0, 2.8)
	for x in [-9.0, 9.0]:
		g.beam(Vector3(x, -8, 9), Vector3(x, 1, 24), 3.0, g.WOOD_LIGHT)
		g.beam(Vector3(x, 13, 9), Vector3(x, 1, 24), 3.0, g.WOOD)
		g.beam(Vector3(x, 10, 11), Vector3(x, -2, 26), 1.5, g.IRON)
	g.cylinder(Vector3(-13, 1, 24), Vector3(13, 1, 24), 2.0, g.IRON)
	# Tiny rack recoil pivots around the supported axle; the cart stays grounded.
	var kick: float = maxf(0.0, float(g.attack_motion(state)))
	var angle: float = -0.38 + kick * 0.035
	var outer := [
		Vector3(-11.5, -9, -9), Vector3(11.5, -9, -9),
		Vector3(11.5, 9, -9), Vector3(-11.5, 9, -9),
		Vector3(-11.5, -9, 9), Vector3(11.5, -9, 9),
		Vector3(11.5, 9, 9), Vector3(-11.5, 9, 9)
	]
	for indices in [[0, 3, 2, 1], [4, 5, 6, 7], [3, 0, 4, 7], [1, 2, 6, 5], [2, 3, 7, 6]]:
		var points: Array[Vector3] = []
		for index in indices:
			points.append(_rack_point(outer[index], angle))
		g.face(points, g.WOOD if indices[0] == 4 else g.WOOD_DARK, true)
	# Tube bodies live inside the casing; their front sleeves are composited
	# with the backing as one panel so its center cannot cover the lower rows.
	g.begin_surface_group(_rack_point(Vector3(0, -9.5, 0), angle))
	for row in 3:
		for column in 4:
			var tube := Vector3(-7.5 + column * 5.0, -9.3, -5.0 + row * 5.0)
			var muzzle: Vector3 = _rack_point(tube, angle)
			# The rest of each tube is enclosed by the solid box. Drawing its
			# hidden rear cap later would turn some black bores into brass dots.
			g.cylinder(_rack_point(tube + Vector3(0, 1.3, 0), angle), muzzle, 1.75, Color("98784b"), 8)
	g.face([
		_rack_point(Vector3(-10, -8.7, -7.5), angle),
		_rack_point(Vector3(10, -8.7, -7.5), angle),
		_rack_point(Vector3(10, -8.7, 7.5), angle),
		_rack_point(Vector3(-10, -8.7, 7.5), angle)
	], Color("332b23"), true)
	for row in 3:
		for column in 4:
			var tube := Vector3(-7.5 + column * 5.0, -9.45, -5.0 + row * 5.0)
			var sleeve: Array[Vector3] = []
			var opening: Array[Vector3] = []
			for i in 8:
				var a: float = TAU * float(i) / 8.0
				sleeve.append(_rack_point(tube + Vector3(cos(a) * 1.75, 0, sin(a) * 1.75), angle))
				opening.append(_rack_point(tube + Vector3(cos(a) * 1.1, -0.12, sin(a) * 1.1), angle))
			g.face(sleeve, Color("b08c58"), true)
			g.face(opening, Color("191e1c"), true)
	g.end_surface_group()
	if _fresh_release(state):
		for row in 3:
			for column in 4:
				if (row + column) % 2 == 0:
					_flash(g, _rack_point(Vector3(-7.5 + column * 5.0, -9.6, -5.0 + row * 5.0), angle), Vector3(0, -cos(angle), -sin(angle)), 2.5 + float(column % 2))
	for z in [-8.5, 8.5]:
		g.beam(_rack_point(Vector3(-12, -9.5, z), angle), _rack_point(Vector3(12, -9.5, z), angle), 1.8, g.WOOD_LIGHT)
	for x in [-11.3, 11.3]:
		g.beam(_rack_point(Vector3(x, -9.5, -9), angle), _rack_point(Vector3(x, -9.5, 9), angle), 1.8, g.WOOD_LIGHT)
		g.beam(_rack_point(Vector3(x, -2, -9), angle), _rack_point(Vector3(x, -2, 9), angle), 1.3, g.IRON)
		g.beam(_rack_point(Vector3(x, 7, -9), angle), _rack_point(Vector3(x, 7, 9), angle), 1.3, g.IRON)
	# Small colored lacquer plates leave the majority of the rack natural wood.
	for x in [-11.6, 11.6]:
		g.face([
			_rack_point(Vector3(x, -1, 3), angle), _rack_point(Vector3(x, 5, 3), angle),
			_rack_point(Vector3(x, 5, 5), angle), _rack_point(Vector3(x, -1, 5), angle)
		], g.team_color)
	g.box(Vector3(-5, 12, 9), Vector3(5, 14, 10.5), g.team_color)

static func _rack_point(local: Vector3, angle: float) -> Vector3:
	return Vector3(local.x, local.y * cos(angle) - local.z * sin(angle), 27.0 + local.y * sin(angle) + local.z * cos(angle))

static func _fresh_release(state) -> bool:
	return state.action_released and state.release_elapsed >= 0.0 and state.release_elapsed < 0.10

static func _fire(g, state, muzzle: Vector3, size: float) -> void:
	if _fresh_release(state):
		_flash(g, muzzle, Vector3(0, -1, 0), size)

static func _flash(g, muzzle: Vector3, direction: Vector3, size: float) -> void:
	# Two crossing tongues make the instant of release legible from all facings.
	var start: Vector3 = muzzle + direction * 0.5
	var tip: Vector3 = start + direction * size * 2.1
	var orange := Color("f4ad48")
	var yellow := Color("ffefb0")
	g.face([start + Vector3(-size * 0.48, 0, 0), tip, start + Vector3(size * 0.48, 0, 0)], orange)
	g.face([start + Vector3(0, 0, -size * 0.42), tip, start + Vector3(0, 0, size * 0.42)], orange)
	g.face([start + Vector3(-size * 0.22, 0, 0), start + direction * size * 1.45, start + Vector3(size * 0.22, 0, 0)], yellow)

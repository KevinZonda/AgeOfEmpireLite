extends RefCounted

# Civic and food buildings keep an open working yard and local entrance steps.
# The bell and windmill sails are physical meshes in the shared face ordering.
static func populate(mesh, kind: String) -> void:
	if kind == "town_center": _town_center(mesh)
	elif kind == "mill": _mill(mesh)

static func _town_center(mesh) -> void:
	var timber: Color = mesh.palette["timber"]
	var stone: Color = mesh.palette["trim"]
	# A broad rear hall leaves the front courtyard open rather than adding a gate tower.
	mesh.hall(0.11, 0.09, 0.74, 0.34, 28, 15)
	mesh.cube(0.11, 0.43, 0.74, 0.023, 2, 3, stone.darkened(0.16))
	mesh.door(0.405, 0.438, 0.15, 21)
	mesh.cube(0.386, 0.47, 0.19, 0.10, 2, 2.2, stone)
	mesh.cube(0.365, 0.555, 0.23, 0.045, 2, 1.1, stone.darkened(0.09))
	mesh.cube(0.382, 0.47, 0.196, 0.02, 24, 2, mesh.accent)
	for u in [0.20, 0.66]: mesh.window(u, 0.457, 12, 8, 10)
	mesh.window(0.852, 0.16, 13, 8, 10, true)
	mesh.window(0.852, 0.31, 13, 7, 10, true)
	_facade(mesh, 0.11, 0.461, 0.74, 28)
	# Side store and shaded porch are lower than the civic hall and its bell frame.
	mesh.hall(0.71, 0.52, 0.17, 0.19, 15, 7)
	mesh.window(0.737, 0.737, 7, 7, 6)
	mesh.cube(0.11, 0.47, 0.10, 0.29, 2, 1.4, stone)
	for v in [0.49, 0.72]: mesh.cube(0.15, v, 0.026, 0.027, 3.4, 14, timber)
	mesh.face([mesh.p(0.105, 0.44, 22), mesh.p(0.232, 0.44, 22), mesh.p(0.232, 0.79, 18), mesh.p(0.105, 0.79, 18)], mesh.palette["roof_dark"])
	# Four short paving slabs mark the path without covering the entire yard.
	for v in [0.66, 0.74, 0.82, 0.90]: mesh.cube(0.45, v, 0.10, 0.057, 2.03, 0.20, stone.darkened(0.15))
	# Open freestanding beam: posts stay either side of the hanging bronze bell.
	for u in [0.245, 0.55]:
		mesh.cube(u - 0.013, 0.775, 0.065, 0.065, 2, 2, stone)
		mesh.cube(u, 0.793, 0.027, 0.029, 4, 24, timber)
	mesh.cube(0.23, 0.78, 0.37, 0.055, 28, 2.4, timber)
	mesh.beam(mesh.p(0.261, 0.835, 24), mesh.p(0.31, 0.835, 28), 1.8, timber)
	mesh.beam(mesh.p(0.50, 0.835, 28), mesh.p(0.565, 0.835, 24), 1.8, timber)
	_bell(mesh, mesh.p(0.414, 0.817, 26), 1.4)
	# An unobstructed team standard stands at the courtyard's outer edge.
	mesh.cube(0.87, 0.83, 0.055, 0.055, 2, 1.5, stone)
	mesh.cube(0.887, 0.848, 0.018, 0.018, 3.5, 29, timber)
	mesh.face([mesh.p(0.905, 0.868, 31), mesh.p(0.985, 0.868, 31), mesh.p(0.985, 0.868, 23), mesh.p(0.905, 0.868, 25)], mesh.accent)
	mesh._crate(0.73, 0.81, 0.08, 0.08, 2, 5)

static func _mill(mesh) -> void:
	var timber: Color = mesh.palette["timber"]
	var stone: Color = mesh.palette["trim"]
	mesh.hall(0.20, 0.10, 0.42, 0.48, 28, 15)
	mesh.cube(0.20, 0.58, 0.42, 0.025, 2, 3, stone.darkened(0.13))
	mesh.door(0.305, 0.59, 0.16, 15)
	mesh.cube(0.29, 0.632, 0.19, 0.07, 2, 1.4, stone)
	mesh.window(0.622, 0.25, 13, 6, 8, true)
	mesh.window(0.27, 0.613, 21, 5, 5)
	_facade(mesh, 0.20, 0.615, 0.42, 28)
	# The rotor lies in the facade's XZ plane and shares one centered drive axis.
	# Long canvas sails sit behind their lattice, with equal quarter-turn spacing.
	var forward := Vector3(0, 1, 0)
	var across := Vector3(1, 0, 0)
	var hub: Vector3 = mesh.p(0.41, 0.77, 31)
	_rod(mesh, hub - forward * 8.0, hub + forward * 1.4, 1.15, Color("665940"))
	for i in 4:
		var angle := PI * 0.25 + i * PI * 0.5
		var radial := across * cos(angle) + Vector3(0, 0, sin(angle))
		var lateral := -across * sin(angle) + Vector3(0, 0, cos(angle))
		# A slim central spar joins the hub to each full-length framed sail.
		_strut(mesh, hub + radial * 1.0 + forward * 0.30, hub + radial * 22.5 + forward * 0.30, 0.85, timber)
		var sail_back := hub - forward * 0.10
		var a := sail_back + radial * 5.8 - lateral * 1.75
		var b := sail_back + radial * 21.8 - lateral * 1.75
		var c := sail_back + radial * 21.8 + lateral * 1.75
		var d := sail_back + radial * 5.8 + lateral * 1.75
		mesh.face([a, b, c, d], Color("d3c6a0"))
		# Two continuous outer rails and six battens reveal the sail structure.
		for side in [-2.1, 2.1]:
			_strut(mesh, hub + radial * 5.3 + lateral * side + forward * 0.30, hub + radial * 22.4 + lateral * side + forward * 0.30, 0.58, timber)
		for along in [5.4, 8.8, 12.2, 15.6, 19.0, 22.3]:
			_strut(mesh, hub + radial * along - lateral * 2.1 + forward * 0.33, hub + radial * along + lateral * 2.1 + forward * 0.33, 0.55, timber)
	# Small round cap leaves the thin central cross and all four sail roots clear.
	_rod(mesh, hub + forward * 1.4, hub + forward * 2.0, 1.9, Color("ad9160"))
	# Grain loading yard: low hopper, exposed grain, sacks and a flour crate.
	mesh.cube(0.71, 0.22, 0.18, 0.20, 2, 6, timber)
	mesh.cube(0.73, 0.24, 0.14, 0.16, 8.04, 0.25, Color("bba468"))
	mesh.cube(0.71, 0.22, 0.018, 0.20, 8, 1.2, timber)
	mesh.cube(0.872, 0.22, 0.018, 0.20, 8, 1.2, timber)
	mesh.cube(0.71, 0.403, 0.18, 0.018, 8, 1.2, timber)
	mesh._sack(0.81, 0.58, 3.0, Color("cbb888"))
	mesh._sack(0.88, 0.72, 3.2, Color("bda675"))
	mesh._sack(0.76, 0.84, 2.7, Color("d4c091"))
	mesh._crate(0.15, 0.80, 0.13, 0.13, 2, 5)
	mesh.cube(0.225, 0.642, 0.35, 0.018, 19, 1.5, mesh.accent)

static func _facade(mesh, u: float, v: float, w: float, h: float) -> void:
	var timber: Color = mesh.palette["timber"]
	if mesh.civilization == "English":
		for x in [u + 0.015, u + w * 0.29, u + w * 0.70, u + w - 0.035]:
			mesh.cube(x, v, 0.021, 0.023, 2, h - 1, timber)
		mesh.cube(u, v, w, 0.021, 9, 1.2, timber)
		mesh.beam(mesh.p(u + 0.04, v + 0.025, h - 1), mesh.p(u + w * 0.22, v + 0.025, 18), 1.0, timber)
		mesh.beam(mesh.p(u + w * 0.78, v + 0.025, 18), mesh.p(u + w - 0.04, v + 0.025, h - 1), 1.0, timber)
	elif mesh.civilization == "French":
		var stone: Color = mesh.palette["trim"]
		for z in [5.0, 11.0, 17.0, 23.0]:
			for x in [u, u + w - 0.045]: mesh.cube(x, v, 0.045, 0.021, z, 2.4, stone)
		mesh.cube(u, v, w, 0.013, 8, 0.42, stone.darkened(0.13))
	else:
		for x in [u + 0.01, u + w - 0.04]: mesh.cube(x, v, 0.03, 0.03, 2, h - 1, timber)
		mesh.cube(u, v, w, 0.025, h - 2, 1.8, timber)

static func _bell(mesh, suspension: Vector3, bell_scale: float) -> void:
	var bronze := Color("a98748")
	# Enlarge below the same suspension point so the bell stays on its beam.
	var center := suspension - Vector3(0, 0, 9.0 * bell_scale)
	var levels := [Vector2(0, 4.0), Vector2(1.2, 4.1), Vector2(3.0, 3.05), Vector2(7.8, 2.2), Vector2(9.0, 1.2)]
	for layer in levels.size() - 1:
		for i in 8:
			var a := TAU * i / 8.0
			var b := TAU * (i + 1) / 8.0
			var low: Vector2 = levels[layer] * bell_scale
			var high: Vector2 = levels[layer + 1] * bell_scale
			mesh.face([center + Vector3(cos(a) * low.y, sin(a) * low.y, low.x), center + Vector3(cos(b) * low.y, sin(b) * low.y, low.x), center + Vector3(cos(b) * high.y, sin(b) * high.y, high.x), center + Vector3(cos(a) * high.y, sin(a) * high.y, high.x)], bronze.lightened(0.10) if i in [0, 1] else bronze.darkened(0.10 if i < 4 else 0.24))
	var opening: Array = []
	for i in 8:
		var angle := TAU * i / 8.0
		opening.append(center + Vector3(cos(angle) * 3.3, sin(angle) * 3.3, 0.06) * bell_scale)
	mesh.face(opening, Color("5b4b2e"))
	mesh.box(Vector2(center.x, center.y), Vector2.ONE * 0.7 * bell_scale, center.z - 2.8 * bell_scale, 4.0 * bell_scale, Color("5b4b2e"))
	mesh.box(Vector2(center.x, center.y), Vector2.ONE * 1.6 * bell_scale, center.z - 3 * bell_scale, 1.7 * bell_scale, bronze)
	mesh.box(Vector2(center.x, center.y), Vector2.ONE * 1.0, suspension.z, 2.5, mesh.palette["timber"])

static func _rod(mesh, a: Vector3, b: Vector3, radius: float, color: Color) -> void:
	var along := (b - a).normalized()
	var across := along.cross(Vector3(0, 0, 1)).normalized()
	var up := along.cross(across).normalized()
	var cap: Array = []
	for i in 8:
		var angle := TAU * i / 8.0
		var next := TAU * (i + 1) / 8.0
		var offset := (across * cos(angle) + up * sin(angle)) * radius
		var offset_next := (across * cos(next) + up * sin(next)) * radius
		mesh.face([a + offset, b + offset, b + offset_next, a + offset_next], color.darkened(0.06 * i))
		cap.append(b + offset)
	mesh.face(cap, color.lightened(0.14))

static func _strut(mesh, a: Vector3, b: Vector3, width: float, color: Color) -> void:
	var along := (b - a).normalized()
	var normal := Vector3(0, 1, 0) * width * 0.5
	var side := along.cross(normal).normalized() * width * 0.5
	mesh.face([a - normal + side, a + normal + side, b + normal + side, b - normal + side], color)
	mesh.face([a + normal - side, a + normal + side, b + normal + side, b + normal - side], color.darkened(0.18))
	mesh.face([a - normal - side, b - normal - side, b - normal + side, a - normal + side], color.darkened(0.12))
	mesh.face([b - normal - side, b + normal - side, b + normal + side, b - normal + side], color.lightened(0.1))

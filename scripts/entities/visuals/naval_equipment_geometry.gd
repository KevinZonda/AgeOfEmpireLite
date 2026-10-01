extends RefCounted

# Equipment shares the hull's local frame: -Y is the bow, water is z = 0,
# and the working deck is z = 5. All dimensions are scaled with the vessel.
const WOOD := Color("886342")
const DARK_WOOD := Color("4f3e2f")
const LIGHT_WOOD := Color("bd9360")
const ROPE := Color("d2bd91")
const LINEN := Color("ece3c8")
const SKIN := Color("d8ad85")
const IRON := Color("485454")
const CLOTH := Color("777f70")

static func build(g, state) -> void:
	var s: float = state.radius / 19.0
	match state.kind:
		"arrow_ship": _arrow_ship(g, state.player_color, s)
		"springald_ship": _springald_ship(g, state.player_color, s)
		"incendiary_ship": _incendiary_ship(g, state.player_color, s)
		"warship": _warship(g, state.player_color, s)
		"transport_ship": _transport_ship(g, state.player_color, s, mini(6, maxi(0, state.passenger_count)))

static func _crew(g, base: Vector3, team: Color, s: float, job: String = "sailor") -> void:
	# Ankles, hip, chest, neck and head overlap, keeping small figures connected.
	var hip := base + Vector3(0, 0, 3.0) * s
	var chest := base + Vector3(0, -0.2, 6.2) * s
	for side in [-1.0, 1.0]:
		g.beam(base + Vector3(side * 0.75, 0.15, 0.1) * s, hip + Vector3(side * 0.55, 0, 0) * s, 1.0 * s, DARK_WOOD)
	g.cylinder(hip, chest, 1.35 * s, team.darkened(0.18), 7)
	g.cylinder(chest - Vector3(0, 0, 0.2) * s, chest + Vector3(0, 0, 1.0) * s, 0.65 * s, SKIN, 6)
	var head := chest + Vector3(0, 0, 1.1) * s
	g.cylinder(head, head + Vector3(0, 0, 1.8) * s, 1.12 * s, SKIN, 8)
	if job == "archer":
		g.cylinder(head + Vector3(0, 0, 1.4) * s, head + Vector3(0, 0, 2.2) * s, 1.2 * s, CLOTH, 8)
	else:
		g.cylinder(head + Vector3(0, 0, 1.7) * s, head + Vector3(0, 0, 2.0) * s, 1.5 * s, LIGHT_WOOD, 8)
	var left := chest + Vector3(-1.1, 0, -0.7) * s
	var right := chest + Vector3(1.1, 0, -0.7) * s
	var grip := base + Vector3(-1.0, -2.1, 5.5) * s
	if job == "archer":
		grip = base + Vector3(-1.6, -2.8, 5.7) * s
		g.beam(left, grip, 0.85 * s, SKIN)
		g.beam(right, base + Vector3(0.6, -1.2, 5.6) * s, 0.85 * s, SKIN)
		var upper := grip + Vector3(0, 0.1, 2.7) * s
		var lower := grip + Vector3(0, 0.1, -2.5) * s
		var belly := grip + Vector3(0, -0.9, 0) * s
		g.beam(upper, belly, 0.55 * s, LIGHT_WOOD)
		g.beam(belly, lower, 0.55 * s, LIGHT_WOOD)
		var draw_point := base + Vector3(0.6, -1.2, 5.6) * s
		g.line(upper, draw_point, ROPE, 0.45 * s)
		g.line(draw_point, lower, ROPE, 0.45 * s)
		g.line(draw_point, grip + Vector3(0, -3.2, 0) * s, LIGHT_WOOD, 0.65 * s)
	else:
		g.beam(left, grip, 0.8 * s, SKIN)
		g.beam(right, grip + Vector3(1.5, 0, 0) * s, 0.8 * s, SKIN)
		if job == "pole":
			g.beam(grip + Vector3(0, 5.0, 1.0) * s, grip + Vector3(0, -7, -1.3) * s, 0.65 * s, DARK_WOOD)

static func _oars(g, s: float, half_beam: float, rows: Array) -> void:
	for side in [-1.0, 1.0]:
		for y in rows:
			var grip := Vector3(side * (half_beam - 2.2), y - 1.5, 6.0) * s
			var lock := Vector3(side * (half_beam + 0.3), y, 6.1) * s
			var end := Vector3(side * (half_beam + 9.5), y + 5.0, 0.4) * s
			g.beam(grip, end, 0.7 * s, LIGHT_WOOD)
			g.cylinder(lock - Vector3(0, 0, 0.55) * s, lock + Vector3(0, 0, 0.55) * s, 0.8 * s, DARK_WOOD, 6)
			var blade_start := lock.lerp(end, 0.68)
			var blade_side := Vector3(0.65, -1.0, 0) * s
			g.face([blade_start - blade_side, blade_start + blade_side, end + blade_side * 1.2, end - blade_side * 1.2], WOOD)

static func _stern_tiller(g, s: float) -> void:
	g.beam(Vector3(0, 23, 5.6) * s, Vector3(-3.4, 17, 6.7) * s, 0.8 * s, DARK_WOOD)
	g.beam(Vector3(0, 23, 0.4) * s, Vector3(0, 23, 5.7) * s, 0.9 * s, DARK_WOOD)

static func _arrow_ship(g, team: Color, s: float) -> void:
	_oars(g, s, 9.4, [-10.0, 1.0, 12.0])
	for y in [-7.0, 7.0]:
		g.beam(Vector3(-7.6, y, 5.4) * s, Vector3(7.6, y, 5.4) * s, 1.0 * s, LIGHT_WOOD)
	_crew(g, Vector3(-3.8, -13.0, 5) * s, team, s, "archer")
	_crew(g, Vector3(3.5, -1.0, 5) * s, team, s, "archer")
	_crew(g, Vector3(-3.7, 11.0, 5) * s, team, s, "archer")
	_crew(g, Vector3(2.9, 18.0, 5) * s, team.darkened(0.15), s * 0.92)
	_stern_tiller(g, s)
	# Spare arrows and a rolled blanket rest on the deck rather than float above it.
	g.cylinder(Vector3(5.4, 9, 6.1) * s, Vector3(5.4, 14, 6.1) * s, 1.0 * s, CLOTH, 7)
	for x in [4.5, 5.1, 5.7]:
		g.line(Vector3(x, 6, 5.5) * s, Vector3(x, 12, 5.5) * s, LIGHT_WOOD, 0.55 * s)

static func _springald_ship(g, team: Color, s: float) -> void:
	_oars(g, s, 11.0, [7.0, 17.0])
	# Four deck feet and a compact pivot carry the bow's mass visibly.
	for side in [-1.0, 1.0]:
		g.beam(Vector3(side * 4, -15, 5.1) * s, Vector3(side * 4, 1, 5.1) * s, 1.5 * s, DARK_WOOD)
		g.beam(Vector3(side * 4, -12, 5.5) * s, Vector3(0, -7, 9) * s, 1.3 * s, WOOD)
		g.beam(Vector3(side * 4, -1, 5.5) * s, Vector3(0, -7, 9) * s, 1.3 * s, WOOD)
	g.cylinder(Vector3(0, -7, 5.5) * s, Vector3(0, -7, 9.3) * s, 2.0 * s, WOOD, 8)
	g.beam(Vector3(0, 3.5, 9.3) * s, Vector3(0, -19, 9.3) * s, 1.8 * s, DARK_WOOD)
	g.beam(Vector3(0, 2.5, 10.2) * s, Vector3(0, -19, 10.2) * s, 0.65 * s, LIGHT_WOOD)
	for side in [-1.0, 1.0]:
		g.beam(Vector3(0, -11, 10.1) * s, Vector3(side * 5.8, -10, 10.1) * s, 1.05 * s, WOOD)
		g.beam(Vector3(side * 5.8, -10, 10.1) * s, Vector3(side * 9.0, -7.6, 10.1) * s, 0.85 * s, WOOD)
		g.line(Vector3(side * 9, -7.6, 10.2) * s, Vector3(0, 0.4, 10.2) * s, ROPE, 0.65 * s)
	g.line(Vector3(0, 1.5, 10.9) * s, Vector3(0, -21, 10.9) * s, LIGHT_WOOD, 0.85 * s)
	g.face([Vector3(0, -23, 10.9) * s, Vector3(-0.9, -19.8, 10.9) * s, Vector3(0.9, -19.8, 10.9) * s], IRON)
	g.beam(Vector3(-2.4, 2.7, 9.5) * s, Vector3(2.4, 2.7, 9.5) * s, 0.7 * s, IRON)
	g.line(Vector3(-2.3, 2.8, 9.5) * s, Vector3(-2.3, 4, 10.5) * s, IRON, 0.7 * s)
	_crew(g, Vector3(-4.5, 6.0, 5) * s, team, s)
	_crew(g, Vector3(4.1, 13.5, 5) * s, team.darkened(0.13), s, "pole")
	_crate(g, Vector3(-4, 16, 5) * s, Vector3(4, 4, 3), s)
	_stern_tiller(g, s)

static func _jar(g, base: Vector3, s: float, burning: bool) -> void:
	var clay := Color("aa714a")
	g.cylinder(base, base + Vector3(0, 0, 1.0) * s, 1.7 * s, clay, 8)
	g.cylinder(base + Vector3(0, 0, 1) * s, base + Vector3(0, 0, 3.4) * s, 2.1 * s, clay, 8)
	g.cylinder(base + Vector3(0, 0, 3.4) * s, base + Vector3(0, 0, 4.0) * s, 1.55 * s, clay.lightened(0.08), 8)
	g.cylinder(base + Vector3(0, 0, 4) * s, base + Vector3(0, 0, 4.7) * s, 0.95 * s, DARK_WOOD, 8)
	if burning:
		var root := base + Vector3(0, 0, 4.75) * s
		g.line(root, root + Vector3(0, 0, 0.7) * s, DARK_WOOD, 0.7 * s)
		# Two crossed flame planes stay legible from every heading, kept jar-sized.
		g.begin_surface_group(root + Vector3(0, 0, 1.6) * s)
		for axis in [Vector3.RIGHT, Vector3(0, 1, 0)]:
			g.face([root - axis * 1.05 * s, root + axis * 1.05 * s, root + Vector3(0.3, 0, 3.8) * s], Color("ef8838"))
			g.face([root - axis * 0.5 * s, root + axis * 0.5 * s, root + Vector3(0, 0, 2.4) * s], Color("ffd077"))
		g.end_surface_group()

static func _incendiary_ship(g, team: Color, s: float) -> void:
	_oars(g, s, 9.2, [8.0, 18.0])
	# Jar cradles and low retainers give the ammunition a secure deck footprint.
	for x in [-3.4, 3.4]:
		g.box(Vector3(x - 2.8, -16.5, 5) * s, Vector3(x + 2.8, -2, 5.6) * s, DARK_WOOD)
		for y in [-13.0, -5.6]:
			_jar(g, Vector3(x, y, 5.65) * s, s, y < -10)
		for side in [-1.0, 1.0]:
			g.beam(Vector3(x + side * 2.6, -16, 6.0) * s, Vector3(x + side * 2.6, -2.4, 6.0) * s, 0.65 * s, LIGHT_WOOD)
	_crew(g, Vector3(-3.0, 5.0, 5) * s, team, s, "pole")
	_crew(g, Vector3(3.4, 16.0, 5) * s, team.darkened(0.15), s)
	g.cylinder(Vector3(4.8, 4.5, 5.2) * s, Vector3(4.8, 4.5, 8.0) * s, 1.4 * s, LIGHT_WOOD, 8)
	_stern_tiller(g, s)

static func _warship(g, team: Color, s: float) -> void:
	_oars(g, s, 12, [-10.0, 1.0, 12.0])
	# Raised stern platform has visible posts, with open water-facing rails.
	for x in [-7.8, 7.8]:
		for y in [12.0, 22.0]:
			g.beam(Vector3(x, y, 5) * s, Vector3(x, y, 9) * s, 1.4 * s, DARK_WOOD)
	g.box(Vector3(-8.5, 11, 8.2) * s, Vector3(8.5, 23, 9.1) * s, LIGHT_WOOD)
	g.begin_surface_group(Vector3(0, 17, 9.15) * s)
	for y in [13.0, 16.0, 19.0, 22.0]:
		g.line(Vector3(-8.4, y, 9.2) * s, Vector3(8.4, y, 9.2) * s, WOOD, 0.6 * s)
	g.end_surface_group()
	for side in [-1.0, 1.0]:
		for y in [12.0, 17.0, 22.0]:
			g.beam(Vector3(side * 8.5, y, 9) * s, Vector3(side * 8.5, y, 12.1) * s, 0.6 * s, DARK_WOOD)
		g.beam(Vector3(side * 8.5, 11.5, 12) * s, Vector3(side * 8.5, 23, 12) * s, 0.7 * s, LIGHT_WOOD)
		for y in [-10.0, 0.0, 10.0]:
			_shield(g, Vector3(side * 11.6, y, 6.2) * s, team, s, side)
	_crew(g, Vector3(3.0, 18.0, 9.2) * s, team, s)
	_crew(g, Vector3(-4.4, -15.0, 5) * s, team, s, "archer")
	# Mast and a broad, panelled square sail. Linen occupies only the high rig;
	# clear deck remains beneath the boom and around the stern platform.
	var mast := Vector3(0, -2.5, 5) * s
	var top := Vector3(0, -2.5, 41) * s
	g.beam(mast, top, 1.6 * s, DARK_WOOD)
	g.beam(Vector3(-11.2, -3, 35.5) * s, Vector3(11.2, -3, 35.5) * s, 1.0 * s, LIGHT_WOOD)
	g.beam(Vector3(-9.3, -3, 19) * s, Vector3(9.3, -3, 19) * s, 0.7 * s, WOOD)
	var sail_top_left := Vector3(-10.5, -3.1, 35.1) * s
	var sail_top_right := Vector3(10.5, -3.1, 35.1) * s
	var sail_bottom_left := Vector3(-9, -3, 19.5) * s
	var sail_bottom_right := Vector3(9, -3, 19.5) * s
	var belly := Vector3(0, -6.0, 26.8) * s
	g.begin_surface_group(Vector3(0, -4.2, 27) * s)
	g.face([sail_top_left, sail_top_right, belly], LINEN)
	g.face([sail_top_left, belly, sail_bottom_left], Color("d5c9ad"))
	g.face([sail_top_right, sail_bottom_right, belly], Color("f2ead5"))
	g.face([sail_bottom_left, belly, sail_bottom_right], Color("e2d6b9"))
	for pair in [[sail_top_left, sail_top_right], [sail_top_left, sail_bottom_left], [sail_top_right, sail_bottom_right], [sail_bottom_left, sail_bottom_right]]:
		g.line(pair[0], pair[1], ROPE.darkened(0.13), 0.65 * s)
	for x in [-5.0, 5.0]:
		g.line(Vector3(x, -3.1, 35) * s, Vector3(x * 0.6, -5.2, 27) * s, Color("cabe9e"), 0.55 * s)
		g.line(Vector3(x * 0.6, -5.2, 27) * s, Vector3(x * 0.85, -3, 19.6) * s, Color("cabe9e"), 0.55 * s)
	# Small team crest follows the central sail belly, rather than painting it all.
	g.face([Vector3(0, -6.06, 30.2) * s, Vector3(2.0, -5.55, 27) * s, Vector3(0, -6.06, 23.6) * s, Vector3(-2.0, -5.55, 27) * s], team.darkened(0.12))
	g.end_surface_group()
	for anchor in [Vector3(0, -27, 6), Vector3(-10, 15, 7), Vector3(10, 15, 7)]:
		g.line(top, anchor * s, ROPE, 0.6 * s)
	for side in [-1.0, 1.0]:
		g.line(Vector3(side * 10.5, -3, 35.5) * s, Vector3(side * 8, 11, 9.5) * s, ROPE, 0.55 * s)
	g.face([top + Vector3(0, 0, 0.5) * s, top + Vector3(0, 6, -1) * s, top + Vector3(0, 0, -2.6) * s], team)
	_stern_tiller(g, s)

static func _shield(g, center: Vector3, team: Color, s: float, side: float) -> void:
	# Shields sit flush against the outer rail in the YZ plane.
	var rim: Array[Vector3] = []
	for i in 10:
		var angle: float = TAU * i / 10.0
		rim.append(center + Vector3(0, cos(angle) * 2.3, sin(angle) * 2.3) * s)
	g.begin_surface_group(center)
	g.face(rim, WOOD)
	var inset: Array[Vector3] = []
	for point in rim: inset.append(center + (point - center) * 0.78 + Vector3(side * 0.05, 0, 0) * s)
	g.face(inset, team.darkened(0.18))
	g.line(center + Vector3(side * 0.08, -1.5, 0) * s, center + Vector3(side * 0.08, 1.5, 0) * s, LIGHT_WOOD, 0.6 * s)
	g.end_surface_group()

static func _crate(g, base: Vector3, size: Vector3, s: float) -> void:
	g.box(base, base + size * s, WOOD)
	# Face decorations use separate supporting groups so the far side stays hidden.
	for side in [0.0, size.x]:
		var center := base + Vector3(side, size.y * 0.5, size.z * 0.5) * s
		g.begin_surface_group(center)
		g.line(base + Vector3(side, 0.1, 0.3) * s, base + Vector3(side, size.y - 0.1, size.z - 0.3) * s, LIGHT_WOOD, 0.7 * s)
		g.line(base + Vector3(side, size.y - 0.1, 0.3) * s, base + Vector3(side, 0.1, size.z - 0.3) * s, LIGHT_WOOD, 0.7 * s)
		g.end_surface_group()
	g.begin_surface_group(base + Vector3(size.x * 0.5, size.y * 0.5, size.z + 0.02) * s)
	for fraction in [0.25, 0.75]:
		g.line(base + Vector3(size.x * fraction, 0, size.z + 0.05) * s, base + Vector3(size.x * fraction, size.y, size.z + 0.05) * s, LIGHT_WOOD, 0.65 * s)
	g.end_surface_group()

static func _transport_ship(g, team: Color, s: float, passengers: int) -> void:
	# The low coaming outlines an open well. It does not cover the working deck.
	for side in [-1.0, 1.0]:
		g.box(Vector3(side * 6.2 - 0.45, -13, 5) * s, Vector3(side * 6.2 + 0.45, 13.5, 6.5) * s, DARK_WOOD)
	for y in [-13.0, 13.0]:
		g.beam(Vector3(-6.5, y, 6) * s, Vector3(6.5, y, 6) * s, 1.0 * s, LIGHT_WOOD)
	for y in [-7.5, 1.0, 9.5]:
		g.beam(Vector3(-5.9, y, 6.4) * s, Vector3(5.9, y, 6.4) * s, 1.7 * s, LIGHT_WOOD)
	_crate(g, Vector3(-5.5, -21, 5) * s, Vector3(5, 5.5, 4), s)
	_crate(g, Vector3(1, -19, 5) * s, Vector3(4.5, 4, 3), s)
	g.cylinder(Vector3(-3.3, 18.5, 5.0) * s, Vector3(-3.3, 18.5, 9.4) * s, 2.0 * s, WOOD, 9)
	for z in [5.6, 8.6]:
		g.cylinder(Vector3(-3.3, 18.5, z) * s, Vector3(-3.3, 18.5, z + 0.35) * s, 2.07 * s, IRON, 9)
	# A narrow boarding gangplank is stowed lengthwise along the starboard rail.
	g.box(Vector3(8, -10, 5.3) * s, Vector3(10.5, 13, 6.0) * s, LIGHT_WOOD)
	g.begin_surface_group(Vector3(9.25, 1.5, 6.05) * s)
	for y in [-8.0, -4.0, 0.0, 4.0, 8.0, 12.0]:
		g.line(Vector3(8.1, y, 6.05) * s, Vector3(10.4, y, 6.05) * s, WOOD, 0.7 * s)
	for y in [-6.0, 9.0]:
		g.line(Vector3(8, y, 6.2) * s, Vector3(10.5, y, 6.2) * s, ROPE, 0.9 * s)
	g.end_surface_group()
	for i in passengers:
		var row: int = i / 2
		var side: float = -1.0 if i % 2 == 0 else 1.0
		_seated_passenger(g, Vector3(side * 3.3, -7.5 + row * 8.5, 6.7) * s, team, s)
	_crew(g, Vector3(3.4, 19.0, 5) * s, team.darkened(0.12), s)
	g.beam(Vector3(-8.5, 15, 5.5) * s, Vector3(-8.5, 15, 15) * s, 0.8 * s, DARK_WOOD)
	g.face([Vector3(-8.5, 15, 15) * s, Vector3(-8.5, 20, 13.8) * s, Vector3(-8.5, 15, 12.4) * s], team)
	_stern_tiller(g, s)

static func _seated_passenger(g, seat: Vector3, team: Color, s: float) -> void:
	var chest := seat + Vector3(0, 0, 3.0) * s
	g.cylinder(seat, chest, 1.25 * s, team.darkened(0.18), 7)
	g.cylinder(chest - Vector3(0, 0, 0.15) * s, chest + Vector3(0, 0, 0.8) * s, 0.6 * s, SKIN, 6)
	g.cylinder(chest + Vector3(0, 0, 0.6) * s, chest + Vector3(0, 0, 2.3) * s, 1.05 * s, SKIN, 8)
	g.cylinder(chest + Vector3(0, 0, 2.0) * s, chest + Vector3(0, 0, 2.6) * s, 1.12 * s, CLOTH, 8)
	for side in [-1.0, 1.0]:
		var knee := seat + Vector3(side * 0.7, -1.7, -0.2) * s
		g.beam(seat + Vector3(side * 0.65, 0, 0) * s, knee, 0.9 * s, DARK_WOOD)
		g.beam(knee, knee + Vector3(0, 0.3, -1.3) * s, 0.9 * s, DARK_WOOD)
		g.beam(chest + Vector3(side * 1.0, 0, -0.6) * s, knee + Vector3(0, 0, 1.1) * s, 0.75 * s, SKIN)

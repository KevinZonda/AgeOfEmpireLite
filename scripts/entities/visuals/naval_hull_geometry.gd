extends RefCounted

# Shared ship shell. Local -Y is the bow, +Y the stern, and z = 0 is water.
# The exposed deck is always z = 5 at the reference radius of 19.
const WOOD := Color("916343")
const WOOD_DARK := Color("513b2c")
const WOOD_LIGHT := Color("c59b69")
const DECK := Color("cfaa79")
const SEAM := Color("a88358")

static func outline(kind: String, inset: float = 1.0, scale: float = 1.0) -> Array[Vector3]:
	var bow := -30.0
	var stern := 27.0
	var beam := 11.8
	var shoulder := -18.0
	match kind:
		"warship":
			bow = -33.0
			stern = 29.0
			beam = 12.8
			shoulder = -20.0
		"transport_ship":
			bow = -29.0
			stern = 28.0
			beam = 13.0
			shoulder = -18.0
		"arrow_ship":
			bow = -33.0
			stern = 27.0
			beam = 10.0
			shoulder = -20.0
		"incendiary_ship":
			bow = -31.0
			stern = 26.0
			beam = 9.8
			shoulder = -19.0
	var points: Array[Vector3] = []
	# A fine stem, curved shoulders, and broad transom distinguish real hulls
	# from a rectangle extruded above the water. Winding faces upward.
	for point in [Vector3(0, bow, 0), Vector3(beam * 0.65, shoulder, 0), Vector3(beam, -7, 0), Vector3(beam * 0.97, 12, 0), Vector3(beam * 0.78, stern - 5, 0), Vector3(beam * 0.56, stern, 0), Vector3(-beam * 0.56, stern, 0), Vector3(-beam * 0.78, stern - 5, 0), Vector3(-beam * 0.97, 12, 0), Vector3(-beam, -7, 0), Vector3(-beam * 0.65, shoulder, 0)]:
		points.append(point * inset * scale)
	return points

static func build(g, state) -> void:
	var s: float = state.radius / 19.0
	var kind: String = state.kind
	var rim := outline(kind, 1.0, s)
	var inside := outline(kind, 0.88, s)
	var deck := outline(kind, 0.88, s)
	var chine := outline(kind, 0.85, s)
	var side_height := 6.3 if kind == "incendiary_ship" else 7.0
	for i in rim.size():
		var height := _rim_height(i, side_height) * s
		rim[i].z = height
		inside[i].z = height
		deck[i].z = 5.0 * s
		chine[i].z = 0.3 * s
	for i in rim.size():
		var j := (i + 1) % rim.size()
		# Each broadside has a shallow outward flare and visible plank strakes.
		# Paint and seams share their supporting panel's painter depth.
		var center: Vector3 = (chine[i] + chine[j] + rim[j] + rim[i]) / 4.0
		g.begin_surface_group(center)
		g.face([chine[i], chine[j], rim[j], rim[i]], WOOD, true)
		if _visible_side(g, chine[i], chine[j], rim[j]):
			g.line(chine[i].lerp(rim[i], 0.34), chine[j].lerp(rim[j], 0.34), WOOD_DARK.lightened(0.10), 0.65 * s)
			g.line(chine[i].lerp(rim[i], 0.68), chine[j].lerp(rim[j], 0.68), WOOD_LIGHT.darkened(0.12), 0.65 * s)
			# Restrained livery retains a wooden hull rather than a solid team block.
			if i in [1, 2, 3, 7, 8, 9]:
				g.line(chine[i].lerp(rim[i], 0.78), chine[j].lerp(rim[j], 0.78), state.player_color.darkened(0.18), 1.4 * s)
		g.end_surface_group()
	_build_deck(g, deck, s)
	for i in rim.size():
		var j := (i + 1) % rim.size()
		# Inner bulwarks face the deck; an actual top plank bridges both walls.
		g.face([deck[j], deck[i], inside[i], inside[j]], WOOD_DARK, true)
		g.begin_surface_group((rim[i] + rim[j] + inside[i] + inside[j]) / 4.0)
		g.face([inside[i], rim[i], rim[j], inside[j]], WOOD_LIGHT, true)
		g.line(rim[i], rim[j], WOOD_DARK, 0.85 * s)
		g.line(inside[i], inside[j], WOOD_LIGHT.lightened(0.14), 0.65 * s)
		g.end_surface_group()
	# The stem follows the upturned bow, but the keel remains in the water.
	g.beam(chine[0], rim[0] + Vector3(0, 0, 0.35 * s), 1.0 * s, WOOD_DARK)
	var stern_y: float = rim[5].y
	g.box(Vector3(-0.7 * s, stern_y - 1.0 * s, 0.1 * s), Vector3(0.7 * s, stern_y + 4.5 * s, 2.6 * s), WOOD_DARK)
	g.beam(Vector3(0, stern_y, 2.3 * s), Vector3(0, stern_y - 1.0 * s, 6.8 * s), 0.85 * s, WOOD_DARK)
	g.beam(Vector3(0, stern_y - 1.0 * s, 6.8 * s), Vector3(-3.0 * s, stern_y - 6.0 * s, 6.8 * s), 0.8 * s, WOOD_LIGHT)

# Small deck tiles sort beneath the equipment at the same local position.
# Breaks include every hull corner, preserving the exact inset silhouette.
static func _build_deck(g, deck: Array[Vector3], s: float) -> void:
	var levels: Array[float] = []
	for point in deck:
		if not levels.has(point.y): levels.append(point.y)
	var bow: float = deck[0].y
	var stern: float = deck[5].y
	var y := -28.0 * s
	while y < stern:
		if y > bow and not levels.has(y): levels.append(y)
		y += 2.5 * s
	levels.sort()
	for band in levels.size() - 1:
		var y_a := levels[band]
		var y_b := levels[band + 1]
		var width_a := _width_at(deck, y_a)
		var width_b := _width_at(deck, y_b)
		var seam := absf(fposmod(y_b / s + 23.0, 5.0)) < 0.01
		for tile in 6:
			var left := -1.0 + tile / 3.0
			var right := -1.0 + (tile + 1) / 3.0
			var a := Vector3(width_a * left, y_a, 5.0 * s)
			var b := Vector3(width_a * right, y_a, 5.0 * s)
			var c := Vector3(width_b * right, y_b, 5.0 * s)
			var d := Vector3(width_b * left, y_b, 5.0 * s)
			g.begin_surface_group((a + b + c + d) / 4.0)
			if width_a < 0.001:
				g.face([a, c, d], DECK)
			else:
				g.face([a, b, c, d], DECK)
			if seam:
				var seam_left := maxf(d.x, -width_b + 0.35 * s)
				var seam_right := minf(c.x, width_b - 0.35 * s)
				if seam_right > seam_left:
					g.line(Vector3(seam_left, y_b, 5.03 * s), Vector3(seam_right, y_b, 5.03 * s), SEAM, 0.6 * s)
			# Join segments stay inside a single tile and inside the hull edge.
			var joint_x := (-2.6 if floori((y_a / s + 23.0) / 5.0) % 2 == 0 else 2.6) * s
			var safe_width := minf(width_a, width_b) - 0.35 * s
			if absf(joint_x) < safe_width and joint_x > maxf(a.x, d.x) and joint_x <= minf(b.x, c.x):
				g.line(Vector3(joint_x, y_a, 5.03 * s), Vector3(joint_x, y_b, 5.03 * s), SEAM, 0.5 * s)
			g.end_surface_group()

static func _rim_height(index: int, side_height: float) -> float:
	if index == 0: return 9.0
	if index in [1, 10]: return maxf(7.8, side_height)
	return side_height

static func _visible_side(g, a: Vector3, b: Vector3, c: Vector3) -> bool:
	var normal: Vector3 = g.world((b - a).cross(c - a).normalized())
	return normal.y * g.height_scale() + normal.z * g.ground_scale() > 0.001

static func _width_at(points: Array[Vector3], y: float) -> float:
	var result := 0.0
	for i in points.size():
		var j := (i + 1) % points.size()
		var a := points[i]
		var b := points[j]
		if absf(a.y - b.y) < 0.001: continue
		if y < minf(a.y, b.y) or y > maxf(a.y, b.y): continue
		result = maxf(result, absf(lerpf(a.x, b.x, (y - a.y) / (b.y - a.y))))
	return result

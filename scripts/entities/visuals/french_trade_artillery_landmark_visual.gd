extends "res://scripts/entities/visuals/western_landmark_details.gd"

# Merchant loggia and ordnance academy retain open, usable ground courts.
static func handles(id: String) -> bool:
	return id in ["fr_chamber_of_commerce", "fr_college_of_artillery"]

static func layout(id: String) -> Array:
	if id == "fr_chamber_of_commerce":
		return [[0.50, 0.25, 0.76, 0.28, 29, "hip"], [0.50, 0.25, 0.13, 0.13, 44, "spire"], [0.50, 0.465, 0.78, 0.15, 17, "hip"], [0.235, 0.705, 0.27, 0.20, 13, "awning"], [0.765, 0.705, 0.27, 0.20, 13, "awning"]]
	return [[0.50, 0.235, 0.76, 0.25, 28, "hip"], [0.18, 0.53, 0.20, 0.40, 19, "gable"], [0.825, 0.455, 0.17, 0.23, 22, "hip"], [0.15, 0.39, 0.065, 0.065, 39, "chimney"], [0.84, 0.37, 0.065, 0.065, 38, "chimney"]]

static func populate(g, id: String, player: Color) -> bool:
	if not handles(id): return false
	g.palette = g.palette.duplicate()
	g.palette["wall"] = Color("cfc3a7")
	g.palette["trim"] = Color("e0d4b7")
	g.palette["roof"] = Color("556e80")
	g.palette["roof_dark"] = Color("354958")
	if id == "fr_chamber_of_commerce":
		_merchant_hall(g, player)
	else:
		_artillery_academy(g, player)
	return true

static func _merchant_hall(g, player: Color) -> void:
	_hall(g, layout("fr_chamber_of_commerce")[0], player)
	# The cupola is mounted into the roof rather than a tower through the court.
	var cupola := _p(g, 0.50, 0.25, 35)
	g.box(Vector2(cupola.x, cupola.y), g.dimensions * 0.115, cupola.z, 9, g.palette["wall"])
	_arch(g, 0.50, 0.309, 37, 2.3, 5.8, false)
	_roof(g, 0.50, 0.25, 0.145, 0.145, 44, "spire", g.palette["roof"], 11)
	var finial := _p(g, 0.50, 0.25, 54)
	g.box(Vector2(finial.x, finial.y), Vector2.ONE * 0.8, finial.z, 4, Color("baa46c"))
	_banner(g, 0.64, 0.391, 26, player)
	# Four real open bays: separate piers and curved spandrels, no solid wall.
	for u in [0.11, 0.305, 0.50, 0.695, 0.89]: _column(g, u, 0.535, 17)
	for u in [0.2075, 0.4025, 0.5975, 0.7925]:
		_open_arcade(g, u, 0.536, 0.195 * g.dimensions.x * 0.5 - 1.1, 17)
	_roof(g, 0.50, 0.465, 0.81, 0.165, 17, "hip", g.palette["roof"], 6)
	for u in [0.235, 0.765]: _striped_stall(g, u, 0.705, player)
	_crate(g, 0.16, 0.86, 5.2, 4.7, 4.5)
	_crate(g, 0.225, 0.88, 4.3, 4.0, 3.2)
	_barrel(g, 0.83, 0.86)
	_sack(g, 0.76, 0.86)
	_sack(g, 0.72, 0.89)
	# Stock in the loggia is visible through its open bays.
	_crate(g, 0.20, 0.475, 5, 4, 4)
	_barrel(g, 0.78, 0.475)

static func _open_arcade(g, u: float, v: float, radius: float, top: float) -> void:
	var hub := _p(g, u, v, 0)
	# Small independent wedges preserve a truly empty arch opening.
	for i in 8:
		var left := -radius + radius * 2.0 * i / 8.0
		var right := -radius + radius * 2.0 * (i + 1) / 8.0
		var za := top - radius - 1.0 + sqrt(maxf(0.0, radius * radius - left * left))
		var zb := top - radius - 1.0 + sqrt(maxf(0.0, radius * radius - right * right))
		g.face([hub + Vector3(left, 0, za), hub + Vector3(right, 0, zb), hub + Vector3(right, 0, top), hub + Vector3(left, 0, top)], g.palette["trim"].darkened(0.06 if i % 2 == 0 else 0.12))

static func _striped_stall(g, u: float, v: float, player: Color) -> void:
	var wood := Color("806447")
	for x in [-0.13, 0.13]:
		for y in [-0.095, 0.095]:
			var post := _p(g, u + x, v + y, 0)
			g.box(Vector2(post.x, post.y), Vector2.ONE * 1.0, g.base_z, 13.5 if y < 0 else 10.5, wood)
	# Cream / blue canvas stripes share the sloping plane and have a valance.
	for i in 7:
		var x0 := u - 0.145 + 0.29 * i / 7.0
		var x1 := u - 0.145 + 0.29 * (i + 1) / 7.0
		var color := Color("e4d9b9") if i % 2 == 0 else player.lightened(0.06)
		var a := _p(g, x0, v - 0.11, 14)
		var b := _p(g, x1, v - 0.11, 14)
		var c := _p(g, x1, v + 0.115, 11)
		var d := _p(g, x0, v + 0.115, 11)
		g.face([a, b, c, d], color)
		g.face([d, c, c + Vector3(0, 0, -2), d + Vector3(0, 0, -2)], color.darkened(0.08))
	var counter := _p(g, u, v + 0.08, 0)
	g.box(Vector2(counter.x, counter.y), g.dimensions * Vector2(0.255, 0.045), g.base_z, 5, wood)
	g.box(Vector2(counter.x, counter.y), g.dimensions * Vector2(0.27, 0.06), g.base_z + 5, 0.8, Color("b09162"))
	for dx in [-0.075, 0.075]:
		var goods := _p(g, u + dx, v + 0.08, 5.8)
		g.box(Vector2(goods.x, goods.y), Vector2(3.7, 3.3), goods.z, 1.6, Color("bbae71") if dx < 0 else Color("9b6c4b"))

static func _crate(g, u: float, v: float, w: float, d: float, h: float) -> void:
	var at := _p(g, u, v, 0)
	g.box(Vector2(at.x, at.y), Vector2(w, d), at.z, h, Color("987447"))
	for x in [-0.32, 0.32]:
		_ribbon(g, at + Vector3(w * x, d * 0.5 + 0.025, 0.3), at + Vector3(w * x, d * 0.5 + 0.025, h - 0.2), 0.55, Color("5c4b35"))
	_ribbon(g, at + Vector3(-w * 0.42, d * 0.5 + 0.04, 0.6), at + Vector3(w * 0.42, d * 0.5 + 0.04, h - 0.6), 0.6, Color("bf9c66"))

static func _barrel(g, u: float, v: float) -> void:
	var at := _p(g, u, v, 0)
	_cylinder(g, at, at + Vector3(0, 0, 5.5), 2.25, Color("967247"), 8)
	for z in [1.0, 4.4]: _cylinder(g, at + Vector3(0, 0, z), at + Vector3(0, 0, z + 0.55), 2.34, Color("5c6155"), 8)

static func _sack(g, u: float, v: float) -> void:
	var at := _p(g, u, v, 0)
	_cylinder(g, at, at + Vector3(0, 0, 3.4), 2.0, Color("c1ad78"), 6)
	_cylinder(g, at + Vector3(0, 0, 3.4), at + Vector3(0, 0, 4.5), 0.65, Color("9a875b"), 6)

static func _artillery_academy(g, player: Color) -> void:
	var forms := layout("fr_college_of_artillery")
	for i in 3: _hall(g, forms[i], player)
	# Academy entrance and workshop shutters look onto the display court.
	_arch(g, 0.50, 0.363, 0, 5.0, 16, false)
	_steps(g, 0.50, 0.40, 0.22)
	_banner(g, 0.63, 0.363, 25, player)
	for v in [0.44, 0.60]: _arch(g, 0.282, v, 1, 4.5, 11, true)
	for row in [[0.15, 0.39, 20.0, 39.0], [0.84, 0.37, 24.0, 38.0]]:
		var at := _p(g, row[0], row[1], row[2])
		g.box(Vector2(at.x, at.y), g.dimensions * 0.055, at.z, row[3] - row[2], Color("ada48c"))
		g.box(Vector2(at.x, at.y), g.dimensions * 0.075, g.base_z + row[3], 1.7, g.palette["trim"])
		g.box(Vector2(at.x, at.y), g.dimensions * 0.038, g.base_z + row[3] + 1.71, 0.15, Color("42443c"))
	_court_cannon(g, 0.415, 0.675)
	_court_cannon(g, 0.685, 0.720)
	# Readable low arsenal: cannonballs, ramrod rack and powder barrel.
	for offset in [Vector2(-1.7, 0.8), Vector2(1.7, 0.8), Vector2(0, -1.9)]:
		var at: Vector3 = _p(g, 0.84, 0.845, 1.4) + Vector3(offset.x, offset.y, 0)
		_ball(g, at, 1.65)
	_ball(g, _p(g, 0.84, 0.845, 3.7), 1.6)
	_barrel(g, 0.16, 0.82)
	var table := _p(g, 0.235, 0.825, 0)
	g.box(Vector2(table.x, table.y), Vector2(4, 9), table.z, 4, Color("795e40"))
	for dx in [-1.0, 1.0]:
		_cylinder(g, table + Vector3(dx, -6, 5), table + Vector3(dx, 6, 5), 0.40, Color("beac7f"), 6)

static func _court_cannon(g, u: float, v: float) -> void:
	var at := _p(g, u, v, 0)
	# Wooden cheeks and long trail sit below the bronze ordnance.
	g.box(Vector2(at.x, at.y - 3), Vector2(3.4, 13), at.z + 1.2, 2, Color("87613d"))
	for x in [-2.4, 2.4]:
		g.box(Vector2(at.x + x, at.y), Vector2(1.4, 7.5), at.z + 2, 4, Color("9a7047"))
	_cylinder(g, at + Vector3(-5.8, 0, 4.1), at + Vector3(5.8, 0, 4.1), 0.65, Color("4d4f43"), 8)
	for x in [-4.8, 4.8]: _cannon_wheel(g, at + Vector3(x, 0, 4.2))
	var breech := at + Vector3(0, -4.5, 6.5)
	var muzzle := at + Vector3(0, 12, 9.0)
	_cylinder(g, breech, muzzle, 2.1, Color("aa9054"), 10)
	var axis := (muzzle - breech).normalized()
	for t in [0.13, 0.57, 0.94]:
		var ring := breech.lerp(muzzle, t)
		_cylinder(g, ring - axis * 0.45, ring + axis * 0.45, 2.4 if t < 0.9 else 2.55, Color("b8a062"), 10)
	_disc_axis(g, muzzle + axis * 0.10, axis, 2.12, Color("725e35"), 10)
	_disc_axis(g, muzzle + axis * 0.13, axis, 1.38, Color("252c29"), 10)
	_cylinder(g, breech - axis * 1.8, breech - axis * 0.2, 0.85, Color("ae9251"), 8)

static func _cannon_wheel(g, hub: Vector3) -> void:
	_cylinder(g, hub - Vector3(0.7, 0, 0), hub + Vector3(0.7, 0, 0), 4.1, Color("464b42"), 10)
	var front := hub + Vector3(0.73, 0, 0)
	_disc_axis(g, front, Vector3.RIGHT, 3.45, Color("a58452"), 10)
	_disc_axis(g, front + Vector3(0.015, 0, 0), Vector3.RIGHT, 2.9, Color("665d44"), 10)
	for i in 6:
		var a := i * TAU / 6.0
		var radial := Vector3(0, cos(a), sin(a)) * 3.3
		var side := Vector3(0, -sin(a), cos(a)) * 0.33
		var p := front + Vector3(0.035, 0, 0)
		g.face([p - side, p + radial - side, p + radial + side, p + side], Color("bd9a60"))
	_cylinder(g, front, front + Vector3(0.65, 0, 0), 1.05, Color("555848"), 8)

static func _ball(g, hub: Vector3, radius: float) -> void:
	# Octahedral round shot shades as a small metal sphere at game scale.
	var ring: Array = []
	for i in 8: ring.append(hub + Vector3(cos(i * TAU / 8), sin(i * TAU / 8), 0) * radius)
	for i in 8:
		g.face([ring[i], ring[(i + 1) % 8], hub + Vector3(0, 0, radius)], Color("5a625b").lightened(0.10 if i > 3 else 0.0))
		g.face([ring[(i + 1) % 8], ring[i], hub - Vector3(0, 0, radius)], Color("353e39"))

static func _disc_axis(g, hub: Vector3, axis: Vector3, radius: float, color: Color, segments: int) -> void:
	var side := axis.cross(Vector3(0, 0, 1)).normalized()
	if side.is_zero_approx(): side = Vector3.RIGHT
	var up := axis.cross(side).normalized()
	var points: Array = []
	for i in segments:
		var a := TAU * i / segments
		points.append(hub + (side * cos(a) + up * sin(a)) * radius)
	g.face(points, color)

static func _cylinder(g, a: Vector3, b: Vector3, radius: float, color: Color, segments: int) -> void:
	var axis := (b - a).normalized()
	var side := axis.cross(Vector3(0, 0, 1)).normalized()
	if side.is_zero_approx(): side = Vector3.RIGHT
	var up := axis.cross(side).normalized()
	_disc_axis(g, a, axis, radius, color.darkened(0.2), segments)
	_disc_axis(g, b, axis, radius, color.lightened(0.13), segments)
	for i in segments:
		var first := TAU * i / segments
		var last := TAU * (i + 1) / segments
		var p := (side * cos(first) + up * sin(first)) * radius
		var q := (side * cos(last) + up * sin(last)) * radius
		g.face([a + p, a + q, b + q, b + p], color.lightened(0.1 * sin(first) - 0.10 * cos(first)))

static func draw_topdown(c: CanvasItem, bounds: Rect2, id: String, palette: Dictionary, player: Color) -> bool:
	if not handles(id): return false
	var french := palette.duplicate()
	french["wall"] = Color("cfc3a7")
	french["trim"] = Color("e0d4b7")
	draw_layout_topdown(c, bounds, layout(id), id, french, player)
	if id == "fr_chamber_of_commerce":
		for u in [0.235, 0.765]:
			for i in 7:
				var box := Rect2(bounds.position + bounds.size * Vector2(u - 0.145 + 0.29 * i / 7.0, 0.595), bounds.size * Vector2(0.29 / 7.0, 0.225))
				c.draw_rect(box, Color("e4d9b9") if i % 2 == 0 else player.lightened(0.06))
			c.draw_line(bounds.position + bounds.size * Vector2(u - 0.14, 0.82), bounds.position + bounds.size * Vector2(u + 0.14, 0.82), Color("795d3d"), 1.5)
		for u in [0.16, 0.225]:
			var at := bounds.position + bounds.size * Vector2(u, 0.875)
			c.draw_rect(Rect2(at - Vector2(2.5, 2), Vector2(5, 4)), Color("9c7848"))
			c.draw_line(at - Vector2(2, 1.5), at + Vector2(2, 1.5), Color("c4a16c"), 0.7)
		for uv in [Vector2(0.83, 0.86), Vector2(0.76, 0.86), Vector2(0.72, 0.89)]:
			c.draw_circle(bounds.position + bounds.size * uv, 2.2, Color("b49b69"))
	else:
		for uv in [Vector2(0.415, 0.675), Vector2(0.685, 0.720)]:
			var at: Vector2 = bounds.position + bounds.size * uv
			var scale := bounds.size / Vector2(92, 92)
			c.draw_rect(Rect2(at + Vector2(-2, -9) * scale, Vector2(4, 13) * scale), Color("997145"))
			for x in [-4.8, 4.8]:
				c.draw_rect(Rect2(at + Vector2(x - 0.9, -4) * scale, Vector2(1.8, 8) * scale), Color("444d44"))
			c.draw_line(at + Vector2(0, -4.5) * scale, at + Vector2(0, 12) * scale, Color("ab9256"), 4.2 * scale.x)
			for y in [-2.3, 5, 11]: c.draw_line(at + Vector2(-2.6, y) * scale, at + Vector2(2.6, y) * scale, Color("c2ab6d"), 1.0)
			c.draw_line(at + Vector2(-1.5, 12.2) * scale, at + Vector2(1.5, 12.2) * scale, Color("303b34"), 1.2)
		for dx in [-1.7, 1.7]: c.draw_circle(bounds.position + bounds.size * Vector2(0.84, 0.845) + Vector2(dx, 1), 1.6, Color("424e45"))
		c.draw_circle(bounds.position + bounds.size * Vector2(0.84, 0.845) - Vector2(0, 1.5), 1.6, Color("616b61"))
		c.draw_circle(bounds.position + bounds.size * Vector2(0.16, 0.82), 2.25, Color("9b7a4c"))
		c.draw_rect(Rect2(bounds.position + bounds.size * Vector2(0.235, 0.825) - Vector2(2, 4.5), Vector2(4, 9)), Color("795e40"))
	return true

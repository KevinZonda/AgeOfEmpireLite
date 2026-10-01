extends "res://scripts/entities/visuals/landmark_visual.gd"

# The quay is three separate solids. The open berth between the fingers has
# no deck face, so the actual water stays visible under the crane and ropes.
var portrait_faces: Array[Dictionary] = []
var portrait_bounds := Rect2()
var flat_faces: Array[Dictionary] = []
var civilization := "English"
var accent := Color.WHITE

func _init(size: Vector2, colors: Dictionary, civ: String, player: Color) -> void:
	set_world_dimensions(size)
	palette = colors.duplicate()
	civilization = civ
	accent = player
	base_z = 0.0
	palette["roof"] = Color("58666b") if civ == "English" else Color("59768a") if civ == "French" else Color("496763")
	palette["roof_dark"] = palette["roof"].darkened(0.32)
	_populate()
	prepare()
	_cache_portrait()

func p(u: float, v: float, z: float) -> Vector3:
	var ground := (Vector2(u, v) - Vector2.ONE * 0.5) * dimensions
	return Vector3(ground.x, ground.y, z)

func cube(u: float, v: float, w: float, d: float, z: float, h: float, color: Color) -> void:
	box((Vector2(u + w * 0.5, v + d * 0.5) - Vector2.ONE * 0.5) * dimensions, Vector2(w, d) * dimensions, z, h, color)

func beam(a: Vector3, b: Vector3, width: float, color: Color) -> void:
	var direction := (b - a).normalized()
	var toward_camera := Vector3(1, 1, sqrt(0.5))
	# Subpixel ropes, seams and bindings need one visible ribbon, not a prism
	# that multiplies BSP cuts across every neighbouring plank and beam.
	if width <= 0.6:
		var ribbon := direction.cross(toward_camera).normalized() * width * 0.5
		face([a - ribbon, b - ribbon, b + ribbon, a + ribbon], color)
		return
	var across := direction.cross(Vector3(0, 0, 1))
	if across.length_squared() < 0.001: across = Vector3(1, 0, 0)
	across = across.normalized() * width * 0.5
	var normal := direction.cross(across).normalized() * width * 0.5
	var corners: Array[Vector3] = [across + normal, -across + normal, -across - normal, across - normal]
	for i in 4:
		var j := (i + 1) % 4
		if ((corners[i] + corners[j]) * 0.5).dot(toward_camera) >= -0.001:
			face([a + corners[i], b + corners[i], b + corners[j], a + corners[j]], color.darkened(0.08 * i))
	var cap := b if direction.dot(toward_camera) >= 0.0 else a
	face([cap + corners[0], cap + corners[1], cap + corners[2], cap + corners[3]], color.lightened(0.15))

func _populate() -> void:
	var wood := Color("9b7951")
	var beam_color := Color("695039")
	# Real piles and diagonal braces precede the raised plank deck.
	for at in [Vector2(0.04, 0.10), Vector2(0.95, 0.10), Vector2(0.04, 0.64), Vector2(0.95, 0.64), Vector2(0.11, 1.08), Vector2(0.27, 1.08), Vector2(0.73, 1.08), Vector2(0.91, 1.08)]:
		cube(at.x - 0.012, at.y - 0.015, 0.024, 0.03, -4.0, 10.0, beam_color)
	for v in [0.64, 1.05]:
		for span in [[0.11, 0.27], [0.73, 0.91]]:
			beam(p(span[0], v, -3), p(span[1], v, 2.2), 1.4, beam_color)
	_platform(0.025, 0.045, 0.95, 0.62, wood)
	_platform(0.09, 0.64, 0.20, 0.48, wood.darkened(0.06))
	_platform(0.71, 0.64, 0.22, 0.48, wood.darkened(0.08))
	# A small ramp marks the connection to land, while the front stays open.
	face([p(0.36, -0.025, 0), p(0.59, -0.025, 0), p(0.59, 0.105, 4.1), p(0.36, 0.105, 4.1)], wood.lightened(0.08))
	for v in [0.01, 0.04, 0.07]: beam(p(0.36, v, 1.1 + v * 31), p(0.59, v, 1.1 + v * 31), 0.35, beam_color)
	_storehouse()
	_shelter()
	_crate(0.105, 0.51, 4.0, 4.4)
	_crate(0.185, 0.54, 4.0, 3.4)
	_crate(0.13, 0.515, 8.5, 3.0)
	_barrel(0.50, 0.545, 4.0, 2.0, 5.0, false)
	_barrel(0.57, 0.59, 4.0, 1.8, 4.5, false)
	_barrel(0.43, 0.54, 4.0, 2.3, 3.0, true)
	_barrel(0.45, 0.60, 4.0, 2.0, 2.9, true)
	# Bollards and their sagging mooring rope follow the water-facing edge.
	for at in [Vector2(0.045, 0.66), Vector2(0.33, 0.66), Vector2(0.66, 0.66), Vector2(0.97, 0.66), Vector2(0.115, 1.08), Vector2(0.265, 1.08), Vector2(0.735, 1.08), Vector2(0.90, 1.08)]:
		_bollard(at.x, at.y)
	_rope(p(0.33, 0.67, 7.2), p(0.66, 0.67, 7.2), 1.4)
	_rope(p(0.11, 0.72, 7.2), p(0.11, 1.07, 7.2), 1.4)
	_rope(p(0.90, 0.72, 7.2), p(0.90, 1.07, 7.2), 1.4)
	# Two small coils are rings laid flat on the platform, not drawn circles.
	for at in [Vector2(0.24, 0.84), Vector2(0.79, 1.00)]:
		for radius in [1.15, 1.75]:
			for i in 10:
				var a := i * TAU / 10.0
				var b := (i + 1) * TAU / 10.0
				beam(p(at.x, at.y, 4.2) + Vector3(cos(a), sin(a), 0) * radius, p(at.x, at.y, 4.2) + Vector3(cos(b), sin(b), 0) * radius, 0.35, Color("c0aa76"))
	_crane()

func _platform(u: float, v: float, w: float, d: float, wood: Color) -> void:
	cube(u, v, w, d, 1.5, 2.5, wood.darkened(0.19))
	# Slightly varied planks cover the structural slab; perimeter beams show
	# its thickness rather than becoming a heavy black foundation outline.
	var rows := maxi(2, ceili(d * dimensions.y / 4.0))
	for row in rows:
		var start := v + d * row / rows
		face([p(u + 0.004, start + 0.002, 4.18), p(u + w - 0.004, start + 0.002, 4.18), p(u + w - 0.004, start + d / rows - 0.002, 4.18), p(u + 0.004, start + d / rows - 0.002, 4.18)], wood.lightened(0.025 if row % 3 else 0.08))
	beam(p(u, v + d, 2.8), p(u + w, v + d, 2.8), 1.45, Color("664b34"))
	beam(p(u + w, v, 2.8), p(u + w, v + d, 2.8), 1.25, Color("6f5338"))

func _storehouse() -> void:
	var chinese := civilization == "Chinese"
	var french := civilization == "French"
	var wall: Color = palette["wall"]
	var frame := Color("724c32") if not chinese else Color("8e4436")
	var u := 0.08
	var v := 0.12
	var w := 0.51
	var d := 0.33
	var z := 4.2
	var h := 17.0 if not french else 19.0
	# The large loading aperture is physically absent from the front wall.
	cube(u, v, w, 0.05, z, h, wall)
	cube(u, v, 0.04, d, z, h, wall)
	cube(u + w - 0.04, v, 0.04, d, z, h, wall)
	cube(u, 0.41, 0.14, 0.04, z, h, wall)
	cube(0.45, 0.41, 0.14, 0.04, z, h, wall)
	cube(0.22, 0.41, 0.23, 0.04, z + h * 0.77, h * 0.23, wall)
	# Overlay the rear interior in a shallow open-faced loading porch; the
	# dark mouth and stacked goods remain distinct below the overhanging roof.
	face([p(0.22, 0.453, z), p(0.45, 0.453, z), p(0.45, 0.453, z + h * 0.77), p(0.22, 0.453, z + h * 0.77)], Color("343b33"))
	for at in [0.085, 0.215, 0.455, 0.585]: beam(p(at, 0.459, z), p(at, 0.459, z + h), 1.5, frame)
	beam(p(u, 0.462, z + h - 1.0), p(u + w, 0.462, z + h - 1.0), 1.6, frame)
	beam(p(0.21, 0.464, z + h * 0.77), p(0.46, 0.464, z + h * 0.77), 1.2, Color("b39b70"))
	for at in [0.10, 0.48]:
		beam(p(at, 0.465, z + 1), p(at + 0.09, 0.465, z + h - 2), 0.85, frame)
	# Open shutters, a high side window and cargo inside the loading mouth.
	cube(0.185, 0.456, 0.028, 0.09, z + 0.7, h * 0.73, Color("8a643f"))
	cube(0.46, 0.456, 0.028, 0.08, z + 0.7, h * 0.73, Color("755434"))
	face([p(0.594, 0.22, 13), p(0.594, 0.33, 13), p(0.594, 0.33, 18), p(0.594, 0.22, 18)], Color("364947"))
	beam(p(0.599, 0.273, 13), p(0.599, 0.273, 18), 0.65, Color("c9b78b"))
	_crate(0.27, 0.466, z, 3.2)
	_barrel(0.39, 0.475, z, 1.8, 4.3, false)
	_roof(u - 0.035, v - 0.045, w + 0.07, d + 0.09, z + h, 8.0 if not chinese else 7.0, french, chinese)
	# Restrained pennant above the loading aperture.
	face([p(0.32, 0.487, z + h - 1), p(0.37, 0.487, z + h - 1), p(0.37, 0.487, z + h - 4), p(0.345, 0.487, z + h - 5), p(0.32, 0.487, z + h - 4)], accent.darkened(0.08))

func _roof(u: float, v: float, w: float, d: float, z: float, rise: float, hip: bool, curved: bool) -> void:
	var a := p(u, v, z)
	var b := p(u + w, v, z)
	var c := p(u + w, v + d, z)
	var e := p(u, v + d, z)
	var roof: Color = palette["roof"]
	var left := p(u + w * (0.18 if hip or curved else 0.0), v + d * 0.5, z + rise)
	var right := p(u + w * (0.82 if hip or curved else 1.0), v + d * 0.5, z + rise)
	if curved:
		var back_a := a.lerp(left, 0.25) - Vector3(0, 0, 1.4)
		var back_b := b.lerp(right, 0.25) - Vector3(0, 0, 1.4)
		var near_a := e.lerp(left, 0.25) - Vector3(0, 0, 1.4)
		var near_b := c.lerp(right, 0.25) - Vector3(0, 0, 1.4)
		face([a + Vector3(0, 0, 1), b + Vector3(0, 0, 1), back_b, back_a], roof.lightened(0.18))
		face([back_a, back_b, right, left], roof.lightened(0.10))
		face([left, right, near_b, near_a], roof)
		face([near_a, near_b, c + Vector3(0, 0, 1), e + Vector3(0, 0, 1)], roof.darkened(0.10))
		face([a + Vector3(0, 0, 1), back_a, left], roof.lightened(0.04))
		face([a + Vector3(0, 0, 1), left, e + Vector3(0, 0, 1)], roof.lightened(0.04))
		face([left, near_a, e + Vector3(0, 0, 1)], roof.lightened(0.04))
		face([b + Vector3(0, 0, 1), c + Vector3(0, 0, 1), right], roof.darkened(0.22))
		face([c + Vector3(0, 0, 1), near_b, right], roof.darkened(0.22))
		face([b + Vector3(0, 0, 1), right, back_b], roof.darkened(0.22))
		for at in [a, b, c, e]: beam(at + Vector3(0, 0, 1), at + Vector3(0, 0, 2.4), 1.0, palette["trim"])
	else:
		face([a, b, right, left], roof.lightened(0.13))
		face([left, right, c, e], roof)
		face([a, left, e], roof.lightened(0.04) if hip else palette["wall"])
		face([b, c, right], roof.darkened(0.24) if hip else palette["wall"].darkened(0.18))
	for t in [0.22, 0.43, 0.64, 0.85]:
		var edge := e.lerp(c, t)
		var peak := left.lerp(right, t)
		if curved: peak = edge.lerp(peak, 0.7)
		beam(edge + Vector3(0, 0, 0.12), peak + Vector3(0, 0, 0.12), 0.22, roof.lightened(0.17))
	beam(e, c, 0.9, palette["roof_dark"])
	beam(left + Vector3(0, 0, 0.25), right + Vector3(0, 0, 0.25), 0.8, palette["trim"].darkened(0.19))

func _shelter() -> void:
	var frame := Color("754f34") if civilization != "Chinese" else Color("8e4436")
	for at in [Vector2(0.69, 0.15), Vector2(0.91, 0.15), Vector2(0.69, 0.38), Vector2(0.91, 0.38)]:
		beam(p(at.x, at.y, 4.2), p(at.x, at.y, 19.0), 1.6, frame)
	for v in [0.15, 0.38]: beam(p(0.69, v, 18), p(0.91, v, 18), 1.4, frame)
	_crate(0.77, 0.24, 4.2, 4.0)
	_barrel(0.86, 0.29, 4.2, 2.0, 4.5, false)
	_roof(0.665, 0.125, 0.27, 0.28, 19.0, 5.0, true, civilization == "Chinese")

func _crane() -> void:
	var color := Color("755435")
	var base := p(0.80, 0.62, 4.2)
	var head := p(0.80, 0.62, 31)
	var tip := p(1.00, 0.69, 31)
	cube(0.77, 0.585, 0.065, 0.07, 4.2, 2.0, Color("654c34"))
	beam(base, head, 1.8, color)
	beam(head, tip, 1.6, color)
	beam(base + Vector3(0, 0, 9), head.lerp(tip, 0.65), 1.1, color.darkened(0.10))
	beam(head + Vector3(0, 0, 0.6), tip + Vector3(0, 0, 0.6), 0.35, Color("c8b583"))
	beam(tip, tip - Vector3(0, 0, 14), 0.40, Color("b9a473"))
	beam(tip - Vector3(0, 0, 14), tip - Vector3(0.7, 0, 15), 0.65, Color("3c4846"))
	beam(tip - Vector3(0.7, 0, 15), tip - Vector3(1.3, 0, 14), 0.65, Color("3c4846"))
	# Cleat at the foot of the mast and a winding drum.
	beam(base + Vector3(-2, 0.4, 5), base + Vector3(2, 0.4, 5), 1.0, color.darkened(0.20))
	_barrel(0.835, 0.64, 4.2, 1.5, 2.4, false)

func _bollard(u: float, v: float) -> void:
	cube(u - 0.013, v - 0.014, 0.026, 0.028, 4.15, 4.2, Color("655038"))
	cube(u - 0.022, v - 0.016, 0.044, 0.032, 7.0, 1.1, Color("a88b5d"))

func _rope(a: Vector3, b: Vector3, sag: float) -> void:
	for i in 4:
		var t0 := i / 4.0
		var t1 := (i + 1) / 4.0
		beam(a.lerp(b, t0) - Vector3(0, 0, sin(t0 * PI) * sag), a.lerp(b, t1) - Vector3(0, 0, sin(t1 * PI) * sag), 0.32, Color("cbb589"))

func _crate(u: float, v: float, z: float, size: float) -> void:
	var w := size / dimensions.x
	var d := size / dimensions.y
	cube(u, v, w, d, z, size, Color("a88250"))
	for offset in [0.0, size]:
		beam(p(u, v + d + 0.005, z + offset), p(u + w, v + d + 0.005, z + offset), 0.60, Color("654b30"))
	beam(p(u, v + d + 0.006, z), p(u + w, v + d + 0.006, z + size), 0.45, Color("715035"))
	beam(p(u + w + 0.003, v, z), p(u + w + 0.003, v + d, z + size), 0.45, Color("715035"))

func _barrel(u: float, v: float, z: float, radius: float, height: float, sack: bool) -> void:
	var center := p(u, v, z)
	var colors := Color("b7a477") if sack else Color("87613e")
	var top: Array = []
	for i in 8:
		var angle := i * TAU / 8.0
		var next := (i + 1) * TAU / 8.0
		var a := center + Vector3(cos(angle), sin(angle), 0) * radius
		var b := center + Vector3(cos(next), sin(next), 0) * radius
		var aa := center + Vector3(cos(angle), sin(angle), 0) * radius * (0.55 if sack else 0.82) + Vector3(0, 0, height)
		var bb := center + Vector3(cos(next), sin(next), 0) * radius * (0.55 if sack else 0.82) + Vector3(0, 0, height)
		var visible := Vector2(cos((angle + next) * 0.5), sin((angle + next) * 0.5)).dot(Vector2.ONE) >= -0.001
		if visible: face([a, b, bb, aa], colors.lightened(0.05 * cos(angle)))
		top.append(aa)
		if not sack and visible:
			for h in [0.22, 0.76]:
				face([a.lerp(aa, h), b.lerp(bb, h), b.lerp(bb, h + 0.08), a.lerp(aa, h + 0.08)], Color("48504a"))
	face(top, colors.lightened(0.15))
	if sack: beam(center + Vector3(0, 0, height), center + Vector3(0, 0, height + 0.8), 0.75, Color("8e7951"))

func _cache_portrait() -> void:
	var by_height := faces.duplicate()
	by_height.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _mean_z(a) < _mean_z(b))
	for polygon in by_height:
		var flat := PackedVector2Array()
		for at in polygon["points"]: flat.append(Vector2(at.x, at.y))
		if not Geometry2D.triangulate_polygon(flat).is_empty(): flat_faces.append({"points": flat, "color": polygon["color"]})
	var first := true
	for polygon in ordered_faces:
		var points := PackedVector2Array()
		for at in polygon["points"]:
			var projected := Vector2((at.x - at.y) * 0.70710678, (at.x + at.y) * 0.35355339 - at.z)
			points.append(projected)
			portrait_bounds = Rect2(projected, Vector2.ZERO) if first else portrait_bounds.expand(projected)
			first = false
		if not Geometry2D.triangulate_polygon(points).is_empty(): portrait_faces.append({"points": points, "color": polygon["color"]})

func _mean_z(polygon: Dictionary) -> float:
	var sum := 0.0
	for at in polygon["points"]: sum += at.z
	return sum / polygon["points"].size()

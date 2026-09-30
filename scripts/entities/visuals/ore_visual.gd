class_name RtsOreVisual
extends RefCounted

# Cache both projections once. A private RNG keeps map generation reproducible;
# the portrait uses this same deposit rather than a generic resource icon.
const FilledPolygon = preload("res://scripts/entities/visuals/filled_polygon.gd")
const GOLD := Color("c99e42")
const GOLD_LIGHT := Color("eed080")
var shapes_2d: Array[Dictionary] = []
var shapes_25d: Array[Dictionary] = []
var ground := PackedVector2Array()
var rng := RandomNumberGenerator.new()
var is_gold := false

func _init(point: Vector2, kind := "stone") -> void:
	is_gold = kind == "gold"
	rng.seed = hash(point) ^ hash(kind)
	for i in 14:
		var angle := i * TAU / 14.0
		ground.append(Vector2(cos(angle) * 25.0, sin(angle) * 21.0) * rng.randf_range(0.86, 1.0))
	var rocks: Array[Dictionary] = []
	# Unequal overlapping boulders leave notches in the outline. The largest
	# rock is off-center, with low broken pieces spreading across the foot.
	var layout := [Vector4(9, -10, 8, 15), Vector4(-9, -5, 12, 20), Vector4(4, 1, 13, 26), Vector4(-15, 8, 7, 10), Vector4(14, 9, 8, 12), Vector4(-2, 13, 7, 8)]
	var spread := rng.randf_range(0.88, 1.0)
	var rise := rng.randf_range(0.83, 1.10)
	for spec: Vector4 in layout:
		rocks.append(_rock(Vector2(spec.x, spec.y) * spread + Vector2(rng.randf_range(-2, 2), rng.randf_range(-2, 2)), spec.z * rng.randf_range(0.86, 1.08), spec.w * rise * rng.randf_range(0.85, 1.06)))
	for i in 7:
		var angle := i * TAU / 7.0 + rng.randf_range(-0.22, 0.22)
		var chip := _rock(Vector2(cos(angle) * 23, sin(angle) * 18), rng.randf_range(1.4, 3.0), rng.randf_range(2.5, 4.5))
		chip["threshold"] = [0.0, 0.30, 0.65][i % 3]
		rocks.append(chip)
	for iso in [false, true]:
		var ordered := rocks.duplicate()
		ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _project(a["base"], iso).y < _project(b["base"], iso).y)
		for rock in ordered:
			_build_rock(shapes_25d if iso else shapes_2d, rock, iso)

func draw_ground(canvas: CanvasItem) -> void:
	FilledPolygon.draw(canvas, ground, Color("655d46", 0.14))
	FilledPolygon.draw(canvas, _ellipse(Vector2(2, 2), Vector2(21, 17)), Color("253028", 0.10))
	FilledPolygon.draw(canvas, _ellipse(Vector2(0, 1), Vector2(15, 12)), Color("202923", 0.10))

func draw(canvas: CanvasItem, isometric: bool, fraction := 1.0) -> void:
	for shape in (shapes_25d if isometric else shapes_2d):
		if fraction < shape["threshold"]: continue
		if shape.get("line", false):
			canvas.draw_polyline(shape["points"], shape["color"], 0.65, true)
		else:
			FilledPolygon.draw(canvas, shape["points"], shape["color"])

func _rock(base: Vector2, width: float, rise: float) -> Dictionary:
	var rim := PackedVector2Array([Vector2(-0.95, 0), Vector2(-1, -0.40), Vector2(-0.67, -0.80), Vector2(-0.22, -1), Vector2(0.40, -0.91), Vector2(0.87, -0.48), Vector2(1, 0.02), Vector2(0.37, 0.16), Vector2(-0.36, 0.12)])
	for i in rim.size(): rim[i] += Vector2(rng.randf_range(-0.07, 0.07), rng.randf_range(-0.06, 0.06))
	var veins: Array[Dictionary] = []
	if is_gold and width > 5.0:
		for i in 3:
			veins.append({"uv": Vector2(0.22 + i * 0.24, rng.randf_range(0.25, 0.72)), "length": rng.randf_range(0.24, 0.36), "slope": rng.randf_range(-0.13, 0.13), "thickness": rng.randf_range(0.10, 0.17), "threshold": [0.0, 0.30, 0.65][i]})
	return {"base": base, "width": width, "rise": rise, "rim": rim, "join": Vector2(rng.randf_range(-0.25, 0.05), rng.randf_range(-0.48, -0.34)), "tone": rng.randf_range(-0.08, 0.08), "veins": veins}

func _build_rock(shapes: Array[Dictionary], rock: Dictionary, iso: bool) -> void:
	var first_shape := shapes.size()
	var base := _project(rock["base"], iso)
	var extent := Vector2(rock["width"], rock["rise"] if iso else rock["width"] * 1.0)
	if not iso: base.y += extent.y * 0.40
	var rim := PackedVector2Array()
	for point: Vector2 in rock["rim"]: rim.append(base + point * extent)
	var join: Vector2 = base + rock["join"] * extent
	var inner := base + Vector2(0.24, -0.14) * extent
	var upper := base + Vector2(-0.05, -0.64) * extent
	var stone := Color("858b88") if not is_gold else Color("7b705d")
	stone = stone.lightened(rock["tone"]) if rock["tone"] >= 0.0 else stone.darkened(-rock["tone"])
	_shape(shapes, rim, stone.darkened(0.34))
	_shape(shapes, [rim[1], rim[2], rim[3], rim[4], rim[5], join], stone.lightened(0.17))
	_shape(shapes, [rim[0], rim[1], join], stone)
	_shape(shapes, [rim[0], join, rim[5], rim[6], rim[7], rim[8]], stone.darkened(0.14))
	_shape(shapes, [rim[2], rim[3], rim[4], upper], stone.lightened(0.29))
	_shape(shapes, [rim[0], join, inner, rim[8]], stone.lightened(0.02))
	_shape(shapes, [join, rim[5], rim[6], inner], stone.darkened(0.22))
	# Small fracture planes and weathering interrupt the large clean facets.
	if rock["width"] > 5.0:
		_shape(shapes, [rim[1].lerp(rim[2], 0.28), rim[2].lerp(upper, 0.35), upper.lerp(join, 0.42), rim[1].lerp(join, 0.55)], stone.lightened(0.09))
		_shape(shapes, [rim[0].lerp(join, 0.24), rim[0].lerp(join, 0.44), inner.lerp(rim[8], 0.5)], stone.darkened(0.06))
		var crack_start := rim[2].lerp(rim[3], 0.27)
		var crack_end := upper.lerp(join, 0.65)
		shapes.append({"line": true, "threshold": 0.0, "points": PackedVector2Array([crack_start, upper, crack_end]), "color": stone.darkened(0.26)})
		shapes.append({"line": true, "threshold": 0.0, "points": PackedVector2Array([inner.lerp(rim[6], 0.3), inner, inner.lerp(rim[8], 0.40)]), "color": stone.darkened(0.30)})
	# Thin, discontinuous mineral inclusions sit within the front fracture face.
	for i in rock["veins"].size():
		var vein: Dictionary = rock["veins"][i]
		if i == 0: _seam(shapes, vein, [rim[2], rim[4], rim[5], join], Vector2(0.15, 0.06))
		_seam(shapes, vein, [join, rim[5], rim[6], rim[8]], Vector2.ZERO, minf(rock["width"] * 0.09, 1.0))
	# Loose rubble diminishes during harvesting; the embedded rock remains.
	for i in range(first_shape, shapes.size()):
		shapes[i]["threshold"] = maxf(shapes[i]["threshold"], rock.get("threshold", 0.0))

func _seam(shapes: Array[Dictionary], vein: Dictionary, face: Array[Vector2], offset := Vector2.ZERO, grain_size := 0.0) -> void:
	var uv: Vector2 = vein["uv"] + offset
	var half_length: float = vein["length"] * 0.5
	var slope: float = vein["slope"]
	var thickness: float = vein["thickness"]
	var a := uv + Vector2(-half_length, -slope)
	var b := uv + Vector2(half_length, slope)
	var outline := [a + Vector2(0, -thickness * 0.25), uv + Vector2(0, -thickness), b, b + Vector2(0.015, thickness * 0.50), uv + Vector2(0.025, thickness * 0.55), a + Vector2(0, thickness * 0.65)]
	var highlight := [a, uv + Vector2(0, -thickness * 0.70), b, uv]
	for band in [outline, highlight]:
		var points := PackedVector2Array()
		for point: Vector2 in band: points.append(_on_face(point, face[0], face[1], face[2], face[3]))
		_shape(shapes, points, GOLD if band == outline else GOLD_LIGHT, vein["threshold"])
	if grain_size > 0.0:
		var grain := _on_face(uv + Vector2(-0.08, 0.16), face[0], face[1], face[2], face[3])
		_shape(shapes, [grain + Vector2(-grain_size, 0), grain + Vector2(0, -grain_size * 0.8), grain + Vector2(grain_size * 0.7, 0.1), grain + Vector2(0, grain_size * 0.6)], GOLD, vein["threshold"])

static func _project(point: Vector2, iso: bool) -> Vector2:
	return Vector2((point.x - point.y) * 0.70710678, (point.x + point.y) * 0.35355339) if iso else point

static func _on_face(uv: Vector2, upper_left: Vector2, upper_right: Vector2, lower_right: Vector2, lower_left: Vector2) -> Vector2:
	return upper_left.lerp(upper_right, uv.x).lerp(lower_left.lerp(lower_right, uv.x), uv.y)

static func _shape(target: Array[Dictionary], points: Variant, color: Color, threshold := 0.0) -> void:
	target.append({"points": PackedVector2Array(points), "color": color, "threshold": threshold})

static func _ellipse(center: Vector2, extent: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 16: points.append(center + Vector2(cos(i * TAU / 16.0), sin(i * TAU / 16.0)) * extent)
	return points

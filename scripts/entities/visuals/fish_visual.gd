class_name RtsFishVisual
extends RefCounted

# Fish live in the water plane: the world's own projection flattens the whole
# school in 2.5D. All motion is local to this resource's fixed gathering point.
const OFFSETS := [Vector2(-9, -7), Vector2(7, 7), Vector2(6, -8), Vector2(-8, 7), Vector2(0, 0)]
const SIZES := [1.08, 1.0, 0.90, 0.84, 0.78]
const DEPTHS := [0.85, 0.92, 0.67, 0.71, 0.59]

static func draw(item: CanvasItem, base: Transform2D, time: float, seed_value: int, fraction: float = 1.0, isometric: bool = false) -> void:
	item.draw_set_transform_matrix(base)
	if fraction <= 0.0:
		return
	# Hashing rather than calling randf keeps both world RNG and school layout
	# unchanged when selection portraits or additional frames are drawn.
	var seed_phase := _noise(seed_value, 11) * TAU
	var heading := _noise(seed_value, 27) * TAU + sin(time * 0.24 + seed_phase) * 0.12
	var school := base * Transform2D(heading, Vector2.ZERO)
	for i in 5:
		var presence := 1.0 if i < 2 else clampf(fraction * 3.0 - float(i - 2), 0.0, 1.0)
		if presence <= 0.0:
			continue
		var phase := seed_phase + float(i) * 1.73
		var drift := Vector2(sin(time * 0.55 + phase) * 0.85, cos(time * 0.43 + phase) * 0.65)
		var offset: Vector2 = OFFSETS[i] + drift
		var angle := sin(time * 0.67 + phase) * 0.12 + (_noise(seed_value, i + 40) - 0.5) * 0.16
		var size: float = SIZES[i] * lerpf(0.96, 1.04, _noise(seed_value, i + 60))
		var figure := school * Transform2D(angle, Vector2(size, size * (1.16 if isometric else 1.0)), 0.0, offset)
		item.draw_set_transform_matrix(figure)
		_draw_fish(item, time * 4.2 + phase, float(DEPTHS[i]) * presence, _noise(seed_value, i + 80))
	item.draw_set_transform_matrix(school)
	# Short broken glints suggest the water above the fish without a resource
	# disk, bubble halo, or opaque patch covering the underlying water texture.
	var glint := 0.075 + 0.025 * sin(time * 0.8 + seed_phase)
	item.draw_arc(Vector2(-7, -5), 7.8, 3.80, 4.72, 12, Color(0.62, 0.80, 0.80, glint), 0.6, true)
	item.draw_arc(Vector2(7, 6), 6.5, 0.48, 1.28, 10, Color(0.62, 0.80, 0.80, glint * 0.85), 0.6, true)
	item.draw_set_transform_matrix(base)

static func draw_portrait(item: CanvasItem, frame: Rect2, seed_value: int = 0) -> void:
	# Use the map's exact school geometry at a stable swimming pose.
	var fit := minf(frame.size.x / 43.0, frame.size.y / 38.0) * 0.90
	var base := Transform2D(0.0, Vector2.ONE * fit, 0.0, frame.get_center())
	draw(item, base, 1.4, seed_value)
	item.draw_set_transform_matrix(Transform2D.IDENTITY)

static func _draw_fish(item: CanvasItem, phase: float, opacity: float, tone: float) -> void:
	var bend := sin(phase) * 0.56
	var tail_sweep := sin(phase + 0.42) * 1.10
	var body_color := Color("77aaa9").lerp(Color("9db8af"), tone * 0.65)
	body_color.a = opacity * 0.82
	var fin_color := Color(0.32, 0.55, 0.56, opacity * 0.58)
	var shade := Color(0.25, 0.46, 0.49, opacity * 0.60)
	# Forked tail lobes follow the flexible rear body rather than translating
	# the entire fish. A central notch remains visible at either stroke extreme.
	var root := Vector2(-4.65, bend)
	var notch := Vector2(-6.65, bend + tail_sweep)
	item.draw_colored_polygon(PackedVector2Array([root + Vector2(0, -0.48), Vector2(-7.7, bend + tail_sweep - 2.0), notch, root + Vector2(-0.25, 0.13)]), fin_color)
	item.draw_colored_polygon(PackedVector2Array([root + Vector2(0, 0.48), Vector2(-7.7, bend + tail_sweep + 2.0), notch, root + Vector2(-0.25, -0.13)]), fin_color)
	# Soft dorsal and paired pectoral fins read as translucent water silhouettes.
	item.draw_colored_polygon(PackedVector2Array([Vector2(-2.9, -1.1), Vector2(-2.2, -2.9), Vector2(-0.2, -2.2), Vector2(0.5, -1.7)]), fin_color)
	item.draw_colored_polygon(PackedVector2Array([Vector2(1.7, 0.7), Vector2(0.4, 3.0), Vector2(-0.1, 1.35)]), fin_color)
	item.draw_colored_polygon(PackedVector2Array([Vector2(1.7, -0.7), Vector2(0.8, -2.7), Vector2(-0.1, -1.35)]), Color(fin_color, fin_color.a * 0.65))
	var upper := PackedVector2Array()
	var lower := PackedVector2Array()
	var center := PackedVector2Array()
	# A rounded snout widens into shoulders then steadily tapers to the wrist.
	# Dense enough samples avoid the old diamond silhouette at portrait scale.
	for j in 17:
		var u := float(j) / 16.0
		var x := lerpf(5.1, -4.65, u)
		var width := pow(sin(u * PI), 0.74) * lerpf(2.42, 0.76, u) + 0.14
		var curve := bend * u * u
		upper.append(Vector2(x, curve - width))
		lower.append(Vector2(x, curve + width))
		center.append(Vector2(x, curve + width * 0.18))
	var body := upper.duplicate()
	for j in range(lower.size() - 1, -1, -1):
		body.append(lower[j])
	item.draw_colored_polygon(body, body_color)
	var underside := center.duplicate()
	for j in range(lower.size() - 1, -1, -1):
		underside.append(lower[j])
	item.draw_colored_polygon(underside, shade)
	# Broken silver light along the upper flank gives volume without a hard rim.
	var highlight := PackedVector2Array()
	for j in range(2, 11):
		highlight.append(upper[j].lerp(center[j], 0.40))
	item.draw_polyline(highlight, Color(0.74, 0.85, 0.79, opacity * 0.44), 0.65, true)
	item.draw_arc(Vector2(2.35, 0.05), 1.05, -0.90, 0.82, 9, Color(0.31, 0.53, 0.53, opacity * 0.46), 0.45, true)
	item.draw_circle(Vector2(3.8, -0.40), 0.34, Color(0.17, 0.36, 0.38, opacity * 0.74), true, -1, true)

static func _noise(seed_value: int, salt: int) -> float:
	return float(hash(Vector2i(seed_value, salt)) & 0xFFFF) / 65535.0

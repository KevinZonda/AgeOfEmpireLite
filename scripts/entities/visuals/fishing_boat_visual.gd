extends RefCounted
class_name RtsFishingBoatVisual

# A shallow working skiff: one solid model, projected toward the actual heading.
# Water remains at z = 0; the keel is submerged rather than floating over a shadow.
const Geometry = preload("res://scripts/entities/visuals/siege_geometry.gd")
const INK := Color("283c3a")
const WOOD := Color("946343")
const WOOD_DARK := Color("584232")
const WOOD_LIGHT := Color("bd8d5a")
const DECK := Color("d3ab77")
const SAIL := Color("f0e7c7")
const ROPE := Color("d9c79b")
const SKIN := Color("dfb28a")
const WATER := Color("b8e7df", 0.56)
const CACHE_LIMIT := 768

static var model_cache: Dictionary = {}
var last_key: Array = []
var model

static func handles(kind: String) -> bool: return kind == "fishing_boat"

static func _value(state, key: String, fallback):
	if state is Dictionary: return state.get(key, fallback)
	var value = state.get(key)
	return fallback if value == null else value

static func is_fishing(state) -> bool:
	if state.visual_moving: return false
	return bool(_value(state, "fishing_active", false)) or state.visual_action in ["fish", "fishing"]

func geometry(state):
	var fishing := is_fishing(state)
	var cycle := float(_value(state, "fishing_cycle", state.action_progress))
	# Twelve poses are shared by every vessel; time never creates an unbounded cache.
	var pose := mini(11, floori(clampf(cycle, 0.0, 1.0) * 12.0)) if fishing else -1
	var key := [state.view_mode_25d, state.facing_direction, state.player_color, snappedf(state.radius, 0.5), pose]
	if key == last_key and model != null: return model
	last_key = key
	if model_cache.has(key):
		model = model_cache[key]
		return model
	model = Geometry.new()
	model.configure(state)
	_build(model, state, (pose + 0.5) / 12.0 if fishing else -1.0)
	model.finish()
	if model_cache.size() >= CACHE_LIMIT: model_cache.clear()
	model_cache[key] = model
	return model

func bounds(state) -> Rect2:
	# Previews fit a complete motion envelope, rather than resizing at every pose.
	var base := legacy_state(state.radius, state.player_color, state.view_mode_25d)
	base.facing_direction = state.facing_direction
	var g = geometry(base)
	var result: Rect2 = g.bounds
	var s: float = state.radius / 15.0
	for side in [-1.0, 1.0]:
		result = result.expand(g.project(Vector3(side * 10.7, -3, 0) * s))
	if state.visual_moving:
		for x in [-14.5, 14.5]:
			for y in [15.0, 35.0]: result = result.expand(g.project(Vector3(x, y, 0) * s))
	elif is_fishing(state):
		for x in [8.0, 25.0]:
			for y in [0.0, 16.0]:
				for z in [-3.0, 7.5]: result = result.expand(g.project(Vector3(x, y, z) * s))
	return result

func draw(canvas: CanvasItem, state) -> void:
	geometry(state).draw(canvas)

func draw_shadow(canvas: CanvasItem, state) -> void:
	var g = geometry(state)
	var scale: float = state.radius / 15.0
	var waterline := _outline(0.97, scale)
	var points := PackedVector2Array()
	for point in waterline: points.append(g.project(Vector3(point.x, point.y, 0.0)))
	canvas.draw_colored_polygon(points, Color("173c40", 0.17))
	# Pale broken water lines hug the boat. Nothing resembles a land-unit ellipse.
	var phase: float = state.visual_phase
	for side in [-1.0, 1.0]:
		var wave: float = sin(phase * 1.7 + side) * 0.6
		_water_line(canvas, g, [Vector3(side * 8.8, -10, 0), Vector3(side * (10.0 + wave), -3, 0), Vector3(side * 9.1, 5, 0)], WATER, scale)
	if state.visual_moving:
		var pulse: float = fposmod(phase * 1.8, 6.0)
		for side in [-1.0, 1.0]:
			_water_line(canvas, g, [Vector3(side * 4.5, 15, 0), Vector3(side * (8.0 + pulse * 0.23), 21 + pulse, 0), Vector3(side * (12.0 + pulse * 0.35), 29 + pulse, 0)], Color("c7f0e5", 0.46), scale)
		_water_line(canvas, g, [Vector3(-2.5, 20 + pulse, 0), Vector3(0, 21.5 + pulse, 0), Vector3(2.5, 20 + pulse, 0)], Color("d7f5e9", 0.34), scale)
	elif is_fishing(state):
		for i in 2:
			var ripple: float = fposmod(phase * 1.8 + i * 2.0, 4.0)
			var center := Vector3(21, 7, 0) * scale
			var ring := PackedVector2Array()
			for j in 17:
				var angle := TAU * j / 16.0
				ring.append(g.project(center + Vector3(cos(angle) * (3 + ripple), sin(angle) * (2 + ripple * 0.7), 0) * scale))
			canvas.draw_polyline(ring, Color("b8e7df", (1.0 - ripple / 4.0) * 0.38), 0.8, true)

static func _water_line(c: CanvasItem, g, points: Array, color: Color, scale: float) -> void:
	var pixels := PackedVector2Array()
	for point in points: pixels.append(g.project(point * scale))
	c.draw_polyline(pixels, color, 0.95, true)

func overlay_y(state) -> float: return minf(-25.0, bounds(state).position.y - 7.0)

func draw_portrait(canvas: CanvasItem, _kind: String, color: Color, area: Rect2) -> void:
	var state := legacy_state(15.0, color, true)
	var g = geometry(state)
	var extent: Vector2 = g.bounds.size
	var fit := minf(area.size.x / maxf(extent.x + 4.0, 1.0), area.size.y / maxf(extent.y + 4.0, 1.0))
	canvas.draw_set_transform_matrix(Transform2D(0.0, Vector2.ONE * fit, 0.0, area.get_center() - g.bounds.get_center() * fit))
	draw_shadow(canvas, state)
	g.draw(canvas)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)

static func legacy_state(radius: float, color: Color, iso: bool) -> Dictionary:
	return {"kind": "fishing_boat", "radius": radius, "player_color": color, "view_mode_25d": iso, "facing_direction": Vector2(1, 1).normalized(), "visual_phase": 0.0, "visual_moving": false, "visual_action": "", "action_progress": 0.0, "fishing_active": false, "fishing_cycle": 0.0}

static func _outline(inset: float, scale: float) -> Array[Vector3]:
	var points: Array[Vector3] = []
	# Pointed raised bow and a broad rounded transom are legible in every heading.
	for point in [Vector3(0, -20, 0), Vector3(6, -14, 0), Vector3(9, -5, 0), Vector3(8.7, 8, 0), Vector3(5.7, 15, 0), Vector3(-5.7, 15, 0), Vector3(-8.7, 8, 0), Vector3(-9, -5, 0), Vector3(-6, -14, 0)]:
		points.append(point * inset * scale)
	return points

static func _build(g, state, cycle: float) -> void:
	var s: float = state.radius / 15.0
	var rim := _outline(1.0, s)
	var deck := _outline(0.84, s)
	var chine := _outline(0.88, s)
	for i in rim.size():
		var height_a := (5.3 if i in [0, 1, 8] else 4.0) * s
		rim[i].z = height_a
		deck[i].z = 2.8 * s
		chine[i].z = 0.35 * s
	for i in rim.size():
		var j := (i + 1) % rim.size()
		# A narrow side wall, not a tall wooden box.
		g.face([chine[i], chine[j], rim[j], rim[i]], WOOD, true)
	# The deck is intentionally one surface group so its seams cannot be erased.
	g.begin_surface_group(Vector3(0, 0, 2.8) * s)
	g.face(deck, DECK)
	for y in [-12.0, -7.0, -2.0, 3.0, 8.0, 12.0]:
		var width := 6.2 if y > -9 else 3.3
		g.line(Vector3(-width, y, 2.85) * s, Vector3(width, y, 2.85) * s, WOOD_LIGHT, 0.65 * s)
	g.end_surface_group()
	for i in rim.size():
		var j := (i + 1) % rim.size()
		var top_j := Vector3(rim[j].x, rim[j].y, (5.3 if j in [0, 1, 8] else 4.0) * s)
		g.line(rim[i], top_j, WOOD_DARK, 1.9 * s)
		g.line(rim[i] + Vector3(0, 0, 0.4 * s), top_j + Vector3(0, 0, 0.4 * s), WOOD_LIGHT, 0.9 * s)
	# Team paint belongs on the gunwales and pennant, leaving a natural linen sail.
	for side in [-1.0, 1.0]:
		g.line(Vector3(side * 8.8, -5, 3.0) * s, Vector3(side * 8.5, 7, 3.0) * s, state.player_color.darkened(0.12), 1.8 * s)
	g.beam(Vector3(-6.8, 3, 3.1) * s, Vector3(6.8, 3, 3.1) * s, 1.6 * s, WOOD_LIGHT)
	# Stern rudder and small tiller are distinct from the pointed bow.
	g.face([Vector3(-0.7, 14, 1) * s, Vector3(0.7, 14, 1) * s, Vector3(0.7, 19, 0) * s, Vector3(-0.7, 19, 0) * s], WOOD_DARK)
	g.beam(Vector3(0, 14, 4.1) * s, Vector3(-3, 9, 5.3) * s, 0.9 * s, WOOD_DARK)
	_sail(g, state.player_color, s)
	_basket(g, Vector3(-4.2, 5.5, 3.1) * s, s, true)
	_basket(g, Vector3(-4, 10.6, 3.1) * s, s * 0.78, false)
	_crew(g, state.player_color, s, cycle)
	_net(g, s, cycle)

static func _sail(g, team: Color, s: float) -> void:
	var mast_base := Vector3(-1.4, -7.8, 3.0) * s
	var mast_top := Vector3(-1.4, -7.8, 29.0) * s
	g.beam(mast_base, mast_top, 1.3 * s, WOOD_DARK)
	g.line(mast_base, mast_top, WOOD_LIGHT, 0.7 * s)
	# The broad lateen sail has a belly and separate pale panels instead of a flag.
	var peak := Vector3(-1.0, -8.8, 26.0) * s
	var front := Vector3(-0.8, -13.0, 9.5) * s
	var aft := Vector3(1.0, 2.5, 11.0) * s
	var belly := Vector3(2.0, -5.2, 15.5) * s
	g.begin_surface_group(Vector3(0, -5, 18) * s)
	g.face([peak, front, belly], SAIL)
	g.face([peak, belly, aft], Color("dfd4b5"))
	g.face([front, aft, belly], Color("f6efd9"))
	g.line(peak, front, Color("af9e7d"), 0.75 * s)
	g.line(front, aft, Color("b6a27f"), 0.8 * s)
	g.line(peak, aft, Color("c3b590"), 0.7 * s)
	g.line(peak.lerp(front, 0.45), peak.lerp(aft, 0.45), Color("cabc98"), 0.6 * s)
	g.end_surface_group()
	g.beam(front, peak + Vector3(0, 0, 0.8 * s), 0.8 * s, WOOD_LIGHT)
	g.line(mast_top, Vector3(0, -18, 4.4) * s, ROPE, 0.55 * s)
	g.line(mast_top, Vector3(-5, 11, 4) * s, ROPE, 0.55 * s)
	g.face([mast_top + Vector3(0, 0, 1.7 * s), mast_top + Vector3(0, 5.0 * s, 0.5 * s), mast_top + Vector3(0, 0, -0.7 * s)], team)

static func _basket(g, base: Vector3, s: float, has_fish: bool) -> void:
	g.cylinder(base, base + Vector3(0, 0, 3.1 * s), 2.5 * s, WOOD_LIGHT, 8)
	g.cylinder(base + Vector3(0, 0, 3.05 * s), base + Vector3(0, 0, 3.15 * s), 2.25 * s, WOOD_DARK, 8)
	for i in 8:
		var angle := TAU * i / 8.0
		var edge := Vector3(cos(angle), sin(angle), 0) * 2.45 * s
		g.line(base + edge, base + edge + Vector3(0, 0, 3.05 * s), ROPE, 0.45 * s)
	if has_fish:
		for offset in [-0.85, 0.8]:
			var center := base + Vector3(offset, 0, 3.45) * s
			g.face([center + Vector3(-0.65, 0, 0) * s, center + Vector3(0, -1.65, 0) * s, center + Vector3(0.7, 0, 0) * s, center + Vector3(0, 1.35, 0) * s], Color("b4d2ce"))
			g.line(center + Vector3(0, 1.0, 0) * s, center + Vector3(0.7, 1.6, 0) * s, Color("799c9b"), 0.6 * s)

static func _crew(g, team: Color, s: float, cycle: float) -> void:
	var lean := sin(cycle * TAU) * 1.3 if cycle >= 0.0 else 0.0
	var hip := Vector3(2.0, 8.4, 6.3) * s
	var chest := hip + Vector3(lean, -0.2, 3.6) * s
	var head := chest + Vector3(0, 0, 2.2) * s
	for side in [-1.0, 1.0]:
		g.beam(hip + Vector3(side * 0.75, 0, 0) * s, Vector3(2 + side * 1.0, 8.8, 3.0) * s, 1.2 * s, Color("484e42"))
	g.cylinder(hip, chest, 1.8 * s, team.darkened(0.13), 7)
	g.cylinder(head - Vector3(0, 0, 1.3 * s), head + Vector3(0, 0, 0.9 * s), 1.55 * s, SKIN, 8)
	g.cylinder(head + Vector3(0, 0, 1.0 * s), head + Vector3(0, 0, 1.5 * s), 2.25 * s, Color("dac48d"), 10)
	g.cylinder(head + Vector3(0, 0, 1.5 * s), head + Vector3(0, 0, 2.1 * s), 1.45 * s, Color("af9468"), 8)
	var grip := Vector3(5.7 + maxf(0.0, lean), 7.5, 7.0 + lean) * s
	for side in [-1.0, 1.0]:
		var shoulder := chest + Vector3(side * 1.4, 0, -0.5) * s
		var hand := grip + Vector3(0, side * 0.8, 0) * s
		g.beam(shoulder, hand, 0.85 * s, SKIN)
		g.line(hand, Vector3(8, 7.5 + side * 0.8, 3.5) * s, ROPE, 0.6 * s)

static func _net_point(u: float, v: float, s: float, deployment: float, lift: float) -> Vector3:
	var span := 5.0 + deployment * 7.0
	var pocket := sin(u * PI)
	var x := 8.0 + v * (2.0 + deployment * (11.0 + pocket * 3.0))
	var y := 2.0 + span * 0.5 + (u - 0.5) * span * (1.0 - v * 0.22)
	var z := 4.4 * (1.0 - v) - sin(v * PI) * deployment * 2.0 - pocket * v * deployment * 1.5 + lift * v
	return Vector3(x, y, z) * s

static func _net(g, s: float, cycle: float) -> void:
	if cycle < 0.0:
		# A visibly rolled net rests against the starboard rail during travel.
		g.cylinder(Vector3(6.8, 5, 4.5) * s, Vector3(6.8, 11, 4.5) * s, 1.3 * s, Color("928f75"), 7)
		for y in [5.5, 7.0, 8.5, 10.0]:
			g.line(Vector3(5.7, y, 5.0) * s, Vector3(7.8, y + 0.7, 5.0) * s, ROPE, 0.55 * s)
		g.line(Vector3(5.7, 5.8, 5.4) * s, Vector3(7.8, 10.6, 5.4) * s, ROPE, 0.55 * s)
		return
	var deployment := clampf(cycle / 0.22, 0.0, 1.0) * clampf((1.0 - cycle) / 0.18, 0.0, 1.0)
	var lift := sin(clampf((cycle - 0.6) / 0.4, 0.0, 1.0) * PI) * 6.0
	var center := _net_point(0.5, 0.5, s, deployment, lift)
	g.begin_surface_group(center)
	# Open translucent net with two crossing families and a sagging lower edge.
	for u in 4:
		for v in 4:
			g.face([_net_point(u / 4.0, v / 4.0, s, deployment, lift), _net_point((u + 1) / 4.0, v / 4.0, s, deployment, lift), _net_point((u + 1) / 4.0, (v + 1) / 4.0, s, deployment, lift), _net_point(u / 4.0, (v + 1) / 4.0, s, deployment, lift)], Color("719b8b", 0.14))
	for i in 11:
		var diagonal := i / 5.0 - 1.0
		var start_u := maxf(0.0, diagonal)
		var finish_u := minf(1.0, 1.0 + diagonal)
		for j in 4:
			var a := lerpf(start_u, finish_u, j / 4.0)
			var b := lerpf(start_u, finish_u, (j + 1) / 4.0)
			g.line(_net_point(a, a - diagonal, s, deployment, lift), _net_point(b, b - diagonal, s, deployment, lift), Color("e0d6b5", 0.74), 0.6 * s)
		var sum_value := i / 5.0
		start_u = maxf(0.0, sum_value - 1.0)
		finish_u = minf(1.0, sum_value)
		for j in 4:
			var a := lerpf(start_u, finish_u, j / 4.0)
			var b := lerpf(start_u, finish_u, (j + 1) / 4.0)
			g.line(_net_point(a, sum_value - a, s, deployment, lift), _net_point(b, sum_value - b, s, deployment, lift), Color("d0c6a6", 0.78), 0.6 * s)
	for side in [0.0, 1.0]:
		for i in 4:
			g.line(_net_point(side, i / 4.0, s, deployment, lift), _net_point(side, (i + 1) / 4.0, s, deployment, lift), ROPE, 0.8 * s)
	for i in 6:
		g.line(_net_point(i / 6.0, 1.0, s, deployment, lift), _net_point((i + 1) / 6.0, 1.0, s, deployment, lift), ROPE, 1.0 * s)
		var float_point := _net_point(i / 5.0, 1.0, s, deployment, lift)
		g.cylinder(float_point, float_point + Vector3(0, 0, 0.8 * s), 0.8 * s, WOOD_LIGHT, 6)
	g.end_surface_group()

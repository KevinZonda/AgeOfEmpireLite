extends RefCounted
class_name RtsNavalVisual

# Shared directional solids for the battlefield, portraits and unit gallery.
const Geometry = preload("res://scripts/entities/visuals/siege_geometry.gd")
const Hull = preload("res://scripts/entities/visuals/naval_hull_geometry.gd")
const Equipment = preload("res://scripts/entities/visuals/naval_equipment_geometry.gd")
const Fishing = preload("res://scripts/entities/visuals/fishing_boat_visual.gd")
const KINDS = ["warship", "springald_ship", "incendiary_ship", "arrow_ship", "transport_ship"]
const CACHE_LIMIT := 512
static var model_cache: Dictionary = {}
var last_key: Array = []
var model
var fishing_renderer := Fishing.new()

static func handles(kind: String) -> bool:
	return kind in KINDS or kind == "fishing_boat"

func geometry(state):
	if state.kind == "fishing_boat": return fishing_renderer.geometry(state)
	var key := [state.kind, state.view_mode_25d, state.facing_direction, state.player_color, state.radius, clampi(state.passenger_count, 0, 6) if state.kind == "transport_ship" else 0]
	if key == last_key and model != null: return model
	last_key = key
	if model_cache.has(key):
		model = model_cache[key]
		return model
	model = Geometry.new()
	model.configure(state)
	Hull.build(model, state)
	Equipment.build(model, state)
	model.finish()
	if model_cache.size() >= CACHE_LIMIT: model_cache.clear()
	model_cache[key] = model
	return model

func bounds(state) -> Rect2:
	if state.kind == "fishing_boat": return fishing_renderer.bounds(state)
	var g = geometry(state)
	var result: Rect2 = g.bounds.grow(1.5)
	var s: float = state.radius / 19.0
	for point in Hull.outline(state.kind, 1.05, s): result = result.expand(g.project(point))
	if state.visual_moving:
		var stern := 0.0
		for point in Hull.outline(state.kind, 1.0, s): stern = maxf(stern, point.y)
		for side in [-1.0, 1.0]:
			result = result.expand(g.project(Vector3(side * 21.0 * s, stern + 24.0 * s, 0)))
	return result

func draw(canvas: CanvasItem, state) -> void:
	geometry(state).draw(canvas)

func draw_shadow(canvas: CanvasItem, state) -> void:
	if state.kind == "fishing_boat":
		fishing_renderer.draw_shadow(canvas, state)
		return
	var g = geometry(state)
	var s: float = state.radius / 19.0
	var outline: Array[Vector3] = Hull.outline(state.kind, 1.015, s)
	var footprint := PackedVector2Array()
	for point in outline: footprint.append(g.project(point))
	canvas.draw_colored_polygon(footprint, Color("173c40", 0.18))
	# Broken pale waterlines hug the hull; moving ships leave a stern wake.
	for side in [-1.0, 1.0]:
		var edge := outline[2] if side > 0 else outline[outline.size() - 2]
		var drift: float = sin(state.visual_phase * 1.4 + side) * 0.5 * s
		_water_line(canvas, g, [edge + Vector3(side * (0.8 * s + drift), -7 * s, 0), edge + Vector3(side * (1.3 * s + drift), 0, 0), edge + Vector3(side * 0.8 * s, 7 * s, 0)], Color("b8e7df", 0.48))
	if state.visual_moving:
		var stern := 0.0
		for point in outline: stern = maxf(stern, point.y)
		var pulse: float = fposmod(state.visual_phase * 1.8, 6.0) * s
		for side in [-1.0, 1.0]:
			_water_line(canvas, g, [Vector3(side * 5 * s, stern, 0), Vector3(side * 11 * s, stern + 8 * s + pulse, 0), Vector3(side * 18 * s, stern + 16 * s + pulse, 0)], Color("c8eee5", 0.44))
		_water_line(canvas, g, [Vector3(-3 * s, stern + 7 * s + pulse, 0), Vector3(0, stern + 9 * s + pulse, 0), Vector3(3 * s, stern + 7 * s + pulse, 0)], Color("d7f5e9", 0.32))

static func _water_line(canvas: CanvasItem, g, points: Array, color: Color) -> void:
	var pixels := PackedVector2Array()
	for point in points: pixels.append(g.project(point))
	canvas.draw_polyline(pixels, color, 0.95, true)

func overlay_y(state) -> float:
	return minf(-25.0, geometry(state).bounds.position.y - 7.0)

func draw_portrait(canvas: CanvasItem, kind: String, color: Color, area: Rect2, passenger_count := 0) -> void:
	var state := legacy_state(kind, 19.0, color, true, passenger_count)
	var extent := bounds(state).grow(1.0)
	var fit := minf(area.size.x / maxf(extent.size.x, 1.0), area.size.y / maxf(extent.size.y, 1.0))
	canvas.draw_set_transform_matrix(Transform2D(0.0, Vector2.ONE * fit, 0.0, area.get_center() - extent.get_center() * fit))
	draw_shadow(canvas, state)
	draw(canvas, state)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)

static func legacy_state(kind: String, radius: float, color: Color, iso: bool, passenger_count := 0) -> Dictionary:
	return {"kind": kind, "radius": radius, "player_color": color, "view_mode_25d": iso, "facing_direction": Vector2(1, 1).normalized(), "visual_phase": 0.0, "visual_moving": false, "visual_action": "", "action_progress": 0.0, "passenger_count": passenger_count}

static func draw_2d(canvas: CanvasItem, kind: String, radius: float, team: Color, passenger_count := 0) -> void:
	var renderer := new()
	renderer.draw(canvas, legacy_state(kind, radius, team, false, passenger_count))

static func draw_25d(canvas: CanvasItem, kind: String, radius: float, team: Color, passenger_count := 0) -> void:
	var renderer := new()
	renderer.draw(canvas, legacy_state(kind, radius, team, true, passenger_count))

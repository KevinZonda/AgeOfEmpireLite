extends RefCounted

const Geometry = preload("res://scripts/entities/visuals/siege_geometry.gd")
const Throwing = preload("res://scripts/entities/visuals/siege_throwing_models.gd")
const Protected = preload("res://scripts/entities/visuals/siege_protected_models.gd")
const Gunpowder = preload("res://scripts/entities/visuals/siege_gunpowder_models.gd")
const KINDS = ["battering_ram", "trebuchet", "mangonel", "springald", "bombard", "cannon", "nest_of_bees", "siege_tower"]

# Vehicles share immutable surfaces across units and UI previews. Wheel motion
# draws independently; firing uses a bounded cache of articulated poses.
static var idle_cache: Dictionary = {}
static var action_cache: Dictionary = {}
var last_key: Array = []
var model

static func handles(kind: String) -> bool: return kind in KINDS

func geometry(state):
	var idle: bool = state.visual_action != "attack"
	var key := [state.kind, state.view_mode_25d, state.facing_direction, state.player_color, state.siege_deployed, state.passenger_count > 0, state.visual_action, snappedf(state.action_progress, 0.025) if not idle else 0.0, state.action_released if not idle else false, snappedf(state.release_elapsed, 0.015) if not idle else -1.0]
	if key == last_key and model != null: return model
	last_key = key
	if idle_cache.has(key):
		model = idle_cache[key]
		return model
	if action_cache.has(key):
		model = action_cache[key]
		return model
	model = Geometry.new()
	model.configure(state)
	match state.kind:
		"battering_ram", "siege_tower": Protected.build(model, state)
		"trebuchet", "mangonel", "springald": Throwing.build(model, state)
		"bombard", "cannon", "nest_of_bees": Gunpowder.build(model, state)
	model.finish()
	if idle:
		if idle_cache.size() >= 256: idle_cache.clear()
		idle_cache[key] = model
	else:
		if action_cache.size() >= 256: action_cache.clear()
		action_cache[key] = model
	return model

func draw(canvas: CanvasItem, state) -> void:
	geometry(state).draw(canvas, state.visual_phase if state.visual_moving else 0.0)

func draw_shadow(canvas: CanvasItem, state) -> void:
	var g = geometry(state)
	var half_length := 22.0 if state.kind in ["battering_ram", "trebuchet", "siege_tower"] else 19.0
	var half_width := 18.0 if state.kind != "springald" else 15.0
	var points := PackedVector2Array()
	for i in 16:
		var angle := TAU * i / 16.0
		points.append(g.project(Vector3(cos(angle) * half_width, sin(angle) * half_length, 0)))
	canvas.draw_colored_polygon(points, Color("172322", 0.43))

func overlay_y(state) -> float:
	return minf(-22.0, geometry(state).bounds.position.y - 8.0)

func draw_portrait(canvas: CanvasItem, kind: String, color: Color, area: Rect2) -> void:
	var state := legacy_state(kind, 20.0, color, 0.0, true)
	var g = geometry(state)
	var extent: Vector2 = g.bounds.size
	var fit := minf(area.size.x / maxf(extent.x, 1.0), area.size.y / maxf(extent.y, 1.0))
	var origin: Vector2 = area.get_center() - g.bounds.get_center() * fit
	canvas.draw_set_transform_matrix(Transform2D(0.0, Vector2.ONE * fit, 0.0, origin))
	draw_shadow(canvas, state)
	g.draw(canvas)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)

static func legacy_state(kind: String, radius: float, color: Color, swing: float, iso: bool) -> Dictionary:
	return {"kind": kind, "radius": radius, "player_color": color, "view_mode_25d": iso, "facing_direction": Vector2(1, 1).normalized(), "visual_phase": 0.0, "visual_moving": false, "visual_action": "attack" if swing > 0.0 else "", "action_progress": 0.5 if swing > 0.0 else 0.0, "action_released": swing > 0.0, "release_elapsed": (1.0 - swing) * 0.24, "siege_deployed": false, "passenger_count": 0}

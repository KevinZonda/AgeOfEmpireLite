class_name RtsSelectionPortrait
extends Control

const Siege = preload("res://scripts/entities/visuals/siege_visual.gd")
const NavalVisual = preload("res://scripts/entities/visuals/naval_visual.gd")
const Figure = preload("res://scripts/entities/visuals/unit_figure_visual.gd")
const UnitVisualState = preload("res://scripts/entities/visuals/unit_visual_state.gd")
const DeerVisual = preload("res://scripts/entities/visuals/deer_visual.gd")
const LivestockVisual = preload("res://scripts/entities/visuals/livestock_visual.gd")
const BuildingVisual = preload("res://scripts/entities/visuals/building_visual.gd")
const RefinedGeometry = preload("res://scripts/entities/visuals/refined_building_geometry.gd")

var subject: Node2D
var owner_tint := Color("8a9a8e")
var figure_renderer := Figure.new()
var siege_renderer := Siege.new()
var humanoid_state := UnitVisualState.new()
var building_portrait_renderer := BuildingVisual.new()

func _ready() -> void:
	custom_minimum_size = Vector2(102, 142)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func show_subject(value: Node2D, tint: Color = Color("8a9a8e")) -> void:
	subject = value
	owner_tint = tint
	queue_redraw()

func _draw() -> void:
	var frame := Rect2(Vector2.ZERO, size)
	draw_rect(frame, Color("1b1814"))
	draw_rect(Rect2(Vector2(5, 5), size - Vector2(10, 10)), Color("594328"))
	draw_rect(Rect2(Vector2(9, 9), size - Vector2(18, 18)), Color("b69a69"))
	draw_rect(Rect2(Vector2(12, 12), size - Vector2(24, 24)), Color("343d38"))
	draw_rect(frame, Color("b9995b"), false, 2)
	for x in [6.0, size.x - 6.0]:
		for y in [6.0, size.y - 6.0]:
			draw_circle(Vector2(x, y), 2.5, Color("e2c987"))
	if subject == null or not is_instance_valid(subject):
		_draw_empty()
	elif subject is RtsBuilding:
		_draw_building()
	elif subject is RtsResource:
		_draw_resource()
	else:
		_draw_unit()

func _draw_resource() -> void:
	var resource: RtsResource = subject
	var center := Vector2(size.x * 0.5, size.y * 0.5)
	var color := Color("79a64e")
	match resource.kind:
		"wood": color = Color("397948")
		"gold": color = Color("e4c359")
		"stone": color = Color("9b9f9e")
	if resource.appearance in ["deer", "boar", "sheep"]:
		# Share the map silhouettes, but use a stable side-on portrait pose.
		# Fit inside the frame even when UI scaling changes the portrait size.
		var portrait_scale := minf((size.x - 30.0) / 54.0, (size.y - 30.0) / 70.0)
		var alive := resource.wildlife_hp > 0.0
		var ground := center + Vector2(0, 23.0 if alive else 4.0)
		var figure := Transform2D(0.0, Vector2.ONE * portrait_scale, 0.0, ground)
		draw_set_transform_matrix(figure * Transform2D(0.0, Vector2(1, 0.35), 0.0, Vector2.ZERO))
		draw_circle(Vector2.ZERO, 17.0, Color("1c2524", 0.5))
		if resource.appearance == "deer":
			if alive: DeerVisual.draw(self, figure, Vector2.RIGHT, 0.0, 0.0, 0.0, 0.0, 0.0)
			else: DeerVisual.draw_carcass(self, figure)
		else:
			var wool: Color = Color("efead9") if resource.claimed_by < 0 or resource.game == null else resource.game.player_color(resource.claimed_by).lightened(0.35)
			LivestockVisual.draw(self, figure, resource.appearance, Vector2.RIGHT, 0.0, 0.0, 0.0, 0.0, 0.0, alive, wool)
		draw_set_transform_matrix(Transform2D.IDENTITY)
	elif resource.appearance == "fish":
		draw_colored_polygon(PackedVector2Array([center + Vector2(-30, 0), center + Vector2(5, -18), center + Vector2(31, 0), center + Vector2(5, 18)]), Color("c5d9cf"))
	elif resource.kind == "gold" or resource.kind == "stone":
		var fraction := clampf(float(resource.amount) / maxf(float(resource.initial_amount), 1.0), 0.0, 1.0)
		var fit := minf((size.x - 30.0) / 60.0, (size.y - 30.0) / 58.0)
		draw_set_transform_matrix(Transform2D(0.0, Vector2.ONE * fit, 0.0, center + Vector2(0, 16 * fit)))
		if resource.ore_visual != null:
			resource.ore_visual.draw_ground(self)
			resource.ore_visual.draw(self, true, fraction)
		draw_set_transform_matrix(Transform2D.IDENTITY)
	elif resource.vegetation_visual != null:
		var is_tree := resource.kind == "wood"
		var visual := resource.vegetation_visual
		var fit := minf((size.x - 30.0) / (66.0 * visual.width), (size.y - 30.0) / (80.0 * visual.height)) if is_tree else minf((size.x - 30.0) / 58.0, (size.y - 30.0) / 42.0)
		var ground := center + Vector2(0, 34.0 * visual.height * fit if is_tree else 10.0 * fit)
		draw_set_transform_matrix(Transform2D(0.0, Vector2.ONE * fit, 0.0, ground))
		visual.draw_ground(self, is_tree)
		visual.draw(self, is_tree, true, float(resource.amount) / maxf(resource.initial_amount, 1))
		draw_set_transform_matrix(Transform2D.IDENTITY)
	else:
		draw_circle(center, 28, color)
		if resource.appearance == "berry":
			for offset in [Vector2(-12, -9), Vector2(10, -13), Vector2(9, 12), Vector2(-14, 11)]: draw_circle(center + offset, 6, Color("d86b65"))

func _draw_empty() -> void:
	var center := Vector2(size.x * 0.5, size.y * 0.48)
	draw_colored_polygon(PackedVector2Array([center + Vector2(-23, -22), center + Vector2(23, -22), center + Vector2(19, 23), center + Vector2(0, 35), center + Vector2(-19, 23)]), Color("766a50"))
	draw_line(center + Vector2(-15, -14), center + Vector2(15, 23), Color("c9b580"), 3)
	draw_line(center + Vector2(15, -14), center + Vector2(-15, 23), Color("c9b580"), 3)

func _draw_building() -> void:
	var center := Vector2(size.x * 0.5, size.y * 0.5)
	var building: RtsBuilding = subject
	if RefinedGeometry.handles(building.kind):
		building_portrait_renderer.draw_refined_portrait(self, building.visual_snapshot(), Rect2(Vector2(17, 20), size - Vector2(34, 40)))
		return
	draw_colored_polygon(PackedVector2Array([Vector2(14, 105), Vector2(88, 105), Vector2(78, 119), Vector2(24, 119)]), Color("202622", 0.65))
	draw_rect(Rect2(center + Vector2(-29, -20), Vector2(58, 47)), Color("a99570"))
	draw_rect(Rect2(center + Vector2(-34, -32), Vector2(68, 14)), owner_tint.darkened(0.23))
	draw_colored_polygon(PackedVector2Array([center + Vector2(-39, -32), center + Vector2(0, -57), center + Vector2(39, -32)]), Color("7a4d37"))
	draw_line(center + Vector2(-31, -31), center + Vector2(31, -31), Color("dbc795"), 2)
	draw_rect(Rect2(center + Vector2(-9, 1), Vector2(18, 26)), Color("42352a"))
	for x in [-22.0, 17.0]:
		draw_rect(Rect2(center + Vector2(x, -13), Vector2(6, 11)), Color("394a4a"))
	if building.kind == "town_center" or building.kind == "keep":
		for x in [-29.0, 18.0]:
			draw_rect(Rect2(center + Vector2(x, -40), Vector2(11, 13)), Color("b9a77d"))

func _draw_unit() -> void:
	var center := Vector2(size.x * 0.5, size.y * 0.5)
	var unit: RtsUnit = subject
	var naval: bool = unit.stats.get("tags", []).has("naval")
	var siege: bool = unit.stats.get("tags", []).has("siege")
	if Figure.handles(unit.kind):
		_draw_figure_portrait(unit, center)
		return
	if siege:
		_draw_siege(unit.kind, center)
		return
	draw_colored_polygon(PackedVector2Array([center + Vector2(-32, 39), center + Vector2(-23, 33), center + Vector2(23, 33), center + Vector2(32, 39), center + Vector2(23, 45), center + Vector2(-23, 45)]), Color("1c2524", 0.65))
	if naval:
		draw_set_transform_matrix(Transform2D(Vector2(1.5, 0), Vector2(0, 1.5), center + Vector2(0, 21)))
		NavalVisual.draw_25d(self, unit.kind, float(unit.stats.get("radius", 18.0)), owner_tint, unit.passengers.size())
		draw_set_transform_matrix(Transform2D.IDENTITY)

func _draw_figure_portrait(unit: RtsUnit, center: Vector2) -> void:
	# Stable three-quarter pose with the same proportions and equipment as the map.
	humanoid_state.kind = unit.kind
	humanoid_state.player_color = owner_tint
	humanoid_state.gather_kind = unit.gather_kind
	humanoid_state.hunting = unit.kind == "villager" and unit.visual_action == "hunt"
	humanoid_state.carries_relic = unit.carried_relic != null
	humanoid_state.shield_active = unit.shield_timer > 0.0
	var dimensions := Figure.portrait_dimensions(humanoid_state)
	var portrait_scale := minf(1.65, minf((size.x - 30.0) / dimensions.x, (size.y - 30.0) / dimensions.y))
	var ground_y := (dimensions.y * 0.5 - 8.0) * portrait_scale if unit.stats.get("tags", []).has("cavalry") else 31.0
	var figure := Transform2D(0.0, Vector2.ONE * portrait_scale, 0.0, center + Vector2(0, ground_y))
	draw_set_transform_matrix(figure * Transform2D(0.0, Vector2(1, 0.4), 0.0, Vector2.ZERO))
	Figure.draw_shadow(self, humanoid_state)
	draw_set_transform_matrix(figure)
	figure_renderer.draw(self, humanoid_state)
	draw_set_transform_matrix(Transform2D.IDENTITY)

func _draw_siege(kind: String, _center: Vector2) -> void:
	siege_renderer.draw_portrait(self, kind, owner_tint, Rect2(Vector2(17, 20), size - Vector2(34, 40)))

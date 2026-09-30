extends RefCounted

# Building drawing and visual hit testing share this geometry/cache. Inputs are
# explicit display values, so memories do not need simulation entities.
const Geometry = preload("res://scripts/entities/visuals/building_geometry.gd")

const VisualState = preload("res://scripts/entities/visuals/building_visual_state.gd")
const FilledPolygon = preload("res://scripts/entities/visuals/filled_polygon.gd")
const CivicGeometry = preload("res://scripts/entities/visuals/civic_building_geometry.gd")
const WonderVisual = preload("res://scripts/entities/visuals/wonder_visual.gd")
const FarmVisual = preload("res://scripts/entities/visuals/farm_visual.gd")
const LandmarkVisual = preload("res://scripts/entities/visuals/landmark_visual.gd")
const WesternLandmark = preload("res://scripts/entities/visuals/western_landmark_visual.gd")
const ChineseLandmark = preload("res://scripts/entities/visuals/chinese_landmark_visual.gd")
const EconomyBuildingVisual = preload("res://scripts/entities/visuals/economy_building_visual.gd")
const IndustryBuildingVisual = preload("res://scripts/entities/visuals/industry_building_visual.gd")
const DockBuildingVisual = preload("res://scripts/entities/visuals/dock_building_visual.gd")
const KeepMonasteryVisual = preload("res://scripts/entities/visuals/keep_monastery_visual.gd")
const FortificationVisual = preload("res://scripts/entities/visuals/fortification_visual.gd")
const RefinedGeometry = preload("res://scripts/entities/visuals/refined_building_geometry.gd")

var canvas_item: CanvasItem
var state: VisualState
var landmark_geometry
var landmark_geometry_key := ""
var refined_geometry
var refined_geometry_key: Array = []
var farm_geometry
var farm_geometry_key: Array = []
var civic_geometry
var civic_geometry_key: Array = []
var portrait_mesh
var civic_portrait_faces: Array[Dictionary] = []
var civic_portrait_bounds := Rect2()

func contains_icon_visual(snapshot: VisualState, world_point: Vector2, canvas: Transform2D) -> bool:
	state = snapshot
	if not state.show_building_icons: return false
	var side := state.icon_size()
	if not state.view_mode_25d:
		var center := Vector2(0, -state.dimensions.y * 0.5 - side * 0.5 - 8.0)
		return Rect2(center - Vector2.ONE * side * 0.5, Vector2.ONE * side).has_point(world_point - state.world_position)
	var construction_ratio := 1.0 - state.build_remaining / maxf(state.build_total, 0.1)
	var height := _visible_height(construction_ratio)
	var terrain_lift := RtsIsoProjection.world_delta(canvas, Vector2(0, -state.foundation_height * state.zoom))
	var screen_point := canvas.basis_xform(world_point - state.world_position - terrain_lift)
	var center := Vector2(0, -height * state.zoom - side * 0.5 - 9.0)
	return Rect2(center - Vector2.ONE * side * 0.5, Vector2.ONE * side).has_point(screen_point)

func contains_topdown_visual(snapshot: VisualState, world_point: Vector2) -> bool:
	state = snapshot
	if Rect2(state.world_position - state.dimensions * 0.5, state.dimensions).has_point(world_point): return true
	var construction_ratio := 1.0 - state.build_remaining / maxf(state.build_total, 0.1)
	if state.kind != "dock" or construction_ratio < 0.65: return false
	var local_point := world_point - state.world_position
	for polygon in _civic_display_geometry().flat_faces:
		if Geometry2D.is_point_in_polygon(local_point, polygon["points"]): return true
	return false

func contains_isometric_visual(snapshot: VisualState, world_point: Vector2, canvas: Transform2D) -> bool:
	state = snapshot
	if Rect2(state.world_position - state.dimensions * 0.5, state.dimensions).has_point(world_point): return true
	var bounds := Rect2(-state.dimensions * 0.5, state.dimensions)
	var nw := bounds.position
	var ne := Vector2(bounds.end.x, bounds.position.y)
	var se := bounds.end
	var sw := Vector2(bounds.position.x, bounds.end.y)
	var terrain_lift := RtsIsoProjection.world_delta(canvas, Vector2(0, -state.foundation_height * state.zoom))
	var construction_ratio := 1.0 - state.build_remaining / maxf(state.build_total, 0.1)
	var height := state.isometric_height() * (0.25 + 0.75 * construction_ratio)
	var lift := terrain_lift + RtsIsoProjection.world_delta(canvas, Vector2(0, -height * state.zoom))
	var local_point := world_point - state.world_position
	if state.kind in ["keep", "outpost"] and construction_ratio >= 0.65:
		if Geometry2D.is_point_in_polygon(local_point - terrain_lift, KeepMonasteryVisual.selection_hull(state, canvas)): return true
	if state.kind.ends_with("_gate") and construction_ratio >= 0.65:
		var top := terrain_lift + RtsIsoProjection.world_delta(canvas, Vector2(0, -(height + state.visual_feature_height()) * state.zoom))
		var hull := Geometry2D.convex_hull(PackedVector2Array([nw + terrain_lift, ne + terrain_lift, se + terrain_lift, sw + terrain_lift, nw + top, ne + top, se + top, sw + top]))
		if Geometry2D.is_point_in_polygon(local_point, hull): return true
	if (state.kind in ["landmark", "wonder"] or CivicGeometry.handles(state.kind) or state.kind == "dock") and construction_ratio < 0.65:
		var scaffold_top := terrain_lift + RtsIsoProjection.world_delta(canvas, Vector2(0, -_visible_height(construction_ratio) * state.zoom))
		var hull := Geometry2D.convex_hull(PackedVector2Array([nw + terrain_lift, ne + terrain_lift, se + terrain_lift, sw + terrain_lift, nw + scaffold_top, ne + scaffold_top, se + scaffold_top, sw + scaffold_top]))
		return Geometry2D.is_point_in_polygon(local_point, hull)
	if (state.kind in ["farm", "dock"] or CivicGeometry.handles(state.kind)) and construction_ratio >= 0.65:
		for polygon in _civic_display_geometry().projected_faces(canvas, state.zoom, terrain_lift):
			if Geometry2D.is_point_in_polygon(local_point, polygon["points"]): return true
		return false
	if RefinedGeometry.handles(state.kind) and construction_ratio >= 0.65:
		for polygon in _refined_geometry().projected_faces(canvas, state.zoom, terrain_lift):
			if Geometry2D.is_point_in_polygon(local_point, polygon["points"]): return true
		return false
	if not state.kind in ["landmark", "wonder", "farm", "barracks", "archery_range", "stable", "palisade_wall", "stone_wall", "palisade_gate", "stone_gate"]:
		var center := (nw + ne + se + sw) * 0.25
		var overhang := 1.1 if state.civilization == "Chinese" else 1.06
		var a := center + (nw - center) * overhang + lift
		var b := center + (ne - center) * overhang + lift
		var c := center + (se - center) * overhang + lift
		var d := center + (sw - center) * overhang + lift
		var roof_rise := 15.0 if state.kind in ["town_center", "landmark", "keep", "wonder"] else 9.0
		var rise := RtsIsoProjection.world_delta(canvas, Vector2(0, -roof_rise * state.zoom))
		var ridge_back := (a + b) * 0.5 + rise
		var ridge_front := (d + c) * 0.5 + rise
		for facet in [PackedVector2Array([a, ridge_back, ridge_front, d]), PackedVector2Array([ridge_back, b, c, ridge_front])]:
			if Geometry2D.is_point_in_polygon(local_point, facet): return true
	for polygon in [
		PackedVector2Array([nw + lift, ne + lift, se + lift, sw + lift]),
		PackedVector2Array([ne + lift, se + lift, se + terrain_lift, ne + terrain_lift]),
		PackedVector2Array([sw + lift, se + lift, se + terrain_lift, sw + terrain_lift]),
	]:
		if Geometry2D.is_point_in_polygon(local_point, polygon): return true
	if state.kind in ["barracks", "archery_range"] and construction_ratio >= 0.65:
		var floor_lift := terrain_lift + (lift - terrain_lift) * 0.18
		var towers: Array = [[0.14, 0.75, 0.15, 0.17, 32.0], [0.72, 0.75, 0.15, 0.17, 32.0]] if state.kind == "barracks" else [[0.76, 0.09, 0.18, 0.24, 38.0]]
		for tower in towers:
			var u: float = tower[0]
			var v: float = tower[1]
			var width: float = tower[2]
			var depth: float = tower[3]
			var up := RtsIsoProjection.world_delta(canvas, Vector2(0, -float(tower[4]) * state.zoom))
			var corners := PackedVector2Array([
				Geometry.point(nw, ne, sw, u, v) + floor_lift,
				Geometry.point(nw, ne, sw, u + width, v) + floor_lift,
				Geometry.point(nw, ne, sw, u + width, v + depth) + floor_lift,
				Geometry.point(nw, ne, sw, u, v + depth) + floor_lift,
			])
			var hull_points := PackedVector2Array(corners)
			for corner in corners: hull_points.append(corner + up)
			hull_points.append(Geometry.point(nw, ne, sw, u + width * 0.5, v + depth * 0.5) + floor_lift + up + RtsIsoProjection.world_delta(canvas, Vector2(0, -16.0 * state.zoom)))
			if Geometry2D.is_point_in_polygon(local_point, Geometry2D.convex_hull(hull_points)): return true
	if state.kind in ["landmark", "wonder"] and construction_ratio >= 0.65:
		for polygon in _landmark_geometry().projected_faces(canvas, state.zoom, terrain_lift if state.kind == "wonder" else lift):
			if Geometry2D.is_point_in_polygon(local_point, polygon["points"]): return true
	return false

func draw(item: CanvasItem, snapshot: VisualState) -> void:
	canvas_item = item
	state = snapshot
	if state.view_mode_25d:
		_draw_isometric()
		return
	var bounds := Rect2(-state.dimensions * 0.5, state.dimensions)
	var palette := _architecture_palette()
	var wall_color: Color = palette["wall"]
	var construction_ratio := 1.0 - state.build_remaining / maxf(state.build_total, 0.1)
	var art_kind := state.visual_kind()
	if not (art_kind.ends_with("_wall") or art_kind.ends_with("_gate")) and not ((RefinedGeometry.handles(state.kind) or state.kind in ["farm", "dock", "wonder"] or CivicGeometry.handles(state.kind)) and state.is_complete()):
		canvas_item.draw_rect(bounds, Color("272d2a"))
		canvas_item.draw_rect(bounds.grow(-4), wall_color.darkened(0.28) if not state.is_complete() else wall_color)
	if state.damage_flash_timer > 0.0: canvas_item.draw_rect(bounds.grow(-2), Color("f8ca91", state.damage_flash_timer * 1.4), false, 3.0)
	if not state.is_complete():
		var timber := Color("b99b6e")
		for side in [-1.0, 1.0]:
			var post_x: float = side * (state.dimensions.x * 0.5 - 7.0)
			canvas_item.draw_line(Vector2(post_x, state.dimensions.y * 0.43), Vector2(post_x, -state.dimensions.y * 0.43 * construction_ratio), timber, 3.0)
			canvas_item.draw_line(Vector2(post_x, state.dimensions.y * 0.2), Vector2(-post_x, -state.dimensions.y * 0.28 * construction_ratio), Color(timber, 0.72), 2.0)
		if construction_ratio < 0.65:
			canvas_item.draw_rect(Rect2(-state.dimensions.x * 0.42, -state.dimensions.y * 0.35, state.dimensions.x * 0.84, 5), Color("6d5a41"))
	if construction_ratio >= 0.65:
		_draw_topdown_architecture(bounds, palette)
		if state.kind == "landmark" or state.kind == "wonder": _draw_topdown_landmark(bounds, palette)
	var side := state.icon_size()
	_draw_building_icon(Vector2(0, -state.dimensions.y * 0.5 - side * 0.5 - 8.0), side)
	var font := ThemeDB.fallback_font
	if font != null and state.show_building_names:
		var font_size: int = state.caption_size
		var canvas := canvas_item.get_viewport().get_canvas_transform()
		var label_anchor := canvas.basis_xform(Vector2(-state.dimensions.x * 0.5, state.dimensions.y * (0.64 if state.kind == "dock" else 0.5)))
		canvas_item.draw_set_transform_matrix(RtsIsoProjection.upright(canvas, Vector2.ZERO))
		canvas_item.draw_string(font, label_anchor + Vector2(0, font_size + 2), state.label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
		canvas_item.draw_set_transform_matrix(Transform2D.IDENTITY)
	var bar_y := -state.dimensions.y * 0.5 - side - 18.0
	if state.show_health_bar:
		canvas_item.draw_rect(Rect2(-state.dimensions.x * 0.5, bar_y, state.dimensions.x, 5), Color("432e2b"))
		canvas_item.draw_rect(Rect2(-state.dimensions.x * 0.5, bar_y, state.dimensions.x * clampf(state.hp / state.max_hp, 0.0, 1.0), 5), Color("7fd47a"))
	if not state.is_complete():
		canvas_item.draw_arc(Vector2.ZERO, 14, 0, TAU * (1.0 - state.build_remaining / maxf(state.build_total, 0.1)), 20, Color.WHITE, 3)
	if state.has_production:
		canvas_item.draw_circle(Vector2(state.dimensions.x * 0.5 - 4, -state.dimensions.y * 0.5 + 4), 8, Color("e5c45d"))

func _draw_isometric() -> void:
	var bounds := Rect2(-state.dimensions * 0.5, state.dimensions)
	var art_kind := state.visual_kind()
	var fortification := art_kind.ends_with("_wall") or art_kind.ends_with("_gate")
	var open_yard := state.kind != "landmark" and art_kind in ["town_center", "barracks", "archery_range", "stable", "market", "university", "dock", "lumber_camp", "mining_camp", "mill", "scout_camp", "blacksmith", "siege_workshop", "keep", "monastery", "outpost"]
	var palette := _architecture_palette()
	var color: Color = palette["wall"]
	var construction_ratio := 1.0 - state.build_remaining / maxf(state.build_total, 0.1)
	if not state.is_complete(): color = color.darkened(0.32)
	var nw := bounds.position
	var ne := Vector2(bounds.end.x, bounds.position.y)
	var se := bounds.end
	var sw := Vector2(bounds.position.x, bounds.end.y)
	var height := state.isometric_height() * (0.25 + 0.75 * construction_ratio)
	var canvas := canvas_item.get_viewport().get_canvas_transform()
	var lift := RtsIsoProjection.world_delta(canvas, Vector2(0, -height * state.zoom))
	var wall_lift := lift * 0.18 if open_yard else lift
	var terrain_lift := RtsIsoProjection.world_delta(canvas, Vector2(0, -state.foundation_height * state.zoom))
	var ne_ground := RtsIsoProjection.world_delta(canvas, Vector2(0, -state.corner_heights[0] * state.zoom)) - terrain_lift
	var se_ground := RtsIsoProjection.world_delta(canvas, Vector2(0, -state.corner_heights[1] * state.zoom)) - terrain_lift
	var sw_ground := RtsIsoProjection.world_delta(canvas, Vector2(0, -state.corner_heights[2] * state.zoom)) - terrain_lift
	canvas_item.draw_set_transform_matrix(Transform2D(0.0, terrain_lift))
	if ne_ground.length() + se_ground.length() + sw_ground.length() > 0.5:
		FilledPolygon.draw(canvas_item, PackedVector2Array([ne, se, se + se_ground, ne + ne_ground]), Color("625d4e"))
		FilledPolygon.draw(canvas_item, PackedVector2Array([sw, se, se + se_ground, sw + sw_ground]), Color("817866"))
		canvas_item.draw_line(sw + sw_ground, se + se_ground, Color("3a3c32", 0.75), 1.4)
	if not fortification and state.kind != "dock":
		FilledPolygon.draw(canvas_item, PackedVector2Array([nw, ne, se, sw]), Color("273a30", 0.65))
	if height > 0.0 and not fortification and not RefinedGeometry.handles(state.kind) and state.kind not in ["farm", "dock", "wonder"] and not CivicGeometry.handles(state.kind):
		FilledPolygon.draw(canvas_item, PackedVector2Array([ne + wall_lift, se + wall_lift, se, ne]), color.darkened(0.26))
		FilledPolygon.draw(canvas_item, PackedVector2Array([sw + wall_lift, se + wall_lift, se, sw]), color)
		canvas_item.draw_polyline(PackedVector2Array([ne + wall_lift, se + wall_lift, se, ne, ne + wall_lift]), Color("1c2829"), 2.0)
		canvas_item.draw_polyline(PackedVector2Array([sw + wall_lift, se + wall_lift, se, sw, sw + wall_lift]), Color("1c2829"), 2.0)
	var roof_color: Color = Color("a79f89") if state.kind == "landmark" else palette["roof"]
	if art_kind == "farm": roof_color = Color("735035")
	if construction_ratio >= 0.65:
		if not fortification and not RefinedGeometry.handles(state.kind) and state.kind not in ["farm", "dock", "wonder"] and not CivicGeometry.handles(state.kind):
			FilledPolygon.draw(canvas_item, PackedVector2Array([nw + wall_lift, ne + wall_lift, se + wall_lift, sw + wall_lift]), roof_color if not open_yard else palette["timber"])
			canvas_item.draw_polyline(PackedVector2Array([nw + wall_lift, ne + wall_lift, se + wall_lift, sw + wall_lift, nw + wall_lift]), Color("1f2929"), 2.0)
		_draw_iso_architecture(art_kind, nw, ne, se, sw, lift, palette, canvas)
		if state.kind == "landmark" or state.kind == "wonder": _draw_iso_landmark_architecture(lift, canvas)
	else:
		var scaffold := Color("c5a878")
		var scaffold_lift := RtsIsoProjection.world_delta(canvas, Vector2(0, -_visible_height(construction_ratio) * state.zoom)) if state.kind in ["landmark", "wonder"] or CivicGeometry.handles(state.kind) or state.kind == "dock" else lift * maxf(0.2, construction_ratio)
		for corner in [nw, ne, sw, se]:
			canvas_item.draw_line(corner, corner + scaffold_lift, scaffold, 2.2)
		canvas_item.draw_line(nw + scaffold_lift * 0.65, se + scaffold_lift * 0.65, Color(scaffold, 0.82), 2.0)
		canvas_item.draw_line(ne + scaffold_lift * 0.65, sw + scaffold_lift * 0.65, Color(scaffold, 0.82), 2.0)
	if state.damage_flash_timer > 0.0:
		canvas_item.draw_polyline(PackedVector2Array([nw + lift, ne + lift, se + lift, sw + lift, nw + lift]), Color("f7d091", state.damage_flash_timer * 3.4), 3.0)
	# Labels and status bars are drawn in screen space so they stay legible.
	canvas_item.draw_set_transform_matrix(RtsIsoProjection.upright(canvas, terrain_lift))
	var side := state.icon_size()
	var icon_height := _visible_height(construction_ratio)
	_draw_building_icon(Vector2(0, -icon_height * state.zoom - side * 0.5 - 9.0), side)
	var font := ThemeDB.fallback_font
	if font != null and state.show_building_names:
		var label := state.label
		var font_size: int = state.caption_size
		var label_width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		canvas_item.draw_string(font, Vector2(-label_width * 0.5, canvas.basis_xform(se).y + font_size + 5.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
	var bar_width := minf(72.0, state.dimensions.x * 0.8)
	var bar_y: float = minf(-icon_height * state.zoom - state.dimensions.y * 0.25 - 16.0, -icon_height * state.zoom - side - 20.0)
	if state.show_health_bar:
		canvas_item.draw_rect(Rect2(-bar_width * 0.5, bar_y, bar_width, 5), Color("422f2d"))
		canvas_item.draw_rect(Rect2(-bar_width * 0.5, bar_y, bar_width * clampf(state.hp / state.max_hp, 0.0, 1.0), 5), Color("7fd47a"))
	if not state.is_complete(): canvas_item.draw_arc(Vector2.ZERO, 14, 0, TAU * (1.0 - state.build_remaining / maxf(state.build_total, 0.1)), 20, Color.WHITE, 3)
	if state.has_production: canvas_item.draw_circle(Vector2(bar_width * 0.5 + 5, bar_y + 2), 6, Color("e5c45d"))
	canvas_item.draw_set_transform_matrix(Transform2D.IDENTITY)

func _architecture_palette() -> Dictionary:
	match state.civilization:
		"French":
			return {"wall": Color("d1c4a4"), "timber": Color("706451"), "roof": Color("647989"), "roof_dark": Color("405463"), "trim": Color("e1d6b4")}
		"Chinese":
			return {"wall": Color("d8c8a3"), "timber": Color("924d3b"), "roof": Color("53645d"), "roof_dark": Color("344740"), "trim": Color("e2ba75")}
		_:
			var palette := {"wall": Color("cbbd99"), "timber": Color("674c39"), "roof": Color("75564a"), "roof_dark": Color("503b37"), "trim": Color("e3d0a0")}
			if state.kind in ["town_center", "lumber_camp", "mining_camp", "mill", "blacksmith", "siege_workshop"]:
				palette["roof"] = Color("59636a")
				palette["roof_dark"] = Color("3b454b")
			return palette

func _draw_topdown_architecture(bounds: Rect2, palette: Dictionary) -> void:
	if state.kind in ["landmark", "wonder"]: return
	if CivicGeometry.handles(state.kind):
		for polygon in _civic_geometry().flat_faces:
			FilledPolygon.draw(canvas_item, polygon["points"], polygon["color"])
		return
	var art_kind := state.visual_kind()
	if RefinedGeometry.handles(state.kind):
		for polygon in _refined_geometry().flat_faces:
			FilledPolygon.draw(canvas_item, polygon["points"], polygon["color"])
		return
	if state.kind not in ["landmark", "wonder"] and art_kind in ["town_center", "mill", "lumber_camp"]:
		EconomyBuildingVisual.draw_topdown(canvas_item, art_kind, bounds, palette, state.player_color, state.civilization)
		return
	if state.kind not in ["landmark", "wonder"] and art_kind in ["mining_camp", "blacksmith", "siege_workshop"]:
		IndustryBuildingVisual.draw_topdown(canvas_item, art_kind, bounds, palette, state.player_color, state.civilization)
		return
	if state.kind not in ["landmark", "wonder"] and art_kind == "dock":
		DockBuildingVisual.draw_topdown(canvas_item, bounds, palette, state.player_color, state.civilization)
		return
	if state.kind not in ["landmark", "wonder"] and art_kind in ["keep", "monastery", "outpost"]:
		KeepMonasteryVisual.draw_topdown(canvas_item, art_kind, bounds, palette, state.player_color, state.civilization)
		return
	if art_kind.ends_with("_wall") or art_kind.ends_with("_gate"):
		FortificationVisual.draw_topdown(canvas_item, art_kind, bounds, palette, state.player_color, state.civilization, state.wall_vertical)
		return
	var roof_bounds := bounds.grow(-6.0)
	var roof: Color = palette["roof"]
	var dark: Color = palette["roof_dark"]
	var trim: Color = palette["trim"]
	var wall: Color = palette["wall"]
	if art_kind == "farm":
		for polygon in _farm_geometry().flat_faces:
			FilledPolygon.draw(canvas_item, polygon["points"], polygon["color"])
		return
	if art_kind in ["keep", "outpost"]:
		canvas_item.draw_rect(roof_bounds, wall.darkened(0.33))
		canvas_item.draw_rect(roof_bounds, trim, false, 3.0)
		for portion in [0.12, 0.36, 0.6, 0.84]:
			var x := lerpf(roof_bounds.position.x, roof_bounds.end.x, portion)
			canvas_item.draw_rect(Rect2(x - 3, roof_bounds.position.y - 2, 6, 5), trim)
			canvas_item.draw_rect(Rect2(x - 3, roof_bounds.end.y - 3, 6, 5), trim)
		canvas_item.draw_rect(Rect2(-5, -5, 10, 10), dark)
		return
	if art_kind in ["barracks", "archery_range", "stable"]:
		_draw_topdown_military_structure(art_kind, roof_bounds, palette)
		return
	if state.kind != "landmark" and art_kind == "university":
		_draw_topdown_university(roof_bounds, palette)
		return
	if art_kind in ["market", "scout_camp"]:
		_draw_topdown_open_structure(art_kind, roof_bounds, palette)
		return
	var top_left := roof_bounds.position
	var top_right := Vector2(roof_bounds.end.x, roof_bounds.position.y)
	var bottom_left := Vector2(roof_bounds.position.x, roof_bounds.end.y)
	var bottom_right := roof_bounds.end
	var ridge_left := Vector2(roof_bounds.position.x + 5, roof_bounds.get_center().y)
	var ridge_right := Vector2(roof_bounds.end.x - 5, roof_bounds.get_center().y)
	FilledPolygon.draw(canvas_item, PackedVector2Array([top_left, top_right, ridge_right, ridge_left]), roof.lightened(0.11))
	FilledPolygon.draw(canvas_item, PackedVector2Array([ridge_left, ridge_right, bottom_right, bottom_left]), roof)
	canvas_item.draw_line(ridge_left, ridge_right, trim, 2.0)
	canvas_item.draw_polyline(PackedVector2Array([top_left, top_right, bottom_right, bottom_left, top_left]), dark, 1.7)
	for portion in [0.28, 0.55, 0.8]:
		var x := lerpf(roof_bounds.position.x, roof_bounds.end.x, portion)
		canvas_item.draw_line(Vector2(x, roof_bounds.position.y + 2), Vector2(x, roof_bounds.get_center().y - 2), Color(dark, 0.46), 1.0)
		canvas_item.draw_line(Vector2(x, roof_bounds.get_center().y + 2), Vector2(x, roof_bounds.end.y - 2), Color(dark, 0.36), 1.0)
	canvas_item.draw_line(Vector2(roof_bounds.position.x, roof_bounds.end.y + 2), Vector2(roof_bounds.end.x, roof_bounds.end.y + 2), state.player_color, 3.0)
	match art_kind:
		"town_center", "palace", "wonder", "university", "monastery":
			var tower := Rect2(Vector2(-7, -8), Vector2(14, 16))
			canvas_item.draw_rect(tower, palette["wall"])
			canvas_item.draw_rect(tower.grow(-2), dark)
			canvas_item.draw_rect(tower, trim, false, 1.3)
			if art_kind in ["wonder", "palace"]:
				canvas_item.draw_rect(tower.grow(4), trim, false, 2.0)
		"house", "siege_workshop":
			canvas_item.draw_rect(Rect2(roof_bounds.position + Vector2(9, 8), Vector2(7, 8)), palette["timber"])
	if art_kind == "siege_workshop":
		canvas_item.draw_rect(Rect2(roof_bounds.position.x + 7, roof_bounds.end.y - 17, roof_bounds.size.x - 14, 11), dark)
	elif art_kind == "monastery":
		canvas_item.draw_line(Vector2(0, -14), Vector2(0, 14), trim, 3.0)
		canvas_item.draw_line(Vector2(-9, 0), Vector2(9, 0), trim, 3.0)

func _draw_topdown_open_structure(art_kind: String, roof_bounds: Rect2, palette: Dictionary) -> void:
	if art_kind == "market":
		_draw_topdown_market(roof_bounds, palette)
		return
	var timber: Color = palette["timber"]
	var trim: Color = palette["trim"]
	canvas_item.draw_rect(roof_bounds, Color("ab9b74"))
	for portion in [0.17, 0.38, 0.59, 0.8]:
		var y := lerpf(roof_bounds.position.y, roof_bounds.end.y, portion)
		canvas_item.draw_line(Vector2(roof_bounds.position.x, y), Vector2(roof_bounds.end.x, y), Color(timber, 0.35), 1.0)
	match art_kind:
		"scout_camp":
			var center := roof_bounds.get_center()
			FilledPolygon.draw(canvas_item, PackedVector2Array([center + Vector2(-13, 7), center + Vector2(0, -12), center + Vector2(13, 7)]), Color("a98458"))
			canvas_item.draw_circle(center + Vector2(0, 14), 3.0, Color("d88a47"))

func _draw_topdown_market(bounds: Rect2, palette: Dictionary) -> void:
	canvas_item.draw_rect(bounds, Color("a99b77"))
	var hall := Geometry.rect(bounds, 0.06, 0.08, 0.55, 0.34)
	var hall_palette := palette.duplicate()
	if state.civilization == "English":
		hall_palette["roof"] = Color("59656a")
		hall_palette["roof_dark"] = Color("404b51")
	_draw_topdown_military_roof(hall, hall_palette)
	for box in [Geometry.rect(bounds, 0.06, 0.58, 0.35, 0.22), Geometry.rect(bounds, 0.66, 0.53, 0.28, 0.27)]:
		canvas_item.draw_rect(box, palette["trim"])
		for stripe in [0.2, 0.55, 0.9]:
			var x := lerpf(box.position.x, box.end.x, stripe)
			canvas_item.draw_line(Vector2(x, box.position.y), Vector2(x, box.end.y), state.player_color, box.size.x * 0.16)
		canvas_item.draw_rect(box, palette["timber"], false, 1.5)
	var cross := bounds.position + bounds.size * Vector2(0.87, 0.37)
	canvas_item.draw_rect(Rect2(cross - Vector2(5, 4), Vector2(10, 8)), palette["wall"].darkened(0.18))
	canvas_item.draw_rect(Rect2(cross - Vector2(2, 7), Vector2(4, 7)), palette["trim"])
	for spot in [Vector2(0.83, 0.86), Vector2(0.2, 0.88)]:
		canvas_item.draw_circle(bounds.position + bounds.size * spot, 2.8, Color("9b6b3d"))

func _university_palette(palette: Dictionary) -> Dictionary:
	var college := palette.duplicate()
	if state.civilization == "English":
		college["wall"] = Color("b8ae96")
		college["timber"] = Color("6b5849")
		college["roof"] = Color("586168")
		college["roof_dark"] = Color("414a51")
		college["trim"] = Color("d8c9ab")
	return college

func _draw_topdown_university(bounds: Rect2, palette: Dictionary) -> void:
	var college := _university_palette(palette)
	canvas_item.draw_rect(bounds, Color("9b9b83"))
	var court := Geometry.rect(bounds, 0.3, 0.37, 0.4, 0.52)
	canvas_item.draw_rect(court, Color("b6ad96"))
	for box in [
		Geometry.rect(bounds, 0.07, 0.07, 0.86, 0.3),
		Geometry.rect(bounds, 0.07, 0.34, 0.23, 0.5),
		Geometry.rect(bounds, 0.7, 0.34, 0.23, 0.5),
	]:
		canvas_item.draw_rect(box.grow(2), college["wall"])
		_draw_topdown_military_roof(box, college)
	var tower := Geometry.rect(bounds, 0.41, 0.18, 0.18, 0.22)
	canvas_item.draw_rect(tower, college["wall"].darkened(0.28))
	canvas_item.draw_rect(tower.grow(-2), college["roof_dark"])
	canvas_item.draw_rect(tower, palette["trim"], false, 1.5)

func _draw_topdown_military_roof(box: Rect2, palette: Dictionary, ridge_along_width := true) -> void:
	var roof: Color = palette["roof"]
	var dark: Color = palette["roof_dark"]
	var trim: Color = palette["trim"]
	canvas_item.draw_rect(box, roof)
	canvas_item.draw_rect(box, dark, false, 1.6)
	if ridge_along_width:
		canvas_item.draw_line(Vector2(box.position.x + 2, box.get_center().y), Vector2(box.end.x - 2, box.get_center().y), trim, 2.0)
	else:
		canvas_item.draw_line(Vector2(box.get_center().x, box.position.y + 2), Vector2(box.get_center().x, box.end.y - 2), trim, 2.0)

func _draw_topdown_military_structure(art_kind: String, bounds: Rect2, palette: Dictionary) -> void:
	var timber: Color = palette["timber"]
	var trim: Color = palette["trim"]
	var wall: Color = palette["wall"]
	canvas_item.draw_rect(bounds, Color("a99b77"))
	for portion in [0.16, 0.37, 0.58, 0.79]:
		var y := lerpf(bounds.position.y, bounds.end.y, portion)
		canvas_item.draw_line(Vector2(bounds.position.x, y), Vector2(bounds.end.x, y), Color(timber, 0.28), 1.0)
	match art_kind:
		"barracks":
			_draw_topdown_military_roof(Geometry.rect(bounds, 0.08, 0.07, 0.84, 0.27), palette)
			_draw_topdown_military_roof(Geometry.rect(bounds, 0.08, 0.28, 0.23, 0.46), palette, false)
			_draw_topdown_military_roof(Geometry.rect(bounds, 0.69, 0.28, 0.23, 0.46), palette, false)
			for u in [0.22, 0.78]:
				var tower := Geometry.rect(bounds, u - 0.1, 0.72, 0.2, 0.2)
				canvas_item.draw_rect(tower, palette["roof_dark"])
				canvas_item.draw_rect(tower, trim, false, 2.0)
			var yard := Geometry.rect(bounds, 0.35, 0.42, 0.3, 0.39)
			for u in [0.42, 0.58]:
				var target := bounds.position + bounds.size * Vector2(u, 0.53)
				canvas_item.draw_line(target, target + Vector2(0, 11), timber, 2.0)
				canvas_item.draw_line(target + Vector2(-4, 5), target + Vector2(4, 5), timber, 1.6)
				canvas_item.draw_circle(target, 2.5, wall)
			canvas_item.draw_line(yard.position + Vector2(0, yard.size.y), yard.end, trim, 2.0)
		"archery_range":
			_draw_topdown_military_roof(Geometry.rect(bounds, 0.06, 0.07, 0.7, 0.27), palette)
			_draw_topdown_military_roof(Geometry.rect(bounds, 0.06, 0.29, 0.22, 0.45), palette, false)
			var tower := Geometry.rect(bounds, 0.72, 0.1, 0.22, 0.24)
			canvas_item.draw_rect(tower, palette["roof_dark"])
			canvas_item.draw_rect(tower, trim, false, 2.0)
			for u in [0.4, 0.59, 0.78]:
				var target := bounds.position + bounds.size * Vector2(u, 0.57)
				canvas_item.draw_line(target + Vector2(0, 5), target + Vector2(0, 13), timber, 1.6)
				canvas_item.draw_circle(target, 5.2, wall)
				canvas_item.draw_circle(target, 3.3, Color("ad654a"))
				canvas_item.draw_circle(target, 1.4, trim)
				canvas_item.draw_line(target + Vector2(0, 14), target + Vector2(0, 20), trim, 1.2)
		"stable":
			_draw_topdown_military_roof(Geometry.rect(bounds, 0.06, 0.06, 0.88, 0.3), palette)
			_draw_topdown_military_roof(Geometry.rect(bounds, 0.06, 0.32, 0.24, 0.38), palette, false)
			var paddock := Geometry.rect(bounds, 0.34, 0.43, 0.55, 0.43)
			canvas_item.draw_rect(paddock, timber, false, 2.0)
			for u in [0.46, 0.74]:
				var stall := bounds.position + bounds.size * Vector2(u, 0.47)
				canvas_item.draw_line(stall, stall + Vector2(0, 11), timber, 1.5)
			var horse := bounds.position + bounds.size * Vector2(0.59, 0.66)
			FilledPolygon.draw(canvas_item, PackedVector2Array([horse + Vector2(-7, -3), horse + Vector2(5, -3), horse + Vector2(8, 1), horse + Vector2(-5, 4)]), Color("765039"))
			canvas_item.draw_circle(horse + Vector2(9, 0), 2.5, Color("765039"))

func _draw_topdown_landmark(bounds: Rect2, palette: Dictionary) -> void:
	if state.kind == "wonder":
		WonderVisual.draw_topdown(canvas_item, bounds, state.civilization, palette, state.player_color)
		return
	if state.kind == "landmark":
		if ChineseLandmark.draw_topdown(canvas_item, bounds, state.landmark_id, palette, state.player_color): return
		if WesternLandmark.draw_topdown(canvas_item, bounds, state.landmark_id, palette, state.player_color): return
	var forms: Array = []
	if state.kind == "wonder":
		forms = [[0.5, 0.5, 0.65, 0.65, "dome"], [0.16, 0.16, 0.17, 0.17, "spire"], [0.84, 0.16, 0.17, 0.17, "spire"], [0.16, 0.84, 0.17, 0.17, "spire"], [0.84, 0.84, 0.17, 0.17, "spire"]]
	else:
		match state.landmark_id:
			"eng_council_hall": forms = [[0.5, 0.44, 0.73, 0.42, "gable"], [0.5, 0.8, 0.57, 0.13, "portico"]]
			"eng_kings_mill": forms = [[0.5, 0.52, 0.37, 0.67, "gable"], [0.22, 0.46, 0.19, 0.24, "spire"], [0.78, 0.46, 0.19, 0.24, "spire"]]
			"eng_white_tower": forms = [[0.5, 0.5, 0.52, 0.58, "flat"]]
			"eng_abbey": forms = [[0.5, 0.43, 0.34, 0.71, "gable"], [0.23, 0.75, 0.2, 0.19, "spire"], [0.77, 0.75, 0.2, 0.19, "spire"]]
			"eng_berkshire_fortress": forms = [[0.5, 0.5, 0.35, 0.35, "flat"], [0.15, 0.15, 0.22, 0.22, "flat"], [0.85, 0.15, 0.22, 0.22, "flat"], [0.15, 0.85, 0.22, 0.22, "flat"], [0.85, 0.85, 0.22, 0.22, "flat"]]
			"eng_wynguard_palace": forms = [[0.5, 0.46, 0.47, 0.55, "hip"], [0.17, 0.55, 0.2, 0.32, "spire"], [0.83, 0.55, 0.2, 0.32, "spire"]]
			"fr_school_of_cavalry": forms = [[0.19, 0.5, 0.23, 0.73, "gable"], [0.81, 0.5, 0.23, 0.73, "gable"], [0.5, 0.17, 0.38, 0.22, "hip"]]
			"fr_chamber_of_commerce": forms = [[0.18, 0.34, 0.28, 0.42, "awning"], [0.5, 0.34, 0.28, 0.42, "awning"], [0.82, 0.34, 0.28, 0.42, "awning"], [0.5, 0.75, 0.3, 0.22, "hip"]]
			"fr_royal_institute": forms = [[0.2, 0.6, 0.29, 0.4, "gable"], [0.8, 0.6, 0.29, 0.4, "gable"], [0.5, 0.4, 0.39, 0.42, "dome"]]
			"fr_guild_hall": forms = [[0.2, 0.62, 0.27, 0.37, "gable"], [0.8, 0.62, 0.27, 0.37, "gable"], [0.5, 0.38, 0.35, 0.38, "spire"]]
			"fr_red_palace": forms = [[0.5, 0.5, 0.38, 0.38, "red"], [0.16, 0.17, 0.2, 0.2, "red"], [0.84, 0.17, 0.2, 0.2, "red"], [0.16, 0.83, 0.2, 0.2, "red"], [0.84, 0.83, 0.2, 0.2, "red"]]
			"fr_college_of_artillery": forms = [[0.5, 0.49, 0.64, 0.51, "gable"], [0.22, 0.2, 0.14, 0.16, "chimney"], [0.78, 0.2, 0.14, 0.16, "chimney"]]
			"zh_imperial_academy": forms = [[0.5, 0.24, 0.44, 0.29, "gable"], [0.17, 0.53, 0.24, 0.44, "pagoda"], [0.83, 0.53, 0.24, 0.44, "pagoda"]]
			"zh_barbican": forms = [[0.5, 0.34, 0.39, 0.3, "flat"], [0.2, 0.67, 0.23, 0.32, "pagoda"], [0.8, 0.67, 0.23, 0.32, "pagoda"]]
			"zh_clocktower": forms = [[0.5, 0.49, 0.38, 0.43, "clock"], [0.16, 0.65, 0.18, 0.29, "gable"], [0.84, 0.65, 0.18, 0.29, "gable"]]
			"zh_imperial_palace": forms = [[0.5, 0.28, 0.7, 0.31, "pagoda"], [0.5, 0.67, 0.56, 0.31, "pagoda"]]
			"zh_gatehouse": forms = [[0.5, 0.45, 0.48, 0.4, "pagoda"], [0.14, 0.53, 0.22, 0.36, "flat"], [0.86, 0.53, 0.22, 0.36, "flat"]]
			"zh_spirit_way": forms = [[0.5, 0.36, 0.59, 0.31, "pagoda"], [0.2, 0.65, 0.16, 0.26, "flat"], [0.8, 0.65, 0.16, 0.26, "flat"]]
	var roof: Color = palette["roof"]
	var trim: Color = palette["trim"]
	var dark: Color = palette["roof_dark"]
	for form in forms:
		var p := bounds.position + bounds.size * Vector2(float(form[0]), float(form[1]))
		var dimensions := bounds.size * Vector2(float(form[2]), float(form[3]))
		var box := Rect2(p - dimensions * 0.5, dimensions)
		var style: String = form[4]
		var fill: Color = Color("a45e4e") if style == "red" else Color("78736b") if style == "chimney" else state.player_color.darkened(0.13) if style == "awning" else roof
		canvas_item.draw_rect(box, fill)
		canvas_item.draw_rect(box, trim, false, 2.0)
		if style in ["gable", "hip", "pagoda", "spire"]:
			canvas_item.draw_line(Vector2(box.position.x + 3, box.get_center().y), Vector2(box.end.x - 3, box.get_center().y), trim, 2.0)
		if style in ["spire", "pagoda"]: canvas_item.draw_rect(box.grow(-5), dark, false, 1.6)
		if style == "dome":
			canvas_item.draw_circle(p, minf(dimensions.x, dimensions.y) * 0.32, trim)
			canvas_item.draw_circle(p, minf(dimensions.x, dimensions.y) * 0.22, roof.lightened(0.28))
		if style == "clock":
			canvas_item.draw_circle(p, 9.0, trim)
			canvas_item.draw_circle(p, 6.0, dark)
		if style == "flat" or style == "red":
			for x in [box.position.x + 4, box.end.x - 4]:
				for y in [box.position.y + 4, box.end.y - 4]: canvas_item.draw_rect(Rect2(x - 2, y - 2, 4, 4), trim)

func _draw_iso_architecture(art_kind: String, nw: Vector2, ne: Vector2, se: Vector2, sw: Vector2, lift: Vector2, palette: Dictionary, canvas: Transform2D) -> void:
	if state.kind in ["landmark", "wonder"]: return
	if CivicGeometry.handles(state.kind):
		for polygon in _civic_geometry().projected_faces(canvas, state.zoom, Vector2.ZERO):
			FilledPolygon.draw(canvas_item, polygon["points"], polygon["color"])
		return
	if RefinedGeometry.handles(state.kind):
		for polygon in _refined_geometry().projected_faces(canvas, state.zoom, Vector2.ZERO):
			FilledPolygon.draw(canvas_item, polygon["points"], polygon["color"])
		return
	if state.kind not in ["landmark", "wonder"] and art_kind in ["town_center", "mill", "lumber_camp"]:
		EconomyBuildingVisual.draw_iso(canvas_item, art_kind, nw, ne, se, sw, lift, palette, state.player_color, state.civilization, canvas, state.zoom)
		return
	if state.kind not in ["landmark", "wonder"] and art_kind in ["mining_camp", "blacksmith", "siege_workshop"]:
		IndustryBuildingVisual.draw_iso(canvas_item, art_kind, nw, ne, se, sw, lift, palette, state.player_color, state.civilization, canvas, state.zoom)
		return
	if state.kind not in ["landmark", "wonder"] and art_kind == "dock":
		DockBuildingVisual.draw_iso(canvas_item, nw, ne, se, sw, lift, palette, state.player_color, state.civilization, canvas, state.zoom)
		return
	if state.kind not in ["landmark", "wonder"] and art_kind in ["keep", "monastery", "outpost"]:
		KeepMonasteryVisual.draw_iso(canvas_item, art_kind, nw, ne, se, sw, lift, palette, state.player_color, state.civilization, canvas, state.zoom)
		return
	if art_kind.ends_with("_wall") or art_kind.ends_with("_gate"):
		FortificationVisual.draw_iso(canvas_item, art_kind, nw, ne, se, sw, lift, palette, state.player_color, state.civilization, state.wall_vertical, canvas, state.zoom)
		return
	if art_kind == "farm":
		_draw_iso_farm(nw, ne, se, sw, lift)
		return
	if state.kind != "landmark" and art_kind in ["barracks", "archery_range", "stable"]:
		_draw_iso_military_structure(art_kind, nw, ne, sw, lift, palette, canvas)
		return
	if state.kind != "landmark" and art_kind == "university":
		_draw_iso_university(nw, ne, sw, lift, palette, canvas)
		return
	if state.kind != "landmark" and art_kind in ["market", "scout_camp"]:
		_draw_iso_open_structure(art_kind, nw, ne, se, sw, lift, palette, canvas)
		return
	var timber: Color = palette["timber"]
	var trim: Color = palette["trim"]
	var front_mid := (sw + se) * 0.5
	var door_half := (se - sw) * (0.11 if art_kind in ["house", "outpost"] else 0.16)
	var door_top := front_mid + lift * 0.72
	var door := PackedVector2Array([door_top - door_half, door_top + door_half, front_mid + door_half, front_mid - door_half])
	FilledPolygon.draw(canvas_item, door, Color("322f2a"))
	canvas_item.draw_polyline(PackedVector2Array([door_top - door_half, door_top + door_half, front_mid + door_half]), trim, 1.5)
	canvas_item.draw_line(front_mid + lift * 0.3, front_mid + lift * 0.57, timber.lightened(0.24), 1.5)
	for portion in [0.08, 0.92]:
		var front_post := sw.lerp(se, portion)
		var side_post := ne.lerp(se, portion)
		canvas_item.draw_line(front_post, front_post + lift, timber, 2.5)
		canvas_item.draw_line(side_post, side_post + lift, timber.darkened(0.16), 2.0)
	for portion in [0.23, 0.77]:
		var window_base := sw.lerp(se, portion) + lift * 0.38
		var window_top := window_base + lift * 0.24
		var half_width := (se - sw) * 0.045
		FilledPolygon.draw(canvas_item, PackedVector2Array([window_top - half_width, window_top + half_width, window_base + half_width, window_base - half_width]), Color("3c4e4c"))
		canvas_item.draw_line(window_base - half_width, window_base + half_width, trim, 1.6)
	# The faction color is an accent; the wall and roof retain their material colors.
	canvas_item.draw_line(sw.lerp(se, 0.08) + lift * 0.88, sw.lerp(se, 0.92) + lift * 0.88, state.player_color, 3.0)
	# Landmark wings share a flat terrace; no generic pitched roof or tower
	# may intersect the bespoke geometry drawn above it.
	if state.kind in ["landmark", "wonder"]: return
	_draw_iso_roof(art_kind, nw, ne, se, sw, lift, palette, canvas)
	_draw_iso_building_feature(art_kind, nw, ne, se, sw, lift, palette, canvas)

func _draw_iso_open_structure(art_kind: String, nw: Vector2, ne: Vector2, se: Vector2, sw: Vector2, lift: Vector2, palette: Dictionary, canvas: Transform2D) -> void:
	if art_kind == "market":
		_draw_iso_market(nw, ne, sw, lift, palette, canvas)
		return
	var floor_lift := lift * 0.18
	var timber: Color = palette["timber"]
	var trim: Color = palette["trim"]
	FilledPolygon.draw(canvas_item, PackedVector2Array([nw + floor_lift, ne + floor_lift, se + floor_lift, sw + floor_lift]), Color("a69a74"))
	for portion in [0.16, 0.34, 0.52, 0.7, 0.88]:
		canvas_item.draw_line(nw.lerp(sw, portion) + floor_lift, ne.lerp(se, portion) + floor_lift, Color(timber, 0.32), 1.0)
	if art_kind == "scout_camp":
		var base_left := nw.lerp(sw, 0.36).lerp(ne.lerp(se, 0.36), 0.25) + floor_lift
		var base_right := nw.lerp(sw, 0.75).lerp(ne.lerp(se, 0.75), 0.76) + floor_lift
		var peak := (base_left + base_right) * 0.5 + RtsIsoProjection.world_delta(canvas, Vector2(0, -15.0 * state.zoom))
		FilledPolygon.draw(canvas_item, PackedVector2Array([base_left, peak, base_right]), Color("a98458"))
		canvas_item.draw_line(base_left, peak, trim, 1.4)
		canvas_item.draw_line(peak, base_right, timber, 1.4)
		canvas_item.draw_circle(sw.lerp(se, 0.22) + floor_lift, 3.2, Color("dd9251"))
		return

func _draw_iso_market(nw: Vector2, ne: Vector2, sw: Vector2, lift: Vector2, palette: Dictionary, canvas: Transform2D) -> void:
	var floor_lift := lift * 0.18
	var up := RtsIsoProjection.world_delta(canvas, Vector2(0, -23.0 * state.zoom))
	var rise := RtsIsoProjection.world_delta(canvas, Vector2(0, -7.0 * state.zoom))
	var timber: Color = palette["timber"]
	var wall: Color = palette["wall"]
	var deck_a := Geometry.point(nw, ne, sw, 0.03, 0.03) + floor_lift
	var deck_b := Geometry.point(nw, ne, sw, 0.97, 0.03) + floor_lift
	var deck_c := Geometry.point(nw, ne, sw, 0.97, 0.97) + floor_lift
	var deck_d := Geometry.point(nw, ne, sw, 0.03, 0.97) + floor_lift
	FilledPolygon.draw(canvas_item, PackedVector2Array([deck_a, deck_b, deck_c, deck_d]), Color("a99b7c"))
	var a := Geometry.point(nw, ne, sw, 0.06, 0.07) + floor_lift
	var b := Geometry.point(nw, ne, sw, 0.59, 0.07) + floor_lift
	var c := Geometry.point(nw, ne, sw, 0.59, 0.42) + floor_lift
	var d := Geometry.point(nw, ne, sw, 0.06, 0.42) + floor_lift
	FilledPolygon.draw(canvas_item, PackedVector2Array([b + up, c + up, c, b]), wall.darkened(0.19))
	FilledPolygon.draw(canvas_item, PackedVector2Array([d + up, c + up, c, d]), wall.lightened(0.04))
	var ridge_left := (a + d) * 0.5 + up + rise
	var ridge_right := (b + c) * 0.5 + up + rise
	var hall_roof: Color = Color("59656a") if state.civilization == "English" else palette["roof"]
	FilledPolygon.draw(canvas_item, PackedVector2Array([a + up, b + up, ridge_right, ridge_left]), hall_roof.darkened(0.2))
	FilledPolygon.draw(canvas_item, PackedVector2Array([ridge_left, ridge_right, c + up, d + up]), hall_roof)
	canvas_item.draw_line(ridge_left, ridge_right, palette["trim"], 1.8)
	for u in [0.13, 0.32, 0.51]:
		var foot := Geometry.point(nw, ne, sw, u, 0.42) + floor_lift
		canvas_item.draw_line(foot, foot + up * 0.88, timber, 2.2)
		var window := foot + up * 0.58
		canvas_item.draw_line(window, window + up * 0.18, Color("343d3b"), 3.2)
		canvas_item.draw_line(window + up * 0.2, window + up * 0.23, palette["trim"], 3.6)
	canvas_item.draw_line(d + up * 0.47, c + up * 0.47, timber, 2.0)
	canvas_item.draw_line(d + up * 0.08, c + up * 0.08, timber, 2.2)
	for spot in [Vector2(0.86, 0.83), Vector2(0.24, 0.91)]:
		var goods := Geometry.point(nw, ne, sw, spot.x, spot.y) + floor_lift
		canvas_item.draw_circle(goods, 3.8, Color("7a5437"))
		canvas_item.draw_circle(goods + Vector2(0, -1), 2.5, Color("c69f64"))
	# The stone marker stands behind the right stall, so draw it first.
	var cross := Geometry.point(nw, ne, sw, 0.87, 0.37) + floor_lift
	var cross_u := (ne - nw) * 0.075
	var cross_v := (sw - nw) * 0.075
	FilledPolygon.draw(canvas_item, PackedVector2Array([cross - cross_u - cross_v, cross + cross_u - cross_v, cross + cross_u + cross_v, cross - cross_u + cross_v]), wall.darkened(0.2))
	var cross_top := cross + RtsIsoProjection.world_delta(canvas, Vector2(0, -19.0 * state.zoom))
	canvas_item.draw_line(cross, cross_top, wall.lightened(0.1), 4.0)
	canvas_item.draw_circle(cross_top, 2.4, palette["trim"])
	_draw_iso_market_stall(nw, ne, sw, floor_lift, canvas, palette, 0.07, 0.62, 0.36, 0.24)
	_draw_iso_market_stall(nw, ne, sw, floor_lift, canvas, palette, 0.69, 0.52, 0.25, 0.25)

func _draw_iso_market_stall(nw: Vector2, ne: Vector2, sw: Vector2, floor_lift: Vector2, canvas: Transform2D, palette: Dictionary, u: float, v: float, width: float, depth: float) -> void:
	var a := Geometry.point(nw, ne, sw, u, v) + floor_lift
	var b := Geometry.point(nw, ne, sw, u + width, v) + floor_lift
	var c := Geometry.point(nw, ne, sw, u + width, v + depth) + floor_lift
	var d := Geometry.point(nw, ne, sw, u, v + depth) + floor_lift
	var high := RtsIsoProjection.world_delta(canvas, Vector2(0, -14.0 * state.zoom))
	var low := high * 0.76
	for corner in [a, b]:
		canvas_item.draw_line(corner, corner + high, palette["timber"], 2.0)
	for stripe in 5:
		var left := float(stripe) / 5.0
		var right := float(stripe + 1) / 5.0
		FilledPolygon.draw(canvas_item, PackedVector2Array([a.lerp(b, left) + high, a.lerp(b, right) + high, d.lerp(c, right) + low, d.lerp(c, left) + low]), state.player_color if stripe % 2 == 0 else palette["trim"])
	canvas_item.draw_line(d + low, c + low, palette["timber"], 1.4)
	for corner in [d, c]:
		canvas_item.draw_line(corner, corner + low, palette["timber"], 2.0)

func _draw_iso_university(nw: Vector2, ne: Vector2, sw: Vector2, lift: Vector2, palette: Dictionary, canvas: Transform2D) -> void:
	var floor_lift := lift * 0.18
	var college := _university_palette(palette)
	var deck_a := Geometry.point(nw, ne, sw, 0.04, 0.04) + floor_lift
	var deck_b := Geometry.point(nw, ne, sw, 0.96, 0.04) + floor_lift
	var deck_c := Geometry.point(nw, ne, sw, 0.96, 0.95) + floor_lift
	var deck_d := Geometry.point(nw, ne, sw, 0.04, 0.95) + floor_lift
	FilledPolygon.draw(canvas_item, PackedVector2Array([deck_a, deck_b, deck_c, deck_d]), Color("a49b85"))
	var court_a := Geometry.point(nw, ne, sw, 0.3, 0.37) + floor_lift
	var court_b := Geometry.point(nw, ne, sw, 0.7, 0.37) + floor_lift
	var court_c := Geometry.point(nw, ne, sw, 0.7, 0.91) + floor_lift
	var court_d := Geometry.point(nw, ne, sw, 0.3, 0.91) + floor_lift
	FilledPolygon.draw(canvas_item, PackedVector2Array([court_a, court_b, court_c, court_d]), Color("b9ae94"))
	_draw_iso_military_block(nw, ne, sw, floor_lift, canvas, college, 0.07, 0.07, 0.86, 0.3, 27.0, "gable_u", false)
	_draw_iso_university_tower(nw, ne, sw, floor_lift, canvas, college)
	_draw_iso_military_block(nw, ne, sw, floor_lift, canvas, college, 0.07, 0.32, 0.23, 0.51, 26.0, "gable_v", false)
	_draw_iso_military_block(nw, ne, sw, floor_lift, canvas, college, 0.7, 0.32, 0.23, 0.51, 26.0, "gable_v", false)

func _draw_iso_university_tower(nw: Vector2, ne: Vector2, sw: Vector2, floor_lift: Vector2, canvas: Transform2D, palette: Dictionary) -> void:
	var a := Geometry.point(nw, ne, sw, 0.41, 0.16) + floor_lift
	var b := Geometry.point(nw, ne, sw, 0.59, 0.16) + floor_lift
	var c := Geometry.point(nw, ne, sw, 0.59, 0.38) + floor_lift
	var d := Geometry.point(nw, ne, sw, 0.41, 0.38) + floor_lift
	var up := RtsIsoProjection.world_delta(canvas, Vector2(0, -44.0 * state.zoom))
	var rise := RtsIsoProjection.world_delta(canvas, Vector2(0, -7.0 * state.zoom))
	FilledPolygon.draw(canvas_item, PackedVector2Array([b + up, c + up, c, b]), palette["wall"].darkened(0.18))
	FilledPolygon.draw(canvas_item, PackedVector2Array([d + up, c + up, c, d]), palette["wall"])
	var peak := (a + b + c + d) * 0.25 + up + rise
	FilledPolygon.draw(canvas_item, PackedVector2Array([a + up, b + up, peak, d + up]), palette["roof_dark"])
	FilledPolygon.draw(canvas_item, PackedVector2Array([b + up, c + up, peak]), palette["roof"])
	FilledPolygon.draw(canvas_item, PackedVector2Array([d + up, c + up, peak]), palette["roof"])
	var window := (d + c) * 0.5
	canvas_item.draw_line(window + up * 0.7, window + up * 0.84, palette["trim"], 4.0)
	canvas_item.draw_line(window + up * 0.72, window + up * 0.82, Color("37403e"), 2.3)

func _draw_iso_upright_disc(center: Vector2, radius: float, color: Color, canvas: Transform2D) -> void:
	var screen_radius: float = radius * state.zoom
	var horizontal := RtsIsoProjection.world_delta(canvas, Vector2(screen_radius, 0))
	var vertical := RtsIsoProjection.world_delta(canvas, Vector2(0, screen_radius))
	var outline := PackedVector2Array()
	for step in 24:
		var angle := TAU * float(step) / 24.0
		outline.append(center + horizontal * cos(angle) + vertical * sin(angle))
	FilledPolygon.draw(canvas_item, outline, color)

func _draw_iso_military_block(nw: Vector2, ne: Vector2, sw: Vector2, floor_lift: Vector2, canvas: Transform2D, palette: Dictionary, u: float, v: float, width: float, depth: float, height: float, style: String, draw_door := true) -> void:
	var a := Geometry.point(nw, ne, sw, u, v) + floor_lift
	var b := Geometry.point(nw, ne, sw, u + width, v) + floor_lift
	var c := Geometry.point(nw, ne, sw, u + width, v + depth) + floor_lift
	var d := Geometry.point(nw, ne, sw, u, v + depth) + floor_lift
	var up := RtsIsoProjection.world_delta(canvas, Vector2(0, -height * state.zoom))
	var rise := RtsIsoProjection.world_delta(canvas, Vector2(0, -8.0 * state.zoom))
	var wall: Color = palette["wall"]
	var roof: Color = palette["roof"]
	var dark: Color = palette["roof_dark"]
	var trim: Color = palette["trim"]
	FilledPolygon.draw(canvas_item, PackedVector2Array([a + up, b + up, b, a]), wall.darkened(0.1))
	FilledPolygon.draw(canvas_item, PackedVector2Array([a + up, d + up, d, a]), wall.darkened(0.12))
	FilledPolygon.draw(canvas_item, PackedVector2Array([b + up, c + up, c, b]), wall.darkened(0.2))
	FilledPolygon.draw(canvas_item, PackedVector2Array([d + up, c + up, c, d]), wall)
	FilledPolygon.draw(canvas_item, PackedVector2Array([a + up, b + up, c + up, d + up]), dark)
	canvas_item.draw_line(d + up, c + up, trim.darkened(0.18), 2.0)
	if style == "tower":
		match state.civilization:
			"English":
				FilledPolygon.draw(canvas_item, PackedVector2Array([a + up, b + up, c + up, d + up]), dark)
				for p in [a + up, b + up, c + up, d + up]: canvas_item.draw_line(p, p + up * 0.16, trim, 3.5)
			"Chinese":
				var peak := (a + c) * 0.5 + up + rise * 1.3
				FilledPolygon.draw(canvas_item, PackedVector2Array([a + up, b + up, peak]), roof.lightened(0.12))
				FilledPolygon.draw(canvas_item, PackedVector2Array([b + up, c + up, peak]), roof)
				FilledPolygon.draw(canvas_item, PackedVector2Array([c + up, d + up, peak]), dark)
				canvas_item.draw_line(d + up, c + up, trim, 2.6)
				var upper := (a + c) * 0.5 + up + rise * 0.85
				canvas_item.draw_line(upper - (b - a) * 0.3, upper + (b - a) * 0.3, trim, 2.0)
			_:
				var peak := (a + c) * 0.5 + up + rise * 1.8
				FilledPolygon.draw(canvas_item, PackedVector2Array([a + up, b + up, peak]), roof.lightened(0.1))
				FilledPolygon.draw(canvas_item, PackedVector2Array([b + up, c + up, peak]), roof)
				FilledPolygon.draw(canvas_item, PackedVector2Array([c + up, d + up, peak]), dark)
		var slit := (d + c) * 0.5 + up * 0.6
		canvas_item.draw_line(slit, slit + up * 0.16, Color("344343"), 3.0)
	else:
		if style == "gable_v":
			var ridge_back := (a + b) * 0.5 + up + rise
			var ridge_front := (d + c) * 0.5 + up + rise
			FilledPolygon.draw(canvas_item, PackedVector2Array([a + up, b + up, ridge_back]), wall.darkened(0.1))
			FilledPolygon.draw(canvas_item, PackedVector2Array([d + up, c + up, ridge_front]), wall)
			FilledPolygon.draw(canvas_item, PackedVector2Array([a + up, ridge_back, ridge_front, d + up]), roof.lightened(0.13))
			FilledPolygon.draw(canvas_item, PackedVector2Array([ridge_back, b + up, c + up, ridge_front]), roof)
			canvas_item.draw_line(ridge_back, ridge_front, trim, 2.0)
		else:
			var ridge_left := (a + d) * 0.5 + up + rise
			var ridge_right := (b + c) * 0.5 + up + rise
			FilledPolygon.draw(canvas_item, PackedVector2Array([a + up, d + up, ridge_left]), wall.darkened(0.12))
			FilledPolygon.draw(canvas_item, PackedVector2Array([b + up, c + up, ridge_right]), wall.darkened(0.2))
			FilledPolygon.draw(canvas_item, PackedVector2Array([a + up, b + up, ridge_right, ridge_left]), roof.lightened(0.13))
			FilledPolygon.draw(canvas_item, PackedVector2Array([ridge_left, ridge_right, c + up, d + up]), roof)
			canvas_item.draw_line(ridge_left, ridge_right, trim, 2.0)
		if state.civilization == "Chinese":
			for corner in [a + up, b + up, c + up, d + up]: canvas_item.draw_circle(corner + rise * 0.2, 2.2, trim)
		for portion in [0.22, 0.51, 0.8]:
			var post := d.lerp(c, portion)
			canvas_item.draw_line(post, post + up * 0.82, palette["timber"], 1.8)
		if draw_door:
			var doorway := (d + c) * 0.5
			canvas_item.draw_line(doorway, doorway + up * 0.56, Color("39433d"), 5.0)

func _draw_iso_military_structure(art_kind: String, nw: Vector2, ne: Vector2, sw: Vector2, lift: Vector2, palette: Dictionary, canvas: Transform2D) -> void:
	var floor_lift := lift * 0.18
	var timber: Color = palette["timber"]
	var trim: Color = palette["trim"]
	var deck := PackedVector2Array([nw + floor_lift, ne + floor_lift, ne + sw - nw + floor_lift, sw + floor_lift])
	FilledPolygon.draw(canvas_item, deck, Color("a69a74"))
	for portion in [0.17, 0.37, 0.57, 0.77]:
		canvas_item.draw_line(Geometry.point(nw, ne, sw, 0.05, portion) + floor_lift, Geometry.point(nw, ne, sw, 0.95, portion) + floor_lift, Color(timber, 0.32), 1.0)
	match art_kind:
		"barracks":
			_draw_iso_military_block(nw, ne, sw, floor_lift, canvas, palette, 0.07, 0.07, 0.86, 0.28, 21, "gable_u")
			_draw_iso_military_block(nw, ne, sw, floor_lift, canvas, palette, 0.07, 0.33, 0.22, 0.39, 17, "gable_v")
			_draw_iso_military_block(nw, ne, sw, floor_lift, canvas, palette, 0.71, 0.33, 0.22, 0.39, 17, "gable_v")
			for u in [0.42, 0.58]:
				var dummy := Geometry.point(nw, ne, sw, u, 0.58) + floor_lift
				var head := dummy + lift * 0.46
				canvas_item.draw_line(dummy, head, timber, 2.5)
				canvas_item.draw_line(dummy + lift * 0.27 - (ne - nw) * 0.05, dummy + lift * 0.27 + (ne - nw) * 0.05, timber, 2.1)
				canvas_item.draw_circle(head, 3.3, palette["wall"])
			for u in [0.14, 0.72]: _draw_iso_military_block(nw, ne, sw, floor_lift, canvas, palette, u, 0.75, 0.15, 0.17, 32, "tower")
		"archery_range":
			_draw_iso_military_block(nw, ne, sw, floor_lift, canvas, palette, 0.06, 0.06, 0.7, 0.28, 21, "gable_u")
			_draw_iso_military_block(nw, ne, sw, floor_lift, canvas, palette, 0.06, 0.33, 0.2, 0.42, 16, "gable_v")
			_draw_iso_military_block(nw, ne, sw, floor_lift, canvas, palette, 0.76, 0.09, 0.18, 0.24, 38, "tower")
			for u in [0.36, 0.61, 0.86]:
				var foot := Geometry.point(nw, ne, sw, u, 0.57) + floor_lift
				var board := foot + RtsIsoProjection.world_delta(canvas, Vector2(0, -12.0 * state.zoom))
				var brace := RtsIsoProjection.world_delta(canvas, Vector2(5.0 * state.zoom, -2.0 * state.zoom))
				canvas_item.draw_line(foot - brace * 0.75, board, timber, 2.0)
				canvas_item.draw_line(foot + brace * 0.75, board, timber, 2.0)
				_draw_iso_upright_disc(board, 6.0, timber.darkened(0.18), canvas)
				_draw_iso_upright_disc(board, 5.0, trim, canvas)
				_draw_iso_upright_disc(board, 3.3, Color("ad654a"), canvas)
				_draw_iso_upright_disc(board, 1.5, trim, canvas)
				var lane := Geometry.point(nw, ne, sw, u, 0.87) + floor_lift
				canvas_item.draw_line(lane, foot, Color("d4bd86"), 1.5)
		"stable":
			_draw_iso_military_block(nw, ne, sw, floor_lift, canvas, palette, 0.06, 0.06, 0.88, 0.3, 22, "gable_u")
			_draw_iso_military_block(nw, ne, sw, floor_lift, canvas, palette, 0.06, 0.34, 0.24, 0.36, 16, "gable_v")
			for u in [0.46, 0.69]:
				var stall := Geometry.point(nw, ne, sw, u, 0.39) + floor_lift
				canvas_item.draw_line(stall, stall + lift * 0.38, timber.darkened(0.14), 2.0)
			var horse := Geometry.point(nw, ne, sw, 0.55, 0.64) + floor_lift
			var horse_up := RtsIsoProjection.world_delta(canvas, Vector2(0, -10.0 * state.zoom))
			var horse_right := RtsIsoProjection.world_delta(canvas, Vector2(8.0 * state.zoom, 0))
			var horse_body := horse + horse_up
			FilledPolygon.draw(canvas_item, PackedVector2Array([horse_body - horse_right - horse_up * 0.35, horse_body + horse_right - horse_up * 0.35, horse_body + horse_right + horse_up * 0.35, horse_body - horse_right + horse_up * 0.35]), Color("765039"))
			for side in [-1.0, 1.0]: canvas_item.draw_line(horse_body + horse_right * side - horse_up * 0.3, horse + horse_right * side * 0.82, Color("66432f"), 2.0)
			canvas_item.draw_line(horse_body + horse_right * 0.8, horse_body + horse_right * 1.35 + horse_up * 0.45, Color("765039"), 3.4)
			canvas_item.draw_circle(horse_body + horse_right * 1.48 + horse_up * 0.45, 3.8, Color("765039"))
			for u in [0.34, 0.54, 0.74, 0.92]:
				var post := Geometry.point(nw, ne, sw, u, 0.9) + floor_lift
				canvas_item.draw_line(post, post + lift * 0.28, timber, 2.5)
			var fence_left := Geometry.point(nw, ne, sw, 0.34, 0.9) + floor_lift + lift * 0.24
			var fence_right := Geometry.point(nw, ne, sw, 0.92, 0.9) + floor_lift + lift * 0.24
			canvas_item.draw_line(fence_left, fence_right, timber, 2.8)
			var fence_back := Geometry.point(nw, ne, sw, 0.92, 0.41) + floor_lift + lift * 0.24
			canvas_item.draw_line(fence_right, fence_back, timber, 2.8)

func _draw_iso_roof(art_kind: String, nw: Vector2, ne: Vector2, se: Vector2, sw: Vector2, lift: Vector2, palette: Dictionary, canvas: Transform2D) -> void:
	var center := (nw + ne + se + sw) * 0.25
	if art_kind in ["keep", "outpost"]:
		var parapet: Color = palette["wall"]
		var masonry: Color = palette["trim"]
		FilledPolygon.draw(canvas_item, PackedVector2Array([nw + lift, ne + lift, se + lift, sw + lift]), parapet.darkened(0.32))
		for edge in [[nw, ne], [ne, se], [se, sw], [sw, nw]]:
			var start: Vector2 = edge[0] + lift
			var finish: Vector2 = edge[1] + lift
			canvas_item.draw_line(start, finish, masonry, 3.2)
		_draw_iso_battlements([nw + lift, ne + lift, se + lift, sw + lift], lift * 0.13, masonry, 4.5)
		return
	var overhang := 1.1 if state.civilization == "Chinese" else 1.06
	var a := center + (nw - center) * overhang + lift
	var b := center + (ne - center) * overhang + lift
	var c := center + (se - center) * overhang + lift
	var d := center + (sw - center) * overhang + lift
	var roof_height := 23.0 if art_kind == "monastery" else 15.0 if art_kind == "university" else 9.0
	var rise := RtsIsoProjection.world_delta(canvas, Vector2(0, -roof_height * state.zoom))
	var ridge_back := (a + b) * 0.5 + rise
	var ridge_front := (d + c) * 0.5 + rise
	var roof: Color = palette["roof"]
	var dark: Color = palette["roof_dark"]
	if state.civilization == "Chinese":
		var upturn := RtsIsoProjection.world_delta(canvas, Vector2(0, -3.5 * state.zoom))
		a += upturn
		b += upturn
		c += upturn
		d += upturn
	FilledPolygon.draw(canvas_item, PackedVector2Array([a, b, c, d]), dark)
	FilledPolygon.draw(canvas_item, PackedVector2Array([a, b, ridge_back]), palette["wall"].darkened(0.1))
	FilledPolygon.draw(canvas_item, PackedVector2Array([d, c, ridge_front]), palette["wall"])
	FilledPolygon.draw(canvas_item, PackedVector2Array([a, ridge_back, ridge_front, d]), roof.lightened(0.09))
	FilledPolygon.draw(canvas_item, PackedVector2Array([ridge_back, b, c, ridge_front]), roof)
	canvas_item.draw_polyline(PackedVector2Array([a, ridge_back, b]), dark, 2.0)
	canvas_item.draw_polyline(PackedVector2Array([d, ridge_front, c]), dark, 2.0)
	canvas_item.draw_line(ridge_back, ridge_front, palette["trim"], 2.0)
	for portion in [0.28, 0.58, 0.84]:
		canvas_item.draw_line(a.lerp(d, portion), ridge_back.lerp(ridge_front, portion), Color(dark, 0.45), 1.0)
		canvas_item.draw_line(ridge_back.lerp(ridge_front, portion), b.lerp(c, portion), Color(dark, 0.37), 1.0)
	if state.civilization == "Chinese":
		for corner in [a, b, c, d]:
			canvas_item.draw_circle(corner, 1.8, palette["trim"])

func _draw_iso_building_feature(art_kind: String, nw: Vector2, ne: Vector2, se: Vector2, sw: Vector2, lift: Vector2, palette: Dictionary, canvas: Transform2D) -> void:
	var roof_middle := (nw + ne + se + sw) * 0.25 + lift
	var timber: Color = palette["timber"]
	var trim: Color = palette["trim"]
	match art_kind:
		"keep", "university", "monastery":
			_draw_iso_tower(art_kind, nw, ne, se, sw, lift, palette, canvas)
		"house":
			var chimney := roof_middle + (nw - roof_middle) * 0.28
			var chimney_top := chimney + RtsIsoProjection.world_delta(canvas, Vector2(0, -10.0 * state.zoom))
			canvas_item.draw_line(chimney, chimney_top, timber, 7.0)
			canvas_item.draw_line(chimney_top + Vector2(-4, 0), chimney_top + Vector2(4, 0), trim, 3.0)
	if art_kind == "outpost":
		var mast := roof_middle + RtsIsoProjection.world_delta(canvas, Vector2(0, -16.0 * state.zoom))
		canvas_item.draw_line(roof_middle, mast, timber, 2.0)
		FilledPolygon.draw(canvas_item, PackedVector2Array([mast, mast + Vector2(9, 3), mast + Vector2(0, 6)]), state.player_color)

func _draw_iso_tower(art_kind: String, nw: Vector2, ne: Vector2, se: Vector2, sw: Vector2, lift: Vector2, palette: Dictionary, canvas: Transform2D) -> void:
	var center := (nw + ne + se + sw) * 0.25 + lift
	var tower_scale := 0.4 if art_kind in ["palace", "wonder"] else 0.34 if art_kind in ["keep", "town_center"] else 0.26
	var a := center + (nw - center + lift) * tower_scale
	var b := center + (ne - center + lift) * tower_scale
	var c := center + (se - center + lift) * tower_scale
	var d := center + (sw - center + lift) * tower_scale
	var rise := RtsIsoProjection.world_delta(canvas, Vector2(0, -(26.0 if art_kind in ["palace", "wonder", "monastery"] else 19.0) * state.zoom))
	var wall: Color = palette["wall"]
	FilledPolygon.draw(canvas_item, PackedVector2Array([b + rise, c + rise, c, b]), wall.darkened(0.25))
	FilledPolygon.draw(canvas_item, PackedVector2Array([d + rise, c + rise, c, d]), wall)
	FilledPolygon.draw(canvas_item, PackedVector2Array([a + rise, b + rise, c + rise, d + rise]), palette["roof_dark"])
	canvas_item.draw_polyline(PackedVector2Array([a + rise, b + rise, c + rise, d + rise, a + rise]), palette["trim"], 1.6)
	if art_kind == "keep":
		_draw_iso_battlements([a + rise, b + rise, c + rise, d + rise], rise * 0.2, palette["trim"], 3.0)
	elif art_kind in ["palace", "wonder"]:
		var upper_center := (a + b + c + d) * 0.25 + rise
		var upper_a := upper_center + (a + rise - upper_center) * 0.64
		var upper_b := upper_center + (b + rise - upper_center) * 0.64
		var upper_c := upper_center + (c + rise - upper_center) * 0.64
		var upper_d := upper_center + (d + rise - upper_center) * 0.64
		var upper_rise := RtsIsoProjection.world_delta(canvas, Vector2(0, -(17.0 if art_kind == "wonder" else 12.0) * state.zoom))
		FilledPolygon.draw(canvas_item, PackedVector2Array([upper_b + upper_rise, upper_c + upper_rise, upper_c, upper_b]), wall.darkened(0.25))
		FilledPolygon.draw(canvas_item, PackedVector2Array([upper_d + upper_rise, upper_c + upper_rise, upper_c, upper_d]), wall)
		var cap_rise := RtsIsoProjection.world_delta(canvas, Vector2(0, -8.0 * state.zoom))
		var peak := (upper_a + upper_b + upper_c + upper_d) * 0.25 + upper_rise + cap_rise
		FilledPolygon.draw(canvas_item, PackedVector2Array([upper_a + upper_rise, peak, upper_d + upper_rise]), palette["roof"])
		FilledPolygon.draw(canvas_item, PackedVector2Array([upper_b + upper_rise, upper_c + upper_rise, peak]), palette["roof_dark"])
		canvas_item.draw_line(upper_d + upper_rise, upper_c + upper_rise, palette["trim"], 2.0)
		_draw_iso_landmark_crown(peak, palette, canvas)
	elif art_kind == "monastery":
		var bell_top := (a + b + c + d) * 0.25 + rise
		canvas_item.draw_circle(bell_top, 3.0, palette["trim"])
		canvas_item.draw_line(bell_top, bell_top + RtsIsoProjection.world_delta(canvas, Vector2(0, -13.0 * state.zoom)), palette["trim"], 2.0)
		canvas_item.draw_line(bell_top + Vector2(-5, -7), bell_top + Vector2(5, -7), palette["trim"], 2.0)
	else:
		_draw_iso_landmark_crown((a + b + c + d) * 0.25 + rise, palette, canvas)

func _draw_iso_landmark_crown(base: Vector2, palette: Dictionary, canvas: Transform2D) -> void:
	var mast_height := 28.0 if state.kind == "wonder" else 13.0
	var top := base + RtsIsoProjection.world_delta(canvas, Vector2(0, -mast_height * state.zoom))
	canvas_item.draw_line(base, top, palette["timber"], 1.7)
	if state.kind == "wonder":
		canvas_item.draw_circle(top, 4.0, palette["trim"])
		canvas_item.draw_line(top + Vector2(-6, 5), top + Vector2(6, 5), palette["trim"], 2.0)
	elif state.landmark_id == "zh_clocktower":
		canvas_item.draw_circle(top, 5.0, palette["trim"])
		canvas_item.draw_circle(top, 2.2, palette["roof_dark"])
	elif state.landmark_id in ["eng_kings_mill", "eng_abbey", "zh_spirit_way"]:
		canvas_item.draw_line(top + Vector2(-5, 4), top + Vector2(5, 4), palette["trim"], 2.2)
	else:
		var accent: Color = Color("c99657") if state.kind == "landmark" else state.player_color
		FilledPolygon.draw(canvas_item, PackedVector2Array([top, top + Vector2(10, 3), top + Vector2(0, 7)]), accent)

func _landmark_geometry():
	var key := str([state.kind, state.landmark_id, state.dimensions, state.civilization, state.player_color])
	if landmark_geometry == null or landmark_geometry_key != key:
		landmark_geometry = LandmarkVisual.new()
		landmark_geometry.dimensions = state.dimensions
		landmark_geometry.palette = _architecture_palette()
		landmark_geometry.populate(state.kind, state.landmark_id, state.player_color, state.civilization)
		landmark_geometry.prepare()
		landmark_geometry_key = key
	return landmark_geometry

func _draw_iso_landmark_architecture(lift: Vector2, canvas: Transform2D) -> void:
	for polygon in _landmark_geometry().projected_faces(canvas, state.zoom, Vector2.ZERO if state.kind == "wonder" else lift):
		FilledPolygon.draw(canvas_item, polygon["points"], polygon["color"])

func _draw_iso_battlements(corners: Array, rise: Vector2, color: Color, width: float) -> void:
	var teeth: Array[Vector2] = []
	for edge in corners.size():
		var start: Vector2 = corners[edge]
		var finish: Vector2 = corners[(edge + 1) % corners.size()]
		var count := maxi(2, ceili(start.distance_to(finish) / 9.0))
		# Half-open intervals include every corner exactly once.
		for i in count: teeth.append(start.lerp(finish, float(i) / count))
	var canvas := canvas_item.get_viewport().get_canvas_transform()
	teeth.sort_custom(func(a: Vector2, b: Vector2) -> bool: return canvas.basis_xform(a).y < canvas.basis_xform(b).y)
	var center := Vector2.ZERO
	for corner in corners: center += corner
	center /= corners.size()
	for tooth in teeth:
		canvas_item.draw_line(tooth, tooth + rise, LandmarkVisual.battlement_color(tooth - center, color), width)

func _farm_geometry():
	var step := clampi(roundi(state.crop_fraction * FarmVisual.CROP_STEPS), 0, FarmVisual.CROP_STEPS)
	var key: Array = [state.dimensions, state.civilization, step, state.farm_stage]
	if farm_geometry == null or farm_geometry_key != key:
		farm_geometry = FarmVisual.geometry(state.dimensions, state.civilization, float(step) / FarmVisual.CROP_STEPS, state.farm_stage)
		farm_geometry_key = key
	return farm_geometry

func _draw_iso_farm(_nw: Vector2, _ne: Vector2, _se: Vector2, _sw: Vector2, _lift: Vector2) -> void:
	var canvas := canvas_item.get_viewport().get_canvas_transform()
	for polygon in _farm_geometry().projected_faces(canvas, state.zoom, Vector2.ZERO):
		FilledPolygon.draw(canvas_item, polygon["points"], polygon["color"])

func _draw_building_icon(center: Vector2, icon_size: float) -> void:
	if not state.show_building_icons: return
	var badge := Rect2(center - Vector2.ONE * icon_size * 0.5, Vector2.ONE * icon_size)
	if state.building_icon != null:
		canvas_item.draw_texture_rect(state.building_icon, badge, false, Color(1, 1, 1, 0.55) if not state.is_complete() else Color.WHITE)
	else:
		canvas_item.draw_rect(badge, Color("24313a"))
		# Wonders have no command icon asset yet; a small column marks them on the map.
		FilledPolygon.draw(canvas_item, PackedVector2Array([center + Vector2(-9, -5), center + Vector2(0, -11), center + Vector2(9, -5)]), Color("e8d5a1"))
		for offset in [-6.0, 0.0, 6.0]:
			canvas_item.draw_rect(Rect2(center + Vector2(offset - 1.5, -4), Vector2(3, 11)), Color("e8d5a1"))
		canvas_item.draw_rect(Rect2(center + Vector2(-10, 7), Vector2(20, 3)), Color("e8d5a1"))
	canvas_item.draw_rect(badge, Color("e4c785"), false, 1.0)

func landmark_extra_height(snapshot: VisualState) -> float:
	state = snapshot
	return _landmark_extra_height()

func _landmark_extra_height() -> float:
	if state.kind in ["farm", "dock"] or CivicGeometry.handles(state.kind) or state.kind == "wonder":
		return maxf(0.0, _civic_display_geometry().height_above_origin - state.isometric_height() - state.visual_feature_height())
	if RefinedGeometry.handles(state.kind):
		return maxf(0.0, _refined_geometry().height_above_origin - state.isometric_height() - state.visual_feature_height())
	if state.kind not in ["landmark", "wonder"]: return 0.0
	return _landmark_geometry().height_above_origin

func _refined_geometry():
	# Position-derived variation also survives fog snapshots, without live entities.
	var variant := absi(hash(state.world_position)) % 3 if state.kind == "house" else 0
	var key: Array = [state.kind, state.dimensions, state.civilization, state.player_color, variant]
	if refined_geometry == null or key != refined_geometry_key:
		refined_geometry = RefinedGeometry.new(state.kind, state.dimensions, state.civilization, state.player_color, variant, _architecture_palette())
		refined_geometry_key = key
	return refined_geometry

func draw_refined_portrait(item: CanvasItem, snapshot: VisualState, frame: Rect2) -> void:
	state = snapshot
	var geometry = _refined_geometry()
	var bounds: Rect2 = geometry.portrait_bounds
	var fit := minf(frame.size.x / bounds.size.x, frame.size.y / bounds.size.y)
	var origin := frame.get_center() - bounds.get_center() * fit
	item.draw_set_transform_matrix(Transform2D(0.0, Vector2.ONE * fit, 0.0, origin))
	for polygon in geometry.portrait_faces:
		FilledPolygon.draw(item, polygon["points"], polygon["color"])
	item.draw_set_transform_matrix(Transform2D.IDENTITY)

func _visible_height(construction_ratio: float) -> float:
	if (state.kind in ["farm", "dock"] or CivicGeometry.handles(state.kind) or state.kind == "wonder") and construction_ratio >= 0.65: return _civic_display_geometry().height_above_origin
	# Finished geometry appears at this stage without height scaling.
	if RefinedGeometry.handles(state.kind) and construction_ratio >= 0.65:
		return _refined_geometry().height_above_origin
	var base := state.isometric_height() * (0.25 + 0.75 * construction_ratio)
	if construction_ratio >= 0.65: return base + state.visual_feature_height() + _landmark_extra_height()
	# The low finished plinth must not shrink the early structural scaffold.
	if state.kind == "landmark": return base + _landmark_extra_height() * maxf(0.2, construction_ratio)
	if state.kind in ["wonder", "dock"] or CivicGeometry.handles(state.kind): return _civic_display_geometry().height_above_origin * maxf(0.2, construction_ratio)
	return base

func _civic_geometry():
	var key: Array = [state.kind, state.dimensions, state.civilization, state.player_color]
	if civic_geometry == null or key != civic_geometry_key:
		civic_geometry = CivicGeometry.new(state.kind, state.dimensions, state.civilization, state.player_color, _architecture_palette())
		civic_geometry_key = key
	return civic_geometry

func _civic_display_geometry():
	if state.kind == "dock": return DockBuildingVisual.geometry(state.dimensions, _architecture_palette(), state.civilization, state.player_color)
	if state.kind == "farm": return _farm_geometry()
	if state.kind in ["wonder", "landmark"]: return _landmark_geometry()
	return _civic_geometry()

func _cache_civic_portrait(snapshot: VisualState) -> void:
	state = snapshot
	var mesh = _civic_display_geometry()
	if mesh != portrait_mesh:
		civic_portrait_faces.clear()
		var first := true
		for polygon in mesh.ordered_faces:
			var points := PackedVector2Array()
			for p in polygon["points"]:
				var point := Vector2((p.x - p.y) * 0.70710678, (p.x + p.y) * 0.35355339 - p.z)
				points.append(point)
				civic_portrait_bounds = Rect2(point, Vector2.ZERO) if first else civic_portrait_bounds.expand(point)
				first = false
			if not Geometry2D.triangulate_polygon(points).is_empty(): civic_portrait_faces.append({"points": points, "color": polygon["color"]})
		portrait_mesh = mesh

func draw_civic_portrait(item: CanvasItem, snapshot: VisualState, frame: Rect2) -> void:
	_cache_civic_portrait(snapshot)
	var fit := minf(frame.size.x / maxf(civic_portrait_bounds.size.x, 0.1), frame.size.y / maxf(civic_portrait_bounds.size.y, 0.1))
	item.draw_set_transform_matrix(Transform2D(0.0, Vector2.ONE * fit, 0.0, frame.get_center() - civic_portrait_bounds.get_center() * fit))
	for polygon in civic_portrait_faces: FilledPolygon.draw(item, polygon["points"], polygon["color"])
	item.draw_set_transform_matrix(Transform2D.IDENTITY)

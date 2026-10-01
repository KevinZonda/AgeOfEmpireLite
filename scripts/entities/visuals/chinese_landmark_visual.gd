extends RefCounted

# Chinese landmarks share timber construction and swept tiled eaves, but keep
# different plans and silhouettes. Every detail is a local 3D face so the BSP,
# silhouette picking, construction reveal and remembered buildings stay intact.
const FilledPolygon = preload("res://scripts/entities/visuals/filled_polygon.gd")
const STONE := Color("b7b1a0")
const TIMBER := Color("894a3f")
const GOLD := Color("d4b46a")
const TILE := Color("626e69")
const DARK := Color("303e3e")

static func populate(g, id: String, player: Color) -> bool:
	if not id.begins_with("zh_"): return false
	_paving(g)
	match id:
		"zh_imperial_academy":
			_hall(g, Vector2(0.5, 0.24), Vector2(0.63, 0.24), 19, TILE, false, false)
			for u in [0.17, 0.83]:
				_hall(g, Vector2(u, 0.53), Vector2(0.16, 0.38), 13, TILE, false, true)
			_hall(g, Vector2(0.5, 0.83), Vector2(0.29, 0.13), 10, TILE, false, false)
			_steps(g, Vector2(0.5, 0.41), 0.22)
			# An inscribed stele and two scholar courtyard planters.
			_box(g, Vector2(0.5, 0.58), Vector2(0.09, 0.07), 0, 2, STONE)
			_box(g, Vector2(0.5, 0.58), Vector2(0.055, 0.025), 2, 9, STONE.lightened(0.1))
			for u in [0.31, 0.69]: _planter(g, Vector2(u, 0.68))
		"zh_barbican":
			# A fortified enclosure: stone parapets, two roofed corner towers,
			# and a real open entrance rather than a door painted on a solid box.
			_wall(g, Vector2(0.5, 0.2), Vector2(0.68, 0.075), 19)
			for u in [0.17, 0.83]: _wall(g, Vector2(u, 0.45), Vector2(0.075, 0.5), 17)
			for u in [0.24, 0.76]:
				_box(g, Vector2(u, 0.65), Vector2(0.21, 0.22), 0, 21, STONE.darkened(0.1))
				_hall(g, Vector2(u, 0.65), Vector2(0.18, 0.19), 11, Color("788276"), false, false, 21)
			_gate(g, Vector2(0.5, 0.69), Vector2(0.32, 0.13), 18, false)
			_box(g, Vector2(0.5, 0.69), Vector2(0.37, 0.15), 18, 3, STONE)
			_banner(g, Vector2(0.33, 0.35), 23, player)
		"zh_clocktower":
			_steps(g, Vector2(0.5, 0.78), 0.23)
			_box(g, Vector2(0.5, 0.46), Vector2(0.32, 0.32), 0, 12, STONE)
			_hall(g, Vector2(0.5, 0.46), Vector2(0.29, 0.29), 20, TILE, false, false, 12)
			_box(g, Vector2(0.5, 0.46), Vector2(0.15, 0.16), 31, 12, TIMBER)
			_hall(g, Vector2(0.5, 0.46), Vector2(0.22, 0.23), 17, TILE, false, false, 42)
			# A bronze astronomical wheel on the tower's front, not a European
			# clock face. Open spokes remain legible at normal play zoom.
			_wheel(g, Vector3(0, g.dimensions.y * 0.105 + 1.1, 25), 7.1)
			for u in [0.17, 0.83]: _hall(g, Vector2(u, 0.67), Vector2(0.17, 0.25), 10, TILE, false, true)
		"zh_imperial_palace":
			_hall(g, Vector2(0.5, 0.29), Vector2(0.65, 0.29), 25, Color("b69a53"), true, false)
			for u in [0.12, 0.88]: _hall(g, Vector2(u, 0.59), Vector2(0.13, 0.35), 13, Color("a58c50"), false, true)
			_hall(g, Vector2(0.5, 0.78), Vector2(0.37, 0.15), 12, Color("b69a53"), false, false)
			_steps(g, Vector2(0.5, 0.49), 0.29)
			# The central ceremonial approach and two bronze incense vessels.
			for u in [0.32, 0.68]:
				_box(g, Vector2(u, 0.59), Vector2(0.06, 0.06), 0, 3, STONE)
				_box(g, Vector2(u, 0.59), Vector2(0.045, 0.045), 3, 5, Color("788976"))
		"zh_gatehouse":
			for u in [0.12, 0.88]:
				_box(g, Vector2(u, 0.51), Vector2(0.16, 0.28), 0, 24, STONE.darkened(0.12))
				g.battlements(_center(g, Vector2(u, 0.51)), g.dimensions * Vector2(0.16, 0.28), 24, STONE)
			_gate(g, Vector2(0.5, 0.51), Vector2(0.6, 0.27), 24, true)
			_hall(g, Vector2(0.5, 0.51), Vector2(0.5, 0.24), 16, TILE, false, false, 24)
			_hall(g, Vector2(0.5, 0.51), Vector2(0.34, 0.17), 12, TILE, false, false, 47)
			_banner(g, Vector2(0.22, 0.68), 30, player)
		"zh_spirit_way":
			_hall(g, Vector2(0.5, 0.22), Vector2(0.58, 0.24), 20, Color("8b8873"), true, false)
			# A roofed ceremonial stone arch and paired guardian sculptures.
			_gate(g, Vector2(0.5, 0.56), Vector2(0.44, 0.08), 13, false)
			_roof(g, _center(g, Vector2(0.5, 0.56)), g.dimensions * Vector2(0.5, 0.13), 13, 7, TILE, false)
			for u in [0.25, 0.75]:
				for v in [0.72, 0.87]: _guardian(g, Vector2(u, v), v > 0.8)
			_steps(g, Vector2(0.5, 0.39), 0.27)
		_: return false
	return true

static func _center(g, uv: Vector2) -> Vector2:
	return (uv - Vector2.ONE * 0.5) * g.dimensions

static func _box(g, uv: Vector2, span: Vector2, bottom: float, height: float, color: Color) -> void:
	g.box(_center(g, uv), span * g.dimensions, bottom + g.base_z, height, color)

static func _paving(g) -> void:
	# Keep the narrow ceremonial path without a slab under the whole footprint.
	_box(g, Vector2(0.5, 0.64), Vector2(0.17, 0.66), 0.0, 0.15, Color("c4bca5"))
	for v in [0.42, 0.58, 0.74, 0.9]:
		_box(g, Vector2(0.5, v), Vector2(0.17, 0.008), 0.16, 0.05, Color("969788"))

static func _steps(g, uv: Vector2, width: float) -> void:
	for i in 3:
		_box(g, uv + Vector2(0, float(i) * 0.035), Vector2(width, 0.037), 0, float(3 - i) * 1.1, STONE.lightened(0.06))

static func _hall(g, uv: Vector2, span: Vector2, height: float, roof: Color, double_eaves: bool, along_y: bool, bottom := 0.0) -> void:
	var center := _center(g, uv)
	var extent: Vector2 = span * g.dimensions
	var plinth := 2.5
	g.box(center, extent + Vector2(3, 3), bottom + g.base_z, plinth, STONE)
	# Recessed cream panels sit behind projecting red timber columns.
	g.box(center, extent * Vector2(0.9, 0.82), bottom + plinth + g.base_z, height - plinth - 1, Color("c4b699"))
	var front := center.y + extent.y * 0.5
	var right := center.x + extent.x * 0.5
	for i in 4:
		var x := lerpf(center.x - extent.x * 0.45, center.x + extent.x * 0.45, float(i) / 3)
		g.box(Vector2(x, front), Vector2(1.9, 1.9), bottom + plinth + g.base_z, height - plinth, TIMBER)
	for f in [0.12, 0.88]:
		g.box(Vector2(right, center.y + extent.y * (f - 0.5)), Vector2(1.9, 1.9), bottom + plinth + g.base_z, height - plinth, TIMBER.darkened(0.1))
	g.box(Vector2(center.x, front), Vector2(extent.x + 1, 1.7), bottom + height - 2 + g.base_z, 2, TIMBER)
	# A shadowed double door and wooden lattice across the front wall.
	var door_y := center.y + extent.y * 0.41 + 0.03
	var door_w := minf(7, extent.x * 0.2)
	g.face([Vector3(center.x - door_w * 0.5, door_y, bottom + plinth), Vector3(center.x + door_w * 0.5, door_y, bottom + plinth), Vector3(center.x + door_w * 0.5, door_y, bottom + height * 0.65), Vector3(center.x - door_w * 0.5, door_y, bottom + height * 0.65)], DARK)
	for side in [-1.0, 1.0]:
		var x: float = center.x + extent.x * 0.3 * side
		g.face([Vector3(x - 2.2, door_y, bottom + height * 0.48), Vector3(x + 2.2, door_y, bottom + height * 0.48), Vector3(x + 2.2, door_y, bottom + height * 0.73), Vector3(x - 2.2, door_y, bottom + height * 0.73)], TIMBER.darkened(0.25))
	if double_eaves:
		_roof(g, center, extent + Vector2(8, 7), bottom + height * 0.68, 4.5, roof.darkened(0.12), along_y)
	_roof(g, center, extent + Vector2(8, 7), bottom + height, 10 if double_eaves else 7, roof, along_y)

static func _roof(g, center: Vector2, extent: Vector2, bottom: float, rise: float, color: Color, along_y: bool) -> void:
	# Three slope bands sweep outward to raised corner tips. The ridge has
	# length, so the silhouette reads as a tiled hall instead of a pyramid.
	var half := Vector2(extent.y, extent.x) * 0.5 if along_y else extent * 0.5
	var ridge := half.x * 0.59
	var rings: Array = []
	for band in 3:
		var x: float = half.x * [1.0, 0.79, 0.64][band]
		var y: float = half.y * [1.0, 0.7, 0.3][band]
		var z: float = bottom + rise * [0.12, 0.2, 0.72][band]
		var ring: Array = []
		for p in [Vector2(-x, -y), Vector2(x, -y), Vector2(x, y), Vector2(-x, y)]:
			var q: Vector2 = Vector2(p.y, p.x) if along_y else p
			ring.append(Vector3(center.x + q.x, center.y + q.y, z))
		rings.append(ring)
	# Deep fascia casts a dark rim below the eaves.
	for side in 4:
		var a: Vector3 = rings[0][side]
		var b: Vector3 = rings[0][(side + 1) % 4]
		g.face([a + Vector3(0, 0, -1.4), b + Vector3(0, 0, -1.4), b, a], color.darkened(0.38))
		for band in 2:
			g.face([rings[band][side], rings[band][(side + 1) % 4], rings[band + 1][(side + 1) % 4], rings[band + 1][side]], color.lightened(0.1 if side == 0 or side == 3 else -0.06))
	# Subtle tile seams lie on the long roof slopes. All four roof planes
	# stay solid and the seams use the same depth sorter as the roof itself.
	for side in [0, 2]:
		var next: int = (side + 1) % 4
		for band in 2:
			var a0: Vector3 = rings[band][side]
			var b0: Vector3 = rings[band][next]
			var a1: Vector3 = rings[band + 1][side]
			var b1: Vector3 = rings[band + 1][next]
			for f in [0.25, 0.5, 0.75]:
				var edge := 0.003
				var lift := Vector3(0, 0, 0.035)
				g.face([a0.lerp(b0, f - edge) + lift, a0.lerp(b0, f + edge) + lift, a1.lerp(b1, f + edge) + lift, a1.lerp(b1, f - edge) + lift], color.darkened(0.13))
	var r0 := Vector2(-ridge, 0)
	var r1 := Vector2(ridge, 0)
	if along_y:
		r0 = Vector2(r0.y, r0.x)
		r1 = Vector2(r1.y, r1.x)
	var a := Vector3(center.x + r0.x, center.y + r0.y, bottom + rise)
	var b := Vector3(center.x + r1.x, center.y + r1.y, bottom + rise)
	g.face([rings[2][0], rings[2][1], b, a], color.lightened(0.16))
	g.face([rings[2][1], rings[2][2], b], color.darkened(0.07))
	g.face([rings[2][2], rings[2][3], a, b], color)
	g.face([rings[2][3], rings[2][0], a], color.lightened(0.1))
	var ridge_extent := Vector2(2, ridge * 2 + 1) if along_y else Vector2(ridge * 2 + 1, 2)
	g.box(center, ridge_extent, bottom + rise, 1.1, GOLD.darkened(0.15))
	# Small ridge-end ornaments and eave finials break the straight roof edge.
	for p in [a, b]: g.box(Vector2(p.x, p.y), Vector2(1.8, 1.8), p.z + 1, 2, GOLD)
	for p in rings[0]: g.box(Vector2(p.x, p.y), Vector2(1.1, 1.1), p.z, 1.4, color.lightened(0.2))

static func _wall(g, uv: Vector2, span: Vector2, height: float) -> void:
	_box(g, uv, span, 0, height, STONE.darkened(0.14))
	_box(g, uv, span + Vector2.ONE * 0.02, height - 2, 2, STONE)
	g.battlements(_center(g, uv), span * g.dimensions, height, STONE)
	_masonry(g, _center(g, uv), span * g.dimensions, height)

static func _masonry(g, center: Vector2, extent: Vector2, height: float) -> void:
	# Sparse stone courses give the defensive mass scale without covering it
	# in dark grid lines. Both visible walls use local face overlays.
	var front := center.y + extent.y * 0.5 + 0.02
	var right := center.x + extent.x * 0.5 + 0.02
	for z in [height * 0.28, height * 0.59]:
		g.face([Vector3(center.x - extent.x * 0.5, front, z), Vector3(right, front, z), Vector3(right, front, z + 0.35), Vector3(center.x - extent.x * 0.5, front, z + 0.35)], STONE.darkened(0.2))
		g.face([Vector3(right, center.y - extent.y * 0.5, z), Vector3(right, front, z), Vector3(right, front, z + 0.35), Vector3(right, center.y - extent.y * 0.5, z + 0.35)], STONE.darkened(0.3))

static func _gate(g, uv: Vector2, span: Vector2, height: float, massive: bool) -> void:
	var center := _center(g, uv)
	var extent: Vector2 = span * g.dimensions
	var opening := minf(extent.x * 0.37, 19)
	var pier := (extent.x - opening) * 0.5
	var passage := height * 0.65
	for side in [-1.0, 1.0]:
		var pier_center := center + Vector2(side * (opening + pier) * 0.5, 0)
		g.box(pier_center, Vector2(pier, extent.y), 0, height, STONE.darkened(0.1))
		_masonry(g, pier_center, Vector2(pier, extent.y), height)
		# Inside reveals close the passage sides; the normal box only emits
		# its camera-facing walls, and the left pier's right face is already there.
		if side > 0:
			var x: float = center.x + opening * 0.5
			g.face([Vector3(x, center.y - extent.y * 0.5, 0), Vector3(x, center.y + extent.y * 0.5, 0), Vector3(x, center.y + extent.y * 0.5, passage), Vector3(x, center.y - extent.y * 0.5, passage)], STONE.darkened(0.35))
	g.box(center, extent, passage, height - passage, STONE.darkened(0.08))
	# A shallow arched soffit closes the ceiling, with stone shoulders in
	# the front opening; the passage itself remains visibly open to the yard.
	for i in 4:
		var x0: float = center.x + opening * [-0.5, -0.3, 0.0, 0.3][i]
		var x1: float = center.x + opening * [-0.3, 0.0, 0.3, 0.5][i]
		var z0: float = passage * [0.8, 0.97, 1.0, 0.97][i]
		var z1: float = passage * [0.97, 1.0, 0.97, 0.8][i]
		var front := center.y + extent.y * 0.5 + 0.025
		var back := center.y - extent.y * 0.5
		g.face([Vector3(x0, back, z0), Vector3(x1, back, z1), Vector3(x1, front, z1), Vector3(x0, front, z0)], STONE.darkened(0.4))
		g.face([Vector3(x0, front, z0), Vector3(x1, front, z1), Vector3(x1, front, passage), Vector3(x0, front, passage)], STONE.darkened(0.1))
	if massive:
		g.box(center, extent + Vector2(3, 3), height - 1, 2, STONE.lightened(0.08))
		for side in [-1.0, 1.0]:
			g.box(center + Vector2(side * (opening * 0.5 + 1), extent.y * 0.5 + 0.2), Vector2(2, 1), 0, passage + 1, STONE.lightened(0.14))
		g.box(center + Vector2(0, extent.y * 0.5 + 0.3), Vector2(opening + 4, 1), passage, 1.6, STONE.lightened(0.14))

static func _wheel(g, hub: Vector3, radius: float) -> void:
	for i in 12:
		var angle := float(i) * TAU / 12
		var next := float(i + 1) * TAU / 12
		var p := Vector3(cos(angle), 0, sin(angle))
		var q := Vector3(cos(next), 0, sin(next))
		g.face([hub + p * radius, hub + q * radius, hub + q * (radius - 1.1), hub + p * (radius - 1.1)], GOLD)
		if i % 3 == 0:
			var cross := Vector3(-sin(angle), 0, cos(angle)) * 0.55
			g.face([hub - cross, hub + p * radius - cross, hub + p * radius + cross, hub + cross], GOLD.darkened(0.1))
	g.disc(hub + Vector3(0, 0.02, 0), 1.3, GOLD)

static func _planter(g, uv: Vector2) -> void:
	_box(g, uv, Vector2(0.075, 0.075), 0, 2, STONE)
	_box(g, uv, Vector2(0.065, 0.065), 2, 1.1, Color("6b8157"))

static func _guardian(g, uv: Vector2, seated: bool) -> void:
	_box(g, uv, Vector2(0.08, 0.1), 0, 2, STONE.lightened(0.1))
	_box(g, uv, Vector2(0.055, 0.065), 2, 5 if seated else 3.5, STONE.darkened(0.16))
	_box(g, uv + Vector2(0, 0.012), Vector2(0.043, 0.04), 6 if seated else 4.5, 3, STONE)
	_box(g, uv + Vector2(0, 0.038), Vector2(0.035, 0.02), 6.5 if seated else 5, 1.4, STONE.lightened(0.1))
	for side in [-1.0, 1.0]:
		_box(g, uv + Vector2(side * 0.022, 0.023), Vector2(0.02, 0.045), 2, 2.2, STONE)

static func _banner(g, uv: Vector2, height: float, player: Color) -> void:
	_box(g, uv, Vector2(0.012, 0.012), 0, height, TIMBER.darkened(0.25))
	var p := _center(g, uv)
	g.face([Vector3(p.x, p.y, height - 1), Vector3(p.x + 5, p.y, height - 2), Vector3(p.x + 5, p.y, height - 9), Vector3(p.x, p.y, height - 8)], player)

static func draw_topdown(item: CanvasItem, bounds: Rect2, id: String, _palette: Dictionary, player: Color) -> bool:
	if not id.begins_with("zh_"): return false
	item.draw_rect(bounds.grow(-2), Color("a7a596"))
	item.draw_rect(_rect(bounds, Vector2(0.5, 0.64), Vector2(0.17, 0.66)), Color("c4bca5"))
	for v in [0.42, 0.58, 0.74, 0.9]:
		var p := bounds.position + bounds.size * Vector2(0.5, v)
		item.draw_line(p - Vector2(bounds.size.x * 0.085, 0), p + Vector2(bounds.size.x * 0.085, 0), Color("969788"), 0.8)
	match id:
		"zh_imperial_academy":
			_top_roof(item, bounds, Vector2(0.5, 0.24), Vector2(0.69, 0.3), TILE)
			for u in [0.17, 0.83]: _top_roof(item, bounds, Vector2(u, 0.53), Vector2(0.21, 0.43), TILE, true)
			_top_roof(item, bounds, Vector2(0.5, 0.83), Vector2(0.35, 0.18), TILE)
			item.draw_rect(_rect(bounds, Vector2(0.5, 0.58), Vector2(0.055, 0.025)), STONE.lightened(0.2))
			for u in [0.31, 0.69]: item.draw_rect(_rect(bounds, Vector2(u, 0.68), Vector2(0.07, 0.07)), Color("6b8157"))
		"zh_barbican":
			_top_wall(item, bounds, Vector2(0.5, 0.2), Vector2(0.74, 0.095))
			for u in [0.17, 0.83]: _top_wall(item, bounds, Vector2(u, 0.44), Vector2(0.095, 0.5))
			_top_wall(item, bounds, Vector2(0.5, 0.69), Vector2(0.38, 0.15))
			for u in [0.24, 0.76]: _top_roof(item, bounds, Vector2(u, 0.65), Vector2(0.25, 0.25), Color("788276"))
		"zh_clocktower":
			for u in [0.17, 0.83]: _top_roof(item, bounds, Vector2(u, 0.67), Vector2(0.23, 0.3), TILE, true)
			_top_roof(item, bounds, Vector2(0.5, 0.46), Vector2(0.36, 0.36), TILE)
			_top_roof(item, bounds, Vector2(0.5, 0.46), Vector2(0.27, 0.28), TILE.lightened(0.09))
		"zh_imperial_palace":
			for u in [0.12, 0.88]: _top_roof(item, bounds, Vector2(u, 0.59), Vector2(0.18, 0.4), Color("a58c50"), true)
			_top_roof(item, bounds, Vector2(0.5, 0.29), Vector2(0.72, 0.36), Color("b69a53"))
			_top_roof(item, bounds, Vector2(0.5, 0.29), Vector2(0.59, 0.26), Color("c0a15a"))
			_top_roof(item, bounds, Vector2(0.5, 0.78), Vector2(0.44, 0.2), Color("b69a53"))
		"zh_gatehouse":
			for u in [0.12, 0.88]: _top_wall(item, bounds, Vector2(u, 0.51), Vector2(0.19, 0.3))
			_top_wall(item, bounds, Vector2(0.5, 0.51), Vector2(0.61, 0.29))
			_top_roof(item, bounds, Vector2(0.5, 0.51), Vector2(0.57, 0.3), TILE)
			_top_roof(item, bounds, Vector2(0.5, 0.51), Vector2(0.41, 0.23), TILE.lightened(0.09))
		"zh_spirit_way":
			_top_roof(item, bounds, Vector2(0.5, 0.22), Vector2(0.65, 0.3), Color("8b8873"))
			_top_roof(item, bounds, Vector2(0.5, 0.22), Vector2(0.53, 0.23), Color("959079"))
			_top_roof(item, bounds, Vector2(0.5, 0.56), Vector2(0.5, 0.13), TILE)
			for u in [0.25, 0.75]:
				for v in [0.72, 0.87]:
					var box := _rect(bounds, Vector2(u, v), Vector2(0.08, 0.1))
					item.draw_rect(box, STONE.darkened(0.15))
					item.draw_rect(box.grow(-1.5), STONE.lightened(0.1))
		_: return false
	# Keep a small civilization/player accent visible without covering the plan.
	item.draw_rect(_rect(bounds, Vector2(0.5, 0.94), Vector2(0.1, 0.018)), player)
	return true

static func _rect(bounds: Rect2, uv: Vector2, span: Vector2) -> Rect2:
	var size := bounds.size * span
	return Rect2(bounds.position + bounds.size * uv - size * 0.5, size)

static func _top_roof(item: CanvasItem, bounds: Rect2, uv: Vector2, span: Vector2, color: Color, along_y := false) -> void:
	var box := _rect(bounds, uv, span)
	item.draw_rect(Rect2(box.position + Vector2(1.5, 2.5), box.size), Color(0.18, 0.2, 0.18, 0.3))
	# Octagonal swept corners, four roof planes and a long ridge.
	var points := PackedVector2Array([box.position + Vector2(0, 2), box.position + Vector2(2, 0), Vector2(box.end.x - 2, box.position.y), Vector2(box.end.x, box.position.y + 2), box.end - Vector2(0, 2), box.end - Vector2(2, 0), Vector2(box.position.x + 2, box.end.y), Vector2(box.position.x, box.end.y - 2)])
	FilledPolygon.draw(item, points, color)
	item.draw_polyline(points + PackedVector2Array([points[0]]), DARK, 1)
	var center := box.get_center()
	var first := center - Vector2(0, box.size.y * 0.3) if along_y else center - Vector2(box.size.x * 0.3, 0)
	var last := center + Vector2(0, box.size.y * 0.3) if along_y else center + Vector2(box.size.x * 0.3, 0)
	FilledPolygon.draw(item, PackedVector2Array([box.position, Vector2(box.end.x, box.position.y), last, first]), color.lightened(0.15))
	for corner in [box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)]:
		item.draw_line(corner, first if corner.distance_squared_to(first) < corner.distance_squared_to(last) else last, color.darkened(0.22), 0.8)
	# Sparse rows of tiles are enough to convey scale without noisy stripes.
	for f in [0.24, 0.76]:
		if along_y:
			var x := lerpf(box.position.x, box.end.x, f)
			item.draw_line(Vector2(x, box.position.y + 3), Vector2(x, box.end.y - 3), color.darkened(0.13), 0.7)
		else:
			var y := lerpf(box.position.y, box.end.y, f)
			item.draw_line(Vector2(box.position.x + 3, y), Vector2(box.end.x - 3, y), color.darkened(0.13), 0.7)
	item.draw_line(first, last, GOLD.darkened(0.1), 1.4)
	item.draw_circle(first, 1.1, GOLD)
	item.draw_circle(last, 1.1, GOLD)

static func _top_wall(item: CanvasItem, bounds: Rect2, uv: Vector2, span: Vector2) -> void:
	var box := _rect(bounds, uv, span)
	item.draw_rect(box, STONE.darkened(0.2))
	item.draw_rect(box.grow(-1.5), STONE)
	for x in [box.position.x + 1, box.end.x - 1]:
		for y in [box.position.y + 1, box.end.y - 1]: item.draw_rect(Rect2(Vector2(x, y) - Vector2.ONE, Vector2.ONE * 2), STONE.lightened(0.1))

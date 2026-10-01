extends RefCounted

# Three different plans, built from the same depth-sorted local faces as the
# landmarks. Architectural scale comes from halls, towers and open approaches.
const Chinese = preload("res://scripts/entities/visuals/chinese_landmark_visual.gd")
const FilledPolygon = preload("res://scripts/entities/visuals/filled_polygon.gd")
const STONE := Color("c3bda9")
const SLATE := Color("586975")
const DARK := Color("354349")
const GOLD := Color("cfad61")

static func populate(g, civilization: String, player: Color) -> bool:
	if civilization not in ["English", "French", "Chinese"]: return false
	match civilization:
		"English":
			# A cruciform cathedral with a tall clerestory and twin west towers.
			_hall(g, Vector2(0.5, 0.41), Vector2(0.3, 0.64), 0.7, 35, true)
			_hall(g, Vector2(0.5, 0.33), Vector2(0.67, 0.19), 0.7, 26, false)
			for u in [0.27, 0.73]:
				_hall(g, Vector2(u, 0.45), Vector2(0.15, 0.53), 0.7, 19, true)
				_tower(g, Vector2(u, 0.76), Vector2(0.18, 0.2), 0.7, 59, false)
				for v in [0.2, 0.43, 0.63]: _flying_buttress(g, u, v)
			_hall(g, Vector2(0.5, 0.75), Vector2(0.27, 0.17), 0.7, 36, false)
			_rose(g, _p(g, Vector2(0.5, 0.836), 24), 5.2)
			_portal(g, Vector2(0.5, 0.837), 0.7, 12, 8)
			_steps(g, Vector2(0.5, 0.9), 0.24, 3)
			_banner(g, Vector2(0.25, 0.89), 18, player)
		"French":
			# A terraced abbey: a single needle spire above asymmetrical halls.
			_terrace(g, Vector2(0.52, 0.3), Vector2(0.52, 0.43), 12)
			_hall(g, Vector2(0.52, 0.3), Vector2(0.34, 0.37), 12, 37, true)
			_hall(g, Vector2(0.21, 0.46), Vector2(0.2, 0.45), 1, 24, true)
			_hall(g, Vector2(0.79, 0.43), Vector2(0.2, 0.37), 6, 28, true)
			_hall(g, Vector2(0.48, 0.7), Vector2(0.62, 0.18), 1, 22, false)
			_tower(g, Vector2(0.52, 0.28), Vector2(0.16, 0.17), 49, 22, true)
			for u in [0.18, 0.78]: _tower(g, Vector2(u, 0.7), Vector2(0.1, 0.14), 1, 31, true, 10)
			_portal(g, Vector2(0.48, 0.791), 1, 11, 7)
			_steps(g, Vector2(0.48, 0.87), 0.21, 5)
			# A cloister visible between the lower wings and the abbey above.
			for u in [0.36, 0.47, 0.58, 0.69]:
				_box(g, Vector2(u, 0.6), Vector2(0.014, 0.014), 1, 10, STONE.lightened(0.08))
			_box(g, Vector2(0.525, 0.6), Vector2(0.37, 0.03), 11, 2, STONE)
			_banner(g, Vector2(0.87, 0.64), 20, player)
		"Chinese":
			# A five-storey octagonal pagoda with stepped swept eaves; lower
			# halls and garden pavilions keep the tower rooted in a temple court.
			Chinese._hall(g, Vector2(0.81, 0.57), Vector2(0.16, 0.19), 11, GOLD.darkened(0.13), false, false)
			_box(g, Vector2(0.14, 0.79), Vector2(0.15, 0.17), 0.7, 1, STONE)
			_box(g, Vector2(0.14, 0.79), Vector2(0.11, 0.13), 1.71, 0.1, Color("668e88"))
			Chinese._hall(g, Vector2(0.5, 0.79), Vector2(0.47, 0.18), 15, GOLD.darkened(0.1), true, false)
			var center := _center(g, Vector2(0.5, 0.35))
			for tier in 5:
				var radius: float = g.dimensions.x * (0.145 - float(tier) * 0.014)
				var bottom := 2.0 + float(tier) * 18
				_octagon(g, center, radius + 1.2, bottom, 1.7, STONE)
				_octagon(g, center, radius * 0.87, bottom + 1.7, 11.3, Color("bda78d"))
				for side in 8:
					var angle := float(side) * TAU / 8 + PI / 8
					if cos(angle) + sin(angle) < -0.55: continue
					var p: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius
					g.box(p, Vector2(1.7, 1.7), bottom + 1.7, 11.3, Color("954b3e"))
				_oct_roof(g, center, radius + 4, bottom + 13, 7, GOLD.darkened(float(tier) * 0.02))
			g.box(center, Vector2(1.6, 1.6), 94, 9, GOLD)
			g.disc(Vector3(center.x, center.y, 102), 2, GOLD.lightened(0.2))
			Chinese._steps(g, Vector2(0.5, 0.55), 0.2)
			for u in [0.28, 0.72]: Chinese._planter(g, Vector2(u, 0.67))
			_banner(g, Vector2(0.78, 0.9), 16, player)
	return true

static func _center(g, uv: Vector2) -> Vector2:
	return (uv - Vector2.ONE * 0.5) * g.dimensions

static func _p(g, uv: Vector2, height: float) -> Vector3:
	var p := _center(g, uv)
	return Vector3(p.x, p.y, height)

static func _box(g, uv: Vector2, span: Vector2, bottom: float, height: float, color: Color) -> void:
	g.box(_center(g, uv), span * g.dimensions, bottom, height, color)

static func _hall(g, uv: Vector2, span: Vector2, bottom: float, height: float, along_y: bool) -> void:
	var center := _center(g, uv)
	var extent: Vector2 = span * g.dimensions
	g.box(center, extent, bottom, height, STONE)
	g.box(center, extent + Vector2(2, 2), bottom + height - 2, 2, STONE.lightened(0.12))
	var a := Vector3(center.x - extent.x * 0.5 - 1, center.y - extent.y * 0.5 - 1, bottom + height)
	var b := a + Vector3(extent.x + 2, 0, 0)
	var c := b + Vector3(0, extent.y + 2, 0)
	var d := a + Vector3(0, extent.y + 2, 0)
	var rise := minf(extent.x if along_y else extent.y, 28) * 0.43
	var r0 := (a + b) * 0.5 + Vector3(0, 0, rise) if along_y else (a + d) * 0.5 + Vector3(0, 0, rise)
	var r1 := (d + c) * 0.5 + Vector3(0, 0, rise) if along_y else (b + c) * 0.5 + Vector3(0, 0, rise)
	if along_y:
		g.face([a, b, r0], STONE.darkened(0.08))
		g.face([d, c, r1], STONE)
		g.face([a, r0, r1, d], SLATE.lightened(0.12))
		g.face([r0, b, c, r1], SLATE)
	else:
		g.face([a, d, r0], STONE)
		g.face([b, c, r1], STONE.darkened(0.14))
		g.face([a, b, r1, r0], SLATE.lightened(0.12))
		g.face([r0, r1, c, d], SLATE)
	# Tall lancet openings sit in the stone walls and clerestory.
	for f in [0.25, 0.75]:
		_lancet(g, Vector3(center.x + extent.x * (f - 0.5), center.y + extent.y * 0.5 + 0.04, bottom + height * 0.38), minf(3, extent.x * 0.12), height * 0.3, false)
		_lancet(g, Vector3(center.x + extent.x * 0.5 + 0.04, center.y + extent.y * (f - 0.5), bottom + height * 0.38), minf(3, extent.y * 0.12), height * 0.3, true)

static func _tower(g, uv: Vector2, span: Vector2, bottom: float, height: float, spire: bool, rise := 30.0) -> void:
	var center := _center(g, uv)
	var extent: Vector2 = span * g.dimensions
	g.box(center, extent, bottom, height, STONE.lightened(0.04))
	for level in [0.28, 0.66, 0.94]:
		g.box(center, extent + Vector2(1.8, 1.8), bottom + height * level, 1.2, STONE.lightened(0.15))
	for side in [-1.0, 1.0]:
		_lancet(g, Vector3(center.x + extent.x * 0.2 * side, center.y + extent.y * 0.5 + 0.04, bottom + height * 0.65), 2.5, height * 0.19, false)
		_lancet(g, Vector3(center.x + extent.x * 0.5 + 0.04, center.y + extent.y * 0.2 * side, bottom + height * 0.65), 2.5, height * 0.19, true)
	if spire:
		var a := Vector3(center.x - extent.x * 0.5 - 0.8, center.y - extent.y * 0.5 - 0.8, bottom + height)
		var b := a + Vector3(extent.x + 1.6, 0, 0)
		var c := b + Vector3(0, extent.y + 1.6, 0)
		var d := a + Vector3(0, extent.y + 1.6, 0)
		g.pyramid(a, b, c, d, rise, SLATE)
		g.box(center, Vector2(0.8, 0.8), bottom + height + rise, 4, GOLD)
		g.box(center, Vector2(3.5, 0.8), bottom + height + rise + 2, 0.8, GOLD)
	else:
		g.box(center, extent + Vector2(1, 1), bottom + height, 2, STONE.lightened(0.12))
		for u in [-0.42, 0.42]:
			for v in [-0.42, 0.42]:
				var p := center + extent * Vector2(u, v)
				g.box(p, Vector2(2, 2), bottom + height, 5, STONE.lightened(0.1))
				var a := Vector3(p.x - 1.5, p.y - 1.5, bottom + height + 5)
				g.pyramid(a, a + Vector3(3, 0, 0), a + Vector3(3, 3, 0), a + Vector3(0, 3, 0), 4, SLATE)

static func _lancet(g, p: Vector3, width: float, height: float, side: bool) -> void:
	var across := Vector3(0, width, 0) if side else Vector3(width, 0, 0)
	g.face([p - across * 0.5, p + across * 0.5, p + across * 0.5 + Vector3(0, 0, height * 0.78), p + Vector3(0, 0, height), p - across * 0.5 + Vector3(0, 0, height * 0.78)], DARK)
	var mullion := Vector3(0, 0.45, 0) if side else Vector3(0.45, 0, 0)
	var lift := Vector3(0.012, 0, 0) if side else Vector3(0, 0.012, 0)
	g.face([p - mullion * 0.5 + lift, p + mullion * 0.5 + lift, p + mullion * 0.5 + lift + Vector3(0, 0, height * 0.77), p - mullion * 0.5 + lift + Vector3(0, 0, height * 0.77)], STONE.darkened(0.08))

static func _flying_buttress(g, u: float, v: float) -> void:
	var side := -1.0 if u < 0.5 else 1.0
	var outer := _center(g, Vector2(0.5 + side * 0.34, v))
	var inner := _center(g, Vector2(0.5 + side * 0.155, v))
	g.box(outer, Vector2(2.8, 3.2), 0.7, 21, STONE.darkened(0.06))
	var low := Vector3(outer.x, outer.y, 18)
	var high := Vector3(inner.x, inner.y, 29)
	var depth := Vector3(0, 1.5, 0)
	var up := Vector3(0, 0, 2.4)
	g.face([low + depth, high + depth, high + up + depth, low + up + depth], STONE)
	g.face([low - depth + up, high - depth + up, high + depth + up, low + depth + up], STONE.lightened(0.1))
	g.face([high - depth, high + depth, high + depth + up, high - depth + up], STONE.darkened(0.2))

static func _rose(g, p: Vector3, radius: float) -> void:
	g.disc(p, radius + 0.9, STONE.lightened(0.18))
	g.disc(p + Vector3(0, 0.015, 0), radius, DARK)
	for i in 8:
		var angle := float(i) * TAU / 8
		var dir := Vector3(cos(angle), 0, sin(angle))
		var across := Vector3(-sin(angle), 0, cos(angle)) * 0.25
		var lift := Vector3(0, 0.03, 0)
		g.face([p - across + lift, p + dir * radius - across + lift, p + dir * radius + across + lift, p + across + lift], STONE)
	g.disc(p + Vector3(0, 0.04, 0), 1.4, GOLD)

static func _portal(g, uv: Vector2, bottom: float, height: float, width: float) -> void:
	var p := _p(g, uv, bottom)
	_lancet(g, p, width + 2, height + 1.5, false)
	g.box(Vector2(p.x - width * 0.5 - 0.8, p.y + 0.02), Vector2(1.1, 1), bottom, height * 0.75, STONE.lightened(0.12))
	g.box(Vector2(p.x + width * 0.5 + 0.8, p.y + 0.02), Vector2(1.1, 1), bottom, height * 0.75, STONE.lightened(0.12))

static func _steps(g, uv: Vector2, width: float, count: int) -> void:
	for i in count:
		_box(g, uv + Vector2(0, float(i) * 0.02), Vector2(width, 0.024), 0, float(count - i) * 0.9, STONE.lightened(0.08))

static func _terrace(g, uv: Vector2, span: Vector2, height: float) -> void:
	var center := _center(g, uv)
	var extent: Vector2 = span * g.dimensions
	var base := [Vector3(center.x - extent.x * 0.5, center.y - extent.y * 0.5, 0.7), Vector3(center.x + extent.x * 0.5, center.y - extent.y * 0.5, 0.7), Vector3(center.x + extent.x * 0.5, center.y + extent.y * 0.5, 0.7), Vector3(center.x - extent.x * 0.5, center.y + extent.y * 0.5, 0.7)]
	var top: Array = []
	for p in base: top.append(Vector3(lerpf(p.x, center.x, 0.1), lerpf(p.y, center.y, 0.1), height))
	for i in [1, 2]:
		g.face([base[i], base[(i + 1) % 4], top[(i + 1) % 4], top[i]], Color("a9a28e").darkened(0.1 if i == 1 else 0))
	g.face(top, STONE)

static func _octagon(g, center: Vector2, radius: float, bottom: float, height: float, color: Color) -> void:
	var top: Array = []
	for i in 8:
		var a := float(i) * TAU / 8 + PI / 8
		var b := float(i + 1) * TAU / 8 + PI / 8
		var p := Vector3(center.x + cos(a) * radius, center.y + sin(a) * radius, bottom)
		var q := Vector3(center.x + cos(b) * radius, center.y + sin(b) * radius, bottom)
		# Back-facing walls of an opaque prism cannot be seen by the game's
		# fixed camera. Keep its complete top and the three facing walls.
		var normal := Vector2(cos((a + b) * 0.5), sin((a + b) * 0.5))
		if normal.x + normal.y > 0.001:
			g.face([p, q, q + Vector3(0, 0, height), p + Vector3(0, 0, height)], color.darkened(0.12 * (1 - sin(a + PI / 4))))
		top.append(p + Vector3(0, 0, height))
	g.face(top, color.lightened(0.08))

static func _oct_roof(g, center: Vector2, radius: float, bottom: float, rise: float, color: Color) -> void:
	for i in 8:
		var a := float(i) * TAU / 8 + PI / 8
		var b := float(i + 1) * TAU / 8 + PI / 8
		var pa := Vector3(cos(a), sin(a), 0)
		var pb := Vector3(cos(b), sin(b), 0)
		var c := Vector3(center.x, center.y, bottom)
		var edge_a := c + pa * radius + Vector3(0, 0, 1.4)
		var edge_b := c + pb * radius + Vector3(0, 0, 1.4)
		var middle_a := c + pa * radius * 0.67 + Vector3(0, 0, 2.4)
		var middle_b := c + pb * radius * 0.67 + Vector3(0, 0, 2.4)
		var high_a := c + pa * radius * 0.25 + Vector3(0, 0, rise)
		var high_b := c + pb * radius * 0.25 + Vector3(0, 0, rise)
		var tint := color.lightened(0.12 * sin(a + PI / 4))
		g.face([edge_a - Vector3(0, 0, 1), edge_b - Vector3(0, 0, 1), edge_b, edge_a], color.darkened(0.3))
		g.face([edge_a, edge_b, middle_b, middle_a], tint)
		g.face([middle_a, middle_b, high_b, high_a], tint.lightened(0.05))
		g.face([high_a, high_b, c + Vector3(0, 0, rise + 0.7)], tint)

static func _banner(g, uv: Vector2, height: float, player: Color) -> void:
	_box(g, uv, Vector2(0.008, 0.008), 0, height, Color("6f5742"))
	var p := _p(g, uv, height)
	g.face([p, p + Vector3(5, 0, -1), p + Vector3(5, 0, -7), p + Vector3(0, 0, -6)], player)

static func draw_topdown(item: CanvasItem, bounds: Rect2, civilization: String, _palette: Dictionary, player: Color) -> bool:
	if civilization not in ["English", "French", "Chinese"]: return false
	item.draw_rect(bounds.grow(-2), Color("a8a392"))
	match civilization:
		"English":
			for u in [0.27, 0.73]: _top_hall(item, bounds, Vector2(u, 0.45), Vector2(0.15, 0.53), true)
			_top_hall(item, bounds, Vector2(0.5, 0.33), Vector2(0.67, 0.19), false)
			_top_hall(item, bounds, Vector2(0.5, 0.41), Vector2(0.3, 0.64), true)
			_top_hall(item, bounds, Vector2(0.5, 0.75), Vector2(0.27, 0.17), false)
			for u in [0.27, 0.73]:
				var box := _rect(bounds, Vector2(u, 0.76), Vector2(0.18, 0.2))
				item.draw_rect(box, STONE)
				item.draw_rect(box.grow(-2), DARK)
				for p in [box.position, box.end, Vector2(box.end.x, box.position.y), Vector2(box.position.x, box.end.y)]: item.draw_rect(Rect2(p - Vector2.ONE * 1.5, Vector2.ONE * 3), STONE.lightened(0.1))
			for u in [0.16, 0.84]:
				for v in [0.2, 0.43, 0.63]: item.draw_rect(_rect(bounds, Vector2(u, v), Vector2(0.04, 0.03)), STONE)
		"French":
			item.draw_rect(_rect(bounds, Vector2(0.52, 0.3), Vector2(0.52, 0.43)), STONE.darkened(0.18))
			_top_hall(item, bounds, Vector2(0.21, 0.46), Vector2(0.2, 0.45), true)
			_top_hall(item, bounds, Vector2(0.79, 0.43), Vector2(0.2, 0.37), true)
			_top_hall(item, bounds, Vector2(0.48, 0.7), Vector2(0.62, 0.18), false)
			_top_hall(item, bounds, Vector2(0.52, 0.3), Vector2(0.34, 0.37), true)
			for uv in [Vector2(0.52, 0.28), Vector2(0.18, 0.7), Vector2(0.78, 0.7)]:
				_top_spire(item, bounds, uv, Vector2(0.16, 0.17) if uv.y < 0.5 else Vector2(0.1, 0.14))
		"Chinese":
			Chinese._top_roof(item, bounds, Vector2(0.81, 0.57), Vector2(0.22, 0.25), GOLD.darkened(0.13))
			item.draw_rect(_rect(bounds, Vector2(0.14, 0.79), Vector2(0.15, 0.17)), STONE)
			item.draw_rect(_rect(bounds, Vector2(0.14, 0.79), Vector2(0.11, 0.13)), Color("668e88"))
			Chinese._top_roof(item, bounds, Vector2(0.5, 0.79), Vector2(0.53, 0.24), GOLD.darkened(0.1))
			Chinese._top_roof(item, bounds, Vector2(0.5, 0.79), Vector2(0.43, 0.17), GOLD)
			var center := bounds.position + bounds.size * Vector2(0.5, 0.35)
			for tier in 5:
				var radius := bounds.size.x * (0.18 - tier * 0.019)
				var ring := PackedVector2Array()
				for i in 8:
					var a := float(i) * TAU / 8 + PI / 8
					ring.append(center + Vector2(cos(a), sin(a)) * radius)
				FilledPolygon.draw(item, ring, GOLD.lightened(tier * 0.025))
				item.draw_polyline(ring + PackedVector2Array([ring[0]]), GOLD.darkened(0.35), 0.9)
				if tier == 4:
					for p in ring: item.draw_line(p, center, GOLD.darkened(0.15), 0.7)
			item.draw_circle(center, 2, GOLD.lightened(0.3))
	item.draw_rect(_rect(bounds, Vector2(0.5, 0.94), Vector2(0.1, 0.015)), player)
	return true

static func _rect(bounds: Rect2, uv: Vector2, span: Vector2) -> Rect2:
	var size := bounds.size * span
	return Rect2(bounds.position + bounds.size * uv - size * 0.5, size)

static func _top_hall(item: CanvasItem, bounds: Rect2, uv: Vector2, span: Vector2, along_y: bool) -> void:
	var box := _rect(bounds, uv, span)
	item.draw_rect(Rect2(box.position + Vector2(1.5, 2), box.size), Color(0.2, 0.21, 0.2, 0.3))
	item.draw_rect(box, SLATE)
	var center := box.get_center()
	var ridge_a := Vector2(center.x, box.position.y) if along_y else Vector2(box.position.x, center.y)
	var ridge_b := Vector2(center.x, box.end.y) if along_y else Vector2(box.end.x, center.y)
	FilledPolygon.draw(item, PackedVector2Array([box.position, Vector2(box.end.x, box.position.y), ridge_b, ridge_a]) if not along_y else PackedVector2Array([box.position, ridge_a, ridge_b, Vector2(box.position.x, box.end.y)]), SLATE.lightened(0.14))
	item.draw_rect(box, STONE.darkened(0.2), false, 1)
	item.draw_line(ridge_a, ridge_b, SLATE.lightened(0.25), 1.4)

static func _top_spire(item: CanvasItem, bounds: Rect2, uv: Vector2, span: Vector2) -> void:
	var box := _rect(bounds, uv, span)
	item.draw_rect(box, SLATE)
	for p in [box.position, box.end, Vector2(box.position.x, box.end.y), Vector2(box.end.x, box.position.y)]: item.draw_line(p, box.get_center(), SLATE.lightened(0.25), 1)
	item.draw_circle(box.get_center(), 1.3, GOLD)

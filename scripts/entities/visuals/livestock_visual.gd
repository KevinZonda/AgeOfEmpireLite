extends RefCounted

const Quadruped = preload("res://scripts/entities/visuals/quadruped_visual.gd")
const OUTLINE := Color("26352d")

static func draw(item: CanvasItem, base: Transform2D, species: String, direction: Vector2, phase: float, gait: float, graze: float, time: float, attack_timer: float, alive: bool, wool: Color) -> void:
	var figure := Quadruped.figure_transform(base, direction, 18.0 if species == "sheep" else 12.0)
	if not alive:
		_draw_carcass(item, base, direction, species, wool)
		return
	item.draw_set_transform_matrix(figure)
	if species == "sheep":
		Quadruped.draw_legs(item, phase, gait, -10.0, 8.0, 4.0, 19.0, 3.2, 2.2, Color("6b6252"), Color("998b75"))
		var torso := figure * Transform2D(0.0, Vector2(0, -absf(sin(phase)) * 0.35 * gait))
		item.draw_set_transform_matrix(torso)
		_draw_wool(item, wool)
		item.draw_line(Vector2(-18, -1), Vector2(-22, 0), wool.darkened(0.2), 4.0)
		var head := torso * Transform2D(graze * 1.05 + sin(time * 2.5) * graze * 0.04, Vector2(11, graze * 4.0))
		if direction.y < -0.55: head.origin += torso.basis_xform(Vector2(-3, -2))
		item.draw_set_transform_matrix(head)
		item.draw_circle(Vector2(6, -5), 6.0, Color("d8ccb2"))
		item.draw_arc(Vector2(6, -5), 6.0, 0.0, TAU, 16, OUTLINE, 1.3)
		item.draw_line(Vector2(8, -3), Vector2(13, -1), Color("d8ccb2"), 4.5)
		item.draw_circle(Vector2(13, -1), 1.4, Color("6b6252"))
		item.draw_line(Vector2(4, -9), Vector2(0, -12), Color("baa98b"), 3.5)
		if direction.y >= -0.55: item.draw_circle(Vector2(8, -6), 1.2, OUTLINE)
	else:
		Quadruped.draw_legs(item, phase, gait, -13.0, 10.0, 3.0, 13.0, 3.8, 1.8, Color("47382d"), Color("72523d"))
		# A short forward lean accompanies an actual hit, then eases back.
		var strike := sin(clampf(attack_timer / 0.36, 0.0, 1.0) * PI)
		var torso := figure * Transform2D(strike * 0.045, Vector2(strike * 2.0, -absf(sin(phase)) * 0.3 * gait))
		item.draw_set_transform_matrix(torso)
		var body := PackedVector2Array([Vector2(-20, -4), Vector2(-14, -11), Vector2(2, -12), Vector2(13, -7), Vector2(17, 2), Vector2(9, 6), Vector2(-17, 6)])
		_poly(item, body, Color("684d3a"))
		item.draw_line(Vector2(-14, -9), Vector2(3, -10), Color("947054"), 2.0)
		for x in [-12.0, -7.0, -2.0]: item.draw_line(Vector2(x, -11), Vector2(x - 1, -15), Color("47382d"), 1.5)
		item.draw_polyline(PackedVector2Array([Vector2(-19, 0), Vector2(-25, -3), Vector2(-26, 0)]), Color("47382d"), 1.8)
		var head := torso * Transform2D(graze * 0.3 + strike * 0.15 + sin(time * 2.0) * graze * 0.025, Vector2(12, -3 + graze * 3))
		if direction.y < -0.55: head.origin += torso.basis_xform(Vector2(-3, -2))
		item.draw_set_transform_matrix(head)
		item.draw_circle(Vector2(5, 0), 7.0, Color("795640"))
		item.draw_arc(Vector2(5, 0), 7.0, 0.0, TAU, 16, OUTLINE, 1.3)
		_poly(item, PackedVector2Array([Vector2(8, -2), Vector2(17, 0), Vector2(17, 5), Vector2(8, 5)]), Color("986d4d"))
		item.draw_line(Vector2(16, 1), Vector2(16, 4), Color("47382d"), 1.5)
		item.draw_polyline(PackedVector2Array([Vector2(11, 5), Vector2(13, 1), Vector2(12, -2)]), Color("e4d5ad"), 2.0)
		_poly(item, PackedVector2Array([Vector2(0, -5), Vector2(-1, -12), Vector2(5, -6)]), Color("684d3a"))
		if direction.y >= -0.55: item.draw_circle(Vector2(8, -2), 1.2, OUTLINE)
	item.draw_set_transform_matrix(base)

static func _draw_wool(item: CanvasItem, wool: Color) -> void:
	# Overlapping tufts form a round, compact sheep silhouette.
	for center in [Vector2(-11, -2), Vector2(0, -5), Vector2(10, -2), Vector2(1, 2)]:
		item.draw_circle(center, 10.0, OUTLINE)
	for center in [Vector2(-11, -2), Vector2(0, -5), Vector2(10, -2), Vector2(1, 2)]:
		item.draw_circle(center, 8.5, wool)
	item.draw_arc(Vector2(-9, -3), 4.0, PI * 1.05, PI * 1.7, 8, wool.darkened(0.15), 1.0)
	item.draw_arc(Vector2(2, -6), 4.0, PI * 1.1, PI * 1.75, 8, wool.lightened(0.1), 1.0)

static func _draw_carcass(item: CanvasItem, base: Transform2D, direction: Vector2, species: String, wool: Color) -> void:
	var figure := Quadruped.figure_transform(base, direction, 2.0)
	item.draw_set_transform_matrix(figure)
	var body := PackedVector2Array([Vector2(-20, 1), Vector2(-14, -6), Vector2(10, -6), Vector2(19, 1), Vector2(13, 7), Vector2(-15, 7)])
	_poly(item, body, wool.darkened(0.16) if species == "sheep" else Color("886b54"))
	item.draw_line(Vector2(-8, 3), Vector2(-14, 7), Color("543f31"), 2.5)
	item.draw_line(Vector2(6, 3), Vector2(12, 7), Color("543f31"), 2.5)
	item.draw_circle(Vector2(20, 1), 5.0, Color("baa98b") if species == "sheep" else Color("795640"))
	item.draw_line(Vector2(20, 0), Vector2(23, 1), OUTLINE, 1.2)
	if species == "boar": item.draw_line(Vector2(23, 4), Vector2(26, 0), Color("e4d5ad"), 2.0)
	item.draw_set_transform_matrix(base)

static func _poly(item: CanvasItem, shape: PackedVector2Array, color: Color) -> void:
	item.draw_colored_polygon(shape, color)
	item.draw_polyline(shape + PackedVector2Array([shape[0]]), OUTLINE, 1.5)

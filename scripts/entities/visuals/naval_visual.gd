extends RefCounted
class_name RtsNavalVisual

# Legacy ship art uses a fixed bow. Fishing boats share the new directional
# renderer with production units, portraits, and previews.
const Fishing = preload("res://scripts/entities/visuals/fishing_boat_visual.gd")
const INK := Color("20302f")
const HULL_DARK := Color("51392c")
const HULL := Color("8a603e")
const HULL_LIGHT := Color("bb8b57")
const DECK := Color("d0a977")
const ROPE := Color("e5d7ab")
const IRON := Color("626d6c")
const IRON_LIGHT := Color("c0c8bd")
const FIRE := Color("ef832f")
const FIRE_LIGHT := Color("ffe07d")

static func handles(kind: String) -> bool:
	return kind in ["fishing_boat", "warship", "springald_ship", "incendiary_ship", "arrow_ship", "transport_ship"]

static func draw_2d(canvas: CanvasItem, kind: String, radius: float, team: Color, passenger_count: int = 0) -> void:
	if not handles(kind): return
	if kind == "fishing_boat":
		Fishing.new().draw(canvas, Fishing.legacy_state(radius, team, false))
		return
	var beam := radius * (0.84 if kind == "transport_ship" else 0.77)
	if kind == "warship": beam = radius * 0.92
	var bow := -radius - 3.0
	var stern := radius + 2.0
	# Dark gunwale and an inset deck leave a clear, recognizable hull silhouette.
	_poly(canvas, [Vector2(0, bow - 3), Vector2(beam, bow + 9), Vector2(beam + 1, stern - 10), Vector2(beam * 0.6, stern), Vector2(-beam * 0.6, stern), Vector2(-beam - 1, stern - 10), Vector2(-beam, bow + 9)], INK)
	_poly(canvas, [Vector2(0, bow), Vector2(beam - 2, bow + 9), Vector2(beam, stern - 10), Vector2(beam * 0.55, stern - 2), Vector2(-beam * 0.55, stern - 2), Vector2(-beam, stern - 10), Vector2(-beam + 2, bow + 9)], HULL)
	_poly(canvas, [Vector2(0, bow + 4), Vector2(beam - 4, bow + 11), Vector2(beam - 5, stern - 10), Vector2(beam * 0.48, stern - 6), Vector2(-beam * 0.48, stern - 6), Vector2(-beam + 5, stern - 10), Vector2(-beam + 4, bow + 11)], DECK)
	_line(canvas, Vector2(-beam + 2, 0), Vector2(-beam + 2, stern - 10), team.darkened(0.14), 2.3)
	_line(canvas, Vector2(beam - 2, 0), Vector2(beam - 2, stern - 10), team.darkened(0.14), 2.3)
	match kind:
		"arrow_ship": _arrow_2d(canvas, radius, team)
		"springald_ship": _springald_2d(canvas, radius, team)
		"incendiary_ship": _incendiary_2d(canvas, radius, team)
		"warship": _warship_2d(canvas, radius, team)
		"transport_ship": _transport_2d(canvas, radius, team, passenger_count)

static func draw_25d(canvas: CanvasItem, kind: String, radius: float, team: Color, passenger_count: int = 0) -> void:
	if not handles(kind): return
	if kind == "fishing_boat":
		Fishing.new().draw(canvas, Fishing.legacy_state(radius, team, true))
		return
	var length := radius * 1.15
	var stern := -length
	var bow := length + 3.0
	# A high bow, curved keel, and light top edge stay legible at game scale.
	_poly(canvas, [Vector2(stern - 3, -15), Vector2(bow - 4, -16), Vector2(bow + 3, -24), Vector2(bow, -10), Vector2(bow - 8, -3), Vector2(stern + 7, -3), Vector2(stern - 2, -8)], INK)
	_poly(canvas, [Vector2(stern - 1, -16), Vector2(bow - 5, -17), Vector2(bow + 1, -23), Vector2(bow - 2, -11), Vector2(bow - 9, -5), Vector2(stern + 7, -5), Vector2(stern, -9)], HULL)
	_poly(canvas, [Vector2(stern + 1, -16), Vector2(bow - 5, -17), Vector2(bow - 2, -20), Vector2(stern - 1, -19)], HULL_LIGHT)
	_line(canvas, Vector2(stern + 5, -10), Vector2(bow - 8, -11), team.darkened(0.12), 2.2)
	match kind:
		"arrow_ship": _arrow_25d(canvas, radius, team)
		"springald_ship": _springald_25d(canvas, radius, team)
		"incendiary_ship": _incendiary_25d(canvas, radius, team)
		"warship": _warship_25d(canvas, radius, team)
		"transport_ship": _transport_25d(canvas, radius, team, passenger_count)

static func _arrow_2d(c: CanvasItem, r: float, team: Color) -> void:
	# Four visible archers and arrows aimed forward make this a fighting skiff.
	for y in [-7.0, 5.0]:
		for side in [-1.0, 1.0]:
			var x: float = side * (r * 0.49)
			c.draw_circle(Vector2(x, y), 2.8, INK)
			c.draw_circle(Vector2(x, y), 2.0, Color("e0bb91"))
			c.draw_arc(Vector2(x + side * 2.5, y - 2), 3.6, -PI * 0.75, PI * 0.28, 9, HULL_DARK, 1.5)
			_line(c, Vector2(x + side * 1.5, y + 2), Vector2(x + side * 1.5, y - 8), IRON_LIGHT, 1)
	for x in [-4.0, 0.0, 4.0]:
		_line(c, Vector2(x, 3), Vector2(x, -r + 2), HULL_DARK, 1.4)
		_poly(c, [Vector2(x - 1.5, -r + 3), Vector2(x, -r - 1), Vector2(x + 1.5, -r + 3)], IRON)
	_line(c, Vector2(-r * 0.62, r - 9), Vector2(r * 0.62, r - 9), team, 2)

static func _springald_2d(c: CanvasItem, r: float, team: Color) -> void:
	# The oversized crossbow spans both gunwales; its iron bolt exceeds the bow.
	_line(c, Vector2(0, r * 0.5), Vector2(0, -r - 5), HULL_DARK, 5)
	_line(c, Vector2(0, r * 0.5), Vector2(0, -r - 5), HULL_LIGHT, 2.7)
	_poly(c, [Vector2(-r + 1, -9), Vector2(-r * 0.47, -14), Vector2(0, -11), Vector2(r * 0.47, -14), Vector2(r - 1, -9), Vector2(r * 0.5, -11), Vector2(0, -8), Vector2(-r * 0.5, -11)], HULL_DARK)
	_line(c, Vector2(-r + 1, -9), Vector2(0, -2), ROPE, 1.2)
	_line(c, Vector2(r - 1, -9), Vector2(0, -2), ROPE, 1.2)
	_line(c, Vector2(0, 3), Vector2(0, -r - 9), IRON_LIGHT, 2)
	_poly(c, [Vector2(-3, -r - 6), Vector2(0, -r - 13), Vector2(3, -r - 6)], IRON)
	c.draw_circle(Vector2(0, -8), 2.2, team)

static func _incendiary_2d(c: CanvasItem, r: float, team: Color) -> void:
	# Exposed fire pots and glowing bow; no generic sail obscures the cargo.
	for y in [-5.0, 6.0]:
		for x in [-4.5, 4.5]:
			c.draw_circle(Vector2(x, y), 4, INK)
			c.draw_circle(Vector2(x, y), 3, Color("ac4e30"))
			c.draw_circle(Vector2(x, y), 1.4, FIRE_LIGHT)
	for x in [-6.0, 0.0, 6.0]:
		_flame(c, Vector2(x, -r + 1 + absf(x) * 0.4), 0.85)
	_line(c, Vector2(-r * 0.55, r * 0.5), Vector2(r * 0.55, r * 0.5), team.darkened(0.3), 2)

static func _warship_2d(c: CanvasItem, r: float, team: Color) -> void:
	# A broad armored rail, shields, stern castle and heavy mast.
	for side in [-1.0, 1.0]:
		for y in [-10.0, -2.0, 6.0]:
			var x: float = side * (r * 0.73)
			c.draw_circle(Vector2(x, y), 3.5, INK)
			c.draw_circle(Vector2(x, y), 2.5, team.darkened(0.15))
			c.draw_circle(Vector2(x, y), 0.9, IRON_LIGHT)
	_poly(c, [Vector2(-r * 0.62, r * 0.38), Vector2(r * 0.62, r * 0.38), Vector2(r * 0.45, r * 0.72), Vector2(-r * 0.45, r * 0.72)], HULL_DARK)
	_line(c, Vector2(-r * 0.55, r * 0.4), Vector2(r * 0.55, r * 0.4), HULL_LIGHT, 2)
	c.draw_circle(Vector2(0, -2), 3, HULL_DARK)
	_line(c, Vector2(0, -2), Vector2(0, -r * 0.7), HULL_DARK, 2.8)
	_poly(c, [Vector2(1, -r * 0.7), Vector2(9, -5), Vector2(1, -6)], team.lightened(0.28))
	_poly(c, [Vector2(-1, -r - 2), Vector2(0, -r - 7), Vector2(1, -r - 2)], IRON_LIGHT)

static func _transport_2d(c: CanvasItem, r: float, team: Color, count: int) -> void:
	# Wide open hold, occupied seats and a lowered boarding ramp.
	_poly(c, [Vector2(-r * 0.55, -r * 0.46), Vector2(r * 0.55, -r * 0.46), Vector2(r * 0.6, r * 0.55), Vector2(-r * 0.6, r * 0.55)], HULL_DARK)
	_poly(c, [Vector2(-r * 0.47, -r * 0.38), Vector2(r * 0.47, -r * 0.38), Vector2(r * 0.49, r * 0.46), Vector2(-r * 0.49, r * 0.46)], Color("ad8157"))
	for y in [-6.0, 5.0]: _line(c, Vector2(-r * 0.42, y + 3), Vector2(r * 0.42, y + 3), HULL_LIGHT, 1.2)
	var seats := [Vector2(-5, -6), Vector2(5, -6), Vector2(-5, 5), Vector2(5, 5)]
	for index in mini(count, seats.size()):
		c.draw_circle(seats[index], 2.5, INK)
		c.draw_circle(seats[index], 1.7, team.lightened(0.2))
	_poly(c, [Vector2(-6, -r + 3), Vector2(6, -r + 3), Vector2(8, -r - 8), Vector2(-8, -r - 8)], HULL_LIGHT)
	for x in [-4.0, 0.0, 4.0]:
		_line(c, Vector2(x, -r + 1), Vector2(x, -r - 7), HULL_DARK, 0.9)
	if count > 0: _count(c, str(count), Vector2(0, r * 0.63), 9)

static func _arrow_25d(c: CanvasItem, r: float, team: Color) -> void:
	for x in [-r * 0.57, 0.0, r * 0.54]:
		c.draw_circle(Vector2(x, -24), 3.1, Color("dfbd91"))
		_line(c, Vector2(x, -21), Vector2(x + 3, -15), team.darkened(0.2), 3)
		c.draw_arc(Vector2(x + 5, -27), 5.0, -PI * 0.8, PI * 0.5, 10, HULL_DARK, 1.7)
		_line(c, Vector2(x + 5, -20), Vector2(x + 5, -33), IRON_LIGHT, 1)
	for x in [-r * 0.43, r * 0.43]:
		_line(c, Vector2(x, -12), Vector2(x - 7, 3), HULL_LIGHT, 2.2)
	_line(c, Vector2(-r * 0.65, -18), Vector2(r * 0.68, -18), team, 2)

static func _springald_25d(c: CanvasItem, r: float, team: Color) -> void:
	_poly(c, [Vector2(-11, -20), Vector2(14, -24), Vector2(16, -19), Vector2(-9, -16)], HULL_DARK)
	_line(c, Vector2(-4, -20), Vector2(16, -31), HULL_LIGHT, 3.2)
	_line(c, Vector2(2, -28), Vector2(17, -35), HULL_DARK, 3)
	_line(c, Vector2(17, -35), Vector2(27, -31), HULL_DARK, 3)
	_line(c, Vector2(2, -28), Vector2(17, -25), ROPE, 1.1)
	_line(c, Vector2(27, -31), Vector2(17, -25), ROPE, 1.1)
	_line(c, Vector2(5, -26), Vector2(31, -37), IRON_LIGHT, 2.4)
	_poly(c, [Vector2(28, -39), Vector2(36, -39), Vector2(31, -35)], IRON)
	c.draw_circle(Vector2(11, -24), 2.5, team)

static func _incendiary_25d(c: CanvasItem, r: float, team: Color) -> void:
	for x in [-r * 0.5, 0.0, r * 0.48]:
		c.draw_circle(Vector2(x, -24), 5, INK)
		c.draw_circle(Vector2(x, -24), 3.7, Color("ac4e30"))
		c.draw_circle(Vector2(x, -26), 1.3, FIRE_LIGHT)
		_flame(c, Vector2(x, -29), 0.9)
	_flame(c, Vector2(r + 1, -23), 1.1)
	_line(c, Vector2(-r * 0.65, -19), Vector2(r * 0.7, -19), team.darkened(0.3), 2)

static func _warship_25d(c: CanvasItem, r: float, team: Color) -> void:
	# Taller armored broadside and a crenellated stern platform.
	_poly(c, [Vector2(-r - 2, -25), Vector2(-r * 0.42, -25), Vector2(-r * 0.4, -19), Vector2(-r - 2, -19)], HULL_DARK)
	for x in [-r * 0.85, -r * 0.5]:
		c.draw_rect(Rect2(x, -29, 5, 6), HULL_LIGHT)
	for x in [-r * 0.62, -r * 0.12, r * 0.38, r * 0.83]:
		_poly(c, [Vector2(x - 3, -14), Vector2(x + 3, -14), Vector2(x + 3, -6), Vector2(x - 3, -6)], IRON)
		c.draw_circle(Vector2(x, -11), 1.2, team.lightened(0.2))
	_line(c, Vector2(0, -18), Vector2(0, -44), HULL_DARK, 3)
	_poly(c, [Vector2(2, -42), Vector2(16, -32), Vector2(2, -32)], team.lightened(0.32))
	_line(c, Vector2(r * 0.6, -19), Vector2(r + 4, -19), HULL_LIGHT, 2)

static func _transport_25d(c: CanvasItem, r: float, team: Color, count: int) -> void:
	# Exposed hold and a hinged gangplank below the bow.
	_poly(c, [Vector2(-r * 0.7, -23), Vector2(r * 0.65, -23), Vector2(r * 0.65, -18), Vector2(-r * 0.7, -18)], HULL_DARK)
	_line(c, Vector2(-r * 0.7, -22), Vector2(r * 0.62, -22), HULL_LIGHT, 2)
	for x in [-r * 0.45, -r * 0.1, r * 0.25]: _line(c, Vector2(x, -20), Vector2(x + 4, -20), HULL_LIGHT, 1)
	var visible_seats := [-r * 0.45, -r * 0.1, r * 0.25]
	for index in mini(count, visible_seats.size()):
		var x: float = visible_seats[index]
		c.draw_circle(Vector2(x, -27), 3.2, Color("e0bf92"))
		_poly(c, [Vector2(x - 3, -24), Vector2(x + 3, -24), Vector2(x + 4, -18), Vector2(x - 4, -18)], team.darkened(0.1))
	_poly(c, [Vector2(r * 0.69, -16), Vector2(r + 13, -12), Vector2(r + 14, -9), Vector2(r * 0.7, -12)], HULL_LIGHT)
	for x in [r * 0.9, r + 8.0]:
		_line(c, Vector2(x, -14), Vector2(x, -10), HULL_DARK, 1)
	if count > 0: _count(c, str(count), Vector2(-r * 0.8, -26), 10)

static func _flame(c: CanvasItem, base: Vector2, scale: float) -> void:
	_poly(c, [base + Vector2(-3, 0) * scale, base + Vector2(-2, -6) * scale, base + Vector2(0, -10) * scale, base + Vector2(1, -5) * scale, base + Vector2(3, -2) * scale, base + Vector2(2, 0) * scale], FIRE)
	_poly(c, [base + Vector2(-1.3, 0) * scale, base + Vector2(0, -6) * scale, base + Vector2(1.3, 0) * scale], FIRE_LIGHT)

static func _count(c: CanvasItem, label: String, center: Vector2, font_size: int) -> void:
	c.draw_circle(center + Vector2(0, -font_size * 0.35), font_size * 0.57, Color("1b2928", 0.85))
	c.draw_string(ThemeDB.fallback_font, center + Vector2(-font_size * 0.31, 0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

static func _poly(c: CanvasItem, points: Array, fill: Color) -> void:
	c.draw_colored_polygon(PackedVector2Array(points), fill)

static func _line(c: CanvasItem, start: Vector2, finish: Vector2, fill: Color, width: float) -> void:
	c.draw_line(start, finish, fill, width, true)

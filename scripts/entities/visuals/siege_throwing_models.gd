extends RefCounted

# All dimensions are model-space pixels: -Y fires forward, +Z is height.
# The shared geometry renderer rotates and depth-sorts these real structures.
static func build(g, state) -> void:
	match state.kind:
		"trebuchet": _trebuchet(g, state)
		"mangonel": _mangonel(g, state)
		"springald": _springald(g, state)

static func _cart(g, half_width: float, half_length: float, wheel_radius: float) -> void:
	# An open ladder chassis keeps the wheelbase and side frames readable.
	for x in [-half_width + 3.0, half_width - 3.0]:
		g.box(Vector3(x - 1.7, -half_length, 5.0), Vector3(x + 1.7, half_length, 8.0), g.WOOD)
	for y in [-half_length + 4.0, 0.0, half_length - 4.0]:
		g.box(Vector3(-half_width + 2.0, y - 1.6, 5.0), Vector3(half_width - 2.0, y + 1.6, 7.5), g.WOOD_DARK)
	for y in [-half_length + 4.0, half_length - 4.0]:
		g.cylinder(Vector3(-half_width - 2.0, y, wheel_radius), Vector3(half_width + 2.0, y, wheel_radius), 1.35, g.IRON, 8)
		for x in [-half_width - 1.0, half_width + 1.0]:
			g.wheel(Vector3(x, y, wheel_radius), wheel_radius, 3.0)

static func _trebuchet(g, state) -> void:
	_cart(g, 14.0, 21.0, 4.7)
	# Two independent A frames, connected by a substantial transverse axle.
	for x in [-10.5, 10.5]:
		var crown := Vector3(x, 0.0, 34.0)
		g.beam(Vector3(x, -18.0, 7.0), crown, 4.0, g.WOOD)
		g.beam(Vector3(x, 18.0, 7.0), crown, 4.0, g.WOOD)
		g.beam(Vector3(x, -11.0, 17.5), Vector3(x, 11.0, 17.5), 2.5, g.WOOD_LIGHT)
		g.beam(Vector3(x, -17.0, 8.0), Vector3(x, 8.5, 21.5), 1.9, g.WOOD_DARK)
		g.beam(Vector3(x, 17.0, 8.0), Vector3(x, -8.5, 21.5), 1.9, g.WOOD_DARK)
		# Iron shoes at the four legs prevent a floating scaffold silhouette.
		for y in [-17.5, 17.5]:
			g.box(Vector3(x - 2.4, y - 2.2, 6.2), Vector3(x + 2.4, y + 2.2, 9.2), g.IRON)
		g.box(Vector3(x - 2.2, -2.0, 30.7), Vector3(x + 2.2, 2.0, 35.5), g.IRON)
	g.beam(Vector3(-11.5, -12.0, 15.0), Vector3(11.5, -12.0, 15.0), 2.3, g.WOOD_DARK)
	g.beam(Vector3(-11.5, 12.0, 15.0), Vector3(11.5, 12.0, 15.0), 2.3, g.WOOD_DARK)
	g.cylinder(Vector3(-14.0, 0.0, 33.0), Vector3(14.0, 0.0, 33.0), 2.2, g.IRON_LIGHT, 10)
	var motion := _throw_motion(g, state)
	var angle := deg_to_rad(20.0 + motion * 126.0)
	var pivot := Vector3(0.0, 0.0, 33.0)
	var direction := Vector3(0.0, cos(angle), sin(angle))
	var tip := pivot + direction * 29.0
	var heel := pivot - direction * 10.0
	g.beam(heel, tip, 3.6, g.WOOD_LIGHT)
	g.beam(pivot - direction * 4.5, pivot + direction * 4.5, 4.5, g.WOOD)
	# The counterweight hangs vertically from a separate pin as the arm rotates.
	g.cylinder(heel + Vector3(-3.3, 0.0, 0.0), heel + Vector3(3.3, 0.0, 0.0), 1.2, g.IRON_LIGHT, 8)
	var weight_center := heel + Vector3(0.0, 0.0, -10.0)
	for x in [-3.0, 3.0]:
		g.beam(heel + Vector3(x, 0.0, 0.0), weight_center + Vector3(x, 0.0, 3.0), 1.0, g.IRON)
	g.box(weight_center + Vector3(-6.0, -4.3, -4.0), weight_center + Vector3(6.0, 4.3, 3.2), Color("8e8b79"))
	g.box(weight_center + Vector3(-6.5, -4.6, -4.2), weight_center + Vector3(6.5, 4.6, -2.8), g.WOOD_DARK)
	g.box(weight_center + Vector3(-6.5, -4.6, 2.5), weight_center + Vector3(6.5, 4.6, 3.7), g.WOOD)
	for x in [-4.5, 4.5]:
		g.beam(weight_center + Vector3(x, -4.7, -4.0), weight_center + Vector3(x, -4.7, 3.5), 1.0, g.IRON)
	# Long sling trails behind the throwing tip, then opens on release.
	var release: float = clampf(motion, 0.0, 1.0)
	var sling_length := 27.3
	var sling_angle := lerpf(atan2(11.0, 25.0), atan2(-21.0, 11.0), release)
	# Swing a constant-length sling. When cocked, the pouch rests on the
	# platform without making the hanging cable shrink or pass through wood.
	if tip.z - cos(sling_angle) * sling_length < 8.0:
		sling_angle = acos(clampf((tip.z - 8.0) / sling_length, 0.0, 1.0))
	var pouch := tip + Vector3(0.0, sin(sling_angle), -cos(sling_angle)) * sling_length
	g.line(tip + Vector3(-0.7, 0.0, 0.0), pouch + Vector3(-1.7, 0.0, 0.0), g.ROPE, 1.2)
	var loose_end := pouch + Vector3(1.7 + release * 3.0, -release * 7.0, -release * 3.0)
	g.line(tip + Vector3(0.7, 0.0, 0.0), loose_end, g.ROPE, 1.2)
	g.beam(pouch + Vector3(-2.2, 0.0, -0.8), pouch + Vector3(2.2, 0.0, -0.8), 2.7, g.WOOD_DARK)
	if _loaded(state):
		_stone(g, pouch + Vector3(0.0, 0.0, 1.2), 2.6)
	# Rear winding drum, crank, tension rope and a small ownership stripe.
	g.cylinder(Vector3(-7.0, 17.0, 10.5), Vector3(7.0, 17.0, 10.5), 2.2, g.WOOD_DARK, 10)
	g.beam(Vector3(7.8, 17.0, 10.5), Vector3(7.8, 17.0, 14.4), 1.3, g.IRON)
	g.beam(Vector3(7.8, 17.0, 14.4), Vector3(11.2, 17.0, 14.4), 1.2, g.WOOD_LIGHT)
	if motion <= 0.0:
		g.line(Vector3(0.0, 17.0, 11.5), tip - direction * 4.0, g.ROPE, 1.0)
	g.box(Vector3(-6.0, 19.5, 7.0), Vector3(6.0, 21.2, 8.8), g.team_color)

static func _mangonel(g, state) -> void:
	_cart(g, 12.5, 16.0, 5.0)
	# The low, wide torsion cart is deliberately unlike the tall A-frame.
	for x in [-9.0, 9.0]:
		g.box(Vector3(x - 2.0, -10.0, 7.0), Vector3(x + 2.0, -5.0, 18.0), g.WOOD)
		g.beam(Vector3(x, -7.0, 17.0), Vector3(x, 12.0, 7.7), 2.7, g.WOOD_DARK)
		g.box(Vector3(x - 2.5, -10.5, 16.0), Vector3(x + 2.5, -4.5, 18.5), g.IRON)
	g.beam(Vector3(-10.5, -8.0, 18.0), Vector3(10.5, -8.0, 18.0), 3.1, g.WOOD_LIGHT)
	g.cylinder(Vector3(-11.0, -4.0, 12.0), Vector3(11.0, -4.0, 12.0), 3.0, g.ROPE, 12)
	for x in [-10.0, -7.5, -5.0, 5.0, 7.5, 10.0]:
		g.cylinder(Vector3(x - 0.45, -4.0, 12.0), Vector3(x + 0.45, -4.0, 12.0), 3.2, g.WOOD_DARK, 10)
	var motion := _throw_motion(g, state)
	var angle := deg_to_rad(27.0 + motion * 88.0)
	var pivot := Vector3(0.0, -4.0, 12.0)
	var along := Vector3(0.0, cos(angle), sin(angle))
	var normal := Vector3(0.0, -sin(angle), cos(angle))
	var cup := pivot + along * 16.0
	g.beam(pivot - along * 2.0, cup, 3.2, g.WOOD_LIGHT)
	g.beam(pivot - along * 1.0, pivot + along * 3.0, 4.1, g.WOOD_DARK)
	# A shallow wooden spoon rotates around the same fixed torsion axle.
	g.beam(cup - along * 2.0, cup + along * 2.0, 6.5, g.WOOD_DARK)
	for x in [-3.5, 3.5]:
		g.beam(cup + Vector3(x, 0.0, 0.0) - along * 2.8, cup + Vector3(x, 0.0, 0.0) + along * 2.8 + normal, 1.5, g.WOOD_LIGHT)
	g.beam(cup + along * 2.5 + normal, cup + along * 2.5 + normal + Vector3(3.5, 0.0, 0.0), 1.5, g.WOOD_LIGHT)
	g.beam(cup + along * 2.5 + normal, cup + along * 2.5 + normal + Vector3(-3.5, 0.0, 0.0), 1.5, g.WOOD_LIGHT)
	if _loaded(state):
		_stone(g, cup + normal * 2.4, 2.6)
	# Rear winch pulls the arm down; its line goes slack after release.
	g.cylinder(Vector3(-7.0, 13.0, 10.3), Vector3(7.0, 13.0, 10.3), 1.8, g.WOOD_DARK, 10)
	g.beam(Vector3(7.3, 13.0, 10.3), Vector3(7.3, 15.5, 12.0), 1.2, g.IRON)
	if motion <= 0.0:
		g.line(Vector3(0.0, 13.0, 11.0), cup - along * 3.0, g.ROPE, 1.0)
	g.box(Vector3(-8.0, -16.2, 7.5), Vector3(8.0, -14.7, 9.2), g.team_color)

static func _springald(g, state) -> void:
	_cart(g, 11.0, 20.0, 4.3)
	# A low box of heavy rails houses two vertical torsion bundles.
	for x in [-9.0, 9.0]:
		g.box(Vector3(x - 1.5, -13.0, 11.5), Vector3(x + 1.5, 16.0, 14.5), g.WOOD)
		for y in [-12.0, 13.0]:
			g.box(Vector3(x - 1.7, y - 1.7, 7.5), Vector3(x + 1.7, y + 1.7, 19.5), g.WOOD_DARK)
		g.beam(Vector3(x, -12.0, 19.5), Vector3(x, 13.0, 19.5), 2.0, g.WOOD_LIGHT)
		g.beam(Vector3(x, -11.0, 8.0), Vector3(x, 12.0, 18.5), 1.5, g.WOOD_DARK)
	for y in [-12.0, 13.0]:
		g.beam(Vector3(-10.0, y, 19.5), Vector3(10.0, y, 19.5), 2.2, g.WOOD_LIGHT)
		g.box(Vector3(-10.7, y - 1.5, 11.5), Vector3(10.7, y + 1.5, 14.2), g.WOOD)
	for x in [-7.0, 7.0]:
		g.cylinder(Vector3(x, -6.0, 12.5), Vector3(x, -6.0, 20.3), 2.2, g.ROPE, 10)
		for z in [13.0, 15.0, 17.0, 19.0]:
			g.cylinder(Vector3(x, -6.0, z), Vector3(x, -6.0, z + 0.5), 2.4, g.WOOD_DARK, 10)
		g.box(Vector3(x - 2.7, -8.7, 19.5), Vector3(x + 2.7, -3.3, 21.0), g.IRON)
	# The central guide is a long open trough rather than a giant hand-held bow.
	for x in [-2.1, 2.1]:
		g.beam(Vector3(x, -24.0, 15.4), Vector3(x, 15.0, 15.4), 1.5, g.WOOD_LIGHT)
	g.beam(Vector3(0.0, -24.0, 14.5), Vector3(0.0, 15.0, 14.5), 2.1, g.WOOD_DARK)
	var motion: float = g.attack_motion(state)
	var release: float = clampf(motion, 0.0, 1.0)
	var draw_back: float = maxf(-motion, 0.0) * 4.0
	var nock := Vector3(0.0, lerpf(10.0 + draw_back, -8.0, release), 16.2)
	for side in [-1.0, 1.0]:
		var root := Vector3(side * 7.0, -6.0, 16.0)
		var elbow := Vector3(side * 12.5, -2.8 - release * 3.0, 16.2)
		var tip := Vector3(side * 18.0, 3.0 + draw_back * 0.35 - release * 7.0, 16.2)
		g.beam(root, elbow, 3.0, g.WOOD)
		g.beam(elbow, tip, 2.2, g.WOOD_LIGHT)
		g.beam(tip - Vector3(0.0, 0.5, 0.0), tip + Vector3(0.0, 0.5, 0.0), 2.6, g.IRON)
		g.line(tip, nock, g.ROPE, 1.25)
	if _loaded(state):
		var head := Vector3(0.0, -22.5 + draw_back, 16.6)
		g.beam(Vector3(0.0, nock.y + 0.5, 16.6), head, 1.15, g.WOOD_LIGHT)
		g.beam(head, head + Vector3(0.0, -3.0, 0.0), 2.6, g.IRON_LIGHT)
		for x in [-1.4, 1.4]:
			g.line(Vector3(x, nock.y + 0.5, 16.6), Vector3(0.0, nock.y - 3.0, 16.6), Color("ccc5a8"), 1.0)
	g.cylinder(Vector3(-7.5, 16.0, 15.0), Vector3(7.5, 16.0, 15.0), 1.8, g.IRON, 10)
	g.beam(Vector3(8.0, 16.0, 15.0), Vector3(8.0, 18.5, 18.0), 1.2, g.IRON_LIGHT)
	g.beam(Vector3(8.0, 18.5, 18.0), Vector3(11.0, 18.5, 18.0), 1.3, g.WOOD)
	if motion <= 0.0:
		g.line(Vector3(0.0, 16.0, 15.5), nock, g.ROPE, 1.0)
	g.box(Vector3(-5.5, 13.8, 12.8), Vector3(5.5, 15.2, 14.4), g.team_color)

static func _stone(g, center: Vector3, radius: float) -> void:
	g.box(center + Vector3(-radius, -radius * 0.8, -radius * 0.65), center + Vector3(radius, radius * 0.8, radius * 0.65), Color("777a72"))
	g.box(center + Vector3(-radius * 0.7, -radius * 0.55, radius * 0.4), center + Vector3(radius * 0.55, radius * 0.5, radius * 0.9), Color("a2a499"))

static func _loaded(state) -> bool:
	# The payload leaves the machine on the real release event, not a bob timer.
	return not state.action_released or state.release_elapsed < 0.0

static func _throw_motion(g, state) -> float:
	if state.visual_action != "attack": return 0.0
	if not state.action_released: return g.attack_motion(state)
	# Unlike a cannon's instantaneous recoil, the throwing arm must sweep
	# around its axle before returning. Payload visibility still follows the
	# combat release event exactly, independently of this short follow-through.
	var elapsed: float = maxf(0.0, state.release_elapsed)
	if elapsed < 0.07:
		return lerpf(-0.22, 1.0, smoothstep(0.0, 0.07, elapsed))
	return 1.0 - smoothstep(0.07, 0.18, elapsed)

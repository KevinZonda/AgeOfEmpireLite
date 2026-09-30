extends RefCounted

const Pose = preload("res://scripts/entities/visuals/humanoid_pose.gd")
const Fill = preload("res://scripts/entities/visuals/filled_polygon.gd")
const EDGE := Color("24302d")
const SKIN := Color("dfbd91")
const LEATHER := Color("6b503b")
const WOOD := Color("ac8050")
const STEEL := Color("c7d3cf")
const ROUND_POINTS := [Vector2(-0.7071, -0.7071), Vector2(0, -1), Vector2(0.7071, -0.7071), Vector2(1, 0), Vector2(0.7071, 0.7071), Vector2(0, 1), Vector2(-0.7071, 0.7071), Vector2(-1, 0)]

static func handles(kind: String) -> bool:
	return kind in ["villager", "spearman", "archer", "longbow"]

static func draw(canvas: CanvasItem, state, pose: Pose) -> void:
	pose.update(state)
	var active: bool = state.visual_action != "" and not state.visual_moving
	var progress: float = state.action_progress
	var attack: bool = active and state.visual_action in ["attack", "hunt"]
	var bow: bool = state.kind in ["archer", "longbow"] or state.hunting
	var tool_tip := Vector2.ZERO
	var spear_tip := Vector2.ZERO
	var pull := 0.0
	var recoil := 0.0
	if bow:
		if attack:
			pull = state.hunt_draw if state.hunting else clampf(progress / 0.47, 0.0, 1.0)
			if state.action_released:
				pull = 0.0
				recoil = pow(1.0 - progress, 2.0) * 2.0
			pose.near_hand = pose.chest + Vector2(pose.aim.x * (12.0 - recoil), pose.aim.y * 5.0 + 2.0)
			pose.far_hand = pose.chest - pose.aim * (pull * 8.0 + 1.0) + Vector2(0, 3.0)
		else:
			pose.near_hand = pose.near_shoulder + Vector2(0, 10.0)
	elif state.kind == "spearman":
		var ready := clampf(progress / 0.47, 0.0, 1.0) if attack else 0.0
		var thrust := (1.0 - smoothstep(0.15, 1.0, progress)) if attack and state.action_released else 0.0
		if state.braced: ready = 1.0
		if state.action_released and attack: ready = 1.0
		pose.near_hand = pose.chest + Vector2(pose.across.x * 0.8, 8) + pose.aim * (thrust * 10.0 - ready * 3.0)
		var rest_angle := Vector2(pose.across.x * 0.08, -1.0).angle()
		var shaft_direction := Vector2.RIGHT.rotated(lerp_angle(rest_angle, pose.aim.angle(), ready))
		spear_tip = pose.near_hand + shaft_direction * 34.0
		if ready > 0.0:
			pose.far_hand = pose.near_hand - shaft_direction * 8.0
			pose.chest += pose.aim * thrust * 1.8
			pose.head += pose.aim * thrust * 1.8
	elif state.kind == "villager":
		pose.near_hand = pose.near_shoulder + Vector2(1.0, 10.0)
		tool_tip = pose.near_hand + Vector2(pose.across.x * 0.3, -21)
		if active:
			# Lift, strike quickly, then recover. Feet stay planted during work.
			var stroke := smoothstep(0.26, 0.52, progress)
			var recovery := smoothstep(0.6, 1.0, progress)
			var raised := pose.chest + Vector2(-pose.aim.x * 9.0, -21)
			var impact := pose.chest + Vector2(pose.aim.x * 28.0, 19.0 + pose.aim.y * 5.0)
			tool_tip = raised.lerp(impact, stroke).lerp(tool_tip, recovery)
			pose.near_hand = pose.chest + Vector2(pose.aim.x * 6.0, lerpf(-1.0, 8.0, stroke))
			pose.far_hand = pose.near_hand - (tool_tip - pose.near_hand).normalized() * 4.0
			pose.chest += pose.aim * stroke * (1.0 - recovery) * 1.4
			pose.head += pose.aim * stroke * (1.0 - recovery) * 1.4
	if state.paling and state.kind == "longbow": _stakes(canvas)
	_leg(canvas, pose.far_hip, pose.far_knee, pose.far_foot, true, pose.direction)
	_arm(canvas, pose.far_shoulder, pose.far_hand, state.player_color.darkened(0.27), -1.0)
	if pose.back:
		_equipment(canvas, state, pose, bow, attack, pull, tool_tip, spear_tip)
	_body(canvas, state, pose)
	_leg(canvas, pose.near_hip, pose.near_knee, pose.near_foot, false, pose.direction)
	_arm(canvas, pose.near_shoulder, pose.near_hand, state.player_color.darkened(0.08), 1.0)
	if not pose.back:
		_equipment(canvas, state, pose, bow, attack, pull, tool_tip, spear_tip)

static func _poly(canvas: CanvasItem, points: Array, color: Color, width := 1.2) -> void:
	var shape := PackedVector2Array(points)
	if shape.size() <= 4:
		Fill.draw(canvas, shape, color)
	else:
		# These larger shapes are convex. Quad fans keep them batched.
		var colors := PackedColorArray([color])
		var index := 1
		while index < shape.size() - 1:
			var part := PackedVector2Array([shape[0], shape[index], shape[index + 1]])
			if index + 2 < shape.size(): part.append(shape[index + 2])
			canvas.draw_primitive(part, colors, PackedVector2Array())
			index += 2
	if width > 0.0: _stroke(canvas, shape + PackedVector2Array([shape[0]]), EDGE, width)

static func _stroke(canvas: CanvasItem, points: PackedVector2Array, color: Color, width: float) -> void:
	# Joined polylines allocate a dedicated polygon per limb in GLES3.
	for index in points.size() - 1: canvas.draw_line(points[index], points[index + 1], color, width)

static func _dot(canvas: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	# Small round details share the primitive batch instead of separate circle buffers.
	var points: Array = []
	for point in ROUND_POINTS: points.append(center + point * radius)
	_poly(canvas, points, color, 0.0)

static func draw_shadow(canvas: CanvasItem) -> void:
	_dot(canvas, Vector2.ZERO, 8.0, Color("172322", 0.33))

static func _leg(canvas: CanvasItem, hip: Vector2, knee: Vector2, foot: Vector2, far_side: bool, direction: Vector2) -> void:
	var joints := PackedVector2Array([hip, knee, foot])
	_stroke(canvas, joints, EDGE, 4.5)
	_stroke(canvas, joints, LEATHER.darkened(0.2) if far_side else LEATHER, 2.6)
	var toe := foot + Vector2(direction.x * 2.5, maxf(0.0, direction.y) * 0.6)
	canvas.draw_line(foot - Vector2(1, 0), toe + Vector2(1, 0), EDGE, 3.0)

static func _arm(canvas: CanvasItem, shoulder: Vector2, hand: Vector2, cloth: Color, bend: float) -> void:
	var delta := hand - shoulder
	var elbow := shoulder.lerp(hand, 0.5) + delta.normalized().orthogonal() * minf(3.5, sqrt(maxf(0.0, 64.0 - delta.length_squared() * 0.25))) * bend
	_stroke(canvas, PackedVector2Array([shoulder, elbow, hand]), EDGE, 4.2)
	canvas.draw_line(shoulder, elbow, cloth, 2.6)
	canvas.draw_line(elbow, hand, cloth.lightened(0.12), 2.3)
	_dot(canvas, hand, 1.8, SKIN)

static func _body(canvas: CanvasItem, state, pose: Pose) -> void:
	var width: float = pose.width
	var top: Vector2 = pose.chest - Vector2(0, 2)
	var waist: Vector2 = pose.pelvis - Vector2(0, 2)
	var cloth: Color = state.player_color.darkened(0.16 if pose.back else 0.05)
	_poly(canvas, [top + Vector2(-width, 0), top + Vector2(width, 0), waist + Vector2(width * 0.72, 0), waist + Vector2(-width * 0.72, 0)], cloth, 0.0)
	_poly(canvas, [waist + Vector2(-width * 0.72, 0), waist + Vector2(width * 0.72, 0), waist + Vector2(width * 0.8, 5), waist + Vector2(-width * 0.8, 5)], cloth, 0.0)
	_stroke(canvas, PackedVector2Array([top + Vector2(-width, 0), top + Vector2(width, 0), waist + Vector2(width * 0.72, 0), waist + Vector2(width * 0.8, 5), waist + Vector2(-width * 0.8, 5), waist + Vector2(-width * 0.72, 0), top + Vector2(-width, 0)]), EDGE, 1.2)
	canvas.draw_line(waist + Vector2(-width * 0.8, 1), waist + Vector2(width * 0.8, 1), LEATHER, 2.0)
	if pose.back:
		canvas.draw_line(top + Vector2(0, 1), waist, cloth.darkened(0.18), 1.0)
	else:
		canvas.draw_line(top + Vector2(-width * 0.45, 2), waist + Vector2(-width * 0.3, -2), cloth.lightened(0.18), 1.3)
	if state.kind in ["archer", "longbow"]:
		_quiver(canvas, pose.chest + Vector2(-pose.across.x * 0.85, 3), pose.back)
	elif state.kind == "spearman":
		_poly(canvas, [top + Vector2(-width, 1), top + Vector2(width, 1), top + Vector2(width * 0.8, 6), top + Vector2(-width * 0.8, 6)], STEEL.darkened(0.22))
	var head: Vector2 = pose.head
	var head_width := lerpf(4.8, 3.7, pose.profile)
	var head_points: Array = []
	for index in 10:
		var angle := TAU * index / 10.0
		head_points.append(head + Vector2(cos(angle) * head_width, sin(angle) * 5.0))
	_poly(canvas, head_points, LEATHER.darkened(0.18) if pose.back else SKIN, 1.1)
	if not pose.back:
		if pose.profile > 0.4:
			var side := signf(pose.direction.x)
			_poly(canvas, [head + Vector2(side * 3, -1), head + Vector2(side * 6, 1), head + Vector2(side * 3, 2)], SKIN, 0.7)
			_dot(canvas, head + Vector2(side * 2.6, -1.1), 0.8, EDGE)
		else:
			for side in [-1.0, 1.0]: _dot(canvas, head + Vector2(side * 1.7, -0.5), 0.65, EDGE)
	var hat_width := head_width + (3.0 if state.kind == "villager" else 1.3)
	var hat: Color = Color("b59861") if state.kind == "villager" else STEEL if state.kind == "spearman" else Color("626848")
	_poly(canvas, [head + Vector2(-hat_width, -3), head + Vector2(hat_width, -3), head + Vector2(hat_width * 0.6, -7), head + Vector2(-hat_width * 0.6, -7)], hat)
	if pose.back: canvas.draw_line(head + Vector2(-head_width, 2), head + Vector2(head_width, 2), LEATHER, 1.8)

static func _equipment(canvas: CanvasItem, state, pose: Pose, bow: bool, attack: bool, pull: float, tool_tip: Vector2, spear_tip: Vector2) -> void:
	if bow:
		var bow_aim := pose.aim if attack else Vector2(-1.0 if pose.direction.x < -0.1 else 1.0, 0)
		_bow(canvas, pose.near_hand, pose.far_hand, bow_aim, 16.0 if state.kind == "longbow" else 11.5, pull, attack and not state.action_released)
	elif state.kind == "spearman":
		var shaft := (spear_tip - pose.near_hand).normalized()
		var heel: Vector2 = pose.near_hand - shaft * 14.0
		canvas.draw_line(heel, spear_tip, EDGE, 3.8)
		canvas.draw_line(heel, spear_tip, WOOD, 2.0)
		var normal := shaft.orthogonal() * 2.8
		_poly(canvas, [spear_tip + shaft * 7.0, spear_tip - shaft * 2.0 + normal, spear_tip - shaft * 2.0 - normal], STEEL)
		if not attack and not state.braced:
			var hand: Vector2 = pose.far_hand
			_poly(canvas, [hand + Vector2(-4, -6), hand + Vector2(4, -6), hand + Vector2(3, 3), hand + Vector2(0, 6), hand + Vector2(-3, 3)], state.player_color.darkened(0.18))
	else:
		_tool(canvas, pose.near_hand, tool_tip, "build" if state.visual_action in ["build", "repair"] else state.gather_kind)
	# Hands rest on their equipment, rather than vanishing underneath it.
	_dot(canvas, pose.near_hand, 1.8, SKIN)
	if attack or state.visual_action in ["gather", "build", "repair"]: _dot(canvas, pose.far_hand, 1.8, SKIN)

static func _tool(canvas: CanvasItem, grip: Vector2, tip: Vector2, kind: String) -> void:
	var shaft := (tip - grip).normalized()
	var normal := shaft.orthogonal()
	canvas.draw_line(grip - shaft * 5.0, tip, EDGE, 3.6)
	canvas.draw_line(grip - shaft * 5.0, tip, WOOD, 2.0)
	if kind in ["gold", "stone"]:
		canvas.draw_line(tip - normal * 7, tip + normal * 7, EDGE, 3.8)
		canvas.draw_line(tip - normal * 7, tip + normal * 7, STEEL, 2.1)
	elif kind in ["food", "berry", "fish"]:
		_poly(canvas, [tip - normal * 2, tip + normal * 6, tip + normal * 7 + shaft * 4, tip - normal * 2 + shaft * 3], STEEL)
	elif kind == "build":
		_poly(canvas, [tip - normal * 5 - shaft * 2, tip + normal * 5 - shaft * 2, tip + normal * 5 + shaft * 3, tip - normal * 5 + shaft * 3], STEEL.darkened(0.12))
	else:
		_poly(canvas, [tip, tip + normal * 7 - shaft * 3, tip + normal * 8 + shaft * 3, tip + shaft * 4], STEEL)

static func _bow(canvas: CanvasItem, grip: Vector2, string_hand: Vector2, aim: Vector2, radius: float, pull: float, nocked: bool) -> void:
	var bow_axis := aim.orthogonal()
	var rest := grip - aim * radius * 0.4
	var top := rest - bow_axis * radius
	var bottom := rest + bow_axis * radius
	var curve := PackedVector2Array()
	for index in 13:
		var t := float(index) / 12.0
		curve.append(top.lerp(bottom, t) + aim * sin(t * PI) * radius * 0.4)
	_stroke(canvas, curve, EDGE, 3.8)
	_stroke(canvas, curve, WOOD, 2.1)
	var string_center := rest.lerp(string_hand, pull)
	_stroke(canvas, PackedVector2Array([top, string_center, bottom]), Color("ecddbb"), 1.0)
	if nocked:
		var tip := string_center + aim * 23.0
		canvas.draw_line(string_center, tip, Color("d8bf8b"), 1.4)
		var normal := aim.orthogonal() * 2.0
		_poly(canvas, [tip + aim * 4, tip - aim + normal, tip - aim - normal], STEEL, 0.8)

static func _quiver(canvas: CanvasItem, center: Vector2, back: bool) -> void:
	var lean := 3.0 if back else -3.0
	_poly(canvas, [center + Vector2(-3, -7), center + Vector2(3, -7), center + Vector2(3 + lean, 7), center + Vector2(-3 + lean, 7)], LEATHER)
	for offset in [-1.5, 1.5]:
		canvas.draw_line(center + Vector2(offset, -7), center + Vector2(offset - 1, -14), WOOD.lightened(0.2), 1.1)

static func _stakes(canvas: CanvasItem) -> void:
	for x in [-16.0, -10.0]:
		canvas.draw_line(Vector2(x, 3), Vector2(x + 6, -8), EDGE, 3.5)
		canvas.draw_line(Vector2(x, 3), Vector2(x + 6, -8), WOOD, 2.1)

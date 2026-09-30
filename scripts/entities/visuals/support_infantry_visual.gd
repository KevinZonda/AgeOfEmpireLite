extends RefCounted

# Common walking skeleton, distinct armor, melee weapons and working hands.
const H = preload("res://scripts/entities/visuals/humanoid_visual.gd")
const Pose = preload("res://scripts/entities/visuals/humanoid_pose.gd")
const GOLD := Color("dfbb68")
const PARCHMENT := Color("e6dab5")
const LACQUER := Color("8c3932")

static func handles(kind: String) -> bool:
	return kind in ["man_at_arms", "palace_guard", "monk", "trader", "imperial_official"]

static func health_bar_y(state) -> float:
	return -63.0 if state.kind in ["man_at_arms", "palace_guard"] else -57.0 if state.kind == "monk" else -47.0

static func draw(canvas: CanvasItem, state, pose: Pose) -> void:
	pose.update(state)
	var attacking: bool = state.visual_action == "attack" and not state.visual_moving
	var melee: bool = state.kind in ["man_at_arms", "palace_guard"]
	var blade_direction := Vector2(pose.across.x * 0.15, -1).normalized()
	var cloth: Color = state.player_color.darkened(0.13)
	if melee:
		blade_direction = _melee_pose(state, pose, attacking)
		cloth = H.STEEL.darkened(0.22) if state.kind == "man_at_arms" else cloth
	elif state.kind == "monk":
		var prayer: bool = state.converting or state.healing
		var lift: float = (0.65 + sin(state.visual_phase * 1.5) * 0.15) if state.converting else sin(state.action_progress * PI) if state.healing else 0.0
		pose.near_hand = pose.near_shoulder + Vector2(pose.aim.x * lift * 6, 9 - lift * 8)
		if prayer: pose.far_hand = pose.chest + pose.aim * 9 + Vector2(0, 3 - lift * 4)
		if state.carries_relic: pose.far_hand = pose.chest + Vector2(-pose.across.x * 0.4, 8)
	elif state.kind == "trader":
		# A weighted pack changes the carriage, not the shared foot rhythm.
		pose.near_hand = pose.near_shoulder + Vector2(pose.across.x * 0.15, 8)
	elif state.kind == "imperial_official":
		var writing: float = sin(state.visual_phase * 2.0) if state.tax_active and not state.visual_moving else 0.0
		pose.far_hand = pose.chest + Vector2(-pose.across.x * 0.45, 10)
		pose.near_hand = pose.chest + Vector2(pose.across.x * 0.25 + writing * 1.7, 6)
	var robed: bool = state.kind in ["monk", "imperial_official"]
	H._leg(canvas, pose.far_hip, pose.far_knee, pose.far_foot, true, pose.direction)
	if state.kind == "man_at_arms": canvas.draw_line(pose.far_knee, pose.far_knee.lerp(pose.far_foot, 0.8), H.STEEL.darkened(0.3), 2.8)
	if robed: H._leg(canvas, pose.near_hip, pose.near_knee, pose.near_foot, false, pose.direction)
	H._arm(canvas, pose.far_shoulder, pose.far_hand, cloth.darkened(0.2), -1.0)
	if state.kind == "trader" and not pose.back: _pack(canvas, pose, state.player_color)
	if melee: _shield(canvas, state, pose)
	if pose.back: _equipment(canvas, state, pose, blade_direction)
	H._body(canvas, state, pose)
	if not robed: H._leg(canvas, pose.near_hip, pose.near_knee, pose.near_foot, false, pose.direction)
	if state.kind == "man_at_arms": canvas.draw_line(pose.near_knee, pose.near_knee.lerp(pose.near_foot, 0.8), H.STEEL, 2.8)
	if state.kind == "trader" and pose.back: _pack(canvas, pose, state.player_color)
	H._arm(canvas, pose.near_shoulder, pose.near_hand, cloth, 1.0)
	if not pose.back: _equipment(canvas, state, pose, blade_direction)
	if state.kind == "monk" and (state.converting or state.healing): _prayer(canvas, state, pose)

static func _melee_pose(state, pose: Pose, attacking: bool) -> Vector2:
	var rest: Vector2 = pose.near_shoulder + Vector2(0, 10)
	var raised: Vector2 = pose.chest - pose.aim * 5.0 + Vector2(0, -7)
	var extended: Vector2 = pose.chest + pose.aim * 16.0 + Vector2(0, 5)
	var rest_angle := Vector2(pose.across.x * 0.15, -1).angle()
	var ready_angle := Vector2(-pose.aim.x * 0.4, -1).angle()
	var hit_angle := Vector2(pose.aim.x, 0.4 + pose.aim.y).angle()
	var preparation: float = clampf(state.action_progress / 0.47, 0.0, 1.0) if attacking else 0.0
	pose.near_hand = rest.lerp(raised, preparation)
	var blade_direction := Vector2.RIGHT.rotated(lerp_angle(rest_angle, ready_angle, preparation))
	if state.action_released and attacking:
		# Damage has already happened: show the end of the stroke immediately,
		# including the first attack where the preparation progress is still zero.
		# A short contact hold then recovers on real time since this exact hit.
		var recover := smoothstep(0.035, 0.17, maxf(0.0, state.release_elapsed))
		pose.near_hand = extended.lerp(rest, recover)
		blade_direction = Vector2.RIGHT.rotated(lerp_angle(hit_angle, rest_angle, recover))
	pose.far_hand = pose.far_shoulder + Vector2(pose.aim.x * (5.0 if state.shield_active else 1.0), 6 if state.shield_active else 10)
	return blade_direction

static func _equipment(canvas: CanvasItem, state, pose: Pose, direction: Vector2) -> void:
	match state.kind:
		"man_at_arms", "palace_guard": _blade(canvas, pose.near_hand, direction, state.kind == "palace_guard")
		"monk":
			_staff(canvas, pose.near_hand, state.converting or state.healing, pose.aim)
			if state.carries_relic: _relic(canvas, pose.far_hand + Vector2(0, -3))
		"trader":
			var pouch: Vector2 = pose.near_hand + Vector2(0, 4)
			H._poly(canvas, [pouch + Vector2(-3, -3), pouch + Vector2(3, -3), pouch + Vector2(4, 3), pouch + Vector2(-4, 3)], H.LEATHER)
			canvas.draw_line(pouch + Vector2(-2, -3), pouch + Vector2(2, -3), GOLD, 1.5)
		"imperial_official": _scroll(canvas, pose.far_hand, pose.near_hand, pose.back)
	H._dot(canvas, pose.near_hand, 1.8, H.SKIN)
	if state.kind in ["monk", "imperial_official"]: H._dot(canvas, pose.far_hand, 1.8, H.SKIN)

static func _blade(canvas: CanvasItem, hand: Vector2, direction: Vector2, dao: bool) -> void:
	var normal := direction.orthogonal()
	var heel := hand + direction * 4
	var tip := hand + direction * (24 if dao else 26)
	canvas.draw_line(hand - direction * 3, heel, H.EDGE, 3.8)
	canvas.draw_line(hand - direction * 2, heel, H.LEATHER, 2.0)
	if dao:
		H._poly(canvas, [heel - normal * 1.4, heel + normal * 2, tip + normal * 3.6 - direction * 3, tip - normal], H.STEEL.lightened(0.1))
		canvas.draw_line(hand - direction * 2, hand - direction * 5 + normal * 4, LACQUER, 1.5)
	else:
		H._poly(canvas, [heel - normal * 1.7, heel + normal * 1.7, tip + normal * 1.2 - direction * 3, tip - normal * 1.2 - direction * 3], H.STEEL)
		H._poly(canvas, [tip - normal * 1.2 - direction * 3, tip + normal * 1.2 - direction * 3, tip + direction], H.STEEL.lightened(0.1))
		canvas.draw_line(heel, tip, H.STEEL.lightened(0.2), 1.0)
	canvas.draw_line(heel - normal * 4, heel + normal * 4, H.EDGE, 3.0)
	canvas.draw_line(heel - normal * 4, heel + normal * 4, GOLD, 1.6)

static func _shield(canvas: CanvasItem, state, pose: Pose) -> void:
	var center: Vector2 = pose.far_hand + Vector2(0, -1)
	var shield_width := lerpf(5.9, 3.6, pose.profile)
	var height := 10.0 if state.kind == "man_at_arms" else 7.0
	var outer: Color = H.STEEL if state.kind == "man_at_arms" else LACQUER
	if pose.back: outer = H.LEATHER.darkened(0.2)
	H._poly(canvas, [center + Vector2(-shield_width, -height), center + Vector2(shield_width, -height), center + Vector2(shield_width, height * 0.25), center + Vector2(0, height), center + Vector2(-shield_width, height * 0.25)], outer)
	if not pose.back:
		H._poly(canvas, [center + Vector2(-shield_width * 0.68, -height * 0.73), center + Vector2(shield_width * 0.68, -height * 0.73), center + Vector2(shield_width * 0.68, height * 0.1), center + Vector2(0, height * 0.65), center + Vector2(-shield_width * 0.68, height * 0.1)], state.player_color.darkened(0.14), 0.0)
		canvas.draw_line(center + Vector2(0, -height * 0.5), center + Vector2(0, height * 0.45), GOLD, 1.3)
		H._dot(canvas, center, 1.6, GOLD)
	if state.shield_active:
		canvas.draw_line(center + Vector2(-shield_width, -height - 2), center + Vector2(shield_width, -height - 2), Color("e9daa6"), 1.4)

static func _staff(canvas: CanvasItem, hand: Vector2, active: bool, aim: Vector2) -> void:
	var direction := Vector2(aim.x * (0.22 if active else 0.08), -1).normalized()
	var top := hand + direction * 29
	canvas.draw_line(hand - direction * 14, top, H.EDGE, 3.8)
	canvas.draw_line(hand - direction * 14, top, H.WOOD, 2.0)
	canvas.draw_line(top + Vector2(-4, 3), top + Vector2(4, 3), GOLD, 2.0)
	H._dot(canvas, top, 2.0, GOLD)

static func _relic(canvas: CanvasItem, center: Vector2) -> void:
	H._poly(canvas, [center + Vector2(-5, -2), center + Vector2(0, -7), center + Vector2(5, -2), center + Vector2(5, 4), center + Vector2(-5, 4)], GOLD)
	H._poly(canvas, [center + Vector2(-3, -1), center + Vector2(3, -1), center + Vector2(3, 2), center + Vector2(-3, 2)], PARCHMENT, 0.0)
	H._dot(canvas, center, 1.4, Color("4f9691"))

static func _prayer(canvas: CanvasItem, state, pose: Pose) -> void:
	var center: Vector2 = pose.near_hand + Vector2(0, -28)
	var color := Color("e7c76e", 0.85) if state.converting else Color("a9dbc3", 0.85)
	for index in 3:
		var phase: float = state.visual_phase * 1.2 + index * TAU / 3.0
		var spark := center + Vector2(cos(phase) * 6, sin(phase) * 3)
		canvas.draw_line(spark - Vector2(0, 2), spark + Vector2(0, 2), color, 1.2)
		canvas.draw_line(spark - Vector2(1.6, 0), spark + Vector2(1.6, 0), color, 1.2)

static func _pack(canvas: CanvasItem, pose: Pose, team: Color) -> void:
	var center: Vector2 = pose.chest + Vector2(-pose.aim.x * 4.5, 5)
	H._poly(canvas, [center + Vector2(-5, -8), center + Vector2(5, -8), center + Vector2(6, 7), center + Vector2(-6, 7)], H.LEATHER)
	H._poly(canvas, [center + Vector2(-4, -7), center + Vector2(4, -7), center + Vector2(4, -1), center + Vector2(-4, -1)], Color("b5a377"))
	canvas.draw_line(center + Vector2(-2, -8), center + Vector2(-2, 7), team.darkened(0.15), 1.6)
	canvas.draw_line(center + Vector2(2, -8), center + Vector2(2, 7), team.darkened(0.15), 1.6)
	canvas.draw_line(center + Vector2(-5, 1), center + Vector2(5, 1), GOLD.darkened(0.15), 1.2)

static func _scroll(canvas: CanvasItem, hand: Vector2, pen_hand: Vector2, back: bool) -> void:
	var center := hand + Vector2(0, -2)
	H._poly(canvas, [center + Vector2(-6, -5), center + Vector2(5, -5), center + Vector2(6, 3), center + Vector2(-5, 3)], PARCHMENT)
	for side in [-1.0, 1.0]:
		canvas.draw_line(center + Vector2(side * 5, -5), center + Vector2(side * 5, 4), H.WOOD, 2.3)
	if not back:
		for y in [-2.0, 0.0]: canvas.draw_line(center + Vector2(-2.5, y), center + Vector2(2.5, y), H.LEATHER, 0.7)
	canvas.draw_line(pen_hand + Vector2(0, -3), pen_hand + Vector2(-2, 3), H.EDGE, 1.1)

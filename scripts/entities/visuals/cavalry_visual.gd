extends RefCounted

const Pose = preload("res://scripts/entities/visuals/cavalry_pose.gd")
const Art = preload("res://scripts/entities/visuals/humanoid_visual.gd")
const EDGE := Color("24302d")
const SKIN := Color("dfbd91")
const WOOD := Color("ac8050")
const STEEL := Color("c7d3cf")
const GOLD := Color("d8ae56")
const LEATHER := Color("654835")

static func handles(kind: String) -> bool:
	return kind in ["scout", "horseman", "knight", "royal_knight", "fire_lancer"]

static func health_bar_y(state) -> float:
	if state.kind == "fire_lancer": return -78.0
	return -72.0 if state.kind == "royal_knight" else -68.0

static func draw_shadow(canvas: CanvasItem) -> void:
	Art._poly(canvas, [Vector2(-22, 0), Vector2(-15, -7), Vector2(14, -7), Vector2(22, 0), Vector2(14, 7), Vector2(-15, 7)], Color("172322", 0.33), 0)

static func draw(canvas: CanvasItem, state, pose: Pose) -> void:
	pose.update(state)
	var heavy: bool = state.kind in ["knight", "royal_knight"]
	var attack: bool = state.visual_action == "attack"
	var lowered: bool = state.charging or (attack and state.charge_impact) or (state.kind == "fire_lancer" and attack)
	var progress: float = state.action_progress
	var hit := 1.0 - smoothstep(0.15, 1.0, progress) if attack and state.action_released else 0.0
	if lowered:
		pose.near_hand = pose.chest + Vector2(0, 7) + pose.aim * (8 + hit * 7)
	elif attack:
		var ready := clampf(progress / 0.45, 0.0, 1.0)
		pose.near_hand = pose.near_shoulder + Vector2(-pose.aim.x * ready * 3, -ready * 5)
		if state.action_released: pose.near_hand = pose.chest + pose.aim * (9 + hit * 5) + Vector2(0, 4)
	if heavy: pose.far_hand = pose.chest - pose.across * 1.15 + Vector2(-pose.aim.x * 3, 7)
	var coat := _horse_color(state.kind)
	_tail(canvas, state, pose)
	_leg(canvas, pose, 0, coat.darkened(0.25))
	_leg(canvas, pose, 2, coat.darkened(0.25))
	if pose.back: _horse_neck(canvas, pose, coat, heavy)
	_horse_body(canvas, state, pose, coat, heavy)
	_leg(canvas, pose, 1, coat)
	_leg(canvas, pose, 3, coat)
	_saddle(canvas, state, pose, heavy)
	_rider_leg(canvas, pose.saddle - pose.across * 0.7, pose.saddle - pose.across * 1.3 + Vector2(0, 12), true, heavy)
	Art._arm(canvas, pose.far_shoulder, pose.far_hand, STEEL.darkened(0.2) if heavy else state.player_color.darkened(0.28), -1)
	if pose.back: _weapon(canvas, state, pose, lowered, attack, hit)
	_rider(canvas, state, pose, heavy)
	_rider_leg(canvas, pose.saddle + pose.across * 0.7, pose.saddle + pose.across * 1.3 + Vector2(0, 12), false, heavy)
	if not pose.back: _horse_neck(canvas, pose, coat, heavy)
	# The reins visibly connect the rider's free hand to the bridle in every heading.
	var bridle: Vector2 = pose.horse_head + pose.aim * 4 + Vector2(0, 3)
	Art._stroke(canvas, PackedVector2Array([pose.far_hand, pose.far_hand.lerp(bridle, 0.55) + Vector2(0, 3), bridle]), LEATHER, 1.1)
	Art._arm(canvas, pose.near_shoulder, pose.near_hand, STEEL if heavy else state.player_color, 1)
	if not pose.back: _weapon(canvas, state, pose, lowered, attack, hit)
	if heavy: _shield(canvas, state, pose)

static func _horse_color(kind: String) -> Color:
	if kind == "royal_knight": return Color("c9bf9e")
	if kind == "knight": return Color("756451")
	if kind == "fire_lancer": return Color("96744a")
	if kind == "scout": return Color("b18c64")
	return Color("a17552")

static func _leg(canvas: CanvasItem, pose: Pose, index: int, coat: Color) -> void:
	var joints := PackedVector2Array([pose.hips[index], pose.knees[index], pose.hooves[index]])
	Art._stroke(canvas, joints, EDGE, 4.4)
	Art._stroke(canvas, joints, coat, 2.6)
	var hoof: Vector2 = pose.hooves[index]
	canvas.draw_line(hoof - Vector2(1.6, 0), hoof + Vector2(1.6, 0) + pose.aim * 1.8, EDGE, 2.7)

static func _tail(canvas: CanvasItem, state, pose: Pose) -> void:
	var start: Vector2 = pose.rear - pose.aim * 5
	var swish := sin(state.visual_phase * 0.6) * 1.8 if state.visual_moving else 0.0
	var end := start - pose.aim * 8 + Vector2(swish, 10)
	Art._stroke(canvas, PackedVector2Array([start, start.lerp(end, 0.6) - Vector2(0, 2), end]), EDGE, 4)
	Art._stroke(canvas, PackedVector2Array([start, end]), LEATHER, 2.2)

static func _horse_body(canvas: CanvasItem, state, pose: Pose, coat: Color, heavy: bool) -> void:
	var width := lerpf(8.0, 21.5, pose.profile)
	var height := lerpf(11.0, 8.0, pose.profile)
	var c: Vector2 = pose.body
	Art._poly(canvas, [c + Vector2(-width, -height * 0.2), c + Vector2(-width * 0.7, -height), c + Vector2(width * 0.65, -height), c + Vector2(width, -height * 0.2), c + Vector2(width * 0.8, height * 0.6), c + Vector2(-width * 0.7, height * 0.6)], coat)
	canvas.draw_line(c + Vector2(-width * 0.62, -height * 0.65), c + Vector2(width * 0.5, -height * 0.65), coat.lightened(0.15), 2)
	if heavy:
		var cloth: Color = state.player_color.darkened(0.23)
		Art._poly(canvas, [c + Vector2(-width * 0.78, -height * 0.7), c + Vector2(width * 0.75, -height * 0.7), c + Vector2(width * 0.75, height * 0.52), c + Vector2(-width * 0.78, height * 0.52)], cloth)
		canvas.draw_line(c + Vector2(-width * 0.73, height * 0.45), c + Vector2(width * 0.7, height * 0.45), GOLD if state.kind == "royal_knight" else STEEL.darkened(0.2), 1.5)
		if state.kind == "royal_knight":
			var emblem := c + Vector2(width * 0.3, 0)
			Art._poly(canvas, [emblem + Vector2(0, -3), emblem + Vector2(3, 0), emblem + Vector2(0, 3), emblem + Vector2(-3, 0)], GOLD, 0)

static func _horse_neck(canvas: CanvasItem, pose: Pose, coat: Color, heavy: bool) -> void:
	var base: Vector2 = pose.fore
	var head: Vector2 = pose.horse_head
	var normal := Vector2(lerpf(4.5, 3.2, pose.profile), 0)
	Art._poly(canvas, [base - normal + Vector2(0, 3), head - normal + Vector2(0, -3), head + normal + Vector2(0, 1), base + normal + Vector2(0, 4)], coat.lightened(0.05))
	var mane: Vector2 = head - pose.aim * 3.2
	canvas.draw_line(base - pose.aim * 4, mane - Vector2(0, 3), LEATHER, 3)
	var hwidth := lerpf(4.5, 5.2, pose.profile)
	var muzzle := head + pose.aim * 2.3 + Vector2(0, 0.5)
	var muzzle_width := hwidth + pose.profile * 1.4
	var muzzle_height := lerpf(6.0, 4.4, pose.profile)
	Art._poly(canvas, [muzzle + Vector2(-muzzle_width, 0), muzzle + Vector2(-muzzle_width * 0.65, -muzzle_height), muzzle + Vector2(muzzle_width * 0.6, -muzzle_height), muzzle + Vector2(muzzle_width, 0), muzzle + Vector2(muzzle_width * 0.55, muzzle_height), muzzle + Vector2(-muzzle_width * 0.55, muzzle_height)], coat.lightened(0.17))
	for side in [-1.0, 1.0]:
		if pose.profile > 0.8 and side < 0: continue
		var ear := head + Vector2(side * 3, -3)
		Art._poly(canvas, [ear + Vector2(-1.2, 0), ear + Vector2(side, -5), ear + Vector2(1.4, 0)], coat.darkened(0.18), 0.8)
	if not pose.back:
		if pose.profile > 0.4:
			Art._dot(canvas, head + Vector2(signf(pose.direction.x) * 2.3, -1), 0.85, EDGE)
		else:
			for side in [-1.0, 1.0]: Art._dot(canvas, head + Vector2(side * 2.8, 0), 0.7, EDGE)
	canvas.draw_line(head + Vector2(-hwidth * 0.6, 1), head + Vector2(hwidth * 0.7, 2), LEATHER, 1.4)
	if heavy:
		Art._poly(canvas, [head + Vector2(-3, -4), head + Vector2(3, -4), head + pose.aim * 3 + Vector2(2, 2), head + pose.aim * 3 + Vector2(-2, 2)], STEEL.darkened(0.15))

static func _saddle(canvas: CanvasItem, state, pose: Pose, heavy: bool) -> void:
	var c: Vector2 = pose.saddle
	var width := lerpf(7, 10, pose.profile)
	Art._poly(canvas, [c + Vector2(-width, -2), c + Vector2(width, -2), c + Vector2(width * 0.8, 5), c + Vector2(-width * 0.8, 5)], LEATHER)
	canvas.draw_line(c + Vector2(-width * 0.7, 0), c + Vector2(width * 0.7, 0), GOLD if heavy else WOOD, 2)
	if state.kind == "scout":
		var bag := c - pose.across * 1.6 + Vector2(0, 6)
		Art._poly(canvas, [bag + Vector2(-4, -4), bag + Vector2(4, -4), bag + Vector2(4, 3), bag + Vector2(-4, 3)], Color("967550"))
		canvas.draw_line(bag + Vector2(-3, -1), bag + Vector2(3, -1), Color("dbc49a"), 1.1)

static func _rider_leg(canvas: CanvasItem, hip: Vector2, foot: Vector2, far_side: bool, heavy: bool) -> void:
	var knee := hip.lerp(foot, 0.5) + Vector2(2 if foot.x >= hip.x else -2, -1)
	Art._stroke(canvas, PackedVector2Array([hip, knee, foot]), EDGE, 4)
	Art._stroke(canvas, PackedVector2Array([hip, knee, foot]), STEEL.darkened(0.25) if heavy else LEATHER.darkened(0.2 if far_side else 0), 2.5)
	canvas.draw_line(foot - Vector2(2, -1), foot + Vector2(3, 0), EDGE, 2.6)
	canvas.draw_line(foot - Vector2(2, -2), foot + Vector2(3, -1), GOLD if heavy else WOOD, 0.8)

static func _rider(canvas: CanvasItem, state, pose: Pose, heavy: bool) -> void:
	var width := lerpf(5.5, 4, pose.profile)
	var coat: Color = STEEL.darkened(0.1 if pose.back else 0) if heavy else state.player_color.darkened(0.18 if pose.back else 0)
	Art._poly(canvas, [pose.chest + Vector2(-width, -2), pose.chest + Vector2(width, -2), pose.saddle + Vector2(width * 0.8, 1), pose.saddle + Vector2(-width * 0.8, 1)], coat)
	canvas.draw_line(pose.saddle - Vector2(width * 0.8, 2), pose.saddle + Vector2(width * 0.8, -2), LEATHER, 1.7)
	if heavy:
		canvas.draw_line(pose.chest + Vector2(-width + 1, 1), pose.saddle + Vector2(-width * 0.5, -4), STEEL.lightened(0.16), 1.5)
		Art._poly(canvas, [pose.chest + Vector2(-width, 0), pose.chest + Vector2(width, 0), pose.chest + Vector2(width, 4), pose.chest + Vector2(-width, 4)], state.player_color.darkened(0.1), 0)
	else:
		canvas.draw_line(pose.chest + Vector2(-3, 0), pose.saddle + Vector2(3, -2), LEATHER, 1.4)
	var h: Vector2 = pose.head
	var hwidth := lerpf(4.4, 3.7, pose.profile)
	Art._poly(canvas, [h + Vector2(-hwidth, -3), h + Vector2(hwidth, -3), h + Vector2(hwidth, 2), h + Vector2(0, 5), h + Vector2(-hwidth, 2)], LEATHER if pose.back else SKIN)
	if heavy:
		Art._poly(canvas, [h + Vector2(-hwidth - 1, -2), h + Vector2(hwidth + 1, -2), h + Vector2(hwidth * 0.7, -7), h + Vector2(-hwidth * 0.7, -7)], STEEL.lightened(0.1))
		if not pose.back:
			if pose.profile > 0.4:
				var side := signf(pose.direction.x)
				canvas.draw_line(h + Vector2(side, -1), h + Vector2(side * (hwidth + 0.5), -1), EDGE, 1.2)
				canvas.draw_line(h + Vector2(side * hwidth * 0.85, -1), h + Vector2(side * hwidth * 0.85, 4), STEEL, 1.5)
			else:
				canvas.draw_line(h + Vector2(-hwidth * 0.6, -1), h + Vector2(hwidth * 0.7, -1), EDGE, 1.2)
				canvas.draw_line(h + Vector2(0, -1), h + Vector2(0, 4), STEEL, 1.5)
		if state.kind == "royal_knight":
			Art._poly(canvas, [h + Vector2(-1, -7), h + Vector2(1, -7), h + Vector2(-pose.aim.x * 4 + 1, -13), h + Vector2(-pose.aim.x * 4 - 2, -12)], state.player_color.lightened(0.25))
			canvas.draw_line(h + Vector2(-4, -4), h + Vector2(4, -4), GOLD, 1.2)
	else:
		var cap := Color("736f49") if state.kind == "scout" else Color("695a45") if state.kind == "horseman" else Color("555f5a")
		Art._poly(canvas, [h + Vector2(-hwidth - 1, -3), h + Vector2(hwidth + 1, -3), h + Vector2(hwidth * 0.7, -7), h + Vector2(-hwidth * 0.7, -7)], cap)
		if not pose.back:
			if pose.profile > 0.4:
				var side := signf(pose.direction.x)
				Art._poly(canvas, [h + Vector2(side * 3, -1), h + Vector2(side * 5.5, 1), h + Vector2(side * 3, 2)], SKIN, 0.7)
			var x := signf(pose.direction.x) * 2.0 if pose.profile > 0.4 else 1.7
			Art._dot(canvas, h + Vector2(x, 0), 0.7, EDGE)
			if pose.profile < 0.4: Art._dot(canvas, h + Vector2(-x, 0), 0.7, EDGE)

static func _weapon(canvas: CanvasItem, state, pose: Pose, lowered: bool, attack: bool, hit: float) -> void:
	var grip: Vector2 = pose.near_hand
	var progress: float = state.action_progress
	if lowered or state.kind == "fire_lancer":
		var rest_angle := Vector2(pose.direction.x * 0.15, -1).angle()
		var angle := pose.aim.angle() if lowered else rest_angle
		var axis := Vector2.RIGHT.rotated(angle)
		var tip := grip + axis * 34
		canvas.draw_line(grip - axis * 12, tip, EDGE, 3.5)
		canvas.draw_line(grip - axis * 12, tip, WOOD, 2)
		var normal := axis.orthogonal() * 2.5
		Art._poly(canvas, [tip + axis * 7, tip - axis + normal, tip - axis - normal], STEEL)
		if state.kind == "fire_lancer":
			canvas.draw_line(tip - axis * 7, tip + axis, LEATHER, 5)
			canvas.draw_line(tip - axis * 6, tip, GOLD.darkened(0.1), 3)
			if attack and state.action_released and state.release_elapsed >= 0.0 and state.release_elapsed < 0.15:
				var flare := 7 + hit * 10
				Art._poly(canvas, [tip, tip + axis * flare + normal * 0.5, tip + axis * (flare + 4), tip + axis * flare - normal * 0.5], Color("e99135"), 0)
				Art._poly(canvas, [tip, tip + axis * (flare * 0.7) + normal * 0.4, tip + axis * (flare * 0.85), tip + axis * (flare * 0.7) - normal * 0.4], Color("ffe1a0"), 0)
	elif state.kind == "scout" and not attack:
		var tip := grip + pose.aim * 11 + Vector2(0, -2)
		canvas.draw_line(grip, tip, EDGE, 4.8)
		canvas.draw_line(grip, tip, WOOD, 3)
		Art._dot(canvas, tip, 2.3, GOLD)
		Art._dot(canvas, tip + pose.aim * 0.3, 1.3, Color("8db4bd"))
	else:
		var angle := Vector2(pose.direction.x * 0.4, -1).angle()
		if attack:
			if state.action_released: angle = lerp_angle(pose.aim.angle(), Vector2(pose.direction.x * 0.4, -1).angle(), smoothstep(0.4, 1, progress))
			else: angle += (-0.7 if pose.direction.x >= 0 else 0.7) * clampf(progress / 0.45, 0, 1)
		var axis := Vector2.RIGHT.rotated(angle)
		var tip := grip + axis * 22
		var normal := axis.orthogonal()
		Art._poly(canvas, [grip + axis * 3 - normal * 1.8, tip, grip + axis * 3 + normal * 1.8], STEEL.lightened(0.1))
		canvas.draw_line(grip + axis * 3 - normal * 4, grip + axis * 3 + normal * 4, GOLD, 2)
		canvas.draw_line(grip - axis * 3, grip + axis * 3, LEATHER, 2.3)
	Art._dot(canvas, grip, 1.8, SKIN)

static func _shield(canvas: CanvasItem, state, pose: Pose) -> void:
	var c: Vector2 = pose.far_hand
	var width := lerpf(5, 3.5, pose.profile)
	Art._poly(canvas, [c + Vector2(-width, -7), c + Vector2(width, -7), c + Vector2(width, 1), c + Vector2(0, 8), c + Vector2(-width, 1)], state.player_color.darkened(0.12))
	canvas.draw_line(c + Vector2(0, -5), c + Vector2(0, 4), GOLD if state.kind == "royal_knight" else STEEL, 1.2)
	if state.kind == "royal_knight": canvas.draw_line(c + Vector2(-width + 1, -1), c + Vector2(width - 1, -1), GOLD, 1.2)

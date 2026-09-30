extends RefCounted

const Pose = preload("res://scripts/entities/visuals/humanoid_pose.gd")
const Human = preload("res://scripts/entities/visuals/humanoid_visual.gd")
const POWDER := Color("49392d")
const BRASS := Color("bd9853")

static func handles(kind: String) -> bool:
	return kind in ["crossbowman", "arbaletrier", "zhuge_nu", "handcannoneer", "grenadier"]

static func health_bar_y(state) -> float:
	return -57.0 if state.kind == "grenadier" else -52.0

static func draw(canvas: CanvasItem, state, pose: Pose) -> void:
	pose.update(state)
	var attack: bool = state.visual_action == "attack" and not state.visual_moving
	var weapon_aim := pose.aim
	if state.kind == "grenadier":
		_grenade_pose(state, pose)
	else:
		weapon_aim = _weapon_pose(state, pose)
	# Stowed pavises are visible behind the soldier; deployed shields stand ahead.
	if state.kind == "arbaletrier" and not state.shield_active:
		_pavise(canvas, pose.chest - Vector2(pose.across.x * 0.85, -3), state.player_color, pose.profile, false)
	Human._leg(canvas, pose.far_hip, pose.far_knee, pose.far_foot, true, pose.direction)
	Human._arm(canvas, pose.far_shoulder, pose.far_hand, state.player_color.darkened(0.27), -1.0)
	if pose.back: _equipment(canvas, state, pose, weapon_aim, attack)
	Human._body(canvas, state, pose)
	_belt_equipment(canvas, state, pose)
	Human._leg(canvas, pose.near_hip, pose.near_knee, pose.near_foot, false, pose.direction)
	Human._arm(canvas, pose.near_shoulder, pose.near_hand, state.player_color.darkened(0.08), 1.0)
	if not pose.back: _equipment(canvas, state, pose, weapon_aim, attack)

static func _weapon_pose(state, pose: Pose) -> Vector2:
	var attack: bool = state.visual_action == "attack" and not state.visual_moving
	var released: bool = attack and state.action_released
	var reload := smoothstep(0.55, 0.95, state.action_progress) if released else 0.0
	var ready := 1.0 - reload if attack else 0.0
	# A carried stock slopes down; aiming changes both arms and the weapon together.
	var carry_side := -1.0 if pose.direction.x < -0.1 else 1.0
	var carrying := Vector2(carry_side * 0.82, 0.44).normalized()
	var aim := Vector2.RIGHT.rotated(lerp_angle(carrying.angle(), pose.aim.angle(), ready))
	var recoil := (1.0 - smoothstep(0.0, 0.16, state.release_elapsed)) * 2.8 if released else 0.0
	var grip := pose.chest + Vector2(0, 5) + pose.aim * (3.0 + ready * 4.0 - recoil)
	pose.near_hand = grip
	pose.far_hand = grip + aim * 10.0
	if reload > 0.0:
		# Draw the cocking/loading hand back toward the breech after the bolt leaves.
		pose.far_hand = pose.far_hand.lerp(grip - aim * 2.0 + Vector2(0, 3), reload)
	return aim

static func _grenade_pose(state, pose: Pose) -> void:
	var attack: bool = state.visual_action == "attack" and not state.visual_moving
	if not attack:
		pose.near_hand = pose.near_shoulder + Vector2(pose.aim.x * 1.5, 10)
		return
	if state.action_released:
		var recover := smoothstep(0.1, 0.3, state.release_elapsed)
		pose.near_hand = (pose.chest + pose.aim * 20.0 - Vector2(0, 3)).lerp(pose.near_shoulder + Vector2(0, 11), recover)
		pose.far_hand = pose.chest - pose.aim * 4.0 + Vector2(0, 8)
	else:
		var lift := smoothstep(0.0, 0.47, state.action_progress)
		pose.near_hand = (pose.near_shoulder + Vector2(0, 10)).lerp(pose.head - Vector2(pose.aim.x * 7.0, 12), lift)
		pose.far_hand = pose.chest + pose.aim * 4.0 + Vector2(0, 7)

static func _equipment(canvas: CanvasItem, state, pose: Pose, aim: Vector2, attack: bool) -> void:
	if state.kind == "grenadier":
		if not attack or not state.action_released:
			_grenade(canvas, pose.near_hand - Vector2(0, 2), attack, state.action_progress)
	elif state.kind == "handcannoneer":
		_handcannon(canvas, pose.near_hand, aim, attack and state.action_released and state.release_elapsed < 0.09)
	else:
		_crossbow(canvas, pose.near_hand, aim, state.kind == "zhuge_nu", attack and not state.action_released)
	if state.kind == "arbaletrier" and state.shield_active:
		_pavise(canvas, pose.pelvis + pose.aim * 12.0 + Vector2(0, 3), state.player_color, absf(pose.aim.x), true)
	Human._dot(canvas, pose.near_hand, 1.8, Human.SKIN)
	if state.kind != "grenadier": Human._dot(canvas, pose.far_hand, 1.8, Human.SKIN)

static func _crossbow(canvas: CanvasItem, grip: Vector2, aim: Vector2, repeating: bool, loaded: bool) -> void:
	var normal := aim.orthogonal()
	var tail := grip - aim * 7.0
	var nose := grip + aim * 19.0
	Human._poly(canvas, [tail - normal * 2, nose - normal * 1.5, nose + normal * 1.5, tail + normal * 3], Human.WOOD)
	var bow_center := grip + aim * 14.0
	var bow_tip_a := bow_center + normal * 10.0 - aim * 3.0
	var bow_tip_b := bow_center - normal * 10.0 - aim * 3.0
	var limbs := PackedVector2Array([bow_tip_a, bow_center + normal * 5.0, bow_center + aim * 1.5, bow_center - normal * 5.0, bow_tip_b])
	Human._stroke(canvas, limbs, Human.EDGE, 3.5)
	Human._stroke(canvas, limbs, Human.STEEL.darkened(0.15), 1.7)
	var string_center := grip + aim * (3.0 if loaded else 13.0)
	Human._stroke(canvas, PackedVector2Array([bow_tip_a, string_center, bow_tip_b]), Color("ded5b8"), 0.9)
	if repeating:
		# An upright bolt magazine and cocking lever distinguish the repeating crossbow.
		var magazine := grip + aim * 6.0 - Vector2(0, 5)
		Human._poly(canvas, [magazine + Vector2(-4, -4), magazine + Vector2(4, -4), magazine + Vector2(4, 3), magazine + Vector2(-4, 3)], Human.WOOD.darkened(0.12))
		canvas.draw_line(magazine + Vector2(-2, -2), magazine + Vector2(2, -2), Human.STEEL, 1.2)
		canvas.draw_line(grip - aim * 2, grip - aim * 5 - Vector2(0, 7), Human.EDGE, 2.2)
	if loaded:
		var tip := grip + aim * 24.0
		canvas.draw_line(string_center, tip, Color("e1c795"), 1.2)
		Human._poly(canvas, [tip + aim * 3, tip - aim + normal * 1.7, tip - aim - normal * 1.7], Human.STEEL, 0.5)

static func _handcannon(canvas: CanvasItem, grip: Vector2, aim: Vector2, flash: bool) -> void:
	var normal := aim.orthogonal()
	var tail := grip - aim * 8.0
	var breech := grip + aim * 3.0
	var muzzle := grip + aim * 23.0
	Human._poly(canvas, [tail - normal * 2, breech - normal * 2.7, breech + normal * 2.7, tail + normal * 3], Human.WOOD.darkened(0.12))
	Human._poly(canvas, [breech - normal * 2.4, muzzle - normal * 2.7, muzzle + normal * 2.7, breech + normal * 2.4], Human.STEEL.darkened(0.3))
	canvas.draw_line(breech - normal * 1.2, muzzle - normal * 1.2, Human.STEEL.lightened(0.1), 1.0)
	canvas.draw_line(muzzle - normal * 2.8, muzzle + normal * 2.8, Human.EDGE, 2.0)
	canvas.draw_line(grip, grip - normal * 5, BRASS, 1.8)
	if flash:
		# Two convex wedges keep the brief flash in the same primitive batch.
		Human._poly(canvas, [muzzle + aim, muzzle + aim * 13, muzzle + aim * 5 + normal * 5], Color("ffcf67"), 0.0)
		Human._poly(canvas, [muzzle + aim, muzzle + aim * 10, muzzle + aim * 4 - normal * 4], Color("fff0a3"), 0.0)

static func _grenade(canvas: CanvasItem, center: Vector2, lit: bool, progress: float) -> void:
	Human._dot(canvas, center, 3.2, Human.EDGE)
	Human._dot(canvas, center, 2.3, POWDER)
	canvas.draw_line(center + Vector2(-1, -2), center + Vector2(1, -2), BRASS, 1.2)
	var wick := center - Vector2(0, 3)
	canvas.draw_line(wick, wick + Vector2(2, -2), Human.WOOD.lightened(0.2), 1.1)
	if lit and progress > 0.15: Human._dot(canvas, wick + Vector2(2, -2), 1.1, Color("ffd370"))

static func _belt_equipment(canvas: CanvasItem, state, pose: Pose) -> void:
	if state.kind == "handcannoneer":
		for side in [-1.0, 1.0]:
			var center := pose.pelvis + Vector2(side * pose.width * 0.75, 1)
			Human._poly(canvas, [center + Vector2(-1.2, -2), center + Vector2(1.2, -2), center + Vector2(2, 3), center + Vector2(-2, 3)], BRASS.darkened(0.1))
	elif state.kind == "grenadier":
		for side in [-1.0, 1.0]:
			var center := pose.pelvis + Vector2(side * pose.width * 0.7, 1.5)
			Human._dot(canvas, center, 2.4, Human.EDGE)
			Human._dot(canvas, center, 1.6, POWDER)
	else:
		var center := pose.pelvis - Vector2(pose.across.x * 0.8, 0)
		Human._poly(canvas, [center + Vector2(-2, -3), center + Vector2(2, -3), center + Vector2(2, 5), center + Vector2(-2, 5)], Human.LEATHER)

static func _pavise(canvas: CanvasItem, center: Vector2, team: Color, profile: float, deployed: bool) -> void:
	var width := lerpf(7.5, 4.0, profile)
	var height := 23.0 if deployed else 20.0
	var bottom := center + Vector2(0, 6)
	var top := bottom - Vector2(0, height)
	Human._poly(canvas, [top + Vector2(-width * 0.75, 0), top + Vector2(width * 0.75, 0), top + Vector2(width, 4), bottom + Vector2(width, 0), bottom + Vector2(-width, 0), top + Vector2(-width, 4)], Human.WOOD.darkened(0.12))
	Human._poly(canvas, [top + Vector2(-width * 0.48, 3), top + Vector2(width * 0.48, 3), bottom + Vector2(width * 0.6, -2), bottom + Vector2(-width * 0.6, -2)], team.darkened(0.08), 0.0)
	canvas.draw_line(top + Vector2(0, 2), bottom - Vector2(0, 1), BRASS, 1.6)
	if deployed: canvas.draw_line(bottom + Vector2(width * 0.5, -3), bottom + Vector2(width + 3, 1), Human.EDGE, 2.0)

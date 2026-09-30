extends RefCounted

# One articulated figure path shared by the map, portraits and unit previews.
const Human = preload("res://scripts/entities/visuals/humanoid_visual.gd")
const HumanPose = preload("res://scripts/entities/visuals/humanoid_pose.gd")
const Support = preload("res://scripts/entities/visuals/support_infantry_visual.gd")
const Ranged = preload("res://scripts/entities/visuals/ranged_infantry_visual.gd")
const Cavalry = preload("res://scripts/entities/visuals/cavalry_visual.gd")
const HorsePose = preload("res://scripts/entities/visuals/cavalry_pose.gd")

var human_pose := HumanPose.new()
var horse_pose := HorsePose.new()

static func handles(kind: String) -> bool:
	return Human.handles(kind) or Support.handles(kind) or Ranged.handles(kind) or Cavalry.handles(kind)

static func draw_shadow(canvas: CanvasItem, state) -> void:
	if Cavalry.handles(state.kind): Cavalry.draw_shadow(canvas)
	else: Human.draw_shadow(canvas)

func draw(canvas: CanvasItem, state) -> void:
	if Cavalry.handles(state.kind): Cavalry.draw(canvas, state, horse_pose)
	elif Support.handles(state.kind): Support.draw(canvas, state, human_pose)
	elif Ranged.handles(state.kind): Ranged.draw(canvas, state, human_pose)
	else: Human.draw(canvas, state, human_pose)

static func health_bar_y(state) -> float:
	if Cavalry.handles(state.kind): return Cavalry.health_bar_y(state)
	if Support.handles(state.kind): return Support.health_bar_y(state)
	if Ranged.handles(state.kind): return Ranged.health_bar_y(state)
	return -74.0 if state.kind == "spearman" else -52.0 if state.kind == "villager" else -45.0

static func portrait_dimensions(state) -> Vector2:
	if state.kind == "handcannoneer": return Vector2(62, 60)
	return Vector2(54, 82) if Cavalry.handles(state.kind) else Vector2(40, 60)

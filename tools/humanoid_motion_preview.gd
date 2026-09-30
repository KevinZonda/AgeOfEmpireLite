extends SceneTree

# Production renderer, no match simulation. Space switches projection;
# left/right rotate work and attack poses. Optional capture saves a PNG and exits.
const Visual = preload("res://scripts/entities/visuals/unit_visual.gd")
const State = preload("res://scripts/entities/visuals/unit_visual_state.gd")
const KINDS = ["villager", "spearman", "archer", "longbow"]
const COLUMNS = ["IDLE / FRONT", "WALK / SIDE", "WALK / BACK", "PREPARE / WORK", "IMPACT / RELEASE"]

class Actor extends Node2D:
	var state
	var renderer = Visual.new()
	func _draw() -> void: renderer.draw(self, state)

var actors: Array[Actor] = []
var camera: Camera2D
var title: Label
var isometric := true
var elapsed := 0.0
var heading := int(OS.get_environment("RTS_HUMANOID_HEADING"))
var show_hunting := OS.get_environment("RTS_HUMANOID_HUNT") == "1"
var capture_path := OS.get_environment("RTS_HUMANOID_CAPTURE")
var captured := false

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1440, 850)
	root.title = "Humanoid motion preview"
	RenderingServer.set_default_clear_color(Color("41523e"))
	isometric = OS.get_environment("RTS_HUMANOID_PROJECTION") != "2d"
	camera = Camera2D.new()
	root.add_child(camera)
	camera.position = Vector2(1500, 1500)
	_apply_camera()
	await process_frame
	var overlay := CanvasLayer.new()
	root.add_child(overlay)
	title = _label(overlay, "", Vector2(20, 18), 21)
	for column in COLUMNS.size(): _label(overlay, COLUMNS[column], Vector2(150 + column * 255, 85), 17)
	for row in KINDS.size():
		_label(overlay, KINDS[row], Vector2(20, 218 + row * 163), 19)
		for column in COLUMNS.size():
			var actor := Actor.new()
			actor.state = State.preview(KINDS[row], GameData.UNITS[KINDS[row]], Color("4e9bea"))
			root.add_child(actor)
			actors.append(actor)
	process_frame.connect(_tick)

func _label(parent: Node, content: String, point: Vector2, size: int) -> Label:
	var label := Label.new()
	label.text = content
	label.position = point
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)
	return label

func _apply_camera() -> void:
	camera.rotation = -PI / 4.0 if isometric else 0.0
	camera.zoom = Vector2(3.2, 1.6) if isometric else Vector2.ONE * 3.2
	camera.force_update_scroll()

func _tick() -> void:
	elapsed += root.get_process_delta_time()
	if capture_path.is_empty():
		if Input.is_action_just_pressed("ui_accept"):
			isometric = not isometric
			_apply_camera()
		if Input.is_action_just_pressed("ui_right"): heading = (heading + 1) % 8
		if Input.is_action_just_pressed("ui_left"): heading = (heading + 7) % 8
	var canvas := root.get_canvas_transform()
	title.text = "Shared humanoid poses · %s · Space: projection · Left / Right: eight directions" % ("2.5D" if isometric else "2D")
	for index in actors.size():
		var row := index / COLUMNS.size()
		var column := index % COLUMNS.size()
		var actor := actors[index]
		actor.position = canvas.affine_inverse() * Vector2(240 + column * 255, 258 + row * 163)
		actor.state.view_mode_25d = isometric
		actor.state.zoom = camera.zoom.x
		actor.state.visual_moving = column in [1, 2]
		actor.state.visual_phase = elapsed * 7.5
		actor.state.facing_direction = Vector2.DOWN if column == 0 else Vector2.RIGHT if column == 1 else Vector2.UP if column == 2 else Vector2.RIGHT.rotated(heading * PI / 4.0)
		actor.state.visual_action = "gather" if row == 0 and column >= 3 else "attack" if column >= 3 else ""
		actor.state.gather_kind = "wood"
		actor.state.hunting = show_hunting and row == 0
		if actor.state.hunting and column >= 3: actor.state.visual_action = "hunt"
		actor.state.hunt_draw = 0.7 if column == 3 else 0.0
		actor.state.action_progress = 0.2 + sin(elapsed * 4.0) * 0.1 if column == 3 else 0.53 + sin(elapsed * 4.0) * 0.09 if column == 4 else 0.0
		actor.state.action_released = column == 4 and (row != 0 or actor.state.hunting)
		actor.queue_redraw()
	if not capture_path.is_empty() and elapsed > 1.0 and not captured:
		captured = true
		_capture.call_deferred()

func _capture() -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture_path)
	print("HUMANOID_PREVIEW_CAPTURE ", capture_path)
	quit()

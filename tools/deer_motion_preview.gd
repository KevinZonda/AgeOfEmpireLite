extends SceneTree

# Isolated renderer/behavior preview using the production resource and AI.
# Space switches projection; optional capture writes a viewport PNG and exits.
class PreviewWorld extends "res://tests/helpers/navigation_fixture.gd":
	var camera: Camera2D

var game: PreviewWorld
var poses: Array[RtsResource] = []
var herd: Array[RtsResource] = []
var elapsed := 0.0
var capture_path := OS.get_environment("RTS_DEER_CAPTURE")
var captured := false
var title: Label

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 800)
	root.title = "Deer motion preview"
	root.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	RenderingServer.set_default_clear_color(Color("526d47"))
	game = PreviewWorld.new()
	root.add_child(game)
	game.initialize(Vector2(3000, 3000))
	game.camera = Camera2D.new()
	game.add_child(game.camera)
	game.camera.position = Vector2(1500, 1500)
	game.view_mode_25d = OS.get_environment("RTS_DEER_PROJECTION") != "2d"
	_apply_camera()
	# Wait for the viewport's camera transform before placing the live herd.
	await process_frame
	var overlay := CanvasLayer.new()
	root.add_child(overlay)
	title = _label(overlay, "", Vector2(30, 20), 24)
	for column in 3:
		_label(overlay, ["GRAZING", "WALKING", "FLEEING"][column], Vector2(240 + column * 350, 80))
	for row in 4:
		_label(overlay, ["Right", "Left", "Toward", "Away"][row], Vector2(30, 165 + row * 95))
		for column in 3:
			poses.append(_deer(Vector2(310 + column * 350, 200 + row * 95)))
	_label(overlay, "LIVE HERD: stationary grazing, short walks, then grazing again", Vector2(30, 550))
	for i in 6:
		herd.append(_deer(Vector2(180 + i * 175, 720)))
	process_frame.connect(_tick)

func _label(parent: Node, content: String, point: Vector2, size := 18) -> Label:
	var label := Label.new()
	label.text = content
	label.position = point
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)
	return label

func _deer(screen: Vector2) -> RtsResource:
	var deer := RtsResource.new()
	deer.game = game
	deer.position = root.get_canvas_transform().affine_inverse() * screen
	game.add_child(deer)
	deer.setup("food", 160, "deer")
	deer.set_process(false)
	game.resources.append(deer)
	return deer

func _apply_camera() -> void:
	game.camera.rotation = -PI / 4.0 if game.view_mode_25d else 0.0
	game.camera.zoom = Vector2(2, 1) if game.view_mode_25d else Vector2(2, 2)
	game.camera.force_update_scroll()

func _tick() -> void:
	var delta := root.get_process_delta_time()
	elapsed += delta
	if capture_path.is_empty() and Input.is_action_just_pressed("ui_accept"):
		game.view_mode_25d = not game.view_mode_25d
		_apply_camera()
		for i in herd.size():
			herd[i].position = root.get_canvas_transform().affine_inverse() * Vector2(180 + i * 175, 720)
			herd[i].setup("food", 160, "deer")
	var canvas := root.get_canvas_transform()
	title.text = "Deer motion · %s · Space: switch view" % ("2.5D" if game.view_mode_25d else "2D")
	for i in poses.size():
		var row := i / 3
		var column := i % 3
		var deer := poses[i]
		deer.position = canvas.affine_inverse() * Vector2(310 + column * 350, 200 + row * 95)
		deer.deer_direction = canvas.affine_inverse().basis_xform([Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP][row]).normalized()
		deer.deer_graze = 1.0 if column == 0 else 0.0
		deer.deer_gait = 0.0 if column == 0 else 1.0
		deer.deer_speed = [0.0, 18.0, 80.0][column]
		deer.deer_phase = elapsed * (4.0 if column == 1 else 11.0)
		deer.wander_time = elapsed
		deer.queue_redraw()
	for deer in herd: deer._process(delta)
	if not capture_path.is_empty() and elapsed > 3.0 and not captured:
		captured = true
		_capture.call_deferred()

func _capture() -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture_path)
	print("DEER_PREVIEW_CAPTURE ", capture_path)
	quit()

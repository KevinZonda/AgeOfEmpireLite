extends SceneTree

class PreviewWorld extends "res://tests/helpers/navigation_fixture.gd":
	var camera: Camera2D
	func player_color(_owner: int) -> Color:
		return Color("628fc4")
	func find_nearest_owned_building(_owner: int, _kind: String, _point: Vector2) -> RtsBuilding:
		return null

class PreviewUnit extends RtsUnit:
	func take_damage(damage: float) -> void:
		hp -= damage

var game: PreviewWorld
var poses: Array[RtsResource] = []
var followers: Array[RtsResource] = []
var targets: Array[RtsUnit] = []
var markers: Array[ColorRect] = []
var elapsed := 0.0
var title: Label
var capture_path := OS.get_environment("RTS_ANIMAL_CAPTURE")
var captured := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 800)
	root.title = "Sheep and boar motion preview"
	RenderingServer.set_default_clear_color(Color("526d47"))
	game = PreviewWorld.new()
	root.add_child(game)
	game.initialize(Vector2(3000, 3000))
	game.camera = Camera2D.new()
	game.add_child(game.camera)
	game.camera.position = Vector2(1500, 1500)
	game.view_mode_25d = OS.get_environment("RTS_ANIMAL_PROJECTION") != "2d"
	_apply_camera()
	await process_frame
	var overlay := CanvasLayer.new()
	root.add_child(overlay)
	title = _label(overlay, "", Vector2(30, 20), 24)
	_label(overlay, "SHEEP", Vector2(310, 78), 22)
	_label(overlay, "BOAR", Vector2(910, 78), 22)
	for column in 7:
		_label(overlay, ["Graze", "Follow", "Carcass", "Sniff", "Chase", "Attack", "Carcass"][column], Vector2(_column_x(column) - 30, 120))
	for row in 4:
		_label(overlay, ["Right", "Left", "Toward", "Away"][row], Vector2(20, 195 + row * 90))
		for column in 7:
			poses.append(_animal(Vector2(_column_x(column), 230 + row * 90), "sheep" if column < 3 else "boar"))
	_label(overlay, "LIVE: sheep follows a scout (blue); boar pursues a villager (red)", Vector2(30, 560))
	for i in 2:
		var node := _animal(Vector2(210 + i * 640, 710), "sheep" if i == 0 else "boar")
		followers.append(node)
		var target := PreviewUnit.new()
		target.game = game
		target.kind = "scout" if i == 0 else "villager"
		target.owner_id = 0
		target.hp = 100000.0
		target.stats = {"radius": 12.0, "speed": 80.0}
		target.position = root.get_canvas_transform().affine_inverse() * Vector2(330 + i * 640, 710)
		game.add_child(target)
		target.set_process(false)
		target.hide()
		game.units.append(target)
		targets.append(target)
		var marker := ColorRect.new()
		marker.size = Vector2(12, 12)
		marker.color = Color("73a7e0") if i == 0 else Color("e98a75")
		overlay.add_child(marker)
		markers.append(marker)
	game.navigation.invalidate_spatial_index()
	process_frame.connect(_tick)

func _label(parent: Node, content: String, point: Vector2, size := 18) -> Label:
	var label := Label.new()
	label.text = content
	label.position = point
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)
	return label

func _column_x(column: int) -> float:
	return 180.0 + column * 160.0

func _animal(screen: Vector2, species: String) -> RtsResource:
	var node := RtsResource.new()
	node.game = game
	node.position = root.get_canvas_transform().affine_inverse() * screen
	game.add_child(node)
	node.setup("food", 200, species)
	node.set_process(false)
	game.resources.append(node)
	return node

func _apply_camera() -> void:
	game.camera.rotation = -PI / 4.0 if game.view_mode_25d else 0.0
	game.camera.zoom = Vector2(1.8, 0.9) if game.view_mode_25d else Vector2.ONE * 1.8
	game.camera.force_update_scroll()

func _tick() -> void:
	var delta := root.get_process_delta_time()
	elapsed += delta
	if capture_path.is_empty() and Input.is_action_just_pressed("ui_accept"):
		game.view_mode_25d = not game.view_mode_25d
		_apply_camera()
		for i in followers.size():
			followers[i].position = root.get_canvas_transform().affine_inverse() * Vector2(210 + i * 640, 710)
			followers[i].setup("food", 200, "sheep" if i == 0 else "boar")
	var canvas := root.get_canvas_transform()
	title.text = "Sheep & boar · %s · Space: switch view" % ("2.5D" if game.view_mode_25d else "2D")
	for i in poses.size():
		var row := i / 7
		var column := i % 7
		var node := poses[i]
		node.position = canvas.affine_inverse() * Vector2(_column_x(column), 230 + row * 90)
		node.animal_direction = canvas.affine_inverse().basis_xform([Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP][row]).normalized()
		node.wildlife_hp = 0.0 if column in [2, 6] else node.wildlife_max_hp
		node.animal_gait = 1.0 if column in [1, 4] else 0.0
		node.animal_graze = 1.0 if column in [0, 3] else 0.0
		node.animal_phase = elapsed * (67.0 / 32.0 if column == 1 else 44.0 / 28.0) * TAU
		node.wander_time = elapsed
		# The hit animation follows the real 1.2-second attack cooldown.
		node.boar_attack_pose = maxf(0.0, 0.36 - fmod(elapsed, 1.2)) if column == 5 else 0.0
		node.queue_redraw()
	for i in followers.size():
		var point := Vector2(330 + i * 640 + sin(elapsed * 0.8) * 60, 710 + cos(elapsed * 0.8) * 15)
		targets[i].position = canvas.affine_inverse() * point
		markers[i].position = point - Vector2(6, 6)
	game.navigation.invalidate_spatial_index()
	for node in followers: node._process(delta)
	if not capture_path.is_empty() and elapsed > 2.55 and not captured:
		captured = true
		_capture.call_deferred()

func _capture() -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture_path)
	print("LIVESTOCK_PREVIEW_CAPTURE ", capture_path)
	quit()
